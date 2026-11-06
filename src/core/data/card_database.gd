## The Card Database: the one owner of game data (card-database CR-1..CR-9;
## ADR-0002). It runs `DataLoader` once at boot and holds the result.
##
## The composition root constructs it and calls `load(validators)` (boot
## epic); tests inject a `DataLoader` over a fixture root and a
## `ValidatorStubs` map. Nothing under `src/core/data/` references the
## composition root (ADR-0001, gate G3).
##
## [codeblock]
## var db: CardDatabase = CardDatabase.new(DataLoader.new("res://tests/fixtures/data/clean/"))
## var report: ValidationReport = db.load(validators)
## db.state() == CardDatabase.State.READY   # no errors in the report
## db.collectible_pool("war")               # CardDef[] id-ascending
## [/codeblock]
##
## States (card-database States and Transitions, story 008), exactly:
## `UNLOADED → LOADING` on `load()`; `LOADING → READY | FAILED`;
## `READY | FAILED → RELOADING` on `reload()` in a debug build only, and not
## while the predicate of [method set_reload_busy] answers `true`;
## `RELOADING → READY` on success (the new snapshot replaces the old in one
## assignment) or back to the previous state on failure (`READY` keeps its
## snapshot, `FAILED` stays `FAILED`). `READY → LOADING` never happens: a
## second `load()` is a no-op returning the existing report — in a debug build
## too (only `reload()` rebuilds), so a release build loads exactly once.
## Lookups (`has`, `card`, `hero`, `hero_power`, `boss`, `treasure`, `bundle`,
## `cards_by_*`, `collectible_pool`, `bundle_pool`, `treasure_pool`,
## `bosses_in_band`, `heroes`) answer in `Ready` and — the one exception to
## "queries are illegal before Ready" (ADR-0002 Decision 4, 2026-11-03) —
## during CR-5 stage 7, for the loader's delegated validators, from the
## staged, id-sorted records that passed stage 6 (`_stage7_lookups_open`).
## `config()` and `data_version()` answer in `Ready` only; called during stage
## 7 they return `null` / `""`, log, and assert in a debug build. Any query,
## `config()`, `data_version()` or `snapshot_handle()` in another state
## returns `null` / empty / `""`, logs one `E_NOT_LOADED` error per call
## naming the method and the state, and asserts in a debug build (after the
## log, so release behaviour is the same minus the assert). The build type is
## injected (`_init`'s `debug_build`, default `OS.is_debug_build()`) so tests
## can drive the release branch from the editor build; it gates `reload()`
## and the asserts only — never the missing-validator rule (story 004).
## Every lookup reads one private source ([method _source]): in `Ready` the
## loader's frozen stage-9 snapshot (story 006; `DataLoader.LoadResult`), so
## every record, nested effect, pool Array and config body a query returns is
## read-only (CR-7) — a caller that needs to change one takes `duplicate(true)`
## first. Records are returned as the snapshot's own Dictionary
## (`records[index_of[id]]`, O(1), no copy); the CR-6 pools are precomputed at
## freeze and returned as the same frozen Array each call; `cards_by_*` filter
## on demand and freeze their result. `data_version()` is the snapshot's CR-9
## fingerprint (`DataLoader.fingerprint`, story 007). The snapshot object is
## never mutated: `reload()` builds a new one, so a consumer that pinned
## [method snapshot_handle] (or a record) keeps reading the data it started
## with. Single-thread-only.
class_name CardDatabase
extends RefCounted

## card-database States and Transitions. `RELOADING` is debug-only (Story 008).
enum State { UNLOADED, LOADING, READY, FAILED, RELOADING }

## What the stage-7 guard reports when `config()` / `data_version()` is called
## from a delegated validator.
const STAGE7_GUARD_MESSAGE: String = "CardDatabase.%s() is illegal before Ready (only lookups are open during stage 7)"
## The `E_NOT_LOADED` log line: method, then state name.
const NOT_LOADED_MESSAGE: String = "E_NOT_LOADED: CardDatabase.%s() is illegal in state %s (queries answer in Ready only)"

