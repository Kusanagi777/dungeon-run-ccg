## Reward Draft D1, D4, D7, D8, D12, F4-F6: determinism, exclusion and short pools
## (design/gdd/reward-draft.md AC-1 to AC-12), over the shipped 36 bundles and 20
## treasures, seeds 1..1000 where the AC says so.
extends GdUnitTestSuite

const BUNDLE: StringName = &"bundle"
const TREASURE: StringName = &"treasure"
const SEEDS: int = 1000
const SEED: int = 42
const LAST_DRAFT: int = DraftHarness.LAST_DRAFT_FLOOR
const W_DEFAULT: int = TestConstants.REOFFER_AFTER_FLOORS
const FLAG_SHORT: StringName = Offer.FLAG_SHORT
const FLAG_REOFFER: StringName = Offer.FLAG_REOFFER
const OFFER_SIZE: int = 3
const FULL_RUN_DRAWS: int = 30
const MVP_RUN_DRAWS: int = 15
const MVP_FLOORS: int = 4
## AC-11b's F5 example and AC-9's bound.
const FLOOR_7_ELIGIBLE: int = 10
const W_BREAKS_P14: int = 3
const W_BREAKS_P20: int = 6

var _fix: DraftHarness = null
var _policies: Array[StringName] = [DraftHarness.POLICY_FIRST, DraftHarness.POLICY_LAST, DraftHarness.POLICY_RANDOM]


func before() -> void:
	_fix = DraftHarness.new(TreasureFixtures.shipped_database())


func after() -> void:
	_fix = null


func _log() -> EventLog:
	return EventLog.new(RunHarness.MAX_EVENTS, EventLog.SCOPE_RUN)


func _record(floor_number: int, kind: String, offered: Array, picked: Variant) -> DraftRecord:
	return DraftRecord.make(floor_number, kind, offered, picked, [])


## On a treasure floor: treasure then bundle on one stream, as the run does.
func _both_offers(draft: RewardDraft, run_state: RunState, stream: RngStream) -> Dictionary:
	var treasure: Offer = draft.offer(TREASURE, run_state, stream)
	var after_treasure: int = stream.draws
	var bundle: Offer = draft.offer(BUNDLE, run_state, stream)
	return {"treasure": treasure, "bundle": bundle, "after_treasure": after_treasure, "after_bundle": stream.draws}


func _treasure_floor_state() -> RunState:
	return _fix.state(1, _fix.real_pool())


# --- AC-1 to AC-5 ------------------------------------------------------------

func test_two_runs_from_one_state_and_position_give_identical_offers() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var run_state: RunState = _treasure_floor_state()

	# Act
	var first: Dictionary = _both_offers(draft, run_state, DraftHarness.stream(SEED, 1))
	var second: Dictionary = _both_offers(draft, run_state, DraftHarness.stream(SEED, 1))

	# Assert
	assert_array(Array(second.treasure.option_ids)).is_equal(Array(first.treasure.option_ids))
	assert_array(Array(second.treasure.flags)).is_equal(Array(first.treasure.flags))
	assert_array(Array(second.bundle.option_ids)).is_equal(Array(first.bundle.option_ids))
	assert_array(Array(second.bundle.flags)).is_equal(Array(first.bundle.flags))


func test_a_treasure_offer_draws_three_and_a_bundle_offer_three_more() -> void:
	# Act
	var offers: Dictionary = _both_offers(_fix.draft(), _treasure_floor_state(), DraftHarness.stream(SEED, 1))

	# Assert
	assert_int(int(offers.after_treasure)).is_equal(OFFER_SIZE)
	assert_int(int(offers.after_bundle)).is_equal(OFFER_SIZE * 2)


func _run_draws(floors: int, treasure_floors: Array) -> int:
	var draft: RewardDraft = _fix.draft()
	var run_state: RunState = _fix.state(1, _fix.real_pool(), floors)
	var total: int = 0
	for f: int in range(1, floors):
		run_state.floor = f
		var stream: RngStream = DraftHarness.stream(SEED, f)
		if treasure_floors.has(f):
			var treasure: Offer = draft.offer(TREASURE, run_state, stream)
			run_state.drafts.append(_record(f, DraftRecord.KIND_TREASURE, treasure.option_ids, treasure.option_ids[0]))
			run_state.treasures.append(treasure.option_ids[0])
		var bundle: Offer = draft.offer(BUNDLE, run_state, stream)
		_fix.take_bundle(run_state, bundle.option_ids, bundle.option_ids[0], f)
		total += stream.draws
	return total


