## card-effects story 001 — DSL spike on the five hardest effect types
## (Pre-Production gate entry condition 6; AC-S1).
##
## Each effect object is the C11 row's DSL text from design/gdd/card-effects.md
## pasted verbatim and parsed with `JSON.parse_string`, exactly as the loader
## will read it (numbers arrive as floats). Everything runs headless against the
## spike stub engine with an injected fixed-seed or scripted stream; no Node, no
## scene. Event order is asserted on the log double (DD-T04).
extends GdUnitTestSuite

# Spike code: written under src/gameplay/effects/spike/, moved here at close
# (story AC-S3) so no throwaway code stays in a production path.
const SpikeStubEngine := preload("res://tests/unit/card_effects/spike/spike_stub_engine.gd")
const SpikeEffectResolver := preload("res://tests/unit/card_effects/spike/spike_effect_resolver.gd")

# --- C11 rows, verbatim -------------------------------------------------------
const ROW_16_ROT: String = '{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"damage","amount":1},{"op":"conditional","if":{"test":["target",{"is_dying":true}]},"then":[{"op":"summon","card_id":"decay_husk","position":"end"}]}]}'
const ROW_20_DISCOVER: String = '{"trigger":"cast","ops":[{"op":"discover","pool":"collectible","filter":{"type":"spell"}}]}'
const ROW_26_LORD: String = '{"trigger":"aura","targets":{"selector":"all_friendly_minions","filter":{"not_self":true}},"ops":[{"op":"aura","attack":1,"health":1}]}'
const ROW_27_ADJACENT: String = '{"trigger":"aura","targets":"adjacent","ops":[{"op":"aura","attack":2}]}'
const ROW_33_CHOOSE_ONE: String = '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"choose_one","options":[{"label_key":"opt.smite","ops":[{"op":"damage","amount":2}]},{"label_key":"opt.mend","ops":[{"op":"heal","amount":4}]}]}]}'
const ROW_45_COUNTER: String = '[{"trigger":"on_minion_died","scope":{"who":"any_minion"},"ops":[{"op":"add_counter","key":"seen","amount":1}]}, {"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"counter.seen"}}]}]'
# Row 7's Deathrattle shape on a minion: lets row 16 show the Husk arrives first.
const ROW_7_DEATHRATTLE: String = '{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":2}]}'
# Row 3's shape as a Deathrattle: kills row 45 between its raise and its add_counter.
const PROBE_DEATHRATTLE_AOE: String = '{"trigger":"deathrattle","targets":"all_enemy_minions","ops":[{"op":"damage","amount":2}]}'
# C8.4 probe (not a C11 row): a `repeat` around a `discover`.
const PROBE_REPEAT_DISCOVER: String = '{"trigger":"cast","ops":[{"op":"repeat","times":2,"ops":[{"op":"discover","pool":"collectible","filter":{"type":"spell"}}]}]}'
# AC-11 probes: a Discover whose filter matches 0 cards, then a following op.
const PROBE_EMPTY_DISCOVER: String = '{"trigger":"cast","ops":[{"op":"discover","pool":"collectible","filter":{"type":"weapon"}},{"op":"add_to_hand","card_id":"war_pool_minion_01"}]}'
const PROBE_LIST_DISCOVER: String = '{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":["war_pool_spell_01","war_pool_spell_02"]}]}'

# --- Fixture ids --------------------------------------------------------------
const SPELL_DISCOVER: String = "war_study"
const SPELL_CHOOSE_ONE: String = "neutral_test_choose_one"
const SPELL_REPEAT_DISCOVER: String = "knowledge_test_double_discover"
const SPELL_EMPTY_DISCOVER: String = "knowledge_test_empty_discover"
const SPELL_LIST_DISCOVER: String = "knowledge_test_list_discover"
const POWER_ROT: String = "hero_decay_rot"
const HUSK: String = "decay_husk"
const VANILLA: String = "neutral_test_vanilla_1_1"
const VANILLA_2_2: String = "neutral_test_vanilla_2_2"
const DIVINE_SHIELD: String = "neutral_test_divine_shield"
const DEATHRATTLE_2_1: String = "neutral_test_deathrattle_2_1"
const COUNTER_MINION: String = "neutral_test_death_counter"
const DEATHRATTLE_AOE: String = "neutral_test_deathrattle_aoe"
const LORD: String = "neutral_test_aura_lord"
const ADJACENT: String = "neutral_test_adjacent_aura"
## War MVP pool for AC-10: 40 cards, 9 spells (the casting spell is one of them).
const POOL_MINIONS: int = 31
const POOL_SPELLS_OTHER: int = 8
const SEED_AC_10: int = 7

