## PERFORMANCE SUITE — the wall-clock half of match-ui AC L6. NOT part of the
## blocking run: `commands.test` ignores `res://tests/performance`, and the
## non-blocking `performance` CI job runs this folder (continue-on-error, one
## retry, `PERF` lines in the job summary).
##
## Story: production/epics/match-ui/story-002-animation-queue-core.md (L6:
## "the 300-step flush completes in ≤ 100 ms"; control manifest Presentation
## guardrail "Skip-all → display = view-state ≤ 100 ms (300-step stream)").
## The stream is built outside the timed window: 300 C15 events, one step each
## (alternating pops from distinct sources, so nothing coalesces), every step
## bound to a `FakePresenter` whose `apply_final` copies view-state values as a
## real presenter would. The measured block is the one `skip_all()` call. The
## ordering and sync half of L6 is deterministic and lives in the blocking
## `tests/unit/match_ui/animation_queue_test.gd`.
extends GdUnitTestSuite

const STEP_COUNT: int = 300
const SKIP_BUDGET_USEC: int = 100_000
const HERO_IDS: Array[int] = [1, 2]
const MINION_BASE: int = 100

var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("match_ui skip_all", "the test ended before its measurement"))


func test_skip_all_over_a_300_step_stream_fits_in_100_ms() -> void:
	# Arrange
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var seq: int = 1
	view.apply({"seq": seq, "turn": 1, "type": "match_started", "payload": {"floor": 1, "hero_id": HERO_IDS[0], "boss_id": HERO_IDS[1], "player_deck_size": 0, "boss_deck_size": 0}, "cause_seq": 0})
	for i: int in 7:
		seq += 1
		view.apply({"seq": seq, "turn": 1, "type": "minion_summoned", "payload": {"side": "boss", "entity_id": MINION_BASE + i, "card_id": "boss_tinder_imp", "position": i, "attack": 1, "health": STEP_COUNT}, "cause_seq": 0})
	var presenter: FakePresenter = FakePresenter.new()
	presenter.bind(view)
	var queue: AnimationQueue = AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings())
	presenter.listen(queue)
	var steps: int = 0
	for i: int in STEP_COUNT:
		seq += 1
		var target: int = MINION_BASE + i % 7
		var event: Dictionary = {"seq": seq, "turn": 1, "type": "damage_dealt", "payload": {"source": 10_000 + i, "target": target, "requested": 1, "prevented": 0, "armor_absorbed": 0, "dealt": 1, "health_after": STEP_COUNT - i}, "cause_seq": 0}
		for step: AnimStep in view.apply(event):
			presenter.bind_step(step)
			queue.enqueue(step)
			steps += 1

	# Act
	var started: int = Time.get_ticks_usec()
	queue.skip_all()
	var elapsed: int = Time.get_ticks_usec() - started
	_measured = true
	print("PERF match_ui skip_all x%d steps: %d us (budget %d us)" % [steps, elapsed, SKIP_BUDGET_USEC])

	# Assert
	assert_int(steps).is_equal(STEP_COUNT)
	assert_array(presenter.sync_report()).is_empty()
	assert_int(elapsed).override_failure_message("skip_all over %d steps took %d us, budget %d us" % [steps, elapsed, SKIP_BUDGET_USEC]).is_less_equal(SKIP_BUDGET_USEC)
