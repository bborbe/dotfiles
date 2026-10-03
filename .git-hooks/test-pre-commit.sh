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
# case would report ALLOW. The suite cannot pass vacuously for the same reason —
# 21 of the cases below assert BLOCK, so a self-skipping hook fails loudly.
#
# Cases are grouped by the rule they pin, and several exist because a review
# round found the rule broken:
#   - reserved-device names are matched on the STEM, so NUL.txt.md is caught
#     (Windows treats NUL.txt and NUL.tar.gz as NUL)
#   - reserved-device names are matched in EVERY component, so NUL/notes.md is
#     caught too — Windows rejects a directory named NUL as readily as a file
#   - a rename AWAY from an unsafe name must commit, because that is the
#     remediation this hook itself prescribes

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks_dir="$repo_root/.git-hooks"

# ~/.cache does not exist on a stock macOS, and it did not exist on the GitHub
# runner either — mktemp -d needs the parent to be there.
scratch_root="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$scratch_root"
scratch="$(mktemp -d "$scratch_root/dotfiles-pre-commit-test.XXXXXX")"
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

# A throwaway repo with the real hook wired in. Echoes nothing; the caller runs
# its body with $dir as cwd via `init_repo`.
init_repo() {
	dir="$scratch/r$((n + 1))"
	mkdir -p "$dir"
	cd "$dir" || exit 99
	git init -q -b master
	git config user.email "pre-commit-test@example.com"
	git config user.name "pre-commit test"
	git config core.hooksPath "$hooks_dir"
}

# check <path> <ALLOW|BLOCK> [vault]
check() {
	local path="$1" want="$2" vault="${3:-yes}"
	n=$((n + 1))
	local dir got
	got="$(
		init_repo
		if [ "$vault" = yes ]; then mkdir -p .obsidian; fi
		mkdir -p "$(dirname "$path")"
		printf 'x\n' >"$path"
		git add -A >/dev/null 2>&1
		if git commit -q -m t >/dev/null 2>&1; then echo ALLOW; else echo BLOCK; fi
	)"
	if [ "$got" = "$want" ]; then
		ok "$(printf '%-36s %s' "[$path]" "$got")"
	else
		no "$(printf '%-36s got=%s want=%s' "[$path]" "$got" "$want")"
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
check 'Trailing Space /File.md' BLOCK
check 'Fine Dir/File.md' ALLOW

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

echo "reserved device names — matched in every component, not just the leaf"
check 'NUL/notes.md' BLOCK
check 'a/NUL/b.md' BLOCK
check 'LPT1.tar.gz/x.md' BLOCK
check '25 Tasks/NUL/notes.md' BLOCK
check 'Console/notes.md' ALLOW

echo "non-vault repo — the block must not fire"
check '25 Tasks/Colon: Here.md' ALLOW no
check 'weird*name?.txt' ALLOW no
check '25 Tasks/NUL.txt.md' ALLOW no

echo "renames"
n=$((n + 1))
got="$(
	init_repo
	mkdir -p .obsidian "25 Tasks"
	printf 'x\n' >"25 Tasks/Bad: Name.md"
	git add -A >/dev/null 2>&1
	git commit -q -m seed --no-verify >/dev/null 2>&1
	git mv "25 Tasks/Bad: Name.md" "25 Tasks/Bad - Name.md"
	git add -A >/dev/null 2>&1
	if git commit -q -m rename >/dev/null 2>&1; then echo ALLOW; else echo BLOCK; fi
)"
if [ "$got" = ALLOW ]; then
	ok "rename away from an unsafe name commits (the prescribed remediation)"
else
	no "rename away from an unsafe name got=$got want=ALLOW — the hook blocks its own fix"
fi

n=$((n + 1))
got="$(
	init_repo
	mkdir -p .obsidian "25 Tasks"
	printf 'x\n' >"25 Tasks/Good Name.md"
	git add -A >/dev/null 2>&1
	git commit -q -m seed --no-verify >/dev/null 2>&1
	git mv "25 Tasks/Good Name.md" "25 Tasks/Bad: Name.md"
	git add -A >/dev/null 2>&1
	if git commit -q -m rename >/dev/null 2>&1; then echo ALLOW; else echo BLOCK; fi
)"
if [ "$got" = BLOCK ]; then
	ok "rename TO an unsafe name is blocked"
else
	no "rename TO an unsafe name got=$got want=BLOCK"
fi

echo "mixed commit"
n=$((n + 1))
got="$(
	init_repo
	mkdir -p .obsidian "25 Tasks"
	printf 'x\n' >"25 Tasks/Good Name.md"
	printf 'x\n' >"25 Tasks/Bad: Name.md"
	git add -A >/dev/null 2>&1
	if git commit -q -m t >/dev/null 2>&1; then echo ALLOW; else echo BLOCK; fi
)"
if [ "$got" = BLOCK ]; then
	ok "one unsafe path blocks the whole commit"
else
	no "mixed commit got=$got want=BLOCK"
fi

echo "message wording (cross-tool contract with git-ai-sync)"
n=$((n + 1))
err="$(
	init_repo
	mkdir -p .obsidian "25 Tasks"
	printf 'x\n' >"25 Tasks/Bad: Name.md"
	git add -A >/dev/null 2>&1
	git commit -m t 2>&1 >/dev/null || true
)"
bad=""
if printf '%s' "$err" | grep -qi 'refusing commit'; then bad="refusing commit"; fi
if printf '%s' "$err" | grep -qi 'conflict markers'; then bad="${bad:+$bad, }conflict markers"; fi
if [ -n "$bad" ]; then
	no "refusal text contains \"$bad\" — git-ai-sync's is_marker_refusal() would misread it as a conflict-marker refusal and kill the sync daemon"
elif ! printf '%s' "$err" | grep -q 'Blocked: staged path is not safe on Windows'; then
	no "refusal text missing its expected headline — did the message move?"
else
	ok "refusal text carries neither git-ai-sync trigger phrase"
fi

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
