# Engine probes — Godot 4.7.2 on Linux (2026-11-03)

> **Spike note, not an ADR.** It has no Status and follows no ADR lifecycle; it
> is observed input for the ADRs that boss-ai.md C1.5 (planner threading),
> meta-progression.md M4 (rename atomicity) and `.claude/docs/run-and-observe.md`
> (capture command) defer to `/create-architecture` / `/architecture-decision`.

Three empirical spikes run on this container to turn "NOT SOURCEABLE" items in
the GDDs into observed behaviour. Everything below marked **observed** was run
on this machine today with the commands shown; everything marked **sourced**
cites a file under `docs/engine-reference/godot/`; anything neither observed nor
sourced is marked **NOT SOURCEABLE** and is not a claim.

Probe projects and raw logs live outside the repo at
`/tmp/claude-0/-home-user-dungeon-run-ccg/cb1e7c62-c2a7-52ec-b886-47b571cec227/scratchpad/probes/`
(`probe_a/`, `probe_b/`, `probe_c/`, `probe_c_compat/`, `probe_c_novkfallback/`,
`*.log`, `*.out`, `*.err`, `b_strace.txt`). They are scratch, not evidence.

## Environment

| Item | Value (observed) |
|---|---|
| Godot | `godot --headless --version` → `4.7.2.stable.official.ed1daf0bf`, Linux x86_64, at `~/.local/bin/godot`. Matches `docs/engine-reference/godot/VERSION.md` pin (**sourced**). |
| Kernel / OS | Linux 6.18.44-fc-v230, Ubuntu 24.04 userland |
| CPU threads | `OS.get_processor_count()` = 4 |
| Display | no X11/Wayland; `xvfb-run` from `xvfb 2:21.1.12-1ubuntu1.9` |
| GL | Mesa 25.2.8 (`libgl1-mesa-dri`), software **llvmpipe** (LLVM 20.1.2) via GLX on Xvfb |
| Vulkan | `libvulkan1 1.3.275` loader present, **no ICD** (`/usr/share/vulkan/icd.d/` absent) → no Vulkan device |
| `user://` | `/root/.local/share/godot/app_userdata/<project name>/`, filesystem reported as ext2/ext3 family by `stat -f` |
| Image tooling | Python 3.13 + Pillow 12.3.0, ImageMagick `identify`/`convert`, `strace` |

Engine-reference coverage check (grep of `docs/engine-reference/godot/` for
`WorkerThreadPool`, `Thread`, `rename_absolute`, `DirAccess`, `FileAccess`,
`write-movie`, `fixed-fps`, `rendering-driver`, `gl_compatibility`, `xvfb`):

- Threading / `WorkerThreadPool` / `Thread`: **no mention anywhere** → NOT SOURCEABLE from the reference; this spike is the only local evidence. Matches boss-ai.md C1.5's own note.
- `FileAccess.store_*` returning `bool` since 4.4: `breaking-changes.md`, "4.3 → 4.4" Core row (**sourced**).
- `DirAccess.rename*`, atomicity, Windows semantics: **no mention** → NOT SOURCEABLE.
- `--write-movie`, `--fixed-fps`, `--rendering-driver`: not in the reference; `current-best-practices.md` § "Command Line — Tests and Parse Check" lists `--headless`, `--path`, `--quit-after`, `--import` etc. (**sourced** for those flags only). `.claude/docs/run-and-observe.md` § "Godot 4 — zero scaffold" describes `--write-movie` behaviour (project doc, not engine reference) and is **confirmed by observation** below.
- Renderer names: `modules/rendering.md` § "Rendering Backend Selection (4.6)" lists Forward+ / Mobile / Compatibility (OpenGL 3.3) (**sourced**).

---

## Probe A — Boss AI planner off the main thread (boss-ai GDD C1.5; `.claude/rules/ai-code.md` 2 ms/frame)

### Method

Minimal headless project (`probe_a/`), one `Node` main scene. Workload is a
`RefCounted` subclass (`Planner`) touching only a `Dictionary` and an
`Array[int]` — 2,000,000 integer mix-and-mask iterations, deterministic
checksum, no Node or SceneTree access from the worker. Each mechanism was
compared against a main-thread baseline checksum. Run twice.

```
cd probe_a && godot --headless --path . --import
godot --headless --path .            # main scene runs, prints, get_tree().quit(0)
```

