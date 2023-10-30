# tvim

## Introduction

A minimal dev environment with tmux + Vim for faster and more efficient coding. Not intended to be a full-fledged IDE, but a simple and easy-to-set-up/maintain solution that can be customized as needed.

## Usage
```
./script.sh [PROJECT/FILE_PATH] [-m MODE] 
```
* `PROJECT/FILE_PATH` can be path of a file or the project folder
* `-m MODE` an optional argument to specify the application to run in the REPL pane.

Examples:

To edit a Python file named "example.py" with a Python interpreter running in the bottom pane, run the command `./tvim.sh example.py -m python` or `./tvim.sh example.py`.

To open a python project at `/home/myproject`, run `./tvim.sh /home/myproject -m py`
