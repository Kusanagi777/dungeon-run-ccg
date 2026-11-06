#!/usr/bin/env bash
# tools/capture.sh — run-and-observe screenshot capture for Godot, on Linux/CI and
# on a Windows desktop.
#
# Usage:
#   bash tools/capture.sh <scene-res-path> <out-dir> [frames]
#   bash tools/capture.sh <scene-res-path> <out-dir> <frames> -- <godot user args...>
#   CAPTURE_LABEL=<nn>-<what> bash tools/capture.sh ...
#   CAPTURE_RENDERER=opengl3 bash tools/capture.sh ...
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
# Records <frames> frames (default 60) with Movie Maker mode, keeps the LAST
# frame as <out-dir>/01-<scene-basename>.png, writes <name>.renderer.txt beside
# it, deletes the other frames and the .wav, prints the kept path, and exits
# non-zero when no PNG was produced or the PNG is all one colour (blank capture).
# Frame and sidecar move into <out-dir> only after every check has passed, so a
# failed capture adds neither and leaves an earlier pair exactly as it was.
# Godot's stdout and stderr are logged and repeated on their own streams once it
# has exited, so nothing shows while it runs.
#
# The sidecar holds the OS, the exact Godot arguments and the engine's startup
# renderer lines; it is committed, so <repo>, <tmp> and <home> stand for this
# machine's paths. Its `renderer:` line comes from the last banner in the log, the
# `<API> <version> - <method> - Using Device...: <device>` line, so a silent fallback
# shows: `xvfb / opengl3 / llvmpipe` on Linux, and on Windows
# `windows / <asked for> (<rendering method>) / <device>`. No banner in the log keeps
# no frame; a line that only names a renderer is not one. On Windows that usually
# means GODOT_BIN names the GUI build, which prints nothing; name the *_console.exe.
#
# Linux/CI launches the scene windowed under Xvfb with the Compatibility (OpenGL 3)
# renderer. This is the command observed to work on 2026-11-03
# (docs/architecture/spikes/2026-11-03-engine-probes.md, Probe C):
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --windowed \
#     --resolution 1280x720 --rendering-driver opengl3 \
#     --write-movie <dir>/f.png --quit-after 60 res://<scene>.tscn
# Output is Compatibility/llvmpipe rendering, not the project's Forward+
# renderer: Forward+-only effects will not appear in CI evidence.
#
# Windows (Git Bash; `uname -s` is MINGW*, MSYS* or CYGWIN*) is ADR-0010 Decision
# 3's form, the same line without xvfb-run and without --rendering-driver: the
# project's Forward+ on the real GPU. CAPTURE_RENDERER=opengl3 adds
# `--rendering-driver opengl3`, Compatibility on the real GPU, still without Xvfb.
# Either frame with its sidecar is BLOCKING UI evidence (DD-X32, ADR-0010 erratum
# 2026-11-05). It goes through tools/bin/godot from the worktree root, because the
# wrapper keys `user://` on the current directory, not on --path. **It opens a real
# window on this desktop for the length of the run**, so it needs a desktop session:
# a service or a remote session with no display is exit 3 with Godot's error shown.
# The blank check runs under the first of python3, python and `py -3` that starts.
#
# `--headless --write-movie` crashes (exit 134); never add --headless here.
# Frames are the project viewport size (1280x720), not --resolution.
#
# Exit codes: 0 kept a non-blank PNG; 2 usage (incl. a bad CAPTURE_LABEL or
# CAPTURE_RENDERER; on Windows also no Godot or no Python that starts); 3 Godot
# failed, wrote no PNG or logged no renderer banner; 4 the PNG is all one colour or
# could not be decoded.
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

renderer="${CAPTURE_RENDERER:-}"
case "$renderer" in
	''|opengl3) ;;
	*) echo "capture.sh: CAPTURE_RENDERER must be unset or opengl3, got '$renderer'" >&2; exit 2 ;;
esac

windows=0
case "$(uname -s)" in
	MINGW*|MSYS*|CYGWIN*) windows=1 ;;
esac

# Asked for by running it, not by `command -v`: the Microsoft Store alias is on PATH
# whether or not a Python is installed. Before the launch, so no window opens for
# a capture that could not be checked.
python_cmd=(python3)
if [ "$windows" = 1 ]; then
	python_cmd=()
	for candidate in "python3" "python" "py -3"; do
		if $candidate -I -c pass > /dev/null 2>&1; then
			read -r -a python_cmd <<< "$candidate"
			break
		fi
	done
	if [ "${#python_cmd[@]}" -eq 0 ]; then
		echo "capture.sh: the blank check needs Python: none of python3, python, py -3 starts" >&2
		exit 2
	fi
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$out_dir"
out_dir="$(cd "$out_dir" && pwd)"
scene_base="$(basename "$scene" .tscn)"
kept="$out_dir/${label:-01-$scene_base}.png"
sidecar="${kept%.png}.renderer.txt"

# Record into a scratch dir inside out-dir so only the kept frame remains.
tmp_dir="$(mktemp -d "$out_dir/.capture-XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

if [ "$windows" = 1 ]; then
	launch=("$repo_root/tools/bin/godot" --path "$(cygpath -m "$repo_root")" --windowed --resolution 1280x720)
	if [ -n "$renderer" ]; then
		launch+=(--rendering-driver "$renderer")
	fi
	launch+=(--write-movie "$(cygpath -m "$tmp_dir/f.png")" --quit-after "$frames" "$scene")
