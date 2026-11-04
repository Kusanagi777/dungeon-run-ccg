## card-effects story 010 — Discover and Choose One: the `ChoiceRequest`, the
## resolver's plain-data continuation and `resume` (design/gdd/card-effects.md
## C5 `discover` / `choose_one` / `add_to_hand`, C6.6, C8, F4, Edge Cases
## "Choices"; AC-10, AC-11, AC-12; ADR-0007 Decision 1: the resolver keeps its
## continuation in `state.effects.pending_choice`, the engine owns `Choice`;
## QA plan sprint 4 NC-2: match-rules 016's after-cast rule through the real
## resolver).
##
## The engine is the real `RulesEngine` from `MatchFactory`'s config with a
## `TestRngService` and `TestEventLog`, bound to the real `EffectResolver`,
## over inline hosts and a fake database whose `collectible_pool("war")` is a
## 40-card War MVP pool holding 9 spells (F4's example). Event names are
## match-rules C15's (DD-X04) plus this GDD's `discover_offered` /
## `discover_picked` / `effect_resolved`.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const HERO_SET: String = "war"
## AC-10: "cast with seed 7".
const AC10_SEED: int = 7
## F4's example pool: 40 cards, 9 of them spells.
const POOL_SIZE: int = 40
const POOL_SPELLS: int = 9
const DAMAGE: int = 2
const MEND: int = 4

## Row 20 ("Discover a spell") on a War spell, so the caster is one of the
## pool's 9 spells and F4 removes it (8 candidates).
const ROW_20: String = "war_test_study"
## Row 21 ("Whenever you cast a spell, draw a card"), C11 fixture text.
const ROW_21: String = "knowledge_fx_row_21_scribe"
## Row 33 (Choose One — Deal 2 damage to a character; or Restore 4 Health to it).
const ROW_33: String = "neutral_fx_row_33_smite_or_mend"
## NC-2's host: `[discover(list of 3, then add_to_hand), damage(enemy_hero, 2)]`.
const SCOUT: String = "neutral_test_scout"
## `[discover(list, filter spell) — 2 of 4 match]`.
const PAIR: String = "neutral_test_pair"
## `[discover(list, filter cost 9) — none match, armor 1]`.
const NONE_MATCH: String = "neutral_test_none_match"
## `[discover(deck), armor 1]`.
const FROM_DECK: String = "neutral_test_from_deck"
## `[add_to_hand(card_id vanilla), discover(list of 3)]` — the pick lands on a full hand.
const FILLER: String = "neutral_test_filler"
## `repeat 2 × discover(list of 3)` (C8.4).
const TWICE: String = "neutral_test_twice"
## `[choose_one [armor 2 | draw 1], damage(enemy_hero, 1)]`.
const PICK_ONE: String = "neutral_test_pick_one"
## Two `cast` effects: `discover(list of 3)`, then `armor 3`.
const TWO_STEP: String = "neutral_test_two_step"
## `discover(list of 3 minions, then summon)`.
const CALLER: String = "neutral_test_caller"
## `discover(list of 3)` with `DISCOVER_EXCLUDE_HAND` set.
const PICKY: String = "neutral_test_picky"
## `add_to_hand from {pool: collectible, filter: spell}, count 2` (C5, F4 pick of 1).
const GIFT: String = "neutral_test_gift"
## "After you cast a spell, gain 1 Armor".
const AFTER_CASTER: String = "neutral_test_after_caster"
const VANILLA: String = "neutral_test_vanilla"
## The `list` pools: three minions and one more spell.
const OPTION_IDS: Array[String] = ["neutral_test_opt_a", "neutral_test_opt_b", "neutral_test_opt_c"]
const OPTION_SPELL: String = "neutral_test_opt_spell"


## `has` / `card` / `hero_power` / `collectible_pool` from maps (the engine
## and the resolver ask nothing else in a match).
class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}
	var pools: Dictionary = {}
	var pool_queries: Array[String] = []

	func _init(by_id: Dictionary, pools_by_set: Dictionary) -> void:
		records = by_id
		pools = pools_by_set

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		return records.get(id)

	func hero_power(id: String) -> Variant:
		return records.get(id)

	func collectible_pool(hero_set: String) -> Array:
		pool_queries.append(hero_set)
		return pools.get(hero_set, [])


