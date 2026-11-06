## The real Run UI composition for the `run_ui` suites: a `RunShell` over a real
## `RunMachine`, `RewardDraft` and the shipped data, built the way `Boot.run_machine`
## builds them but with an immediate planner, so a match needs no worker thread.
## `Boot` itself is never booted: `boot_composition_test` relies on that.
##
## Input goes through `Viewport.push_input`, so a key reaches the shell the way a player's
## does: `_input`, the GUI, then `_unhandled_input`.
## [codeblock]
## var rig: RunUiRig = await RunUiRig.start(self)
## rig.intent(&"new_run_requested")
## await rig.key(KEY_ENTER)
## assert_str(String(rig.shell.screen())).is_equal("hero_select")
## [/codeblock]
class_name RunUiRig
extends RefCounted

const SHELL_SCENE: PackedScene = preload("res://src/ui/run/run_shell.tscn")
## Where a real `MetaFacade`'s files go: removed by [method wipe_profiles].
const PROFILE_ROOT: String = "user://run_ui_rig/"
## Frames [method settle] gives a deferred skip and a transition.
const SETTLE_FRAMES: int = 4
## Frames a scripted match may take.
const MATCH_FRAMES: int = 3000
const INSTANT: Dictionary = {"anim_speed": "instant"}
## What [SfxLog] records for `stop_music`.
const STOP_MUSIC: StringName = &"stop_music"


## Records every event instead of looking up a file.
class SfxLog:
	extends SfxPlayer

	var events: Array[StringName] = []

	func play(event: StringName) -> void:
		events.append(event)

	func play_music(event: StringName) -> void:
		events.append(event)

	func stop_music() -> void:
		events.append(STOP_MUSIC)


## A `MetaStub` with what a test needs to set: the load status, ReadOnly, a run log, the
## notification queue and a lock on some heroes.
class FakeMeta:
	extends MetaStub

	var status: StringName = &"FRESH"
	var read_only: bool = false
	## What `load_profile` makes [member read_only]: a Retry that got the lock.
	var read_only_after_load: bool = false
	var loads: int = 0
	## Oldest first, as `ProfileStore` keeps it.
	var log_rows: Array = []
	var notes: Array = []
	var locked: Array = []
	var stats: Dictionary = {}

	func load_status() -> StringName:
		return status

	func is_read_only() -> bool:
		return read_only

	func load_profile() -> Dictionary:
		loads += 1
		read_only = read_only_after_load
		return super.load_profile()

	func run_log(offset: int, limit: int) -> Array:
		return log_rows.slice(offset, offset + limit)

	func run_log_count() -> int:
		return log_rows.size()

	func pending_notifications() -> Array:
		return notes.duplicate(true)

	func ack_notification(key: String) -> void:
		super.ack_notification(key)
		notes = notes.filter(func(note: Dictionary) -> bool: return note.key != key)

	func is_hero_unlocked(hero_id: String) -> bool:
		return not locked.has(hero_id) and super.is_hero_unlocked(hero_id)

	func get_stats() -> Dictionary:
		return stats

	## How often [param method] was called.
	func count(method: String) -> int:
		return calls.filter(func(row: Dictionary) -> bool: return row.method == method).size()


static var _db: CardDatabase = null
static var _input_saved: Dictionary = {}

var host: Node = null
var db: CardDatabase = null
var meta: MetaApi = null
var run: RunMachine = null
var shell: RunShell = null
var controller: RunController = null
var sfx: SfxLog = null
## `[name, reason]` per `ui_intent_rejected`.
var rejected: Array = []
## `[kind, payload]` per toast the controller raised.
var toasts: Array = []
## Every base screen the controller opened after the first, in order, and how.
var screens: Array[StringName] = []
var kinds: Array[StringName] = []
## Boss health for every match, 0 for the real one.
var boss_health: int = 0
var bindings: InputBindings = null
var _bus_volumes: Dictionary = {}
# Every run this rig started: their archived logs go in [method finish].
var _run_ids: Array[String] = []


## The shipped data, loaded once with the real validators and shared read-only.
static func database() -> CardDatabase:
	if _db == null:
		_db = CardDatabase.new()
		var _report: ValidationReport = _db.load(Boot._collect_validators(null))
	return _db


## The `config("run_ui")` body.
static func config() -> Dictionary:
	return database().config("run_ui")


## A `MetaFacade` over [param folder] under [constant PROFILE_ROOT], its profile loaded:
## real unlocks, stats, run log and a real lock, on files [method wipe_profiles] removes.
static func facade(folder: String, clock: Callable = Time.get_unix_time_from_system) -> MetaFacade:
	var body: Dictionary = database().config("profile_defaults")
	var knobs: Dictionary = body[ProfileStore.KNOBS_KEY]
	var root: String = PROFILE_ROOT.path_join(folder) + "/"
	var _made: Error = DirAccess.make_dir_recursive_absolute(root)
	var lock: ProfileLock = ProfileLock.new(root + "profile.lock", int(knobs.lock_stale_s))
	var store: ProfileStore = ProfileStore.new(ProfileStore.settings_defaults(body), knobs, AtomicFileWriter.new(), lock, clock, root)
	var abandon_is_loss: bool = (database().config("run_structure") as Dictionary).get("abandon_counts_as_loss", true)
	var meta_api: MetaFacade = MetaFacade.new(store, UnlockEvaluator.new(database(), knobs), StatsFold.new(abandon_is_loss))
	var _loaded: Dictionary = meta_api.load_profile()
	return meta_api


