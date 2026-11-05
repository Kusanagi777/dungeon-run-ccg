## The Boss AI lethal search (design/gdd/boss-ai.md C3, F4, F7
## `lethal_max_nodes`, F9 `lethal_search`, Edge Cases "Lethal and defence";
## ADR-0006; TR-boss-ai-001; boss-ai-match-driver story 007).
##
## A depth-first search over the **damage subset** of a sandbox's
## `legal_commands()`: attacks; `play_card` for Charge minions, Rush minions
## while the player has a Taunt, and weapons; spells and hero powers whose
## spec holds a `damage` op that can reach the enemy hero. A **node** is one
## clone plus one `submit`; a node with the player's hero at ≤ 0 is the leaf,
## and the commands that reached it are the plan. F4 ([method prunes]) cuts a
## node, the root included, that cannot reach lethal; a sandbox
## `resolution_overflow` cuts that branch. Nodes are counted against
## `budgets.lethal_max_nodes`: a search out of budget returns null and
## [member outcome] says so, so the turn proceeds normally (C3).
## `rules.lethal_search`: `full` as above; `shallow` (band 1, F9 "depth 1:
## direct attacks and one burn") only attacks on the hero and at most one burn
## aimed at it, so it never clears a Taunt or plays a weapon; `off` skips it.
##
## The stack is explicit (story Engine Notes): [method search] is the only
## coroutine frame, and it awaits `planner.checkpoint()` once per node. Memory
## is one clone per live depth, each ended with `end_match()` as it is left, on
## every path. The caller's sandbox is read and cloned, never submitted to.
## Clones of the root take the `ai_<floor>` `sim_<turn>` fork given as
## [param sim_stream] (C4: "the lethal search's sandboxes take the same fork"),
## each deeper clone a copy of its parent's, so the search's randomness is an
## estimate and can differ from what the sandbox really draws: story 008's
## step-by-step execution detects that (`ai_plan_aborted`).
##
## A boss-side Choice raised at a node is answered with [Chooser] (C7), as
## [Scorer] does in its trials: a tie draws from the node's own stream, so it
## moves neither the fork nor the live `ai_<floor>` stream.
##
## F4 reads "hand damage cards" as the C3 subset: a Charge minion, a Rush
## minion against a Taunt, a weapon and a damage hero power count alongside
## burn, or the bound would prune the very lines C3 searches (A8's weapon).
## Reads the sandbox's `state()`, read-only, as [Scorer] does (no `MatchQuery`
## yet); the player's hand is never read.
## [codeblock]
## var lethal := LethalSearch.new(db, picker)
## var plan: Variant = await lethal.search(base, profile, profile.budgets, planner, sim)
## if plan == null: print(lethal.outcome, lethal.nodes)
## [/codeblock]
class_name LethalSearch
extends RefCounted

## [member outcome] values. `lethal_search_exhausted` and `shallow_none` are the
## strings `ai_decision` records (A7, A9, Edge Cases).
const OUTCOME_FOUND: StringName = &"found"
const OUTCOME_NONE: StringName = &"none"
const OUTCOME_OFF: StringName = &"off"
const OUTCOME_SHALLOW_NONE: StringName = &"shallow_none"
const OUTCOME_EXHAUSTED: StringName = &"lethal_search_exhausted"
## F9 `rules.lethal_search` values (also `BossAI.RULE_ENUMS`).
const RULE_SHALLOW: String = "shallow"
const RULE_OFF: String = "off"
## The op the damage subset is defined by (C3).
const OP_DAMAGE: String = "damage"
## Selectors that can reach the enemy hero without a chosen target (C3).
const FACE_SELECTORS: Array[String] = [
	"enemy_hero", "all_enemy_characters", "all_characters",
	"random_enemy_character", "random_character",
]
## Filter values of a `chosen` selector that keep the enemy hero in reach.
const FACE_FILTER_KINDS: Array[String] = ["", EffectSelectors.KIND_ANY, MatchRecords.KIND_HERO]
const FACE_FILTER_SIDES: Array[String] = ["", EffectSelectors.SIDE_ANY, EffectSelectors.SIDE_ENEMY]
## The `damage` op's `spell_damage` field values that scale (Card Effects F1).
const SPELL_DAMAGE_AUTO: String = "auto"
## [method face_damage] of a card whose `amount` is an expression: it cannot be
## priced without running it. F4 is an upper bound, so such a card within mana
## makes the potential [constant UNBOUNDED] rather than pruning a real lethal.
const UNPRICED: int = -1
const UNBOUNDED: int = 9223372036854775807
## Move order: what lands damage first, so the leaf comes early. A rank, not a
## tuning value.
const RANK_FACE: int = 0
const RANK_BODY: int = 1
const RANK_OTHER: int = 2

