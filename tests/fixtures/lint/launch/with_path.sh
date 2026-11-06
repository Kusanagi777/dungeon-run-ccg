#!/usr/bin/env bash
# Runs "$2" on "$3" with PATH set to "$1". The lint suites launch this file rather than
# pass the line to `bash -c`: Godot's OS.execute goes through a shell on Linux when it
# captures output, and that shell would expand any `$` in an argument to nothing.
PATH="$1" exec "$BASH" "$2" "$3"
