if [[ "$OSTYPE" == "linux-gnu" ]]; then

	# Golang
	export GOPATH="$HOME/go"
	export GO=$GOPATH
	export GOROOT=/opt/go
	export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
fi
