## Self-test for tests/helpers/ — the helpers are verified before any suite
## leans on them. Each failing-path test uses gdUnit4's `assert_failure` so a
## helper is also watched failing, not only passing (test-standards: "a gate
## you have not watched fail is not a gate").
##
## Created by /test-helpers on 2026-11-03. Every number comes from
## TestConstants (the registry mirror) or from a GDD example that the helper
## claims to reproduce; the GDD section is named at each site.
extends GdUnitTestSuite


class Emitter:
	extends RefCounted
	signal fired(value: int)

	func fire() -> void:
		fired.emit(1)


# --- TestConstants -----------------------------------------------------------

func test_band_split_sums_to_floors_per_run() -> void:
	# Arrange / Act
	var total: int = 0
	for s: int in TestConstants.BAND_SPLIT:
		total += s

	# Assert (run-structure F1: s1 + s2 + s3 = floors_per_run)
	assert_int(total).is_equal(TestConstants.FLOORS_PER_RUN)


func test_constants_mirror_registry_values() -> void:
	# Boundary-value check: the exact numbers ARE the point (registry constants:)
	assert_int(TestConstants.BOARD_SIZE).is_equal(7)
	assert_int(TestConstants.HAND_SIZE).is_equal(10)
	assert_int(TestConstants.MAX_MANA_CRYSTALS).is_equal(10)
	assert_int(TestConstants.PLAYER_STARTING_HEALTH).is_equal(30)
	assert_int(TestConstants.STARTING_HAND_PLAYER).is_equal(3)
	assert_int(TestConstants.STARTING_HAND_BOSS).is_equal(4)
	assert_int(TestConstants.HERO_POWER_COST).is_equal(2)
	assert_int(TestConstants.DISCOVER_COUNT).is_equal(3)
	assert_int(TestConstants.FLOORS_PER_RUN).is_equal(8)
	assert_array(TestConstants.BOSS_STARTING_HEALTH_BY_BAND).contains_exactly([30, 40, 50])


# --- GameAssertions ----------------------------------------------------------

func test_fail_if_false_reports_success() -> void:
	assert_failure(func() -> void: GameAssertions.fail_if(false, "never")).is_success()


func test_fail_if_true_reports_failure_with_message() -> void:
	assert_failure(func() -> void: GameAssertions.fail_if(true, "boom-marker")) \
		.is_failed() \
		.contains_message("boom-marker")


func test_assert_in_range_inside_bounds_passes() -> void:
	assert_failure(func() -> void: GameAssertions.assert_in_range(TestConstants.MAX_MANA_CRYSTALS, 1, TestConstants.MAX_MANA_CRYSTALS, "mana")).is_success()


func test_assert_in_range_outside_bounds_fails() -> void:
	assert_failure(func() -> void: GameAssertions.assert_in_range(TestConstants.MAX_MANA_CRYSTALS + 1, 0, TestConstants.MAX_MANA_CRYSTALS, "mana")) \
		.is_failed() \
		.contains_message("mana")


func test_assert_signal_emitted_detects_emission() -> void:
	# Arrange
	var emitter: Emitter = Emitter.new()

	# Act / Assert
	assert_failure(func() -> void: GameAssertions.assert_signal_emitted(emitter, "fired", func() -> void: emitter.fire())).is_success()
	assert_failure(func() -> void: GameAssertions.assert_signal_emitted(emitter, "fired", func() -> void: pass)).is_failed()


func test_assert_signal_not_emitted_fails_when_emitted() -> void:
	# Arrange
	var emitter: Emitter = Emitter.new()

	# Act / Assert
	assert_failure(func() -> void: GameAssertions.assert_signal_not_emitted(emitter, "fired", func() -> void: emitter.fire())).is_failed()
	assert_failure(func() -> void: GameAssertions.assert_signal_not_emitted(emitter, "fired", func() -> void: pass)).is_success()


func test_is_json_representable_follows_rule_14() -> void:
	# rng-event-log rule 14: int, float, bool, String, StringName, null, Array/Dictionary of those
	assert_bool(GameAssertions.is_json_representable({"a": [1, 2.5, true, null, "s", &"n", {"b": []}]})).is_true()
	assert_bool(GameAssertions.is_json_representable({"pos": Vector2(1, 2)})).is_false()
	assert_bool(GameAssertions.is_json_representable([Color.RED])).is_false()
	assert_failure(func() -> void: GameAssertions.assert_json_representable({"pos": Vector2.ZERO}, "payload")) \
		.is_failed() \
		.contains_message("Vector2")


func test_assert_sorted_ascending_fails_on_unsorted() -> void:
	assert_failure(func() -> void: GameAssertions.assert_sorted_ascending(["a", "b", "c"])).is_success()
	assert_failure(func() -> void: GameAssertions.assert_sorted_ascending(["a", "c", "b"])).is_failed()
	assert_failure(func() -> void: GameAssertions.assert_sorted_ascending(["a", "a"])).is_failed()


func test_assert_no_duplicates_fails_on_duplicate() -> void:
	assert_failure(func() -> void: GameAssertions.assert_no_duplicates(["t1", "t2"])).is_success()
	assert_failure(func() -> void: GameAssertions.assert_no_duplicates(["t1", "t1"])).is_failed()


