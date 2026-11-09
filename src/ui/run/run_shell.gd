## The root of everything outside a match (ADR-0011 Decision 1; run-ui U1): one screen
## stack holding a base and its overlays, the toast layer, the focus ring, the fade
## layer, and the host `MatchView` is swapped into. Display only: it mirrors what
## [RunController] asks for and owns no game state.
##
## `main.gd` boots and hands over the services with [method bind] **before** adding
## the shell. Launched as a scene with nothing bound it falls back to `Boot` once in
## `_ready()`, the only `Boot` reference here beside `run_debug_loader.gd`. A `Failed`
## load has no controller and shows `data_error` (S2, TD-008).
##
## `MatchView` is loaded by path because it is Match UI's scene: it needs no class name
## here, only its documented contract (`set_match_info`, `set_controller`, the
## `match_view_finished` signal).
## [codeblock]
## var shell: RunShell = preload("res://src/ui/run/run_shell.tscn").instantiate()
## shell.bind(Boot.services(), Boot.run_machine())
## add_child(shell)
## shell.screen()   # &"main_menu" or &"data_error"
## [/codeblock]
class_name RunShell
extends Control

const MATCH_VIEW_PATH: String = "res://src/ui/match/match_view.tscn"
const SCREEN_PATH: String = "res://src/ui/run/screens/%s.tscn"
const CONFIG_NAME: String = "run_ui"
const NO_TRANSITION: StringName = &"none"
const OPTION_ACTIONS: Array[StringName] = [&"option_1", &"option_2", &"option_3"]
const FOCUS_ENTRY_ACTIONS: Array[StringName] = [&"ui_focus_next", &"ui_focus_prev", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]
const BANNER_H_PX: float = 28.0
## On a button whose press raises its own sound.
const META_SILENT: StringName = &"sfx_silent"
const SFX_HOVER: StringName = &"ui_hover"
const SFX_SELECT: StringName = &"ui_select"
const SFX_TICK: StringName = &"ui_slider_tick"
const SFX_PICK: StringName = &"ui_pick"
const SFX_UNLOCK: StringName = &"ui_unlock"
const SFX_OVERLAY: StringName = &"sfx.ui.overlay"
const SFX_BOSS_INTRO: String = "boss_intro_%d"
## The run shell's own loop (menus, map, draft); the match view plays `music.match_ambient`.
const MUSIC_AMBIENT: StringName = &"music.run_ambient"
const BUS_VOLUME: Dictionary = {"volume_master": "Master", "volume_music": "Music", "volume_sfx": "SFX"}
const SETTING_KEYS: Array[StringName] = [
	&"anim_speed", &"reduce_motion", &"text_scale", &"high_contrast_states", &"gamma", &"fullscreen",
	&"volume_master", &"volume_music", &"volume_sfx",
]

## What is showing. The controller's own when there is one.
var state: ShellState = ShellState.new()
## Set before `add_child` to raise sound through this player instead of a new one.
var sfx_player: SfxPlayer = null
## Set before a `fullscreen` change to drive this window instead of the shell's own.
var window: Window = null

var _services: Services = null
var _run: RunMachine = null
var _controller: RunController = null
## What `data_error` draws with on a `Failed` load (run-ui S2). That load has no config,
## and the broken file may be `run_ui.json` itself, so nothing here comes from disk: the
## one screen that reports bad data must not depend on good data. The theme's tokens and
## sizes, and the four strings that screen shows.
const FALLBACK_CONFIG: Dictionary = {
	"palette": {
		"state_actionable": "#F2E9D8", "bg_edge": "#141820", "table_dark": "#2B2118", "text_light": "#F2E9D8",
		"text_muted": "#B8AC96", "ink": "#1F1A14", "neutral": "#6F655A", "table_lit": "#4A3626",
		"parchment": "#E8DCC4", "text_ink": "#1F1A14", "state_danger": "#FF5A4D",
	},
	"font_px": {"hero": 88, "title": 28, "heading": 20, "body": 16, "small": 13, "muted": 14},
	"strings": {
		"error.title": "The game data failed to load",
		"error.count": "{n} problems: fix the data files and restart",
		"error.copy": "Copy report",
		"menu.quit": "Quit",
	},
}

