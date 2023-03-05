#!/bin/bash

# This script will create a new tmux session with two panes horizontally.
# The left pane will open Vim and the right pane will open either
# a Python REPL or an R REPL, depending on the specified mode or file extension.

# which vim used by shell
vi=nvim
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

# function to check if file is python
function isPython {
  local file=$1
  echo $(isFileType $file "py")
}

# function to check if file is R
function isR {
  local file=$1
  echo $(isFileType $file "R")
}

function is_filename {
    if [[ "$1" =~ ^[^\.]+\.[^\.]+$ ]]; then
      echo "True"
    else
      echo "False"
    fi
}

function echo_file {
    if [[ $(is_filename $1) == "True" ]]; then
        echo $1
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
tmux send-keys "$vi" C-m

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
