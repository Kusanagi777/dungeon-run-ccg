## Runs the `migrate_v{k}_to_v{k+1}` chain over a loaded profile (M4.4; ADR-0004
## Decision 7). Each step is a pure `Dictionary -> Dictionary` function with no
## I/O and sets `schema_version` itself; a shipped step lives in
## `src/core/save/migrations/profile_v{k}_to_v{k+1}.gd` and is listed in
## [method shipped_steps]. Schema 1 has none.
##
## [codeblock]
## var chain := ProfileMigrations.new({1: my_step}, 2)
## var migrated: Variant = chain.migrate(profile)   # null: no path to the target
## [/codeblock]
class_name ProfileMigrations
extends RefCounted

## Run Structure's record version the archive is read against (R1, registry
## constant): a `run_log[]` entry above it is kept opaque (M4.4). v1 has no
## record migrations, so no step runs on `active_run` or `run_log[]` yet.
const RUN_RECORD_SCHEMA_VERSION: int = 1

var _steps: Dictionary
var _target: int


## [param steps] maps a from-version to its step Callable; [param target] is the
## schema this build writes. Tests inject both (AC-8).
func _init(steps: Dictionary, target: int) -> void:
	_steps = steps
	_target = target


## The steps this build ships, by from-version.
static func shipped_steps() -> Dictionary:
	return {}


## The schema version this chain ends on.
func target() -> int:
	return _target


## [param profile] at the target version, or `null` when a step is missing or
## did not advance `schema_version`. A profile already at the target is returned
## as it is.
func migrate(profile: Dictionary) -> Variant:
	var current: Dictionary = profile
	var version: int = int(current.get("schema_version", 0))
	while version < _target:
		if not _steps.has(version):
			return null
		current = (_steps[version] as Callable).call(current)
		if int(current.get("schema_version", 0)) != version + 1:
			return null
		version += 1
	return current
