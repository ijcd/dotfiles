# Restore aliases saved before module loading
# This removes any aliases added by frameworks/modules

unalias -m '*'
eval $_saved_aliases
unset _saved_aliases
