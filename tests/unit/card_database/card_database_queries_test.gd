## Unit tests for the CR-6 queries and `config(name)` on a `Ready` database
## (story card-database/story-006; card-database CR-6, Formulas "Lookup",
## States table; ADR-0002 Decisions 5-6).
##
## Fixture `pools/`: 4 War cards (`war_recruit` is the token), 3 neutral, 2
## boss-set cards; heroes `hero_war` and the locked `hero_decay`; bosses in
## bands 1 and 2; treasures and bundles. Every definition file lists its
## records out of id order on purpose, so an id-ascending result cannot come
## from file order. `pools/` carries every manifest config file (copied from
## `clean/`), so it is also the AC-3 root. Validators are `ValidatorStubs`
## stubs injected explicitly, never `Boot`; the fixture root is read-only.
extends GdUnitTestSuite

const ROOT: String = "res://tests/fixtures/data/pools/"
## Every CR-1 config name (DD-T01 config rows, CR-1 table order).
const CONFIG_NAMES: Array[String] = [
	"match_rules", "card_effects", "ai_profiles", "run_structure", "reward_draft",
	"treasures_balance", "heroes_balance", "match_ui", "run_ui", "profile_defaults",
	"card_database", "content_budgets", "rng_event_log",
]


func _ready_db() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(ROOT))
	db.load(ValidatorStubs.accept_all())
	GameAssertions.fail_if(db.state() != CardDatabase.State.READY, "pools/ did not load:\n%s" % db.report().to_text())
	return db


func _ids(records: Array) -> Array:
	return records.map(func(r: Dictionary) -> String: return r.id)


# --- AC-1: pools and filters, id-ascending ---------------------------------------

func test_collectible_pool_war_is_the_six_non_token_war_and_neutral_cards_by_id() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act
	var pool: Array = db.collectible_pool("war")

	# Assert — the token and both boss-set cards are out; id order, not file order
	assert_array(_ids(pool)).is_equal([
		"neutral_bat", "neutral_mage", "neutral_ogre", "war_axe", "war_banner", "war_zealot",
	])


func test_collectible_pool_of_a_set_without_cards_is_the_neutral_cards() -> void:
	# Act / Assert — `decay` has a hero and an empty set file
	assert_array(_ids(_ready_db().collectible_pool("decay"))).is_equal(["neutral_bat", "neutral_mage", "neutral_ogre"])


func test_collectible_pool_never_includes_boss_cards() -> void:
	# Act
	var pool: Array = _ready_db().collectible_pool("boss")

	# Assert — `set ∈ {hero_set, neutral}` with `boss` never included (CR-6)
	assert_array(_ids(pool)).is_equal(["neutral_bat", "neutral_mage", "neutral_ogre"])


func test_cards_by_set_includes_the_token_by_id() -> void:
	assert_array(_ids(_ready_db().cards_by_set("war"))).is_equal(["war_axe", "war_banner", "war_recruit", "war_zealot"])


func test_cards_by_type_includes_the_token_by_id() -> void:
	assert_array(_ids(_ready_db().cards_by_type("minion"))).is_equal(["neutral_bat", "neutral_ogre", "war_recruit", "war_zealot"])


func test_cards_by_tag_includes_the_token_by_id() -> void:
	assert_array(_ids(_ready_db().cards_by_tag("steel"))).is_equal(["war_axe", "war_banner", "war_recruit", "war_zealot"])


func test_cards_by_cost_spans_every_set_by_id() -> void:
	assert_array(_ids(_ready_db().cards_by_cost(2))).is_equal(["boss_claw", "neutral_ogre", "war_axe", "war_banner"])


func test_cards_by_rarity_includes_the_token_by_id() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act / Assert
	assert_array(_ids(db.cards_by_rarity("common"))).is_equal([
		"boss_claw", "boss_skull", "neutral_bat", "neutral_ogre", "war_axe", "war_recruit",
	])
	assert_array(_ids(db.cards_by_rarity("rare"))).is_equal(["neutral_mage", "war_zealot"])


func test_bundle_pool_is_the_hero_set_and_neutral_bundles_by_id() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act / Assert
	assert_array(_ids(db.bundle_pool("war"))).is_equal([
		"bundle_neutral_fen", "bundle_neutral_moor", "bundle_neutral_wild", "bundle_war_anvil", "bundle_war_steel",
	])
	assert_array(_ids(db.bundle_pool("decay"))).is_equal(["bundle_neutral_fen", "bundle_neutral_moor", "bundle_neutral_wild"])


func test_treasure_pool_is_every_treasure_by_id() -> void:
	assert_array(_ids(_ready_db().treasure_pool())).is_equal(["treasure_alpha", "treasure_beta", "treasure_gamma"])


func test_bosses_in_band_are_that_band_by_id() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act / Assert — bosses.json lists boss_zed, boss_mid, boss_alpha
	assert_array(_ids(db.bosses_in_band(1))).is_equal(["boss_alpha", "boss_mid"])
	assert_array(_ids(db.bosses_in_band(2))).is_equal(["boss_zed"])
	assert_array(db.bosses_in_band(3)).is_empty()


