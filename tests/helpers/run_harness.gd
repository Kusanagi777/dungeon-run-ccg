## The Run Structure Acceptance Criteria fixture (design/gdd/run-structure.md AC
## preamble): the `boss_a1..a6`, `boss_b1..b6`, `boss_c1..c4` pool, the hero `hero_war`
## with a 15-card starter deck, a stub Reward Draft, a stub Treasures, a stub Meta, and
## Match Rules scripted down to one `match_ended`.
##
## The driver is a real [MatchDriver] over [MatchDriverFixture]'s board, writing to the
## run's own match log, because `RunMachine` connects to it and `Treasures.collect_state`
## reads its hooks. [method finish] is the script: it stops the engine, seals the log the
## way Match Rules does and fires the signal. Everything the stubs were asked lands in
## [member trace], in call order, across all of them.
## [codeblock]
## var h := RunHarness.new()
## var run: RunMachine = h.machine()
## run.new_run(RunHarness.HERO_ID, "42")
## h.play_floor(run)                 # begin, win, take the first option of each draft
## h.begin(run)
## h.finish_loss(run)
## h.release()                       # from after_test
## [/codeblock]
class_name RunHarness
extends RefCounted

const HERO_ID: String = "hero_war"
const DATA_VERSION: String = "fixture-data-1"
const ENGINE_VERSION: String = "fixture-engine-1"
const BAND_PREFIXES: Array[String] = ["boss_a", "boss_b", "boss_c"]
const POOL_SIZES: Array[int] = [6, 6, 4]
const BAND_HEALTH: Array[int] = [30, 40, 50]
const STARTER_PREFIX: String = "starter_"
const TREASURE_PREFIX: String = "t"
const BUNDLE_PREFIX: String = "b"
## How many treasures and bundles the fixture knows; the stub offers three of them.
const TREASURE_COUNT: int = 20
const BUNDLE_COUNT: int = 40
const OFFER_SIZE: int = 3
const SHIPPED_RUN_STRUCTURE: String = "res://assets/data/run_structure.json"
const SHIPPED_PROFILE_DEFAULTS: String = "res://assets/data/profile_defaults.json"
const SHIPPED_HEROES_BALANCE: String = "res://assets/data/heroes_balance.json"
const SHIPPED_REWARD_DRAFT: String = "res://assets/data/reward_draft.json"
## A log cap no fixture run reaches.
const MAX_EVENTS: int = 10000
## The first instance the scripted damage in [method finish] is dealt from.
const SCRIPTED_SOURCE: int = 900


## The AC-preamble database: a `CardDatabase` double answering from memory.
class FakeDb:
	extends CardDatabase

	var records: Dictionary = {}
	var bands: Dictionary = {1: [], 2: [], 3: []}
	var hero_list: Array = []
	var bodies: Dictionary = {}
	var version: String = DATA_VERSION

	func _init() -> void:
		pass

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		return records.get(id)

	func any_record(id: String) -> Variant:
		return records.get(id)

	func hero(id: String) -> Variant:
		return records.get(id)

	func boss(id: String) -> Variant:
		return records.get(id)

	func treasure(id: String) -> Variant:
		return records.get(id)

	func bundle(id: String) -> Variant:
		return records.get(id)

	func heroes() -> Array:
		return hero_list

	func bosses_in_band(band: int) -> Array:
		return bands.get(band, [])

	func config(config_name: String) -> Variant:
		return bodies.get(config_name)

	func data_version() -> String:
		return version


