## The one autoload and the lazy composition root (ADR-0001 Decision 4;
## ADR-0011 Decision 4; architecture.md §Dependency injection and the
## composition root, §Data Flow 5 steps 1-4).
##
## Registered in `project.godot [autoload]` as `Boot` — the only entry there
## (gate G4). `_ready()` does nothing: a headless gdUnit4 run that instantiates
## autoloads pays nothing (QQ-04). The first [method boot] call constructs the
## services and places them in a [Services] bag; later calls return the same
## result and the same bag (idempotent).
##
## `Boot` owns no game state (no match, run, deck, gold or floor), runs no
## process tick and is no service locator: it exposes [method services], never
## a per-service getter. Only `src/scenes/`, `src/ui/**/*_view.gd`,
## `src/ui/**/run_shell.gd`, `*_debug_loader.gd` and `tests/` name it (gate G3).
##
## Engine note — no `class_name`: on Godot 4.7.2 a script declaring
## `class_name Boot` that is also registered as the autoload `Boot` fails to
## parse ("Class "Boot" hides an autoload singleton", observed 2026-11-03) and
## the autoload is not instantiated. The singleton name `Boot` is the public
## handle; tests that need a fresh instance `preload` this script.
##
## [codeblock]
## var result: BootResult = Boot.boot()                      # MVP: MetaStub over the real data
## var result: BootResult = Boot.boot({"meta": stub})        # RunDebugLoader / tests
## if result.ok:
##     var services: Services = Boot.services()
## [/codeblock]
##
## Single-thread-only: call from the main thread.
extends Node

## The override keys [method boot] understands. Later epics append theirs.
const OVERRIDE_KEYS: PackedStringArray = ["meta", "card_database"]
## Config files whose owner has not shipped a stage-7a validator yet; each is
## registered with [method _pending_config_validator], which checks nothing and
## says so: one `W_VALIDATOR_PENDING` entry per file, a warning in a debug
## build and an **error in an exported one**, so a shipped load fails rather
## than passes unchecked (ADR-0002 Decision 4). Remove a name when its owner's
## `validate_config` lands; the release guardrail is that this list is empty
## (control manifest, Foundation). The owner named in each entry is the
## `DataLoader.FILE_MANIFEST` row's.
const PENDING_CONFIG_OWNERS: PackedStringArray = [
	"run_structure", "reward_draft", "treasures_balance", "heroes_balance",
	"match_ui", "run_ui", "profile_defaults",
]
## Stage-7b record validator keys whose owner has not shipped its validator;
## each is registered with [method _pending_record_validator] (one
## `W_VALIDATOR_PENDING` entry per host kind per load, same severity rule).
const PENDING_RECORD_OWNERS: PackedStringArray = ["ai_profile", "treasure"]

## False until [method boot] has run once (the QQ-04 test asserts it at suite
## start); true from then on, whatever the load's outcome. Read-only: it is
## derived from the stored result, and a write is logged and ignored.
## Example: `if not Boot.booted: Boot.boot()`.
var booted: bool = false:
	get:
		return _result != null
	set(_value):
		push_error("Boot.booted is read-only; set by boot()")

var _services: Services = null
var _result: BootResult = null

# Meta Progression epic (ADR-0004 Decisions 6/8): `Boot` gains two `Timer`
# children — the profile-lock heartbeat (`lock_heartbeat_s`) and the settings
# debounce — created and started in `boot()`, never in `_ready()`, plus a
# `NOTIFICATION_WM_CLOSE_REQUEST` / `_exit_tree` hook calling
# `profile_store.release_lock()`. They exist only once `ProfileStore` does.


## Does nothing: composition is lazy and starts at [method boot] (ADR-0001).
func _ready() -> void:
	return


