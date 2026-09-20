#!/usr/bin/env bash
#
# Print the role -> {window_id, chip, scheme} map published by the WezTerm config.
#
# The map is written by `export_role_map()` in `.config/wezterm/wezterm.lua` on
# every reconcile tick, so it always reflects the window ids that exist RIGHT NOW.
# Window ids are runtime-assigned and move on a WezTerm restart, which is exactly
# why this reads the published file rather than carrying a table of its own — a
# frozen map answers the question confidently and wrongly.
#
# Output: one TSV row per role, `role<TAB>window_id<TAB>chip<TAB>scheme`.
#
# Exit codes are load-bearing:
#   0  the map is present AND carries at least one role
#   1  the map is missing, or present but empty
#
# The empty case is its own failure on purpose. A published-but-empty map looks
# identical to a working one under a presence check (`[ -f ]` passes, `cat` shows
# `{}`), and a caller that reads it falls back to its default silently — which
# reads as "no role declared" rather than as a fault. Measured 2026-09-20: the map
# sat at 5 bytes of `{}` for hours while every spawn quietly ignored its role.

set -o errexit
set -o pipefail

MAP="${WEZTERM_ROLE_MAP:-$HOME/.cache/wezterm-role-map.json}"

if [ ! -f "$MAP" ]; then
  echo "wezterm-roles: no role map at ${MAP}" >&2
  echo "  the wezterm config publishes it on its reconcile tick; if wezterm is not running, nothing is published" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "wezterm-roles: jq is required to read ${MAP}" >&2
  exit 1
fi

if ! jq -e 'type == "object" and length > 0' "$MAP" >/dev/null 2>&1; then
  echo "wezterm-roles: role map at ${MAP} is empty or unreadable" >&2
  echo "  present-but-empty is a failure, not a result: every consumer falls back to its default" >&2
  exit 1
fi

jq -r 'to_entries[] | [.key, (.value.window_id | tostring), (.value.chip // "-"), (.value.scheme // "-")] | @tsv' "$MAP"