## Deletes everything under [constant PROFILE_ROOT].
static func wipe_profiles() -> void:
	wipe(PROFILE_ROOT)


## Deletes the folder [param path] and all it holds.
static func wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for folder: String in DirAccess.get_directories_at(path):
		wipe(path.path_join(folder))
	for file: String in DirAccess.get_files_at(path):
		var _gone: Error = DirAccess.remove_absolute(path.path_join(file))
	var _removed: Error = DirAccess.remove_absolute(path)


## Adds the Run UI actions, first keeping the map as it was. [method restore_input] puts
## it back, so no suite leaves the global `InputMap` changed.
static func install_input() -> void:
	_input_saved.clear()
	for action: StringName in InputMap.get_actions():
		_input_saved[action] = InputMap.action_get_events(action)
	RunInput.install()


## Undoes [method install_input] and anything a rebind did since. Also puts `Boot` back:
## a real `MatchView` boots it for itself, and `boot_composition_test` needs it unbooted.
static func restore_input() -> void:
	_unboot()
	for action: StringName in InputMap.get_actions():
		if not _input_saved.has(action):
			InputMap.erase_action(action)
	for action: StringName in _input_saved:
		InputMap.action_erase_events(action)
		for event: InputEvent in _input_saved[action]:
			InputMap.action_add_event(action, event)


# Releases what `Boot.boot()` took, so the autoload reads as never booted.
static func _unboot() -> void:
	var boot: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Boot")
	if not boot.booted:
		return
	boot._release_profile()
	for child: Node in boot.get_children():
		child.free()
	boot._result = null
	boot._services = null
	boot._planner_tasks = null
	boot._debounce_timer = null
	boot._input_bindings = null


## A rig with the shell in the tree on `main_menu`. [param settings] go to the record
## first, so the shell starts with them; a null [param meta_api] is a [FakeMeta].
static func start(suite: Node, meta_api: MetaApi = null, settings: Dictionary = INSTANT) -> RunUiRig:
	var rig: RunUiRig = RunUiRig.new()
	await rig._start(suite, meta_api, settings)
	return rig


func _start(suite: Node, meta_api: MetaApi, settings: Dictionary) -> void:
	host = suite
	db = database()
	meta = meta_api if meta_api != null else FakeMeta.new(db)
	for key_name: String in settings:
		var _set: Error = meta.set_setting(StringName(key_name), settings[key_name])
	for bus: String in RunShell.BUS_VOLUME.values():
		_bus_volumes[bus] = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
	run = machine()
	var services: Services = Services.new()
	services.card_database = db
	services.meta = meta
	services.settings_bus = meta.settings_bus
	bindings = InputBindings.new()
	meta.settings_bus.settings_changed.connect(_on_setting_changed)
	shell = SHELL_SCENE.instantiate()
	shell.bind(services, run)
	sfx = SfxLog.new()
	shell.sfx_player = sfx
	host.add_child(shell)
	controller = shell.controller()
	controller.screen_requested.connect(func(id: StringName, _model: Dictionary, kind: StringName) -> void:
		screens.append(id)
		kinds.append(kind))
	controller.ui_intent_rejected.connect(func(name: StringName, reason: StringName) -> void: rejected.append([name, reason]))
	controller.toast.connect(func(kind: StringName, payload: Dictionary) -> void: toasts.append([kind, payload]))
	await settle()


# What `Boot._start_profile_upkeep` does for a real profile.
func _on_setting_changed(key_name: StringName, value: Variant) -> void:
	if key_name == &"bindings":
		bindings.apply(value if value is Dictionary else {})


## A `RunMachine` as `Boot.run_machine` builds it, on the immediate planner.
func machine() -> RunMachine:
	var treasures: Treasures = Treasures.new(db, db.config("treasures_balance"))
	var draft: RewardDraft = RewardDraft.new(db, treasures, meta, db.config("reward_draft"))
	var run_config: Dictionary = db.config("run_structure").duplicate(true)
	run_config["max_match_events"] = EventLog.max_events_for(db.config("rng_event_log"))
	run_config["engine_version"] = Engine.get_version_info().string
	var archive: EventLogArchive = EventLogArchive.new(AtomicFileWriter.new(), true)
	var machine_made: RunMachine = RunMachine.new(db, meta, draft, treasures, run_config, _driver, archive)
	machine_made.run_log_opened.connect(func(_log: EventLog) -> void: _run_ids.append(machine_made.state.run_id))
	return machine_made


