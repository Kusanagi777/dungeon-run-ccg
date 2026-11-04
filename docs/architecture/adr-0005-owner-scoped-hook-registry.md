# ADR-0005: Owner-scoped hook registry

## Status

Accepted

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner. `technical-director` is the role
> `coordination-rules.md` escalates technical conflicts to.

**Review record (this authoring run, 2026-11-03):**
- **Erratum 2026-11-03 (code review of match-rules 009)**: rule 4 exception — `on_draw`, `on_hero_damaged` and `on_minion_summoned` are reached inside a primitive; their entries run synchronously within the current step with no C10 loop between them, and a re-entry of the same hook point within one entry faults `resolution_overflow` (a self-feeding hook must end the match as a fault, never overflow the call stack).
- Engine validation (`godot-specialist`, Step 5.5): **NOT ASSESSED — not spawned.** The registry uses no engine API beyond `RefCounted`, `Dictionary`, `Array`, `StringName` and `Callable`; the two post-cutoff GDScript rules that touch it are sourced below.
- TD-ADR (`technical-director`, Step 5.6): **skipped — Lean mode** (`review_mode: lean`; not a PHASE-GATE).
- GDD sync (Step 5.7): checked 4 referenced GDDs (treasures, match-rules, card-effects, boss-ai). No renames. One arity difference carried from `architecture.md` §API Boundaries: treasures T3.1 writes `installers_for(treasure_ids)`; code is `installers_for(treasure_ids, treasure_state)` because T3.2 says each installer's `state` comes from `treasure_state.by_treasure[host_id]` and `Treasures` never reads `RunState` itself (T5.1).
- Numbering: fixed by `design/design-decisions.md` DD-X08 (the owner-scoped hook registry ADR supersedes `docs/architecture/modifier-hook-chain.md`, which stays unnumbered).
- **TD review 2026-11-03 (acceptance pass over ADR-0001..0011):** the diagram passed `resolver.fold_entry` / `resolver.run_entry`, method names that exist nowhere; now `resolver.apply_value_hook` / `resolver.run_hook_effect` (ADR-0007 Key Interfaces), and the `set_evaluators` comment states that `fold_entry` / `run_entry` are parameter names only. Call shapes `(entry, side, value, ctx) -> int` and `(entry, side, ctx)` agree with ADR-0007. TD: retires the modifier half of TD-009, consistent with ADR-0004/0008/0011 and `architecture.md` §Tech-debt retirement mapping. Dependencies ADR-0001 and ADR-0007 were Accepted first.
- **Accepted 2026-11-03 by technical-director** on the owner's standing approval of the project plan (plan approved 2026-11-03; "accept each" step). Owner may revert to Proposed.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2 (`docs/engine-reference/godot/VERSION.md`) and treasures.md / match-rules.md / card-effects.md / boss-ai.md as Approved on 2026-11-03.

## Decision Makers

Authored headlessly by `/architecture-decision` (guided automation, no `AskUserQuestion` answerer); recommended options taken and listed under *Decisions taken* in the run report. Acceptance authority: Jacob (owner) or `technical-director` on his confirmation.

## Summary

Treasures and boss passives alter match rules through a per-match `HookRegistry` that lives on `MatchState.hooks`, holds plain-data `HookEntry` rows per hook point in installation order (treasures in pick order, each `effects[]` in array order, boss passive last), and offers three hook kinds — synchronous trigger steps, value folds clamped once by the engine, and gates (defined, no v1 hook point). There is no singleton, no `priority`, no `Node` and no back-reference from an entry to its registry; this supersedes the prototype's `ModifierManager` (`modifier-hook-chain.md`) and retires the modifier half of TD-009.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7) |
| **Domain** | Core |
| **Layer** | Core |
| **Knowledge Risk** | LOW for the APIs used (`RefCounted`, `Dictionary`, `Array`, `StringName`, `Callable` — unchanged through 4.7); HIGH for GDScript generally (VERSION.md), of which two sourced rules apply |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `breaking-changes.md` (4.6→4.7 GDScript: typed-return overrides, packed-array setter; 4.4→4.5 `@abstract`); `current-best-practices.md` (lambdas capture by value, variadic args, `@abstract`); `deprecated-apis.md` (`duplicate()` for nested *resources*; untyped containers pattern; string `connect`) |
| **Post-Cutoff APIs Used** | None. Applicable post-cutoff *rules*: lambdas capture locals by value — the fold and trigger evaluators therefore receive the entry and context as arguments and never close over mutable locals (sourced, `current-best-practices.md`); an override of a typed method returns explicitly (4.7, sourced) — relevant to `MatchState.clone()` and any test double of `HookRegistry` |
| **Verification Required** | None engine-level: the prototype's `NOT SOURCEABLE — sort_custom stability` is removed by design (no sort; installation order is array order). Behavioural tests under *Validation Criteria* |