var _engine: SpikeStubEngine = null
var _log: TestEventLog = null
var _rng: TestRngStream = null
var _state: Dictionary = {}


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null


# --- Row 20: Discover a spell (AC-10, AC-11) ----------------------------------

func test_row20_discover_offers_three_distinct_spells_and_pauses_in_choice() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	# Act
	_engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_DISCOVER)
	# Assert
	var offered: Dictionary = _log.first(&"discover_offered").payload
	var options: Array = offered.option_card_ids
	assert_int(options.size()).is_equal(TestConstants.DISCOVER_COUNT)
	GameAssertions.assert_no_duplicates(options)
	for id: Variant in options:
		assert_str(String(id)).is_not_equal(SPELL_DISCOVER)
		assert_str(String(_db().cards[String(id)].type)).is_equal("spell")
	assert_str(_engine.phase()).is_equal(SpikeStubEngine.PHASE_CHOICE)
	assert_int(_rng.draws).is_equal(TestConstants.DISCOVER_COUNT)
	EventLogAssertions.assert_order(_log, [&"spell_cast", &"choice_requested", &"discover_offered"])
	EventLogAssertions.assert_count(_log, &"effect_resolved", 0)
	# C8.1 / ADR-0007: the continuation is plain data in MatchState.effects.
	assert_bool(_state.effects.pending_choice != null).is_true()
	GameAssertions.assert_json_representable(_state.effects, "EffectRuntime")


func test_row20_choose_one_puts_picked_card_in_hand_after_discover_picked() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	_engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_DISCOVER)
	var options: Array = _log.first(&"discover_offered").payload.option_card_ids
	# Act
	var result: Dictionary = _engine.choose(1)
	# Assert
	assert_bool(bool(result.accepted)).is_true()
	var hand: Array = _state.players[MatchFactory.SIDE_PLAYER].hand
	assert_int(hand.size()).is_equal(1)
	assert_str(String(hand[0].def_id)).is_equal(String(options[1]))
	EventLogAssertions.assert_consecutive(_log, [&"choice_made", &"discover_picked", &"card_added_to_hand", &"effect_resolved"])
	assert_int(_rng.draws).is_equal(TestConstants.DISCOVER_COUNT)  # C8.1: no draw while waiting or on resume
	assert_str(_engine.phase()).is_equal(SpikeStubEngine.PHASE_MAIN)
	assert_bool(_state.effects.pending_choice == null).is_true()


func test_row20_scripted_draws_follow_f4_ranges_over_id_ascending_candidates() -> void:
	# Arrange — F4 example: 8 candidates, draws randi_range(0,7), (0,6), (0,5)
	var script: Array[int] = [3, 0, 5]
	_build(TestRngStream.scripted("match_1", script))
	# Act
	_engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_DISCOVER)
	# Assert — candidates war_pool_spell_01..08: 3 -> _04; 0 -> _01; 5 of [02,03,05,06,07,08] -> _08
	var options: Array = _log.first(&"discover_offered").payload.option_card_ids
	assert_array(options).is_equal(["war_pool_spell_04", "war_pool_spell_01", "war_pool_spell_08"])
	var ranges: Array = []
	for call: Dictionary in _rng.calls:
		ranges.append(call.args)
	assert_array(ranges).is_equal([[0, 7], [0, 6], [0, 5]])


func test_discover_with_two_candidates_offers_two() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	# Act
	_engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_LIST_DISCOVER)
	# Assert
	assert_int((_log.first(&"discover_offered").payload.option_card_ids as Array).size()).is_equal(2)
	assert_int(_rng.draws).is_equal(2)


func test_discover_with_zero_candidates_is_empty_pool_and_next_op_runs() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	# Act
	_engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_EMPTY_DISCOVER)
	# Assert
	EventLogAssertions.assert_not_contains_type(_log, &"choice_requested")
	assert_str(_engine.phase()).is_equal(SpikeStubEngine.PHASE_MAIN)
	var ops: Array = _log.first(&"effect_resolved").payload.ops
	assert_str(String(ops[0].outcome)).is_equal("empty_pool")
	assert_str(String(ops[1].outcome)).is_equal("applied")
	assert_int((_state.players[MatchFactory.SIDE_PLAYER].hand as Array).size()).is_equal(1)
	assert_int(_rng.draws).is_equal(0)


