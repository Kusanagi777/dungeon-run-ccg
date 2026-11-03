# ADR-0009: Match UI Animation Queue, Tween Approach and Scene Partition

## Status

Accepted

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner. `technical-director` is the role
> `coordination-rules.md` escalates technical conflicts to.

Review record for this authoring run (2026-11-03, `review_mode: lean`,
`automation: guided`, `workflow: standard`, `docs.density: balanced`):

- **TD-ADR gate skipped — Lean mode.** `technical-director` was not spawned.
- **Engine validation: NOT ASSESSED** — no `Agent` tool was available to this
  run, so `godot-specialist` was not spawned. `docs/engine-reference/godot/`
  (`VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`,
  `current-best-practices.md`, `modules/ui.md`, `modules/animation.md`,
  `modules/input.md`) was read directly and is cited per claim.
- **GDD sync: checked 4 referenced GDDs** (`match-ui.md`, `match-rules.md`,
  `rng-event-log.md`, `meta-progression.md`): no naming inconsistencies. The
  GDD's presenter names (`HandPresenter`, `BoardPresenter`, `HeroPresenter`,
  `FeedPresenter`, `OverlayPresenter`, `TargetingArrow`, `InputRouter`,
  `MatchDebugLoader`) are kept as the **script class names**; the scene file
  names this ADR adds (`hand_fan.tscn`, `board_row.tscn`, …) are new, not
  renames. `AnimStep` fields match U4.1–U4.2 plus `parallel_ok`.
- **Registry conflict check (Step 3a):** `docs/registry/architecture.yaml` has
  no entries; nothing to conflict with. Registry rows this ADR would add are in
  the authoring report, not written.
- **Numbering:** fixed by DD-X08 and `architecture.md` §Required ADRs.
- **TD review 2026-11-03 (acceptance pass over ADR-0001..0011):** no decision
  change; the dependency row's "none Accepted" note updated. Checked against
  ADR-0008 (`MatchController` wraps the driver; `tick()` from `_process`; no
  event buffer — subscribers fire synchronously as plans replay) and ADR-0010
  (capture launch line). TD-003 is shared with ADR-0001, TD-006 display half
  with ADR-0011 — consistent with `architecture.md` mapping. Dependencies
  ADR-0001, ADR-0003, ADR-0008 Accepted first.
- **Accepted 2026-11-03 by technical-director** on the owner's standing approval of the project plan (plan approved 2026-11-03; "accept each" step). Owner may revert to Proposed.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2 (installed) and the GDDs approved on
2026-11-03.

## Decision Makers

Jacob (Head of Design, owner) — standing approval for guided mode;
`/architecture-decision` run (authoring); `technical-director` (acceptance, on
the owner's confirmation). No director or specialist agent reviewed this draft.

## Summary

match-ui U4 requires an animation queue that plays `AnimStep`s FIFO in command
groups (by `cause_seq` root), coalesces, scales by `anim_speed`, flushes on
skip-all within 100 ms and guarantees that an idle queue means every presenter
equals `MatchViewState`; U12 leaves the scene/node architecture and the tween
library to an ADR. This ADR decides: `AnimationQueue` is a `RefCounted`
scheduler driven from `MatchView._process(delta)` that owns *timing* and calls
`apply_final`; presenters own *visuals* through `Tween`s they create and kill
(never `AnimationPlayer`), using `Control.offset_transform_*` (4.7) for lifts
inside containers; the scene is partitioned into `match_view.tscn` plus one
scene per presenter (HandFan, BoardRow ×2, HeroPanel ×2, TargetingArrow,
ChoiceOverlay, EventFeed, Banner, MulliganScreen, PauseMenu, shared CardFrame);
and `MatchDebugLoader` is the `--fixture` / `--pose` seam of U11.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2 stable — `VERSION.md`) |
| **Domain** | UI / Animation |
| **Layer** | Presentation |
| **Knowledge Risk** | **HIGH** — UI and Animation both carry 4.5–4.7 changes (`VERSION.md`); the specific APIs this ADR leans on are sourced below, the rest are 4.0-era (training data, LOW) and named as such |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `breaking-changes.md` (4.6→4.7 GUI, Rendering `CanvasItem` line feather, Project stretch defaults; 4.5→4.6 UI dual-focus); `deprecated-apis.md` (`yield()` → `await`, string `connect`, `$NodePath` in `_process`, untyped containers, `RichTextLabel.add_image` 4.7 rename); `current-best-practices.md` (Animation 4.7 `Tween.tween_await()`; UI and Input 4.7 `Control.offset_transform_*`, `RichTextLabel` image units, `InputEvent.DEVICE_ID_*`, stretch defaults; UI 4.6 dual focus; GDScript lambda capture-by-value; `@abstract`); `modules/ui.md`, `modules/animation.md`, `modules/input.md` |
| **Post-Cutoff APIs Used** | `Tween.tween_await()` (4.7, sourced: `modules/animation.md`, `current-best-practices.md` § Animation 4.7) — used only where a step must wait on a presenter signal; `Control.offset_transform_enabled / offset_transform_position / offset_transform_scale / offset_transform_rotation` (4.7, sourced: `modules/ui.md`, `current-best-practices.md` § UI and Input 4.7) — hover lift and press inside `BoardRow`'s container; dual-focus (4.6, sourced: `modules/ui.md` § Focus Management) — the focus ring is keyboard focus only; `@abstract` (4.5, sourced) for `Presenter`; the 4.7 typed-return override rule (sourced) applies to every `Presenter` override; `RichTextLabel.add_image(width_unit / height_unit)` (4.7 rename, sourced) if `FeedPresenter` ever inlines icons; `CanvasItem` lines have no antialiasing feather in 4.7 (sourced) — `TargetingArrow` line width is data, not tuned by eye on 4.6 |
| **Verification Required** | (1) `Control.offset_transform_*` survives an `HBoxContainer` re-layout during a `BoardRow` lunge (sourced in principle, not observed on this machine); (2) `Tween.tween_await()` behaviour when the awaited signal never fires — **NOT SOURCEABLE** (the reference names the method, not its timeout semantics); the queue's own timer, not the tween, ends every step, so this is a visual-only risk — test: a step whose presenter signal never fires still ends at `d_eff`; (3) skip-all drains a 300-step recorded stream in ≤ 100 ms on the min-spec machine (TBD per `architecture.md` Performance budgets); (4) the `--write-movie` capture of each fixture renders under the ADR-0010 launch line (Compatibility renderer, llvmpipe) with no Forward+-only effect in Match UI |