var _engine: RulesEngine = null
var _log: TestEventLog = null
var _db: FakeCardDatabase = null


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null
	_log = null
	_db = null


# --- fixtures --------------------------------------------------------------------

func _effects_config(overrides: Dictionary = {}) -> Dictionary:
	var config: Dictionary = {
		"discover_count": float(TestConstants.DISCOVER_COUNT),
		"discover_exclude_hand": false,
		"max_ops_per_effect": float(TestConstants.MAX_OPS_PER_EFFECT),
		"max_repeat": float(TestConstants.MAX_REPEAT),
		"max_summon_count": float(TestConstants.BOARD_SIZE),
		"effect_static_step_limit": float(TestConstants.EFFECT_STATIC_STEP_LIMIT),
		"spell_damage_default": "auto",
		"hooks_before_triggers": true,
	}
	config.merge(overrides, true)
	return config


func _fx(json_text: String) -> Array:
	var parsed: Variant = JSON.parse_string(json_text)
	assert_bool(parsed != null).override_failure_message("fixture JSON does not parse: %s" % json_text).is_true()
	return parsed if parsed is Array else [parsed]


func _list_json() -> String:
	return JSON.stringify(OPTION_IDS)


## The 40-card War pool: 31 minions and 9 spells (row 20 among them), ids
## ascending as `collectible_pool` returns them (CR-6).
func _war_pool(by_id: Dictionary) -> Array:
	var pool: Array = []
	for i: int in POOL_SIZE - POOL_SPELLS:
		pool.append(CardFactory.make_minion("war_test_minion_%02d" % i, 1 + i % 5, 1, 1, [], {"set": HERO_SET}))
	for i: int in POOL_SPELLS - 1:
		pool.append(CardFactory.make_spell("war_test_spell_%02d" % i, 1 + i % 4, [], {"set": HERO_SET}))
	pool.append(by_id[ROW_20])
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for record: Dictionary in pool:
		by_id[record.id] = record
	return pool


func _make_db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	var flat: JSON = load("res://tests/fixtures/cards_effects_test.json")
	for record: Dictionary in flat.data:
		by_id[record.id] = record
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	by_id[VANILLA] = CardFactory.make_minion(VANILLA, 1, 1, 1)
	for id: String in OPTION_IDS:
		by_id[id] = CardFactory.make_minion(id, 1, 1, 1)
	by_id[OPTION_SPELL] = CardFactory.make_spell(OPTION_SPELL, 1)
	var row_20: Dictionary = (by_id["knowledge_fx_row_20_study"] as Dictionary).duplicate(true)
	row_20.id = ROW_20
	row_20.set = HERO_SET
	by_id[ROW_20] = row_20
	var list: String = _list_json()
	by_id[SCOUT] = CardFactory.make_spell(SCOUT, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":%s,"then":"add_to_hand"},' % list
		+ '{"op":"damage","targets":"enemy_hero","amount":%d}]}' % DAMAGE))
	by_id[PAIR] = CardFactory.make_spell(PAIR, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":["%s","%s","%s","%s"],"filter":{"type":"spell"}}]}'
		% [OPTION_IDS[0], "neutral_test_bolt", OPTION_SPELL, OPTION_IDS[1]]))
	by_id[NONE_MATCH] = CardFactory.make_spell(NONE_MATCH, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":%s,"filter":{"cost_eq":9}},' % list
		+ '{"op":"armor","amount":1}]}'))
	by_id[FROM_DECK] = CardFactory.make_spell(FROM_DECK, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"discover","pool":"deck"},{"op":"armor","amount":1}]}'))
	by_id[FILLER] = CardFactory.make_spell(FILLER, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"add_to_hand","card_id":"%s"},{"op":"discover","pool":"list","list":%s}]}' % [VANILLA, list]))
	by_id[TWICE] = CardFactory.make_spell(TWICE, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"repeat","times":2,"ops":[{"op":"discover","pool":"list","list":%s}]}]}' % list))
	by_id[PICK_ONE] = CardFactory.make_spell(PICK_ONE, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"choose_one","options":[{"label_key":"opt.wall","ops":[{"op":"armor","amount":2}]},'
		+ '{"label_key":"opt.read","ops":[{"op":"draw","count":1}]}]},{"op":"damage","targets":"enemy_hero","amount":1}]}'))
	by_id[TWO_STEP] = CardFactory.make_spell(TWO_STEP, 1, _fx(
		'[{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":%s}]},' % list
		+ '{"trigger":"cast","ops":[{"op":"armor","amount":3}]}]'))
	by_id[CALLER] = CardFactory.make_spell(CALLER, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":%s,"then":"summon"}]}' % list))
	by_id[PICKY] = CardFactory.make_spell(PICKY, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":%s}]}' % list))
	by_id[GIFT] = CardFactory.make_spell(GIFT, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"add_to_hand","from":{"pool":"collectible","filter":{"type":"spell"}},"count":2}]}'))
	by_id[AFTER_CASTER] = CardFactory.make_minion(AFTER_CASTER, 1, 1, 3, [], {"effects": _fx(
		'{"trigger":"after_cast","ops":[{"op":"armor","targets":"owner","amount":1}]}')})
	var pools: Dictionary = {HERO_SET: _war_pool(by_id)}
	return FakeCardDatabase.new(by_id, pools)


