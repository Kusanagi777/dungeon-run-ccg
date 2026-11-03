#!/usr/bin/env bash
# No-global-RNG lint (rng-event-log rule 7; ADR-0003 Decision 10(b) and its
# 2026-11-03 erratum; TD-007).
#
#   bash tools/lint/no_global_rng.sh [root]   # project root, default the current directory
#
# Greps <root>/src (minus src/ui/ and src/core/rng/, minus ALLOW_LISTED) and
# the rules tests (<root>/tests/unit, <root>/tests/integration, minus
# TESTS_EXCLUDED; comment lines dropped) for bare global RNG calls with the
# ADR-0003 erratum regex — never a fixed-string list: `randf(` as a fixed
# string hits the injected `stream.randf(`. Look-around-free (ripgrep 14).
#
# Every hit prints as `no_global_rng <file>:<line>:<text>` (file relative to
# root), then `no_global_rng hits: <n>`.
# Exit 0: no hit. Exit 1: any hit. Exit 2: refused or could not run (rg
# missing or older than 14, root missing, rg erroring) — never a hit count.
#
# A hit in rules code is a bug to fix by injecting a stream; never weaken the
# token list to make one go away.
#
# Story: rng-event-log/story-004.

set -u

PATTERN='(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|\.pick_random\(|RandomNumberGenerator\.new\('

# The one permitted entropy call: Run Structure's run-creation command, the F1
# empty-seed branch (ADR-0003 Decision 10(b)). A path list, not a pattern
# exemption. `src/gameplay/run/run_machine.gd` holds `new_run`
# (architecture.md §Directory layout); until the Run Structure epic adds it,
# the entry is inert.
ALLOW_LISTED=(
	"src/gameplay/run/run_machine.gd"
)

# Tests that drive a raw RandomNumberGenerator on purpose, or hold planted
# violations as data (story rng-event-log/story-004 AC-3, amended 2026-11-03).
TESTS_EXCLUDED=(
	"tests/unit/rng_event_log/rng_engine_pins_test.gd"
	"tests/unit/rng_event_log/rng_stream_test.gd"
	"tests/unit/rng_event_log/rng_service_test.gd"  # compares the service against a raw seeded generator (added 2026-11-03)
	"tests/integration/rng_event_log/rng_lint_test.gd"
)

if ! command -v rg > /dev/null 2>&1; then
	echo "no_global_rng.sh: ripgrep (rg) not found on PATH — refusing to run (needs ripgrep >= 14)" >&2
	exit 2
fi
rg_version_line="$(rg --version 2>/dev/null | head -n 1)"
echo "no_global_rng.sh: ${rg_version_line:-rg --version printed nothing}"
rg_major="$(printf '%s\n' "$rg_version_line" | sed -n 's/^ripgrep \([0-9][0-9]*\)\..*/\1/p')"
if [ -z "$rg_major" ] || [ "$rg_major" -lt 14 ]; then
	echo "no_global_rng.sh: '${rg_version_line}' — needs ripgrep >= 14, refusing to run" >&2
	exit 2
fi

root="${1:-.}"
if [ ! -d "$root" ]; then
	echo "no_global_rng.sh: root '$root' is not a directory — refusing to run" >&2
	exit 2
fi
cd "$root" || exit 2

# scan <exclude globs...> -- <dirs...>: prints `file:line:text`; returns 2 on an rg error.
scan() {
	local globs=() dirs=() d
	while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
		globs+=(--glob "!$1")
		shift
	done
	shift
	for d in "$@"; do
		[ -d "$d" ] && dirs+=("$d")
	done
	[ "${#dirs[@]}" -eq 0 ] && return 0
	local out rc
	out="$(rg --line-number --with-filename --no-heading --color never --glob '*.gd' "${globs[@]}" -e "$PATTERN" -- "${dirs[@]}")"
	rc=$?
	if [ "$rc" -ge 2 ]; then
		echo "no_global_rng.sh: rg exited $rc" >&2
		return 2
	fi
	[ -n "$out" ] && printf '%s\n' "$out"
	return 0
}

src_hits="$(scan 'src/ui/**' 'src/core/rng/**' "${ALLOW_LISTED[@]}" -- src)" || exit 2
tests_hits="$(scan "${TESTS_EXCLUDED[@]}" -- tests/unit tests/integration)" || exit 2
# A comment that quotes a call (the F4 examples) is prose, not a call.
tests_hits="$(printf '%s\n' "$tests_hits" | rg -v '^[^:]+:[0-9]+:\s*#' || true)"

n=0
while IFS= read -r line; do
	[ -z "$line" ] && continue
	echo "no_global_rng $line"
	n=$((n + 1))
done <<< "$(printf '%s\n%s\n' "$src_hits" "$tests_hits")"
echo "no_global_rng hits: $n"
[ "$n" -eq 0 ] || exit 1
exit 0
