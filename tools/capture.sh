#!/usr/bin/env bash
# tools/capture.sh — run-and-observe screenshot capture for Godot on Linux/CI.
#
# Usage:
#   bash tools/capture.sh <scene-res-path> <out-dir> [frames]
#   bash tools/capture.sh <scene-res-path> <out-dir> <frames> -- <godot user args...>
#   CAPTURE_LABEL=<nn>-<what> bash tools/capture.sh ...
#   bash tools/capture.sh res://src/scenes/boot.tscn production/qa/evidence/<story-slug>
#
# Arguments after a literal `--` (the 4th argument) are passed to Godot after
# the scene, behind its own `--`, so the scene reads them with
# OS.get_cmdline_user_args() (boot-composition-root story 006; match-ui
# story 004's spec). CAPTURE_LABEL (optional, `<nn>-<what>`, e.g.
# `02-data_error`) names the kept frame `<out-dir>/<label>.png`, so several
# states of one scene can be retained in one folder; without it the name is
# `01-<scene-basename>.png` as before.
#
# Launches the scene windowed under Xvfb with the Compatibility (OpenGL 3)
# renderer, records <frames> frames (default 60) with Movie Maker mode, keeps
# the LAST frame as <out-dir>/01-<scene-basename>.png, deletes the other
# frames and the .wav, prints the kept path, and exits non-zero when no PNG
# was produced or the PNG is all one colour (blank capture).
#
# This is the command observed to work on 2026-11-03
# (docs/architecture/spikes/2026-11-03-engine-probes.md, Probe C):
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --windowed \
#     --resolution 1280x720 --rendering-driver opengl3 \
#     --write-movie <dir>/f.png --quit-after 60 res://<scene>.tscn
# `--headless --write-movie` crashes (exit 134); never add --headless here.
# Frames are the project viewport size (1280x720), not --resolution.
# Output is Compatibility/llvmpipe rendering, not the project's Forward+
# renderer: Forward+-only effects will not appear in CI evidence.
#
# Exit codes: 0 kept a non-blank PNG; 2 usage (incl. a bad CAPTURE_LABEL); 3 Godot failed or wrote no
# PNG; 4 the PNG is all one colour or could not be decoded.
set -euo pipefail

usage="usage: $0 <scene-res-path> <out-dir> [frames] | <scene-res-path> <out-dir> <frames> -- <args...>"
if [ "$#" -lt 2 ] || { [ "$#" -gt 3 ] && [ "$4" != "--" ]; }; then
	echo "$usage" >&2
	exit 2
fi

scene="$1"
out_dir="$2"
frames="${3:-60}"
user_args=()
if [ "$#" -ge 4 ]; then
	user_args=("${@:5}")
fi
label="${CAPTURE_LABEL:-}"
if [ -n "$label" ]; then
	case "$label" in
		[0-9][0-9]-*) ;;
		*) echo "capture.sh: CAPTURE_LABEL must be <nn>-<what>, got '$label'" >&2; exit 2 ;;
	esac
	case "$label" in
		*[!A-Za-z0-9_-]*) echo "capture.sh: CAPTURE_LABEL may hold only letters, digits, '_' and '-', got '$label'" >&2; exit 2 ;;
	esac
fi

case "$scene" in
	res://*.tscn) ;;
	*) echo "capture.sh: scene must be a res://...tscn path, got '$scene'" >&2; exit 2 ;;
esac
case "$frames" in
	''|*[!0-9]*|0) echo "capture.sh: frames must be a positive integer, got '$frames'" >&2; exit 2 ;;
esac

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$out_dir"
out_dir="$(cd "$out_dir" && pwd)"
scene_base="$(basename "$scene" .tscn)"
kept="$out_dir/${label:-01-$scene_base}.png"

# Record into a scratch dir inside out-dir so only the kept frame remains.
tmp_dir="$(mktemp -d "$out_dir/.capture-XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

set +e
xvfb-run -a -s "-screen 0 1280x720x24" \
	godot --path "$repo_root" --windowed --resolution 1280x720 \
	--rendering-driver opengl3 \
	--write-movie "$tmp_dir/f.png" --quit-after "$frames" "$scene" \
	${user_args[@]+-- "${user_args[@]}"}
godot_exit=$?
set -e

# Movie Maker names frames f00000000.png … f<frames-1>.png; take the last.
last_frame="$(ls "$tmp_dir"/f[0-9]*.png 2>/dev/null | sort | tail -n 1 || true)"
if [ -z "$last_frame" ]; then
	echo "capture.sh: no PNG frame written (godot exit $godot_exit)" >&2
	exit 3
fi
if [ "$godot_exit" -ne 0 ]; then
	echo "capture.sh: godot exited $godot_exit; discarding frames" >&2
	exit 3
fi

mv "$last_frame" "$kept"

# Blank check: a minimal PNG reader (no third-party packages), run with -I so
# nothing in the cwd shadows stdlib modules. Prints WxH and the number of
# distinct colours; exits 1 when every pixel is the same colour.
set +e
python3 -I - "$kept" <<'PY'
import struct, sys, zlib

path = sys.argv[1]
with open(path, "rb") as fh:
    data = fh.read()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    print("capture.sh: not a PNG: %s" % path, file=sys.stderr)
    sys.exit(1)

pos = 8
width = height = bit_depth = color_type = None
idat = bytearray()
while pos < len(data):
    length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
    body = data[pos + 8:pos + 8 + length]
    pos += 12 + length
    if ctype == b"IHDR":
        width, height, bit_depth, color_type, _c, _f, interlace = struct.unpack(">IIBBBBB", body)
        if bit_depth != 8 or interlace != 0:
            print("capture.sh: unsupported PNG (bit depth %s, interlace %s)" % (bit_depth, interlace), file=sys.stderr)
            sys.exit(1)
    elif ctype == b"IDAT":
        idat += body
    elif ctype == b"IEND":
        break

channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(color_type)
if channels is None or width is None:
    print("capture.sh: unsupported PNG colour type %s" % color_type, file=sys.stderr)
    sys.exit(1)

raw = zlib.decompress(bytes(idat))
stride = width * channels
prev = bytearray(stride)
colours = set()
offset = 0
for _row in range(height):
    ftype = raw[offset]
    line = bytearray(raw[offset + 1:offset + 1 + stride])
    offset += 1 + stride
    for i in range(stride):
        a = line[i - channels] if i >= channels else 0
        b = prev[i]
        c = prev[i - channels] if i >= channels else 0
        if ftype == 1:
            line[i] = (line[i] + a) & 0xFF
        elif ftype == 2:
            line[i] = (line[i] + b) & 0xFF
        elif ftype == 3:
            line[i] = (line[i] + ((a + b) >> 1)) & 0xFF
        elif ftype == 4:
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
            line[i] = (line[i] + pred) & 0xFF
    for x in range(0, stride, channels):
        colours.add(bytes(line[x:x + channels]))
    prev = line

print("capture.sh: %s %dx%d, %d distinct colours" % (path, width, height, len(colours)))
if len(colours) <= 1:
    print("capture.sh: capture is all one colour — blank frame", file=sys.stderr)
    sys.exit(1)
PY
blank_exit=$?
set -e
if [ "$blank_exit" -ne 0 ]; then
	exit 4
fi

echo "$kept"
