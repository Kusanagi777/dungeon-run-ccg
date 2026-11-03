## Unit tests for win, loss, concede, faults and the MatchResult (story
## match-rules/story-008; design/gdd/match-rules.md C14, C15 `match_ended`,
## States `Ended` and the `log_overflow` row, Edge Cases "Win/loss"; ADR-0007
## `win_loss_check` + `resolver.unbind()` at Ended, ADR-0003 Decision 8,
## ADR-0008 `end_match()`).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan. Damage that ends a match comes from scripted `turn_end` triggers
## on the `TestEffectResolver` (the End step runs `win_loss_check` at step 6,
## after its loop). The `event_cap` path uses the production `EventLog`
## (`log_overflow`, then exactly one more append) — `TestEventLog` fabricates
## its own `match_ended` on overflow.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
## AC-42: the step count `resolution_overflow` reports (story 009's loop passes
## its own; here `fault()` is called directly).
const OVERFLOW_STEPS: int = 1001
## AC-42 stats: damage the player's source deals the boss hero before the end.
const STATS_HIT: int = 3
const DEF_STATS_SOURCE: String = "neutral_test_jab"


# --- helpers -----------------------------------------------------------------

func _engine(log: TestEventLog = null, resolver: TestEffectResolver = null, overrides: Dictionary = {}) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, overrides, {}, resolver)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	return engine


func _hero(engine: RulesEngine, side: String) -> Dictionary:
	return engine.state().players[side].hero


## Leaves [param side]'s hero at exactly [param hp] health.
func _set_health(engine: RulesEngine, side: String, hp: int) -> void:
	var hero: Dictionary = _hero(engine, side)
	hero.damage_taken = engine.max_health(hero) - hp


## Trigger script: 1 damage to each hero, player first (one step, no source).
func _hit_both(engine: RulesEngine, _ctx: Dictionary) -> void:
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		engine.apply_damage(int(engine.state().players[side].hero.entity_id), 1, null)


func _hit_player(engine: RulesEngine, _ctx: Dictionary) -> void:
	engine.apply_damage(int(engine.state().players[SIDE_PLAYER].hero.entity_id), 1, null)


func _hit_boss(engine: RulesEngine, _ctx: Dictionary) -> void:
	engine.apply_damage(int(engine.state().players[SIDE_BOSS].hero.entity_id), 1, null)


func _heal_player(engine: RulesEngine, _ctx: Dictionary) -> void:
	var hero_id: int = int(engine.state().players[SIDE_PLAYER].hero.entity_id)
	engine.apply_heal(hero_id, 1, hero_id)


## A started engine whose player `end_turn` runs [param scripts] as the
## `turn_end` trigger point, both heroes at 1 health.
func _engine_with_end_scripts(log: TestEventLog, resolver: TestEffectResolver, scripts: Array) -> RulesEngine:
	resolver.scripts[&"turn_end"] = scripts
	var engine: RulesEngine = _engine(log, resolver)
	_set_health(engine, SIDE_PLAYER, 1)
	_set_health(engine, SIDE_BOSS, 1)
	return engine


func _assert_rejected(result: Dictionary, code: String) -> void:
	assert_bool(result.accepted).is_false()
	if not result.accepted:
		assert_str(str(result.rejection.code)).is_equal(code)


## An engine whose state sits in [param phase] (a fixture: the phases a
## command cannot yet reach — `choice` before story 016).
func _engine_in_phase(phase: String, active: String = SIDE_PLAYER, pending: Variant = null) -> RulesEngine:
	var engine: RulesEngine = _engine()
	engine.state().phase = phase
	engine.state().active_side = active
	engine.state().pending_choice = pending
	return engine


# --- AC-34: hero_dead and both_dead -----------------------------------------------

