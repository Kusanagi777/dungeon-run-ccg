## Integration: effects replay byte for byte, a clone is isolated, and the runtime cap is
## match-rules' (card-effects C6.9, C6.10, F4, F5, F6, AC-37, AC-38, AC-39, AC-40; ADR-0007
## Decisions 3, 7, 10; story 016).
##
## AC-37 reads `tests/fixtures/replay_card_effects_100.json` over the C11 fixture folder:
## decks of rows 9, 12, 13, 20, 22, 26 and 34, both seats scripted. The fixture's commands
## were taken once from the legal list, so each is accepted; `hero_set` is `decay`, so
## row 13's filtered pool is not empty and F4 draws. AC-38 and AC-40 build their own cards.
extends GdUnitTestSuite

const FIXTURE_ROOT: String = "res://tests/fixtures/data/card_effects_v1/"
const REPLAY: String = "res://tests/fixtures/replay_card_effects_100.json"
const RESOLVER_SOURCE: String = "res://src/gameplay/effects/effect_resolver.gd"
const OPS_SOURCE: String = "res://src/gameplay/effects/ops.gd"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const EVENT_RESOLVED: String = "effect_resolved"
const COMMANDS: int = 100
## AC-39's envelope of every `effect_resolved`.
const RESOLVED_KEYS: Array[String] = ["effect_id", "host_id", "host_kind", "source_id", "owner", "trigger", "depth", "fizzled", "ops"]

const CYCLE: String = "neutral_test_cycle"
const STEP_CAP: int = 50
## A second cap, to tell the config's reading from a constant.
const LOW_STEP_CAP: int = 20
const MAX_EVENTS_KEY: String = "rng_event_log"
const COUNTER_MINION: String = "neutral_test_counter"
const COUNTER_KEY: String = "seen"
const FILLER: String = "neutral_test_filler"
const FATAL_HEALTH: int = 1
const FATAL_SWING: int = 1

var _replay: Dictionary = {}


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


## A played match: its engine, log and stream.
class Played:
	extends RefCounted

	var engine: RulesEngine
	var log: TestEventLog
	var rejected: int = 0


func before() -> void:
	_replay = JSON.parse_string(FileAccess.get_file_as_string(REPLAY))


func _fixture_db() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(FIXTURE_ROOT))
	db.load(ValidatorStubs.accept_all())
	return db


## Runs the fixture's commands on a fresh engine over [param db].
func _play_fixture(db: CardDatabase) -> Played:
	var played: Played = Played.new()
	played.log = TestEventLog.new()
	var rng: TestRngService = TestRngService.new(int(_replay.seed))
	played.engine = RulesEngine.new(db, db.config("match_rules"), EffectResolver.new(db, db.config("card_effects"), str(_replay.hero_set)))
	played.engine.start(MatchFactory.make_started_config(rng, played.log, {
		"player": {"deck": (_replay.player_deck as Array).duplicate()},
		"boss": {"deck": (_replay.boss_deck as Array).duplicate()},
	}))
	for command: Dictionary in _replay.commands:
		var numbered: Dictionary = _with_ints(command)
		if not played.engine.submit(numbered).accepted:
			played.rejected += 1
	return played


## JSON gives every number back as a float; `hand_index` and the ids are ints.
func _with_ints(command: Dictionary) -> Dictionary:
	var out: Dictionary = command.duplicate(true)
	for key: String in out:
		if out[key] is float:
			out[key] = int(out[key])
	return out


## The random picks of one op entry of host [param host_id]: F4 for a `from` pool, F5
## for a `random_*` selector.
func _random_ops(db: CardDatabase, host_id: String) -> Dictionary:
	var named: Dictionary = {}
	var host: Variant = db.any_record(host_id) if db.has(host_id) else null
	if not host is Dictionary:
		return named
	for effect: Dictionary in (host as Dictionary).get("effects", []):
		_collect_random(effect.get("ops", []), effect.get("targets"), named)
	return named