> If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated when the project upgrades engine versions.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (rules / presentation split: `src/gameplay/**` is `RefCounted`, no Node, constructor-injected — `adr-0001-rules-presentation-split.md`, **Accepted** 2026-11-03); ADR-0007 (effect resolver / validator boundary: hook effects are DSL effects and `EffectResolver.apply_value_hook` / `run_hook_effect` are the only evaluators — `adr-0007-effect-resolver-validator-boundary.md`, **Accepted** 2026-11-03). Acceptance is refused while either is `Proposed` |
| **Enables** | ADR-0006 (Boss AI planner relies on `clone()` carrying hooks by value — boss-ai A20); ADR-0008 (`MatchConfig.player/boss.hook_installers` built by the match driver); Treasures epic; boss passives in Content MVP-1 |
| **Blocks** | Treasures epic (installers, pool, `collect_state`), the Match Rules story that implements the hook table, boss-passive content stories |
| **Ordering Note** | `architecture.md` priority order places this after ADR-0007 (0001 → 0002 → 0003 → 0004 → 0010 → 0007 → 0005). It is written now in DD-X08 number order, in the same session as ADR-0007; the resolver-side binding it assumes (`EffectResolver.bind(engine, installers)` installing through `state.hooks.install(installer)` at C3 step 1; a clone binding a fresh resolver with no installers — ADR-0007 Decision 2–3) is fixed there and restated here only as a consumer. Checked against ADR-0007 on 2026-11-03: no contradiction. Supersedes `docs/architecture/modifier-hook-chain.md` (prior art; stays unnumbered per DD-X08) |

## Context

### Problem Statement

Treasures (3 held per run, 20 in the v1 pool) and boss passives must bend match rules — costs, damage, heals, starting hand, max attacks, and reactions at match start, turn boundaries, plays, summons, hero damage and draws — without the rules engine carrying per-treasure branches, with an order the player can see, scoped so the player's treasure never changes the boss's numbers, and copyable into Boss AI's look-ahead clones so the sandbox scores the real rules. The prototype's `ModifierManager` solved the first goal and failed the other three (`modifier-hook-chain.md` Known Issues): one global dictionary for both players, five hook families with no owner argument, `priority` ordering with undefined ties, `Node`-typed hook parameters, and `Modifier.on_turn_end` calling the singleton to remove itself (TD-009).

### Current State

No production code. `match-rules.md` Interactions fixes the twelve hook points, their signatures and the post-fold clamps; `treasures.md` T2–T5 fixes per-match owner-scoped registry semantics, installation order, the installer shape, duplicate handling and two state tiers; `card-effects.md` C2/C9 fixes that hook effects are ordinary DSL effects bound per trigger and that hook-less event triggers run as hero-slot observers; `boss-ai.md` A20 requires clones to carry hooks. `architecture.md` §API Boundaries already names `HookRegistry`, `HookEntry`, `HookInstaller` and their methods; `tests/helpers/match_factory.gd` carries `"hooks": []` with a `TODO(E1)` swap marker; `TestConstants.HAND_SIZE` (10) and `MAX_ATTACKS_CAP` (4) mirror the clamp bounds.

### Constraints

- DD-T02 / ADR-0001: everything under `src/gameplay/` is `RefCounted`, takes collaborators by constructor or `bind`, references no Node, autoload or scene, and runs headless under gdUnit4.
- Match-rules C1: `hooks` is a field of `MatchState`; C2: `clone()` is a deep copy with no shared references; C3 step 1 installs hooks before step 4 (`on_match_start`) so match-start hooks see the full chain.
- Match-rules Interactions: the hook table is owned by Match Rules — "a hook that needs a rule not in this table is a GDD change here, not a workaround in Treasures"; the engine clamps once after the fold (cost/damage/heal floor 0; starting hand `[0, HAND_SIZE]`; max attacks `[0, MAX_ATTACKS_CAP]`).
- Card-effects C2: value triggers may only contain `modify_value` ops and may not mutate state; C9: trigger hooks run synchronously as their own step at the hook point; the End step is the exception where card `turn_end` triggers precede `on_turn_end` hooks (C6.3).
- Treasures F5 / TR-treasures-004: ≤ 12 entries; 12-entry fold < 0.05 ms; three installed treasures add < 2 ms per match; **no allocation in the fold**.
- Treasures T4: `treasure_state` is JSON-only (rng-event-log rule 14), read at `installers_for`, written only by `collect_state` after `match_ended`.
- `modifier-hook-chain.md` Follow-Up Work (constraints, not open questions): owner-scoped, no back-reference, plain data, documented ordering, hook catalogue derived from the treasures GDD not copied from `modifier.gd`.

### Requirements

- Implement the twelve hook points with the signatures in match-rules Interactions (TR-match-rules-006) as one `HookRegistry` per match on `MatchState.hooks` (TR-treasures-001).
- `installers_for(treasure_ids, treasure_state) → HookInstaller[]` pure and idempotent; duplicate host skipped with `hook_install_skipped` (TR-treasures-002).
- `collect_state(hooks, match_result) → Dictionary` and `pool(unlocked_keys, exclude_ids)` id-ascending (TR-treasures-003).
- Value hooks fold in installation order and are clamped once by the engine (treasures F2); stacking across different treasures is additive unless an op uses `mul` (F3).
- `MatchState.clone()` copies entries by value so a clone's hooks fire identically and emit nothing to the live log (match-rules C2; boss-ai A20).
- Boss passives use the same installer shape and registry, installed last (treasures T2.3, Edge Cases "passive wins on `set`").

