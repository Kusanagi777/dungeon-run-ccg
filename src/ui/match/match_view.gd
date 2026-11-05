## The match scene's root (ADR-0009 Decision 3; ADR-0008 Decision 8; match-ui U1). It
## owns the [MatchViewState], the [AnimationQueue] and the [InputRouter], projects
## `events_since(0)` and then subscribes, and drives `controller.tick()` and
## `queue.advance(delta)` from `_process`. It never navigates, reads no run state and
## does not know about floors beyond the text of the top bar.
##
## **Display.** The view-state runs ahead of the screen (U3.1), so every event's steps
## carry the state as of that event in `step.data.display`, and a step's `apply_final`
## shows that state on every presenter. An event with no step folds into the last
## display, or shows at once on an idle queue. After a drain the display equals the
## view-state, which [method assert_in_sync] proves in debug builds.
##
## A shell swaps it in with a controller; a debug launch reads `--fixture` itself.
## [codeblock]
## var view: MatchView = MATCH_VIEW_SCENE.instantiate()
## view.set_controller(MatchController.new(driver))
## view.match_view_finished.connect(_on_match_finished)
## add_child(view)
## [/codeblock]
class_name MatchView
extends Control

## Emitted once, after the end banner (ADR-0008 Decision 8).
signal match_view_finished(result: Dictionary)

## `load()`ed by path: a release export has no such script, so nothing may name its class.
const DEBUG_LOADER_PATH: String = "res://src/ui/match/match_debug_loader.gd"
const SPEED_INSTANT: StringName = &"instant"
const SETTING_ANIM_SPEED: StringName = &"anim_speed"
const SETTING_REDUCE_MOTION: StringName = &"reduce_motion"
const SETTING_ACTION_DELAY: StringName = &"action_delay_ms"
const SETTING_TEXT_SCALE: StringName = &"text_scale"
const SETTING_HIGH_CONTRAST: StringName = &"high_contrast_states"
const SETTING_GAMMA: StringName = &"gamma"
## The event feed's drawer, which `FeedPresenter` answers for (MUI-014).
const FEED_TOGGLE_METHOD: StringName = &"toggle"
const FEED_OPEN_METHOD: StringName = &"is_open"
const POSE_CHOICE: String = "choice"
const POSE_REJECT: String = "reject"
const POSE_FOCUS: String = "focus"
const POSE_MENU: String = "menu"
const POSE_MENU_CONCEDE: String = "concede"
const POSE_TREASURE_PREFIX: String = "treasure:"
## `focus:<n>` below this is a hand index, at or above it a token's instance id.
const HAND_SLOTS: int = 10
const EVENT_REJECTED: String = "command_rejected"
const EVENT_TURN_STARTED: String = "turn_started"
const CONFIG_NAME: String = "match_ui"
const AI_CONFIG_NAME: String = "ai_profiles"
const TOP_BAR_MARGIN_PX: int = 24
const INSPECT_GAP_PX: float = 60.0
## match-end.md §10: the one colour ramp, on its own fixed time.
const SATURATE_S: float = 0.4
const CARD_FRAME_SCENE: PackedScene = preload("res://src/ui/common/card_frame.tscn")

## Failed [method assert_in_sync] lines this match; a test reads it.
var sync_failures: int = 0
## The audio seam; a test reads its log.
var sfx: SfxStub = SfxStub.new()

var _controller: MatchController = null
var _view: MatchViewState = null
var _queue: AnimationQueue = null
var _router: InputRouter = null
var _ui: MatchUiContext = null
var _config: Dictionary = {}
var _ai_config: Dictionary = {}
var _settings: Dictionary = {}
var _boss_pacing: Dictionary = {}
var _speed: StringName = SPEED_INSTANT
var _match_info: Dictionary = {}
var _started: bool = false
var _presenters: Array[Presenter] = []
# The display the newest queued step will show.
var _last_display: Dictionary = {}
var _loader: RefCounted = null
var _launch_args: Dictionary = {}
var _turn_label: Label = null
var _floor_label: Label = null
var _end_turn: Button = null
var _end_turn_style: StyleBoxFlat = null
var _menu_button: Button = null
var _meta: MetaApi = null
var _settings_bus: SettingsBus = null
var _last_state: StringName = &""
var _inspect: CardFrame = null
var _inspected: int = -1
# The card of the drag that just submitted, until the engine has answered.
var _dropped_card: int = -1
var _display_settings: MatchDisplay = null
var _reject: RejectPresenter = null
var _tray: TreasureTray = null
var _focus: FocusPresenter = null
# The turn focus last took its default on.
var _focus_turn: int = -1
# The source of the last session, for the rejection shake and tooltip.
var _last_source: Dictionary = {}
var _last_by_pointer: bool = false
var _ended: bool = false
# True while events_since(0) is projected: nothing is shown until it has all landed.
var _loading: bool = false
var _finished: bool = false

