if SHELL=$(command -v zsh); then
	export SHELL
	$SHELL
else
	unset SHELL
fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/bborbe/.lmstudio/bin"
# End of LM Studio CLI section


. "$HOME/.local/bin/env"
