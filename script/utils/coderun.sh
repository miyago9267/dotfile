#!/bin/bash

R='\033[0;31m'
G='\033[0;32m'
NC='\033[0m'

# Parameter parsing
debug_flag=0
gdb_flag=0
source_file=""

while getopts "f:d:s:" opt; do
  case $opt in
    f) debug_flag=1 ;;
    d) gdb_flag=1 ;;
    s) source_file="$OPTARG" ;;
    *) echo "Usage: $0 -s source_file [-f] [-d]"; exit 1 ;;
  esac
done

if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
  printf "${R}Error: File Missing! Check your file path correctly.${NC}\n"
  exit 1
fi

# Workspace Directory
workspace_dir="$HOME/.workspace"
mkdir -p "$workspace_dir"

# Copy file to workspace
cp "$source_file" "$workspace_dir"
cd "$workspace_dir"

if [ "$debug_flag" -eq 1 ]; then
  sed -i '1i#define debug' "$(basename "$source_file")"
  g++ -o solexec --std=c++17 -D DEBUG "$(basename "$source_file")"
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
