## The Card Effects resolver (design/gdd/card-effects.md C6.1, C6.8, C9,
## Tuning Knobs; ADR-0007 Decisions 2–4, Key Interfaces; ADR-0005
## `set_evaluators`).
##
## A `RefCounted` built once per match by the composition code
## (`MatchDriver`: `EffectResolver.new(db, db.config("card_effects"),
## hero_set)` — the hero set is F4's collectible pool, story 010), handed
## to `RulesEngine._init`, and bound by `RulesEngine.start` at C3 step 1 —
## before `on_match_start`:
## - [method bind] keeps the engine, installs each `HookInstaller` through
##   `engine.state().hooks.install` in the order given (treasures in pick
##   order, then the boss passive; a refused duplicate is the **engine's**
##   `hook_install_skipped`), keeps each installed host's `aura` effects and
##   hero-slot observers in `EffectRuntime.aura_hosts` (they are not hook entries;
##   stories 013, 015), then registers the bound methods
##   [method apply_value_hook] / [method run_hook_effect] as the registry's
##   evaluators.
## - [method unbind] (the engine calls it once, at `Ended` or from
##   `RulesEngine.end_match()`) clears the evaluators and the engine reference,
##   breaking the engine↔resolver `RefCounted` cycle.
##
## It reads the live match through `engine.state()` and will write only
## through engine primitives, emit only through `engine.emit` and draw only
## through `engine.rng_match()` (stories 006 onwards). It holds no `EventLog`
## and no random generator of its own (ADR-0007 gate G7). Its only runtime state is
## `MatchState.effects` (an [EffectRuntime]); what it keeps itself is the
## frozen `card_effects` config body and a per-`def_id` memo of definition
## effects — derived data, rebuildable from the database, empty in a fresh
## resolver (a clone's resolver starts empty — ADR-0007 Decision 3).
##
## **Choices** (story 010; card-effects C8, F4): a `discover` / `choose_one`
## op raises the engine's `ChoiceRequest` and suspends its pass, keeping the
## rest as plain data in `EffectRuntime.pending_choice`; the engine calls
## [method resume] on `choose` (ADR-0007 Decision 1).
##
## **Treasures and passives** (story 015; card-effects C2 hook column, C9): an
## event trigger with a hook column is a registry entry, run as one pass at the
## hook point by [method run_hook_effect]. One without is a **hero-slot observer**:
## [method _collect] reads the owner's hosts where the engine's candidates name
## that side's hero, so the slot needs no id of its own (the story's "resolver
## appends at that position"; `ctx.candidates` stays entity ids). Either way the
## source is the host's String id, always live, and the pass's events name it.
##
## Every Tuning Knob is read from the injected config body (the `config` of
## `assets/data/card_effects.json`), never from a literal: [method knob],
## [method knob_int]; keys are [constant EffectValidator.CONFIG_KEYS].
## [codeblock]
## var resolver := EffectResolver.new(db, db.config("card_effects"), "war")
## var engine := RulesEngine.new(db, db.config("match_rules"), resolver)
## engine.start(config)       # binds the resolver
## engine.end_match()         # unbinds it
## [/codeblock]
class_name EffectResolver
extends RefCounted

## The `card_effects` knob the resolver asserts (card-effects Tuning Knobs:
## `true` only — match-rules C4 hard-orders hooks before triggers).
const KNOB_HOOKS_BEFORE_TRIGGERS: String = "hooks_before_triggers"
## Memo field: the definition's `effects[]`.
const MEMO_EFFECTS: String = "effects"
## Memo field: the definition record itself (`{}` when the database has none).
const MEMO_RECORD: String = "record"
## Memo field: the derived C1 rule 1 targeting spec (`EffectValidator.derive_targeting_spec`).
const MEMO_TARGETING: String = "targeting_spec"
## The record type whose CR-2 id prefix (`RecordSchemas.SCHEMAS`, `power_`)
## sends the memo to `hero_power(id)` instead of `card(id)` — a lookup of the
## wrong type logs an error and asserts in a debug build.
const HERO_POWER_RECORD: String = "HeroPowerDef"
## Engine play point → the DSL play trigger bound to it (card-effects C2).
const PLAY_TRIGGERS: Dictionary[StringName, String] = {
	&"battlecry": "battlecry",
	&"on_cast": "cast",
	&"hero_power": "hero_power",
}
## Engine event point → the DSL event triggers bound to it (card-effects C2;
## `on_damage` splits into `on_damage_taken` / `on_damage_dealt`, both bound
## to the one engine point). A candidate's effects are walked in `effects[]`
## order, so two triggers on one point keep their authored order.
const EVENT_TRIGGERS: Dictionary[StringName, Array] = {
	&"deathrattle": ["deathrattle"],
	&"turn_start": ["turn_start"],
	&"turn_end": ["turn_end"],
	&"on_play": ["on_play"],
	&"on_summon": ["on_summon"],
	&"on_card_played": ["on_card_played"],
	&"after_cast": ["after_cast"],
	&"on_attack": ["on_attack"],
	&"on_damage": ["on_damage_taken", "on_damage_dealt"],
	&"on_heal": ["on_heal"],
	&"on_minion_died": ["on_minion_died"],
	&"on_draw": ["on_draw"],
	&"on_hero_power": ["on_hero_power"],
	&"on_weapon_equipped": ["on_weapon_equipped"],
}
## Event points whose `subject` entered play with the raising event: that
## entity does not observe its own entry (Edge Cases "a summoned minion's
## `on_summon` observer is the minion itself" — a source must have been in
## play *before* the raising event).
const ENTRY_POINTS: Array[StringName] = [&"on_play", &"on_summon", &"on_card_played", &"on_weapon_equipped"]
## Queue-entry fields (ADR-0007 erratum 2026-11-03: `{source_id, effect_id,
## point?, snapshot?}` — this resolver supplies the C6.5 `snapshot`; the rest is the
## resolver's own plain data, read back by the queued pass).
const ENTRY_DEF_ID: String = "def_id"
const ENTRY_EFFECT_INDEX: String = "effect_index"
const ENTRY_OWNER: String = "owner"
const ENTRY_TRIGGER: String = "trigger"
const ENTRY_SUBJECT: String = "trigger_subject"
const ENTRY_TRIGGER_SOURCE: String = "trigger_source"
const ENTRY_AMOUNT: String = "amount"
const ENTRY_DEPTH: String = "depth"
## `host_kind` of a hero-slot entry (a card's is [constant HOST_KIND_CARD]).
const ENTRY_HOST_KIND: String = "host_kind"
## The candidate an entry was collected from: the hero for a hero-slot entry.
## The engine orders a death check's entries by it (2026-11-04, AC-45).
const ENTRY_CANDIDATE: String = "candidate"
## C3: what a departed `trigger_subject` / `trigger_source` reads, kept only for
## an effect that names one ([method _keep_trigger_snapshots]).
const ENTRY_SUBJECT_SNAPSHOT: String = ENTRY_SUBJECT + EffectValues.SNAPSHOT_SUFFIX
const ENTRY_SOURCE_SNAPSHOT: String = ENTRY_TRIGGER_SOURCE + EffectValues.SNAPSHOT_SUFFIX
## The text every `trigger_subject` / `trigger_source` reference holds.
const TRIGGER_ENTITY_TEXT: String = "trigger_s"
## A hook-point name authored as a trigger → the DSL trigger whose scope keys it
## answers to. Shipped data spells the DSL trigger (C2); the hook point's own
## name reaches here only from a fixture, and is not a DSL word.
const HOOK_SCOPE_TRIGGERS: Dictionary[String, String] = {
	"on_turn_start": "turn_start",
	"on_turn_end": "turn_end",
	"on_minion_summoned": "on_summon",
	"on_hero_damaged": "on_damage_taken",
}
## The trigger the engine fires once per side, each time with every entry (C3
## step 4): an entry runs for its own side.
const TRIGGER_MATCH_START: String = "on_match_start"
## The resolver's own event, one per effect pass (card-effects C6.6).
const EVENT_EFFECT_RESOLVED: StringName = &"effect_resolved"
## `effect_resolved.host_kind` values (card-effects Interactions).
const HOST_KIND_CARD: String = "card"
const HOST_KIND_HERO_POWER: String = "hero_power"
## `effect_resolved.fizzled` for a false `condition` (C1).
const FIZZLED_CONDITION_FALSE: String = "condition_false"
## This GDD's Choice events (C6.6, C8.1; DD-X04 — distinct from match-rules'
## `choice_requested` / `choice_made`).
const EVENT_DISCOVER_OFFERED: StringName = &"discover_offered"
const EVENT_DISCOVER_PICKED: StringName = &"discover_picked"
## The ops that suspend a pass (C8).
const OP_DISCOVER: String = "discover"
const OP_CHOOSE_ONE: String = "choose_one"
## The DSL play trigger a `discover` `then: cast` pick resolves (C5).
const TRIGGER_CAST: String = "cast"
## The static aura triggers (C2 static class, C7; story 012): `aura` on a
## source in play, and `passive_hand`, the self-only hand aura.
const TRIGGER_AURA: String = "aura"
const TRIGGER_PASSIVE_HAND: String = "passive_hand"
## Run-context field: the index of the running effect in its host's
## `effects[]`, so a resumed pass re-reads the effect from the memo instead of
## carrying it in the continuation.
const RUN_EFFECT_INDEX: String = "effect_index"
## Continuation field: the running effect of a treasure or passive, which no
## definition memo can give back to [method resume].
const RUN_HOST_EFFECT: String = "host_effect"
## `EffectRuntime.pending_choice` — the continuation (C8.1; ADR-0007 Decision
## 1), plain data only: `{effect_id, side, kind, options, op_index, item,
## remaining_ops, entries, run, source_snapshot, tail}` (see [method _offer]).
const CONT_EFFECT_ID: String = "effect_id"
const CONT_SIDE: String = "side"
const CONT_KIND: String = "kind"
const CONT_OPTIONS: String = "options"
const CONT_OP_INDEX: String = "op_index"
const CONT_ITEM: String = "item"
const CONT_REMAINING_OPS: String = "remaining_ops"
const CONT_ENTRIES: String = "entries"
const CONT_RUN: String = "run"
const CONT_SOURCE_SNAPSHOT: String = "source_snapshot"
const CONT_TAIL: String = "tail"
## A play run still owed (a [constant CONT_TAIL] entry): the host's effects
## with `trigger` from index `next`, as [method resolve] runs a play point.
const PLAY_TRIGGER: String = "trigger"
const PLAY_HOST: String = "host_id"
const PLAY_SOURCE: String = "source"
const PLAY_SIDE: String = "side"
const PLAY_TARGET: String = "target_id"
const PLAY_NEXT: String = "next"

