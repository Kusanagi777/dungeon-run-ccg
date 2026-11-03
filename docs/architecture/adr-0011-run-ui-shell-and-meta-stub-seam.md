# ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam

## Status

Proposed

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
  `current-best-practices.md`, `modules/ui.md`, `modules/input.md`) was read
  directly and is cited per claim.
- **GDD sync: checked 5 referenced GDDs** (`run-ui.md`, `meta-progression.md`,
  `run-structure.md`, `reward-draft.md`, `match-ui.md`): no naming
  inconsistencies. `RunShell`, `ShellState`, `RunController`,
  `intent(name, args)`, `ui_intent_rejected`, the screen ids of run-ui U2, the
  `MetaApi` method names of meta-progression M1.3 and `settings_changed{key,
  value}` are used verbatim. New names introduced here (`ToastLayer`,
  `ScreenStack`, `Transition`, `MetaStub`, `MetaFacade`, `RunDebugLoader`) are
  additions the GDDs describe without naming.
- **Registry conflict check (Step 3a):** `docs/registry/architecture.yaml` has
  no entries; nothing to conflict with. Rows this ADR would add are in the
  authoring report, not written.
- **Numbering:** fixed by DD-X08 and `architecture.md` §Required ADRs (kept
  separate from ADR-0008 and ADR-0009 for the reasons recorded there).

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

run-ui U1–U5 require one `RunShell` root with a screen stack mirroring Run
Structure's phases, a `RunController` as the sole talker to Run Structure,
Reward Draft and Meta Progression, read models in and intents out, a toast
layer, and (U10) a fixture seam that loads a profile into an in-memory Meta
stub; the systems index's gate condition says the MVP ships that stub. This
ADR fixes the shell pattern (`RunShell` + `ScreenStack` + `ShellState` +
`RunController` + `ToastLayer` + `Transition`), the `@abstract Screen`
contract, and the one seam the MVP depends on: `@abstract MetaApi`
(ADR-0004's interface) injected by `Boot.boot({meta: …})` as `MetaStub` now
(defaults from `config("profile_defaults")`, all heroes unlocked, saves held in
memory, no run log, no notifications) and as the `ProfileStore`-backed
`MetaFacade` later, with `RunDebugLoader` (`--run-ui-screen` /
`--run-ui-fixture`) using the same seam. Settings reach every consumer through
`SettingsBus.settings_changed` (DD-X07 / DD-X10).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2 stable — `VERSION.md`) |
| **Domain** | UI |
| **Layer** | Presentation |
| **Knowledge Risk** | **HIGH** — UI carries 4.5–4.7 changes (`VERSION.md`); each API this ADR depends on is sourced below or marked as 4.0-era training data |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `breaking-changes.md` (4.6→4.7 GUI rows, Input device ids, Project stretch defaults; 4.5→4.6 UI dual focus); `deprecated-apis.md` (`yield()`, string `connect`, `$NodePath` in `_process`, untyped containers, `event.device == 0`); `current-best-practices.md` (GDScript 4.5+ `@abstract`, 4.7 typed-return override rule, lambda capture; UI 4.6 dual focus; UI and Input 4.7 `offset_transform_*`, `DEVICE_ID_*`, `canvas_items` stretch default; Accessibility 4.5+ AccessKit, `FoldableContainer`, recursive Control disable); `modules/ui.md`; `modules/input.md` |
| **Post-Cutoff APIs Used** | `@abstract` class / method (4.5, sourced) — `Screen`, `MetaApi`; 4.7 typed-return override rule (sourced) — every `Screen` / `MetaApi` override returns explicitly; dual focus (4.6, sourced) — focus ring from keyboard focus only, hover is a lift; recursive Control disable (4.5, sourced) — the input lock during transitions and under `confirm`; `Control.offset_transform_*` (4.7, sourced) — hover lift on option panels inside containers; `InputEvent.DEVICE_ID_MOUSE / DEVICE_ID_KEYBOARD` (4.7, sourced) — never `device == 0`; `FoldableContainer` (4.5, sourced) — optional for the summary's drafted-cards section; `display/window/stretch/mode = canvas_items` (4.7 default for new projects, sourced; DD-T05 requires it either way) |
| **Verification Required** | (1) Recursive Control disable blocks mouse **and** keyboard focus for a whole base screen while `confirm` is up (sourced as a feature; the exact property name is **NOT SOURCEABLE** from the reference — test: a `scene_runner()` click and `ui_accept` on the base during `confirm` produce no intent); (2) `grab_focus()` on the default control after a transition lands keyboard focus without a mouse (4.6 dual focus, sourced) — fixture `hero_select` screenshot shows the ring on Start; (3) `DisplayServer.clipboard_set` for Copy seed under Xvfb — **NOT SOURCEABLE**; test asserts the flash, not the OS clipboard; (4) `tr()` key resolution with no translation file loaded returns the key (4.0 behaviour, training data) — test asserts a screen with no `.po` shows keys, not empty strings |

