## Scripted `EffectResolver` double (ADR-0007 Key Interfaces; match-rules
## story 003). Match Rules must be testable without Card Effects (ADR-0007
## Alt 1), so the rules suites bind this instead of the real resolver.
##
## It has the ADR-0007 surface and nothing it does is hidden:
## - `bind(engine, installers)` installs every installer through
##   `engine.state().hooks.install` in the order given and registers its own
##   bound methods [method apply_value_hook] / [method run_hook_effect] as the
##   registry's evaluators. It emits nothing: a duplicate `host_id` is the
##   **engine's** `hook_install_skipped` (ADR-0005). The engine is kept in the
##   plain field [member engine] so a teardown test can watch the cycle break.
## - `resolve(point, ctx)` records `{point, ctx}` in [member resolve_calls]
##   (`ctx.candidates` included — story 005 asserts the engine's candidate
##   order from here), then runs the Callables a test put in
##   [member scripts]`[point]`, each as `callable.call(engine, ctx)`; it returns
##   the triggers listed in [member queued]`[point]` (ADR-0007 erratum: resolve
##   returns the triggers it queues), `[]` by default.
## - `apply_value_hook` applies the entry's card-effects C5 `modify_value` ops
##   (`delta` adds, `set` replaces, `mul` multiplies — no clamp) when the fold's
##   `side` is in the entry's scope; `run_hook_effect` runs
##   [member hook_scripts]`[effect_id]` as `callable.call(engine, entry, side,
##   ctx)` under the same scope test. Every call is recorded.
## - Scope (ADR-0005 rule 3: relative to `entry.side`): `effect.scope.side` is
##   `"friendly"` (the default — the fold side equals `entry.side`), `"enemy"`
##   or `"any"`.
## - `legal_targets` / `targeting_spec` answer from [member targets_by_def] /
##   [member specs_by_def]; `recompute_auras()` counts calls, re-applies the
##   fixture [member auras] and runs [member aura_scripts]; `resume` records
##   its arguments.
## - **Event triggers** (match-rules story 009, the C10 queue): a test
##   registers responders with [method add_trigger] — `{point, source_id,
##   effect_id, run, guard}`. A *collecting* `resolve(point, ctx)` walks
##   `ctx.candidates` in engine order and, per candidate, the registered
##   triggers in registration order (the resolver orders only within one
##   entity), and returns one queue entry `{source_id, effect_id}` for each
##   whose `guard` (if set) answers true. When the engine pops that entry it
##   calls `resolve(point, ctx)` again with `ctx[RulesEngine.CTX_QUEUED] =
##   true`: the double records it in [member passes] and runs the trigger's
##   `run` as `run.call(engine, ctx)` — one effect pass, one C10 step.
##   Fixture builders: [method add_deathrattle_summon], [method
##   add_heal_ping_pong] (AC-30), [member auras].
## - **Silence** (match-rules story 015): a candidate whose record (or, for a
##   Deathrattle, raise-time snapshot) is `silenced` answers no registered
##   trigger, and a silenced [member auras] source emits nothing — so "no
##   Deathrattle after Silence" is observable with no Card Effects code.
##
## Scripts are bound methods or lambdas that capture nothing mutable (lambdas
## capture locals by value — current-best-practices "GDScript (4.5+)").
## [codeblock]
## var resolver := TestEffectResolver.new()
## resolver.hook_scripts["crown.0"] = func(e: RulesEngine, _entry: Dictionary, s: StringName, _c: Dictionary) -> void:
##         e.add_mana(String(s), 1, false)
## var engine: RulesEngine = MatchFactory.make_started_engine(rng, log, {}, {}, resolver)
## resolver.candidates_for(&"turn_start")   # [[ids…], …] one Array per resolve call
## [/codeblock]
class_name TestEffectResolver
extends RefCounted

## Scope side values of a scripted hook effect (`effect.scope.side`).
const SCOPE_FRIENDLY: String = "friendly"
const SCOPE_ENEMY: String = "enemy"
const SCOPE_ANY: String = "any"
## The card-effects C5 op a value hook carries.
const OP_MODIFY_VALUE: String = "modify_value"
## `targeting_spec` for a def with no scripted spec (card-effects C1: no `chosen`).
const DEFAULT_TARGETING_SPEC: Dictionary = {"mode": "none", "filter": {}}

