## The Card Effects resolver (design/gdd/card-effects.md C6.1, C6.8, C9,
## Tuning Knobs; ADR-0007 Decisions 2–4, Key Interfaces; ADR-0005
## `set_evaluators`).
##
## A `RefCounted` built once per match by the composition code
## (`MatchDriver`: `EffectResolver.new(db, db.config("card_effects"))`), handed
## to `RulesEngine._init`, and bound by `RulesEngine.start` at C3 step 1 —
## before `on_match_start`:
## - [method bind] keeps the engine, installs each `HookInstaller` through
##   `engine.state().hooks.install` in the order given (treasures in pick
##   order, then the boss passive; a refused duplicate is the **engine's**
##   `hook_install_skipped`), then registers the bound methods
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
## Every Tuning Knob is read from the injected config body (the `config` of
## `assets/data/card_effects.json`), never from a literal: [method knob],
## [method knob_int]; keys are [constant EffectValidator.CONFIG_KEYS].
## [codeblock]
## var resolver := EffectResolver.new(db, db.config("card_effects"))
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
## point?, snapshot?}` — the engine fills `snapshot`; the rest is the
## resolver's own plain data, read back by the queued pass).
const ENTRY_DEF_ID: String = "def_id"
const ENTRY_EFFECT_INDEX: String = "effect_index"
const ENTRY_OWNER: String = "owner"
const ENTRY_TRIGGER: String = "trigger"
const ENTRY_SUBJECT: String = "trigger_subject"
const ENTRY_TRIGGER_SOURCE: String = "trigger_source"
const ENTRY_AMOUNT: String = "amount"
const ENTRY_DEPTH: String = "depth"
## The resolver's own event, one per effect pass (card-effects C6.6).
const EVENT_EFFECT_RESOLVED: StringName = &"effect_resolved"
## `effect_resolved.host_kind` values (card-effects Interactions).
const HOST_KIND_CARD: String = "card"
const HOST_KIND_HERO_POWER: String = "hero_power"
## `effect_resolved.fizzled` for a false `condition` (C1).
const FIZZLED_CONDITION_FALSE: String = "condition_false"

var _db: CardDatabase
var _config: Dictionary
## The bound engine: set by [method bind], cleared by [method unbind].
var _engine: RulesEngine = null
## `def_id → {effects: Array, record: Dictionary, targeting_spec: Dictionary}`
## — derived from the definition, filled on first use (story 002's memo;
## story 004 adds the record and the memoised targeting spec).
var _memo: Dictionary[String, Dictionary] = {}
## The C5 op dispatch table (stateless; story 006).
var _ops: EffectOps = EffectOps.new()
## `effect_resolved.depth` of the pass running now (0 between passes): a
## trigger raised inside a pass queues with `depth + 1` (story 008). Passes
## never nest — a raise inside one only collects — so one field suffices.
var _depth: int = 0


## Keeps [param db] (the frozen `CardDatabase`; lookups by `card(def_id)`)
## and [param effects_config] (the frozen `card_effects` config body, read
## once here and kept as the same reference — never re-queried). In debug
## builds asserts the body's `hooks_before_triggers` is `true` (the knob
## exists only for this assertion; `EffectValidator.validate_config` rejects
## any other value at load).
func _init(db: CardDatabase, effects_config: Dictionary) -> void:
	_db = db
	_config = effects_config
	assert(_config.get(KNOB_HOOKS_BEFORE_TRIGGERS) == true, "card_effects.hooks_before_triggers must be true (card-effects Tuning Knobs)")


## Binds this resolver to [param engine] at `RulesEngine.start` (C3 step 1,
## after `state.hooks = HookRegistry.new()`, before `on_match_start`):
## installs [param installers] in order through the engine's registry, then
## registers [method apply_value_hook] and [method run_hook_effect] as its
## evaluators. A refused installer (duplicate `host_id`) is left for the
## engine to log. Example: see the class description.
func bind(engine: RulesEngine, installers: Array[HookInstaller]) -> void:
	assert(_engine == null, "EffectResolver.bind: already bound (one resolver per engine; a clone binds a fresh one)")
	_engine = engine
	var hooks: HookRegistry = engine.state().hooks
	for installer: HookInstaller in installers:
		@warning_ignore("return_value_discarded")
		hooks.install(installer)
	hooks.set_evaluators(apply_value_hook, run_hook_effect)


