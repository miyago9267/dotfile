#!/bin/bash

# Check file path exist
if [ -z "$1" ] || [ ! -f "$1" ]; then
  echo "\033[0;31mError: File Missing! Check your file path correctly.\033[0m"
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
  g++ -o solexec -D DEBUG "$(basename "$1")"
else
  g++ -o solexec "$(basename "$1")"
fi

if [ $? -eq 0 ]; then
  echo "\033[0;32mSuccess: Compile Successfully!\033[0m"

  # Checking gdb mode
  if [ "$2" == "-d" ] || [ "$3" == "-d" ]; then
    gdb ./solexec
  else
    ./solexec
  fi

  # Remove redundant files
  rm -f "$(basename "$1")" solexec
else
  echo "\033[0;31mErorr: Compile Failed!\033[0m"
fi

exit 0
