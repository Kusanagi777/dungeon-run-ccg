## Integration: `Boot.driver_factory()`, the per-task planner factory chosen by
## `planner_mode` (story boot-composition-root/story-009; ADR-0008 Decisions 1, 7, 11;
## ADR-0006 Implementation Guidelines; DD-X31, DD-X33).
##
## Every boot runs on a fresh instance of the script, never the shared autoload. A
## [ReadyDatabase] gives `Boot` a `Ready` database over [MatchDriverFixture]'s data, so
## a test sets `runtime` by hand. A planner is asserted by class with `is`: no worker
## and no task of `Boot`'s starts here (TD-012). The override tests drive
## [FakePlannerTask]s, which run nothing.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SOURCE_ROOT: String = "res://src/"
const SHIPPED_ROOT: String = "res://assets/data/"
const FAILED_FIXTURE: String = "res://tests/fixtures/data/parse_error/"
const MINIMAL_FIXTURE: String = "res://tests/fixtures/data/minimal/"
const STAGE_ROOT: String = "user://boot_driver_factory_test/"
const NO_BOOT_MESSAGE: String = "Boot.driver_factory(): no Ready boot, so no factory (call boot() first and check BootResult.ok)"
const AI_SYNC: String = "--ai-sync"
const MODE_WORKER: String = "worker"
const MODE_TIME_SLICED: String = "time_sliced"
const MODE_IMMEDIATE: String = "immediate"
const PLANNER_FIELD: String = "runtime.planner_mode"
## A fractional `slice_ms`, so a conversion that truncates first is seen: the answer
## is `int(slice_ms * 1000)`, not `int(slice_ms) * 1000`.
const SLICE_MS: float = 2.5
const SLICE_USEC: int = 2500
const CALLS: int = 3
## The fixture-data folder a debug entry may point at at run time: `Main`'s
## `--boot-fail-fixture` and `MatchDebugLoader`'s `--fixture` read data from here. A
## data path is not a script dependency, so an export without `tests/*` still loads.
const FIXTURE_DATA_PATH: String = "res://tests/fixtures/"
const HELPER_CLASS: String = "ImmediatePlannerTask"
const TESTS_PATH: String = "res://tests"


## A [MatchDriverFixture.FixtureDatabase] already `Ready`, so `Boot` keeps it as it is.
## It counts the reads the factory is held to.
class ReadyDatabase:
	extends MatchDriverFixture.FixtureDatabase

	## `config()` calls for `ai_profiles`.
	var profile_reads: int = 0
	## `boss()` calls: one per driver built.
	var boss_reads: int = 0

	func _init(source: MatchDriverFixture.FixtureDatabase) -> void:
		super(source.records)
		bodies = source.bodies
		bodies["profile_defaults"] = {"telegraph_mode": BossAI.TELEGRAPH_FULL}

	func state() -> CardDatabase.State:
		return CardDatabase.State.READY

	func config(config_name: String) -> Variant:
		if config_name == BossAI.CONFIG_NAME:
			profile_reads += 1
		return super(config_name)

	func boss(id: String) -> Variant:
		boss_reads += 1
		return super(id)


var _db: ReadyDatabase = null
## Typed `Node`, so a call into `Boot` resolves at run time, as `Boot` itself has no
## `class_name`.
var _boot: Node = null
var _drivers: Array[MatchDriver] = []


func before() -> void:
	DirAccess.make_dir_recursive_absolute(STAGE_ROOT)
	for file_name: String in DirAccess.get_files_at(MINIMAL_FIXTURE):
		if file_name.get_extension() == "json":
			DirAccess.copy_absolute(MINIMAL_FIXTURE + file_name, STAGE_ROOT + file_name)


func after() -> void:
	for file_name: String in DirAccess.get_files_at(STAGE_ROOT):
		DirAccess.remove_absolute(STAGE_ROOT + file_name)
	DirAccess.remove_absolute(STAGE_ROOT)


func before_test() -> void:
	_db = ReadyDatabase.new(MatchDriverFixture.database())
	_boot = auto_free(BOOT_SCRIPT.new())
	_drivers = []


func after_test() -> void:
	for driver: MatchDriver in _drivers:
		driver.shutdown()
	_drivers = []
	# Never in the tree, so `_exit_tree` will not drop a real `MetaFacade`'s lock.
	_boot._release_profile()


