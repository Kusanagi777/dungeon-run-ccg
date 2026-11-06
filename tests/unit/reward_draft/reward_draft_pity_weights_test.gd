## Reward Draft D5, D6, F1-F3: pity, coverage and weights (design/gdd/reward-draft.md
## AC-13 to AC-23), over the shipped War pool and starter.
extends GdUnitTestSuite

const BUNDLE: StringName = &"bundle"
const TREASURE: StringName = &"treasure"
const SEEDS: int = 1000
const SEED: int = 42
const TREASURE_SEEDS: int = 10000
const WEAPONS: String = "weapons"
const AGGRO: String = "aggro"
const PITY: StringName = Offer.FLAG_PITY_FORCED
const COVERAGE: StringName = Offer.FLAG_COVERAGE_FORCED
const UNIVERSAL_FORCED: StringName = Offer.FLAG_UNIVERSAL_FORCED
const UNIVERSAL_MISSING: StringName = Offer.FLAG_UNIVERSAL_MISSING
const OFFER_SIZE: int = 3
## AC-23's band, of the slot-2/3 picks.
const RARE_SHARE_LOW: float = 0.15
const RARE_SHARE_HIGH: float = 0.30

var _fix: DraftHarness = null


func before() -> void:
	_fix = DraftHarness.new(TreasureFixtures.shipped_database())


func after() -> void:
	_fix = null


func _theme(id: String) -> String:
	return _fix.db.bundle(id).theme


func _of_theme(theme: String) -> Array:
	return DraftHarness.ids_of(_fix.p20().filter(func(b: Dictionary) -> bool: return b.theme == theme))


func _not_of_theme(theme: String) -> Array:
	return DraftHarness.ids_of(_fix.p20().filter(func(b: Dictionary) -> bool: return b.theme != theme and b["set"] == DraftHarness.NEUTRAL_SET))


## Floors 1 and 2 drafted from [param offered_1] and [param offered_2], first option
## taken: the record a floor-3 offer is computed from.
func _two_drafts(offered_1: Array, offered_2: Array) -> RunState:
	var run_state: RunState = _fix.state(3)
	_fix.take_bundle(run_state, offered_1, offered_1[0], 1)
	_fix.take_bundle(run_state, offered_2, offered_2[0], 2)
	return run_state


func _starved_state() -> RunState:
	var others: Array = _not_of_theme(WEAPONS)
	return _two_drafts(others.slice(0, OFFER_SIZE), others.slice(OFFER_SIZE, OFFER_SIZE * 2))


func _count_flag(draft: RewardDraft, run_state: RunState, flag: StringName) -> int:
	var count: int = 0
	for run_seed: int in range(1, SEEDS + 1):
		if draft.offer(BUNDLE, run_state, DraftHarness.stream(run_seed, run_state.floor)).flags.has(flag):
			count += 1
	return count


# --- AC-13 to AC-17 ----------------------------------------------------------

func test_two_starved_drafts_force_a_weapons_bundle_on_every_seed() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var run_state: RunState = _starved_state()
	var bad: Array = []

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		var offer: Offer = draft.offer(BUNDLE, run_state, DraftHarness.stream(run_seed, 3))
		if not offer.flags.has(PITY) or not Array(offer.option_ids).any(func(id: String) -> bool: return _theme(id) == WEAPONS):
			bad.append(run_seed)

	# Assert
	assert_array(bad).is_empty()


func test_pity_never_fires_on_floors_one_and_two() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var others: Array = _not_of_theme(WEAPONS)
	var second: RunState = _fix.state(2)
	_fix.take_bundle(second, others.slice(0, OFFER_SIZE), others[0], 1)

	# Act
	var on_first: int = _count_flag(draft, _fix.state(1), PITY)
	var on_second: int = _count_flag(draft, second, PITY)

	# Assert
	assert_int(on_first).is_equal(0)
	assert_int(on_second).is_equal(0)


func test_a_pity_window_of_one_fires_on_floor_two_so_the_value_is_data() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft({"pity_window": 1})
	var others: Array = _not_of_theme(WEAPONS)
	var run_state: RunState = _fix.state(2)
	_fix.take_bundle(run_state, others.slice(0, OFFER_SIZE), others[0], 1)

	# Act
	var fired: int = _count_flag(draft, run_state, PITY)

	# Assert
	assert_int(fired).is_equal(SEEDS)