func test_both_heroes_at_zero_after_one_action_is_a_boss_win_both_dead() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine_with_end_scripts(log, resolver, [_hit_both])

	# Act
	var result: Dictionary = engine.submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_bool(result.accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)
	var outcome: Dictionary = engine.result()
	assert_str(str(outcome.winner)).is_equal(SIDE_BOSS)
	assert_str(str(outcome.reason)).is_equal(MatchRecords.REASON_BOTH_DEAD)
	assert_str(str(outcome.result)).is_equal(MatchRecords.RESULT_LOSS)
	# both damage_dealt events precede match_ended (DD-M12), which is last
	var types: Array[String] = log.types()
	var hits: Array[Dictionary] = log.of_type(&"damage_dealt")
	assert_int(hits.size()).is_equal(2)
	assert_int(types.rfind("damage_dealt")).is_less(types.find("match_ended"))
	EventLogAssertions.assert_last_type(log, &"match_ended")
	assert_dict(log.last().payload).is_equal(outcome)
	# the boss's turn never started
	assert_int(log.count(&"turn_ended")).is_equal(0)


func test_only_the_player_hero_dead_is_a_boss_win_hero_dead() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine_with_end_scripts(log, TestEffectResolver.new(), [_hit_player])

	# Act
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert
	var outcome: Dictionary = engine.result()
	assert_array([outcome.result, outcome.winner, outcome.reason]).is_equal([MatchRecords.RESULT_LOSS, SIDE_BOSS, MatchRecords.REASON_HERO_DEAD])


func test_only_the_boss_hero_dead_is_a_player_win_hero_dead() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine_with_end_scripts(log, TestEffectResolver.new(), [_hit_boss])

	# Act
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert
	var outcome: Dictionary = engine.result()
	assert_array([outcome.result, outcome.winner, outcome.reason]).is_equal([MatchRecords.RESULT_WIN, SIDE_PLAYER, MatchRecords.REASON_HERO_DEAD])
	assert_int(int(outcome.final_health[SIDE_BOSS])).is_equal(0)
	assert_int(int(outcome.final_health[SIDE_PLAYER])).is_equal(1)


func test_a_hero_at_zero_mid_action_healed_later_in_the_same_action_survives() -> void:
	# Arrange: the player's hero drops to 0, then a later step heals it to 1
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine_with_end_scripts(log, TestEffectResolver.new(), [_hit_player, _heal_player])

	# Act
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert: the check ran only at the end — the match goes on to the boss's turn
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_str(String(engine.active_side())).is_equal(SIDE_BOSS)
	assert_that(engine.result()).is_null()
	assert_int(int(log.of_type(&"damage_dealt")[0].payload.health_after)).is_equal(0)
	assert_int(engine.health(_hero(engine, SIDE_PLAYER))).is_equal(1)


func test_win_loss_check_on_a_living_match_changes_nothing() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var before: int = log.events.size()

	# Act (the engine-internal C14 check, run at the end of every action)
	var ended: bool = engine._win_loss_check()

	# Assert
	assert_bool(ended).is_false()
	assert_int(log.events.size()).is_equal(before)
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)


# --- AC-35: concede -------------------------------------------------------------

func test_player_concede_during_the_boss_main_ends_the_match_for_the_boss() -> void:
	# Arrange: the boss's Main phase
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_str(String(engine.active_side())).is_equal(SIDE_BOSS)

	# Act
	var conceded: Dictionary = engine.submit(MatchRecords.concede())
	var late: Dictionary = engine.submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	assert_bool(conceded.accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)
	var outcome: Dictionary = engine.result()
	assert_array([outcome.result, outcome.winner, outcome.reason]).is_equal([MatchRecords.RESULT_LOSS, SIDE_BOSS, MatchRecords.REASON_CONCEDE])
	assert_int(int(conceded.events[1])).is_equal(int(log.last().seq))
	EventLogAssertions.assert_last_type(log, &"match_ended")
	_assert_rejected(late, "MATCH_ENDED")
	assert_array(engine.legal_commands()).is_empty()
	assert_int(resolver.unbind_count).is_equal(1)


func test_concede_is_accepted_in_mulligan_and_choice() -> void:
	# Arrange
	var in_mulligan: RulesEngine = MatchFactory.make_started_engine()
	var in_choice: RulesEngine = _engine_in_phase(MatchState.PHASE_CHOICE, SIDE_BOSS, {"side": SIDE_BOSS, "options": [0, 1]})

	# Act
	var from_mulligan: Dictionary = in_mulligan.submit(MatchRecords.concede())
	var from_choice: Dictionary = in_choice.submit(MatchRecords.concede())

	# Assert
	for pair: Array in [[from_mulligan, in_mulligan], [from_choice, in_choice]]:
		assert_bool(pair[0].accepted).is_true()
		var engine: RulesEngine = pair[1]
		assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)
		assert_str(str(engine.result().reason)).is_equal(MatchRecords.REASON_CONCEDE)


