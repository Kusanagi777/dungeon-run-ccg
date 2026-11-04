## card-effects story 007 — value expressions, conditions, Spell Damage (F1),
## area and random selectors (F5), `conditional` / `repeat` and the per-turn
## tallies (design/gdd/card-effects.md C3, C4, C5, F1, F5, Edge Cases
## "Targeting and selection" / "Resolution order and the queue"; AC-13,
## AC-14, AC-23, AC-24; ADR-0007 Decision 7: draws only through
## `engine.rng_match()`).
##
## The engine is the real `RulesEngine` from `MatchFactory`'s config with a
## `TestRngService` (its `match_<floor>` stream is a seeded `TestRngStream`,
## whose recorded `randi_range` calls count the F5 draws) and `TestEventLog`,
## bound to the real `EffectResolver`, over the committed C11 fixture rows 18,
## 19, 22, 34, 44 and the inline hosts below. Event names are match-rules
## C15's (DD-X04): the AC's `damage_dealt.amount` is C15's `damage_dealt
## {requested, dealt}` — the hits here have no shield or armour, so the two
## are equal and both are asserted.
extends GdUnitTestSuite

const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
const ROW_18: String = "knowledge_fx_row_18_bolt"
const ROW_19: String = "knowledge_fx_row_19_storm"
const ROW_22: String = "knowledge_fx_row_22_hoarder"
const ROW_34: String = "neutral_fx_row_34_twin_pinger"
const ROW_44: String = "power_fx_row_44_brand"
const VANILLA: String = "neutral_test_vanilla"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS

## Inline hosts (test-only defs; ids carry their set prefix, CR-2).
## A 1/3 Spell Damage +1 minion (match-rules F7 reads `CardDef.spell_damage`).
const SD_ONE: String = "knowledge_test_spell_damage_one"
## Battlecry: deal `1 − 3` to the enemy hero — a negative computed amount.
const NEGATIVE_PING: String = "war_test_negative_ping"
## Battlecry: gain Armor equal to the number of other friendly minions.
const COUNTER: String = "war_test_count_friends"
## Battlecry (`chosen` minion): 2 damage to it, 1 to its neighbours.
const SPLASH: String = "war_test_splash"
## Battlecry: if you played a card this turn, gain 2 Armor (per-turn tally).
const COMBO: String = "war_test_combo"
## Battlecry: `conditional` — if the enemy has a minion, 1 damage to all
## enemy minions, else 3 Armor.
const BRANCH: String = "war_test_branch"
## Review S4: spells that `buff cost -1` the `{selector: hand, n}` picks.
const HAND_ONE: String = "war_test_hand_one"
const HAND_TWO: String = "war_test_hand_two"
const HAND_NINE: String = "war_test_hand_nine"
const HAND_ALL: String = "war_test_hand_all"
## `buff` two `hand` picks, then Armor equal to `{count: {hand, n: 2}}`.
const HAND_COUNTED: String = "war_test_hand_counted"
## Cards beside the cast spell in the S4 fixture (review P11).
const HAND_OTHERS: int = 3
## Seeds whose first draw differs (the same seed repeats its pick).
const HAND_SEED_A: int = 1
const HAND_SEED_B: int = 2
## How far the pick-order case looks for a seed that runs against hand order.
const HAND_SEED_SEARCH: int = 30


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
	by_id[SD_ONE] = CardFactory.make_minion(SD_ONE, 1, 1, 3, ["spell_damage"], {"set": "knowledge", "spell_damage": 1})
	by_id[NEGATIVE_PING] = CardFactory.make_minion(NEGATIVE_PING, 1, 1, 1, ["battlecry"], {"set": "war", "effects": _fx(
		'{"trigger":"battlecry","targets":"enemy_hero","ops":[{"op":"damage","amount":{"sub":[1,3]}}]}')})
	by_id[COUNTER] = CardFactory.make_minion(COUNTER, 1, 1, 1, ["battlecry"], {"set": "war", "effects": _fx(
		'{"trigger":"battlecry","ops":[{"op":"armor","targets":"owner","amount":{"count":{"selector":"all_friendly_minions","filter":{"not_self":true}}}}]}')})
	by_id[SPLASH] = CardFactory.make_minion(SPLASH, 1, 1, 1, ["battlecry"], {"set": "war", "effects": _fx(
		'{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"damage","amount":2},'
		+ '{"op":"damage","amount":1,"targets":{"selector":"adjacent","of":"target"}}]}')})
	by_id[COMBO] = CardFactory.make_minion(COMBO, 1, 1, 1, ["battlecry"], {"set": "war", "effects": _fx(
		'{"trigger":"battlecry","condition":{"cmp":[{"ref":"owner.cards_played_this_turn"},">=",1]},"ops":[{"op":"armor","targets":"owner","amount":2}]}')})
	by_id[BRANCH] = CardFactory.make_minion(BRANCH, 1, 1, 1, ["battlecry"], {"set": "war", "effects": _fx(
		'{"trigger":"battlecry","ops":[{"op":"conditional","if":{"exists":"all_enemy_minions"},'
		+ '"then":[{"op":"damage","amount":1,"targets":"all_enemy_minions"}],"else":[{"op":"armor","targets":"owner","amount":3}]}]}')})
	for pair: Array in [[HAND_ONE, ',"n":1'], [HAND_TWO, ',"n":2'], [HAND_NINE, ',"n":9'], [HAND_ALL, ""]]:
		by_id[pair[0]] = CardFactory.make_spell(pair[0], 1, _fx(
			'{"trigger":"cast","targets":{"selector":"hand"%s},"ops":[{"op":"buff","cost":-1}]}' % pair[1]), {"set": "war"})
	by_id[HAND_COUNTED] = CardFactory.make_spell(HAND_COUNTED, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"buff","cost":-1,"targets":{"selector":"hand","n":2}},'
		+ '{"op":"armor","targets":"owner","amount":{"count":{"selector":"hand","n":2}}}]}'), {"set": "war"})
	return FakeCardDatabase.new(by_id)