func test_a_plain_floor_draws_three() -> void:
	# Arrange
	var stream: RngStream = DraftHarness.stream(SEED, 2)

	# Act
	var _offer: Offer = _fix.draft().offer(BUNDLE, _fix.state(2), stream)

	# Assert
	assert_int(stream.draws).is_equal(OFFER_SIZE)


func test_a_full_run_totals_thirty_draws() -> void:
	# Act
	var draws: int = _run_draws(TestConstants.FLOORS_PER_RUN, Array(TestConstants.TREASURE_FLOORS))

	# Assert
	assert_int(draws).is_equal(FULL_RUN_DRAWS)


func test_an_mvp_run_totals_fifteen_draws() -> void:
	# Act
	var draws: int = _run_draws(MVP_FLOORS, [1, 3])

	# Assert
	assert_int(draws).is_equal(MVP_RUN_DRAWS)


func test_a_position_restored_at_three_regenerates_the_bundle_offer() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var run_state: RunState = _treasure_floor_state()
	var stream: RngStream = DraftHarness.stream(SEED, 1)
	var treasure: Offer = draft.offer(TREASURE, run_state, stream)
	var bundle: Offer = draft.offer(BUNDLE, run_state, stream)
	# the treasure pick changes the record, and must not change the bundle offer
	run_state.drafts.append(_record(1, DraftRecord.KIND_TREASURE, treasure.option_ids, treasure.option_ids[0]))
	run_state.treasures.append(treasure.option_ids[0])

	# Act
	var restored: RngStream = DraftHarness.stream(SEED, 1)
	restored.restore(OFFER_SIZE)
	var again: Offer = draft.offer(BUNDLE, run_state, restored)

	# Assert
	assert_array(Array(again.option_ids)).is_equal(Array(bundle.option_ids))
	assert_array(Array(again.flags)).is_equal(Array(bundle.flags))


func test_a_position_restored_at_zero_regenerates_the_treasure_offer() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var run_state: RunState = _treasure_floor_state()
	var first: Offer = draft.offer(TREASURE, run_state, DraftHarness.stream(SEED, 1))

	# Act
	var restored: RngStream = DraftHarness.stream(SEED, 1)
	restored.restore(0)
	var again: Offer = draft.offer(TREASURE, run_state, restored)

	# Assert
	assert_array(Array(again.option_ids)).is_equal(Array(first.option_ids))


func test_offer_mutates_nothing_and_emits_one_draft_offered(kind: StringName, test_parameters := [[&"bundle"], [&"treasure"]]) -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var log: EventLog = _log()
	draft.set_run_log(log)
	var run_state: RunState = _treasure_floor_state()
	var before: String = JSON.stringify(RunRecord.to_dict(run_state))

	# Act
	var _offer: Offer = draft.offer(kind, run_state, DraftHarness.stream(SEED, 1))

	# Assert
	assert_str(JSON.stringify(RunRecord.to_dict(run_state))).is_equal(before)
	assert_array(RunHarness.event_types(log)).is_equal([String(RunCodes.EVENT_DRAFT_OFFERED)])


func test_draft_offered_carries_floor_kind_ids_and_flags() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var log: EventLog = _log()
	draft.set_run_log(log)

	# Act
	var offer: Offer = draft.offer(TREASURE, _treasure_floor_state(), DraftHarness.stream(SEED, 1))

	# Assert
	var payload: Dictionary = log.events_since(0)[0].payload
	assert_int(int(payload.floor)).is_equal(1)
	assert_str(payload.kind).is_equal(DraftRecord.KIND_TREASURE)
	assert_array(payload.option_ids).is_equal(Array(offer.option_ids))
	assert_array(payload.flags).is_equal(["universal_forced"])


func test_option_ids_are_strictly_ascending_on_every_seed_and_floor() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var bad: Array = []

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		var sim: DraftHarness.SimResult = _fix.simulate(draft, run_seed, DraftHarness.POLICY_RANDOM)
		for offer: Offer in sim.offers:
			for i: int in range(1, offer.option_ids.size()):
				if offer.option_ids[i - 1] >= offer.option_ids[i]:
					bad.append([run_seed, offer.floor])

	# Assert
	assert_array(bad).is_empty()


