## The Meta Progression seam: the whole meta-progression M1.3 surface as one
## abstract base (ADR-0004 Decision 9; ADR-0011 Decision 4 and Key Interfaces;
## ADR-0001 Decision 7; design/gdd/systems-index.md §Circular Dependencies).
##
## Two implementations exist: `MetaStub` (the MVP, in memory) and `MetaFacade`
## (later: ProfileStore + UnlockEvaluator + StatsFold). Run Structure, Reward
## Draft and Run UI take a `MetaApi` as a constructor argument and code against
## this surface only — they never downcast. Only the composition root, debug
## loaders and tests name an implementation by type.
##
## Method names are the GDD's (M1.3 is authoritative over run-ui.md's proposed
## names — M1.3 "Name mapping"). Every override must end in an explicit
## `return` (Godot 4.7: an override of a typed method inherits its return type).
##
## Error vocabulary (ADR-0004): `E_RANGE` = `ERR_PARAMETER_RANGE_ERROR`,
## `E_READONLY` = `ERR_LOCKED`, `E_IO` = `ERR_CANT_CREATE`.
## TODO(meta-progression): map these once in src/core/save/save_errors.gd and
## point implementations at it; until then compare against the `Error`
## constants directly, never a numeric literal.
##
## Usage (a consumer receives an implementation; it never constructs one):
## [codeblock]
## func _init(meta: MetaApi) -> void:
##     _meta = meta
##     _meta.unlock_granted.connect(_on_unlock_granted)
## [/codeblock]
@abstract class_name MetaApi extends RefCounted

## Keeps this script alive through engine shutdown (TD-013): the engine clears it
## when its shutdown walk reaches this script, so a subclass's release cannot free
## this script mid-walk. `load()`, not the class name: naming the class here leaks
## the script at exit. Remove with the move to Godot 4.8 (godotengine/godot#117991).
static var _teardown_anchor: Script = load("res://src/gameplay/meta/meta_api.gd")


## Emitted when an unlock is granted (M3), live or retroactive (M3.5).
## `ToastLayer` and `RunController` subscribe (ADR-0011 Decisions 2–3); both
## implementations emit this same signal.
signal unlock_granted(key: String, kind: StringName, id: String, by_run_id: String, retro: bool)


## The bus every settings consumer reads (ADR-0011 Key Interfaces). The
## implementation holds or receives it and emits `settings_changed` on it after
## a successful [method set_setting]; the composition root's
## `settings_bus` service is this same object.
var settings_bus: SettingsBus


# --- Persistence subset (M1.3; the run-structure R7 contract) -----------------

## Loads the profile (M5 load order). Returns
## [code]{status: StringName, profile: Dictionary}[/code] where `status` is one
## of [code]&"OK"[/code], [code]&"RECOVERED_BAK"[/code], [code]&"FRESH"[/code],
## [code]&"FRESH_AFTER_CORRUPT"[/code], [code]&"E_SCHEMA_NEWER"[/code],
## [code]&"E_LOCKED"[/code]. (M1.3, M5)
@abstract func load_profile() -> Dictionary


## Writes the profile atomically (M4). Returns `OK`, `E_IO`
## (`ERR_CANT_CREATE`) or `E_READONLY` (`ERR_LOCKED`). (M1.3, M4)
@abstract func save_profile() -> Error


## Stores [param record] — the opaque `RunRecord.to_dict()` blob — as the
## active run and persists it. Returns `OK` or `E_IO`. (M1.3; run-structure R7)
@abstract func save_active_run(record: Dictionary) -> Error


## Returns the stored active-run Dictionary, or [code]null[/code] when there is
## none. (M1.3; run-structure R7)
@abstract func load_active_run() -> Variant


## Clears the active run and persists. (M1.3; run-structure R7, R8.1)
@abstract func clear_active_run() -> void


## Archives a finished run: stats fold (M7), run log (M8), unlock grants (M3).
## Returns [code]{ok: bool, unlocks_granted: Array}[/code] (unlock keys).
## (M1.3, M3, M7, M8)
@abstract func archive_run(record: Dictionary) -> Dictionary