@onready var _table: ColorRect = %Table
@onready var _player_panel: HeroPresenter = %PlayerPanel
@onready var _boss_panel: HeroPresenter = %BossPanel
@onready var _player_row: BoardPresenter = %PlayerRow
@onready var _boss_row: BoardPresenter = %BossRow
@onready var _chrome: Control = %Chrome
@onready var _hand: HandPresenter = %HandFan
@onready var _arrow: TargetingArrow = %TargetingArrow
@onready var _feed: FeedPresenter = %EventFeed
@onready var _choice: OverlayPresenter = %ChoiceOverlay
@onready var _mulligan: MulliganPresenter = %MulliganScreen
@onready var _banner: BannerPresenter = %Banner
@onready var _pause: PauseMenu = %PauseMenu


## Injects the controller and starts the match, now or at `_ready`.
func set_controller(controller: MatchController) -> void:
	_controller = controller
	if is_node_ready():
		_start()


## What the panels, the top bar and the tray name: `{floor, boss_def_id, hero_def_id,
## treasures}` from the `MatchConfig`, `treasures` being the held ids in pick order. Call
## it before [method set_controller].
func set_match_info(info: Dictionary) -> void:
	_match_info = info


## The projection this view owns; read only.
func view_state() -> MatchViewState:
	return _view


## The queue this view owns.
func queue() -> AnimationQueue:
	return _queue


## The input router this view owns.
func router() -> InputRouter:
	return _router


## U11 `select:<id>`: a click-to-select session on hand card or attacker [param id] (or
## `hero_power` for -1), the arrow on the first legal target.
func pose_select(id: int) -> void:
	_refresh_interaction()
	_router.intent(InputRouter.INTENT_SELECT, {"source": _pose_source(id), "pos": _ui.rect("viewport").get_center(), "entered_by": TargetingSession.ENTERED_POINTER, "first": true})


## U11 `drag:<id>`: an arrow session on hand card or attacker [param id] (or `hero_power`
## for -1), the pointer at screen centre.
func pose_drag(id: int) -> void:
	var centre: Vector2 = _ui.rect("viewport").get_center()
	_refresh_interaction()
	_router.intent(InputRouter.INTENT_DRAG_START, {"source": _pose_source(id), "pos": centre})


func _pose_source(id: int) -> Dictionary:
	var kind: String = InputRouter.SOURCE_ATTACKER
	if id == -1:
		kind = InputRouter.SOURCE_HERO_POWER
	elif _hand.card(id) != null:
		kind = InputRouter.SOURCE_CARD
	return {"kind": kind, "id": id}


## U11: the poses the debug loader does not name itself. False for an unknown
## [param pose]. `choice:open` needs nothing: the fixture ends in the Choice.
func apply_pose(pose: String, _value: String) -> bool:
	match pose:
		POSE_CHOICE:
			return true
		POSE_REJECT:
			_pose_reject(_value)
			return true
		POSE_FOCUS:
			_pose_focus(_value)
			return true
		POSE_MENU:
			_open_menu()
			if _value == POSE_MENU_CONCEDE:
				_pause.show_concede_confirm()
			return true
	return false


## U11 `focus:<element>`: a hand index, a token's instance id, `hero_power`, `end_turn`
## or `treasure:<n>`, with what focus opens.
func _pose_focus(element: String) -> void:
	_refresh_interaction()
	var stop: Dictionary = {}
	if element == InputRouter.SOURCE_HERO_POWER:
		stop = {"kind": InputRouter.SOURCE_HERO_POWER, "id": -1}
	elif element == InputRouter.STOP_END_TURN:
		stop = {"kind": InputRouter.STOP_END_TURN, "id": 0}
	elif element.begins_with(POSE_TREASURE_PREFIX):
		stop = {"kind": FocusPresenter.KIND_TREASURE, "id": int(element.trim_prefix(POSE_TREASURE_PREFIX))}
	elif int(element) < HAND_SLOTS and int(element) < (_view.side(&"player").hand as Array).size():
		stop = {"kind": InputRouter.SOURCE_CARD, "id": int(_view.side(&"player").hand[int(element)].instance_id)}
	elif _boss_row.has_token(int(element)):
		stop = {"kind": FocusPresenter.KIND_BOSS_TOKEN, "id": int(element)}
	else:
		stop = {"kind": InputRouter.SOURCE_ATTACKER, "id": int(element)}
	_focus.focus_stop(stop, true)


## U11 `reject:<code>`: the projected rejection of [param code], its tooltip and flash
## frozen. View-only: the engine is not called.
func _pose_reject(code: String) -> void:
	_reject.frozen = true
	_reject.set_origin(null, _ui.rect("viewport").get_center())
	_on_event({"seq": 0, "type": EVENT_REJECTED, "cause_seq": 0, "payload": {"side": MatchViewState.SIDE_PLAYER, "code": code, "command": {}, "diagnostic": true}})


## U11 `end:<reason>`: the end banner as [param reason]; a match must have ended.
func pose_end(reason: String) -> void:
	if _view.result is Dictionary:
		_banner.pose_reason(reason, _view.result)


## The Choice overlay, for tests.
func choice() -> OverlayPresenter:
	return _choice


## The mulligan screen, for tests.
func mulligan() -> MulliganPresenter:
	return _mulligan


