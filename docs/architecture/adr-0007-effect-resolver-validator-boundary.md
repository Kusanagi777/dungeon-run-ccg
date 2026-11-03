# ADR-0007: Effect Resolver / Validator Boundary

## Status

Accepted

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner.

Review record for this authoring run (2026-11-03, `/architecture-decision`,
headless, `automation: guided`, `review_mode: lean`, `workflow: standard`):

- **TD-ADR skipped — Lean mode.**
- **Engine specialist validation: NOT ASSESSED** — not spawned in this headless
  run (see ADR-0001 Status). This ADR uses no engine API beyond `RefCounted`,
  `Dictionary`, `Array`, `StringName`, `Callable` and `static func`; nothing
  post-cutoff is relied on.
- **GDD sync: checked 6 referenced GDDs** (`card-effects`, `match-rules`,
  `card-database`, `heroes`, `treasures`, `boss-ai`) — no rename. **Additions**
  to `architecture.md` §API Boundaries are introduced here and reported, not
  silently assumed: `RulesEngine.state()` / `emit()` / `rng_match()`
  (resolver-only surface), `EffectResolver.unbind()`, and
  `EffectResolver.apply_value_hook` / `run_hook_effect` — the evaluator
  Callables ADR-0005's `HookRegistry.set_evaluators` receives (shape aligned
  with ADR-0005, and the stage-7b call shape with ADR-0002, on 2026-11-03).
