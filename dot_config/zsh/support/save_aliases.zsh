# https://unix.stackexchange.com/questions/161973/clear-or-disable-aliases-in-zsh
# Save aliases before running modules so we can remove any created in modules

_saved_aliases=$(alias -L)
