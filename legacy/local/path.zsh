# # PATH
# for dir in \
#     $HOME/bin \
#     $HOME/.mix \
#     $HOME/go/bin \
#     $HOME/.local/bin \
#     $HOME/.cargo/bin \
#     $HOME/.cabal/bin \
#     $HOME/Library/Haskell/bin \
#     $(command -v yarn && yarn global bin) \
#     $HOME/miniconda3/bin \
#     /opt/local/bin \
#     /opt/local/sbin \
# ; do
# 	if [[ -d $dir ]]; then
# 	    punshift $dir PATH
# 	fi
# done

# # MANPATH
# for dir in \
#     /usr/share/man \
#     /usr/local/share/man \
#     /usr/X11/share/man \
#     /usr/local/man \
# ; do
# 	if [[ -d $dir ]]; then
# 		punshift $dir MANPATH
# 	fi
# done

# # condense PATH entries
# PATH=$(puniq $PATH)
# MANPATH=$(puniq $MANPATH)