# --- helpers -----------------------------------------------------------------

## `_boot` booted over `_db`, with `runtime` set to [param mode].
func _boot_with_mode(mode: String) -> void:
	var runtime: Dictionary = _db.bodies[BossAI.CONFIG_NAME].runtime
	runtime["planner_mode"] = mode
	runtime["slice_ms"] = SLICE_MS
	var result: BootResult = _boot.boot({"card_database": _db, "meta": MetaStub.new(_db)})
	GameAssertions.fail_if(not result.ok, "the fixture boot did not end Ready")


## A driver from [param factory], shut down after the test.
func _drive(factory: Callable) -> MatchDriver:
	var driver: MatchDriver = factory.call(MatchDriverFixture.match_config(TestEventLog.new()))
	_drivers.append(driver)
	return driver


## [constant CALLS] tasks from the planner `Callable` a [param factory] driver holds.
func _tasks_from(factory: Callable) -> Array[PlannerTask]:
	var planner: Callable = _drive(factory)._planner_factory
	var tasks: Array[PlannerTask] = []
	for _i: int in CALLS:
		tasks.append(planner.call())
	return tasks


## Asserts [param tasks] are pairwise distinct objects, none of them started.
func _assert_distinct_and_unstarted(tasks: Array[PlannerTask]) -> void:
	for index: int in tasks.size():
		assert_bool(tasks[index].is_live()).is_false()
		for other: int in range(index + 1, tasks.size()):
			assert_object(tasks[index]).is_not_same(tasks[other])


## Every line of the `.gd` and `.tscn` files under [param dir], as `[path, text]`.
func _source_lines(dir: String) -> Array[PackedStringArray]:
	var lines: Array[PackedStringArray] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd" or file.get_extension() == "tscn":
			var path: String = dir.path_join(file)
			for line: String in FileAccess.get_file_as_string(path).split("\n"):
				lines.append(PackedStringArray([path, line]))
	for sub: String in DirAccess.get_directories_at(dir):
		lines.append_array(_source_lines(dir.path_join(sub)))
	return lines


## Which of [param lines] (`[path, text]`) would tie `src/` to `tests/`: the helper
## class, or a `res://tests` path other than [constant FIXTURE_DATA_PATH], on any line
## that is not a `##` doc comment.
func _test_tree_references(lines: Array[PackedStringArray]) -> Array[String]:
	var hits: Array[String] = []
	for line: PackedStringArray in lines:
		if line[1].strip_edges().begins_with("##"):
			continue
		var bare: String = line[1].replace(FIXTURE_DATA_PATH, "")
		if bare.contains(HELPER_CLASS) or bare.contains(TESTS_PATH):
			hits.append("%s: %s" % [line[0], line[1]])
	return hits


## Rewrites the staged `ai_profiles.json` to say [param mode].
func _stage_mode(mode: String) -> void:
	var text: String = FileAccess.get_file_as_string(MINIMAL_FIXTURE + BossAI.PROFILES_FILE)
	var staged: FileAccess = FileAccess.open(STAGE_ROOT + BossAI.PROFILES_FILE, FileAccess.WRITE)
	staged.store_string(text.replace("\"planner_mode\": \"worker\"", "\"planner_mode\": \"%s\"" % mode))
	staged.close()


# --- AC-1: a new driver per call, over the settings of that call --------------

func test_driver_factory_returns_a_new_driver_over_the_services_database_per_call() -> void:
	# Arrange
	_boot_with_mode(MODE_WORKER)
	var factory: Callable = _boot.driver_factory()

	# Act
	var first: MatchDriver = _drive(factory)
	var second: MatchDriver = _drive(factory)

	# Assert
	assert_object(first).is_not_same(second)
	assert_object(first.query()._db).is_same(_boot.services().card_database)
	assert_object(second.query()._db).is_same(_boot.services().card_database)


