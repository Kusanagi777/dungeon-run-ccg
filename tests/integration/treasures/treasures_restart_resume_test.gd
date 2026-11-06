## Integration: a resumed run reinstalls its treasures (treasures story 011;
## design/gdd/treasures.md T3.4, T4, T6, AC-4, AC-9, AC-10, AC-11; run-structure R3, R4,
## R8.2, R8.3; ADR-0005 rules 5, 8; ADR-0008).
##
## A real `RunMachine` over the shipped data, a real `MatchDriver` and a real
## `RewardDraft`, against `MetaStub`'s slot. The record a test edits goes through
## JSON on its way back into the slot, as a save does, so its numbers arrive as floats.
## A "quit" is what the OS does to a process: nothing is called on the machine, and
## the next launch is a new machine over the same slot.
extends GdUnitTestSuite

const SEED_INPUT: String = "00000000000000A7"
const HERO_WAR: String = TreasureFixtures.HERO_WAR
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const CROWN: String = TreasureFixtures.CROWN
const CLOAK: String = TreasureFixtures.CLOAK
const SIGNET: String = TreasureFixtures.SIGNET
const TITHE: String = "treasure_grave_tithe"
const TITHE_KEY: String = "hero_decay_first_win"
const NO_STATE: Dictionary = TreasureFixtures.NO_STATE
const ENGINE_VERSION: String = "test-engine"
## The treasure floors the edited record's picks sit on (R5.1).
const PICK_FLOORS: Array[int] = [1, 3, 5]
## A `treasure_state` this build cannot read, holding a blob that must not get through.
const FUTURE_VERSION: int = 99
const BLOB: Dictionary = {"n": 1}
## The sizes of the deal: both decks shuffled once, 3 and 4 starting cards.
const SHUFFLES_BEFORE_COMMAND: int = 2
const STARTING_CARDS: int = 7
## Enough ticks for the boss's plan to run after the second command.
const TICKS: int = 8
const WARNING_DUPLICATE: String = Treasures.WARNING_DUPLICATE_TREASURE
const WARNING_RESET: String = Treasures.WARNING_TREASURE_STATE_RESET


## Meta whose profile no longer holds [member removed] (Edge Cases "unlock revoked
## mid-run").
class RevokedMeta:
	extends MetaStub

	var removed: String = ""

	func unlocked_keys() -> Array:
		return super().filter(func(key: Variant) -> bool: return str(key) != removed)


var _db: CardDatabase = null
var _configs: Array[Dictionary] = []
var _drivers: Array[MatchDriver] = []


func before() -> void:
	_db = TreasureFixtures.shipped_database()


func after() -> void:
	_db = null


func after_test() -> void:
	for driver: MatchDriver in _drivers:
		driver.shutdown()
	_drivers.clear()
	_configs.clear()


func _make_driver(config: Dictionary) -> MatchDriver:
	_configs.append(config)
	var driver := MatchDriver.new(config, _db, {}, func() -> PlannerTask: return ImmediatePlannerTask.new(), func() -> int: return 0)
	_drivers.append(driver)
	return driver


func _machine(meta: MetaApi) -> RunMachine:
	var treasures: Treasures = Treasures.new(_db, _db.config("treasures_balance"))
	var draft: RewardDraft = RewardDraft.new(_db, treasures, meta, _db.config("reward_draft"))
	var config: Dictionary = _db.config("run_structure").duplicate(true)
	config["max_match_events"] = EventLog.max_events_for(_db.config("rng_event_log"))
	config["engine_version"] = ENGINE_VERSION
	return RunMachine.new(_db, meta, draft, treasures, config, _make_driver)


## A saved run in [param meta]'s slot on floor 1, holding [param ids] with
## [param treasure_state]: a hand-edited save, through JSON.
func _save_with(meta: MetaApi, ids: Array, treasure_state: Dictionary = NO_STATE) -> void:
	var run: RunMachine = _machine(meta)
	assert_int(run.new_run(HERO_WAR, SEED_INPUT)).is_equal(OK)
	var record: Dictionary = meta.load_active_run()
	var rows: Array = []
	for i: int in ids.size():
		rows.append(DraftRecord.make(PICK_FLOORS[i], DraftRecord.KIND_TREASURE, [ids[i]], ids[i], []).to_dict())
	record["treasures"] = ids.duplicate()
	record["drafts"] = rows
	record["treasure_state"] = treasure_state.duplicate(true)
	assert_int(meta.save_active_run(JSON.parse_string(JSON.stringify(record)))).is_equal(OK)


