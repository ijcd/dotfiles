hash boot2docker 2>/dev/null && {
	if boot2docker status 2>&/dev/null && [ "$(boot2docker status)" = "running" ] ; then
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

dspec() {
	  spec=$1 ; shift
	  id=$(docker ps -aqf "name=$spec")
		echo ${id:-$spec}
}

dbash() {
	  spec=$1 ; shift
		docker exec -it $(dspec $spec) bash;
}

dexec() {
	  spec=$1 ; shift
	  docker exec -it $(dspec $spec) "$@";
}

docker_ips() {
    docker ps -q | xargs -n 1 docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Name }} {{ .ID }}'
}

docker_ip() {
		spec=$1 ; shift
		id=$(dspec $spec)
	  docker_ips | awk "/$id/ {print \$1}"
}