> If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated when the
> project upgrades engine versions.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (rules / presentation split; `Boot` as the one composition root whose `services()` only scene roots and debug loaders may call); ADR-0004 (save format — defines `MetaApi`, `ProfileStore`, `SettingsBus` and `MetaFacade`; this ADR only fixes how they are **injected** and consumed); ADR-0008 (match driver and the Run ↔ Match ↔ UI hand-off — `RunController` receives the `MatchDriver` from `RunMachine.begin_match()` and hands `MatchView` a `MatchController`). All `Proposed` or unwritten on 2026-11-03 |
| **Enables** | Every Run UI story; the nine run fixtures (U10); `/ux-review` of `design/ux/hero-select.md`, `draft-picker.md`, `run-summary.md` can assume this shell |
| **Blocks** | Run UI epic; the MVP build's main menu / hero select / boss intro / drafts / summaries; `data_error` screen (card-database CR-8) |
| **Ordering Note** | `MetaStub` can ship **before** ADR-0004's `ProfileStore` exists — that is the point of the seam — but `MetaApi` itself is ADR-0004's interface, so a change there is a change here. ADR-0009 supplies `CardFrame`, `PauseMenu` (settings panel) and the `Transition` helper's tween conventions; the Run UI epic can start on the shell and `main_menu` / `hero_select` before ADR-0009's presenters exist |

## Context

### Problem Statement

Run UI is every screen outside a match (run-ui U2: fourteen base screens and
overlays). Without one shell, each screen would talk to Run Structure, Reward
Draft and Meta directly, hold its own slice of run state (the prototype's
`set_meta` strings, TD-009) and infer state from its own last command. run-ui
U1 forbids all three; U4 adds a transition input lock and a per-screen
`committed` sub-state; U5 a toast queue with acknowledgement; U10 a debug seam
that must share the production Meta interface. The systems index's circular
dependency Run Structure ↔ Meta is resolved by shipping an in-memory Meta stub
for the MVP, which needs a seam that lets the real implementation replace it
with no second code path.

### Current State

No production UI code. `architecture.md` already declares `RunShell`,
`RunController`, `@abstract Screen`, `@abstract MetaApi`, `MetaStub` and
`RunDebugLoader` (§API Boundaries Feature / Presentation, §Screenshot capture
and the fixtures seam) and the `Boot.boot({meta: MetaStub.new(...)})`
selection. This ADR makes those binding and fills in the shell internals.

### Constraints

- **Display-only screens** (`ui-code.md`; U1.2): a screen never holds a `RunState` and never mutates game state.
- **Every visible mutation renders from an event** (DD-T04; U1.3): `run_floor_entered` → boss intro, `draft_offered` → draft, `run_ended` → summary, `run_warning` → toast.
- **Restart budget** (run-ui F1): path A ≤ 1350 ms at defaults, `new_run` ≤ 200 ms, `intro_ready` ≤ 300 ms, `select_ready` ≤ 300 ms, `restart_budget_ms` 5000.
- **Mouse primary, keyboard complete, gamepad maps onto the focus graph** (DD-T05; U3; `ui-code.md`).
- **Localisation**: every string a `tr()` key (U1.4).
- **Text scale 1.0 / 1.25 / 1.5 as three fixture-tested layouts**, never a slider (U2 settings row; AC-31).
- **Toast reading time** ≥ 5 s, one at a time, pause on hover / focus (U5; accessibility-requirements).
- **The MVP ships without `ProfileStore`** (systems-index gate condition; meta-progression Dependencies: "Soft for MVP (in-memory stub)").

### Requirements

- One root scene `run_shell.tscn` with a screen stack (base + overlays), `ShellState` `{base, overlays[], transitioning}` and the S1–S23 transition table (run-ui States).
- `RunController` as the only object calling `RunMachine`, `RewardDraft`, `MetaApi`; screens receive read models and send `intent(name, args)`.
- Toast queue per U5 and F3, including `ack_notification` on show and persistence across base transitions.
- `RunDebugLoader`: `--run-ui-screen=<id> --run-ui-fixture=<name>` loads `tests/fixtures/run_ui/<name>.json` into a `MetaStub` and opens the screen with no transition.
- Settings edited here, persisted by Meta, consumed live by Run UI, Match UI and Boss AI via `settings_changed` (DD-X07, DD-X10, cross-review C-01).

## Decision

### 1. Shell pattern

`RunShell extends Control` (`src/ui/run/run_shell.tscn`) is the root of
everything outside a match. Its children, in draw order: `ScreenStack`
(a `Control` holding exactly one **base** screen and zero or more **overlay**
screens as children, top-most last), `ToastLayer` (above every screen and
above the swapped-in `MatchView`, U5 persistence rule), `TransitionLayer`
(a full-rect `ColorRect` the `Transition` helper fades), and one
`CanvasModulate` for `gamma` (DD-X10). `RunShell._ready()` calls
`Boot.services()` once (the only place in `src/ui/run/` allowed to — ADR-0001
grep gate), constructs `RunController` with those services, subscribes to
`controller.screen_requested`, `match_requested`, `toast`, and opens the first
screen (`main_menu`, or `data_error` on a `Failed` load, S1/S2).

`ShellState` (`RefCounted`, plain data) is `{base: StringName, overlays:
Array[StringName], transitioning: bool, committed: bool}` and is the only
state the shell owns; it mirrors Run Structure's phase (run-ui States table)
but never stores run data. Screens are instantiated from a registry
`SCREENS: Dictionary[StringName, PackedScene]` (`src/ui/run/screens/<id>.tscn`,
one scene per U2 row; `match` is not a screen but the hand-off state). A base
change frees the outgoing base after the transition (`queue_free` under
`src/ui/` only); overlays push / pop. The base is hidden-not-freed only for
`match` (U2 `match` row).

`Transition` (`RefCounted` helper, `src/ui/common/transition.gd`) runs F2's
`t_transition = base_ms[kind] × speed_factor[anim_speed]` as one `Tween` on
`TransitionLayer` (`create_tween()`, 4.0-era, training data), sets
`ShellState.transitioning` for its duration, and ends early on `skip`. While
`transitioning`, `RunController.intent` drops everything except `skip` with
`ui_intent_rejected{reason: transitioning}` (U4). The outgoing base's input is
cut by the recursive Control disable (4.5, sourced) so no click lands during
the fade. This is the same tween convention ADR-0009 uses; no
`AnimationPlayer`.

