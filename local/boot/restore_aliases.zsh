echo Restoring aliases...
unalias -m '*'
eval $save_aliases
unset save_aliases