## Unit tests for the Boss AI scorer (story boss-ai-match-driver/story-004;
## design/gdd/boss-ai.md C4, C5, C6, F1, F2, F3, F5, Edge Cases "board full"
## and "sandbox `resolution_overflow`", A11, A13, A14, A18; ADR-0006;
## TR-boss-ai-001).
##
## Every acceptance case is a board setup under `tests/fixtures/boss_ai/`
## played on the production `EffectResolver` ([BossAiBoard]); the expected
## numbers are read from the fixture where the GDD pins them (A11's 2.45 /
## 1.87 / −1.0 / −0.33) and written out only where the number is the point
## (A13's `1/7`, F2 / F3 examples, A18's ×1.25). `score_all` is a coroutine,
## so the tests await it with an `ImmediatePlannerTask` (no worker thread,
## ADR-0006). Each fixture test also asserts that no scored candidate needed a
## sandbox Choice answer (the BAI-010 placeholder; story readiness note).
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
## Float tolerance for sums the GDD states exactly.
const EPSILON: float = 1e-9
## The overflow fixture's two scripted boss minions and spell.
const OVERFLOW_SPELL: String = "bai_test_mend"
const OVERFLOW_MINION: String = "bai_test_twin"


## A [PlannerTask] that counts `checkpoint()` calls.
class CountingPlanner:
	extends PlannerTask

	var checkpoints: int = 0

	func start(work: Callable) -> void:
		_result = work.call()
		return

	func poll() -> bool:
		return true

	func checkpoint() -> void:
		checkpoints += 1
		return


## A plain card lookup for the scripted-resolver overflow fixture.
class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


# --- helpers -----------------------------------------------------------------

func _scorer(db: Variant) -> Scorer:
	return Scorer.new(db, BossAiBoard.keyword_values())


func _score_all(scorer: Scorer, engine: RulesEngine, profile: Dictionary, context: Dictionary = {}) -> Array:
	var base: RulesEngine = engine.clone()
	var scored: Array = await scorer.score_all(base, base.legal_commands(), profile, Scorer.MODE_NORMAL, context, ImmediatePlannerTask.new())
	base.end_match()
	return scored


func _entry_of_type(scored: Array, type: String) -> Dictionary:
	for entry: Dictionary in scored:
		if str(entry.command.type) == type:
			return entry
	return {}


func _entry_where(scored: Array, type: String, key: String, value: Variant) -> Dictionary:
	for entry: Dictionary in scored:
		if str(entry.command.type) == type and entry.command.get(key) == value:
			return entry
	return {}


func _assert_no_sandbox_choice(scored: Array) -> void:
	for entry: Dictionary in scored:
		assert_bool(entry.sim_choice_placeholder).override_failure_message("a sandbox Choice was raised by %s" % str(entry.command)).is_false()


# --- static helpers: F2, F3 ------------------------------------------------------

func test_board_value_and_threat_match_the_f2_example() -> void:
	# Arrange — F2: a 3/2 Divine Shield Taunt
	var keyword_values: Dictionary = BossAiBoard.keyword_values()
	var keywords: Array = [MatchRecords.KEYWORD_DIVINE_SHIELD, MatchRecords.KEYWORD_TAUNT]

	# Act
	var bv: float = Scorer.board_value(3, 2, keywords, keyword_values)
	var threat: float = Scorer.threat(3, keywords, false)

	# Assert — (3+2)·1.3·1.2 = 7.8; threat 3 + 1.5 = 4.5
	assert_float(bv).is_equal_approx(7.8, EPSILON)
	assert_float(threat).is_equal_approx(4.5, EPSILON)


