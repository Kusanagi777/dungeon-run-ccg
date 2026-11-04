## card-effects story 011 — hero powers through the `hero_power` play trigger
## (design/gdd/card-effects.md C11 rows 8 / 16 / 25; C3 `deck_top`, `is_dying`;
## C5 `buff` on card instances, `summon` position for a non-minion source,
## `conditional`; AC-15, AC-43, AC-44; ADR-0007 Decision 1: one pass through
## primitives only, the death check after the pass).
##
## The engine is the real `RulesEngine` from `MatchFactory`'s config with a
## `TestRngService` and a `TestEventLog`, bound to the real `EffectResolver`,
## over the committed C11 fixture (`tests/fixtures/cards_effects_test.json`,
## HeroPowerDef rows 8 / 16 / 25 from card-effects story 005 — the heroes epic
## has no `hero_powers.json` stories yet) and the inline hosts below. The
## power under test is set on `players.player.hero_power.def_id`; the
## `hero_power` command is match-rules C7's. Event names are match-rules C15's
## (DD-X04): the AC's `damage_dealt{amount}` is `damage_dealt {requested,
## dealt}`; the AC's `enchantment_applied{expires: end_of_turn}` is
## `MatchRecords.EXPIRES_END_OF_TURN`.
extends GdUnitTestSuite

const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
const ROW_08: String = "power_fx_row_08_whetstone"
const ROW_16: String = "power_fx_row_16_rot"
const ROW_25: String = "power_fx_row_25_insight"
const BLADE: String = "war_whetstone_blade"
const HUSK: String = "decay_husk"
const VANILLA: String = "neutral_test_vanilla"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
## The Blade's printed stats (fixture `war_whetstone_blade`, 1/2).
const BLADE_ATTACK: int = 1
const BLADE_DURABILITY: int = 2
## Whetstone's `+1 Attack this turn` (row 8).
const WHETSTONE_DELTA: int = 1
## Insight's `costs (1) more` (row 25).
const INSIGHT_COST_DELTA: int = 1

## Inline hosts (test-only defs; ids carry their set / CR-2 prefix).
## A 3-cost spell with no effect: Insight's card on top of the deck.
const SPELL_3: String = "knowledge_test_three_cost_spell"
const SPELL_3_COST: int = 3
## A hero power that summons a Husk with no `position` (C5 default
## `right_of_source`, which a non-minion source resolves to `end`).
const DEFAULT_SUMMON_POWER: String = "power_test_default_summon"
## A hero power that buffs the top deck card's Attack: a card instance takes
## `cost` only (C5 Legal targets), so this is skipped.
const DECK_ATTACK_POWER: String = "power_test_deck_attack"


## `has` / `card` / `hero_power` from a map (the engine and the resolver ask
## nothing else in a match).
class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}

	func _init(by_id: Dictionary) -> void:
		records = by_id

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		return records.get(id)

	func hero_power(id: String) -> Variant:
		return records.get(id)


var _engine: RulesEngine = null
var _log: TestEventLog = null


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null
	_log = null


# --- helpers -------------------------------------------------------------------

func _effects_config() -> Dictionary:
	return {
		"discover_count": float(TestConstants.DISCOVER_COUNT),
		"discover_exclude_hand": false,
		"max_ops_per_effect": float(TestConstants.MAX_OPS_PER_EFFECT),
		"max_repeat": float(TestConstants.MAX_REPEAT),
		"max_summon_count": float(TestConstants.BOARD_SIZE),
		"effect_static_step_limit": float(TestConstants.EFFECT_STATIC_STEP_LIMIT),
		"spell_damage_default": "auto",
		"hooks_before_triggers": true,
	}


func _fx(json_text: String) -> Array:
	var parsed: Variant = JSON.parse_string(json_text)
	assert_bool(parsed != null).override_failure_message("fixture JSON does not parse: %s" % json_text).is_true()
	return parsed if parsed is Array else [parsed]


## The C11 fixture, the vanilla set and the inline hosts.
func _db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	var flat: JSON = load(FLAT)
	for record: Dictionary in flat.data:
		by_id[record.id] = record
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	by_id[VANILLA] = CardFactory.make_minion(VANILLA, 1, 1, 1)
	by_id[SPELL_3] = CardFactory.make_spell(SPELL_3, SPELL_3_COST, [], {"set": "knowledge"})
	by_id[DEFAULT_SUMMON_POWER] = CardFactory.make_hero_power_def(DEFAULT_SUMMON_POWER, _fx(
		'{"trigger":"hero_power","ops":[{"op":"summon","card_id":"decay_husk"}]}'))
	by_id[DECK_ATTACK_POWER] = CardFactory.make_hero_power_def(DECK_ATTACK_POWER, _fx(
		'{"trigger":"hero_power","ops":[{"op":"buff","targets":{"selector":"deck_top","n":1},"attack":1}]}'))
	return FakeCardDatabase.new(by_id)


