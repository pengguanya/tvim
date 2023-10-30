#!/bin/bash

shopt -s extglob

# --- Constants ---
socket=default   # tvim_socket
session=tvim
editor_cmd=nvim
editor_window=Editor
terminal_window=Terminal
edit_pane=0
repl_pane=1
#project_dir=''

# -- Functions ---
# tmux command conditioned on socket
tmux_cmd() {
  local socket="$1"
  if [ -n "$socket" ]; then
    echo tmux -L "$socket"
  else
    echo tmux
  fi
}

# Get file extension
get_file_extension() {
  filename=$1
  extension="${filename##*.}"
  if [ ! -f "$filename" ] || [ "$extension" = "$filename" ]; then
    extension=""
  fi
  echo "$extension"
}

# Determine application
determine_app() {
  local value="$1"
  local type="$2"
  local r_condition="$3"
  local py_condition="$4"
  local sh_condition="$5"
  local app=""
  case "$value" in
    ${r_condition})
        app=R
        ;;
    ${py_condition})
        app=python
        ;;
    ${sh_condition})
        :
        ;;
    *)
    echo "Error: $type $value is not support yet."
    exit 1
    ;;
  esac
  echo "$app"
}

# Run cmd in tmux session
run_cmd_in_tmux () {
  local session="$1"
  local window="$2"
  local cmd="$3"
  local pane="${4-$edit_pane}"

  ($(tmux_cmd "$socket") send-keys -t "${session}:${window}.${pane}" "$cmd" C-m)
}

# Extracts dirname from path, sanitizes for tmux session name.
sanitize() {
  local input="$1"
  sanitized=$(echo "$input" | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+|-+$//g')
  echo "$sanitized"
}

# Function to define session name based on path
session_name() {
  local path="$1"
  local session_name=""
  
  if [[ -d "$path" ]]; then
    dir_name=$(basename "$path")
    session_name=$(sanitize "$dir_name")
  elif [[ -f "$path" ]]; then
    filename=$(basename "$path")
    filename_no_ext=$(echo "$filename" | sed -E 's/(.+)\..+/\1/')
    session_name=$(sanitize "$filename_no_ext")
  else
    session_name=$(basename "$PWD")
  fi
  
  echo "$session_name"
}

# Define function to check if tmux session already exists
session_exists() {
  $(tmux_cmd "$socket") has-session -t "$1" 2>/dev/null
}

openfile () {
  local cmd="$1"
  local filename="$2"
  echo "$cmd $filename"
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
if [[ $session != $(session_name $path) ]]; then
  session="$(session_name $path)"
fi

# Check if tvim session already exists
if session_exists "$session"; then
  read -p "[${session}] session already exists. Do you want to overwrite it? [y/n]. Quit [Enter] " overwrite
  if [[ $overwrite == [Yy]* ]]; then
    $(tmux_cmd "$socket") kill-session -t "$session"
    # $(tmux_cmd "$socket") kill-server # make sure only one session running in socket
  elif [[ $overwrite == [Nn]* ]]; then
    $(tmux_cmd "$socket") attach-session -t "${session}"
    exit 0
  else
    echo "Exiting script."
    exit 0
  fi
else
  echo "Create new session [${session}]!"
fi

# Decide what application will be used in the bottom pane
if [ -n "$mode" ]; then
  app=$(determine_app "$mode" "mode" '@(r|R)' '@(python|Python|py|PYTHON|PY)' '@(sh|bash|Bash|SH)')
elif [ -n "$file_ext" ]; then
  app=$(determine_app "$file_ext" "file type" '@(r|R)' "py" 'sh')
fi

# Determine project dir
if [ -z "$path" ]; then
  fullpath="$PWD"
elif [ -d "$path" ]; then
  fullpath="$(realpath "${path%/}")"
elif [ -f "$path" ]; then
  fullpath="$(realpath "$(dirname "$path")")"
  filename="$(basename "$path")"
fi

# Create new tmux session
if [[ -n $TVIM_TMUX_CONFIG ]]; then
  $(tmux_cmd "$socket") -f "$TVIM_TMUX_CONFIG" new-session -c "$fullpath" -d -s "$session" -n "$editor_window"
else 
  $(tmux_cmd "$socket") new-session -c "$fullpath" -d -s "$session" -n "$editor_window"
fi


# Split window vertically
$(tmux_cmd "$socket") split-window -c "$fullpath" -v -p 10 -t "${session}:${editor_window}"

# Open vim in top pane
run_cmd_in_tmux "$session" "$editor_window" "$(openfile "$editor_cmd" "$filename")"

# Get into right folder in bottom pane based path

# If app existed, run app in bottom pane in editor window
if [ -n "$app" ]; then
  run_cmd_in_tmux "$session" "$editor_window" "clear"  "$repl_pane"
  run_cmd_in_tmux "$session" "$editor_window" "$app"  "$repl_pane"
fi

# Create terminal window
$(tmux_cmd "$socket") new-window -c "$fullpath" -n "${terminal_window}" -t "${session}"

# Leave the terminal window and select editor window
$(tmux_cmd "$socket") select-window -t "${session}:${editor_window}"

# Attach to tvim session
$(tmux_cmd "$socket") select-pane -t "${session}:${editor_window}.${edit_pane}"
$(tmux_cmd "$socket") attach-session -t "${session}"
