## Reward Draft D3, D9, D11, F7, F8, Tuning Knobs: picks, events, the unlock snapshot,
## coherence and dilution (design/gdd/reward-draft.md AC-24 to AC-31).
extends GdUnitTestSuite

const BUNDLE: StringName = &"bundle"
const TREASURE: StringName = &"treasure"
const SEED: int = 42
const SEEDS: int = 1000
const OFFER_SIZE: int = 3
const HERO: String = DraftHarness.HERO_ID
const FOLLOWER_PLAN_SHARE: float = 0.60
const FOLLOWER_TOP_TAG_SHARE: float = 0.30
const RANDOM_PLAN_SHARE: float = 0.45
## F8 at a deck of 36.
const DECK_36: int = 36
const STARTER: int = TestConstants.STARTER_DECK_SIZE
const HAND: int = 3
const SEEN: int = 10
const TOLERANCE: float = 0.000000001
## F7's uniform baseline on P20, reported and not gated.
const P20_UNIFORM_BASELINE: float = 0.43
## From floor 5 for the rails metric (cross-review D-02).
const RAILS_FLOOR: int = 5
## The Tuning Knobs literals AC-31's gate looks for, with `reward_draft.gd` scanned as
## code: a value here outside a `const` or a `check_` line is a hardcoded knob.
const SOURCE: String = "res://src/gameplay/draft/reward_draft.gd"
const KNOB_LITERAL: String = "(?<![\\w.])(25|6|70|120|110|130|2\\.5|4\\.0|0\\.25)(?![\\w.])"

var _fix: DraftHarness = null


func before() -> void:
	_fix = DraftHarness.new(TreasureFixtures.shipped_database())


func after() -> void:
	_fix = null


func _logged(draft: RewardDraft) -> EventLog:
	var log := EventLog.new(RunHarness.MAX_EVENTS, EventLog.SCOPE_RUN)
	draft.set_run_log(log)
	return log


func _bundle_offer(draft: RewardDraft) -> Offer:
	return draft.offer(BUNDLE, _fix.state(), DraftHarness.stream(SEED, 1))


func _treasure_offer(draft: RewardDraft) -> Offer:
	return draft.offer(TREASURE, _fix.state(1, _fix.real_pool()), DraftHarness.stream(SEED, 1))


# --- AC-24 to AC-26 ----------------------------------------------------------

func test_a_bundle_pick_emits_one_draft_picked_with_its_cards_in_data_order() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var offer: Offer = _bundle_offer(draft)
	var log: EventLog = _logged(draft)
	var id: String = offer.option_ids[1]

	# Act
	var pick: Pick = draft.pick(BUNDLE, id, offer, _fix.state())

	# Assert
	var cards: Array = Array(_fix.db.bundle(id).cards)
	assert_int(pick.error).is_equal(OK)
	assert_array(Array(pick.card_ids_added)).is_equal(cards)
	assert_str(str(pick.picked_id)).is_equal(id)
	assert_int(pick.option_index).is_equal(1)
	assert_int(log.size()).is_equal(1)
	assert_dict(log.events_since(0)[0].payload).is_equal({"floor": 1, "kind": DraftRecord.KIND_BUNDLE, "picked_id": id, "option_index": 1, "card_ids_added": cards})


func test_a_treasure_pick_adds_no_cards_and_indexes_the_sorted_list() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var offer: Offer = _treasure_offer(draft)
	var log: EventLog = _logged(draft)

	# Act
	var pick: Pick = draft.pick(TREASURE, offer.option_ids[2], offer, _fix.state())

	# Assert
	assert_array(Array(pick.card_ids_added)).is_empty()
	assert_int(pick.option_index).is_equal(2)
	assert_array(log.events_since(0)[0].payload.card_ids_added).is_empty()


func test_the_runs_treasure_granted_follows_draft_picked_in_the_log() -> void:
	# Arrange: a real run, a real draft
	var game := RunRealFixture.new(_fix.db)
	game.boss_health = RunRealFixture.ONE_BLOW
	var run: RunMachine = game.machine(MetaStub.new(_fix.db))
	assert_int(run.new_run(HERO, "42")).is_equal(OK)
	game.play_out(run, game.begin(run))

	# Act
	assert_int(run.draft_pick(TREASURE, run.current_offer().option_ids[0])).is_equal(OK)

	# Assert
	var picked: int = int(RunHarness.events_of(run.run_log, RunCodes.EVENT_DRAFT_PICKED)[0].seq)
	assert_int(int(RunHarness.events_of(run.run_log, RunCodes.EVENT_TREASURE_GRANTED)[0].seq)).is_equal(picked + 1)
	game.release()


