#!/usr/bin/env bash
# Runs "$4" with the fake engine "$1", forced exit "$2" and ok flag "$3". See with_path.sh
# for why this is a file.
GODOT="$1" FAKE_GODOT_EXIT="$2" FAKE_GODOT_OK="$3" exec "$BASH" "$4"