## Runs initialisation steps 2-4 once (architecture.md §Data Flow 5) and
## returns the outcome:
## 1. the Card Database — the `card_database` override, or a `CardDatabase`
##    over the shipped data — loaded with [method _collect_validators] unless
##    the override arrives already loaded;
## 2. when the load ends `Ready`, the Meta seam — the `meta` override, or
##    `MetaStub.new(card_database)` (the MVP line);
## 3. the settings bus — the Meta implementation's own `settings_bus`.
## A `Failed` load constructs nothing that reads data: `ok` is false, the
## report is in the result, and `Services.meta` holds only a `meta` override.
## Override keys are [constant OVERRIDE_KEYS]; any other key, or a value of the
## wrong type (`card_database` not a `CardDatabase`, `meta` not a `MetaApi`), is
## logged (an error in debug builds) and not used. A second call re-runs nothing and
## returns the first call's result; overrides passed to it are logged and not
## used.
## [codeblock]
## var result: BootResult = Boot.boot({"card_database": db})
## result.load_status   # &"Ready" or &"Failed"
## [/codeblock]
func boot(overrides: Dictionary = {}) -> BootResult:
	if booted:
		if not overrides.is_empty():
			push_warning("Boot.boot(): already booted; overrides %s not used" % str(overrides.keys()))
		return _result
	var given: Dictionary = _checked_overrides(overrides)
	var services: Services = Services.new()

	# Step 2 — the Card Database (ADR-0002).
	# Typed assignment is safe: _checked_overrides dropped wrong-type values.
	var card_database: CardDatabase = given.get("card_database")
	if card_database == null:
		card_database = CardDatabase.new()
	var meta_override: MetaApi = given.get("meta")
	if card_database.state() == CardDatabase.State.UNLOADED:
		card_database.load(_collect_validators(meta_override))
	services.card_database = card_database
	var loaded: bool = card_database.state() == CardDatabase.State.READY

	# Step 3 — the Meta seam (ADR-0011 Decision 4).
	# TODO(meta-progression): the one-line switch — construct
	# `ProfileStore` into `services.profile_store` and `MetaFacade.new(...)`
	# here instead of `MetaStub`, reading `config("profile_defaults")` only to
	# hand it to them. `config("rng_event_log")` goes to the RNG service the
	# same way when that epic constructs it here.
	services.profile_store = null
	if meta_override != null:
		services.meta = meta_override
	elif loaded:
		services.meta = MetaStub.new(card_database)

	# Step 4 — the settings bus: the profile owner's, shared, never a second one.
	if services.meta != null:
		services.settings_bus = services.meta.settings_bus

	_services = services
	_result = BootResult.new(loaded, card_database.report(), _state_name(card_database.state()))
	return _result


## The service bag the first [method boot] built, the same instance on every
## call; `null` before [method boot]. Scene roots and debug loaders read it
## once and pass the services down by argument.
## Example: `var meta: MetaApi = Boot.services().meta`.
func services() -> Services:
	return _services


## The validators map `CardDatabase.load()` takes (architecture.md §Data Flow 5
## step 2; ADR-0002 Decision 4): `{effects, ai_profile, unlock, treasure,
## configs: {<every config file but card_database>}}`. A key missing here is
## `E_DELEGATED` → `Failed` in every build (card-database story 004), so every
## owner is registered — the real validator where its owner has shipped one,
## else a **pending** validator that reports itself (never an accept-all):
## - `effects` → [method _effects_adapter] over `EffectValidator.validate_effects`
##   (card-effects 003), the ADR-0007 stage-7b adapter with
##   `caps = configs["card_effects"]`;
## - `unlock` → the Meta seam's `validate_unlock_defs` (the `meta` override's,
##   else [method _validate_unlock_defs_mvp]), through [method _unlock_adapter];
## - `configs.card_effects` → `EffectValidator.validate_config` (card-effects
##   story 002; snake_case keys);
## - `configs.match_rules` → `RulesEngine.validate_rules_config`;
## - `configs.ai_profiles` → `BossAI.validate_profiles_config` (boss-ai 002);
## - `configs.rng_event_log` → `EventLog.validate_config` (rng-event-log 007);
## - `configs.content_budgets` → `ContentValidator.validate_config` (content 007);
## - pending: [constant PENDING_RECORD_OWNERS] through
##   [method _pending_record_validator] and [constant PENDING_CONFIG_OWNERS]
##   through [method _pending_config_validator].
## [param debug_build] picks the pending entries' severity (`warning` when
## true, `error` when false); it defaults to `OS.is_debug_build()` and is a
## parameter only so a test can build the release map. Build a fresh map per
## load: the pending record validators share a per-map "already reported" set.
## TODO(boss-ai): "ai_profile" → BossAI.validate_profile_key (7b adapter, profiles = configs["ai_profiles"])
## TODO(treasures): "treasure" → Treasures.validate_treasure_defs
## TODO(each config owner): replace its pending entry with its static `validate_config`.
func _collect_validators(meta: MetaApi, debug_build: bool = OS.is_debug_build()) -> Dictionary:
	var configs: Dictionary = {}
	for config_name: String in PENDING_CONFIG_OWNERS:
		configs[config_name] = _pending_config_validator.bind(config_name, debug_build)
	configs["card_effects"] = EffectValidator.validate_config
	configs["match_rules"] = RulesEngine.validate_rules_config
	configs["ai_profiles"] = BossAI.validate_profiles_config
	configs["rng_event_log"] = EventLog.validate_config
	configs["content_budgets"] = ContentValidator.validate_config
	var unlock_defs: Callable = meta.validate_unlock_defs if meta != null else _validate_unlock_defs_mvp
	var reported: Dictionary = {}
	var map: Dictionary = {
		"effects": _effects_adapter,
		"unlock": _unlock_adapter.bind(unlock_defs),
		"configs": configs,
	}
	for key: String in PENDING_RECORD_OWNERS:
		map[key] = _pending_record_validator.bind(key, reported, debug_build)
	return map


