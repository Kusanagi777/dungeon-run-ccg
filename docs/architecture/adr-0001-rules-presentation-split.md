# ADR-0001: Rules / Presentation Split

## Status

Accepted

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner. `technical-director` is the role
> `coordination-rules.md` escalates technical conflicts to.

Review record for this authoring run (2026-11-03, `/architecture-decision`,
headless, `automation: guided`, `review_mode: lean`, `workflow: standard`):

- **TD-ADR skipped — Lean mode.** No `technical-director` gate ran; acceptance
  is a separate step.
- **Engine specialist validation: NOT ASSESSED** — `godot-specialist` was not
  spawned in this headless run (same reasoning as `architecture.md` Document
  Status: a specialist answering from pre-4.3 training data is what
  `VERSION.md` warns against). Every engine claim below cites
  `docs/engine-reference/godot/` or is marked `NOT SOURCEABLE` with the test
  that will prove it.
- **GDD sync: checked 6 referenced GDDs** (`match-rules`, `match-ui`, `run-ui`,
  `boss-ai`, `systems-index`, `design-decisions`) — this ADR renames nothing;
  every class and signal name is the one the GDD or `architecture.md`
  §API Boundaries already uses.
- Numbering fixed by `design/design-decisions.md` DD-X08.
- **TD review 2026-11-03 (acceptance pass over ADR-0001..0011):** no change to
  this ADR; its TD list agrees with `architecture.md` §Tech-debt retirement
  mapping (TD-008/TD-011 are ADR-0002's, TD-002/004 ADR-0007's, TD-007 ADR-0003's,
  TD-009 split across ADR-0004/0005/0008/0011).
- **Erratum 2026-11-03 (boot-composition-root story 004)**: on Godot 4.7.2 a script declaring `class_name Boot` that is also registered as the autoload `Boot` fails to parse ("Class \"Boot\" hides an autoload singleton") and the autoload never loads. `src/core/boot.gd` is therefore `extends Node` with no `class_name`; the autoload name `Boot` and every `Boot.boot()` / `Boot.services()` / `Boot.booted` reference work unchanged; tests that need a fresh instance `preload` the script. Also observed: gdUnit4 runs under `godot -s` do create autoloads (`/root/Boot` idle, `booted == false`), answering QQ-04.
- **Erratum 2026-11-03 (engine validation, `docs/architecture/engine-validation-2026-11-03.md`)**: G2b's negative look-ahead does not run on the installed ripgrep 14.1.0 and would flag the `await plan_turn/score_all` lines ADR-0006 requires; replaced by the deny-list pattern in the gate table. Advisory: G2 `%[A-Z]` false-positives on `"%X" % v`; G1 misses `extends Button/Label/Resource`; `@abstract` refusal is parse-time, so Verification (1) is a parse-check test.
- **Erratum 2026-11-03 (code review)**: two gate patterns in Decision 6 were wrong. **G6** `randi\(|randf\(|…` flagged the legitimate injected-stream calls `stream.randf()` / `stream.randi_range()` and missed bare `randi_range(`, `randf_range(` and `seed(`; it is now `(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|pick_random\(` — the `(^|[^.\w])` prefix is the look-around-free way to skip `obj.` calls and identifiers that end in a token (`_fork_seed(`), and `\.shuffle\(\)` / `pick_random\(` are kept (the global-RNG `Array` methods; `stream.shuffle(deck)` takes an argument and is not hit). The same correction applies to the ADR-0003 rule 7 lint token list. **G3** excluded only `boot.gd`, but `src/core/services.gd` and `src/core/boot_result.gd` are the composition root's own types and name `Boot` / `Services` by definition; G3 now also excludes those two files and drops doc-comment lines (`^\s*##`) as a second filter, so prose that describes the composition root is not a reference to it. Verified on ripgrep 14.1.0 against the current tree (0 hits each) and a planted file (every bare call hit; `stream.randf()`, `self.randf()`, `stream.shuffle(cards)`, `rng.seed = 4`, `_fork_seed(1)` not hit).
- **Accepted 2026-11-03 by technical-director** on the owner's standing approval of the project plan (plan approved 2026-11-03; "accept each" step). Owner may revert to Proposed.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2 (`docs/engine-reference/godot/VERSION.md`)
and `docs/architecture/architecture.md` v1.

