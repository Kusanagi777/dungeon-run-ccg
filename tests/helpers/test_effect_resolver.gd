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


## Registers an event-trigger responder: entity [param source_id] responds to
## trigger point [param point] (when [param guard], called `(engine, ctx)`,
## is unset or answers true) with effect [param effect_id], whose pass is
## [param pass_script] `(engine, ctx)` (unset: a pass that does nothing).
## [codeblock]
## resolver.add_trigger(&"on_damage", id, "m.0", draw_one, resolver.subject_is.bind(id))
## [/codeblock]
func add_trigger(point: StringName, source_id: int, effect_id: String, pass_script: Callable = Callable(), guard: Callable = Callable()) -> void:
	triggers.append({"point": point, "source_id": source_id, "effect_id": effect_id, "run": pass_script, "guard": guard})


## `guard` helper: true when `ctx.subject` is [param entity_id] (bind it).
func subject_is(_engine: RulesEngine, ctx: Dictionary, entity_id: int) -> bool:
	return ctx.get("subject") == entity_id


## Fixture Deathrattle (C10 summons): when [param source_id] dies, summon
## [param count] × [param def_id] for its controller at its former index
## (`ctx.snapshot.position`) — the engine clamps a past-the-end index to the
## rightmost slot and a full board answers `summon_failed`.
func add_deathrattle_summon(source_id: int, def_id: String, count: int = 1) -> void:
	add_trigger(&"deathrattle", source_id, "dr_summon.%d" % source_id, _summon_from_snapshot.bind(def_id, count))


## AC-30 fixture: each of [param first_id] and [param second_id] has
## "whenever the other friendly minion is healed, heal this one for 1". A
## full-health heal restores 0 and still emits `healed` (C9), so the pair
## ping-pongs forever — one queued step per heal — until the step cap.
func add_heal_ping_pong(first_id: int, second_id: int) -> void:
	add_trigger(&"on_heal", first_id, "ping.%d" % first_id, _heal_one.bind(first_id), subject_is.bind(second_id))
	add_trigger(&"on_heal", second_id, "ping.%d" % second_id, _heal_one.bind(second_id), subject_is.bind(first_id))


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
	resolve_calls.append({"point": point, "ctx": ctx.duplicate(true)})
	var out: Array[Dictionary] = []
	if ctx.get(RulesEngine.CTX_QUEUED, false):
		passes.append({"point": point, "ctx": ctx.duplicate(true)})
		for trigger: Dictionary in triggers:
			if trigger.effect_id == str(ctx.get("effect_id", "")) and (trigger.run as Callable).is_valid():
				(trigger.run as Callable).call(engine, ctx)
				break
		return out
	for script: Callable in scripts.get(point, []):
		script.call(engine, ctx)
	out.assign(queued.get(point, []))
	for candidate: Variant in ctx.get("candidates", []):
		for trigger: Dictionary in triggers:
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
			if aura == null:
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


func _summon_from_snapshot(bound_engine: RulesEngine, ctx: Dictionary, def_id: String, count: int) -> void:
	var snapshot: Dictionary = ctx.snapshot
	for _i: int in count:
		@warning_ignore("return_value_discarded")
		bound_engine.summon_minion(str(snapshot.controller), def_id, int(snapshot.position))


func _heal_one(bound_engine: RulesEngine, _ctx: Dictionary, entity_id: int) -> void:
	@warning_ignore("return_value_discarded")
	bound_engine.apply_heal(entity_id, 1, entity_id)


## Records the `choose` continuation call.
func resume(choice: Variant, option_index: int) -> void:
	resume_calls.append({"choice": choice, "option_index": option_index})


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
	hook_calls.append(_hook_call("fold", entry, side, value, output, ctx))
	return output


## One trigger-hook step: runs [member hook_scripts]`[entry.effect_id]` when
## [param side] is in scope.
func run_hook_effect(entry: Dictionary, side: StringName, ctx: Dictionary) -> void:
	var ran: bool = _in_scope(entry, side) and hook_scripts.has(entry.effect_id)
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