## The stage-7b `effects` adapter (ADR-0002 Decision 4): the `card_effects`
## body that passed stage 7a is `validate_effects`' `caps`. When that body
## failed 7a (it is then absent from [param bodies]) the effects are not
## validated against empty caps — that would skip every cap check — but get
## one explicit `E_DELEGATED` error per host instead.
static func _effects_adapter(host_kind: StringName, host_id: String, effects: Variant, db: Variant, bodies: Dictionary) -> Array:
	if not bodies.get("card_effects") is Dictionary:
		return [{"code": ValidationReport.E_DELEGATED, "host_id": host_id,
			"message": "not checked: the card_effects config failed stage 7a, so the effect caps are unknown (owner: Card Effects)"}]
	return EffectValidator.validate_effects(host_kind, host_id, effects, db, EffectValidator.stage7_caps(bodies))


## The stage-7b `unlock` adapter: one `{host_kind, host_id, unlock}` def per
## call to [param unlock_defs] (the Meta seam's `validate_unlock_defs`).
static func _unlock_adapter(host_kind: StringName, host_id: String, unlock: Variant, _db: Variant, _bodies: Dictionary, unlock_defs: Callable) -> Array:
	return unlock_defs.call([{"host_kind": host_kind, "host_id": host_id, "unlock": unlock}])


## The MVP unlock validator when no `meta` override is given: `MetaStub` is
## built after the load (it reads `config("profile_defaults")`), so its
## answer — no rules, `[]` (story 003) — stands in for it here. Receives one
## `{host_kind, host_id, unlock}` def per stage-7b call.
## TODO(meta-progression): replace with the real M2.4 validator.
static func _validate_unlock_defs_mvp(_defs: Array) -> Array:
	return []


## Pending stage-7b record validator for a [constant PENDING_RECORD_OWNERS]
## key: checks nothing, and returns one `W_VALIDATOR_PENDING` entry the first
## time it sees a host kind (tracked in [param reported], owned by the map),
## naming the owner from `DataLoader.RECORD_VALIDATORS`; `[]` afterwards.
## Severity per [method _pending_entry].
static func _pending_record_validator(host_kind: StringName, _host_id: String, _value: Variant, _db: Variant, _bodies: Dictionary, key: String, reported: Dictionary, debug_build: bool) -> Array:
	var seen: String = "%s/%s" % [key, host_kind]
	if reported.has(seen):
		return []
	reported[seen] = true
	var spec: Dictionary = DataLoader.RECORD_VALIDATORS[key]
	return [_pending_entry(debug_build, "`%s` (host kind %s) is not checked: its owner %s has not shipped the validator (%s)"
		% [key, host_kind, spec.owner, spec.validates])]


## Pending stage-7a config validator for each [constant PENDING_CONFIG_OWNERS]
## name: checks nothing, and returns one `W_VALIDATOR_PENDING` entry naming the
## owner from `DataLoader.FILE_MANIFEST`. Severity per [method _pending_entry].
static func _pending_config_validator(_body: Dictionary, _db: Variant, config_name: String, debug_build: bool) -> Array:
	var file_name: String = config_name + ".json"
	var owner_name: String = "unknown"
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		if row.name == file_name:
			owner_name = row.owner
	return [_pending_entry(debug_build, "configs.%s is not checked: its owner %s has not shipped validate_config" % [config_name, owner_name])]


## A `W_VALIDATOR_PENDING` entry: severity `warning` in a debug build, `error`
## otherwise, so an exported build with a pending validator fails its load.
static func _pending_entry(debug_build: bool, message: String) -> Dictionary:
	return {
		"severity": ValidationReport.SEVERITY_WARNING if debug_build else ValidationReport.SEVERITY_ERROR,
		"code": ValidationReport.W_VALIDATOR_PENDING,
		"host_id": null,
		"field": null,
		"message": message,
	}


## The overrides with String keys, after logging any key not in
## [constant OVERRIDE_KEYS] and any value that is not of its key's type — an
## error in debug builds, a warning otherwise; neither is used. A `null` value
## is the same as an absent key.
func _checked_overrides(overrides: Dictionary) -> Dictionary:
	var given: Dictionary = {}
	for raw_key: Variant in overrides:
		var key: String = String(raw_key)
		var value: Variant = overrides[raw_key]
		if not OVERRIDE_KEYS.has(key):
			_log_override_problem("Boot.boot(): unknown override key \"%s\" (known: %s)" % [key, ", ".join(OVERRIDE_KEYS)])
			continue
		if value == null:
			continue
		if not _is_override_type(key, value):
			_log_override_problem("Boot.boot(): override \"%s\" has the wrong type (%s); not used" % [key, type_string(typeof(value))])
			continue
		given[key] = value
	return given


## Whether `value` is the type override `key` takes.
func _is_override_type(key: String, value: Variant) -> bool:
	match key:
		"card_database":
			return value is CardDatabase
		"meta":
			return value is MetaApi
	return false


## An override problem is an error in debug builds, a warning otherwise.
func _log_override_problem(message: String) -> void:
	if OS.is_debug_build():
		push_error(message)
	else:
		push_warning(message)


func _state_name(state: CardDatabase.State) -> StringName:
	match state:
		CardDatabase.State.READY:
			return &"Ready"
		CardDatabase.State.FAILED:
			return &"Failed"
		CardDatabase.State.LOADING:
			return &"Loading"
		CardDatabase.State.RELOADING:
			return &"Reloading"
	return &"Unloaded"