func test_a_declined_weapons_bundle_resets_starve() -> void:
	# Arrange: floor 2 offered a weapons bundle and took something else
	var draft: RewardDraft = _fix.draft()
	var others: Array = _not_of_theme(WEAPONS)
	var run_state: RunState = _two_drafts(others.slice(0, OFFER_SIZE), [others[OFFER_SIZE], _of_theme(WEAPONS)[0], others[OFFER_SIZE + 1]])

	# Act
	var fired: int = _count_flag(draft, run_state, PITY)

	# Assert
	assert_int(fired).is_equal(0)


func test_a_pivot_moves_d_and_no_pity_fires_for_the_old_theme() -> void:
	# Arrange: two aggro bundles taken, the second offered on floor 2. AC-16 says aggro 8
	# against weapons 3; a shipped aggro card also carries `weapons`, so the real deck is 8 to 4
	var draft: RewardDraft = _fix.draft()
	var aggro: Array = _of_theme(AGGRO)
	var others: Array = _not_of_theme(WEAPONS)
	var run_state: RunState = _two_drafts([aggro[0], others[0], others[1]], [aggro[1], others[2], others[3]])
	var counts: Dictionary = draft.deck_tag_counts(run_state.deck)
	var plan_tags: Array = Heroes.new(_fix.db).plan_tags(DraftHarness.HERO_ID)

	# Act
	var fired: int = _count_flag(draft, run_state, PITY)

	# Assert
	assert_int(int(counts[AGGRO])).is_equal(8)
	assert_int(int(counts[WEAPONS])).is_less(int(counts[AGGRO]))
	assert_str(draft.dominant_theme(plan_tags, counts)).is_equal(AGGRO)
	assert_int(draft.starve_count(run_state, WEAPONS)).is_equal(2)
	assert_int(fired).is_equal(0)


func test_a_tie_goes_to_the_earlier_plan_tag() -> void:
	# Arrange
	var plan_tags: Array = Heroes.new(_fix.db).plan_tags(DraftHarness.HERO_ID)

	# Act
	var dominant: String = _fix.draft().dominant_theme(plan_tags, {WEAPONS: 3, AGGRO: 3})

	# Assert
	assert_str(dominant).is_equal(WEAPONS)


func test_the_war_starter_has_weapons_dominant_at_three_two_two() -> void:
	# Act
	var counts: Dictionary = _fix.draft().deck_tag_counts(Array(_fix.state().deck))

	# Assert: Heroes H-4
	assert_int(int(counts[WEAPONS])).is_equal(3)
	assert_int(int(counts[AGGRO])).is_equal(2)
	assert_int(int(counts["armour"])).is_equal(2)


func test_starve_counts_only_consecutive_bundle_drafts_from_the_latest() -> void:
	# Arrange: a weapons offer on floor 1, then two without, with a treasure draft between
	var draft: RewardDraft = _fix.draft()
	var others: Array = _not_of_theme(WEAPONS)
	var run_state: RunState = _fix.state(4)
	_fix.take_bundle(run_state, [_of_theme(WEAPONS)[0], others[0], others[1]], others[0], 1)
	_fix.take_bundle(run_state, [others[2], others[3], others[4]], others[2], 2)
	run_state.drafts.append(DraftRecord.make(3, DraftRecord.KIND_TREASURE, ["t"], "t", []))
	_fix.take_bundle(run_state, [others[5], others[6], others[7]], others[5], 3)

	# Act
	var starve: int = draft.starve_count(run_state, WEAPONS)

	# Assert
	assert_int(starve).is_equal(2)


# --- AC-18, AC-19: coverage --------------------------------------------------

func test_p14_never_offers_three_of_one_theme_and_coverage_marks_exactly_the_shared_draws() -> void:
	# Arrange
	var over: DraftHarness.PoolDb = _fix.pool_db(_fix.p14())
	var draft: RewardDraft = _fix.draft({}, over)
	var run_state: RunState = _fix.state()
	var candidates: Array = DraftHarness.ids_of(_fix.p14())
	var wrong: Array = []
	var forced: int = 0

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		var stream := DraftHarness.RecordingStream.new("draft_1", RngService.stream_seed_for(run_seed, "draft_1"))
		var offer: Offer = draft.offer(BUNDLE, run_state, stream)
		var left: Array = candidates.duplicate()
		var first: String = left.pop_at(stream.indices[0])
		var second: String = left.pop_at(stream.indices[1])
		var shared: bool = _theme(first) == _theme(second)
		forced += 1 if shared else 0
		if offer.flags.has(COVERAGE) != shared:
			wrong.append(run_seed)
		var themes: Dictionary = {}
		for id: String in offer.option_ids:
			themes[_theme(id)] = true
		if themes.size() == 1:
			wrong.append(run_seed)

	# Assert
	assert_array(wrong).is_empty()
	assert_int(forced).is_greater(0)


