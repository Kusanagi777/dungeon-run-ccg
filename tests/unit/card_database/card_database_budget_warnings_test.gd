## Unit tests for CR-5 stage 8, budget warnings and pool thresholds (story
## card-database/story-005; card-database CR-5 step 8, Formulas "Collectible
## pool size", "Bundle pool size", "Minimum treasure pool", Edge Cases;
## ADR-0002 Decision 3).
##
## Every threshold comes from data: the four `card_database.json` knobs, and
## the inputs other owners hold — `run_structure.json` `floors_per_run` /
## `treasure_floors` (treasure drafts per run, Run Structure), `reward_draft.json`
## `treasure_offers_per_draft` (Reward Draft), `match_rules.json`
## `boss_starting_health_by_band` (registry source: match-rules). `clean/`
## carries all of them (War collectible pool 11, bundle pool 3, 9 treasures
## unlocked by default, bosses at their band defaults) and loads with an empty
## report; each other root changes the one input its test names. Read-only
## fixture roots through an injected `DataLoader` root; validators are
## `ValidatorStubs.accept_all()`.
extends GdUnitTestSuite

const FIXTURES: String = "res://tests/fixtures/data/"


func _load(case_name: String) -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(FIXTURES + case_name))
	db.load(ValidatorStubs.accept_all())
	return db


func _with(report: ValidationReport, code: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if e.code == code:
			out.append(e)
	return out


# --- AC-1: treasure and collectible pools ------------------------------------------

func test_eight_default_unlocked_treasures_warn_8_below_9_and_stay_ready() -> void:
	# Act
	var db: CardDatabase = _load("pool_treasures")

	# Assert — 3 treasure floors below floors_per_run × 3 offers = 9
	var hits: Array[Dictionary] = _with(db.report(), ValidationReport.W_POOL_SIZE)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].file).is_equal("treasures.json")
	assert_str(hits[0].message).contains("8 < 9")
	assert_str(String(hits[0].severity)).is_equal(String(ValidationReport.SEVERITY_WARNING))
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_collectible_pool_below_the_knob_names_set_found_and_threshold() -> void:
	# Act — war 7 non-token + neutral 4 = 11 < min_collectible_pool 20
	var db: CardDatabase = _load("pool_collectible")

	# Assert
	var hits: Array[Dictionary] = _with(db.report(), ValidationReport.W_POOL_SIZE)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].file).is_equal("cards_war.json")
	assert_str(hits[0].field).is_equal("min_collectible_pool")
	assert_str(hits[0].message).contains("war")
	assert_str(hits[0].message).contains("11 < 20")
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_tokens_are_not_counted_in_the_collectible_pool() -> void:
	# clean/ has 8 war cards, one a token (war_recruit): 7 + 4 = 11, so a
	# threshold of 11 is met exactly and raises nothing.
	assert_array(_load("pool_at_threshold").report().entries()).is_empty()


func test_mvp_sized_pool_of_40_is_clean_at_the_default_30() -> void:
	# Formulas example: MVP 25 + 15 = 40 ≥ 30, no warning.
	var db: CardDatabase = _load("pool_mvp_40")
	assert_array(db.report().entries()).is_empty()
	assert_int(db.collectible_pool("war").size()).is_equal(40)


# --- AC-2: bundle pools ---------------------------------------------------------------

func test_bundle_pool_of_2_is_e_count_below_the_hard_floor_3_and_fails() -> void:
	# Act — 2 war bundles, 0 neutral
	var db: CardDatabase = _load("pool_bundles_floor")

	# Assert
	var hits: Array[Dictionary] = _with(db.report(), ValidationReport.E_COUNT)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].file).is_equal("bundles.json")
	assert_str(hits[0].message).contains("war")
	assert_str(hits[0].message).contains("2")
	assert_str(hits[0].message).contains("hard floor 3")
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_bundle_pool_exactly_at_the_hard_floor_is_clean() -> void:
	# clean/: war 2 + neutral 1 = 3, min_bundle_pool 3
	assert_array(_with(_load("clean").report(), ValidationReport.E_COUNT)).is_empty()