# --- Row 33: Choose One (AC-12) -----------------------------------------------

func test_row33_choose_zero_deals_two_and_no_heal() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	var target: Dictionary = _spike_summon(_state, MatchFactory.SIDE_BOSS, 3, 3, -1, [], VANILLA)
	_engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_CHOOSE_ONE, int(target.entity_id))
	# Act
	_engine.choose(0)
	# Assert — card-effects AC-12 writes `damage_dealt{amount: 2}`; match-rules C15 names the field `dealt`
	EventLogAssertions.assert_payload(_log, &"damage_dealt", {"target": int(target.entity_id), "requested": 2, "dealt": 2})
	EventLogAssertions.assert_not_contains_type(_log, &"healed")
	EventLogAssertions.assert_payload(_log, &"discover_offered", {"kind": "choose_one", "option_label_keys": ["opt.smite", "opt.mend"]})
	EventLogAssertions.assert_order(_log, [&"choice_requested", &"discover_offered", &"choice_made", &"discover_picked", &"damage_dealt", &"effect_resolved"])
	assert_int(_rng.draws).is_equal(0)


func test_row33_choose_one_heals_and_no_damage() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	var target: Dictionary = _spike_summon(_state, MatchFactory.SIDE_BOSS, 3, 3, -1, [], VANILLA)
	_engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_CHOOSE_ONE, int(target.entity_id))
	# Act
	_engine.choose(1)
	# Assert — the option's op used the effect-level `chosen` target (C8.3)
	EventLogAssertions.assert_payload(_log, &"healed", {"target": int(target.entity_id)})
	EventLogAssertions.assert_not_contains_type(_log, &"damage_dealt")


func test_choice_pending_rejects_a_second_command_one_request_outstanding() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	_engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_DISCOVER)
	var draws_before: int = _rng.draws
	# Act
	var second: Dictionary = _engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_DISCOVER)
	# Assert
	assert_bool(bool(second.accepted)).is_false()
	assert_str(String(second.rejection.code)).is_equal("CHOICE_PENDING")
	EventLogAssertions.assert_count(_log, &"choice_requested", 1)
	assert_int(_rng.draws).is_equal(draws_before)


func test_repeat_around_discover_produces_sequential_choices() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	_engine.cast_spell(MatchFactory.SIDE_PLAYER, SPELL_REPEAT_DISCOVER)
	EventLogAssertions.assert_count(_log, &"choice_requested", 1)
	# Act
	_engine.choose(0)
	EventLogAssertions.assert_count(_log, &"choice_requested", 2)
	assert_str(_engine.phase()).is_equal(SpikeStubEngine.PHASE_CHOICE)
	_engine.choose(2)
	# Assert
	EventLogAssertions.assert_count(_log, &"discover_picked", 2)
	EventLogAssertions.assert_count(_log, &"effect_resolved", 1)
	assert_int((_state.players[MatchFactory.SIDE_PLAYER].hand as Array).size()).is_equal(2)
	assert_int(_rng.draws).is_equal(2 * TestConstants.DISCOVER_COUNT)


# --- Row 16: Rot, `is_dying` inside one pass (AC-43) ---------------------------

func test_row16_rot_on_2_1_summons_husk_before_target_dies() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	_spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], VANILLA_2_2)
	var target: Dictionary = _spike_summon(_state, MatchFactory.SIDE_BOSS, 2, 1, -1, [], DEATHRATTLE_2_1)
	# Act
	_engine.use_hero_power(MatchFactory.SIDE_PLAYER, POWER_ROT, int(target.entity_id))
	# Assert — one pass (C6.0): no event between the ops, the death check after
	EventLogAssertions.assert_consecutive(_log, [&"damage_dealt", &"minion_summoned", &"effect_resolved"])
	EventLogAssertions.assert_order(_log, [&"hero_power_used", &"damage_dealt", &"minion_summoned", &"effect_resolved", &"minion_died", &"trigger_resolved", &"damage_dealt"])
	EventLogAssertions.assert_payload(_log, &"minion_summoned", {"card_id": HUSK, "side": MatchFactory.SIDE_PLAYER, "board_index": 1})
	var resolved: Dictionary = _log.first(&"effect_resolved").payload
	assert_str(String(resolved.ops[1].outcome)).is_equal("applied")
	assert_str(String(_engine.trace[0].kind)).is_equal("pass")
	assert_str(String(_engine.trace[1].kind)).is_equal("death_check")


