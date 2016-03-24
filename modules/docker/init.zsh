hash boot2docker && {
	if [ "$(boot2docker status)" = "running" ] ; then
	    $(boot2docker shellinit)
	fi
}

hash docker-machine && {
	if [ "$(docker-machine status dev)" = "Running" ] ; then
 		eval "$(docker-machine env dev)"
	fi
}

alias ddm=docker-machine
alias ddc=docker-compose