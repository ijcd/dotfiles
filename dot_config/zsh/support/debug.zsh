# Debug/profiling utilities for zsh startup
#
# Usage:
#   ZSH_DEBUG=1 zsh          # Enable file timing
#   ZSH_PROFILE=1 zsh        # Enable zprof profiling
#
# Add to each sourced file:
#   debug_file_start
#   ... file contents ...
#   debug_file_end

# Load datetime module for EPOCHREALTIME
zmodload zsh/datetime

# Track start time for total elapsed calculation
: ${_debug_dotfiles_start:=$EPOCHREALTIME}

# Hash to store per-file start times
typeset -gA _debug_file_times

# Array to store completed file stats for summary (file|elapsed|depth)
typeset -ga _debug_file_stats

# Current nesting depth
: ${_debug_depth:=0}

# Print to stderr with optional indentation
_debug_print() {
  local depth=${1:-$_debug_depth}
  shift
  printf "%$((depth * 4))s" "" >&2
  printf "$@" >&2
}

# Call at top of each file
debug_file_start() {
  [[ "$ZSH_DEBUG" == "1" ]] && {
    local caller=${funcfiletrace[1]%:*}
    local resolved=${caller:A}  # Resolve symlinks
    _debug_file_times[$resolved]=$EPOCHREALTIME
    _debug_print $_debug_depth ">>> %s\n" "$resolved"
    (( _debug_depth++ ))
  }
}

# Call at bottom of each file
debug_file_end() {
  [[ "$ZSH_DEBUG" == "1" ]] && {
    local caller=${funcfiletrace[1]%:*}
    local resolved=${caller:A}  # Resolve symlinks
    local start=${_debug_file_times[$resolved]}
    local elapsed=$(( EPOCHREALTIME - start ))
    (( _debug_depth-- ))
    _debug_print $_debug_depth "<<< %s [%.3fs]\n" "$resolved" "$elapsed"
    # Store for summary: file|elapsed|depth
    _debug_file_stats+=("$resolved|$elapsed|$_debug_depth")
  }
}

# Print summary of all file timings
debug_summary() {
  [[ "$ZSH_DEBUG" == "1" ]] && {
    _debug_print 0 "\n"
    _debug_print 0 "=== Startup Timing Summary ===\n"
    local entry file elapsed depth
    for entry in "${_debug_file_stats[@]}"; do
      file=${entry%%|*}
      entry=${entry#*|}
      elapsed=${entry%%|*}
      depth=${entry#*|}
      _debug_print "$depth" "%-50s [%.3fs]\n" "$file" "$elapsed"
    done
    _debug_print 0 "\n"
    _debug_print 0 "Total: %.3fs\n" $(( EPOCHREALTIME - _debug_dotfiles_start ))
  }
}

# Print total elapsed time since shell start
dotfiles_elapsed() {
  printf "%.2f seconds" $(( EPOCHREALTIME - _debug_dotfiles_start ))
}

# zprof-based profiling (function-level summary)
debug_profile_start() {
  [[ "$ZSH_PROFILE" == "1" ]] && zmodload zsh/zprof
}

debug_profile_stop() {
  [[ "$ZSH_PROFILE" == "1" ]] && {
    zprof
    echo "Dotfiles evaluated in $(dotfiles_elapsed)"
  }
}
