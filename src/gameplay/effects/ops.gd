## The C5 operations of one effect pass (design/gdd/card-effects.md C5,
## C6.0, C6.4; ADR-0007 Decision 5): a dispatch table `op name → bound
## method`. Each handler resolves its targets (the op's own `targets`, else
## the effect's), calls the engine **primitive** per target in canonical
## order and returns the op's `effect_resolved.ops[i]` entry
## `{op, targets: Array[int], values: Dictionary, outcome}` with `outcome`
## from [constant OUTCOMES]. Handlers never write match state and, but for the
## counter ops' `counter_changed` (the resolver's own data, C5), never emit:
## the primitive emits the mutation event (C5 "the resolver never
## double-emits"; gate G7). They never run the death check or
## `recompute_auras()` — that is the engine's C10 loop after the pass (C6.0).
##
## Story 006 ships `damage`, `heal`, `buff`, `destroy`, `draw`, `armor`,
## `equip`, `summon`, `silence`, `freeze`, `give_keyword` and `mana`; every
## other C5 op is recorded `skipped` until its story lands. Story 013 adds
## `transform`, `copy_to_hand` and `return_to_hand`. Story 007 adds `conditional` / `repeat` ([method step]), value
## expressions — every value param ([constant VALUE_PARAMS]) is evaluated by
## `EffectValues.eval` in [method run] before the handler sees it, a negative
## result for a [constant NON_NEGATIVE] param clamped to 0 with
## `values.clamped_from` — and Spell Damage (F1) in `damage`. The pass
## context `run` carries `resolver`, the bound [EffectResolver]. Story 010
## turns a pass into a plain-data **work list** ([method work], [method step])
## so a `discover` / `choose_one` can suspend it mid-effect, and adds
## `add_to_hand` and the F4 pool ([method pool_candidates],
## [method draw_options]); the pause itself is the resolver's. Story 009 adds
## `add_counter` / `set_counter`, `values.read_from` on an op whose value read
## `source.*` or `counter.*`, and `source_slot` from the raise-time snapshot.
## Story 014 adds [method modify_value], the one op of a value trigger (a fold
## step, never a pass op), and `values.hook_delta` on `damage` / `heal`.
## [codeblock]
## var ops := EffectOps.new()
## var todo: Array[Dictionary] = EffectOps.work([{"op": "draw", "count": 2}])
## var entries: Array[Dictionary] = ops.step(engine, todo, run)
## [/codeblock]
class_name EffectOps
extends RefCounted

## The closed `outcome` set (card-effects Interactions; C5 and Edge Cases use
## no other).
const OUTCOMES: Array[String] = [
	"applied", "partial", "no_target", "board_full", "burned", "fatigue",
	"empty_pool", "skipped", "already_has", "no_such_trigger",
]
const APPLIED: String = "applied"
const PARTIAL: String = "partial"
const NO_TARGET: String = "no_target"
const BOARD_FULL: String = "board_full"
const BURNED: String = "burned"
const FATIGUE: String = "fatigue"
const SKIPPED: String = "skipped"
const ALREADY_HAS: String = "already_has"
const NO_SUCH_TRIGGER: String = "no_such_trigger"
## `trigger_queued.reason` of a C5 `retrigger`.
const REASON_RETRIGGER: String = "retrigger"
## The op params that take a C4 value expression (story 007).
const VALUE_PARAMS: Array[String] = ["amount", "count", "attack", "health", "cost", "value", "delta", "set"]
## The param each op needs non-negative: a negative computed value is clamped
## to 0 and logged `values.clamped_from` (Edge Cases; `apply_damage(…, 0)`
## is still called).
const NON_NEGATIVE: Dictionary[String, String] = {"damage": "amount", "heal": "amount", "armor": "amount", "draw": "count", "discard": "count", "shuffle_into_deck": "count"}
## C5 `damage.spell_damage` values (F1); an absent field is the
## `spell_damage_default` knob.
const SPELL_DAMAGE_AUTO: String = "auto"
const KNOB_SPELL_DAMAGE_DEFAULT: String = "spell_damage_default"
const KNOB_MAX_REPEAT: String = "max_repeat"
## The host card type `auto` scales for (F1).
const HOST_TYPE_SPELL: String = "spell"
## C5 `buff.duration` value that expires at the End step (F3).
const DURATION_END_OF_TURN: String = "until_end_of_turn"
## C5 `mana.duration` value for temporary crystals.
const DURATION_THIS_TURN: String = "this_turn"
const DURATION_PERMANENT: String = "permanent"
## C5 `summon.position` values.
const POSITION_SOURCE_SLOT: String = "source_slot"
const POSITION_RIGHT_OF_SOURCE: String = "right_of_source"
## The DSL trigger whose `summon` defaults to `source_slot` (C5).
const TRIGGER_DEATHRATTLE: String = "deathrattle"
## `summon_minion`'s "rightmost slot" position (match-rules Interactions).
const POSITION_END: int = -1
## C5 `summon.position: end`, and what `source_slot` / `right_of_source`
## resolve to when the source is not a minion in play (story 011) — logged
## as the summon entry's `values.position`.
const POSITION_NAME_END: String = "end"
## `conditional` entries' `values.branch` (story 011, AC-15).
const BRANCH_THEN: String = "then"
const BRANCH_ELSE: String = "else"
## The kinds each targeted op accepts at runtime (C5 "Legal targets"); a
## target of another kind, or one no longer in play, is skipped and logged
## in `values.skipped`. [constant EffectSelectors.KIND_CARD] is a card
## instance in hand or deck, legal only for the ops in
## [constant CARD_INSTANCE_PARAMS].
const LEGAL_KINDS: Dictionary[String, Array] = {
	"damage": ["minion", "hero"],
	"heal": ["minion", "hero"],
	"buff": ["minion", "hero", "weapon", EffectSelectors.KIND_CARD],
	"destroy": ["minion", "weapon"],
	"silence": ["minion"],
	"freeze": ["minion", "hero"],
	"give_keyword": ["minion", "hero", "weapon"],
	"retrigger": ["minion", "weapon"],
	"transform": ["minion"],
	"return_to_hand": ["minion"],
	"copy_to_hand": ["minion", EffectSelectors.KIND_CARD],
	"set_stats": ["minion"],
	"remove_keyword": ["minion", "hero"],
	"weapon_durability": ["weapon"],
	"shuffle_into_deck": ["minion", EffectSelectors.KIND_CARD],
}
## The ops that may target a card instance in hand or deck, and the param
## such a target needs (C5 `buff`: "card instances in hand **or deck**
## (`cost` only)"; story 011, row 25 Insight). Without it the instance is
## skipped like any other illegal target.
const CARD_INSTANCE_PARAMS: Dictionary[String, String] = {"buff": "cost"}
## The ops that take a card instance in hand or deck with no param to require
## (C5 `copy_to_hand`: "characters (minions), hand/deck cards").
const CARD_INSTANCE_OPS: Array[String] = ["copy_to_hand", "shuffle_into_deck"]
## The static op `recompute_auras()` applies (C5 `aura`, C7; story 012).
const OP_AURA: String = "aura"
## The one op of a value trigger (C5 `modify_value`, C2; story 014).
const OP_MODIFY_VALUE: String = "modify_value"
## The engine fold each op's primitive runs (match-rules hook table).
const POINT_MODIFY_DAMAGE: StringName = &"modify_damage"
const POINT_MODIFY_HEAL: StringName = &"modify_heal"
## The kinds an `aura` op accepts (C5 Legal targets: "as for `buff`"); a card
## instance only with `cost` ([method apply_aura]).
const AURA_KINDS: Array[String] = ["minion", "hero", "weapon", EffectSelectors.KIND_CARD]
## C2 `scope.zone` value of a hand-cost aura (row 24): its default targets.
const ZONE_HAND: String = "hand"

