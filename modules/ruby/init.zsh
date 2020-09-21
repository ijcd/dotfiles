if [[ -s "$HOME/.rvm/scripts/rvm" ]]
then
  echo "Setting up RVM"
  source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
fi

alias rwatch="watchman-make -p '**/*.rb' -s 1 --make 'bash -e' -t"