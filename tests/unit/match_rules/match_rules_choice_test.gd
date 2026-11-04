## Unit tests for the Choice phase and the Discover continuation (story
## match-rules/story-016; design/gdd/match-rules.md C2 `choose` row,
## `CHOICE_PENDING` / `INVALID_CHOICE`, States `Choice` and its transition
## rows, C12 Discover, Edge Cases "If a Discover is raised during the boss's
## turn"; ADR-0007 Decision 1 — the resolver keeps its continuation in
## `state.effects.pending_choice`, the engine owns `Choice`; quick-design
## 2026-11-04 — a paused spell runs no later step or `after_cast` until `choose`).
##
## The resolver is the `TestEffectResolver` double. A scripted play point (or
## queued pass) calls `engine.discover(...)` and writes the rest of its effect
## — "then deal N to X" — into `effects.pending_choice` as plain data; its
## [member TestEffectResolver.resume_script] adds the chosen option to hand and
## runs that rest, as Card Effects' `resume` will (card-effects story 010).
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const MARKER: StringName = &"test_pass_marker"
const DEF_SCOUT: String = "neutral_test_scout_spell"
const DEF_SEER: String = "neutral_test_seer"
const OPTIONS: Array = ["neutral_test_opt_a", "neutral_test_opt_b", "neutral_test_opt_c"]
const EFFECT_ID: String = "test_discover.0"
const SPELL_DAMAGE: int = 2
const MANA_POOL: int = 10


class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


# --- helpers -----------------------------------------------------------------

func _db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	db.cards[DEF_SCOUT] = CardFactory.make_spell(DEF_SCOUT, 1)
	db.cards[DEF_SEER] = CardFactory.make_minion(DEF_SEER, 1, 1, 1, ["battlecry"])
	return db


## A started engine past the mulligan (player Main, turn 1), the resume
## script installed, [param side]'s hand replaced by [param hand] and its mana
## set to [constant MANA_POOL]; [param rules_overrides] patch `match_rules`.
func _engine(log: TestEventLog, resolver: TestEffectResolver, hand: Array, side: String = SIDE_PLAYER, rules_overrides: Dictionary = {}) -> RulesEngine:
	resolver.resume_script = _resume
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {}, rules_overrides, resolver, _db())
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	if side == SIDE_BOSS:
		assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	_set_hand(engine, side, hand)
	return engine


func _set_hand(engine: RulesEngine, side: String, hand: Array) -> void:
	var state: MatchState = engine.state()
	var cards: Array = state.players[side].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[side].mana_current = MANA_POOL
	state.players[side].mana_max = MANA_POOL


func _player(engine: RulesEngine, side: String = SIDE_PLAYER) -> Dictionary:
	return engine.state().players[side]


func _hero_id(engine: RulesEngine, side: String) -> int:
	return int(_player(engine, side).hero.entity_id)


## A scripted effect `[discover(side, OPTIONS), deal_damage(target, amount)…]`:
## raises the request and stores the rest of the effect as the resolver's
## plain-data continuation (`then`: `[{target, amount}]`, source the host).
func _discover(engine: RulesEngine, ctx: Dictionary, side: String, then: Array) -> void:
	var source: Variant = ctx.get("source", ctx.get("source_id"))
	@warning_ignore("return_value_discarded")
	engine.discover(side, OPTIONS, MatchRecords.CHOICE_DISCOVER, source, EFFECT_ID)
	engine.state().effects.pending_choice = {"effect_id": EFFECT_ID, "source": source, "then": then}


## The double's `resume`: the chosen option into the chooser's hand
## (`add_card_to_hand`), then the rest of the paused effect.
func _resume(engine: RulesEngine, choice: Dictionary, index: int) -> void:
	@warning_ignore("return_value_discarded")
	engine.add_card_to_hand(str(choice.side), str(choice.options[index]))
	var continuation: Variant = engine.state().effects.pending_choice
	engine.state().effects.pending_choice = null
	if continuation is Dictionary:
		for hit: Dictionary in continuation.then:
			@warning_ignore("return_value_discarded")
			engine.apply_damage(int(hit.target), int(hit.amount), continuation.source)