> If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated when the
> project upgrades engine versions.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (rules / presentation split — `src/ui/` is display-only over events, commands and queries); ADR-0003 (event log — `cause_seq`, `subscribe` / `events_since`, synchronous main-thread subscribers; the view-state is a projection of that log); ADR-0008 (match driver — `MatchController` wraps `MatchDriver`; `tick()` is driven from `MatchView._process`; `MatchController.on_setting_changed` and `is_planning()` are its additions). All written 2026-11-03; all Accepted 2026-11-03 before this ADR |
| **Enables** | ADR-0011 (Run UI reuses the `CardFrame` scene, the `Transition` tween helper and the pause-menu settings panel); the twenty match fixtures (U11) and every Visual / UI story under `src/ui/match/` |
| **Blocks** | Every Match UI story; the `boss_turn_playback`, `midgame_full_board`, `simultaneous_deaths` fixtures; AC L6 (skip-at-every-index invariant test) |
| **Ordering Note** | ADR-0006's replay-per-tick rule means the boss turn may enter the log across a few frames; the F4 compression rule below is written for that. ADR-0010 fixes the capture launch line this ADR's fixtures use; it does not change this ADR's content |

## Context

### Problem Statement

match-ui U4 specifies queue semantics (unit, ordering by command group,
coalescing, speed divisor, skip-all ≤ 100 ms, the idle invariant, flush before
a new command, process-tick timing) and U6 the boss-turn pacing (F4), but U12
says "scene/node architecture and the tween library choice are ADRs". Without
this decision, each presenter story would pick its own animation mechanism and
its own notion of "done", and the idle invariant — the property that makes the
display trustworthy at rest (TD-003's defect was a board that existed only as
scene children) — could not be asserted in one place.

### Current State

No production UI code. The prototype's `Minion` was a `Control` that owned
stats and freed itself (TD-005), the UI mutated game state (TD-006) and the
board was never registered (TD-003). Salvage references named by the GDD
(`targeting_arrow.gd`, `mulligan_screen.gd`, `discover_selection.gd`) are
behaviour references, not ported code (TD-010).

### Constraints

- **Display-only** (`.claude/rules/ui-code.md`; ADR-0001): no presenter holds a number the view-state cannot reproduce; every match mutation goes through `submit`.
- **The UI never blocks the game thread** (`ui-code.md`; U4.8): per-step timing on process ticks, no `await` chains inside rules code.
- **Every animation skippable and motion-preference aware** (`ui-code.md`; DD-X07 `anim_speed`, `reduce_motion`; F3).
- **Latency table** (match-ui Input Responsiveness): pickup 16 ms, drag 16 ms, release → first visual 50 ms, rejection 50 ms, skip-all 100 ms, End Turn → commit beat 300 ms, hover 100 ms.
- **1280x720 logical, `canvas_items` stretch** (DD-T05; F6 grid).
- **Evidence**: every screen reachable from a launch argument (U11) and captured per `run-and-observe.md` / ADR-0010.
- **Deprecated patterns banned** (`deprecated-apis.md`): `yield()`, string `connect`, `$NodePath` in `_process`, untyped `Array` / `Dictionary`.

### Requirements

- Must implement U4.1–U4.8 and F3/F4 exactly, with the timing logic unit-testable headless (no scene).
- Must assert the idle invariant in debug builds after each drain and in the headless suite after a skip at every step index (AC L6).
- Must keep boss `card_drawn.card_id` and boss `discover_offered` options out of the view-state (U3.2, hidden information).
- Must let `MatchDebugLoader` run the real engine over a fixture and show any pose without a second code path.

