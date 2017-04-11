hash boot2docker 2>/dev/null && {
	if [ "$(boot2docker status)" = "running" ] ; then
	    $(boot2docker shellinit)
	fi
}

hash docker-machine 2>/dev/null && {
	if [ "$(docker-machine status default)" = "Running" ] ; then
		eval "$(docker-machine env default)"
	fi
}

alias ddm=docker-machine
alias ddc=docker-compose

dbash() { docker exec -it $(docker ps -aqf "name=$1") bash; }
dexec() { docker exec -it $(docker ps -aqf "name=$1") "$2"; }
dips() { docker ps -q | xargs -n 1 docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Name }}' }
