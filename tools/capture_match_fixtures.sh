#!/usr/bin/env bash
# The match-ui fixture sweep (story 022): one retained screenshot per fixture, through
# tools/capture.sh, labelled <nn>-<fixture>.
#
#   bash tools/capture_match_fixtures.sh [out-dir] [fixture ...]
#
# With no fixture named it sweeps every tests/fixtures/match_ui/*.json. Exit 0 when every
# capture worked, else the number that failed (capped at 125).

set -u

cd "$(dirname "$0")/.." || exit 2
out="${1:-production/qa/evidence/story-022-debug-loader-poses-and-fixture-sweep}"
[ "$#" -gt 0 ] && shift
fixtures=("$@")
if [ "${#fixtures[@]}" -eq 0 ]; then
	for path in tests/fixtures/match_ui/*.json; do
		fixtures+=("$(basename "$path" .json)")
	done
fi

failed=0
index=0
for fixture in "${fixtures[@]}"; do
	index=$((index + 1))
	label="$(printf '%02d-%s' "$index" "$fixture")"
	if ! CAPTURE_LABEL="$label" bash tools/capture.sh res://src/ui/match/match_view.tscn "$out" 60 -- "--fixture=$fixture"; then
		echo "capture failed: $fixture" >&2
		failed=$((failed + 1))
	fi
done
[ "$failed" -gt 125 ] && failed=125
exit "$failed"
