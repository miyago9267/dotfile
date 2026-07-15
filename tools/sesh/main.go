// Command sesh is a unified session finder across Claude Code and Codex CLI
// sessions. It scans both history stores, presents a single fzf-driven picker
// sorted by recency, and execs the correct resume command for the choice.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"syscall"
	"time"
)

// Session is one resumable conversation from either backend.
type Session struct {
	Tool    string // "cc" or "codex"
	ID      string
	Cwd     string
	Title   string
	Updated time.Time
}

func main() {
	var (
		onlyCC    bool
		onlyCodex bool
		listOnly  bool
		query     string
	)
	for _, a := range os.Args[1:] {
		switch a {
		case "--help", "-h":
			usage()
			return
		case "--cc":
			onlyCC = true
		case "--codex":
			onlyCodex = true
		case "--list":
			listOnly = true
		default:
			if strings.HasPrefix(a, "-") {
				fmt.Fprintf(os.Stderr, "sesh: unknown flag %q\n", a)
				usage()
				os.Exit(2)
			}
			query = a
		}
	}

	home, _ := os.UserHomeDir()
	var sessions []Session
	if !onlyCodex {
		sessions = append(sessions, scanClaude(home)...)
	}
	if !onlyCC {
		sessions = append(sessions, scanCodex(home)...)
	}

	sort.SliceStable(sessions, func(i, j int) bool {
		return sessions[i].Updated.After(sessions[j].Updated)
	})

	if len(sessions) == 0 {
		fmt.Fprintln(os.Stderr, "sesh: no sessions found")
		return
	}

	lines := make([]string, len(sessions))
	for i, s := range sessions {
		lines[i] = fmt.Sprintf("%d\t%s", i, displayLine(s, home))
	}

	if listOnly {
		for _, l := range lines {
			if tab := strings.IndexByte(l, '\t'); tab >= 0 {
				fmt.Println(l[tab+1:])
			}
		}
		return
	}

	idx, ok := runFzf(lines, query)
	if !ok {
		return
	}
	resume(sessions[idx], home)
}

func usage() {
	fmt.Print(`sesh - unified Claude Code + Codex session finder

Usage:
  sesh [query]       Search all sessions (query pre-fills the fzf prompt)
  sesh --cc [query]  Only Claude Code sessions
  sesh --codex [q]   Only Codex sessions
  sesh --list        Print the parsed list as plain text (no fzf)
  sesh --help        This help

Select a session to resume it in place (cd + claude --resume, or codex resume).
Requires fzf on PATH for interactive selection.
`)
}

// displayLine renders the human-visible portion of an fzf row.
func displayLine(s Session, home string) string {
	tag := "[cc]"
	if s.Tool == "codex" {
		tag = "[codex]"
	}
	cwd := tildify(s.Cwd, home)
	if cwd == "" {
		cwd = "?"
	}
	title := sanitize(s.Title)
	if title == "" {
		title = "(no title)"
	}
	title = truncate(title, 70)
	return fmt.Sprintf("%-7s %6s  %-32s  %s", tag, relTime(s.Updated), truncate(cwd, 32), title)
}

func tildify(p, home string) string {
	if home != "" && (p == home || strings.HasPrefix(p, home+"/")) {
		return "~" + strings.TrimPrefix(p, home)
	}
	return p
}

func sanitize(s string) string {
	s = strings.ReplaceAll(s, "\n", " ")
	s = strings.ReplaceAll(s, "\t", " ")
	return strings.TrimSpace(s)
}

func truncate(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	if n <= 1 {
		return string(r[:n])
	}
	return string(r[:n-1]) + "…"
}

// relTime formats a timestamp as a compact age like "5m", "2h", "3d", "2w".
func relTime(t time.Time) string {
	if t.IsZero() {
		return "?"
	}
	d := time.Since(t)
	switch {
	case d < time.Minute:
		return "now"
	case d < time.Hour:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	case d < 24*time.Hour:
		return fmt.Sprintf("%dh", int(d.Hours()))
	case d < 7*24*time.Hour:
		return fmt.Sprintf("%dd", int(d.Hours()/24))
	case d < 365*24*time.Hour:
		return fmt.Sprintf("%dw", int(d.Hours()/(24*7)))
	default:
		return fmt.Sprintf("%dy", int(d.Hours()/(24*365)))
	}
}

// ---- Claude Code ----

type ccLine struct {
	Type    string          `json:"type"`
	Cwd     string          `json:"cwd"`
	Message json.RawMessage `json:"message"`
}

