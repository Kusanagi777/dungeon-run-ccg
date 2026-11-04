## The shipped `assets/data/match_ui.json` body against the code that reads
## it: `AnimationQueue` (`speed_div`, `coalesce_threshold`) and
## `MatchViewState` (`feed_max_lines`). Code review 2026-11-04 (content story
## 001 / match-ui stories 001-002): the three knobs were UPPER_CASE file keys,
## against DD-T01's snake_case rule; the GDD's knob names map to snake_case
## file keys (design/gdd/match-ui.md Tuning Knobs). Read as the imported JSON
## resource (never `FileAccess`), as the Card Database serves it: the
## envelope's `config` body. No wall clock.
extends GdUnitTestSuite

const SHIPPED: String = "res://assets/data/match_ui.json"
## The snake_case file keys of the three renamed knobs.
const FILE_KEYS: Array[String] = ["speed_div", "coalesce_threshold", "feed_max_lines"]
const UPPER_KEYS: Array[String] = ["SPEED_DIV", "COALESCE_THRESHOLD", "FEED_MAX_LINES"]


func _body() -> Dictionary:
	var resource: JSON = load(SHIPPED)
	return (resource.data as Dictionary).config


func test_the_shipped_body_names_the_knobs_by_snake_case_file_keys_only() -> void:
	# Arrange
	var body: Dictionary = _body()

	# Act / Assert
	for key: String in FILE_KEYS:
		assert_bool(body.has(key)).override_failure_message("missing file key %s" % key).is_true()
	for key: String in UPPER_KEYS:
		assert_bool(body.has(key)).override_failure_message("UPPER_CASE file key %s" % key).is_false()


func test_the_animation_queue_reads_the_shipped_speed_divisor_and_threshold() -> void:
	# Arrange
	var body: Dictionary = _body()
	var out: Dictionary = {}

	# Act — a missing or non-positive threshold is a pushed error
	await assert_error(func() -> void: out.queue = AnimationQueue.new(body, {"anim_speed": "fast", "reduce_motion": false})).is_success()
	var d_base: float = float(body.d_base.damage_pop)
	var step: AnimStep = AnimStep.new(AnimStep.DAMAGE_POP, [1], d_base, 1, 1)

	# Assert
	assert_float((out.queue as AnimationQueue).effective_duration(step)).is_equal_approx(d_base / float(body.speed_div.fast), 1e-9)


func test_the_view_state_keeps_at_most_the_shipped_feed_max_lines() -> void:
	# Arrange
	var body: Dictionary = _body()
	var cap: int = int(body.feed_max_lines)
	var view: MatchViewState = MatchViewState.new(body)

	# Act — one feed line per non-silent event, past the cap
	for seq: int in range(1, cap + 6):
		view.apply({"seq": seq, "turn": 1, "type": "mana_spent", "payload": {"side": "player", "amount": 1, "mana_current": 0}, "cause_seq": 0})

	# Assert
	assert_int(view.feed_lines.size()).is_equal(cap)