func test_one_theme_in_the_pool_gives_three_of_it_with_no_coverage_flag() -> void:
	# Arrange
	var weapons: Array = _fix.p20().filter(func(b: Dictionary) -> bool: return b.theme == WEAPONS)
	var over: DraftHarness.PoolDb = _fix.pool_db(weapons)
	var draft: RewardDraft = _fix.draft({}, over)

	# Act
	var offer: Offer = draft.offer(BUNDLE, _fix.state(), DraftHarness.stream(SEED, 1))

	# Assert
	assert_int(offer.option_ids.size()).is_equal(OFFER_SIZE)
	assert_bool(offer.flags.has(COVERAGE)).is_false()


func test_pity_with_no_candidate_of_d_is_absent_and_the_offer_is_still_full() -> void:
	# Arrange: a pool with no weapons bundle at all
	var neutrals: Array = _fix.p20().filter(func(b: Dictionary) -> bool: return b["set"] == DraftHarness.NEUTRAL_SET)
	var over: DraftHarness.PoolDb = _fix.pool_db(neutrals)
	var draft: RewardDraft = _fix.draft({}, over)
	var run_state: RunState = _starved_state()

	# Act
	var offer: Offer = draft.offer(BUNDLE, run_state, DraftHarness.stream(SEED, 3))

	# Assert
	assert_bool(offer.flags.has(PITY)).is_false()
	assert_int(offer.option_ids.size()).is_equal(OFFER_SIZE)


# --- AC-20, AC-21: the weights -----------------------------------------------

func _bundle_with_costs(costs: Array, theme: String, over: DraftHarness.PoolDb) -> Dictionary:
	var cards: Array = []
	for i: int in costs.size():
		var id: String = "fixture_%s_%d" % [theme, i]
		over.extra[id] = {"id": id, "cost": costs[i], "tags": []}
		cards.append(id)
	return {"id": "fixture_bundle_%s" % theme, "theme": theme, "cards": cards}


func test_the_f1_example_weighs_180_175_150_100_70() -> void:
	# Arrange: War starter counts, the example's average costs
	var over := DraftHarness.PoolDb.new(_fix.db)
	var draft: RewardDraft = _fix.draft({}, over)
	var counts: Dictionary = {WEAPONS: 3, AGGRO: 2, "armour": 2}
	var bundles: Array = [
		_bundle_with_costs([2, 2, 2], AGGRO, over),
		_bundle_with_costs([2, 3, 3], WEAPONS, over),
		_bundle_with_costs([3, 3, 4], "armour", over),
		_bundle_with_costs([3, 3, 3], "taunt", over),
		_bundle_with_costs([5, 5, 6], "giants", over),
	]

	# Act
	var weights: Array = bundles.map(func(b: Dictionary) -> int: return draft.bundle_weight(b, 1, counts))

	# Assert
	assert_array(weights).is_equal([180, 175, 150, 100, 70])


func test_on_floor_seven_the_cap_holds_weapons_at_250_and_giants_are_130() -> void:
	# Arrange
	var over := DraftHarness.PoolDb.new(_fix.db)
	var draft: RewardDraft = _fix.draft({}, over)
	var counts: Dictionary = {WEAPONS: 9}

	# Act
	var weapons: int = draft.bundle_weight(_bundle_with_costs([2, 3, 3], WEAPONS, over), 3, counts)
	var giants: int = draft.bundle_weight(_bundle_with_costs([5, 5, 6], "giants", over), 3, counts)

	# Assert
	assert_int(weapons).is_equal(250)
	assert_int(giants).is_equal(130)


func test_a_cap_of_eight_moves_weapons_to_300_so_the_cap_is_data() -> void:
	# Arrange
	var over := DraftHarness.PoolDb.new(_fix.db)
	var draft: RewardDraft = _fix.draft({"affinity_cap": 8}, over)

	# Act
	var weight: int = draft.bundle_weight(_bundle_with_costs([2, 3, 3], WEAPONS, over), 3, {WEAPONS: 9})

	# Assert
	assert_int(weight).is_equal(300)