var _table: Dictionary[String, Callable] = {}


func _init() -> void:
	_table = {
		"damage": _op_damage,
		"heal": _op_heal,
		"buff": _op_buff,
		"destroy": _op_destroy,
		"silence": _op_silence,
		"freeze": _op_freeze,
		"give_keyword": _op_give_keyword,
		"retrigger": _op_retrigger,
		"draw": _op_draw,
		"armor": _op_armor,
		"equip": _op_equip,
		"summon": _op_summon,
		"mana": _op_mana,
	}
	_table["add_to_hand"] = _op_add_to_hand
	_table["transform"] = _op_transform
	_table["copy_to_hand"] = _op_copy_to_hand
	_table["return_to_hand"] = _op_return_to_hand
	_table["add_counter"] = _op_add_counter
	_table["set_counter"] = _op_set_counter
	_table["set_stats"] = _op_set_stats
	_table["remove_keyword"] = _op_remove_keyword
	_table["weapon_durability"] = _op_weapon_durability
	_table["shuffle_into_deck"] = _op_shuffle_into_deck
	_table["discard"] = _op_discard
	_table["hero_power_refresh"] = _op_hero_power_refresh


## True when this story's table runs [param op_name] (else [method run]
## records it `skipped`).
func handles(op_name: String) -> bool:
	return _table.has(op_name)


