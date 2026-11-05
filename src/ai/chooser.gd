## The Boss AI choice phase (design/gdd/boss-ai.md C7, C1.4 `choose`, States
## `Choosing`, Edge Cases "If a Discover is raised during the boss's turn" and
## "If all Discover options are identical"; ADR-0006, ADR-0008;
## TR-boss-ai-001, TR-boss-ai-002; boss-ai-match-driver story 010).
##
## [method choose] answers one boss `ChoiceRequest` on a sandbox. It is pure
## over the clone: it reads, returns an index and never submits. The caller
## submits `choose{issuer: boss, option_index}`: the sandbox loop inside
## `plan_turn`, a scoring trial ([Scorer]), or the driver on the main thread.
##
## 1. **Collapse** (C7): options with the same `def_id`, or identical `ops[]`
##    whatever their `label_key`, collapse to the lowest index, so a duplicate
##    never enters the tie set and consumes no RNG.
## 2. **Score**: a Discover option is `op_value(option) × cost_fit + preference`
##    ([method CandidateSet.card_value]; `cost_fit` is 1 if its cost is at most
##    [method next_mana_max], else the `cost_fit_over` normaliser). A Choose One
##    option is `Σ op_value(op) × targets_now(op) + preference`
##    ([method CandidateSet.ops_value]), with `cost_fit` 1.
## 3. **Pick**: F8 through [method TieBreak.pick], so a tie takes one draw from
##    [param ai_stream] and a clear winner none.
##
## **`preference`** sums the profile's `choice_preference` rows over the
## option's distinct tags. A Discover option's tags are its C6 `synergy_match`
## fields (`tags`, keywords, effect trigger names) plus its `type` (`weapon`) and
## its op names (`heal`). `damage_all` names no op: it is a `damage` op on one of
## C6's area selectors ([constant Scorer.AOE_SELECTORS]). `low_cost` belongs to
## the options of the lowest cost among those offered. A Choose One option has
## its op names and `damage_all`, and no cost.
##
## The request does not carry the offering effect's `targets`, so a Choose One
## op without its own `targets` counts one target (C6's single-target default).
## [codeblock]
## var decision: Dictionary = Chooser.choose(sandbox, sandbox.pending_choice(), profile, op_values, ai_stream, db, MatchRecords.SIDE_BOSS)
## engine.submit(MatchRecords.choose(MatchRecords.SIDE_BOSS, decision.index))
## [/codeblock]
class_name Chooser
extends RefCounted

## The index [method choose] returns when it answers nothing: a request for
## another side (C1.3: those options are hidden) or one with no options.
const NO_OPTION: int = -1
## The `choice_preference` key of the tempo rule "lowest cost" (F9).
const TAG_LOW_COST: String = "low_cost"
## The `choice_preference` key of an area `damage` op (F9, C7).
const TAG_DAMAGE_ALL: String = "damage_all"
## The op `damage_all` reads.
const OP_DAMAGE: String = "damage"
## The turns between this one and the next (match-rules F4 `t + 1`).
const NEXT_TURN: int = 1


## Answers the boss `ChoiceRequest` [param request] on [param sandbox] (see the
## class doc). [param profile] is the resolved profile (`rules.tie_epsilon`,
## `choice_preference`, `synergy_tags`), [param op_values] the `ai_profiles`
## `op_values` map, [param ai_stream] the stream a tie draws from, [param db]
## answers `card(id)`, [param own] the side answering (a request for any other is
## left alone), [param mode] the planner mode to log. Returns `{index,
## diagnostic}`: `diagnostic` is the `ai_decision {kind: choice, chosen, mode,
## alternatives, draws, diagnostic: true}` payload, plain data, with `draws` the
## stream draws taken. `alternatives` holds the distinct options best first, at
## most [constant Scorer.ALTERNATIVES_MAX], the pick always among them
## ([method Scorer.alternatives]): unlike a lone `end_turn` (A24), a choice counts
## the pick itself (A16, Edge Cases).
## [constant NO_OPTION] and an empty `diagnostic` when nothing is answered.
## [codeblock]
## Chooser.choose(sandbox, request, profile, op_values, ai_stream, db, MatchRecords.SIDE_BOSS).index   # 0 (A16)
## [/codeblock]
static func choose(sandbox: RulesEngine, request: Dictionary, profile: Dictionary, op_values: Dictionary, ai_stream: RefCounted, db: Variant, own: String, mode: StringName = Scorer.MODE_NORMAL) -> Dictionary:
	var side: String = str(request.get("side"))
	var options: Array = request.get("options", [])
	if side != own or options.is_empty():
		return {"index": NO_OPTION, "diagnostic": {}}
	var discover: bool = str(request.get("kind")) == MatchRecords.CHOICE_DISCOVER
	var kept: Array[int] = _distinct(options, discover)
	var values: CandidateSet = CandidateSet.new(db, op_values, profile.get("synergy_tags", []))
	var preferences: Dictionary = profile.get("choice_preference", {})
	var limit: int = next_mana_max(sandbox, side)
	var lowest: int = _lowest_cost(options, kept, db) if discover else NO_OPTION
	var scored: Array = []
	for index: int in kept:
		var parts: Dictionary = {}
		if discover:
			parts = _discover_parts(_card(db, options[index]), values, sandbox, side, limit, lowest, preferences)
		else:
			parts = _choose_one_parts(options[index], values, sandbox, side, preferences)
		scored.append({
			"command": MatchRecords.choose(side, index),
			"score": float(parts.op_value) * float(parts.cost_fit) + float(parts.preference),
			"features": parts,
		})
	var decision: Dictionary = TieBreak.pick(scored, float(profile.rules.tie_epsilon), ai_stream)
	var chosen: Dictionary = decision.chosen
	return {
		"index": int(chosen.command.option_index),
		"diagnostic": {
			"kind": BossAI.KIND_CHOICE,
			"chosen": chosen.command,
			"mode": String(mode),
			"alternatives": Scorer.alternatives(_ranked(scored), chosen),
			"draws": int(decision.draws),
			TurnPlan.DIAGNOSTIC_KEY: true,
		},
	}