func test_the_cost_bucket_edges_are_inclusive_of_mid(costs: Array, expected: int, test_parameters := [
		[[2, 2, 3], 120], [[2, 3, 3], 100], [[4, 4, 4], 100], [[4, 4, 5], 70]]) -> void:
	# Arrange: 7/3 < 2.5 low; 8/3 mid; 4.0 mid; 13/3 > 4.0 high
	var over := DraftHarness.PoolDb.new(_fix.db)
	var draft: RewardDraft = _fix.draft({}, over)

	# Act
	var weight: int = draft.bundle_weight(_bundle_with_costs(costs, "edge", over), 1, {})

	# Assert
	assert_int(weight).is_equal(expected)


func test_a_weight_never_falls_below_one() -> void:
	# Arrange
	var over := DraftHarness.PoolDb.new(_fix.db)
	var draft: RewardDraft = _fix.draft({"base_weight": 0}, over)

	# Act
	var weight: int = draft.bundle_weight(_bundle_with_costs([3, 3, 3], "floor", over), 1, {})

	# Assert
	assert_int(weight).is_equal(1)


func test_every_shipped_bundle_is_weighed_inside_the_f1_range() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var deck_counts: Dictionary = {WEAPONS: 20, AGGRO: 20, "armour": 20}
	var bad: Array = []

	# Act
	for hero_set: String in ["war", "decay", "knowledge"]:
		for bundle: Dictionary in _fix.db.bundle_pool(hero_set):
			for band: int in [1, 2, 3]:
				var weight: int = draft.bundle_weight(bundle, band, deck_counts)
				if weight < 1 or weight > 325:
					bad.append([bundle.id, band, weight])

	# Assert
	assert_array(bad).is_empty()


func test_treasure_weights_are_105_70_45_30() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var plan_tags: Array = Heroes.new(_fix.db).plan_tags(DraftHarness.HERO_ID)
	var by_id: Dictionary = {}
	for record: Dictionary in DraftHarness.t10():
		by_id[record.id] = record

	# Act
	var affine_common: int = draft.treasure_weight(by_id.t10_w0, plan_tags)
	var plain_common: int = draft.treasure_weight(by_id.t10_u0, plan_tags)
	var affine_rare: int = draft.treasure_weight(by_id.t10_w2, plan_tags)
	var plain_rare: int = draft.treasure_weight(by_id.t10_u6, plan_tags)

	# Assert
	assert_array([affine_common, plain_common, affine_rare, plain_rare]).is_equal([105, 70, 45, 30])


func test_iron_constitution_is_universal_and_affine_for_war() -> void:
	# Arrange: F2's example, on the shipped record
	var draft: RewardDraft = _fix.draft()
	var plan_tags: Array = Heroes.new(_fix.db).plan_tags(DraftHarness.HERO_ID)
	var record: Dictionary = _fix.db.treasure(TreasureFixtures.CONSTITUTION)

	# Act
	var weight: int = draft.treasure_weight(record, plan_tags)

	# Assert
	assert_bool(Array(record.tags).has(RewardDraft.UNIVERSAL_TAG)).is_true()
	assert_int(weight).is_equal(int(_fix.config().treasure_rarity_weights[record.rarity]) * 3 / 2)


# --- AC-22, AC-23 ------------------------------------------------------------

## The ids a stream that always takes one end of the list draws (D6): [param take] is
## `pop_front` or `pop_back` of the candidates, slot 3 restricted by coverage.
func _expected_ends(candidates: Array, front: bool) -> Array:
	var left: Array = candidates.duplicate()
	var drawn: Array = [left.pop_front() if front else left.pop_back(), left.pop_front() if front else left.pop_back()]
	if _theme(drawn[0]) == _theme(drawn[1]):
		left = left.filter(func(id: String) -> bool: return _theme(id) != _theme(drawn[0]))
	drawn.append(left.pop_front() if front else left.pop_back())
	drawn.sort()
	return drawn


func test_a_zero_stub_takes_the_id_first_candidate_of_each_slot() -> void:
	# Arrange
	var over: DraftHarness.PoolDb = _fix.pool_db(_fix.p14())
	var draft: RewardDraft = _fix.draft({}, over)

	# Act
	var offer: Offer = draft.offer(BUNDLE, _fix.state(), TestRngStream.constant("draft_1", 0))

	# Assert
	assert_array(Array(offer.option_ids)).is_equal(_expected_ends(DraftHarness.ids_of(_fix.p14()), true))