## Decision

### 1. Timing and visuals are separated: the queue schedules, presenters tween

`AnimationQueue` (`RefCounted`, `src/ui/match/animation_queue.gd`) holds the
FIFO of `AnimStep`s, computes each step's effective duration (F3 and, in
boss-turn mode, F4's `gap` and `k`), advances a per-step clock from
`MatchView._process(delta)` via `advance(delta)`, and — at the end of every
step, animated or skipped — calls `step.apply_final` (idempotent; sets the
presenters to the view-state for that step). It emits `step_started(step,
d_eff)` and `step_finished(step)`; it never touches a Node and never creates a
Tween, so U4 is unit-tested with a fake clock.

Presenters (Nodes) subscribe to `step_started`, check `owns(entity_ids)` and
build a `Tween` (`create_tween()` on the presenter — 4.0 API, training data,
LOW) of duration `d_eff` that moves toward the state `apply_final` will set.
Tweens are visual sugar: `apply_final` is authoritative, so a tween that is
killed early, never started (`instant`) or lags by a frame cannot leave the
display disagreeing with the view-state once the queue is idle. `skip_all()`
kills every live tween (`Tween.kill()`), runs the remaining `apply_final`s in
order within one frame, drops queued SFX and cancels hit-stop / slow-down
(U4.5). `Tween.tween_await()` (4.7, sourced) is permitted only inside a
presenter that must wait on its own signal (e.g. a particle burst's
`finished`) and never decides when a step ends.

`Tween` over `AnimationPlayer`: steps are data-driven (17 kinds × runtime
targets, entity ids and durations from `match_ui.json`), so there is nothing to
author on a timeline; `AnimationPlayer` would need one animation per kind per
target or runtime track rewriting. `AnimationPlayer` remains allowed for
authored, target-free clips (the end banner's flourish, the intent banner's
"plan changed" crossfade) if the art pass wants them — still fire-and-forget
under the queue's clock.

### 2. Command groups, coalescing and boss-turn pacing

- `MatchViewState.apply(event) -> Array[AnimStep]` (pure; U3) sets
  `group_id` to the `seq` of the event's command root (walk `cause_seq` to 0
  through a `seq → cause_seq` map the view-state keeps for the current turn).
- The queue plays groups FIFO; inside a group, `parallel_ok` steps start with
  the step before them (U4.2). Coalescing per U4.3: > `COALESCE_THRESHOLD` (8)
  damage / heal pops on distinct targets from one source in a group become one
  simultaneous pop; consecutive `minion_died` of one cause are always one step
  (the view-state emits them as one step already).
- Speed: `d_eff = 0` if skipped or `anim_speed == instant`, else
  `d_base / SPEED_DIV[anim_speed]` (F3); impact extras (hit-stop 60 / 90 ms,
  shake 120 ms, lethal slow-down 400 ms) are queue-local clock multipliers,
  dropped at `fast` or when `reduce_motion` is set. Never `Engine.time_scale`.
- Boss-turn mode: entered on `turn_started{side: boss}`, exited when
  `turn_started{side: player}` has drained. The commit beat (`intent_banner_s`)
  plays first; **F4's `gap` and `k` are computed when the first action group
  would start**, over the groups present in the queue at that moment. Because
  ADR-0006 may replay the turn across a few ticks, groups appended later play
  with the already-computed `gap`; if the running total would exceed
  `max_turn_playback_s`, the auto-skip rule (F4 last sentence) applies. In
  practice the whole plan replays in one tick (`replay_budget_ms`), so the
  computation sees the full turn; the rule exists so a partial burst is never
  wrong, only less compressed.
- A new player command flushes the queue first (U4.7) — `MatchController.submit`
  calls `queue.skip_all()` before `driver.submit` (architecture §Data Flow 1).

### 3. Scene partition

`src/ui/match/`:

