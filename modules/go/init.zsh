#export GOPATH=~/.go
#export PATH=$GOPATH/bin:$PATH

# [[ -s ~/.gvm/scripts/gvm ]] && source ~/.gvm/scripts/gvm

#gvm use go1.4
#gvm pkgset use dev

alias -g gopath0='$(echo $GOPATH | sed "s/:.*//")'
alias gogo="[[ -s ~/.gvm/scripts/gvm ]] && source ~/.gvm/scripts/gvm ; gvm use go1.4 ; gvm pkgset use dev"