func _collect_random(ops: Array, inherited: Variant, named: Dictionary) -> void:
	for op: Dictionary in ops:
		var selector: Variant = op.get("targets", inherited)
		var name: String = str(selector.get("selector", "")) if selector is Dictionary else str(selector)
		if name.begins_with("random_") or op.has("from"):
			named[str(op.op)] = true
		if op.has("ops"):
			_collect_random(op.ops, selector, named)


## F4 / F5 recomputed from the log: `{discover, picks}`.
func _draws_from_log(db: CardDatabase, log: TestEventLog) -> Dictionary:
	var counted: Dictionary = {"discover": 0, "picks": 0}
	for event: Dictionary in log.events:
		if str(event.type) == "discover_offered":
			# A Choose One offers its printed options: no draw (C8).
			counted.discover += (event.payload.get("option_card_ids", []) as Array).size()
		elif str(event.type) == EVENT_RESOLVED:
			var random_ops: Dictionary = _random_ops(db, str(event.payload.host_id))
			for entry: Dictionary in event.payload.ops:
				if not random_ops.has(str(entry.op)):
					continue
				if str(entry.op) == "add_to_hand":
					counted.picks += (entry.values.get("card_ids", []) as Array).size()
				else:
					counted.picks += (entry.targets as Array).size()
	return counted


func test_ac37_the_fixture_is_a_hundred_commands_all_accepted() -> void:
	# Act
	var played: Played = _play_fixture(_fixture_db())

	# Assert
	assert_int((_replay.commands as Array).size()).is_equal(COMMANDS)
	assert_int(played.rejected).is_equal(0)
	played.engine.end_match()


func test_ac37_two_replays_are_byte_identical() -> void:
	# Arrange
	var db: CardDatabase = _fixture_db()

	# Act
	var first: Played = _play_fixture(db)
	var second: Played = _play_fixture(db)

	# Assert
	EventLogAssertions.assert_replay_equal(first.log.events, second.log.events, "AC-37 logs")
	assert_str(first.log.to_json()).is_equal(second.log.to_json())
	first.engine.end_match()
	second.engine.end_match()


func test_ac37_stream_draws_equal_the_f4_and_f5_counts_in_the_log() -> void:
	# Arrange
	var db: CardDatabase = _fixture_db()

	# Act
	var played: Played = _play_fixture(db)
	var counted: Dictionary = _draws_from_log(db, played.log)
	var draws: int = (played.engine.rng_match() as TestRngStream).count_calls("randi_range")

	# Assert — both formulas really ran, and nothing else drew
	assert_int(int(counted.discover)).is_greater(0)
	assert_int(int(counted.picks)).is_greater(0)
	assert_int(draws).is_equal(int(counted.discover) + int(counted.picks))
	played.engine.end_match()


func test_ac37_the_fixture_exercises_every_named_row() -> void:
	# Arrange
	var rows: Array[String] = ["row_09", "row_12", "row_13", "row_20", "row_22", "row_34"]
	var db: CardDatabase = _fixture_db()

	# Act
	var played: Played = _play_fixture(db)
	var ran: Array = played.log.events.filter(func(e: Dictionary) -> bool: return str(e.type) == EVENT_RESOLVED).map(func(e: Dictionary) -> String: return str(e.payload.host_id))

	# Assert — row 26 is an aura, seen as its recompute, not as an `effect_resolved`
	for row: String in rows:
		assert_bool(ran.any(func(id: String) -> bool: return id.contains(row))).override_failure_message(row).is_true()
	var auras: Array = played.log.events.filter(func(e: Dictionary) -> bool: return str(e.type) == "auras_recomputed")
	assert_array(auras).is_not_empty()
	played.engine.end_match()


func test_ac39_every_effect_resolved_carries_the_envelope() -> void:
	# Act
	var played: Played = _play_fixture(_fixture_db())
	var resolved: Array = played.log.events.filter(func(e: Dictionary) -> bool: return str(e.type) == EVENT_RESOLVED)

	# Assert
	assert_array(resolved).is_not_empty()
	for event: Dictionary in resolved:
		for key: String in RESOLVED_KEYS:
			assert_bool((event.payload as Dictionary).has(key)).override_failure_message("%s in %s" % [key, event.payload]).is_true()
		assert_int(int(event.cause_seq)).is_greater(0)
	played.engine.end_match()


