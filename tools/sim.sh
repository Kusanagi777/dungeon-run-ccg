#!/usr/bin/env bash
# tools/sim.sh: the headless AI-vs-AI simulation harness (boss-ai C11; story 016).
#
#   bash tools/sim.sh --boss boss_rat_king --seeds 100
#   bash tools/sim.sh --boss boss_hollow_king --seeds 200 --verify
#   bash tools/sim.sh --boss boss_rat_king --vs-boss boss_gatekeeper --seeds 50
#   GODOT=/path/to/godot bash tools/sim.sh --boss boss_x
#
# Writes production/qa/sim/<boss_id>_<date>.json and prints a table. Arguments are
# documented in tests/integration/boss_ai/sim_main.gd. Run after
# `godot --headless --path . --import`: the harness needs the class cache.
#
# Exit 0: report written, no boss rejection, fault or overflow. Exit 1: one of those is
# in the report. Exit 2: could not run.

set -u

cd "$(dirname "$0")/.." || exit 2
godot_bin="${GODOT:-godot}"
if ! command -v "$godot_bin" > /dev/null 2>&1; then
	echo "sim.sh: '$godot_bin' not found" >&2
	exit 2
fi
exec "$godot_bin" --headless --path . -s res://tests/integration/boss_ai/sim_main.gd -- "$@"
