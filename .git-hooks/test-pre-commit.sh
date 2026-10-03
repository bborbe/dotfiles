#!/usr/bin/env bash
#
# Table-driven test for the Windows-safe filename block in .git-hooks/pre-commit.
#
# Every case gets its own throwaway git repo with core.hooksPath pointed at this
# repo's .git-hooks, so the real hook decides ALLOW/BLOCK and nothing touches a
# live vault. Wired into `make check`, so CI runs it on every pull request.
#
# The scratch dir is deliberately NOT under /tmp or /var/folders: the hook skips
# itself in those paths (test fixtures elsewhere legitimately commit marker-laden
# files), so a scratch repo there would skip the very block under test and every
# case would report ALLOW.
#
# Cases are grouped by the rule they pin. The reserved-device group tests the
# STEM — Windows treats NUL.txt and NUL.tar.gz as NUL, so matching the whole name
# instead of the stem silently lets NUL.txt.md through (found in review
# 2026-10-03; this table is what keeps it fixed).

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks_dir="$repo_root/.git-hooks"
scratch="$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-pre-commit-test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

pass=0
fail=0
n=0

# check <path> <ALLOW|BLOCK> [vault]
check() {
	local path="$1" want="$2" vault="${3:-yes}"
	n=$((n + 1))
	local dir="$scratch/c$n"
	mkdir -p "$dir"

	local got
	got="$(
		cd "$dir" || exit 99
		git init -q -b master
		git config user.email "pre-commit-test@example.com"
		git config user.name "pre-commit test"
		git config core.hooksPath "$hooks_dir"
		[ "$vault" = yes ] && mkdir -p .obsidian
		mkdir -p "$(dirname "$path")"
		printf 'x\n' >"$path"
		git add -A >/dev/null 2>&1
		if git commit -q -m t >/dev/null 2>&1; then echo ALLOW; else echo BLOCK; fi
	)"

	if [ "$got" = "$want" ]; then
		pass=$((pass + 1))
		printf '  ok   %-34s %s\n' "[$path]" "$got"
	else
		fail=$((fail + 1))
		printf '  FAIL %-34s got=%s want=%s\n' "[$path]" "$got" "$want"
	fi
}

echo "forbidden characters"
check '25 Tasks/Plain Valid Name.md' ALLOW
check '25 Tasks/Colon: Here.md' BLOCK
check '25 Tasks/Question?.md' BLOCK
check '25 Tasks/Star*.md' BLOCK
check '25 Tasks/Quote".md' BLOCK
check '25 Tasks/Less<.md' BLOCK
check '25 Tasks/Greater>.md' BLOCK
check '25 Tasks/Pipe|.md' BLOCK
check '25 Tasks/emdash — ok.md' ALLOW

echo "trailing dot or space, including directory components"
check '25 Tasks/Trailing Dot.' BLOCK
check '25 Tasks/Trailing Space ' BLOCK
check 'Bad Dir. /File.md' BLOCK

echo "reserved device names — matched on the stem"
check '25 Tasks/CON.md' BLOCK
check '25 Tasks/com1.md' BLOCK
check '25 Tasks/LPT9.md' BLOCK
check '25 Tasks/aux.md' BLOCK
check '25 Tasks/con.txt' BLOCK
check '25 Tasks/NUL.txt.md' BLOCK
check '25 Tasks/NUL.tar.gz' BLOCK
check '25 Tasks/LPT1.tar.gz.bak' BLOCK
check '25 Tasks/PRN.txt.md' BLOCK
check '25 Tasks/Console.md' ALLOW
check '25 Tasks/NULx.md' ALLOW
check '25 Tasks/COM0.md' ALLOW
check '25 Tasks/LPT0.md' ALLOW
check '25 Tasks/COM10.md' ALLOW

echo "non-vault repo — the block must not fire"
check '25 Tasks/Colon: Here.md' ALLOW no
check 'weird*name?.txt' ALLOW no
check '25 Tasks/NUL.txt.md' ALLOW no

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
