if [[ "$OSTYPE" == "linux-gnu" || "$OSTYPE" == "linux-gnueabihf" ]]; then

  # SSH key management with keychain (or fallback to ssh-agent)
  if type "keychain" > /dev/null 2>&1; then
    eval $(keychain --eval --agents ssh --quiet id_ed25519_personal)
  else
    # Fallback to ssh-agent if keychain not installed
    if [ -z "$SSH_AUTH_SOCK" ]; then
      eval "$(ssh-agent -s)" > /dev/null
    fi
  fi

  # GPG TTY for commit signing
  export GPG_TTY=$(tty)

  # Golang
  export GOPATH="$HOME/go"
  export GO=$GOPATH
  export GOROOT=/opt/go
  export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

  export PATH=/snap/bin:$PATH
fi