## Runs [param op] once against the live board of [param engine] and returns
## its `ops[]` entry. [param run] is the pass context: `{owner, source_id,
## target_id, effect}` (`effect` the whole effect object — its `targets` is
## the default target set). An op this story does not ship is recorded
## `{op, targets: [], values: {}, outcome: skipped}` and calls nothing.
func run(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var name: String = str(op.get("op", ""))
	if not _table.has(name):
		return entry(name, [], {}, SKIPPED)
	var evaluated: Dictionary = op
	# `values.read_from` is worked out with the value, before the handler: that
	# is the state the value was read in, and a handler that hits the event cap
	# unbinds the resolver (sprint-4 review S1; M1 review R1).
	var read_from: String = ""
	if run_ctx.get("resolver") is EffectResolver:
		evaluated = op.duplicate()
		for key: String in VALUE_PARAMS:
			if op.get(key) is Dictionary:
				var origin: String = EffectValues.read_origin(op[key], run_ctx)
				if origin != "":
					read_from = origin
				evaluated[key] = EffectValues.eval(op[key], run_ctx)
	var clamped: Variant = null
	var key: String = NON_NEGATIVE.get(name, "")
	if key != "" and typeof(evaluated.get(key)) in [TYPE_INT, TYPE_FLOAT] and int(evaluated[key]) < 0:
		if evaluated == op:
			evaluated = op.duplicate()
		clamped = int(evaluated[key])
		evaluated[key] = 0
	var result: Dictionary = _table[name].call(engine, evaluated, run_ctx)
	if clamped != null:
		(result.values as Dictionary)["clamped_from"] = clamped
	if read_from != "":
		(result.values as Dictionary)["read_from"] = read_from
	return result


## The work items of [param ops] for a pass's work list (story 010): one
## plain-data `{op, condition, branch, skip, op_index}` per op, in order.
## `condition` is the outermost `conditional`'s evaluated `if` the op sits
## under (null at top level), `branch` the branch that conditional took
## (`then` / `else`, story 011 AC-15; null at top level), `skip` marks an op
## of the branch not taken, and `op_index` is
## the index of the effect's top-level op it came from ([param op_index], or
## each op's own index when it is −1). Plain data, so a suspended pass keeps
## it in `EffectRuntime.pending_choice`.
## Example: `var todo: Array[Dictionary] = EffectOps.work(effect.ops)`.
static func work(ops: Variant, condition: Variant = null, skip: bool = false, op_index: int = -1, branch: Variant = null) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var list: Array = ops if ops is Array else []
	for index: int in list.size():
		items.append({
			"op": list[index],
			"condition": condition,
			"branch": branch,
			"skip": skip,
			"op_index": index if op_index < 0 else op_index,
		})
	return items


## Pops the front item of the work list [param todo] and runs it, returning
## the `effect_resolved.ops` entries it produced — one per leaf op executed
## (C5, story 007; as a work list since story 010):
## - a `skip` item (an op of the `conditional` branch not taken): one
##   `skipped` entry, nothing run;
## - `conditional {if, then, else}`: `if` (a C4 condition) evaluated now; both
##   branches go to the front of [param todo] — the taken one to run, the
##   other as `skip` items — and every entry from either carries
##   `values.condition` (Edge Cases: the log carries the evaluated condition)
##   and `values.branch`, the branch taken — `then` or `else` (story 011);
##   returns no entry itself;
## - `repeat {times, ops}`: `times` (a value, clamped to 0 … `max_repeat`)
##   copies of `ops` go to the front of [param todo]; each copy's selectors are
##   resolved when it runs, against the live board (C6.0: a minion an
##   iteration kills is dying, so the next finds no target);
## - any other op: [method run], one entry.
## `discover` / `choose_one` never reach here un-skipped: the resolver takes
## them off the list first, because they suspend the pass (C8).
## Example: `while not todo.is_empty(): entries.append_array(ops.step(engine, todo, run))`.
func step(engine: RulesEngine, todo: Array[Dictionary], run_ctx: Dictionary) -> Array[Dictionary]:
	var item: Dictionary = todo.pop_front()
	var op: Dictionary = item.op
	var out: Array[Dictionary] = []
	var children: Array[Dictionary] = []
	if bool(item.skip):
		var none: Array[int] = []
		out.append(entry(str(op.get("op", "")), none, {}, SKIPPED))
	else:
		match str(op.get("op", "")):
			"conditional":
				var taken: bool = EffectValues.holds(op.get("if"), run_ctx)
				var marker: Variant = item.condition if item.condition != null else taken
				var branch: Variant = item.get("branch") if item.condition != null else (BRANCH_THEN if taken else BRANCH_ELSE)
				children = work(op.get("then", []), marker, not taken, int(item.op_index), branch)
				children.append_array(work(op.get("else", []), marker, taken, int(item.op_index), branch))
			"repeat":
				var times: int = EffectValues.eval(op.get("times", 1), run_ctx)
				var resolver: EffectResolver = run_ctx.resolver
				times = clampi(times, 0, resolver.knob_int(KNOB_MAX_REPEAT))
				for _i: int in times:
					children.append_array(work(op.get("ops", []), item.condition, false, int(item.op_index), item.get("branch")))
			_:
				out.append(run(engine, op, run_ctx))
	if not children.is_empty():
		children.append_array(todo)
		todo.assign(children)
	for e: Dictionary in out:
		tag_condition(e, item)
	return out


## Writes [param item]'s `conditional` marker into [param op_entry]'s
## `values.condition` and `values.branch` (none at top level). Example: `EffectOps.tag_condition(e, item)`.
static func tag_condition(op_entry: Dictionary, item: Dictionary) -> void:
	if item.get("condition") != null:
		(op_entry.values as Dictionary)["condition"] = item.condition
	if item.get("branch") != null:
		(op_entry.values as Dictionary)["branch"] = item.branch


## One `ops[]` entry (card-effects Interactions payload).
static func entry(op_name: String, targets: Array[int], values: Dictionary, outcome: String) -> Dictionary:
	return {"op": op_name, "targets": targets, "values": values, "outcome": outcome}


## Folds per-call outcomes into the op's outcome: none → `no_target`; all
## the same → that one; mixed → `partial`.
static func fold_outcomes(outcomes: Array[String]) -> String:
	if outcomes.is_empty():
		return NO_TARGET
	for outcome: String in outcomes:
		if outcome != outcomes[0]:
			return PARTIAL
	return outcomes[0]


# --- targeted ops -----------------------------------------------------------------

## C5 `damage` with F1: `requested = amount + (scales ? spell_damage(owner) :
## 0)`, `scales = spell_damage == true ∨ (spell_damage == auto ∧ host.type
## == spell)`; an absent `spell_damage` is the `spell_damage_default` knob.
## `spell_damage(owner)` is match-rules F7, read through the engine once per
## op (re-read per op, added once — not per target). When a `modify_damage`
## hook changed `requested` the entry also carries `values.hook_delta` and
## `values.dealt` ([method _record_folds]).
func _op_damage(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var amount: int = _int(op.get("amount", 0))
	var requested: int = amount
	if _scales(op, run_ctx):
		requested += engine.spell_damage(str(run_ctx.owner))
	var deltas: Array[int] = []
	var dealt: Array[int] = []
	var result: Dictionary = _per_target(engine, op, run_ctx, {"amount": amount, "requested": requested}, func(id: int) -> String:
		deltas.append(_hook_delta(engine, POINT_MODIFY_DAMAGE, requested, id, run_ctx))
		dealt.append(engine.apply_damage(id, requested, run_ctx.source_id))
		return APPLIED)
	_record_folds(result, deltas, "dealt", dealt)
	return result


## F1 `scales` for a `damage` op of the pass [param run_ctx] (no resolver in
## the context → no scaling).
static func _scales(op: Dictionary, run_ctx: Dictionary) -> bool:
	if not run_ctx.get("resolver") is EffectResolver:
		return false
	var resolver: EffectResolver = run_ctx.resolver
	var flag: Variant = op.get("spell_damage", resolver.knob(KNOB_SPELL_DAMAGE_DEFAULT))
	if typeof(flag) == TYPE_BOOL:
		return bool(flag)
	if str(flag) == SPELL_DAMAGE_AUTO:
		# A treasure or passive (C9) is no spell, and `definition` holds no such id.
		if run_ctx.get("source_id") is String:
			return false
		return str(resolver.definition(str(run_ctx.get("host_id", ""))).get("type", "")) == HOST_TYPE_SPELL
	return false


## C5 `heal`: `apply_heal` per target. When a `modify_heal` hook changed the
## amount the entry also carries `values.hook_delta` and `values.restored`
## ([method _record_folds]).
func _op_heal(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var amount: int = _int(op.get("amount", 0))
	var deltas: Array[int] = []
	var restored: Array[int] = []
	var result: Dictionary = _per_target(engine, op, run_ctx, {"amount": amount}, func(id: int) -> String:
		deltas.append(_hook_delta(engine, POINT_MODIFY_HEAL, amount, id, run_ctx))
		restored.append(engine.apply_heal(id, amount, run_ctx.source_id))
		return APPLIED)
	_record_folds(result, deltas, "restored", restored)
	return result


## The net change the hooks on [param point] make to [param requested] for this
## target, before the engine's clamp (treasures Edge Cases: a fold of −1 from 1
## logs −2). The fold is pure, so reading it ahead of the primitive changes
## nothing; the primitive folds again with the same inputs.
static func _hook_delta(engine: RulesEngine, point: StringName, requested: int, target_id: int, run_ctx: Dictionary) -> int:
	var ctx: Dictionary = {"source": run_ctx.source_id, "target": target_id}
	return engine.state().hooks.fold(point, StringName(str(run_ctx.owner)), requested, ctx) - requested


## Story 014 (ADR-0005 Events; treasures Edge Cases, AC-27): when a fold changed
## the value for any target, `values.hook_delta` and `values[key]` of
## [param result] hold one int per entry of `targets`, in that order, so the
## feed can name the treasure. With no change neither key exists, and the entry
## keeps the shape it has with no hooks installed.
static func _record_folds(result: Dictionary, deltas: Array[int], key: String, amounts: Array[int]) -> void:
	for delta: int in deltas:
		if delta != 0:
			(result.values as Dictionary)["hook_delta"] = deltas
			(result.values as Dictionary)[key] = amounts
			return


## C5 `modify_value`, one step of a value fold (C2, C9; story 014): [param value]
## with the op's one param applied — `delta` adds, `set` replaces, `mul`
## multiplies; `delta` and `set` are C4 value expressions read in
## [param run_ctx], so `context.value` is the value coming in. Never clamps:
## the engine clamps once after the whole fold (ADR-0005 rule 4). Any other op
## leaves the value alone (the validator rejects one at load, `E_FX_OP`).
## Example: `folded = EffectOps.modify_value({"op": "modify_value", "delta": -1}, 3, run)`.
static func modify_value(op: Dictionary, value: int, run_ctx: Dictionary) -> int:
	if str(op.get("op", "")) != OP_MODIFY_VALUE:
		return value
	if op.has("delta"):
		return value + EffectValues.eval(op["delta"], run_ctx)
	if op.has("set"):
		return EffectValues.eval(op["set"], run_ctx)
	if op.has("mul"):
		return value * _int(op["mul"])
	return value


## C5 `buff`: `apply_enchantment(target, {attack_delta, health_delta,
## cost_delta?, keywords_added, source_entity_id, expires})` per target. A
## card instance in hand or deck is a legal target when the op has `cost`
## (story 011; [constant CARD_INSTANCE_PARAMS]): the engine keeps the
## enchantment in its `cost_modifiers`, which travel with the instance into
## hand, so `buff cost` on `deck_top` then `draw` is Insight (row 25);
## `until_end_of_turn` expires at the owner's End step (match-rules C4 step 5).
func _op_buff(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var enchantment: Dictionary = {
		"attack_delta": _int(op.get("attack", 0)),
		"health_delta": _int(op.get("health", 0)),
		"keywords_added": (op.get("keywords", []) as Array).duplicate(),
		"source_entity_id": run_ctx.source_id,
		"expires": MatchRecords.EXPIRES_END_OF_TURN if str(op.get("duration", "")) == DURATION_END_OF_TURN else null,
	}
	if op.has("cost"):
		enchantment["cost_delta"] = _int(op.cost)
	var values: Dictionary = enchantment.duplicate()
	values.erase("source_entity_id")
	return _per_target(engine, op, run_ctx, values, func(id: int) -> String:
		engine.apply_enchantment(id, enchantment)
		return APPLIED)


## C5 `aura` / C7 / F2 (story 012), run by `EffectResolver.recompute_auras()`
## only — never from an effect pass (the validator allows `aura` only under the
## static `aura` / `passive_hand` triggers). For each `aura` op of the effect
## [param run_ctx]`.effect`: its value params (`attack`, `health`, `cost`)
## evaluated now ([method EffectValues.eval]), its targets the op's `targets`,
## else the effect's — `hand` when the effect's scope is `zone: hand` and it
## names none — resolved afresh against the live board, or only
## [param self_target] for a `passive_hand` host (the card instance itself).
## Each target, once (one source never applies one aura twice to a target),
## gets `apply_enchantment(target, {attack_delta, health_delta, cost_delta?,
## keywords_added, source_entity_id, is_aura: true})`; a card instance only
## when the op has `cost` (C5: hand cards take `cost` only), a target of a kind
## the op does not accept never. Records no `ops[]` entry and emits nothing
## itself: an aura is not an effect pass (the engine's one `auras_recomputed`
## reports the net change). Example: `ops.apply_aura(engine, run, null)`.
func apply_aura(engine: RulesEngine, run_ctx: Dictionary, self_target: Variant) -> void:
	var state: MatchState = engine.state()
	var effect: Dictionary = run_ctx.effect
	var scope: Variant = effect.get("scope")
	var default_targets: Variant = effect.get("targets")
	if default_targets == null and scope is Dictionary and str((scope as Dictionary).get("zone", "")) == ZONE_HAND:
		default_targets = ZONE_HAND
	for op: Variant in effect.get("ops", []):
		if not op is Dictionary or str((op as Dictionary).get("op", "")) != OP_AURA:
			continue
		var aura: Dictionary = op
		var enchantment: Dictionary = {
			"attack_delta": EffectValues.eval(aura.get("attack", 0), run_ctx),
			"health_delta": EffectValues.eval(aura.get("health", 0), run_ctx),
			"keywords_added": (aura.get("keywords", []) as Array).duplicate(),
			"source_entity_id": run_ctx.source_id,
			"is_aura": true,
		}
		if aura.has("cost"):
			enchantment["cost_delta"] = EffectValues.eval(aura.cost, run_ctx)
		var targets: Array[int] = []
		if self_target != null:
			targets.append(int(self_target))
		else:
			targets = EffectSelectors.entities(state, aura.get("targets", default_targets), run_ctx)
		var seen: Dictionary = {}
		for id: int in targets:
			if seen.has(id):
				continue
			seen[id] = true
			var kind: String = EffectSelectors.kind_of(state, id)
			if kind == "" and aura.has("cost") and EffectSelectors.is_card_instance(state, id):
				kind = EffectSelectors.KIND_CARD
			if (AURA_KINDS as Array).has(kind):
				engine.apply_enchantment(id, enchantment)


func _op_destroy(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	return _per_target(engine, op, run_ctx, {}, func(id: int) -> String:
		engine.destroy(id)
		return APPLIED)


func _op_silence(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	return _per_target(engine, op, run_ctx, {}, func(id: int) -> String:
		engine.silence(id)
		return APPLIED)


func _op_freeze(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	return _per_target(engine, op, run_ctx, {}, func(id: int) -> String:
		engine.freeze(id)
		return APPLIED)


func _op_give_keyword(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var keyword: String = str(op.get("keyword", ""))
	var state: MatchState = engine.state()
	return _per_target(engine, op, run_ctx, {"keyword": keyword}, func(id: int) -> String:
		if EffectSelectors.has_keyword(EffectSelectors.find(state, id), keyword):
			return ALREADY_HAS
		engine.add_keyword(id, keyword)
		return APPLIED)


## C5 `transform`: `transform(target, card_id)` per target. The primitive gives
## the new `entity_id`, drops enchantments and damage, carries summoning
## sickness and fires no Battlecry. `targets` are the old ids, `values.new_ids`
## the new ones. A target that is the pass's source rebinds `self` to the new
## body (C6.5, [method EffectResolver.rebind_source]); a definition the database
## lacks transforms nothing (`skipped`).
func _op_transform(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var card_id: String = str(op.get("card_id", ""))
	var new_ids: Array[int] = []
	var result: Dictionary = _per_target(engine, op, run_ctx, {"card_id": card_id}, func(id: int) -> String:
		var new_id: int = engine.transform(id, card_id)
		if new_id == RulesEngine.NO_ENTITY:
			return SKIPPED
		new_ids.append(new_id)
		if run_ctx.get("resolver") is EffectResolver and EffectSelectors.run_source(run_ctx) == id:
			(run_ctx.resolver as EffectResolver).rebind_source(run_ctx, id, new_id)
		return APPLIED)
	(result.values as Dictionary)["new_ids"] = new_ids
	return result


## C5 `copy_to_hand`: `add_card_to_hand(side, target.def_id)` × count per target,
## a minion or a card instance in hand or deck. A copy is the **definition**,
## never the instance: no enchantments, damage or Silence (Edge Cases). `side`
## is the op's, else the owner ([method _side]). Per copy a full hand is
## `burned` (the engine emits `card_burned`), else `applied`.
func _op_copy_to_hand(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var count: int = _int(op.get("count", 1))
	var state: MatchState = engine.state()
	var added: Array[String] = []
	var result: Dictionary = _per_target(engine, op, run_ctx, {"count": count, "side": side}, func(id: int) -> String:
		var def_id: String = EffectSelectors.def_id_of(state, id)
		var outcomes: Array[String] = []
		for _i: int in count:
			# The last copy may have hit the event cap: the resolver is unbound now.
			if engine.phase() == MatchState.PHASE_ENDED:
				break
			outcomes.append(hand_add_outcome(engine, side))
			@warning_ignore("return_value_discarded")
			engine.add_card_to_hand(side, def_id)
			added.append(def_id)
		return fold_outcomes(outcomes) if count > 0 else APPLIED)
	(result.values as Dictionary)["card_ids"] = added
	return result


## C5 `return_to_hand`: `return_to_hand(target)` per target. The minion leaves
## play with no death and its controller gets a fresh instance of its `def_id`:
## nothing is copied, so counters keyed by the old `entity_id` are simply out of
## reach (story 009). A full hand is `burned`: the primitive emits
## `minion_returned{burned: true}`, never `card_burned` (match-rules C15).
func _op_return_to_hand(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var state: MatchState = engine.state()
	return _per_target(engine, op, run_ctx, {}, func(id: int) -> String:
		var outcome: String = hand_add_outcome(engine, str(EffectSelectors.find(state, id).controller))
		@warning_ignore("return_value_discarded")
		engine.return_to_hand(id)
		return outcome)


## C5 `set_stats`: `set_stats(target, attack, health)` per target; an absent
## param stays null and leaves that stat alone. [method run] evaluates both
## value params before this handler, so "swap Attack and Health"
## (`attack: {ref: target.health}, health: {ref: target.attack}`) reads both
## refs before the write, as C5 requires.
func _op_set_stats(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var new_attack: Variant = _int(op.attack) if op.has("attack") else null
	var new_health: Variant = _int(op.health) if op.has("health") else null
	return _per_target(engine, op, run_ctx, {"attack": new_attack, "health": new_health}, func(id: int) -> String:
		engine.set_stats(id, new_attack, new_health)
		return APPLIED)


## C5 `remove_keyword`: `remove_keyword(target, kw)` per target. A keyword the
## target does not hold is the no-op `skipped`.
func _op_remove_keyword(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var keyword: String = str(op.get("keyword", ""))
	var state: MatchState = engine.state()
	return _per_target(engine, op, run_ctx, {"keyword": keyword}, func(id: int) -> String:
		if not EffectSelectors.has_keyword(EffectSelectors.find(state, id), keyword):
			return SKIPPED
		engine.remove_keyword(id, keyword)
		return APPLIED)


## C5 `weapon_durability`: `modify_durability(weapon, amount)` per target (±);
## a weapon at ≤ 0 breaks in the next death check. No weapon is `no_target`.
func _op_weapon_durability(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var amount: int = _int(op.get("amount", 0))
	return _per_target(engine, op, run_ctx, {"amount": amount}, func(id: int) -> String:
		engine.modify_durability(id, amount)
		return APPLIED)


## C5 `shuffle_into_deck`: `add_card_to_deck(side, def_id, position)` × count.
## The `card_id` form never fails. The `targets` form (hand cards, minions)
## adds a fresh instance of each target's definition and leaves the target where
## it is: the C5 primitive only adds, and no planned card uses this form. A
## `random` position draws one `match_<floor>` index per copy, in the primitive.
func _op_shuffle_into_deck(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var count: int = _int(op.get("count", 1))
	var position: String = str(op.get("position", MatchRecords.POSITION_RANDOM))
	var values: Dictionary = {"count": count, "side": side, "position": position}
	if op.has("card_id"):
		var added: Array[int] = []
		for _i: int in count:
			var id: int = engine.add_card_to_deck(side, str(op.card_id), position)
			if id != RulesEngine.NO_ENTITY:
				added.append(id)
		values["card_id"] = str(op.card_id)
		return entry("shuffle_into_deck", added, values, APPLIED)
	var state: MatchState = engine.state()
	return _per_target(engine, op, run_ctx, values, func(id: int) -> String:
		var def_id: String = EffectSelectors.def_id_of(state, id)
		for _i: int in count:
			@warning_ignore("return_value_discarded")
			engine.add_card_to_deck(side, def_id, position)
		return APPLIED)


## C5 `discard`: `discard(side, random)` × count (v1 is random only; each pick
## draws from `match_<floor>` in the primitive). `targets` are the discarded
## instance ids; an empty hand from the first pick on is `no_target`, and a hand that
## runs out partway folds to `partial`, as a short `summon` does.
func _op_discard(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var count: int = _int(op.get("count", 1))
	var discarded: Array[int] = []
	var outcomes: Array[String] = []
	for _i: int in count:
		var id: int = engine.discard(side, MatchRecords.PICK_RANDOM)
		if id == RulesEngine.NO_ENTITY:
			outcomes.append(NO_TARGET)
		else:
			discarded.append(id)
			outcomes.append(APPLIED)
	return entry("discard", discarded, {"count": count, "side": side}, fold_outcomes(outcomes) if count > 0 else APPLIED)


## C5 `hero_power_refresh`: `refresh_hero_power(side)`, no mana refund. A power
## not yet used this turn is the no-op `skipped`.
func _op_hero_power_refresh(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var used: bool = bool(engine.state().players[side].hero_power.used_this_turn)
	engine.refresh_hero_power(side)
	return entry("hero_power_refresh", [], {"side": side}, APPLIED if used else SKIPPED)


## C5 `retrigger` (sprint-4 review S5): queues each target's live effects with
## the op's `trigger` as if raised now, through the engine's
## [method RulesEngine.queue_triggers] (`trigger_queued{reason: retrigger}`) —
## the C10 loop resolves them after this pass, each as its own step (C6.0). The
## source stays in play, so nothing dies and a `source.*` read is live (C6.5).
## A target with no live effect for the trigger (none printed, or Silenced) is
## `no_such_trigger`; no target at all is `no_target`. A board with both folds
## through [method fold_outcomes] like any targeted op: C5 does not name that
## case, so no test pins it (open question, content story 004's notes).
func _op_retrigger(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var trigger: String = str(op.get("trigger", ""))
	var resolver: EffectResolver = run_ctx.resolver
	return _per_target(engine, op, run_ctx, {"trigger": trigger}, func(id: int) -> String:
		# An earlier target's `trigger_queued` may have hit the event cap.
		if engine.phase() == MatchState.PHASE_ENDED:
			return SKIPPED
		var entries: Array[Dictionary] = resolver.retrigger_entries(trigger, id)
		if entries.is_empty():
			return NO_SUCH_TRIGGER
		engine.queue_triggers(StringName(trigger), entries, REASON_RETRIGGER)
		return APPLIED)


## Resolves the op's targets, skips any of a kind the op does not accept
## (C5 Legal targets; `values.skipped`), and calls [param act] per remaining
## target in canonical order; the outcome folds the per-target results.
func _per_target(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary, values: Dictionary, act: Callable) -> Dictionary:
	var name: String = str(op.op)
	var state: MatchState = engine.state()
	var selector: Variant = op.get("targets", (run_ctx.effect as Dictionary).get("targets"))
	var targets: Array[int] = []
	var skipped: Array[int] = []
	var outcomes: Array[String] = []
	for id: int in EffectSelectors.entities(state, selector, run_ctx):
		if not (LEGAL_KINDS[name] as Array).has(_target_kind(state, name, op, id)):
			skipped.append(id)
			continue
		targets.append(id)
		outcomes.append(str(act.call(id)))
	if not skipped.is_empty():
		values["skipped"] = skipped
		if not outcomes.is_empty():
			outcomes.append(SKIPPED)
	return entry(name, targets, values, fold_outcomes(outcomes))


## The kind [param id] counts as for op [param name]: [method
## EffectSelectors.kind_of] for an entity in play; for a card instance in
## hand or deck, [constant EffectSelectors.KIND_CARD] when the op is in
## [constant CARD_INSTANCE_OPS] or has the param [constant CARD_INSTANCE_PARAMS]
## names, else "" (not a legal target).
static func _target_kind(state: MatchState, name: String, op: Dictionary, id: int) -> String:
	var kind: String = EffectSelectors.kind_of(state, id)
	var takes_card: bool = CARD_INSTANCE_OPS.has(name) or (CARD_INSTANCE_PARAMS.has(name) and op.has(CARD_INSTANCE_PARAMS[name]))
	if kind == "" and takes_card and EffectSelectors.is_card_instance(state, id):
		return EffectSelectors.KIND_CARD
	return kind


# --- source-scoped ops --------------------------------------------------------------

## C5 `add_counter`: `counters[source][key] += amount`, on the live bucket even
## for a source that has left play (Edge Cases row 45: a late write the queued
## Deathrattle's snapshot does not see). Never fails.
func _op_add_counter(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var key: String = str(op.get("key", ""))
	var amount: int = _int(op.get("amount", 0))
	var value: int = EffectRuntime.counter(engine.state().effects, run_ctx.source_id, key) + amount
	return _write_counter(engine, "add_counter", key, value, run_ctx, {"amount": amount})


## C5 `set_counter`: `counters[source][key] = value`; a `{count: selector}`
## value was evaluated against the live board by [method run] (row 46: before
## the following `destroy`). Never fails.
func _op_set_counter(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	return _write_counter(engine, "set_counter", str(op.get("key", "")), _int(op.get("value", 0)), run_ctx, {})


## Stores [param value] and emits `counter_changed {source_id, key, value}` for
## a real change (ADR-0007: one per counter change; a write of the same value
## changes nothing and emits nothing). The op is `applied` either way.
static func _write_counter(engine: RulesEngine, op_name: String, key: String, value: int, run_ctx: Dictionary, values: Dictionary) -> Dictionary:
	var runtime: Dictionary = engine.state().effects
	var source_id: Variant = run_ctx.source_id
	var changed: bool = EffectRuntime.counter(runtime, source_id, key) != value
	EffectRuntime.write_counter(runtime, source_id, key, value)
	if changed:
		@warning_ignore("return_value_discarded")
		engine.emit(&"counter_changed", {"source_id": source_id, "key": key, "value": value})
	values["key"] = key
	values["value"] = value
	var none: Array[int] = []
	return entry(op_name, none, values, APPLIED)


# --- side-scoped ops ----------------------------------------------------------------

## C5 `draw`: `draw(side, 1)` × count. Each call's outcome is read before it:
## an empty deck is `fatigue`, a full hand `burned`, else `applied` (the
## engine emits `fatigue_damage` / `card_burned` / `card_drawn`).
func _op_draw(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var count: int = _int(op.get("count", 1))
	var player: Dictionary = engine.state().players[side]
	var outcomes: Array[String] = []
	for _i: int in count:
		if (player.deck as Array).is_empty():
			outcomes.append(FATIGUE)
		elif (player.hand as Array).size() >= engine.rule("hand_size"):
			outcomes.append(BURNED)
		else:
			outcomes.append(APPLIED)
		engine.draw(side, 1)
	var none: Array[int] = []
	return entry("draw", none, {"count": count, "side": side}, fold_outcomes(outcomes) if count > 0 else APPLIED)


func _op_armor(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var amount: int = _int(op.get("amount", 0))
	engine.apply_armor(side, amount)
	var none: Array[int] = []
	return entry("armor", none, {"amount": amount, "side": side}, APPLIED)


## C5 `equip`: `equip_weapon(side, card_id)` (the engine destroys a held
## weapon first). `targets` is the new weapon; a definition the database
## lacks equips nothing (`skipped`).
func _op_equip(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var card_id: String = str(op.get("card_id", ""))
	var id: int = engine.equip_weapon(side, card_id)
	var targets: Array[int] = []
	if id != RulesEngine.NO_ENTITY:
		targets.append(id)
	return entry("equip", targets, {"card_id": card_id, "side": side}, APPLIED if not targets.is_empty() else SKIPPED)


## C5 `summon`: `summon_minion(side, card_id, position)` × count, left to
## right. Position: `right_of_source` (the default outside Deathrattles) and
## `source_slot` both place the copies immediately right of the source, in
## order, while it is a minion in play on that side: `[source, copy, copy]`,
## and the source never moves (DD-X27); otherwise — a spell, hero power, weapon
## or passive source (C5; story 011: Rot) — and for `end`, the rightmost
## slot. `values.position` is the position as resolved: the authored one, or
## [constant POSITION_NAME_END] after that fallback. A full board is
## `board_full` per copy (the engine emits `summon_failed`). `targets` are
## the summoned entity ids.
## A source that has left play keeps its `source_slot`: the raise-time snapshot's
## `board_index` on that side (C5, match-rules C10 "at the dead minion's former
## index"; story 009), and a Deathrattle defaults to it. TODO(story 007): `chosen_slot`.
func _op_summon(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var card_id: String = str(op.get("card_id", ""))
	var count: int = _int(op.get("count", 1))
	var position: String = str(op.get("position", POSITION_SOURCE_SLOT if str(run_ctx.get("trigger", "")) == TRIGGER_DEATHRATTLE else POSITION_RIGHT_OF_SOURCE))
	var board: Array = engine.state().players[side].board
	var summoned: Array[int] = []
	var outcomes: Array[String] = []
	for _i: int in count:
		if board.size() >= engine.rule("board_size"):
			outcomes.append(BOARD_FULL)
		var index: int = _summon_index(board, position, side, run_ctx, summoned.size())
		var id: int = engine.summon_minion(side, card_id, index)
		if id != RulesEngine.NO_ENTITY:
			summoned.append(id)
			outcomes.append(APPLIED)
		elif board.size() < engine.rule("board_size"):
			outcomes.append(SKIPPED)
	var resolved: String = position
	if _source_index(board, EffectSelectors.run_source(run_ctx)) < 0 and _former_slot(position, side, run_ctx) < 0:
		resolved = POSITION_NAME_END
	return entry("summon", summoned, {"card_id": card_id, "count": count, "side": side, "position": resolved}, fold_outcomes(outcomes) if count > 0 else APPLIED)


## The board index of the next copy: after the source and the copies already
## placed by this op, from the source's former slot when it has left play
## ([method _former_slot]), or [constant POSITION_END].
static func _summon_index(board: Array, position: String, side: String, run_ctx: Dictionary, placed: int) -> int:
	if position != POSITION_RIGHT_OF_SOURCE and position != POSITION_SOURCE_SLOT:
		return POSITION_END
	var index: int = _source_index(board, EffectSelectors.run_source(run_ctx))
	if index < 0:
		var former: int = _former_slot(position, side, run_ctx)
		return former + placed if former >= 0 else POSITION_END
	return index + placed + 1


## The `board_index` of the pass's raise-time snapshot when [param position] is
## `source_slot` and the copies land on the side the source stood on; else −1
## (no snapshot, a weapon source, `right_of_source`, the other side).
static func _former_slot(position: String, side: String, run_ctx: Dictionary) -> int:
	var snapshot: Variant = run_ctx.get("snapshot")
	if position != POSITION_SOURCE_SLOT or not snapshot is Dictionary or str((snapshot as Dictionary).get("owner", "")) != side:
		return -1
	return int((snapshot as Dictionary).get("board_index", -1))


## The source's index on [param board], or -1 when it is not a minion there
## (a hero power's hero, a spell, a weapon, a passive — C5's `end` fallback).
static func _source_index(board: Array, source_id: int) -> int:
	for index: int in board.size():
		if int((board[index] as Dictionary).entity_id) == source_id:
			return index
	return -1


## C5 `mana`: `add_mana(side, amount, temporary)` with `temporary =
## (duration == this_turn)` — an absent `duration` is permanent; the engine
## clamps and logs.
func _op_mana(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var amount: int = _int(op.get("amount", 0))
	var duration: String = str(op.get("duration", DURATION_PERMANENT))
	engine.add_mana(side, amount, duration == DURATION_THIS_TURN)
	var none: Array[int] = []
	return entry("mana", none, {"amount": amount, "duration": duration, "side": side}, APPLIED)


# --- helpers ----------------------------------------------------------------------

## The side of a side-scoped op: its `side` param, else an `owner` /
## `opponent` selector (the op's `targets`, else the effect's), else the
## owner (C3, C5).
static func _side(op: Dictionary, run_ctx: Dictionary) -> String:
	var owner: String = str(run_ctx.owner)
	if op.has("side"):
		return EffectSelectors.side_of(op.side, owner)
	var selector: Variant = op.get("targets", (run_ctx.effect as Dictionary).get("targets"))
	if EffectSelectors.is_side_selector(selector):
		return EffectSelectors.side_of(EffectSelectors.selector_name(selector), owner)
	return owner


## An int-literal value (JSON numbers arrive as floats).
## Value expressions never reach here: [method run] evaluates them first
## (story 007); a non-literal at this point is 0.
static func _int(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return 0


# --- choices and pools (story 010; C5 `discover` / `add_to_hand`, F4) -------------

## The C5 outcome of a `discover` / `add_to_hand.from` with no candidate (F4
## `n_options == 0`: no Choice phase, the effect continues).
const EMPTY_POOL: String = "empty_pool"
## C5 `discover.pool` / `add_to_hand.from.pool` values.
const POOL_COLLECTIBLE: String = "collectible"
const POOL_LIST: String = "list"
const POOL_DECK: String = "deck"
const POOL_HAND: String = "hand"
## The pools that offer the owner's card instances: a pick from them must
## move that instance, which no match-rules primitive does yet (see
## [method _op_add_to_hand] and `EffectResolver.resume`).
const INSTANCE_POOLS: Array[String] = [POOL_DECK, POOL_HAND]
## C5 `discover.then` values (default `add_to_hand`).
const THEN_ADD_TO_HAND: String = "add_to_hand"
const THEN_SUMMON: String = "summon"
const THEN_CAST: String = "cast"
## The F4 Tuning Knobs (card-effects Tuning Knobs).
const KNOB_DISCOVER_COUNT: String = "discover_count"
const KNOB_DISCOVER_EXCLUDE_HAND: String = "discover_exclude_hand"
## `values.unsupported` on a pick from [constant INSTANCE_POOLS].
const UNSUPPORTED_INSTANCE_PICK: String = "instance_pick_needs_a_move_primitive"


## F4 `candidates` for the pool spec [param spec] (`{pool, list?, filter?}` —
## a `discover` op, or an `add_to_hand.from`) in pass [param run_ctx]:
## `distinct_by_def_id(filter(base(pool), spec.filter) \ {source.def_id})`,
## minus the def_ids in the owner's hand when `DISCOVER_EXCLUDE_HAND` is set,
## id-ascending (CR-6 order, so the draw is independent of file order).
## `base(collectible)` is `collectible_pool(player_hero_set)` for both sides
## ([method EffectResolver.collectible_pool]); `base(list)` is `spec.list ∩
## has(id)`; `base(deck)` / `base(hand)` are the owner's instances, by def_id.
## Cards are filtered as `{entity_id: -1, def_id, controller: owner}`, so the
## definition predicates of C3 apply. Example:
## `var ids: Array[String] = EffectOps.pool_candidates(resolver, op, run)`.
static func pool_candidates(resolver: EffectResolver, spec: Dictionary, run_ctx: Dictionary) -> Array[String]:
	var owner: String = str(run_ctx.owner)
	var player: Dictionary = resolver.bound_engine().state().players[owner]
	var base: Array[String] = []
	match str(spec.get("pool", "")):
		POOL_COLLECTIBLE:
			for record: Variant in resolver.collectible_pool():
				base.append(str((record as Dictionary).id))
		POOL_LIST:
			for id: Variant in (spec.get("list") if spec.get("list") is Array else []):
				if resolver.collection_allows(str(id)):
					base.append(str(id))
		POOL_DECK, POOL_HAND:
			for card: Variant in player[str(spec.pool)]:
				base.append(str((card as Dictionary).def_id))
	var excluded: Dictionary = {str(run_ctx.get("host_id", "")): true}
	if bool(resolver.knob(KNOB_DISCOVER_EXCLUDE_HAND)):
		for card: Variant in player.hand:
			excluded[str((card as Dictionary).def_id)] = true
	var filter: Dictionary = spec.filter if spec.get("filter") is Dictionary else {}
	var seen: Dictionary = {}
	var out: Array[String] = []
	for id: String in base:
		if seen.has(id) or excluded.has(id):
			continue
		seen[id] = true
		if EffectSelectors.matches(resolver, {"entity_id": -1, "def_id": id, "controller": owner}, filter, owner, EffectSelectors.run_source(run_ctx), run_ctx):
			out.append(id)
	out.sort()
	return out


## F4's offer draw: `min(n, |candidates|)` options, each the candidate at
## `j = engine.rng_match().randi_range(0, |candidates| − 1)`, with removal
## — exactly that many stream draws, none when the pool is empty. Leaves
## [param candidates] unchanged. Example:
## `var options: Array[String] = EffectOps.draw_options(engine, ids, 3)`.
static func draw_options(engine: RulesEngine, candidates: Array[String], n: int) -> Array[String]:
	var rest: Array[String] = candidates.duplicate()
	var options: Array[String] = []
	var rng: RefCounted = engine.rng_match()
	for _i: int in mini(n, rest.size()):
		var j: int = rng.randi_range(0, rest.size() - 1)
		options.append(rest[j])
		rest.remove_at(j)
	return options


## The outcome a hand-add will have: `burned` when [param side]'s hand is
## full (the engine burns the card, C5), else `applied`.
static func hand_add_outcome(engine: RulesEngine, side: String) -> String:
	return BURNED if (engine.state().players[side].hand as Array).size() >= engine.rule("hand_size") else APPLIED


## C5 `add_to_hand`: `add_card_to_hand(side, def_id)` × count, `def_id` the
## op's `card_id` or, with `from: {pool, filter, list}`, one F4 pick per copy
## ([method pool_candidates] then one draw). Per copy: an empty pool is
## `empty_pool`, a full hand `burned` (the engine emits `card_burned`), else
## `applied`. A `from` over the owner's deck or hand would have to move that
## instance, which no primitive does yet: each such copy is `skipped` with
## `values.unsupported` and draws nothing.
func _op_add_to_hand(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var count: int = _int(op.get("count", 1))
	var from: Variant = op.get("from")
	var values: Dictionary = {"count": count, "side": side}
	var added: Array[String] = []
	var outcomes: Array[String] = []
	for _i: int in count:
		# The last copy may have hit the event cap: the resolver is unbound now.
		if engine.phase() == MatchState.PHASE_ENDED:
			break
		var def_id: String = str(op.get("card_id", ""))
		if from is Dictionary:
			if INSTANCE_POOLS.has(str((from as Dictionary).get("pool", ""))):
				values["unsupported"] = UNSUPPORTED_INSTANCE_PICK
				outcomes.append(SKIPPED)
				continue
			var picks: Array[String] = draw_options(engine, pool_candidates(run_ctx.resolver, from, run_ctx), 1)
			if picks.is_empty():
				outcomes.append(EMPTY_POOL)
				continue
			def_id = picks[0]
		outcomes.append(hand_add_outcome(engine, side))
		@warning_ignore("return_value_discarded")
		engine.add_card_to_hand(side, def_id)
		added.append(def_id)
	values["card_ids"] = added
	var none: Array[int] = []
	return entry("add_to_hand", none, values, fold_outcomes(outcomes) if count > 0 else APPLIED)