var _loader: DataLoader
var _debug_build: bool
var _state: State = State.UNLOADED
var _report: ValidationReport = ValidationReport.new()
## The loader's frozen snapshot after a clean load (the lookup source in
## `Ready`), `null` otherwise.
var _snapshot: Variant = null
## The lookup source while `_stage7_lookups_open`.
var _stage7_staging: Dictionary = {}
## True only while the loader runs CR-5 stage 7 (ADR-0002 Decision 4).
var _stage7_lookups_open: bool = false
## The map `load()` was given; `reload()` runs the pipeline with it again.
var _validators: Dictionary = {}
## The report of the last debug `reload()`, `null` before one ran.
var _last_reload_report: ValidationReport = null
## A `Callable() -> bool`, `true` while a reload must wait; empty when none is set.
var _reload_busy: Callable = Callable()


## A database that will load through `loader`, or through a `DataLoader` over
## `res://assets/data/` when none is given. `debug_build` (default
## `OS.is_debug_build()`) selects the debug behaviour: `reload()` allowed and
## caller-bug asserts on; tests pass `false` to drive the release branch.
## Example: `CardDatabase.new(DataLoader.new("res://tests/fixtures/data/minimal/"))`.
func _init(loader: DataLoader = null, debug_build: bool = OS.is_debug_build()) -> void:
	_loader = loader if loader != null else DataLoader.new()
	_debug_build = debug_build


## Runs the CR-5 load pipeline once, synchronously, and returns its report.
## `validators` is the composition-time map
## `{effects, ai_profile, unlock, treasure: Callable, configs: {<name>: Callable}}`
## (ADR-0002 Decision 4); each validator receives this database, whose
## lookups are open during stage 7. Any error leaves the state `FAILED` with
## no snapshot (CR-8: `report()` holds the full report; there is no "load what
## passed" path); none swaps the frozen snapshot in and leaves it `READY`.
## Only the first call loads: any later one (in any state, any build type)
## changes nothing and returns the existing report — `reload()` is the
## debug-build way to rebuild.
## Example: `if db.load(validators).has_errors(): show_data_error(db.report())`.
func load(validators: Dictionary) -> ValidationReport:
	if _state != State.UNLOADED:
		return _report
	_validators = validators
	_state = State.LOADING
	var result: DataLoader.LoadResult = _loader.run(validators, self)
	_report = result.report
	if _report.has_errors():
		_snapshot = null
		_state = State.FAILED
	else:
		_snapshot = result.snapshot
		_state = State.READY
	return _report


## Debug builds: runs the pipeline again over the loader's root with the
## validators `load()` was given, in state `RELOADING`, and returns the new
## report (also kept as [method last_reload_report]). On success the new
## frozen snapshot replaces the old one in a single assignment, `report()`
## becomes the new report and the state is `READY`; the old snapshot object
## is untouched, so a match holding [method snapshot_handle] (or any record)
## keeps reading the data it started with. On failure the state returns to
## what it was: from `READY` the previous snapshot, `report()` and
## `data_version()` stay active; from `FAILED` it stays `FAILED` and
## `report()` becomes the new full report. Release builds: returns a report
## whose one entry is `E_NOT_SUPPORTED` and touches nothing. Before any
## `load()` finished (`UNLOADED`, or re-entered while loading): a report
## whose one entry is `E_NOT_LOADED`, nothing touched. While the predicate of
## [method set_reload_busy] answers `true`: a report whose one entry is
## `E_BUSY`, nothing touched and the loader not run.
## Holds two snapshots briefly (≤ 2 × `data_memory_budget_mb`).
## Example: `var r: ValidationReport = db.reload(); toast("Data reloaded: %d records" % r.record_count())`.
func reload() -> ValidationReport:
	var refused: ValidationReport = ValidationReport.new()
	if not _debug_build:
		refused.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_NOT_SUPPORTED, "", null, null,
			"reload() is debug-only; a release build loads once per process")
		return refused
	if _state != State.READY and _state != State.FAILED:
		refused.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_NOT_LOADED, "", null, null,
			"reload() needs a finished load(); state is %s" % State.keys()[_state])
		return refused
	if _reload_busy.is_valid() and _reload_busy.call():
		refused.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_BUSY, "", null, null,
			"reload() refused: a reader of the snapshot is running; try again when it has finished")
		return refused
	var previous: State = _state
	_state = State.RELOADING
	var result: DataLoader.LoadResult = _loader.run(_validators, self)
	_last_reload_report = result.report
	if not result.report.has_errors():
		_snapshot = result.snapshot
		_report = result.report
		_state = State.READY
	else:
		_state = previous
		if previous == State.FAILED:
			_report = result.report
	return result.report


