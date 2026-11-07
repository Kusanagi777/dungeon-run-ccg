#!/usr/bin/env bash
# tools/balance.sh: the relative balance report (spec section 5).
#
#   bash tools/balance.sh                          # every class, power and archetype
#   bash tools/balance.sh --seeds 8 --all-bosses   # slower and steadier
#   bash tools/balance.sh --class hero_fortune --no-archetypes
#   GODOT=/path/to/godot bash tools/balance.sh
#
# Writes production/qa/balance/<date>.md and prints it. It reports and never blocks a
# build: exit 0 once a report is written, 2 if it could not run. Run after
# `godot --headless --path . --import`.

set -u

cd "$(dirname "$0")/.." || exit 2
godot_bin="${GODOT:-godot}"
if ! command -v "$godot_bin" > /dev/null 2>&1; then
	echo "balance.sh: '$godot_bin' not found" >&2
	exit 2
fi
exec "$godot_bin" --headless --path . -s res://tests/integration/boss_ai/balance_main.gd -- "$@"
