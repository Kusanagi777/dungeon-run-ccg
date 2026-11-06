## Performance: AC-27 (design/gdd/meta-progression.md M4.3, F5; ADR-0004 Verification):
## a profile at `run_log_cap` with full ArchivedRuns saves within `max_save_ms` at the
## median of 20 and stays under `max_profile_bytes`. Both thresholds are read from the
## shipped `profile_defaults.json`, so a retune moves the gate. Real writes in a scratch
## directory. The GDD's "minimum spec" machine is not this one: the `PERF` line is what the
## owner compares against it.
extends GdUnitTestSuite

const DEFAULTS_FILE: String = "res://assets/data/profile_defaults.json"
const SAVES: int = 20
const DAMAGE_KEYS: int = 30

var _root: String
var _knobs: Dictionary
## Held here: a store's clock is a Callable, which does not keep its object alive.
var _clock: ProfileFixtures.ManualClock


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()
	_knobs = JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS_FILE)).config[ProfileStore.KNOBS_KEY]


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


## A store loaded from a file whose `run_log` is full, every entry a real ArchivedRun.
func _store_at_the_cap() -> ProfileStore:
	var store: ProfileStore = ProfileFixtures.store(_root, _clock, {
		"run_log_cap": int(_knobs.run_log_cap),
		"archive_top_cards": int(_knobs.archive_top_cards),
		"max_save_ms": int(_knobs.max_save_ms),
	})
	var log: Array = []
	for index: int in int(_knobs.run_log_cap):
		log.append(store.archived_form(ProfileFixtures.full_record("run_%03d" % index, DAMAGE_KEYS)))
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"run_log": log}))
	store.load_profile()
	return store


func test_save_at_run_log_cap_median_of_20_is_within_max_save_ms() -> void:
	# Arrange
	var store: ProfileStore = _store_at_the_cap()
	store.save_profile()
	var samples: Array[int] = []

	# Act
	for _save: int in SAVES:
		var started: int = Time.get_ticks_usec()
		store.save_profile()
		samples.append(Time.get_ticks_usec() - started)

	# Assert
	var measured: Dictionary = PerfGate.stats(samples)
	var budget_usec: int = int(_knobs.max_save_ms) * PerfGate.USEC_PER_MS
	print("PERF meta_progression save at cap: median %d us, p95 %d us, max %d us (budget %d us)" % [
		int(measured.median), int(measured.p95), int(measured.max), budget_usec])
	assert_int(int(measured.median)).is_less_equal(budget_usec)


func test_archive_at_run_log_cap_median_of_20_is_within_max_save_ms() -> void:
	# Arrange: the save that ends a run, with an entry printed and one pruned each time
	var store: ProfileStore = _store_at_the_cap()
	store.save_profile()
	store.set_setting(&"keep_run_records", false)
	var records: Array = []
	for index: int in SAVES:
		records.append(ProfileFixtures.full_record("run_new_%02d" % index, DAMAGE_KEYS))
	var samples: Array[int] = []

	# Act
	for record: Dictionary in records:
		var started: int = Time.get_ticks_usec()
		store.archive_run(record)
		samples.append(Time.get_ticks_usec() - started)

	# Assert
	var measured: Dictionary = PerfGate.stats(samples)
	var budget_usec: int = int(_knobs.max_save_ms) * PerfGate.USEC_PER_MS
	print("PERF meta_progression archive at cap: median %d us, p95 %d us, max %d us (budget %d us)" % [
		int(measured.median), int(measured.p95), int(measured.max), budget_usec])
	assert_int(int(measured.median)).is_less_equal(budget_usec)


func test_profile_at_run_log_cap_is_under_max_profile_bytes() -> void:
	# Arrange
	var store: ProfileStore = _store_at_the_cap()

	# Act
	store.save_profile()

	# Assert
	var size: int = ProfileFixtures.read_bytes(_root.path_join("profile.json")).size()
	print("PERF meta_progression profile at cap: %d bytes (budget %d)" % [size, int(_knobs.max_profile_bytes)])
	assert_int(size).is_less(int(_knobs.max_profile_bytes))