| Scene | Root script (GDD name) | Owns | Notes |
|---|---|---|---|
| `match_view.tscn` | `MatchView extends Control` | the tree below, `MatchViewState`, `AnimationQueue`, `InputRouter`, the subscription (`events_since(0)` then `subscribe`), `_process` → `controller.tick()` + `queue.advance(delta)`, `_assert_in_sync()` in debug builds | layout per F6; `set_controller(MatchController)`; emits `match_view_finished(result)` |
| `hand_fan.tscn` | `HandPresenter extends Presenter` | player hand (F1 fan layout, F2 hover preview), card pickup / drag visuals | custom layout (not a Container) because F1 rotates and overlaps; boss hand = count badge on `HeroPanel` |
| `board_row.tscn` ×2 | `BoardPresenter extends Presenter` | one side's minion tokens, re-spacing, lunge, death group, gap-close | an `HBoxContainer` of `MinionToken` controls; lunge / lift use `offset_transform_*` so the container never resets them mid-tween (4.7, sourced) |
| `hero_panel.tscn` ×2 | `HeroPresenter extends Presenter` | portrait, health / armor, weapon slot, mana bar, hero-power button, deck count, fatigue label, boss intent banner anchor | number pops are children spawned per step |
| `targeting_arrow.tscn` | `TargetingArrow extends Presenter` | the quadratic Bezier arrow (U7), target ring | `_draw` each frame while active; line width from data (4.7: no feather, sourced) |
| `choice_overlay.tscn` | `OverlayPresenter extends Presenter` | Choice overlay (U9), table dim, "boss discovers…" label | 3 `CardFrame`s or 3 plates; no cancel |
| `event_feed.tscn` | `FeedPresenter extends Presenter` | 3-line ticker and the full panel (U10) | `RichTextLabel`; if images are ever inlined, `add_image(width_unit=…)` not `*_in_percent` (4.7 rename, sourced) |
| `banner.tscn` | `BannerPresenter extends Presenter` | turn banner, intent banner (`full` / `brief` / `hidden` renderings), end banner incl. `fault` copy | the one place `AnimationPlayer` clips are allowed |
| `mulligan_screen.tscn` | `MulliganPresenter extends Presenter` | U8 | opened by the `mulligan_offered` step |
| `pause_menu.tscn` | `PauseMenu extends Control` | concede confirm, settings quick-access (`anim_speed`, `reduce_motion`, volumes) | shared with Run UI (ADR-0011) as the settings panel |
| `../common/card_frame.tscn` | `CardFrame extends Control` | one card face (name, cost, stats, text keys, keyword badges) | shared with Run UI's drafts / deck drawer (ADR-0011) |
| `input_router.gd` | `InputRouter extends Node` | mouse / keyboard → intent → command (U5); `Esc` chain; skip-all; focus cycling | focus ring is keyboard focus only (4.6 dual focus, sourced); hover never moves focus |
| `match_debug_loader.gd` | `MatchDebugLoader` | U11 seam (below) | script present in debug builds only |

`@abstract class_name Presenter extends Control` (4.5, sourced) with
`bind(view_state)`, `owns(entity_ids) -> bool`, `on_step_started(step, d_eff)`,
`apply_final(step)` and `sync_report() -> Array[String]` (field-by-field diff
against the view-state for the debug assert). Every override returns
explicitly (4.7 typed-return rule, sourced).

`gamma` (DD-X10) is one `CanvasModulate` under `match_view.tscn` (4.0 node,
training data, LOW) updated from `settings_changed`; never a colour-token
change. `text_scale` is a theme override on `MatchView` (`theme_type_variation`
/ font-size overrides per 1.0 / 1.25 / 1.5, three fixture-tested layouts).

### 4. The debug loader seam (U11)

`MatchDebugLoader` reads `OS.get_cmdline_user_args()` (arguments after `--`;
4.x API, training data, LOW) in debug builds: `--fixture=<name>` loads
`tests/fixtures/match_ui/<name>.json` (a `MatchConfig` + scripted command list),
calls `Boot.boot()`, builds a real `MatchDriver` with
`ImmediatePlannerTask` (ADR-0006), runs the commands headlessly, then
`MatchView` projects `events_since(0)` with `anim_speed = instant`; `--pose`,
`--pause-at`, `--anim-speed`, `--ai-debug` apply afterwards exactly as the U11
table says. The same JSON is the input of
`tests/integration/match_ui/` (one file format for evidence and tests). The
loader script is attached only when `OS.is_debug_build()` is true; the release
export must not contain it (export-preset exclude filter — **NOT SOURCEABLE**
for 4.7's preset syntax; test: grep the exported `.pck` listing for
`match_debug_loader`). Launch line: ADR-0010's capture command with
`res://src/ui/match/match_view.tscn -- --fixture=<name> …`.

### Architecture Diagram

```
EventLog.subscribe (main thread, ADR-0003)
   │ event {seq, turn, type, payload, cause_seq}
   ▼
MatchViewState.apply(event) ──► Array[AnimStep{kind, entity_ids, base_duration_s,
   │ (pure; U3 table; hidden-info           apply_final: Callable, group_id, parallel_ok}]
   │  rules; diagnostic filter 4a)          │
   ▼                                        ▼
view-state fields (truth at rest)     AnimationQueue.enqueue(step)
                                            │ FIFO by group_id; coalesce; d_eff (F3); boss mode (F4)
MatchView._process(delta):                  │
   controller.tick()  ──► MatchDriver.tick() (ADR-0006 poll + replay → more events above)
   queue.advance(delta) ──► step_started(step, d_eff) ──► Presenter.owns? → create_tween() toward final
                        └─► at d_eff: step.apply_final() ──► Presenter fields == view-state for that step
   if queue.idle and OS.is_debug_build(): _assert_in_sync()   # every Presenter.sync_report() empty

InputRouter (Node): mouse/keyboard → intent → MatchController.submit(cmd)
                                            └─► queue.skip_all() first (U4.7) → driver.submit → events above
skip_all(): kill tweens → apply_final × remaining (one frame) → idle  (≤ 100 ms)
```

### Key Interfaces