func test_a_null_pick_without_allow_skip_is_refused_with_no_event() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var offer: Offer = _bundle_offer(draft)
	var log: EventLog = _logged(draft)

	# Act
	var pick: Pick = draft.pick(BUNDLE, null, offer, _fix.state())

	# Assert
	assert_int(pick.error).is_equal(RunCodes.E_NOT_OFFERED)
	assert_int(log.size()).is_equal(0)


func test_a_null_pick_with_allow_skip_is_taken_and_adds_nothing() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft({"allow_skip": true})
	var offer: Offer = _bundle_offer(draft)
	var log: EventLog = _logged(draft)

	# Act
	var pick: Pick = draft.pick(BUNDLE, null, offer, _fix.state())

	# Assert
	assert_int(pick.error).is_equal(OK)
	assert_object(pick.picked_id).is_null()
	assert_array(Array(pick.card_ids_added)).is_empty()
	assert_object(log.events_since(0)[0].payload.picked_id).is_null()


func test_a_run_skipping_a_bundle_keeps_its_deck_and_stays_valid() -> void:
	# Arrange
	var game := RunRealFixture.new(_fix.db)
	game.boss_health = RunRealFixture.ONE_BLOW
	game.draft_overrides = {"allow_skip": true}
	var run: RunMachine = game.machine(MetaStub.new(_fix.db))
	assert_int(run.new_run(HERO, "42")).is_equal(OK)
	game.play_out(run, game.begin(run))
	assert_int(run.draft_pick(TREASURE, null)).is_equal(OK)

	# Act
	var answer: Error = run.draft_pick(BUNDLE, null)

	# Assert
	assert_int(answer).is_equal(OK)
	assert_int(run.state.deck.size()).is_equal(STARTER)
	assert_int(run.state.treasures.size()).is_equal(0)
	assert_int(run.state.floor).is_equal(2)
	assert_int(run.state.validate(_fix.db)).is_equal(OK)
	game.release()


func test_an_id_not_in_the_offer_is_refused_with_no_event() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var offer: Offer = _bundle_offer(draft)
	var log: EventLog = _logged(draft)

	# Act
	var pick: Pick = draft.pick(BUNDLE, "bundle_not_offered", offer, _fix.state())

	# Assert
	assert_int(pick.error).is_equal(RunCodes.E_NOT_OFFERED)
	assert_int(log.size()).is_equal(0)


func test_an_offered_id_that_no_longer_resolves_is_e_unknown_id() -> void:
	# Arrange
	var draft: RewardDraft = _fix.draft()
	var offer: Offer = Offer.new()
	offer.option_ids.assign(["bundle_gone"])
	var log: EventLog = _logged(draft)

	# Act
	var pick: Pick = draft.pick(BUNDLE, "bundle_gone", offer, _fix.state())

	# Assert
	assert_int(pick.error).is_equal(RunCodes.E_UNKNOWN_ID)
	assert_int(log.size()).is_equal(0)


# --- AC-27: the snapshot -----------------------------------------------------

func _locked_id() -> Dictionary:
	for def: Dictionary in _fix.db.treasure_pool():
		if def.unlock != null:
			return def
	return {}


func test_init_run_snapshots_the_unlocked_pool_id_sorted() -> void:
	# Arrange
	var locked: Dictionary = _locked_id()
	_fix.meta.keys = []

	# Act
	var state: Dictionary = _fix.draft().init_run(_fix.state())

	# Assert
	var pool: Array = state.treasure_pool
	var sorted: Array = pool.duplicate()
	sorted.sort()
	assert_int(int(state.schema_version)).is_equal(RewardDraft.DRAFT_STATE_SCHEMA_VERSION)
	assert_array(pool).is_equal(sorted)
	assert_bool(pool.has(locked.id)).is_false()
	assert_int(pool.size()).is_greater_equal(TestConstants.TREASURE_FLOORS.size() * OFFER_SIZE)


