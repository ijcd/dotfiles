# Use Git’s colored diff when available
hash git &>/dev/null
if [ $? -eq 0 ]; then
	function diff() {
		git diff --no-index --color-words "$@"
	}
fi
