## The save error vocabulary, mapped once (ADR-0004 Key Interfaces; control
## manifest, Foundation): callers compare these constants, never a literal.
##
## [codeblock]
## if meta.save_active_run(record) != OK:
##     pass   # SaveErrors.E_IO or SaveErrors.E_READONLY
## [/codeblock]
class_name SaveErrors
extends RefCounted

## A write failed after its retry; the previous files are intact (M4.1).
const E_IO: Error = ERR_CANT_CREATE
## The profile is `ReadOnly`: the change stays in memory only (M5.2, M6).
const E_READONLY: Error = ERR_LOCKED
## A setting key or value outside M9 (M1.3).
const E_RANGE: Error = ERR_PARAMETER_RANGE_ERROR

## The `load_profile` statuses (M1.3).
const STATUS_OK: StringName = &"OK"
const STATUS_RECOVERED_BAK: StringName = &"RECOVERED_BAK"
const STATUS_FRESH: StringName = &"FRESH"
const STATUS_FRESH_AFTER_CORRUPT: StringName = &"FRESH_AFTER_CORRUPT"
const STATUS_SCHEMA_NEWER: StringName = &"E_SCHEMA_NEWER"
const STATUS_LOCKED: StringName = &"E_LOCKED"
