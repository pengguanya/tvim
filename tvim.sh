#!/bin/bash

# This script will create a new tmux session with two panes horizontally.
# The left pane will open Vim and the right pane will open either
# a Python REPL or an R REPL, depending on the specified mode or file extension.

# Constant and options
editor=nvim # which vim used by shell
sessionName=tvim

# Get file extension from path
function get_extension {
  local path=$1
  # Get the file name from the path
  filename=$(basename "$path")

  # Extract all characters after the last dot in the file name
  echo "${filename##*.}"
}

# Check filetype
function isFileType {
  local file=$1
  local fileType=$2
  if [[ "$(get_extension $file)" == "$fileType" ]]; then
    echo "True"
  else
    echo "False"
  fi
}

# Check if file is python script
function isPython {
  local file=$1
  echo $(isFileType $file "py")
}

# Check if file is R script
function isR {
  local file=$1
  echo $(isFileType $file "R")
}

# Expand relative path to absolute path
function get_absolute_path {
  # resolve path relative to the current directory
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  elif [[ "$path" == "." ]]; then
    echo "$(pwd)"
  elif [[ "$path" == ".." ]]; then
    echo "$(dirname "$(pwd)")"
  else
    echo "$(pwd)/$path"
  fi
}

# Function to echo file full path if input path is valid
function echo_file {
    local path="$1"
    local cmd_sep="$2"
    if [[ $(is_valid_path "$path" ) == "True" ]]; then
        echo "${cmd_sep}$(get_absolute_path $path)"
    fi
}

# Make command based on path
function make_cmd_path {
  local cmd=$1
  local path={$2-"None"}

  if [ "$path" == "None" ]; then
    echo "$cmd ."
  elif [ -d "$path" ] || [ -f "$path" ]; then
    echo "$cmd $(get_absolute_path $path)"
  else
    echo "$cmd" .
  fi
}

# Make command based on mode
function make_cmd_mode {
  local mode="$1"
  local path="$1"
  # Check for the mode/file extension"
  if [ "$mode" == "python" ] || [ "$mode" == "Python" ] || [ "$mode" == ".py" ] || [[ $(isPython "$path") == "True" ]]; then
    echo "python"
  elif [ "$file" == "R" ] || [ "$mode" == ".R" ] || [ "$mode" == ".r" ] || [[ $(isR "$path") == "True" ]]; then
    echo "R"
  elif [ -d "$path" ]; then
    echo "cd $path"
  else
    echo "Error: Invalid argument. Usage: ./tvim.sh <_> or <mode/file_extension>"
    exit 1
  fi
}

# Check for the number of arguments
if [ $# -gt 1 ]; then
  echo "Error: Invalid number of arguments. tvim takes 0 or 1 argument. Usage: ./tvim.sh <_> or <mode/file_extension/filename>"
  exit 1
fi

# Check if tmux session exists
tmux has-session -t "$sessionName"

# If tmux session exists, open the tmux session
if [ $? -eq 0 ]; then
  read -p "Session $sessionName already exists. Do you want to overwrite it? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
      tmux kill-session -t $sessionName
      tmux new-session -s $sessionName -d
  else
      tmux attach -t $sessionName
  fi
else
  # Create a new tmux session
  tmux new-session -s "$sessionName" -d
fi
    
# Split the window into two panes vertically
tmux split-window -v -p 20
    
# Select the top window and open Vim
tmux select-pane -t 0

# If script has no argument, only trigger editor in top pane and do nothing with bottom pane  
if [ $# -eq 0 ]; then
  tmux send-keys "$(make_cmd_path $editor)" C-m
# If script has oee argument, trigger editor based on path in top pane and trigger repl in bottom pane based on the mode.
else
  path_or_mode="$1"

  tmux send-keys "$(make_cmd_path $editor $path_or_mode)" C-m

  # Select the bottom window and open the REPL
  tmux select-pane -t 1

  tmux send-keys "$(make_cmd_mode $path_or_mode)" C-m

  # Go back to the top window
  tmux select-pane -t 0
fi

# Attach the tvim session
tmux attach-session -t "$sessionName"
