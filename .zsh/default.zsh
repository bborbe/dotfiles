if [ -d ~/Documents/workspaces/dotfiles ]; then
  export DOTFILES=~/Documents/workspaces/dotfiles
else
  export DOTFILES=~/dotfiles
fi

# init nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# usx to PATH
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# add .local/bin to path
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