// scanClaude walks ~/.claude/projects and extracts one Session per jsonl file
// that carries a user message with a cwd.
func scanClaude(home string) []Session {
	root := filepath.Join(home, ".claude", "projects")
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil
	}
	var out []Session
	for _, dir := range entries {
		if !dir.IsDir() {
			continue
		}
		files, err := os.ReadDir(filepath.Join(root, dir.Name()))
		if err != nil {
			continue
		}
		for _, f := range files {
			if f.IsDir() || !strings.HasSuffix(f.Name(), ".jsonl") {
				continue
			}
			path := filepath.Join(root, dir.Name(), f.Name())
			if s, ok := parseClaudeFile(path); ok {
				out = append(out, s)
			}
		}
	}
	return out
}

func parseClaudeFile(path string) (Session, bool) {
	fh, err := os.Open(path)
	if err != nil {
		return Session{}, false
	}
	defer fh.Close()

	sc := bufio.NewScanner(fh)
	sc.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)
	var s Session
	found := false
	for sc.Scan() {
		var l ccLine
		if err := json.Unmarshal(sc.Bytes(), &l); err != nil {
			continue
		}
		if l.Type != "user" || l.Cwd == "" {
			continue
		}
		title := ccTitle(l.Message)
		if !found {
			s = Session{
				Tool:  "cc",
				ID:    strings.TrimSuffix(filepath.Base(path), ".jsonl"),
				Cwd:   l.Cwd,
				Title: title,
			}
			if fi, err := os.Stat(path); err == nil {
				s.Updated = fi.ModTime()
			}
			found = true
		}
		if title == "" || isInjectedPrompt(title) {
			continue
		}
		s.Title = title
		return s, true
	}
	if found && isInjectedPrompt(s.Title) {
		s.Title = ""
	}
	return s, found
}

// ccTitle extracts the user message text from either the string or array form
// of message.content.
func ccTitle(raw json.RawMessage) string {
	var msg struct {
		Content json.RawMessage `json:"content"`
	}
	if err := json.Unmarshal(raw, &msg); err != nil {
		return ""
	}
	var str string
	if err := json.Unmarshal(msg.Content, &str); err == nil {
		return str
	}
	var arr []struct {
		Text string `json:"text"`
	}
	if err := json.Unmarshal(msg.Content, &arr); err == nil {
		for _, el := range arr {
			if el.Text != "" {
				return el.Text
			}
		}
	}
	return ""
}

// ---- Codex ----

type codexIndex struct {
	ID         string `json:"id"`
	ThreadName string `json:"thread_name"`
	UpdatedAt  string `json:"updated_at"`
}

// scanCodex reads the session index (primary) plus any rollout files not
// present in the index (orphans), resolving cwd from the rollout files.
func scanCodex(home string) []Session {
	rollouts := codexRollouts(home)

	var out []Session
	seen := map[string]bool{}

	idxPath := filepath.Join(home, ".codex", "session_index.jsonl")
	if fh, err := os.Open(idxPath); err == nil {
		sc := bufio.NewScanner(fh)
		sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
		for sc.Scan() {
			var e codexIndex
			if err := json.Unmarshal(sc.Bytes(), &e); err != nil || e.ID == "" {
				continue
			}
			seen[e.ID] = true
			s := Session{Tool: "codex", ID: e.ID, Title: e.ThreadName}
			if t, err := time.Parse(time.RFC3339, e.UpdatedAt); err == nil {
				s.Updated = t
			}
			if rp, ok := rollouts[e.ID]; ok {
				s.Cwd = codexCwd(rp)
				if s.Updated.IsZero() {
					if fi, err := os.Stat(rp); err == nil {
						s.Updated = fi.ModTime()
					}
				}
			}
			out = append(out, s)
		}
		fh.Close()
	}

	for id, rp := range rollouts {
		if seen[id] {
			continue
		}
		s := Session{Tool: "codex", ID: id, Cwd: codexCwd(rp), Title: codexRolloutTitle(rp)}
		if fi, err := os.Stat(rp); err == nil {
			s.Updated = fi.ModTime()
		}
		out = append(out, s)
	}
	return out
}

// codexRollouts builds a uuid -> rollout-path map by scanning both the live and
// archived session directories.
func codexRollouts(home string) map[string]string {
	m := map[string]string{}
	for _, base := range []string{
		filepath.Join(home, ".codex", "sessions"),
		filepath.Join(home, ".codex", "archived_sessions"),
	} {
		filepath.WalkDir(base, func(path string, d os.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return nil
			}
			name := d.Name()
			if !strings.HasPrefix(name, "rollout-") || !strings.HasSuffix(name, ".jsonl") {
				return nil
			}
			stem := strings.TrimSuffix(name, ".jsonl")
			if len(stem) < 36 {
				return nil
			}
			uuid := stem[len(stem)-36:]
			if _, ok := m[uuid]; !ok {
				m[uuid] = path
			}
			return nil
		})
	}
	return m
}