func test_assert_has_keys_names_missing_key() -> void:
	assert_failure(func() -> void: GameAssertions.assert_has_keys({"result": 1, "winner": 2}, ["result", "winner"])).is_success()
	assert_failure(func() -> void: GameAssertions.assert_has_keys({"result": 1}, ["result", "winner"])) \
		.is_failed() \
		.contains_message("winner")


# --- TestRngStream / TestRngService ------------------------------------------

func test_seeded_streams_same_seed_produce_identical_sequence() -> void:
	# Arrange (rng-event-log AC: two services with run_seed = 42, 100 draws each)
	var a: TestRngService = TestRngService.new(TestConstants.DEFAULT_TEST_SEED)
	var b: TestRngService = TestRngService.new(TestConstants.DEFAULT_TEST_SEED)
	var sample: int = 100

	# Act
	var seq_a: Array = []
	var seq_b: Array = []
	for _i: int in range(sample):
		seq_a.append(a.stream("run").randi_range(0, TestRngStream.MAX_RANGE_SPAN - 1))
		seq_b.append(b.stream("run").randi_range(0, TestRngStream.MAX_RANGE_SPAN - 1))

	# Assert
	assert_array(seq_a).is_equal(seq_b)
	assert_int(a.stream("run").draws).is_equal(sample)
	assert_int(b.stream("run").draws).is_equal(sample)
	assert_int(a.stream("match_1").draws).is_zero()


func test_different_seeds_produce_different_sequences() -> void:
	# Arrange
	var a: TestRngStream = TestRngService.new(TestConstants.DEFAULT_TEST_SEED).stream("run")
	var b: TestRngStream = TestRngService.new(TestConstants.DEFAULT_TEST_SEED + 1).stream("run")

	# Act
	var seq_a: Array = []
	var seq_b: Array = []
	for _i: int in range(20):
		seq_a.append(a.randi32())
		seq_b.append(b.randi32())

	# Assert
	assert_array(seq_a).is_not_equal(seq_b)


func test_stream_seed_matches_gdd_f2_examples() -> void:
	# rng-event-log F2 example values for run_seed = 42 and run_seed = 0
	var seed42: int = TestConstants.DEFAULT_TEST_SEED
	assert_str(TestRngStream.to_hex_u64(TestRngStream.stream_seed_for(seed42, "run"))).is_equal(TestConstants.EXPECTED_STREAM_SEED_42_RUN_HEX)
	assert_str(TestRngStream.to_hex_u64(TestRngStream.stream_seed_for(seed42, "match_1"))).is_equal("8E28D71DC7508C82")
	assert_str(TestRngStream.to_hex_u64(TestRngStream.stream_seed_for(seed42, "match_2"))).is_equal("3FC25FB4D7E5C7F5")
	assert_str(TestRngStream.to_hex_u64(TestRngStream.stream_seed_for(seed42, "draft_1"))).is_equal("FFC74EA120AA040F")
	assert_str(TestRngStream.to_hex_u64(TestRngStream.stream_seed_for(seed42, "ai_1"))).is_equal("89527D2C36D9A252")
	assert_str(TestRngStream.to_hex_u64(TestRngStream.stream_seed_for(0, "run"))).is_equal("8AE616A7F56EA560")
	assert_str(TestRngStream.to_hex_u64(TestRngStream.fnv1a64("run".to_utf8_buffer()))).is_not_equal(TestRngStream.to_hex_u64(TestRngStream.fnv1a64("rum".to_utf8_buffer())))


func test_run_seed_from_input_matches_gdd_f1_examples() -> void:
	# rng-event-log F1 examples; run-structure AC-24 restates "deckdelve"
	assert_str(TestRngStream.to_hex_u64(TestRngStream.run_seed_from_input("42"))).is_equal("000000000000002A")
	assert_str(TestRngStream.to_hex_u64(TestRngStream.run_seed_from_input("-1"))).is_equal("FFFFFFFFFFFFFFFF")
	assert_str(TestRngStream.to_hex_u64(TestRngStream.run_seed_from_input("deckdelve"))).is_equal(TestConstants.EXPECTED_RUN_SEED_DECKDELVE_HEX)
	assert_int(TestRngStream.run_seed_from_input(TestConstants.EXPECTED_RUN_SEED_DECKDELVE_HEX)).is_equal(TestRngStream.run_seed_from_input("deckdelve"))
	assert_int(TestRngStream.run_seed_from_input("0x000000000000002A")).is_equal(TestConstants.DEFAULT_TEST_SEED)


func test_shuffle_consumes_n_minus_one_draws() -> void:
	# Arrange (rng-event-log AC: a 15-card deck shuffle raises draws by 14; F4: 0 or 1 elements → 0 draws)
	var stream: TestRngStream = TestRngStream.seeded("match_1", TestConstants.DEFAULT_TEST_SEED)
	var deck: Array = CardFactory.make_starter_deck_ids("war")
	var single: Array = ["only"]

	# Act
	stream.shuffle(deck)
	var after_deck: int = stream.draws
	stream.shuffle(single)
	stream.shuffle([])

	# Assert
	assert_int(after_deck).is_equal(TestConstants.STARTER_DECK_SIZE - 1)
	assert_int(stream.draws).is_equal(TestConstants.STARTER_DECK_SIZE - 1)
	assert_int(deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE)
	assert_int(stream.count_calls("shuffle")).is_equal(3)
	assert_int(stream.count_calls("randi_range")).is_zero()


