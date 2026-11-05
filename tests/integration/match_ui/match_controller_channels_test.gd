## `MatchController` and `MatchQuery`: the three channels, flush-before-submit and value
## copies (match-ui story 003 AC-1, AC-2; design/gdd/match-ui.md U1, U2, U4.7;
## ADR-0008 Key Interfaces).
##
## The driver is a real `MatchDriver` over [MatchDriverFixture]'s database with
## `ImmediatePlannerTask`. It is built directly: the `driver_factory` the story names
## has no owning story yet (QA plan, MUI-003 "Gaps"). [method _planner] is the one
## place that says what the driver is planned with. The last section plays real boss
## turns on the shipped data through the whole UI side, as `MatchView` will.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const SEQ_ZERO: int = 0
## Enough for the fixture's hero power and any card.
const PLENTY_OF_MANA: int = 9
## An id no record has.
const NO_SUCH_ID: int = 9_999_999
const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SHIPPED_ROOT: String = "res://assets/data/"
const REAL_BOSS: String = "boss_torchbearer"
const REAL_SEED: int = 21
const REAL_ROUNDS: int = 4
## A 60 fps frame on the fake clock.
const FRAME_S: float = 1.0 / 60.0
## More frames than any boss turn takes: `max_turn_playback_s` plus planning.
const FRAME_CAP: int = 1200
## A task that stays live for the whole test.
const STAYS_LIVE: int = 1000

var _db: MatchDriverFixture.FixtureDatabase
var _log: TestEventLog
var _driver: MatchDriver
# The UI side of the real matches, as `MatchView` holds it.
var _view: MatchViewState
var _queue: AnimationQueue
var _router: InputRouter
var _pacing: Dictionary = {}


## A driver that records each call and answers with what it was told to.
class SpyDriver:
	extends MatchDriver

	var trail: Array[String] = []
	var submitted: Array[Dictionary] = []
	var seqs: Array[int] = []
	var callbacks: Array[Callable] = []
	var settings_seen: Array = []
	var answer: Dictionary = {}
	var commands: Array = []
	var events: Array = []
	var planning: bool = false

	func _init(config: Dictionary, db: CardDatabase, settings: Dictionary, planner: Callable) -> void:
		super(config, db, settings, planner)

	func submit(command: Dictionary) -> Dictionary:
		trail.append("submit")
		submitted.append(command)
		return answer

	func legal_commands() -> Array:
		trail.append("legal_commands")
		return commands

	func query() -> MatchQuery:
		trail.append("query")
		return super()

	func subscribe(callback: Callable) -> void:
		trail.append("subscribe")
		callbacks.append(callback)

	func events_since(seq: int) -> Array:
		trail.append("events_since")
		seqs.append(seq)
		return events

	func tick() -> void:
		trail.append("tick")

	func on_setting_changed(key: StringName, value: Variant) -> void:
		trail.append("on_setting_changed")
		settings_seen.append([key, value])

	func shutdown() -> void:
		trail.append("shutdown")
		super()

	func is_planning() -> bool:
		trail.append("is_planning")
		return planning


func before_test() -> void:
	_db = MatchDriverFixture.database()
	_log = TestEventLog.new()
	_driver = null


func after_test() -> void:
	if _driver != null:
		_driver.shutdown()
	_driver = null


## What `MatchDriver`'s construction is given to plan with (DD-X31).
func _planner() -> Callable:
	return func() -> PlannerTask: return ImmediatePlannerTask.new()


func _real_driver() -> MatchDriver:
	_driver = MatchDriver.new(MatchDriverFixture.match_config(_log), _db, {}, _planner())
	return _driver


func _spy() -> SpyDriver:
	var spy: SpyDriver = SpyDriver.new(MatchDriverFixture.match_config(_log), _db, {}, _planner())
	_driver = spy
	return spy


## The player's Main with one 1/1 on the board, cards in hand and plenty of mana.
func _board_query() -> MatchQuery:
	var driver: MatchDriver = _real_driver()
	MatchDriverFixture.past_mulligan(driver)
	var played: Dictionary = driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	assert_bool(played.accepted).override_failure_message("fixture play rejected").is_true()
	_player_state().mana_current = PLENTY_OF_MANA
	return driver.query()