## A started engine bound to a real `EffectResolver` for the War hero set,
## past a keep-all mulligan (player Main, turn 1), the player's hand replaced
## by [param hand], 10 mana.
func _main_phase(hand: Array, seed_value: int = TestConstants.DEFAULT_TEST_SEED, effects_overrides: Dictionary = {}) -> RulesEngine:
	_db = _make_db()
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(seed_value), _log)
	_engine = RulesEngine.new(_db, MatchFactory.make_rules_config(), EffectResolver.new(_db, _effects_config(effects_overrides), HERO_SET))
	_engine.start(config)
	_submit(_engine.legal_commands()[0])
	_set_hand(SIDE_PLAYER, hand)
	return _engine


func _set_hand(side: String, hand: Array) -> void:
	var state: MatchState = _engine.state()
	var cards: Array = state.players[side].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[side].mana_current = 10
	state.players[side].mana_max = 10


func _put(side: String, def_id: String, attack: int, health: int) -> int:
	return int(MatchFactory.summon(_engine.state(), side, attack, health, -1, [], def_id).entity_id)


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


func _cast(hand_index: int = 0, target: Variant = null) -> void:
	_submit(MatchRecords.play_card(SIDE_PLAYER, hand_index, null, target))


func _since(from_seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq)


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return str(e.type))


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


func _seq_of(events: Array, type: String) -> int:
	var found: Array = _of_type(events, type)
	assert_int(found.size()).override_failure_message("expected one %s, found %d" % [type, found.size()]).is_equal(1)
	return int(found[0].seq) if found.size() == 1 else -1


func _stream() -> TestRngStream:
	return _engine.rng_match()


func _hand_ids(side: String = SIDE_PLAYER) -> Array:
	return (_engine.state().players[side].hand as Array).map(func(c: Dictionary) -> String: return str(c.def_id))


func _continuation() -> Variant:
	return _engine.state().effects.pending_choice


func _choose(index: int, side: String = SIDE_PLAYER) -> void:
	_submit(MatchRecords.choose(side, index))


# --- AC-10: row 20, F4 draws, the event pairing ---------------------------------------

