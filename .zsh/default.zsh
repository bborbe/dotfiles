if [ -d ~/Documents/workspaces/dotfiles ]; then
  export DOTFILES=~/Documents/workspaces/dotfiles
else
  export DOTFILES=~/dotfiles
fi

# Lazy-load nvm — shaves ~4.5s off shell startup
export NVM_DIR="$HOME/.nvm"

# Pre-seed PATH with default Node version so node/npm work immediately
if [ -s "$NVM_DIR/alias/default" ]; then
  _NVM_DEFAULT_VERSION=$(cat "$NVM_DIR/alias/default")
  _NVM_BIN="$NVM_DIR/versions/node/v${_NVM_DEFAULT_VERSION}/bin"
  [ -d "$_NVM_BIN" ] && export PATH="$_NVM_BIN:$PATH"
  unset _NVM_DEFAULT_VERSION _NVM_BIN
fi

nvm() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
  nvm "$@"
}
node()  { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"; command node "$@"; }
npm()   { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"; command npm "$@"; }
npx()   { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"; command npx "$@"; }

# usx to PATH
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# add .local/bin to path
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