func test_treasure_option_ids_are_strictly_ascending_on_every_seed() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var run_state: RunState = _treasure_floor_state()
	var bad: Array = []

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		var ids: Array[String] = draft.offer(TREASURE, run_state, DraftHarness.stream(run_seed, 1)).option_ids
		if not (ids[0] < ids[1] and ids[1] < ids[2]):
			bad.append(run_seed)

	# Assert
	assert_array(bad).is_empty()


# --- AC-6 to AC-8 ------------------------------------------------------------

func _pool_ids() -> Array:
	return DraftHarness.ids_of(_fix.p20())


func test_a_taken_bundle_is_never_offered_again() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var ids: Array = _pool_ids()
	var taken: String = ids[0]
	var seen: int = 0

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		var run_state: RunState = _fix.state()
		_fix.take_bundle(run_state, [taken, ids[1], ids[2]], taken, 1)
		for f: int in range(2, LAST_DRAFT + 1):
			run_state.floor = f
			if draft.offer(BUNDLE, run_state, DraftHarness.stream(run_seed, f)).option_ids.has(taken):
				seen += 1

	# Assert
	assert_int(seen).is_equal(0)


func test_a_declined_bundle_cools_for_the_window_and_returns_after_it() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var ids: Array = _pool_ids()
	var declined: String = ids[1]
	var seen: Dictionary = {2: 0, 3: 0, 4: 0}

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		var run_state: RunState = _fix.state()
		_fix.take_bundle(run_state, [ids[0], declined, ids[2]], ids[0], 1)
		for f: int in seen.keys():
			run_state.floor = f
			if draft.offer(BUNDLE, run_state, DraftHarness.stream(run_seed, f)).option_ids.has(declined):
				seen[f] += 1

	# Assert
	assert_int(int(seen[2])).is_equal(0)
	assert_int(int(seen[3])).is_equal(0)
	assert_int(int(seen[4])).is_greater(0)


func test_held_and_offered_treasures_never_come_back() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var pool: Array = _fix.real_pool()
	var gone: Array = pool.slice(0, OFFER_SIZE)
	var seen: int = 0

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		for f: int in [3, 5]:
			var run_state: RunState = _fix.state(f, pool)
			run_state.treasures.assign([gone[0]])
			run_state.drafts.append(_record(1, DraftRecord.KIND_TREASURE, gone, gone[0]))
			for id: String in draft.offer(TREASURE, run_state, DraftHarness.stream(run_seed, f)).option_ids:
				if gone.has(id):
					seen += 1

	# Assert
	assert_int(seen).is_equal(0)


# --- AC-9, AC-11b: F5 --------------------------------------------------------

func _sweep_flags(draft: RewardDraft, over: CardDatabase) -> Array:
	var bad: Array = []
	for policy: StringName in _policies:
		for run_seed: int in range(1, SEEDS + 1):
			var sim: DraftHarness.SimResult = _fix.simulate(draft, run_seed, policy, over)
			if sim.flagged(FLAG_SHORT) or sim.flagged(FLAG_REOFFER):
				bad.append([policy, run_seed])
	return bad


func _any_reoffer(window: int, over: CardDatabase) -> bool:
	var draft: RewardDraft = _fix.draft({"reoffer_after_floors": window}, over)
	for policy: StringName in _policies:
		for run_seed: int in range(1, SEEDS + 1):
			if _fix.simulate(draft, run_seed, policy, over).flagged(FLAG_REOFFER):
				return true
	return false


func test_p14_at_w2_is_never_short_or_reoffering_under_any_policy() -> void:
	# Arrange
	var over: DraftHarness.PoolDb = _fix.pool_db(_fix.p14())
	assert_int(_fix.p14().size()).is_equal(14)

	# Act
	var bad: Array = _sweep_flags(_fix.draft({}, over), over)

	# Assert
	assert_array(bad).is_empty()


func test_p14_at_w3_passes_the_f5_bound_and_reoffers() -> void:
	# Act
	var reoffered: bool = _any_reoffer(W_BREAKS_P14, _fix.pool_db(_fix.p14()))

	# Assert
	assert_bool(reoffered).is_true()


func test_p20_at_w2_is_never_short_or_reoffering_under_any_policy() -> void:
	# Arrange
	assert_int(_fix.p20().size()).is_equal(20)

	# Act
	var bad: Array = _sweep_flags(_fix.draft(), null)

	# Assert
	assert_array(bad).is_empty()