func test_row_20_discover_offers_three_distinct_spells_from_f4_draws() -> void:
	# Arrange
	_main_phase([ROW_20], AC10_SEED)
	var stream: TestRngStream = _stream()
	var calls_before: int = stream.calls.size()
	var draws_before: int = stream.draws
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — in Choice, exactly 3 draws randi_range(0,7), (0,6), (0,5)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	var calls: Array = stream.calls.slice(calls_before)
	assert_array(calls.map(func(c: Dictionary) -> Array: return [c.method, c.args])).is_equal([
		["randi_range", [0, 7]], ["randi_range", [0, 6]], ["randi_range", [0, 5]]])
	var events: Array = _since(before)
	var offered: Array = _of_type(events, "discover_offered")
	assert_int(offered.size()).is_equal(1)
	var ids: Array = offered[0].payload.option_card_ids
	GameAssertions.assert_no_duplicates(ids, "option_card_ids")
	assert_int(ids.size()).is_equal(3)
	for id: Variant in ids:
		assert_str(str(_db.card(str(id)).type)).is_equal("spell")
		assert_str(str(id)).is_not_equal(ROW_20)
	# F4 replayed: the id-ascending candidates without the caster, three draws with removal
	var candidates: Array = []
	for record: Dictionary in _db.pools[HERO_SET]:
		if str(record.type) == "spell" and str(record.id) != ROW_20:
			candidates.append(str(record.id))
	var replay: TestRngStream = TestRngService.new(AC10_SEED).stream(stream.name)
	replay.restore(draws_before)
	var expected: Array = []
	for _i: int in 3:
		var j: int = replay.randi_range(0, candidates.size() - 1)
		expected.append(candidates[j])
		candidates.remove_at(j)
	assert_array(ids).is_equal(expected)
	assert_str(str(offered[0].payload.kind)).is_equal(MatchRecords.CHOICE_DISCOVER)
	assert_str(str(offered[0].payload.side)).is_equal(SIDE_PLAYER)
	assert_bool(_db.pool_queries.has(HERO_SET)).is_true()
	# choice_requested, then discover_offered; no effect_resolved yet (the pass is suspended)
	assert_int(_seq_of(events, "choice_requested")).is_less(int(offered[0].seq))
	assert_array(_of_type(events, "effect_resolved")).is_empty()


func test_row_20_choose_one_puts_the_pick_in_hand_under_one_cause_seq() -> void:
	# Arrange
	_main_phase([ROW_20], AC10_SEED)
	var before: int = _last_seq()
	_cast()
	var offered: Dictionary = _of_type(_since(before), "discover_offered")[0]
	var pick: String = str(offered.payload.option_card_ids[1])
	var draws_paused: int = _stream().draws

	# Act
	_choose(1)

	# Assert — the pick is in hand; choice_made, then discover_picked, then the hand-add
	var events: Array = _since(before)
	assert_bool(_hand_ids().has(pick)).is_true()
	assert_int(_stream().draws).is_equal(draws_paused)
	var made: int = _seq_of(events, "choice_made")
	var picked: int = _seq_of(events, "discover_picked")
	var added: Array = _of_type(events, "card_added_to_hand")
	assert_int(made).is_less(picked)
	assert_int(added.size()).is_equal(1)
	assert_int(picked).is_less(int(added[0].seq))
	assert_str(str(added[0].payload.card_id)).is_equal(pick)
	var picked_event: Dictionary = _of_type(events, "discover_picked")[0]
	assert_int(int(picked_event.payload.picked_index)).is_equal(1)
	assert_str(str(picked_event.payload.picked_card_id)).is_equal(pick)
	# all four under one cause_seq (card-effects Interactions: DD-X04 pairing)
	var cause: int = int(_of_type(events, "choice_requested")[0].cause_seq)
	for type: String in ["choice_requested", "discover_offered", "choice_made", "discover_picked"]:
		assert_int(int(_of_type(events, type)[0].cause_seq)).override_failure_message(type).is_equal(cause)
	assert_int(cause).is_equal(int(_of_type(events, "spell_cast")[0].seq))
	# one effect_resolved, after the pick, with the discover op applied
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_int(resolved.size()).is_equal(1)
	assert_int(int(resolved[0].seq)).is_greater(int(added[0].seq))
	assert_str(str(resolved[0].payload.ops[0].op)).is_equal("discover")
	assert_str(str(resolved[0].payload.ops[0].outcome)).is_equal(EffectOps.APPLIED)
	assert_that(_continuation()).is_null()
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MAIN)


# --- AC-11: fewer candidates, none, empty deck, full hand ------------------------------