type codexPayload struct {
	Payload struct {
		Cwd     string          `json:"cwd"`
		Type    string          `json:"type"`
		Role    string          `json:"role"`
		Message string          `json:"message"`
		Content json.RawMessage `json:"content"`
	} `json:"payload"`
}

// codexCwd returns the first non-empty payload.cwd from a rollout file.
func codexCwd(path string) string {
	fh, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer fh.Close()
	sc := bufio.NewScanner(fh)
	sc.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)
	for sc.Scan() {
		var p codexPayload
		if err := json.Unmarshal(sc.Bytes(), &p); err != nil {
			continue
		}
		if p.Payload.Cwd != "" {
			return p.Payload.Cwd
		}
	}
	return ""
}

// codexRolloutTitle derives a title from the first real user prompt in a
// rollout, skipping the injected environment_context block.
func codexRolloutTitle(path string) string {
	fh, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer fh.Close()
	sc := bufio.NewScanner(fh)
	sc.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)
	for sc.Scan() {
		var p codexPayload
		if err := json.Unmarshal(sc.Bytes(), &p); err != nil {
			continue
		}
		var text string
		switch {
		case p.Payload.Type == "user_message" && p.Payload.Message != "":
			text = p.Payload.Message
		case p.Payload.Type == "message" && p.Payload.Role == "user":
			var arr []struct {
				Text string `json:"text"`
			}
			if json.Unmarshal(p.Payload.Content, &arr) == nil {
				for _, el := range arr {
					if el.Text != "" {
						text = el.Text
						break
					}
				}
			}
		}
		text = strings.TrimSpace(text)
		if text == "" || isInjectedPrompt(text) {
			continue
		}
		return text
	}
	return ""
}

// injectedTag matches the harness's XML-ish wrapper tags (environment_context,
// local-command-stdout, ide_opened_file, command-name, …) that both CC and Codex
// prepend before a real prompt. Real user prompts rarely open with such a tag.
var injectedTag = regexp.MustCompile(`^<[a-z][a-z0-9_-]*>`)

// isInjectedPrompt reports whether a user_message is harness-injected context
// (agent rules, plugin lists, environment/command wrappers) rather than a real prompt.
func isInjectedPrompt(text string) bool {
	if injectedTag.MatchString(text) {
		return true
	}
	for _, p := range []string{
		"# AGENTS.md instructions",
		"Caveat:",
	} {
		if strings.HasPrefix(text, p) {
			return true
		}
	}
	return false
}

// ---- fzf + resume ----

// runFzf pipes the rows through fzf and returns the index of the selection.
// When fzf is unavailable it prints the plain list and returns ok=false.
func runFzf(lines []string, query string) (int, bool) {
	if _, err := exec.LookPath("fzf"); err != nil {
		fmt.Fprintln(os.Stderr, "sesh: fzf not found on PATH; install it (brew install fzf). Showing plain list:")
		for _, l := range lines {
			if tab := strings.IndexByte(l, '\t'); tab >= 0 {
				fmt.Println(l[tab+1:])
			}
		}
		return 0, false
	}

	args := []string{
		"--delimiter", "\t",
		"--with-nth", "2..",
		"--ansi",
		"--no-sort",
		"--prompt", "session> ",
		"--height", "80%",
		"--reverse",
	}
	if query != "" {
		args = append(args, "--query", query)
	}
	cmd := exec.Command("fzf", args...)
	cmd.Stdin = strings.NewReader(strings.Join(lines, "\n"))
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return 0, false // ESC / no match: exit quietly
	}
	sel := strings.TrimRight(string(out), "\n")
	if sel == "" {
		return 0, false
	}
	tab := strings.IndexByte(sel, '\t')
	if tab < 0 {
		return 0, false
	}
	var idx int
	if _, err := fmt.Sscanf(sel[:tab], "%d", &idx); err != nil || idx < 0 {
		return 0, false
	}
	return idx, true
}

// resume replaces the current process with the backend's resume command so its
// interactive TUI takes over the terminal.
func resume(s Session, home string) {
	var shellCmd string
	switch s.Tool {
	case "cc":
		shellCmd = fmt.Sprintf("cd %s && claude --resume %s", shQuote(s.Cwd), shQuote(s.ID))
	case "codex":
		if s.Cwd != "" {
			shellCmd = fmt.Sprintf("cd %s && codex resume %s", shQuote(s.Cwd), shQuote(s.ID))
		} else {
			shellCmd = fmt.Sprintf("codex resume %s", shQuote(s.ID))
		}
	default:
		fmt.Fprintf(os.Stderr, "sesh: unknown tool %q\n", s.Tool)
		os.Exit(1)
	}
	if err := syscall.Exec("/bin/sh", []string{"sh", "-c", shellCmd}, os.Environ()); err != nil {
		fmt.Fprintf(os.Stderr, "sesh: failed to exec: %v\n", err)
		os.Exit(1)
	}
}

func shQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}
