# shellcheck shell=bash
# Git workflow helpers.

# Create a feature worktree in one shot, with the remote branch + correct
# upstream set BEFORE any commit. Prevents the "upstream points at origin/master"
# trap that lets a feature branch's commits slip onto master via auto-push.
#
# Usage:
#   wt-feat <repo> <feature-name>
#
# Examples:
#   wt-feat coding rule-base-pilot
#     → creates ../coding-rule-base-pilot worktree off origin/master
#     → branch: feat/rule-base-pilot
#     → remote branch pushed; upstream set to origin/feat/rule-base-pilot
#   wt-feat dark-factory bump-image-v0.9.0
wt-feat() {
	local repo="$1" feat="$2"
	if [[ -z "$repo" || -z "$feat" ]]; then
		echo "usage: wt-feat <repo> <feature-name>" >&2
		return 1
	fi
	local root="$HOME/Documents/workspaces"
	if [[ ! -d "$root/$repo" ]]; then
		echo "wt-feat: repo not found: $root/$repo" >&2
		return 1
	fi
	cd "$root/$repo" || return 1
	git fetch origin || return 1
	local branch="feat/$feat"
	local worktree="$root/${repo}-${feat}"
	git worktree add "$worktree" -b "$branch" origin/master || return 1
	cd "$worktree" || return 1
	git push -u origin "$branch" || return 1
	echo ""
	echo "✓ worktree: $worktree"
	echo "✓ branch:   $branch"
	# shellcheck disable=SC1083  # @{upstream} is git's syntax, not a brace expansion
	echo "✓ upstream: $(git rev-parse --abbrev-ref '@{upstream}')"
}
