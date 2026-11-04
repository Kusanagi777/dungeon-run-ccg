## `EffectResolver` binding lifecycle, `EffectRuntime` and `ChoiceRequest`
## shapes (story card-effects/story-002 AC-1, AC-2, AC-41 resolver half;
## design/gdd/card-effects.md C6.1, C6.8, C8, Tuning Knobs; ADR-0007 Decisions
## 2–4, Key Interfaces; ADR-0005 `set_evaluators`).
##
## The engine is the real `RulesEngine` started from `MatchFactory`'s config
## with a `TestRngService` and `TestEventLog`; the resolver is the real
## `EffectResolver` (or a recording subclass of it, so the evaluators the
## registry calls are the subclass's overrides of the very methods `bind`
## registers). The database is a `CardDatabase` subclass that answers from an
## in-memory record map and counts its lookups. No file is read.
extends GdUnitTestSuite

## A `CardDatabase` that answers `has(id)` / `card(id)` from a map and counts
## `card` calls; any other query is a test bug (the resolver asks `has` before
## `card`, story 004).
class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}
	var card_calls: Dictionary = {}
	var config_calls: int = 0

	func _init(by_id: Dictionary = {}) -> void:
		records = by_id

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		card_calls[id] = int(card_calls.get(id, 0)) + 1
		return records.get(id)

	func config(_config_name: String) -> Variant:
		config_calls += 1
		return null


## Records every evaluator call and the log size at that moment, and folds by
## `+ FOLD_DELTA` so a registered evaluator is observable.
class RecordingResolver:
	extends EffectResolver

	const FOLD_DELTA: int = 100
	var runs: Array[Dictionary] = []
	var folds: Array[Dictionary] = []

	func _init(db: CardDatabase, effects_config: Dictionary) -> void:
		super(db, effects_config)

	func apply_value_hook(entry: Dictionary, side: StringName, value: int, _ctx: Dictionary) -> int:
		folds.append({"effect_id": entry.effect_id, "side": side, "value": value})
		return value + FOLD_DELTA

	func run_hook_effect(entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
		var log: TestEventLog = bound_engine().state().log
		runs.append({"effect_id": entry.effect_id, "side": side, "events_so_far": log.types()})


# --- helpers -------------------------------------------------------------------

## The `card_effects` body at the GDD Tuning Knobs "Current value" column, keys
## snake_case (DD-T01), numbers as floats (as JSON parses them).
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


## A started engine (phase mulligan) bound to [param resolver], with
## [param overrides] merged into the `MatchConfig` as `MatchFactory` does.
func _start(resolver: EffectResolver, overrides: Dictionary = {}) -> RulesEngine:
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), TestEventLog.new(), overrides)
	var engine: RulesEngine = RulesEngine.new(null, MatchFactory.make_rules_config(), resolver)
	engine.start(config)
	return engine


## A treasure installer whose one effect is on [param point], plus a boss
## passive on `modify_cost` — the order ADR-0007 Decision 2 installs them in.
func _installers(point: String) -> Dictionary:
	return {
		"player": {"hook_installers": [MatchFactory.make_hook_installer("treasure_signet", MatchFactory.SIDE_PLAYER, [point])]},
		"boss": {"hook_installers": [MatchFactory.make_hook_installer("boss_test_passive", MatchFactory.SIDE_BOSS, ["modify_cost"])]},
	}


# --- AC-1: EffectRuntime is plain data in MatchState.effects --------------------

func test_started_match_effects_is_an_effect_runtime_of_plain_data() -> void:
	# Arrange
	var resolver: EffectResolver = EffectResolver.new(FakeCardDatabase.new(), _effects_config())

	# Act
	var engine: RulesEngine = _start(resolver)
	var effects: Dictionary = engine.state().effects

	# Assert — exactly the four fields, plain containers, JSON-representable
	var keys: Array = effects.keys()
	keys.sort()
	var expected: Array = EffectRuntime.FIELDS.duplicate()
	expected.sort()
	assert_array(keys).is_equal(expected)
	assert_bool(effects.once_marks is Dictionary).is_true()
	assert_bool(effects.counters is Dictionary).is_true()
	assert_bool(effects.per_turn is Dictionary).is_true()
	assert_that(effects.pending_choice).is_null()
	assert_bool(EffectRuntime.is_runtime(effects)).is_true()
	GameAssertions.assert_json_representable(effects, "state.effects")
	engine.end_match()


func test_effect_runtime_make_is_the_shape_match_state_starts_with() -> void:
	# Act / Assert — one shape, two factories: they must not drift
	assert_dict(EffectRuntime.make()).is_equal(MatchState.make_effect_runtime())
	assert_array(EffectRuntime.FIELDS).is_equal(["once_marks", "counters", "per_turn", "pending_choice"])


