test -r ~/.opam/opam-init/init.zsh && . /Users/ijcd/.opam/opam-init/init.zsh > /dev/null 2> /dev/null || true

# converts ocaml code into reason
alias mlre="pbpaste | refmt --parse ml --print re --interface false | pbcopy"
