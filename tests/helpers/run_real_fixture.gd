## A whole real run for the `tests/integration/run/` suites: the shipped data, a real
## `RewardDraft`, `Treasures` and `MatchDriver`, and a player [method play_out] plays
## with the commands the engine lists. [member boss_health] weakens the boss through the
## `MatchConfig`, so the bot wins in a few turns. Meta is the caller's: `MetaStub`,
## or a real [MetaFacade] over [method facade].
## [codeblock]
## var game := RunRealFixture.new(db)
## var run: RunMachine = game.machine(MetaStub.new(db))
## run.new_run("hero_war", "42")
## game.play_out(run, game.begin(run))
## game.release()
## [/codeblock]
class_name RunRealFixture
extends RefCounted

const HERO_ID: String = "hero_war"
const ENGINE_VERSION: String = "test-engine"
## More steps than a match of a few turns needs: running out fails the test.
const MAX_STEPS: int = 4000
const MAX_TICKS_PER_STEP: int = 200
const BOSS_SIDE: String = MatchRecords.SIDE_BOSS
## The boss's deck when [member boss_health] is set.
const FILLER_CARD: String = "neutral_tunnel_rat"
const FILLER_DECK_SIZE: int = 30
## Lower than any card's first hit, so one blow ends the match; 0 leaves the data's.
const ONE_BLOW: int = 1

var db: CardDatabase
## The health of every boss, when above 0.
var boss_health: int = 0
## `reward_draft` knobs laid over the data's, for [method machine].
var draft_overrides: Dictionary = {}
## Every `MatchConfig` the factory received, oldest first.
var configs: Array[Dictionary] = []
var drivers: Array[MatchDriver] = []


func _init(database: CardDatabase) -> void:
	db = database


## A real `RunMachine` over [param meta]. [param archive] files its match logs.
func machine(meta: MetaApi, overrides: Dictionary = {}, archive: EventLogArchive = null) -> RunMachine:
	var treasures: Treasures = Treasures.new(db, db.config("treasures_balance"))
	var draft_config: Dictionary = (db.config("reward_draft") as Dictionary).duplicate(true)
	draft_config.merge(draft_overrides, true)
	var draft: RewardDraft = RewardDraft.new(db, treasures, meta, draft_config)
	var config: Dictionary = (db.config("run_structure") as Dictionary).duplicate(true)
	config["max_match_events"] = EventLog.max_events_for(db.config("rng_event_log"))
	config["engine_version"] = ENGINE_VERSION
	config.merge(overrides, true)
	return RunMachine.new(db, meta, draft, treasures, config, _make_driver, archive)


## A `MetaFacade` over a `ProfileStore` rooted at [param root], unloaded.
## [param writer] replaces the store's `AtomicFileWriter`.
static func facade(database: CardDatabase, root: String, writer: AtomicFileWriter = null) -> MetaFacade:
	var body: Dictionary = database.config("profile_defaults")
	var knobs: Dictionary = (body[ProfileStore.KNOBS_KEY] as Dictionary).duplicate(true)
	knobs["io_retry_ms"] = 0
	var lock := ProfileLock.new(root.path_join("profile.lock"), int(knobs.lock_stale_s))
	var store := ProfileStore.new(ProfileStore.settings_defaults(body), knobs, writer if writer != null else AtomicFileWriter.new(), lock, Time.get_unix_time_from_system, root)
	var abandon_is_loss: bool = (database.config("run_structure") as Dictionary).abandon_counts_as_loss
	return MetaFacade.new(store, UnlockEvaluator.new(database, knobs), StatsFold.new(abandon_is_loss))


## Stops every driver; call from `after_test`.
func release() -> void:
	for driver: MatchDriver in drivers:
		driver.shutdown()
	drivers.clear()


func begin(run: RunMachine) -> MatchDriver:
	var driver: MatchDriver = run.begin_match()
	GameAssertions.fail_if(driver == null, "begin_match refused: %s" % RunCodes.code_name(run.last_error))
	return driver