func test_trade_quality_matches_the_f3_example_and_rows() -> void:
	# Arrange — F3: a 4/4 (BV 8) into a 5/2 (BV 7), both die, trade_ratio 1.0
	var ratio: float = 1.0

	# Act / Assert
	assert_int(Scorer.trade_quality(8.0, 7.0, true, true, ratio)).is_equal(0)
	assert_int(Scorer.trade_quality(8.0, 7.0, false, true, ratio)).is_equal(1)
	assert_int(Scorer.trade_quality(8.0, 8.0, true, true, ratio)).is_equal(1)
	assert_int(Scorer.trade_quality(8.0, 2.0, true, true, ratio)).is_equal(-1)
	assert_int(Scorer.trade_quality(8.0, 7.0, false, false, ratio)).is_equal(-1)


# --- A11: the F1 worked example --------------------------------------------------

func test_f1_worked_example_plays_trade_then_four_four_then_end_turn_at_the_gdd_scores() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var scorer: Scorer = _scorer(db)
	var expect: Dictionary = fixture.expect
	var chosen_types: Array[String] = []
	var chosen_scores: Array[float] = []
	var end_turn_scores: Array[float] = []

	# Act — the test's own action loop (play_turn is story 008): score, submit the best
	while engine.phase() == MatchState.PHASE_MAIN and String(engine.active_side()) == SIDE_BOSS:
		var scored: Array = await _score_all(scorer, engine, profile)
		_assert_no_sandbox_choice(scored)
		var best: Dictionary = scored[0]
		chosen_types.append(str(best.command.type))
		chosen_scores.append(float(best.score))
		end_turn_scores.append(float(_entry_of_type(scored, MatchRecords.CMD_END_TURN).score))
		assert_bool(engine.submit(best.command).accepted).is_true()

	# Assert
	assert_array(chosen_types).is_equal(Array(expect.order, TYPE_STRING, &"", null))
	for i: int in (expect.scores as Array).size():
		assert_float(chosen_scores[i]).is_equal_approx(float(expect.scores[i]), float(expect.tolerance))
	assert_float(end_turn_scores[0]).is_equal_approx(float(expect.end_turn[0]), float(expect.tolerance))
	assert_float(end_turn_scores[end_turn_scores.size() - 1]).is_equal_approx(float(expect.end_turn[1]), float(expect.tolerance))


func test_f1_trade_features_are_the_worked_example_terms() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)

	# Act
	var scored: Array = await _score_all(_scorer(db), engine, BossAiBoard.profile(fixture))
	var trade: Dictionary = _entry_of_type(scored, MatchRecords.CMD_ATTACK)

	# Assert — F1: f_board 0.4, f_trade +1, f_threat (2+1.5)/12, f_card 1/3, f_mana 0
	assert_array(trade.features.keys()).contains_exactly(Scorer.FEATURE_KEYS)
	assert_float(trade.features.f_board).is_equal_approx(0.4, EPSILON)
	assert_float(trade.features.f_trade).is_equal(1.0)
	assert_float(trade.features.f_threat).is_equal_approx(3.5 / 12.0, EPSILON)
	assert_float(trade.features.f_card).is_equal_approx(1.0 / 3.0, EPSILON)
	assert_float(trade.features.f_mana).is_equal(0.0)


# --- A13: aoe_seen and the over-extension cap -----------------------------------------

func test_aoe_seen_lowers_a_fifth_minion_play_by_exactly_one_seventh() -> void:
	# Arrange — the player cast an all_enemy_minions spell on turn 1
	var fixture: Dictionary = BossAiBoard.read("aoe_seen_board")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = BossAiBoard.engine(fixture, db, [fixture.aoe_cast], log)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var scorer: Scorer = _scorer(db)
	var aoe_seen: bool = Scorer.aoe_seen_in(log.events, db, SIDE_PLAYER)
	var rightmost: int = int(fixture.expect.boss_board)

	# Act
	var seen: Array = await _score_all(scorer, engine, profile, {"aoe_seen": aoe_seen})
	var unseen: Array = await _score_all(scorer, engine, profile, {"aoe_seen": false})

	# Assert — boss board 4 → 5 > cap 4: f_over = −1/7, × w_over (1)
	assert_bool(aoe_seen).is_true()
	assert_int(engine.state().players[SIDE_BOSS].board.size()).is_equal(rightmost)
	_assert_no_sandbox_choice(seen)
	var with_aoe: Dictionary = _entry_where(seen, MatchRecords.CMD_PLAY_CARD, "position", rightmost)
	var without: Dictionary = _entry_where(unseen, MatchRecords.CMD_PLAY_CARD, "position", rightmost)
	assert_float(float(profile.weights.w_over)).is_equal(1.0)
	assert_float(without.score - with_aoe.score).is_equal_approx(1.0 / float(TestConstants.BOARD_SIZE), EPSILON)
	assert_float(with_aoe.features.f_over).is_equal_approx(-1.0 / float(TestConstants.BOARD_SIZE), EPSILON)