## A started engine bound to a real `EffectResolver`, past a keep-all
## mulligan (player Main, turn 1), the hand replaced by [param hand], 10 mana.
func _main_phase(hand: Array, seed_value: int = TestConstants.DEFAULT_TEST_SEED) -> RulesEngine:
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(seed_value), _log)
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	_engine.start(config)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	_set_hand(SIDE_PLAYER, hand)
	return _engine


## Replaces [param side]'s hand with fresh instances of [param hand] and gives it 10 mana.
func _set_hand(side: String, hand: Array) -> void:
	var state: MatchState = _engine.state()
	var cards: Array = state.players[side].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[side].mana_current = 10


func _put(side: String, def_id: String, attack: int, health: int, keywords: Array = []) -> int:
	return int(MatchFactory.summon(_engine.state(), side, attack, health, -1, keywords, def_id).entity_id)


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


func _since(from_seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq)


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


## The `effect_resolved` payloads of [param events] whose host is [param host_id].
func _resolved_of(events: Array, host_id: String) -> Array:
	return _of_type(events, "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.host_id) == host_id).map(
		func(e: Dictionary) -> Dictionary: return e.payload)


func _rng_draws() -> int:
	return (_engine.rng_match() as TestRngStream).count_calls("randi_range")


func _hero(side: String) -> int:
	return int(_engine.state().players[side].hero.entity_id)


# --- AC-13: F1 scales spells only, re-read per op ----------------------------------

func test_a_hero_power_deal_1_does_not_scale_with_spell_damage() -> void:
	# Arrange — row 44 and two Spell Damage +1 minions.
	_main_phase([])
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = ROW_44
	_put(SIDE_PLAYER, SD_ONE, 1, 3, ["spell_damage"])
	_put(SIDE_PLAYER, SD_ONE, 1, 3, ["spell_damage"])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, _hero(SIDE_BOSS)))

	# Assert
	var dealt: Array = _of_type(_since(before), "damage_dealt")
	assert_int(dealt.size()).is_equal(1)
	assert_int(int(dealt[0].payload.requested)).is_equal(1)
	assert_int(int(dealt[0].payload.dealt)).is_equal(1)


func test_a_spell_deal_3_scales_with_two_spell_damage_minions_to_5() -> void:
	# Arrange — row 18 instead.
	_main_phase([ROW_18])
	_put(SIDE_PLAYER, SD_ONE, 1, 3, ["spell_damage"])
	_put(SIDE_PLAYER, SD_ONE, 1, 3, ["spell_damage"])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, _hero(SIDE_BOSS)))

	# Assert
	var events: Array = _since(before)
	var dealt: Array = _of_type(events, "damage_dealt")
	assert_int(int(dealt[0].payload.requested)).is_equal(5)
	assert_int(int(dealt[0].payload.dealt)).is_equal(5)
	var ops: Array = _resolved_of(events, ROW_18)[0].ops
	assert_int(int(ops[0].values.requested)).is_equal(5)
	assert_int(int(ops[0].values.amount)).is_equal(3)


