#!/bin/bash

shopt -s extglob

# --- Constants ---
session=tvim
editor_cmd=nvim
editor_window=Editor
terminal_window=Terminal
top_pane=0
bottom_pane=1

# -- Functions ---
# Get file extension
get_file_extension() {
  filename=$1
  extension="${filename##*.}"
  if [ "$extension" = "$filename" ]; then
    extension=""
  fi
  echo "$extension"
}

# Determine application
determine_app() {
  local value="$1"
  local r_condition="$2"
  local py_condition="$3"
  local type="$4"
  local app=""
  case "$value" in
    ${r_condition})
        app=R
        ;;
    ${py_condition})
        app=python
        ;;
    *)
    echo "Error: $type $value is not support yet."
    exit 1
    ;;
  esac
  echo "$app"
}

# Run cmd under path. First cd into the path. Then run cmd.
run_cmd_in_path () {
  local path="$1"
  local session="$2"
  local window="$3"
  local cmd="$4"
  local pane="${5-$top_pane}"
  local apply_on_path="${6-False}"

  if [ -d "$path" ] 
  then
    (tmux send-keys -t "${session}:${window}.${pane}" "cd $path" C-m)
    (tmux send-keys -t "${session}:${window}.${pane}" "$cmd" C-m)
  elif [ -f "$path" ] 
  then
    (tmux send-keys -t "${session}:${window}.${pane}" "cd $(dirname $path)" C-m)
    if [[ $apply_on_path == "True" ]]; then
      (tmux send-keys -t "${session}:${window}.${pane}" "$cmd $path" C-m)
    else
      (tmux send-keys -t "${session}:${window}.${pane}" "$cmd" C-m)
    fi
  else
    (tmux send-keys -t "${session}:${window}.${pane}" "$cmd" C-m)
  fi
}

# Define function to check if tmux session already exists
session_exists() {
  tmux has-session -t "$1" 2>/dev/null
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
tmux new-session -d -s "$session" -n "$editor_window"

# Split window vertically
tmux split-window -v -p 10 -t "${session}:${editor_window}"

# Open vim in top pane
run_cmd_in_path "$path" "$session" "$editor_window" "$editor_cmd" "$top_pane" "True"

# Get into right folder in bottom pane based path
run_cmd_in_path "$path" "$session" "$editor_window" "clear" "$bottom_pane"


# If app existed, run app in bottom pane in editor window
if [ -n "$app" ]; then
  tmux send-keys -t "${session}:${editor_window}.${bottom_pane}" "$app" C-m
fi

# Create terminal window
tmux new-window -n "${terminal_window}" -t "${session}"

# Get into right folder in terminal window
run_cmd_in_path "$path" "$session" "$terminal_window" "clear"

# Leave the terminal window and select editor window
tmux select-window -t "${session}:${editor_window}"

# Attach to tvim session
tmux select-pane -t "${session}:${editor_window}.${top_pane}"
tmux attach-session -t "${session}"
