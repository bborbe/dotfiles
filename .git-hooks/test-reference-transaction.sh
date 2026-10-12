#!/usr/bin/env bash
#
# Tests for .git-hooks/reference-transaction (the branch-pin guard).
#
# Usage: bash .git-hooks/test-reference-transaction.sh   (exit 0 = all pass)
#
# The hook ABORTS a git command, so every case asserts on the real command's
# exit code, never on a direct hook invocation — a suite that called the hook
# itself could pass while git never consulted it.
#
# Two traps this suite is built around, both measured 2026-10-12:
#
#   1. The deny target must be a branch checked out NOWHERE. `master` is held by
#      the main checkout, so `git checkout master` inside its own linked
#      worktree is refused by git itself ("already used by worktree") and would
#      report BLOCK with the hook doing nothing. `third` is free, so a BLOCK can
#      only come from the guard.
#   2. A pin on a MAIN checkout cannot be tested with `git worktree add`: during
#      the add git runs the hook at the INVOKING checkout while the HEAD line
#      names the NEW worktree, so a pinned main checkout refuses the add. That is
#      why main checkouts are unpinned, and why the add cases below run from an
#      unpinned main checkout.
#
# Scratch lives under $XDG_CACHE_HOME, never /tmp: the hook self-skips under
# /tmp and /var/folders, so a scratch repo there would report ALLOW for every
# case and the suite would pass vacuously.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks_dir="$repo_root/.git-hooks"

scratch_root="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$scratch_root"
scratch="$(mktemp -d "$scratch_root/dotfiles-reference-transaction-test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

registry="$scratch/pins"
pass=0
fail=0
n=0

ok() {
	pass=$((pass + 1))
	printf '  ok   %s\n' "$1"
}

no() {
	fail=$((fail + 1))
	printf '  FAIL %s\n' "$1"
}

# new_repo <dir> — master, one commit, and free branches `other` and `third`.
new_repo() {
	mkdir -p "$1"
	(
		cd "$1" || exit 99
		git init -q -b master
		git config user.email "reference-transaction-test@example.com"
		git config user.name "reference-transaction test"
		git config core.hooksPath "$hooks_dir"
		printf 'x\n' >f
		mkdir -p sub
		printf 'y\n' >sub/f
		git add -A
		# --no-verify: the pre-commit hook is not under test here.
		git commit -q --no-verify -m seed
		git branch other
		git branch third
	)
}

# pair <id> — an UNPINNED main checkout plus a linked worktree on `other`, with
# ONLY the linked worktree pinned. Sets $registry to that fixture.
pair() {
	local d="$scratch/main$1"
	new_repo "$d"
	( cd "$d" && DOTFILES_PIN_REGISTRY=/dev/null git worktree add -q "$d-linked" other )
	printf '%s\tother\n' "$d-linked" >"$registry"
}

# run <want ALLOW|BLOCK> <tree main|linked> <id> <subdir> <git args...>
last_out=""
run() {
	local want="$1" tree="$2" id="$3" sub="$4"
	shift 4
	n=$((n + 1))
	local dir="$scratch/main$id"
	[ "$tree" = linked ] && dir="$dir-linked"
	local rc=0
	last_out="$( cd "$dir/${sub:-.}" && DOTFILES_PIN_REGISTRY="$registry" git "$@" 2>&1 )" || rc=$?
	local got=ALLOW
	[ "$rc" = 0 ] || got=BLOCK
	if [ "$got" = "$want" ]; then
		ok "$(printf '%-44s %s' "$tree: git $*" "$got")"
	else
		no "$(printf '%-44s got=%s want=%s rc=%s' "$tree: git $*" "$got" "$want" "$rc")"
	fi
}

echo "pinned linked worktree (pinned to 'other')"
pair 1
run BLOCK linked 1 . checkout third
run BLOCK linked 1 . switch third
run BLOCK linked 1 . checkout -b newbranch
run BLOCK linked 1 . checkout --detach HEAD
run ALLOW linked 1 . checkout other
run ALLOW linked 1 . commit --allow-empty -m c
run ALLOW linked 1 . branch zzz
run BLOCK linked 1 sub checkout third

