## The Run Structure and Reward Draft vocabulary: rejection codes, event types and
## `run_warning` codes (design/gdd/run-structure.md R5, R8, R10, Transition table;
## design/gdd/reward-draft.md D8, D11).
##
## Commands return `Error` (architecture.md §Feature), so each rejection is a named
## alias of one engine constant, as `MetaApi` does for its `E_IO`; compare against
## these names, never a number, and show [method code_name] to a person.
## [codeblock]
## if run.draft_pick(&"bundle", id) == RunCodes.E_NOT_OFFERED:
##     show(RunCodes.code_name(RunCodes.E_NOT_OFFERED))
## RunCodes.warn(run_log, RunCodes.W_SAVE_FAILED, {"floor": 2})
## [/codeblock]
class_name RunCodes
extends RefCounted

## The trigger is not in the transition table for this state.
const E_BAD_PHASE: Error = ERR_UNAVAILABLE
## `new_run` with a hero Meta reports locked (R2).
const E_HERO_LOCKED: Error = ERR_UNAUTHORIZED
## The run layout cannot be played (Edge Cases "Configuration and content").
const E_CONFIG: Error = ERR_UNCONFIGURED
## `draft_pick` of a kind other than `reward_step` (R5.3).
const E_DRAFT_KIND: Error = ERR_INVALID_PARAMETER
## `draft_pick` of an id the offer does not hold (R5.3).
const E_NOT_OFFERED: Error = ERR_DOES_NOT_EXIST
## A `draft_pick` for a `(floor, kind)` already in `drafts[]` (R8.5).
const E_DRAFT_DONE: Error = ERR_ALREADY_EXISTS
## An id does not resolve in Card Database (R8.1).
const E_UNKNOWN_ID: Error = ERR_FILE_MISSING_DEPENDENCIES
## `resume` with no active run in the slot.
const E_NO_SAVE: Error = ERR_FILE_NOT_FOUND
## `RunRecord.validate`: wrong `schema_version`, or a field missing or of the wrong type.
const E_SCHEMA: Error = ERR_FILE_UNRECOGNIZED
## `RunRecord.validate`: the record was written against other data.
const E_DATA_VERSION: Error = ERR_INVALID_DATA
## `RunRecord.validate`: an R1 invariant does not hold.
const E_CORRUPT: Error = ERR_FILE_CORRUPT

## Run-scope event types (R10; reward-draft D11).
const EVENT_RUN_STARTED: StringName = &"run_started"
const EVENT_FLOOR_ENTERED: StringName = &"run_floor_entered"
const EVENT_RUN_RESUMED: StringName = &"run_resumed"
const EVENT_MATCH_FAULTED: StringName = &"match_faulted"
const EVENT_MATCH_SUMMARY: StringName = &"match_summary"
const EVENT_TREASURE_GRANTED: StringName = &"treasure_granted"
const EVENT_DECK_GREW: StringName = &"deck_grew"
const EVENT_RUN_SAVED: StringName = &"run_saved"
const EVENT_RUN_ENDED: StringName = &"run_ended"
const EVENT_RUN_WARNING: StringName = &"run_warning"
const EVENT_DRAFT_OFFERED: StringName = &"draft_offered"
const EVENT_DRAFT_PICKED: StringName = &"draft_picked"

## `run_warning.code` values raised by the run.
const W_BOSS_POOL_SHORT: String = "boss_pool_short"
const W_THEME_ADJACENT: String = "theme_adjacent"
const W_SEED_IGNORED: String = "seed_ignored"
const W_TURN_CAP: String = "turn_cap"
const W_SAVE_FAILED: String = "save_failed"
const W_RECORD_TRUNCATED: String = "record_truncated"
const W_COERCED_STATUS: String = "coerced_status"
const W_HERO_LOCKED_AT_RESUME: String = "hero_locked_at_resume"
const W_ENGINE_VERSION_CHANGED: String = "engine_version_changed"
## `run_warning.code` values raised by Reward Draft (D8, D11, Edge Cases).
const W_BUNDLE_POOL_SHORT: String = "bundle_pool_short"
const W_TREASURE_POOL_SHORT: String = "treasure_pool_short"
const W_DRAFT_STATE_INIT_LATE: String = "draft_state_init_late"
const W_BUNDLE_INVALID: String = "bundle_invalid"
const W_DRAFT_FAULT: String = "draft_fault"

## The rule 12a marker: a `run_warning` records no mutation (rng-event-log catalogue).
const DIAGNOSTIC_KEY: String = "diagnostic"


## The name a rejection is documented under, for the UI's rejection toast.
## [param code] outside this vocabulary gives `&"E_UNKNOWN"`.
static func code_name(code: Error) -> StringName:
	match code:
		OK:
			return &"OK"
		E_BAD_PHASE:
			return &"E_BAD_PHASE"
		E_HERO_LOCKED:
			return &"E_HERO_LOCKED"
		E_CONFIG:
			return &"E_CONFIG"
		E_DRAFT_KIND:
			return &"E_DRAFT_KIND"
		E_NOT_OFFERED:
			return &"E_NOT_OFFERED"
		E_DRAFT_DONE:
			return &"E_DRAFT_DONE"
		E_UNKNOWN_ID:
			return &"E_UNKNOWN_ID"
		E_NO_SAVE:
			return &"E_NO_SAVE"
		E_SCHEMA:
			return &"E_SCHEMA"
		E_DATA_VERSION:
			return &"E_DATA_VERSION"
		E_CORRUPT:
			return &"E_CORRUPT"
	return &"E_UNKNOWN"


## Appends `run_warning{code, detail{}, diagnostic: true}` (R10) to [param log].
## A null or sealed log takes nothing: the warning has nowhere to go, and is not worth
## a fault. [param detail] holds only JSON values.
static func warn(log: EventLog, code: String, detail: Dictionary = {}) -> void:
	if log == null or log.is_sealed():
		return
	@warning_ignore("return_value_discarded")
	log.append(EVENT_RUN_WARNING, {"code": code, "detail": detail, DIAGNOSTIC_KEY: true})