func test_p20_at_w2_keeps_ten_eligible_on_floor_seven() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var least: int = 1000

	# Act
	for policy: StringName in _policies:
		for run_seed: int in range(1, SEEDS + 1):
			var sim: DraftHarness.SimResult = _fix.simulate(draft, run_seed, policy, null, LAST_DRAFT, _fix.p20(), W_DEFAULT)
			least = mini(least, sim.eligible[LAST_DRAFT - 1])

	# Assert
	assert_int(least).is_greater_equal(FLOOR_7_ELIGIBLE)


func test_p20_at_w6_passes_the_f5_bound_and_reoffers() -> void:
	# Act
	var reoffered: bool = _any_reoffer(W_BREAKS_P20, null)

	# Assert
	assert_bool(reoffered).is_true()


# --- AC-10, AC-11: treasure pools --------------------------------------------

func _three_treasure_drafts(draft: RewardDraft, pool: Array, run_seed: int) -> Array[Offer]:
	var offers: Array[Offer] = []
	var run_state: RunState = _fix.state(1, pool)
	for f: int in TestConstants.TREASURE_FLOORS:
		run_state.floor = f
		var offer: Offer = draft.offer(TREASURE, run_state, DraftHarness.stream(run_seed, f))
		offers.append(offer)
		if not offer.option_ids.is_empty():
			run_state.drafts.append(_record(f, DraftRecord.KIND_TREASURE, offer.option_ids, offer.option_ids[0]))
			run_state.treasures.append(offer.option_ids[0])
	return offers


func test_a_snapshot_of_ten_is_never_short() -> void:
	# Arrange
	var over: DraftHarness.PoolDb = _fix.t10_db()
	var draft: RewardDraft = _fix.draft({}, over)
	var pool: Array = DraftHarness.ids_of(DraftHarness.t10())
	var bad: Array = []

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		for offer: Offer in _three_treasure_drafts(draft, pool, run_seed):
			if offer.flags.has(FLAG_SHORT):
				bad.append(run_seed)

	# Assert
	assert_array(bad).is_empty()


func test_the_shipped_twenty_are_never_short() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var bad: Array = []

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		for offer: Offer in _three_treasure_drafts(draft, _fix.real_pool(), run_seed):
			if offer.flags.has(FLAG_SHORT) or offer.option_ids.size() != OFFER_SIZE:
				bad.append(run_seed)

	# Assert
	assert_array(bad).is_empty()


func test_a_snapshot_of_eight_offers_two_on_floor_five_with_a_warning() -> void:
	# Arrange
	var over: DraftHarness.PoolDb = _fix.t10_db()
	var draft: RewardDraft = _fix.draft({}, over)
	var log: EventLog = _log()
	draft.set_run_log(log)
	var pool: Array = DraftHarness.ids_of(DraftHarness.t10()).slice(0, 8)

	# Act
	var offers: Array[Offer] = _three_treasure_drafts(draft, pool, SEED)

	# Assert
	assert_int(offers[2].option_ids.size()).is_equal(2)
	assert_bool(offers[2].flags.has(FLAG_SHORT)).is_true()
	var warnings: Array = RunHarness.warnings_of(log, RunCodes.W_TREASURE_POOL_SHORT)
	assert_int(warnings.size()).is_equal(1)
	assert_dict(warnings[0].payload.detail).is_equal({"floor": 5, "needed": OFFER_SIZE, "available": 2})


func test_the_debug_reoffer_policy_refills_from_offered_not_held() -> void:
	# Arrange
	var over: DraftHarness.PoolDb = _fix.t10_db()
	var draft: RewardDraft = _fix.draft({"treasure_short_policy": RewardDraft.POLICY_REOFFER}, over)
	var pool: Array = DraftHarness.ids_of(DraftHarness.t10()).slice(0, 8)

	# Act
	var offers: Array[Offer] = _three_treasure_drafts(draft, pool, SEED)

	# Assert
	var last: Offer = offers[2]
	var earlier: Array = Array(offers[0].option_ids) + Array(offers[1].option_ids)
	var held: Array = [offers[0].option_ids[0], offers[1].option_ids[0]]
	assert_int(last.option_ids.size()).is_equal(OFFER_SIZE)
	assert_bool(last.flags.has(FLAG_REOFFER)).is_true()
	assert_bool(last.flags.has(FLAG_SHORT)).is_false()
	assert_int(Array(last.option_ids).filter(func(id: String) -> bool: return earlier.has(id)).size()).is_equal(1)
	assert_array(Array(last.option_ids).filter(func(id: String) -> bool: return held.has(id))).is_empty()


