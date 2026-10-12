SHELL_FILES = install update .git-hooks/pre-commit .git-hooks/pre-push .git-hooks/reference-transaction .git-hooks/test-pre-commit.sh .git-hooks/test-reference-transaction.sh .zsh/git-helpers.zsh

test: check

check:
	shellcheck -S error $(SHELL_FILES)
	./.git-hooks/test-pre-commit.sh
	./.git-hooks/test-reference-transaction.sh

precommit: check

.PHONY: test check precommit