func test_concede_from_the_boss_issuer_is_rejected_in_every_phase() -> void:
	# Arrange: Mulligan, boss Main and Choice owed by the boss
	var in_mulligan: RulesEngine = MatchFactory.make_started_engine()
	var in_boss_main: RulesEngine = _engine()
	assert_bool(in_boss_main.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var in_choice: RulesEngine = _engine_in_phase(MatchState.PHASE_CHOICE, SIDE_BOSS, {"side": SIDE_BOSS, "options": [0, 1]})

	# Act / Assert: concede's row is issuer = PLAYER (C2); the phase guard's
	# ordered checks answer WRONG_PHASE for a disallowed issuer of a player-only row
	for engine: RulesEngine in [in_mulligan, in_boss_main, in_choice]:
		_assert_rejected(engine.submit(MatchRecords.concede(SIDE_BOSS)), "WRONG_PHASE")
		assert_bool(engine.phase() != MatchState.PHASE_ENDED).is_true()


func test_concede_after_ended_is_match_ended() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	assert_bool(engine.submit(MatchRecords.concede()).accepted).is_true()

	# Act / Assert: MATCH_ENDED is checked before the issuer
	_assert_rejected(engine.submit(MatchRecords.concede()), "MATCH_ENDED")
	_assert_rejected(engine.submit(MatchRecords.concede(SIDE_BOSS)), "MATCH_ENDED")


# --- AC-42: the MatchResult, faults, unbind and teardown --------------------------

func test_match_result_carries_the_c14_fields_and_both_sides_stats() -> void:
	# Arrange: the player's source deals 3 to the boss hero, then the player concedes
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var state: MatchState = engine.state()
	var jab: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 1, 1, -1, [], DEF_STATS_SOURCE)
	engine.apply_damage(int(_hero(engine, SIDE_BOSS).entity_id), STATS_HIT, int(jab.entity_id))

	# Act
	assert_bool(engine.submit(MatchRecords.concede()).accepted).is_true()

	# Assert
	var outcome: Dictionary = engine.result()
	var template: Dictionary = MatchFactory.make_match_result()
	assert_array(outcome.keys()).contains_exactly_in_any_order(template.keys())
	assert_array(outcome.stats.keys()).contains_exactly_in_any_order([SIDE_PLAYER, SIDE_BOSS])
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		assert_array(outcome.stats[side].keys()).contains_exactly_in_any_order(MatchRecords.empty_stats().keys())
	assert_int(int(outcome.stats[SIDE_PLAYER].damage_dealt_by_card[DEF_STATS_SOURCE])).is_equal(STATS_HIT)
	assert_int(int(outcome.stats[SIDE_BOSS].damage_taken)).is_equal(STATS_HIT)
	assert_int(int(outcome.stats[SIDE_PLAYER].minions_summoned)).is_equal(1)
	assert_int(int(outcome.floor)).is_equal(1)
	assert_int(int(outcome.turns)).is_equal(1)
	assert_dict(outcome.turns_per_side).is_equal({SIDE_PLAYER: 1, SIDE_BOSS: 0})
	assert_dict(outcome.final_health).is_equal({
		SIDE_PLAYER: TestConstants.PLAYER_STARTING_HEALTH,
		SIDE_BOSS: MatchFactory.boss_health_for_band(1) - STATS_HIT,
	})
	assert_bool(outcome.has("seed")).is_false()
	GameAssertions.assert_json_representable(outcome, "MatchResult")
	# result() is a value copy: the stats block is not the live one
	outcome.stats[SIDE_BOSS].damage_taken = 99
	assert_int(int(state.players[SIDE_BOSS].stats.damage_taken)).is_equal(STATS_HIT)
	assert_int(int(engine.result().stats[SIDE_BOSS].damage_taken)).is_equal(STATS_HIT)


