# install oh-my-zsh if not exists
if [ ! -d $HOME/.oh-my-zsh ]; then
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable bi-weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment to change how often before auto-updates occur? (in days)
# export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want to disable command autocorrection
# DISABLE_CORRECTION="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Uncomment following line if you want to disable marking untracked files under
# VCS as dirty. This makes repository status check for large repositories much,
# much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git)

source $ZSH/oh-my-zsh.sh
source ~/.zsh/colors.zsh

export PAGER=more
export BLOCKSIZE=K
export HISTSIZE=50000
export PATH=/opt/local/libexec/gnubin:/opt/local/sbin:/opt/local/bin:/opt/local/apache2/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin
export LC_ALL=en_US.UTF-8

# Emacs
export ALTERNATE_EDITOR=""
#export EDITOR="emacsclient -t"                  # $EDITOR should open in terminal
#export VISUAL="emacsclient -c -a emacs"         # $VISUAL opens in GUI with non-daemon as alternate
export EDITOR="ec"         # $EDITOR should open in terminal
export VISUAL="ec"         # $VISUAL opens in GUI with non-daemon as alternate

export PATH=/Applications/Emacs.app/Contents/MacOS/bin:$PATH

# Vim
#alias vim='/Applications/MacPorts/MacVim.app/Contents/MacOS/Vim -g'
alias vim='open -a /Applications/MacPorts/MacVim.app $1'

# VS Code
alias vscode='open -a /Applications/Visual\ Studio\ Code.app $1'

# Perl
export PERL_LWP_SSL_VERIFY_HOSTNAME=0
export PERL_UNICODE=SDL

# Java
if type "/usr/libexec/java_home" > /dev/null; then
    export JAVA_HOME=`/usr/libexec/java_home`
fi
export M2_REPO=~/.m2/repository
export M2_HOME=/opt/apache-maven-3.2.5
export MAVEN_OPTS="-Dfile.encoding=UTF-8 -Djava.awt.headless=true -Xmx1024M  -XX:MaxPermSize=512m -XX:MaxMetaspaceSize=512m"
export JAVA_OPTS="-Djava.awt.headless=true -Xmx1024M  -XX:MaxPermSize=512m -XX:MaxMetaspaceSize=512m"
export PATH=$M2_HOME/bin:$PATH

# Golang
export GOPATH="$HOME/Documents/workspaces/go"
export GO=$GOPATH
export GOROOT=/opt/go
if type "launchctl" > /dev/null; then
    launchctl setenv GOROOT /opt/go
    launchctl setenv GOPATH /Users/bborbe/Documents/workspaces/go
fi
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

# Wget
alias get="wget --no-check-certificate"

# CoreOS
export COREOS_ENDPOINT=172.16.30.10
export FLEETCTL_ENDPOINT=http://$COREOS_ENDPOINT:4001
export ETCDCTL_ENDPOINT=http://$COREOS_ENDPOINT:2379

# Docker
export PATH=/Applications/Docker.app/Contents/Resources/bin:$PATH

# Phantomjs
export PATH=/opt/phantomjs/bin:$PATH

# Chromedriver
export PATH=/opt/chromedriver/bin:$PATH

# Nsq
export PATH=/opt/nsq/bin:$PATH

# Postgresql
export PATH=/opt/local/lib/postgresql93/bin:$PATH

# Mysql
export PATH=/opt/local/lib/mysql55/bin:$PATH

# Vagrant
export PATH=/Applications/Vagrant/bin:$PATH

# User Bins
export PATH=$HOME/Documents/workspaces/scripts:$PATH

# Postgresql
export PATH=/opt/local/lib/postgresql96/bin:$PATH

#export http_proxy="http://127.0.0.1:8118"

# vim mode
bindkey -v

# Use vim cli mode
bindkey '^P' up-history
bindkey '^N' down-history

# backspace and ^h working even after
# returning from command mode
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char

# ctrl-w removed word backwards
bindkey '^w' backward-kill-word

# ctrl-r starts searching history backward
bindkey '^r' history-incremental-search-backward

# prompt
PROMPT='%n@%m %{$fg_bold[red]%}➜ %{$fg_bold[green]%}%p %{$fg[blue]%}%c %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}'
#PROMPT='%{$fg_bold[red]%}➜ %{$fg_bold[green]%}%p %{$fg[blue]%}%c %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}'

function zle-line-init zle-keymap-select {
    VIM_PROMPT="%{$fg_bold[red]%} <N> %{$reset_color%}"
    RPS1="${${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)} $EPS1"
    zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select
export KEYTIMEOUT=1

# searching
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down

# pyenv
export PATH="/Users/bborbe/.pyenv/bin:$PATH"
if type "pyenv" > /dev/null; then
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

# git alias
alias gps='git pull && git submodule update'

# update dotfiles
source ~/.zsh/dotfiles.zsh
${DOTFILES}/update

