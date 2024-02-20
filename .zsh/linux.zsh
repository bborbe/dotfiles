if [[ "$OSTYPE" == "linux-gnu" || "$OSTYPE" == "linux-gnueabihf" ]]; then

	# Golang
	export GOPATH="$HOME/go"
	export GO=$GOPATH
	export GOROOT=/opt/go
	export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

	export PATH=/snap/bin:$PATH
fi