## Decision

**`HookRegistry` is a plain `RefCounted` owned by `MatchState` (`src/gameplay/match/hook_registry.gd`), created by `RulesEngine.start` and discarded with the match. It stores, per hook point, an `Array` of `HookEntry` dictionaries in installation order, and nothing else that could reach outward: no log, no engine, no `Node`, no autoload.** Entries are installed by `EffectResolver.bind(engine, installers)` during match-rules C3 step 1, from `MatchConfig.player.hook_installers` (treasures, pick order) followed by `MatchConfig.boss.hook_installers` (the passive), one entry per effect in each installer's `effects[]` array order. The registry evaluates nothing itself: at `bind` the resolver hands it two evaluator `Callable`s — its bound methods `apply_value_hook` and `run_hook_effect` (ADR-0007 Decision 1 table) — which the registry calls per entry; `copy()` copies entries only, and the clone's fresh resolver, bound with no installers (ADR-0007 Decision 3), sets its own evaluators. `unbind()` on `match_ended` (ADR-0007) also clears the evaluators, so no `RefCounted` cycle survives the match. That keeps the DSL out of Match Rules (ADR-0007 boundary) while the engine keeps the single call sites `architecture.md` names.

Rules the decision fixes:

1. **Hook catalogue = match-rules' table, no more.** Trigger points: `on_match_start`, `on_turn_start`, `on_turn_end`, `on_card_played`, `on_minion_summoned`, `on_hero_damaged`, `on_draw`. Value points: `modify_cost`, `modify_damage`, `modify_heal`, `modify_starting_hand_size`, `modify_max_attacks`. Gate points: **none in v1** — the kind is reserved in the API (`gate(point, side, ctx) → bool`, AND with short-circuit) so adding one is a match-rules hook-table change plus one line here, never a new mechanism. The prototype's 36-hook catalogue is not carried.
2. **Ordering is installation order and nothing else.** No `priority`, no sort, no stability dependency. Treasures in `RunState.treasures[]` order (pick order), each treasure's `effects[]` in array order, then the boss passive's effects. The tray shows the same order (Pillar 4). A `set` by the passive therefore wins over a treasure's `set` by construction (treasures Edge Cases).
3. **Owner scope is a field, not an argument convention.** `HookEntry.side` is the installer's side (`"player"` for treasures, `"boss"` for the passive — the `MatchFactory.SIDE_*` strings). Every invocation carries the side it concerns; the resolver evaluates the entry's `scope` relative to `entry.side` (card-effects C2 scope keys: `side: owner|opponent|any`, default `owner`; `source`/`target`/`card` filters), and an entry whose scope does not match is skipped before anything runs. So "the player's heals restore 3 less" is a boss-side entry whose scope names the enemy's heals, and a plain cost discount with the default scope touches only its owner's cards. The prototype's unscoped families cannot be expressed.
4. **Three hook kinds, two live.** *Trigger* entries run synchronously as their own step at the hook point and may call primitives (through the resolver), each followed by the full C10 loop. *Value* entries fold: entry *n*'s output is entry *n+1*'s input (`delta` adds, `set` replaces, `mul` multiplies — treasures F2); the fold mutates nothing and allocates nothing; **the engine clamps once after the whole fold** with the bounds from `config("match_rules")` (`HAND_SIZE`, `MAX_ATTACKS_CAP`) and the floor-0 rules of F1/F2. A clamp between entries is a defect (`1 − 1 − 1 → 0`, not `0 → 0`).
5. **Installation is idempotent and duplicate-safe.** `install(installer)` returns `false` and installs nothing when `installer.host_id` is already present; the **engine** (which owns the log) appends `hook_install_skipped{host_id, reason: duplicate}` — the registry never touches the log. Installing the same list onto a fresh match yields an equal registry.
6. **No back-reference, no lifecycle.** An entry holds `{host_kind, host_id, side, effect_id, effect, state}` and nothing else. No `is_enabled`, `duration_turns`, `stacks` or removal in v1 (treasures T3.5); if a future treasure needs removal it is `HookRegistry.remove_host(host_id)` called by the engine, never by an effect. Entries live until `Ended` and die with `MatchState`.
7. **Copy by value.** `copy()` returns a new registry whose entry dictionaries are `duplicate(true)` copies (plain containers — the `duplicate_deep()` row in `deprecated-apis.md` concerns nested Resources and does not apply) and whose evaluators are unset. `MatchState.clone()` calls it; the clone's resolver binds evaluators again; nothing a clone's hook does reaches the live log or stream (match-rules C2).
8. **Two state tiers, one of them here.** Match-tier state (`once_per_turn` marks, counters) lives in `EffectRuntime` keyed by the treasure id (card-effects C6.7–8, ADR-0007), not in the registry. Run-tier state is the installer's `state` blob (`treasure_state.by_treasure[host_id]`, `{}` in v1), carried on the entry read-only and returned by `hosts()` so `Treasures.collect_state(hooks, result)` has its input; v1 returns `{schema_version: 1, by_treasure: {}}` unchanged.
9. **Hook-less event triggers are not hooks.** Treasure effects on `on_play`, `after_cast`, `on_attack`, `on_damage_dealt`, `on_heal`, `on_minion_died`, `on_hero_power`, `on_weapon_equipped` and non-hero `on_damage_taken` are hero-slot observers queued by the resolver in candidate order (card-effects C9, treasures T2.5); they never enter the registry. Only Grave Tithe uses one in v1.
10. **Pool predicate lives once.** `Treasures.pool(unlocked_keys, exclude_ids)` implements membership (`unlock == null` or `unlock.key ∈ unlocked_keys`, not held, not offered) over `CardDatabase.treasure_pool()` and returns id-ascending; **`RewardDraft.init_run` calls it** (`architecture.md` QQ-08, decided there and recorded here) rather than re-deriving the predicate inline.
11. **Binding time.** `RulesEngine.start(config)` constructs `state.hooks = HookRegistry.new()`, then calls `resolver.bind(self, config.player.hook_installers + config.boss.hook_installers)` as C3 step 1, before heroes, decks and `on_match_start` (step 4).

