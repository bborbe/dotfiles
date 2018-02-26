if [[ "$OSTYPE" == "darwin"* ]]; then
	defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

	# Vim
	alias vim='open -a /Applications/MacPorts/MacVim.app $1'

	# VS Code
	alias vscode='open -a /Applications/Visual\ Studio\ Code.app $1'

	# Docker
	export PATH=/Applications/Docker.app/Contents/Resources/bin:$PATH

	# Phantomjs
	export PATH=/opt/phantomjs/bin:$PATH

	# Chromedriver
	export PATH=/opt/chromedriver/bin:$PATH

	# Nsq
	export PATH=/opt/nsq/bin:$PATH

	# Postgresql
	export PATH=/opt/local/lib/postgresql10/bin:$PATH

	# Vagrant
	export PATH=/Applications/Vagrant/bin:$PATH

	# Mysql
	export PATH=/opt/local/lib/mysql57/bin:$PATH

	# Java
	if type "/usr/libexec/java_home" > /dev/null; then
			export JAVA_HOME=`/usr/libexec/java_home`
	fi

	# Emacs
	export PATH=/Applications/Emacs.app/Contents/MacOS/bin:$PATH
fi