## Nodes the last [method search] expanded (0 when F4 fired at the root).
var nodes: int = 0
## How the last [method search] ended: one of the `OUTCOME_*` constants.
var outcome: StringName = OUTCOME_NONE

var _db: Variant
var _picker: CandidateSet


## [param db] answers `card(id)` / `hero_power(id)`; [param picker] supplies
## the C6 position rule, so a plain minion is tried once, at the rightmost slot
## (Edge Cases "a Charge minion is lethal only at an exact position").
func _init(db: Variant, picker: CandidateSet) -> void:
	_db = db
	_picker = picker


## Searches [param sandbox] (a `RulesEngine.clone()`, never the live engine) for
## a command list that leaves the player's hero at ≤ 0, reading
## `rules.lethal_search` from [param profile] and `lethal_max_nodes` and
## `max_actions_per_turn` (the depth bound) from [param budgets]. Returns the
## commands in order, or null: no lethal, or none within the budget
## ([member outcome] tells them apart, [member nodes] counts the work). A
## **coroutine** (ADR-0006 erratum): it awaits [param planner]`.checkpoint()`
## after each node, so every caller awaits it. [param sim_stream] is the turn's
## `sim_<turn>` fork; null falls back to each clone's copy of `rng_match`.
## [param unseen] is a forecast's undrawn deck ([method drop_unseen]): each node loses
## those cards as it draws them, so no line runs through one.
## [codeblock]
## var plan: Variant = await lethal.search(base, profile, profile.budgets, planner, sim)
## [/codeblock]
func search(sandbox: RulesEngine, profile: Dictionary, budgets: Dictionary, planner: PlannerTask, sim_stream: RngStream = null, unseen: Array = []) -> Variant:
	nodes = 0
	var rule: String = str(profile.rules.lethal_search)
	var shallow: bool = rule == RULE_SHALLOW
	var miss: StringName = OUTCOME_SHALLOW_NONE if shallow else OUTCOME_NONE
	outcome = miss
	if rule == RULE_OFF:
		outcome = OUTCOME_OFF
		return null
	if prunes(sandbox):
		return null
	var max_nodes: int = int(budgets.lethal_max_nodes)
	var max_depth: int = int(budgets.max_actions_per_turn)
	var path: Array = []
	var stack: Array[Dictionary] = [_frame(sandbox, shallow, false)]
	while not stack.is_empty():
		var frame: Dictionary = stack.back()
		if int(frame.next) >= (frame.moves as Array).size():
			_leave(stack, path, sandbox)
			continue
		if nodes >= max_nodes:
			outcome = OUTCOME_EXHAUSTED
			_release(stack, sandbox)
			return null
		var move: Dictionary = frame.moves[int(frame.next)]
		frame.next = int(frame.next) + 1
		nodes += 1
		var parent: RulesEngine = frame.engine
		var child: RulesEngine = parent.clone(sim_stream.copy() if sim_stream != null and parent == sandbox else null)
		var accepted: bool = child.submit(move.duplicate(true)).accepted
		if accepted:
			_answer_choices(child, profile)
			drop_unseen(child, String(sandbox.active_side()), unseen)
		await planner.checkpoint()
		if accepted and _is_lethal(child):
			child.end_match()
			_release(stack, sandbox)
			path.append(move)
			outcome = OUTCOME_FOUND
			return path
		var burned: bool = bool(frame.burned) or _is_burn(move, parent)
		if accepted and path.size() + 1 < max_depth and _is_own_main(child, sandbox) and not prunes(child):
			var next: Dictionary = _frame(child, shallow, burned)
			if not (next.moves as Array).is_empty():
				path.append(move)
				stack.append(next)
				continue
		child.end_match()
	return null