### Architecture Diagram

```
RunMachine.begin_match                          (Feature, ADR-0008)
  treasures[] (pick order) ──► Treasures.installers_for(ids, treasure_state) ──► HookInstaller[]
  BossDef.passive ──────────► [HookInstaller{host_kind: passive, host_id: boss_id, side: "boss"}]
          │                                   │
          └──── MatchConfig.player.hook_installers / .boss.hook_installers ──────┐
                                                                                  ▼
RulesEngine.start(config)   (Core, match-rules C3 step 1)
  state.hooks = HookRegistry.new()
  resolver.bind(engine, player_installers + boss_installers)
        │  for each installer, for each effect in effects[] (array order):
        │     hooks.install(...) → HookEntry appended to entries[point]        ← duplicate host → false,
        │  hooks.set_evaluators(resolver.apply_value_hook, resolver.run_hook_effect)   engine logs hook_install_skipped
        ▼
HookRegistry (plain data)                                      MatchState.clone()  →  hooks.copy()
  entries: { on_match_start: [e, e, …], modify_cost: [e, e], … }   (entries duplicate(true); evaluators unset;
  hosts:   { treasure_x: {state}, boss_y: {state} }                  clone's resolver rebinds)
        ▲                              ▲
        │ run_triggers(point, side, ctx)│ fold(point, side, v, ctx) → v'
        │ (each entry = one step +      │ (resolver evaluates scope, applies
        │  C10 loop)                    │  delta/set/mul; no allocation)
RulesEngine hook sites (12):                                      engine clamps ONCE after fold:
  C3.4 on_match_start · C4 start.4 on_turn_start · C4 end.3 on_turn_end   cost/damage/heal ≥ 0
  C6 on_card_played · summon → on_minion_summoned · F2 → on_hero_damaged   hand ∈ [0, HAND_SIZE]
  draw → on_draw · F1 modify_cost · F2 modify_damage · heal modify_heal    attacks ∈ [0, MAX_ATTACKS_CAP]
  C3.5 modify_starting_hand_size · max_attacks modify_max_attacks
```

### Key Interfaces

Signatures match `architecture.md` §API Boundaries (Core — Match Rules, Feature — Treasures); additions are marked.

