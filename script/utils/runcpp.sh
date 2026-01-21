#!/bin/bash
set -e

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
NC='\033[0m'

# Usage function
usage() {
  printf "${Y}Usage: rc <source_file> [options]${NC}\n"
  printf "Options:\n"
  printf "  -f <flag>  Set DEBUG flag\n"
  printf "  -d         Run with gdb debugger\n"
  printf "  -O<level>  Optimization level (0-3, default: 0)\n"
  printf "  -s <std>   C++ standard (11/14/17/20, default: 17)\n"
  exit 1
}

# Check if source file is provided
if [ $# -lt 1 ]; then
  printf "${R}Error: Missing source file!${NC}\n"
  usage
fi

source_file="$1"

# Check if file exists
if [ ! -f "$source_file" ]; then
  printf "${R}Error: File '$source_file' not found!${NC}\n"
  exit 1
fi

# Default parameters
debug_flag=""
gdb_flag=0
opt_level="0"
cpp_std="17"
shift

# Parse options
while getopts "f:dO:s:h" opt; do
  case $opt in
    f) debug_flag="$OPTARG" ;;
    d) gdb_flag=1 ;;
    O) opt_level="$OPTARG" ;;
    s) cpp_std="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Workspace Directory
workspace_dir="$HOME/.workspace/cpp"
mkdir -p "$workspace_dir"

# Copy file to workspace
basename_file="$(basename "$source_file")"
cp "$source_file" "$workspace_dir/"
cd "$workspace_dir"

# Build compile command
compile_flags="-std=c++${cpp_std} -O${opt_level} -Wall -Wextra"

if [ -n "$debug_flag" ]; then
  compile_flags="$compile_flags -D DEBUG=\"$debug_flag\" -g"
  printf "${Y}Debug Mode: Enabled (flag=$debug_flag)${NC}\n"
elif [ "$gdb_flag" -eq 1 ]; then
  compile_flags="$compile_flags -g"
fi

printf "${Y}Compiling: g++ $compile_flags $basename_file${NC}\n"

if g++ -o solexec $compile_flags "$basename_file"; then
  printf "${G}✓ Compilation successful!${NC}\n\n"

  # Run or debug
  if [ "$gdb_flag" -eq 1 ]; then
    printf "${Y}Starting GDB...${NC}\n"
    gdb -q ./solexec
  else
    printf "${Y}Running program...${NC}\n"
    printf "${Y}─────────────────────────────${NC}\n"
    ./solexec
    exit_code=$?
    printf "${Y}─────────────────────────────${NC}\n"
    printf "${Y}Program exited with code: $exit_code${NC}\n"
  fi

  # Cleanup
  rm -f "$basename_file" solexec
else
  printf "${R}✗ Compilation failed!${NC}\n"
  rm -f "$basename_file"
  exit 1
fi