var _db: CardDatabase
var _config: Dictionary
## The player's hero set: `base(collectible)` of F4 for both sides (Discover
## and `add_to_hand.from` draw from the player's pool).
var _hero_set: String = ""
## The play runs still owed after the pass running now (a play point's later
## effects; a `then: cast` pick): captured into the continuation when the
## pass suspends ([constant CONT_TAIL]), empty between calls.
var _tail: Array[Dictionary] = []
## The bound engine: set by [method bind], cleared by [method unbind].
var _engine: RulesEngine = null
## `def_id → {effects: Array, record: Dictionary, targeting_spec: Dictionary}`
## — derived from the definition, filled on first use (story 002's memo;
## story 004 adds the record and the memoised targeting spec).
var _memo: Dictionary[String, Dictionary] = {}
## The C5 op dispatch table (stateless; story 006).
var _ops: EffectOps = EffectOps.new()
## `effect_resolved.depth` of the pass running now (0 between passes): a
## trigger raised inside a pass queues with `depth + 1` (story 008). A raise
## inside a pass only collects; the one pass that nests is an in-primitive hook's
## ([method run_hook_effect]), which puts this field back when it ends.
var _depth: int = 0
## `"<def_id>:<index>" → bool`: does this effect name a trigger entity (derived
## data, like [member _memo]; [method _keep_trigger_snapshots]).
var _names_trigger_entity: Dictionary[String, bool] = {}
## The pass context of one [method apply_value_hook] call, refilled in place
## because a fold allocates nothing (ADR-0005 rule 4). `resolver` is set by
## [method bind] and cleared by [method unbind]: it is a reference to this
## object, so it must not outlive the match.
var _fold_run: Dictionary = {
	"resolver": null, "owner": "", "source_id": "", "target_id": null,
	ENTRY_SUBJECT: null, ENTRY_TRIGGER_SOURCE: null, "value": 0,
}
## The filter view of a card instance, hero power or weapon in a fold, refilled
## in place ([method EffectScope.matches_value]).
var _fold_view: Dictionary = {"entity_id": -1, "def_id": "", "controller": "", "kind": ""}


## Keeps [param db] (the frozen `CardDatabase`; lookups by `card(def_id)`)
## and [param effects_config] (the frozen `card_effects` config body, read
## once here and kept as the same reference — never re-queried). In debug
## builds asserts the body's `hooks_before_triggers` is `true` (the knob
## exists only for this assertion; `EffectValidator.validate_config` rejects
## any other value at load).
## [param player_hero_set] is the run's hero set (`HeroDef.set`, e.g. `war`):
## F4's `base(collectible) = collectible_pool(player_hero_set)` for both sides.
## The composition code that knows the hero passes it; `clone()` must pass the
## live resolver's [method player_hero_set] to the clone's. Left empty, a
## `pool: collectible` draw logs an error and offers nothing.
func _init(db: CardDatabase, effects_config: Dictionary, player_hero_set: String = "") -> void:
	_db = db
	_config = effects_config
	_hero_set = player_hero_set
	assert(_config.get(KNOB_HOOKS_BEFORE_TRIGGERS) == true, "card_effects.hooks_before_triggers must be true (card-effects Tuning Knobs)")


## Binds this resolver to [param engine] at `RulesEngine.start` (C3 step 1,
## after `state.hooks = HookRegistry.new()`, before `on_match_start`):
## installs [param installers] in order through the engine's registry (the
## effects with a C2 hook column, [method HookRegistry.hook_point]), routes each
## installed host's `aura` effects and hero-slot observers to
## `EffectRuntime.aura_hosts`, then registers [method apply_value_hook] and
## [method run_hook_effect] as its evaluators. A refused installer (duplicate
## `host_id`) is left for the engine to log, and its effects stay out. A clone
## binds with no installers: its hosts arrive in the copied `MatchState.effects`.
## Example: see the class description.
func bind(engine: RulesEngine, installers: Array[HookInstaller]) -> void:
	assert(_engine == null, "EffectResolver.bind: already bound (one resolver per engine; a clone binds a fresh one)")
	_engine = engine
	_fold_run.resolver = self
	var hooks: HookRegistry = engine.state().hooks
	for installer: HookInstaller in installers:
		if hooks.install(installer):
			_keep_hosted(installer, engine.state().effects)
	hooks.set_evaluators(apply_value_hook, run_hook_effect)


## Routes what [param installer] hosts on the hero slot to [param runtime] (C7,
## C9; stories 013, 015): its `aura` effects and its event triggers with no hook
## column, each with its id settled from its index in the installer. ADR-0005:
## the registry holds only hook-bound effects, and a treasure compiles into no
## card instance (Alt 3).
func _keep_hosted(installer: HookInstaller, runtime: Dictionary) -> void:
	var hosted: Array = []
	for index: int in installer.effects.size():
		var effect: Dictionary = installer.effects[index]
		if str(effect.get("trigger", "")) == TRIGGER_AURA or _is_hero_slot_observer(effect):
			var kept: Dictionary = effect.duplicate(true)
			kept["id"] = _effect_id(effect, installer.host_id, index)
			hosted.append(kept)
	if not hosted.is_empty():
		EffectRuntime.add_aura_host(runtime, installer.host_id, str(installer.host_kind), str(installer.side), hosted)


## Whether [param effect], on a treasure or passive, is a hero-slot observer: an
## event trigger (C2) with no hook column.
static func _is_hero_slot_observer(effect: Dictionary) -> bool:
	var row: Dictionary = EffectSchema.TRIGGERS.get(str(effect.get("trigger", "")), {})
	return row.get("class") == EffectSchema.CLASS_EVENT and HookRegistry.hook_point(effect) == &""


## Releases the engine: clears the registry's evaluators and the engine
## reference, and drops a continuation still pending (a `concede` in
## `Choice` abandons it — C8.5). A no-op when not bound.
## Example: `resolver.unbind()`.
func unbind() -> void:
	if _engine == null:
		return
	var state: MatchState = _engine.state()
	if state != null and state.hooks != null:
		state.hooks.set_evaluators(Callable(), Callable())
	if state != null and state.effects.has("pending_choice"):
		state.effects.pending_choice = null
	_tail.clear()
	_fold_run.resolver = null
	_engine = null