## A started engine bound to a real `EffectResolver`, past a keep-all
## mulligan (player Main, turn 1), the player's hero power set to
## [param power_id], an empty hand and 10 mana.
func _main_phase(power_id: String) -> RulesEngine:
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log)
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	_engine.start(config)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = power_id
	_engine.state().players[SIDE_PLAYER].hand.clear()
	_refill_mana()
	return _engine


func _refill_mana() -> void:
	_engine.state().players[SIDE_PLAYER].mana_current = 10


## Replaces the player's deck with fresh instances of [param def_ids], top
## first; returns their instance ids.
func _set_deck(def_ids: Array) -> Array[int]:
	var state: MatchState = _engine.state()
	var deck: Array = state.players[SIDE_PLAYER].deck
	deck.clear()
	var ids: Array[int] = []
	for def_id: Variant in def_ids:
		var card: Dictionary = MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "deck")
		deck.append(card)
		ids.append(int(card.instance_id))
	return ids


func _put(side: String, def_id: String, attack: int, health: int, keywords: Array = []) -> int:
	return int(MatchFactory.summon(_engine.state(), side, attack, health, -1, keywords, def_id).entity_id)


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


## Ends the player's turn and the boss's: the player is back in Main with
## its hero power unused; mana refilled to 10.
func _next_player_turn() -> void:
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	_submit(MatchRecords.end_turn(SIDE_BOSS))
	_refill_mana()


func _since(from_seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq)


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return str(e.type))


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


## The `effect_resolved` payloads of [param events] whose host is [param host_id].
func _resolved_of(events: Array, host_id: String) -> Array:
	return _of_type(events, "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.host_id) == host_id).map(
		func(e: Dictionary) -> Dictionary: return e.payload)


func _hero(side: String) -> int:
	return int(_engine.state().players[side].hero.entity_id)


func _hand_card(instance_id: int) -> Dictionary:
	for card: Dictionary in _engine.state().players[SIDE_PLAYER].hand:
		if int(card.instance_id) == instance_id:
			return card
	return {}


# --- AC-15: Whetstone (row 8) -------------------------------------------------------

func test_whetstone_with_no_weapon_equips_the_blade_on_the_else_branch() -> void:
	# Arrange
	_main_phase(ROW_08)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert — a 1/2 Blade equipped; the pass is the power's, on `else`
	var events: Array = _since(before)
	var equipped: Array = _of_type(events, "weapon_equipped")
	assert_int(equipped.size()).is_equal(1)
	assert_str(str(equipped[0].payload.card_id)).is_equal(BLADE)
	assert_int(int(equipped[0].payload.attack)).is_equal(BLADE_ATTACK)
	assert_int(int(equipped[0].payload.durability)).is_equal(BLADE_DURABILITY)
	assert_array(_of_type(events, "enchantment_applied")).is_empty()
	var resolved: Array = _resolved_of(events, ROW_08)
	assert_int(resolved.size()).is_equal(1)
	assert_str(str(resolved[0].host_kind)).is_equal(EffectResolver.HOST_KIND_HERO_POWER)
	assert_str(str(resolved[0].trigger)).is_equal("hero_power")
	assert_int(int(resolved[0].source_id)).is_equal(_hero(SIDE_PLAYER))
	var ops: Array = resolved[0].ops
	assert_str(str(ops[0].values.branch)).is_equal("else")
	assert_array(ops.map(func(o: Dictionary) -> Array: return [str(o.op), str(o.outcome)])).is_equal([["buff", "skipped"], ["equip", "applied"]])
	assert_array(ops[1].targets).is_equal([int(_engine.state().players[SIDE_PLAYER].weapon.entity_id)])


func test_whetstone_with_the_blade_held_buffs_it_this_turn_on_the_then_branch() -> void:
	# Arrange — Whetstone once (equips the Blade), then the next player turn
	_main_phase(ROW_08)
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	_next_player_turn()
	var blade: int = int(_engine.state().players[SIDE_PLAYER].weapon.entity_id)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert — `enchantment_applied {attack_delta: 1, expires: end_of_turn}` on
	# the Blade, no equip, `branch: then`
	var events: Array = _since(before)
	assert_array(_of_type(events, "weapon_equipped")).is_empty()
	var applied: Array = _of_type(events, "enchantment_applied")
	assert_int(applied.size()).is_equal(1)
	assert_int(int(applied[0].payload.instance_id)).is_equal(blade)
	assert_int(int(applied[0].payload.attack_delta)).is_equal(WHETSTONE_DELTA)
	assert_str(str(applied[0].payload.expires)).is_equal(MatchRecords.EXPIRES_END_OF_TURN)
	var ops: Array = _resolved_of(events, ROW_08)[0].ops
	assert_str(str(ops[0].values.branch)).is_equal("then")
	assert_array(ops.map(func(o: Dictionary) -> Array: return [str(o.op), str(o.outcome)])).is_equal([["buff", "applied"], ["equip", "skipped"]])
	assert_array(ops[0].targets).is_equal([blade])
	assert_int(_engine.attack(_engine.state().players[SIDE_PLAYER].hero)).is_equal(BLADE_ATTACK + WHETSTONE_DELTA)