func test_shuffle_scripted_trace_matches_gdd_f4_example() -> void:
	# Arrange — F4 example: shuffle([A,B,C,D]) with j = 1, 0, 1 → [C,D,A,B], 3 draws
	var stream: TestRngStream = TestRngStream.scripted("match_1", [1, 0, 1])
	var items: Array = ["A", "B", "C", "D"]

	# Act
	stream.shuffle(items)

	# Assert
	assert_array(items).contains_exactly(["C", "D", "A", "B"])
	assert_int(stream.draws).is_equal(3)


func test_weighted_pick_follows_gdd_f4_example_and_zero_stub() -> void:
	# Arrange — F4 example: weighted_pick([5, 0, 15]) with r = 7 → index 2; reward-draft zero stub → first candidate
	var scripted: TestRngStream = TestRngStream.scripted("draft_1", [7])
	var zero_stub: TestRngStream = TestRngStream.constant("draft_1", 0)
	var weights: Array = [5, 0, 15]

	# Act / Assert
	assert_int(scripted.weighted_pick(weights)).is_equal(2)
	assert_int(scripted.draws).is_equal(1)
	assert_int(zero_stub.weighted_pick(weights)).is_equal(0)
	assert_int(zero_stub.weighted_pick([0, 0, 3])).is_equal(2)


func test_fork_twice_returns_same_object_and_one_parent_draw() -> void:
	# Arrange (rng-event-log AC: fork("x") twice → same object, parent draws +1 in total)
	var parent: TestRngStream = TestRngService.new().stream("ai_1")

	# Act
	var first: TestRngStream = parent.fork("sim_1")
	var second: TestRngStream = parent.fork("sim_1")

	# Assert
	assert_object(second).is_same(first)
	assert_int(parent.draws).is_equal(1)
	assert_str(first.name).is_equal("ai_1/sim_1")
	assert_bool(TestRngStream.is_valid_stream_name(first.name)).is_true()


func test_restore_reproduces_next_outputs() -> void:
	# Arrange (rng-event-log AC: draws = 37, snapshot, restore into a fresh service, next 20 match)
	var original: TestRngService = TestRngService.new(TestConstants.DEFAULT_TEST_SEED)
	var warmup: int = 37
	for _i: int in range(warmup):
		original.stream("match_3").randi32()
	var snap: Dictionary = original.snapshot()

	# Act
	var restored: TestRngService = TestRngService.new(TestConstants.DEFAULT_TEST_SEED)
	var status: Error = restored.restore(snap)
	var expected: Array = []
	var actual: Array = []
	for _i: int in range(20):
		expected.append(original.stream("match_3").randi32())
		actual.append(restored.stream("match_3").randi32())

	# Assert
	assert_int(status).is_equal(OK)
	assert_int(snap.streams["match_3"]).is_equal(warmup)
	assert_array(actual).is_equal(expected)
	assert_bool(GameAssertions.is_json_representable(snap)).is_true()


func test_restore_rejects_data_version_mismatch() -> void:
	# Arrange (rng-event-log AC: snapshot data_version "1.0", installed "1.1" → error, no stream)
	var saved: TestRngService = TestRngService.new(TestConstants.DEFAULT_TEST_SEED, "1.0")
	saved.stream("run").randi32()
	var installed: TestRngService = TestRngService.new(TestConstants.DEFAULT_TEST_SEED, "1.1")

	# Act
	var status: Error = installed.restore(saved.snapshot())

	# Assert
	assert_int(status).is_equal(ERR_INVALID_DATA)
	assert_bool(installed.has_stream("run")).is_false()


func test_service_memoises_streams_and_counts_outside_draws() -> void:
	# Arrange
	var service: TestRngService = TestRngService.new()

	# Act
	var first: TestRngStream = service.stream("match_1")
	first.randi32()
	var second: TestRngStream = service.stream("match_1")
	service.stream("draft_1").randi32()

	# Assert (match-rules AC-01: no RNG call outside rng_match)
	assert_object(second).is_same(first)
	assert_int(service.draws_outside(["match_1", "draft_1"])).is_zero()
	assert_int(service.draws_outside(["match_1"])).is_equal(1)


func test_installed_stream_is_served_by_name() -> void:
	# Arrange (run-structure AC-2: a recording double for the `run` stream)
	var service: TestRngService = TestRngService.new()
	var recorder: TestRngStream = service.install(TestRngStream.constant("run", 0))

	# Act
	service.stream("run").shuffle([1, 2, 3])

	# Assert
	assert_object(service.stream("run")).is_same(recorder)
	assert_int(recorder.count_calls("shuffle")).is_equal(1)
	assert_array(recorder.calls[0].args).contains_exactly([3])


# --- TestEventLog / EventLogAssertions ---------------------------------------