func test_a_filter_matching_two_offers_two_with_two_draws() -> void:
	# Arrange
	_main_phase([PAIR])
	var stream: TestRngStream = _stream()
	var calls_before: int = stream.calls.size()
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	var offered: Array = _of_type(_since(before), "discover_offered")
	assert_int(offered.size()).is_equal(1)
	var ids: Array = offered[0].payload.option_card_ids
	ids.sort()
	assert_array(ids).is_equal(["neutral_test_bolt", OPTION_SPELL])
	assert_int(stream.calls.slice(calls_before).size()).is_equal(2)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_CHOICE)


func test_a_filter_matching_none_is_empty_pool_with_no_choice_and_the_next_op_runs() -> void:
	# Arrange
	_main_phase([NONE_MATCH])
	var calls_before: int = _stream().calls.size()
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	var events: Array = _since(before)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_array(_of_type(events, "choice_requested")).is_empty()
	assert_array(_of_type(events, "discover_offered")).is_empty()
	assert_int(_stream().calls.size()).is_equal(calls_before)
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_int(resolved.size()).is_equal(1)
	assert_str(str(resolved[0].payload.ops[0].outcome)).is_equal(EffectOps.EMPTY_POOL)
	assert_str(str(resolved[0].payload.ops[1].op)).is_equal("armor")
	assert_str(str(resolved[0].payload.ops[1].outcome)).is_equal(EffectOps.APPLIED)
	assert_int(_of_type(events, "armor_gained").size()).is_equal(1)


func test_a_deck_pool_on_an_empty_deck_is_empty_pool_without_fatigue() -> void:
	# Arrange
	_main_phase([FROM_DECK])
	(_engine.state().players[SIDE_PLAYER].deck as Array).clear()
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	var events: Array = _since(before)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_array(_of_type(events, "fatigue_damage")).is_empty()
	assert_array(_of_type(events, "choice_requested")).is_empty()
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_str(str(resolved[0].payload.ops[0].outcome)).is_equal(EffectOps.EMPTY_POOL)
	assert_str(str(resolved[0].payload.ops[1].outcome)).is_equal(EffectOps.APPLIED)


func test_a_pick_into_a_full_hand_is_still_a_pick_and_burns() -> void:
	# Arrange — the spell plus 9 cards; its first op refills the hand to 10
	var hand: Array = [FILLER]
	for _i: int in TestConstants.HAND_SIZE - 1:
		hand.append(VANILLA)
	_main_phase(hand)
	var before: int = _last_seq()
	_cast()
	assert_int((_engine.state().players[SIDE_PLAYER].hand as Array).size()).is_equal(TestConstants.HAND_SIZE)

	# Act
	_choose(0)

	# Assert
	var events: Array = _since(before)
	assert_int(_of_type(events, "discover_picked").size()).is_equal(1)
	var burned: Array = _of_type(events, "card_burned")
	assert_int(burned.size()).is_equal(1)
	assert_str(str(burned[0].payload.card_id)).is_equal(OPTION_IDS[0])
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_str(str(resolved[0].payload.ops[1].op)).is_equal("discover")
	assert_str(str(resolved[0].payload.ops[1].outcome)).is_equal(EffectOps.BURNED)


# --- AC-12: Choose One (row 33) and a repeat around a discover ---------------------------

func _cast_row_33_on_enemy_3_3() -> Array:
	_main_phase([ROW_33])
	var enemy: int = _put(SIDE_BOSS, VANILLA, 3, 3)
	var minion: Dictionary = EffectSelectors.find(_engine.state(), enemy)
	minion.damage_taken = 1
	var before: int = _last_seq()
	_cast(0, enemy)
	return [enemy, before]