func _player_state() -> Dictionary:
	return _driver._engine.state().players[SIDE_PLAYER]


func _boss_state() -> Dictionary:
	return _driver._engine.state().players[SIDE_BOSS]


## The first minion on the player's board.
func _token_id() -> int:
	return int(_player_state().board[0].entity_id)


## A `bind`-ready queue holding [param steps] pending steps; each writes to [param trail].
func _queue_holding(steps: int, trail: Array[String]) -> AnimationQueue:
	var queue: AnimationQueue = AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings())
	for index: int in steps:
		var step: AnimStep = AnimStep.new(AnimStep.DRAW, [index], 1.0, index + 1, index + 1)
		step.apply_final = func() -> void: trail.append("final:%d" % index)
		queue.enqueue(step)
	return queue


# --- AC-1: every U2 call is a pass-through -----------------------------------------------

func test_new_over_a_real_driver_answers_the_drivers_own_query() -> void:
	# Arrange
	var driver: MatchDriver = _real_driver()

	# Act
	var controller: MatchController = MatchController.new(driver)

	# Assert
	assert_object(controller.query()).is_same(driver.query())
	assert_str(controller.query().phase()).is_equal(MatchState.PHASE_MULLIGAN)
	assert_that(controller.legal_commands()).is_equal(driver.legal_commands())
	assert_that(controller.events_since(SEQ_ZERO)).is_equal(driver.events_since(SEQ_ZERO))
	assert_bool(controller.is_planning()).is_equal(driver.is_planning())


func test_submit_over_a_real_driver_changes_the_real_engine() -> void:
	# Arrange
	var driver: MatchDriver = _real_driver()
	var controller: MatchController = MatchController.new(driver)

	# Act
	var result: Dictionary = controller.submit(driver.legal_commands()[0])

	# Assert
	assert_bool(result.accepted).is_true()
	assert_str(controller.query().phase()).is_equal(MatchState.PHASE_MAIN)


func test_submit_passes_the_command_and_answers_the_drivers_result_unchanged() -> void:
	# Arrange
	var spy: SpyDriver = _spy()
	spy.answer = MatchRecords.command_result(false, RulesEngine.R_NOT_YOUR_TURN, "spy", 4, 4)
	var command: Dictionary = MatchRecords.end_turn(SIDE_PLAYER)
	var controller: MatchController = MatchController.new(spy)

	# Act
	var result: Dictionary = controller.submit(command)

	# Assert
	assert_that(spy.submitted).is_equal([command])
	assert_that(result).is_equal(spy.answer)
	assert_bool(is_same(result, spy.answer)).override_failure_message("the result was rebuilt").is_true()


func test_legal_commands_and_events_since_answer_the_drivers_values() -> void:
	# Arrange
	var spy: SpyDriver = _spy()
	spy.commands = [MatchRecords.end_turn(SIDE_PLAYER)]
	spy.events = [{"seq": 7}]
	var controller: MatchController = MatchController.new(spy)

	# Act
	var commands: Array = controller.legal_commands()
	var events: Array = controller.events_since(6)

	# Assert
	assert_bool(is_same(commands, spy.commands)).is_true()
	assert_bool(is_same(events, spy.events)).is_true()
	assert_that(spy.seqs).is_equal([6])


func test_subscribe_passes_the_callback_to_the_driver() -> void:
	# Arrange
	var spy: SpyDriver = _spy()
	var callback: Callable = func(_event: Dictionary) -> void: pass
	var controller: MatchController = MatchController.new(spy)

	# Act
	controller.subscribe(callback)

	# Assert
	assert_that(spy.callbacks).is_equal([callback])


func test_tick_shutdown_and_is_planning_reach_the_driver() -> void:
	# Arrange
	var spy: SpyDriver = _spy()
	spy.planning = true
	var controller: MatchController = MatchController.new(spy)

	# Act
	controller.tick()
	var planning: bool = controller.is_planning()
	controller.shutdown()

	# Assert
	assert_that(spy.trail).is_equal(["tick", "is_planning", "shutdown"])
	assert_bool(planning).is_true()