# --- Unlocks (M1.3; M2–M3, M10) ----------------------------------------------

## True when the hero [param hero_id] is playable. (M1.3, M10)
@abstract func is_hero_unlocked(hero_id: String) -> bool


## True when the unlock [param key] is granted. (M1.3, M2–M3)
@abstract func is_unlocked(key: String) -> bool


## The ids of every unlocked record of [param kind] (hero, treasure, bundle).
## (M1.3, M2)
@abstract func unlocked_ids(kind: StringName) -> Array


## Every granted unlock key — the set `Treasures.pool(unlocked_keys,
## exclude_ids)` takes (treasures.md T6). (M1.3)
@abstract func unlocked_keys() -> Array


## True when [param treasure_id] may be offered: its `unlock` is null or its key
## is granted (Reward Draft `init_run`). (M1.3, M10)
@abstract func is_treasure_unlocked(treasure_id: String) -> bool


## Display read model for [param key]:
## [code]{met: bool, progress: float, parts: Array}[/code]. (M1.3, F6)
@abstract func unlock_progress(key: String) -> Dictionary


## Run UI's read model for a key, hero id or treasure id:
## [code]{text_key, progress, target}[/code]. (M1.3 "Name mapping", F6)
@abstract func unlock_hint(key_or_id: String) -> Dictionary


# --- Settings (M1.3, M9; DD-X07, DD-X10) ---------------------------------------

## Stores [param value] for the M9 setting [param key] and emits
## `settings_bus.settings_changed(key, value)` once. Returns `OK`, or `E_RANGE`
## (`ERR_PARAMETER_RANGE_ERROR`) for an unknown key or a value outside M9's
## range / enum — then nothing is stored or emitted. (M1.3, M9)
@abstract func set_setting(key: StringName, value: Variant) -> Error


## The current value of setting [param key], or [code]null[/code] for an
## unknown key. (M1.3, M9)
@abstract func get_setting(key: StringName) -> Variant


## The whole settings record (M9 key set, unknown keys preserved). Callers
## treat it as read-only. (M1.3, M9)
@abstract func get_settings() -> Dictionary


# --- Statistics and run log (M1.3; M7, M8) ------------------------------------

## The HeroStats aggregate for [param hero_id] (M7). (M1.3, M7)
@abstract func stats_for_hero(hero_id: String) -> Dictionary


## The most recently played hero id (argmax `stats.heroes[*].last_played_at`),
## or [code]null[/code] when none was played (→ War pre-selected, DD-X02).
## (M1.3, M7)
@abstract func last_hero_id() -> Variant


## Up to [param limit] archived runs starting at [param offset], newest last.
## (M1.3, M8)
@abstract func run_log(offset: int, limit: int) -> Array


## The archived run [param run_id], or [code]null[/code]. (M1.3, M8)
@abstract func run_log_entry(run_id: String) -> Variant


# --- Notifications, validation, reset (M1.3; M3.6, M2.4) -----------------------

## Pending unlock notifications `{key, kind, id, by_run_id}`, oldest first.
## (M1.3, M3.6)
@abstract func pending_notifications() -> Array


## Drains the notification for [param key]; Run UI calls it once, when the
## toast is shown. (M1.3, M3.6)
@abstract func ack_notification(key: String) -> void


## Validates unlock definitions — the validator Card Database injects at its
## CR-5 stage. Returns the error list ([code][][/code] when valid). (M1.3, M2.4)
@abstract func validate_unlock_defs(defs: Array) -> Array


## Resets the profile to defaults when [param confirm_token] is the typed
## confirmation (Run UI). Returns `OK`. (M1.3, M1.1)
@abstract func reset_profile(confirm_token: String) -> Error


# --- Load status (ADR-0004 Decision 9; ADR-0011; architecture.md §Presentation)

## The status of the last profile load: one of [code]&"OK"[/code],
## [code]&"RECOVERED_BAK"[/code], [code]&"FRESH"[/code],
## [code]&"FRESH_AFTER_CORRUPT"[/code], [code]&"E_SCHEMA_NEWER"[/code],
## [code]&"E_LOCKED"[/code].
@abstract func load_status() -> StringName
