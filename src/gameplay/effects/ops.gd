## The C5 operations of one effect pass (design/gdd/card-effects.md C5,
## C6.0, C6.4; ADR-0007 Decision 5): a dispatch table `op name → bound
## method`. Each handler resolves its targets (the op's own `targets`, else
## the effect's), calls the engine **primitive** per target in canonical
## order and returns the op's `effect_resolved.ops[i]` entry
## `{op, targets: Array[int], values: Dictionary, outcome}` with `outcome`
## from [constant OUTCOMES]. Handlers never write match state and never emit:
## the primitive emits the mutation event (C5 "the resolver never
## double-emits"; gate G7). They never run the death check or
## `recompute_auras()` — that is the engine's C10 loop after the pass (C6.0).
##
## Story 006 ships `damage`, `heal`, `buff`, `destroy`, `draw`, `armor`,
## `equip`, `summon`, `silence`, `freeze`, `give_keyword` and `mana`; every
## other C5 op is recorded `skipped` until its story lands
## (TODO: counters 009, `transform` /
## `copy_to_hand` / keyword removal 013, the rest with the stories that own
## them). Story 007 adds `conditional` / `repeat` ([method step]), value
## expressions — every value param ([constant VALUE_PARAMS]) is evaluated by
## `EffectValues.eval` in [method run] before the handler sees it, a negative
## result for a [constant NON_NEGATIVE] param clamped to 0 with
## `values.clamped_from` — and Spell Damage (F1) in `damage`. The pass
## context `run` carries `resolver`, the bound [EffectResolver]. Story 010
## turns a pass into a plain-data **work list** ([method work], [method step])
## so a `discover` / `choose_one` can suspend it mid-effect, and adds
## `add_to_hand` and the F4 pool ([method pool_candidates],
## [method draw_options]); the pause itself is the resolver's. `retrigger`
## (sprint-4 review S5) queues through the engine ([method _op_retrigger]).
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
const NON_NEGATIVE: Dictionary[String, String] = {"damage": "amount", "heal": "amount", "armor": "amount", "draw": "count"}
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
}
## The ops that may target a card instance in hand or deck, and the param
## such a target needs (C5 `buff`: "card instances in hand **or deck**
## (`cost` only)"; story 011, row 25 Insight). Without it the instance is
## skipped like any other illegal target.
const CARD_INSTANCE_PARAMS: Dictionary[String, String] = {"buff": "cost"}
## The static op `recompute_auras()` applies (C5 `aura`, C7; story 012).
const OP_AURA: String = "aura"
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
		"draw": _op_draw,
		"armor": _op_armor,
		"equip": _op_equip,
		"summon": _op_summon,
		"mana": _op_mana,
	}
	_table["add_to_hand"] = _op_add_to_hand
	_table["retrigger"] = _op_retrigger


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
	if run_ctx.get("resolver") is EffectResolver:
		evaluated = op.duplicate()
		for key: String in VALUE_PARAMS:
			if op.get(key) is Dictionary:
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
## op (re-read per op, added once — not per target).
func _op_damage(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var amount: int = _int(op.get("amount", 0))
	var requested: int = amount
	if _scales(op, run_ctx):
		requested += engine.spell_damage(str(run_ctx.owner))
	return _per_target(engine, op, run_ctx, {"amount": amount, "requested": requested}, func(id: int) -> String:
		@warning_ignore("return_value_discarded")
		engine.apply_damage(id, requested, run_ctx.source_id)
		return APPLIED)


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
		return str(resolver.definition(str(run_ctx.get("host_id", ""))).get("type", "")) == HOST_TYPE_SPELL
	return false


func _op_heal(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var amount: int = _int(op.get("amount", 0))
	return _per_target(engine, op, run_ctx, {"amount": amount}, func(id: int) -> String:
		@warning_ignore("return_value_discarded")
		engine.apply_heal(id, amount, run_ctx.source_id)
		return APPLIED)


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
## hand or deck, [constant EffectSelectors.KIND_CARD] when the op has the
## param [constant CARD_INSTANCE_PARAMS] names, else "" (not a legal target).
static func _target_kind(state: MatchState, name: String, op: Dictionary, id: int) -> String:
	var kind: String = EffectSelectors.kind_of(state, id)
	if kind == "" and CARD_INSTANCE_PARAMS.has(name) and op.has(CARD_INSTANCE_PARAMS[name]) and EffectSelectors.is_card_instance(state, id):
		return EffectSelectors.KIND_CARD
	return kind


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
## `source_slot` place the copies right of / at the source while the source
## is a minion in play on that side; otherwise — a spell, hero power, weapon
## or passive source (C5; story 011: Rot) — and for `end`, the rightmost
## slot. `values.position` is the position as resolved: the authored one, or
## [constant POSITION_NAME_END] after that fallback. A full board is
## `board_full` per copy (the engine emits `summon_failed`). `targets` are
## the summoned entity ids.
## TODO(story 009): `source_slot` from the Deathrattle snapshot's
## `board_index`; TODO(story 007): `chosen_slot`.
func _op_summon(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var card_id: String = str(op.get("card_id", ""))
	var count: int = _int(op.get("count", 1))
	var position: String = str(op.get("position", POSITION_RIGHT_OF_SOURCE))
	var board: Array = engine.state().players[side].board
	var summoned: Array[int] = []
	var outcomes: Array[String] = []
	for _i: int in count:
		if board.size() >= engine.rule("board_size"):
			outcomes.append(BOARD_FULL)
		var index: int = _summon_index(board, position, int(run_ctx.source_id), summoned.size())
		var id: int = engine.summon_minion(side, card_id, index)
		if id != RulesEngine.NO_ENTITY:
			summoned.append(id)
			outcomes.append(APPLIED)
		elif board.size() < engine.rule("board_size"):
			outcomes.append(SKIPPED)
	var resolved: String = position
	if _source_index(board, int(run_ctx.source_id)) < 0:
		resolved = POSITION_NAME_END
	return entry("summon", summoned, {"card_id": card_id, "count": count, "side": side, "position": resolved}, fold_outcomes(outcomes) if count > 0 else APPLIED)


## The board index of the next copy: after the source and the copies already
## placed by this op, or [constant POSITION_END].
static func _summon_index(board: Array, position: String, source_id: int, placed: int) -> int:
	if position != POSITION_RIGHT_OF_SOURCE and position != POSITION_SOURCE_SLOT:
		return POSITION_END
	var index: int = _source_index(board, source_id)
	if index < 0:
		return POSITION_END
	return index + placed + (1 if position == POSITION_RIGHT_OF_SOURCE else 0)


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
				if not resolver.definition(str(id)).is_empty():
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
		if EffectSelectors.matches(resolver, {"entity_id": -1, "def_id": id, "controller": owner}, filter, owner, int(run_ctx.get("source_id", -1)), run_ctx):
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