```gdscript
# src/gameplay/match/hook_registry.gd — match-rules Interactions hook table; treasures T2–T3
class_name HookRegistry extends RefCounted
const TRIGGER_POINTS: Array[StringName] = [&"on_match_start", &"on_turn_start", &"on_turn_end", &"on_card_played",
                                           &"on_minion_summoned", &"on_hero_damaged", &"on_draw"]
const VALUE_POINTS: Array[StringName]   = [&"modify_cost", &"modify_damage", &"modify_heal",
                                           &"modify_starting_hand_size", &"modify_max_attacks"]
const GATE_POINTS: Array[StringName]    = []                       # reserved kind; none in v1
func install(installer: HookInstaller) -> bool                     # false on duplicate host_id; installs nothing then
func set_evaluators(fold_entry: Callable, run_entry: Callable) -> void   # (addition) parameter names only; EffectResolver.bind passes its methods apply_value_hook / run_hook_effect (ADR-0007); unset after copy() and on unbind()
func entries(point: StringName) -> Array                           # (addition, read-only view) installation order
func fold(point: StringName, side: StringName, value: int, ctx: Dictionary) -> int
#   for e in entries[point]: value = fold_entry.call(e, side, value, ctx)   — scope mismatch returns value unchanged; no allocation
func run_triggers(point: StringName, side: StringName, ctx: Dictionary) -> void
#   for e in entries[point]: run_entry.call(e, side, ctx)                  — each call is one step; engine runs C10 after it
func gate(point: StringName, side: StringName, ctx: Dictionary) -> bool   # reserved: AND, short-circuit; true when no entries
func hosts() -> Array[Dictionary]                                  # (addition) [{host_kind, host_id, side, state}] for collect_state
func copy() -> HookRegistry                                        # entries duplicate(true); evaluators NOT copied
func entry_count() -> int                                          # (addition) ≤ 12 by F5; asserted in debug

class_name HookEntry     # Dictionary shape, never a class with behaviour:
                         # {host_kind: &"treasure"|&"passive", host_id: String, side: StringName, effect_id: String,
                         #  effect: Dictionary (frozen DSL object), state: Dictionary (run-tier blob, read-only)}
class_name HookInstaller extends RefCounted                        # treasures T3.2
var host_kind: StringName; var host_id: String; var side: StringName
var effects: Array            # copy of TreasureDef.effects / BossDef.passive
var state: Dictionary         # treasure_state.by_treasure[host_id] or {}
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> HookInstaller

# src/gameplay/treasures/treasures.gd — treasures T3–T7
class_name Treasures extends RefCounted
func _init(db: CardDatabase, balance_config: Dictionary) -> void
func installers_for(treasure_ids: Array, treasure_state: Dictionary) -> Array[HookInstaller]
#   pure, idempotent, pick order; repeated id → first kept, caller logs run_warning{duplicate_treasure}
#   unknown treasure_state.schema_version → ignored, caller logs run_warning{treasure_state_reset}
func collect_state(hooks: HookRegistry, result: MatchResult) -> Dictionary     # {schema_version: 1, by_treasure: {}} in v1
func pool(unlocked_keys: Dictionary, exclude_ids: Array) -> Array               # id-ascending TreasureDef[]
static func validate_treasure_defs(defs: Array, db: CardDatabase) -> Array      # E_TR_RARITY, E_TR_TAGS, E_TR_EFFECT_COUNT, E_TR_TOKEN_REF, W_TR_POWER, W_TR_TEXT
static func passive_installer(boss_def: Dictionary) -> Array[HookInstaller]    # (addition) [] when passive == null; else one installer, side "boss"

# Engine call sites (RulesEngine, match-rules Interactions) — the only callers of fold / run_triggers
#   cost  = clampi(hooks.fold(&"modify_cost", side, base_cost, {card: ci}), 0, 1 << 30)
#   dmg   = maxi(0, hooks.fold(&"modify_damage", source_side, requested, {source: s, target: t}))
#   heal  = maxi(0, hooks.fold(&"modify_heal", source_side, amount, {source: s, target: t}))
#   hand  = clampi(hooks.fold(&"modify_starting_hand_size", side, n, {}), 0, cfg.HAND_SIZE)
#   atks  = clampi(hooks.fold(&"modify_max_attacks", character.controller, 2 if windfury else 1, {who: character}), 0, cfg.MAX_ATTACKS_CAP)
#   hooks.run_triggers(&"on_turn_start", side, {})   # C4 Start step 4, each entry then C10
```

Events this decision touches (match-rules C15 spelling is authoritative, DD-X04): `hook_install_skipped{host_id, reason}` appended by the engine; `effect_resolved` with `source_id` = treasure or passive id, `hook_delta` where a fold changed a value (treasures Edge Cases); `run_warning{code: duplicate_treasure | treasure_state_reset, treasure_id}` appended by Run Structure.

### Implementation Guidelines

- **Must** keep `HookRegistry`, `HookEntry` and `HookInstaller` free of any reference to `RulesEngine`, `EventLog`, `MatchState`, a Node, an autoload or the registry itself; **must never** give an entry a method that calls back into its registry (the TD-009 defect).
- **Must** install in `MatchConfig.player.hook_installers` order, then `boss.hook_installers`, each `effects[]` in array order; **must never** sort entries or add a `priority`, `weight` or `order` field.
- **Must** keep the catalogue equal to match-rules' hook table; **must never** add a hook point here without a match-rules GDD change and a card-effects C2 row.
- **Must** clamp exactly once in the engine after `fold()` returns, with bounds from `config("match_rules")`; **must never** clamp inside the fold or inside a `modify_value` op.
- **Must** keep the fold allocation-free (iterate the existing `Array`, pass the existing `ctx` Dictionary, return an `int`); **must never** `duplicate()` entries or build arrays per invocation. `entry_count() ≤ 12` is asserted in debug builds.
- **Must** pass `side` on every invocation and let the resolver evaluate `scope` relative to `entry.side`; **must never** special-case "player only" in engine code — scope is data.
- **Must** return `false` from `install()` on a duplicate `host_id` and let the engine log `hook_install_skipped`; **must never** append to a log from the registry.
- **Must** route hook-less treasure event triggers through the resolver's hero-slot observers; **must never** add them to the registry "because they are treasure effects".
- **Must** make `copy()` a by-value copy with evaluators unset; `MatchState.clone()` **must** call it and the clone's resolver **must** rebind. Overrides of typed methods on test doubles **must** `return` explicitly (4.7).
- **Must** read `treasure_state` only in `installers_for` and write it only in `collect_state`; **must never** mutate `RunState` from `src/gameplay/treasures/`.
- **Must** call `Treasures.pool()` from `RewardDraft.init_run`; **must never** re-implement the membership predicate elsewhere.
- Evaluator Callables **must** take everything they need as arguments (lambdas capture locals by value — sourced); the resolver binds bound methods, not closures over mutable state.