## Plays [param driver]'s match to its end for the player: every card and power it
## can, then every attack, at the boss's hero when one is listed, then `end_turn`.
func play_out(run: RunMachine, driver: MatchDriver) -> void:
	for _i: int in MAX_STEPS:
		if run.phase() != RunState.STATUS_IN_MATCH:
			return
		_settle(run, driver)
		if run.phase() != RunState.STATUS_IN_MATCH:
			return
		var command: Variant = _next_command(driver)
		if command != null:
			@warning_ignore("return_value_discarded")
			driver.submit(command)
	GameAssertions.fail_if(true, "the match did not end in %d steps" % MAX_STEPS)


## The player concedes through [param driver] after the mulligan, a queued concede
## included (ADR-0008 Decision 2).
func concede(run: RunMachine, driver: MatchDriver) -> void:
	@warning_ignore("return_value_discarded")
	driver.submit(driver.legal_commands()[0])
	@warning_ignore("return_value_discarded")
	driver.submit(MatchRecords.concede())
	for _i: int in MAX_TICKS_PER_STEP:
		if run.phase() != RunState.STATUS_IN_MATCH:
			return
		driver.tick()


## Takes the first option of every pending draft step.
func take_drafts(run: RunMachine) -> void:
	while run.phase() == RunState.STATUS_POST_MATCH_REWARD:
		var offer: Dictionary = run.current_offer()
		var answer: Error = run.draft_pick(StringName(run.state.reward_step), offer.option_ids[0])
		GameAssertions.fail_if(answer != OK, "draft_pick refused: %s" % RunCodes.code_name(answer))


## One floor, played and drafted through.
func play_floor(run: RunMachine) -> void:
	play_out(run, begin(run))
	take_drafts(run)


func _settle(run: RunMachine, driver: MatchDriver) -> void:
	for _i: int in MAX_TICKS_PER_STEP:
		if run.phase() != RunState.STATUS_IN_MATCH:
			return
		driver.tick()
		if not driver.is_planning() and _players_move(driver):
			return


## True when the engine lists a player command.
func _players_move(driver: MatchDriver) -> bool:
	return not _of_player(driver).is_empty()


func _of_player(driver: MatchDriver) -> Array:
	return driver.legal_commands().filter(func(c: Dictionary) -> bool: return str(c.issuer) == MatchRecords.SIDE_PLAYER)


func _next_command(driver: MatchDriver) -> Variant:
	var legal: Array = _of_player(driver)
	if legal.is_empty():
		return null
	var boss_hero: int = int(driver.query().snapshot(BOSS_SIDE).hero.entity_id)
	for kind: String in [MatchRecords.CMD_MULLIGAN, MatchRecords.CMD_CHOOSE, MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_USE_HERO_POWER, MatchRecords.CMD_ATTACK]:
		var of_kind: Array = legal.filter(func(c: Dictionary) -> bool: return str(c.type) == kind)
		if not of_kind.is_empty():
			var at_boss: Array = of_kind.filter(func(c: Dictionary) -> bool: return _target_of(c) == boss_hero)
			return at_boss[0] if not at_boss.is_empty() else of_kind[0]
	return legal.back()


## What a weakened boss plays: nothing that taunts or heals.
func _filler_deck() -> Array:
	var deck: Array = []
	for _i: int in FILLER_DECK_SIZE:
		deck.append(FILLER_CARD)
	return deck


static func _target_of(command: Dictionary) -> Variant:
	return command.get("args", command).get("target_id")


func _make_driver(config: Dictionary) -> MatchDriver:
	configs.append(config)
	if boss_health > 0:
		config.boss["health"] = boss_health
		config.boss["hook_installers"] = []
		config.boss["deck"] = _filler_deck()
	var driver := MatchDriver.new(config, db, {}, func() -> PlannerTask: return ImmediatePlannerTask.new(), func() -> int: return 0)
	drivers.append(driver)
	return driver
