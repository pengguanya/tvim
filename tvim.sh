#!/bin/bash

shopt -s extglob

# --- Constants ---
socket=tvim_socket
session=tvim
editor_cmd=nvim
editor_window=Editor
terminal_window=Terminal
edit_pane=0
repl_pane=1

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
  if [ "$extension" = "$filename" ]; then
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

# Run cmd under path. First cd into the path. Then run cmd.
run_cmd_in_path () {
  local path="$1"
  local session="$2"
  local window="$3"
  local cmd="$4"
  local pane="${5-$edit_pane}"
  local apply_on_path="${6-False}"

  if [ -d "$path" ] 
  then
    local cd_cmd="cd $path &&"
  elif [ -f "$path" ] 
  then
    local cd_cmd="cd $(dirname $path) &&"
    if [[ $apply_on_path == "True" ]]; then
      local filename=$(basename "$path")
      cmd="$cmd $filename"
    fi
  fi
  local vim_cmd="$cd_cmd $cmd"

  ($(tmux_cmd "$socket") send-keys -t "${session}:${window}.${pane}" "$vim_cmd" C-m)
}

# Function to define session name based on path
session_name() {
  local path="$1"
  local session_name
  local dirpath
  if [[ -n $path ]] && [[ -d $path ]]; then
    session_name="$(basename "$path" | tr . -)"
  elif [[ -n $path ]] && [[ -f $path ]]; then
    dirpath="$(dirname "$path" | tr . -)"
    session_name="$(basename "$dirpath")"
  else 
    session_name="$(basename "$pwd" | tr . -)"
  fi
  echo "$session_name"
}

# Define function to check if tmux session already exists
session_exists() {
  $(tmux_cmd "$socket") has-session -t "$1" 2>/dev/null
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
echo "$(session_name $path)"
if [[ $session != $(session_name $path) ]]; then
  session="$(session_name $path)"
  echo "New session name $session"
fi

# Check if tvim session already exists
if session_exists "$session"; then
  read -p "tvim session already exists. Do you want to overwrite it? [y/n] " overwrite
  if [[ $overwrite == [Yy]* ]]; then
    $(tmux_cmd "$socket") kill-session -t "tvim"
    $(tmux_cmd "$socket") kill-server # make sure only one session running in socket
  else
    echo "Exiting script."
    exit 0
  fi
else
  echo "Create new session!"
fi

# Decide what application will be used in the bottom pane
if [ -n "$mode" ]; then
  app=$(determine_app "$mode" "mode" '@(r|R)' '@(python|Python|py|PYTHON|PY)' '@(sh|bash|Bash|SH)')
elif [ -n "$file_ext" ]; then
  app=$(determine_app "$file_ext" "file type" '@(r|R)' "py" 'sh')
fi

# Create new tmux session called tvim
if [[ -n $TVIM_TMUX_CONFIG ]]; then
  $(tmux_cmd "$socket") -f "$TVIM_TMUX_CONFIG" new-session -d -s "$session" -n "$editor_window"
else 
  $(tmux_cmd "$socket") new-session -d -s "$session" -n "$editor_window"
fi

# Split window vertically
$(tmux_cmd "$socket") split-window -v -p 10 -t "${session}:${editor_window}"

# Open vim in top pane
run_cmd_in_path "$path" "$session" "$editor_window" "$editor_cmd" "$edit_pane" "True"
#
# Get into right folder in bottom pane based path
run_cmd_in_path "$path" "$session" "$editor_window" "clear" "$repl_pane"

# If app existed, run app in bottom pane in editor window
if [ -n "$app" ]; then
  $(tmux_cmd "$socket") send-keys -t "${session}:${editor_window}.${repl_pane}" "$app" C-m
fi

# Create terminal window
$(tmux_cmd "$socket") new-window -n "${terminal_window}" -t "${session}"

# Get into right folder in terminal window
run_cmd_in_path "$path" "$session" "$terminal_window" "clear"

# Leave the terminal window and select editor window
$(tmux_cmd "$socket") select-window -t "${session}:${editor_window}"

# Attach to tvim session
$(tmux_cmd "$socket") select-pane -t "${session}:${editor_window}.${edit_pane}"
$(tmux_cmd "$socket") attach-session -t "${session}"
