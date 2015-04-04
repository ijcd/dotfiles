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

ZDOTCACHE=~/.zdotcache
# rm -f ~/.zdotcache

# fire up antigen 
source $DOTDIR/antigen/antigen.zsh clone/antigen.zsh

if [ -f $ZDOTCACHE ] ; then
    source $ZDOTCACHE
else
    dots-start-capture $ZDOTCACHE

    antigen bundle sorin-ionescu/prezto modules/environment
    antigen bundle sorin-ionescu/prezto modules/colored-manterminal
    antigen bundle sorin-ionescu/prezto modules/colored-maneditor
    antigen bundle colored-man
    antigen bundle debian
    antigen bundle extract

    dots-stop-capture
fi