# --- AC-38 ------------------------------------------------------------------------


## The Deathrattle cycle: each death summons a copy, and the copy takes 1.
func _cycle_db(cap: int) -> Dictionary:
	var effect: Dictionary = {"id": CYCLE + ".0", "trigger": "deathrattle", "ops": [
		CardFactory.make_op("summon", {"card_id": CYCLE, "count": 1, "position": "end"}),
		CardFactory.make_op("damage", {"amount": 1, "targets": "all_friendly_minions"}),
	]}
	var db: FakeCardDatabase = FakeCardDatabase.new({
		CYCLE: CardFactory.make_minion(CYCLE, 0, FATAL_SWING, FATAL_HEALTH, ["deathrattle"], {"effects": [effect], "token": true}),
	})
	return {"db": db, "rules": MatchFactory.make_rules_config({"resolution_step_cap": cap})}


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


## Kills a cycle minion at [param cap]; answers the played match.
func _run_cycle(cap: int) -> Played:
	var built: Dictionary = _cycle_db(cap)
	var played: Played = Played.new()
	played.log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), played.log)
	played.engine = RulesEngine.new(built.db, built.rules, EffectResolver.new(built.db, _effects_config()))
	played.engine.start(config)
	assert_bool(played.engine.submit(played.engine.legal_commands()[0]).accepted).is_true()
	var engine: RulesEngine = played.engine
	var id: Array[int] = [0]
	engine.run_action(func() -> void: id[0] = engine.summon_minion(SIDE_PLAYER, CYCLE, 0))
	engine.run_action(func() -> void: engine.apply_damage(id[0], FATAL_HEALTH, null))
	return played


func _ended(played: Played) -> Dictionary:
	var ends: Array = played.log.events.filter(func(e: Dictionary) -> bool: return str(e.type) == "match_ended")
	assert_int(ends.size()).is_equal(1)
	return ends[0].payload if not ends.is_empty() else {}


func test_ac38_a_deathrattle_cycle_ends_resolution_overflow_within_the_cap() -> void:
	# Act
	var played: Played = _run_cycle(STEP_CAP)

	# Assert
	assert_str(str(_ended(played).reason)).is_equal(MatchRecords.REASON_RESOLUTION_OVERFLOW)
	assert_str(played.engine.phase()).is_equal(MatchState.PHASE_ENDED)
	var passes: Array = played.log.events.filter(func(e: Dictionary) -> bool: return str(e.type) == EVENT_RESOLVED)
	assert_int(passes.size()).is_less_equal(STEP_CAP)
	assert_int(played.log.events.size()).is_less(TestConstants.MAX_MATCH_EVENTS)


func test_ac38_the_cap_is_read_from_match_rules() -> void:
	# Act
	var high: Played = _run_cycle(STEP_CAP)
	var low: Played = _run_cycle(LOW_STEP_CAP)

	# Assert — a constant of the resolver's would give both the same length
	var high_passes: int = high.log.events.filter(func(e: Dictionary) -> bool: return str(e.type) == EVENT_RESOLVED).size()
	var low_passes: int = low.log.events.filter(func(e: Dictionary) -> bool: return str(e.type) == EVENT_RESOLVED).size()
	assert_int(low_passes).is_less(high_passes)
	assert_str(str(_ended(low).reason)).is_equal(MatchRecords.REASON_RESOLUTION_OVERFLOW)


