hash boot2docker && {
	if [ "$(boot2docker status)" = "running" ] ; then
	    $(boot2docker shellinit)
	fi
}
