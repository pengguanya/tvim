#!/bin/bash

# This script will create a new tmux session with two panes horizontally.
# The left pane will open Vim and the right pane will open either
# a Python REPL or an R REPL, depending on the specified mode or file extension.

# Constant and options
vi=nvim # which vim used by shell
sessionName=tvim

# function to check filetype
function isFileType {
  local file=$1
  local fileType=$2
  if [[ ${file##*.} == ${fileType} ]]; then
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

# Check if the argument is a valid file path with extention
function is_valid_path {
  local path="$1"
  if [[ "$path" =~ ^(.+\/)*[^/]+\.[^/]+$ ]]; then
    echo "True"
  else
    echo "False"
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
tmux send-keys "$vi" "$(echo_file $1 ' ')" C-m

if [ $# -eq 1 ]; then
    file="$1"

    # Select the bottom window and open the REPL
    tmux select-pane -t 1
    
    # Check for the mode/file extension"
    if [ "$file" == "python" ] || [ "$file" == ".py" ] || [[ $(isPython "$file") == "True" ]]; then
        tmux send-keys "python" C-m
    elif [ "$file" == "R" ] || [ "$file" == ".R" ] || [[ $(isR "$file") == "True" ]]; then
        tmux send-keys "R" C-m
    else
        echo "Error: Invalid argument. Usage: ./tvim.sh <_> or <mode/file_extension>"
        exit 1

    fi
    # Go back to the top window
    tmux select-pane -t 0
fi

# Attach the tvim session
tmux attach-session -t "$sessionName"