func test_aoe_seen_is_false_after_a_single_target_spell() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("aoe_seen_board")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	BossAiBoard.engine(fixture, db, [fixture.plain_cast], log)

	# Act
	var aoe_seen: bool = Scorer.aoe_seen_in(log.events, db, SIDE_PLAYER)

	# Assert
	assert_int(log.count(&"card_played")).is_equal(1)
	assert_bool(aoe_seen).is_false()


func test_assume_aoe_applies_the_cap_without_a_seen_spell() -> void:
	# Arrange — F5: `rules.assume_aoe` (band 3 vs the Knowledge hero)
	var fixture: Dictionary = BossAiBoard.read("aoe_seen_board")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	profile.rules["assume_aoe"] = true
	var rightmost: int = int(fixture.expect.boss_board)

	# Act
	var scored: Array = await _score_all(_scorer(db), engine, profile, {"aoe_seen": false})

	# Assert
	var play: Dictionary = _entry_where(scored, MatchRecords.CMD_PLAY_CARD, "position", rightmost)
	assert_float(play.features.f_over).is_equal_approx(-1.0 / float(TestConstants.BOARD_SIZE), EPSILON)


func test_is_aoe_derives_the_c6_annotation_from_the_effect_spec() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("aoe_seen_board")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var friendly_buff: Dictionary = CardFactory.make_spell("bai_test_rally", 1, [CardFactory.make_effect("cast", [CardFactory.make_op("buff", {"attack": 1})], {}, {"targets": "all_friendly_minions"})])
	var shrink: Dictionary = CardFactory.make_spell("bai_test_wither", 1, [CardFactory.make_effect("cast", [CardFactory.make_op("buff", {"attack": -1})], {}, {"targets": "all_enemy_minions"})])
	var nested: Dictionary = CardFactory.make_spell("bai_test_storm", 1, [CardFactory.make_effect("cast", [CardFactory.make_op("repeat", {"times": 2, "ops": [CardFactory.make_op("damage", {"amount": 1, "targets": "all_characters"})]})])])

	# Act / Assert
	assert_bool(Scorer.is_aoe(db.card(str(fixture.aoe_cast)))).is_true()
	assert_bool(Scorer.is_aoe(db.card(str(fixture.plain_cast)))).is_false()
	assert_bool(Scorer.is_aoe(friendly_buff)).is_false()
	assert_bool(Scorer.is_aoe(shrink)).is_true()
	assert_bool(Scorer.is_aoe(nested)).is_true()


# --- A14: target choice emerges from f_threat --------------------------------------

func test_control_fireball_targets_the_six_six() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("fireball_targets")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var giant: int = BossAiBoard.ids_of(engine, SIDE_PLAYER, str(fixture.expect.target))[0]

	# Act
	var scored: Array = await _score_all(_scorer(db), engine, BossAiBoard.profile(fixture))

	# Assert
	_assert_no_sandbox_choice(scored)
	var plays: Array = scored.filter(func(e: Dictionary) -> bool: return str(e.command.type) == MatchRecords.CMD_PLAY_CARD)
	assert_int(plays.size()).is_equal(int(fixture.expect.spell_targets))
	assert_str(str(scored[0].command.type)).is_equal(MatchRecords.CMD_PLAY_CARD)
	assert_int(int(scored[0].command.target_id)).is_equal(giant)
	assert_float(scored[0].features.f_threat).is_greater(plays[1].features.f_threat)