func test_driver_factory_takes_the_settings_snapshot_at_each_call() -> void:
	# Arrange
	_boot_with_mode(MODE_WORKER)
	var factory: Callable = _boot.driver_factory()
	var meta: MetaApi = _boot.services().meta

	# Act
	var first: MatchDriver = _drive(factory)
	var changed: Error = meta.set_setting(MatchDriver.SETTING_TELEGRAPH, BossAI.TELEGRAPH_OFF)
	var second: MatchDriver = _drive(factory)

	# Assert
	assert_int(changed).is_equal(OK)
	assert_str(first._boss_ai._telegraph_mode).is_equal(BossAI.TELEGRAPH_FULL)
	assert_str(first._settings[MatchDriver.SETTING_TELEGRAPH]).is_equal(BossAI.TELEGRAPH_FULL)
	assert_str(second._boss_ai._telegraph_mode).is_equal(BossAI.TELEGRAPH_OFF)


func test_driver_factory_builder_reads_the_config_once_and_builds_no_driver() -> void:
	# Arrange
	_boot_with_mode(MODE_TIME_SLICED)
	_db.profile_reads = 0

	# Act
	var factory: Callable = _boot.driver_factory()

	# Assert
	assert_bool(factory.is_valid()).is_true()
	assert_int(_db.profile_reads).is_equal(1)
	assert_int(_db.boss_reads).is_equal(0)


func test_driver_factory_before_boot_is_an_empty_callable_and_an_error() -> void:
	# Arrange
	var out: Dictionary = {}

	# Act / Assert
	await assert_error(func() -> void: out.factory = _boot.driver_factory()).is_push_error(NO_BOOT_MESSAGE)
	assert_bool((out.factory as Callable).is_null()).is_true()


func test_driver_factory_after_a_failed_load_is_an_empty_callable_and_an_error() -> void:
	# Arrange: the `meta` override stays in `Services` whatever the load's outcome, so
	# a factory that looked only at `meta` would serve a database with no data.
	var failed: CardDatabase = CardDatabase.new(DataLoader.new(FAILED_FIXTURE))
	var result: BootResult = _boot.boot({"card_database": failed, "meta": MetaStub.new(_db)})
	var out: Dictionary = {}

	# Act / Assert
	assert_bool(result.ok).is_false()
	assert_object(_boot.services().meta).is_not_null()
	await assert_error(func() -> void: out.factory = _boot.driver_factory()).is_push_error(NO_BOOT_MESSAGE)
	assert_bool((out.factory as Callable).is_null()).is_true()


# --- AC-2: a new task per call, by planner_mode and --ai-sync -----------------

func test_worker_mode_makes_a_new_worker_task_per_call() -> void:
	# Arrange
	_boot_with_mode(MODE_WORKER)

	# Act
	var tasks: Array[PlannerTask] = _tasks_from(_boot.driver_factory(Callable(), PackedStringArray()))

	# Assert
	assert_int(tasks.size()).is_equal(CALLS)
	for task: PlannerTask in tasks:
		assert_bool(task is WorkerPoolPlannerTask).is_true()
	_assert_distinct_and_unstarted(tasks)


func test_time_sliced_mode_makes_a_new_sliced_task_per_call_on_the_config_budget() -> void:
	# Arrange
	_boot_with_mode(MODE_TIME_SLICED)

	# Act
	var tasks: Array[PlannerTask] = _tasks_from(_boot.driver_factory(Callable(), PackedStringArray()))

	# Assert
	assert_int(tasks.size()).is_equal(CALLS)
	for task: PlannerTask in tasks:
		assert_bool(task is TimeSlicedPlannerTask).is_true()
		assert_int((task as TimeSlicedPlannerTask).slice_usec).is_equal(SLICE_USEC)
	_assert_distinct_and_unstarted(tasks)


func test_ai_sync_selects_the_sliced_task_whatever_the_config_says() -> void:
	# Arrange: the suite runs on a debug build, which is where the flag counts.
	_boot_with_mode(MODE_WORKER)

	# Act
	var tasks: Array[PlannerTask] = _tasks_from(_boot.driver_factory(Callable(), PackedStringArray([AI_SYNC])))

	# Assert
	assert_bool(OS.is_debug_build()).is_true()
	for task: PlannerTask in tasks:
		assert_bool(task is TimeSlicedPlannerTask).is_true()
		assert_int((task as TimeSlicedPlannerTask).slice_usec).is_equal(SLICE_USEC)
	_assert_distinct_and_unstarted(tasks)


# --- AC-3: the override, and no tie from src/ to tests/ -----------------------