## The player's hero set given to `_init` ("" when none was).
## Example: `EffectResolver.new(db, config, live.player_hero_set())` for a clone.
func player_hero_set() -> String:
	return _hero_set


## F4 `base(collectible)`: `collectible_pool(player_hero_set)` — the same pool
## for both sides (tokens and the `boss` set excluded by Card Database CR-6).
## Without a hero set it logs an error and is empty, so a misbuilt resolver
## shows up as `empty_pool` plus the error, never as a silent pass.
## Example: `resolver.collectible_pool().size()`.
func collectible_pool() -> Array:
	if _hero_set == "":
		push_error("EffectResolver: `pool: collectible` needs the player's hero set (EffectResolver.new(db, config, hero_set); F4)")
		return []
	return _db.collectible_pool(_hero_set)


## The engine this resolver is bound to, or null before [method bind] and
## after [method unbind]. Example: `assert(resolver.bound_engine() == engine)`.
func bound_engine() -> RulesEngine:
	return _engine


## The `card_effects` config body given to `_init` (the same reference).
func effects_config() -> Dictionary:
	return _config


## The value of Tuning Knob [param key] (one of
## [constant EffectValidator.CONFIG_KEYS]) as stored. A missing key is a data
## error `validate_config` reports at load: this asserts in debug builds and
## never falls back to a default.
## Example: `if resolver.knob("discover_exclude_hand"): …`.
func knob(key: String) -> Variant:
	assert(_config.has(key), "card_effects config lacks '%s'" % key)
	return _config.get(key)


## The whole-number Tuning Knob [param key] as an `int` (JSON numbers parse as
## float). Example: `var n: int = resolver.knob_int("discover_count")`.
func knob_int(key: String) -> int:
	return int(knob(key))


## The `effects[]` of definition [param def_id] (`[]` when it has none),
## read from the database once per `def_id` and memoised. The returned Array
## is the database's frozen one: read it, never write it.
## Example: `for effect: Dictionary in resolver.effects_of("war_scout"): …`.
func effects_of(def_id: String) -> Array:
	return _memo_entry(def_id)[MEMO_EFFECTS]


## The frozen definition record of [param def_id] (a CardDef, or a
## HeroPowerDef for a `power_` id — CR-2), memoised; `{}` when the database
## has no such id. Read it, never write it.
## Example: `int(resolver.definition("war_scout").cost)`.
func definition(def_id: String) -> Dictionary:
	return _memo_entry(def_id)[MEMO_RECORD]


## The targeting spec of [param def_id] (card-effects C1 rule 1; ADR-0007 Key
## Interfaces): `{mode: none | optional | required, filter}`, derived from its
## one play-trigger `chosen` selector by `EffectValidator.derive_targeting_spec`
## — never read from a stored field (Card Database CR-3 rejects one) — and
## memoised per `def_id`, so match-rules' C6 validation and
## `legal_commands()` pay one derivation per definition. The same Dictionary
## on every call; read it, never write it. A def_id the database lacks is
## `none`. Example: `if resolver.targeting_spec(def_id).mode == "required": …`.
func targeting_spec(def_id: String) -> Dictionary:
	return _memo_entry(def_id)[MEMO_TARGETING]


## The entity ids [param def_id]'s `chosen` may name when played from
## [param source] (`{side, source_id, card_id}` — the engine's hand-card or
## hero-power source): `[]` for a `none` spec; else every character in
## canonical order (player board, boss board, player hero, boss hero) that is
## not dying, is not an **enemy** Stealth minion (match-rules C12 — the only
## runtime rule beyond the filter) and matches the spec's filter, "friendly"
## relative to `source.side`. Reads the bound engine's live state; never
## writes. Example: `var ids: Array[int] = resolver.legal_targets("knowledge_bolt", source)`.
func legal_targets(def_id: String, source: Dictionary) -> Array[int]:
	var spec: Dictionary = targeting_spec(def_id)
	if str(spec.mode) == EffectSchema.TARGETING_NONE:
		var none: Array[int] = []
		return none
	assert(_engine != null, "EffectResolver.legal_targets: not bound to an engine")
	return EffectSelectors.chosen_candidates(self, spec.filter, str(source.side), int(source.get("source_id", -1)))


## Trigger point [param trigger_point] fired by the engine with
## [param ctx] (`{candidates: Array[int], side, …}` in engine order); returns
## the triggers this pass queues, which the engine appends to Q (ADR-0007 Key
## Interfaces, erratum 2026-11-03). The engine raises points from setup on
## (`on_draw` while dealing starting hands), so a bound resolver must answer.
##
## **Play points** (`battlecry`, `on_cast`, `hero_power` — card-effects C2
## play class, C6.2): the single candidate is the host `ctx.source`
## (`ctx {side, candidates: [source], source, target_id, card_id}`, match-rules
## C6 step 3a / C7). Its definition `ctx.card_id`'s effects whose trigger binds
## to the point run **now**, in `effects[]` order, each as one pass
## ([method _run_pass]); a play point queues nothing. A Battlecry whose
## `required` `chosen` has no legal target never reaches here: the engine does
## not raise it (`RulesEngine._play_plan` `fizzles`; card-effects AC-08).
##
## **Event points** ([constant EVENT_TRIGGERS] — C2 event class, C6.2, story
## 008): walks `ctx.candidates` in the engine's order (never re-sorted) and,
## per candidate, its definition effects in `effects[]` order; each effect
## whose trigger binds to the point and that [method _responds] is returned
## as one queue entry (`{source_id, effect_id, snapshot, def_id, effect_index, owner,
## trigger, trigger_subject, trigger_source, amount, depth}`) — the engine
## appends them to Q; nothing runs now (C10: triggers queue, never nest).
## **A queued entry** (`ctx.queued`, the engine popping it) runs as that one
## pass ([method _run_queued]) and queues nothing itself.
## Example: `var queued: Array[Dictionary] = resolver.resolve(&"on_draw", ctx)`.
func resolve(trigger_point: StringName, ctx: Dictionary) -> Array[Dictionary]:
	var queued: Array[Dictionary] = []
	if bool(ctx.get(RulesEngine.CTX_QUEUED, false)):
		_run_queued(ctx)
	elif PLAY_TRIGGERS.has(trigger_point):
		_run_play_point(PLAY_TRIGGERS[trigger_point], ctx)
	elif EVENT_TRIGGERS.has(trigger_point):
		_keep_tallies(trigger_point, ctx)
		queued = _collect(trigger_point, ctx)
	return queued


## The C4 per-turn tallies, kept from the trigger points the resolver
## already sees (C6.8, story 007; `EffectRuntime.per_turn`): `turn_start`
## drops `ctx.side`'s tallies; `on_card_played` bumps the player's
## `cards_played_this_turn` (and `spells_cast_this_turn` for a spell);
## `on_minion_died` bumps the dead minion's side's `minions_died_this_turn`.
## Bumped before the observers are collected; they read it when they resolve.
func _keep_tallies(point: StringName, ctx: Dictionary) -> void:
	var runtime: Dictionary = _engine.state().effects
	var side: String = str(ctx.get("side", ""))
	match point:
		&"turn_start":
			EffectRuntime.reset_turn(runtime, side)
		&"on_card_played":
			EffectRuntime.bump(runtime, side, "cards_played_this_turn")
			if str(definition(str(ctx.get("card_id", ""))).get("type", "")) == EffectOps.HOST_TYPE_SPELL:
				EffectRuntime.bump(runtime, side, "spells_cast_this_turn")
		&"on_minion_died":
			EffectRuntime.bump(runtime, side, "minions_died_this_turn")


