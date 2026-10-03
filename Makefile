SHELL_FILES = install update .git-hooks/pre-commit .git-hooks/pre-push .git-hooks/test-pre-commit.sh .zsh/git-helpers.zsh

test: check

check:
	shellcheck -S error $(SHELL_FILES)
	./.git-hooks/test-pre-commit.sh

precommit: check

.PHONY: test check precommit
