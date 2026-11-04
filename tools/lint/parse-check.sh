#!/usr/bin/env bash
# Per-file parse check of the rules and foundation tiers (ADR-0001
# Implementation Guidelines: "Every rules file must pass
# .claude/scripts/godot-parse-check.gd on its own").
#
#   bash tools/lint/parse-check.sh          # from anywhere; runs at the project root
#   GODOT=/path/to/godot bash tools/lint/parse-check.sh
#
# One `godot --headless --path . -s res://.claude/scripts/godot-parse-check.gd
# -- res://<file>` per script under src/gameplay/, src/ai/ and src/core/, so
# each file is proven to load on its own. Run it after
# `godot --headless --path . --import`: the check needs the class cache.
#
# Prints `ok: <path>` per script that loads and `PARSE FAIL: <path>` (with
# Godot's error lines) per one that does not, then a count.
# Exit 0: every script loaded. Exit 1: any `PARSE FAIL` line or non-zero exit.
# Exit 2: could not run (no godot, or no script found in scope).
#
# Story: boot-composition-root/story-005 (TD-002, TD-010).

set -u

cd "$(dirname "$0")/../.." || exit 2
godot_bin="${GODOT:-godot}"
if ! command -v "$godot_bin" > /dev/null 2>&1; then
	echo "parse-check.sh: '$godot_bin' not found — parse NOT VERIFIED" >&2
	exit 2
fi

scopes=()
for d in src/gameplay src/ai src/core; do
	[ -d "$d" ] && scopes+=("$d")
done
files=()
if [ "${#scopes[@]}" -gt 0 ]; then
	mapfile -t files < <(find "${scopes[@]}" -type f -name '*.gd' | LC_ALL=C sort)
fi
if [ "${#files[@]}" -eq 0 ]; then
	echo "parse-check.sh: no .gd file under src/gameplay, src/ai or src/core — nothing checked, not a pass" >&2
	exit 2
fi

checked=0
failed=0
for f in "${files[@]}"; do
	out="$("$godot_bin" --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- "res://$f" 2>&1)"
	rc=$?
	checked=$((checked + 1))
	if [ "$rc" -ne 0 ] || printf '%s\n' "$out" | grep -q 'PARSE FAIL'; then
		failed=$((failed + 1))
		printf '%s\n' "$out" | grep -v '^Godot Engine v'
		printf '%s\n' "$out" | grep -q 'PARSE FAIL' || echo "PARSE FAIL: res://$f (godot exited $rc)"
	else
		echo "ok: res://$f"
	fi
done

echo "parse-check.sh: $checked checked, $failed failed"
[ "$failed" -eq 0 ] || exit 1
exit 0