## Installs [param busy], a `Callable() -> bool` read on the main thread at the top
## of [method reload]: while it answers `true`, a debug reload is refused with
## `E_BUSY`. The composition root sets it, so this class names none of what it
## waits for (ADR-0001). An empty `Callable` clears it.
## Example: `db.set_reload_busy(tracker.any_live)`.
func set_reload_busy(busy: Callable) -> void:
	_reload_busy = busy


## The report of the last debug `reload()` (success or failure) for the debug
## overlay, or `null` when none has run. Example: `db.last_reload_report()`.
func last_reload_report() -> ValidationReport:
	return _last_reload_report


## The frozen snapshot in `Ready` (the [class DataLoader.LoadResult] shape,
## every container read-only), for a consumer that must keep reading one
## consistent data set across a debug `reload()` — a match pins it at its
## start. Before `Ready`: `{}` and `E_NOT_LOADED` as for a query.
## Example: `var pinned: Dictionary = db.snapshot_handle()`.
func snapshot_handle() -> Dictionary:
	if _state != State.READY:
		_not_loaded("snapshot_handle")
		return {}
	return _snapshot


## The current state (States table). `UNLOADED` until `load()` is called.
## Example: `db.state() == CardDatabase.State.FAILED`.
func state() -> State:
	return _state


## The last load's report: empty before any load, warnings only when `READY`,
## the full report when `FAILED` (CR-8).
## Example: `print(db.report().to_text())`.
func report() -> ValidationReport:
	return _report


## True when a record with `id` exists (any type). An unknown id is not an
## error: `has()` never logs for it, in `Ready` or during stage 7 — it is how a
## caller that may ask for an absent id checks before `card(id)`. Called before
## `Ready` (outside stage 7) it is illegal like every query: `false` and the
## logged state error. Example: `db.has("war_iron_axe")`.
func has(id: String) -> bool:
	var source: Dictionary = _source("has")
	return not source.is_empty() and source.index_of.has(id)


## The frozen CardDef `id` (the same Dictionary on every call), or `null`, a
## logged error and, in `Ready` in a debug build, an assert. Treat it as
## read-only; `duplicate(true)` for a writable copy (CR-7).
## Example: `db.card("war_iron_axe").cost`.
func card(id: String) -> Variant:
	return _record("card", "CardDef", id)


## The frozen record `id` of any type, or `null` without a logged error: for an id a log
## names, which may be a card, a hero power or a treasure.
## Example: `db.any_record("power_sharpen").name`.
func any_record(id: String) -> Variant:
	var source: Dictionary = _source("any_record")
	if source.is_empty():
		return null
	var at: Variant = source.index_of.get(id)
	return null if at == null else source.records_by_type[at.type][at.position]


## The frozen HeroDef `id`, or `null` as for [method card]. Example: `db.hero("hero_war").starter_deck`.
func hero(id: String) -> Variant:
	return _record("hero", "HeroDef", id)


## The frozen HeroPowerDef `id`, or `null` as for [method card]. Example: `db.hero_power("power_sharpen").cost`.
func hero_power(id: String) -> Variant:
	return _record("hero_power", "HeroPowerDef", id)


## The frozen BossDef `id`, or `null` as for [method card]. Example: `db.boss("boss_rot_warden").band`.
func boss(id: String) -> Variant:
	return _record("boss", "BossDef", id)


## The frozen TreasureDef `id`, or `null` as for [method card]. Example: `db.treasure("treasure_t01").rarity`.
func treasure(id: String) -> Variant:
	return _record("treasure", "TreasureDef", id)


## The frozen BundleDef `id`, or `null` as for [method card]. Example: `db.bundle("bundle_war_weapons").cards`.
func bundle(id: String) -> Variant:
	return _record("bundle", "BundleDef", id)


## CardDefs of `set_id`, tokens included, id-ascending, as a read-only Array.
## Example: `db.cards_by_set("decay")`.
func cards_by_set(set_id: String) -> Array:
	return _filter("cards_by_set", "CardDef", func(r: Dictionary) -> bool: return r["set"] == set_id)