## A Reward Draft double. [method offer] draws from the stream it is given, so its
## answer proves the stream position; `empty_kinds` makes a kind answer `[]`.
class StubDraft:
	extends RewardDraft

	var harness: RunHarness
	var empty_kinds: Array[String] = []
	var init_value: Dictionary = {"schema_version": 1, "treasure_pool": ["t1", "t2", "t3"]}
	var calls: Array[Dictionary] = []
	var log: EventLog = null

	func _init(db: CardDatabase, meta: MetaApi, owner: RunHarness) -> void:
		super(db, null, meta, RunHarness.shipped_body(SHIPPED_REWARD_DRAFT))
		harness = owner

	func set_run_log(run_log: EventLog) -> void:
		log = run_log

	func init_run(run_state: RunState) -> Dictionary:
		calls.append({"method": "init_run", "state": run_state})
		harness.trace.append("init_run")
		return init_value.duplicate(true)

	func offer(kind: StringName, run_state: RunState, stream: RngStream) -> Offer:
		harness.trace.append("offer:%s" % kind)
		calls.append({"method": "offer", "kind": String(kind), "floor": run_state.floor, "draws_before": stream.draws})
		var result: Offer = Offer.new()
		result.kind = String(kind)
		result.floor = run_state.floor
		if empty_kinds.has(String(kind)):
			return result
		var pool: Array = RunHarness.pool_ids(result.kind)
		var drawn: Array[String] = []
		for _i: int in OFFER_SIZE:
			var at: int = stream.randi_range(0, pool.size() - 1)
			drawn.append(pool[at])
			pool.remove_at(at)
		drawn.sort()
		result.option_ids = drawn
		if log != null:
			@warning_ignore("return_value_discarded")
			log.append(RunCodes.EVENT_DRAFT_OFFERED, {"floor": result.floor, "kind": result.kind, "option_ids": Array(drawn), "flags": []})
		return result

	func pick(kind: StringName, id: Variant, current_offer: Offer, run_state: RunState) -> Pick:
		harness.trace.append("pick:%s" % kind)
		calls.append({"method": "pick", "kind": String(kind), "id": id, "offer": current_offer, "state": run_state})
		var result: Pick = Pick.new()
		result.picked_id = id
		result.option_index = current_offer.option_ids.find(str(id))
		if String(kind) == DraftRecord.KIND_BUNDLE and id != null:
			result.card_ids_added.assign(RunHarness.bundle_cards(str(id)))
		if log != null:
			@warning_ignore("return_value_discarded")
			log.append(RunCodes.EVENT_DRAFT_PICKED, {"floor": run_state.floor, "kind": String(kind), "picked_id": id, "option_index": result.option_index, "card_ids_added": Array(result.card_ids_added)})
		return result

	func calls_of(method: String) -> Array:
		return calls.filter(func(call: Dictionary) -> bool: return call.method == method)


## A Treasures double: no records, every call kept.
class StubTreasures:
	extends Treasures

	var harness: RunHarness
	var state_to_collect: Dictionary = {"schema_version": 1, "by_treasure": {}}
	var installer_calls: Array[Array] = []
	var collect_calls: Array[Dictionary] = []

	func _init(db: CardDatabase, owner: RunHarness) -> void:
		super(db, {})
		harness = owner

	func installers_for(treasure_ids: Array, _treasure_state: Dictionary) -> Array[HookInstaller]:
		harness.trace.append("installers_for")
		installer_calls.append(treasure_ids.duplicate())
		return []

	func collect_state(hooks: HookRegistry, result: Dictionary) -> Dictionary:
		harness.trace.append("collect_state")
		collect_calls.append({"hooks": hooks, "result": result})
		return state_to_collect.duplicate(true)


## A Meta double with a slot, a refusal queue and a lock list.
class StubMeta:
	extends MetaStub

	var harness: RunHarness
	## Codes the next saves answer, oldest first; `OK` once it runs out.
	var save_answers: Array[Error] = []
	var locked: Array[String] = []
	var granted: Array = []

	func _init(db: CardDatabase, owner: RunHarness) -> void:
		super(db)
		harness = owner

	func save_active_run(record: Dictionary) -> Error:
		harness.trace.append("save_active_run")
		harness.save_attempts.append(record.duplicate(true))
		if not save_answers.is_empty():
			var answer: Error = save_answers.pop_front()
			if answer != OK:
				return answer
		return super(record)

	func archive_run(record: Dictionary) -> Dictionary:
		harness.trace.append("archive_run")
		harness.archived.append(record.duplicate(true))
		var answer: Dictionary = super(record)
		answer["unlocks_granted"] = granted.duplicate()
		return answer

	func clear_active_run() -> void:
		harness.trace.append("clear_active_run")
		super()

	## What a damaged slot answers; `MetaStub` holds only Dictionaries.
	func load_active_run() -> Variant:
		return super() if _active_run is Dictionary or _active_run == null else _active_run

	func is_hero_unlocked(hero_id: String) -> bool:
		return not locked.has(hero_id) and super(hero_id)

	## The slot as a load from disk answers it: JSON's floats.
	func reload_slot_as_json() -> void:
		var held: Variant = load_active_run()
		if held != null:
			_active_run = JSON.parse_string(JSON.stringify(held))

	## Replaces the slot.
	func set_slot(record: Variant) -> void:
		_active_run = record


## A `RunMachine` whose RNG service records every draw (run-structure AC-2).
class SpyMachine:
	extends RunMachine

	func _make_rng(run_seed: int, data_version: String) -> RngService:
		return TestRngService.new(run_seed, data_version)