## The bound engine; null before [method bind] and after [method unbind].
## A plain field on purpose (story 003 Engine Notes: the card-effects teardown
## test observes `weakref(engine).get_ref() == null` after unbind).
var engine: RulesEngine = null
## Every `bind` call: `{installers: Array}` (the installers as passed).
var bind_calls: Array[Dictionary] = []
## Number of [method unbind] calls.
var unbind_count: int = 0
## `point → Array[Callable]`, each called `(engine, ctx)` by [method resolve].
var scripts: Dictionary = {}
## `point → Array[Dictionary]`, the triggers [method resolve] returns.
var queued: Dictionary = {}
## Every `resolve` call, in order: `{point: StringName, ctx: Dictionary}` (a deep copy).
var resolve_calls: Array[Dictionary] = []
## `effect_id → Callable`, called `(engine, entry, side, ctx)` by [method run_hook_effect].
var hook_scripts: Dictionary = {}
## Every evaluator call, in order: `{kind: "fold" | "run", point, effect_id,
## side, input, output, ctx}` — `point` is the entry's hook point, `ctx` a
## copy of the context the engine passed (match-rules story 007: a fold's
## per-entry inputs show whether anything clamped between entries).
var hook_calls: Array[Dictionary] = []
## `def_id → Array[int]` answered by [method legal_targets].
var targets_by_def: Dictionary = {}
## `def_id → Dictionary` answered by [method targeting_spec].
var specs_by_def: Dictionary = {}
## Callables `(engine)` run by every [method recompute_auras] call.
var aura_scripts: Array[Callable] = []
## Number of [method recompute_auras] calls.
var aura_recomputes: int = 0
## Every `resume` call: `{choice, option_index}`.
var resume_calls: Array[Dictionary] = []
## Optional `choose` continuation (match-rules story 016), called
## `(engine, choice, option_index)` by [method resume] after recording: a test
## that scripts a Discover puts the rest of its effect here (e.g.
## `add_card_to_hand` of the pick, then the effect's later ops). Unset: resume
## only records, as before.
var resume_script: Callable = Callable()
## Registered event-trigger responders, in registration order:
## `{point: StringName, source_id: int, effect_id: String, run: Callable,
## guard: Callable}` (see [method add_trigger]).
var triggers: Array[Dictionary] = []
## Every queued pass the engine executed, in order: `{point, ctx}` (a deep
## copy, so `ctx.snapshot` is the raise-time snapshot the engine carried).
var passes: Array[Dictionary] = []
## Fixture auras (C10 `recompute_auras`): `entity_id → {attack_delta,
## health_delta}` — each living source buffs every **other** minion on its
## own board, sources in board order, player side first.
var auras: Dictionary = {}
## The double [method clone_unbound] last built (match-rules story 017), as a
## weak reference so the live double never keeps a clone alive; null before.
var last_clone: WeakRef = null
## Whether the double records its calls ([member resolve_calls],
## [member passes], [member hook_calls] — each a deep copy of the context).
## `true` by default, as before; the match-rules story 018 timing suite sets
## it `false` so a measured `submit` / fold pays for the engine and the
## scripted effects, not for the double's own bookkeeping (the production
## resolver records nothing). Copied by [method clone_unbound].
var recording: bool = true

# Lookup index over [member triggers] (story 018): `source_id → [trigger…]`
# in registration order and `effect_id → first trigger`. It only speeds up
# [method resolve] — same answers, same order — and is used only while it
# covers every entry ([member _indexed] equals `triggers.size()`); a test that
# edits [member triggers] directly gets the linear scan, as before.
var _by_source: Dictionary = {}
var _by_effect: Dictionary = {}
var _indexed: int = 0


## Registers an event-trigger responder: entity [param source_id] responds to
## trigger point [param point] (when [param guard], called `(engine, ctx)`,
## is unset or answers true) with effect [param effect_id], whose pass is
## [param pass_script] `(engine, ctx)` (unset: a pass that does nothing).
## [codeblock]
## resolver.add_trigger(&"on_damage", id, "m.0", draw_one, resolver.subject_is.bind(id))
## [/codeblock]
func add_trigger(point: StringName, source_id: int, effect_id: String, pass_script: Callable = Callable(), guard: Callable = Callable()) -> void:
	var trigger: Dictionary = {"point": point, "source_id": source_id, "effect_id": effect_id, "run": pass_script, "guard": guard}
	var was_indexed: bool = _indexed == triggers.size()
	triggers.append(trigger)
	if was_indexed:
		_index(trigger)