### Results (observed, run 1 / run 2; checksum `1045393980` in every case)

| Mechanism | Exact API | Result == baseline | Ran on main thread? | Time |
|---|---|---|---|---|
| Baseline | main thread, synchronous | — | yes | 72.6 / 69.8 ms |
| Worker pool, blocking wait | `WorkerThreadPool.add_task(callable, true, "desc") -> int`, `WorkerThreadPool.wait_for_task_completion(id) -> Error` | **yes** | **no** (`OS.get_thread_caller_id() != OS.get_main_thread_id()`) | 79.4 / 70.5 ms (first-ever run in a fresh process: 140.7 ms) |
| Worker pool, polled per frame (C1.5 driver shape) | `add_task` → each frame `WorkerThreadPool.is_task_completed(id)` → `await get_tree().process_frame` → finally `wait_for_task_completion(id)` | **yes** | no | 76.7 / 90.5 ms, 14 / 16 frames waited |
| Dedicated thread, blocking | `Thread.new()`, `thread.start(callable, Thread.PRIORITY_NORMAL) -> Error` (returned `OK`), `thread.wait_to_finish() -> Variant` (the callable's return value) | **yes** | no | 74.8 / 68.9 ms |
| Dedicated thread, polled | `thread.is_alive()` per frame, then `wait_to_finish()` | **yes** | no | 76.1 / 76.2 ms, 13 frames |
| Time-sliced coroutine, 2 ms budget, chunk 20,000 iters | `await get_tree().process_frame` from a Node | **yes** | yes | 50–51 frames, **max slice 3.6–4.8 ms (over budget)** |
| Time-sliced coroutine, 2 ms budget, chunk 1,000 iters | same | **yes** | yes | 82–83 frames, max slice **2.09–2.11 ms** |
| Determinism | 3 more `add_task` runs | all equal | — | — |

Warnings / errors printed:

- First draft called `WorkerThreadPool.is_task_completed(id)` **after**
  `wait_for_task_completion(id)`: prints `ERROR: Invalid Task ID at:
  is_task_completed (core/object/worker_thread_pool.cpp:397)`. The id is
  released by `wait_for_task_completion`; poll before, never after. Fixed
  script printed nothing on stderr in either run.
- No warning about `RefCounted` / `Dictionary` / `Array` use from a worker
  thread. No `Node` was touched from the worker (not tested; the GDD forbids it).
- Headless frame pacing: `Engine.max_fps` = 0; 60 awaited frames took ~345 ms
  here (≈6–7 ms/frame), so frame counts above are not wall-clock-comparable to
  a 60 Hz client.

### Verdict A

All three mechanisms exist and work on 4.7.2. A RefCounted-only planner returns
a deterministic result from a worker thread with no warnings. **Preferred for
C1.5:** `WorkerThreadPool.add_task` + per-frame `is_task_completed` poll +
`wait_for_task_completion` on completion — zero thread lifecycle to manage,
main-thread cost per frame is one poll. `Thread` works identically if an ADR
prefers an owned thread. The time-sliced coroutine also works but its slice
granularity has to be finer than 2 ms of work (chunk ≈1k ops here) or it
overshoots; the planner's inner loop would have to be rewritten as resumable,
which the worker options avoid. Threading on 4.7.2 is **NOT SOURCEABLE** from
`docs/engine-reference/godot/` — this spike is the only local evidence, and it
is single-machine, 4 cores.

---

## Probe B — Atomic profile write (meta-progression M1/M4/M6: tmp → rename)

### Method

Headless `SceneTree` script (`probe_b/probe_b.gd`) against `user://`:

```
cd probe_b && godot --headless --path . --import
godot --headless --path . -s res://probe_b.gd
strace -f -e trace=rename,renameat,renameat2,openat,fsync,fdatasync,close godot --headless --path . -s res://probe_b.gd
```

Write helper: `FileAccess.open(p, FileAccess.WRITE)` → `store_string()` →
`get_error()` → `flush()` → `close()`. Reads back `get_as_text()` after every rename.

### Results (observed)

| Step | Call | Return / state |
|---|---|---|
| Write tmp | `store_string` → `true`; `get_error()` after store and after flush → `0 (OK)` | matches `breaking-changes.md` 4.4 row (**sourced**) |
| Rename, target absent | `DirAccess.rename_absolute("user://profile.json.tmp", "user://profile.json")` | `0 (OK)`; final exists, tmp gone, content = new |
| Rename **over existing** target | `DirAccess.rename_absolute(tmp, final)` | `0 (OK)`, **no error, tmp gone, final content = new** |
| Relative form | `DirAccess.open("user://")` (non-null, `get_open_error()` = 0) then `.rename("profile.json.tmp", "profile.json")` | `0 (OK)`, same replace behaviour |
| M4 chain | `rename_absolute(final, bak)` then `rename_absolute(tmp, final)` | both `0`; bak = previous final, final = new |
| M4 chain with `.bak` already present | same | both `0 (OK)` — `.bak` replaced |
| Missing source | `rename_absolute("user://does_not_exist.tmp", final)` | `1 (Failed)` = `ERR_FAILED`; target untouched |
| Target in missing dir | `rename_absolute(final, "user://no_such_dir/profile.json")` | `1 (Failed)`; source still present |
| `FileAccess.open(WRITE)` into missing dir | returns `null`; `FileAccess.get_open_error()` = `7 (File not found)` = `ERR_FILE_NOT_FOUND` | **parent dirs are not created** |
| `FileAccess.open(READ)` missing file | `null`, `get_open_error()` = `7` | |
| `FileAccess.open(READ_WRITE)` missing file | `null`, `get_open_error()` = `7` | |
| `FileAccess.open(READ)` existing | non-null, `get_open_error()` = `0` | |
| `DirAccess.make_dir_recursive_absolute("user://runs")` then write | `0`, write OK | the fix for the missing-dir case (M8 `user://runs/`) |

`strace` (observed): every `rename_absolute` / `rename` is a single POSIX
`rename(2)` on the globalised paths (`rename(".../profile.json.tmp",
".../profile.json") = 0`; missing-source case `= -1 ENOENT`). The tmp file is
opened with `O_WRONLY|O_CREAT|O_TRUNC`. **No `fsync`/`fdatasync` appears for
`flush()` or `close()`** — Godot's `flush()` is a user-space/stdio flush, not a
durability barrier.

### Verdict B

On Linux, `DirAccess.rename_absolute(tmp, final)` (and `DirAccess.rename`)
**replaces an existing file with no error and the new content, and is a single
`rename(2)` call** — so the visible swap is as atomic as POSIX `rename(2)` on the
filesystem in use. Error codes: rename failure → `ERR_FAILED` (1), no
`ERR_FILE_NOT_FOUND` distinction; open into a missing directory →
`get_open_error()` `ERR_FILE_NOT_FOUND` (7), and the directory must be created
with `make_dir_recursive_absolute` first.

NOT SOURCEABLE (do not assume):
- **Crash durability**: with no fsync, a power loss after rename can leave a
  zero-length or stale `profile.json` depending on filesystem and mount options;
  GDScript exposes no fsync. The M4 `.bak` step is the only mitigation available
  in-engine. Not testable here.
- **Windows** `rename_absolute` over an existing file (MoveFileEx semantics,
  antivirus locks, error code): no engine-reference page covers it; not run here.
- Behaviour on exFAT/NTFS/network shares or Steam Cloud-synced folders.

---

## Probe C — Renderer vs Xvfb screenshot capture (`.claude/docs/run-and-observe.md`; match-ui fixtures)

### Method

`probe_c/`: a `Control` main scene — full-screen dark `ColorRect`, red/green/blue
`ColorRect`s at known positions, a `Label` — with
`display/window/size/viewport_width=1280`, `viewport_height=720` and
`rendering/renderer/rendering_method="forward_plus"`. `probe_c_compat/` is the
same with `rendering_method="gl_compatibility"`; `probe_c_novkfallback/` is
Forward+ plus `rendering/rendering_device/fallback_to_opengl3=false`.

Base command for every row (only the renderer/driver part varies):

```
xvfb-run -a -s "-screen 0 1280x720x24" \
  godot --path . --windowed --resolution 1280x720 [variant flags] \
  --write-movie out/<name>/f.png --quit-after 60 res://main.tscn
```

Verification: Pillow — frame size, per-channel extrema (non-black), pixel
samples at the three rectangles, count of non-background pixels in the Label's
rect.

### Results (observed; all PNGs checked were 1280x720, 8-bit sRGB, 10,592 B)

| # | Project setting | Flags | Exit | Frames | Driver actually used (printed by scene) | Non-black / rects / label | Wall |
|---|---|---|---|---|---|---|---|
| 1 | `forward_plus` | none | **0** | `f00000000.png`…`f00000059.png` + `f.wav` (61 files) | **opengl3 / gl_compatibility / llvmpipe** — silent fallback | yes / (230,51,51) (51,204,77) (51,102,242) / 1,267 px | 7.6 s (cold shader cache) |
| 2 | `forward_plus` | `--rendering-driver opengl3` | **0** | 61 | opengl3 / gl_compatibility / llvmpipe | yes, identical pixels | 2.4 s |
| 3 | `forward_plus` | `--rendering-driver vulkan` | **0** | 61 | **opengl3** — the flag is overridden by the same fallback | yes, identical | 2.4 s |
| 4 | `gl_compatibility` | none | **0** | 61 | opengl3 / gl_compatibility / llvmpipe, no Vulkan errors in log | yes, identical | 2.4 s |
| 5 | `gl_compatibility` | `--fixed-fps 30` | 0 | 61, log says `@ 30 FPS`, "movie length 00:00:02:00" | same | yes | 2.4 s |
| 6 | `gl_compatibility` | `--rendering-driver opengl3` | 0 | 61 | same | yes | 2.4 s |
| 7 | `forward_plus` + `fallback_to_opengl3=false` | none | **1** | 0 (dir empty) | — | — | 0.09 s |
| 8 | same as 7 | `--rendering-driver vulkan` | **1** | 0 | — | — | 0.09 s |
| 9 | `forward_plus` | `--headless` (no xvfb) | **134 (SIGABRT, signal 11 crash handler)** | only a 0-byte `f.wav` | dummy rasterizer, window (0,0), viewport 64x64 | — | 0.15 s |
| 10 | `forward_plus` | `--resolution 640x360` | 0 | 61 | fallback as #1 | PNG is **1280x720** (viewport size), window was 640x360 | 2.8 s |
| 11 | `forward_plus` | no `xvfb-run`, no DISPLAY | 1 | 0 | — | — | 0.07 s |

Log excerpts (stdout; stderr was empty for rows 1–6):

- Rows 1, 3, 10 (Forward+ under Xvfb):
  `ERROR: Required Vulkan instance extension VK_KHR_surface not found. at: _initialize_instance_extensions (drivers/vulkan/rendering_context_driver_vulkan.cpp:494)` →
  `WARNING: Your video card drivers seem not to support the required Vulkan version, switching to OpenGL 3. at: DisplayServerX11 (platform/linuxbsd/x11/display_server_x11.cpp:7124)` →
  `WARNING: Could not set V-Sync mode ... (gl_manager_x11.cpp:372)` →
  `OpenGL API 4.5 (Core Profile) Mesa 25.2.8 ... Using Device: Mesa - llvmpipe`.
  Then `Movie Maker mode enabled, recording movie in 1280×720 @ 60 FPS...` and
  `60 frames at 60 FPS ... CPU render time ... GPU render time: avg 3.8–4.3 ms/frame, Encoding time: avg 22 ms/frame`.
- Rows 7–8 (fallback disabled): same two Vulkan ERRORs, then the plain-text
  `Your video card drivers seem not to support the required Vulkan version ... --rendering-driver opengl3`, `ERROR: Could not initialize vulkan`, exit 1, no frames.
- Row 9 (`--headless`): `ERROR: Parameter "t" is null. at: texture_2d_get (./servers/rendering/dummy/storage/texture_storage.h:110)` then `handle_crash: Program crashed with signal 11`. Confirms run-and-observe's "never use `--headless`" row.
- Row 11: `ERROR: X11 Display is not available` → `Display driver x11 failed, falling back to wayland` → `Can't connect to a Wayland display` → `Unable to create DisplayServer, all display drivers failed`. Confirms "Linux CI with no display needs `xvfb-run`".

`--write-movie` and `--fixed-fps` (observed from `godot --help`):
`--write-movie <file>  Write a video to the specified path (usually with .avi
or .png extension). --fixed-fps is forced when enabled, but it can be used to
change movie FPS. --quit-after can be used to specify the number of frames to
write.` So `--fixed-fps` is **not required**; it defaults to 60 under
`--write-movie` and only changes the frame rate (row 5). Frame 0 was already
fully rendered and identical to frame 59 for this static scene (row 2 checked
`f00000000.png`, `f00000001.png`, `f00000059.png`: all 1,267 label pixels, same
extrema).

### Verdict C

Under Xvfb on this container, **every** display-backed combination produces a
correct 1280x720 non-black PNG with exit 0, because Godot 4.7.2 silently falls
back from Vulkan to OpenGL 3 / Compatibility when no Vulkan ICD exists (project
setting `rendering/rendering_device/fallback_to_opengl3`, default on). The
recommended, explicit command — identical output, no Vulkan error noise in the
log, and 3x faster than the cold Forward+ run:

```
xvfb-run -a -s "-screen 0 1280x720x24" \
  godot --path . --windowed --resolution 1280x720 --rendering-driver opengl3 \
  --write-movie out/f.png --quit-after 60 res://main.tscn
# → out/f00000000.png … out/f00000059.png (take the last), out/f.wav; exit 0; ~2.4 s
```

Consequences for match-ui fixtures: screenshots taken this way are rendered by
the **Compatibility** renderer on llvmpipe, not the project's Forward+ renderer.
Anything Forward+-only (glow/HDR/3D lighting, Forward+-specific shaders) will
look different or be absent in CI evidence; 2D `Control`/`ColorRect`/`Label`
output matched the expected colours exactly here. Frame size follows the
project viewport, not `--resolution` (row 10), as run-and-observe already says.

NOT SOURCEABLE:
- Whether a lavapipe (Mesa software Vulkan) ICD, if installed, would let
  Forward+ render under Xvfb — no ICD is present here; not tested.
- Windows/macOS capture behaviour and Forward+ output parity with the CI frames.
- The fallback setting's exact name/default is taken from the running engine's
  behaviour with `rendering_device/fallback_to_opengl3=false` (row 7 proves the
  key is honoured); it is not in `docs/engine-reference/godot/`.

---

## Verified API / command list (4.7.2, this machine)

GDScript:
- `WorkerThreadPool.add_task(Callable, high_priority: bool, description: String) -> int`
- `WorkerThreadPool.is_task_completed(int) -> bool` (only before `wait_for_task_completion`)
- `WorkerThreadPool.wait_for_task_completion(int) -> Error` (returned `OK`)
- `Thread.new().start(Callable, Thread.PRIORITY_NORMAL) -> Error`, `is_started()`, `is_alive()`, `get_id()`, `wait_to_finish() -> Variant`
- `OS.get_thread_caller_id()`, `OS.get_main_thread_id()`, `OS.get_processor_count()`
- `await get_tree().process_frame` inside a `Node` method
- `FileAccess.open(path, FileAccess.WRITE | READ | READ_WRITE)` (null on failure), `FileAccess.get_open_error()`, `store_string() -> bool`, `get_error()`, `flush()`, `close()`, `get_as_text()`, `FileAccess.file_exists()`
- `DirAccess.rename_absolute(from, to) -> Error`, `DirAccess.open(path)` + `.rename(a, b)`, `DirAccess.get_open_error()`, `DirAccess.remove_absolute()`, `DirAccess.make_dir_recursive_absolute()`, `DirAccess.get_files_at()`
- `ProjectSettings.globalize_path("user://")`, `error_string(int)`
- `RenderingServer.get_current_rendering_driver_name()`, `get_current_rendering_method()`, `get_video_adapter_name()`, `DisplayServer.get_name()`, `DisplayServer.window_get_size()`

Command line:
- `godot --headless --path . --import` (exit 0 in all five projects)
- `godot --headless --path .` / `godot --headless --path . -s res://<script>.gd`
- `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --windowed --resolution 1280x720 --rendering-driver opengl3 --write-movie <dir>/f.png --quit-after 60 res://main.tscn`
- `--fixed-fps <n>` optional with `--write-movie`; `--rendering-driver vulkan` is silently overridden when Vulkan is unavailable unless `rendering/rendering_device/fallback_to_opengl3=false`, in which case exit 1 with `ERROR: Could not initialize vulkan`.
- `--headless` + `--write-movie` crashes (exit 134); never use for capture.
