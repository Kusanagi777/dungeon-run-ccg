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
## step 2; ADR-0002 Decision 4): every owner that exists today. The full
## shape is `{effects, ai_profile, unlock, treasure, configs: {match_rules,
## card_effects, ai_profiles, run_structure, reward_draft, treasures_balance,
## heroes_balance, match_ui, run_ui, profile_defaults, content_budgets,
## rng_event_log}}`; each later epic adds its own line here, and a missing one
## is `E_DELEGATED` once the loader's stage 7 runs.
## TODO(card-effects): "effects": EffectValidator.validate
## TODO(boss-ai): "ai_profile": BossAI.validate_profile
## TODO(treasures): "treasure": Treasures.validate
## TODO(each config owner): its `configs` entry (control manifest: the static
## `validate_config` each owner registers here).
func _collect_validators(meta: MetaApi) -> Dictionary:
	var configs: Dictionary = {}
	return {
		"unlock": meta.validate_unlock_defs if meta != null else _validate_unlock_defs_mvp,
		"configs": configs,
	}


## The MVP unlock validator when no `meta` override is given: `MetaStub` is
## built after the load (it reads `config("profile_defaults")`), so its
## answer — no rules, `[]` (story 003) — stands in for it here.
## TODO(meta-progression): replace with the real M2.4 validator.
func _validate_unlock_defs_mvp(_defs: Array) -> Array:
	return []


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