func test_row16_rot_on_2_3_damages_only_and_summons_nothing() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	var target: Dictionary = _spike_summon(_state, MatchFactory.SIDE_BOSS, 2, 3, -1, [], VANILLA)
	# Act
	_engine.use_hero_power(MatchFactory.SIDE_PLAYER, POWER_ROT, int(target.entity_id))
	# Assert
	EventLogAssertions.assert_payload(_log, &"damage_dealt", {"dealt": 1})
	EventLogAssertions.assert_not_contains_type(_log, &"minion_summoned")
	EventLogAssertions.assert_not_contains_type(_log, &"minion_died")
	assert_str(String(_log.first(&"effect_resolved").payload.ops[1].outcome)).is_equal("skipped")


func test_row16_rot_on_divine_shield_1_1_pops_shield_and_summons_nothing() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	var target: Dictionary = _spike_summon(_state, MatchFactory.SIDE_BOSS, 1, 1, -1, ["divine_shield"], DIVINE_SHIELD)
	# Act
	_engine.use_hero_power(MatchFactory.SIDE_PLAYER, POWER_ROT, int(target.entity_id))
	# Assert
	EventLogAssertions.assert_contains_type(_log, &"divine_shield_popped")
	EventLogAssertions.assert_not_contains_type(_log, &"damage_dealt")
	EventLogAssertions.assert_not_contains_type(_log, &"minion_summoned")
	assert_str(String(_log.first(&"effect_resolved").payload.ops[1].outcome)).is_equal("skipped")


# --- Row 45: counter + snapshot Deathrattle (AC-46) ---------------------------

func test_row45_deathrattle_deals_damage_equal_to_snapshot_counter() -> void:
	# Arrange — three minions (either side) die while row 45 is in play
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	var counter: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], COUNTER_MINION)
	var victims: Array = [
		_spike_summon(_state, MatchFactory.SIDE_PLAYER, 1, 1, -1, [], VANILLA),
		_spike_summon(_state, MatchFactory.SIDE_BOSS, 1, 1, -1, [], VANILLA),
		_spike_summon(_state, MatchFactory.SIDE_BOSS, 1, 1, -1, [], VANILLA),
	]
	for victim: Dictionary in victims:
		_engine.destroy(int(victim.entity_id))
	_engine.settle()
	EventLogAssertions.assert_count(_log, &"counter_changed", victims.size())
	# Act
	_engine.destroy(int(counter.entity_id))
	_engine.settle()
	# Assert
	var boss_hero: int = int(_state.players[MatchFactory.SIDE_BOSS].hero.entity_id)
	EventLogAssertions.assert_order(_log, [&"minion_died", &"trigger_queued", &"trigger_resolved", &"damage_dealt", &"effect_resolved"])
	EventLogAssertions.assert_payload(_log, &"damage_dealt", {"target": boss_hero, "dealt": victims.size()})
	var last_resolved: Dictionary = _log.of_type(&"effect_resolved").back().payload
	assert_str(String(last_resolved.trigger)).is_equal("deathrattle")
	assert_str(String(last_resolved.ops[0].values.read_from)).is_equal("snapshot")
	assert_int(int(last_resolved.ops[0].values.amount)).is_equal(victims.size())


func test_row45_counter_raised_before_death_but_resolved_after_is_not_in_snapshot() -> void:
	# Arrange — boss minion B dies; Q gets [B's Deathrattle, row 45's add_counter].
	# B's Deathrattle kills row 45 before its add_counter resolves, so row 45's
	# own Deathrattle is raised (snapshot taken) with seen == 0, and the late
	# add_counter then raises the live bucket to 1. C6.5 as written: snapshot wins.
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	var counter: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], COUNTER_MINION)
	var killer: Dictionary = _spike_summon(_state, MatchFactory.SIDE_BOSS, 1, 1, -1, [], DEATHRATTLE_AOE)
	# Act
	_engine.destroy(int(killer.entity_id))
	_engine.settle()
	# Assert
	var boss_hero: int = int(_state.players[MatchFactory.SIDE_BOSS].hero.entity_id)
	EventLogAssertions.assert_payload(_log, &"counter_changed", {"source_id": int(counter.entity_id), "value": 1})
	var final_hit: Dictionary = _log.of_type(&"damage_dealt").back().payload
	assert_int(int(final_hit.target)).is_equal(boss_hero)
	assert_int(int(final_hit.dealt)).is_equal(0)


