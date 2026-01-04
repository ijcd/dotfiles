###########################################
#  ZSH Options
#  (Zim's environment module handles the basics;
#   these are personal preferences beyond that)
###########################################

# History
HISTFILE=$HOME/.zsh_history
HISTSIZE=20000
SAVEHIST=10000
setopt HIST_REDUCE_BLANKS       # Remove superfluous blanks from history

# Directory navigation
setopt PUSHD_MINUS              # Swap +/- meanings for directory stack

# Globbing
setopt GLOB_COMPLETE            # Expand globs upon completion
setopt NO_CASE_GLOB             # Case-insensitive globbing
setopt NUMERIC_GLOB_SORT        # Sort numerically (file1, file2, file10)
setopt RC_EXPAND_PARAM          # Array expansion: foo${arr}bar expands correctly

# I/O
setopt MULTIOS                  # Allow multiple redirections (echo foo > a > b)
setopt NO_FLOW_CONTROL          # Disable Ctrl-S/Ctrl-Q flow control

# Safety
setopt IGNORE_EOF               # Don't exit on Ctrl-D (require 'exit')

# Performance reporting
REPORTTIME=2                    # Show time for commands taking >2 seconds
