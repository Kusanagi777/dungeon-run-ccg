## L12 (match-ui U9; story 013 AC-1): a log that stops on the player's Choice projects to
## `ChoiceOpen` with its options on an empty queue at `instant`.
extends GdUnitTestSuite

const OPTIONS: Array[String] = ["card_a", "card_b", "card_c"]
const SOURCE: int = 14


func _event(seq: int, type: String, payload: Dictionary, cause: int = 0) -> Dictionary:
	return {"seq": seq, "turn": 1, "type": type, "payload": payload, "cause_seq": cause}


func _offer(side: String) -> Array[Dictionary]:
	return [
		_event(10, "discover_offered", {"side": side, "kind": "discover", "option_card_ids": OPTIONS, "source_id": SOURCE, "effect_id": "e"}),
		_event(11, "choice_requested", {"side": side, "kind": "discover", "options": OPTIONS, "source_id": SOURCE, "effect_id": "e"}, 10),
	]


func _project(events: Array[Dictionary], view: MatchViewState, queue: AnimationQueue) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for event: Dictionary in events:
		for step: AnimStep in view.apply(event):
			kinds.append(step.kind)
			queue.enqueue(step)
	return kinds


func _router(view: MatchViewState, queue: AnimationQueue) -> InputRouter:
	var router: InputRouter = auto_free(InputRouter.new())
	router.bind(view, queue)
	router.set_controller(MatchController.new(null))
	return router


func test_l12_a_player_choice_is_open_with_three_options_and_an_empty_queue() -> void:
	# Arrange
	var view := MatchViewState.new(MatchUiTestConfig.body())
	var queue := AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings({"anim_speed": "instant"}))
	var router: InputRouter = _router(view, queue)

	# Act
	var kinds: Array[StringName] = _project(_offer("player"), view, queue)
	queue.advance(0.0)

	# Assert
	assert_str(String(router.view_state())).is_equal(String(InputRouter.STATE_CHOICE_OPEN))
	assert_array(view.pending_choice.options).is_equal(OPTIONS)
	assert_bool(queue.is_idle()).is_true()
	assert_array(kinds).is_equal([AnimStep.OVERLAY_OPEN])


func test_a_player_choice_opens_once_whichever_event_lands_first() -> void:
	# Arrange
	var view := MatchViewState.new(MatchUiTestConfig.body())
	var queue := AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings({"anim_speed": "instant"}))
	var events: Array[Dictionary] = _offer("player")
	events.reverse()

	# Act
	var kinds: Array[StringName] = _project(events, view, queue)

	# Assert
	assert_array(kinds).is_equal([AnimStep.OVERLAY_OPEN])
	assert_array(view.pending_choice.options).is_equal(OPTIONS)


func test_a_boss_choice_stores_no_options_and_opens_no_overlay() -> void:
	# Arrange
	var view := MatchViewState.new(MatchUiTestConfig.body())
	var queue := AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings({"anim_speed": "instant"}))

	# Act
	var kinds: Array[StringName] = _project(_offer("boss"), view, queue)

	# Assert
	assert_bool((view.pending_choice as Dictionary).has("options")).is_false()
	assert_array(kinds).is_equal([AnimStep.BOSS_DISCOVERS])


func test_choice_made_closes_a_player_choice_with_one_step() -> void:
	# Arrange
	var view := MatchViewState.new(MatchUiTestConfig.body())
	var queue := AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings({"anim_speed": "instant"}))
	_project(_offer("player"), view, queue)

	# Act
	var kinds: Array[StringName] = _project([_event(12, "choice_made", {"side": "player", "option_index": 1})], view, queue)

	# Assert
	assert_that(view.pending_choice).is_null()
	assert_array(kinds).is_equal([AnimStep.OVERLAY_CLOSE])