func test_resolution_overflow_fault_has_no_winner_and_seals_the_log() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var before: int = log.events.size()

	# Act
	engine.fault(MatchRecords.REASON_RESOLUTION_OVERFLOW, OVERFLOW_STEPS)

	# Assert
	var events: Array[Dictionary] = log.events.slice(before)
	assert_array(log.types().slice(before)).is_equal(["resolution_overflow", "match_ended"])
	assert_dict(events[0].payload).is_equal({"steps": OVERFLOW_STEPS})
	var outcome: Dictionary = engine.result()
	assert_str(str(outcome.result)).is_equal(MatchRecords.RESULT_FAULT)
	assert_that(outcome.winner).is_null()
	assert_str(str(outcome.reason)).is_equal(MatchRecords.REASON_RESOLUTION_OVERFLOW)
	assert_bool(log.sealed).is_true()
	assert_int(resolver.unbind_count).is_equal(1)
	assert_that(resolver.engine).is_null()
	_assert_rejected(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)), "MATCH_ENDED")


func test_log_overflow_ends_the_match_with_exactly_one_event_cap_match_ended() -> void:
	# Arrange: a reference run counts the events before the first Start step's
	# mana_refilled; the real log's cap is that count, so that append overflows
	var reference_log: TestEventLog = TestEventLog.new()
	_engine(reference_log)
	var cap: int = reference_log.types().find("mana_refilled")
	var log: EventLog = EventLog.new(cap, EventLog.SCOPE_MATCH)
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), null, {"log": log})
	var engine: RulesEngine = RulesEngine.new(null, MatchFactory.make_rules_config(), resolver)
	engine.start(config)
	var hand_before: int = engine.state().players[SIDE_PLAYER].hand.size()

	# Act: keep all → match_started → the Start step overflows the log
	var result: Dictionary = engine.submit(engine.legal_commands()[0])

	# Assert: log_overflow, then exactly one more event — match_ended(fault)
	var events: Array[Dictionary] = log.events_since(0)
	assert_int(events.size()).is_equal(cap + 2)
	assert_str(str(events[cap].type)).is_equal("log_overflow")
	EventLogAssertions.assert_last_type(events, &"match_ended")
	assert_int(EventLogAssertions.count_type(events, &"match_ended")).is_equal(1)
	var payload: Dictionary = events[cap + 1].payload
	assert_array([payload.result, payload.reason, payload.winner]).is_equal([MatchRecords.RESULT_FAULT, MatchRecords.REASON_EVENT_CAP, null])
	assert_bool(log.is_sealed()).is_true()
	assert_bool(result.accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)
	assert_int(resolver.unbind_count).is_equal(1)
	# the engine stopped: the Start step's draw never happened
	assert_int(engine.state().players[SIDE_PLAYER].hand.size()).is_equal(hand_before)


## A started engine past the mulligan on a production `EventLog` whose cap is
## exactly the events a "keep all" mulligan leaves (counted on a reference
## run), so the log is full and still Open.
func _engine_on_a_full_log(resolver: TestEffectResolver) -> RulesEngine:
	var reference_log: TestEventLog = TestEventLog.new()
	_engine(reference_log)
	var log: EventLog = EventLog.new(reference_log.events.size(), EventLog.SCOPE_MATCH)
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), null, {"log": log})
	var engine: RulesEngine = RulesEngine.new(null, MatchFactory.make_rules_config(), resolver)
	engine.start(config)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	assert_int(log.state()).is_equal(EventLog.State.OPEN)
	return engine


func test_match_ended_refused_at_the_log_cap_is_logged_as_an_event_cap_fault() -> void:
	# Arrange: the log is full, so concede's match_ended is the append that overflows
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine_on_a_full_log(resolver)
	var log: EventLog = engine.state().log as EventLog
	var cap: int = log.max_events()

	# Act
	var result: Dictionary = engine.submit(MatchRecords.concede())

	# Assert: log_overflow, then one match_ended(fault, event_cap); the log sealed
	var events: Array[Dictionary] = log.events_since(0)
	assert_int(events.size()).is_equal(cap + 2)
	assert_str(str(events[cap].type)).is_equal("log_overflow")
	EventLogAssertions.assert_last_type(events, &"match_ended")
	assert_int(EventLogAssertions.count_type(events, &"match_ended")).is_equal(1)
	var payload: Dictionary = events[events.size() - 1].payload
	assert_array([payload.result, payload.reason, payload.winner]).is_equal([MatchRecords.RESULT_FAULT, MatchRecords.REASON_EVENT_CAP, null])
	assert_bool(log.is_sealed()).is_true()
	assert_bool(result.accepted).is_true()
	var outcome: Dictionary = engine.result()
	assert_array([outcome.result, outcome.reason, outcome.winner]).is_equal([MatchRecords.RESULT_FAULT, MatchRecords.REASON_EVENT_CAP, null])
	assert_int(resolver.unbind_count).is_equal(1)