`Screen` is `@abstract` (4.5, sourced): `bind(read_model: Dictionary)`,
`default_focus() -> Control`, `set_committed(on: bool)`, and a
`intent_requested(name: StringName, args: Dictionary)` signal the shell wires
to `RunController.intent`. A screen that sent a terminal intent (`pick`,
`start_run`, `begin_match`, `continue`) sets `committed` and ignores further
input until swapped out (U4); a rejection (`E_*`) uncommits it (U8). Screens
own no state beyond what `bind` gave them; re-`bind` on every read-model
change is the update path.

### 2. `RunController` — the only talker

`RunController` (`RefCounted`, `src/ui/run/run_controller.gd`) holds
`RunMachine`, `RewardDraft`, `MetaApi`, `CardDatabase` and `config("run_ui")`.
It implements the U2 intent → command map and the S1–S23 table as one
`match` over `(ShellState, intent)`; an unlisted pair is dropped with
`ui_intent_rejected{reason: bad_state}`. It subscribes to the run `EventLog`
(`run_log.subscribe`) and to `MetaApi.unlock_granted`; every screen change it
emits (`screen_requested(id, read_model)`) is caused by an event, never by its
own last command (U1.3). During `match` it **buffers** run-scope events and
applies them in `seq` order on `match_view_finished(result)` (S11). On
`begin_match` it receives the `MatchDriver` from `RunMachine.begin_match()`
and emits `match_requested(driver)`; `RunShell` instantiates `match_view.tscn`,
calls `set_controller(MatchController.new(driver))` (ADR-0008 / ADR-0009) and
hides the base.

Read models are plain Dictionaries built by `RunController.read_model()` from
`RunMachine.read_model()`, `RewardDraft`'s `Offer` read model
(`current_offer()`), `MetaApi` queries (`stats_for_hero`, `unlock_progress`,
`run_log`, `load_status`, `get_settings`) and `CardDatabase` records. The
`data_error` read model is the `ValidationReport` rows (CR-8).

### 3. `ToastLayer`

`ToastLayer extends Control` (`src/ui/run/toast_layer.gd`) owns the U5 queue:
enqueue from `run_warning` and from both unlock channels (`unlock_granted`
signal and `pending_notifications()` read on S1 and on every `run_ended`),
`ack_notification(key)` once per key **when shown**, one visible toast at a
time for `t_toast = clamp(toast_base_ms + chars × toast_per_char_ms,
toast_min_ms, toast_max_ms)` (F3; 5000 ms floor), timer paused while hovered
or focused, dismiss on click / `Enter`, `toast_gap_ms` between toasts,
`toast_queue_max` 8 dropping the oldest *warning* first. A queued toast may
**start** only while `ShellState.transitioning == false` and `base ∉ {match,
run_start, data_error}`; a *showing* unlock toast survives base transitions and
the `begin_match` hand-off because it lives on this layer, not on a screen
(cross-review S-05). Toast text is built from `kind + id` through
`CardDatabase` names (never a `name_key` in the payload).

### 4. The Meta seam

`MetaApi` is the `@abstract` base ADR-0004 defines (method list =
meta-progression M1.3, `architecture.md` §API Boundaries Feature). This ADR
fixes **injection and the stub**:

- `Boot.boot(overrides)` constructs the Meta implementation and places it in
  `Services.meta`; `RunMachine`, `RewardDraft` and `RunController` take it as a
  constructor argument and never downcast. **MVP rule:** until the
  `ProfileStore` story under ADR-0004 lands, `Boot` constructs
  `MetaStub.new(card_database)`; afterwards `MetaFacade.new(profile_store,
  unlock_evaluator, stats_fold)`. The switch is one line in `Boot`; nothing
  under `src/ui/run/` changes.