func test_override_supplies_every_task_the_driver_plans_with() -> void:
	# Arrange: both things the override must beat are set against it.
	_boot_with_mode(MODE_TIME_SLICED)
	var made := MatchDriverFixture.TaskFactory.new()
	var factory: Callable = _boot.driver_factory(made.make, PackedStringArray([AI_SYNC]))

	# Act: the player's forecast, which returns, then the boss's plan task.
	var driver: MatchDriver = _drive(factory)
	MatchDriverFixture.to_boss_main(driver)

	# Assert
	assert_int(made.made.size()).is_greater(1)
	assert_object(driver._task).is_same(made.last())
	for task: FakePlannerTask in made.made:
		assert_int(task.starts).is_equal(1)


func test_override_is_chosen_without_reading_the_config() -> void:
	# Arrange
	_boot_with_mode(MODE_TIME_SLICED)
	var made := MatchDriverFixture.TaskFactory.new()
	_db.profile_reads = 0

	# Act
	var factory: Callable = _boot.driver_factory(made.make)

	# Assert
	assert_bool(factory.is_valid()).is_true()
	assert_int(_db.profile_reads).is_equal(0)


func test_src_has_no_reference_to_the_test_tree() -> void:
	# Arrange
	var lines: Array[PackedStringArray] = _source_lines(SOURCE_ROOT)

	# Act
	var hits: Array[String] = _test_tree_references(lines)

	# Assert
	assert_int(lines.size()).is_greater(0)
	assert_array(hits).is_empty()


func test_the_source_scan_finds_a_planted_reference() -> void:
	# Arrange: the two things the scan must see, and the two it must let by.
	var helper := PackedStringArray(["a.gd", "var task := %s.new()" % HELPER_CLASS])
	var path := PackedStringArray(["b.gd", "const P := preload(\"%s/helpers/x.gd\")" % TESTS_PATH])
	var doc := PackedStringArray(["c.gd", "## `%s` lives in `%s/helpers/`" % [HELPER_CLASS, TESTS_PATH]])
	var data := PackedStringArray(["d.gd", "const ROOT: String = \"%sdata/\"" % FIXTURE_DATA_PATH])
	var lines: Array[PackedStringArray] = [helper, path, doc, data]

	# Act
	var hits: Array[String] = _test_tree_references(lines)

	# Assert
	assert_int(hits.size()).is_equal(2)
	assert_str(hits[0]).starts_with("a.gd")
	assert_str(hits[1]).starts_with("b.gd")


# --- AC-4: `immediate` is a data error through Boot's own validators (DD-X33) ---

func test_immediate_planner_mode_fails_the_load_with_one_row() -> void:
	# Arrange
	_stage_mode(MODE_IMMEDIATE)

	# Act
	var result: BootResult = _boot.boot({"card_database": CardDatabase.new(DataLoader.new(STAGE_ROOT))})

	# Assert
	var rows: Array[Dictionary] = []
	for entry: Dictionary in result.report.errors():
		if entry.get("field") == PLANNER_FIELD:
			rows.append(entry)
	assert_bool(result.ok).is_false()
	assert_int(rows.size()).is_equal(1)
	# The loader files an owner's row as `E_DELEGATED`, its code heading the message.
	assert_str(str(rows[0].code)).is_equal(str(ValidationReport.E_DELEGATED))
	assert_str(str(rows[0].message)).starts_with(str(BossAI.E_AI_UNKNOWN_FIELD))


func test_each_shipping_planner_mode_loads_ready() -> void:
	for mode: String in [MODE_WORKER, MODE_TIME_SLICED]:
		# Arrange
		_stage_mode(mode)
		var boot: Node = auto_free(BOOT_SCRIPT.new())

		# Act
		var result: BootResult = boot.boot({"card_database": CardDatabase.new(DataLoader.new(STAGE_ROOT))})

		# Assert
		assert_bool(result.ok).override_failure_message("%s: %s" % [mode, result.report.to_text()]).is_true()
		boot._release_profile()


func test_shipped_data_boots_to_a_factory() -> void:
	# Act
	var result: BootResult = _boot.boot({"card_database": CardDatabase.new(DataLoader.new(SHIPPED_ROOT))})

	# Assert
	assert_bool(result.ok).override_failure_message(result.report.to_text()).is_true()
	assert_bool((_boot.driver_factory() as Callable).is_valid()).is_true()