var _config: Dictionary = {}
var _transition: Transition = null
var _base: Screen = null
var _overlays: Array[Screen] = []
## The focus owner under each overlay, restored when it closes.
var _focus_stack: Array[Control] = []
var _match_view: Control = null
var _settings: Dictionary = {}
var _banner: PanelContainer = null
## A pick's fly-to-strip is playing; the screen it decided waits in [member _held_open].
var _landing: bool = false
var _held_open: Array = []
var _sfx: SfxPlayer = null
# True while a screen is built: what it sets up is not the player acting.
var _binding: bool = false

@onready var _stack: Control = %ScreenStack
@onready var _match_host: Control = %MatchHost
@onready var _toasts: ToastLayer = %ToastLayer
@onready var _ring: FocusRing = %FocusRing
@onready var _fade: ColorRect = %TransitionLayer
@onready var _gamma: CanvasModulate = %Gamma


## Hands the shell its services and the [param run] machine. Call before `add_child`.
## Example: `shell.bind(Boot.services(), Boot.run_machine())`.
func bind(services: Services, run: RunMachine = null) -> void:
	_services = services
	_run = run


## The services bag this shell was bound to (or fell back to).
func services() -> Services:
	return _services


## The controller, or null on a `Failed` load. The debug loader drives it.
func controller() -> RunController:
	return _controller


## The base screen id: `&"main_menu"`, `&"data_error"`, ...; `&""` before `_ready()`.
func screen() -> StringName:
	return state.base


## Opens base [param id] over [param read_model], freeing the old base and every
## overlay, and runs transition [param kind] (`&"none"` for no transition).
func open_base(id: StringName, read_model: Dictionary, kind: StringName = RunUiConfig.KIND_FADE) -> void:
	if _landing:
		_held_open = [id, read_model, kind]
		return
	if _transition != null:
		_transition.skip()
	_clear_overlays()
	if _base != null:
		_stack.remove_child(_base)
		_base.queue_free()
	_base = _instance(id)
	_stack.add_child(_base)
	_stack.move_child(_base, 0)
	_binding = true
	_base.bind(read_model)
	_binding = false
	_raise_screen_sound(id, read_model)
	_update_banner()
	if kind == NO_TRANSITION or _transition == null:
		_finish_open()
		return
	state.transitioning = true
	_refresh_idle()
	_transition.run(kind)


## Pushes overlay [param id]; the screens under it take no focus and no mouse.
func push_overlay(id: StringName, read_model: Dictionary) -> void:
	var under: Screen = _top()
	if under != null:
		under.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
		under.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_focus_stack.append(get_viewport().gui_get_focus_owner())
	var overlay: Screen = _instance(id)
	_stack.add_child(overlay)
	_overlays.append(overlay)
	_binding = true
	overlay.bind(read_model)
	_focus(overlay)
	_binding = false
	_sfx.play(SFX_OVERLAY)
	_refresh_idle()


## Pops the top overlay and gives focus back to what held it.
func pop_overlay() -> void:
	if _overlays.is_empty():
		return
	var overlay: Screen = _overlays.pop_back()
	_stack.remove_child(overlay)
	overlay.queue_free()
	var under: Screen = _top()
	if under != null:
		under.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		under.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	var previous: Control = _focus_stack.pop_back()
	if is_instance_valid(previous) and previous.is_visible_in_tree():
		previous.grab_focus()
	elif under != null:
		_focus(under)
	_refresh_idle()


## Hides the run screens and shows `MatchView` over [param driver] (S10, ADR-0008). The
## toast layer stays above it.
func swap_in_match(driver: MatchDriver, info: Dictionary) -> void:
	if not ResourceLoader.exists(MATCH_VIEW_PATH):
		push_error("RunShell: %s is missing, so the match cannot be shown" % MATCH_VIEW_PATH)
		return
	var view: Control = (load(MATCH_VIEW_PATH) as PackedScene).instantiate()
	view.call(&"set_match_info", info)
	view.call(&"set_controller", MatchController.new(driver))
	Signal(view, &"match_view_finished").connect(_on_match_view_finished)
	_sfx.stop_music()
	_stack.visible = false
	_banner.visible = false
	_match_view = view
	_match_host.add_child(view)
	_refresh_idle()