- `MetaStub` (`src/gameplay/meta/meta_stub.gd`, Feature layer per the layer
  map): `load_status()` = `FRESH`; `is_hero_unlocked` = true for every
  `HeroDef` in data; `unlocked_keys()` = every unlock key in data;
  `is_treasure_unlocked` = true; `save_active_run` / `load_active_run` /
  `clear_active_run` hold one record **in memory** (so S23 `suspend` → Continue
  works within a session and the S1–S5 save path is exercised; across launches
  there is no Continue, which is what run-ui Dependencies means by "no
  Continue"); `archive_run` returns `{ok: true, unlocks_granted: []}` and
  appends nothing; `run_log()` = `[]`; `pending_notifications()` = `[]`;
  `stats_for_hero` = zeros; `last_hero_id()` = null (→ War pre-selected,
  DD-X02); settings = `config("profile_defaults")` held in memory,
  `set_setting` clamps per M9 ranges and emits `settings_bus.settings_changed`.
  An optional `mirror: ProfileStore` lets a later build write-through without
  changing consumers.
- `SettingsBus` (`RefCounted`, `src/core/save/settings_bus.gd` — ADR-0004's
  class): `signal settings_changed(key: StringName, value: Variant)` and
  `get_setting(key)`. Run UI's `settings` screen calls `MetaApi.set_setting`;
  the implementation persists (or holds) and emits; `RunShell` applies
  `anim_speed` (F2), `text_scale` (theme overrides, three layouts), `gamma`
  (`CanvasModulate`), `high_contrast_states` (theme variation), volumes and
  `fullscreen`; `MatchView` and `BossAI` apply their own keys (ADR-0009,
  boss-ai C8.4). Nothing reads settings from Run UI; both UIs read the bus
  (match-ui Interactions "Run UI": settings are not handed over).
- `RunDebugLoader` (`src/ui/run/run_debug_loader.gd`, debug builds only) reads
  `--run-ui-screen=<id> --run-ui-fixture=<name>` from
  `OS.get_cmdline_user_args()`, loads `tests/fixtures/run_ui/<name>.json`
  (profile fields incl. settings → `MetaStub`; optional `RunRecord` →
  `MetaStub.save_active_run` then `RunMachine.resume()`; optional offer → the
  draft read model), calls `Boot.boot({meta: stub})`, and opens the screen
  with `t_transition = 0`. It is the same seam the MVP ships with — no second
  code path (`architecture.md` §Screenshot capture).

### 5. Input and focus

Mouse primary, keyboard complete (U3). Each screen declares its focus order
(UX spec Focus Order table) via `focus_neighbor_*` and a `default_focus()`
the shell calls after a transition with `grab_focus()` — keyboard focus only
(4.6 dual focus, sourced); hover is a lift via `offset_transform_*` on panels
inside containers (4.7, sourced) and never moves focus. The 2 px
`state_actionable` focus ring is drawn by a shared `FocusRing` script on
`focus_entered` / `focus_exited`, at every `anim_speed`. `1` / `2` / `3` move
focus to option *n* on three-option screens; `Esc` → `back` / `close` /
`cancel`; gamepad uses `ui_accept` / `ui_cancel` and d-pad neighbours. Events
are identified by type, never `device == 0` (4.7, sourced).

### Architecture Diagram

```
run_shell.tscn (RunShell, Control)                     Boot.services() — called here only
├── ScreenStack (Control)                              ┌─────────────────────────────────────┐
│   ├── <base>  e.g. hero_select.tscn (Screen)  ◄──bind(read_model)── RunController (RefCounted)
│   └── <overlay>* e.g. confirm.tscn (Screen)  ──intent(name,args)──► │ validates ShellState (S1–S23)
├── ToastLayer (Control)  ◄── toast(kind, payload) ────────────────── │ maps intent → command (U2)
├── TransitionLayer (ColorRect) ◄── Transition (F2 tween)             │ RunMachine.new_run/begin_match/
└── CanvasModulate (gamma, DD-X10)                                    │   draft_pick/abandon/resume/suspend/return_to_menu
                                                                      │ RewardDraft.current_offer() read model
   MatchView (match_view.tscn) swapped in on match_requested(driver)  │ MetaApi.* queries + set_setting/ack_notification/reset_profile
   └── match_view_finished(result) ──► RunController (S11: apply buffered run events)
                                                                      └─────────────────────────────────────┘
events in: run EventLog.subscribe → run_started / run_floor_entered / draft_offered / deck_grew /
           treasure_granted / run_warning / run_saved / run_ended / match_faulted → screen_requested(id, read_model)
           MetaApi.unlock_granted + pending_notifications() → ToastLayer
settings:  settings screen → MetaApi.set_setting → SettingsBus.settings_changed → RunShell / MatchView / BossAI

Meta seam:  Boot.boot({})            → MetaStub(db)  [MVP]        ┐ same @abstract MetaApi,
            Boot.boot({})            → MetaFacade(ProfileStore…)  ┤ same RunMachine / RewardDraft /
            RunDebugLoader           → Boot.boot({meta: stub-from-fixture}) ┘ RunController constructors
```

### Key Interfaces

Names match `architecture.md` §API Boundaries; additions marked `# new`.

```gdscript
# src/ui/run/run_shell.gd
class_name RunShell extends Control                    # src/ui/run/run_shell.tscn root
var state: ShellState
func open_base(id: StringName, read_model: Dictionary, kind: StringName = &"fade") -> void   # new; runs Transition
func push_overlay(id: StringName, read_model: Dictionary) -> void                              # new
func pop_overlay() -> void                                                                     # new
func swap_in_match(controller: MatchController) -> void                                        # new; hides base, keeps ToastLayer on top

class_name ShellState extends RefCounted               # new — plain data, mirrors run-ui States
var base: StringName; var overlays: Array[StringName]; var transitioning: bool; var committed: bool

# src/ui/run/run_controller.gd — architecture.md §API Boundaries, Presentation
class_name RunController extends RefCounted
func _init(run: RunMachine, draft: RewardDraft, meta: MetaApi, db: CardDatabase, ui_config: Dictionary) -> void
func intent(name: StringName, args: Dictionary) -> void   # validates ShellState, maps to a command (U2) or emits ui_intent_rejected
func read_model() -> Dictionary
func on_match_view_finished(result: MatchResult) -> void  # new — S11: apply buffered run-scope events in seq order
signal screen_requested(id: StringName, read_model: Dictionary)
signal match_requested(driver: MatchDriver)
signal toast(kind: StringName, payload: Dictionary)
signal ui_intent_rejected(name: StringName, reason: StringName)   # new — also appended to the run log as diagnostic (rule 12a) in debug builds

# src/ui/run/screen.gd
@abstract class_name Screen extends Control
@abstract func bind(read_model: Dictionary) -> void     # display-only; sends intents through the controller
@abstract func default_focus() -> Control               # new — the shell grab_focus()es it after a transition
func set_committed(on: bool) -> void                    # new — U4 terminal-intent sub-state
signal intent_requested(name: StringName, args: Dictionary)   # new — wired by RunShell to RunController.intent

# src/ui/run/toast_layer.gd — run-ui U5, F3
class_name ToastLayer extends Control                   # new
func enqueue(kind: StringName, payload: Dictionary) -> void          # kinds: unlock | warning
func set_idle(idle: bool) -> void                                    # shell tells it when a queued toast may start
signal shown(kind: StringName, key: String)                          # controller acks unlocks on this

# src/ui/common/transition.gd — run-ui F2 (shared tween convention with ADR-0009)
class_name Transition extends RefCounted                # new
func _init(layer: CanvasItem, ui_config: Dictionary, settings_bus: SettingsBus) -> void
func run(kind: StringName) -> Signal                    # returns `finished`; honours anim_speed (instant → 0 ms)
func skip() -> void

# src/gameplay/meta/meta_api.gd — ADR-0004's interface (restated; method list = meta-progression M1.3)
@abstract class_name MetaApi extends RefCounted
# is_hero_unlocked, unlocked_keys, is_treasure_unlocked, save_active_run, load_active_run, clear_active_run,
# archive_run, stats_for_hero, last_hero_id, unlock_progress, unlock_hint, get_settings, set_setting,
# run_log, run_log_entry, pending_notifications, ack_notification, reset_profile, load_status
signal unlock_granted(key: String, kind: StringName, id: String, by_run_id: String, retro: bool)
var settings_bus: SettingsBus

# src/gameplay/meta/meta_stub.gd — MVP implementation (this ADR)
class_name MetaStub extends MetaApi                     # new
func _init(db: CardDatabase, mirror: ProfileStore = null) -> void   # settings from db.config("profile_defaults")
# every override has an explicit `return` (4.7 typed-return rule)

# src/core/save/settings_bus.gd — ADR-0004's class, consumed here
class_name SettingsBus extends RefCounted
signal settings_changed(key: StringName, value: Variant)
func get_setting(key: StringName) -> Variant

# src/ui/run/run_debug_loader.gd — run-ui U10 (debug builds only)
class_name RunDebugLoader extends RefCounted            # new
static func from_args(args: PackedStringArray) -> Dictionary        # {screen, fixture}
func load_fixture(name: String) -> Dictionary                       # builds MetaStub from the JSON; returns Boot overrides
func open(shell: RunShell, screen: StringName) -> void              # no transition
```

### Implementation Guidelines

- `Boot` / `Services` **must** appear under `src/ui/run/` only in
  `run_shell.gd` and `run_debug_loader.gd` (ADR-0001 grep gate); screens and
  `RunController` **must never** reference them.
- A `Screen` **must never** hold a `RunState`, a `RunRecord`, a `MatchDriver`
  or a `MetaApi`; it **must** render only from the `bind` read model and
  **must** send every action as `intent_requested`.
- `RunController` **must** be the only object under `src/ui/run/` that calls
  `RunMachine`, `RewardDraft` or `MetaApi`; it **must** emit
  `screen_requested` only from an event handler, **never** from the command
  it just issued (U1.3).
- Every (state, intent) pair **must** be in the S1–S23 table or be dropped
  with `ui_intent_rejected`; the controller **must never** queue a dropped
  intent.
- While `ShellState.transitioning` is true, every intent except `skip`
  **must** be dropped (U4); a `committed` screen **must** ignore input until
  swapped out or uncommitted by a rejection.
- Run-scope events arriving during `match` **must** be buffered and applied
  in `seq` order on `match_view_finished` (S11); the shell **must never**
  change screen while `MatchView` is up.
- `ack_notification(key)` **must** be called exactly once per key, when the
  toast is shown; an unlock toast **must never** be dropped from the queue and
  **must** survive base transitions on `ToastLayer`.
- All timing, counts and sizes **must** come from `config("run_ui")`
  (`transition_ms.*`, `run_start_ms`, `toast_*`, `restart_budget_ms`, F4
  geometry) — **never** literals.
- All user-facing text **must** be a `tr()` key; data text follows
  Card Database's key-or-`text.en` rule.
- Settings **must** be written only through `MetaApi.set_setting` and read
  only through `SettingsBus` / `get_settings()`; Run UI **must never** pass
  settings to Match UI.
- `MetaStub` **must** implement every `MetaApi` method with an explicit
  `return` (4.7 rule) and **must** be constructible with a `CardDatabase`
  alone; tests under `tests/unit/run_ui/` **must** inject it directly, never
  through `Boot`.
- Focus **must** come from `grab_focus()` on `default_focus()` after every
  transition; the focus ring **must** draw from `focus_entered` /
  `focus_exited`; hover **must never** move focus (4.6 dual focus).
- `text_scale` **must** be one of three discrete theme-override sets (1.0 /
  1.25 / 1.5), each with a retained `_ts150` fixture screenshot (AC-31);
  **never** a continuous scale.
- Deprecated patterns **must not** appear: `yield()`, string `connect`,
  `$NodePath` in `_process`, untyped `Array` / `Dictionary`, `event.device == 0`.

## Alternatives Considered

### Alternative 1: One scene per screen with `change_scene_to_packed` and an autoload holding run state
- **Description**: Each screen is its own main scene; navigation swaps the whole tree; a global holds the `RunState` and the Meta handle.
- **Pros**: Idiomatic Godot tutorial shape; minimal shell code.
- **Cons**: Reintroduces TD-001 / TD-009 (global run state) and a second autoload (ADR-0001 forbids siblings of `Boot`); overlays (`confirm`, `pause`, `toast`) and the persistent progress strip would be rebuilt per scene; a toast could not survive a scene change (cross-review S-05); the restart budget (F1) pays a full scene reload per step.
- **Estimated Effort**: Lower for the first screen, higher for every overlay and for the state bugs.
- **Rejection Reason**: Violates ADR-0001's one-autoload rule and run-ui U1 (screens never hold state); fails S-05.

### Alternative 2: Screens call Run Structure / Meta directly, with a thin event bus
- **Description**: No `RunController`; each screen injects the services it needs and subscribes to the run log itself.
- **Pros**: Fewer indirections; each screen is self-contained.
- **Cons**: The S1–S23 table and the U4 input lock would be re-implemented per screen; "every visible mutation from an event" would be enforced in fourteen places; the Meta seam would have fourteen injection points; the GDD names `RunController` as the sole talker (U1.2).
- **Estimated Effort**: Lower per screen, far higher in total and in review.
- **Rejection Reason**: Contradicts U1.2; spreads the transition table.

### Alternative 3: No stub — build `ProfileStore` first and ship only the real `MetaFacade`
- **Description**: Block the Run UI epic on ADR-0004's persistence stories.
- **Pros**: One implementation; no stub drift.
- **Cons**: The systems index's gate condition and meta-progression Dependencies ("Soft for MVP") exist precisely to break the Run Structure ↔ Meta cycle; the MVP would wait on atomic writes, migrations, lock files and corruption handling (M4–M6) before showing a main menu; U10 fixtures need an in-memory profile regardless.
- **Estimated Effort**: Same code eventually, worse ordering.
- **Rejection Reason**: The stub is required by U10 anyway; making it the MVP's Meta costs nothing extra and unblocks the epic.

### Alternative 4: Stub via a `MetaApi` subclass that throws on persistence calls
- **Description**: `MetaStub.save_active_run` returns `E_READONLY`; no in-memory record.
- **Pros**: Simpler; matches the literal "no Continue".
- **Cons**: S23 `suspend` → Continue and the S1–S5 save path would be untestable until `ProfileStore` lands; `RunMachine` would see `E_IO`-like failures and emit `run_warning{save_failed}` toasts in every MVP run.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Produces spurious warnings and leaves the save path unexercised; in-memory is the recorded decision (see "Decisions taken" in the authoring report).

## Consequences

### Positive
- Run state has one owner (`RunMachine`) and one reader in the UI (`RunController`); TD-009's `set_meta` pattern has no place to live.
- The MVP ships a full menu → run → summary loop against `MetaStub`; swapping in `MetaFacade` is one line in `Boot` and touches no screen.
- Fixtures and the shipped build share the same Meta seam and the same `Boot` path — a Run UI screenshot can never show a state the shell cannot reach.
- Toasts, transitions and the input lock are implemented once; the S1–S23 table is one function to test.

### Negative
- `MetaStub` is a second implementation of nineteen methods that must track `MetaApi` changes (ADR-0004); drift shows up as a parse / abstract-method error, which is the acceptable failure mode.
- `RunController` is a large class (intent map + transition table + event handlers + read-model builders); it is split by concern into `run_controller.gd` + `run_read_models.gd` + `run_transitions.gd` but is still the single choke point.
- Buffering run-scope events during `match` means a crash between `match_ended` and `match_view_finished` loses only UI state (the run was saved at S2/S5 by Run Structure), but the shell must handle a buffered `run_ended` after a long banner.

### Neutral
- `ToastLayer` is a Node under the shell rather than part of `RunController`, so it can sit above `MatchView`; the controller still decides *when* a toast may start.
- `MetaFacade`'s internals (ADR-0004) are unaffected by anything here.

## Risks
- **Recursive Control disable property name / semantics on 4.7** (feature sourced, API NOT SOURCEABLE). Mitigation: the `confirm` overlay test clicks and `ui_accept`s the base; fallback is `mouse_filter = MOUSE_FILTER_IGNORE` + `focus_mode = FOCUS_NONE` applied by the shell to the base subtree.
- **Fixture profile drifts from the real profile schema** (M1.2). Mitigation: `RunDebugLoader` validates fixture profiles with the same `MetaStub.set_setting` clamps and `RunRecord.validate()`; a fixture that fails validation fails the integration test, not the screenshot run silently.
- **Toast persistence across the `begin_match` hand-off overlaps the intent banner.** Mitigation: `ToastLayer` anchors top-right (U5) clear of the banner rect in match-ui F6; the `toast_sample` fixture over `boss_turn_playback` is captured.
- **Restart budget regressions** (F1 `new_run` 200 ms, `intro_ready` 300 ms). Mitigation: `RunController` timestamps S18 → S9 → `boss_intro` ready in debug builds and the profile test asserts the three measured steps.
- **`tr()` with no translation loaded** returns the key (training data). Mitigation: a smoke test asserts non-empty labels on every screen; v1 ships `en` keys as the fallback text table.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| run-ui.md | TR-run-ui-001 — U1: `RunShell` root with screen stack and `ShellState`; `RunController` the only talker; read models in, `intent(name, args)` out; every visible mutation from an event | Decision §1–2; `Screen` abstract; `screen_requested` emitted only from event handlers |
| run-ui.md | TR-run-ui-002 — U2: screen inventory and intent → command map; `data_error` over a `Failed` load | `SCREENS` registry (one scene per U2 row); `RunController.intent` implements the map; S2 |
| run-ui.md | TR-run-ui-003 — U3: mouse primary, keyboard complete; focus ring separate from hover (4.6); gamepad on the focus graph | Decision §5; `default_focus()`; `FocusRing`; `ui_accept` / `ui_cancel` |
| run-ui.md | TR-run-ui-004 — U10: `--run-ui-screen` / `--run-ui-fixture` into an in-memory Meta stub | `RunDebugLoader` + `Boot.boot({meta: stub})` — the same seam the MVP ships |
| run-ui.md | TR-run-ui-005 — F1: `restart_budget_ms` 5000; `new_run` ≤ 200, `intro_ready` ≤ 300, `select_ready` ≤ 300 | No scene reloads between steps; F2 transitions skippable and 0 at `instant`; debug timestamps per step |
| run-ui.md | U4 (transition input lock, `committed`), U5 / F3 (toast queue, ack on show, persistence across transitions), U6 (strip from read model), S1–S23 | `Transition`, `ShellState.transitioning`, `Screen.set_committed`; `ToastLayer`; strip rendered by `bind(read_model)`; one transition function |
| meta-progression.md | TR-meta-progression-001 — M1.3 persistence API surface | Consumed only through `MetaApi`; `MetaStub` implements the full M1.3 list |
| meta-progression.md | TR-meta-progression-005 — M9 settings owned by Meta, defaults from `config("profile_defaults")`, applied via `settings_changed`; MVP in-memory stub | `MetaStub` settings from `profile_defaults`; `SettingsBus`; Run UI edits, never owns |
| meta-progression.md | Dependencies: "Soft for MVP (in-memory stub: no Continue across launches, all heroes unlocked, no log, session-local settings), Hard from Vertical Slice" | `MetaStub` behaviour list in Decision §4; `MetaFacade` swap in `Boot` |
| run-structure.md | TR-run-structure-003 — seven commands and the transition table; `E_BAD_PHASE` elsewhere | `RunController` issues exactly those commands; `ShellState` mirrors the phase machine |
| run-structure.md | TR-run-structure-004 — save points through Meta's API; resume semantics | `RunMachine` → `MetaApi` (stub or facade); `resume_prompt` S4–S6 |
| reward-draft.md | TR-reward-draft-001 — `Offer{option_ids[], flags[]}` read model; `pick` is Run Structure's `draft_pick` | U8 contract: `pick(index)` → `draft_pick(kind, option_ids[index])`; synergy hint from `current_offer()` |
| match-ui.md | TR-match-ui-006 — hand-off: Run UI swaps `MatchView` in with `MatchConfig` + `MatchController`; `match_view_finished(result)` back | `swap_in_match`, `on_match_view_finished` (S10, S11); settings not handed over |
| systems-index.md | TR-systems-index-001 — Run Structure ↔ Meta: MVP ships a Meta stub | `MetaStub` through the `MetaApi` seam |
| systems-index.md | TR-systems-index-002 — Match UI ↔ Run UI one-way hand-off; reverse edge a signal | `match_requested` out, `match_view_finished` in; `ToastLayer` above both |
| card-database.md | TR-card-database-002 — `Failed` load has no main menu (CR-8) | S2 → `data_error`, terminal |
| design-decisions.md | TR-design-decisions-003 — DD-T05; DD-X02 (War pre-selected, never forced); DD-X07 / DD-X10 settings keys | 1280x720 `canvas_items`; `last_hero_id()` null → War; settings screen rows = the M9 key set incl. `gamma` |

## TD Items Retired

| TD | Prototype root cause | How this ADR rules it out |
|---|---|---|
| TD-009 (run-state-in-screens half) | Run state kept in `set_meta` strings on nodes | Screens hold no run data; `RunController` reads `RunMachine.read_model()`; `ShellState` is the only shell-owned state and carries no run fields; `/create-control-manifest` rule: `set_meta` / `get_meta` banned under `src/ui/run/` |
| TD-006 (display half) | UI mutated game state | Intents → `RunController` → commands; screens have no handle to `RunMachine`, `RewardDraft` or `MetaApi` |

(TD-009's typed-`RunState` half is ADR-0008's; its modifier half is ADR-0005's.)

## Verification / How We Know

| Claim | Evidence today | Test that proves it |
|---|---|---|
| `@abstract` classes / methods on 4.5+; overrides need explicit `return` on 4.7 | **Sourced**: `current-best-practices.md` § GDScript 4.5+ and 4.7; `breaking-changes.md` 4.6→4.7 GDScript row | Parse check (`godot-parse-check.gd`) on `MetaStub`, `Screen` subclasses; a unit test instantiates `MetaStub` and calls all nineteen methods |
| Keyboard focus separate from hover (4.6) | **Sourced**: `modules/ui.md`, `modules/input.md` | Fixture `locked_heroes` screenshot: ring on Start while the cursor hovers a panel; `scene_runner()` asserts `get_viewport().gui_get_focus_owner()` |
| Recursive Control disable (4.5) blocks a base subtree | **Sourced** as a feature (`current-best-practices.md` § Accessibility 4.5+, `modules/ui.md`); exact API **NOT SOURCEABLE** | `tests/integration/run_ui/test_confirm_blocks_base.gd`: click + `ui_accept` on the base under `confirm` → no intent |
| `Control.offset_transform_*` for hover lifts in containers | **Sourced**: `modules/ui.md` § 4.7 | `draft_bundle_sample` hover pose screenshot; panel `position` unchanged while lifted |
| `create_tween()`, `CanvasModulate`, `tr()`, `grab_focus()`, `OS.get_cmdline_user_args()`, `OS.is_debug_build()` | Training data (4.0-era, LOW); `grab_focus()` also in `modules/ui.md` | Exercised by every shell test; parse check catches a missing symbol |
| S1–S23 transition table complete; unlisted pairs dropped | GDD table | `tests/unit/run_ui/test_run_controller_transitions.gd`: every row, plus a sweep of every (state, intent) pair asserting `ui_intent_rejected{bad_state}` for the rest |
| Toast rules (F3 bounds, ack once, persistence across transitions, idle gating) | GDD U5 / F3 worked examples (32 chars → 5960 ms; cap 8000) | `tests/unit/run_ui/test_toast_layer.gd` with a fake clock; `toast_sample` fixture screenshot during a transition |
| Restart budget F1 (path A 1350 ms, measured steps ≤ 200 / 300 / 300 ms) | GDD arithmetic | Profile test on the `defeat_sample` → New Run path with debug timestamps |
| `MetaStub` ≡ `MetaApi` contract | Design | Contract test suite run against **both** `MetaStub` and (later) `MetaFacade`: same return shapes, same error codes for M9 range clamps |
| Fixtures reach every base screen with no second code path | Design | `tests/integration/run_ui/test_fixtures_load.gd` over the nine required fixtures + the three `_ts150` variants; retained screenshots under ADR-0010's launch line |
| Clipboard under Xvfb for Copy seed | **NOT SOURCEABLE** | Test asserts the "Copied" flash and the string passed to the clipboard call, not the OS clipboard |

## Performance Implications
- **CPU**: idle shell costs nothing per frame beyond the toast timer and an active `Transition` tween; `RunController.read_model()` is O(deck + floors) and built per screen change, not per frame; `run_log` pages are read on demand (`load_more`).
- **Memory**: one base screen + overlays instantiated at a time; the `SCREENS` registry preloads fourteen small `PackedScene`s; `MetaStub` holds one `RunRecord` and the settings record.
- **Load Time**: `select_ready` ≤ 300 ms and `intro_ready` ≤ 300 ms (run-ui F1) are the binding budgets; the registry preload happens at `RunShell._ready` inside the boot budget.
- **Network**: n/a.

## Migration Plan

Greenfield. Story order: `ShellState` + `RunController` transition table
(headless) with `MetaStub` → `RunShell` + `Transition` + `main_menu` /
`hero_select` + `RunDebugLoader` with `fresh_profile` and its first retained
screenshot → `boss_intro` + progress strip → drafts (needs ADR-0009's
`CardFrame`) → summaries → `settings` / `pause` / `confirm` / `toast` →
`run_log` / `run_detail` (empty under the stub; filled when `MetaFacade`
lands) → the `Boot` one-line swap to `MetaFacade` when ADR-0004's
`ProfileStore` story closes, with the contract suite run against both.

**Rollback plan**: the shell pattern is internal to `src/ui/run/`; if the
single-controller shape proves too large, split `RunController` by screen
family behind the same `intent` entry point. The Meta seam has no rollback
need: `MetaStub` stays as the fixture / test implementation forever.

## Validation Criteria

- All nine required fixtures and three `_ts150` variants load and have retained screenshots; AC-31 (150 % reflow) passes on the three stressed layouts.
- Transition-table sweep: every S1–S23 row passes; every other (state, intent) pair is rejected with `bad_state`.
- run-ui F1 measured: path A ≤ 1350 ms at defaults, `new_run` ≤ 200 ms, `intro_ready` ≤ 300 ms, `select_ready` ≤ 300 ms.
- Toast tests: 5000 ms floor, ack exactly once, unlock toast survives a base transition and the `begin_match` hand-off.
- `MetaApi` contract suite green against `MetaStub`; green again against `MetaFacade` on the swap.
- Grep gates: no `Boot` / `Services` outside `run_shell.gd` and `run_debug_loader.gd` under `src/ui/run/`; no `set_meta` / `get_meta`; no deprecated patterns.

## Related
- Depends on: ADR-0001 (composition root, display-only UI), ADR-0004 (`MetaApi`, `ProfileStore`, `SettingsBus`, `MetaFacade`), ADR-0008 (`RunMachine`, `MatchDriver`, hand-off). Consumes ADR-0009's `CardFrame`, `PauseMenu` and tween convention. Sibling: ADR-0010 (capture launch line for the fixtures).
- `docs/architecture/architecture.md` §Dependency injection and the composition root, §Data Flow 3–5, §API Boundaries Feature (`MetaApi`, `MetaStub` paragraph) and Presentation (Run UI), §Screenshot capture and the fixtures seam, §Required ADRs (why 0011 is separate), §Decisions taken 4 and 7.
- `design/gdd/run-ui.md` U1–U10, States and Transitions S1–S23, F1–F4, Interactions, Dependencies; `design/gdd/meta-progression.md` M1.3, M9, Dependencies; `design/gdd/run-structure.md` R1–R8, T1–T21; `design/gdd/reward-draft.md` D1, D8, D9, D11; `design/gdd/match-ui.md` U9 "Match end", Interactions "Run UI"; `design/gdd/systems-index.md` Circular Dependencies; `design/design-decisions.md` DD-T05, DD-X02, DD-X07, DD-X10.
- `design/ux/hero-select.md`, `draft-picker.md`, `run-summary.md`, `interaction-patterns.md`; `design/accessibility-requirements.md`.
- `.claude/rules/ui-code.md`; `.claude/docs/run-and-observe.md`.
- Code (once implemented): `src/ui/run/run_shell.{gd,tscn}`, `run_controller.gd`, `shell_state.gd`, `screen.gd`, `toast_layer.gd`, `run_debug_loader.gd`, `src/ui/run/screens/*.tscn`, `src/ui/common/transition.gd`, `src/gameplay/meta/meta_api.gd`, `meta_stub.gd`, `src/core/save/settings_bus.gd`, `tests/fixtures/run_ui/*.json`, `tests/unit/run_ui/`, `tests/integration/run_ui/`.