func test_a_release_build_refuses_the_reoffer_policy() -> void:
	# Arrange
	var body: Dictionary = _fix.config({"treasure_short_policy": RewardDraft.POLICY_REOFFER})

	# Act
	var release: Array = RewardDraft.validate_config(body, null, false)
	var debug: Array = RewardDraft.validate_config(body, null, true)

	# Assert
	assert_array(release.map(func(row: Dictionary) -> StringName: return row.code)).is_equal([ConfigRows.E_CONFIG])
	assert_array(debug).is_empty()


func test_no_treasure_left_returns_empty_under_either_policy(policy: String, test_parameters := [["fewer"], ["reoffer"]]) -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft({"treasure_short_policy": policy})
	var pool: Array = _fix.real_pool().slice(0, OFFER_SIZE)
	var run_state: RunState = _fix.state(3, pool)
	run_state.drafts.append(_record(1, DraftRecord.KIND_TREASURE, pool, pool[0]))
	run_state.treasures.assign([pool[0]])

	# Act
	var offer: Offer = draft.offer(TREASURE, run_state, DraftHarness.stream(SEED, 3))

	# Assert
	assert_array(Array(offer.option_ids)).is_empty()


func test_an_empty_offer_emits_no_draft_offered() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var log: EventLog = _log()
	draft.set_run_log(log)

	# Act
	var _offer: Offer = draft.offer(TREASURE, _fix.state(1, []), DraftHarness.stream(SEED, 1))

	# Assert
	assert_array(RunHarness.events_of(log, RunCodes.EVENT_DRAFT_OFFERED)).is_empty()


# --- AC-12: a 3-bundle pool --------------------------------------------------

func _three_bundle_run() -> Dictionary:
	var pool: Array = _fix.p20().slice(0, OFFER_SIZE)
	var over: DraftHarness.PoolDb = _fix.pool_db(pool)
	var draft: RewardDraft = _fix.draft({}, over)
	var log: EventLog = _log()
	draft.set_run_log(log)
	var sim: DraftHarness.SimResult = _fix.simulate(draft, SEED, DraftHarness.POLICY_FIRST, over, MVP_FLOORS)
	return {"sim": sim, "log": log}


func test_a_three_bundle_pool_runs_three_two_one_then_empty() -> void:
	# Act
	var sim: DraftHarness.SimResult = _three_bundle_run().sim

	# Assert
	assert_array(sim.offers.map(func(o: Offer) -> int: return o.option_ids.size())).is_equal([3, 2, 1, 0])


func test_the_second_floor_of_a_three_bundle_pool_flags_reoffer_and_short_and_warns() -> void:
	# Act
	var run: Dictionary = _three_bundle_run()

	# Assert
	var flags: Array = Array((run.sim as DraftHarness.SimResult).offers[1].flags)
	assert_array(flags).is_equal([FLAG_REOFFER, FLAG_SHORT])
	var warned: Array = RunHarness.warnings_of(run.log, RunCodes.W_BUNDLE_POOL_SHORT).map(func(e: Dictionary) -> int: return int(e.payload.detail.floor))
	assert_bool(warned.has(2)).is_true()


func test_the_exhausted_floor_records_a_null_pick_and_leaves_the_deck() -> void:
	# Act
	var sim: DraftHarness.SimResult = _three_bundle_run().sim

	# Assert
	var record: DraftRecord = sim.state.drafts.back()
	assert_object(record.picked_id).is_null()
	assert_int(sim.state.deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE + OFFER_SIZE * TestConstants.BUNDLE_CARD_COUNT)


func test_a_run_over_a_three_bundle_pool_skips_floor_four_with_no_deck_growth() -> void:
	# Arrange: the real RunMachine, the real draft, a one-blow boss
	var over: DraftHarness.PoolDb = _fix.pool_db(_fix.p20().slice(0, OFFER_SIZE))
	var game := RunRealFixture.new(over)
	game.boss_health = RunRealFixture.ONE_BLOW
	var run: RunMachine = game.machine(MetaStub.new(over))
	assert_int(run.new_run(DraftHarness.HERO_ID, "42")).is_equal(OK)

	# Act
	for _f: int in MVP_FLOORS:
		game.play_floor(run)

	# Assert
	assert_int(run.state.floor).is_equal(MVP_FLOORS + 1)
	assert_int(run.state.deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE + OFFER_SIZE * TestConstants.BUNDLE_CARD_COUNT)
	assert_int(run.state.validate(over)).is_equal(OK)
	game.release()
