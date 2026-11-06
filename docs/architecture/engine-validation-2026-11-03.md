# Engine Validation — godot-specialist consultation over the Accepted ADRs

| Field | Value |
|---|---|
| **Date** | 2026-11-03 |
| **Engine pin** | Godot 4.7 (`docs/engine-reference/godot/VERSION.md`); installed `4.7.2.stable.official.ed1daf0bf`, Linux x86_64, on PATH — matches the pin |
| **Reviewer** | `godot-specialist` (orchestrated run under the owner's standing approval; no `Agent` tool used, no ADR edited) |
| **Scope** | ADR-0006, ADR-0009, ADR-0010, ADR-0011 — **Engine Compatibility** and **Decision** sections, read by heading; ADR-0004 "Decision addendum (2026-11-03) — input remapping storage"; spot-checks of ADR-0001 grep gates G1–G6 and ADR-0003's per-stream `RandomNumberGenerator` claim |
| **Closes** | The **NOT ASSESSED** "Engine Specialist Findings" item of `docs/architecture/architecture-review-2026-11-03.md` (§ line 180) and `architecture-review-2026-11-03b.md` (§ lines 178, 193–198), and **TD-PHASE-GATE (Technical Setup → Pre-Production) entry condition 6** ("Engine-specialist pass. Spawn `godot-specialist` once over ADR-0006/0009/0010/0011 … record the result in the next architecture-review report"). The next `/architecture-review` run should fold the verdict table below into its Engine Specialist section |

## Method

Every engine claim in the reviewed sections was classified as one of:

- **SOURCED** — a file under `docs/engine-reference/godot/` (cited `file:line`) or a probe row in `docs/architecture/spikes/2026-11-03-engine-probes.md` (cited `spike:line`).
- **OBSERVED (this review)** — not in the reference; run today on the installed 4.7.2 with the probe in `…/scratchpad/probe_v/` (`probe_v.gd`, `probe_v2.gd`, `syn_*.gd`; command `godot --headless --path . --import` then `godot --headless --path . -s res://probe_v.gd`). Scratch, not evidence; the durable record is this file plus the tests it names.
- **NOT SOURCEABLE** — neither; the test that would prove it is named.
- **CONTRADICTED** — the reference or an observation says otherwise; the quote is given.

Reference files read whole (all under 12 KB): `VERSION.md`, `deprecated-apis.md`, `breaking-changes.md`, `current-best-practices.md`, `modules/animation.md`, `modules/input.md`, `modules/rendering.md`, `modules/ui.md`, and the spike file. Abbreviations below: `cbp` = `current-best-practices.md`, `bc` = `breaking-changes.md`, `dep` = `deprecated-apis.md`, `spike` = `spikes/2026-11-03-engine-probes.md`.

## Verdict table

| ADR | Verdict | One-line reason |
|---|---|---|
| ADR-0006 Boss AI planner threading | **REVISE** | The design works on 4.7.2 (observed: worker, immediate and time-sliced shapes all return the plan), but the call shape the ADR writes — `func(): return boss_ai.plan_turn(sandbox)` — is a **parse error** on 4.7.2 because `plan_turn` awaits `checkpoint()` and is therefore a coroutine; `await` must appear at that call site and at every caller up the chain, which ADR-0001's G2b gate forbids as written |
| ADR-0009 Match UI animation queue + scene partition | **APPROVE WITH NOTES** | Every post-cutoff API is sourced and exists on 4.7.2; notes are the one-line `@abstract` spelling (observed equivalent), the `apply_final` lambda capture rule, and a `_process` gating suggestion |
| ADR-0010 Renderer choice vs Xvfb capture | **APPROVE** | Every claim is sourced or observed in Probe C; `project.godot` matches what the ADR asserts; one cosmetic wording note on the AA line |
| ADR-0011 Run UI shell + Meta stub seam | **APPROVE WITH NOTES** | All sourced; the two NOT SOURCEABLE items are now observed (`Control.focus_behavior_recursive` / `mouse_behavior_recursive`; typed `Dictionary[StringName, PackedScene]` parses) — add them to the Engine Compatibility table on the next touch |
| ADR-0004 addendum — input remapping storage | **APPROVE WITH NOTES** | `InputMap.action_erase_events` / `action_add_event` exist; the 4.7 device-id change does not break bindings rebuilt without a `device` field for keyboard/mouse (observed); joypad device handling and JSON `float` → `int` coercion of keycodes need the named tests; the ADR's Engine Compatibility table does not yet list these claims |
| ADR-0001 grep gates G1–G6 (spot-check) | **REVISE** (G2b only) | G2b's pattern uses a negative lookahead that the installed ripgrep 14.1.0 rejects (`look-around … is not supported`, exit 2), and its allow-list contradicts the coroutine propagation ADR-0006 requires; G1/G2/G6 have advisory gaps |
| ADR-0003 per-stream `RandomNumberGenerator` (spot-check) | **APPROVE WITH NOTES** | Golden pin re-observed (`seed = 42` → `492690617, 1919685028, 3561993920`, two instances equal); the probe D/E record lives only inside the ADR and a scratch file — move it into the spike file until `rng_engine_pins_test.gd` lands |

Deprecated APIs (`dep`): **none used** by any reviewed ADR. Idioms `cbp` warns against: **none violated**; see the per-ADR notes for the two places the ADRs lean on an idiom `cbp` describes (lambda capture by value; the `@abstract` spelling).

---

## ADR-0006 — Boss AI planner threading

### (a) Engine claims

| # | Claim (section) | Status | Citation / test |
|---|---|---|---|
| 1 | `WorkerThreadPool.add_task(callable, false, "boss_ai") -> int`, one `is_task_completed(id)` per `tick()`, `wait_for_task_completion(id)` exactly once after completion (Decision) | SOURCED (observed in spike) | `spike:64–65`, `spike:261–263`; signature `add_task(Callable, high_priority: bool, description: String) -> int` |
| 2 | `is_task_completed` after `wait_for_task_completion` prints `ERROR: Invalid Task ID` (Decision, Guidelines) | SOURCED | `spike:74–78` |
| 3 | Checksum `1045393980`, 70–90 ms off-thread, 14–16 frames polled, no stderr (Decision) | SOURCED | `spike:59`, `spike:64–65` |
| 4 | Time-sliced fallback: 1,000-op chunks hold 2.09–2.11 ms, 20,000-op chunks overshoot to 3.6–4.8 ms (Decision) | SOURCED | `spike:68–69` |
| 5 | `Thread.start / is_alive / wait_to_finish` as the Alternative-2 shape (Engine Compat) | SOURCED | `spike:66–67`, `spike:264` |
| 6 | `OS.get_thread_caller_id()` / `OS.get_main_thread_id()` (Engine Compat) | SOURCED | `spike:265`; re-observed today (`off_main=true` inside the task) |
| 7 | `@abstract class_name PlannerTask extends RefCounted` with `@abstract func start(work: Callable) -> void` (Key Interfaces) | SOURCED + OBSERVED | `cbp:32–40` (the reference writes `@abstract` on its own line; the ADR's one-line form loads, `is_abstract()` is `true`, and a subclass missing an override fails to parse: `Class "…" must implement "ProbeAbstractOneLine.start()" and other inherited abstract methods or be marked as "@abstract"`). Note: enforcement is **parse-time** — a statically typed `X.new()` fails with `Cannot construct abstract class "X"`, but `load(path).new()` on the abstract script instantiated without error on 4.7.2 |
| 8 | Every override of a typed method ends in an explicit `return` (Key Interfaces comment, Guidelines) | SOURCED + OBSERVED | `bc:17`, `cbp:45–46`; observed `Parse Error: Not all code paths return a value` on `func result() -> Variant: pass` |
| 9 | `signal _resume` + `_resume.emit()` inside `poll()` "resumes the coroutine synchronously inside poll()" (Key Interfaces) | OBSERVED | Not in the reference. Probe: `start` ran to the first `await resume` (`yields=1`), each `emit()` resumed synchronously, `done=true result=10 polls=5 yields=5` |
| 10 | `_result = await work.call()` where `work` is a lambda wrapping the plan (Time-sliced `_run`) | OBSERVED | Works when the lambda is itself `func(): return await plan(...)` (see claim 12) |
| 11 | `ImmediatePlannerTask.start`: `_result = work.call()` returns the plan directly (Key Interfaces) | OBSERVED | A coroutine that never suspends (no-op `checkpoint()`) returns its value directly: `result=45 type=int` on the main thread and `result=45 type=int off_main=true` inside the worker task |
| 12 | The diagram's `task.start(func(): return boss_ai.plan_turn(sandbox))`, `play_turn` "= plan_turn on engine.clone() + replay", and `BossAI` "awaits `planner.checkpoint()` between candidate evaluations (C4–C6 `score_all`) and between lethal-search nodes (C3)" (Decision, Diagram, Key Interfaces, Guidelines) | **CONTRADICTED (observed)** | 4.7.2: `SCRIPT ERROR: Parse Error: Function "plan()" is a coroutine, so it must be called with "await".` Any function containing `await` is a coroutine and every **statically resolved** call to it must be `await`ed; the requirement propagates up the call chain. So: `score_all` and the lethal search (they await `checkpoint()`) are coroutines → `plan_turn` must `await` them → `plan_turn` is a coroutine → the task lambda must read `func(): return await boss_ai.plan_turn(sandbox)` → `play_turn`, the sim harness and unit tests that call `plan_turn` must `await` it. Only dynamic calls through a `Callable` (`work.call()`) escape the static check, which is why claims 10–11 work. The runtime behaviour the ADR wants is confirmed (claims 9–11); the code shape and the G2b gate are not |
| 13 | `RulesEngine.clone()` is a deep copy (Decision) | NOT SOURCEABLE | `dep:33` (`duplicate()` → `duplicate_deep()`) applies to `Resource`, not `RefCounted`; `clone()` must be hand-written (`Dictionary.duplicate(true)` for nested state is 4.0-era, unverified here). Test: the ADR's own determinism test plus "mutating the clone leaves the live engine's `MatchState` and hook table byte-identical" |
| 14 | `RefCounted` reference counts are atomic (Thread-safety argument) | NOT SOURCEABLE | ADR already labels it training-data; test = Verification (4) stress run, and `--debug` run checking stderr for leaked-instance warnings at exit |
| 15 | Concurrent read-only `Dictionary` access is safe (Thread-safety argument) | NOT SOURCEABLE | ADR says so; Verification (4) |
| 16 | A `WorkerThreadPool` task cannot be cancelled, only awaited (Guidelines) | NOT SOURCEABLE | No reference page; consistent with `spike:261–263` (no cancel API exercised). Design assumes the stricter case, so no test needed |
| 17 | `Time.get_ticks_usec()` (Time-sliced task) | NOT SOURCEABLE (LOW) | `dep:32` names the `Time` singleton as the replacement for `OS.get_ticks_msec()`; `get_ticks_usec` itself is not listed. Test: parse check |
| 18 | Windows `WorkerThreadPool` behaviour; `tests/unit/**` never start a worker (Engine Compat, Guidelines) | NOT SOURCEABLE | ADR gates it to the Windows run; agreed |

### (b) Deprecated APIs — none. `yield`, string `connect`, `OS.get_ticks_msec` all absent.

### (c) `cbp` idioms — the ADR's `await planner.checkpoint()` on a base whose implementation is a plain no-op produced no warning on stderr in the headless run; if the project turns on `REDUNDANT_AWAIT`-class warnings as errors, keep `checkpoint()` declared on the abstract base (dynamic dispatch) exactly as the ADR does.

### (d) Verdict: **REVISE** — textual, not architectural

Fix (all in ADR-0006 unless noted):

1. Diagram and Key Interfaces: write the task lambda as `func() -> Variant: return await boss_ai.plan_turn(sandbox)`; declare `plan_turn`, `play_turn`, `score_all` and the lethal search as coroutines in the comments ("contains `await`; callers must `await`"); state that `ImmediatePlannerTask` and the worker receive the value directly because the no-op `checkpoint()` never suspends (observed).
2. Move the lambda construction into `src/ai/` so `src/gameplay/run/match_driver.gd` stays `await`-free: e.g. `BossAI.plan_task(sandbox: RulesEngine) -> Callable` returns the lambda; `MatchDriver` calls `task.start(boss_ai.plan_task(sandbox))`. Otherwise G2b's `src/gameplay/**` scope flags the driver.
3. Verification: add "the first BossAI unit test `await`s `plan_turn` and the parse check passes with no `await`-less coroutine call" — this is the test that would have caught claim 12.
4. ADR-0001 G2b must change in step (see below).

---

## ADR-0009 — Match UI animation queue + scene partition

### (a) Engine claims

| # | Claim | Status | Citation / test |
|---|---|---|---|
| 1 | `Tween.tween_await()` pauses a tween until a signal is emitted (4.7) | SOURCED + OBSERVED | `modules/animation.md:8`, `cbp:110`; `ClassDB.class_has_method("Tween","tween_await") == true` |
| 2 | `tween_await` timeout semantics when the signal never fires | NOT SOURCEABLE | ADR says so; its test (step still ends at `d_eff` by the queue clock) is the right one |
| 3 | `Control.offset_transform_enabled / _position / _scale / _rotation` — containers do not reset them | SOURCED + OBSERVED | `modules/ui.md:15–16`, `cbp:138–141`; observed property set on 4.7.2: `offset_transform_enabled, _position, _position_ratio, _scale, _rotation, _pivot, _pivot_ratio, _visual_only` |
| 4 | Survives an `HBoxContainer` re-layout mid-tween | NOT SOURCEABLE (in principle sourced) | ADR's Verification (1) test stands |
| 5 | Dual focus (4.6): focus ring from keyboard focus only; `grab_focus()` moves keyboard focus only | SOURCED | `modules/ui.md:19–21, 47–60`, `cbp:130–134`, `bc:55` |
| 6 | `@abstract class_name Presenter extends Control`, `@abstract func …` | SOURCED + OBSERVED | `cbp:32–40`; one-line spelling observed equivalent (ADR-0006 claim 7) |
| 7 | Typed-return override rule | SOURCED + OBSERVED | `bc:17`, `cbp:45–46` |
| 8 | `RichTextLabel.add_image(width_unit / height_unit)` rename | SOURCED | `dep:38`, `bc:20`, `modules/ui.md:8–11` |
| 9 | `CanvasItem` lines have no antialiasing feather in 4.7 | SOURCED | `bc:31`, `cbp:76–77`, `modules/rendering.md:11` |
| 10 | Identify events by type, never `event.device == 0` | SOURCED | `dep:53`, `modules/input.md:8–10`, `bc:24` |
| 11 | `create_tween()`, `Tween.kill()`, `AnimationPlayer`, `CanvasModulate`, `theme_type_variation`, `OS.is_debug_build()` — "4.0-era, training data" | NOT SOURCEABLE (LOW), partly OBSERVED | Not in the reference. Observed: `CanvasModulate` parent class is `Node2D` (placing it under a `Control` root is legal; it modulates the canvas it lives in). Test: a fixture capture with `gamma != 1.0` shows the whole `MatchView` modulated |
| 12 | `OS.get_cmdline_user_args()` for `--fixture=…` after `--` | OBSERVED | `ClassDB.class_has_method("OS","get_cmdline_user_args") == true` |
| 13 | Export-preset exclude filter syntax for `match_debug_loader.gd` | NOT SOURCEABLE | ADR says so; `.pck` listing grep is the right test |
| 14 | `TargetingArrow` "`_draw` each frame while active" | NOT SOURCEABLE (LOW) | `_draw` runs only after `queue_redraw()`; the presenter must call it per frame while active. Test: the arrow follows the mouse in a `--pose=targeting` capture |

### (b) Deprecated APIs — none; the ADR explicitly bans `yield()`, string `connect`, `$NodePath` in `_process`, untyped containers (`dep:27–28, 48–49`).

### (c) `cbp` idioms

- `cbp:19–30` (lambdas capture locals **by value**): `AnimStep.apply_final: Callable` is built inside `MatchViewState.apply()`. It may read captured values but must not try to reassign a captured local; share through the step's own fields or a Dictionary. Worth one sentence in Guidelines.
- `cbp:32–40`: the reference's `@abstract` example is two lines; the ADR's one-line form is observed equivalent — no change needed.

### (d) Verdict: **APPROVE WITH NOTES**

Notes (non-blocking): (1) add the lambda-capture sentence to Guidelines; (2) `MatchView._process` runs `controller.tick()` + `queue.advance(delta)` every frame — consider `set_process(false)` when the queue is idle **and** `driver.is_planning()` is false, re-enabled on `enqueue` / `submit` (specialist best practice, not an engine claim); (3) record claim 11's `CanvasModulate` parent-class observation in the Engine Compatibility table.

---

## ADR-0010 — Renderer choice vs Xvfb screenshot capture

### (a) Engine claims

| # | Claim | Status | Citation |
|---|---|---|---|
| 1 | Renderers: Forward+ / Mobile / Compatibility (OpenGL 3.3 / WebGL 2) | SOURCED | `modules/rendering.md:56–64` |
| 2 | D3D12 is the default backend on Windows since 4.6 | SOURCED | `modules/rendering.md:17, 63`, `bc:52`, `cbp:83` |
| 3 | `CanvasItem` lines without feather; `LinearToSRGB` no clamp | SOURCED | `bc:31–32`, `cbp:76–79` |
| 4 | New-project stretch defaults `canvas_items` / `expand`; this project keeps `canvas_items` / `keep` | SOURCED + OBSERVED | `bc:39`, `cbp:151–153`; `project.godot:25–26` reads `window/stretch/mode="canvas_items"`, `window/stretch/aspect="keep"`; `project.godot:30` `renderer/rendering_method="forward_plus"`; viewport 1280x720 at `:23–24` |
| 5 | `--headless`, `--path`, `--quit-after`, `--import` | SOURCED | `cbp:180–186` |
| 6 | `--write-movie`, `--fixed-fps` implied, `--quit-after` as frame count, `--rendering-driver opengl3`, `--windowed`, `--resolution` | SOURCED (observed in spike) | `spike:175–179`, `spike:215–223`, `spike:275–277` |
| 7 | Silent Vulkan → OpenGL 3 fallback; `rendering/rendering_device/fallback_to_opengl3=false` → exit 1 `Could not initialize vulkan` | SOURCED (observed in spike) | `spike:189–196`, `spike:203–211`, `spike:252–254` (setting name taken from behaviour, as the ADR says) |
| 8 | `--headless --write-movie` crashes, exit 134 | SOURCED | `spike:197`, `spike:212` |
| 9 | Frames are viewport-sized regardless of `--resolution` | SOURCED | `spike:198`, `spike:246` |
| 10 | Frame 0 already rendered for a static scene | SOURCED | `spike:220–223` |
| 11 | `RenderingServer.get_current_rendering_method()` etc. | SOURCED | `spike:270` |
| 12 | `ResourceImporterDynamicFont.hinting` default 3 in 4.7 | SOURCED | `bc:40` |
| 13 | lavapipe would make Forward+ render under Xvfb; Windows/macOS parity; Compatibility GLSL subset | NOT SOURCEABLE | ADR says so; `spike:248–254` agrees; the per-story Windows playtest row is the test |

### (b) Deprecated APIs — none. (c) `cbp` idioms — none; the ADR's rule 6 (no glow/HDR/3D/AA, `canvas_item` shaders only) keeps the project clear of every 4.5–4.7 rendering change listed in `cbp:70–95`.

### (d) Verdict: **APPROVE**

Cosmetic note: Decision 6 says "MSAA/FXAA/SMAA 2D are off in `project.godot`" — the file contains no anti-aliasing keys (observed), i.e. they are at engine default. The reference lists the options (`modules/rendering.md:48–54`) but not their defaults, so say "left at engine default (not enabled)" or set the keys explicitly so a future diff review has something to grep.

---

## ADR-0011 — Run UI shell + Meta stub seam

### (a) Engine claims

| # | Claim | Status | Citation / test |
|---|---|---|---|
| 1 | `@abstract class_name Screen extends Control`, `@abstract class_name MetaApi extends RefCounted` | SOURCED + OBSERVED | `cbp:32–40`; one-line spelling observed equivalent |
| 2 | Typed-return override rule for every `Screen` / `MetaApi` / `MetaStub` override | SOURCED + OBSERVED | `bc:17`, `cbp:45–46` |
| 3 | Dual focus; `grab_focus()` keyboard-only; `focus_neighbor_*` | SOURCED | `modules/ui.md:19–21, 47–60`, `modules/input.md:16–19, 51–62`, `bc:55` |
| 4 | Recursive Control disable (4.5) for the input lock during transitions and under `confirm`; "exact property name NOT SOURCEABLE" | SOURCED feature + **OBSERVED name** | `cbp:101`, `bc:82`, `modules/ui.md:27–28`; observed on 4.7.2: `Control.focus_behavior_recursive` and `Control.mouse_behavior_recursive`. (`modules/ui.md:70–76` illustrates the feature with `mouse_filter`, which is a different, older property — read the reference example as loose.) Enum values not probed: the ADR's `scene_runner()` click + `ui_accept` test remains the proof |
| 5 | `Control.offset_transform_*` hover lift | SOURCED + OBSERVED | as ADR-0009 claim 3 |
| 6 | `InputEvent.DEVICE_ID_MOUSE / DEVICE_ID_KEYBOARD`; never `device == 0` | SOURCED + OBSERVED | `dep:53`, `bc:24`, `modules/input.md:8–10`; observed values `DEVICE_ID_KEYBOARD = 16`, `DEVICE_ID_MOUSE = 32` |
| 7 | `FoldableContainer` (4.5) | SOURCED + OBSERVED | `cbp:100`, `modules/ui.md:26`; `ClassDB.class_exists` true |
| 8 | `display/window/stretch/mode = canvas_items` | SOURCED + OBSERVED | `bc:39`; `project.godot:25` |
| 9 | `SCREENS: Dictionary[StringName, PackedScene]` (typed Dictionary) | **OBSERVED** (not in reference — `bc` 4.3→4.4 has no row for it) | A script declaring `var screens: Dictionary[StringName, PackedScene] = {}` and a function returning that type loads and instantiates on 4.7.2 |
| 10 | `DisplayServer.clipboard_set` for Copy seed | OBSERVED exists; behaviour under Xvfb NOT SOURCEABLE | `ClassDB.class_has_method` true; ADR's "assert the flash, not the OS clipboard" is right |
| 11 | `tr()` returns the key when no translation is loaded | NOT SOURCEABLE (LOW) | ADR labels it training-data and names the test |
| 12 | `Transition` (`RefCounted`) runs one `Tween` via `layer.create_tween()` and returns `finished` as a `Signal` | NOT SOURCEABLE (LOW) | 4.0-era; a tween created on the layer is processed by the tree regardless of who holds the reference. Test: `t_transition` fixture capture mid-fade with `--pause-at` |
| 13 | `OS.get_cmdline_user_args()` (`RunDebugLoader`) | OBSERVED | as ADR-0009 claim 12 |
| 14 | `CanvasModulate` for gamma under `RunShell` | NOT SOURCEABLE (LOW), parent observed `Node2D` | as ADR-0009 claim 11 |

### (b) Deprecated APIs — none; Guidelines ban the `dep` patterns explicitly. (c) `cbp` idioms — none violated; the ADR already applies `cbp:148–150` (device ids) and `cbp:130–134` (dual focus).

### (d) Verdict: **APPROVE WITH NOTES**

Notes: (1) on the next touch, replace "exact property name NOT SOURCEABLE" with the observed `focus_behavior_recursive` / `mouse_behavior_recursive` and add the typed-Dictionary row; (2) the Verification (1) test should set both properties on the base screen (mouse and focus are separate systems since 4.6 — `bc:55`); (3) the Alpha Controls-page row the review asked for will rely on the ADR-0004 addendum findings below.

---

## ADR-0004 — Decision addendum (2026-11-03), input remapping storage

### (a) Engine claims

| # | Claim | Status | Citation / test |
|---|---|---|---|
| 1 | `InputMap.action_erase_events` then `action_add_event` per action (addendum 2) | **OBSERVED** (not in reference — `modules/input.md` has no `InputMap` rows) | `ClassDB.class_has_method("InputMap", …)` true for `action_erase_events`, `action_add_event`, `action_get_events`, `get_actions`, `has_action`, `event_is_action`, `load_from_project_settings` |
| 2 | Serialise `InputEventKey` as keycode / physical keycode / modifiers; `InputEventMouseButton` / `JoypadButton` as button index; `JoypadMotion` as axis and sign (addendum 1) | OBSERVED (key, motion) / NOT SOURCEABLE (mouse, joypad button fields) | Observed: an `InputEventKey` rebuilt from `{keycode, physical_keycode, ctrl, shift, alt, meta}` satisfies `is_match()` against the original; `InputEventJoypadMotion` exposes `axis` and `axis_value`. Test for the rest: round-trip each of the four event types through the Dictionary and `JSON.stringify` / `parse_string`, then `InputMap.event_is_action` |
| 3 | Implicit: omitting `device` from the Dictionary is harmless under the 4.7 device-id change (`bc:24`) | OBSERVED safe for keyboard/mouse on 4.7.2 | A fresh `InputEventKey.new()` has `device == 16` (`DEVICE_ID_KEYBOARD`) and a fresh `InputEventMouseButton.new()` has `device == 32`; the project's own `ui_accept` events load with `device == 16`; `InputMap.event_is_action` matched a real keyboard event (`device = 16`) against stored events with default device, `device = 0` and `device = -1` alike. **Joypad not observed**: a `JoypadButton`/`Motion` binding rebuilt without `device` versus a controller reporting `device = 1` — NOT SOURCEABLE; test it before deciding whether to persist `device` for joypad events |
| 4 | Bindings travel through the profile JSON (addendum 1–2) | SOURCED by ADR-0003's record | `JSON.parse_string` returns `float` for every number (ADR-0003 Engine Compatibility Details, probe E); keycodes must be coerced with `int()` on load before assignment to `keycode` / `button_index` / `axis`. Test: the round-trip in claim 2 goes through JSON, not just the Dictionary |
| 5 | Actions are read by name in `InputRouter` / `RunShell`; unknown action names ignored | not an engine claim | — |

### (b) Deprecated APIs — none. (c) `cbp` idioms — the addendum should explicitly cite `cbp:148–150` / `dep:53`: never store or compare `device == 0`.

### (d) Verdict: **APPROVE WITH NOTES**

Notes: (1) add rows for claims 1–4 to ADR-0004's Engine Compatibility Details table (the review's advisory); (2) state in addendum 1 that `device` is **not** serialised and why (claim 3), pending the joypad test; (3) name the JSON round-trip + `int()` coercion test in Verification; (4) state that `cancel` is a project action distinct from the engine's built-in `ui_cancel`, and whether `ui_*` built-ins are rebindable (they are the gamepad path in ADR-0011 §5).

---

## ADR-0001 — grep gates G1–G6 (spot-check)

| Gate | Finding | Status |
|---|---|---|
| Tooling premise | "ripgrep has no `gdscript` type; use `--glob "*.gd"`" | SOURCED `cbp:172–176` |
| **G2b** `\bawait\b(?!.*\.checkpoint\(\))` | Installed `ripgrep 14.1.0`: `regex parse error … look-around, including look-ahead and look-behind, is not supported … Consider enabling PCRE2 with the --pcre2 flag`, **exit 2** (the gate never runs). With `rg -P` it works. Independently, ADR-0006 claim 12 shows that `src/ai/**` must contain `await score_all(...)`, `await _lethal_search(...)` and `await plan_turn(...)`, none of which match the allow-list, and `src/gameplay/run/match_driver.gd` would contain the `await` lambda | **CONTRADICTED (observed)** → REVISE |
| G2 `%[A-Z]` | `"%X" % v` matches (observed); ADR-0003 rule 4 formats seeds as uppercase hex (`%016X` escapes, a bare `%X` does not) | Advisory false positive — prefix with `(^|[^"%\w])` |
| G1 `extends (Node\|Control\|Node2D\|CanvasItem\|Timer)` | `extends Button`, `extends Label`, `extends Panel`, `extends Resource` are not caught (observed: of `Button / Node3D / Label / Resource` only `Node3D` matched, and only because `Node` is a prefix) | Advisory — add a positive gate: every `.gd` under the rules tier whose `extends` is neither `RefCounted` nor a project class name is a hit |
| G4 "exactly 1 autoload named `Boot`" | `project.godot` has no `[autoload]` section yet (observed) — the gate reads 0 until the Boot story lands | Observation, expected pre-implementation |
| G6 vs ADR-0003 Decision 10(b) | Two RNG deny-lists differ (`G6` lacks `randi_range(`, `randf_range(`, `RandomNumberGenerator.new(`; ADR-0003's lacks `randf_range(`) | Advisory — G6 should point at `tools/lint/no_global_rng.sh` instead of restating the list |
| Verification (1) "`@abstract` bases refuse direct instantiation" | Refusal is parse-time for a statically typed `X.new()` (`Cannot construct abstract class`) and for a subclass that omits an override; `load(path).new()` was **not** refused on 4.7.2 (observed) | Advisory — write the test as a parse check of a fixture that calls `Presenter.new()`, not a runtime assertion |

**Verdict: REVISE (G2b only).** Proposed G2b: (i) `src/gameplay/**`, `src/core/**` (minus `boot.gd`): `rg --glob "*.gd" '\bawait\b'` → 0 hits — unchanged, which requires ADR-0006 fix 2 (lambda built in `src/ai/`); (ii) `src/ai/**`: a deny-list without look-around, `rg --glob "*.gd" '\bawait\b.*(get_tree|process_frame|physics_frame|create_timer|\.timeout|\.finished|tween|signal)'` → 0 hits, relying on G1/G2 for the Node ban — or keep the current pattern and run it with `rg -P`, widening the allow-list to `\.checkpoint\(\)|score_all\(|_lethal|plan_turn\(`. The first is simpler and does not need updating when BossAI gains a method.

---

## ADR-0003 — per-stream `RandomNumberGenerator` (spot-check)

| Claim | Status | Citation |
|---|---|---|
| One `RandomNumberGenerator` per stream, `seed` set once; same seed ⇒ same `randi()` sequence; `randi()` ∈ `[0, 2^32 − 1]` | **OBSERVED (re-run)** | Not in the reference (ADR says so). Today: `seed = 42` → `[492690617, 1919685028, 3561993920]`, two instances equal — matches the ADR's Verification row and the scratch `probe_rng.out` line 3 (`D1 same_seed_same_sequence=true first3=[492690617, 1919685028, 3561993920]`) |
| `state` is a settable `int`; reseed-and-discard ≡ state restore | NOT re-observed; ADR records probe D4/D5 | Not relied on (Alternative 3); `rng_service_test.gd` covers restore |
| Typed-return rule, lambda capture, typed arrays | SOURCED | `bc:17`, `cbp:19–30, 45–46`, `dep:49` |
| `Time.get_ticks_usec()` | NOT SOURCEABLE (LOW) | as ADR-0006 claim 17 |

**Verdict: APPROVE WITH NOTES.** Probe D/E are cited as "spike (environment + verified API list); probe D/E outputs recorded below", but the spike file holds only Probes A–C; the durable record is the ADR's own table plus a scratch file that will not survive the container. Append Probe D/E sections (method, command, first-three values, `randi` extrema, F2 example) to `spikes/2026-11-03-engine-probes.md` or a sibling spike, until `tests/unit/rng_event_log/rng_engine_pins_test.gd` lands (E1).

---

## Cross-cutting observations

1. **Coroutine propagation is the one engine fact none of the ADRs accounted for.** 4.7.2 enforces `await` at every statically resolved call to a coroutine. It touches ADR-0006 (call shapes), ADR-0001 (G2b), and any test or harness that calls `BossAI.plan_turn` / `play_turn`. It does not touch ADR-0009 or ADR-0011: their tweens are fire-and-forget and the queue clock never awaits.
2. **`@abstract` spelling.** The ADRs' one-line `@abstract class_name X extends Y` and the reference's two-line form behave identically (observed). Enforcement is static; dynamic `GDScript.new()` is not refused.
3. **Everything the review reports listed as NOT SOURCEABLE on these ADRs is now either observed or has a named test**: recursive Control disable property names (observed), typed Dictionary (observed), `InputMap` methods (observed), 4.7 device-id interaction with stored bindings (observed for keyboard/mouse, test named for joypad), RNG golden pin (re-observed). Still NOT SOURCEABLE and correctly gated by the ADRs: Windows `WorkerThreadPool` and `rename_absolute`, Forward+/D3D12 parity, lavapipe, `tween_await` timeout semantics, export-preset filter syntax, clipboard under Xvfb, crash durability.
4. **No deprecated API and no `cbp`-warned idiom appears in any reviewed section.**

## Follow-ups (owner's call; no file edited by this consultation)

| # | Action | Where |
|---|---|---|
| F1 | Apply ADR-0006 fixes 1–3 (call shape, lambda built in `src/ai/`, verification line) | ADR-0006 Decision, Diagram, Key Interfaces, Verification |
| F2 | Rewrite G2b per the proposal; tighten G2 `%[A-Z]`; make G6 point at `no_global_rng.sh`; note G1 positive-gate option | ADR-0001 Decision 6 + `/create-control-manifest` Forbidden rows |
| F3 | Add the observed names/rows to ADR-0011 and ADR-0004 Engine Compatibility tables; add joypad-device and JSON-coercion tests to ADR-0004 Verification | ADR-0011, ADR-0004 |
| F4 | Append Probe D/E (RNG, JSON) and today's Probe V (coroutine, `@abstract`, `InputMap`, recursive-disable names, typed Dictionary) to the spike file so the durable record is not a scratch directory | `docs/architecture/spikes/2026-11-03-engine-probes.md` |
| F5 | Fold the verdict table into the next `/architecture-review` Engine Specialist section and mark TD-PHASE-GATE entry condition 6 met | next review report; `production/gate-checks/` |
