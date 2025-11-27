#https://unix.stackexchange.com/questions/161973/clear-or-disable-aliases-in-zsh
echo Saving aliases...

# save aliases before running modules so we can remove any created in modules
save_aliases=$(alias -L)