func _mark(engine: RulesEngine, ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(MARKER, {"effect_id": str(ctx.get("effect_id", ""))})


func _since(log: TestEventLog, before: int, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in log.events.slice(before):
		if String(event.type) == type:
			out.append(event)
	return out


func _assert_rejected(result: Dictionary, code: String) -> void:
	assert_bool(result.accepted).is_false()
	if not result.accepted:
		assert_str(str(result.rejection.code)).is_equal(code)


## Every plain-data field of [param state] (all but `log`, `rng_match`, `hooks`).
func _plain_state(state: MatchState) -> Dictionary:
	return {
		"turn": state.turn, "active_side": state.active_side, "phase": state.phase,
		"players": state.players, "pending_choice": state.pending_choice, "result": state.result,
		"next_entity_id": state.next_entity_id, "effects": state.effects, "floor": state.floor,
		"suspended_queue": state.suspended_queue, "suspended_steps": state.suspended_steps,
		"suspended_action": state.suspended_action,
	}


## A player Scout spell `[discover(PLAYER, OPTIONS), deal_damage(BOSS_HERO, 2)]`
## and a player minion that observes `after_cast`. Returns `[engine, spell id]`.
func _paused_spell_fixture(log: TestEventLog, resolver: TestEffectResolver) -> Array:
	var engine: RulesEngine = _engine(log, resolver, [DEF_SCOUT])
	var observer: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1)
	resolver.add_trigger(&"after_cast", int(observer.entity_id), "observer.0", _mark)
	var then: Array = [{"target": _hero_id(engine, SIDE_BOSS), "amount": SPELL_DAMAGE}]
	resolver.scripts[&"on_cast"] = [_discover.bind(SIDE_PLAYER, then)]
	return [engine, int(_player(engine).hand[0].instance_id)]


# --- quick-design 2026-11-04: a paused spell ------------------------------------

func test_a_spell_paused_by_discover_runs_no_later_step_until_choose() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var fixture: Array = _paused_spell_fixture(log, resolver)
	var engine: RulesEngine = fixture[0]
	var spell_id: int = fixture[1]
	var boss_health: int = engine.health(_player(engine, SIDE_BOSS).hero)
	var before: int = log.events.size()

	# Act
	var result: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null))

	# Assert — accepted, paused: no damage, still resolving, no after_cast
	assert_bool(result.accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_array(_since(log, before, "damage_dealt")).is_empty()
	assert_int(engine.health(_player(engine, SIDE_BOSS).hero)).is_equal(boss_health)
	assert_int(_player(engine).resolving.size()).is_equal(1)
	assert_int(int(_player(engine).resolving[0].instance_id)).is_equal(spell_id)
	assert_array(resolver.candidates_for(&"after_cast")).is_empty()
	assert_array(_since(log, before, "card_to_graveyard")).is_empty()


func test_choose_resumes_the_paused_spell_in_seq_order_and_once() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var fixture: Array = _paused_spell_fixture(log, resolver)
	var engine: RulesEngine = fixture[0]
	var spell_id: int = fixture[1]
	var before: int = log.events.size()
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()
	var cast_seq: int = int(_since(log, before, "spell_cast")[0].seq)

	# Act
	var result: Dictionary = engine.submit(MatchRecords.choose(SIDE_PLAYER, 0))

	# Assert — card added, then damage 2, then after_cast and leaving resolving
	assert_bool(result.accepted).is_true()
	var added: Array[Dictionary] = _since(log, before, "card_added_to_hand")
	var dealt: Array[Dictionary] = _since(log, before, "damage_dealt")
	var observed: Array[Dictionary] = _since(log, before, String(MARKER))
	var to_graveyard: Array[Dictionary] = _since(log, before, "card_to_graveyard")
	assert_int(added.size()).is_equal(1)
	assert_int(dealt.size()).is_equal(1)
	assert_int(observed.size()).is_equal(1)
	assert_int(to_graveyard.size()).is_equal(1)
	assert_str(str(added[0].payload.card_id)).is_equal(str(OPTIONS[0]))
	assert_int(int(dealt[0].payload.dealt)).is_equal(SPELL_DAMAGE)
	assert_int(int(added[0].seq)).is_less(int(dealt[0].seq))
	assert_int(int(dealt[0].seq)).is_less(int(observed[0].seq))
	assert_int(int(dealt[0].seq)).is_less(int(to_graveyard[0].seq))
	assert_int(int(to_graveyard[0].payload.instance_id)).is_equal(spell_id)
	# the same cause_seq chain: the resumed effect is still the spell's
	assert_int(int(added[0].cause_seq)).is_equal(cast_seq)
	assert_int(int(dealt[0].cause_seq)).is_equal(cast_seq)
	assert_int(resolver.candidates_for(&"after_cast").size()).is_equal(1)
	assert_array(_player(engine).resolving).is_empty()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_object(engine.pending_choice()).is_null()


# --- AC-36: a boss Discover --------------------------------------------------------

func test_a_boss_battlecry_discover_rejects_the_player_until_the_boss_chooses() -> void:
	# Arrange — boss Main, a boss Battlecry that Discovers for the boss
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [DEF_SEER], SIDE_BOSS)
	_set_hand(engine, SIDE_PLAYER, [DEF_SCOUT])
	resolver.scripts[&"battlecry"] = [_discover.bind(SIDE_BOSS, [])]
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_BOSS, 0, 0, null)).accepted).is_true()
	var request: Variant = engine.pending_choice()
	var before: int = log.events.size()

	# Act 1 — the player tries to act
	var player_play: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null))

	# Assert 1
	_assert_rejected(player_play, RulesEngine.R_CHOICE_PENDING)
	assert_str(str(request.side)).is_equal(SIDE_BOSS)

	# Act 2 — Boss AI answers
	var hand_before: int = _player(engine, SIDE_BOSS).hand.size()
	var result: Dictionary = engine.submit(MatchRecords.choose(SIDE_BOSS, 1))

	# Assert 2
	assert_bool(result.accepted).is_true()
	assert_int(resolver.resume_calls.size()).is_equal(1)
	assert_dict(resolver.resume_calls[0].choice).is_equal(request)
	assert_int(int(resolver.resume_calls[0].option_index)).is_equal(1)
	var hand: Array = _player(engine, SIDE_BOSS).hand
	assert_int(hand.size()).is_equal(hand_before + 1)
	assert_str(str(hand[hand.size() - 1].def_id)).is_equal(str(OPTIONS[1]))
	EventLogAssertions.assert_payload(log.events.slice(before), &"choice_made", {"side": SIDE_BOSS, "option_index": 1})
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_str(String(engine.active_side())).is_equal(SIDE_BOSS)


