if [[ "$OSTYPE" == "darwin"* ]]; then
  export DOTFILES=~/Documents/workspaces/dotfiles

	defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

  ssh-add -q --apple-load-keychain

	# Golang
	export GOPATH=$HOME/Documents/workspaces/go
	export GO=$GOPATH
	export GOROOT=/opt/go
	export GODEBUG=gocachelimit=10000
	export GO_TEST_PARALLEL="$(sysctl -n hw.ncpu)"
	if type "launchctl" > /dev/null; then
		#launchctl setenv GOROOT /opt/go
		launchctl setenv GOPATH ~/Documents/workspaces/go
	fi
	export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

	# Rust/Cargo
	export PATH=$HOME/.cargo/bin:$PATH

	# google-cloud-sdk
	export PATH=$PATH:/opt/google-cloud-sdk/bin

	# The next line updates PATH for the Google Cloud SDK.
	if [ -f '/opt/google-cloud-sdk/path.zsh.inc' ]; then . '/opt/google-cloud-sdk/path.zsh.inc'; fi

	# The next line enables shell command completion for gcloud.
	if [ -f '/opt/google-cloud-sdk/completion.zsh.inc' ]; then . '/opt/google-cloud-sdk/completion.zsh.inc'; fi

	# Use python 3.12 for gcloud sdk
	export CLOUDSDK_PYTHON=/opt/local/bin/python3.12

	# Mono
	export PATH=$PATH:/Library/Frameworks/Mono.framework/Versions/Current/bin

	# Update Crontab
	cat ~/.crontab | crontab -

	# Dotnet
	export PATH=$PATH:/usr/local/share/dotnet

	# Flutter
	export PATH=$PATH:$HOME/Documents/workspaces/flutter/bin

	# Phantomjs
	export PATH=$PATH:/opt/phantomjs/bin

	# Chromedriver
	export PATH=$PATH:/opt/chromedriver/bin

	# Postgresql
	export PATH=$PATH:/opt/local/lib/postgresql10/bin

	# Vagrant
	export PATH=$PATH:/Applications/Vagrant/bin

	# Mysql
	export PATH=$PATH:/opt/local/lib/mysql57/bin

	# Java
	if type "/usr/libexec/java_home" > /dev/null; then
		export JAVA_HOME=`/usr/libexec/java_home`
	fi

	# Emacs
	export PATH=$PATH:/Applications/Emacs.app/Contents/MacOS/bin

	# PhantomJS
	export PATH=$PATH:$PATH:/opt/phantomjs-2.1.1-macosx/bin
	export PHANTOMJS_PATH=$PATH:"/opt/phantomjs-2.1.1-macosx/bin/phantomjs"

	# Python
	#export PATH=$(pyenv root)/shims:$PATH
	export PYENV_ROOT="$HOME/.pyenv"
	export PATH="$PYENV_ROOT/bin:$PATH"    # if `pyenv` is not already on PATH
	eval "$(pyenv init --path)"
	eval "$(pyenv init -)"

	# Rancher Desktop
	# export PATH=/Users/bborbe/.rd/bin:$PATH
	# export DOCKER_HOST=unix:///Users/bborbe/.rd/docker.sock
	# zstyle ':completion:*:*:-command-:*:*' ignored-patterns 'kuberlr'

	# Docker Desktop
	export DOCKER_HOST=unix:///Users/bborbe/.docker/run/docker.sock
	# export DOCKER_HOST=tcp://127.0.0.1:1111

	# VS Code
	alias code='open -a /Applications/Visual\ Studio\ Code.app $1'
	alias vscode='open -a /Applications/Visual\ Studio\ Code.app $1'

	# Alias for pssh
	alias parallel-ssh='pssh'

	# Sleep
	alias sleepnow='sudo /usr/bin/pmset sleepnow'

fi