func test_append_assigns_contiguous_seq_and_events_since() -> void:
	# Arrange (rng-event-log AC: 5 appends → seq 1..5; events_since(3) → 4 and 5)
	var log: TestEventLog = TestEventLog.new()

	# Act
	for i: int in range(5):
		log.append(&"card_drawn", {"side": MatchFactory.SIDE_PLAYER, "instance_id": i + 10})
	var later: Array[Dictionary] = log.events_since(3)

	# Assert
	assert_int(log.events.size()).is_equal(5)
	assert_int(later.size()).is_equal(2)
	assert_int(later[0].seq).is_equal(4)
	assert_int(later[1].seq).is_equal(5)
	assert_int(log.events_since(-1).size()).is_equal(5)
	assert_int(log.events_since(5).size()).is_zero()
	EventLogAssertions.assert_seq_contiguous(log)
	EventLogAssertions.assert_envelopes_valid(log)


func test_subscriber_receives_each_event_once_in_order() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var received: Array = []
	log.subscribe(func(event: Dictionary) -> void: received.append(int(event.seq)))

	# Act
	log.append(&"turn_started", {"turn": 1})
	log.append(&"card_drawn", {})
	log.append(&"mana_spent", {"amount": TestConstants.HERO_POWER_COST})

	# Assert
	assert_array(received).contains_exactly([1, 2, 3])
	EventLogAssertions.assert_payload(log, &"mana_spent", {"amount": TestConstants.HERO_POWER_COST})


func test_match_ended_seals_log_and_drops_appends() -> void:
	# Arrange (rule 15)
	var log: TestEventLog = TestEventLog.new()
	log.append(&"damage_dealt", {"dealt": 1})

	# Act
	log.append(&"match_ended", {"result": "win"})
	var dropped_seq: int = log.append(&"card_drawn", {})

	# Assert
	assert_bool(log.sealed).is_true()
	assert_int(dropped_seq).is_equal(-1)
	assert_int(log.dropped).is_equal(1)
	assert_int(log.events.size()).is_equal(2)
	EventLogAssertions.assert_last_type(log, &"match_ended")


func test_cap_appends_overflow_then_fault_and_seals() -> void:
	# Arrange (rng-event-log AC: at max_match_events → log_overflow, match_ended{fault}, sealed)
	var log: TestEventLog = TestEventLog.new()
	log.max_events = 3
	for _i: int in range(3):
		log.append(&"healed", {"amount": 0})

	# Act
	var result: int = log.append(&"healed", {"amount": 0})

	# Assert
	assert_int(result).is_equal(-1)
	assert_bool(log.sealed).is_true()
	EventLogAssertions.assert_consecutive(log, [&"log_overflow", &"match_ended"])
	EventLogAssertions.assert_payload(log, &"match_ended", {"result": "fault", "reason": "event_cap"})
	assert_int(log.first(&"log_overflow").payload.cap).is_equal(3)


func test_cause_seq_validation_flags_forward_reference() -> void:
	# Arrange (Edge Cases: cause_seq < seq always)
	var log: TestEventLog = TestEventLog.new()
	log.append(&"minion_died", {})
	log.append(&"trigger_resolved", {}, 1)
	var forged: Array = [{"seq": 1, "turn": 0, "type": "x", "payload": {}, "cause_seq": 1}]

	# Act / Assert
	assert_failure(func() -> void: EventLogAssertions.assert_cause_seq_valid(log)).is_success()
	assert_failure(func() -> void: EventLogAssertions.assert_cause_seq_valid(forged)).is_failed()
	assert_int(log.events[1].cause_seq).is_equal(1)


func test_to_json_round_trip_is_replay_equal() -> void:
	# Arrange (rng-event-log AC: to_json → from_json → replay_equal, F6)
	var log: TestEventLog = TestEventLog.new()
	log.turn = 1
	log.append(&"damage_dealt", {"source": 7, "target": 2, "requested": 6, "prevented": 1, "armor_absorbed": 0, "dealt": 5, "health_after": 25})
	log.append(&"minion_died", {"instance_id": 7, "card_id": "card_a", "side": MatchFactory.SIDE_BOSS, "board_index": 0}, 1)

	# Act
	var text: String = log.to_json()
	var copy: TestEventLog = TestEventLog.from_json(text)

	# Assert
	EventLogAssertions.assert_replay_equal(log, copy)
	assert_str(EventLogAssertions.canonical_json(log.events)).is_equal(EventLogAssertions.canonical_json(copy.events))
	assert_str(EventLogAssertions.canonical_json({"b": 1, "a": 2.0})).is_equal("{\"a\":2.000000,\"b\":1}")
	assert_bool(text.contains(" ")).is_false()


func test_replay_equal_fails_on_divergent_payload() -> void:
	# Arrange
	var a: TestEventLog = TestEventLog.new()
	var b: TestEventLog = TestEventLog.new()
	a.append(&"card_drawn", {"instance_id": 3})
	b.append(&"card_drawn", {"instance_id": 4})

	# Act / Assert
	assert_failure(func() -> void: EventLogAssertions.assert_replay_equal(a, b)).is_failed()


