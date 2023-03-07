#!/bin/bash

shopt -s extglob

# Set default value for -m option
# mode="bash"

editor=nvim
session=tvim
window=editor

# Get file extension
get_file_extension() {
  filename=$1
  extension="${filename##*.}"
  if [ "$extension" = "$filename" ]; then
    extension=""
  fi
  echo "$extension"
}

# Remove quotation marks from string
function remove_quotes() {
  local unquoted="${1//\"/}"  # remove double quotes
  echo "$unquoted"
}

# Determine application
determine_app() {
  local value="$1"
  local r_condition="$2"
  local py_condition="$3"
  local type="$4"
  local app=""
  case "$value" in
    $(remove_quotes "$r_condition"))
        app=R
        ;;
    $(remove_quotes "$py_condition"))
        app=python
        ;;
    *)
    echo "Error: $type $value is not support yet."
    exit 1
    ;;
  esac
  echo "$app"
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
else
  echo "Create new session!"
fi

# Decide what application will be used in the bottom pane
if [ -n "$mode" ]; then
  app=$(determine_app "$mode" '@(r|R)' '@(python|Python|py|PYTHON|PY)' "mode")
elif [ -n "$file_ext" ]; then
  app=$(determine_app "$file_ext" '@(r|R)' "py" "file type")
fi

# Create new tmux session called tvim
tmux new-session -d -s "$session" -n "$window"

# Split window vertically
tmux split-window -v -p 20 -t "${session}:${window}"

# Open vim in top pane
if [ -d "$path" ]; then
  tmux send-keys -t "${session}:${window}.0" "cd $path" C-m
  tmux send-keys -t "${session}:${window}.0" "$editor" C-m
elif [ -f "$path" ]; then
  tmux send-keys -t "${session}:${window}.0" "cd $(dirname $path)" C-m
  tmux send-keys -t "${session}:${window}.0" "$editor $path" C-m
else
  tmux send-keys -t "${session}:${window}.0" "$editor" C-m
fi

# Get into right folder in bottom pane based path
if [ -d "$path" ] 
then
  tmux send-keys -t "${session}:${window}.1" "cd $path" C-m
  tmux send-keys -t "${session}:${window}.1" "clear" C-m
elif [ -f "$path" ] 
then
  tmux send-keys -t "${session}:${window}.1" "cd $(dirname $path)" C-m
  tmux send-keys -t "${session}:${window}.1" "clear" C-m
fi

if [ -n "$app" ]; then
  tmux send-keys -t "${session}:${window}.1" "$app" C-m
fi
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
tmux select-pane -t "${session}:${window}.0"
tmux attach-session -t "${session}"