## F4: whether [param node] cannot reach lethal —
## `potential − taunt_hp < player_health + player_armor`, for the side to move.
## Equality does not prune.
## [codeblock]
## lethal.prunes(base)   # F4 example: 12 − 5 < 8 → true
## [/codeblock]
func prunes(node: RulesEngine) -> bool:
	var hero: Dictionary = node.state().players[_enemy(node)].hero
	return potential(node) - taunt_hp(node) < node.health(hero) + int(hero.armor)


## F4 `potential` of the side to move on [param node]: `Σ attack × attacks
## remaining` over the characters with a legal attack, plus the
## greedy-by-damage/cost sum of hand and hero power damage within mana.
## [constant UNBOUNDED] when an affordable card's damage is an expression.
func potential(node: RulesEngine) -> int:
	var own: String = String(node.active_side())
	var attackers: Dictionary = {}
	var power_usable: bool = false
	for command: Dictionary in node.legal_commands():
		match str(command.type):
			MatchRecords.CMD_ATTACK:
				attackers[int(command.attacker_id)] = true
			MatchRecords.CMD_USE_HERO_POWER:
				power_usable = true
	var total: int = 0
	for id: int in attackers:
		var attacker: Dictionary = node.state_snapshot(id)
		total += node.attack(attacker) * node.attacks_remaining(attacker)
	var player: Dictionary = node.state().players[own]
	var bonus: int = node.spell_damage(own)
	var taunted: bool = _has_taunt(node)
	var entries: Array[Dictionary] = []
	for index: int in (player.hand as Array).size():
		var card: Dictionary = player.hand[index]
		var damage: int = _hand_damage(_card(str(card.def_id)), bonus, taunted, node)
		if damage != 0:
			entries.append({"damage": damage, "cost": node.effective_cost(card, own), "index": index})
	if power_usable:
		var power_damage: int = face_damage(_power(str(player.hero_power.def_id)), 0)
		if power_damage != 0:
			entries.append({"damage": power_damage, "cost": node.hero_power_cost(own), "index": (player.hand as Array).size()})
	entries.sort_custom(_denser)
	var mana: int = int(player.mana_current)
	for entry: Dictionary in entries:
		if int(entry.cost) > mana:
			continue
		if int(entry.damage) == UNPRICED:
			return UNBOUNDED
		mana -= int(entry.cost)
		total += int(entry.damage)
	return total


## F4 `taunt_hp` on [param node]: the health of the taunters (F3: Taunt, not
## Stealth) on the board of the side not to move.
func taunt_hp(node: RulesEngine) -> int:
	var total: int = 0
	for minion: Dictionary in node.state().players[_enemy(node)].board:
		if is_taunter(minion):
			total += node.health(minion)
	return total


## F4 `face_damage` of the spell or hero power definition [param def]: every
## `damage` op that can reach the enemy hero, `amount` plus [param bonus] (the
## Spell Damage total, Match Rules F7) where it scales, inner ops of
## `conditional` / `repeat` / `choose_one` included. 0 when no op reaches the
## hero; [constant UNPRICED] when an amount or a `repeat.times` is an
## expression. C3's test for "a spell or hero power in the damage subset".
## [codeblock]
## lethal.face_damage(bolt_def, 1)   # 4 for a 3-damage bolt with 1 Spell Damage
## [/codeblock]
func face_damage(def: Variant, bonus: int) -> int:
	if not def is Dictionary:
		return 0
	var total: int = 0
	for effect: Variant in def.get("effects", []):
		if effect is Dictionary and effect.get("ops") is Array:
			var damage: int = _ops_face_damage(effect.ops, effect.get("targets"), bonus)
			if damage == UNPRICED:
				return UNPRICED
			total += damage
	return total


