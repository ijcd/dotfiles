export RBENV_ROOT=/usr/local/var/rbenv

# init according to man page
if (( $+commands[rbenv] ))
then
  eval "$(rbenv init -)"
fi