## Hides the run screens and plays the archived log at [param path] over them. Nothing
## here touches the run: the viewer ends in [method _on_replay_finished], on the screen
## it started from. A log [MatchReplay] refuses changes nothing.
func swap_in_replay(path: String, hero_id: String, boss_id: String) -> void:
	var view: Control = MatchReplay.create_view(path, _services.card_database, hero_id, boss_id)
	if view == null:
		return
	Signal(view, &"match_view_finished").connect(_on_replay_finished)
	_sfx.stop_music()
	_stack.visible = false
	_banner.visible = false
	_match_view = view
	_match_host.add_child(view)
	_refresh_idle()


func _ready() -> void:
	if _services == null:
		_services = Boot.services()
		_run = Boot.run_machine() if Boot.booted and _services.meta != null else null
	var db: CardDatabase = _services.card_database if _services != null else null
	var ready_load: bool = db != null and db.state() == CardDatabase.State.READY
	_config = db.config(CONFIG_NAME) if ready_load else FALLBACK_CONFIG
	RunText.install(_config)
	_sfx = sfx_player if sfx_player != null else SfxPlayer.new()
	_sfx.name = "Sfx"
	add_child(_sfx)
	_sfx.configure(_config.get("sfx", {}))
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_moved)
	_transition = Transition.new(_fade, _config)
	_transition.finished.connect(_on_transition_finished)
	_toasts.configure(_config)
	_build_banner()
	if ready_load and _run != null and _services.meta != null:
		_start_controller(db)
		return
	_apply_theme(1.0, false)
	_ring.configure(RunUiConfig.color(_config, "state_actionable"))
	if ready_load:
		state.base = RunController.SCREEN_MENU
		open_base(state.base, {}, NO_TRANSITION)
		return
	state.base = RunController.SCREEN_DATA_ERROR
	open_base(state.base, RunReadModels.data_error(db.report() if db != null else null), NO_TRANSITION)


func _start_controller(db: CardDatabase) -> void:
	_controller = RunController.new(_run, _run.draft(), _services.meta, db, _config)
	state = _controller.state
	_controller.screen_requested.connect(open_base)
	_controller.overlay_requested.connect(push_overlay)
	_controller.overlay_closed.connect(pop_overlay)
	_controller.screen_refreshed.connect(_on_screen_refreshed)
	_controller.match_requested.connect(swap_in_match)
	_controller.replay_requested.connect(swap_in_replay)
	_controller.pick_landed.connect(_on_pick_landed)
	_controller.toast.connect(_toasts.enqueue)
	_controller.committed_changed.connect(_on_committed_changed)
	_controller.skip_requested.connect(_transition.skip)
	_controller.quit_requested.connect(_quit)
	_toasts.shown.connect(_controller.on_toast_shown)
	_toasts.shown.connect(_on_toast_shown)
	if _services.settings_bus != null:
		_services.settings_bus.settings_changed.connect(_on_setting_changed)
	_settings = _controller.settings().duplicate()
	for key: StringName in SETTING_KEYS:
		_apply_setting(key)
	_controller.start()
	_sfx.play_music(MUSIC_AMBIENT)


func _exit_tree() -> void:
	if _controller != null:
		_controller.shutdown()


func _instance(id: StringName) -> Screen:
	var scene: PackedScene = load(SCREEN_PATH % id) as PackedScene
	var node: Screen = scene.instantiate() as Screen
	node.cfg = _config
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.intent_requested.connect(_on_intent)
	node.landing_finished.connect(_end_landing)
	node.sfx_requested.connect(_on_sfx_requested)
	return node


func _on_intent(intent_name: StringName, args: Dictionary) -> void:
	if _controller != null:
		_controller.intent(intent_name, args)
	elif intent_name == &"quit_requested":
		_quit()


func _quit() -> void:
	get_tree().quit()


func _top() -> Screen:
	return _overlays[_overlays.size() - 1] if not _overlays.is_empty() else _base


func _clear_overlays() -> void:
	for overlay: Screen in _overlays:
		_stack.remove_child(overlay)
		overlay.queue_free()
	_overlays.clear()
	_focus_stack.clear()


func _focus(target: Screen) -> void:
	var control: Control = target.default_focus()
	if control != null and control.is_visible_in_tree():
		control.grab_focus()
	else:
		get_viewport().gui_release_focus()


func _finish_open() -> void:
	state.transitioning = false
	if _controller != null:
		_controller.on_screen_settled.call_deferred()
	if _base != null:
		_focus(_base)
		_base.on_revealed()
	_refresh_idle()