## Decision Makers

Jacob (Head of Design, owner; standing approval for this run) · `/architecture-decision`
skill (author) · `technical-director` (acceptance, pending).

## Summary

Every prototype defect in TD-001/003/005/006 came from match rules living in
`Node`s and in one autoload singleton. This ADR makes DD-T02 binding: everything
under `src/gameplay/` and `src/ai/` is `RefCounted`, takes its collaborators in
`_init`, references no Node, no autoload and no scene, and runs headless; `src/ui/`
is display-only and talks to the rules through exactly three channels (commands
in, events out, value-copy queries out, all via `MatchController`); one lazy
autoload `Boot` is a composition root that owns no game state; grep gates enforce
the split in CI.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7 — `docs/engine-reference/godot/VERSION.md`) |
| **Domain** | Core (GDScript / scripting architecture) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH — 4.7 is post-cutoff (`VERSION.md`); the GDScript features this ADR relies on were added in 4.5 and changed in 4.7 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `current-best-practices.md` (§GDScript 4.5+, §GDScript 4.7, §Command Line, §Tooling), `deprecated-apis.md`, `breaking-changes.md` (4.6→4.7 GDScript rows) |
| **Post-Cutoff APIs Used** | `@abstract` classes and methods (4.5 — `current-best-practices.md` §GDScript 4.5+) for `MetaApi`, `Screen`, `Presenter`, `PlannerTask`; the 4.7 rule that an override of a typed method inherits the return type and needs an explicit `return` (`breaking-changes.md` 4.6→4.7 "Overrides inherit a typed return"); lambdas capture locals by value, so event subscribers share state through a Dictionary or object (`current-best-practices.md` §GDScript 4.5+) |
| **Verification Required** | (1) `@abstract` base classes parse and refuse direct instantiation on 4.7.2 — covered by the first unit test that instantiates a concrete `MetaStub`; (2) `NOT SOURCEABLE — whether a `godot --headless -s GdUnitCmdTool.gd` run instantiates `[autoload]` entries` (architecture QQ-04). Test: a gdUnit4 test asserts `Boot.booted == false` after the suite starts, and the per-file parse check (`.claude/scripts/godot-parse-check.gd`) proves rules files load with no autoload present either way |

> Knowledge Risk is HIGH, so this ADR must be re-validated on any engine upgrade:
> mark it Superseded and write a new ADR.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (first ADR; DD-T02 is the design decision it binds) |
| **Enables** | ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011 — every other ADR assumes this layer split |
| **Blocks** | Every Core and Foundation epic (`/create-stories` stops at `standard` for a missing Foundation ADR); the test-rig story (fixtures launch `match_view.tscn` through `Boot`) |
| **Ordering Note** | Accept before ADR-0002/0003 so the composition root they inject through is settled; the directory layout below is what `.claude/rules/*-code.md` path globs already bind to |

## Context

### Problem Statement

The January 2026 prototype (`prototypes/hearthstone-clone-2026-01/`) could not
run a match headless and could not be unit-tested: a 1,144-line `GameManager`
autoload owned match flow, mana, combat and run state (TD-001); minions were
`Control` nodes owning their own stats and freeing themselves, so death resolved
twice (TD-005); the board was never registered and existed only as scene-tree
children (TD-003); and the UI and the AI mutated state by reparenting nodes
(TD-006). DD-T02 already says "rules are `RefCounted` with no Node references; the
UI subscribes to events and issues commands". This ADR decides *how* that is
made true and kept true before the first production rules file is written.

### Current State

No production code exists under `src/` yet. `tests/helpers/` already models the
contracts (`TestRngService`, `TestEventLog`, `MatchFactory` field names, sides
`"player"` / `"boss"`), `project.godot` has `run/main_scene = res://src/scenes/boot.tscn`
and no rules autoload, and `architecture.md` fixes the layer map, directory layout
and API Boundaries this ADR binds.

### Constraints

- DD-T02 (rules purity), DD-T04 (one mutation, one event; UI renders from events)
  and Pillar 4 (legibility: the log alone explains a match).
