## The Boss AI candidate set (design/gdd/boss-ai.md C4 pre-filter, C6 op
## value table and derived annotations, F1 `f_hp`, F7 `max_evals_per_action`,
## F9 `hero_power`, Edge Cases "an effect requires a target but none is
## legal"; ADR-0006; TR-boss-ai-001; boss-ai-match-driver story 005).
##
## [method collect] turns a sandbox's `legal_commands()` into the commands the
## [Scorer] simulates: the planner never synthesises a command (match-rules
## 015/017 review, note 6 — `submit` ignores a stray `position` or
## `target_id`, so a made-up command could score as a duplicate). Two steps:
## 1. **Positions** (C6): a minion play keeps every offered position only when
##    its card is `position_sensitive`; otherwise only the rightmost
##    (`position = board.size`). A Battlecry minion offered with
##    `target_id = null` stays as offered and is scored as a body.
## 2. **Pre-filter** (C4): when more than `budgets.max_evals_per_action`
##    remain, they are ranked by [method op_value] (high first, ties in
##    `legal_commands()` order) and only the top `max_evals_per_action − 1`
##    plus `end_turn` are kept — `end_turn` is always simulated. The rest are
##    never scored, so never chosen. The kept commands keep their
##    `legal_commands()` order.
##
## The three C6 annotations ([method derive_annotations]) are derived from the
## effect spec — Card Effects adds no AI-only field — and memoised per
## `def_id` **per instance** (story Engine Notes: one memo per `BossAI`, never
## global). The `op_value` of an op is its `op_values` row (`aura` and
## `modify_value` as `buff`; `conditional` / `repeat` / `choose_one` as the
## sum of their inner ops; an op with no row at the Edge Cases' 1.0) times the
## number of targets its selector yields on the current board.
##
## Reads the sandbox clone's `state()` for hand definitions and board sizes,
## read-only — the same deviation as [Scorer] (no `MatchQuery` yet).
## [codeblock]
## var picker := CandidateSet.new(db, config.op_values, profile.synergy_tags)
## var base: RulesEngine = engine.clone()
## var candidates: Array = picker.collect(base, profile, profile.budgets)
## var scored: Array = await scorer.score_all(base, candidates, profile, Scorer.MODE_NORMAL, {}, planner)
## [/codeblock]
class_name CandidateSet
extends RefCounted

## F9 `rules.hero_power` values (also `BossAI.RULE_ENUMS`).
const HERO_POWER_ALWAYS: String = "always"
const HERO_POWER_SPARE_MANA: String = "spare_mana"
const HERO_POWER_NEVER: String = "never"
const HERO_POWER_VALUE: String = "value"
## Edge Cases "an op type … has no `op_values` row: valued 1.0" (the load
## reports `E_AI_OP_UNVALUED`, `BossAI.validate_op_coverage`).
const OP_UNVALUED: float = 1.0
## C7's vanilla-body rule, used here for every minion body: `buff` value ×
## `(attack + health) / BODY_DIVISOR`.
const BODY_DIVISOR: float = 4.0
## The op a body is valued as (C7), the op a weapon play is valued as (C6
## `equip`), the op an attack is valued as (one `damage` to one target).
const OP_BODY: String = "buff"
const OP_WEAPON: String = "equip"
const OP_ATTACK: String = "damage"

## Selectors whose target count is the size of a board (C6 "× the number of
## targets its selector yields"): `[own minions, enemy minions, heroes]`
## counted per selector.
const BOARD_SELECTORS: Dictionary = {
	"all_friendly_minions": [1, 0, 0],
	"all_enemy_minions": [0, 1, 0],
	"all_minions": [1, 1, 0],
	"all_friendly_characters": [1, 0, 1],
	"all_enemy_characters": [0, 1, 1],
	"all_characters": [1, 1, 2],
}

## The neighbour selector that reaches both sides of a minion (C3).
const SELECTOR_ADJACENT: String = "adjacent"

var _db: Variant
var _op_values: Dictionary
var _synergy_tags: Array
## `def_id → {position_sensitive, aoe, synergy_tags_hit}` (this instance only).
var _annotations: Dictionary = {}


## [param db] answers `card(id)` / `hero_power(id)`; [param op_values] is the
## `ai_profiles` `op_values` map; [param synergy_tags] the resolved profile's
## `synergy_tags`. All read only.
func _init(db: Variant, op_values: Dictionary, synergy_tags: Array = []) -> void:
	_db = db
	_op_values = op_values
	_synergy_tags = synergy_tags.duplicate()


