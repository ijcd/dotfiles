ztrace_with_debug () {
    echo "====================================================================="
    echo zgen "$@"

    declare -A binds
    declare -A new_binds

    # collect initial binds into associative array
    for map in $(bindkey -l) ; do
        binds[$map]=$(bindkey -M $map)
    done

    zgen "$@"

    # collect finished binds into associative array
    for map in $(bindkey -l) ; do
        new_binds[$map]=$(bindkey -M $map)
    done

    for map in $(bindkey -l) ; do
        if ! diff -q <(echo $binds[$map]) <(echo $new_binds[$map]) >/dev/null
        then
            echo "---------------------------------------"
            echo KEYMAP=$map
            the_diff=$(diff -ud <(echo $binds) <(echo $new_binds))
            echo $the_diff | grep -E '^(\+|-|\!)"'
        fi
    done
}

ztrace_without_debug() {
    zgen "$@";
}

what_binds () {
    for map in $(bindkey -l) ; do
        if [ -n $1 ]
        then
            echo KEYMAP $map $1
        fi
        bindkey -M $map
    done
}

# TODO: finish defining this and put this somewhere
if [[ -n $ZGEN_DEBUG_BINDS ]]; then
    # define ztrace with diffing
else
    ztrace() { zgen "$@"; }
fi