- `.claude/rules/gameplay-code.md` ("no static singletons for game state — use
  dependency injection"; "no direct references to UI code"), `ui-code.md` ("UI must
  never own or directly modify game state"), `ai-code.md` (2 ms per frame).
- match-ui U11 and run-ui U10 launch `match_view.tscn` / `run_shell.tscn`
  **directly** for screenshot fixtures, so composition must be reachable from a
  scene root without `main.tscn`.
- The parse check runs per file (`current-best-practices.md` §Command Line:
  `--check-only` is not a parse check when a script names an autoload), so rules
  files must parse with no autoload present.
- `coding-standards.md`: all public methods unit-testable, dependency injection
  over singletons; gdUnit4 headless (`commands.test` in `project.yaml`).

### Requirements

- A match and a run must run to completion under `godot --headless` with no scene
  tree beyond the gdUnit4 runner (TR-match-rules-001, TR-design-decisions-001).
- Human input, Boss AI and Run Structure must all drive the engine through the
  same `submit()` (TR-match-rules-002; match-ui U2; boss-ai Interactions "just
  another command issuer").
- The UI must have no channel to rules state other than events and value copies
  (TR-match-ui-001, TR-run-ui-001).
- One composition point that debug loaders can override with fixtures and stubs
  (TR-match-ui-004, TR-run-ui-004, TR-systems-index-001 `MetaStub`).
- Each `.claude/rules/*-code.md` file must apply to exactly the code it was written
  for (directory layout).

## Decision

**Three tiers of code, one direction of dependency, one composition root.**

1. **Rules tier — `src/gameplay/**` and `src/ai/**`.** Every class `extends
   RefCounted` (records may be plain Dictionaries with `to_dict()`/`from_dict()`
   wrappers). Collaborators arrive through `_init(...)` or an explicit `bind(...)`
   (`RulesEngine._init(db, rules_config, resolver)`, `BossAI._init(boss_def,
   resolved_profile, band, ai_stream, op_values, log)`, `RunMachine._init(db, meta,
   draft, treasures, run_config, driver_factory)` — `architecture.md` §API
   Boundaries is normative). The tier never names `Boot`, `Services`, `get_tree()`,
   `get_node()`, `$`, `%`, `queue_free`, `Node`, `Control`, `Tween`, `Timer`,
   `await`, `preload` of a `.tscn`, or any global RNG call. Rules state is plain
   data (`MatchState`, `RunState`); derived values are functions, never fields
   (match-rules C1).
2. **Foundation tier — `src/core/**`.** `CardDatabase`, `RngService`/`RngStream`,
   `EventLog`, `ProfileStore` (+ `SettingsBus`) are `RefCounted` services with the
   same injection rule; they are the only code that touches `FileAccess`,
   `DirAccess`, `RandomNumberGenerator` and `user://`. `src/core/boot.gd` is the
   exception described in 4.
3. **Presentation tier — `src/ui/**` and `src/scenes/**`.** May hold Nodes. Talks to
   the rules through exactly three channels: **commands in** (`MatchController.submit(Command)
   -> CommandResult`, `RunController.intent(name, args)` mapped to `RunMachine`
   commands), **events out** (`subscribe(Callable)` / `events_since(seq)` on the
   controller, delivering `{seq, turn, type, payload, cause_seq}` in order), and
   **queries out** (`MatchQuery.*`, `RunMachine.read_model()` — value copies only,
   never a live object). Presenters are projections of events; a presenter that
   holds a number the view-state cannot reproduce from events is a defect
   (match-ui U1, U3 idle invariant). `queue_free` appears only here.
4. **One autoload, `Boot` (`src/core/boot.gd`, `extends Node` with **no** `class_name` — erratum 2026-11-03), as a
   lazy composition root.** `_ready()` does nothing. `boot(overrides: Dictionary =
   {}) -> BootResult` constructs `CardDatabase` and calls `load(validators)` with
   the validators collected from `EffectValidator`, `BossAI`, `Treasures`,
   `MetaProgression` and each config owner, constructs `ProfileStore` (or the
   `MetaStub` an override names), `SettingsBus`, and returns; `services() ->
   Services` is a plain `RefCounted` bag `{card_database, profile_store, meta:
   MetaApi, settings_bus}`. `Boot` owns no `MatchState`, `RunState`, deck, floor or
   any other game state, runs no process tick, and is referenced only from
   `src/scenes/`, `src/ui/**/*_view.gd`, `src/ui/**/run_shell.gd`,
   `*_debug_loader.gd` and `tests/`. It is the single entry in `project.godot
   [autoload]`; a second autoload is an architecture change (new ADR).
5. **Directory layout** is the one in `architecture.md` §Directory layout
   (`src/core/{data,rng,log,save}`, `src/gameplay/{match,effects,run,draft,
   treasures,heroes,meta}`, `src/ai/`, `src/ui/{match,run,shared}`, `src/scenes/`),
   chosen so `.claude/rules/engine-code.md`, `gameplay-code.md`, `ai-code.md` and
   `ui-code.md` path globs each cover exactly one tier.
6. **Grep gates** (CI, `/create-control-manifest` Forbidden rows; `rg --glob "*.gd"`
   — ripgrep has no `gdscript` type, `current-best-practices.md` §Tooling):

   | Gate | Pattern | Scope | Expected |
   |---|---|---|---|
   | G1 no Node in rules | `extends (Node|Control|Node2D|CanvasItem|Timer)` | `src/gameplay/**`, `src/ai/**` | 0 hits |
   | G2 no tree access in rules | `get_tree\(|get_node\(|\$[A-Za-z%]|%[A-Z]|queue_free|add_child` | `src/gameplay/**`, `src/ai/**`, `src/core/**` (minus `boot.gd`) | 0 hits |
   | G2b no coroutines in rules | `\bawait\b` | `src/gameplay/**`, `src/core/**` (minus `boot.gd`); under `src/ai/**` `await` is allowed only on the planner's own coroutines (`checkpoint()`, `plan_turn`, `score_all`, lethal search — ADR-0006's time-slicing seam), so the gate there is a look-around-free deny-list: `\bawait\b.*(get_tree|process_frame|physics_frame|create_timer|\.timeout|\.finished|tween|signal)` (ripgrep 14 rejects `(?!…)`; erratum 2026-11-03, engine validation) | 0 hits |
   | G3 no composition root in rules | `\bBoot\b|\bServices\b` | `src/gameplay/**`, `src/ai/**`, `src/core/**` (minus `boot.gd`, `services.gd`, `boot_result.gd`; hit lines that are doc comments, `^\s*##`, are dropped by a second filter — ripgrep has no look-around) (erratum 2026-11-03, code review) | 0 hits |
   | G4 one autoload | `^[A-Za-z_]+=` lines under `[autoload]` in `project.godot` | — | exactly 1, named `Boot` |
   | G5 UI never mutates | `\.submit\(` outside `*_controller.gd`, `*_driver.gd`, `*_view.gd` input path; `MatchState|RunState` type names | `src/ui/**` | 0 hits of state types; `submit` only via the controller |
   | G6 no global RNG in rules | `(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|pick_random\(` (erratum 2026-11-03, code review) | `src/gameplay/**`, `src/ai/**` | 0 hits (owned by ADR-0003, listed here because it is the same gate script) |

   Each gate is a distinctive token, not a word (`skill-authoring.md` "assert
   something that cannot be true by accident"), and the gate script is run once
   against a deliberately broken file before it is trusted.
7. **Interfaces with two implementations use `@abstract` base classes** (4.5,
   sourced): `MetaApi` (facade / `MetaStub`), `Screen`, `Presenter`,
   `PlannerTask`. Overrides of typed methods return explicitly (4.7 rule).

### Architecture Diagram

```
 src/ui/** (Nodes)            src/gameplay/** · src/ai/** (RefCounted)      src/core/** (RefCounted)
 ┌──────────────┐  commands ► ┌──────────────────────────────┐  reads ►  ┌──────────────────────┐
 │ MatchView    │ ──────────► │ MatchDriver ─► RulesEngine   │ ────────► │ CardDatabase         │
 │  presenters  │ ◄────────── │             ─► EffectResolver│ appends ► │ RngService / EventLog│
 │ RunShell     │  events     │             ─► BossAI        │ ────────► │ ProfileStore         │
 │  screens     │ ◄─ queries ─│ RunMachine · RewardDraft     │           │ SettingsBus          │
 └──────┬───────┘ (copies)    └──────────────────────────────┘           └──────────▲───────────┘
        │ services()                                                               │ constructs
        ▼                                                                          │
 src/core/boot.gd  Boot (the one autoload, lazy) ──────────────────────────────────┘
        ▲ called only by src/scenes/main.tscn, *_view.gd, run_shell.gd, *_debug_loader.gd, tests/
 dependencies point DOWN only · events and signals travel UP only · Boot is never named by rules
```

### Key Interfaces

```gdscript
# src/core/boot.gd — the one autoload (architecture.md §API Boundaries, Foundation)
extends Node                                          # autoload name `Boot`; no class_name (erratum 2026-11-03)
func boot(overrides: Dictionary = {}) -> BootResult    # idempotent; overrides: {meta: MetaApi, card_database: CardDatabase, ...}
func services() -> Services                            # {card_database, profile_store, meta: MetaApi, settings_bus}
var booted: bool                                       # false until boot(); asserted by the QQ-04 test

class_name Services extends RefCounted                 # plain bag; no behaviour
var card_database: CardDatabase; var profile_store: ProfileStore; var meta: MetaApi; var settings_bus: SettingsBus

class_name BootResult extends RefCounted               # {ok: bool, report: ValidationReport, load_status: StringName}

# The three UI channels (match-ui U2; names from architecture.md §Presentation)
class_name MatchController extends RefCounted
func _init(driver: MatchDriver) -> void
func submit(command: Command) -> CommandResult; func legal_commands() -> Array[Command]; func query() -> MatchQuery
func subscribe(cb: Callable) -> void; func events_since(seq: int) -> Array; func tick() -> void

class_name RunController extends RefCounted
func _init(run: RunMachine, draft: RewardDraft, meta: MetaApi, db: CardDatabase, ui_config: Dictionary) -> void
func intent(name: StringName, args: Dictionary) -> void
func read_model() -> Dictionary

# Rules-tier constructor shape (every class under src/gameplay/** and src/ai/**)
class_name RulesEngine extends RefCounted
func _init(db: CardDatabase, rules_config: Dictionary, resolver: EffectResolver) -> void
```

Full signatures for every class are in `architecture.md` §API Boundaries; this
ADR fixes the *shape* (RefCounted, `_init` injection, three channels), ADR-0007
and ADR-0008 fix the resolver and driver contracts.

### Implementation Guidelines

- Code under `src/gameplay/**` and `src/ai/**` **must** `extends RefCounted` (or be
  a plain Dictionary record) and **must** receive every collaborator through
  `_init(...)` or an explicit `bind(...)`.
- Rules code **must never** reference `Boot`, `Services`, `get_tree()`, `get_node()`,
  `$`/`%` node paths, `queue_free`, `add_child`, `Tween`, `Timer`, a `.tscn`, or a
  global RNG function (gates G1–G3, G6); `await` is banned under `src/gameplay/**`
  and `src/core/**`, and under `src/ai/**` is allowed only as
  `await <planner>.checkpoint()` (gate G2b; ADR-0006).
- UI code **must** mutate match or run state only by calling `MatchController.submit`
  or `RunController.intent`; it **must never** hold a `MatchState`/`RunState` or a
  live rules object, and **must** render numbers from events, not from queries
  (gate G5; match-ui U2/U3).
- `Boot` **must** stay idle in `_ready()`; `boot()` **must** be idempotent; `Boot`
  **must never** hold game state or a process tick; `project.godot [autoload]`
  **must** contain exactly `Boot` (gate G4).
- Scene roots (`MatchView`, `RunShell`, `main.tscn`) and `*_debug_loader.gd` are
  the only non-test callers of `Boot.services()`; they **must** pass the services
  down by argument, never re-fetch them deeper in the tree.
- Tests under `tests/unit/**` **must** construct rules objects with
  `TestRngService`, `TestEventLog` and factory records directly, never through
  `Boot`; the `TODO(E1/E2)` swap in `tests/helpers/` is a type change, not a rename.
- Abstract bases **must** be declared `@abstract`; overrides of typed methods
  **must** end in an explicit `return` (4.7).
- Every rules file **must** pass `.claude/scripts/godot-parse-check.gd` on its own.

## Alternatives Considered

### Alternative 1: No autoload — `main.tscn` is the only composition root

- **Description**: `main.tscn._ready()` composes services and passes them to
  `RunShell`; no `[autoload]` entry at all.
- **Pros**: Zero global surface; the strictest reading of DD-T02 and TD-001.
- **Cons**: match-ui U11 and run-ui U10 launch `match_view.tscn` /
  `run_shell.tscn` directly for screenshot fixtures; without a tree-level root
  each debug loader re-implements composition and the evidence path diverges from
  the shipped boot path — the screenshot would no longer prove the real wiring.
- **Estimated Effort**: Same as chosen for the shipped path; one extra composition
  copy per debug loader.
- **Rejection Reason**: Two composition paths is exactly how the prototype's
  `card_ui.setup(card)` ended up without `player_id` (TD-006). A lazy root with a
  grep gate gives the same isolation without the duplication.

### Alternative 2: Service locator autoload reachable from anywhere

- **Description**: `Boot` (or `Game`) exposes `Boot.card_database`, `Boot.rng`,
  `Boot.log` as globals that rules code reads on demand — the prototype's shape.
- **Pros**: Least boilerplate; no constructor threading.
- **Cons**: Rules classes cannot be instantiated in a unit test without the
  autoload; hidden dependencies; parse check fails on files naming an autoload
  (`current-best-practices.md` §Command Line); it is TD-001 again.
- **Estimated Effort**: Lower up front, unbounded later.
- **Rejection Reason**: It is the root cause of TD-001/TD-009 and contradicts
  `gameplay-code.md` "no static singletons for game state".

### Alternative 3: Rules as `Node`s under a headless `SceneTree` (signals for everything)

- **Description**: `RulesEngine` extends `Node`, emits Godot signals per event,
  presenters connect; tests use gdUnit4's `scene_runner`.
- **Pros**: Idiomatic Godot; free signal wiring; `_process` available to rules.
- **Cons**: Needs a tree to exist at all; Boss AI's `clone()` for look-ahead would
  duplicate Nodes (expensive, and `duplicate_deep()` semantics for Resources are
  post-cutoff — `deprecated-apis.md`); signals cannot be replayed from a log;
  `queue_free` ordering is what made death resolve twice (TD-005).
- **Estimated Effort**: Comparable to chosen; higher test cost.
- **Rejection Reason**: Pillar 4 needs an append-only log as the single truth
  (DD-T04), and a node graph cannot be cloned cheaply thousands of times per boss
  turn (boss-ai F7).

## Consequences

### Positive

- Every rule is unit-testable headless; the boss-ai sim harness, match fixtures
  and replay are all plain function calls over data.
- `MatchState.clone()` is a data copy, so Boss AI look-ahead needs no engine support.
- One place to swap `MetaStub`, fixture data or a scripted driver for screenshots.
- TD-001, TD-003, TD-005, TD-006 and the enabling half of TD-010/TD-012 are ruled
  out structurally rather than by review.

### Negative

- Constructor threading: every rules class carries 3–6 constructor arguments and
  `MatchConfig` is wide; readers must follow `architecture.md` §API Boundaries.
- Rules code cannot use `await`, `Timer` or signals-with-tree for pacing; all
  timing lives in the UI (ADR-0009), which must pace a burst it already holds.
- A second autoload for a legitimate need (e.g. an audio bus) requires a new ADR.

### Neutral

- `src/core/boot.gd` is a `Node` and is the one file under `src/core/` exempt from
  gate G2; G3 also exempts the composition root's own types `services.gd` and
  `boot_result.gd` (erratum 2026-11-03, code review); the gate script names
  each exemption explicitly.
- Presenters and screens become thinner than idiomatic Godot UI; the projection
  (`MatchViewState`) carries the logic instead.

## Risks

- **Rules reach for the tree during a crunch** (a `Timer` for a delay, a `$` for a
  debug print). Mitigation: gates G1–G3 in CI; the control manifest; the per-file
  parse check fails a rules file that names an autoload.
- **`RefCounted` reference cycles leak** (`RulesEngine` ↔ `EffectResolver`,
  `MatchDriver` ↔ engine). Mitigation: ADR-0007/0008 name an explicit
  `unbind()`/drop order and a `weakref` test that asserts the graph is freed
  after `match_view_finished`.
- **QQ-04: autoloads under `godot -s`.** `NOT SOURCEABLE`. Mitigation: `Boot` is
  lazy either way; the first test suite asserts `Boot.booted == false`.
- **Gate drift** — a new directory outside the four globs. Mitigation: gates run
  over `src/**` minus an explicit allowlist (`src/ui/**`, `src/scenes/**`,
  `src/core/boot.gd`); an unlisted directory is a failure, not a pass
  (`skill-authoring.md` obligation 5).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| match-rules.md C1 (TR-match-rules-001) | `RulesEngine` owns one `MatchState`; plain data, no Node references | Rules tier is `RefCounted`; gate G1/G2 |
| match-rules.md C2 (TR-match-rules-002) | `submit(command) -> CommandResult`, `legal_commands()`; illegal moves are data | The single command channel for UI, AI and Run Structure |
| match-rules.md Interactions (TR-match-rules-005) | Primitive API is the only mutator; Boss AI and Match UI are command issuers | Three-channel rule; `submit` only via controllers |
| match-ui.md U1, U2 (TR-match-ui-001) | `MatchView` + injected `MatchController` + `MatchQuery`; commands in, events out, queries out, nothing else | Presentation tier definition; gate G5 |
| match-ui.md U11 (TR-match-ui-004) | Fixtures launch `match_view.tscn` directly and run the real engine | `Boot.boot(overrides)` reachable from a scene root; debug loaders are allowed callers |
| run-ui.md U1 (TR-run-ui-001) | `RunController` is the only object talking to Run Structure / Reward Draft / Meta; screens get read models and send intents | Presentation tier definition |
| run-ui.md U10 (TR-run-ui-004) | `--run-ui-fixture` loads into an in-memory Meta stub | `Boot.boot({meta: MetaStub.new(...)})` |
| boss-ai.md C1 (TR-boss-ai-001) | `BossAI` is `RefCounted`, pure, mutates only through `submit` | Rules tier rule applies to `src/ai/**` |
| systems-index.md Circular Dependencies (TR-systems-index-001, -002) | Run Structure ↔ Meta via `MetaApi` + stub; Match UI ↔ Run UI one-way scene hand-off | `@abstract MetaApi` seam; the reverse edge is a signal only (detailed in ADR-0008) |
| design-decisions.md DD-T02 (TR-design-decisions-001) | Rules are `RefCounted` GDScript with no Node references; UI subscribes and issues commands | Made binding and gated |
| tech-debt-register.md (TR-tech-debt-001) | The production tree rules out each prototype root cause | See "TD items retired" |

## TD Items Retired

| TD | Prototype root cause | Rule here that rules it out |
|---|---|---|
| TD-001 | `GameManager` autoload god object owning rules and run state | `Boot` owns no game state and is referenced only by scene roots; one autoload entry; gates G3/G4 |
| TD-003 | Board never registered; minions only as scene children | `MatchState.players[side].board` is the only board; presenters are projections (gate G5) |
| TD-005 | `Minion` is a `Control` owning stats and freeing itself; death resolves twice | Nothing under `src/gameplay/` extends `Node`; `queue_free` only in `src/ui/` (gates G1/G2) |
| TD-006 | UI mutates state; AI reparents nodes; cards owned by player 0 | All input through `submit()`; `MatchQuery` returns copies; `Command.issuer` carries ownership (gate G5; the AI half is completed by ADR-0008) |
| TD-010 (enabler) | Dead scenes, duplicate resolvers | Nothing is ported; the parse check and `/asset-audit` catch orphans |
| TD-012 (enabler) | No tests; nothing could run headless | Headless rules make gdUnit4 unit tests possible for every Logic story |

TD-002, TD-004, TD-007, TD-008, TD-009, TD-011 are retired by ADR-0002/0003/0005/0007/0008.

## Performance Implications

- **CPU**: Neutral. Method calls on `RefCounted` are cheaper than signal fan-out
  through a node graph; the `≤ 5 ms submit` / `≤ 2 ms legal_commands` budgets
  (match-rules Input Responsiveness) are unaffected by the split itself.
- **Memory**: Lower than the node alternative — `MatchState.clone()` copies
  Dictionaries/Arrays, not Nodes (boss-ai up to 4,000 lethal nodes per turn).
- **Load Time**: `Boot.boot()` is the synchronous data load; it must fit
  `data_load_budget_ms` 200 (card-database Formulas) and is measured by the
  performance test, not changed by this ADR.
- **Network**: N/A (single-player, anti-pillar).

## Migration Plan

Greenfield under `src/`; nothing from `prototypes/hearthstone-clone-2026-01/` is
ported (TD-010). Order: (1) `src/core/boot.gd` + `Services` + `main.tscn` calling
`boot()`; (2) gate script in CI, watched to fail on a planted `extends Node` under
`src/gameplay/`; (3) `tests/helpers` `TODO(E1/E2)` swap as the Foundation classes
land. `tests/helpers/` names are already the production names, so no rename pass.

**Rollback plan**: none needed structurally — if a second autoload or a Node-based
rule proves necessary, write a superseding ADR that narrows the gate; the gates
are a script, not code the game depends on.

## Validation Criteria

- Gates G1–G6 (incl. G2b) run in CI; each has been watched to fail on a planted violation
  (`skill-authoring.md`: a gate you have not watched fail is not a gate).
- A full match (`tests/integration/match_rules/`) and a full run
  (`tests/integration/run_structure/`) complete under `commands.test` with no
  scene beyond the gdUnit4 runner.
- `tests/unit/core/boot_lazy_test.gd`: `Boot.booted == false` at suite start;
  `boot()` twice returns the same `Services` (idempotent).
- `match_view.tscn` launched with `--fixture=<name>` under the ADR-0010 capture
  line produces a retained PNG whose state the fixture's command list reaches
  through the real engine (match-ui U11).
- `.claude/scripts/godot-parse-check.gd` passes on every `src/gameplay/**` and
  `src/ai/**` file individually.

## Verification / How We Know

| Claim | Source | Status |
|---|---|---|
| `@abstract` classes/methods exist and refuse instantiation | `current-best-practices.md` §GDScript 4.5+; `breaking-changes.md` 4.4→4.5 | sourced |
| Typed-method overrides need an explicit `return` | `breaking-changes.md` 4.6→4.7; `current-best-practices.md` §GDScript 4.7 | sourced |
| Lambdas capture locals by value; share state via a reference type | `current-best-practices.md` §GDScript 4.5+ | sourced |
| `--check-only` is not a parse check for scripts naming an autoload; per-file parse check exists | `current-best-practices.md` §Command Line; `.claude/scripts/godot-parse-check.gd` on disk | sourced |
| `rg --type gdscript` is an error; use `--glob "*.gd"` | `current-best-practices.md` §Tooling | sourced |
| gdUnit4 6.2.x runs on 4.7.2; exit codes 0/100/101/105 | `current-best-practices.md` §Command Line | sourced |
| Autoload instantiation under `godot -s GdUnitCmdTool.gd` | — | **NOT SOURCEABLE** — proven by `boot_lazy_test.gd` (above) |
| `RefCounted` cycle collection semantics | — | **NOT SOURCEABLE** from the reference (pre-cutoff behaviour, not covered); proven by the `weakref` teardown test named in ADR-0007/0008 |

## Related

- Enables: ADR-0002 (data + `config()`), ADR-0003 (RNG + event log), ADR-0004
  (save), ADR-0005 (hook registry), ADR-0006 (planner threading), ADR-0007
  (resolver boundary), ADR-0008 (match driver), ADR-0009 (Match UI), ADR-0010
  (capture), ADR-0011 (Run UI shell).
- `docs/architecture/architecture.md` §Architecture Principles 1, 4, 6; §Dependency
  injection and the composition root; §API Boundaries; §Tech-debt retirement mapping.
- `design/design-decisions.md` DD-T02, DD-T04, DD-X08.
- `docs/tech-debt-register.md` TD-001, TD-003, TD-005, TD-006, TD-010, TD-012.
- `.claude/rules/gameplay-code.md`, `ui-code.md`, `ai-code.md`, `engine-code.md`.
- Code (once implemented): `src/core/boot.gd`, `src/scenes/main.tscn`,
  `tools/ci/gates.sh` (the gate script).
