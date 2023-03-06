#!/bin/bash

# Set default value for -m option
# mode="bash"

get_file_extension() {
    filename=$1
    extension="${filename##*.}"
    if [ "$extension" = "$filename" ]; then
        extension=""
    fi
    echo "$extension"
}

# Parse command line arguments
while getopts ":m:" opt; do
  case $opt in
    m)
      mode="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Get positional argument
shift $((OPTIND -1))
path="$1"
file_ext="$(get_file_extension $path)"

if [ -n "$mode" ]; then
  case "$mode" in
    r|R)
      app=R
      ;;
    python|Python|py)
      app=python
      ;;
    *)
      echo "Error: mode $mode is not support yet."
      exit 1
      ;;
  esac
elif [ -n "$file_ext" ]; then
  case "$file_ext" in
    r|R)
      # Open R file
      app=R
      ;;
    py)
      # Open Python file
      app=python
      ;;
    *)
      echo "Error: file type $file_ext is not support yet."
      exit 1
      # Do nothing
      ;;
  esac
fi

# Define function to check if tmux session already exists
session_exists() {
  tmux has-session -t "$1" 2>/dev/null
}

# Check if tvim session already exists
if session_exists "tvim"; then
  read -p "tvim session already exists. Do you want to overwrite it? [y/n] " overwrite
  if [[ $overwrite == [Yy]* ]]; then
    tmux kill-session -t "tvim"
  else
    echo "Exiting script."
    exit 0
  fi
fi

# Create new tmux session called tvim
tmux new-session -d -s "tvim"

# Split window vertically
tmux split-window -v -t "tvim:0"

# Open vim in top pane
if [ -d "$path" ]
then
  tmux send-keys -t "tvim:0.0" "cd $path" C-m
  tmux send-keys -t "tvim:0.0" "nvim" C-m
elif [ -f "$path" ]
then
  tmux send-keys -t "tvim:0.0" "nvim $path" C-m
else
  tmux send-keys -t "tvim:0.0" "nvim" C-m
fi

# Get into right folder in bottom pane based path
if [ -d "$path" ] 
then
  tmux send-keys -t "tvim:0.1" "cd $path" C-m
elif [ -f "$path" ] 
then
  tmux send-keys -t "tvim:0.1" "cd $(dirname $path)" C-m
fi

tmux send-keys -t "tvim:0.1" "$app" C-m
# Determine what to open in bottom pane based on mode and/or file type
# if [[ $mode == "bash" ]]; then
# else
#   file_ext="${path##*.}"
#   case $file_ext in
#     py)
#       tmux send-keys -t "tvim:0.1" "python" C-m
#       ;;
#     r)
#       tmux send-keys -t "tvim:0.1" "R" C-m
#       ;;
#     *)
#       tmux send-keys -t "tvim:0.1" "$mode" C-m
#       ;;
#   esac
# fi

# Attach to tvim session
tmux select-pane -t "tvim:0.0"
tmux attach-session -t "tvim"