func test_effect_runtime_is_runtime_rejects_extra_missing_and_object_fields() -> void:
	# Arrange
	var extra: Dictionary = EffectRuntime.make()
	extra["engine"] = null
	var missing: Dictionary = EffectRuntime.make()
	missing.erase("counters")
	var holds_object: Dictionary = EffectRuntime.make()
	holds_object.counters["7"] = RefCounted.new()
	var holds_callable: Dictionary = EffectRuntime.make()
	holds_callable.pending_choice = {"resume": Callable()}
	var used: Dictionary = EffectRuntime.make()
	used.counters["7"] = {"seen": 2}
	used.once_marks["treasure_signet.0"] = 3
	used.pending_choice = ChoiceRequest.make("player", ChoiceRequest.KIND_DISCOVER, ["a_01", "b_02"], 7, "scout.0")

	# Act / Assert
	assert_bool(EffectRuntime.is_runtime(extra)).is_false()
	assert_bool(EffectRuntime.is_runtime(missing)).is_false()
	assert_bool(EffectRuntime.is_runtime(holds_object)).is_false()
	assert_bool(EffectRuntime.is_runtime(holds_callable)).is_false()
	assert_bool(EffectRuntime.is_runtime(used)).is_true()


func test_effect_runtime_is_runtime_rejects_string_names_which_do_not_survive_json() -> void:
	# Arrange: a StringName value and a StringName key (JSON reads both back as
	# String, so a runtime holding one does not round-trip — rng-event-log rule 14)
	var name_value: Dictionary = EffectRuntime.make()
	name_value.once_marks["treasure_signet.0"] = &"turn_3"
	var name_key: Dictionary = EffectRuntime.make()
	name_key.counters[&"7"] = {"seen": 2}
	var nested_name: Dictionary = EffectRuntime.make()
	nested_name.counters["7"] = {"tags": [&"spent"]}

	# Act / Assert (code review 2026-11-03: String only)
	assert_bool(EffectRuntime.is_runtime(name_value)).is_false()
	assert_bool(EffectRuntime.is_runtime(name_key)).is_false()
	assert_bool(EffectRuntime.is_runtime(nested_name)).is_false()


func test_choice_request_make_has_the_adr_shape_and_matches_the_engine_record() -> void:
	# Act
	var request: Dictionary = ChoiceRequest.make("player", ChoiceRequest.KIND_CHOOSE_ONE, [{"index": 0}, {"index": 1}], 9, "druid.0")

	# Assert — {side, kind, options, source_id, effect_id}, the engine's record exactly
	var keys: Array = request.keys()
	keys.sort()
	var expected: Array = ChoiceRequest.FIELDS.duplicate()
	expected.sort()
	assert_array(keys).is_equal(expected)
	assert_dict(request).is_equal(MatchRecords.choice_request("player", MatchRecords.CHOICE_CHOOSE_ONE, [{"index": 0}, {"index": 1}], 9, "druid.0"))
	assert_array(ChoiceRequest.KINDS).is_equal([MatchRecords.CHOICE_DISCOVER, MatchRecords.CHOICE_CHOOSE_ONE])
	GameAssertions.assert_json_representable(request, "ChoiceRequest")


# --- AC-2: bind before on_match_start, evaluators registered, unbind clears ----

func test_bind_runs_before_on_match_start_so_the_resolver_observes_it() -> void:
	# Arrange
	var resolver: RecordingResolver = RecordingResolver.new(FakeCardDatabase.new(), _effects_config())

	# Act
	var engine: RulesEngine = _start(resolver, _installers("on_match_start"))

	# Assert — the on_match_start hook reached the resolver's evaluator once per
	# side (C3 step 4: player then boss; scope is the evaluator's business),
	# after the decks were shuffled (step 3) and before any card was drawn (step 5)
	assert_array(resolver.runs.map(func(r: Dictionary) -> String: return r.effect_id)).is_equal(["treasure_signet.0", "treasure_signet.0"])
	assert_array(resolver.runs.map(func(r: Dictionary) -> String: return String(r.side))).is_equal([MatchFactory.SIDE_PLAYER, MatchFactory.SIDE_BOSS])
	for run: Dictionary in resolver.runs:
		assert_array(run.events_so_far).is_equal(["deck_shuffled", "deck_shuffled"])
	engine.end_match()


func test_bind_installs_installers_in_order_and_registers_both_evaluators() -> void:
	# Arrange
	var resolver: RecordingResolver = RecordingResolver.new(FakeCardDatabase.new(), _effects_config())
	var engine: RulesEngine = _start(resolver, _installers("on_turn_start"))
	var hooks: HookRegistry = engine.state().hooks

	# Act
	var folded: int = hooks.fold(&"modify_cost", &"boss", 3, {})
	hooks.run_triggers(&"on_turn_start", &"player", {})

	# Assert — treasures first, then the boss passive; both Callables are the resolver's
	var host_ids: Array = hooks.hosts().map(func(h: Dictionary) -> String: return h.host_id)
	assert_array(host_ids).is_equal(["treasure_signet", "boss_test_passive"])
	assert_bool(resolver.bound_engine() == engine).is_true()
	assert_int(folded).is_equal(3 + RecordingResolver.FOLD_DELTA)
	assert_array(resolver.folds.map(func(f: Dictionary) -> String: return f.effect_id)).is_equal(["boss_test_passive.0"])
	assert_array(resolver.runs.map(func(r: Dictionary) -> String: return r.effect_id)).is_equal(["treasure_signet.0"])
	engine.end_match()


