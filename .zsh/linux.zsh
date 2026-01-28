if [[ "$OSTYPE" == "linux-gnu" || "$OSTYPE" == "linux-gnueabihf" ]]; then

  # Auto-start ssh-agent
  if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
  fi

  # Golang
  export GOPATH="$HOME/go"
  export GO=$GOPATH
  export GOROOT=/opt/go
  export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

  export PATH=/snap/bin:$PATH
fi
