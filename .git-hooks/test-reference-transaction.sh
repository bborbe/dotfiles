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
#   2. A pin on a MAIN checkout cannot coexist with `git worktree add`: during
#      the add git runs the hook at the INVOKING checkout while the HEAD line
#      names the NEW worktree. That is why only worktree-scope pins count, and
#      why the add cases run from an unpinned main checkout.
#
# Scratch lives under $XDG_CACHE_HOME, never /tmp: pre-commit and pre-push
# self-skip under /tmp, and keeping every hook suite in the same place avoids a
# case that passes vacuously because a sibling hook skipped it.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks_dir="$repo_root/.git-hooks"

scratch_root="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$scratch_root"
scratch="$(mktemp -d "$scratch_root/dotfiles-reference-transaction-test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

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

# new_repo <dir> — master, one commit, and free branches `other`, `third`,
# `fourth`, plus a tracked `sub/` directory.
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
		git branch fourth
	)
}

# pair <id> — an UNPINNED main checkout plus a linked worktree on `other`, with
# ONLY the linked worktree pinned, the way git-pin-worktree does it.
pair() {
	local d="$scratch/main$1"
	new_repo "$d"
	(
		cd "$d" || exit 99
		git worktree add -q "$d-linked" other
		git config extensions.worktreeConfig true
	)
	( cd "$d-linked" && git config --worktree hook.pinBranch other )
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
	last_out="$( cd "$dir/${sub:-.}" && git "$@" 2>&1 )" || rc=$?
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
for needle in 'Blocked: this working tree is pinned to other' "$scratch/main1-linked" 'git worktree add' 'git config --worktree --unset hook.pinBranch' 'DOTFILES_ALLOW_UNPIN'; do
	printf '%s' "$last_out" | grep -qF "$needle" || missing="${missing:+$missing, }$needle"
done
if [ -n "$missing" ]; then
	no "refusal is missing: $missing"
else
	ok "refusal names the pin, the path, the unpin command and the override"
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

echo "a worktree pin does not leak to the main checkout"
run ALLOW main 1 . checkout third
run ALLOW main 1 . checkout -b newbranch2
run ALLOW main 1 . checkout --detach HEAD

echo "a worktree pin does not leak to a sibling worktree"
n=$((n + 1))
rc=0
( cd "$scratch/main1" && git worktree add -q "$scratch/main1-sibling" fourth ) || rc=$?
[ "$rc" = 0 ] && ok "git worktree add of a sibling" || no "sibling worktree add rc=$rc"
n=$((n + 1))
rc=0
( cd "$scratch/main1-sibling" && git checkout -q -b sibling-branch ) || rc=$?
[ "$rc" = 0 ] && ok "the unpinned sibling switches freely" || no "sibling was blocked (rc=$rc) — the pin leaked"

echo "a repo-wide (--local) value is ignored, so it cannot pin the main checkout"
n=$((n + 1))
d="$scratch/local$n"
new_repo "$d"
( cd "$d" && git config --local hook.pinBranch master )
rc=0
( cd "$d" && git worktree add -q "$d-wt" other ) || rc=$?
[ "$rc" = 0 ] && ok "git worktree add from a repo carrying a --local pin" || no "a --local pin blocked worktree add (rc=$rc)"
n=$((n + 1))
rc=0
( cd "$d" && git checkout -q third ) || rc=$?
[ "$rc" = 0 ] && ok "a --local pin does not hold the main checkout" || no "a --local pin was honoured (rc=$rc)"

echo "git init is not blocked"
n=$((n + 1))
d="$scratch/init$n"
rc=0
( cd "$scratch" && git init -q -b master "$d" ) || rc=$?
[ "$rc" = 0 ] && ok "git init" || no "git init rc=$rc"

echo "worktree remove of a pinned worktree is not blocked"
pair 3
n=$((n + 1))
rc=0
( cd "$scratch/main3" && git worktree remove "$scratch/main3-linked" ) >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && ok "git worktree remove of a pinned worktree" || no "worktree remove rc=$rc"

echo "escape hatch"
pair 2
n=$((n + 1))
rc=0
( cd "$scratch/main2-linked" && DOTFILES_ALLOW_UNPIN=1 git checkout third ) >/dev/null 2>&1 || rc=$?
got="$( cd "$scratch/main2-linked" && git rev-parse --abbrev-ref HEAD )"
if [ "$rc" = 0 ] && [ "$got" = third ]; then
	ok "DOTFILES_ALLOW_UNPIN=1 allows the switch (now on $got)"
else
	no "escape hatch rc=$rc branch=$got"
fi

echo "an off-spelling of the override must not disarm the guard"
n=$((n + 1))
rc=0
( cd "$scratch/main2-linked" && DOTFILES_ALLOW_UNPIN=0 git checkout fourth ) >/dev/null 2>&1 || rc=$?
got="$( cd "$scratch/main2-linked" && git rev-parse --abbrev-ref HEAD )"
if [ "$rc" != 0 ] && [ "$got" = third ]; then
	ok "DOTFILES_ALLOW_UNPIN=0 is refused — only =1 disarms it"
else
	no "DOTFILES_ALLOW_UNPIN=0 rc=$rc branch=$got — an off-spelling disarmed the guard"
fi

echo "an unset HOME does not disarm the guard"
n=$((n + 1))
rc=0
( cd "$scratch/main1-linked" && env -u HOME git checkout third ) >/dev/null 2>&1 || rc=$?
[ "$rc" != 0 ] && ok "unset HOME still blocks" || no "unset HOME disarmed the guard (rc=$rc)"

echo "unpinning restores normal behaviour"
n=$((n + 1))
( cd "$scratch/main1-linked" && git config --worktree --unset hook.pinBranch )
rc=0
( cd "$scratch/main1-linked" && git checkout -q third ) || rc=$?
[ "$rc" = 0 ] && ok "git config --worktree --unset hook.pinBranch releases the tree" || no "unpinned tree still blocked (rc=$rc)"

# Discriminating check: the deny cases above must depend on the hook actually
# blocking. A no-op hook has to turn the same command into ALLOW — otherwise the
# suite would report green against a guard that does nothing.
echo "the suite is discriminating (a no-op hook must fail the deny cases)"
pair 4
n=$((n + 1))
mkdir -p "$scratch/noop-hooks"
printf '#!/bin/bash\nexit 0\n' >"$scratch/noop-hooks/reference-transaction"
chmod +x "$scratch/noop-hooks/reference-transaction"
rc=0
( cd "$scratch/main4-linked" \
	&& git -c core.hooksPath="$scratch/noop-hooks" checkout third ) >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ]; then
	ok "no-op hook lets the switch through, so a BLOCK means the guard fired"
else
	no "no-op hook still blocked (rc=$rc) — the deny cases prove nothing"
fi

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