func test_heroes_include_the_locked_hero_by_id() -> void:
	# Act
	var heroes: Array = _ready_db().heroes()

	# Assert — heroes.json lists hero_war before hero_decay; hero_decay has an unlock
	assert_array(_ids(heroes)).is_equal(["hero_decay", "hero_war"])
	assert_that(heroes[0].unlock).is_not_null()


func test_precomputed_pools_are_the_same_frozen_array_on_every_call() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act / Assert — a lookup at freeze, not a filter per call
	assert_bool(is_same(db.collectible_pool("war"), db.collectible_pool("war"))).is_true()
	assert_bool(is_same(db.bundle_pool("war"), db.bundle_pool("war"))).is_true()
	assert_bool(is_same(db.treasure_pool(), db.treasure_pool())).is_true()
	assert_bool(is_same(db.bosses_in_band(1), db.bosses_in_band(1))).is_true()
	assert_bool(is_same(db.heroes(), db.heroes())).is_true()


# --- AC-2: lookups ---------------------------------------------------------------

func test_card_for_a_known_id_is_records_at_index_of_and_the_same_instance_each_call() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()
	var at: Dictionary = db._snapshot.index_of["war_banner"]

	# Act
	var first: Variant = db.card("war_banner")
	var second: Variant = db.card("war_banner")

	# Assert — Formulas "Lookup": records[index_of[id]], no copy
	assert_str(at.type).is_equal("CardDef")
	assert_bool(is_same(first, db._snapshot.records_by_type.CardDef[at.position])).is_true()
	assert_bool(is_same(first, second)).is_true()
	assert_str(first.id).is_equal("war_banner")


func test_each_typed_lookup_returns_its_own_record_type() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act / Assert
	assert_str(db.hero("hero_decay").set).is_equal("decay")
	assert_int(int(db.hero_power("power_rot").cost)).is_equal(2)
	assert_int(int(db.boss("boss_zed").band)).is_equal(2)
	assert_str(db.treasure("treasure_beta").unlock.key).is_equal("first_victory")
	assert_str(db.bundle("bundle_war_anvil").theme).is_equal("steel")


func test_has_is_true_for_any_record_type_and_false_for_an_unknown_id() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act / Assert
	assert_bool(db.has("war_recruit")).is_true()
	assert_bool(db.has("hero_decay")).is_true()
	assert_bool(db.has("bundle_neutral_wild")).is_true()
	assert_bool(db.has("no_such_id")).is_false()


## Runs [param call] and asserts the unknown-id report: one push_error with
## [param message] in a release build; in a debug build the assert that
## follows that push_error in the same function (CardDatabase._unknown_record),
## which the runner reports as the script error — so the assert firing also
## proves the push_error ran.
func _assert_unknown_id_reported(call: Callable, message: String) -> void:
	if OS.is_debug_build():
		await assert_error(call).is_runtime_error("Assertion failed: " + message)
	else:
		await assert_error(call).is_push_error(message)


func test_card_for_an_unknown_id_returns_null_logs_and_asserts_in_debug() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()
	var box: Dictionary = {"value": "untouched"}

	# Act / Assert — the assert sits beside the push_error, so release still
	# returns null (and so does debug: the assert aborts only the helper)
	await _assert_unknown_id_reported(func() -> void: box.value = db.card("no_such_id"),
		"CardDatabase.card(): no CardDef \"no_such_id\"")
	assert_that(box.value).is_null()


func test_typed_lookup_of_an_id_of_another_type_returns_null() -> void:
	# Arrange — war_axe exists, but it is a CardDef
	var db: CardDatabase = _ready_db()
	var box: Dictionary = {"value": "untouched"}

	# Act / Assert
	await _assert_unknown_id_reported(func() -> void: box.value = db.hero("war_axe"),
		"CardDatabase.hero(): no HeroDef \"war_axe\"")
	assert_that(box.value).is_null()


# --- AC-3: config(name) ----------------------------------------------------------

func test_config_serves_every_manifest_config_as_a_frozen_dictionary() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act / Assert
	for config_name: String in CONFIG_NAMES:
		var body: Variant = db.config(config_name)
		assert_bool(body is Dictionary).override_failure_message(config_name).is_true()
		assert_bool((body as Dictionary).is_read_only()).override_failure_message(config_name).is_true()


func test_config_names_cover_every_manifest_config_row() -> void:
	# Arrange — the test's list must not silently miss a manifest row
	var manifest: Array = []
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		if row["class"] == "config":
			manifest.append(String(row.name).get_basename())

	# Assert
	assert_array(manifest).is_equal(CONFIG_NAMES)


func test_config_is_the_same_body_on_every_call() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act / Assert — owners read it once and keep the reference
	assert_bool(is_same(db.config("match_rules"), db.config("match_rules"))).is_true()
	assert_array(Array(db.config("match_rules").boss_starting_health_by_band).map(func(v: Variant) -> int: return int(v))) \
		.is_equal([30, 40, 50])


func test_config_of_an_unknown_name_returns_null_with_one_logged_error() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()
	var box: Dictionary = {"value": "untouched"}

	# Act / Assert
	await assert_error(func() -> void: box.value = db.config("no_such")) \
		.is_push_error("CardDatabase.config(): no config file \"no_such.json\"")
	assert_that(box.value).is_null()
