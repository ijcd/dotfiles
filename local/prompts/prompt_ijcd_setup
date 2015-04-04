#
# Custom prompt by ijcd
#
# Authors:
#   Ian Duggan <ian@ianduggan.net>
#
# Features:
#   - Two lines.
#   - Uses a different color smileys depending on if the last command succeeded/failed.
#   - Blank line before prompt.
#   - VCS information in the prompt.
#   - Path shown.
#   - Shows user@hostname if connected through SSH.
#   - Shows if logged in as root or not.
#

# Load dependencies.
pmodload 'helper'

function prompt_ijcd_precmd {
  #%1v is last command from history
  psvar[1]="$history[$[HISTCMD-1]]"

  #%2v is unstaged changes
  # Check for untracked files or updated submodules since vcs_info does not.
  if [[ -n $(git ls-files --other --exclude-standard 2> /dev/null) ]]; then
    psvar[2]="●"
  else
    psvar[2]=""
  fi

  echo psvar2=psvar[2]

  vcs_info 'prompt'
}

function prompt_ijcd_setup {
  setopt localoptions nolocaltraps noksharrays unset
  # typeset -gA _prompt_colors

  # Load required functions.
  autoload -Uz add-zsh-hook
  autoload -Uz vcs_info
  autoload -Uz colors

  # Add hook for calling vcs_info before each command.
  add-zsh-hook precmd prompt_ijcd_precmd

  # Use extended color pallete if available.
  if [[ $TERM = *256color* || $TERM = *rxvt* ]]; then
    _prompt_colors=(
      "%F{81}"  # Turquoise
      "%F{166}" # Orange
      "%F{135}" # Purple
      "%F{161}" # Hotpink
      "%F{118}" # Limegreen
    )
  else
    _prompt_colors=(
      "%F{cyan}"
      "%F{yellow}"
      "%F{magenta}"
      "%F{red}"
      "%F{green}"
    )
  fi

  # setup colors
  local rs happy_color sad_color
  rs="%f%b"
  happy_color="%F{green}"
  sad_color="$fg_bold[red]"

  # Formats:
  #   %b - branchname
  #   %m - In case of Git, show information about stashes
  #   %u - Show unstaged changes in the repository
  #   %c - Show staged changes in the repository
  #   %a - action (e.g. rebase-i)
  #   %R - repository path
  #   %S - path in the repository
  #   %s - current vcs (git, svn, hg)
  #   %r - name of root directory
  local branch_format="${_prompt_colors[1]}%b%f%m%u%c${_prompt_colors[4]}%2v%f%%b"    #%2v is unstaged changes
  local action_format="${_prompt_colors[5]}%a%f"
  local unstaged_format="${_prompt_colors[2]}●%f"
  local staged_format="${_prompt_colors[5]}●%f"

  # Set vcs_info parameters.
  zstyle ':vcs_info:*' enable bzr git hg svn
  zstyle ':vcs_info:*:prompt:*' check-for-changes true
  zstyle ':vcs_info:*:prompt:*' unstagedstr "${unstaged_format}"
  zstyle ':vcs_info:*:prompt:*' stagedstr "${staged_format}"
  zstyle ':vcs_info:*:prompt:*' actionformats "${branch_format}${action_format}"
  zstyle ':vcs_info:*:prompt:*' formats "${branch_format}"
  zstyle ':vcs_info:*:prompt:*' nvcsformats   ""

  # setup prompt segments
  local smiley name host dir tty datetime hist1 caret vcs_message
  smiley="%(?.$happy_color:).$sad_color:()$rs"  # green smiley / red frown (for error code)
  name="%n"
  host="%m"
  dir="%5~"
  tty="%y"
  datetime="%D %*"
  hist1="%1v"                                   #%1v is last command from history
  caret="%(!.$sad_color#.$happy_color%%)"       # green % / red # (for root)
  vcs_message='${vcs_info_msg_0_:+(}${vcs_info_msg_0_}${vcs_info_msg_0_:+) }'

  local -ah prompt
  prompt=(
    "$smiley$rs "
    "%F{yellow}$name$rs"
    "%F{white}@$rs"
    "%F{yellow}$host$rs"
    "%F{white}:$rs"
    "%F{green}$dir$rs "
    "$vcs_message"
    #"%F{yellow}($tty)$rs "
    "%F{white}[$datetime]$rs "
    "%(?.%F{blue}.$sad_color)[$hist1]$rs"       # red on failure
    $'\n'
    "$caret$rs "
  )
  PROMPT="${(j::)prompt}"

  RPROMPT="$vcs_message"
}

prompt_ijcd_setup "$@"