else
	launch=(xvfb-run -a -s "-screen 0 1280x720x24"
		godot --path "$repo_root" --windowed --resolution 1280x720
		--rendering-driver opengl3
		--write-movie "$tmp_dir/f.png" --quit-after "$frames" "$scene")
fi
launch+=(${user_args[@]+-- "${user_args[@]}"})

set +e
if [ "$windows" = 1 ]; then
	# The paths are already drive paths; the switch keeps a user argument that starts
	# with `/` as it was written.
	(cd "$repo_root" && MSYS_NO_PATHCONV=1 "${launch[@]}") > "$tmp_dir/godot.out" 2> "$tmp_dir/godot.err"
else
	"${launch[@]}" > "$tmp_dir/godot.out" 2> "$tmp_dir/godot.err"
fi
godot_exit=$?
set -e
cat "$tmp_dir/godot.out"
cat "$tmp_dir/godot.err" >&2

# 127 is the wrapper's own "no engine found", and its message is the line above.
if [ "$windows" = 1 ] && [ "$godot_exit" -eq 127 ]; then
	exit 2
fi

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

# The engine's banner, the only line the gate accepts: a word such as `Vulkan` in an
# error or in a game's print is not a renderer. The last one is what ran, because a
# failed start can come before a fallback.
banner_pattern='^(Vulkan|D3D12|Metal|OpenGL API) .* - (Forward\+|Forward Mobile|Mobile|Compatibility) - Using Device( #[0-9]+)?: .+'
engine_log="$(cat "$tmp_dir/godot.out" "$tmp_dir/godot.err" | tr -d '\r')"
banner="$(printf '%s\n' "$engine_log" | grep -E "$banner_pattern" | tail -n 1 || true)"
if [ -z "$banner" ]; then
	echo "capture.sh: no renderer banner in Godot's log; discarding frames (on Windows, GODOT_BIN must name the *_console.exe)" >&2
	exit 3
fi

# The sidecar quotes more than the banner: a fallback warning belongs beside the line
# it led to.
renderer_lines="$(printf '%s\n' "$engine_log" \
	| grep -E 'Forward\+|Forward Mobile|Compatibility|Using Device|Vulkan|D3D12|Direct3D|OpenGL' \
	| head -n 5 || true)"
case "$renderer_lines" in
	*"$banner"*) ;;
	*) renderer_lines="$renderer_lines"$'\n'"$banner" ;;
esac

method="$(printf '%s\n' "$banner" | sed -E 's/.* - (Forward\+|Forward Mobile|Mobile|Compatibility) - Using Device.*/\1/')"
device="$(printf '%s\n' "$banner" | sed -E 's/.* - Using Device[^:]*: *//')"
if [ "$windows" = 1 ]; then
	summary="windows / ${renderer:-default} ($method) / $device"
else
	case "$device" in
		*llvmpipe*) device=llvmpipe ;;
	esac
	case "$method" in
		Compatibility) method=opengl3 ;;
	esac
	summary="xvfb / $method / $device"
fi

# Blank check, on the frame while it is still in the scratch dir: a minimal PNG
# reader (no third-party packages), run with -I so nothing in the cwd shadows stdlib
# modules. Prints WxH and the number of distinct colours; exits 1 when every pixel
# is the same colour.
set +e
"${python_cmd[@]}" -I - "$last_frame" "$kept" <<'PY'
import struct, sys, zlib

path = sys.argv[1]
kept = sys.argv[2]
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

print("capture.sh: %s %dx%d, %d distinct colours" % (kept, width, height, len(colours)))
if len(colours) <= 1:
    print("capture.sh: capture is all one colour — blank frame", file=sys.stderr)
    sys.exit(1)
PY
blank_exit=$?
set -e
if [ "$blank_exit" -ne 0 ]; then
	exit 4
fi

# `text` with this machine's paths taken out. The scratch dir first: it is usually
# inside the repository.
portable() {
	local text="$1" path
	for path in "$tmp_dir" "$(native_path "$tmp_dir")"; do
		text="${text//"$path"/<tmp>}"
	done
	for path in "$repo_root" "$(native_path "$repo_root")"; do
		text="${text//"$path"/<repo>}"
	done
	if [ -n "${HOME:-}" ]; then
		for path in "$HOME" "$(native_path "$HOME")"; do
			text="${text//"$path"/<home>}"
		done
	fi
	printf '%s' "$text"
}

# `path` as a Windows-side program spells it, or unchanged on Linux.
native_path() {
	if [ "$windows" = 1 ]; then
		cygpath -m "$1"
	else
		printf '%s' "$1"
	fi
}

portable_args=""
for arg in "${launch[@]}"; do
	quoted="$(printf '%q' "$(portable "$arg")")"
	quoted="${quoted//\\</<}"
	quoted="${quoted//\\>/>}"
	portable_args+="${portable_args:+ }$quoted"
done

# Every check has passed. Nothing reaches <out-dir> before this line.
{
	echo "os: $(uname -s -r)"
	echo "renderer: $summary"
	echo "godot arguments: $portable_args"
	echo "engine renderer lines:"
	portable "$renderer_lines"
	echo
} > "$tmp_dir/sidecar.txt"
mv "$tmp_dir/sidecar.txt" "$sidecar"
mv "$last_frame" "$kept"

echo "$kept"