## A new machine, as a new launch has, resumed from the slot.
func _resumed(meta: MetaApi) -> RunMachine:
	var run: RunMachine = _machine(meta)
	assert_int(run.resume()).override_failure_message(str(run.last_error)).is_equal(OK)
	return run


func _begin(run: RunMachine) -> MatchDriver:
	var driver: MatchDriver = run.begin_match()
	assert_object(driver).is_not_null()
	return driver


## The match's `{point: entries}` and hosts, by value.
func _registry(driver: MatchDriver) -> Dictionary:
	var hooks: HookRegistry = driver.hooks()
	var points: Dictionary = {}
	for point: StringName in HookRegistry.TRIGGER_POINTS + HookRegistry.VALUE_POINTS:
		points[String(point)] = Array(hooks.entries(point)).duplicate(true)
	return {"points": points, "hosts": Array(hooks.hosts())}


## The player's first two commands: a keep-all mulligan and `end_turn`, then the boss's
## answer as far as [constant TICKS] take it.
func _two_commands(driver: MatchDriver) -> void:
	assert_bool(bool(driver.submit(driver.legal_commands()[0]).accepted)).is_true()
	assert_bool(bool(driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted)).is_true()
	for _i: int in TICKS:
		driver.tick()


func _match_events(attempt: int) -> Array:
	return Array((_configs[attempt].log as EventLog).events_since(0))


## The events before the first player command: through `mulligan_offered`.
func _before_first_command(events: Array) -> Array:
	var kept: Array = []
	for event: Dictionary in events:
		kept.append(event)
		if str(event.type) == "mulligan_offered":
			break
	return kept


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


func _run_warnings(run: RunMachine, code: String) -> Array:
	return _of_type(Array(run.run_log.events_since(0)), "run_warning").filter(func(e: Dictionary) -> bool: return str(e.payload.code) == code)


func _installer_rows(attempt: int) -> Array:
	return (_configs[attempt].player.hook_installers as Array).map(func(installer: HookInstaller) -> Dictionary: return installer.to_dict())


## The match begun, two commands played, the process gone, the next launch restarting
## the floor: AC-9's whole story. Leaves the two attempts in [member _configs].
func _quit_after_the_second_command_and_restart() -> Dictionary:
	var meta: MetaStub = MetaStub.new(_db)
	_save_with(meta, [CROWN, CLOAK])
	var first_run: RunMachine = _resumed(meta)
	var first: MatchDriver = _begin(first_run)
	var first_registry: Dictionary = _registry(first)
	_two_commands(first)
	# the quit: the driver's worker stops with the process, and no save is written
	first.shutdown()
	var run: RunMachine = _resumed(meta)
	var restarted: MatchDriver = _begin(run)
	return {"run": run, "driver": restarted, "first_registry": first_registry}


# --- AC-9: quit after the second command -----------------------------------------

func test_ac9_the_first_attempt_really_got_past_the_second_command() -> void:
	# Act
	@warning_ignore("return_value_discarded")
	_quit_after_the_second_command_and_restart()

	# Assert: the first log holds the mulligan, the end of turn and the boss's Start
	var first: Array = _match_events(0)
	assert_int(_of_type(first, "mulligan_resolved").size()).is_equal(1)
	assert_int(_of_type(first, "turn_ended").size()).is_greater_equal(1)
	assert_bool(_of_type(first, "turn_started").any(func(e: Dictionary) -> bool: return str(e.payload.side) == MatchRecords.SIDE_BOSS)).is_true()


func test_ac9_the_two_logs_are_identical_up_to_the_first_player_command() -> void:
	# Act
	@warning_ignore("return_value_discarded")
	_quit_after_the_second_command_and_restart()

	# Assert
	var first: Array = _before_first_command(_match_events(0))
	var second: Array = _before_first_command(_match_events(1))
	assert_str(JSON.stringify(second)).is_equal(JSON.stringify(first))