## The commands of [param sandbox]'s `legal_commands()` to simulate (see the
## class doc): positions filtered by C6, then capped at
## `budgets.max_evals_per_action` ([param budgets], the resolved profile's F7
## budgets) by the `op_value` rank, `end_turn` always kept. [param _profile] is
## the resolved profile (reserved for the band-specific pre-filter, F7
## `prefilter`, which is `op_value` in every band).
func collect(sandbox: RulesEngine, _profile: Dictionary, budgets: Dictionary) -> Array:
	var own: String = String(sandbox.active_side())
	var player: Dictionary = sandbox.state().players[own]
	var rightmost: int = (player.board as Array).size()
	var filtered: Array = []
	for command: Dictionary in sandbox.legal_commands():
		if str(command.type) == MatchRecords.CMD_PLAY_CARD and command.has("position") and int(command.position) != rightmost:
			var def: Variant = _card(str(player.hand[int(command.hand_index)].def_id))
			if not (def is Dictionary and bool(derive_annotations(def).position_sensitive)):
				continue
		filtered.append(command)
	var cap: int = int(budgets.max_evals_per_action)
	if filtered.size() <= cap:
		return filtered
	var ranked: Array = []
	for index: int in filtered.size():
		if str(filtered[index].type) != MatchRecords.CMD_END_TURN:
			ranked.append({"index": index, "value": op_value(filtered[index], sandbox)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.value > b.value if a.value != b.value else int(a.index) < int(b.index))
	var keep: Dictionary = {}
	for entry: Dictionary in ranked.slice(0, cap - 1):
		keep[int(entry.index)] = true
	var kept: Array = []
	for index: int in filtered.size():
		if keep.has(index) or str(filtered[index].type) == MatchRecords.CMD_END_TURN:
			kept.append(filtered[index])
	return kept


## C6 cheap estimate of [param command] on [param sandbox]: a card play is its
## definition's [method def_value] (plus, for a minion, C7's body value
## `buff × (attack + health) / 4`; for a weapon, the `equip` row); a hero
## power its definition's [method def_value]; an attack one `damage` op on
## one target; `end_turn` 0.
func op_value(command: Dictionary, sandbox: RulesEngine) -> float:
	var own: String = String(sandbox.active_side())
	var player: Dictionary = sandbox.state().players[own]
	match str(command.type):
		MatchRecords.CMD_PLAY_CARD:
			var def: Variant = _card(str(player.hand[int(command.hand_index)].def_id))
			if not def is Dictionary:
				return 0.0
			var value: float = def_value(def, sandbox, own)
			match str(def.get("type")):
				RulesEngine.CARD_MINION:
					value += _row(OP_BODY) * float(int(def.get("attack", 0)) + int(def.get("health", 0))) / BODY_DIVISOR
				RulesEngine.CARD_WEAPON:
					value += _row(OP_WEAPON)
			return value
		MatchRecords.CMD_USE_HERO_POWER:
			var power: Variant = _db.hero_power(str(player.hero_power.def_id)) if _db != null else null
			return def_value(power, sandbox, own) if power is Dictionary else 0.0
		MatchRecords.CMD_ATTACK:
			return _row(OP_ATTACK)
	return 0.0


## The C6 value of the effect ops of the definition [param def] on
## [param sandbox]'s current board, for its owner [param own]: each op's row ×
## the targets its selector (the op's `targets`, else its effect's) yields.
func def_value(def: Variant, sandbox: RulesEngine, own: String) -> float:
	if not def is Dictionary:
		return 0.0
	var total: float = 0.0
	for effect: Variant in def.get("effects", []):
		if effect is Dictionary and effect.get("ops") is Array:
			total += _ops_value(effect.ops, effect.get("targets"), sandbox, own)
	return total


## The three C6 annotations of [param def], memoised by its `id` in this
## instance: `position_sensitive` (any effect or op selector is `adjacent`,
## `left_neighbour` or `right_neighbour`), `aoe` ([method Scorer.is_aoe]) and
## `synergy_tags_hit` (the profile's `synergy_tags` the card matches by a
## `tags` entry, a keyword or an effect trigger name, in tag order).
func derive_annotations(def: Dictionary) -> Dictionary:
	var key: String = str(def.get("id"))
	if _annotations.has(key):
		return _annotations[key]
	var hits: Array = []
	for tag: Variant in _synergy_tags:
		if Scorer.synergy_match(def, [tag]):
			hits.append(tag)
	var sensitive: bool = false
	for effect: Variant in def.get("effects", []):
		if effect is Dictionary and _neighbour_selector(effect.get("ops", []), effect.get("targets")):
			sensitive = true
	var annotations: Dictionary = {"position_sensitive": sensitive, "aoe": Scorer.is_aoe(def), "synergy_tags_hit": hits}
	_annotations[key] = annotations
	return annotations


## F1 `f_hp` for a `use_hero_power` candidate under the F9 rule [param rule]:
## `always` +1; `spare_mana` +1 only when no card is playable with the
## remaining mana ([param card_playable] false — a `play_card` is in
## `legal_commands()`), else −1; `never` −1; `value` 0. Any other action's
## `f_hp` is 0.
static func hero_power_feature(rule: String, card_playable: bool) -> float:
	match rule:
		HERO_POWER_ALWAYS:
			return 1.0
		HERO_POWER_SPARE_MANA:
			return -1.0 if card_playable else 1.0
		HERO_POWER_NEVER:
			return -1.0
	return 0.0


# --- internals -------------------------------------------------------------------

func _ops_value(ops: Array, inherited: Variant, sandbox: RulesEngine, own: String) -> float:
	var total: float = 0.0
	for op: Variant in ops:
		if not op is Dictionary:
			continue
		var op_name: String = str(op.get("op"))
		var selector: Variant = op.get("targets", inherited)
		if BossAI.STRUCTURAL_OPS.has(op_name):
			for param: String in BossAI.STRUCTURAL_OPS[op_name]:
				var inner: Variant = op.get(param)
				if not inner is Array:
					continue
				if op_name == Scorer.OP_CHOOSE_ONE:
					for option: Variant in inner:
						if option is Dictionary and option.get("ops") is Array:
							total += _ops_value(option.ops, selector, sandbox, own)
				else:
					total += _ops_value(inner, selector, sandbox, own)
			continue
		total += _row(str(BossAI.VALUED_AS.get(op_name, op_name))) * float(_targets(selector, sandbox, own))
	return total


## How many targets [param selector] yields now (C6): `all_*` count the
## boards (and heroes); `adjacent` up to 2 and `left_/right_neighbour` up to
## 1 of the owner's minions; a selector with `n` takes `n`; anything else
## (a single entity, `chosen`, no selector) 1.
func _targets(selector: Variant, sandbox: RulesEngine, own: String) -> int:
	var name: String = Scorer.selector_name(selector)
	var players: Dictionary = sandbox.state().players
	var own_minions: int = (players[own].board as Array).size()
	var enemy_minions: int = (players[Scorer.other_side(own)].board as Array).size()
	if BOARD_SELECTORS.has(name):
		var weights: Array = BOARD_SELECTORS[name]
		return int(weights[0]) * own_minions + int(weights[1]) * enemy_minions + int(weights[2])
	if name == SELECTOR_ADJACENT:
		return mini(EffectSchema.F6_MAX_TARGETS_ADJACENT, own_minions)
	if EffectSchema.NEIGHBOUR_SELECTORS.has(name):
		return mini(EffectSchema.F6_MAX_TARGETS_SINGLE, own_minions)
	if selector is Dictionary and BossAI.is_number(selector.get("n")):
		return int(selector.n)
	return EffectSchema.F6_MAX_TARGETS_SINGLE


static func _neighbour_selector(ops: Variant, inherited: Variant) -> bool:
	if EffectSchema.NEIGHBOUR_SELECTORS.has(Scorer.selector_name(inherited)):
		return true
	if not ops is Array:
		return false
	for op: Variant in ops:
		if not op is Dictionary:
			continue
		if EffectSchema.NEIGHBOUR_SELECTORS.has(Scorer.selector_name(op.get("targets"))):
			return true
		var op_name: String = str(op.get("op"))
		for param: String in BossAI.STRUCTURAL_OPS.get(op_name, []):
			var inner: Variant = op.get(param)
			if not inner is Array:
				continue
			for item: Variant in inner:
				var nested: Variant = item.get("ops") if op_name == Scorer.OP_CHOOSE_ONE and item is Dictionary else [item]
				if _neighbour_selector(nested, null):
					return true
	return false


func _row(op_name: String) -> float:
	return float(_op_values.get(op_name, OP_UNVALUED))


func _card(def_id: String) -> Variant:
	return _db.card(def_id) if _db != null else null
