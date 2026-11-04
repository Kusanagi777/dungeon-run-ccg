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
## (TODO: `conditional` / `repeat` story 007, `discover` / `choose_one` 010,
## counters 009, `transform` / `copy_to_hand` / keyword removal 013, the
## rest with the stories that own them). Values are int literals here; value
## expressions and Spell Damage (F1) are story 007.
## [codeblock]
## var ops := EffectOps.new()
## var entry: Dictionary = ops.run(engine, {"op": "draw", "count": 2}, run)
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
## The kinds each targeted op accepts at runtime (C5 "Legal targets"); a
## target of another kind, or one no longer in play, is skipped and logged
## in `values.skipped`.
const LEGAL_KINDS: Dictionary[String, Array] = {
	"damage": ["minion", "hero"],
	"heal": ["minion", "hero"],
	"buff": ["minion", "hero", "weapon"],
	"destroy": ["minion", "weapon"],
	"silence": ["minion"],
	"freeze": ["minion", "hero"],
	"give_keyword": ["minion", "hero", "weapon"],
}

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


## True when this story's table runs [param op_name] (else [method run]
## records it `skipped`).
func handles(op_name: String) -> bool:
	return _table.has(op_name)


## Runs [param op] once against the live board of [param engine] and returns
## its `ops[]` entry. [param run] is the pass context: `{owner, source_id,
## target_id, effect}` (`effect` the whole effect object — its `targets` is
## the default target set). An op this story does not ship is recorded
## `{op, targets: [], values: {}, outcome: skipped}` and calls nothing; so is
## a shipped op with a computed value ([method computed_param]), with
## `values {unsupported_value, reason}`.
func run(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var name: String = str(op.get("op", ""))
	if not _table.has(name):
		return entry(name, [], {}, SKIPPED)
	var computed: String = computed_param(op)
	if computed != "":
		return entry(name, [], {"unsupported_value": computed, "reason": REASON_VALUE_EXPRESSION}, SKIPPED)
	return _table[name].call(engine, op, run_ctx)


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

func _op_damage(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var amount: int = _int(op.get("amount", 0))
	return _per_target(engine, op, run_ctx, {"amount": amount, "requested": amount}, func(id: int) -> String:
		@warning_ignore("return_value_discarded")
		engine.apply_damage(id, amount, run_ctx.source_id)
		return APPLIED)


func _op_heal(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var amount: int = _int(op.get("amount", 0))
	return _per_target(engine, op, run_ctx, {"amount": amount}, func(id: int) -> String:
		@warning_ignore("return_value_discarded")
		engine.apply_heal(id, amount, run_ctx.source_id)
		return APPLIED)


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
		if not (LEGAL_KINDS[name] as Array).has(EffectSelectors.kind_of(state, id)):
			skipped.append(id)
			continue
		targets.append(id)
		outcomes.append(str(act.call(id)))
	if not skipped.is_empty():
		values["skipped"] = skipped
		if not outcomes.is_empty():
			outcomes.append(SKIPPED)
	return entry(name, targets, values, fold_outcomes(outcomes))


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
## is a minion in play on that side; otherwise, and for `end`, the rightmost
## slot. A full board is `board_full` per copy (the engine emits
## `summon_failed`). `targets` are the summoned entity ids.
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
	return entry("summon", summoned, {"card_id": card_id, "count": count, "side": side}, fold_outcomes(outcomes) if count > 0 else APPLIED)


## The board index of the next copy: after the source and the copies already
## placed by this op, or [constant POSITION_END].
static func _summon_index(board: Array, position: String, source_id: int, placed: int) -> int:
	if position != POSITION_RIGHT_OF_SOURCE and position != POSITION_SOURCE_SLOT:
		return POSITION_END
	for index: int in board.size():
		if int((board[index] as Dictionary).entity_id) == source_id:
			return index + placed + (1 if position == POSITION_RIGHT_OF_SOURCE else 0)
	return POSITION_END


## `values.reason` of a `mana` op with `duration: this_turn` until temporary
## crystals exist (code review 2026-11-04).
const REASON_TEMPORARY_MANA: String = "temporary_unsupported: this-turn crystals are match-rules story 011"


## C5 `mana`: `add_mana(side, amount, temporary)` with `temporary =
## (duration == this_turn)` — an absent `duration` is permanent; the engine
## clamps and logs. TODO(match-rules story 011): `add_mana` refuses temporary
## crystals until then, so a `this_turn` op calls nothing and is `skipped`
## with `values.reason` [constant REASON_TEMPORARY_MANA] — never `applied`
## for crystals that were not granted (code review 2026-11-04).
func _op_mana(engine: RulesEngine, op: Dictionary, run_ctx: Dictionary) -> Dictionary:
	var side: String = _side(op, run_ctx)
	var amount: int = _int(op.get("amount", 0))
	var duration: String = str(op.get("duration", DURATION_PERMANENT))
	var values: Dictionary = {"amount": amount, "duration": duration, "side": side}
	var none: Array[int] = []
	if duration == DURATION_THIS_TURN:
		values["reason"] = REASON_TEMPORARY_MANA
		return entry("mana", none, values, SKIPPED)
	engine.add_mana(side, amount, false)
	return entry("mana", none, values, APPLIED)


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


## `values.reason` of an op skipped for a computed value (code review
## 2026-11-04).
const REASON_VALUE_EXPRESSION: String = "value_expression_unsupported: computed values are card-effects story 007"


## The first numeric param of [param op] (C4: a `P_VALUE` / `P_COUNT` param
## in [constant EffectSchema.OPS]) holding a value expression (`{ref}`,
## `{count}`, `{add}`, …) instead of an int literal, else `""`.
## TODO(story 007): evaluate value expressions; until then [method run]
## records such an op `skipped` with `values.unsupported_value` and calls no
## primitive — fail closed, as an unsupported condition fizzles (C4).
## Example: `EffectOps.computed_param({"op": "armor", "amount": {"ref": "match.turn"}})  # "amount"`.
static func computed_param(op: Dictionary) -> String:
	var spec: Dictionary = (EffectSchema.OPS.get(str(op.get("op", "")), {}) as Dictionary).get("params", {})
	for param: String in spec:
		var kind: Variant = spec[param]  # a StringName kind, or an Array enum
		if kind is StringName and (kind == EffectSchema.P_VALUE or kind == EffectSchema.P_COUNT) and op.get(param) is Dictionary:
			return param
	return ""


## An int-literal value (JSON numbers arrive as floats). A value expression
## never reaches a handler ([method computed_param]); anything else is 0.
static func _int(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return 0