func test_row45_new_instance_counter_starts_at_zero() -> void:
	# Arrange — a death seen by the first instance must not leak to a new entity
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	var first: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], COUNTER_MINION)
	var victim: Dictionary = _spike_summon(_state, MatchFactory.SIDE_BOSS, 1, 1, -1, [], VANILLA)
	_engine.destroy(int(victim.entity_id))
	_engine.settle()
	_engine.destroy(int(first.entity_id))
	_engine.settle()
	var second: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], COUNTER_MINION)
	var damage_before: int = _log.count(&"damage_dealt")
	# Act
	_engine.destroy(int(second.entity_id))
	_engine.settle()
	# Assert
	assert_int(_log.count(&"damage_dealt")).is_equal(damage_before + 1)
	assert_int(int(_log.of_type(&"damage_dealt").back().payload.dealt)).is_equal(0)


# --- Rows 26 + 27: stacked auras (AC-26) --------------------------------------

func test_rows26_27_stacked_auras_give_ac26_stats() -> void:
	# Arrange — friendly board [26, 26, vanilla 1/1, 27]
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	var lord_a: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], LORD)
	var lord_b: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], LORD)
	var vanilla: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 1, 1, -1, [], VANILLA)
	var adjacent: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], ADJACENT)
	# Act
	_engine.settle()
	# Assert — AC-26 numbers are the point of the test
	_assert_stats(vanilla, 5, 3)
	_assert_stats(lord_a, 3, 3)
	_assert_stats(lord_b, 3, 3)
	_assert_stats(adjacent, 4, 4)
	EventLogAssertions.assert_count(_log, &"auras_recomputed", 1)


func test_row27_adjacency_follows_neighbour_change_and_recompute_is_idempotent() -> void:
	# Arrange
	_build(TestRngStream.seeded("match_1", SEED_AC_10))
	var lord_a: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], LORD)
	var lord_b: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], LORD)
	var vanilla: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 1, 1, -1, [], VANILLA)
	var adjacent: Dictionary = _spike_summon(_state, MatchFactory.SIDE_PLAYER, 2, 2, -1, [], ADJACENT)
	_engine.settle()
	# Act — the 1/1 dies: row 27's left neighbour becomes lord B
	_engine.destroy(int(vanilla.entity_id))
	_engine.settle()
	_engine.settle()
	# Assert
	_assert_stats(lord_a, 3, 3)
	_assert_stats(lord_b, 5, 3)
	_assert_stats(adjacent, 4, 4)
	EventLogAssertions.assert_count(_log, &"auras_recomputed", 2)


# --- Fixture --------------------------------------------------------------------

func _build(rng: TestRngStream) -> void:
	_rng = rng
	_log = TestEventLog.new()
	_state = _spike_match_state({"turn": 1, "phase": MatchFactory.PHASE_MAIN})
	var rules: Dictionary = {
		"BOARD_SIZE": TestConstants.BOARD_SIZE,
		"HAND_SIZE": TestConstants.HAND_SIZE,
		"RESOLUTION_STEP_CAP": TestConstants.RESOLUTION_STEP_CAP,
	}
	var effects_config: Dictionary = {"DISCOVER_COUNT": TestConstants.DISCOVER_COUNT, "DISCOVER_EXCLUDE_HAND": false}
	var db: Dictionary = _db()
	_engine = SpikeStubEngine.new(_state, db, rules, _rng, _log, SpikeEffectResolver.new(db, effects_config))