## Alternatives Considered

### Alternative 1: Global priority-ordered modifier manager (the prototype, `modifier-hook-chain.md`)
- **Description**: An autoload owning one dictionary of `Modifier` resources for the whole game, iterated in descending `priority`, ~36 virtual hooks, stacking/duration/enable flags, save/load.
- **Pros**: One integration surface; stacking and duration solved once; content as `Resource`.
- **Cons**: Not owner-scoped (a player discount lowers boss costs; five hook families carry no owner); `Modifier.on_turn_end` back-references the singleton; `Node`-typed parameters prevent headless tests; `priority` ties are undefined (`sort_custom` stability NOT SOURCEABLE); `clear_all_modifiers()` at match start killed run persistence; duck-typed `has_method` dispatch hides typos; 14 duplicated fold loops.
- **Estimated Effort**: Already written; porting is forbidden (`prototype-code.md`) and would import every defect.
- **Rejection Reason**: Every Known Issue in the prior-art document is a treasures T2 requirement in the negative; DD-T02 and ADR-0001 forbid the singleton and the Node coupling outright.

### Alternative 2: Signals / event bus with subscribing treasure objects
- **Description**: Engine emits signals at hook points; treasure objects connect and mutate state or return values.
- **Pros**: Idiomatic Godot; decoupled.
- **Cons**: Value hooks need a return value and a defined order; signals give neither (connection order is an implementation detail, and a signal cannot fold). Subscribers would be objects with behaviour, not data, so `clone()` could not copy them by value and A20 would fail. Mutation outside primitives violates "one mutation, one event" (DD-T04).
- **Estimated Effort**: Comparable to write, higher to make deterministic.
- **Rejection Reason**: Folds and copyable clones are hard requirements (treasures F2, match-rules C2).

### Alternative 3: Treasure effects compiled into card instances (no registry)
- **Description**: At `begin_match`, rewrite each affected card/hero definition in the player's deck copy (e.g. cost − 1) and skip hooks.
- **Pros**: Zero runtime cost; no new concept.
- **Cons**: Cannot express reactive treasures (`on_hero_damaged`, `on_turn_start`, Grave Tithe) or conditional discounts ("first card each turn"); treasures that affect cards added mid-match (Discover, summon tokens) would miss them; the passive-last ordering and visible fold order are lost; Match UI could not attribute a change to a treasure (`source_id`).
- **Estimated Effort**: Low for the three cost treasures, impossible for the rest of the v1 pool.
- **Rejection Reason**: Covers a minority of the T8 pool; the GDD's Pillar 4 attribution requires hooks as events.

### Alternative 4: Registry evaluates the DSL itself (no evaluator Callables)
- **Description**: `HookRegistry.fold` parses the entry's `modify_value` op and applies it; `run_triggers` calls primitives directly.
- **Pros**: Fewer indirections; `copy()` has nothing to rebind.
- **Cons**: Puts DSL knowledge (ops, scope grammar, context refs) into Match Rules, duplicating the resolver and breaking the ADR-0007 boundary (the resolver decides *who responds*); every DSL change would touch two systems.
- **Estimated Effort**: Lower now, higher for every card-effects change.
- **Rejection Reason**: Ownership — card-effects C9 says Card Effects owns binding and resolution order; Match Rules owns only *when* a point fires. The two-Callable seam keeps that line and costs one `Callable.call` per entry.

## Consequences

### Positive
- The player's treasures cannot touch the boss's numbers by accident, and the boss passive cannot be reordered under a treasure; order is on screen in the tray.
- The registry is a Dictionary of Arrays: unit-testable with `MatchFactory` fixtures, copyable in one call, serialisable if a future design wants mid-match restore (QQ-07).
- Boss AI's clone scores the real rules (A20) because entries are data; `EffectRuntime` carries the only mutable hook-related state.
- No sort, no priority, no stability question: the prototype's `NOT SOURCEABLE — sort_custom` disappears.
- Adding a hook point is a three-line change across three documents, not a new mechanism; adding a *gate* is pre-shaped.

### Negative
- `set_evaluators` is match-local wiring that every constructor of a `RulesEngine` or clone must perform; a missed rebind makes hooks silently inert in a clone — mitigated by a debug assertion in `fold`/`run_triggers` when evaluators are unset and by the A20 test.
- Two indirections per entry (`Callable.call` → resolver → op) on the hottest point (`modify_cost` per F1 evaluation); bounded by ≤ 12 entries and asserted by the F5 performance test.
- Removal, duration, stacking and enable flags are deliberately absent; a v2 treasure needing them is a GDD change first.

### Neutral
- `HookEntry` is a Dictionary shape, not a class — consistent with the engine's other records being plain data with normative field names.
- Gate hooks exist in the API with no callers; `/code-review` should not flag the empty `GATE_POINTS` as dead code.