echo "the refusal names the pin, the path, and the way out"
n=$((n + 1))
missing=""
for needle in 'Blocked: this working tree is pinned to other' "$scratch/main1-linked" 'git worktree add' 'DOTFILES_ALLOW_UNPIN'; do
	printf '%s' "$last_out" | grep -qF "$needle" || missing="${missing:+$missing, }$needle"
done
if [ -n "$missing" ]; then
	no "refusal is missing: $missing"
else
	ok "refusal names the pin, the path and the override"
fi

echo "the refusal must not trip git-ai-sync's conflict-marker classifier"
n=$((n + 1))
bad=""
printf '%s' "$last_out" | grep -qi 'refusing commit' && bad="refusing commit"
printf '%s' "$last_out" | grep -qi 'conflict markers' && bad="${bad:+$bad, }conflict markers"
if [ -n "$bad" ]; then
	no "refusal contains \"$bad\" — is_marker_refusal() would bounce the sync daemon"
else
	ok "refusal carries neither git-ai-sync trigger phrase"
fi

echo "an unpinned main checkout is untouched"
run ALLOW main 1 . checkout third
run ALLOW main 1 . checkout -b newbranch2
run ALLOW main 1 . checkout --detach HEAD

echo "the documented flow still works from an unpinned main checkout"
n=$((n + 1))
d="$scratch/main9"
new_repo "$d"
printf '%s\tother\n' "$d-wt" >"$registry"
rc=0
( cd "$d" && DOTFILES_PIN_REGISTRY="$registry" git worktree add -q "$d-wt" other ) || rc=$?
[ "$rc" = 0 ] && ok "git worktree add" || no "git worktree add rc=$rc"

n=$((n + 1))
rc=0
( cd "$d" && DOTFILES_PIN_REGISTRY="$registry" git worktree remove "$d-wt" ) >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && ok "git worktree remove of a pinned worktree" || no "git worktree remove rc=$rc"

echo "git init is not blocked"
n=$((n + 1))
d="$scratch/init$n"
rc=0
( cd "$scratch" && DOTFILES_PIN_REGISTRY=/dev/null git init -q -b master "$d" ) || rc=$?
[ "$rc" = 0 ] && ok "git init" || no "git init rc=$rc"

echo "escape hatch"
pair 2
n=$((n + 1))
rc=0
( cd "$scratch/main2-linked" && DOTFILES_PIN_REGISTRY="$registry" DOTFILES_ALLOW_UNPIN=1 git checkout third ) >/dev/null 2>&1 || rc=$?
got="$( cd "$scratch/main2-linked" && git rev-parse --abbrev-ref HEAD )"
if [ "$rc" = 0 ] && [ "$got" = third ]; then
	ok "DOTFILES_ALLOW_UNPIN=1 allows the switch (now on $got)"
else
	no "escape hatch rc=$rc branch=$got"
fi

echo "an absent registry disables the guard"
n=$((n + 1))
rc=0
( cd "$scratch/main1-linked" && DOTFILES_PIN_REGISTRY="$scratch/does-not-exist" git checkout third ) >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && ok "missing registry is a no-op" || no "missing registry rc=$rc"

# Discriminating check: the deny cases above must depend on the hook actually
# blocking. A no-op hook has to turn the same command into ALLOW — otherwise the
# suite would report green against a guard that does nothing.
echo "the suite is discriminating (a no-op hook must fail the deny cases)"
n=$((n + 1))
mkdir -p "$scratch/noop-hooks"
printf '#!/bin/bash\nexit 0\n' >"$scratch/noop-hooks/reference-transaction"
chmod +x "$scratch/noop-hooks/reference-transaction"
rc=0
( cd "$scratch/main1-linked" \
	&& git -c core.hooksPath="$scratch/noop-hooks" checkout third ) >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ]; then
	ok "no-op hook lets the switch through, so a BLOCK means the guard fired"
else
	no "no-op hook still blocked (rc=$rc) — the deny cases prove nothing"
fi

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