func test_whetstones_blade_buff_is_removed_at_the_owners_end_step() -> void:
	# Arrange — the Blade held and whetted this turn
	_main_phase(ROW_08)
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	_next_player_turn()
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	var blade: int = int(_engine.state().players[SIDE_PLAYER].weapon.entity_id)
	var before: int = _last_seq()

	# Act — the player's End step
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	var removed: Array = _of_type(_since(before), "enchantment_removed").filter(
		func(e: Dictionary) -> bool: return int(e.payload.instance_id) == blade)
	assert_int(removed.size()).is_equal(1)
	assert_int(int(removed[0].payload.attack_delta)).is_equal(WHETSTONE_DELTA)
	assert_str(str(removed[0].payload.reason)).is_equal(MatchRecords.EXPIRES_END_OF_TURN)
	assert_array(_engine.state().players[SIDE_PLAYER].weapon.enchantments).is_empty()


func test_a_whetted_blade_swing_deals_the_blade_attack_plus_1() -> void:
	# Arrange — the weapon's enchantment counts in the hero's attack (C1).
	# The swing's `damage_dealt.source` (DD-X15: the hero) is match-rules
	# C8's, owned by the match-rules review fixes — not asserted here.
	_main_phase(ROW_08)
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	_next_player_turn()
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.attack(SIDE_PLAYER, _hero(SIDE_PLAYER), _hero(SIDE_BOSS)))

	# Assert
	var dealt: Array = _of_type(_since(before), "damage_dealt")
	assert_int(dealt.size()).is_equal(1)
	assert_int(int(dealt[0].payload.target)).is_equal(_hero(SIDE_BOSS))
	assert_int(int(dealt[0].payload.dealt)).is_equal(BLADE_ATTACK + WHETSTONE_DELTA)


# --- AC-43: Rot (row 16) ------------------------------------------------------------

func test_rot_on_an_enemy_2_1_summons_a_husk_at_the_right_before_the_target_dies() -> void:
	# Arrange — one friendly minion, so `end` is board index 1
	_main_phase(ROW_16)
	_put(SIDE_PLAYER, VANILLA, 1, 1)
	var target: int = _put(SIDE_BOSS, VANILLA, 2, 1)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, target))

	# Assert — damage, Husk at the rightmost slot, the pass, then the death
	var events: Array = _since(before)
	var wanted: Array = ["damage_dealt", "minion_summoned", "effect_resolved", "minion_died"]
	var order: Array = _types(events).filter(func(t: String) -> bool: return wanted.has(t))
	assert_array(order).is_equal(wanted)
	var dealt: Array = _of_type(events, "damage_dealt")
	assert_int(int(dealt[0].payload.target)).is_equal(target)
	assert_int(int(dealt[0].payload.dealt)).is_equal(1)
	var summoned: Array = _of_type(events, "minion_summoned")
	assert_str(str(summoned[0].payload.card_id)).is_equal(HUSK)
	assert_str(str(summoned[0].payload.side)).is_equal(SIDE_PLAYER)
	assert_int(int(summoned[0].payload.position)).is_equal(1)
	var ops: Array = _resolved_of(events, ROW_16)[0].ops
	assert_str(str(ops[1].outcome)).is_equal(EffectOps.APPLIED)
	assert_str(str(ops[1].values.position)).is_equal(EffectOps.POSITION_NAME_END)
	assert_int(int(_of_type(events, "minion_died")[0].payload.entity_id)).is_equal(target)


func test_rot_on_an_enemy_2_3_deals_damage_only_and_skips_the_summon() -> void:
	# Arrange
	_main_phase(ROW_16)
	var target: int = _put(SIDE_BOSS, VANILLA, 2, 3)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, target))

	# Assert
	var events: Array = _since(before)
	assert_int(_of_type(events, "damage_dealt").size()).is_equal(1)
	assert_array(_of_type(events, "minion_summoned")).is_empty()
	assert_array(_of_type(events, "minion_died")).is_empty()
	var ops: Array = _resolved_of(events, ROW_16)[0].ops
	assert_str(str(ops[1].outcome)).is_equal(EffectOps.SKIPPED)
	assert_str(str(ops[1].values.branch)).is_equal("else")


