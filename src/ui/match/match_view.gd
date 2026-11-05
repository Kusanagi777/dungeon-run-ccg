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
const EVENT_TURN_STARTED: String = "turn_started"
const CONFIG_NAME: String = "match_ui"
const AI_CONFIG_NAME: String = "ai_profiles"
const TOP_BAR_MARGIN_PX: int = 24
const INSPECT_GAP_PX: float = 60.0
const CARD_FRAME_SCENE: PackedScene = preload("res://src/ui/common/card_frame.tscn")

## Failed [method assert_in_sync] lines this match; a test reads it.
var sync_failures: int = 0

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
var _last_state: StringName = &""
var _inspect: CardFrame = null
var _inspected: int = -1

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


## Injects the controller and starts the match, now or at `_ready`.
func set_controller(controller: MatchController) -> void:
	_controller = controller
	if is_node_ready():
		_start()


## What the panels and the top bar name: `{floor, boss_def_id, hero_def_id}` from the
## `MatchConfig`. Call it before [method set_controller].
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


func _unhandled_input(event: InputEvent) -> void:
	if not _started:
		return
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)


func _exit_tree() -> void:
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
	_table.color = _ui.color("table_lit")
	_build_chrome()
	_build_inspect()
	_presenters = [_boss_panel, _player_panel, _boss_row, _player_row, _hand, _arrow, _feed, _choice, _mulligan, _banner]
	for presenter: Presenter in _presenters:
		presenter.setup(_ui)
		presenter.bind(_view)
	_queue.step_started.connect(_on_step_started)
	_queue.skipped.connect(_on_skipped)
	_queue.drained.connect(_on_drained)


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
	_controller.bind_queue(_queue)
	_apply_identity()
	_queue.set_speed(SPEED_INSTANT)
	for event: Dictionary in _controller.events_since(0):
		_on_event(event)
	_queue.advance(0.0)
	_queue.set_speed(_speed)
	_controller.subscribe(_on_event)
	_present(_display())
	if _loader != null:
		_loader.call("apply_pose", self, str(_launch_args.pose))


func _apply_identity() -> void:
	_player_panel.set_identity(_ui.hero_identity(str(_match_info.get("hero_def_id", ""))))
	var boss_id: String = str(_match_info.get("boss_def_id", ""))
	_boss_panel.set_identity(_ui.boss_identity(boss_id))
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
	var display: Dictionary = _display()
	if steps.is_empty():
		if _queue.is_idle():
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
	var key: String = "hud.turn.player" if str(display.active_side) == MatchViewState.SIDE_PLAYER else "hud.turn.boss"
	_turn_label.text = tr("hud.turn.setup") if int(display.turn) == 0 else tr(key) % int(display.turn)


func _on_command_requested(command: Dictionary) -> void:
	_controller.submit(command)


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
	_player_panel.set_power_state(_ui.query.hero_power_state(MatchViewState.SIDE_PLAYER))


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
	_show_inspect(-1)
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
	_hand.set_hover(card)
	_show_inspect(_row_token_at(point) if card == -1 else -1)
	_player_panel.show_power_tooltip(_player_panel.power_rect().has_point(point))


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
	for presenter: Presenter in _presenters:
		presenter.on_drained()
	if OS.is_debug_build():
		assert_in_sync()