func test_on_setting_changed_passes_the_key_and_value_to_the_driver() -> void:
	# Arrange
	var spy: SpyDriver = _spy()
	var controller: MatchController = MatchController.new(spy)

	# Act
	controller.on_setting_changed(&"telegraph_mode", "brief")

	# Assert
	assert_that(spy.settings_seen).is_equal([[&"telegraph_mode", "brief"]])


func test_the_controller_holds_the_driver_and_the_queue_handle_and_nothing_else() -> void:
	# Arrange
	var controller: MatchController = MatchController.new(_real_driver())
	var fields: Array[String] = []

	# Act
	for property: Dictionary in controller.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(str(property.name))
	fields.sort()

	# Assert
	assert_that(fields).is_equal(["_driver", "_queue"])


# --- AC-1: every MatchQuery method answers a value copy ----------------------------------

func test_phase_answers_a_value_and_the_active_side_comes_with_it() -> void:
	# Arrange
	var query: MatchQuery = _board_query()

	# Act
	var phase: String = query.phase()
	phase += "_mutated"

	# Assert
	assert_str(query.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_str(query.active_side()).is_equal(SIDE_PLAYER)


func test_pending_choice_of_the_player_is_a_copy_with_its_options() -> void:
	# Arrange
	_db = MatchDriverFixture.database()
	var deck: Array = MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER)
	_driver = MatchDriver.new(MatchDriverFixture.match_config(_log, deck), _db, {}, _planner())
	MatchDriverFixture.past_mulligan(_driver)
	var played: Dictionary = _driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0))
	assert_bool(played.accepted).is_true()
	var query: MatchQuery = _driver.query()
	var before: Dictionary = query.pending_choice()

	# Act
	var copy: Dictionary = query.pending_choice()
	copy.side = "mutated"
	(copy.options as Array).clear()

	# Assert
	assert_that(query.pending_choice()).is_equal(before)
	assert_int((before.options as Array).size()).is_greater(0)


func test_entity_of_a_token_is_the_u2_snapshot_and_a_copy() -> void:
	# Arrange
	var query: MatchQuery = _board_query()
	var id: int = _token_id()
	var before: Dictionary = query.entity(id)

	# Act
	var copy: Dictionary = query.entity(id)
	copy.attack = 99
	(copy.keywords as Array).append("mutated")
	copy.flags.frozen = true
	(copy.enchantments as Array).append({})

	# Assert
	assert_that(query.entity(id)).is_equal(before)
	assert_str(str(before.card_id)).is_equal(MatchDriverFixture.VANILLA)
	assert_str(str(before.side)).is_equal(SIDE_PLAYER)
	assert_str(str(before.zone)).is_equal(MatchQuery.ZONE_BOARD)
	assert_int(int(before.attack)).is_equal(1)
	assert_int(int(before.health)).is_equal(1)
	assert_int(int(before.max_health)).is_equal(1)
	assert_object(before.durability).is_null()
	assert_bool(bool(before.flags.summoning_sick)).is_true()
	assert_that(before.flags.keys()).contains_exactly_in_any_order(["frozen", "stealth", "divine_shield", "silenced", "summoning_sick", "pending_destroy"])


func test_entity_reads_enchantments_and_keywords_from_the_live_record() -> void:
	# Arrange
	var query: MatchQuery = _board_query()
	var id: int = _token_id()
	var buff: Dictionary = MatchRecords.enchantment(2, 3, ["divine_shield"], 77)
	_player_state().board[0].enchantments.append(buff)

	# Act
	var token: Dictionary = query.entity(id)

	# Assert
	assert_int(int(token.attack)).is_equal(3)
	assert_int(int(token.health)).is_equal(4)
	assert_int(int(token.max_health)).is_equal(4)
	assert_bool(bool(token.flags.divine_shield)).is_true()
	assert_that(token.keywords).contains(["divine_shield"])
	assert_that(token.enchantments).is_equal([{"source_id": 77, "delta": {"attack": 2, "health": 3}}])