## `guard` helper: true when `ctx.subject` is [param entity_id] (bind it).
func subject_is(_engine: RulesEngine, ctx: Dictionary, entity_id: int) -> bool:
	return ctx.get("subject") == entity_id


## Fixture Deathrattle (C10 summons): when [param source_id] dies, summon
## [param count] × [param def_id] for its controller at its former index
## (`ctx.snapshot.position`) — the engine clamps a past-the-end index to the
## rightmost slot and a full board answers `summon_failed`.
func add_deathrattle_summon(source_id: int, def_id: String, count: int = 1) -> void:
	add_trigger(&"deathrattle", source_id, "dr_summon.%d" % source_id, _summon_from_snapshot.bind(def_id, count))


## Fixture Deathrattle chain (match-rules story 018, AC-40 worst case): when
## [param source_id] dies its Deathrattle (a) summons one [param def_id] for
## its controller at its former index, carrying this same Deathrattle with
## [param generations] − 1 (none is summoned at 0 — the chain is finite), then
## (b) deals [param damage] to every minion on both boards (the new token
## included, so a 1-health token dies in the next death check and its own
## Deathrattle queues). One host therefore resolves `generations + 1`
## Deathrattle passes; seven hosts of generation 7 resolve 56. Registered on
## whichever double runs the pass, so a clone's chain grows on the clone's
## double only.
func add_deathrattle_chain(source_id: int, def_id: String, generations: int, damage: int) -> void:
	add_trigger(&"deathrattle", source_id, "dr_chain.%d" % source_id, _chain_link.bind(def_id, generations, damage))


## AC-30 fixture: each of [param first_id] and [param second_id] has
## "whenever the other friendly minion is healed, heal this one for 1". A
## full-health heal restores 0 and still emits `healed` (C9), so the pair
## ping-pongs forever — one queued step per heal — until the step cap.
func add_heal_ping_pong(first_id: int, second_id: int) -> void:
	add_trigger(&"on_heal", first_id, "ping.%d" % first_id, _heal_one.bind(first_id), subject_is.bind(second_id))
	add_trigger(&"on_heal", second_id, "ping.%d" % second_id, _heal_one.bind(second_id), subject_is.bind(first_id))


## `guard` helper: true when `ctx.attacker` is [param entity_id] (bind it) —
## an `on_attack` responder that answers only its own host's attacks.
func attacker_is(_engine: RulesEngine, ctx: Dictionary, entity_id: int) -> bool:
	return ctx.get("attacker") == entity_id


## Fixture `on_attack` responder (match-rules story 013, AC-21): when
## [param attacker_id] attacks, its trigger destroys [param victim_id] — one
## queued pass, so the victim leaves play in that step's death check, before
## the engine's re-check.
func add_on_attack_destroy(attacker_id: int, victim_id: int) -> void:
	add_trigger(&"on_attack", attacker_id, "oa_destroy.%d" % attacker_id, _destroy_one.bind(victim_id), attacker_is.bind(attacker_id))


## Fixture `on_attack` responder (match-rules story 013, AC-21): when
## [param attacker_id] attacks, its trigger summons [param def_id] for
## [param side] at the rightmost slot (a Taunt summoned mid-attack must not
## redirect it).
func add_on_attack_summon(attacker_id: int, side: String, def_id: String) -> void:
	add_trigger(&"on_attack", attacker_id, "oa_summon.%d" % attacker_id, _summon_rightmost.bind(side, def_id), attacker_is.bind(attacker_id))


## ADR-0007 Decision 2: store the engine, install [param installers] in order
## through the engine's registry, register the evaluators.
## Typed as ADR-0007's real `bind`, so a caller passing a plain Array fails
## here the way it would against `EffectResolver` (code review 2026-11-03).
func bind(bound_engine: RulesEngine, installers: Array[HookInstaller]) -> void:
	engine = bound_engine
	bind_calls.append({"installers": installers.duplicate()})
	var hooks: HookRegistry = engine.state().hooks
	for installer: HookInstaller in installers:
		@warning_ignore("return_value_discarded")
		hooks.install(installer)
	hooks.set_evaluators(apply_value_hook, run_hook_effect)