```gdscript
# src/ui/match/match_view_state.gd — match-ui U3 (architecture.md §API Boundaries, Presentation)
class_name MatchViewState extends RefCounted
func apply(event: Dictionary) -> Array[AnimStep]      # pure; same events → same state and steps
func side(name: StringName) -> Dictionary             # hero, mana, deck_count, fatigue_next, hand, board (value copies)
var phase: StringName; var active_side: StringName; var turn: int; var intent: Variant
var pending_choice: Variant; var counters: Dictionary; var feed_lines: Array; var result: Variant

# src/ui/match/anim_step.gd
class_name AnimStep extends RefCounted
var kind: StringName; var entity_ids: Array[int]; var base_duration_s: float
var apply_final: Callable; var group_id: int; var parallel_ok: bool = false
var impact: Dictionary = {}                            # {hit_stop_ms, shake_ms, slow_ms} — dropped at fast / reduce_motion

# src/ui/match/animation_queue.gd — match-ui U4, F3, F4
class_name AnimationQueue extends RefCounted
func _init(ui_config: Dictionary, settings: Dictionary) -> void   # match_ui.json + DD-X07 settings (anim_speed, reduce_motion, action_delay_ms)
func enqueue(step: AnimStep) -> void
func advance(delta: float) -> void                     # called from MatchView._process; never awaits
func skip_all() -> void                                # kills tweens via presenters (signal), apply_final × rest, one frame
func is_idle() -> bool
func set_speed(anim_speed: StringName) -> void; func set_reduce_motion(on: bool) -> void
func enter_boss_turn(pacing: Dictionary) -> void       # {intent_banner_s, ai_action_delay_s, max_turn_playback_s, MIN_ACTION_GAP_S, K_MIN}
func exit_boss_turn() -> void
signal step_started(step: AnimStep, d_eff: float)
signal step_finished(step: AnimStep)
signal drained()
signal skipped()                                       # presenters kill their tweens on this

# src/ui/match/presenter.gd
@abstract class_name Presenter extends Control
@abstract func bind(view_state: MatchViewState) -> void
@abstract func owns(entity_ids: Array[int]) -> bool
@abstract func on_step_started(step: AnimStep, d_eff: float) -> void   # creates the Tween; fire-and-forget
@abstract func apply_final(step: AnimStep) -> void                     # idempotent; sets display = view-state
@abstract func sync_report() -> Array[String]                          # [] when display == view-state

# src/ui/match/match_view.gd — architecture.md §API Boundaries
class_name MatchView extends Control
func set_controller(controller: MatchController) -> void
signal match_view_finished(result: MatchResult)

# src/ui/match/input_router.gd — match-ui U5
class_name InputRouter extends Node
func intent(name: StringName, args: Dictionary) -> void   # drag_release, select, key_target, end_turn, skip, menu, …
signal command_requested(command: Command)                # MatchView forwards to MatchController.submit

# src/ui/match/match_debug_loader.gd — match-ui U11 (debug builds only)
class_name MatchDebugLoader extends RefCounted
static func from_args(args: PackedStringArray) -> Dictionary        # {fixture, pose, pause_at, anim_speed, ai_debug}
func load_fixture(name: String) -> MatchController                  # Boot.boot(); real MatchDriver(ImmediatePlannerTask); runs the scripted commands
func apply_pose(view: MatchView, pose: String) -> void
```

### Implementation Guidelines

- `AnimationQueue`, `MatchViewState` and `AnimStep` **must** be `RefCounted`
  with no Node reference; their unit tests run headless with a fake clock.
- A presenter **must never** store a value the view-state does not have
  (U1); `sync_report()` **must** compare every displayed field to the
  view-state, and `MatchView._assert_in_sync()` **must** run after every drain
  in debug builds (`OS.is_debug_build()`).
- Step duration **must** end with the queue's clock calling `apply_final`;
  a Tween **must never** be what finishes a step. `Tween.tween_await()` is
  allowed only inside a presenter and only on the presenter's own signals.
- Presenters **must** create tweens with `create_tween()` on themselves and
  **must** kill them on `skipped` and on `apply_final`; no tween may outlive
  its step.
- Lifts and presses on children of a `Container` **must** use
  `Control.offset_transform_*` (4.7), **never** `position` / `scale` (the
  container resets them on re-layout).
- Timing **must** run on `_process` ticks (`advance(delta)`); **never**
  `await`, `Timer` nodes per step, or `Engine.time_scale` for hit-stop.
- `anim_speed`, `reduce_motion`, `action_delay_ms`, `text_scale`,
  `high_contrast_states`, `gamma` **must** be read from `SettingsBus`
  (`settings_changed`, DD-X07 / DD-X10) and applied live; **never** hardcoded
  defaults — session-local defaults come from `config("profile_defaults")`
  via `MetaStub` (ADR-0011).
- Every duration, threshold and geometry value **must** come from
  `config("match_ui")` (read once in `MatchView._ready`); the UI **must never**
  parse JSON itself (card-database CR-1).