func _on_transition_finished() -> void:
	if state.transitioning:
		_finish_open()


func _on_screen_refreshed(id: StringName, read_model: Dictionary) -> void:
	var target: Screen = _top()
	if target != null and state.top() == id:
		target.bind(read_model)
		_focus(target)


func _on_committed_changed(on: bool) -> void:
	var target: Screen = _top()
	if target != null:
		target.set_committed(on)


func _on_match_view_finished(result: Variant) -> void:
	_match_view.queue_free()
	_match_view = null
	_stack.visible = true
	_sfx.play_music(MUSIC_AMBIENT)
	_controller.on_match_view_finished(result)
	_update_banner()


func _raise_screen_sound(id: StringName, read_model: Dictionary) -> void:
	if id == RunController.SCREEN_BOSS:
		_sfx.play(StringName(SFX_BOSS_INTRO % int(read_model.get("band", 1))))
		return
	var event: Variant = (_config.get("sfx", {}).get("screens", {}) as Dictionary).get(String(id))
	if event != null:
		_sfx.play(StringName(str(event)))


func _on_sfx_requested(event: StringName) -> void:
	if not _binding:
		_sfx.play(event)


func _on_toast_shown(kind: StringName, _key: String) -> void:
	if kind == &"unlock":
		_sfx.play(SFX_UNLOCK)


# One place wires every control's sound, so a screen stays free of audio.
func _on_node_added(node: Node) -> void:
	if not _stack.is_ancestor_of(node):
		return
	if node is BaseButton:
		var button: BaseButton = node
		if not button.has_meta(META_SILENT):
			button.pressed.connect(_on_sfx_requested.bind(SFX_SELECT))
		button.mouse_entered.connect(_on_sfx_requested.bind(SFX_HOVER))
	elif node is Slider:
		(node as Slider).value_changed.connect(func(_value: float) -> void: _on_sfx_requested(SFX_TICK))
	elif node is OptionPanel:
		(node as Control).mouse_entered.connect(_on_sfx_requested.bind(SFX_HOVER))


func _on_focus_moved(_control: Control) -> void:
	if not _match_showing():
		_on_sfx_requested(SFX_HOVER)


func _on_pick_landed(index: int, deck_size: int) -> void:
	_sfx.play(SFX_PICK)
	var speed: String = str(_settings.get("anim_speed", RunUiConfig.SPEED_NORMAL))
	var reduce: bool = bool(_settings.get("reduce_motion", false))
	var ms: int = RunUiConfig.t_transition(_config, RunUiConfig.KIND_FLY_TO_STRIP, speed, reduce)
	if ms > 0 and _base != null:
		_landing = _base.play_landing(index, deck_size, ms / RunUiConfig.MS_PER_S, reduce)


func _end_landing() -> void:
	if not _landing:
		return
	_landing = false
	_base.finish_landing()
	if not _held_open.is_empty():
		var held: Array = _held_open
		_held_open = []
		open_base(held[0], held[1], held[2])


func _on_replay_finished(_result: Variant) -> void:
	_match_view.queue_free()
	_match_view = null
	_stack.visible = true
	_sfx.play_music(MUSIC_AMBIENT)
	_update_banner()
	if _top() != null:
		_focus(_top())
	_refresh_idle()


# A live match, or a replay over a run screen.
func _match_showing() -> bool:
	return _match_view != null or state.base == RunController.SCREEN_MATCH


## U5: a queued toast may start only here.
func _refresh_idle() -> void:
	var base: StringName = state.base
	var held: bool = _match_showing() or base == RunController.SCREEN_RUN_START or base == RunController.SCREEN_DATA_ERROR
	_toasts.set_idle(not state.transitioning and not held and state.top() != RunController.SCREEN_CONFIRM)