func _driver(match_config: Dictionary, clock: Callable = Time.get_ticks_usec) -> MatchDriver:
	if boss_health > 0:
		match_config.boss.health = boss_health
	var planner: Callable = func() -> PlannerTask: return ImmediatePlannerTask.new()
	return MatchDriver.new(match_config, db, meta.get_settings(), planner, clock)


## Frees the shell and undoes what the settings changed on the engine.
func finish() -> void:
	for bus: String in _bus_volumes:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), float(_bus_volumes[bus]))
	for run_id: String in _run_ids:
		wipe(EventLogArchive.LOGS_ROOT.path_join(run_id))
	if is_instance_valid(shell):
		shell.free()


## Sends [param name] to the controller.
func intent(name: StringName, args: Dictionary = {}) -> void:
	controller.intent(name, args)


## Lets a deferred skip and a transition land.
func settle(frames: int = SETTLE_FRAMES) -> void:
	for _i: int in frames:
		await host.get_tree().process_frame


## Presses and releases [param keycode], as a player would.
func key(keycode: Key, shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.shift_pressed = shift
	event.pressed = true
	await push(event)
	var up: InputEventKey = event.duplicate()
	up.pressed = false
	await push(up)


## Presses and releases gamepad [param button] on device 0.
func pad(button: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	await push(event)
	var up: InputEventJoypadButton = event.duplicate()
	up.pressed = false
	await push(up)


## Sends [param event] down the viewport's input path.
func push(event: InputEvent) -> void:
	shell.get_viewport().push_input(event)
	await host.get_tree().process_frame


## The focus owner, or null.
func focus() -> Control:
	return shell.get_viewport().gui_get_focus_owner()


## The base or overlay on top.
func top() -> Screen:
	return shell._top()


## From the menu to the boss intro of floor 1.
func to_boss(hero_id: String = "hero_war", seed_input: String = "deckdelve") -> void:
	intent(&"new_run_requested")
	await settle()
	intent(&"start_run", {"hero_id": hero_id, "seed_input": seed_input})
	await settle()


## Fight on the boss intro; returns the `MatchView`.
func begin() -> Control:
	intent(&"begin_match")
	await settle()
	return view()


## The swapped-in view, or null.
func view() -> Control:
	var live: Array = shell.get_node("%MatchHost").get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion())
	return live[0] if not live.is_empty() else null


## Plays [param match_view] with legal commands, attacks first, until it has a result.
## Set [member boss_health] to 1 first for a win.
func play_out(match_view: Control) -> void:
	var ctl: MatchController = match_view._controller
	for _i: int in MATCH_FRAMES:
		match_view.queue().skip_all()
		if match_view.view_state().result != null:
			break
		if not ctl.is_planning() and match_view.queue().is_idle():
			var legal: Array = ctl.legal_commands()
			if not legal.is_empty():
				var _result: Dictionary = ctl.submit(_best(legal))
		await host.get_tree().process_frame
	await drain(match_view)


## Runs the view's queue dry.
func drain(match_view: Control) -> void:
	for _i: int in SETTLE_FRAMES * 4:
		match_view.queue().skip_all()
		if match_view.queue().is_idle():
			return
		await host.get_tree().process_frame


func _best(legal: Array) -> Dictionary:
	var pick: Dictionary = legal[0]
	for command: Dictionary in legal:
		if str(command.type) == "attack":
			return command
		if str(command.type) != "end_turn" and str(pick.type) == "end_turn":
			pick = command
	return pick


## Wins the current floor through the real view and banner: the engine ends the match as
## a hero death would, so a deep floor does not depend on the scripted play winning it.
func win_floor() -> void:
	var match_view: Control = await begin()
	await force_win(match_view)
	await continue_banner(match_view)


## Ends the running match as a win, up to the banner.
func force_win(match_view: Control) -> void:
	var driver: MatchDriver = run._driver
	driver._engine._end_match(MatchRecords.SIDE_PLAYER, MatchRecords.REASON_HERO_DEAD)
	driver._after_engine_step()
	await drain(match_view)


## Concedes the current match through the real view and banner.
func lose_floor() -> void:
	var match_view: Control = await begin()
	var _sent: Dictionary = match_view._controller.submit(MatchRecords.concede())
	await drain(match_view)
	await continue_banner(match_view)


## Presses `Enter` on the end banner until the view hands control back.
func continue_banner(match_view: Control, limit_frames: int = 240) -> void:
	for _i: int in limit_frames:
		if not is_instance_valid(match_view) or match_view.is_queued_for_deletion():
			break
		await key(KEY_ENTER)
	await settle()


## Every `Label` text under [param node].
static func texts(node: Node) -> Array[String]:
	var found: Array[String] = []
	for label: Node in node.find_children("*", "Label", true, false):
		found.append((label as Label).text)
	return found


## The first `Button` under [param node] whose text is [param text], or null.
static func button(node: Node, text: String) -> Button:
	for found: Node in node.find_children("*", "Button", true, false):
		if (found as Button).text == text:
			return found
	return null