- The focus ring **must** be drawn from keyboard focus (`focus_entered` /
  `focus_exited`) and **never** from hover (4.6 dual focus); `grab_focus()`
  moves keyboard focus only.
- Mouse / keyboard events **must** be identified by type (`InputEventMouseButton`,
  `InputEventKey`), **never** by `event.device == 0` (4.7, sourced).
- `MatchDebugLoader` **must** run the real engine over the fixture and **must**
  be absent from release exports; fixtures **must never** contain hand-built
  view-states.
- Deprecated patterns **must not** appear: `yield()`, string-based `connect`,
  `$NodePath` in `_process` (cache with `@onready` / `%Unique`), untyped
  `Array` / `Dictionary` in signatures.
- `queue_free` **may** appear only under `src/ui/` (ADR-0001 / TD-005) and only
  for presenter children (number pops, tokens on death) after `apply_final`.

## Alternatives Considered

### Alternative 1: `AnimationPlayer` / `AnimationTree` per presenter
- **Description**: Author one animation per step kind on each presenter; the queue calls `play(&"attack_lunge")` and awaits `animation_finished`.
- **Pros**: Artist-editable timelines; `AnimationMixer` base (4.3, sourced) is stable.
- **Cons**: Steps target runtime entities (which token, which slot) with data-driven durations, so each play needs track rewriting or a generic track per possible target; `animation_finished` as the step end would make the timeline, not the queue, the authority (breaks the idle invariant on a skipped or mis-authored clip); durations would live in `.tres` files, not `match_ui.json` (coding standard: gameplay values data-driven).
- **Estimated Effort**: Higher per presenter; lower per authored flourish.
- **Rejection Reason**: Wrong authority model for a projection-driven UI; kept for target-free authored clips under the queue's clock.

### Alternative 2: Queue owns the tweens (one `Tween` per step, step ends on `Tween.finished`)
- **Description**: `AnimationQueue` extends `Node`, creates a `Tween` per step and advances on `finished`.
- **Pros**: One place to look; no presenter boilerplate.
- **Cons**: The queue becomes a Node (not headless-testable without a scene runner); `instant` and `skip_all` need special-casing around tweens that never start; a stalled tween stalls the match display; F4's compression needs a tween-independent clock anyway.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Couples timing correctness to a visual mechanism; the chosen split keeps U4 unit-tested with a fake clock and makes the idle invariant provable.

### Alternative 3: Single monolithic `match_view.tscn`
- **Description**: One scene with every zone as inline nodes and one script.
- **Pros**: Fewest files; no cross-scene wiring.
- **Cons**: Run UI cannot reuse the card frame or pause menu without importing the match scene; the GDD's presenter ownership table (U1) has no file boundary to enforce it; fixtures and screenshots per zone become harder; TD-010's duplicate/dead scene problem returns at the other extreme (one giant file nobody can audit).
- **Estimated Effort**: Lower initially, higher at every story after.
- **Rejection Reason**: U1 already partitions by presenter; one scene per presenter plus a shared `CardFrame` is the direct encoding.

### Alternative 4: Presenters poll `MatchQuery` to render numbers
- **Description**: Skip the projection; presenters read the engine each frame.
- **Pros**: No `MatchViewState`.
- **Cons**: U2 forbids it ("numbers come from the projection so the screen can lag the engine during playback without ever disagreeing with it at rest"); the display could not lag the engine during boss-turn playback (U6) because the engine is already at the end of the turn.
- **Estimated Effort**: Lower code, unworkable behaviour.
- **Rejection Reason**: Contradicts U2 / U3 and DD-T04 (UI renders from events).

## Consequences

### Positive
- The idle invariant is a single assertion over `sync_report()`; TD-003 and TD-006 cannot recur without failing it in debug builds and in AC L6.
- Queue semantics (F3, F4, coalescing, skip) are headless unit tests; visuals are fire-and-forget and cannot corrupt state.
- One scene per presenter matches U1's ownership table; `CardFrame` and `PauseMenu` are reused by Run UI without importing match code.
- Fixtures run the real engine, so evidence screenshots cannot show unreachable states.

### Negative
- Two layers per step (queue clock + presenter tween) is more code than a single tween; every presenter implements five abstract methods.
- `apply_final` idempotence is a discipline every presenter must keep; a non-idempotent one breaks skip-all.
- Boss-turn compression may be computed over a partial burst if ADR-0006's replay spans ticks — accepted, with the auto-skip rule as the backstop.

### Neutral
- `AnimationPlayer` is not banned, only demoted to authored, target-free clips.
- `Tween.tween_await()` (4.7) is available but rarely needed; most steps need no signal wait.