# --- the damage subset -------------------------------------------------------------

## A stack frame over [param engine]: its moves, best first, and whether the
## path has spent `shallow`'s one burn.
func _frame(engine: RulesEngine, shallow: bool, burned: bool) -> Dictionary:
	var ranked: Array[Dictionary] = []
	var commands: Array = _picker.positions(engine)
	for index: int in commands.size():
		var rank: int = _rank(commands[index], engine, shallow, burned)
		if rank >= 0:
			ranked.append({"rank": rank, "index": index, "command": commands[index]})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.rank) < int(b.rank) if int(a.rank) != int(b.rank) else int(a.index) < int(b.index))
	var moves: Array = []
	for entry: Dictionary in ranked:
		moves.append(entry.command)
	return {"engine": engine, "moves": moves, "next": 0, "burned": burned}


## The move rank of [param command] on [param engine], or -1 when it is
## outside the damage subset.
func _rank(command: Dictionary, engine: RulesEngine, shallow: bool, burned: bool) -> int:
	var hero_id: int = int(engine.state().players[_enemy(engine)].hero.entity_id)
	match str(command.type):
		MatchRecords.CMD_ATTACK:
			if int(command.target_id) == hero_id:
				return RANK_FACE
			return -1 if shallow else RANK_OTHER if not _has_taunt(engine) else RANK_FACE
		MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_USE_HERO_POWER:
			if _is_burn(command, engine):
				return _burn_rank(command, hero_id, shallow, burned)
			if shallow or str(command.type) != MatchRecords.CMD_PLAY_CARD:
				return -1
			return _body_rank(_played(command, engine), engine)
	return -1


func _burn_rank(command: Dictionary, hero_id: int, shallow: bool, burned: bool) -> int:
	var target: Variant = command.get("target_id")
	var at_face: bool = target == null or int(target) == hero_id
	if shallow and (burned or not at_face):
		return -1
	return RANK_FACE if at_face else RANK_OTHER


## C3's non-burn plays: a Charge minion, a Rush minion against a Taunt, a weapon.
func _body_rank(def: Variant, engine: RulesEngine) -> int:
	if not def is Dictionary:
		return -1
	if str(def.get("type")) == RulesEngine.CARD_WEAPON:
		return RANK_BODY
	var keywords: Array = def.get("keywords", [])
	if str(def.get("type")) == RulesEngine.CARD_MINION and (keywords.has(MatchRecords.KEYWORD_CHARGE) or (keywords.has(MatchRecords.KEYWORD_RUSH) and _has_taunt(engine))):
		return RANK_BODY
	return -1


## Whether [param command] on [param engine] is a burn: a spell or a hero power
## with a `damage` op that can reach the enemy hero.
func _is_burn(command: Dictionary, engine: RulesEngine) -> bool:
	match str(command.type):
		MatchRecords.CMD_USE_HERO_POWER:
			var player: Dictionary = engine.state().players[String(engine.active_side())]
			return face_damage(_power(str(player.hero_power.def_id)), 0) != 0
		MatchRecords.CMD_PLAY_CARD:
			var def: Variant = _played(command, engine)
			return def is Dictionary and str(def.get("type")) == RulesEngine.CARD_SPELL and face_damage(def, 0) != 0
	return false