## Risks
- **Scope evaluation cost or ambiguity for `modify_damage` / `modify_heal` (which side is "the invocation's side")** → fixed here as the *source's* controller, with `source`/`target` filters in the entry's scope doing the rest; the unit test covers a boss-side "player heals restore 3 less" entry and a player-side Focusing Prism entry on the same `modify_damage` point.
- **Clamp applied twice (engine and op)** → the control manifest forbids clamping in ops; the `1 − 1 − 1 → 0` test (treasures Edge Cases) fails if a clamp sneaks between entries.
- **Clone rebind forgotten** → debug assertion when evaluators are null; A20 integration test.
- **Installer order diverging from tray order** → both read `RunState.treasures[]`; the Match UI fixture `treasure_tray` asserts the order against `hooks.hosts()`.
- **Future removal need introduces a back-reference by habit** → the only sanctioned path is `HookRegistry.remove_host(host_id)` called by the engine; recorded here so `/dev-story` has the rule before the need arises.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| treasures.md | T2 one registry per match on `MatchState.hooks`; `HookEntry {host_kind, host_id, side, effect_id, effect}`; installation order; owner scope (TR-treasures-001) | `HookRegistry` shape, no sort, `side` field, scope evaluated relative to the entry |
| treasures.md | T3 `installers_for` pure/idempotent, duplicate host → `hook_install_skipped`, bound at `RulesEngine.start` before `on_match_start` (TR-treasures-002) | `install()` returns `false`; engine logs; binding in C3 step 1 |
| treasures.md | T4 two state tiers, `treasure_state` schema; T6 `pool()` id-ascending (TR-treasures-003) | `state` on entries + `hosts()` for `collect_state`; `pool()` called from `RewardDraft.init_run` |
| treasures.md | T5 holding rules; F2 fold-then-clamp; F3 additive stacking; F5 cost bound, no allocation (TR-treasures-004) | Fold semantics, engine clamps once, `entry_count() ≤ 12`, allocation-free loop with a perf test |
| match-rules.md | Interactions hook table (12 points, signatures, clamps); C1 `hooks` field; C2 `clone()` deep copy carrying entries; C3 step 1/4 ordering (TR-match-rules-003, -006) | Catalogue constants, engine call sites, `copy()` by value, binding before `on_match_start` |
| card-effects.md | C9 hook-hosted triggers as synchronous steps, value triggers as folds, hooks before card triggers (End-step exception); C2 hook column and scope keys (TR-card-effects-004) | `run_triggers` per entry = one step; `fold`; hook-less triggers routed to hero-slot observers |
| boss-ai.md | A20 clone carries hooks so sandbox scoring is correct; provisional note confirmed 2026-11-03 | `copy()` + rebind; A20 kept as the integration test |
| tech-debt-register.md | TD-009 modifier half: back-reference to a singleton, unscoped modifiers (TR-tech-debt-001) | No singleton, no back-reference, `side` on every entry |
| architecture.md | QQ-08 pool predicate location | Decided: `RewardDraft.init_run` calls `Treasures.pool(unlocked_keys, [])` |
| reward-draft.md | TR-reward-draft-001 — D1: `init_run(run_state) → draft_state`; `offer(kind, run_state, stream)` pure, mutates nothing | Decision 10 / QQ-08: the unlock-filtered treasure pool is read **once** at `init_run` (`Treasures.pool(unlocked_keys, [])`, id-ascending, T6) and kept in `draft_state`; `offer` reads that snapshot and the stream only — it never calls `pool()` again, so no hook, unlock or treasure state changes under a live offer; stream side in ADR-0003 |
| reward-draft.md | TR-reward-draft-002 — D3, D7: exclusion and pity derived from `run_state.drafts[]`; pool snapshotted at `init_run` | Pool half here (Decision 10); exclusion and pity are recomputed at every call from the `DraftRecord{floor, kind, offered_ids[], picked_id, card_ids_added[]}` entries in `run_state.drafts[]` against the `init_run` pool snapshot — a pure function of the record, no separate pity state, so the `RunRecord` is the only persisted input; persistence half in ADR-0003 |
| systems-index.md | TR-systems-index-003 — Circular Dependencies, Treasures ↔ Reward Draft: Treasures owns definitions and the chain; Reward Draft reads the pool; the run writes `treasure_granted` | Pool edge decided (QQ-08); the `treasure_granted{floor, treasure_id}` emitter is `RunMachine` (run-structure R5.4, transition T11 on `draft_pick(treasure, id)`; none on T19 empty offer) appending to the run-scope `EventLog` — neither Treasures nor Reward Draft emits it; Treasures only turns the granted ids into installers at the next `begin_match` (`installers_for`, T3); ADR-0011 routes the event to the UI |

## Performance Implications
- **CPU**: ≤ 12 entries per match; `modify_cost` is the hot point (≤ 10 hand cards + hero power per F1 evaluation per step); each entry is one `Callable.call`, one scope check and one integer op. Budget: 12-entry fold < 0.05 ms; three treasures add < 2 ms per match (treasures F5). `copy()` runs once per Boss AI clone — ≤ 12 small `duplicate(true)` calls, inside the planner's per-turn budget (boss-ai F7).
- **Memory**: a few KB per match; cloned registries die with their clones.
- **Load Time**: none (installers are built at `begin_match` from frozen records).
- **Network**: none.