func test_row_33_choose_zero_smites_for_two_and_heals_nothing() -> void:
	# Arrange
	var fixture: Array = _cast_row_33_on_enemy_3_3()
	var enemy: int = fixture[0]
	var offered: Array = _of_type(_since(fixture[1]), "discover_offered")

	# Act
	_choose(0)

	# Assert
	assert_int(offered.size()).is_equal(1)
	assert_str(str(offered[0].payload.kind)).is_equal(MatchRecords.CHOICE_CHOOSE_ONE)
	assert_array(offered[0].payload.option_label_keys).is_equal(["opt.smite", "opt.mend"])
	var events: Array = _since(fixture[1])
	var dealt: Array = _of_type(events, "damage_dealt")
	assert_int(dealt.size()).is_equal(1)
	assert_int(int(dealt[0].payload.target)).is_equal(enemy)
	assert_int(int(dealt[0].payload.dealt)).is_equal(DAMAGE)
	assert_array(_of_type(events, "healed")).is_empty()
	var picked: Array = _of_type(events, "discover_picked")
	assert_str(str(picked[0].payload.picked_label_key)).is_equal("opt.smite")


func test_row_33_choose_one_mends_and_deals_no_damage() -> void:
	# Arrange
	var fixture: Array = _cast_row_33_on_enemy_3_3()
	var enemy: int = fixture[0]

	# Act
	_choose(1)

	# Assert
	var events: Array = _since(fixture[1])
	var healed: Array = _of_type(events, "healed")
	assert_int(healed.size()).is_equal(1)
	assert_int(int(healed[0].payload.target)).is_equal(enemy)
	assert_int(int(healed[0].payload.requested)).is_equal(MEND)
	assert_array(_of_type(events, "damage_dealt")).is_empty()


func test_a_repeat_around_a_discover_makes_sequential_choices() -> void:
	# Arrange
	_main_phase([TWICE])
	var before: int = _last_seq()
	_cast()
	assert_int(_of_type(_since(before), "choice_requested").size()).is_equal(1)

	# Act 1 — the first choose raises the second request
	_choose(0)

	# Assert 1 — one request outstanding again, the first pick in hand, no effect_resolved yet
	var events: Array = _since(before)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_int(_of_type(events, "choice_requested").size()).is_equal(2)
	assert_int(_of_type(events, "discover_picked").size()).is_equal(1)
	assert_int(int(_of_type(events, "discover_picked")[0].seq)).is_less(int(_of_type(events, "choice_requested")[1].seq))
	assert_array(_of_type(events, "effect_resolved")).is_empty()

	# Act 2
	_choose(2)

	# Assert 2 — both picks, one effect_resolved with both discover entries
	events = _since(before)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_int(_of_type(events, "card_added_to_hand").size()).is_equal(2)
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_int(resolved.size()).is_equal(1)
	assert_array((resolved[0].payload.ops as Array).map(func(e: Dictionary) -> String: return str(e.op))).is_equal(["discover", "discover"])


# --- NC-2: the after-cast rule through the real resolver ------------------------------------