func test_bundle_pool_of_5_below_min_bundle_pool_10_warns_and_stays_ready() -> void:
	# Act
	var db: CardDatabase = _load("pool_bundles_warn")

	# Assert
	var hits: Array[Dictionary] = _with(db.report(), ValidationReport.W_POOL_SIZE)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].file).is_equal("bundles.json")
	assert_str(hits[0].field).is_equal("min_bundle_pool")
	assert_str(hits[0].message).contains("5 < 10")
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_hard_floor_is_the_min_bundle_pool_range_floor() -> void:
	# Formulas: "3 is the hard floor for one draft (DD-R04)" — the knob's range floor.
	assert_int(int(RecordSchemas.KNOB_RANGES.min_bundle_pool[0])).is_equal(TestConstants.BUNDLE_CARD_COUNT)


# --- AC-3: empty set, band health, duplicate names --------------------------------------

func test_empty_decay_set_warns_w_empty_set_and_cards_by_set_is_empty() -> void:
	# Act
	var db: CardDatabase = _load("empty_set")

	# Assert
	var hits: Array[Dictionary] = _with(db.report(), ValidationReport.W_EMPTY_SET)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].file).is_equal("cards_decay.json")
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_array(db.cards_by_set("decay")).is_empty()


func test_boss_health_off_its_band_default_warns_naming_boss_found_and_default() -> void:
	# Act — boss_rot_warden, band 1, health 35
	var db: CardDatabase = _load("band_health")

	# Assert
	var hits: Array[Dictionary] = _with(db.report(), ValidationReport.W_BAND_HEALTH)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].record_id).is_equal("boss_rot_warden")
	assert_str(hits[0].field).is_equal("health")
	assert_str(hits[0].message).contains("35")
	assert_str(hits[0].message).contains("%d" % TestConstants.BOSS_STARTING_HEALTH_BY_BAND[0])
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_two_cards_sharing_a_name_warn_naming_both_ids() -> void:
	# Act
	var db: CardDatabase = _load("dup_name")

	# Assert
	var hits: Array[Dictionary] = _with(db.report(), ValidationReport.W_DUP_NAME)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("neutral_ember_hound")
	assert_str(hits[0].message).contains("war_shield_bearer")
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


# --- AC-4: knobs from data ----------------------------------------------------------------

func test_min_collectible_pool_99_over_a_40_card_pool_warns() -> void:
	var hits: Array[Dictionary] = _with(_load("knobs_99").report(), ValidationReport.W_POOL_SIZE)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("40 < 99")


func test_record_counts_are_not_capped_and_the_removed_max_records_knob_is_rejected() -> void:
	# Open-growth contract: the former 20-record cap no longer exists.
	var db: CardDatabase = _load("max_records")
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_int(db.report().record_count()).is_equal(31)
	assert_array(_with(db.report(), ValidationReport.E_COUNT)).is_empty()
	var body: Dictionary = db.config("card_database").duplicate(true)
	body["max_records"] = 20
	var report: ValidationReport = ValidationReport.new()
	assert_bool(RecordSchemas.check_card_database_config(body, report)).is_false()
	var hits: Array[Dictionary] = _with(report, ValidationReport.E_SCHEMA)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].field).is_equal("max_records")


func test_checks_whose_inputs_are_missing_announce_that_they_did_not_run() -> void:
	# Act — run_structure {} , reward_draft offers "three", match_rules {}
	var report: ValidationReport = _load("stage8_inputs_missing").report()

	# Assert — no silent pass: one "not checked" warning per skipped check
	var pool: Array[Dictionary] = _with(report, ValidationReport.W_POOL_SIZE)
	var band: Array[Dictionary] = _with(report, ValidationReport.W_BAND_HEALTH)
	assert_int(pool.size()).is_equal(1)
	assert_str(pool[0].message).contains("not checked")
	assert_str(pool[0].message).contains("run_structure")
	assert_str(pool[0].message).contains("reward_draft")
	assert_int(band.size()).is_equal(1)
	assert_str(band[0].message).contains("not checked")
	assert_str(band[0].message).contains("boss_starting_health_by_band")


func test_stage_8_holds_no_numeric_literal() -> void:
	# The only numeric constant in src/core/data/ stays SCHEMA_VERSION_CURRENT
	# (card_database_single_parser_test scans the scripts); this pins that the
	# thresholds move with the data: the same pool, two knob values, two outcomes.
	assert_array(_with(_load("pool_mvp_40").report(), ValidationReport.W_POOL_SIZE)).is_empty()
	assert_int(_with(_load("knobs_99").report(), ValidationReport.W_POOL_SIZE).size()).is_equal(1)