func test_entity_of_a_hero_and_of_a_weapon_name_their_zone_and_side() -> void:
	# Arrange
	var query: MatchQuery = _board_query()
	var weapon: Dictionary = MatchRecords.weapon(NO_SUCH_ID - 1, "fixture_axe", 3, 2, ["windfury"])
	_boss_state().weapon = weapon

	# Act
	var hero: Dictionary = query.entity(int(_player_state().hero.entity_id))
	var axe: Dictionary = query.entity(int(weapon.entity_id))

	# Assert
	assert_str(str(hero.zone)).is_equal(MatchQuery.ZONE_HERO)
	assert_str(str(hero.side)).is_equal(SIDE_PLAYER)
	assert_int(int(hero.health)).is_equal(int(_driver._engine.health(_player_state().hero)))
	assert_str(str(axe.zone)).is_equal(MatchQuery.ZONE_WEAPON)
	assert_str(str(axe.side)).is_equal(SIDE_BOSS)
	assert_int(int(axe.attack)).is_equal(3)
	assert_int(int(axe.durability)).is_equal(2)


func test_entity_of_an_unknown_id_is_empty() -> void:
	# Arrange
	var query: MatchQuery = _board_query()

	# Act / Assert
	assert_bool(query.entity(NO_SUCH_ID).is_empty()).is_true()


func test_entity_never_shows_a_card_in_a_deck_or_the_bosss_hand() -> void:
	# Arrange
	var query: MatchQuery = _board_query()

	# Act
	var boss_hand: Dictionary = query.entity(int(_boss_state().hand[0].instance_id))
	var boss_deck: Dictionary = query.entity(int(_boss_state().deck[0].instance_id))
	var own_deck: Dictionary = query.entity(int(_player_state().deck[0].instance_id))
	var own_hand: Dictionary = query.entity(int(_player_state().hand[0].instance_id))

	# Assert
	assert_bool(boss_hand.is_empty()).override_failure_message("boss hand card shown").is_true()
	assert_bool(boss_deck.is_empty()).override_failure_message("boss deck card shown").is_true()
	assert_bool(own_deck.is_empty()).override_failure_message("deck order shown").is_true()
	assert_str(str(own_hand.card_id)).is_equal(MatchDriverFixture.VANILLA)
	assert_str(str(own_hand.zone)).is_equal(MatchQuery.ZONE_HAND)


func test_hand_of_the_player_is_u2_rows_and_a_copy() -> void:
	# Arrange
	var query: MatchQuery = _board_query()
	var before: Array = query.hand(SIDE_PLAYER)

	# Act
	var copy: Array = query.hand(SIDE_PLAYER)
	copy[0].card_id = "mutated"
	copy.clear()

	# Assert
	assert_that(query.hand(SIDE_PLAYER)).is_equal(before)
	assert_int(before.size()).is_equal((_player_state().hand as Array).size())
	assert_that((before[0] as Dictionary).keys()).contains_exactly_in_any_order(["instance_id", "card_id", "effective_cost", "playable"])
	assert_int(int(before[0].effective_cost)).is_equal(0)
	assert_bool(bool(before[0].playable)).is_true()


func test_hand_card_is_not_playable_when_no_legal_play_lists_it() -> void:
	# Arrange
	var driver: MatchDriver = _real_driver()

	# Act: Mulligan lists no play at all
	var cards: Array = driver.query().hand(SIDE_PLAYER)

	# Assert
	assert_int(cards.size()).is_greater(0)
	assert_bool(bool(cards[0].playable)).is_false()


func test_hand_of_the_boss_is_a_count_only() -> void:
	# Arrange
	var query: MatchQuery = _board_query()

	# Act
	var count: Variant = query.hand(SIDE_BOSS)

	# Assert
	assert_int(typeof(count)).is_equal(TYPE_INT)
	assert_int(int(count)).is_equal((_boss_state().hand as Array).size())