- Numbering fixed by DD-X08.
- **TD review 2026-11-03 (acceptance pass over ADR-0001..0011):** the
  Decision 8 test stub had four parameters while ADR-0002's stage 7b calls every
  record validator with five; a four-parameter lambda would fail at call time.
  Stub now takes five. Stage 7a/7b contract otherwise agrees with ADR-0002
  (ADR-0002 now names `derive_targeting_spec`, this ADR's spelling). Dependencies
  ADR-0001 and ADR-0002 were Accepted first.
- **Accepted 2026-11-03 by technical-director** on the owner's standing approval of the project plan (plan approved 2026-11-03; "accept each" step). Owner may revert to Proposed.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2 and `architecture.md` v1; card-effects.md
C1–C10, F6 as revised 2026-11-03.

## Decision Makers

Jacob (owner; standing approval) · `/architecture-decision` (author) ·
`technical-director` (acceptance, pending).

## Summary

Card Effects and Match Rules both touch every mutation of a match, so the line
between them decides whether TD-002 (calls into an API that does not exist) and
TD-004 (no effect ever implemented) recur. This ADR fixes it: `RulesEngine` owns
`MatchState`, the primitive API, the trigger points, candidate order and the C10
loop; `EffectResolver` is bound at `RulesEngine.start`, reads the live state,
writes **only** through primitives, decides who responds and in what order among
responders, and keeps its only state (`EffectRuntime`) as plain data inside
`MatchState`; `EffectValidator.validate_effects` is a `static`, side-effect-free
function injected into Card Database load stage 7 with the closed `E_FX_*` /
`W_FX_*` code set and the F6 static step bound, and tests inject a stub that
accepts everything.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7) |
| **Domain** | Core (GDScript rules code; no engine subsystem) |
| **Layer** | Core |
| **Knowledge Risk** | HIGH by version (4.7 post-cutoff, `VERSION.md`) — but the APIs used (`RefCounted`, `Dictionary`, `Array`, `StringName`, `Callable`, `static func`) predate 4.3 and have no post-cutoff change listed in `breaking-changes.md` |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (all post-cutoff Core/GDScript rows), `current-best-practices.md` §GDScript 4.5+/4.7, `deprecated-apis.md` (Patterns: typed `Array[Type]` / `Dictionary` preferred over untyped) |
| **Post-Cutoff APIs Used** | None. Typed-return overrides (4.7) apply only if a subclass of `EffectResolver` is written (none planned) |
| **Verification Required** | `NOT SOURCEABLE — RefCounted cycle collection`: `RulesEngine` holds `resolver`, `bind()` gives the resolver the engine. Test `tests/unit/effects/effect_resolver_teardown_test.gd`: build engine+resolver, hold `weakref(engine)`, call `RulesEngine.end_match()` (which calls `resolver.unbind()`), drop strong refs, assert `weakref.get_ref() == null` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (rules tier, `_init` injection), ADR-0002 (effect JSON schema, `config("card_effects")`, Card Database stage-7 injection map) |
| **Enables** | ADR-0005 (hook effects are DSL effects evaluated by this resolver), ADR-0006 (a `clone()` that carries `EffectRuntime` is what makes off-thread look-ahead safe), ADR-0009 (`effect_resolved` is the UI's playback unit) |
| **Blocks** | Card Effects epic; Match Rules stories that fire trigger points (C6, C10); Content's first validated batch (content CN-6) |
| **Ordering Note** | Write after ADR-0002 (owns the effect object shape) and before ADR-0005 (owns the registry this resolver's hook entry points serve) |

## Context

### Problem Statement

Match Rules (C6, C10, Interactions) owns *when* a trigger point fires, *what
order* candidates are considered (board order, player side first), the primitive
API and the resolution loop. Card Effects (C1–C10) owns the DSL, *who responds*
among candidates, the order among responders, the Discover continuation, auras,
counters and `once_per_turn` marks, and the static validator. Both GDDs describe
the hand-off in prose from their own side; without one decision, programmers
would pick the seam per story and the two halves would drift — which is how the
prototype ended with `CardEffectBase` never invoked (TD-004) and calls to rules
functions that did not exist (TD-002).

### Current State

No code. `architecture.md` §API Boundaries lists `EffectResolver._init(db,
effects_config)`, `bind(engine, installers)`, `resolve(trigger_point, ctx)`,
`legal_targets`, `targeting_spec`, `recompute_auras`, `resume(choice,
option_index)`, `ChoiceRequest`, and `static EffectValidator.validate_effects(host_kind,
host_id, effects, db, caps) -> Array`. `tests/helpers/match_factory.gd` fixes
record field names and the closed rejection-code list.

### Constraints

- card-effects C6.0: one effect pass = one C10 step; the engine's loop runs after
  the pass, never between ops. C6.8: `EffectRuntime` is plain data inside
  `MatchState`, holds no Node or Callable. C6.9: random draws go to `rng_match`
  directly through the engine, no per-effect fork. C6.10: no runtime cap in the
  resolver; `RESOLUTION_STEP_CAP` (match-rules) and `max_match_events`
  (rng-event-log) are the authorities; the validator's F6 bound is static.
- card-effects C1 rule 1: targeting is derived from the one `chosen` selector,
  never stored (match-rules Dependencies, cross-review C-04).
- card-effects C8: exactly one `ChoiceRequest` outstanding; continuation stored
  in `EffectRuntime.pending_choice`; `concede` abandons it.
- card-effects C10 / card-database CR-5 stage 7: delegated validators injected at
  composition; a `Failed` load has no main menu; unit tests inject stubs.
- match-rules C2: `MatchState.clone()` is a deep copy carrying hooks,
  continuation, a detached scratch log and a copied `rng_match` state; Boss AI
  look-ahead runs `resolve` on the clone deterministically (boss-ai Interactions).
- boss-ai F7: up to 4,000 lethal-search nodes per turn → `clone()` + resolve must
  be cheap; nothing per-clone may rebuild heavy indices.
- ADR-0001: rules tier is `RefCounted`, `_init`-injected, no Node.

### Requirements

- TR-card-effects-001..006, TR-match-rules-005/006, TR-card-database-002 (stage
  7 injection), heroes H-3 (hero powers are `hero_power`-trigger effects),
  treasures T7 (its validator runs after `validate_effects("treasure", …)`).
- `validate_effects` must be callable with no engine, no match and no RNG
  (static, pure) so `tools/content/validate.gd` and CI run it headless.

## Decision

**The engine owns time and order; the resolver owns meaning; the validator owns
nothing at runtime.**

1. **Ownership table.**

   | Concern | Owner | Interface |
   |---|---|---|
   | `MatchState`, `next_entity_id`, phase machine, `win_loss_check`, the C10 loop (death check → `recompute_auras()` → queue pop), `RESOLUTION_STEP_CAP` | `RulesEngine` | internal |
   | The primitive API (`draw` … `discard`, 24 calls — match-rules Interactions) and the one event each emits | `RulesEngine` | called only by `EffectResolver` (and by the engine's own command handlers) |
   | *When* a trigger point fires, *which* entities are candidates and in *what order* (board order, player first; C6.3 table) | `RulesEngine` | `resolver.resolve(point, ctx)` with `ctx.candidates: Array[int]` already in engine order |
   | *Who responds* (trigger bound, scope matches, source live, not silenced, `once_per_turn` clear), order among one entity's effects (array order, definition before enchantment-granted), queueing vs run-now | `EffectResolver` | inside `resolve` |
   | Running one effect pass: condition → ops → selectors → primitives → `effect_resolved` | `EffectResolver` | primitives only; never a field write |
   | `EffectRuntime {once_marks, counters, per_turn_tallies, pending_choice}` | **data lives in `MatchState.effects`**; **code lives in `EffectResolver`** | `engine.state().effects` |
   | Value hooks (`modify_*` folds) and trigger hooks on `HookEntry`s | `EffectResolver.apply_value_hook` / `run_hook_effect`; the registry (ADR-0005) stores entries, the engine chooses the moment | see Key Interfaces |
   | `targeting_spec(def_id)`, `legal_targets(def_id, source)` | `EffectResolver` (derived from the `chosen` selector; memoised per `def_id`) | called by the engine during C6 validation |
   | Discover / Choose One continuation | resolver stores it in `EffectRuntime.pending_choice`; engine owns the `Choice` phase and `pending_choice.side` | `discover(side, options) -> ChoiceRequest` (primitive); `resume(choice, option_index)` on `choose` |
   | Static validation, `E_FX_*` / `W_FX_*`, F6 bound | `EffectValidator` (`static`, pure) | injected into `CardDatabase.load({effects: …})` |

2. **Binding and lifetime.** `RulesEngine._init(db, rules_config, resolver)` stores
   the resolver; `RulesEngine.start(config)` calls `resolver.bind(self,
   config.player.hook_installers + config.boss.hook_installers)` (C3 step 1, before
   `on_match_start`). `bind` stores the engine reference, installs hook entries
   through `state.hooks.install(installer)` in installation order (treasures in
   pick order, then the boss passive), and registers itself as the registry's
   evaluator: `state.hooks.set_evaluators(apply_value_hook, run_hook_effect)`
   (ADR-0005's addition — the registry stores plain data and calls back through
   these two Callables). On `match_ended` the engine calls
   `resolver.unbind()`, which clears the engine reference and the registry's
   evaluators — this breaks the
   `RefCounted` cycle. The resolver keeps **no per-instance index**: effects are
   looked up by `def_id` through `CardDatabase.card(id).effects` and memoised per
   `def_id` in a resolver-local Dictionary that is derived data, rebuildable from
   the database at any time.
3. **Clone.** `RulesEngine.clone()` deep-copies `MatchState` (including
   `state.effects` and `state.hooks.copy()`), constructs a fresh
   `EffectResolver.new(db, effects_config)` and binds it to the clone with no
   installers (entries are already in the copied registry; `HookRegistry.copy()`
   leaves evaluators unset, so the clone's `bind` re-registers them — ADR-0005).
   The clone's scratch log is what ADR-0006's planner reads. Nothing in the
   resolver is shared between live and clone except the immutable `CardDatabase`
   and the frozen config body. The per-`def_id` memo starts empty in the clone;
   its cost is bounded by the number of distinct defs touched in one look-ahead
   and is measured by the boss-ai sim harness (A22).
4. **Read access.** The resolver reads the live `MatchState` via
   `RulesEngine.state() -> MatchState` (**addition to §API Boundaries**). This is a
   live reference by necessity (selectors evaluate against the board mid-pass).
   Control-manifest rule: `state()` may be called only from `src/gameplay/effects/**`;
   `MatchQuery` and Boss AI keep using `snapshot_entity` / `clone()`.
5. **Writes.** The resolver mutates match state **only** by calling engine
   primitives. Writing a `MatchState` field, a `PlayerState` list, an
   `enchantments[]` array or `next_entity_id` from `src/gameplay/effects/**` is a
   defect (grep gate G7 below). `EffectRuntime` fields are the one exception: they
   are the resolver's own data, and each change that the log must explain emits
   its own event (`counter_changed`; `once_per_turn` marks and tallies are
   derivable from the log and emit nothing).
6. **Events and `cause_seq`.** Primitives emit their events with the `cause_seq`
   the engine holds for the current step; the resolver emits exactly one
   `effect_resolved` per pass (payload per card-effects Interactions),
   `discover_offered` / `discover_picked` and `counter_changed` through
   `engine.emit(type, payload)` — a thin engine method that appends with the
   current `cause_seq` so the resolver never touches the `EventLog` directly
   (keeps `log.append` call sites inside the engine; rng-event-log rule 12 "one
   event per mutation" is then auditable in one file).
7. **Randomness.** The resolver asks the engine for draws: `engine.rng_match()`
   returns the injected `RngStream`; the resolver calls `randi_range` / `shuffle`
   on it directly, in resolution order, with the counts F4/F5 define (C6.9: no
   per-effect fork). Nothing in `src/gameplay/effects/**` names `RandomNumberGenerator`
   or a global RNG function (ADR-0001 gate G6 covers the directory).
8. **Validator.** `EffectValidator.validate_effects(host_kind, host_id, effects, db,
   caps) -> Array` is `static`, allocates its own report, touches no engine, no RNG,
   no file. `caps` is the `card_effects` config body (`MAX_OPS_PER_EFFECT`,
   `MAX_REPEAT`, `MAX_SUMMON_COUNT`, `EFFECT_STATIC_STEP_LIMIT`, `DISCOVER_COUNT`).
   `Boot` registers it under `"effects"`; Card Database stage 7b invokes the
   registered Callable as `callable.call(host_kind, host_id, effects, db,
   configs_bodies)` (ADR-0002 — `db` in `Loading` answers lookups only during
   stage 7, and the parsed config bodies travel as the fifth argument), so `Boot`
   registers `func(k, id, fx, db, bodies): return
   EffectValidator.validate_effects(k, id, fx, db, bodies["card_effects"])`.
   This ADR fixes only that the validator is static and pure and that `caps` is
   a parameter, never a lookup through a global. It returns `[{code, host_id, effect_id, path, message}]`
   with the closed set `E_FX_SCHEMA, E_FX_TRIGGER, E_FX_SELECTOR, E_FX_FILTER,
   E_FX_OP, E_FX_OP_TARGET, E_FX_OP_UNAVAILABLE, E_FX_REF, E_FX_REF_PATH,
   E_FX_CHOSEN, E_FX_BUDGET, W_FX_KEYWORD_MISMATCH, W_FX_UNREACHABLE` (card-effects
   C10) and computes `effect_step_bound` per F6. The same function also yields
   `targeting_spec` for the host (one derivation, two callers: the validator checks
   it, the resolver memoises it). The test stub is `func(_k, _id, _fx, _db, _configs): return []` (five parameters — stage 7b always passes five arguments, ADR-0002).
9. **Grep gate G7** (CI): under `src/gameplay/effects/**`, zero hits for direct
   state writes — `\.(board|hand|deck|graveyard|enchantments|keywords)\s*\.(append|erase|insert|remove_at|clear)\(|\.(damage_taken|base_attack|base_health|armor|mana_current|mana_max|frozen|silenced|attacks_used|durability|next_entity_id)\s*[+\-]?=` — and zero hits for `log\.append\(` and `RandomNumberGenerator`.

### Architecture Diagram

```
 RulesEngine (src/gameplay/match/)                 EffectResolver (src/gameplay/effects/)
 ┌─────────────────────────────────────┐          ┌──────────────────────────────────────┐
 │ MatchState                          │  state() │ bind(engine, installers) / unbind()  │
 │   players, hooks: HookRegistry,     │◄─────────┤ resolve(point, ctx{candidates…})     │
 │   effects: EffectRuntime  ◄─ owned data, resolver code ─┤   who responds · order among them  │
 │ command handlers → trigger points ──┼─────────►│   queue (event triggers) / run (play) │
 │ C10 loop: death_check · auras · pop │ resolve  │ one pass: condition → ops → selectors│
 │ primitives: draw … discard ◄────────┼──────────┤   → primitives (only writes)         │
 │ emit(type, payload) (cause_seq) ◄───┼──────────┤   → effect_resolved                   │
 │ rng_match() ────────────────────────┼─────────►│ F4/F5 draws, resolution order         │
 │ discover(side, options) ─► Choice ──┼─────────►│ continuation in state.effects         │
 │ submit(choose) ─────────────────────┼─────────►│ resume(choice, option_index)          │
 │ clone() → new engine + new resolver │          │ apply_value_hook / run_hook_effect    │
 └─────────────────────────────────────┘          └──────────────────────────────────────┘
                 ▲ validators injected at composition (Boot → CardDatabase.load)
 EffectValidator.validate_effects(host_kind, host_id, effects, db, caps)  — static, pure
```

### Key Interfaces

```gdscript
# src/gameplay/effects/effect_resolver.gd — card-effects C1, C5–C10 (architecture.md §Core — Card Effects)
class_name EffectResolver extends RefCounted
func _init(db: CardDatabase, effects_config: Dictionary) -> void
func bind(engine: RulesEngine, installers: Array[HookInstaller]) -> void   # at RulesEngine.start, before on_match_start
func unbind() -> void                                                      # at match_ended; breaks the engine↔resolver cycle
func resolve(trigger_point: StringName, ctx: Dictionary) -> void           # ctx: {candidates: Array[int], subject, source, amount, side, ...}
func legal_targets(def_id: String, source: Dictionary) -> Array[int]
func targeting_spec(def_id: String) -> Dictionary                          # {mode: none|optional|required, filter}; memoised per def_id
func recompute_auras() -> void                                             # called by the engine's C10 loop
func resume(choice: ChoiceRequest, option_index: int) -> void              # `choose` continuation
func apply_value_hook(entry: HookEntry, side: StringName, value: int, ctx: Dictionary) -> int  # one fold step; condition re-evaluated per call (C1); shape fixed by ADR-0005 set_evaluators
func run_hook_effect(entry: HookEntry, side: StringName, ctx: Dictionary) -> void            # one synchronous step at a hook point (C9)
class_name ChoiceRequest   # {side, kind: discover|choose_one, options: Array, source_id, effect_id}
class_name EffectRuntime   # plain data in MatchState.effects: {once_marks: Dictionary, counters: Dictionary, per_turn: Dictionary, pending_choice: Variant}

# Engine surface the resolver may use (src/gameplay/match/rules_engine.gd) — additions marked
func state() -> MatchState                          # ADDITION: live read, resolver-only (control manifest)
func emit(type: StringName, payload: Dictionary) -> int   # ADDITION: log.append with the current cause_seq
func rng_match() -> RngStream                       # the injected match_<floor> stream (match-rules C3 step 1)
# + the 24 primitives listed in architecture.md §Core — Match Rules (draw … discard)

# src/gameplay/effects/effect_validator.gd — card-effects C10, F6
class_name EffectValidator extends RefCounted
static func validate_effects(host_kind: StringName, host_id: String, effects: Array, db: CardDatabase, caps: Dictionary) -> Array
    # -> [{code: StringName, host_id, effect_id, path, message}]; codes from the closed E_FX_* / W_FX_* set
static func step_bound(effect: Dictionary, caps: Dictionary) -> int        # F6 effect_step_bound; exposed for tests and /balance-check
static func derive_targeting_spec(effects: Array) -> Dictionary            # the one derivation (C1 rule 1); resolver memoises it
```

### Implementation Guidelines

- `EffectResolver` **must** mutate match state only through `RulesEngine`
  primitives and **must never** assign a `MatchState`/`PlayerState`/`Character`
  field or mutate one of their arrays (gate G7).
- `EffectResolver` **must never** call `EventLog.append`, hold an `EventLog`, or
  touch a `RandomNumberGenerator`; it **must** use `engine.emit` and
  `engine.rng_match()`.
- `RulesEngine` **must** call `resolver.bind` in `start()` before `on_match_start`
  and `resolver.unbind()` when `phase` becomes `Ended`; `clone()` **must** bind a
  new resolver instance to the clone and **must never** share the live resolver.
- `EffectRuntime` **must** be a plain-data member of `MatchState` (Dictionaries,
  Arrays, ints, Strings) and **must never** hold a Callable, a Node or an object
  reference; `clone()` copies it by value.
- The engine **must** fire trigger points with `ctx.candidates` already in engine
  order; the resolver **must never** re-sort candidates across entities, only
  order effects *within* one entity (array order, definition before granted).
- One effect pass **must** be one C10 step: the resolver **must never** call the
  death check or `recompute_auras()` between ops.
- `validate_effects` **must** be `static`, allocate its own report, and read
  nothing but its arguments; a code outside the closed set **must not** be added
  without a card-effects GDD change.
- `targeting_spec` **must** be derived (`derive_targeting_spec`), never read from
  a stored field; Card Database rejects a `targeting` field (CR-3).
- Tests **must** inject the accept-all stub into `CardDatabase.load`; the real
  validator is tested on its own with fixture effect objects.

## Alternatives Considered

### Alternative 1: Resolver owns the C10 loop and the trigger queue

- **Description**: The engine only exposes primitives and state; `EffectResolver`
  runs the death check, aura recompute and queue pop itself after each pass.
- **Pros**: All trigger logic in one module; fewer engine→resolver callbacks.
- **Cons**: The C10 loop is match-rules' rule (it defines when a hero dies,
  DD-M11 ordering, `RESOLUTION_STEP_CAP`, `win_loss_check`); moving it makes
  Match Rules untestable without Card Effects and splits one GDD's acceptance
  criteria across two modules.
- **Estimated Effort**: Equal.
- **Rejection Reason**: match-rules C10 and card-effects C6.0 both place the loop
  in the engine ("the engine's loop runs after the pass").

### Alternative 2: Effects compiled to GDScript callables at load

- **Description**: The validator compiles each effect object into a `Callable`
  chain stored on the card record; the resolver just invokes it.
- **Pros**: Faster per-pass dispatch; validation and execution share one pass.
- **Cons**: Callables cannot live in `MatchState` (C6.8, DD-T02 "no callbacks"),
  so `clone()` and any future `restore(log)` break; a frozen Card Database record
  would carry code; harder to log `effect_resolved.ops[]` outcomes.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Contradicts card-effects C1 rule 4 ("everything is plain
  JSON data, no callbacks") and the clone contract.

### Alternative 3: Validator as a `RefCounted` instance with cached database access

- **Description**: `EffectValidator.new(db, caps)` registered as a bound method.
- **Pros**: Fewer parameters per call.
- **Cons**: Instance state invites caching across loads (`reload()` in debug) and
  makes `tools/content/validate.gd` construct a validator before a database
  exists; harder to prove purity.
- **Estimated Effort**: Equal.
- **Rejection Reason**: card-effects C10 / card-database CR-5 describe a stateless
  function injected at composition; `static` makes the stub trivially
  substitutable.

## Consequences

### Positive

- Match Rules is testable with a null resolver (every hook identity, no effects);
  Card Effects is testable against a scripted engine double that records
  primitive calls — TD-002's "API defined first" and TD-004's "effects as data"
  both hold.
- `clone()` stays a data copy; Boss AI look-ahead resolves effects exactly as the
  live match (boss-ai A20) without the resolver knowing about threads.
- `effect_resolved` with per-op outcomes gives the UI and `/balance-check` one
  playback unit.

### Negative

- Two engine additions (`state()`, `emit()`) widen `RulesEngine`'s surface; the
  control manifest must restrict their callers by directory.
- Per-`def_id` memo rebuilt per clone — a small, repeated cost inside the
  planner's budget (measured, not assumed).
- The explicit `unbind()` is a lifecycle step a programmer can forget; the
  `weakref` teardown test exists for that.

### Neutral

- The resolver's hook entry points (`apply_value_hook`, `run_hook_effect`) exist
  before ADR-0005 defines who calls them; ADR-0005 wires the registry to them.
- `targeting_spec` lives in the validator file as a static and is memoised by the
  resolver — one derivation, two callers.

## Risks

- **A primitive missing for a content need** → `E_FX_OP_UNAVAILABLE` at load, not
  a runtime special case; the fix is a match-rules GDD change (its Interactions
  row says so).
- **Resolver writes a field "just this once"** → gate G7; `effect_resolved` and
  the primitive events would no longer explain the state (Pillar 4). Mitigation:
  the integration test replays a match log into a fresh `MatchViewState` and
  asserts it equals `snapshot_entity` for every entity (match-ui U4.6).
- **`RefCounted` cycle leak** (`NOT SOURCEABLE` from the reference): teardown test
  above; `unbind()` mandated.
- **Stage-7 `caps` availability**: resolved by ADR-0002's stage-7b call shape
  (config bodies arrive as the fifth argument); if that shape changes, `Boot`'s
  registering lambda is the one place to adapt.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| card-effects.md C1 (TR-card-effects-001) | Effects are plain JSON; `targeting_spec` derived from the one `chosen`, never stored | `derive_targeting_spec` static; no `targeting` field anywhere |
| card-effects.md C5, C6 (TR-card-effects-002) | Resolver composes card text from primitives only; one pass = one C10 step; binding at `RulesEngine.start` | Decision 1, 2, 5; gate G7 |
| card-effects.md C8 (TR-card-effects-003) | One `ChoiceRequest`, continuation resumed by `choose` | `discover` primitive + `EffectRuntime.pending_choice` + `resume` |
| card-effects.md C9 (TR-card-effects-004) | Treasure/passive effects bind to hook points (trigger hooks as synchronous steps, value hooks as folds) or run as hero-slot observers | `apply_value_hook` / `run_hook_effect`; observers via `resolve` candidates |
| card-effects.md C10 (TR-card-effects-005) | `validate_effects(host_kind, host_id, effects[]) -> report[]`, closed `E_FX_*` set, injected at stage 7, stub in tests | Decision 8 |
| card-effects.md F6 (TR-card-effects-006) | Static step bound ≤ `EFFECT_STATIC_STEP_LIMIT` (250); `MAX_OPS_PER_EFFECT` 8 | `step_bound` static; `E_FX_BUDGET` |
| match-rules.md Interactions (TR-match-rules-005) | Primitive API is the only mutator; each call emits one event | Decision 5, 6 |
| match-rules.md C6, C10 (TR-match-rules-006) | 15 trigger points fired by the engine; candidate order board-first; C10 loop with `RESOLUTION_STEP_CAP` | Ownership table: engine owns time and order |
| match-rules.md Dependencies | Card Effects calls only the primitive API and never touches `MatchState` fields; `targeting_spec` derived | Decisions 4, 5 |
| card-database.md CR-5 stage 7 (TR-card-database-002) | Delegated validators injected at composition; tests inject stubs | Decision 8 |
| heroes.md H-3 | Hero powers are `hero_power`-trigger effects in the DSL | Same resolver path; no hero-specific code |
| treasures.md T7 | `validate_effects("treasure", …)` runs first, then the `E_TR_*` validator | Validator order fixed by the injection map (ADR-0002); this ADR guarantees the first is pure |
| boss-ai.md Interactions | `resolve` deterministic on a `clone()`; `legal_targets` for play enumeration | Decision 3 |

## TD Items Retired

| TD | Prototype root cause | Rule here that rules it out |
|---|---|---|
| TD-002 | Calls to rules functions that did not exist (half-finished rename) | The engine surface the resolver may call is enumerated (24 primitives + `state`, `emit`, `rng_match`) and typed; the per-file parse check and the scripted-engine double catch a missing call before a match runs |
| TD-004 (resolution half; schema half is ADR-0002) | `CardEffectBase` never subclassed or invoked; synergies as stubs | Effects are data resolved by one `EffectResolver` through primitives; the validator rejects anything unexpressible at load; there is no code-per-card path to leave unimplemented |

## Performance Implications

- **CPU**: `submit()` ≤ 5 ms worst case (50-step Deathrattle chain) is the
  engine's budget and includes resolver passes; `targeting_spec` memoised per
  `def_id` keeps C6 validation inside `legal_commands()` ≤ 2 ms. `clone()` +
  empty memo per look-ahead node: measured by the sim harness (A22) against
  `planner_target_ms` 50 p95.
- **Memory**: `EffectRuntime` is a few Dictionaries per `MatchState`; the per-def
  memo is bounded by the card pool (~120 + tokens).
- **Load Time**: `validate_effects` over ~900 O(1) checks fits
  `data_load_budget_ms` 200 (card-database Formulas); F6 is linear in ops.
- **Network**: N/A.

## Migration Plan

Greenfield. Order: (1) `RulesEngine` with primitives and a **null resolver**
(every trigger point a no-op) passes match-rules C3–C14 unit tests; (2)
`EffectValidator` + fixtures for every `E_FX_*` code and the F6 examples
("deal 1 to all minions, 10 times" = 161 legal; `times: 20` = 321 rejected); (3)
`EffectResolver` against a scripted engine double, then against the real engine
through card-effects C11 coverage rows; (4) `clone()` equivalence test.

**Rollback plan**: the seam is the `resolver` constructor argument; a different
resolver design plugs into the same `bind`/`resolve` surface without touching the
engine. If the two engine additions prove wrong, `state()` can be replaced by
passing `MatchState` in `ctx` (one signature change in `resolve`).

## Validation Criteria

- `tests/unit/match_rules/*` pass with the null resolver; `tests/unit/effects/*`
  pass with a scripted engine double that asserts only primitives were called.
- Every C11 coverage row (rows 1–25 for the three heroes, all 20 treasures) resolves
  through the real engine and produces the `effect_resolved` payload the GDD
  states (card-effects AC).
- Clone equivalence: for 100 seeded states, `clone().submit(cmd)` and
  `live.submit(cmd)` produce identical event sequences (modulo `seq` offsets) and
  the live log is untouched by the clone.
- `effect_resolver_teardown_test.gd`: engine graph freed after `unbind()`
  (`weakref.get_ref() == null`).
- `tools/content/validate.gd` exits non-zero on a planted `E_FX_BUDGET` card and
  zero on the MVP batch (content CN-6).
- Gate G7 watched to fail on a planted `state.players["player"].board.append(...)`
  under `src/gameplay/effects/`.

## Verification / How We Know

| Claim | Source | Status |
|---|---|---|
| `static func`, `Callable`, typed `Array[...]`/`Dictionary` behave as pre-4.3 | `breaking-changes.md` lists no change to them 4.4→4.7; `deprecated-apis.md` Patterns prefers typed containers | sourced (by absence of a breaking row — the reference is the pin) |
| No post-cutoff API is needed | `breaking-changes.md` 4.6→4.7 Core/GDScript rows (typed-return override, packed-array setter, `is_class` `StringName`) — none used here | sourced |
| `RefCounted` cycle is not auto-collected; `unbind()` needed | — | **NOT SOURCEABLE** from the reference; proven by `effect_resolver_teardown_test.gd` |
| `clone()` + fresh resolver fits the planner budget | boss-ai F7 (≈60 ms band-3 worst case), A22 | to be measured by the sim harness; no claim made here |
| Stage-7 Callable contract and `caps` availability | card-database CR-5 stage 7; ADR-0002 Key Interfaces (stage 7b: `call(host_kind, host_id, value, db, configs_bodies)`) | design-sourced; aligned with ADR-0002 on 2026-11-03 |

## Related

- Depends on ADR-0001 (tier rules), ADR-0002 (effect schema, stage-7 map).
- Enables ADR-0005 (hook registry calls `apply_value_hook` / `run_hook_effect`),
  ADR-0006 (clone safety), ADR-0009 (`effect_resolved` playback).
- `design/gdd/card-effects.md` C1, C5–C10, F6, Interactions, Dependencies;
  `design/gdd/match-rules.md` C6, C10, Interactions, Dependencies;
  `design/gdd/card-database.md` CR-5; `design/gdd/heroes.md` H-3;
  `design/gdd/treasures.md` T7; `design/gdd/boss-ai.md` Interactions.
- `docs/architecture/architecture.md` §API Boundaries (Core — Match Rules, Core
  — Card Effects), §Data Flow 1, §Tech-debt retirement mapping.
- `docs/tech-debt-register.md` TD-002, TD-004.
- Code (once implemented): `src/gameplay/effects/effect_resolver.gd`,
  `effect_validator.gd`, `effect_runtime.gd`, `src/gameplay/match/rules_engine.gd`.