## ADR-0007 Decision 2: clear the registry's evaluators and the engine reference.
func unbind() -> void:
	unbind_count += 1
	if engine != null and engine.state() != null and engine.state().hooks != null:
		engine.state().hooks.set_evaluators(Callable(), Callable())
	engine = null


## Records the call. For a queued pass (`ctx[RulesEngine.CTX_QUEUED]`) runs
## that trigger's `run` and returns `[]`; otherwise runs the scripted
## Callables for [param point] and returns the scripted [member queued]
## entries followed by the registered responders among `ctx.candidates`.
func resolve(point: StringName, ctx: Dictionary) -> Array[Dictionary]:
	if recording:
		resolve_calls.append({"point": point, "ctx": ctx.duplicate(true)})
	var out: Array[Dictionary] = []
	if ctx.get(RulesEngine.CTX_QUEUED, false):
		if recording:
			passes.append({"point": point, "ctx": ctx.duplicate(true)})
		var effect_id: String = str(ctx.get("effect_id", ""))
		var indexed: Variant = _by_effect.get(effect_id) if _indexed == triggers.size() else null
		if indexed != null and (indexed.run as Callable).is_valid():
			(indexed.run as Callable).call(engine, ctx)
			return out
		for trigger: Dictionary in triggers:
			if trigger.effect_id == effect_id and (trigger.run as Callable).is_valid():
				(trigger.run as Callable).call(engine, ctx)
				break
		return out
	for script: Callable in scripts.get(point, []):
		script.call(engine, ctx)
	out.assign(queued.get(point, []))
	var use_index: bool = _indexed == triggers.size()
	for candidate: Variant in ctx.get("candidates", []):
		if use_index and not _by_source.has(int(candidate)):
			continue   # no responder: nothing to answer, silenced or not
		if _silenced(ctx, int(candidate)):
			continue
		for trigger: Dictionary in (_by_source[int(candidate)] if use_index else triggers):
			if trigger.point != point or int(trigger.source_id) != int(candidate):
				continue
			var guard: Callable = trigger.guard
			if guard.is_valid() and not guard.call(engine, ctx):
				continue
			out.append({"source_id": int(candidate), "effect_id": str(trigger.effect_id)})
	return out


## The `effect_id` of every executed queued pass on [param point] (all points
## when empty), in execution order.
func pass_ids(point: StringName = &"") -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in passes:
		if point == &"" or entry.point == point:
			out.append(str(entry.ctx.effect_id))
	return out


## `ctx.candidates` of every recorded `resolve` call that fired trigger point
## [param point] (the engine executing a queued pass is not a fire), in call order.
func candidates_for(point: StringName) -> Array:
	var found: Array = []
	for call: Dictionary in resolve_calls:
		if call.point == point and not call.ctx.get(RulesEngine.CTX_QUEUED, false):
			found.append(call.ctx.get("candidates", []))
	return found


## The scripted legal targets of [param def_id] (`[]` when none).
func legal_targets(def_id: String, _source: Dictionary) -> Array[int]:
	var out: Array[int] = []
	out.assign(targets_by_def.get(def_id, []))
	return out


## The scripted targeting spec of [param def_id], else [constant DEFAULT_TARGETING_SPEC].
func targeting_spec(def_id: String) -> Dictionary:
	return specs_by_def.get(def_id, DEFAULT_TARGETING_SPEC)


## Counts the call, re-applies [member auras] (every living source in board
## order, player side first, through `apply_enchantment(…, is_aura = true)`
## — the engine stripped every aura enchantment first), then runs
## [member aura_scripts].
func recompute_auras() -> void:
	aura_recomputes += 1
	for side: String in MatchRecords.SIDES:
		var board: Array = engine.state().players[side].board
		for source: Dictionary in board:
			var aura: Variant = auras.get(int(source.entity_id))
			if aura == null or bool(source.get("silenced", false)):
				continue
			for other: Dictionary in board:
				if other.entity_id == source.entity_id:
					continue
				engine.apply_enchantment(int(other.entity_id), {
					"attack_delta": int(aura.get("attack_delta", 0)), "health_delta": int(aura.get("health_delta", 0)),
					"source_entity_id": int(source.entity_id), "is_aura": true,
				})
	for script: Callable in aura_scripts:
		script.call(engine)