## What one hand card adds to F4's sum: a burn's [method face_damage]; for a Charge
## (or, against a Taunt, Rush) minion or a weapon, F4's own attacker term once it
## lands, `attack × attacks_remaining`, so Windfury counts on either.
func _hand_damage(def: Variant, bonus: int, taunted: bool, node: RulesEngine) -> int:
	if not def is Dictionary:
		return 0
	var keywords: Array = def.get("keywords", [])
	var swings: int = node.rule("max_attacks_windfury") if keywords.has(MatchRecords.KEYWORD_WINDFURY) else RulesEngine.ATTACKS_PER_TURN
	match str(def.get("type")):
		RulesEngine.CARD_SPELL:
			return face_damage(def, bonus)
		RulesEngine.CARD_MINION:
			var charges: bool = keywords.has(MatchRecords.KEYWORD_CHARGE) or (taunted and keywords.has(MatchRecords.KEYWORD_RUSH))
			return int(def.get("attack", 0)) * swings if charges else 0
		RulesEngine.CARD_WEAPON:
			return int(def.get("attack", 0)) * swings
	return 0


func _ops_face_damage(ops: Array, inherited: Variant, bonus: int) -> int:
	var total: int = 0
	for op: Variant in ops:
		if not op is Dictionary:
			continue
		var op_name: String = str(op.get("op"))
		var selector: Variant = op.get("targets", inherited)
		var damage: int = 0
		if BossAI.STRUCTURAL_OPS.has(op_name):
			damage = _structural_face_damage(op, op_name, selector, bonus)
		elif op_name == OP_DAMAGE and _reaches_face(selector):
			damage = _op_amount(op, bonus)
		if damage == UNPRICED:
			return UNPRICED
		total += damage
	return total


## An upper bound over a structural op: both branches of a `conditional`, every
## `choose_one` option, `repeat` × its `times`.
func _structural_face_damage(op: Dictionary, op_name: String, selector: Variant, bonus: int) -> int:
	var total: int = 0
	for param: String in BossAI.STRUCTURAL_OPS[op_name]:
		var inner: Variant = op.get(param)
		if not inner is Array:
			continue
		for item: Variant in (inner as Array):
			var nested: Variant = item.get("ops") if op_name == Scorer.OP_CHOOSE_ONE and item is Dictionary else [item]
			var damage: int = _ops_face_damage(nested, selector, bonus) if nested is Array else 0
			if damage == UNPRICED:
				return UNPRICED
			total += damage
	if not op.has("times") or total == 0:
		return total
	return total * int(op.times) if BossAI.is_number(op.times) else UNPRICED


func _op_amount(op: Dictionary, bonus: int) -> int:
	var amount: Variant = op.get("amount")
	if not BossAI.is_number(amount):
		return UNPRICED
	var scales: Variant = op.get("spell_damage", SPELL_DAMAGE_AUTO)
	return int(amount) + (0 if typeof(scales) == TYPE_BOOL and not scales else bonus)


## Whether [param selector] can yield the enemy hero (C3): an area or random
## character selector, the hero itself, or a `chosen` whose filter allows it.
static func _reaches_face(selector: Variant) -> bool:
	var name: String = Scorer.selector_name(selector)
	if FACE_SELECTORS.has(name):
		return true
	if name != EffectSelectors.SELECTOR_CHOSEN:
		return false
	var filter: Variant = selector.get("filter") if selector is Dictionary else null
	if not filter is Dictionary:
		return true
	return FACE_FILTER_KINDS.has(str(filter.get("kind", ""))) and FACE_FILTER_SIDES.has(str(filter.get("side", "")))


# --- nodes ---------------------------------------------------------------------------

## Answers the Choices the side to move owes on [param node] with [Chooser].
func _answer_choices(node: RulesEngine, profile: Dictionary) -> void:
	var own: String = String(node.active_side())
	while node.phase() == MatchState.PHASE_CHOICE:
		var pending: Variant = node.pending_choice()
		if not pending is Dictionary or str(pending.side) != own:
			return
		var index: int = int(Chooser.choose(node, pending, profile, _picker.op_values(), node.rng_match(), _db, own).index)
		if index == Chooser.NO_OPTION or not node.submit(MatchRecords.choose(own, index)).accepted:
			return


