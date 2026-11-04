## PERFORMANCE SUITE — the Card Database memory budget. NOT part of the blocking
## run; the non-blocking `performance` job runs this folder (`tests/README.md`).
## One gate per suite: the load gate and how the shipped data is loaded are in
## `card_database_load_budget_perf_test.gd`.
##
## Story: production/epics/card-database/story-009-load-and-memory-budget.md AC-2.
## Control manifest Foundation guardrail: frozen snapshot ≤ `data_memory_budget_mb`.
##
## Memory: the `Performance.MEMORY_STATIC` delta across one `load()` (the
## database kept alive until after the second reading) and, as the documented
## proxy, the UTF-8 byte length of `DataLoader.canonical_json(snapshot)` — a
## conservative upper figure, since the precomputed pools repeat records the
## snapshot shares by reference. Both are printed; the delta is compared when
## it is positive (measurable), else the proxy, and the `PERF` line says which.
## `Performance.get_monitor(MEMORY_STATIC)` is NOT SOURCEABLE against
## `docs/engine-reference/godot/` (a pre-4.4 API; the story rates it LOW risk) —
## the numbers printed are what this build observed.
extends GdUnitTestSuite

const SHIPPED_ROOT: String = "res://assets/data/"
const BOOT_SCRIPT: GDScript = preload("res://src/core/boot.gd")
const BYTES_PER_MB: int = 1024 * 1024

var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("card_database snapshot", "the test ended before its measurement"))


func _validators() -> Dictionary:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	return boot._collect_validators(null, true)


## A fresh database over the shipped data, loaded once; fails the test with the
## report when the load is not `Ready` (a budget over a failed load means nothing).
func _loaded_db() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
	var report: ValidationReport = db.load(_validators())
	assert_int(db.state()).override_failure_message(report.to_text()).is_equal(CardDatabase.State.READY)
	return db


func test_shipped_snapshot_is_within_data_memory_budget_mb() -> void:
	# Arrange — warm-up load, thrown away
	var warm: CardDatabase = _loaded_db()
	var budget_mb: int = int(warm.config("card_database").data_memory_budget_mb)
	var validators: Dictionary = _validators()
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))

	# Act
	var before: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	db.load(validators)
	var after: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var delta: int = int(after - before)
	var proxy: int = DataLoader.canonical_json(db.snapshot_handle()).to_utf8_buffer().size()
	var measurable: bool = delta > 0
	var compared: int = delta if measurable else proxy
	_measured = true
	print("PERF card_database snapshot (shipped): MEMORY_STATIC delta %d bytes, canonical-JSON proxy %d bytes; compared: %s (budget %d MB = %d bytes)"
		% [delta, proxy, "delta" if measurable else "proxy (delta not measurable)", budget_mb, budget_mb * BYTES_PER_MB])

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_int(compared).override_failure_message("snapshot %d bytes (%s), budget %d MB" % [compared, "delta" if measurable else "proxy", budget_mb]) \
		.is_less_equal(budget_mb * BYTES_PER_MB)
	assert_int(proxy).override_failure_message("canonical-JSON proxy %d bytes, budget %d MB" % [proxy, budget_mb]) \
		.is_less_equal(budget_mb * BYTES_PER_MB)