## Releases the engine: clears the registry's evaluators and the engine
## reference. A no-op when not bound. Example: `resolver.unbind()`.
func unbind() -> void:
	if _engine == null:
		return
	var state: MatchState = _engine.state()
	if state != null and state.hooks != null:
		state.hooks.set_evaluators(Callable(), Callable())
	_engine = null


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
## as one queue entry (`{source_id, effect_id, def_id, effect_index, owner,
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


## The engine's C10 loop calls this once per step (match-rules C10; the End
## step too). Story 012 recomputes auras; until then there are none to
## recompute. Example: `resolver.recompute_auras()`.
func recompute_auras() -> void:
	pass


## One value-hook fold step (ADR-0005 `set_evaluators` shape; card-effects
## C9). Story 014 applies the entry's `modify_value` ops; until then the
## value passes through unchanged.
func apply_value_hook(_entry: Dictionary, _side: StringName, value: int, _ctx: Dictionary) -> int:
	return value


## One trigger-hook step at a hook point (card-effects C9). Story 015 runs
## the entry's effect as one pass; until then it does nothing.
func run_hook_effect(_entry: Dictionary, _side: StringName, _ctx: Dictionary) -> void:
	pass


## Runs every effect of the host `ctx.card_id` whose trigger is
## [param trigger] now, in `effects[]` order (C1 rule 3, C6.2).
func _run_play_point(trigger: String, ctx: Dictionary) -> void:
	assert(_engine != null, "EffectResolver.resolve: not bound to an engine")
	var host_id: String = str(ctx.card_id)
	var power_prefix: String = str(RecordSchemas.SCHEMAS[HERO_POWER_RECORD].prefix)
	var host_kind: String = HOST_KIND_HERO_POWER if host_id.begins_with(power_prefix) else HOST_KIND_CARD
	var effects: Array = effects_of(host_id)
	for index: int in effects.size():
		var effect: Dictionary = effects[index]
		if str(effect.get("trigger", "")) != trigger:
			continue
		_run_pass(effect, {
			"effect_id": str(effect.get("id", "%s.%d" % [host_id, index])),
			"host_id": host_id,
			"host_kind": host_kind,
			"source_id": int(ctx.source),
			"owner": str(ctx.side),
			"trigger": trigger,
			"target_id": ctx.get("target_id"),
		})


## C6.2 "who responds" for event point [param point]: the queue entries of
## every candidate effect that responds, in candidate order, then
## `effects[]` order within one candidate (definition effects; the
## enchantment-granted ones after them arrive with story 012). The engine
## decides candidates and their order; this never re-sorts them.
func _collect(point: StringName, ctx: Dictionary) -> Array[Dictionary]:
	assert(_engine != null, "EffectResolver.resolve: not bound to an engine")
	var queued: Array[Dictionary] = []
	var triggers: Array = EVENT_TRIGGERS[point]
	var subject: Variant = ctx.get("subject")
	for candidate: Variant in ctx.get("candidates", []):
		var source_id: int = int(candidate)
		if ENTRY_POINTS.has(point) and subject != null and int(subject) == source_id:
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
			queued.append(_queue_entry(point, ctx, source_id, def_id, index, effect, str(host.owner), trigger))
	return queued


## The candidate's host `{def_id, owner}`, or `{}` when it cannot respond:
## a Silenced source responds to nothing (C6.2; story 009 keeps a trigger
## already queued). A Deathrattle's candidate has just left play, so it is
## read from the death snapshot `ctx.snapshot` (match-rules C10); every other
## candidate is a minion or weapon in play. Heroes host no definition
## effects (hero-slot observers — hero power, treasures, passive — are story
## 015).
func _candidate_host(point: StringName, source_id: int, ctx: Dictionary) -> Dictionary:
	var record: Dictionary = {}
	var owner: String = ""
	if point == &"deathrattle":
		var snapshot: Variant = ctx.get("snapshot")
		if snapshot is Dictionary and int((snapshot as Dictionary).get("entity_id", -1)) == source_id:
			record = snapshot
			owner = str(record.get("controller", ctx.get("side", "")))
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
## Silence are checked by the caller. TODO(story 009): the `once_per_turn`
## mark (C6.7) — until marks exist every occurrence responds.
func _responds(trigger: String, effect: Dictionary, ctx: Dictionary, source_id: int, owner: String) -> bool:
	return EffectScope.matches(self, trigger, effect.get("scope"), ctx, source_id, owner)