func test_end_match_unbinds_clearing_the_engine_reference_and_the_evaluators() -> void:
	# Arrange
	var resolver: RecordingResolver = RecordingResolver.new(FakeCardDatabase.new(), _effects_config())
	var engine: RulesEngine = _start(resolver, _installers("on_turn_start"))
	var hooks: HookRegistry = engine.state().hooks

	# Act
	engine.end_match()

	# Assert — no engine; the registry folds through nothing and runs nothing
	assert_object(resolver.bound_engine()).is_null()
	assert_int(hooks.fold(&"modify_cost", &"boss", 3, {})).is_equal(3)
	hooks.run_triggers(&"on_turn_start", &"player", {})
	assert_array(resolver.folds).is_empty()
	assert_array(resolver.runs).is_empty()


func test_base_resolver_evaluators_are_identity_until_stories_014_and_015() -> void:
	# Arrange
	var resolver: EffectResolver = EffectResolver.new(FakeCardDatabase.new(), _effects_config())
	var engine: RulesEngine = _start(resolver, _installers("on_match_start"))
	var entry: Dictionary = engine.state().hooks.entries(&"modify_cost")[0]

	# Act / Assert — the value hook returns its input unchanged
	assert_int(resolver.apply_value_hook(entry, &"boss", 5, {})).is_equal(5)
	engine.end_match()


func test_unbind_without_bind_is_a_no_op() -> void:
	# Arrange
	var resolver: EffectResolver = EffectResolver.new(FakeCardDatabase.new(), _effects_config())

	# Act
	resolver.unbind()

	# Assert
	assert_object(resolver.bound_engine()).is_null()


# --- memo: effects by def_id, derived and rebuildable ---------------------------

func test_effects_of_reads_the_database_once_per_def_id() -> void:
	# Arrange
	var fx: Array = [CardFactory.make_effect("battlecry", [CardFactory.make_op("draw", {"count": 1})])]
	var db: FakeCardDatabase = FakeCardDatabase.new({
		"war_scout": CardFactory.make_minion("war_scout", 2, 2, 1, [], {"effects": fx}),
		"neutral_vanilla": CardFactory.make_minion("neutral_vanilla", 1, 1, 1),
	})
	var resolver: EffectResolver = EffectResolver.new(db, _effects_config())

	# Act
	var first: Array = resolver.effects_of("war_scout")
	var second: Array = resolver.effects_of("war_scout")
	var vanilla: Array = resolver.effects_of("neutral_vanilla")

	# Assert — the definition's effects, one lookup per def_id, none for config
	assert_array(first).is_equal(fx)
	assert_bool(is_same(first, second)).is_true()
	assert_array(vanilla).is_empty()
	assert_dict(db.card_calls).is_equal({"war_scout": 1, "neutral_vanilla": 1})
	assert_int(db.config_calls).is_equal(0)


func test_a_fresh_resolver_starts_with_an_empty_memo() -> void:
	# Arrange — ADR-0007 Decision 3: a clone's resolver rebuilds its memo
	var db: FakeCardDatabase = FakeCardDatabase.new({"neutral_vanilla": CardFactory.make_minion("neutral_vanilla", 1, 1, 1)})
	var live: EffectResolver = EffectResolver.new(db, _effects_config())
	live.effects_of("neutral_vanilla")

	# Act
	var fresh: EffectResolver = EffectResolver.new(db, _effects_config())
	fresh.effects_of("neutral_vanilla")

	# Assert — the fresh resolver looked the def up itself
	assert_int(int(db.card_calls["neutral_vanilla"])).is_equal(2)


# --- AC-41 (resolver half): knobs come from the injected config body ------------

func test_knobs_are_read_from_the_injected_config_body() -> void:
	# Arrange
	var body: Dictionary = _effects_config()
	body["discover_count"] = 5.0
	body.make_read_only()

	# Act
	var resolver: EffectResolver = EffectResolver.new(FakeCardDatabase.new(), body)

	# Assert — the same frozen body, read as given (ints coerced, others as stored)
	assert_bool(is_same(resolver.effects_config(), body)).is_true()
	assert_int(resolver.knob_int("discover_count")).is_equal(5)
	assert_int(resolver.knob_int("effect_static_step_limit")).is_equal(TestConstants.EFFECT_STATIC_STEP_LIMIT)
	assert_bool(resolver.knob("discover_exclude_hand")).is_false()
	assert_str(str(resolver.knob("spell_damage_default"))).is_equal("auto")
	assert_bool(resolver.knob("hooks_before_triggers")).is_true()