## The hand fan, for poses and tests.
func hand() -> HandPresenter:
	return _hand


## Debug builds: every presenter's display equals the view-state (U4.6).
func assert_in_sync() -> void:
	for presenter: Presenter in _presenters:
		for line: String in presenter.sync_report():
			sync_failures += 1
			push_error("MatchView: %s out of sync: %s" % [presenter.name, line])


func _ready() -> void:
	_read_services()
	if _config.is_empty():
		return
	_build()
	if _controller == null:
		_launch_from_args()
	_start()


func _process(delta: float) -> void:
	if not _started:
		return
	_controller.tick()
	_queue.advance(delta)
	_refresh_interaction()
	_banner.tick(delta)


## A drag owns the pointer: a disabled End Turn under it must not swallow the release.
func _input(event: InputEvent) -> void:
	if _started and _router.in_session():
		_router.handle_input(event)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _started:
		return
	if _router.view_state() == InputRouter.STATE_ENDED:
		_on_ended_input(event)
		return
	if _router.view_state() == InputRouter.STATE_MENU:
		_router.handle_input(event)
		return
	if _choice.is_open() and _choice.handle_action(MatchInput.read(event), MatchInput.hand_slot(event)):
		return
	if _mulligan.is_open() and _mulligan.handle_action(MatchInput.read(event), MatchInput.hand_slot(event)):
		return
	_router.handle_input(event)
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	if _settings_bus != null and _settings_bus.settings_changed.is_connected(_on_setting_changed):
		_settings_bus.settings_changed.disconnect(_on_setting_changed)
	if _controller != null:
		_controller.shutdown()


# --- lifecycle -------------------------------------------------------------------

func _read_services() -> void:
	var booted: BootResult = Boot.boot()
	if not booted.ok:
		push_error("MatchView: the data load failed; nothing to show")
		return
	var services: Services = Boot.services()
	var db: CardDatabase = services.card_database
	_config = db.config(CONFIG_NAME)
	_ai_config = db.config(AI_CONFIG_NAME)
	_settings = services.meta.get_settings()
	_meta = services.meta
	_settings_bus = services.settings_bus
	MatchStrings.install(db, _config)
	_ui = MatchUiContext.new(_config, db)


func _build() -> void:
	_queue = AnimationQueue.new(_config, _settings)
	_speed = StringName(str(_settings.get(SETTING_ANIM_SPEED)))
	_boss_pacing = AnimationQueue.boss_pacing(_config, _ai_config, _settings)
	_view = MatchViewState.new(_config)
	_router = InputRouter.new()
	_router.name = "InputRouter"
	add_child(_router)
	_router.bind(_view, _queue)
	_router.command_requested.connect(_on_command_requested)
	_router.session_started.connect(_on_session_started)
	_router.session_moved.connect(_on_session_moved)
	_router.session_phase_changed.connect(_on_session_phase_changed)
	_router.session_ended.connect(_on_session_ended)
	_router.attackers_armed.connect(_player_row.set_attack_badges)
	_router.feed_requested.connect(_toggle_feed)
	_router.set_end_turn_arm(int(_config.end_turn_arm_ms))
	_router.set_drawer_check(_feed_drawer_open)
	_router.menu_requested.connect(_on_menu_requested)
	_settings_bus.settings_changed.connect(_on_setting_changed)
	_table.color = _ui.color("table_lit")
	_build_chrome()
	_build_inspect()
	_presenters = [_boss_panel, _player_panel, _boss_row, _player_row, _hand, _arrow, _feed, _choice, _mulligan, _banner]
	_presenters.append_array(_build_extra_presenters())
	for presenter: Presenter in _presenters:
		presenter.setup(_ui)
		presenter.bind(_view)
	_focus.configure(_hand, _player_row, _boss_row, _player_panel, _boss_panel)
	_focus.changed.connect(_on_focus_changed)
	_router.focus_step_requested.connect(_focus.move)
	_router.focus_direction_requested.connect(_focus.move_direction)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_reject.set_flash_targets({"taunts": _boss_row.flash_taunts, "mana_bar": _player_panel.flash_mana})
	_banner.continued.connect(_finish_match)
	_pause.configure(_pause_style(), _meta)
	_pause.closed.connect(_on_menu_closed)
	_pause.concede_confirmed.connect(func() -> void: _router.intent(InputRouter.INTENT_CONCEDE))
	_choice.chosen.connect(func(index: int) -> void:
		_router.intent(InputRouter.CHOICE_INTENT, {"index": index}))
	_mulligan.confirmed.connect(func(keep_mask: Array) -> void:
		_router.intent(InputRouter.INTENT_MULLIGAN_CONFIRM, {"keep_mask": keep_mask}))
	_display_settings = MatchDisplay.new(self, _ui)
	_apply_read_settings()
	_queue.step_started.connect(_on_step_started)
	_queue.skipped.connect(_on_skipped)
	_queue.drained.connect(_on_drained)