func test_a_treasure_unlocked_mid_run_stays_out_until_the_next_run() -> void:
	# Arrange
	var locked: Dictionary = _locked_id()
	_fix.meta.keys = []
	var draft: RewardDraft = _fix.draft()
	var run_state: RunState = _fix.state()
	run_state.draft_state = draft.init_run(run_state)
	var seen: int = 0

	# Act: unlocked after floor 1
	_fix.meta.keys = [locked.unlock.key]
	for run_seed: int in range(1, SEEDS + 1):
		for f: int in [3, 5]:
			run_state.floor = f
			if draft.offer(TREASURE, run_state, DraftHarness.stream(run_seed, f)).option_ids.has(locked.id):
				seen += 1
	var next_run: Dictionary = draft.init_run(_fix.state())
	_fix.meta.keys = []

	# Assert
	assert_int(seen).is_equal(0)
	assert_bool((next_run.treasure_pool as Array).has(locked.id)).is_true()


func test_draft_state_usability_takes_json_floats_and_refuses_the_rest() -> void:
	# Act
	var loaded: bool = RewardDraft.draft_state_is_usable({"schema_version": 1.0, "treasure_pool": []})
	var empty: bool = RewardDraft.draft_state_is_usable({})
	var wrong: bool = RewardDraft.draft_state_is_usable({"schema_version": 2, "treasure_pool": []})
	var no_pool: bool = RewardDraft.draft_state_is_usable({"schema_version": 1})

	# Assert
	assert_bool(loaded).is_true()
	assert_bool(empty).is_false()
	assert_bool(wrong).is_false()
	assert_bool(no_pool).is_false()


# --- AC-28 -------------------------------------------------------------------

func test_a_bundle_with_a_token_is_excluded_and_named_and_the_offer_is_still_full() -> void:
	# Arrange: a debug reload put a token in the first bundle
	var pool: Array = _fix.p20().duplicate(true)
	var broken: Dictionary = pool[0].duplicate(true)
	var over: DraftHarness.PoolDb = _fix.pool_db(pool)
	over.extra["token_card"] = {"id": "token_card", "cost": 1, "tags": [], "token": true}
	broken["cards"] = ["token_card", broken.cards[1], broken.cards[2]]
	pool[0] = broken
	over.extra[broken.id] = broken
	var draft: RewardDraft = _fix.draft({}, over)
	var log: EventLog = _logged(draft)
	var seen: int = 0

	# Act
	for run_seed: int in range(1, SEEDS + 1):
		var offer: Offer = draft.offer(BUNDLE, _fix.state(), DraftHarness.stream(run_seed, 1))
		seen += 1 if offer.option_ids.has(broken.id) or offer.option_ids.size() != OFFER_SIZE else 0
		if run_seed == 1:
			assert_str(str(RunHarness.warnings_of(log, RunCodes.W_BUNDLE_INVALID)[0].payload.detail.bundle_id)).is_equal(broken.id)
		draft.set_run_log(null)

	# Assert
	assert_int(seen).is_equal(0)


func test_a_bundle_of_the_wrong_size_or_with_a_missing_card_is_excluded() -> void:
	# Arrange
	var pool: Array = _fix.p20().duplicate(true)
	var short: Dictionary = pool[0].duplicate(true)
	short["cards"] = [short.cards[0]]
	var missing: Dictionary = pool[1].duplicate(true)
	missing["cards"] = ["card_gone", missing.cards[1], missing.cards[2]]
	pool[0] = short
	pool[1] = missing
	var over: DraftHarness.PoolDb = _fix.pool_db(pool)
	var draft: RewardDraft = _fix.draft({}, over)
	var log: EventLog = _logged(draft)

	# Act
	var offer: Offer = draft.offer(BUNDLE, _fix.state(), DraftHarness.stream(SEED, 1))

	# Assert
	assert_int(offer.option_ids.size()).is_equal(OFFER_SIZE)
	assert_int(RunHarness.warnings_of(log, RunCodes.W_BUNDLE_INVALID).size()).is_equal(2)


# --- AC-29: coherence --------------------------------------------------------