func _db() -> Dictionary:
	var cards: Dictionary = {}
	var pool: Array = []
	for i: int in range(1, POOL_MINIONS + 1):
		var id: String = "war_pool_minion_%02d" % i
		cards[id] = CardFactory.make_minion(id, 1, 1, 1, [], {"set": "war"})
		pool.append(id)
	for i: int in range(1, POOL_SPELLS_OTHER + 1):
		var id: String = "war_pool_spell_%02d" % i
		cards[id] = CardFactory.make_spell(id, 1, [], {"set": "war"})
		pool.append(id)
	cards[SPELL_DISCOVER] = CardFactory.make_spell(SPELL_DISCOVER, 1, [_parse(ROW_20_DISCOVER)], {"set": "war"})
	pool.append(SPELL_DISCOVER)
	cards[SPELL_CHOOSE_ONE] = CardFactory.make_spell(SPELL_CHOOSE_ONE, 1, [_parse(ROW_33_CHOOSE_ONE)])
	cards[SPELL_REPEAT_DISCOVER] = CardFactory.make_spell(SPELL_REPEAT_DISCOVER, 1, [_parse(PROBE_REPEAT_DISCOVER)])
	cards[SPELL_EMPTY_DISCOVER] = CardFactory.make_spell(SPELL_EMPTY_DISCOVER, 1, [_parse(PROBE_EMPTY_DISCOVER)])
	cards[SPELL_LIST_DISCOVER] = CardFactory.make_spell(SPELL_LIST_DISCOVER, 1, [_parse(PROBE_LIST_DISCOVER)])
	cards[POWER_ROT] = CardFactory.make_hero_power_def(POWER_ROT, [_parse(ROW_16_ROT)])
	cards[HUSK] = CardFactory.make_minion(HUSK, 1, 1, 1, [], {"set": "decay", "token": true, "tags": ["husk"]})
	cards[VANILLA] = CardFactory.make_minion(VANILLA, 1, 1, 1)
	cards[VANILLA_2_2] = CardFactory.make_minion(VANILLA_2_2, 2, 2, 2)
	cards[DIVINE_SHIELD] = CardFactory.make_minion(DIVINE_SHIELD, 1, 1, 1, ["divine_shield"])
	cards[DEATHRATTLE_2_1] = CardFactory.make_minion(DEATHRATTLE_2_1, 2, 2, 1, ["deathrattle"], {"effects": [_parse(ROW_7_DEATHRATTLE)]})
	cards[DEATHRATTLE_AOE] = CardFactory.make_minion(DEATHRATTLE_AOE, 1, 1, 1, ["deathrattle"], {"effects": [_parse(PROBE_DEATHRATTLE_AOE)]})
	cards[COUNTER_MINION] =CardFactory.make_minion(COUNTER_MINION, 3, 2, 2, ["deathrattle"], {"effects": _parse(ROW_45_COUNTER)})
	cards[LORD] = CardFactory.make_minion(LORD, 3, 2, 2, ["aura"], {"effects": [_parse(ROW_26_LORD)]})
	cards[ADJACENT] = CardFactory.make_minion(ADJACENT, 3, 2, 2, ["aura"], {"effects": [_parse(ROW_27_ADJACENT)]})
	return {"cards": cards, "collectible_pool": pool}


func _parse(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	GameAssertions.fail_if(parsed == null, "C11 DSL text did not parse as JSON: %s" % text)
	return parsed


func _assert_stats(minion: Dictionary, attack: int, health: int) -> void:
	assert_int(MatchFactory.attack_of(minion)).override_failure_message("attack of %s" % minion.def_id).is_equal(attack)
	assert_int(MatchFactory.health_of(minion)).override_failure_message("health of %s" % minion.def_id).is_equal(health)


# --- Spike-local Dictionary-state helpers -------------------------------------
# The spike runs on a plain-Dictionary C1 state (its stub engine predates the
# production `MatchState`, match-rules story 001). These two helpers keep it
# independent of the production type; they mirror MatchFactory as of the spike.

## A Dictionary C1 state at the end of setup (turn 0, Mulligan, both heroes).
static func _spike_match_state(overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"turn": 0,
		"active_side": MatchFactory.SIDE_PLAYER,
		"phase": MatchFactory.PHASE_MULLIGAN,
		"players": {
			MatchFactory.SIDE_PLAYER: MatchFactory.make_player_state(MatchFactory.SIDE_PLAYER),
			MatchFactory.SIDE_BOSS: MatchFactory.make_player_state(MatchFactory.SIDE_BOSS),
		},
		"pending_choice": null,
		"result": null,
		"next_entity_id": MatchFactory.BOSS_HERO_ENTITY_ID + 1,
		"hooks": [],
		"floor": 1,
		"band": 1,
	}
	state.merge(overrides, true)
	return state


## Put a minion on `side`'s board (-1 = rightmost); {} when the board is full.
static func _spike_summon(state: Dictionary, side: String, attack: int, health: int, position: int = -1, keywords: Array = [], def_id: String = "") -> Dictionary:
	var board: Array = state.players[side].board
	if board.size() >= TestConstants.BOARD_SIZE:
		return {}
	var id: int = int(state.next_entity_id)
	state.next_entity_id = id + 1
	var minion: Dictionary = MatchFactory.make_minion(id, side, attack, health, keywords, def_id)
	minion.summoned_on_turn = int(state.turn)
	var index: int = board.size() if position < 0 else clampi(position, 0, board.size())
	board.insert(index, minion)
	state.players[side].stats.minions_summoned += 1
	return minion