var db: FakeDb
var meta: StubMeta
var draft: StubDraft
var treasures: StubTreasures
## Every `MatchConfig` the factory received, oldest first.
var configs: Array[Dictionary] = []
var drivers: Array[MatchDriver] = []
## Call order across the stubs.
var trace: Array[String] = []
## Every record `save_active_run` was handed, refused ones too.
var save_attempts: Array[Dictionary] = []
## Every record `archive_run` was handed.
var archived: Array[Dictionary] = []
## The value `RunMachine.ticks_clock` reads, for a test to move.
var ticks: int = 0
var _driver_db: CardDatabase = MatchDriverFixture.database()
var _tasks: MatchDriverFixture.TaskFactory = MatchDriverFixture.TaskFactory.new()


## [param db_edit] may reshape [member db] before anything reads it.
func _init(db_edit: Callable = Callable()) -> void:
	db = RunHarness.fixture_db()
	if db_edit.is_valid():
		db_edit.call(db)
	meta = StubMeta.new(db, self)
	draft = StubDraft.new(db, meta, self)
	treasures = StubTreasures.new(db, self)


## The parsed `config` body of a shipped data file.
static func shipped_body(path: String) -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary).config


## The AC-preamble database.
static func fixture_db() -> FakeDb:
	var fixture: FakeDb = FakeDb.new()
	fixture.bodies = {
		"profile_defaults": shipped_body(SHIPPED_PROFILE_DEFAULTS),
		"heroes_balance": shipped_body(SHIPPED_HEROES_BALANCE),
	}
	for band_index: int in BAND_PREFIXES.size():
		for i: int in range(1, POOL_SIZES[band_index] + 1):
			add_boss(fixture, "%s%d" % [BAND_PREFIXES[band_index], i], band_index + 1)
	var starter: Array[String] = starter_deck()
	for id: String in starter:
		fixture.records[id] = {"id": id, "tags": [], "cost": 1}
	var hero: Dictionary = {"id": HERO_ID, "name": "War", "set": "war", "health": 30, "hero_power": "power", "starter_deck": starter}
	fixture.records[HERO_ID] = hero
	fixture.hero_list = [hero]
	for id: String in pool_ids(DraftRecord.KIND_TREASURE):
		fixture.records[id] = {"id": id}
	for id: String in pool_ids(DraftRecord.KIND_BUNDLE):
		fixture.records[id] = {"id": id, "cards": bundle_cards(id)}
		for card_id: String in bundle_cards(id):
			fixture.records[card_id] = {"id": card_id, "tags": [], "cost": 1}
	return fixture


## Adds a BossDef to [param fixture] in [param band].
static func add_boss(fixture: FakeDb, id: String, band: int, tags: Array = [], health: int = -1) -> void:
	var boss: Dictionary = {
		"id": id, "name": id, "band": band, "health": health if health >= 0 else BAND_HEALTH[band - 1],
		"deck": ["boss_card"], "ai_profile": "default", "passive": null, "tags": tags,
	}
	fixture.records[id] = boss
	(fixture.bands[band] as Array).append(boss)


## The 15 ids of the fixture hero's starter deck.
static func starter_deck() -> Array[String]:
	var deck: Array[String] = []
	for i: int in range(1, TestConstants.STARTER_DECK_SIZE + 1):
		deck.append("%s%02d" % [STARTER_PREFIX, i])
	return deck


## Every fixture id of [param kind].
static func pool_ids(kind: String) -> Array:
	var ids: Array = []
	var treasure: bool = kind == DraftRecord.KIND_TREASURE
	for i: int in range(1, (TREASURE_COUNT if treasure else BUNDLE_COUNT) + 1):
		ids.append("%s%d" % [TREASURE_PREFIX if treasure else BUNDLE_PREFIX, i])
	return ids


## The three card ids of fixture bundle [param bundle_id], in data order.
static func bundle_cards(bundle_id: String) -> Array:
	var cards: Array = []
	for i: int in range(1, TestConstants.BUNDLE_CARD_COUNT + 1):
		cards.append("%s_card_%d" % [bundle_id, i])
	return cards


## The shipped `run_structure` body as `RunMachine` receives it, [param overrides] on top.
static func run_config(overrides: Dictionary = {}) -> Dictionary:
	var config: Dictionary = shipped_body(SHIPPED_RUN_STRUCTURE)
	config["max_match_events"] = MAX_EVENTS
	config["engine_version"] = ENGINE_VERSION
	config.merge(overrides, true)
	return config