## The fresh, unbound resolver `RulesEngine.clone()` binds to its clone
## (match-rules story 017; ADR-0007 Decision 3 — never the live resolver; the
## production engine builds `EffectResolver.new(db, effects_config)` instead).
## The scripted configuration is copied — [member scripts], [member queued],
## [member hook_scripts], [member targets_by_def], [member specs_by_def],
## [member aura_scripts], [member auras], [member triggers],
## [member resume_script] — so the clone resolves exactly as the live double
## would; every record ([member bind_calls], [member resolve_calls],
## [member hook_calls], [member passes], [member resume_calls], the counters)
## starts empty and [member engine] is null until `bind`. A trigger's `run` /
## `guard` that is a bound method of this double (the fixture builders) is
## rebound to the new double; a test suite's Callables are shared (they take
## the engine as their first argument). Recorded in [member last_clone].
## [codeblock]
## var sandbox: RulesEngine = engine.clone()
## var clone_resolver: TestEffectResolver = resolver.last_clone.get_ref()
## [/codeblock]
func clone_unbound() -> TestEffectResolver:
	var out: TestEffectResolver = TestEffectResolver.new()
	out.scripts = scripts.duplicate(true)
	out.queued = queued.duplicate(true)
	out.hook_scripts = hook_scripts.duplicate()
	out.targets_by_def = targets_by_def.duplicate(true)
	out.specs_by_def = specs_by_def.duplicate(true)
	out.aura_scripts = aura_scripts.duplicate()
	out.auras = auras.duplicate(true)
	out.resume_script = resume_script
	out.recording = recording
	for trigger: Dictionary in triggers:
		var copy: Dictionary = trigger.duplicate()
		copy.run = _rebound(trigger.run, out)
		copy.guard = _rebound(trigger.guard, out)
		out.triggers.append(copy)
		out._index(copy)
	last_clone = weakref(out)
	return out


## Adds [param trigger] (the last entry of [member triggers]) to the index.
func _index(trigger: Dictionary) -> void:
	var source_id: int = int(trigger.source_id)
	if not _by_source.has(source_id):
		_by_source[source_id] = []
	(_by_source[source_id] as Array).append(trigger)
	if not _by_effect.has(str(trigger.effect_id)):
		_by_effect[str(trigger.effect_id)] = trigger
	_indexed += 1


## [param callable] re-targeted at [param target] when it is one of this
## double's own (bound) methods, else [param callable] itself.
func _rebound(callable: Callable, target: TestEffectResolver) -> Callable:
	if not callable.is_valid() or callable.get_object() != self:
		return callable
	return Callable(target, callable.get_method()).bindv(callable.get_bound_arguments())


## Whether the candidate [param entity_id] is Silenced (match-rules story 015,
## C13 step 3: "Card Effects skips the definition's triggers for this
## entity"): read from `ctx.snapshot` when it is that entity's (a Deathrattle
## — the source has just left play), else from its live record. A silenced
## candidate answers no registered trigger; scripted [member queued] entries
## and [member scripts] are not entity triggers and still run.
func _silenced(ctx: Dictionary, entity_id: int) -> bool:
	var snapshot: Variant = ctx.get("snapshot")
	if snapshot is Dictionary and int((snapshot as Dictionary).get("entity_id", RulesEngine.NO_ENTITY)) == entity_id:
		return bool((snapshot as Dictionary).get("silenced", false))
	if engine == null or engine.state() == null:
		return false
	return bool(engine.state_snapshot(entity_id).get("silenced", false))


func _summon_from_snapshot(bound_engine: RulesEngine, ctx: Dictionary, def_id: String, count: int) -> void:
	var snapshot: Dictionary = ctx.snapshot
	for _i: int in count:
		@warning_ignore("return_value_discarded")
		bound_engine.summon_minion(str(snapshot.controller), def_id, int(snapshot.position))