## CardDefs of `type` (`minion | spell | weapon`), tokens included,
## id-ascending, read-only. Example: `db.cards_by_type("weapon")`.
func cards_by_type(type: String) -> Array:
	return _filter("cards_by_type", "CardDef", func(r: Dictionary) -> bool: return r["type"] == type)


## CardDefs carrying `tag`, tokens included, id-ascending, read-only.
## Example: `db.cards_by_tag("weapons")`.
func cards_by_tag(tag: String) -> Array:
	return _filter("cards_by_tag", "CardDef", func(r: Dictionary) -> bool: return Array(r["tags"]).has(tag))


## CardDefs costing `cost`, tokens included, id-ascending, read-only.
## Example: `db.cards_by_cost(2)`.
func cards_by_cost(cost: int) -> Array:
	return _filter("cards_by_cost", "CardDef", func(r: Dictionary) -> bool: return int(r["cost"]) == cost)


## CardDefs of `rarity`, tokens included, id-ascending, read-only.
## Example: `db.cards_by_rarity("legendary")`.
func cards_by_rarity(rarity: String) -> Array:
	return _filter("cards_by_rarity", "CardDef", func(r: Dictionary) -> bool: return r["rarity"] == rarity)


## CR-6: CardDefs with `set ∈ {hero_set, neutral}` and `token == false`
## (never `boss`; `DataLoader.in_collectible_pool`), id-ascending, read-only —
## precomputed at freeze for every CR-3 set. Example: `db.collectible_pool("war")`.
func collectible_pool(hero_set: String) -> Array:
	return _pool("collectible_pool", "collectible", hero_set, "CardDef",
		func(r: Dictionary) -> bool: return DataLoader.in_collectible_pool(r, hero_set))


## CR-6: BundleDefs with `set ∈ {hero_set, neutral}`, id-ascending, read-only,
## precomputed at freeze. Example: `db.bundle_pool("war")`.
func bundle_pool(hero_set: String) -> Array:
	return _pool("bundle_pool", "bundle", hero_set, "BundleDef",
		func(r: Dictionary) -> bool: return DataLoader.in_bundle_pool(r, hero_set))


## CR-6: every TreasureDef, id-ascending, read-only. Example: `db.treasure_pool().size()`.
func treasure_pool() -> Array:
	return _pool("treasure_pool", "all", "TreasureDef", "TreasureDef", Callable())


## CR-6: BossDefs of `band`, id-ascending (DD-R02 pool), read-only,
## precomputed at freeze for every band. Example: `db.bosses_in_band(1)`.
func bosses_in_band(band: int) -> Array:
	return _pool("bosses_in_band", "bosses_in_band", band, "BossDef",
		func(r: Dictionary) -> bool: return int(r["band"]) == band)


## CR-6: every HeroDef, locked included, id-ascending, read-only. Example: `db.heroes()`.
func heroes() -> Array:
	return _pool("heroes", "all", "HeroDef", "HeroDef", Callable())


## The frozen `config` body of `<config_name>.json` in `Ready` (the same
## Dictionary on every call: read it once at the owner's construction and keep
## it); `null` and a logged error for an unknown name or before `Ready`
## (during stage 7 the guard also asserts in a debug build — config bodies
## reach validators as the 7b `configs` argument instead).
## Example: `db.config("match_rules").board_size`.
func config(config_name: String) -> Variant:
	if _state != State.READY:
		_illegal_before_ready("config")
		return null
	var body: Variant = _snapshot.config_bodies.get(config_name)
	if body == null:
		push_error("CardDatabase.config(): no config file \"%s.json\"" % config_name)
	return body


## The CR-9 fingerprint in `Ready`: 16 lowercase hex characters, the same for
## the same files on every machine and changed by any edit (computed at freeze,
## `DataLoader.fingerprint`); `""`, one logged error (`E_NOT_LOADED`, or the
## stage-7 guard) and a debug-build assert in any other state.
## Example: `RngService.new(run_seed, db.data_version())`.
func data_version() -> String:
	if _state != State.READY:
		_illegal_before_ready("data_version")
		return ""
	return _snapshot.data_version


