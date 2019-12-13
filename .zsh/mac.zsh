if [[ "$OSTYPE" == "darwin"* ]]; then
	defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

	# Golang
	export GOPATH=$HOME/Documents/workspaces/go
	export GO=$GOPATH
	#export GOROOT=/opt/go
	if type "launchctl" > /dev/null; then
		#launchctl setenv GOROOT /opt/go
		launchctl setenv GOPATH ~/Documents/workspaces/go
	fi
	export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

	# google-cloud-sdk
	export PATH=$PATH:/opt/google-cloud-sdk/bin

	# The next line updates PATH for the Google Cloud SDK.
	if [ -f '/opt/google-cloud-sdk/path.zsh.inc' ]; then . '/opt/google-cloud-sdk/path.zsh.inc'; fi

	# The next line enables shell command completion for gcloud.
	if [ -f '/opt/google-cloud-sdk/completion.zsh.inc' ]; then . '/opt/google-cloud-sdk/completion.zsh.inc'; fi

	# Docker
	export PATH=/Applications/Docker.app/Contents/Resources/bin:$PATH:

	# Mono
	export PATH=$PATH:/Library/Frameworks/Mono.framework/Versions/Current/bin

	# Update Crontab
	cat ~/.crontab | crontab -

	# Vim
	alias vim='open -a /Applications/MacPorts/MacVim.app $1'

	# VS Code
	alias vscode='open -a /Applications/Visual\ Studio\ Code.app $1'

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

fi