func test_assert_order_accepts_subsequence_and_rejects_misorder() -> void:
	# Arrange (match-rules AC-14 shape: weapon_destroyed, trigger_resolved, weapon_equipped)
	var log: TestEventLog = TestEventLog.new()
	for type: StringName in [&"card_played", &"weapon_destroyed", &"trigger_resolved", &"mana_spent", &"weapon_equipped"]:
		log.append(type, {})

	# Act / Assert
	assert_failure(func() -> void: EventLogAssertions.assert_order(log, [&"weapon_destroyed", &"trigger_resolved", &"weapon_equipped"])).is_success()
	assert_failure(func() -> void: EventLogAssertions.assert_order(log, [&"weapon_equipped", &"weapon_destroyed"])).is_failed()
	assert_failure(func() -> void: EventLogAssertions.assert_order(log, [&"card_played", &"healed"])).is_failed().contains_message("healed")


func test_assert_consecutive_requires_adjacent_events() -> void:
	# Arrange (match-rules AC-16: two damage_dealt with consecutive seq, nothing between)
	var log: TestEventLog = TestEventLog.new()
	log.append(&"attack_declared", {})
	log.append(&"damage_dealt", {})
	log.append(&"damage_dealt", {})
	log.append(&"minion_died", {})

	# Act / Assert
	assert_failure(func() -> void: EventLogAssertions.assert_consecutive(log, [&"damage_dealt", &"damage_dealt"])).is_success()
	assert_failure(func() -> void: EventLogAssertions.assert_consecutive(log, [&"attack_declared", &"minion_died"])).is_failed()


func test_count_and_contains_assertions_read_types() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	log.append(&"card_drawn", {})
	log.append(&"card_drawn", {})

	# Act / Assert
	assert_failure(func() -> void: EventLogAssertions.assert_count(log, &"card_drawn", 2)).is_success()
	assert_failure(func() -> void: EventLogAssertions.assert_count(log, &"card_drawn", 1)).is_failed()
	assert_failure(func() -> void: EventLogAssertions.assert_contains_type(log, &"card_drawn")).is_success()
	assert_failure(func() -> void: EventLogAssertions.assert_not_contains_type(log, &"healed")).is_success()
	assert_failure(func() -> void: EventLogAssertions.assert_not_contains_type(log, &"card_drawn")).is_failed()
	assert_array(log.types()).contains_exactly(["card_drawn", "card_drawn"])
	assert_int(log.count(&"card_drawn")).is_equal(2)


# --- CardFactory -------------------------------------------------------------

func test_card_factory_defaults_pass_shape_check() -> void:
	# Act
	var minion: Dictionary = CardFactory.make_minion("neutral_test_vanilla_3_4", 3, 3, 4)
	var weapon: Dictionary = CardFactory.make_weapon("neutral_test_weapon_2_2", 2, 2, 2)
	var spell: Dictionary = CardFactory.make_spell("neutral_test_bolt", 1)

	# Assert (card-database CR-3 shapes)
	assert_array(CardFactory.validate_card_def(minion)).is_empty()
	assert_array(CardFactory.validate_card_def(weapon)).is_empty()
	assert_array(CardFactory.validate_card_def(spell)).is_empty()
	assert_bool(spell.has("attack")).is_false()
	assert_bool(spell.has("health")).is_false()
	assert_bool(weapon.has("health")).is_false()
	assert_bool(minion.has("durability")).is_false()
	assert_str(minion.text.key).is_equal("card.neutral_test_vanilla_3_4.text")


func test_card_factory_shape_check_reports_bad_records() -> void:
	# Arrange
	var bad: Dictionary = CardFactory.make_card_def({"id": "Bad-Id", "set": "epic_set", "cost": CardFactory.COST_MAX + 1, "keywords": ["taunt", "taunt", "nope"]})

	# Act
	var problems: Array = CardFactory.validate_card_def(bad)

	# Assert
	assert_int(problems.size()).is_greater_equal(4)
	assert_bool(CardFactory.is_valid_id("war_iron_vanguard")).is_true()
	assert_bool(CardFactory.is_valid_id("Bad-Id")).is_false()


func test_fixture_card_set_has_valid_unique_ids() -> void:
	# Act
	var cards: Array = CardFactory.make_fixture_card_set()
	var ids: Array = cards.map(func(c: Dictionary) -> String: return c.id)

	# Assert (match-rules AC fixture: vanillas, one per keyword, a weapon, two spells)
	GameAssertions.assert_no_duplicates(ids, "fixture ids")
	for card: Dictionary in cards:
		assert_array(CardFactory.validate_card_def(card)).override_failure_message("card %s" % card.id).is_empty()
	assert_int(cards.filter(func(c: Dictionary) -> bool: return c.type == "weapon").size()).is_equal(1)
	assert_int(cards.filter(func(c: Dictionary) -> bool: return c.type == "spell").size()).is_equal(2)


func test_definition_and_config_envelopes_carry_schema_version() -> void:
	# Act
	var definition: Dictionary = CardFactory.make_definition_file([CardFactory.make_hero_def()])
	var config: Dictionary = CardFactory.make_config_file({"max_mana": TestConstants.MAX_MANA_CRYSTALS})

	# Assert (card-database CR-1)
	assert_int(definition.schema_version).is_equal(TestConstants.SCHEMA_VERSION_CURRENT)
	assert_int(definition.records[0].starter_deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE)
	assert_int(config.schema_version).is_equal(TestConstants.SCHEMA_VERSION_CURRENT)
	assert_dict(config.config).contains_key_value("max_mana", TestConstants.MAX_MANA_CRYSTALS)
	assert_bool(GameAssertions.is_json_representable(definition)).is_true()