## Loader-only: opens the stage-7 lookups over `staging` (`LoadResult.staging`
## shape). Called by `DataLoader.run` before 7a.
func _begin_stage7(staging: Dictionary) -> void:
	_stage7_staging = staging
	_stage7_lookups_open = true


## Loader-only: closes the stage-7 lookups. Called by `DataLoader.run` after 7b.
func _end_stage7() -> void:
	_stage7_lookups_open = false
	_stage7_staging = {}


## The one lookup source: the stage-7 staging while open (ADR-0002 Decision
## 4 — the exception ends at `Ready`), the frozen snapshot in `Ready`;
## otherwise `{}` and [method _not_loaded] naming `caller`. Both carry
## `records_by_type` and `index_of`; only the snapshot carries `pools`.
func _source(caller: String) -> Dictionary:
	if _stage7_lookups_open:
		return _stage7_staging
	if _state == State.READY:
		return _snapshot
	_not_loaded(caller)
	return {}


## Formulas "Lookup": `records[index_of[id]]`, O(1), no allocation; `null`
## and [method _unknown_record] when `id` is not a `record_type`.
func _record(caller: String, record_type: String, id: String) -> Variant:
	var source: Dictionary = _source(caller)
	if source.is_empty():
		return null
	var at: Variant = source.index_of.get(id)
	if at == null or at.type != record_type:
		_unknown_record("CardDatabase.%s(): no %s \"%s\"" % [caller, record_type, id])
		return null
	return source.records_by_type[record_type][at.position]


## A pool precomputed at freeze, `source.pools[pool_name][key]`, when the
## source has it; otherwise (stage 7, or a key not precomputed such as a band
## outside the BossDef range) the filter over `record_type`.
func _pool(caller: String, pool_name: String, key: Variant, record_type: String, keep: Callable) -> Array:
	var source: Dictionary = _source(caller)
	if source.is_empty():
		return []
	var precomputed: Variant = Dictionary(source.get("pools", {})).get(pool_name, {}).get(key)
	if precomputed != null:
		return precomputed
	return _filter_source(source, record_type, keep)


func _filter(caller: String, record_type: String, keep: Callable) -> Array:
	var source: Dictionary = _source(caller)
	if source.is_empty():
		return []
	return _filter_source(source, record_type, keep)


## A new read-only Array of the `record_type` records `keep` accepts (all of
## them when `keep` is not valid), in the source's id order.
func _filter_source(source: Dictionary, record_type: String, keep: Callable) -> Array:
	var records: Array = source.records_by_type[record_type]
	var out: Array = records.duplicate() if not keep.is_valid() else records.filter(keep)
	out.make_read_only()
	return out


## An unknown id (CR-6): one logged error; in `Ready` a debug build also
## asserts (the database asserts; a caller that may ask for an absent id
## checks `has(id)` first). During stage 7 the id is data under validation, so
## it is logged only (never assert on data).
func _unknown_record(message: String) -> void:
	_report_caller_bug(message, _state == State.READY and not _stage7_lookups_open)


## Caller-bug report for `config()` / `data_version()` before `Ready`: the
## stage-7 guard message while `_stage7_lookups_open`, else [method _not_loaded].
## Either way one logged error and, in a debug build, an assert.
func _illegal_before_ready(caller: String) -> void:
	if _stage7_lookups_open:
		_report_caller_bug(STAGE7_GUARD_MESSAGE % caller, true)
		return
	_not_loaded(caller)


## `E_NOT_LOADED` (States table): a query, `config()`, `data_version()` or
## `snapshot_handle()` outside `Ready` (and outside the stage-7 window).
func _not_loaded(caller: String) -> void:
	_report_caller_bug(NOT_LOADED_MESSAGE % [caller, State.keys()[_state]], true)


## One `push_error(message)`, then — when `assert_in_debug` and this is a
## debug build (`_debug_build`) — `assert(false, message)`. The assert sits
## after the log and aborts only this function, so the caller still returns
## its release-safe fallback (`null` / empty / `""`); a release build never
## asserts (and compiles `assert` out anyway).
func _report_caller_bug(message: String, assert_in_debug: bool) -> void:
	push_error(message)
	if assert_in_debug and _debug_build:
		assert(false, message)