func test_a_discover_from_a_start_step_trigger_resumes_the_rest_of_the_start_step() -> void:
	# Arrange — a boss-side minion Discovers "at the start of your turn"
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [])
	var dawn: Dictionary = MatchFactory.summon(engine.state(), SIDE_BOSS, 1, 1)
	var on_boss_turn: Callable = func(_e: RulesEngine, ctx: Dictionary) -> bool: return ctx.side == SIDE_BOSS
	resolver.add_trigger(&"turn_start", int(dawn.entity_id), "dawn.0", _discover.bind(SIDE_BOSS, []), on_boss_turn)

	# Act 1 — the player's End step, then the boss's Start step pauses
	var before: int = log.events.size()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert 1 — no Start-step draw, no Main yet
	assert_str(engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_array(_since(log, before, "card_drawn")).is_empty()

	# Act 2
	assert_bool(engine.submit(MatchRecords.choose(SIDE_BOSS, 2)).accepted).is_true()

	# Assert 2 — the draw (C4 Start 6) and Main (Start 7) ran once, after the pick
	var drawn: Array[Dictionary] = _since(log, before, "card_drawn")
	assert_int(drawn.size()).is_equal(1)
	assert_int(int(_since(log, before, "card_added_to_hand")[0].seq)).is_less(int(drawn[0].seq))
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_str(String(engine.active_side())).is_equal(SIDE_BOSS)


# --- States `Choice` guards --------------------------------------------------------

func test_choice_guards_not_your_turn_invalid_choice_and_choice_pending() -> void:
	# Arrange — a player Discover is pending
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var fixture: Array = _paused_spell_fixture(log, resolver)
	var engine: RulesEngine = fixture[0]
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()

	# Act / Assert
	_assert_rejected(engine.submit(MatchRecords.choose(SIDE_BOSS, 0)), RulesEngine.R_NOT_YOUR_TURN)
	_assert_rejected(engine.submit(MatchRecords.choose(SIDE_PLAYER, OPTIONS.size())), RulesEngine.R_INVALID_CHOICE)
	_assert_rejected(engine.submit(MatchRecords.choose(SIDE_PLAYER, -1)), RulesEngine.R_INVALID_CHOICE)
	_assert_rejected(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)), RulesEngine.R_CHOICE_PENDING)
	_assert_rejected(engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER, null)), RulesEngine.R_CHOICE_PENDING)
	assert_str(engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_int(resolver.resume_calls.size()).is_zero()


func test_legal_commands_in_choice_are_one_choose_per_option_and_the_concede() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var fixture: Array = _paused_spell_fixture(log, resolver)
	var engine: RulesEngine = fixture[0]
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()

	# Act
	var legal: Array = engine.legal_commands()

	# Assert
	var expected: Array = []
	for i: int in OPTIONS.size():
		expected.append(MatchRecords.choose(SIDE_PLAYER, i))
	expected.append(MatchRecords.concede(SIDE_PLAYER))
	assert_array(legal).is_equal(expected)


func test_raising_the_request_emits_phase_changed_and_choice_requested() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var fixture: Array = _paused_spell_fixture(log, resolver)
	var engine: RulesEngine = fixture[0]
	var spell_id: int = fixture[1]
	var before: int = log.events.size()

	# Act
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()

	# Assert
	var changed: Array[Dictionary] = _since(log, before, "phase_changed")
	assert_int(changed.size()).is_equal(1)
	assert_str(str(changed[0].payload.phase)).is_equal(MatchState.PHASE_CHOICE)
	var requested: Array[Dictionary] = _since(log, before, "choice_requested")
	assert_int(requested.size()).is_equal(1)
	assert_dict(requested[0].payload).is_equal({
		"side": SIDE_PLAYER, "kind": MatchRecords.CHOICE_DISCOVER, "options": OPTIONS,
		"source_id": spell_id, "effect_id": EFFECT_ID,
	})
	EventLogAssertions.assert_not_contains_type(log.events.slice(before), &"discover_offered")


func test_concede_in_choice_ends_the_match_and_the_spell_leaves_resolving() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var fixture: Array = _paused_spell_fixture(log, resolver)
	var engine: RulesEngine = fixture[0]
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()

	# Act
	var result: Dictionary = engine.submit(MatchRecords.concede(SIDE_PLAYER))

	# Assert
	assert_bool(result.accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)
	assert_str(str(engine.result().reason)).is_equal(MatchRecords.REASON_CONCEDE)
	assert_str(str(engine.result().winner)).is_equal(SIDE_BOSS)
	assert_array(_player(engine).resolving).is_empty()
	assert_int(resolver.resume_calls.size()).is_zero()


# --- C2 / ADR-0007: the suspended queue and step count ------------------------------

## A Scout spell whose `on_cast` raises four queued triggers t1…t4 from the
## spell itself; t1's pass Discovers, the others mark. Returns `[engine, spell id]`.
func _queued_fixture(log: TestEventLog, resolver: TestEffectResolver, rules_overrides: Dictionary = {}) -> Array:
	var engine: RulesEngine = _engine(log, resolver, [DEF_SCOUT], SIDE_PLAYER, rules_overrides)
	var spell_id: int = int(_player(engine).hand[0].instance_id)
	resolver.add_trigger(&"on_cast", spell_id, "t1", _discover.bind(SIDE_PLAYER, []))
	for name: String in ["t2", "t3", "t4"]:
		resolver.add_trigger(&"on_cast", spell_id, name, _mark)
	return [engine, spell_id]


func test_a_choice_raised_with_a_queue_parks_it_as_plain_data() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _queued_fixture(log, resolver)[0]

	# Act
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()

	# Assert — t2…t4 wait on MatchState; nothing in the state is an object
	var state: MatchState = engine.state()
	assert_str(state.phase).is_equal(MatchState.PHASE_CHOICE)
	var waiting: Array[String] = []
	for step: Dictionary in state.suspended_queue:
		waiting.append(str(step.ctx.effect_id))
	assert_array(waiting).is_equal(["t2", "t3", "t4"])
	assert_int(state.suspended_steps).is_greater(0)
	assert_array(resolver.pass_ids()).is_equal(["t1"])
	GameAssertions.assert_json_representable(_plain_state(state), "MatchState")
	var copy: Variant = engine.pending_choice()
	copy.options.clear()
	assert_int((state.pending_choice.options as Array).size()).is_equal(OPTIONS.size())


func test_after_choose_the_parked_queue_resumes_in_order_with_its_cause_seq() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _queued_fixture(log, resolver)[0]
	var before: int = log.events.size()
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()
	var cast_seq: int = int(_since(log, before, "spell_cast")[0].seq)

	# Act
	assert_bool(engine.submit(MatchRecords.choose(SIDE_PLAYER, 0)).accepted).is_true()

	# Assert
	assert_array(resolver.pass_ids()).is_equal(["t1", "t2", "t3", "t4"])
	var resolved: Array[Dictionary] = _since(log, before, "trigger_resolved")
	assert_int(resolved.size()).is_equal(4)
	for event: Dictionary in resolved:
		assert_int(int(event.cause_seq)).is_equal(cast_seq)
	assert_int(int(_since(log, before, "card_added_to_hand")[0].cause_seq)).is_equal(int(resolved[0].seq))
	assert_array(engine.state().suspended_queue).is_empty()
	assert_dict(engine.state().suspended_action).is_empty()


func test_the_step_count_carries_across_the_pause_to_the_step_cap() -> void:
	# Arrange — cap 4: accept 1, on_cast 2, t1 3 (pauses), t2 4, t3 over the cap.
	# A count restarted at choose would run t2…t4 as steps 1–3 and never fault.
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _queued_fixture(log, resolver, {"resolution_step_cap": 4})[0]
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()

	# Act
	assert_bool(engine.submit(MatchRecords.choose(SIDE_PLAYER, 0)).accepted).is_true()

	# Assert
	assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)
	assert_str(str(engine.result().reason)).is_equal(MatchRecords.REASON_RESOLUTION_OVERFLOW)
	EventLogAssertions.assert_payload(log, &"resolution_overflow", {"steps": 4})
	assert_array(resolver.pass_ids()).is_equal(["t1", "t2"])