## The presenters `match_view.tscn` does not hold.
func _build_extra_presenters() -> Array[Presenter]:
	_reject = RejectPresenter.new()
	_reject.name = "RejectFeedback"
	add_child(_reject)
	_tray = TreasureTray.new()
	_tray.name = "TreasureTray"
	add_child(_tray)
	_focus = FocusPresenter.new()
	_focus.name = "Focus"
	add_child(_focus)
	return [_reject, _tray, _focus]


## The top bar and End Turn: the zones no presenter owns (hud.md §3.2).
func _build_chrome() -> void:
	var bar_rect: Rect2 = _ui.rect("top_bar")
	var bar := ColorRect.new()
	bar.color = _ui.color("bg_edge")
	bar.position = bar_rect.position
	bar.size = bar_rect.size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.add_child(bar)
	_turn_label = _bar_label(bar_rect, HORIZONTAL_ALIGNMENT_CENTER)
	_floor_label = _bar_label(bar_rect.grow_individual(-TOP_BAR_MARGIN_PX, 0, 0, 0), HORIZONTAL_ALIGNMENT_LEFT)
	var rect: Rect2 = _ui.rect("end_turn")
	_end_turn = Button.new()
	_end_turn.text = tr("hud.end_turn")
	_end_turn.position = rect.position
	_end_turn.size = rect.size
	_end_turn.focus_mode = Control.FOCUS_NONE
	_end_turn_style = _button_style()
	for state: String in ["normal", "hover", "pressed"]:
		_end_turn.add_theme_stylebox_override(state, _end_turn_style)
	_end_turn.add_theme_stylebox_override("disabled", _button_style())
	_end_turn.add_theme_color_override("font_color", _ui.color("text_light"))
	_end_turn.add_theme_color_override("font_disabled_color", _ui.color("text_muted"))
	_end_turn.pressed.connect(func() -> void: _router.intent(InputRouter.INTENT_END_TURN))
	_end_turn.disabled = true
	_chrome.add_child(_end_turn)
	_build_menu_button()


## hud.md §4.2: a 44x32 button whose hit rect is 44x44 at y 0-44.
func _build_menu_button() -> void:
	var rect: Rect2 = _ui.rect("menu_button")
	_menu_button = Button.new()
	_menu_button.text = tr("hud.menu")
	_menu_button.position = rect.position
	_menu_button.size = rect.size
	_menu_button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = _ui.color("table_dark")
	for state: String in ["normal", "hover", "pressed"]:
		_menu_button.add_theme_stylebox_override(state, style)
	_menu_button.add_theme_color_override("font_color", _ui.color("text_light"))
	_menu_button.pressed.connect(func() -> void: _router.intent(InputRouter.INTENT_MENU))
	_chrome.add_child(_menu_button)


func _pause_style() -> Dictionary:
	var cfg: Dictionary = _config.pause
	return {
		"rect": _ui.rect("pause_menu"), "fill": _ui.color("table_dark"), "text": _ui.color("text_light"),
		"ring": _ui.color("state_actionable"), "ring_px": _config.focus.ring_px,
		"ring_offset_px": _config.focus.ring_offset_px, "row_h": cfg.row_h, "gap": cfg.gap,
		"font_px": cfg.font_px, "title_px": cfg.title_px, "label_w": cfg.label_w,
	}


## A pad that drops out takes its session with it; keyboard and mouse stay live
## (targeting.md §15 "Controller disconnection").
func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected and _started and not _router.dragging():
		_router.intent(InputRouter.INTENT_CANCEL)


func _on_menu_requested() -> void:
	if _pause.is_open():
		_pause.back()
	else:
		_open_menu()


func _open_menu() -> void:
	_router.intent(InputRouter.INTENT_CANCEL)
	_router.set_menu_open(true)
	_pause.open()
	_table.color = _ui.color("table_dark")


func _on_menu_closed() -> void:
	_router.set_menu_open(false)
	_present(_last_display if not _queue.is_idle() else _display())


## The settings read once at `_ready`; a change comes through [method _on_setting_changed].
func _apply_read_settings() -> void:
	for key: StringName in [SETTING_REDUCE_MOTION, SETTING_TEXT_SCALE, SETTING_HIGH_CONTRAST, SETTING_GAMMA]:
		if _settings.has(key):
			_on_setting_changed(key, _settings[key])


func _apply_text_scale(scale: float) -> void:
	_display_settings.set_text_scale(scale)
	_player_panel.set_text_scale(scale)
	_boss_panel.set_text_scale(scale)
	var rect: Rect2 = _ui.rect("end_turn")
	var width: float = minf(rect.size.x * scale, float(_config.text_scale.end_turn_max_w))
	_end_turn.position = Vector2(rect.end.x - width, rect.position.y)
	_end_turn.size = Vector2(width, rect.size.y)


