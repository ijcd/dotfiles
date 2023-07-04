[ -d $HOME/.asdf ] && {
  source $HOME/.asdf/asdf.sh
  source $HOME/.asdf/completions/asdf.bash
}

[ -d /usr/local/opt/asdf ] && {
  source /usr/local/opt/asdf/asdf.sh
  source /usr/local/opt/asdf/etc/bash_completion.d/asdf.bash
}

[ -f /usr/local/opt/asdf/libexec/asdf.sh ] && {
  source /usr/local/opt/asdf/libexec/asdf.sh
}
