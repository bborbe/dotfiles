if SHELL=$(command -v zsh); then
	export SHELL
	$SHELL
else
	unset SHELL
fi