## A setting moved: applied from `settings_changed`, so on the next frame (ADR-0011).
func _on_setting_changed(key: StringName, value: Variant) -> void:
	_settings[key] = value
	if _controller != null:
		_controller.on_setting_changed(key, value)
	match key:
		SETTING_ANIM_SPEED:
			_speed = StringName(str(value))
			_queue.set_speed(_speed)
		SETTING_REDUCE_MOTION:
			_queue.set_reduce_motion(value == true)
			_reject.reduce_motion = value == true
		SETTING_ACTION_DELAY:
			_boss_pacing = AnimationQueue.boss_pacing(_config, _ai_config, _settings)
		SETTING_TEXT_SCALE:
			_apply_text_scale(float(value))
		SETTING_HIGH_CONTRAST:
			_ui.set_high_contrast(value == true)
			for presenter: Presenter in _presenters:
				presenter.restyle()
		SETTING_GAMMA:
			_display_settings.set_gamma(float(value))


func _build_inspect() -> void:
	_inspect = CARD_FRAME_SCENE.instantiate()
	add_child(_inspect)
	_inspect.configure(_ui)
	_inspect.scale = Vector2.ONE * float(_config.hand.hover_scale)
	_inspect.visible = false


func _bar_label(rect: Rect2, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", _ui.color("text_light"))
	_chrome.add_child(label)
	return label


func _button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _ui.color("table_dark")
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	style.border_color = _ui.color("table_dark")
	return style


func _launch_from_args() -> void:
	if not OS.is_debug_build() or not ResourceLoader.exists(DEBUG_LOADER_PATH):
		return
	var script: GDScript = load(DEBUG_LOADER_PATH)
	_launch_args = script.call("from_args", OS.get_cmdline_user_args())
	if str(_launch_args.fixture) == "":
		return
	_loader = script.new()
	var controller: MatchController = _loader.call("load_fixture", str(_launch_args.fixture))
	if controller == null:
		return
	set_match_info(_loader.get("match_info"))
	if str(_launch_args.anim_speed) != "":
		_speed = StringName(str(_launch_args.anim_speed))
	_controller = controller


## `Loading`: projects the log at `instant`, then subscribes (hud.md §5).
func _start() -> void:
	if _started or _controller == null or _view == null:
		return
	_started = true
	_ui.query = _controller.query()
	_ui.locate = _locate
	_router.set_controller(_controller)
	_router.set_hit_test(MatchHitTest.new(_ui, _view, _hand, _player_row, _boss_row, _player_panel, _boss_panel), float(_config.click_drag_px))
	_controller.bind_queue(_queue)
	_apply_identity()
	_queue.set_speed(SPEED_INSTANT)
	_loading = true
	for event: Dictionary in _controller.events_since(0):
		_on_event(event)
	_loading = false
	_queue.advance(0.0)
	_queue.set_speed(_speed)
	_controller.subscribe(_on_event)
	_present(_display())
	if _loader != null:
		var pose: String = str(_launch_args.pose)
		_loader.call("apply_pose", self, pose if pose != "" else str(_loader.get("fixture_pose")))


func _apply_identity() -> void:
	_player_panel.set_identity(_ui.hero_identity(str(_match_info.get("hero_def_id", ""))))
	var boss_id: String = str(_match_info.get("boss_def_id", ""))
	_boss_panel.set_identity(_ui.boss_identity(boss_id))
	_banner.set_boss(boss_id)
	_tray.set_treasures(_match_info.get("treasures", []))
	_focus.set_treasures(_tray.count(), _tray.hit_rect)
	_floor_label.text = tr("hud.floor") % [int(_match_info.get("floor", 0)), tr(MatchStrings.BOSS_NAME_KEY % boss_id)]


# --- the event path ---------------------------------------------------------------

func _on_event(event: Dictionary) -> void:
	if str(event.get("type", "")) == EVENT_TURN_STARTED:
		var side: String = str((event.get("payload", {}) as Dictionary).get("side", ""))
		if side == MatchViewState.SIDE_BOSS:
			_queue.enter_boss_turn(_boss_pacing)
		else:
			_queue.exit_boss_turn()
	var steps: Array[AnimStep] = _view.apply(event)
	if _view.result != null:
		_router.intent(InputRouter.INTENT_CANCEL)
	var display: Dictionary = _display()
	if steps.is_empty():
		if _queue.is_idle() and not _loading:
			_present(display)
		else:
			_last_display.merge(display, true)
		return
	_last_display = display
	for step: AnimStep in steps:
		step.data["display"] = display
		step.apply_final = _finish_step.bind(step)
		_queue.enqueue(step)


func _display() -> Dictionary:
	return {
		"player": _view.side(&"player"),
		"boss": _view.side(&"boss"),
		"turn": _view.turn,
		"active_side": _view.active_side,
		"phase": _view.phase,
		"pending_mulligan": _view.pending_mulligan,
		"pending_choice": _view.pending_choice,
		"result": _view.result,
	}


func _on_step_started(step: AnimStep, d_eff: float) -> void:
	for presenter: Presenter in _presenters:
		if presenter.claims(step):
			presenter.on_step_started(step, d_eff)


func _finish_step(step: AnimStep) -> void:
	for presenter: Presenter in _presenters:
		if presenter.claims(step):
			presenter.apply_final(step)
	_present(step.data.get("display", _last_display))


func _present(display: Dictionary) -> void:
	for presenter: Presenter in _presenters:
		presenter.present(display)
	var dimmed: bool = display.pending_mulligan != null or _choice.is_open() or _pause.is_open()
	_table.color = _ui.color("table_dark" if dimmed else "table_lit")
	var key: String = "hud.turn.player" if str(display.active_side) == MatchViewState.SIDE_PLAYER else "hud.turn.boss"
	_turn_label.text = tr("hud.turn.setup") if int(display.turn) == 0 else tr(key) % int(display.turn)


func _on_command_requested(command: Dictionary) -> void:
	_aim_rejection()
	var result: Dictionary = _controller.submit(command)
	if not result.accepted:
		_mulligan.on_rejected()
		_choice.on_rejected()
		if _dropped_card != -1:
			_hand.reset_card(_dropped_card)
	_dropped_card = -1


## Rejection Feedback's anchor: the cursor for the mouse, above the source for a key.
func _aim_rejection() -> void:
	var anchor: Vector2 = get_global_mouse_position()
	if not _last_by_pointer:
		anchor = _source_centre(_last_source) if not _last_source.is_empty() else _ui.rect("end_turn").get_center()
	_reject.set_origin(_origin_control(_last_source), anchor)


func _origin_control(source: Dictionary) -> Control:
	match str(source.get("kind", "")):
		InputRouter.SOURCE_CARD:
			return _hand.card(int(source.id))
		InputRouter.SOURCE_HERO_POWER:
			return _player_panel.power_control()
		InputRouter.SOURCE_ATTACKER:
			var token: MinionToken = _player_row.token(int(source.id))
			return token if token != null else _player_panel.portrait_control()
	return _end_turn


func _on_session_started(session: Dictionary) -> void:
	var source: Dictionary = session.source
	var kind: String = str(source.kind)
	var targeted: bool = session.phase == InputRouter.SESSION_TARGET
	_focus.focus_stop(source, false)
	_set_source_lifted(source, true, targeted or session.entered_by != TargetingSession.ENTERED_DRAG)
	if targeted:
		_open_target_phase(session, _source_centre(source))
	elif session.phase == InputRouter.SESSION_CAST:
		_arrow.show_cast_zone(_ui.rect("cast_zone"))
	if kind == InputRouter.SOURCE_CARD and session.phase == InputRouter.SESSION_POSITION:
		_player_row.set_gap((session.positions as Array).size() - 1)


## Phase P → T: the card parks, a ghost holds the gap and the arrow starts from it. The
## row keeps its gap; `Esc` from here cancels the whole play (targeting.md §6).
func _on_session_phase_changed(session: Dictionary) -> void:
	var ghost: Rect2 = _player_row.gap_rect_at(int(session.position))
	_hand.park()
	_arrow.show_slot(Rect2())
	_player_row.set_gap(int(session.position))
	_player_row.show_ghost(_hand_card_id(int(session.source.id)))
	session.ghost_rect = ghost
	_open_target_phase(session, ghost.get_center())


## Lights the targets and starts the arrow at [param from], with the chip above it when
## a null entry exists; the router reads the chip's rect from the session.
func _open_target_phase(session: Dictionary, from: Vector2) -> void:
	_arrow.start_from(from)
	_light_targets(session.targets, InputRouter.NO_TARGET)
	if bool(session.null_allowed):
		var cfg: Dictionary = _config.targeting
		var chip := Vector2(float(cfg.chip_w), float(cfg.chip_h))
		session.chip_rect = Rect2(Vector2(from.x - chip.x / 2.0, from.y - float(_config.board.token_h) / 2.0 - float(cfg.chip_gap_px) - chip.y), chip)
		_arrow.show_chip(session.chip_rect, false)


func _hand_card_id(instance_id: int) -> String:
	for card: Dictionary in _view.side(&"player").hand:
		if int(card.instance_id) == instance_id:
			return str(card.card_id)
	return ""


func _on_session_moved(session: Dictionary) -> void:
	var pos: Vector2 = session.pos
	if str(session.source.kind) == InputRouter.SOURCE_CARD:
		_hand.follow(pos)
	match session.phase:
		InputRouter.SESSION_TARGET:
			_arrow.snap_to(pos, bool(session.lit), _snap_seconds() if session.snap else 0.0)
			_light_targets(session.targets, int(session.hovered))
			if bool(session.null_allowed):
				_arrow.show_chip(session.chip_rect, int(session.hovered) == TargetingSession.NO_TARGET_CHIP)
		InputRouter.SESSION_POSITION:
			if int(session.gap) != InputRouter.NO_GAP:
				_player_row.set_gap(int(session.gap))
				_arrow.show_slot(_player_row.gap_rect_at(int(session.gap)))
		InputRouter.SESSION_CAST:
			_arrow.set_zone_dim(bool(session.dim_zone))


func _on_session_ended(session: Dictionary, submitted: bool) -> void:
	_last_source = session.source if submitted else {}
	_last_by_pointer = session.entered_by != TargetingSession.ENTERED_KEY
	_set_source_lifted(session.source, false, submitted)
	_arrow.stop()
	_player_row.set_gap(InputRouter.NO_GAP)
	_light_targets({}, InputRouter.NO_TARGET)
	_dropped_card = int(session.source.id) if submitted and str(session.source.kind) == InputRouter.SOURCE_CARD else -1


## §10 "Arrow snap": 0 under `reduce_motion` and at `instant`.
func _snap_seconds() -> float:
	if _speed == SPEED_INSTANT or _settings.get(SETTING_REDUCE_MOTION) == true:
		return 0.0
	return float(_config.targeting.snap_s)


## [param flag] is the parked state on pickup and the submitted state on drop.
func _set_source_lifted(source: Dictionary, on: bool, flag: bool) -> void:
	var id: int = int(source.id)
	match str(source.kind):
		InputRouter.SOURCE_CARD:
			if on:
				_hand.begin_drag(id, flag)
			else:
				_hand.end_drag(flag)
		InputRouter.SOURCE_HERO_POWER:
			_player_panel.set_power_lifted(on)
		InputRouter.SOURCE_ATTACKER:
			if _player_row.has_token(id):
				_player_row.set_lifted(id, on)
			else:
				_player_panel.set_portrait_lifted(on)


func _source_centre(source: Dictionary) -> Vector2:
	match str(source.kind):
		InputRouter.SOURCE_CARD:
			return _hand.card_centre(int(source.id))
		InputRouter.SOURCE_HERO_POWER:
			return _player_panel.power_rect().get_center()
	return _locate(int(source.id))


func _light_targets(targets: Dictionary, hovered: int) -> void:
	_player_row.set_targets(targets, hovered)
	_boss_row.set_targets(targets, hovered)
	for panel: HeroPresenter in [_player_panel, _boss_panel]:
		var hero_id: Variant = _view.side(panel.side).hero.entity_id
		panel.set_targeted(hero_id != null and targets.has(int(hero_id)), hero_id != null and int(hero_id) == hovered)


## The controls follow the view state. Legality is read on entering `Idle` only (U2).
func _refresh_interaction() -> void:
	var state: StringName = _router.view_state()
	if state == _last_state:
		return
	_last_state = state
	_end_turn.disabled = not _router.can_end_turn()
	if state == InputRouter.STATE_IDLE:
		_show_legality()
	else:
		_clear_legality()


func _show_legality() -> void:
	var legal: Array[Dictionary] = _router.player_commands()
	var playable: Dictionary = {}
	for card: Dictionary in _ui.query.hand(MatchViewState.SIDE_PLAYER):
		if card.playable:
			playable[int(card.instance_id)] = true
	_hand.set_playable(playable, true)
	_show_attackers(legal)
	var mana: int = int(_view.side(&"player").mana.available)
	_set_end_turn_lit(legal.size() <= 1 or mana == 0)
	_focus.enter_idle(_default_stop(playable), int(_view.turn) != _focus_turn)
	_focus_turn = int(_view.turn)
	_player_panel.set_power_state(_ui.query.hero_power_state(MatchViewState.SIDE_PLAYER))


## U5: End Turn when nothing is lit, else the left-most playable card.
func _default_stop(playable: Dictionary) -> Dictionary:
	for card: Dictionary in _view.side(&"player").hand:
		if playable.has(int(card.instance_id)):
			return {"kind": InputRouter.SOURCE_CARD, "id": int(card.instance_id)}
	return {"kind": InputRouter.STOP_END_TURN, "id": 0}


func _toggle_feed() -> void:
	if _feed.has_method(FEED_TOGGLE_METHOD):
		_feed.call(FEED_TOGGLE_METHOD)


func _feed_drawer_open() -> bool:
	return _feed.has_method(FEED_OPEN_METHOD) and bool(_feed.call(FEED_OPEN_METHOD))


## Can-attack outlines from the last `legal_commands()`, and the summoning-sick badge
## from the query: both are highlighting, never numbers (U2).
func _show_attackers(legal: Array[Dictionary]) -> void:
	var attackers: Dictionary = {}
	for command: Dictionary in legal:
		if str(command.type) == MatchRecords.CMD_ATTACK:
			attackers[int(command.attacker_id)] = true
	var sick: Dictionary = {}
	for token: Dictionary in _view.side(&"player").board:
		var id: int = int(token.entity_id)
		var entity: Dictionary = _ui.query.entity(id)
		if not entity.is_empty() and entity.flags.summoning_sick:
			sick[id] = true
	_player_row.set_attackers(attackers, sick)
	var hero_id: Variant = _view.side(&"player").hero.entity_id
	_player_panel.set_can_attack(hero_id != null and attackers.has(int(hero_id)))


func _clear_legality() -> void:
	_set_end_turn_lit(false)
	_hand.set_playable({}, false)
	_hand.set_hover(-1, 0.0)
	_player_row.set_attackers({}, {})
	_player_panel.set_can_attack(false)
	_focus.leave_idle()
	_show_inspect(-1)
	_player_panel.show_power_tooltip(false)
	_player_panel.set_power_state({})


## U5: the `state_actionable` outline, "nothing left to do".
func _set_end_turn_lit(on: bool) -> void:
	_end_turn_style.border_color = _ui.color("state_actionable") if on else _ui.color("table_dark")


## The screen centre of a drawn entity, or the centre of the table.
func _locate(entity_id: int) -> Vector2:
	if _player_row.has_token(entity_id):
		return _player_row.center_of(entity_id)
	if _boss_row.has_token(entity_id):
		return _boss_row.center_of(entity_id)
	if _player_panel.owns([entity_id]):
		return _player_panel.portrait_rect().get_center()
	if _boss_panel.owns([entity_id]):
		return _boss_panel.portrait_rect().get_center()
	return _ui.rect("viewport").get_center()


## Hover previews belong to `Idle` (States), and a preview never moves focus.
func _update_hover(point: Vector2) -> void:
	if _router.view_state() != InputRouter.STATE_IDLE:
		return
	var card: int = _hand.card_at(point)
	_show_info(card, _row_token_at(point) if card == -1 else -1, _player_panel.power_rect().has_point(point))


## Hover and focus open the same information, and what a key opened stays up when the
## pointer has nothing to show.
func _show_info(card: int, token: int, over_power: bool) -> void:
	var held: Dictionary = _focus.inspected()
	var kind: String = str(held.get("kind", ""))
	var held_id: int = int(held.get("id", -1))
	var held_token: bool = kind == FocusPresenter.KIND_BOSS_TOKEN or (kind == InputRouter.SOURCE_ATTACKER and _player_row.has_token(held_id))
	_hand.set_hover(card if card != -1 or kind != InputRouter.SOURCE_CARD else held_id)
	_show_inspect(token if token != -1 or not held_token else held_id)
	_player_panel.show_power_tooltip(over_power or kind == InputRouter.SOURCE_HERO_POWER)
	if kind == InputRouter.SOURCE_ATTACKER and not held_token:
		_player_panel.show_portrait_tooltip(true)
	_boss_panel.show_portrait_tooltip(kind == FocusPresenter.KIND_BOSS_PORTRAIT)
	_tray.show_tooltip(held_id if kind == FocusPresenter.KIND_TREASURE else TreasureTray.NO_CHIP)


func _on_focus_changed(stop: Dictionary) -> void:
	_router.set_focus_stop(stop)
	_show_info(-1, -1, false)


func _row_token_at(point: Vector2) -> int:
	var id: int = _player_row.token_at(point)
	return id if id != -1 else _boss_row.token_at(point)


## The 1.5x preview of a token (art bible §4), to the side of the token's row centre.
func _show_inspect(entity_id: int) -> void:
	if entity_id == _inspected:
		return
	_inspected = entity_id
	var row: BoardPresenter = _player_row if _player_row.has_token(entity_id) else _boss_row
	_inspect.visible = row.has_token(entity_id)
	if not _inspect.visible:
		return
	var card_id: String = row.card_of(entity_id)
	var face: Dictionary = _ui.card_face(card_id)
	_inspect.show_card(face, int(face.get("cost", 0)) if face.get("cost") != null else 0)
	var scale_by: float = float(_config.hand.hover_scale)
	var preview: Vector2 = CardFrame.SIZE * scale_by
	var centre: Vector2 = row.center_of(entity_id)
	var left: bool = centre.x > _ui.rect("viewport").get_center().x
	var x: float = centre.x - preview.x - INSPECT_GAP_PX if left else centre.x + INSPECT_GAP_PX
	var y: float = clampf(centre.y - preview.y / 2.0, _ui.rect("top_bar").end.y, _ui.rect("viewport").end.y - preview.y)
	_inspect.position = Vector2(x, y)


func _on_skipped() -> void:
	for presenter: Presenter in _presenters:
		presenter.on_skipped()


func _on_drained() -> void:
	_present(_display())
	_display_settings.refresh()
	for presenter: Presenter in _presenters:
		presenter.on_drained()
	if OS.is_debug_build():
		assert_in_sync()
	if _view.result != null and not _ended:
		_enter_ended()


## `Ended`: the banner settles, the winner saturates, the stinger plays. Never on a
## fault: it is not a defeat (U9).
func _enter_ended() -> void:
	_ended = true
	_pause.close()
	_menu_button.disabled = true
	_banner.settle()
	match _banner.variant():
		BannerPresenter.VARIANT_FAULT:
			pass
		BannerPresenter.VARIANT_VICTORY:
			_player_panel.saturate(SATURATE_S)
			sfx.play(SfxStub.CUE_VICTORY)
		_:
			_boss_panel.saturate(SATURATE_S)
			sfx.play(SfxStub.CUE_DEFEAT)
	_end_turn.disabled = true


## DD-X09: in `Ended` only a fresh press continues; `Esc` and everything else do nothing.
func _on_ended_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_banner.press_continue()
	elif MatchInput.read(event) in [MatchInput.CONFIRM, MatchInput.END_TURN]:
		_banner.press_continue()


func _finish_match() -> void:
	if _finished:
		return
	_finished = true
	match_view_finished.emit(_view.result)