func test_a_top_stub_takes_the_id_last_candidate_of_each_slot() -> void:
	# Arrange
	var over: DraftHarness.PoolDb = _fix.pool_db(_fix.p14())
	var draft: RewardDraft = _fix.draft({}, over)

	# Act
	var offer: Offer = draft.offer(BUNDLE, _fix.state(), DraftHarness.TopStream.new("draft_1", 1))

	# Assert
	assert_array(Array(offer.option_ids)).is_equal(_expected_ends(DraftHarness.ids_of(_fix.p14()), false))


func test_every_t10_offer_holds_a_universal_and_rares_are_15_to_30_percent_of_free_slots() -> void:
	# Arrange
	var over: DraftHarness.PoolDb = _fix.t10_db()
	var draft: RewardDraft = _fix.draft({}, over)
	var records: Array = DraftHarness.t10()
	var pool: Array = DraftHarness.ids_of(records)
	var run_state: RunState = _fix.state(1, pool)
	var bad: Array = []
	var free_slots: int = 0
	var rares: int = 0

	# Act
	for run_seed: int in range(1, TREASURE_SEEDS + 1):
		var stream := DraftHarness.RecordingStream.new("draft_1", RngService.stream_seed_for(run_seed, "draft_1"))
		var offer: Offer = draft.offer(TREASURE, run_state, stream)
		var universal: Array = pool.filter(func(id: String) -> bool: return Array(over.treasure(id).tags).has(RewardDraft.UNIVERSAL_TAG))
		if not offer.flags.has(UNIVERSAL_FORCED) or not Array(offer.option_ids).any(func(id: String) -> bool: return universal.has(id)):
			bad.append(run_seed)
		var left: Array = pool.duplicate()
		left.erase(universal[stream.indices[0]])
		for slot: int in [1, 2]:
			var id: String = left.pop_at(stream.indices[slot])
			free_slots += 1
			rares += 1 if over.treasure(id).rarity == "rare" else 0

	# Assert
	var share: float = float(rares) / float(free_slots)
	assert_array(bad).is_empty()
	assert_float(share).is_between(RARE_SHARE_LOW, RARE_SHARE_HIGH)


func test_every_shipped_treasure_offer_holds_a_universal() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var run_state: RunState = _fix.state(1, _fix.real_pool())
	var bad: Array = []

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		var offer: Offer = draft.offer(TREASURE, run_state, DraftHarness.stream(run_seed, 1))
		if not Array(offer.option_ids).any(func(id: String) -> bool: return Array(_fix.db.treasure(id).tags).has(RewardDraft.UNIVERSAL_TAG)):
			bad.append(run_seed)

	# Assert
	assert_array(bad).is_empty()


func test_no_universal_left_flags_universal_missing_and_still_offers() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft({}, _fix.t10_db())
	var war_only: Array = ["t10_w0", "t10_w1", "t10_w2"]

	# Act
	var offer: Offer = draft.offer(TREASURE, _fix.state(1, war_only), DraftHarness.stream(SEED, 1))

	# Assert
	assert_bool(offer.flags.has(UNIVERSAL_MISSING)).is_true()
	assert_bool(offer.flags.has(UNIVERSAL_FORCED)).is_false()
	assert_int(offer.option_ids.size()).is_equal(OFFER_SIZE)


func test_universal_slot_off_forces_nothing() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft({"universal_slot": false}, _fix.t10_db())

	# Act
	var offer: Offer = draft.offer(TREASURE, _fix.state(1, DraftHarness.ids_of(DraftHarness.t10())), DraftHarness.stream(SEED, 1))

	# Assert
	assert_bool(offer.flags.has(UNIVERSAL_FORCED)).is_false()
	assert_bool(offer.flags.has(UNIVERSAL_MISSING)).is_false()


func test_the_read_model_shows_hint_numbers_and_never_a_weight() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()

	# Act
	var offer: Offer = draft.offer(BUNDLE, _fix.state(), DraftHarness.stream(SEED, 1))
	var model: Dictionary = offer.read_model(TestConstants.STARTER_DECK_SIZE, TestConstants.BUNDLE_CARD_COUNT, draft.allows_skip())

	# Assert
	assert_int(int(model.deck_size_after)).is_equal(TestConstants.STARTER_DECK_SIZE + TestConstants.BUNDLE_CARD_COUNT)
	assert_array((model.options as Array).map(func(row: Dictionary) -> Array: return row.keys())[0]).contains_exactly_in_any_order(["id", "theme", "n_tag"])
	assert_bool(model.allow_skip).is_false()