func test_ac9_the_compared_prefix_holds_the_shuffles_the_crystal_and_the_deal() -> void:
	# Act
	@warning_ignore("return_value_discarded")
	_quit_after_the_second_command_and_restart()

	# Assert
	var second: Array = _before_first_command(_match_events(1))
	assert_int(_of_type(second, "deck_shuffled").size()).is_equal(SHUFFLES_BEFORE_COMMAND)
	assert_int(_of_type(second, "mana_added").size()).is_equal(1)
	assert_int(_of_type(second, "card_drawn").size()).is_equal(STARTING_CARDS)


func test_ac9_the_restarted_registry_equals_the_first() -> void:
	# Act
	var quit: Dictionary = _quit_after_the_second_command_and_restart()

	# Assert
	var restarted: Dictionary = _registry(quit.driver)
	assert_str(JSON.stringify(restarted)).is_equal(JSON.stringify(quit.first_registry))
	var treasure_hosts: Array = restarted.hosts.filter(func(host: Dictionary) -> bool: return host.host_kind == HookInstaller.HOST_KIND_TREASURE)
	assert_array(treasure_hosts.map(func(host: Dictionary) -> String: return str(host.host_id))).is_equal([CROWN, CLOAK])


func test_ac9_the_same_two_commands_on_the_restart_replay_the_same_match() -> void:
	# Arrange
	var quit: Dictionary = _quit_after_the_second_command_and_restart()

	# Act
	_two_commands(quit.driver)

	# Assert: the `ai_1` stream restarted too, so the boss answers the same way
	assert_str(JSON.stringify(_match_events(1))).is_equal(JSON.stringify(_match_events(0)))


func test_ac9_the_resume_counts_the_quit_as_a_second_attempt() -> void:
	# Act
	var quit: Dictionary = _quit_after_the_second_command_and_restart()

	# Assert
	var run: RunMachine = quit.run
	assert_int(run.state.attempts_on(1)).is_equal(2)
	var resumed: Array = _of_type(Array(run.run_log.events_since(0)), "run_resumed")
	assert_int(int(resumed.back().payload.attempt)).is_equal(2)
	assert_str(str(resumed.back().payload.phase)).is_equal(RunState.STATUS_PRE_MATCH)


# --- AC-10: state after the match, and an unknown version ------------------------

func test_ac10_collect_state_after_a_played_match_is_the_empty_v1_shape() -> void:
	# Arrange: a blob in the state, which the match's end must not carry forward
	var meta: MetaStub = MetaStub.new(_db)
	_save_with(meta, [CROWN, CLOAK], {"schema_version": Treasures.SCHEMA_VERSION, "by_treasure": {CROWN: BLOB}})
	var run: RunMachine = _resumed(meta)
	var driver: MatchDriver = _begin(run)
	assert_bool(bool(driver.submit(driver.legal_commands()[0]).accepted)).is_true()
	for _i: int in TICKS:
		driver.tick()

	# Act: a real `Ended`, so `collect_state` reads the hooks of a finished match
	assert_bool(bool(driver.submit(MatchRecords.concede()).accepted)).is_true()

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_DEFEAT)
	assert_dict(run.state.treasure_state).is_equal({"schema_version": Treasures.SCHEMA_VERSION, "by_treasure": {}})


func test_ac10_an_unknown_state_version_warns_once_on_the_run_log() -> void:
	# Arrange
	var meta: MetaStub = MetaStub.new(_db)
	_save_with(meta, [SIGNET], {"schema_version": FUTURE_VERSION, "by_treasure": {SIGNET: BLOB}})
	var run: RunMachine = _resumed(meta)

	# Act
	@warning_ignore("return_value_discarded")
	_begin(run)

	# Assert
	assert_int(_run_warnings(run, WARNING_RESET).size()).is_equal(1)


func test_ac10_the_reset_warning_stays_off_the_match_log() -> void:
	# Arrange
	var meta: MetaStub = MetaStub.new(_db)
	_save_with(meta, [SIGNET], {"schema_version": FUTURE_VERSION, "by_treasure": {}})

	# Act
	@warning_ignore("return_value_discarded")
	_begin(_resumed(meta))

	# Assert
	assert_array(_of_type(_match_events(0), "run_warning")).is_empty()