func test_rot_on_a_divine_shield_1_1_pops_the_shield_and_summons_nothing() -> void:
	# Arrange — `is_dying` stays false: a popped shield leaves health unchanged
	_main_phase(ROW_16)
	var target: int = _put(SIDE_BOSS, VANILLA, 1, 1, [EffectSelectors.KEYWORD_DIVINE_SHIELD])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, target))

	# Assert
	var events: Array = _since(before)
	assert_int(_of_type(events, "divine_shield_popped").size()).is_equal(1)
	assert_array(_of_type(events, "minion_summoned")).is_empty()
	assert_array(_of_type(events, "minion_died")).is_empty()
	assert_str(str(_resolved_of(events, ROW_16)[0].ops[1].outcome)).is_equal(EffectOps.SKIPPED)


func test_a_hero_power_summon_with_no_position_fills_from_the_right() -> void:
	# Arrange — C5: `right_of_source` from a non-minion source resolves to `end`
	_main_phase(DEFAULT_SUMMON_POWER)
	_put(SIDE_PLAYER, VANILLA, 1, 1)
	_put(SIDE_PLAYER, VANILLA, 1, 1)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	var summoned: Array = _of_type(events, "minion_summoned")
	assert_int(summoned.size()).is_equal(1)
	assert_int(int(summoned[0].payload.position)).is_equal(2)
	var op: Dictionary = _resolved_of(events, DEFAULT_SUMMON_POWER)[0].ops[0]
	assert_str(str(op.values.position)).is_equal(EffectOps.POSITION_NAME_END)


# --- AC-44: Insight (row 25) --------------------------------------------------------

func test_insight_costs_the_drawn_card_1_more_before_drawing_it() -> void:
	# Arrange — a 3-cost spell on top of the deck
	_main_phase(ROW_25)
	var top: int = _set_deck([SPELL_3, VANILLA])[0]
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert — the enchantment on the instance, then the draw of that instance
	var events: Array = _since(before)
	var order: Array = _types(events).filter(func(t: String) -> bool: return t == "enchantment_applied" or t == "card_drawn")
	assert_array(order).is_equal(["enchantment_applied", "card_drawn"])
	var applied: Dictionary = _of_type(events, "enchantment_applied")[0].payload
	assert_int(int(applied.instance_id)).is_equal(top)
	assert_int(int(applied.cost_delta)).is_equal(INSIGHT_COST_DELTA)
	assert_str(str(applied.expires)).is_equal(MatchRecords.EXPIRES_END_OF_TURN)
	assert_int(int(_of_type(events, "card_drawn")[0].payload.instance_id)).is_equal(top)
	var ops: Array = _resolved_of(events, ROW_25)[0].ops
	assert_array(ops.map(func(o: Dictionary) -> String: return str(o.outcome))).is_equal([EffectOps.APPLIED, EffectOps.APPLIED])
	assert_array(ops[0].targets).is_equal([top])
	assert_int(_engine.effective_cost(_hand_card(top), SIDE_PLAYER)).is_equal(SPELL_3_COST + INSIGHT_COST_DELTA)


func test_insights_cost_increase_expires_at_the_owners_end_step() -> void:
	# Arrange
	_main_phase(ROW_25)
	var top: int = _set_deck([SPELL_3, VANILLA])[0]
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	var before: int = _last_seq()

	# Act — the player's End step
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	var removed: Array = _of_type(_since(before), "enchantment_removed").filter(
		func(e: Dictionary) -> bool: return int(e.payload.instance_id) == top)
	assert_int(removed.size()).is_equal(1)
	assert_int(_engine.effective_cost(_hand_card(top), SIDE_PLAYER)).is_equal(SPELL_3_COST)


func test_insight_on_an_empty_deck_is_no_target_then_one_fatigue_hit() -> void:
	# Arrange
	_main_phase(ROW_25)
	_set_deck([])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	assert_array(_of_type(events, "enchantment_applied")).is_empty()
	assert_int(_of_type(events, "fatigue_damage").size()).is_equal(1)
	var ops: Array = _resolved_of(events, ROW_25)[0].ops
	assert_str(str(ops[0].outcome)).is_equal(EffectOps.NO_TARGET)
	assert_str(str(ops[1].outcome)).is_equal(EffectOps.FATIGUE)


func test_a_buff_without_cost_on_a_deck_card_is_skipped() -> void:
	# Arrange — C5 Legal targets: a card instance takes `cost` only
	_main_phase(DECK_ATTACK_POWER)
	var top: int = _set_deck([SPELL_3])[0]
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	assert_array(_of_type(events, "enchantment_applied")).is_empty()
	var op: Dictionary = _resolved_of(events, DECK_ATTACK_POWER)[0].ops[0]
	assert_str(str(op.outcome)).is_equal(EffectOps.NO_TARGET)
	assert_array(op.values.skipped).is_equal([top])
