#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPOSITORY_URL="https://github.com/miyago9267/dotfile"
readonly DEFAULT_REF="main"
readonly DEFAULT_INSTALL_DIR="${HOME:?HOME is required}/dotfile"

ref="$DEFAULT_REF"
install_dir="${DOTFILE_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
ref_was_set=0
dir_was_set=0
dry_run=0
no_setup=0
setup_mode=""
declare -a setup_args=()

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

usage() {
  printf '%s\n' \
    'Usage: curl -fsSL https://raw.githubusercontent.com/miyago9267/dotfile/main/install.sh | bash -s -- [OPTIONS]' \
    '' \
    'Options:' \
    '  --ref REF       download a branch, tag, or commit (default: main)' \
    '  --dir PATH      keep the downloaded source at an absolute path' \
    '  --config-only   download and sync config only' \
    '  --environment   download and open the environment selection menu' \
    '  --all           install every non-optional environment item' \
    '  --everything    include optional mobile tools' \
    '  --no-setup      download the source without running setup.sh' \
    '  --dry-run       show the plan without downloading or writing files' \
    '  --help          show this help'
}

while (($# > 0)); do
  case "$1" in
    --ref)
      (($# >= 2)) || die '--ref requires a value'
      ref="$2"
      ref_was_set=1
      shift 2
      ;;
    --dir|--install-dir)
      (($# >= 2)) || die '--dir requires a value'
      install_dir="$2"
      dir_was_set=1
      shift 2
      ;;
    --config-only|--environment|--all|--everything)
      [[ -z "$setup_mode" ]] || die 'choose only one setup mode'
      [[ "$no_setup" -eq 0 ]] || die '--no-setup cannot be combined with a setup mode'
      setup_mode="$1"
      setup_args+=("$1")
      shift
      ;;
    --no-setup)
      [[ -z "$setup_mode" ]] || die '--no-setup cannot be combined with a setup mode'
      no_setup=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown option: $1"
      ;;
  esac
done

case "$ref" in
  ""|/*|*/|*//*|*..*|-*) die 'ref must be a safe branch, tag, or commit name' ;;
esac
[[ "$ref" =~ ^[A-Za-z0-9._/-]+$ ]] || die 'ref contains unsupported characters'

case "$install_dir" in
  /*) ;;
  *) die '--dir must be an absolute path' ;;
esac
case "$install_dir" in
  /|"$HOME"|*/../*|*/..|../*|..|*$'\n'*) die 'refusing an unsafe install directory' ;;
esac

source_dir=""
source_path="${BASH_SOURCE[0]:-}"
if [[ -n "$source_path" && -f "$source_path" ]]; then
  candidate_dir="$(cd "$(dirname "$source_path")" && pwd)"
  if [[ -f "$candidate_dir/setup.sh" && -d "$candidate_dir/config" ]]; then
    source_dir="$candidate_dir"
  fi
fi

use_checkout=0
if [[ -n "$source_dir" && "$ref_was_set" -eq 0 && "$dir_was_set" -eq 0 \
  && -z "${DOTFILE_INSTALL_DIR:-}" ]]; then
  use_checkout=1
  install_dir="$source_dir"
fi

archive_url="https://codeload.github.com/miyago9267/dotfile/tar.gz/$ref"
printf 'dotfile source: %s (%s)\n' "$REPOSITORY_URL" "$ref"
printf 'install directory: %s\n' "$install_dir"
if [[ "$use_checkout" -eq 1 ]]; then
  printf '%s\n' 'source: existing checkout'
elif [[ "$no_setup" -eq 1 ]]; then
  printf '%s\n' 'setup: skipped'
else
  printf 'setup: %s\n' "${setup_mode:-interactive}"
fi

if [[ "$dry_run" -eq 1 ]]; then
  printf '%s\n' 'dry-run: no files changed'
  exit 0
fi

if [[ "$use_checkout" -eq 0 ]]; then
  case "$(uname -s)" in
    Darwin|Linux) ;;
    *) die 'remote installer supports macOS and Linux/WSL; use setup.bat on Windows' ;;
  esac

  for required_command in bash curl tar; do
    command -v "$required_command" >/dev/null 2>&1 \
      || die "$required_command is required"
  done

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfile-install.XXXXXX")"
  cleanup() {
    if [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]]; then
      rm -rf "$tmp_dir"
    fi
  }
  trap cleanup EXIT

  archive_path="$tmp_dir/dotfile.tar.gz"
  stage_dir="$tmp_dir/source"
  mkdir -p "$stage_dir"
  curl --proto '=https' --tlsv1.2 \
    --fail --silent --show-error --location \
    --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 300 \
    "$archive_url" --output "$archive_path"
  tar -xzf "$archive_path" -C "$stage_dir" --strip-components=1
  [[ -f "$stage_dir/setup.sh" && -d "$stage_dir/config" ]] \
    || die 'downloaded archive does not look like a dotfile source tree'

  parent_dir="$(dirname "$install_dir")"
  mkdir -p "$parent_dir"

  backup_dir=""
  if [[ -e "$install_dir" || -L "$install_dir" ]]; then
    backup_dir="${install_dir}.backup.$(date +%Y%m%d%H%M%S).$$"
    mv "$install_dir" "$backup_dir"
    printf 'backup: %s\n' "$backup_dir"
  fi

  if ! mv "$stage_dir" "$install_dir"; then
    if [[ -n "$backup_dir" && ! -e "$install_dir" && ! -L "$install_dir" ]]; then
      mv "$backup_dir" "$install_dir" || true
    fi
    die "could not place source at $install_dir"
  fi
  source_dir="$install_dir"
fi

printf 'source ready: %s\n' "$source_dir"

if [[ "$no_setup" -eq 0 ]]; then
  export MIYAGO_DOTFILE_ROOT="$source_dir"
  if [[ -z "${MIYAGO_AGENT_WORKSPACE_ROOT:-}" ]]; then
    export MIYAGO_AGENT_WORKSPACE_ROOT="$HOME/Project/AI/agent-workspace"
  fi

  case "$setup_mode" in
    --config-only|--all|--everything)
      bash "$source_dir/setup.sh" "${setup_args[@]}"
      ;;
    *)
      [[ -r /dev/tty ]] || die 'interactive setup needs a terminal; use --config-only, --all, or --no-setup'
      bash "$source_dir/setup.sh" "${setup_args[@]}" < /dev/tty
      ;;
  esac
fi

printf '%s\n' 'dotfile install finished'
