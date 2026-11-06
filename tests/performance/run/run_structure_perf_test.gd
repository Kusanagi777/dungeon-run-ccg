## Performance: `new_run`, resume and `offer` budgets (design/gdd/run-structure.md AC-30;
## design/gdd/reward-draft.md AC-31). Real records, real data, headless. Each figure is
## the median of [constant SAMPLES] runs, printed so a regression is a number.
extends GdUnitTestSuite

const SAMPLES: int = 21
const HERO: String = RunRealFixture.HERO_ID
const LAST_FLOOR: int = TestConstants.FLOORS_PER_RUN
const USEC_PER_MSEC: float = 1000.0
const NEW_RUN_BUDGET_MS: float = 5.0
const RESUME_BUDGET_MS: float = 20.0
const OFFER_BUDGET_MS: float = 5.0
## AC-31's deck.
const DECK_CARDS: int = 36

var _db: CardDatabase = null


func before() -> void:
	_db = TreasureFixtures.shipped_database()


func after() -> void:
	_db = null


func _median_ms(work: Callable) -> float:
	var samples: Array[int] = []
	for _i: int in SAMPLES:
		var started: int = Time.get_ticks_usec()
		work.call()
		samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	return float(samples[SAMPLES / 2]) / USEC_PER_MSEC


func test_new_run_with_its_sequence_is_under_five_ms() -> void:
	# Arrange
	var game := RunRealFixture.new(_db)
	var meta := MetaStub.new(_db)

	# Act
	var ms: float = _median_ms(func() -> void:
		var run: RunMachine = game.machine(meta)
		var _answer: Error = run.new_run(HERO, "42")
		meta.clear_active_run())
	print("AC-30 new_run: %.3f ms" % ms)

	# Assert
	assert_float(ms).is_less(NEW_RUN_BUDGET_MS)


func test_validate_and_restore_of_a_floor_eight_s4_record_is_under_twenty_ms() -> void:
	# Arrange: a real run walked to floor 8
	var game := RunRealFixture.new(_db)
	game.boss_health = RunRealFixture.ONE_BLOW
	var meta := MetaStub.new(_db)
	var run: RunMachine = game.machine(meta)
	assert_int(run.new_run(HERO, "42")).is_equal(OK)
	for _f: int in LAST_FLOOR - 1:
		game.play_floor(run)
	var record: Dictionary = JSON.parse_string(JSON.stringify(meta.load_active_run()))
	assert_int(int(record.floor)).is_equal(LAST_FLOOR)

	# Act
	var ms: float = _median_ms(func() -> void:
		meta.save_active_run(record)
		var resumed: RunMachine = game.machine(meta)
		assert_int(resumed.resume()).is_equal(OK))
	print("AC-30 validate + restore: %.3f ms" % ms)
	game.release()

	# Assert
	assert_float(ms).is_less(RESUME_BUDGET_MS)


func test_an_offer_over_the_shipped_pools_and_a_36_card_deck_is_under_five_ms() -> void:
	# Arrange
	var fix := DraftHarness.new(_db)
	var draft: RewardDraft = fix.draft()
	var run_state: RunState = fix.state(5)
	var pool: Array = fix.p20()
	for i: int in DraftHarness.LAST_DRAFT_FLOOR:
		run_state.deck.append_array(pool[i].cards)
	assert_int(run_state.deck.size()).is_equal(DECK_CARDS)

	# Act
	var ms: float = _median_ms(func() -> void:
		var _offer: Offer = draft.offer(&"bundle", run_state, DraftHarness.stream(42, 5)))
	print("AC-31 offer: %.3f ms" % ms)

	# Assert
	assert_float(ms).is_less(OFFER_BUDGET_MS)
