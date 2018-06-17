. /Users/iduggan/.opam/opam-init/init.zsh > /dev/null 2> /dev/null || true

# converts ocaml code into reason
alias mlre="pbpaste | refmt --parse ml --print re --interface false | pbcopy"
# # converts reason code into ocaml
alias reml="pbpaste | refmt --parse re --print ml --interface false | pbcopy"