## One queue entry (ADR-0007 erratum shape plus this resolver's fields):
## plain data only — the engine copies it into Q and back into `ctx`.
## `trigger_subject` is the card instance for `on_card_played` (C2), the
## defender for `on_attack`, else `ctx.subject`; `trigger_source` is the
## damager / healer (`ctx.source`) or the attacker.
func _queue_entry(point: StringName, ctx: Dictionary, source_id: int, def_id: String, index: int, effect: Dictionary, owner: String, trigger: String) -> Dictionary:
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
	return {
		"source_id": source_id,
		"effect_id": str(effect.get("id", "%s.%d" % [def_id, index])),
		ENTRY_DEF_ID: def_id,
		ENTRY_EFFECT_INDEX: index,
		ENTRY_OWNER: owner,
		ENTRY_TRIGGER: trigger,
		ENTRY_SUBJECT: subject,
		ENTRY_TRIGGER_SOURCE: trigger_source,
		ENTRY_AMOUNT: ctx.get("amount"),
		ENTRY_DEPTH: _depth + 1,
	}


## The engine popped one of this resolver's queue entries (`ctx` is the
## entry plus the engine's `snapshot` and `queued`): run that effect as one
## pass, whether or not its source is still in play (C6.5: queued = earned).
## The engine emitted `trigger_resolved` first; this pass runs under it.
func _run_queued(ctx: Dictionary) -> void:
	assert(_engine != null, "EffectResolver.resolve: not bound to an engine")
	var def_id: String = str(ctx.get(ENTRY_DEF_ID, ""))
	var effects: Array = effects_of(def_id)
	var index: int = int(ctx.get(ENTRY_EFFECT_INDEX, -1))
	assert(index >= 0 and index < effects.size(), "EffectResolver: queued entry %s names no effect of %s" % [ctx.get("effect_id"), def_id])
	if index < 0 or index >= effects.size():
		return
	_run_pass(effects[index], {
		"effect_id": str(ctx.effect_id),
		"host_id": def_id,
		"host_kind": HOST_KIND_CARD,
		"source_id": int(ctx.source_id),
		"owner": str(ctx.get(ENTRY_OWNER, "")),
		"trigger": str(ctx.get(ENTRY_TRIGGER, "")),
		"target_id": null,
		ENTRY_SUBJECT: ctx.get(ENTRY_SUBJECT),
		ENTRY_TRIGGER_SOURCE: ctx.get(ENTRY_TRIGGER_SOURCE),
		ENTRY_AMOUNT: ctx.get(ENTRY_AMOUNT),
		ENTRY_DEPTH: int(ctx.get(ENTRY_DEPTH, 1)),
		"snapshot": ctx.get("snapshot", {}),
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
func _run_pass(effect: Dictionary, run_ctx: Dictionary) -> void:
	run_ctx["effect"] = effect
	run_ctx["resolver"] = self
	_depth = int(run_ctx.get(ENTRY_DEPTH, 0))
	var fizzled: Variant = null
	var ops: Array[Dictionary] = []
	if _condition_holds(effect.get("condition"), run_ctx):
		for op: Dictionary in effect.get("ops", []):
			ops.append_array(_ops.run_all(_engine, op, run_ctx))
	else:
		fizzled = FIZZLED_CONDITION_FALSE
		for op: Dictionary in effect.get("ops", []):
			var none: Array[int] = []
			ops.append(EffectOps.entry(str(op.get("op", "")), none, {}, EffectOps.SKIPPED))
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
		"ops": ops,
	})
	_depth = 0


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
