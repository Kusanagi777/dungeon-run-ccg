## The Card Database: the one owner of game data (card-database CR-1..CR-9;
## ADR-0002). It runs `DataLoader` once at boot and holds the result.
##
## The composition root constructs it and calls `load(validators)` (boot
## epic); tests inject a `DataLoader` over a fixture root. Nothing under
## `src/core/data/` references the composition root (ADR-0001, gate G3).
##
## [codeblock]
## var db: CardDatabase = CardDatabase.new(DataLoader.new("res://tests/fixtures/data/minimal/"))
## var report: ValidationReport = db.load({})
## db.state() == CardDatabase.State.READY   # no errors in the report
## [/codeblock]
##
## This story implements `Unloaded → Loading → Ready | Failed` (States table).
## Story 006 adds the freeze, `index_of`, the CR-6 queries and `config(name)`
## over the snapshot kept in `_snapshot`; Story 008 adds `reload()`,
## `Reloading`, `E_NOT_LOADED` and `E_NOT_SUPPORTED`. Single-thread-only.
class_name CardDatabase
extends RefCounted

## card-database States and Transitions. `RELOADING` is debug-only (Story 008).
enum State { UNLOADED, LOADING, READY, FAILED, RELOADING }

var _loader: DataLoader
var _state: State = State.UNLOADED
var _report: ValidationReport = ValidationReport.new()
## The loader's snapshot after a clean load, `null` otherwise. Story 006
## freezes it and builds the query tables from it.
var _snapshot: Variant = null


## A database that will load through `loader`, or through a `DataLoader` over
## `res://assets/data/` when none is given.
## Example: `CardDatabase.new(DataLoader.new("res://tests/fixtures/data/minimal/"))`.
func _init(loader: DataLoader = null) -> void:
	_loader = loader if loader != null else DataLoader.new()


## Runs the CR-5 load pipeline once, synchronously, and returns its report.
## `validators` is the composition-time map
## `{effects, ai_profile, unlock, treasure: Callable, configs: {<name>: Callable}}`
## (ADR-0002 Decision 4; consumed from Story 004). Any error leaves the state
## `FAILED` with no snapshot; none leaves it `READY`.
## Example: `if db.load(validators).has_errors(): show_data_error(db.report())`.
func load(validators: Dictionary) -> ValidationReport:
	_state = State.LOADING
	var result: DataLoader.LoadResult = _loader.run(validators)
	_report = result.report
	if _report.has_errors():
		_snapshot = null
		_state = State.FAILED
	else:
		_snapshot = result.snapshot
		_state = State.READY
	return _report


## The current state (States table). `UNLOADED` until `load()` is called.
## Example: `db.state() == CardDatabase.State.FAILED`.
func state() -> State:
	return _state


## The last load's report: empty before any load, warnings only when `READY`,
## the full report when `FAILED` (CR-8).
## Example: `print(db.report().to_text())`.
func report() -> ValidationReport:
	return _report