## C7 / F2 (story 012): re-applies every live aura. The engine's C10 loop calls
## this once per loop pass (match-rules C10; the End step too) **after** it has
## stripped every `is_aura` enchantment — characters, weapons and hand
## `cost_modifiers` (`RulesEngine._recompute_auras`, the engine's side of the
## contract) — and while it keeps the re-applications silent (one
## `auras_recomputed` lists the net changes). Walks the sources in canonical
## order ([method _aura_sources]: player board left to right, boss board, then
## the equipped weapons, player first), skips a **silenced** source (Silence
## stops emission, match-rules C13), and runs each definition effect with
## trigger `aura` through [method EffectOps.apply_aura]: its `targets` evaluated
## afresh, one `apply_enchantment(…, is_aura: true)` per (source, effect,
## target). Then the treasures' and the passive's auras, hosted on their owner's
## hero slot, in installation order (C7, C9; story 013): always live, never
## Silenced, and the enchantment's `source_entity_id` is the host id. Then
## every hand card's own `passive_hand` effects, each on that card only
## (C7: the self-only hand aura, its value read now). Holds no state of its
## own: what an aura grants is re-derived from the board and
## `EffectRuntime.aura_hosts` every call, so a `clone()` recomputes the same
## auras from its copied state.
## Example: the engine's `_resolver.recompute_auras()`.
func recompute_auras() -> void:
	assert(_engine != null, "EffectResolver.recompute_auras: not bound to an engine")
	var state: MatchState = _engine.state()
	for source: Dictionary in _aura_sources(state):
		if bool(source.get("silenced", false)) or not source.has("def_id"):
			continue
		var def_id: String = str(source.def_id)
		var owner: String = EffectScope.controller_of(state, int(source.entity_id))
		var effects: Array = effects_of(def_id)
		for index: int in effects.size():
			var effect: Dictionary = effects[index]
			if str(effect.get("trigger", "")) == TRIGGER_AURA:
				_ops.apply_aura(_engine, _aura_run(effect, def_id, index, int(source.entity_id), owner), null)
	for host: Dictionary in state.effects.get("aura_hosts", []):
		var hosted: Array = host.effects
		for index: int in hosted.size():
			if str((hosted[index] as Dictionary).get("trigger", "")) == TRIGGER_AURA:
				_ops.apply_aura(_engine, _aura_run(hosted[index], str(host.host_id), index, str(host.host_id), str(host.side)), null)
	for side: String in MatchRecords.SIDES:
		for card: Dictionary in state.players[side].hand:
			var effects: Array = effects_of(str(card.def_id))
			for index: int in effects.size():
				var effect: Dictionary = effects[index]
				if str(effect.get("trigger", "")) == TRIGGER_PASSIVE_HAND:
					_ops.apply_aura(_engine, _aura_run(effect, str(card.def_id), index, int(card.instance_id), side), int(card.instance_id))