# --- AC-14: area damage, scaled once per op, canonical order ------------------------

func test_row_19_deals_3_to_each_enemy_minion_left_to_right_then_the_hero() -> void:
	# Arrange — +1 Spell Damage, three enemy minions.
	_main_phase([ROW_19])
	_put(SIDE_PLAYER, SD_ONE, 1, 3, ["spell_damage"])
	var enemies: Array[int] = []
	for _i: int in 3:
		enemies.append(_put(SIDE_BOSS, VANILLA, 1, 5))
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null))

	# Assert
	var dealt: Array = _of_type(_since(before), "damage_dealt")
	assert_array(dealt.map(func(e: Dictionary) -> int: return int(e.payload.target))).is_equal([enemies[0], enemies[1], enemies[2], _hero(SIDE_BOSS)])
	assert_array(dealt.map(func(e: Dictionary) -> int: return int(e.payload.dealt))).is_equal([3, 3, 3, 3])


# --- AC-23: turn_end condition and one random draw --------------------------------

func test_row_22_with_four_cards_fizzles_condition_false_and_deals_nothing() -> void:
	# Arrange
	_main_phase([VANILLA, VANILLA, VANILLA, VANILLA])
	_put(SIDE_PLAYER, ROW_22, 2, 2)
	var draws: int = _rng_draws()
	var before: int = _last_seq()

	# Act — the owner's End step
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	var resolved: Array = _resolved_of(events, ROW_22)
	assert_int(resolved.size()).is_equal(1)
	assert_str(str(resolved[0].fizzled)).is_equal("condition_false")
	assert_array(_of_type(events, "damage_dealt")).is_empty()
	assert_int(_rng_draws()).is_equal(draws)


func test_row_22_with_five_cards_hits_one_random_enemy_character_with_one_draw() -> void:
	# Arrange — one enemy minion, so the random pool is [minion, enemy hero].
	_main_phase([VANILLA, VANILLA, VANILLA, VANILLA, VANILLA])
	_put(SIDE_PLAYER, ROW_22, 2, 2)
	var enemy: int = _put(SIDE_BOSS, VANILLA, 1, 5)
	var draws: int = _rng_draws()
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	var resolved: Array = _resolved_of(events, ROW_22)
	assert_that(resolved[0].fizzled).is_null()
	var dealt: Array = _of_type(events, "damage_dealt")
	assert_int(dealt.size()).is_equal(1)
	assert_int(int(dealt[0].payload.dealt)).is_equal(3)
	assert_array([enemy, _hero(SIDE_BOSS)]).contains([int(dealt[0].payload.target)])
	assert_int(_rng_draws() - draws).is_equal(1)


# --- AC-24: repeat re-selects live; negative computed amounts clamp ---------------

func test_row_34_repeat_kills_the_only_enemy_minion_then_finds_no_target() -> void:
	# Arrange — row 34 on the player's board, one 1-health enemy minion;
	# reach the player's next Start step.
	_main_phase([])
	_put(SIDE_PLAYER, ROW_34, 2, 2)
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	var enemy: int = _put(SIDE_BOSS, VANILLA, 1, 1)
	var before: int = _last_seq()

	# Act — the boss ends its turn: the player's Start step
	_submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert — two entries, `applied` then `no_target`; the hero is never hit
	var events: Array = _since(before)
	var resolved: Array = _resolved_of(events, ROW_34)
	assert_int(resolved.size()).is_equal(1)
	var ops: Array = resolved[0].ops
	assert_array(ops.map(func(o: Dictionary) -> String: return str(o.outcome))).is_equal(["applied", "no_target"])
	assert_array(ops[0].targets).is_equal([enemy])
	var targets: Array = _of_type(events, "damage_dealt").map(func(e: Dictionary) -> int: return int(e.payload.target))
	assert_array(targets).is_equal([enemy])
	assert_array(_of_type(events, "minion_died").map(func(e: Dictionary) -> int: return int(e.payload.entity_id))).is_equal([enemy])


func test_a_negative_computed_damage_amount_is_clamped_to_0_and_logged() -> void:
	# Arrange — `amount: {sub: [1, 3]}` = −2.
	_main_phase([NEGATIVE_PING])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert — apply_damage(…, 0) still called (C5), clamped_from −2 logged
	var events: Array = _since(before)
	var op: Dictionary = _resolved_of(events, NEGATIVE_PING)[0].ops[0]
	assert_int(int(op.values.amount)).is_equal(0)
	assert_int(int(op.values.clamped_from)).is_equal(-2)
	var dealt: Array = _of_type(events, "damage_dealt")
	assert_int(dealt.size()).is_equal(1)
	assert_int(int(dealt[0].payload.requested)).is_equal(0)