## Risks
- **`offset_transform_*` not behaving as the reference describes under `HBoxContainer` re-spacing** (sourced from release notes, not observed). Mitigation: first `BoardRow` story captures a mid-lunge frame (`--pause-at`) as evidence; fallback is a non-container row laid out by `BoardPresenter` (as `HandPresenter` already is).
- **Skip-all over a long recorded stream exceeding 100 ms** on min-spec (TBD). Mitigation: `apply_final` sets fields only (no layout recomputation per step; one `queue_sort()` at the end); measured in AC L6 with a 300-step stream.
- **A `tween_await()` that never resolves** (NOT SOURCEABLE). Mitigation: the queue's clock ends the step and `apply_final` runs regardless; the tween is killed on `skipped` / `apply_final`.
- **Debug loader leaking into a release export** (NOT SOURCEABLE preset syntax). Mitigation: CI greps the exported `.pck` file list; `OS.is_debug_build()` guard as second line.
- **Forward+-only visuals absent in CI evidence** (ADR-0010: captures use Compatibility / llvmpipe). Mitigation: Match UI uses 2D `Control` / `CanvasItem` drawing only; no glow, HDR or 3D light.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| match-ui.md | TR-match-ui-001 — U1, U2: `MatchView` + injected `MatchController` + `MatchQuery` + `MatchViewState` + `AnimationQueue` + presenters + `InputRouter`; three channels only | Scene partition table and Key Interfaces; `MatchController` is the only command path; queries on hover only |
| match-ui.md | TR-match-ui-002 — U3, U4: projection of events; `AnimStep` FIFO by command root; coalescing; speed divisor; skip-all ≤ 100 ms; idle invariant | Decision §1–2; `sync_report()` assert; AC L6 test |
| match-ui.md | TR-match-ui-003 — U6: boss turn already in the log; UI paces and compresses to `max_turn_playback_s` | Boss-turn mode with F4 computed at first action group; auto-skip backstop; aligned with ADR-0006 replay |
| match-ui.md | TR-match-ui-004 — U11: `--fixture`, `--pose`, `--pause-at`, `--anim-speed`, `--ai-debug`; fixtures run the real engine; loader absent from release | Decision §4; `MatchDebugLoader` interface; export grep |
| match-ui.md | TR-match-ui-005 — latency table | Pickup / drag are immediate (no tween-in on pickup); first visual event = step start within the frame after `submit`; skip-all one-frame flush |
| match-ui.md | TR-match-ui-006 — hand-off: Run UI swaps `MatchView` in; `match_view_finished(result)` after the end banner | `MatchView.set_controller`, `match_view_finished`; end banner is a `BannerPresenter` step followed by the `Ended` wait |
| match-ui.md | F3 (effective duration), F4 (gap / compression), U4.3 `COALESCE_THRESHOLD`, Tuning Knobs from `match_ui.json` | Implemented in `AnimationQueue` from `config("match_ui")` + settings |
| match-rules.md | Game Feel (hit-stop 60/90 ms, shake, lethal slow-down); TR-match-rules-008 (`submit` ≤ 5 ms) | Impact extras as queue-local clock multipliers; `submit` is called once per intent after a one-frame flush |
| rng-event-log.md | TR-rng-event-log-004 (`cause_seq` envelope), TR-rng-event-log-005 (diagnostic filter) | `group_id` = command root via `cause_seq`; U3.4a filter in `MatchViewState.apply` |
| meta-progression.md | TR-meta-progression-005 — settings record via `settings_changed` (DD-X07 `anim_speed`, `reduce_motion`, `action_delay_ms`, `text_scale`, `high_contrast_states`; DD-X10 `gamma`) | Read from `SettingsBus`; `CanvasModulate` for gamma; theme overrides for text scale |
| design-decisions.md | TR-design-decisions-003 — DD-T05 1280x720, `canvas_items` stretch, mouse primary, keyboard shortcuts | F6 layout at 1280x720; `InputRouter` implements U5's keyboard set |
| systems-index.md | TR-systems-index-002 — Match UI ↔ Run UI one-way scene hand-off; reverse edge is a signal | `match_view_finished` is the only edge back; Run UI reuses `CardFrame` / `PauseMenu` scenes, never match presenters |

## TD Items Retired

| TD | Prototype root cause | How this ADR rules it out |
|---|---|---|
| TD-003 | Board never registered; minions existed only as scene children | `MatchViewState.board` is a projection of `MatchState.players[side].board` events; presenters are projections of the view-state; the idle invariant assert fails if a token exists that the view-state does not have |
| TD-006 (display half) | UI mutated game state | Presenters are display-only (`Presenter` has no engine reference); the only command path is `InputRouter → MatchController.submit`; `MatchQuery` returns copies |

(TD-005 and TD-010 are retired by ADR-0001; this ADR keeps `queue_free` under `src/ui/` only and ports no prototype scene.)

## Verification / How We Know