func test_discover_spell_resumes_remaining_ops_once_then_engine_after_cast() -> void:
	# Arrange
	_main_phase([SCOUT])
	var scribe: int = _put(SIDE_PLAYER, ROW_21, 2, 2)
	var after_caster: int = _put(SIDE_PLAYER, AFTER_CASTER, 1, 3)
	var boss_hero: Dictionary = _engine.state().players[SIDE_BOSS].hero
	var boss_health: int = _engine.health(boss_hero)
	var before: int = _last_seq()

	# Act 1
	_cast()

	# Assert while paused
	var events: Array = _since(before)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_array(_of_type(events, "effect_resolved")).is_empty()
	var pending: Dictionary = _continuation()
	assert_int(int(pending.op_index)).is_equal(0)
	assert_str(str(pending.remaining_ops[0].op.op)).is_equal("damage")
	assert_array(_of_type(events, "damage_dealt")).is_empty()
	assert_int(_engine.health(boss_hero)).is_equal(boss_health)
	assert_int((_engine.state().players[SIDE_PLAYER].resolving as Array).size()).is_equal(1)
	assert_array(_of_type(events, "card_to_graveyard")).is_empty()
	assert_array(_of_type(events, "trigger_queued")).is_empty()
	assert_array(_of_type(events, "card_drawn")).is_empty()
	GameAssertions.assert_json_representable(_engine.state().effects, "state.effects")
	assert_bool(EffectRuntime.is_runtime(_engine.state().effects)).is_true()
	var draws_paused: int = _stream().draws

	# Act 2
	_choose(0)

	# Assert — seq order: discover_picked, hand-add, damage, one effect_resolved, then the C6.3 tail
	events = _since(before)
	assert_int(_stream().draws).is_equal(draws_paused)
	var picked: int = _seq_of(events, "discover_picked")
	var added: int = _seq_of(events, "card_added_to_hand")
	var dealt: int = _seq_of(events, "damage_dealt")
	var resolved_events: Array = _of_type(events, "effect_resolved")
	var host_resolved: Array = resolved_events.filter(func(e: Dictionary) -> bool: return str(e.payload.host_id) == SCOUT)
	assert_int(host_resolved.size()).is_equal(1)
	var resolved: Dictionary = host_resolved[0]
	assert_array((resolved.payload.ops as Array).map(func(e: Dictionary) -> Array: return [str(e.op), str(e.outcome)])).is_equal([
		["discover", EffectOps.APPLIED], ["damage", EffectOps.APPLIED]])
	var triggers: Array = _of_type(events, "trigger_resolved")
	var scribe_step: Array = triggers.filter(func(e: Dictionary) -> bool: return int(e.payload.source_id) == scribe)
	var after_step: Array = triggers.filter(func(e: Dictionary) -> bool: return int(e.payload.source_id) == after_caster)
	assert_int(scribe_step.size()).is_equal(1)
	assert_int(after_step.size()).is_equal(1)
	assert_str(str(scribe_step[0].payload.point)).is_equal("on_card_played")
	assert_str(str(after_step[0].payload.point)).is_equal("after_cast")
	var drawn: int = _seq_of(events, "card_drawn")
	var to_graveyard: int = _seq_of(events, "card_to_graveyard")
	assert_int(picked).is_less(added)
	assert_int(added).is_less(dealt)
	assert_int(dealt).is_less(int(resolved.seq))
	assert_int(int(resolved.seq)).is_less(int(scribe_step[0].seq))
	assert_int(int(scribe_step[0].seq)).is_less(drawn)
	assert_int(drawn).is_less(int(after_step[0].seq))
	assert_int(int(after_step[0].seq)).is_less(to_graveyard)
	assert_int(int(_of_type(events, "damage_dealt")[0].payload.dealt)).is_equal(DAMAGE)
	assert_array(_engine.state().players[SIDE_PLAYER].resolving).is_empty()
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MAIN)


func test_choose_one_option_ops_run_inline_then_rest_of_effect() -> void:
	# Arrange
	_main_phase([PICK_ONE])
	var before: int = _last_seq()
	_cast()

	# Act
	_choose(0)

	# Assert — the option's armor, then the effect's next op, then one effect_resolved
	var events: Array = _since(before)
	var armor: int = _seq_of(events, "armor_gained")
	var dealt: int = _seq_of(events, "damage_dealt")
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_int(resolved.size()).is_equal(1)
	assert_int(armor).is_less(dealt)
	assert_int(dealt).is_less(int(resolved[0].seq))
	assert_array(_of_type(events, "card_drawn")).is_empty()
	assert_array((resolved[0].payload.ops as Array).map(func(e: Dictionary) -> String: return str(e.op))).is_equal(["choose_one", "armor", "damage"])
	assert_int(int(resolved[0].payload.ops[0].values.picked_index)).is_equal(0)