func test_ac38_the_resolver_has_no_cap_of_its_own() -> void:
	# Arrange — ADR-0007 Decision 7: the config has no key for it, the source no constant
	var db: CardDatabase = _fixture_db()

	# Act
	var resolver: String = FileAccess.get_file_as_string(RESOLVER_SOURCE)
	var ops: String = FileAccess.get_file_as_string(OPS_SOURCE)

	# Assert
	assert_bool((db.config("card_effects") as Dictionary).has("resolution_step_cap")).is_false()
	assert_str(resolver).not_contains("resolution_step_cap")
	assert_str(resolver).not_contains("STEP_CAP")
	assert_str(ops).not_contains("resolution_step_cap")


# --- AC-40 ------------------------------------------------------------------------


## A player's Main with a `turn_end` observer on the board that counts, once already.
func _counted_engine() -> Played:
	var effect: Dictionary = {"id": COUNTER_MINION + ".0", "trigger": "turn_end", "scope": {"side": "owner"}, "ops": [
		CardFactory.make_op("add_counter", {"key": COUNTER_KEY, "amount": 1}),
		CardFactory.make_op("armor", {"amount": 1, "targets": "owner"}),
	]}
	var db: FakeCardDatabase = FakeCardDatabase.new({
		COUNTER_MINION: CardFactory.make_minion(COUNTER_MINION, 0, 1, 3, [], {"effects": [effect]}),
	})
	var played: Played = Played.new()
	played.log = TestEventLog.new()
	played.engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	played.engine.start(MatchFactory.make_started_config(TestRngService.new(), played.log))
	assert_bool(played.engine.submit(played.engine.legal_commands()[0]).accepted).is_true()
	var engine: RulesEngine = played.engine
	engine.run_action(func() -> void: engine.summon_minion(SIDE_PLAYER, COUNTER_MINION, 0))
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	return played


## The types and payloads of [param events], which `seq` does not move in a clone.
func _shape(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return "%s %s" % [e.type, EventLogAssertions.canonical_json(e.payload)])


func test_ac40_clone_and_original_log_the_same_sequence() -> void:
	# Arrange
	var played: Played = _counted_engine()
	var engine: RulesEngine = played.engine
	var clone: RulesEngine = engine.clone()
	var from: int = played.log.events.size()

	# Act
	var on_clone: Dictionary = clone.submit(MatchRecords.end_turn(SIDE_PLAYER))
	var on_live: Dictionary = engine.submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_bool(on_clone.accepted).is_true()
	assert_bool(on_live.accepted).is_true()
	var live_events: Array = played.log.events.slice(from)
	var clone_events: Array = clone.state().log.events_since(0)
	assert_array(live_events).is_not_empty()
	assert_array(_shape(clone_events)).is_equal(_shape(live_events))
	clone.end_match()
	engine.end_match()


func test_ac40_the_clones_resolution_leaves_the_originals_runtime_alone() -> void:
	# Arrange
	var played: Played = _counted_engine()
	var engine: RulesEngine = played.engine
	var before_runtime: Dictionary = (engine.state().effects as Dictionary).duplicate(true)
	var clone: RulesEngine = engine.clone()

	# Act
	assert_bool(clone.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert
	assert_dict(engine.state().effects).is_equal(before_runtime)
	assert_dict(clone.state().effects).is_not_equal(before_runtime)
	assert_bool(is_same(engine.state().effects, clone.state().effects)).is_false()
	clone.end_match()
	engine.end_match()


func test_ac40_the_clone_has_a_fresh_resolver_bound_to_itself() -> void:
	# Arrange
	var played: Played = _counted_engine()
	var engine: RulesEngine = played.engine

	# Act
	var clone: RulesEngine = engine.clone()

	# Assert
	var live_resolver: EffectResolver = engine._resolver
	var clone_resolver: EffectResolver = clone._resolver
	assert_bool(is_same(live_resolver, clone_resolver)).is_false()
	assert_bool(is_same(clone_resolver.bound_engine(), clone)).is_true()
	assert_bool(is_same(live_resolver.bound_engine(), engine)).is_true()
	assert_dict(clone_resolver._memo).is_empty()
	assert_bool(is_same(engine.state().hooks, clone.state().hooks)).is_false()
	clone.end_match()
	engine.end_match()
