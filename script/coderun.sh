#!/bin/bash

R='\033[0;31m'
G='\033[0;32m'
NC='\033[0m'

# Check file path exist
if [ -z "$1" ] || [ ! -f "$1" ]; then
  printf "${R}Error: File Missing! Check your file path correctly.${NC}\n"
  exit 1
fi

# Workspace Directory
workspace_dir="$HOME/.workspace"
mkdir -p "$workspace_dir"

# Copy file to workspace
cp "$1" "$workspace_dir"
cd "$workspace_dir"

# Checking debug mode
if [ "$2" == "-f" ]; then
  sed -i '1i#define debug' "$(basename "$1")"
fi


if [ "$2" == "-f" ] || [ "$3" == "-f" ]; then
  g++ -o solexec --std=c++17 -D DEBUG "$(basename "$1")"
else
  g++ -o solexec --std=c++17 "$(basename "$1")"
fi

if [ $? -eq 0 ]; then
  printf "${G}Success: Compile Successfully!${NC}\n"

  # Checking gdb mode
  if [ "$2" == "-d" ] || [ "$3" == "-d" ]; then
    gdb ./solexec
  else
    ./solexec
  fi

  # Remove redundant files
  rm -f "$(basename "$1")" solexec
else
  printf "${R}Erorr: Compile Failed!${NC}\n"
fi

exit 0