func test_concede_during_choice_drops_continuation() -> void:
	# Arrange
	_main_phase([SCOUT])
	var before: int = _last_seq()
	_cast()

	# Act
	_submit(MatchRecords.concede(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	assert_array(_of_type(events, "discover_picked")).is_empty()
	assert_array(_of_type(events, "effect_resolved")).is_empty()
	var ended: Array = _of_type(events, "match_ended")
	assert_int(ended.size()).is_equal(1)
	assert_str(str(_engine.result().reason)).is_equal("concede")
	assert_that(_continuation()).is_null()


# --- the continuation's other seams -----------------------------------------------------------

func test_a_later_cast_effect_of_the_same_host_runs_after_choose() -> void:
	# Arrange
	_main_phase([TWO_STEP])
	var before: int = _last_seq()
	_cast()
	assert_array(_of_type(_since(before), "armor_gained")).is_empty()

	# Act
	_choose(1)

	# Assert — effect 0 resolves, then effect 1 runs once
	var events: Array = _since(before)
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_int(resolved.size()).is_equal(2)
	assert_str(str(resolved[0].payload.ops[0].op)).is_equal("discover")
	assert_str(str(resolved[1].payload.ops[0].op)).is_equal("armor")
	assert_int(_of_type(events, "armor_gained").size()).is_equal(1)
	assert_int(int(_of_type(events, "card_added_to_hand")[0].seq)).is_less(int(_of_type(events, "armor_gained")[0].seq))


func test_discover_then_summon_puts_the_pick_on_the_board() -> void:
	# Arrange
	_main_phase([CALLER])
	var before: int = _last_seq()
	_cast()
	var pick: String = str(_of_type(_since(before), "discover_offered")[0].payload.option_card_ids[2])

	# Act
	_choose(2)

	# Assert
	var events: Array = _since(before)
	var summoned: Array = _of_type(events, "minion_summoned")
	assert_int(summoned.size()).is_equal(1)
	assert_str(str(summoned[0].payload.card_id)).is_equal(pick)
	assert_array(_of_type(events, "card_added_to_hand")).is_empty()
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_array(resolved[0].payload.ops[0].targets).is_equal([int(summoned[0].payload.entity_id)])


func test_discover_exclude_hand_drops_a_def_id_already_held() -> void:
	# Arrange — option a is held; the knob is on
	_main_phase([PICKY, OPTION_IDS[0]], TestConstants.DEFAULT_TEST_SEED, {"discover_exclude_hand": true})
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — 2 candidates left, both offered
	var offered: Array = _of_type(_since(before), "discover_offered")
	var ids: Array = offered[0].payload.option_card_ids
	ids.sort()
	assert_array(ids).is_equal([OPTION_IDS[1], OPTION_IDS[2]])


func test_add_to_hand_from_a_pool_draws_one_pick_per_copy() -> void:
	# Arrange
	_main_phase([GIFT])
	var stream: TestRngStream = _stream()
	var calls_before: int = stream.calls.size()
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — two randi_range over the 9 spells (the caster is not in the War pool), two hand-adds
	var events: Array = _since(before)
	assert_array(stream.calls.slice(calls_before).map(func(c: Dictionary) -> Array: return [c.method, c.args])).is_equal([
		["randi_range", [0, POOL_SPELLS - 1]], ["randi_range", [0, POOL_SPELLS - 1]]])
	var added: Array = _of_type(events, "card_added_to_hand")
	assert_int(added.size()).is_equal(2)
	for event: Dictionary in added:
		assert_str(str(_db.card(str(event.payload.card_id)).type)).is_equal("spell")
	assert_array(_of_type(events, "choice_requested")).is_empty()
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_str(str(resolved[0].payload.ops[0].op)).is_equal("add_to_hand")
	assert_str(str(resolved[0].payload.ops[0].outcome)).is_equal(EffectOps.APPLIED)


func test_a_boss_discover_is_the_boss_choice_and_still_offers_its_options() -> void:
	# Arrange — the boss's turn, row-20-shaped list Discover in its hand
	_main_phase([])
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	_set_hand(SIDE_BOSS, [PICKY])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_BOSS, 0, null, null))

	# Assert — the boss chooses; the player is refused; options ride on discover_offered
	var offered: Array = _of_type(_since(before), "discover_offered")
	assert_int(offered.size()).is_equal(1)
	assert_str(str(offered[0].payload.side)).is_equal(SIDE_BOSS)
	assert_str(str(_engine.pending_choice().side)).is_equal(SIDE_BOSS)
	assert_str(str(_continuation().side)).is_equal(SIDE_BOSS)
	var refused: Dictionary = _engine.submit(MatchRecords.end_turn(SIDE_PLAYER))
	assert_bool(refused.accepted).is_false()
	_choose(0, SIDE_BOSS)
	assert_bool(_hand_ids(SIDE_BOSS).has(str(offered[0].payload.option_card_ids[0]))).is_true()