func test_card_text_is_the_u2_row_and_a_copy() -> void:
	# Arrange
	var query: MatchQuery = _board_query()
	var id: String = MatchDriverFixture.VANILLA
	var before: Dictionary = query.card_text(id)

	# Act
	var copy: Dictionary = query.card_text(id)
	copy.cost = 99
	(copy.keywords as Array).append("mutated")

	# Assert
	assert_that(query.card_text(id)).is_equal(before)
	assert_str(str(before.name_key)).is_equal("card.%s.name" % id)
	assert_str(str(before.type)).is_equal("minion")
	assert_int(int(before.cost)).is_equal(0)
	assert_int(int(before.attack)).is_equal(1)
	assert_int(int(before.health)).is_equal(1)
	assert_that(before.keys()).contains_exactly_in_any_order(["name_key", "text_key", "type", "cost", "attack", "health", "keywords"])


func test_card_text_of_an_unknown_card_is_empty() -> void:
	# Arrange
	var query: MatchQuery = _board_query()

	# Act / Assert
	assert_bool(query.card_text("no_such_card").is_empty()).is_true()


func test_legal_commands_are_a_fresh_list_each_call() -> void:
	# Arrange
	var query: MatchQuery = _board_query()
	var before: Array = query.legal_commands()

	# Act
	var copy: Array = query.legal_commands()
	copy[0].type = "mutated"
	copy.clear()

	# Assert
	assert_that(query.legal_commands()).is_equal(before)


func test_hero_power_state_is_a_copy() -> void:
	# Arrange
	var query: MatchQuery = _board_query()
	var before: Dictionary = query.hero_power_state(SIDE_PLAYER)

	# Act
	var copy: Dictionary = query.hero_power_state(SIDE_PLAYER)
	copy.state = "mutated"

	# Assert
	assert_that(query.hero_power_state(SIDE_PLAYER)).is_equal(before)


func test_hero_power_goes_ready_then_used() -> void:
	# Arrange
	var query: MatchQuery = _board_query()
	_player_state().hero_power.def_id = MatchDriverFixture.POWER_ID

	# Act
	var ready: Dictionary = query.hero_power_state(SIDE_PLAYER)
	var used: Dictionary = _driver.submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	assert_bool(used.accepted).is_true()
	assert_that(ready).is_equal({"state": MatchQuery.POWER_READY, "reason_code": null})
	assert_that(query.hero_power_state(SIDE_PLAYER)).is_equal({"state": MatchQuery.POWER_USED, "reason_code": null})


func test_hero_power_blocked_names_the_code_submit_would_answer() -> void:
	# Arrange
	var driver: MatchDriver = _real_driver()
	var query: MatchQuery = driver.query()
	_player_state().hero_power.def_id = MatchDriverFixture.POWER_ID
	_boss_state().hero_power.def_id = ""

	# Act
	var mulligan: Dictionary = query.hero_power_state(SIDE_PLAYER)
	MatchDriverFixture.past_mulligan(driver)
	_player_state().mana_current = 0
	var no_mana: Dictionary = query.hero_power_state(SIDE_PLAYER)
	_boss_state().hero_power.def_id = MatchDriverFixture.POWER_ID
	var not_my_turn: Dictionary = query.hero_power_state(SIDE_BOSS)
	_boss_state().hero_power.def_id = ""
	var no_power: Dictionary = query.hero_power_state(SIDE_BOSS)

	# Assert
	assert_that(mulligan).is_equal({"state": MatchQuery.POWER_BLOCKED, "reason_code": RulesEngine.R_WRONG_PHASE})
	assert_that(no_mana).is_equal({"state": MatchQuery.POWER_BLOCKED, "reason_code": RulesEngine.R_NOT_ENOUGH_MANA})
	assert_that(not_my_turn).is_equal({"state": MatchQuery.POWER_BLOCKED, "reason_code": RulesEngine.R_NOT_YOUR_TURN})
	assert_that(no_power).is_equal({"state": MatchQuery.POWER_BLOCKED, "reason_code": RulesEngine.R_HERO_POWER_USED})