## Whether [param node] ended with the opposing hero at ≤ 0 and no fault: a
## `resolution_overflow` cuts the branch instead (Edge Cases).
static func _is_lethal(node: RulesEngine) -> bool:
	var result: Variant = node.result()
	if result is Dictionary and MatchRecords.FAULT_REASONS.has(str(result.get("reason"))):
		return false
	var hero: Dictionary = node.state().players[_enemy(node)].hero
	return node.health(hero) <= 0


## Whether it is still the search's own Main on [param node].
static func _is_own_main(node: RulesEngine, root: RulesEngine) -> bool:
	return node.phase() == MatchState.PHASE_MAIN and node.active_side() == root.active_side()


## Pops the top frame, ending its clone (never the caller's [param root]).
static func _leave(stack: Array[Dictionary], path: Array, root: RulesEngine) -> void:
	var frame: Dictionary = stack.pop_back()
	if frame.engine != root:
		(frame.engine as RulesEngine).end_match()
		path.pop_back()


## Ends every clone still on [param stack].
static func _release(stack: Array[Dictionary], root: RulesEngine) -> void:
	for frame: Dictionary in stack:
		if frame.engine != root:
			(frame.engine as RulesEngine).end_match()


## The side not to move on [param node].
static func _enemy(node: RulesEngine) -> String:
	return Scorer.other_side(String(node.active_side()))


static func _has_taunt(node: RulesEngine) -> bool:
	for minion: Dictionary in node.state().players[_enemy(node)].board:
		if is_taunter(minion):
			return true
	return false


## Drops from [param side]'s hand every card of [param unseen], the instance ids of
## its deck when a forecast began, so nothing downstream of a draw reads an undrawn
## card (C1.3, C8.1; BAI-011 review D1). A card the hand held, or one an effect made,
## stays. Only at a Main: a pending Choice's stages must not be disturbed. Through
## `run_action`, so auras settle; `discard` raises no trigger.
## [codeblock]
## LethalSearch.drop_unseen(node, "boss", unseen)
## [/codeblock]
static func drop_unseen(node: RulesEngine, side: String, unseen: Array) -> void:
	if unseen.is_empty() or node.phase() != MatchState.PHASE_MAIN:
		return
	var hand: Array = node.state().players[side].hand
	var drops: Array[int] = []
	for index: int in range(hand.size() - 1, -1, -1):
		if unseen.has(int(hand[index].instance_id)):
			drops.append(index)
	if drops.is_empty():
		return
	node.run_action(func() -> void:
		for index: int in drops:
			@warning_ignore("return_value_discarded")
			node.discard(side, index))


## F3 `taunters`: Taunt, and not Stealth.
static func is_taunter(minion: Dictionary) -> bool:
	var keywords: Array = Scorer.keywords_of(minion)
	return keywords.has(MatchRecords.KEYWORD_TAUNT) and not keywords.has(MatchRecords.KEYWORD_STEALTH)


## F4's greedy order: damage per mana, high first (a free card first of all),
## then more damage, then hand order. Cross-multiplied, so a cost of 0 needs no
## special case.
static func _denser(a: Dictionary, b: Dictionary) -> bool:
	if int(a.damage) == UNPRICED or int(b.damage) == UNPRICED:
		return int(a.damage) == UNPRICED and int(b.damage) != UNPRICED
	var left: int = int(a.damage) * int(b.cost)
	var right: int = int(b.damage) * int(a.cost)
	if left != right:
		return left > right
	if int(a.damage) != int(b.damage):
		return int(a.damage) > int(b.damage)
	return int(a.index) < int(b.index)


func _played(command: Dictionary, engine: RulesEngine) -> Variant:
	var player: Dictionary = engine.state().players[String(engine.active_side())]
	return _card(str(player.hand[int(command.hand_index)].def_id))


func _card(def_id: String) -> Variant:
	return _db.card(def_id) if _db != null else null


func _power(def_id: String) -> Variant:
	return _db.hero_power(def_id) if _db != null else null
