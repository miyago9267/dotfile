---
name: diagnose
description: "Codex hard-bug diagnosis loop -- build a reproducible pass/fail signal before fixing. Use when Miyago reports broken behavior, failing tests, crashes, flaky behavior, regressions, or asks to debug/diagnose."
user-invocable: true
when_to_use: "Use when a bug or regression needs structured reproduction, hypothesis testing, instrumentation, and regression verification."
tags: [codex, debug, diagnose, regression, tests]
effort: medium
shell: preferred
runtime-scope: codex-native
---

# Codex Diagnose

Debug through a feedback loop, not code staring.

## Flow

1. Define the observed failure in one sentence.
2. Build the cheapest deterministic pass/fail signal:
   - targeted failing test
   - CLI command with fixture input
   - HTTP request against a local server
   - replayed log, trace, payload, or fixture
   - browser script only when UI behavior is the bug
3. Reproduce the user's failure with that signal. If it shows a different
   failure, narrow again.
4. List 3-5 falsifiable hypotheses, ranked by likelihood.
5. Test one hypothesis at a time. Prefer debugger/REPL inspection, then
   targeted logs.
6. Convert the minimal repro into a regression test when a correct seam exists.
7. Fix the issue, then rerun both the minimal signal and the original scenario.
8. Remove temporary instrumentation and throwaway harnesses.

## Instrumentation

- Tag temporary logs with a unique prefix like `[DEBUG-a4f2]`.
- Change one variable per probe.
- For performance regressions, measure before fixing: baseline timing, profiler
  output, query plan, or equivalent.

## When A Loop Is Not Available

Stop and say what was tried. Ask for the missing artifact only after local
attempts are exhausted:

- failing input
- logs or stack trace
- HAR/network capture
- screen recording with timestamps
- access to an environment that reproduces the issue

Do not present a speculative fix as complete without a reproduction path.

## Done Criteria

- Original failure no longer reproduces.
- Regression test exists, or the missing test seam is explicitly reported.
- Temporary `[DEBUG-...]` instrumentation is removed.
- Verification commands and unverified risk are reported.