func test_snapshot_is_a_copy_and_gives_the_boss_a_hand_count() -> void:
	# Arrange
	var query: MatchQuery = _board_query()
	var before: Dictionary = query.snapshot(SIDE_PLAYER)

	# Act
	var copy: Dictionary = query.snapshot(SIDE_PLAYER)
	copy.hero.armor = 99
	copy.board[0].attack = 99
	(copy.hand as Array).clear()
	var boss: Dictionary = query.snapshot(SIDE_BOSS)

	# Assert
	assert_that(query.snapshot(SIDE_PLAYER)).is_equal(before)
	assert_int(typeof(boss.hand)).is_equal(TYPE_INT)
	assert_int(int(boss.hand)).is_equal((_boss_state().hand as Array).size())


# --- ADR-0007 Decision 4: no live state outside the engine -------------------------------

## The code lines of [param path] calling `.state()`.
static func _state_calls(path: String) -> Array[String]:
	var hits: Array[String] = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.contains(".state()") and not line.strip_edges().begins_with("#"):
			hits.append(line.strip_edges())
	return hits


func test_the_read_model_and_the_driver_never_call_state() -> void:
	# Act
	var query: Array[String] = _state_calls("res://src/gameplay/match/match_query.gd")
	var driver: Array[String] = _state_calls("res://src/gameplay/run/match_driver.gd")

	# Assert
	assert_array(query).is_empty()
	assert_array(driver).is_empty()


# --- AC-2: U4.7 flush before submit ------------------------------------------------------

func test_submit_runs_every_pending_final_before_the_command_reaches_the_driver() -> void:
	# Arrange
	var spy: SpyDriver = _spy()
	var trail: Array[String] = spy.trail
	var queue: AnimationQueue = _queue_holding(3, trail)
	var controller: MatchController = MatchController.new(spy)
	controller.bind_queue(queue)

	# Act
	var result: Dictionary = controller.submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_that(spy.trail).is_equal(["final:0", "final:1", "final:2", "submit"])
	assert_bool(queue.is_idle()).is_true()
	assert_bool(is_same(result, spy.answer)).is_true()


func test_submit_with_no_queue_bound_still_reaches_the_driver() -> void:
	# Arrange
	var spy: SpyDriver = _spy()
	var controller: MatchController = MatchController.new(spy)

	# Act
	controller.submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_that(spy.trail).is_equal(["submit"])


# --- Real planning through the UI side ---------------------------------------------------

func test_a_forecast_on_the_players_turn_reads_as_planning_and_locks_nothing() -> void:
	# Arrange: a forecast task that never returns, on the player's Main
	var task: FakePlannerTask = FakePlannerTask.new()
	task.polls_before_done = STAYS_LIVE
	_driver = MatchDriver.new(MatchDriverFixture.match_config(_log), _db, {}, MatchDriverFixture.same_task(task))
	var controller: MatchController = MatchController.new(_driver)
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var queue: AnimationQueue = AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings())
	var router: InputRouter = auto_free(InputRouter.new())
	router.bind(view, queue)

	# Act
	MatchDriverFixture.past_mulligan(_driver)
	for event: Dictionary in controller.events_since(SEQ_ZERO):
		@warning_ignore("return_value_discarded")
		view.apply(event)
	var planning: bool = controller.is_planning()
	var locked: bool = router.controls_locked()
	task.finish()

	# Assert
	assert_bool(planning).override_failure_message("the forecast is not live").is_true()
	assert_bool(locked).override_failure_message("a forecast locked the player's controls").is_false()


func _shipped() -> CardDatabase:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
	db.load(boot._collect_validators(null, true))
	return db


## What `MatchView` does with an event: the mode first, then the projection.
func _project(event: Dictionary) -> void:
	if str(event.type) == "turn_started":
		if str(event.payload.side) == SIDE_BOSS:
			_queue.enter_boss_turn(_pacing)
		else:
			_queue.exit_boss_turn()
	for step: AnimStep in _view.apply(event):
		_queue.enqueue(step)


## The player's Main, nothing replaying and nothing playing.
func _at_rest(controller: MatchController) -> bool:
	var main: bool = controller.query().phase() == MatchState.PHASE_MAIN and controller.query().active_side() == SIDE_PLAYER
	return main and not controller.is_planning() and _queue.is_idle() and not _queue.boss_turn_active()