## Migration Plan
Greenfield. Stories, in order: (1) `HookRegistry` + `HookInstaller` with unit tests over `MatchFactory` states (swap `"hooks": []` for a `HookRegistry` per the helper's `TODO(E1)` marker); (2) the twelve engine call sites in `RulesEngine` with the clamps from `config("match_rules")`; (3) `EffectResolver.bind` installing entries and binding evaluators (ADR-0007 story); (4) `Treasures.installers_for` / `pool` / `collect_state` / `validate_treasure_defs` + `passive_installer`; (5) `RunFactory.make_match_config_for` passes `Treasures.installers_for(...)` instead of raw ids (`TODO(E2)`); (6) A20 and the Match UI `treasure_tray` fixture.

**Rollback plan**: the registry is referenced only through `MatchState.hooks`, `install`, `fold`, `run_triggers`, `copy`, `hosts`; replacing its internals (e.g. a typed `HookEntry` class) changes no caller. Reverting to a priority field or a global manager is not a rollback — it reopens TD-009 and needs a treasures GDD change first.

## Validation Criteria
Tests under `tests/unit/match/` and `tests/unit/treasures/` (gdUnit4; names per `test-standards.md`):
- `hook_registry_install_order_test.gd`: three treasures in pick order plus a passive produce entries in that exact order per point; a repeated `host_id` returns `false` and adds nothing; installing the same list onto a fresh registry yields equal `entries()`.
- `hook_registry_fold_test.gd`: `delta −1, delta −1` on cost 1 folds to −1 and the engine's clamp yields 0 (not `0 → 0`); `set 1` then passive `delta +1` yields 2; `set 2` on Windfury base 2 yields 2; starting hand `+2` then `+6` clamps to `HAND_SIZE`; a boss-side `modify_heal` entry scoped to enemy heals reduces the player's heal and leaves the boss's untouched (owner scope).
- `hook_registry_triggers_test.gd`: `on_hero_damaged` with a treasure and a passive runs treasure first, passive second, each as its own step with a C10 pass between (event `seq` order asserted via `TestEventLog`).
- `hook_registry_copy_test.gd`: `copy()` is deep (mutating a copied entry's `effect` leaves the original unchanged), carries no evaluators, and after rebind produces identical fold results; `MatchState.clone()` + a boss heal scored in the clone reflects the passive (boss-ai A20, integration under `tests/integration/boss_ai/`).
- `hook_registry_perf_test.gd` (performance): 12-entry `modify_cost` fold < 0.05 ms on the reference machine; a scripted 30-turn match with three treasures adds < 2 ms over an empty registry; `Performance.get_monitor(OBJECT_COUNT)` / allocation counter unchanged across 10,000 folds.
- `treasures_installers_test.gd`: `installers_for` is pure (no RNG draws, no log appends, no `RunState` writes), idempotent, keeps the first of a repeated id; unknown `treasure_state.schema_version` yields stateless installers; `passive_installer` returns `[]` for `passive: null`.
- `treasures_pool_test.gd`: membership predicate over `unlock` / `unlocked_keys` / `exclude_ids`; id-ascending regardless of file order; `RewardDraft.init_run` calls it exactly once (stub assertion).
- Control-manifest grep gate: no `priority` field, no `sort` call, no `EventLog`/`RulesEngine` reference and no `Node` in `src/gameplay/match/hook_registry.gd` or `src/gameplay/treasures/`.
- Evidence: Match UI fixture `treasure_tray` screenshot shows tray order == `hooks.hosts()` order (UI story, retained under `production/qa/evidence/`).

## Related
- **Supersedes** `docs/architecture/modifier-hook-chain.md` (reverse-documented prior art; stays unnumbered per DD-X08). Every item in its *Follow-Up Work* checklist is addressed above: owner-scoped, no back-reference, plain data, documented ordering, no duration/stacking in v1 (GDD decision), run state survives via `treasure_state`, clamps stated per hook, catalogue from the treasures GDD.
- Depends on ADR-0001, ADR-0007; enables ADR-0006, ADR-0008.
- `design/gdd/treasures.md` (T1–T7, F2, F3, F5, Edge Cases), `design/gdd/match-rules.md` (C1–C3, Interactions hook table), `design/gdd/card-effects.md` (C2, C6.1, C9), `design/gdd/boss-ai.md` (A20), `design/gdd/run-structure.md` (R1 `treasure_state`, R3, R4), `design/gdd/reward-draft.md` (D3, D7).
- `docs/architecture/architecture.md` §API Boundaries (Core — Match Rules; Feature — Treasures), §Module Ownership (`HookRegistry / HookEntry`), §Open Questions QQ-08, §Technical Requirements Baseline (TR-treasures-001..004, TR-match-rules-003/-006, TR-card-effects-004).
- `docs/tech-debt-register.md` TD-009.
- Code once implemented: `src/gameplay/match/hook_registry.gd`, `src/gameplay/match/hook_installer.gd`, `src/gameplay/treasures/treasures.gd`, `src/gameplay/treasures/treasure_validator.gd`, `src/gameplay/effects/effect_resolver.gd` (bind), `tests/helpers/match_factory.gd` (`TODO(E1)` swap).