# --- C3 / C4 / C5 beyond the four ACs ------------------------------------------------

func test_a_count_value_counts_other_friendly_minions() -> void:
	# Arrange — two minions already on board.
	_main_phase([COUNTER])
	_put(SIDE_PLAYER, VANILLA, 1, 1)
	_put(SIDE_PLAYER, VANILLA, 1, 1)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert — `not_self` excludes the host
	var gained: Array = _of_type(_since(before), "armor_gained")
	assert_int(int(gained[0].payload.amount)).is_equal(2)


func test_adjacent_of_target_hits_the_chosen_minions_neighbours_only() -> void:
	# Arrange — enemy board [A, B, C]; chosen B.
	_main_phase([SPLASH])
	var a: int = _put(SIDE_BOSS, VANILLA, 1, 5)
	var b: int = _put(SIDE_BOSS, VANILLA, 1, 5)
	var c: int = _put(SIDE_BOSS, VANILLA, 1, 5)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, b))

	# Assert
	var dealt: Array = _of_type(_since(before), "damage_dealt").map(func(e: Dictionary) -> Array: return [int(e.payload.target), int(e.payload.dealt)])
	assert_array(dealt).is_equal([[b, 2], [a, 1], [c, 1]])


func test_a_per_turn_tally_counts_cards_played_this_turn() -> void:
	# Arrange — first COMBO with nothing played, then another after a card.
	_main_phase([COMBO, VANILLA, COMBO])
	var before: int = _last_seq()

	# Act — COMBO first (tally 0), VANILLA, then COMBO (tally 2)
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert
	var resolved: Array = _resolved_of(_since(before), COMBO)
	assert_array(resolved.map(func(p: Dictionary) -> Variant: return p.fizzled)).is_equal(["condition_false", null])
	assert_dict(_engine.state().effects.per_turn).is_equal({SIDE_PLAYER: {"cards_played_this_turn": 3}})


func test_per_turn_tallies_reset_at_that_sides_start_step() -> void:
	# Arrange — the player plays one card, then both turns pass.
	_main_phase([VANILLA])
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	assert_int(int(_engine.state().effects.per_turn[SIDE_PLAYER].cards_played_this_turn)).is_equal(1)

	# Act
	_submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	assert_bool(_engine.state().effects.per_turn.has(SIDE_PLAYER)).is_false()


func test_conditional_logs_the_branch_not_taken_as_skipped() -> void:
	# Arrange — one enemy minion: the `then` branch runs.
	_main_phase([BRANCH, BRANCH])
	var enemy: int = _put(SIDE_BOSS, VANILLA, 1, 5)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert — one entry per inner op: then `applied`, else `skipped`
	var ops: Array = _resolved_of(_since(before), BRANCH)[0].ops
	assert_array(ops.map(func(o: Dictionary) -> Array: return [str(o.op), str(o.outcome)])).is_equal([["damage", "applied"], ["armor", "skipped"]])
	assert_array(ops[0].targets).is_equal([enemy])
	assert_bool(bool(ops[0].values.condition)).is_true()


# --- sprint-4 review S4: `hand` honours `n` (C3 "`n` (random) or `all`", F5) ---------

## The cast spell's `{selector: hand, …}` host at hand index 0 and
## [param others] vanilla cards after it. Returns the others' instance ids, in
## hand order; they are what the selector's pool holds once the spell resolves.
func _hand_fixture(spell: String, others: int = HAND_OTHERS, seed_value: int = TestConstants.DEFAULT_TEST_SEED) -> Array:
	var hand: Array = [spell]
	for _i: int in others:
		hand.append(VANILLA)
	_main_phase(hand, seed_value)
	var ids: Array = (_engine.state().players[SIDE_PLAYER].hand as Array).map(func(c: Dictionary) -> int: return int(c.instance_id))
	return ids.slice(1)


func _cast_first() -> Array:
	var before: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null))
	return _since(before)


func _buff_entry(events: Array) -> Dictionary:
	for event: Dictionary in _of_type(events, "effect_resolved"):
		for entry: Dictionary in event.payload.ops:
			if str(entry.op) == "buff":
				return entry
	return {}