## `MatchView._process`, until at rest or the match ended. Answers the frames run;
## [param locked] gains the lock as read on each of them.
func _play_frames(controller: MatchController, locked: Array[bool]) -> int:
	var frames: int = 0
	while frames < FRAME_CAP and not _at_rest(controller) and controller.query().phase() != MatchState.PHASE_ENDED:
		controller.tick()
		_queue.advance(FRAME_S)
		frames += 1
		if not _at_rest(controller):
			locked.append(_router.controls_locked())
	return frames


func test_real_boss_turns_plan_replay_and_pace_through_the_controller() -> void:
	# Arrange: the shipped data and `ImmediatePlannerTask`; only the budget clock is fake
	var db: CardDatabase = _shipped()
	var boss_def: Dictionary = db.boss(REAL_BOSS)
	var hero: Dictionary = db.hero("hero_war")
	var log: EventLog = EventLog.new(TestConstants.MAX_MATCH_EVENTS, EventLog.SCOPE_MATCH)
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(REAL_SEED), null, {
		"log": log,
		"player": {"deck": hero.starter_deck},
		"boss": {"boss_def_id": REAL_BOSS, "deck": boss_def.deck, "health": boss_def.health, "ai_id": boss_def.ai_profile},
	})
	_driver = MatchDriver.new(config, db, {}, _planner(), func() -> int: return 0)
	var controller: MatchController = MatchController.new(_driver)
	var ui: Dictionary = db.config("match_ui")
	_view = MatchViewState.new(ui)
	_queue = AnimationQueue.new(ui, MatchUiTestConfig.settings())
	_pacing = AnimationQueue.boss_pacing(ui, db.config("ai_profiles"), {})
	_router = auto_free(InputRouter.new())
	_router.bind(_view, _queue)
	controller.bind_queue(_queue)
	var starts: Array[StringName] = []
	_queue.step_started.connect(func(step: AnimStep, _d_eff: float) -> void: starts.append(step.kind))
	for event: Dictionary in controller.events_since(SEQ_ZERO):
		_project(event)
	controller.subscribe(_project)
	var kept: Dictionary = controller.submit(controller.legal_commands()[0])
	assert_bool(kept.accepted).is_true()
	var unlocked_after_round: Array[bool] = []
	var locked_frames: Array[bool] = []

	# Act
	@warning_ignore("return_value_discarded")
	_play_frames(controller, [] as Array[bool])
	for _round: int in REAL_ROUNDS:
		var ended: Dictionary = controller.submit(MatchRecords.end_turn(SIDE_PLAYER))
		assert_bool(ended.accepted).is_true()
		@warning_ignore("return_value_discarded")
		_play_frames(controller, locked_frames)
		if controller.query().phase() == MatchState.PHASE_ENDED:
			break
		unlocked_after_round.append(not _router.controls_locked())

	# Assert
	var types: Array[String] = []
	for event: Dictionary in log.events_since(SEQ_ZERO):
		types.append(str(event.type))
	assert_int(types.count("ai_intent_committed")).override_failure_message("no plan committed").is_greater_equal(REAL_ROUNDS)
	assert_int(types.count("ai_fault")).is_equal(0)
	assert_int(types.count("command_rejected")).is_equal(0)
	assert_int(types.count("card_played")).is_greater(0)
	assert_int(starts.count(AnimStep.INTENT_COMMIT)).is_greater_equal(REAL_ROUNDS)
	assert_int(starts.count(AnimStep.PLAY_CARD)).is_greater(0)
	assert_bool(locked_frames.has(false)).override_failure_message("unlocked during a boss turn").is_false()
	assert_int(locked_frames.size()).is_greater(0)
	assert_that(unlocked_after_round).is_equal([true, true, true, true])
	for side: String in MatchRecords.SIDES:
		var truth: Dictionary = controller.query().snapshot(side)
		var shown: Dictionary = _view.side(StringName(side))
		assert_int(int(shown.mana.available)).is_equal(int(truth.mana.available))
		assert_int(int(shown.deck_count)).is_equal(int(truth.deck_count))
