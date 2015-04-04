# dots: A simple dotfile manager for zsh
# Authors: Ian Duggan
# Homepage: http://github.com/ijcd/dots
# License: MIT License

# A syntax sugar to avoid the `-` when calling dots commands. With this
# function, you can write `dots-import` as `dots import` and so on.
dots () {
    local cmd="$1"
    if [[ -z "$cmd" ]]; then
        echo 'dots: Please give a command to run.' >&2
        return 1
    fi
    shift

    if functions "dots-$cmd" > /dev/null; then
        "dots-$cmd" "$@"
    else
        echo "dots: Unknown command: $cmd" >&2
    fi
}

# module def:   (look at oh-my-zsh and prezto, can we merge/incorporate?)
#   bin/*                   install or symlink?
#   topic/*.zsh             source 
#   fpath                   function autoloads
#   topic/path.zsh          builds path
#   topic/completion.zsh    adds completions (look at prezto/oh-my-zsh)
#   topic/*.symlink         copy in as symlinks
#
#   * ability to partially include (completions, but not aliases, for example)
#   * look at command history on startup to suggest modules to add from list-modules ('suggest' module)
#   * check aliases when commands are run to see if one could have been used ('suggest' module)
function dots-import-local-module () {
    moddir=$1
    
    setopt null_glob
    
    # if a directory wasn't given, assume they meant a DOTFILES module
    if [ ! -d $moddir ] ; then
        moddir=$DOTDIR/modules/$moddir
    fi

    # autoload functions
    [ -d "$moddir/functions" ] && {
        autoload-fpath $moddir/functions
    }

    # add bin dir to path
    [ -d "$moddir/bin" ] && {
        prepend-path $moddir/bin
    }

    # source zsh files
    for file ($moddir/*.zsh) ; do
        [ -f $file ] && source $file
    done
}

# TODO: maybe a smart import that checks for prezto module, and if not found, uses ohmyzsh module
function dots-import-modules () {
    local source
    local my_modules
    local -A cmd
    local aliasfn=""
    
    cmd+=(prezto "antigen bundle sorin-ionescu/prezto modules/")
    cmd+=(ohmyzsh "antigen bundle ")
    cmd+=(local "dots-import-local-module ")
    
    source=$1
    my_modules=("${@[2,-1]}")
    
    for modname ($my_modules) ; do
        case "$modname" in
        with_noalias)
            aliasfn=-dots-with-noalias
            ;;
        with_echoalias)
            aliasfn=-dots-with-echoalias
            ;;
        with_alias)
            aliasfn=""
            ;;
        *)
            torun=$cmd[$source]
            if [ -n "$torun" ] ; then
                eval $aliasfn $torun$modname
            else
                alert_message "Unknown source $source for module $modname"
            fi
            ;;
        esac
    done
}

function dots-unexport-file () {
    grep '^function' $1 | awk '{print $2}' | xargs -n1 unfunction
}

function dots-start-capture () {
    dots__capture__file=$1
    echo "Starting -antigen-load capture into $dots__capture__file"

    # remove prior cache file
    [ -f "$dots__capture__file" ] && rm -f $dots__capture__file
    
    # save current -antigen-load and shim in a version
    # that logs calls to the catpure file
    eval "function -dots-original$(functions -- -antigen-load)"
    function -antigen-load () {
        echo -antigen-load "$@" >>! $dots__capture__file
        -dots-original-antigen-load "$@"
    }
}

function dots-stop-capture () {
    echo "Captured -antigen-load calls into $dots__capture__file"
    
    # unset catpure file var and restore intercepted -antigen-load
    unset dots__capture__file
    eval "function $(functions -- -dots-original-antigen-load | sed 's/-dots-original//')"
}

function dots-check-modules () {
    # report oh-my-zsh modules that could be taken from prezto instead
    antigen list | grep oh-my-zsh | awk '{print $2}' | xargs basename | while read omz_module ; do
        if [ -d $ZPREZTODIR/modules/$omz_module ] ; then
            -dots-alert-message "oh-my-zsh module $omz_module is also in prezto"
        fi
    done
}

dots-help () {
    cat <<EOF
Dots is a plugin/module based dotfile management system for zsh. It uses
antigen, prezto, and oh-my-zsh. It also has a module format for including
zsh modules of symlinks, bin files, functions, etc. See dots-import-local-module
in dots.zsh. Visit the project's page at 'http://github.com/ijcd/dots'.
EOF
}

function -dots-with-noalias () {
    alias alias=false
    echo 'alias alias=false' >>! $dots__capture__file

    eval "$@"

    echo 'unalias alias 2>/dev/null' >>! $dots__capture__file
}

function -dots-with-echoalias () {
    alias alias=echo
    echo 'alias alias=echo' >>! $dots__capture__file
    echo "$@"

    eval "$@"

    echo 'unalias alias 2>/dev/null' >>! $dots__capture__file
}

function -dots-alert-message () {
    echo "***" "$@" "***" 2>&1
}

# Setup antigen's autocompletion
_dots () {
    compadd \
        import-modules \
        import-local-module \
        unexport-file \
        start-capture \
        stop-capture  \
        check-modules \
        help
}
