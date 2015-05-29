source /usr/local/share/zsh/site-functions/_aws

function read_aws_credentials_key {
  section=$1
  key=$2
  awk -F ' *= *' '{ if ($1 ~ /^\[/) section=$1; else if ($1 !~ /^$/) print $1 section "=" $2 }' ~/.aws/credentials | grep "$2\[$1\]" | sed 's/.*=//'
}

function enable_aws {
  export AWS_ACCESS_KEY=$(read_aws_credentials_key default aws_access_key_id)
  export AWS_SECRET_KEY=$(read_aws_credentials_key default aws_secret_access_key)
  export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
  export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
}

enable_aws