## [param side]'s `mana_max` on its next turn on [param sandbox] (match-rules
## F4 `mana_max_by_turn(t + 1)`, as the engine's Start step computes it):
## `min(turns_taken + 1 + crystal_bonus, max_mana)`.
## [codeblock]
## Chooser.next_mana_max(sandbox, MatchRecords.SIDE_BOSS)   # 4 after the boss's third turn
## [/codeblock]
static func next_mana_max(sandbox: RulesEngine, side: String) -> int:
	var player: Dictionary = sandbox.state().players[side]
	return mini(int(player.turns_taken) + NEXT_TURN + int(player.crystal_bonus), sandbox.rule("max_mana"))


# --- internals -------------------------------------------------------------------

## The indices of [param options] left after C7's collapse, ascending.
static func _distinct(options: Array, discover: bool) -> Array[int]:
	var seen: Array = []
	var kept: Array[int] = []
	for index: int in options.size():
		var identity: Variant = options[index] if discover else (options[index] as Dictionary).get("ops", [])
		if not seen.has(identity):
			seen.append(identity)
			kept.append(index)
	return kept


static func _discover_parts(def: Variant, values: CandidateSet, sandbox: RulesEngine, side: String, limit: int, lowest: int, preferences: Dictionary) -> Dictionary:
	var fits: bool = _cost(def) <= limit
	var tags: Dictionary = card_tags(def)
	if _cost(def) == lowest:
		tags[TAG_LOW_COST] = true
	return {
		"op_value": values.card_value(def, sandbox, side),
		"cost_fit": float(Scorer.NORMALISERS.cost_fit_full if fits else Scorer.NORMALISERS.cost_fit_over),
		"preference": _preference(tags, preferences),
	}


static func _choose_one_parts(option: Dictionary, values: CandidateSet, sandbox: RulesEngine, side: String, preferences: Dictionary) -> Dictionary:
	var ops: Array = option.get("ops", [])
	var tags: Dictionary = {}
	_add_op_tags(ops, null, tags)
	return {
		"op_value": values.ops_value(ops, sandbox, side),
		"cost_fit": float(Scorer.NORMALISERS.cost_fit_full),
		"preference": _preference(tags, preferences),
	}


static func _preference(tags: Dictionary, preferences: Dictionary) -> float:
	var total: float = 0.0
	for tag: Variant in tags:
		total += float(preferences.get(tag, 0.0))
	return total


## The tags of the card definition [param def] (see the class doc), as a set.
static func card_tags(def: Variant) -> Dictionary:
	var tags: Dictionary = {}
	if not def is Dictionary:
		return tags
	tags[str(def.get("type"))] = true
	for field: String in ["tags", "keywords"]:
		for value: Variant in def.get(field, []):
			tags[value] = true
	for effect: Variant in def.get("effects", []):
		if not effect is Dictionary:
			continue
		tags[effect.get("trigger")] = true
		if effect.get("ops") is Array:
			_add_op_tags(effect.ops, effect.get("targets"), tags)
	return tags


## Adds the op names of [param ops], inner ops of the structural ops included,
## to [param tags]; [param inherited] is the selector of the enclosing effect.
static func _add_op_tags(ops: Array, inherited: Variant, tags: Dictionary) -> void:
	for op: Variant in ops:
		if not op is Dictionary:
			continue
		var op_name: String = str(op.get("op"))
		var selector: Variant = op.get("targets", inherited)
		if BossAI.STRUCTURAL_OPS.has(op_name):
			for param: String in BossAI.STRUCTURAL_OPS[op_name]:
				for item: Variant in _inner_lists(op.get(param), op_name):
					_add_op_tags(item, selector, tags)
			continue
		tags[op_name] = true
		if op_name == OP_DAMAGE and Scorer.AOE_SELECTORS.has(Scorer.selector_name(selector)):
			tags[TAG_DAMAGE_ALL] = true


## The op lists under the structural param value [param inner] of
## [param op_name]: `choose_one` holds them under `options[].ops`.
static func _inner_lists(inner: Variant, op_name: String) -> Array:
	if not inner is Array:
		return []
	if op_name != Scorer.OP_CHOOSE_ONE:
		return [inner]
	var lists: Array = []
	for option: Variant in inner:
		if option is Dictionary and option.get("ops") is Array:
			lists.append(option.ops)
	return lists


static func _lowest_cost(options: Array, kept: Array[int], db: Variant) -> int:
	var lowest: int = _cost(_card(db, options[kept[0]]))
	for index: int in kept:
		lowest = mini(lowest, _cost(_card(db, options[index])))
	return lowest


static func _card(db: Variant, def_id: Variant) -> Variant:
	return db.card(str(def_id)) if db != null else null


static func _cost(def: Variant) -> int:
	return int(def.get("cost", 0)) if def is Dictionary else 0


## [param scored] best first, equal scores by option index.
static func _ranked(scored: Array) -> Array:
	var ranked: Array = scored.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score if a.score != b.score else int(a.command.option_index) < int(b.command.option_index))
	return ranked