# --- A18: board-full threat weight ------------------------------------------------------

func test_full_player_board_makes_removal_beat_an_equal_face_attack() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("player_board_full")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var target: int = BossAiBoard.ids_of(engine, SIDE_PLAYER, str(fixture.expect.removal_target))[0]
	var hero: int = int(engine.state().players[SIDE_PLAYER].hero.entity_id)

	# Act
	var scored: Array = await _score_all(_scorer(db), engine, profile)

	# Assert — removal 1.0·0.9 + 2.4·1.25/12 = 1.15 vs face 1.1
	_assert_no_sandbox_choice(scored)
	assert_int(engine.state().players[SIDE_PLAYER].board.size()).is_equal(TestConstants.BOARD_SIZE)
	var removal: Dictionary = _entry_where(scored, MatchRecords.CMD_PLAY_CARD, "target_id", target)
	var face: Dictionary = _entry_where(scored, MatchRecords.CMD_ATTACK, "target_id", hero)
	assert_dict(scored[0].command).is_equal(removal.command)
	var raise: float = float(profile.weights.w_threat) * (1.25 - 1.0) * removal.features.f_threat
	assert_float(removal.score - face.score).is_equal_approx(raise, EPSILON)


func test_player_board_of_six_leaves_removal_and_face_attack_equal() -> void:
	# Arrange — the boundary: one Stealth filler fewer, no ×1.25
	var fixture: Dictionary = BossAiBoard.read("player_board_full")
	fixture.player.board.erase(fixture.expect.filler)
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var target: int = BossAiBoard.ids_of(engine, SIDE_PLAYER, str(fixture.expect.removal_target))[0]
	var hero: int = int(engine.state().players[SIDE_PLAYER].hero.entity_id)

	# Act
	var scored: Array = await _score_all(_scorer(db), engine, BossAiBoard.profile(fixture))

	# Assert
	assert_int(engine.state().players[SIDE_PLAYER].board.size()).is_equal(TestConstants.BOARD_SIZE - 1)
	var removal: Dictionary = _entry_where(scored, MatchRecords.CMD_PLAY_CARD, "target_id", target)
	var face: Dictionary = _entry_where(scored, MatchRecords.CMD_ATTACK, "target_id", hero)
	assert_float(removal.score).is_equal_approx(face.score, EPSILON)


# --- isolation, coroutine, Edge Cases ------------------------------------------------------

func test_score_all_leaves_the_live_engine_log_stream_and_state_unchanged() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = BossAiBoard.engine(fixture, db, [], log)
	var events_before: int = log.events.size()
	var draws_before: int = engine.rng_match().draws
	var players_before: Dictionary = engine.state().players.duplicate(true)

	# Act
	var scored: Array = await _score_all(_scorer(db), engine, BossAiBoard.profile(fixture))

	# Assert
	assert_array(scored).is_not_empty()
	assert_int(log.events.size()).is_equal(events_before)
	assert_int(engine.rng_match().draws).is_equal(draws_before)
	assert_dict(engine.state().players).is_equal(players_before)


func test_score_all_awaits_one_checkpoint_per_candidate() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var base: RulesEngine = engine.clone()
	var candidates: Array = base.legal_commands()
	var planner: CountingPlanner = CountingPlanner.new()

	# Act
	var scored: Array = await _scorer(db).score_all(base, candidates, BossAiBoard.profile(fixture), Scorer.MODE_NORMAL, {}, planner)
	base.end_match()

	# Assert
	assert_int(scored.size()).is_equal(candidates.size())
	assert_int(planner.checkpoints).is_equal(candidates.size())


