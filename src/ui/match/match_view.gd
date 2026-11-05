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

@onready var _table: ColorRect = %Table
@onready var _player_panel: HeroPresenter = %PlayerPanel
@onready var _boss_panel: HeroPresenter = %BossPanel
@onready var _player_row: BoardPresenter = %PlayerRow
@onready var _boss_row: BoardPresenter = %BossRow
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


## What the top bar names: `{floor, boss_def_id}` from the `MatchConfig`.
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
	_table.color = _ui.color("table_lit")
	_presenters = [_boss_panel, _player_panel, _boss_row, _player_row, _hand, _arrow, _feed, _choice, _mulligan, _banner]
	for presenter: Presenter in _presenters:
		presenter.setup(_ui)
		presenter.bind(_view)
	_queue.step_started.connect(_on_step_started)
	_queue.skipped.connect(_on_skipped)
	_queue.drained.connect(_on_drained)


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
	_controller.bind_queue(_queue)
	_queue.set_speed(SPEED_INSTANT)
	for event: Dictionary in _controller.events_since(0):
		_on_event(event)
	_queue.advance(0.0)
	_queue.set_speed(_speed)
	_controller.subscribe(_on_event)
	_present(_display())
	if _loader != null:
		_loader.call("apply_pose", self, str(_launch_args.pose))


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


func _on_skipped() -> void:
	for presenter: Presenter in _presenters:
		presenter.on_skipped()


func _on_drained() -> void:
	_present(_display())
	if OS.is_debug_build():
		assert_in_sync()