## The aura sources in play, in C7's canonical source order: player board
## left to right, boss board left to right, then the equipped weapons (player,
## boss — `aura` hosts include weapons, C2; C3 orders weapons after the boards).
func _aura_sources(state: MatchState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for side: String in MatchRecords.SIDES:
		out.append_array(state.players[side].board)
	for side: String in MatchRecords.SIDES:
		var weapon: Variant = state.players[side].weapon
		if weapon != null:
			out.append(weapon)
	return out


## The pass context of one aura effect (plain run fields, as [method _run_pass]
## builds them, plus [constant EffectSelectors.RUN_AURA_RECOMPUTE]).
## [param source_id] is an entity id, or a treasure's or passive's String id.
func _aura_run(effect: Dictionary, def_id: String, index: int, source_id: Variant, owner: String) -> Dictionary:
	return {
		"effect": effect,
		"resolver": self,
		"effect_id": str(effect.get("id", "%s.%d" % [def_id, index])),
		"host_id": def_id,
		"source_id": source_id,
		"owner": owner,
		"target_id": null,
		EffectSelectors.RUN_AURA_RECOMPUTE: true,
	}


## One value-hook fold step (ADR-0005 `set_evaluators` shape; card-effects C2
## value class, C9; story 014): [param value] after the entry's `modify_value`
## ops, or [param value] unchanged when the entry's `scope` does not match this
## occurrence ([method EffectScope.matches_value], relative to `entry.side`,
## ADR-0005 rule 3) or its `condition` is false — evaluated on every call, so it
## sees `context.value`, the previous entry's output, and the live tallies (C1;
## Treasures R-2). An entry whose trigger is not a value trigger never matches.
## [param side] is the fold's side, read only by the `side` scope of
## `modify_starting_hand_size` and as a hero power's controller. Never clamps:
## the engine clamps once after the whole fold (ADR-0005 rule 4). Mutates no
## match state and builds nothing: it refills [member _fold_run] and
## [member _fold_view] in place.
## Example: `hooks.set_evaluators(resolver.apply_value_hook, resolver.run_hook_effect)`.
func apply_value_hook(entry: Dictionary, side: StringName, value: int, ctx: Dictionary) -> int:
	var effect: Dictionary = entry.effect
	var owner: String = str(entry.side)
	var run: Dictionary = _fold_run
	run.owner = owner
	run.source_id = entry.get("host_id", "")
	run.value = value
	run[ENTRY_TRIGGER_SOURCE] = ctx.get("source")
	run[ENTRY_SUBJECT] = ctx.get("target")
	if not EffectScope.matches_value(self, str(effect.get("trigger", "")), effect.get("scope"), str(side), ctx, owner, _fold_view, run):
		return value
	if not EffectValues.holds(effect.get("condition"), run):
		return value
	var folded: int = value
	var ops: Variant = effect.get("ops")
	if ops is Array:
		for op: Dictionary in ops:
			folded = EffectOps.modify_value(op, folded, run)
			run.value = folded
	return folded


## One trigger-hook step at a hook point (card-effects C9; story 015): the
## entry's effect as **one pass now**, not queued, when its `scope` matches this
## occurrence relative to `entry.side` (ADR-0005 rule 3) and its `once_per_turn`
## mark is clear. [param side] is the side the point concerns; [param ctx] is the
## engine's hook payload ([method _hook_occurrence]). The engine owns what comes
## after: at a step boundary this call is the whole step and the C10 loop follows;
## inside a primitive it nests in the running pass, one `depth` below it, and
## hands that pass its depth back. The host id is `source_id` throughout (C9).
## Example: `hooks.set_evaluators(resolver.apply_value_hook, resolver.run_hook_effect)`.
func run_hook_effect(entry: Dictionary, side: StringName, ctx: Dictionary) -> void:
	assert(_engine != null, "EffectResolver.run_hook_effect: not bound to an engine")
	var effect: Dictionary = entry.effect
	var owner: String = str(entry.side)
	var trigger: String = str(effect.get("trigger", ""))
	var bound: String = HOOK_SCOPE_TRIGGERS.get(trigger, trigger)
	if bound == TRIGGER_MATCH_START and str(side) != owner:
		return
	var occurrence: Dictionary = _hook_occurrence(bound, str(side), ctx)
	if not EffectScope.matches(self, bound, effect.get("scope"), occurrence, EffectSelectors.NO_SOURCE, owner):
		return
	var host_id: String = str(entry.host_id)
	var effect_id: String = str(entry.effect_id)
	if not _claim_once(effect, effect_id, host_id):
		return
	var outer: int = _depth
	@warning_ignore("return_value_discarded")
	_run_pass(effect, {
		"effect_id": effect_id,
		"host_id": host_id,
		"host_kind": str(entry.host_kind),
		"source_id": host_id,
		"owner": owner,
		"trigger": trigger,
		"target_id": null,
		ENTRY_SUBJECT: occurrence.get("instance_id", occurrence.get("subject")),
		ENTRY_TRIGGER_SOURCE: occurrence.get("source"),
		ENTRY_AMOUNT: occurrence.get("amount"),
		ENTRY_DEPTH: outer + 1,
	})
	_depth = outer


## The trigger `ctx` [method EffectScope.matches] reads for one hook occurrence,
## from the engine's hook payload (match-rules hook table): the side is the
## call's, and the subject is the played or summoned entity, the drawn card, or
## for `on_damage_taken` the hero of [param side], with `amount_dealt` as `amount`.
func _hook_occurrence(trigger: String, side: String, ctx: Dictionary) -> Dictionary:
	var occurrence: Dictionary = ctx.duplicate()
	occurrence["side"] = side
	if trigger == HookRegistry.TRIGGER_DAMAGE_TAKEN:
		occurrence["subject"] = int(_engine.state().players[side].hero.entity_id)
		occurrence[ENTRY_AMOUNT] = ctx.get("amount_dealt")
	else:
		occurrence["subject"] = ctx.get("entity_id", ctx.get("instance_id"))
	return occurrence


## C6.5, story 013: the pass [param run_ctx]'s source [param old_id] was
## transformed into [param new_id], so `self` is the new body for the ops left in
## this pass and for the later effects of its play run, kept in [member _tail].
## Queued triggers of the old entity keep their snapshot.
## Example: `resolver.rebind_source(run, old_id, new_id)`.
func rebind_source(run_ctx: Dictionary, old_id: int, new_id: int) -> void:
	run_ctx.source_id = new_id
	for play: Dictionary in _tail:
		if int(play[PLAY_SOURCE]) == old_id:
			play[PLAY_SOURCE] = new_id


## Runs every effect of the host `ctx.card_id` whose trigger is
## [param trigger] now, in `effects[]` order (C1 rule 3, C6.2).
func _run_play_point(trigger: String, ctx: Dictionary) -> void:
	assert(_engine != null, "EffectResolver.resolve: not bound to an engine")
	@warning_ignore("return_value_discarded")
	_run_play_from({
		PLAY_TRIGGER: trigger,
		PLAY_HOST: str(ctx.card_id),
		PLAY_SOURCE: int(ctx.source),
		PLAY_SIDE: str(ctx.side),
		PLAY_TARGET: ctx.get("target_id"),
		PLAY_NEXT: 0,
	})


## The play run [param play] (`{trigger, host_id, source, side, target_id,
## next}`): each effect of the host from index `next` whose trigger is
## `trigger`, as one pass each. While a pass runs, the rest of this run is at
## the front of [member _tail], so a pass that suspends for a choice carries
## it in its continuation and [method resume] runs it after `choose`.
## Returns false when a pass suspended, or the match ended in it (nothing after
## it ran).
func _run_play_from(play: Dictionary) -> bool:
	var host_id: String = str(play[PLAY_HOST])
	var power_prefix: String = str(RecordSchemas.SCHEMAS[HERO_POWER_RECORD].prefix)
	var host_kind: String = HOST_KIND_HERO_POWER if host_id.begins_with(power_prefix) else HOST_KIND_CARD
	var trigger: String = str(play[PLAY_TRIGGER])
	var effects: Array = effects_of(host_id)
	for index: int in range(int(play[PLAY_NEXT]), effects.size()):
		var effect: Dictionary = effects[index]
		if str(effect.get("trigger", "")) != trigger or not _claim_once(effect, _effect_id(effect, host_id, index), int(play[PLAY_SOURCE])):
			continue
		var rest: Dictionary = play.duplicate(true)
		rest[PLAY_NEXT] = index + 1
		_tail.push_front(rest)
		var finished: bool = _run_pass(effect, {
			"effect_id": str(effect.get("id", "%s.%d" % [host_id, index])),
			"host_id": host_id,
			"host_kind": host_kind,
			"source_id": int(play[PLAY_SOURCE]),
			"owner": str(play[PLAY_SIDE]),
			"trigger": trigger,
			"target_id": play[PLAY_TARGET],
			RUN_EFFECT_INDEX: index,
		})
		_tail.pop_front()
		if not finished:
			return false
		play[PLAY_SOURCE] = rest[PLAY_SOURCE]
	return true


## C6.2 "who responds" for event point [param point]: the queue entries of
## every candidate effect that responds, in candidate order, then
## `effects[]` order within one candidate (definition effects; the
## enchantment-granted ones after them arrive with story 012). The engine
## decides candidates and their order; this never re-sorts them. A hero in the
## candidates stands for its side's hero slot ([method _collect_hero_slot]).
func _collect(point: StringName, ctx: Dictionary) -> Array[Dictionary]:
	assert(_engine != null, "EffectResolver.resolve: not bound to an engine")
	var queued: Array[Dictionary] = []
	var triggers: Array = EVENT_TRIGGERS[point]
	var subject: Variant = ctx.get("subject")
	var hosts: Array = _engine.state().effects.aura_hosts
	for candidate: Variant in ctx.get("candidates", []):
		var source_id: int = int(candidate)
		if not hosts.is_empty():
			var slot: String = _hero_slot(source_id)
			if slot != "":
				_collect_hero_slot(point, ctx, slot, source_id, triggers, queued)
				continue
		if ENTRY_POINTS.has(point) and (subject != null and int(subject) == source_id or int(ctx.get("entered", RulesEngine.NO_ENTITY)) == source_id):
			continue
		var host: Dictionary = _candidate_host(point, source_id, ctx)
		if host.is_empty():
			continue
		var def_id: String = str(host.def_id)
		var effects: Array = effects_of(def_id)
		for index: int in effects.size():
			var effect: Dictionary = effects[index]
			var trigger: String = str(effect.get("trigger", ""))
			if not triggers.has(trigger) or not _responds(trigger, effect, ctx, source_id, str(host.owner)):
				continue
			if not _claim_once(effect, _effect_id(effect, def_id, index), source_id):
				continue
			queued.append(_queue_entry(point, ctx, source_id, def_id, index, effect, str(host.owner), trigger, source_id))
	return queued


## The side whose hero is [param candidate], or "" for any other entity.
func _hero_slot(candidate: int) -> String:
	for side: String in MatchRecords.SIDES:
		var hero: Variant = _engine.state().players[side].hero
		if hero != null and int(hero.entity_id) == candidate:
			return side
	return ""


## C9: [param slot]'s hero-slot observers on [param point], appended to
## [param queued]: its hosts in installation order, each host's effects in order.
## A treasure or passive is always a live source, never Silenced, so only `scope`
## and the mark decide; both are keyed on the host id. [param hero] is the
## candidate they answer for. The entry's snapshot is empty: a host has no stats
## to keep, and its counters stay live.
func _collect_hero_slot(point: StringName, ctx: Dictionary, slot: String, hero: int, triggers: Array, queued: Array[Dictionary]) -> void:
	for host: Dictionary in _engine.state().effects.aura_hosts:
		if str(host.side) != slot:
			continue
		var host_id: String = str(host.host_id)
		var effects: Array = host.effects
		for index: int in effects.size():
			var effect: Dictionary = effects[index]
			var trigger: String = str(effect.get("trigger", ""))
			if not triggers.has(trigger) or not _is_hero_slot_observer(effect):
				continue
			if not _responds(trigger, effect, ctx, EffectSelectors.NO_SOURCE, slot):
				continue
			if not _claim_once(effect, _effect_id(effect, host_id, index), host_id):
				continue
			var entry: Dictionary = _queue_entry(point, ctx, host_id, host_id, index, effect, slot, trigger, hero)
			entry[ENTRY_HOST_KIND] = str(host.host_kind)
			queued.append(entry)


## The candidate's host `{def_id, owner}`, or `{}` when it cannot respond:
## a Silenced source responds to nothing (C6.2; a trigger already queued still
## resolves, [method _run_queued]). The exception is a Deathrattle the engine
## kept through Silence: `deathrattles_kept` on the death snapshot, set when
## Silence hit a minion already `pending_destroy` (match-rules C13 step 2;
## 2026-11-04, DD-X21). A Deathrattle's candidate has just left play, so it is
## read from the death snapshot `ctx.snapshot` (match-rules C10); every other
## candidate is a minion or weapon in play. Heroes host no definition
## effects: a hero candidate's treasures and passive are [method
## _collect_hero_slot]'s (a hero power's event triggers are not hosted yet: no
## shipped power has one).
func _candidate_host(point: StringName, source_id: int, ctx: Dictionary) -> Dictionary:
	var record: Dictionary = {}
	var owner: String = ""
	if point == &"deathrattle":
		var snapshot: Variant = ctx.get("snapshot")
		if snapshot is Dictionary and int((snapshot as Dictionary).get("entity_id", -1)) == source_id:
			record = snapshot
			owner = str(record.get("controller", ctx.get("side", "")))
			if bool(record.get("deathrattles_kept", false)):
				return {"def_id": str(record.def_id), "owner": owner}
	else:
		var state: MatchState = _engine.state()
		var kind: String = EffectSelectors.kind_of(state, source_id)
		if kind == MatchRecords.KIND_MINION or kind == EffectSelectors.KIND_WEAPON:
			record = EffectSelectors.find(state, source_id)
			owner = EffectScope.controller_of(state, source_id)
	if record.is_empty() or not record.has("def_id") or bool(record.get("silenced", false)):
		return {}
	return {"def_id": str(record.def_id), "owner": owner}


## Whether [param effect] (DSL [param trigger], source [param source_id],
## owned by [param owner]) responds to this occurrence [param ctx]: its
## `scope` matches (C2, [EffectScope]). The trigger binding, liveness and
## Silence are checked by the caller, and the `once_per_turn` mark by
## [method _claim_once] once this says yes.
func _responds(trigger: String, effect: Dictionary, ctx: Dictionary, source_id: int, owner: String) -> bool:
	return EffectScope.matches(self, trigger, effect.get("scope"), ctx, source_id, owner)


## C6.7: true when [param effect] (id [param effect_id]) may be queued or run for
## [param source_id] now: an entity id, or the id of a treasure or passive (C9).
## Without `once_per_turn` that is always; with it the first call of a global
## `turn` sets the mark and says yes, and any later one says no — a dropped raise
## emits nothing (Edge Cases: nothing mutated). The mark is set here, when queued
## or run, so two raises in one step produce one resolution; a false `condition`
## still spends it.
func _claim_once(effect: Dictionary, effect_id: String, source_id: Variant) -> bool:
	if not bool(effect.get("once_per_turn", false)):
		return true
	var state: MatchState = _engine.state()
	var key: String = EffectRuntime.once_key(effect_id, source_id, int(state.turn))
	if EffectRuntime.once_marked(state.effects, key):
		return false
	EffectRuntime.mark_once(state.effects, key)
	return true


## The id of [param effect]: its own `id`, else `def_id.index`.
static func _effect_id(effect: Dictionary, def_id: String, index: int) -> String:
	return str(effect.get("id", "%s.%d" % [def_id, index]))


## One queue entry (ADR-0007 erratum shape plus this resolver's fields):
## plain data only — the engine copies it into Q and back into `ctx`.
## `trigger_subject` is the card instance for `on_card_played` (C2), the
## defender for `on_attack`, else `ctx.subject`; `trigger_source` is the
## damager / healer (`ctx.source`) or the attacker. `snapshot` is the C6.5
## raise-time snapshot ([method EffectValues.source_snapshot]) of the source as
## it is now: the death record for a Deathrattle, so post-Silence stats for a
## kept one; the live record otherwise; empty for a treasure or passive, whose
## [param source_id] is its String id. [param candidate] is the candidate it came
## from ([constant ENTRY_CANDIDATE]).
func _queue_entry(point: StringName, ctx: Dictionary, source_id: Variant, def_id: String, index: int, effect: Dictionary, owner: String, trigger: String, candidate: int) -> Dictionary:
	var subject: Variant = ctx.get("subject")
	var trigger_source: Variant = null
	match point:
		&"on_card_played":
			subject = ctx.get("instance_id", subject)
		&"on_attack":
			subject = ctx.get("defender")
			trigger_source = ctx.get("attacker")
		&"on_damage", &"on_heal":
			trigger_source = ctx.get("source")
	var snapshot: Dictionary = {}
	if not source_id is String:
		var record: Dictionary = ctx.snapshot if point == &"deathrattle" else EffectSelectors.find(_engine.state(), source_id)
		snapshot = EffectValues.source_snapshot(self, record, source_id, def_id, owner)
	var entry: Dictionary = {
		"source_id": source_id,
		"effect_id": _effect_id(effect, def_id, index),
		"snapshot": snapshot,
		ENTRY_DEF_ID: def_id,
		ENTRY_EFFECT_INDEX: index,
		ENTRY_OWNER: owner,
		ENTRY_TRIGGER: trigger,
		ENTRY_SUBJECT: subject,
		ENTRY_TRIGGER_SOURCE: trigger_source,
		ENTRY_AMOUNT: ctx.get("amount"),
		ENTRY_DEPTH: _depth + 1,
		ENTRY_CANDIDATE: candidate,
	}
	_keep_trigger_snapshots(entry, effect, def_id, index, ctx)
	return entry


## C3: `trigger_subject` / `trigger_source` read the raise-time snapshot once the
## entity has left play, so [param entry] keeps one of each, for an effect that
## names either. The rest skip the copy: this runs per queued trigger.
func _keep_trigger_snapshots(entry: Dictionary, effect: Dictionary, def_id: String, index: int, ctx: Dictionary) -> void:
	var key: String = "%s:%d" % [def_id, index]
	if not _names_trigger_entity.has(key):
		_names_trigger_entity[key] = str(effect).contains(TRIGGER_ENTITY_TEXT)
	if _names_trigger_entity[key]:
		entry[ENTRY_SUBJECT_SNAPSHOT] = _entity_snapshot(entry[ENTRY_SUBJECT], ctx)
		entry[ENTRY_SOURCE_SNAPSHOT] = _entity_snapshot(entry[ENTRY_TRIGGER_SOURCE], ctx)


## The C6.5-shaped snapshot of [param id] now: the death record `ctx.snapshot`
## when it names [param id], else the character in play; `{}` for anything with no
## stats to keep (a card instance, a host's String id, null).
func _entity_snapshot(id: Variant, ctx: Dictionary) -> Dictionary:
	if typeof(id) != TYPE_INT and typeof(id) != TYPE_FLOAT:
		return {}
	var dead: Variant = ctx.get("snapshot")
	var named: bool = dead is Dictionary and int((dead as Dictionary).get("entity_id", -1)) == int(id)
	var record: Dictionary = dead if named else EffectSelectors.find(_engine.state(), int(id))
	var owner: String = str(record.get("controller", ""))
	if owner == "":
		return {}
	return EffectValues.source_snapshot(self, record, int(id), str(record.get("def_id", "")), owner)


## The engine popped one of this resolver's queue entries (`ctx` is the
## entry, its C6.5 `snapshot` included, plus `queued`): run that effect as one
## pass, whether or not its source is still in play (C6.5: queued = earned).
## The engine emitted `trigger_resolved` first; this pass runs under it.
func _run_queued(ctx: Dictionary) -> void:
	assert(_engine != null, "EffectResolver.resolve: not bound to an engine")
	var def_id: String = str(ctx.get(ENTRY_DEF_ID, ""))
	var source: Variant = ctx.source_id
	var hosted: bool = source is String
	var effects: Array = EffectRuntime.hosted_effects(_engine.state().effects, def_id) if hosted else effects_of(def_id)
	var index: int = int(ctx.get(ENTRY_EFFECT_INDEX, -1))
	assert(index >= 0 and index < effects.size(), "EffectResolver: queued entry %s names no effect of %s" % [ctx.get("effect_id"), def_id])
	if index < 0 or index >= effects.size():
		return
	@warning_ignore("return_value_discarded")
	_run_pass(effects[index], {
		"effect_id": str(ctx.effect_id),
		"host_id": def_id,
		"host_kind": str(ctx.get(ENTRY_HOST_KIND, HOST_KIND_CARD)),
		"source_id": source if hosted else int(source),
		"owner": str(ctx.get(ENTRY_OWNER, "")),
		"trigger": str(ctx.get(ENTRY_TRIGGER, "")),
		"target_id": null,
		ENTRY_SUBJECT: ctx.get(ENTRY_SUBJECT),
		ENTRY_TRIGGER_SOURCE: ctx.get(ENTRY_TRIGGER_SOURCE),
		ENTRY_SUBJECT_SNAPSHOT: ctx.get(ENTRY_SUBJECT_SNAPSHOT),
		ENTRY_SOURCE_SNAPSHOT: ctx.get(ENTRY_SOURCE_SNAPSHOT),
		ENTRY_AMOUNT: ctx.get(ENTRY_AMOUNT),
		ENTRY_DEPTH: int(ctx.get(ENTRY_DEPTH, 1)),
		"snapshot": ctx.get("snapshot", {}),
		RUN_EFFECT_INDEX: index,
	})


## C5 `retrigger` (sprint-4 review S5): the queue entries of [param target_id]'s
## live effects with DSL trigger [param trigger], as if that point had been
## raised now — [method _collect] over the one candidate, so Silence, `scope`
## and the entry shape are the real raise's (depth included: one below the pass
## running now). The entity is still in play, so it stands in for the death
## snapshot [method _candidate_host] reads. `[]` when it has no such effect, or
## is Silenced: C3 "live (unsilenced)" holds here, so a Deathrattle kept through
## Silence fires from the death and nothing else (2026-11-04, DD-X21; M1 review H1).
## A hero has no effects of its own: it never stands for its hero slot here.
## Queues nothing itself: the op hands the entries to the engine.
## Example: `var entries: Array[Dictionary] = resolver.retrigger_entries("deathrattle", id)`.
func retrigger_entries(trigger: String, target_id: int) -> Array[Dictionary]:
	var state: MatchState = _engine.state()
	var candidates: Array[int] = [target_id]
	if bool(EffectSelectors.find(state, target_id).get("silenced", false)) or _hero_slot(target_id) != "":
		var none: Array[Dictionary] = []
		return none
	return _collect(StringName(trigger), {
		"side": EffectScope.controller_of(state, target_id),
		"candidates": candidates,
		"subject": target_id,
		"snapshot": EffectSelectors.find(state, target_id),
	})


## One effect pass — one C10 step (card-effects C6.0, C6.4; ADR-0007
## Decision 1): `condition` once (false → `fizzled: condition_false`, every op
## `skipped`, nothing called) → each op in order through [EffectOps] (its
## selector against the live board, the primitive per target, its `ops[]`
## entry; an op with no target never stops the next) → exactly one
## `effect_resolved` through `engine.emit`, under the engine's current
## `cause_seq` (the command's `card_played` / `spell_cast` /
## `hero_power_used` for a play trigger, C6.6). Never runs the death check or
## `recompute_auras()`: the engine's C10 loop does, after the pass, so a minion
## an op destroys is still in play — dying — for the ops after it.
## `depth` (Interactions: the length of the `cause_seq` chain to the
## command) is 0 for a play effect — the command's own — and, for a queued
## pass, the depth of the pass that raised it plus one (1 when raised outside
## any pass: a command's own primitive, a combat hit, a death check, a turn
## step).
## **Suspension** (C8, story 010): the ops run off a plain-data work list
## ([method EffectOps.work]); a `discover` / `choose_one` that raises a
## `ChoiceRequest` ([method _offer]) stores the rest of the list as the
## continuation and the pass returns **false** — no `effect_resolved`, no
## later op, no draw — until [method resume] finishes it. Returns true when
## the pass ran to its `effect_resolved` and the match goes on.
func _run_pass(effect: Dictionary, run_ctx: Dictionary) -> bool:
	run_ctx["effect"] = effect
	run_ctx["resolver"] = self
	_depth = int(run_ctx.get(ENTRY_DEPTH, 0))
	var fizzled: Variant = null
	var entries: Array[Dictionary] = []
	var todo: Array[Dictionary] = []
	if _condition_holds(effect.get("condition"), run_ctx):
		todo = EffectOps.work(effect.get("ops", []))
	else:
		fizzled = FIZZLED_CONDITION_FALSE
		for op: Dictionary in effect.get("ops", []):
			var none: Array[int] = []
			entries.append(EffectOps.entry(str(op.get("op", "")), none, {}, EffectOps.SKIPPED))
	return _continue_pass(run_ctx, entries, todo, fizzled)


## Runs the work list [param todo] of a pass to its end — then the one
## `effect_resolved` with [param entries] (the `ops[]` so far plus each item's)
## — or until a choice suspends it (returns false; see [method _run_pass]).
## An emit that hits the event cap ends the match and unbinds this resolver in
## its own frame (sprint-4 review S1): [member _engine] goes null, the rest of
## the list is dropped and it returns false, so no owed play run follows.
## A treasure's or passive's pass runs with the engine naming it on every event
## (C9: `source_id` is the host's id); the source a nesting pass interrupted comes
## back after it.
func _continue_pass(run_ctx: Dictionary, entries: Array[Dictionary], todo: Array[Dictionary], fizzled: Variant) -> bool:
	if not run_ctx.source_id is String:
		return _work_through(run_ctx, entries, todo, fizzled)
	var engine: RulesEngine = _engine
	var outer: Variant = engine.event_source()
	engine.set_event_source(run_ctx.source_id)
	var finished: bool = _work_through(run_ctx, entries, todo, fizzled)
	engine.set_event_source(outer)
	return finished


## The body of [method _continue_pass].
func _work_through(run_ctx: Dictionary, entries: Array[Dictionary], todo: Array[Dictionary], fizzled: Variant) -> bool:
	while not todo.is_empty() and _engine != null:
		var item: Dictionary = todo.front()
		var name: String = str((item.op as Dictionary).get("op", ""))
		if not bool(item.skip) and (name == OP_DISCOVER or name == OP_CHOOSE_ONE):
			todo.pop_front()
			if _offer(item, run_ctx, entries, todo):
				_depth = 0
				return false
			continue
		entries.append_array(_ops.step(_engine, todo, run_ctx))
	if _engine == null:
		_depth = 0
		return false
	@warning_ignore("return_value_discarded")
	_engine.emit(EVENT_EFFECT_RESOLVED, {
		"effect_id": run_ctx.effect_id,
		"host_id": run_ctx.host_id,
		"host_kind": run_ctx.host_kind,
		"source_id": run_ctx.source_id,
		"owner": run_ctx.owner,
		"trigger": run_ctx.trigger,
		"depth": _depth,
		"fizzled": fizzled,
		"ops": entries,
	})
	_depth = 0
	return _engine != null


## C8.1 for the work item [param item] (a `discover` or `choose_one` op):
## builds the options — F4 for `discover` ([method EffectOps.pool_candidates],
## `n = count` (default `DISCOVER_COUNT`) draws with removal), the option
## records for `choose_one` — and, when there are any, raises the request
## through the engine's `discover(owner, options, kind, source_id, effect_id)`
## primitive (it enters `Choice`, emits `choice_requested`), emits
## `discover_offered {side, source_id, effect_id, kind, option_card_ids |
## option_label_keys}` and stores the continuation in
## `EffectRuntime.pending_choice` — `{effect_id, side, kind, options,
## op_index, item, remaining_ops, entries, run, source_snapshot, tail}`, plain
## data (the run context without the effect and the resolver, the work list
## left, the `ops[]` entries so far, the play runs still owed). Returns true
## when the pass is now suspended. No candidate: one `empty_pool` entry, no
## Choice, false (the effect continues — AC-11). A request the engine refuses
## (Setup, an in-primitive hook, the match ended, or one already pending — the
## engine logs why): one `skipped` entry, false, and [param todo] is emptied, so
## the effect's later ops do not run (C6.0; match-rules C3 step 4; review N2).
func _offer(item: Dictionary, run_ctx: Dictionary, entries: Array[Dictionary], todo: Array[Dictionary]) -> bool:
	var op: Dictionary = item.op
	var name: String = str(op.get("op", ""))
	var owner: String = str(run_ctx.owner)
	var none: Array[int] = []
	var kind: String = ChoiceRequest.KIND_CHOOSE_ONE if name == OP_CHOOSE_ONE else ChoiceRequest.KIND_DISCOVER
	var options: Array = []
	if kind == ChoiceRequest.KIND_CHOOSE_ONE:
		options = (op.get("options", []) as Array).duplicate(true)
	else:
		var n: int = maxi(0, EffectValues.eval(op.get("count", knob_int(EffectOps.KNOB_DISCOVER_COUNT)), run_ctx))
		options = EffectOps.draw_options(_engine, EffectOps.pool_candidates(self, op, run_ctx), n)
		if options.is_empty():
			var empty: Dictionary = EffectOps.entry(name, none, {"pool": str(op.get("pool", "")), "options": []}, EffectOps.EMPTY_POOL)
			EffectOps.tag_condition(empty, item)
			entries.append(empty)
			return false
	var request: Dictionary = _engine.discover(owner, options, kind, run_ctx.source_id, str(run_ctx.effect_id))
	if request.is_empty():
		var refused: Dictionary = EffectOps.entry(name, none, {}, EffectOps.SKIPPED)
		EffectOps.tag_condition(refused, item)
		entries.append(refused)
		todo.clear()
		return false
	var offered: Dictionary = {"side": owner, "source_id": run_ctx.source_id, "effect_id": str(run_ctx.effect_id), "kind": kind}
	if kind == ChoiceRequest.KIND_CHOOSE_ONE:
		offered["option_label_keys"] = options.map(func(option: Variant) -> String: return str((option as Dictionary).get("label_key", "")))
	else:
		offered["option_card_ids"] = options.duplicate()
	@warning_ignore("return_value_discarded")
	_engine.emit(EVENT_DISCOVER_OFFERED, offered)
	if _engine == null:
		return true
	var run: Dictionary = run_ctx.duplicate()
	run.erase("effect")
	run.erase("resolver")
	if run_ctx.source_id is String:
		run[RUN_HOST_EFFECT] = run_ctx.effect
	var snapshot: Variant = run_ctx.get("snapshot")
	if not snapshot is Dictionary or (snapshot as Dictionary).is_empty():
		snapshot = EffectSelectors.find(_engine.state(), EffectSelectors.run_source(run_ctx)).duplicate(true)
	_engine.state().effects.pending_choice = {
		CONT_EFFECT_ID: str(run_ctx.effect_id),
		CONT_SIDE: owner,
		CONT_KIND: kind,
		CONT_OPTIONS: options.duplicate(true),
		CONT_OP_INDEX: int(item.op_index),
		CONT_ITEM: item.duplicate(true),
		CONT_REMAINING_OPS: todo.duplicate(true),
		CONT_ENTRIES: entries.duplicate(true),
		CONT_RUN: run.duplicate(true),
		CONT_SOURCE_SNAPSHOT: snapshot,
		CONT_TAIL: _tail.duplicate(true),
	}
	return true


## The `choose` continuation (ADR-0007 Key Interfaces; C8.2): the engine calls
## it on `choose{option_index}` with [param choice] (its `ChoiceRequest`)
## after `choice_made`, under the paused step's `cause_seq`. Takes the
## continuation out of `EffectRuntime.pending_choice`, emits `discover_picked
## {side, picked_index, picked_card_id | picked_label_key}`, applies the pick
## ([method _apply_pick]: `then` for Discover, the option's `ops` inline for
## Choose One), continues the same effect from the next work item, emits its
## one `effect_resolved`, then runs the play runs still owed (the host's later
## effects of the same play point). Any of these may raise the next request:
## the pass suspends again the same way (a `repeat` around a `discover` makes
## sequential choices, C8.4). Draws nothing itself. Without a continuation
## (a resolver defect) it logs an error and does nothing.
## Example: the engine's `_resolver.resume(choice, option_index)`.
func resume(choice: Variant, option_index: int) -> void:
	assert(_engine != null, "EffectResolver.resume: not bound to an engine")
	var runtime: Dictionary = _engine.state().effects
	var cont: Variant = runtime.get("pending_choice")
	if not cont is Dictionary:
		push_error("EffectResolver.resume: no continuation pending (card-effects C8)")
		return
	runtime.pending_choice = null
	var pending: Dictionary = cont
	assert(not choice is Dictionary or str((choice as Dictionary).get("effect_id", "")) == str(pending[CONT_EFFECT_ID]), "EffectResolver.resume: the ChoiceRequest is not this continuation's")
	var run_ctx: Dictionary = (pending[CONT_RUN] as Dictionary).duplicate(true)
	run_ctx["effect"] = run_ctx[RUN_HOST_EFFECT] if run_ctx.has(RUN_HOST_EFFECT) else effects_of(str(run_ctx.host_id))[int(run_ctx[RUN_EFFECT_INDEX])]
	run_ctx["resolver"] = self
	_depth = int(run_ctx.get(ENTRY_DEPTH, 0))
	var entries: Array[Dictionary] = []
	entries.assign(pending[CONT_ENTRIES])
	var todo: Array[Dictionary] = []
	todo.assign(pending[CONT_REMAINING_OPS])
	var tail: Array[Dictionary] = []
	tail.assign(pending[CONT_TAIL])
	_tail = tail
	var engine: RulesEngine = _engine
	if run_ctx.source_id is String:
		engine.set_event_source(run_ctx.source_id)
	_apply_pick(pending, option_index, run_ctx, entries, todo)
	engine.set_event_source(null)
	if _engine != null and _continue_pass(run_ctx, entries, todo, null):
		while not tail.is_empty():
			if not _run_play_from(tail.pop_front()):
				break
	_tail = []
	_depth = 0


## The pick of [param pending] at [param index] (C8.2; C5 `discover.then`):
## `discover_picked`, then
## - Choose One: one `choose_one` entry `{picked_index, label_key}` and the
##   option's `ops` at the front of [param todo] (they run inline, before the
##   effect's next op);
## - Discover `then: add_to_hand` (default): `add_card_to_hand(side, id)` —
##   `burned` on a full hand (still a pick, Edge Cases); `then: summon`:
##   `summon_minion(side, id, end)` — `board_full` when full; `then: cast`:
##   the picked spell's `cast` effects run as passes of their own once this
##   pass has resolved (passes never nest; v1 content has no `then: cast`);
## - a pick from the owner's deck or hand would have to move that instance:
##   no primitive does yet, so it is `skipped` with `values.unsupported`.
func _apply_pick(pending: Dictionary, index: int, run_ctx: Dictionary, entries: Array[Dictionary], todo: Array[Dictionary]) -> void:
	var side: String = str(pending[CONT_SIDE])
	var item: Dictionary = pending[CONT_ITEM]
	var op: Dictionary = item.op
	var options: Array = pending[CONT_OPTIONS]
	var picked: Dictionary = {"side": side, "picked_index": index}
	var targets: Array[int] = []
	var outcome: String = EffectOps.APPLIED
	var values: Dictionary = {}
	if str(pending[CONT_KIND]) == ChoiceRequest.KIND_CHOOSE_ONE:
		var option: Dictionary = options[index]
		picked["picked_label_key"] = str(option.get("label_key", ""))
		@warning_ignore("return_value_discarded")
		_engine.emit(EVENT_DISCOVER_PICKED, picked)
		if _engine == null:
			return
		values = {"picked_index": index, "label_key": str(option.get("label_key", ""))}
		var inline: Array[Dictionary] = EffectOps.work(option.get("ops", []), item.condition, false, int(item.op_index))
		inline.append_array(todo)
		todo.assign(inline)
	else:
		var def_id: String = str(options[index])
		picked["picked_card_id"] = def_id
		@warning_ignore("return_value_discarded")
		_engine.emit(EVENT_DISCOVER_PICKED, picked)
		if _engine == null:
			return
		var then: String = str(op.get("then", EffectOps.THEN_ADD_TO_HAND))
		values = {"pool": str(op.get("pool", "")), "options": options.duplicate(), "picked": def_id, "then": then, "side": side}
		if EffectOps.INSTANCE_POOLS.has(str(op.get("pool", ""))):
			values["unsupported"] = EffectOps.UNSUPPORTED_INSTANCE_PICK
			outcome = EffectOps.SKIPPED
		else:
			match then:
				EffectOps.THEN_SUMMON:
					if (_engine.state().players[side].board as Array).size() >= _engine.rule("board_size"):
						outcome = EffectOps.BOARD_FULL
					var id: int = _engine.summon_minion(side, def_id, EffectOps.POSITION_END)
					if id != RulesEngine.NO_ENTITY:
						targets.append(id)
				EffectOps.THEN_CAST:
					_tail.push_front({
						PLAY_TRIGGER: TRIGGER_CAST, PLAY_HOST: def_id, PLAY_SOURCE: int(run_ctx.source_id),
						PLAY_SIDE: side, PLAY_TARGET: null, PLAY_NEXT: 0,
					})
				_:
					outcome = EffectOps.hand_add_outcome(_engine, side)
					@warning_ignore("return_value_discarded")
					_engine.add_card_to_hand(side, def_id)
	var picked_entry: Dictionary = EffectOps.entry(str(op.get("op", "")), targets, values, outcome)
	EffectOps.tag_condition(picked_entry, item)
	entries.append(picked_entry)


## C4 condition, evaluated once when the pass starts (C1): `cmp`, `exists`,
## `test`, `holding`, `is_owner_turn`, `all` / `any` / `not` through
## `EffectValues.holds` (story 007). Absent or `{}` is true.
func _condition_holds(condition: Variant, run_ctx: Dictionary) -> bool:
	return EffectValues.holds(condition, run_ctx)


## The memo entry of [param def_id], built on first use. `has()` before the
## typed lookup (an unknown id is not an error — card-database story 006); a
## `power_` id (CR-2, `RecordSchemas`) is a HeroPowerDef, anything else a
## CardDef.
func _memo_entry(def_id: String) -> Dictionary:
	if not _memo.has(def_id):
		var def: Variant = null
		if _db.has(def_id):
			var power_prefix: String = str(RecordSchemas.SCHEMAS[HERO_POWER_RECORD].prefix)
			def = _db.hero_power(def_id) if def_id.begins_with(power_prefix) else _db.card(def_id)
		var record: Dictionary = def if def is Dictionary else {}
		var effects: Array = []
		if record.get(MEMO_EFFECTS) is Array:
			effects = record[MEMO_EFFECTS]
		_memo[def_id] = {
			MEMO_EFFECTS: effects,
			MEMO_RECORD: record,
			MEMO_TARGETING: EffectValidator.derive_targeting_spec(effects),
		}
	return _memo[def_id]