func test_boss_def_adds_passive_text_only_with_passive() -> void:
	# Act
	var plain: Dictionary = CardFactory.make_boss_def("boss_b1", 2)
	var passive: Dictionary = CardFactory.make_boss_def("boss_b2", 2, {"passive": CardFactory.make_effect("on_turn_start", [CardFactory.make_op("gain_armor", {"amount": 1})])})

	# Assert (card-database CR-3 BossDef; band-2 default health)
	assert_int(plain.health).is_equal(TestConstants.BOSS_STARTING_HEALTH_BY_BAND[1])
	assert_bool(plain.has("passive_text")).is_false()
	assert_bool(passive.has("passive_text")).is_true()


# --- MatchFactory ------------------------------------------------------------

func test_match_state_defaults_match_setup_step_2() -> void:
	# Act
	var state: Dictionary = MatchFactory.make_match_state()
	var player: Dictionary = state.players[MatchFactory.SIDE_PLAYER]
	var boss: Dictionary = state.players[MatchFactory.SIDE_BOSS]

	# Assert (match-rules C3 step 2: health 30 / band default, armour 0, mana 0/0, fatigue 0)
	assert_int(MatchFactory.health_of(player.hero)).is_equal(TestConstants.PLAYER_STARTING_HEALTH)
	assert_int(MatchFactory.health_of(boss.hero)).is_equal(TestConstants.BOSS_STARTING_HEALTH_BY_BAND[0])
	assert_int(player.hero.armor).is_zero()
	assert_int(player.mana_current).is_zero()
	assert_int(player.mana_max).is_zero()
	assert_int(player.fatigue_counter).is_zero()
	assert_int(state.turn).is_zero()
	assert_str(state.phase).is_equal(MatchFactory.PHASE_MULLIGAN)
	assert_int(state.next_entity_id).is_equal(MatchFactory.BOSS_HERO_ENTITY_ID + 1)
	assert_bool(GameAssertions.is_json_representable(state)).is_true()


func test_summon_fills_board_to_board_size_then_returns_empty() -> void:
	# Arrange
	var state: Dictionary = MatchFactory.make_match_state()
	var board: Array = state.players[MatchFactory.SIDE_PLAYER].board

	# Act
	for _i: int in range(TestConstants.BOARD_SIZE):
		MatchFactory.summon(state, MatchFactory.SIDE_PLAYER, 1, 1)
	var overflow: Dictionary = MatchFactory.summon(state, MatchFactory.SIDE_PLAYER, 1, 1)

	# Assert (match-rules Edge Cases: summon onto a full board is a no-op)
	assert_int(board.size()).is_equal(TestConstants.BOARD_SIZE)
	assert_dict(overflow).is_empty()
	assert_int(state.next_entity_id).is_equal(MatchFactory.BOSS_HERO_ENTITY_ID + 1 + TestConstants.BOARD_SIZE)
	assert_int(state.players[MatchFactory.SIDE_PLAYER].stats.minions_summoned).is_equal(TestConstants.BOARD_SIZE)


func test_summon_at_position_inserts_at_index() -> void:
	# Arrange (match-rules AC-11: position = 2 → board[2])
	var state: Dictionary = MatchFactory.make_match_state()
	MatchFactory.summon(state, MatchFactory.SIDE_BOSS, 1, 1)
	MatchFactory.summon(state, MatchFactory.SIDE_BOSS, 1, 1)
	MatchFactory.summon(state, MatchFactory.SIDE_BOSS, 1, 1)

	# Act
	var inserted: Dictionary = MatchFactory.summon(state, MatchFactory.SIDE_BOSS, 3, 4, 2)
	var board: Array = state.players[MatchFactory.SIDE_BOSS].board

	# Assert
	assert_int(board[2].entity_id).is_equal(inserted.entity_id)
	assert_int(board.size()).is_equal(4)
	assert_dict(MatchFactory.find_entity(state, inserted.entity_id)).is_same(inserted)
	assert_str(inserted.controller).is_equal(MatchFactory.SIDE_BOSS)


func test_derived_health_follows_f6_arithmetic() -> void:
	# Arrange (match-rules F6 example: a 2/2 buffed to 2/4 with damage_taken 3 → health 1)
	var state: Dictionary = MatchFactory.make_match_state()
	var minion: Dictionary = MatchFactory.summon(state, MatchFactory.SIDE_PLAYER, 2, 2, -1, ["taunt"])
	minion.enchantments.append(MatchFactory.make_enchantment(0, 2, ["windfury"]))
	minion.damage_taken = 3

	# Act / Assert
	assert_int(MatchFactory.max_health_of(minion)).is_equal(4)
	assert_int(MatchFactory.health_of(minion)).is_equal(1)
	assert_bool(MatchFactory.has_keyword(minion, "taunt")).is_true()
	assert_bool(MatchFactory.has_keyword(minion, "windfury")).is_true()
	assert_bool(MatchFactory.has_keyword(minion, "stealth")).is_false()
	var hero: Dictionary = state.players[MatchFactory.SIDE_PLAYER].hero
	var weapon: Dictionary = MatchFactory.make_weapon(MatchFactory.alloc_entity_id(state), 2, 2)
	assert_int(MatchFactory.attack_of(hero, weapon)).is_equal(2)
	assert_int(MatchFactory.attack_of(hero)).is_zero()