## The hand position of the one card seed [param seed_value] picks.
func _picked_position(seed_value: int) -> int:
	var ids: Array = _hand_fixture(HAND_ONE, HAND_OTHERS, seed_value)
	var targets: Array = Array(_buff_entry(_cast_first()).get("targets", []))
	assert_int(targets.size()).is_equal(1)
	var position: int = ids.find(int(targets[0])) if targets.size() == 1 else -1
	_engine.end_match()
	return position


func test_hand_with_n_1_targets_exactly_one_card_with_one_draw() -> void:
	# Arrange — P11: three other cards in hand
	var ids: Array = _hand_fixture(HAND_ONE)
	var draws: int = _rng_draws()

	# Act
	var events: Array = _cast_first()

	# Assert
	var targets: Array = Array(_buff_entry(events).get("targets", []))
	assert_int(targets.size()).is_equal(1)
	assert_bool(ids.has(int(targets[0]) if targets.size() == 1 else -1)).is_true()
	assert_int(_rng_draws() - draws).is_equal(1)


func test_two_seeds_pick_different_hand_cards_and_one_seed_repeats_its_pick() -> void:
	# Act
	var first: int = _picked_position(HAND_SEED_A)
	var second: int = _picked_position(HAND_SEED_B)
	var repeat: int = _picked_position(HAND_SEED_A)

	# Assert
	assert_int(first).is_not_equal(second)
	assert_int(repeat).is_equal(first)


func test_hand_with_n_at_or_above_the_pool_takes_every_card_with_that_many_draws() -> void:
	# Arrange
	var ids: Array = _hand_fixture(HAND_NINE)
	var draws: int = _rng_draws()

	# Act
	var events: Array = _cast_first()

	# Assert — F5: k = min(n, |cands|) draws, so a whole-pool pick still draws
	assert_array(Array(_buff_entry(events).get("targets", []))).contains_exactly_in_any_order(ids)
	assert_int(_rng_draws() - draws).is_equal(ids.size())


func test_hand_without_n_targets_the_whole_hand_in_order_and_draws_nothing() -> void:
	# Arrange
	var ids: Array = _hand_fixture(HAND_ALL)
	var draws: int = _rng_draws()

	# Act
	var events: Array = _cast_first()

	# Assert — C3 "default all"
	assert_array(Array(_buff_entry(events).get("targets", []))).is_equal(ids)
	assert_int(_rng_draws() - draws).is_equal(0)


func test_hand_with_n_on_an_empty_hand_is_no_target_and_draws_nothing() -> void:
	# Arrange — the cast spell is the only card, and it has left the hand
	@warning_ignore("return_value_discarded")
	_hand_fixture(HAND_ONE, 0)
	var draws: int = _rng_draws()

	# Act
	var events: Array = _cast_first()

	# Assert
	assert_str(str(_buff_entry(events).get("outcome", ""))).is_equal(EffectOps.NO_TARGET)
	assert_int(_rng_draws() - draws).is_equal(0)


## F5 replayed on a copy of the match stream over [param ids]: two picks with
## removal, in pick order.
func _replayed_two_picks(ids: Array) -> Array:
	var replay: RngStream = (_engine.rng_match() as RngStream).copy()
	var cands: Array = ids.duplicate()
	var picks: Array = []
	for _i: int in 2:
		var j: int = replay.randi_range(0, cands.size() - 1)
		picks.append(cands[j])
		cands.remove_at(j)
	return picks


func test_hand_picks_apply_in_pick_order_not_hand_order() -> void:
	# Arrange — the first seed whose two draws run against hand order
	var expected: Array = []
	for seed_value: int in range(1, HAND_SEED_SEARCH):
		var ids: Array = _hand_fixture(HAND_TWO, HAND_OTHERS, seed_value)
		expected = _replayed_two_picks(ids)
		if int(expected[0]) > int(expected[1]):
			break
		_engine.end_match()
	assert_int(int(expected[0])).is_greater(int(expected[1]))

	# Act
	var events: Array = _cast_first()

	# Assert — F5 output: the op applies in the order the dice fell
	assert_array(Array(_buff_entry(events).get("targets", []))).is_equal(expected)


func test_a_count_over_hand_with_n_agrees_with_what_the_selector_targets() -> void:
	# Arrange
	@warning_ignore("return_value_discarded")
	_hand_fixture(HAND_COUNTED)

	# Act
	var events: Array = _cast_first()

	# Assert — one spell, one selector: `pick_count` and `entities` say the same
	var armor: int = int(_engine.state().players[SIDE_PLAYER].hero.armor)
	assert_int(armor).is_equal(Array(_buff_entry(events).get("targets", [])).size())
	assert_int(armor).is_equal(2)
