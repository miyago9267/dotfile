#!/bin/bash

R='\033[0;31m'
G='\033[0;32m'
NC='\033[0m'

# Check if source file is provided as the first argument
if [ $# -lt 1 ]; then
  printf "${R}Error: Missing source file! Usage: rc <source_file> [-f debug_flag] [-d]${NC}\n"
  exit 1
fi

# Check if the provided file exists
if [ -z "$1" ] || [ ! -f "$1" ]; then
  printf "${R}Error: File Missing! Check your file path correctly.${NC}\n"
  exit 1
fi

# Parameter parsing
debug_flag=0
gdb_flag=0
source_file="$1"
shift

while getopts "f:d:" opt; do
  case $opt in
    f) debug_flag="$OPTARG" ;;
    d) gdb_flag=1 ;;
    *) echo "Usage: $0 -s source_file [-f] [-d]"; exit 1 ;;
  esac
done

# Workspace Directory
workspace_dir="$HOME/.workspace"
mkdir -p "$workspace_dir"

# Copy file to workspace
cp "$source_file" "$workspace_dir"
cd "$workspace_dir"

if [ -n "$debug_flag" ]; then
  printf "${G}Debug Mode: Enabled with flag $debug_flag${NC}\n"
  g++ -o solexec --std=c++17 -D DEBUG=\"$debug_flag\" "$(basename "$source_file")"
else
  g++ -o solexec --std=c++17 "$(basename "$source_file")"
fi

if [ $? -eq 0 ]; then
  printf "${G}Success: Compile Successfully!${NC}\n"

  # Checking gdb mode
  if [ "$gdb_flag" -eq 1 ]; then
    gdb ./solexec
  else
    ./solexec
  fi

  # Remove redundant files
  rm -f "$(basename "$source_file")" solexec
else
  printf "${R}Erorr: Compile Failed!${NC}\n"
fi

exit 0