func test_deal_deck_and_draw_top_move_instances_between_zones() -> void:
	# Arrange
	var state: Dictionary = MatchFactory.make_match_state()
	MatchFactory.deal_deck(state, MatchFactory.SIDE_PLAYER, CardFactory.make_starter_deck_ids("war"))

	# Act
	var drawn: Dictionary = MatchFactory.draw_top(state, MatchFactory.SIDE_PLAYER)
	var player: Dictionary = state.players[MatchFactory.SIDE_PLAYER]

	# Assert (C1: index 0 is the top; zones deck → hand)
	assert_str(drawn.def_id).is_equal("war_starter_01")
	assert_str(drawn.zone).is_equal("hand")
	assert_int(player.deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE - 1)
	assert_int(player.hand.size()).is_equal(1)
	assert_str(player.deck[0].def_id).is_equal("war_starter_02")


func test_match_config_wires_memoised_streams_and_log() -> void:
	# Arrange
	var rng: TestRngService = TestRngService.new()
	var log: TestEventLog = TestEventLog.new()

	# Act
	var config: Dictionary = MatchFactory.make_match_config(5, rng, log)

	# Assert (match-rules C3 step 1 / run-structure R3; DD-T03 memoised streams)
	assert_object(config.rng_match).is_same(rng.stream("match_5"))
	assert_object(config.rng_ai).is_same(rng.stream("ai_5"))
	assert_object(config.log).is_same(log)
	assert_int(config.band).is_equal(2)
	assert_int(config.boss.health).is_equal(TestConstants.BOSS_STARTING_HEALTH_BY_BAND[1])
	assert_int(config.player.deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE)
	assert_bool(config.has("seed")).is_false()


func test_command_and_match_results_carry_gdd_fields() -> void:
	# Act
	var rejected: Dictionary = MatchFactory.make_command_result(false, "INVALID_MASK", "mask length 2")
	var accepted: Dictionary = MatchFactory.make_command_result(true, "", "", 4, 9)
	var fault: Dictionary = MatchFactory.make_match_result("fault", MatchFactory.SIDE_BOSS, "resolution_overflow")

	# Assert (match-rules C2, AC-42)
	assert_bool(MatchFactory.REJECTION_CODES.has(rejected.rejection.code)).is_true()
	assert_object(accepted.rejection).is_null()
	assert_array(accepted.events).contains_exactly([4, 9])
	GameAssertions.assert_has_keys(fault, ["result", "winner", "reason", "floor", "turns", "turns_per_side", "stats"], "MatchResult")
	assert_object(fault.winner).is_null()
	assert_int(MatchFactory.REJECTION_CODES.size()).is_equal(21)


# --- RunFactory --------------------------------------------------------------

func test_band_of_follows_f1_for_default_split() -> void:
	# Act (run-structure AC-1)
	var bands: Array = []
	for f: int in range(1, TestConstants.FLOORS_PER_RUN + 1):
		bands.append(RunFactory.band_of(f))

	# Assert
	assert_array(bands).contains_exactly([1, 1, 1, 2, 2, 2, 3, 3])
	assert_int(RunFactory.first_floor_of_band(1)).is_equal(1)
	assert_int(RunFactory.first_floor_of_band(2)).is_equal(4)
	assert_int(RunFactory.first_floor_of_band(3)).is_equal(7)
	assert_array([RunFactory.band_of(1, [2, 1, 1]), RunFactory.band_of(2, [2, 1, 1]), RunFactory.band_of(3, [2, 1, 1]), RunFactory.band_of(4, [2, 1, 1])]).contains_exactly([1, 1, 2, 3])


func test_deck_size_at_floor_follows_f4() -> void:
	# run-structure F4 example: floor 6 → 30; floors 1 and 8 → 15 and 36
	assert_int(RunFactory.deck_size_at_floor(1)).is_equal(TestConstants.STARTER_DECK_SIZE)
	assert_int(RunFactory.deck_size_at_floor(6)).is_equal(30)
	assert_int(RunFactory.deck_size_at_floor(TestConstants.FLOORS_PER_RUN)).is_equal(36)


func test_effective_treasure_floors_drop_floors_at_or_past_end() -> void:
	# run-structure AC-6: floors_per_run = 4 → treasure floors [1, 3]; F4 treasures held 0,1,1,2,2,3,3,3
	assert_array(RunFactory.effective_treasure_floors(TestConstants.TREASURE_FLOORS, 4)).contains_exactly([1, 3])
	assert_array(RunFactory.effective_treasure_floors()).contains_exactly([1, 3, 5])
	var held: Array = []
	for f: int in range(1, TestConstants.FLOORS_PER_RUN + 1):
		held.append(RunFactory.treasures_held_at_floor(f))
	assert_array(held).contains_exactly([0, 1, 1, 2, 2, 3, 3, 3])