func test_rejection_that_overflows_the_log_returns_an_empty_event_range() -> void:
	# Arrange: the log is full; the boss's end_turn is NOT_YOUR_TURN
	var engine: RulesEngine = _engine_on_a_full_log(TestEffectResolver.new())

	# Act: its command_rejected diagnostic is the append that overflows
	var result: Dictionary = engine.submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert: rejected with range [0, 0], and the match faulted on event_cap
	_assert_rejected(result, "NOT_YOUR_TURN")
	assert_array(result.events).is_equal([0, 0])
	assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)
	assert_str(str(engine.result().reason)).is_equal(MatchRecords.REASON_EVENT_CAP)


func test_submit_after_end_match_on_a_live_engine_is_match_ended() -> void:
	# Arrange: a live match torn down by the driver's teardown entry
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var turn: int = engine.state().turn
	engine.end_match()
	var before: int = log.events.size()

	# Act
	var result: Dictionary = engine.submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert: rejected, unlogged, nothing moved
	_assert_rejected(result, "MATCH_ENDED")
	assert_array(result.events).is_equal([0, 0])
	assert_int(log.events.size()).is_equal(before)
	assert_int(engine.state().turn).is_equal(turn)


func test_ended_engine_is_collected_after_unbind() -> void:
	# Arrange: a weak reference only, once the match has ended
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(null, resolver)
	var watched: WeakRef = weakref(engine)
	assert_bool(engine.submit(MatchRecords.concede()).accepted).is_true()

	# Act: the driver's end_match() is idempotent once Ended; drop the strong ref
	engine.end_match()
	engine = null

	# Assert: unbind() broke the engine↔resolver cycle
	assert_int(resolver.unbind_count).is_equal(1)
	assert_that(watched.get_ref()).is_null()


func test_end_match_on_a_live_engine_unbinds_once() -> void:
	# Arrange: the teardown entry called before the match ended (card-effects
	# story 002's teardown test, an abandoned attempt)
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var boost: HookInstaller = HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, "t_whet", &"player", [{
		"id": "t_whet.0", "trigger": "modify_damage", "scope": {}, "condition": {},
		"ops": [{"op": TestEffectResolver.OP_MODIFY_VALUE, "delta": 2}], "once_per_turn": false,
	}])
	var engine: RulesEngine = _engine(null, resolver, {"player": {"hook_installers": [boost]}})
	var watched: WeakRef = weakref(engine)
	var hooks: HookRegistry = engine.state().hooks
	var folded_while_bound: int = hooks.fold(&"modify_damage", &"player", 1, {})

	# Act
	engine.end_match()
	engine.end_match()
	engine = null

	# Assert: unbound once, collectable, the registry's evaluators unset
	assert_int(resolver.unbind_count).is_equal(1)
	assert_that(watched.get_ref()).is_null()
	assert_int(folded_while_bound).is_equal(3)
	assert_int(hooks.fold(&"modify_damage", &"player", 1, {})).is_equal(1)


func test_match_ended_signal_fires_once_with_the_result() -> void:
	# Arrange: the unit-test convenience signal (ADR-0008: never connected in production)
	var engine: RulesEngine = _engine()
	var seen: Array = []
	engine.match_ended.connect(func(outcome: Dictionary) -> void: seen.append(outcome))

	# Act
	assert_bool(engine.submit(MatchRecords.concede()).accepted).is_true()
	engine.end_match()

	# Assert
	assert_int(seen.size()).is_equal(1)
	assert_dict(seen[0]).is_equal(engine.result())