func _means(over: CardDatabase, policy: StringName) -> Dictionary:
	var draft: RewardDraft = _fix.draft({}, over)
	var plan_tags: Array = Heroes.new(_fix.db).plan_tags(HERO)
	var plan_total: float = 0.0
	var top_total: float = 0.0
	var late_drafts: int = 0
	var rails: int = 0
	for run_seed: int in range(1, SEEDS + 1):
		var sim: DraftHarness.SimResult = _fix.simulate(draft, run_seed, policy, over)
		var deck: Array = Array(sim.state.deck)
		plan_total += DraftAnalysis.plan_share(deck, plan_tags, _fix.db)
		top_total += DraftAnalysis.top_tag_share(deck, _fix.db)
		for offer: Offer in sim.offers:
			if offer.floor >= RAILS_FLOOR:
				late_drafts += 1
				if offer.flags.has(Offer.FLAG_COVERAGE_FORCED) and _off_plan_options(offer, plan_tags) == 1:
					rails += 1
	return {
		"plan_share": plan_total / float(SEEDS),
		"top_tag_share": top_total / float(SEEDS),
		"rails": float(rails) / float(maxi(late_drafts, 1)),
	}


func _off_plan_options(offer: Offer, plan_tags: Array) -> int:
	return Array(offer.option_ids).filter(func(id: String) -> bool: return not plan_tags.has(_fix.db.bundle(id).theme)).size()


func test_p14_follower_reaches_the_plan_and_top_tag_targets() -> void:
	# Act
	var means: Dictionary = _means(_fix.pool_db(_fix.p14()), DraftHarness.POLICY_FOLLOWER)
	print("AC-29 P14 follower: plan_share %.3f, top_tag_share %.3f, rails %.3f" % [means.plan_share, means.top_tag_share, means.rails])

	# Assert
	assert_float(float(means.plan_share)).is_greater_equal(FOLLOWER_PLAN_SHARE)
	assert_float(float(means.top_tag_share)).is_greater_equal(FOLLOWER_TOP_TAG_SHARE)


func test_p14_uniform_random_reaches_the_plan_target() -> void:
	# Act
	var means: Dictionary = _means(_fix.pool_db(_fix.p14()), DraftHarness.POLICY_RANDOM)
	print("AC-29 P14 uniform: plan_share %.3f, top_tag_share %.3f, rails %.3f" % [means.plan_share, means.top_tag_share, means.rails])

	# Assert
	assert_float(float(means.plan_share)).is_greater_equal(RANDOM_PLAN_SHARE)


func test_p20_follower_still_reaches_the_plan_target_and_reports_the_baseline() -> void:
	# Act
	var follower: Dictionary = _means(null, DraftHarness.POLICY_FOLLOWER)
	var uniform: Dictionary = _means(null, DraftHarness.POLICY_RANDOM)
	print("AC-29 P20 follower: plan_share %.3f, top_tag_share %.3f, rails %.3f" % [follower.plan_share, follower.top_tag_share, follower.rails])
	print("AC-29 P20 uniform: plan_share %.3f against the %.2f baseline (reported, not gated), rails %.3f" % [uniform.plan_share, P20_UNIFORM_BASELINE, uniform.rails])

	# Assert
	assert_float(float(follower.plan_share)).is_greater_equal(FOLLOWER_PLAN_SHARE)


# --- AC-30: F8 ---------------------------------------------------------------

func test_f8_at_a_deck_of_36() -> void:
	# Act
	var starter: float = DraftAnalysis.p_starter(DECK_36, STARTER)
	var no_starter: float = DraftAnalysis.p_no_starter_hand(DECK_36, STARTER, HAND)
	var seen: float = DraftAnalysis.p_card_seen(DECK_36, SEEN)

	# Assert
	assert_float(starter).is_equal_approx(15.0 / 36.0, TOLERANCE)
	assert_float(no_starter).is_equal_approx(1330.0 / 7140.0, TOLERANCE)
	assert_float(seen).is_equal_approx(10.0 / 36.0, TOLERANCE)


func test_f8_at_the_starter_size_is_all_starter() -> void:
	# Act
	var no_starter: float = DraftAnalysis.p_no_starter_hand(STARTER, STARTER, HAND)
	var expected: float = DraftAnalysis.expected_starter_seen(STARTER, STARTER, SEEN)

	# Assert
	assert_float(no_starter).is_equal_approx(0.0, TOLERANCE)
	assert_float(expected).is_equal_approx(float(SEEN), TOLERANCE)


func test_f7_shares_on_the_war_starter_are_seven_of_fifteen() -> void:
	# Arrange
	var deck: Array = Array(_fix.state().deck)
	var plan_tags: Array = Heroes.new(_fix.db).plan_tags(HERO)

	# Act
	var share: float = DraftAnalysis.plan_share(deck, plan_tags, _fix.db)

	# Assert
	assert_float(share).is_equal_approx(7.0 / 15.0, TOLERANCE)