func test_fixture_boss_pool_has_six_six_four_in_id_order() -> void:
	# Act
	var pool: Array = RunFactory.make_fixture_boss_pool()
	var band3: Array = RunFactory.bosses_in_band(pool, 3)

	# Assert (run-structure Acceptance Criteria fixture)
	assert_int(pool.size()).is_equal(16)
	assert_int(RunFactory.bosses_in_band(pool, 1).size()).is_equal(6)
	assert_int(band3.size()).is_equal(4)
	GameAssertions.assert_sorted_ascending(band3.map(func(b: Dictionary) -> String: return b.id), "band 3 ids")
	assert_int(band3[0].health).is_equal(TestConstants.BOSS_STARTING_HEALTH_BY_BAND[2])


func test_run_state_defaults_satisfy_r1_invariants() -> void:
	# Act
	var run_state: Dictionary = RunFactory.make_run_state()

	# Assert
	assert_array(RunFactory.validate_invariants(run_state)).is_empty()
	RunFactory.assert_invariants(run_state)
	assert_int(run_state.boss_sequence.size()).is_equal(TestConstants.FLOORS_PER_RUN)
	assert_str(run_state.boss_sequence[0]).is_equal("boss_a1")
	assert_str(run_state.boss_sequence[TestConstants.FLOORS_PER_RUN - 1]).is_equal("boss_c2")
	assert_str(run_state.run_seed_hex).is_equal("000000000000002A")
	assert_bool(GameAssertions.is_json_representable(run_state)).is_true()


func test_apply_picks_keep_invariants_and_validate_reports_breaks() -> void:
	# Arrange
	var run_state: Dictionary = RunFactory.make_run_state()
	var bundle_cards: Array = ["war_bundle_card_01", "war_bundle_card_02", "war_bundle_card_03"]

	# Act
	RunFactory.apply_treasure_pick(run_state, 1, ["treasure_a", "treasure_b", "treasure_c"], "treasure_b")
	RunFactory.apply_bundle_pick(run_state, 1, ["bundle_war_a", "bundle_war_b", "bundle_war_c"], "bundle_war_a", bundle_cards)
	run_state.drafts.append(RunFactory.make_draft_record(2, RunFactory.KIND_BUNDLE, [], null))
	var clean: Array = RunFactory.validate_invariants(run_state)
	run_state.boss_sequence.pop_back()
	var broken: Array = RunFactory.validate_invariants(run_state)

	# Assert (R1: deck = 15 + 3 × non-null bundle picks; a skipped step adds no cards; AC-21 length-7 sequence)
	assert_array(clean).is_empty()
	assert_int(run_state.deck.size()).is_equal(RunFactory.deck_size_at_floor(2))
	assert_array(run_state.treasures).contains_exactly(["treasure_b"])
	assert_int(broken.size()).is_equal(1)
	assert_failure(func() -> void: RunFactory.assert_invariants(run_state)).is_failed().contains_message("boss_sequence")


func test_match_config_for_run_uses_floor_boss_and_deck() -> void:
	# Arrange
	var run_state: Dictionary = RunFactory.make_run_state({"floor": 4, "treasures": ["treasure_x"]})
	run_state.drafts.append(RunFactory.make_draft_record(1, RunFactory.KIND_TREASURE, ["treasure_x"], "treasure_x"))
	var rng: TestRngService = TestRngService.new()

	# Act
	var config: Dictionary = RunFactory.make_match_config_for(run_state, rng)

	# Assert (run-structure R3 / AC-9 shape)
	assert_str(config.boss.boss_def_id).is_equal("boss_b1")
	assert_int(config.band).is_equal(2)
	assert_int(config.boss.health).is_equal(TestConstants.BOSS_STARTING_HEALTH_BY_BAND[1])
	assert_array(config.player.hook_installers).contains_exactly(["treasure_x"])
	assert_object(config.rng_match).is_same(rng.stream("match_4"))
	assert_object(config.log).is_null()


func test_offer_and_summary_shapes_match_reward_draft_and_r4() -> void:
	# Act
	var offer: Dictionary = RunFactory.make_offer(["bundle_a", "bundle_b", "bundle_c"], ["pity_forced"])
	var summary: Dictionary = RunFactory.make_match_summary(5, "win", 9, {"boss_id": "boss_b2"})

	# Assert
	assert_int(offer.option_ids.size()).is_equal(TestConstants.OFFERS_PER_DRAFT)
	assert_bool(RunFactory.OFFER_FLAGS.has(offer.flags[0])).is_true()
	GameAssertions.assert_has_keys(summary, ["floor", "result", "turns", "event_count", "cards_played", "damage_by_card", "boss_id", "band", "attempt", "duration_s"], "MatchSummary")
	assert_int(summary.band).is_equal(2)


# --- SceneRunnerHelper -------------------------------------------------------

func test_load_scene_and_wait_adds_instance_under_host() -> void:
	# Arrange -- an in-memory scene; auto_free: a Node left alive is an orphan (exit 101)
	var template: Node = auto_free(Node.new())
	template.name = "HelperScene"
	var packed: PackedScene = PackedScene.new()
	assert_int(packed.pack(template)).is_equal(OK)

	# Act
	var instance: Node = auto_free(await SceneRunnerHelper.load_scene_and_wait(self, packed))

	# Assert
	assert_object(instance).is_not_null()
	assert_bool(instance.is_inside_tree()).is_true()
	assert_object(instance.get_parent()).is_same(self)
	GameAssertions.assert_node_exists(self, NodePath("HelperScene"))
