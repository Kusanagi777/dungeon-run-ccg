#!/usr/bin/env bash
# Runs "$2" on "$3" with "$1" put in front of PATH. See with_path.sh for why this is a file.
PATH="$1:$PATH" exec "$BASH" "$2" "$3"
