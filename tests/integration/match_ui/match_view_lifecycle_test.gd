## MatchView's skeleton and the fixture launch (match-ui story 004 AC-1, AC-2; U1, U11;
## ADR-0009 Decision 3). A real view on real fixtures through [MatchViewHarness].
extends GdUnitTestSuite

const PARTITION: Array[String] = [
	"HandFan", "PlayerRow", "BossRow", "PlayerPanel", "BossPanel", "TargetingArrow",
	"ChoiceOverlay", "EventFeed", "Banner", "MulliganScreen", "PauseMenu",
]


## A controller that notes the order of the calls a view makes.
class SpyController:
	extends MatchController

	var trail: Array[String] = []

	func _init(driver: MatchDriver) -> void:
		super(driver)

	func events_since(seq: int) -> Array:
		trail.append("events_since:%d" % seq)
		return super(seq)

	func subscribe(callback: Callable) -> void:
		trail.append("subscribe")
		super(callback)

	func tick() -> void:
		trail.append("tick")
		super()

	func shutdown() -> void:
		trail.append("shutdown")
		super()


## A presenter whose display never matches.
class StuckPresenter:
	extends Presenter

	func bind(_view_state: MatchViewState) -> void:
		return

	func owns(_entity_ids: Array[int]) -> bool:
		return false

	func on_step_started(_step: AnimStep, _d_eff: float) -> void:
		return

	func apply_final(_step: AnimStep) -> void:
		return

	func sync_report() -> Array[String]:
		return ["stuck"]


func _spy_view() -> Array:
	var boot: Node = MatchViewHarness.fresh_boot({"anim_speed": "instant"})
	var loader := MatchDebugLoader.new(MatchViewHarness.immediate_planner(), boot)
	var live: MatchController = loader.load_fixture("turn1_player")
	var spy := SpyController.new(live.get("_driver"))
	var view: MatchView = await MatchViewHarness.open_controller(self, boot, spy, loader.match_info)
	return [view, spy]


func test_the_scene_holds_the_adr_0009_partition_and_one_of_each_owner() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")

	# Assert
	for node_name: String in PARTITION:
		assert_object(view.find_child(node_name, true, false)).override_failure_message("no %s" % node_name).is_not_null()
	assert_object(view.view_state()).is_instanceof(MatchViewState)
	assert_object(view.queue()).is_instanceof(AnimationQueue)
	assert_object(view.router()).is_instanceof(InputRouter)
	assert_int(view.find_children("*", "InputRouter", true, false).size()).is_equal(1)
	assert_object(view.hand()).is_instanceof(Presenter)
	MatchViewHarness.close(view)


func test_events_are_projected_before_the_view_subscribes() -> void:
	# Arrange / Act
	var parts: Array = await _spy_view()
	var spy: SpyController = parts[1]

	# Assert
	assert_int(spy.trail.find("events_since:0")).is_greater_equal(0)
	assert_int(spy.trail.find("subscribe")).is_greater(spy.trail.find("events_since:0"))
	MatchViewHarness.close(parts[0])


func test_process_ticks_the_controller_and_advances_the_queue() -> void:
	# Arrange
	var parts: Array = await _spy_view()
	var view: MatchView = parts[0]
	var spy: SpyController = parts[1]
	var step := AnimStep.new(AnimStep.TURN_BANNER, [], 0.05, 0, 0)
	view.queue().set_speed(&"normal")
	view.queue().enqueue(step)
	var ticks_before: int = spy.trail.count("tick")

	# Act
	MatchViewHarness.run(view, 0.2)

	# Assert
	assert_int(spy.trail.count("tick")).is_greater(ticks_before)
	assert_bool(view.queue().is_idle()).is_true()
	MatchViewHarness.close(view)


func test_leaving_the_tree_shuts_the_controller_down_once() -> void:
	# Arrange
	var parts: Array = await _spy_view()
	var spy: SpyController = parts[1]

	# Act
	MatchViewHarness.close(parts[0])

	# Assert
	assert_int(spy.trail.count("shutdown")).is_equal(1)


func test_a_drain_runs_the_sync_check_in_a_debug_build() -> void:
	# Arrange: a presenter that is always out of sync, which only the check can notice
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var stuck: StuckPresenter = auto_free(StuckPresenter.new())
	stuck.name = "Stuck"
	(view.get("_presenters") as Array).append(stuck)

	# Act / Assert
	await assert_error(func() -> void: view.queue().drained.emit()).is_push_error("MatchView: Stuck out of sync: stuck")
	assert_int(view.sync_failures).is_equal(1)
	(view.get("_presenters") as Array).erase(stuck)
	MatchViewHarness.close(view)


func test_fixture_launch_runs_clean_and_reaches_idle_with_an_empty_queue() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var loader: MatchDebugLoader = view.get("_loader")

	# Assert
	assert_array(loader.rejections).is_empty()
	assert_bool(view.queue().is_idle()).is_true()
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_IDLE))
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	assert_int(view.sync_failures).is_equal(0)
	MatchViewHarness.close(view)


func test_the_view_leaves_the_boot_autoload_alone_under_the_seam() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")

	# Assert: boot_composition_test relies on it
	assert_bool(Boot.booted).is_false()
	MatchViewHarness.close(view)
