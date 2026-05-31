SHELL_FILES = install update .git-hooks/pre-push .zsh/git-helpers.zsh

test: check

check:
	shellcheck -S error $(SHELL_FILES)

precommit: check

.PHONY: test check precommit