| Claim | Evidence today | Test that proves it |
|---|---|---|
| `Tween.tween_await()` exists on 4.7 | **Sourced**: `modules/animation.md` § 4.7, `current-best-practices.md` § Animation 4.7 | Not load-bearing (queue clock ends steps); one presenter unit test if used |
| `Control.offset_transform_*` exists on 4.7 and is not reset by containers | **Sourced**: `modules/ui.md` § 4.7, `current-best-practices.md` § UI and Input 4.7 | `tests/integration/match_ui/test_board_row_lunge.gd` with `scene_runner()`: token `offset_transform_position` non-zero mid-step while the row re-sorts; evidence frame via `--pause-at` |
| Keyboard focus is separate from mouse hover (4.6) | **Sourced**: `modules/ui.md`, `modules/input.md` § Focus Management | Fixture `turn1_player --pose=focus:hand:0` shows the ring on the focused card while the cursor hovers another |
| `create_tween()`, `Tween.kill()`, `CanvasModulate`, `OS.get_cmdline_user_args()`, `OS.is_debug_build()` | Training data (4.0-era, LOW risk); not in the reference | Exercised by every presenter test and by the debug loader test; the parse check (`godot-parse-check.gd`) catches a missing symbol |
| Idle queue ⇒ display == view-state | Design property | AC L6: headless, skip at every step index of a recorded 300-step stream, `sync_report()` empty each time; debug-build `_assert_in_sync()` after each drain |
| Skip-all ≤ 100 ms | Not yet measurable | AC L6 timing on the 300-step stream; integration test with `scene_runner()` |
| F3 / F4 arithmetic | GDD worked examples (F4: A = 5, D = 2.5 → gap 0.6, T = 5.2 s; A = 30, D = 15 → k = 0.509) | `tests/unit/match_ui/test_animation_queue.gd` asserts the three F4 examples and the F3 examples (`fast` 0.175 s, `normal` 0.35 s, `instant` 0) |
| Fixtures run the real engine | Design property | `tests/integration/match_ui/test_fixtures_load.gd`: every required fixture loads with zero rejected commands; screenshot per fixture under ADR-0010's launch line retained in `production/qa/evidence/` |
| Release export excludes the debug loader | **NOT SOURCEABLE** (4.7 export filter syntax) | CI step lists the exported `.pck` contents and fails on `match_debug_loader` |

## Performance Implications
- **CPU**: `advance(delta)` is O(active steps) per frame (≤ a handful); `MatchViewState.apply` is O(1) per event; skip-all is O(remaining steps) once. Tween count ≤ steps in flight (parallel group ≤ 8 pops after coalescing). `MatchQuery` calls only on hover / drag (≤ 2 ms each by contract).
- **Memory**: view-state ≈ a few KB; queue holds at most one boss turn of steps (≤ 30 groups); feed buffer `FEED_MAX_LINES` 200.
- **Load Time**: 11 scenes preloaded by `match_view.tscn`; measured against the `intro_ready` / `begin_match` budgets of run-ui F1 once scenes exist.
- **Network**: n/a.

## Migration Plan

Greenfield. Story order: `AnimStep` + `AnimationQueue` + `MatchViewState`
(headless, F3/F4 tests) → `Presenter` base + `MatchView` skeleton +
`MatchDebugLoader` with the `turn1_player` fixture and its first retained
screenshot → presenters one scene at a time (each with its fixture and
screenshot) → `InputRouter` → boss-turn mode with `boss_turn_playback`.

**Rollback plan**: the queue/presenter split is internal to `src/ui/match/`;
if the tween layer proves unworkable, presenters may set final state in
`on_step_started` and let the clock run (a "cut" animation style) with no
change to the queue, the view-state or any other system.

## Validation Criteria

- AC L6 passes (idle invariant after a skip at every step index); the debug assert never fires across the twenty required fixtures.
- Every fixture in U11 loads, runs the real engine and has a retained screenshot in `production/qa/evidence/`.
- match-ui Input Responsiveness table measured by the `scene_runner()` integration test: all seven rows within budget.
- F4 compression examples reproduce; `boss_turn_playback` fixture plays a 12-action turn within `max_turn_playback_s`.
- No `AnimationPlayer` drives a data-driven step; no `yield`, string `connect` or `$NodePath` in `_process` under `src/ui/match/` (grep gate).

## Related
- Depends on: ADR-0001, ADR-0003, ADR-0008. Enables: ADR-0011. Sibling: ADR-0006 (boss-turn burst timing), ADR-0010 (capture launch line used by the fixtures).
- `docs/architecture/architecture.md` §API Boundaries Presentation, §Data Flow 1, §Screenshot capture and the fixtures seam, §Performance budgets (UI latency, boss turn playback).
- `design/gdd/match-ui.md` U1–U12, F3, F4, F6, States and Transitions, Input Responsiveness, Tuning Knobs; `design/gdd/match-rules.md` Game Feel, C14; `design/gdd/rng-event-log.md` rules 11–13, 12a; `design/gdd/meta-progression.md` M9; `design/design-decisions.md` DD-T05, DD-X07, DD-X09, DD-X10.
- `design/ux/hud.md` (Focus Order, F6 rects), `design/ux/interaction-patterns.md`, `design/accessibility-requirements.md`.
- `.claude/rules/ui-code.md`; `.claude/docs/run-and-observe.md`.
- Code (once implemented): `src/ui/match/*.gd`, `src/ui/match/*.tscn`, `src/ui/common/card_frame.tscn`, `tests/fixtures/match_ui/*.json`, `tests/unit/match_ui/`, `tests/integration/match_ui/`.