## The events of [param log] of [param type], payloads and all.
static func events_of(log: EventLog, type: StringName) -> Array:
	return Array(log.events_since(0)).filter(func(e: Dictionary) -> bool: return str(e.type) == String(type))


## The `run_warning`s of [param log] with [param code].
static func warnings_of(log: EventLog, code: String) -> Array:
	return events_of(log, RunCodes.EVENT_RUN_WARNING).filter(func(e: Dictionary) -> bool: return str(e.payload.code) == code)


## The event types of [param log], in order.
static func event_types(log: EventLog) -> Array:
	return Array(log.events_since(0)).map(func(e: Dictionary) -> String: return str(e.type))


## A [SpyMachine] over the stubs, on fixed clocks.
func machine(config_overrides: Dictionary = {}) -> RunMachine:
	var run: RunMachine = SpyMachine.new(db, meta, draft, treasures, run_config(config_overrides), _make_driver)
	run.unix_clock = func() -> int: return 1000
	run.ticks_clock = func() -> int: return ticks
	run.entropy = func() -> int: return 7
	return run


## Stops every driver the factory built; call from `after_test`.
func release() -> void:
	for driver: MatchDriver in drivers:
		driver.shutdown()
	drivers.clear()


## Starts the floor's match; the driver is in [member drivers].
func begin(run: RunMachine) -> MatchDriver:
	var driver: MatchDriver = run.begin_match()
	GameAssertions.fail_if(driver == null, "begin_match refused: %s" % RunCodes.code_name(run.last_error))
	return driver


## The match of [method begin] ends with [param result]. [param damage] is
## `{card_id: amount}`, written to the log as the player's own damage.
func finish(result: Dictionary, damage: Dictionary = {}) -> void:
	var driver: MatchDriver = drivers.back()
	var log: EventLog = configs.back().log
	driver.shutdown()
	var source: int = SCRIPTED_SOURCE
	for card_id: String in damage:
		source += 1
		@warning_ignore("return_value_discarded")
		log.append(&"minion_summoned", {"entity_id": source, "card_id": card_id, "side": MatchRecords.SIDE_PLAYER})
		@warning_ignore("return_value_discarded")
		log.append(&"damage_dealt", {"source": source, "dealt": damage[card_id]})
	@warning_ignore("return_value_discarded")
	log.append(&"match_ended", result)
	driver.match_ended.emit(result)


func finish_win(run: RunMachine, turns: int = 10, damage: Dictionary = {}) -> void:
	finish(MatchRecords.match_result(MatchRecords.RESULT_WIN, MatchRecords.SIDE_PLAYER, MatchRecords.REASON_HERO_DEAD, run.state.floor, turns), damage)


func finish_loss(run: RunMachine, reason: String = MatchRecords.REASON_HERO_DEAD, turns: int = 10) -> void:
	finish(MatchRecords.match_result(MatchRecords.RESULT_LOSS, MatchRecords.SIDE_BOSS, reason, run.state.floor, turns))


func finish_fault(run: RunMachine) -> void:
	finish(MatchRecords.match_result(MatchRecords.RESULT_FAULT, null, MatchRecords.REASON_EVENT_CAP, run.state.floor, 3))


## The pending offer's ids; `[]` when none is pending.
func offered(run: RunMachine) -> Array:
	var model: Variant = run.current_offer()
	return model.option_ids if model is Dictionary else []


## Takes the first option of every pending step of the floor.
func take_drafts(run: RunMachine) -> void:
	while run.phase() == RunState.STATUS_POST_MATCH_REWARD:
		var answer: Error = run.draft_pick(StringName(run.state.reward_step), offered(run)[0])
		GameAssertions.fail_if(answer != OK, "draft_pick refused: %s" % RunCodes.code_name(answer))


## One floor, begun, won and drafted through.
func play_floor(run: RunMachine, turns: int = 10, damage: Dictionary = {}) -> void:
	@warning_ignore("return_value_discarded")
	begin(run)
	finish_win(run, turns, damage)
	take_drafts(run)


## Plays floors until [param floor_number] is the current one, in `pre_match`.
func advance_to(run: RunMachine, floor_number: int) -> void:
	while run.state.floor < floor_number:
		play_floor(run)


func _make_driver(config: Dictionary) -> MatchDriver:
	configs.append(config)
	trace.append("driver_factory")
	var driver := MatchDriver.new(MatchDriverFixture.match_config(config.log), _driver_db, {}, _tasks.make, func() -> int: return 0)
	drivers.append(driver)
	return driver