func _input(event: InputEvent) -> void:
	if _controller == null or _match_showing() or not _is_press(event):
		return
	if _landing:
		_end_landing()
		get_viewport().set_input_as_handled()
		return
	var at_run_start: bool = state.top() == RunController.SCREEN_RUN_START
	if state.transitioning or at_run_start:
		_controller.intent(&"skip")
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _match_showing() or _top() == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var _closed: bool = _top().close_drawer()
		return
	if event.is_action_pressed(&"ui_cancel"):
		_top().handle_cancel()
		get_viewport().set_input_as_handled()
		return
	for i: int in OPTION_ACTIONS.size():
		if InputMap.has_action(OPTION_ACTIONS[i]) and event.is_action_pressed(OPTION_ACTIONS[i]):
			_top().handle_option_key(i)
			get_viewport().set_input_as_handled()
			return
	if get_viewport().gui_get_focus_owner() == null:
		for action: StringName in FOCUS_ENTRY_ACTIONS:
			if event.is_action_pressed(action):
				var entry: Control = _top().tab_entry()
				if entry != null:
					entry.grab_focus()
					get_viewport().set_input_as_handled()
				return


func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.is_pressed() and not event.is_echo()
	return false


func _on_setting_changed(key: StringName, value: Variant) -> void:
	_settings[String(key)] = value
	_apply_setting(key)


## ADR-0011 Decision 4: the keys the shell applies. Match UI and Boss AI read their own.
func _apply_setting(key: StringName) -> void:
	var value: Variant = _settings.get(String(key))
	match key:
		&"anim_speed", &"reduce_motion":
			var speed: String = str(_settings.get("anim_speed", RunUiConfig.SPEED_NORMAL))
			var reduce: bool = bool(_settings.get("reduce_motion", false))
			_transition.set_motion(speed, reduce)
			_toasts.set_motion(speed, reduce)
		&"text_scale", &"high_contrast_states":
			var contrast: bool = bool(_settings.get("high_contrast_states", false))
			_apply_theme(float(_settings.get("text_scale", 1.0)), contrast)
			_ring.configure(RunUiConfig.color(_config, "state_actionable", contrast))
		&"gamma":
			var level: float = float(value) if value != null else 1.0
			_gamma.color = Color(level, level, level)
		&"fullscreen":
			(window if window != null else get_window()).mode = Window.MODE_FULLSCREEN if bool(value) else Window.MODE_WINDOWED
		&"volume_master", &"volume_music", &"volume_sfx":
			var bus: int = AudioServer.get_bus_index(str(BUS_VOLUME[String(key)]))
			if bus >= 0 and value != null:
				AudioServer.set_bus_volume_db(bus, linear_to_db(float(value)))


func _apply_theme(text_scale: float, high_contrast: bool) -> void:
	var theme_set: Theme = RunUiTheme.build(_config, text_scale, high_contrast)
	_stack.theme = theme_set
	_toasts.theme = theme_set
	_banner.theme = theme_set


## The shared ReadOnly strip (U2), on every base outside `match`.
func _build_banner() -> void:
	_banner = UiKit.panel(RunUiTheme.PANEL_INK)
	UiKit.place(_banner, Rect2(0, 0, float(_config.get("design_width", 1280)), BANNER_H_PX))
	_banner.visible = false
	var row: HBoxContainer = UiKit.hbox()
	row.name = "Row"
	_banner.add_child(row)
	row.add_child(UiKit.label("", RunUiTheme.LABEL_SMALL))
	var retry: Button = UiKit.button(tr("banner.retry"))
	retry.custom_minimum_size = Vector2.ZERO
	retry.pressed.connect(_on_intent.bind(&"retry_lock", {}))
	row.add_child(retry)
	add_child(_banner)
	move_child(_banner, _match_host.get_index())


func _update_banner() -> void:
	var text: String = _controller.read_only_text() if _controller != null else ""
	_banner.visible = not text.is_empty() and not _match_showing()
	var row: Node = _banner.get_node("Row")
	(row.get_child(0) as Label).text = text
	var retry: Button = row.get_child(1)
	retry.visible = state.base == RunController.SCREEN_MENU and text == tr("banner.locked")
	if retry.visible and _banner.visible:
		_chain_retry(retry)


# U3: every intent is reachable by keyboard, so Retry joins the base's `Tab` cycle.
func _chain_retry(retry: Button) -> void:
	var first: Control = _base.tab_entry()
	if first == null or first.focus_previous.is_empty():
		return
	var last: Control = first.get_node(first.focus_previous)
	last.focus_next = last.get_path_to(retry)
	retry.focus_previous = retry.get_path_to(last)
	retry.focus_next = retry.get_path_to(first)
	first.focus_previous = first.get_path_to(retry)