func test_ac10_the_installers_equal_a_stateless_runs() -> void:
	# Arrange
	var stale: MetaStub = MetaStub.new(_db)
	_save_with(stale, [SIGNET], {"schema_version": FUTURE_VERSION, "by_treasure": {SIGNET: BLOB}})
	var clean: MetaStub = MetaStub.new(_db)
	_save_with(clean, [SIGNET])

	# Act
	@warning_ignore("return_value_discarded")
	_begin(_resumed(stale))
	@warning_ignore("return_value_discarded")
	_begin(_resumed(clean))

	# Assert
	assert_str(JSON.stringify(_installer_rows(0))).is_equal(JSON.stringify(_installer_rows(1)))
	assert_dict(_installer_rows(0)[0].state).is_empty()


func test_ac10_a_known_version_through_json_keeps_its_state_and_warns_nothing() -> void:
	# Arrange: the version comes back as the float 1.0, which is still version 1
	var meta: MetaStub = MetaStub.new(_db)
	_save_with(meta, [SIGNET], {"schema_version": Treasures.SCHEMA_VERSION, "by_treasure": {SIGNET: BLOB}})
	var run: RunMachine = _resumed(meta)

	# Act
	@warning_ignore("return_value_discarded")
	_begin(run)

	# Assert
	assert_array(_run_warnings(run, WARNING_RESET)).is_empty()
	assert_dict(_installer_rows(0)[0].state).is_equal(BLOB)


# --- AC-4: a duplicate in a hand-edited save -------------------------------------

func test_ac4_a_duplicate_in_the_save_warns_once_on_the_run_log() -> void:
	# Arrange
	var meta: MetaStub = MetaStub.new(_db)
	_save_with(meta, [SIGNET, CROWN, SIGNET])
	var run: RunMachine = _resumed(meta)

	# Act
	@warning_ignore("return_value_discarded")
	_begin(run)

	# Assert
	var warnings: Array = _run_warnings(run, WARNING_DUPLICATE)
	assert_int(warnings.size()).is_equal(1)
	assert_str(str(warnings[0].payload.detail.treasure_id)).is_equal(SIGNET)
	assert_bool(bool(warnings[0].payload.diagnostic)).is_true()


func test_ac4_the_match_installs_two_treasure_hosts_in_pick_order() -> void:
	# Arrange
	var meta: MetaStub = MetaStub.new(_db)
	_save_with(meta, [SIGNET, CROWN, SIGNET])

	# Act
	var driver: MatchDriver = _begin(_resumed(meta))

	# Assert
	var treasure_hosts: Array = driver.hooks().hosts().filter(func(host: Dictionary) -> bool: return host.host_kind == HookInstaller.HOST_KIND_TREASURE)
	assert_array(treasure_hosts.map(func(host: Dictionary) -> String: return str(host.host_id))).is_equal([SIGNET, CROWN])
	assert_array(_of_type(_match_events(0), "hook_install_skipped")).is_empty()


# --- AC-11: an unlock revoked mid-run --------------------------------------------

func test_ac11_a_revoked_unlock_still_installs_the_held_treasure() -> void:
	# Arrange
	var meta := RevokedMeta.new(_db)
	meta.removed = TITHE_KEY
	_save_with(meta, [TITHE])

	# Act
	var driver: MatchDriver = _begin(_resumed(meta))

	# Assert
	assert_array(driver.hooks().hosts().map(func(host: Dictionary) -> String: return str(host.host_id))).contains([TITHE])


func test_ac11_the_pool_query_on_that_profile_leaves_it_out() -> void:
	# Arrange
	var meta := RevokedMeta.new(_db)
	meta.removed = TITHE_KEY
	var unlocked: Dictionary = {}
	for key: Variant in meta.unlocked_keys():
		unlocked[key] = true

	# Act
	var pool: Array = Treasures.new(_db, _db.config("treasures_balance")).pool(unlocked, [])

	# Assert
	assert_array(pool.map(func(def: Dictionary) -> String: return str(def.id))).not_contains([TITHE])
