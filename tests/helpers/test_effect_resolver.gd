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
##   [member specs_by_def]; `recompute_auras()` counts calls and runs
##   [member aura_scripts]; `resume` records its arguments.
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
## Every evaluator call, in order: `{kind: "fold" | "run", effect_id, side, input, output}`.
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


## ADR-0007 Decision 2: store the engine, install [param installers] in order
## through the engine's registry, register the evaluators.
func bind(bound_engine: RulesEngine, installers: Array) -> void:
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


## Records the call, runs the scripted Callables for [param point], returns
## the scripted queued triggers.
func resolve(point: StringName, ctx: Dictionary) -> Array[Dictionary]:
	resolve_calls.append({"point": point, "ctx": ctx.duplicate(true)})
	for script: Callable in scripts.get(point, []):
		script.call(engine, ctx)
	var out: Array[Dictionary] = []
	out.assign(queued.get(point, []))
	return out


## `ctx.candidates` of every recorded `resolve` call on [param point], in call order.
func candidates_for(point: StringName) -> Array:
	var found: Array = []
	for call: Dictionary in resolve_calls:
		if call.point == point:
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


## Counts the call and runs [member aura_scripts].
func recompute_auras() -> void:
	aura_recomputes += 1
	for script: Callable in aura_scripts:
		script.call(engine)


## Records the `choose` continuation call.
func resume(choice: Variant, option_index: int) -> void:
	resume_calls.append({"choice": choice, "option_index": option_index})


## One fold step (ADR-0005 `set_evaluators` shape): [param value] through the
## entry's `modify_value` ops when [param side] is in scope; no clamp.
func apply_value_hook(entry: Dictionary, side: StringName, value: int, _ctx: Dictionary) -> int:
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
	hook_calls.append({"kind": "fold", "effect_id": entry.effect_id, "side": side, "input": value, "output": output})
	return output


## One trigger-hook step: runs [member hook_scripts]`[entry.effect_id]` when
## [param side] is in scope.
func run_hook_effect(entry: Dictionary, side: StringName, ctx: Dictionary) -> void:
	var ran: bool = _in_scope(entry, side) and hook_scripts.has(entry.effect_id)
	hook_calls.append({"kind": "run", "effect_id": entry.effect_id, "side": side, "input": ran, "output": null})
	if ran:
		(hook_scripts[entry.effect_id] as Callable).call(engine, entry, side, ctx)


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