func test_end_turn_is_scored_without_simulation_as_the_mana_waste_penalty() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var base: RulesEngine = engine.clone()
	var scratch: Variant = base.state().log
	var events_before: int = scratch.size()

	# Act
	var entry: Dictionary = _scorer(db).score(MatchRecords.end_turn(SIDE_BOSS), base, BossAiBoard.profile(fixture), Scorer.MODE_NORMAL, {})

	# Assert — every delta 0, f_mana −6/6, and the base sandbox did not move
	for key: String in Scorer.FEATURE_KEYS:
		if key != "f_mana":
			assert_float(entry.features[key]).override_failure_message(key).is_equal(0.0)
	assert_float(entry.features.f_mana).is_equal(-1.0)
	assert_int(scratch.size()).is_equal(events_before)
	assert_str(base.phase()).is_equal(MatchState.PHASE_MAIN)
	base.end_match()


func test_battlecry_minion_with_no_legal_target_is_scored_as_its_body() -> void:
	# Arrange — a "deal 2 to a chosen enemy minion" Battlecry 2/2 and a vanilla 2/2, empty enemy board
	var fixture: Dictionary = BossAiBoard.read("battlecry_no_target")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)

	# Act
	var scored: Array = await _score_all(_scorer(db), engine, BossAiBoard.profile(fixture))

	# Assert
	_assert_no_sandbox_choice(scored)
	var battlecry: Dictionary = _entry_where(scored, MatchRecords.CMD_PLAY_CARD, "hand_index", 0)
	var vanilla: Dictionary = _entry_where(scored, MatchRecords.CMD_PLAY_CARD, "hand_index", 1)
	assert_that(battlecry.command.target_id).is_null()
	assert_float(battlecry.score).is_equal_approx(vanilla.score, EPSILON)
	assert_dict(battlecry.features).is_equal(vanilla.features)


func test_defensive_mode_adds_the_taunt_board_value_bonus() -> void:
	# Arrange — F2 / States DEFENSIVE: a Taunt minion is worth +0.5 BV
	var keyword_values: Dictionary = BossAiBoard.keyword_values()
	var taunt: Array = [MatchRecords.KEYWORD_TAUNT]

	# Act
	var normal: float = Scorer.board_value(2, 3, taunt, keyword_values, 0, false, false)
	var defensive: float = Scorer.board_value(2, 3, taunt, keyword_values, 0, false, true)
	var plain: float = Scorer.board_value(2, 3, [], keyword_values, 0, false, true)

	# Assert
	assert_float(defensive - normal).is_equal_approx(0.5, EPSILON)
	assert_float(plain).is_equal_approx(5.0, EPSILON)


func test_sandbox_resolution_overflow_scores_negative_infinity_and_leaves_live_untouched() -> void:
	# Arrange — two boss minions that heal each other forever (AC-30's ping-pong), a spell that starts it
	var db: FixtureDb = FixtureDb.new()
	db.cards[OVERFLOW_SPELL] = CardFactory.make_spell(OVERFLOW_SPELL, 0)
	db.cards[OVERFLOW_MINION] = CardFactory.make_minion(OVERFLOW_MINION, 1, 1, 3)
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var deck: Array = []
	for _i: int in BossAiBoard.DECK_SIZE:
		deck.append(OVERFLOW_MINION)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = MatchFactory.make_started_engine(TestRngService.new(BossAiBoard.SETUP_SEED), log, {"player": {"deck": deck}, "boss": {"deck": deck.duplicate()}}, {}, resolver, db)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var state: MatchState = engine.state()
	var twins: Array[int] = []
	for _i: int in 2:
		var twin: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 1, 3, -1, [], OVERFLOW_MINION)
		twins.append(int(twin.entity_id))
	resolver.add_heal_ping_pong(twins[0], twins[1])
	resolver.scripts[&"on_cast"] = [func(e: RulesEngine, _ctx: Dictionary) -> void:
		@warning_ignore("return_value_discarded")
		e.apply_heal(twins[0], 1, null)]
	(state.players[SIDE_BOSS].hand as Array).clear()
	BossAiBoard.add_to_hand(engine, SIDE_BOSS, OVERFLOW_SPELL)
	var events_before: int = log.events.size()
	var cast: Dictionary = MatchRecords.play_card(SIDE_BOSS, 0, null, null)

	# Act
	var base: RulesEngine = engine.clone()
	var base_resolver: TestEffectResolver = resolver.last_clone.get_ref()
	var entry: Dictionary = Scorer.new(db, BossAiBoard.keyword_values()).score(cast, base, BossAiBoard.profile(BossAiBoard.read("f1_worked_example")), Scorer.MODE_NORMAL, {})
	base.end_match()

	# Assert — and nothing of the overflowed trial is left alive (a fault ends
	# the match, which unbinds; the scorer's `end_match()` is then a no-op)
	assert_bool(entry.sim_overflow).is_true()
	assert_float(entry.score).is_equal(-INF)
	assert_int(log.events.size()).is_equal(events_before)
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_object(base_resolver.last_clone.get_ref()).is_null()