# --- AC-31, Tuning Knobs: validate_config ------------------------------------

func test_the_shipped_config_passes_in_debug_and_release() -> void:
	# Act
	var debug: Array = RewardDraft.validate_config(_fix.config(), null, true)
	var release: Array = RewardDraft.validate_config(_fix.config(), null, false)

	# Assert
	assert_array(debug).is_empty()
	assert_array(release).is_empty()


func test_the_shipped_config_holds_exactly_the_knobs() -> void:
	# Act
	var keys: Array = _fix.config().keys()
	keys.sort()
	var known: Array = Array(RewardDraft.CONFIG_KEYS).duplicate()
	known.sort()

	# Assert
	assert_array(keys).is_equal(known)


func test_each_knob_past_its_safe_range_is_e_range(key: String, value: Variant, test_parameters := [
		["base_weight", 9], ["base_weight", 1001], ["affinity_step", 9], ["affinity_step", 51],
		["affinity_cap", 3], ["affinity_cap", 13], ["cost_low", 1.9], ["cost_low", 3.1],
		["cost_high", 3.4], ["cost_high", 5.1], ["pity_window", 0], ["pity_window", 5],
		["reoffer_after_floors", -1], ["reoffer_after_floors", 4], ["treasure_affinity", -1], ["treasure_affinity", 201],
		["bundle_offers_per_draft", 1], ["bundle_offers_per_draft", 5], ["treasure_offers_per_draft", 1], ["treasure_offers_per_draft", 5]]) -> void:
	# Arrange
	var body: Dictionary = _fix.config({key: value})

	# Act
	var rows: Array = RewardDraft.validate_config(body, null, true)

	# Assert
	assert_array(rows.map(func(row: Dictionary) -> String: return "%s:%s" % [row.code, row.field])).is_equal(["E_RANGE:%s" % key])


func test_a_band_multiplier_outside_50_to_200_is_e_range() -> void:
	# Arrange
	var body: Dictionary = _fix.config()
	body.band_cost_curve["2"][1] = 201

	# Act
	var rows: Array = RewardDraft.validate_config(body, null, true)

	# Assert
	assert_array(rows.map(func(row: Dictionary) -> String: return row.field)).is_equal(["band_cost_curve.2"])


func test_a_cost_curve_row_short_of_three_is_e_bad_value() -> void:
	# Arrange
	var body: Dictionary = _fix.config()
	body.band_cost_curve["3"] = [80, 100]

	# Act
	var rows: Array = RewardDraft.validate_config(body, null, true)

	# Assert
	assert_array(rows.map(func(row: Dictionary) -> StringName: return row.code)).is_equal([ConfigRows.E_BAD_VALUE])


func test_a_rarity_weight_missing_or_out_of_range_is_reported() -> void:
	# Arrange
	var body: Dictionary = _fix.config({"treasure_rarity_weights": {"common": 101}})

	# Act
	var rows: Array = RewardDraft.validate_config(body, null, true)

	# Assert
	var codes: Array = rows.map(func(row: Dictionary) -> String: return str(row.code))
	assert_bool(codes.has("E_RANGE")).is_true()
	assert_bool(codes.has(str(ValidationReport.E_MISSING_FIELD))).is_true()


func test_an_unknown_short_policy_is_e_bad_value() -> void:
	# Arrange
	var body: Dictionary = _fix.config({"treasure_short_policy": "refill"})

	# Act
	var rows: Array = RewardDraft.validate_config(body, null, true)

	# Assert
	assert_array(rows.map(func(row: Dictionary) -> StringName: return row.code)).is_equal([ConfigRows.E_BAD_VALUE])


func test_no_tuning_knob_is_a_literal_in_the_draft_code() -> void:
	# Arrange
	var pattern: RegEx = RegEx.create_from_string(KNOB_LITERAL)
	var hits: Array = []

	# Act
	var lines: PackedStringArray = FileAccess.get_file_as_string(SOURCE).split("\n")
	for i: int in lines.size():
		var code: String = lines[i].get_slice("#", 0).strip_edges()
		if code.begins_with("const ") or code.contains("ConfigRows.check"):
			continue
		if pattern.search(code) != null:
			hits.append("%d: %s" % [i + 1, code])

	# Assert
	assert_array(hits).is_empty()