func _chain_link(bound_engine: RulesEngine, ctx: Dictionary, def_id: String, generations: int, damage: int) -> void:
	var snapshot: Dictionary = ctx.snapshot
	if generations > 0:
		var token: int = bound_engine.summon_minion(str(snapshot.controller), def_id, int(snapshot.position))
		if token != RulesEngine.NO_ENTITY:
			add_deathrattle_chain(token, def_id, generations - 1, damage)
	var ids: Array[int] = []
	for side: String in MatchRecords.SIDES:
		for minion: Dictionary in bound_engine.state().players[side].board:
			ids.append(int(minion.entity_id))
	for id: int in ids:
		@warning_ignore("return_value_discarded")
		bound_engine.apply_damage(id, damage, null)


func _destroy_one(bound_engine: RulesEngine, _ctx: Dictionary, entity_id: int) -> void:
	bound_engine.destroy(entity_id)


func _summon_rightmost(bound_engine: RulesEngine, _ctx: Dictionary, side: String, def_id: String) -> void:
	@warning_ignore("return_value_discarded")
	bound_engine.summon_minion(side, def_id, bound_engine.state().players[side].board.size())


func _heal_one(bound_engine: RulesEngine, _ctx: Dictionary, entity_id: int) -> void:
	@warning_ignore("return_value_discarded")
	bound_engine.apply_heal(entity_id, 1, entity_id)


## Records the `choose` continuation call, then runs [member resume_script]
## when one is set.
func resume(choice: Variant, option_index: int) -> void:
	resume_calls.append({"choice": choice, "option_index": option_index})
	if resume_script.is_valid():
		resume_script.call(engine, choice, option_index)


## One fold step (ADR-0005 `set_evaluators` shape): [param value] through the
## entry's `modify_value` ops when [param side] is in scope; no clamp.
func apply_value_hook(entry: Dictionary, side: StringName, value: int, ctx: Dictionary) -> int:
	var output: int = value
	if _in_scope(entry, side):
		for op: Dictionary in entry.effect.get("ops", []):
			if str(op.get("op", "")) != OP_MODIFY_VALUE:
				continue
			if op.has("delta"):
				output += int(op.delta)
			elif op.has("set"):
				output = int(op.set)
			elif op.has("mul"):
				output *= int(op.mul)
	if recording:
		hook_calls.append(_hook_call("fold", entry, side, value, output, ctx))
	return output


## One trigger-hook step: runs [member hook_scripts]`[entry.effect_id]` when
## [param side] is in scope.
func run_hook_effect(entry: Dictionary, side: StringName, ctx: Dictionary) -> void:
	var ran: bool = _in_scope(entry, side) and hook_scripts.has(entry.effect_id)
	if recording:
		hook_calls.append(_hook_call("run", entry, side, ran, null, ctx))
	if ran:
		(hook_scripts[entry.effect_id] as Callable).call(engine, entry, side, ctx)


## The `input` of every fold call on value point [param point], in call
## order — one per entry per fold (match-rules story 007: `1, 0, −1` for a
## `delta −1` × 3 chain over a requested 1 shows no clamp between entries).
func fold_inputs(point: StringName) -> Array[int]:
	var out: Array[int] = []
	for call: Dictionary in hook_calls:
		if call.kind == "fold" and call.point == String(point):
			out.append(int(call.input))
	return out


## The `ctx` of every `run` call on trigger point [param point], in call order.
func run_contexts(point: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for call: Dictionary in hook_calls:
		if call.kind == "run" and call.point == String(point):
			out.append(call.ctx)
	return out


func _hook_call(kind: String, entry: Dictionary, side: StringName, input: Variant, output: Variant, ctx: Dictionary) -> Dictionary:
	return {
		"kind": kind, "point": str(entry.effect.get("trigger", "")), "effect_id": entry.effect_id,
		"side": side, "input": input, "output": output, "ctx": ctx.duplicate(true),
	}


func _in_scope(entry: Dictionary, side: StringName) -> bool:
	var scope: Variant = entry.effect.get("scope", {})
	var scope_side: String = SCOPE_FRIENDLY
	if scope is Dictionary:
		scope_side = str((scope as Dictionary).get("side", SCOPE_FRIENDLY))
	match scope_side:
		SCOPE_ANY:
			return true
		SCOPE_ENEMY:
			return String(side) != String(entry.side)
	return String(side) == String(entry.side)