func test_score_all_ends_every_trial_clone_so_none_stays_alive() -> void:
	# Arrange — the scripted resolver records a weakref to each clone's resolver
	var db: FixtureDb = FixtureDb.new()
	db.cards[OVERFLOW_MINION] = CardFactory.make_minion(OVERFLOW_MINION, 1, 1, 3)
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var deck: Array = []
	for _i: int in BossAiBoard.DECK_SIZE:
		deck.append(OVERFLOW_MINION)
	var engine: RulesEngine = MatchFactory.make_started_engine(TestRngService.new(BossAiBoard.SETUP_SEED), TestEventLog.new(), {"player": {"deck": deck}, "boss": {"deck": deck.duplicate()}}, {}, resolver, db)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var base: RulesEngine = engine.clone()
	var base_resolver: TestEffectResolver = resolver.last_clone.get_ref()
	var candidates: Array = base.legal_commands()
	var trials: Array[WeakRef] = []
	var watcher: CountingPlanner = CountingPlanner.new()

	# Act — after each evaluation, the trial's resolver must already be gone
	var scorer: Scorer = Scorer.new(db, BossAiBoard.keyword_values())
	for command: Dictionary in candidates:
		@warning_ignore("return_value_discarded")
		scorer.score(command, base, BossAiBoard.profile(BossAiBoard.read("f1_worked_example")), Scorer.MODE_NORMAL, {})
		trials.append(base_resolver.last_clone)
	var scored: Array = await scorer.score_all(base, candidates, BossAiBoard.profile(BossAiBoard.read("f1_worked_example")), Scorer.MODE_NORMAL, {}, watcher)
	# the early-return path: a command the trial rejects (never from legal_commands)
	var rejected: Dictionary = scorer.score(MatchRecords.play_card(SIDE_BOSS, TestConstants.HAND_SIZE, null, null), base, BossAiBoard.profile(BossAiBoard.read("f1_worked_example")), Scorer.MODE_NORMAL, {})
	var rejected_trial: WeakRef = base_resolver.last_clone
	base.end_match()

	# Assert — every trial gone, the rejected one too (its match never ended,
	# so only the scorer's `end_match()` breaks its engine–resolver cycle:
	# review 2026-11-04 S4-MR015/017 note 3); end_turn is never simulated
	assert_float(rejected.score).is_equal(-INF)
	assert_bool(rejected.sim_overflow).is_false()
	assert_object(rejected_trial.get_ref()).is_null()
	assert_int(scored.size()).is_equal(candidates.size())
	assert_bool(candidates.any(func(c: Dictionary) -> bool: return str(c.type) == MatchRecords.CMD_PLAY_CARD)).is_true()
	for trial: WeakRef in trials:
		if trial != null:
			assert_object(trial.get_ref()).is_null()
	assert_object(base_resolver.last_clone.get_ref()).is_null()
