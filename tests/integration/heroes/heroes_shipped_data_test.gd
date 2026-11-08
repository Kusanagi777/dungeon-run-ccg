## Integration: the `Heroes` accessor over the shipped `res://assets/data/` (heroes
## story 002 AC-2, AC-3, AC-4; heroes.md AC-1, AC-6, H-4, H-5; content CN-6, DD-H06).
##
## Loads through the real `DataLoader` and `CardDatabase` with the validator map
## `Boot` composes (a fresh, `auto_free`d Boot instance, never the autoload; debug
## severity). The structural rules these tests observe live in `DataLoader` stage
## 6: this suite asserts them through the accessor and adds no second validator.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SHIPPED_ROOT: String = "res://assets/data/"

const HERO_WAR: String = "hero_war"
const HERO_UNKNOWN: String = "hero_not_in_the_data"
## A shipped id that is a CardDef and no HeroDef.
const CARD_ID: String = "war_rusted_axe"
## Heroes H-5, War's theme tags, in `heroes_balance.json` order (AC-2).
const WAR_PLAN_TAGS: Array = ["weapons", "aggro", "armour", "berserk", "pack", "salvage"]
## H-1: a starter is its hero's set or neutral.
const WAR_STARTER_SETS: Array = ["war", "neutral"]
## The two tokens of heroes AC-6, and every set present in the shipped data.
const TOKENS: Array = ["decay_husk", "war_whetstone_blade"]
const SETS_PRESENT: Array = ["war", "neutral", "decay", "boss"]


func _map() -> Dictionary:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	return boot._collect_validators(null, true)


func _loaded() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
	db.load(_map())
	return db


func _ids(records: Array) -> Array:
	return records.map(func(r: Dictionary) -> String: return str(r.id))


# --- AC-2 ----------------------------------------------------------------------------

func test_plan_tags_of_war_are_the_shipped_list() -> void:
	# Arrange
	var heroes: Heroes = Heroes.new(_loaded())

	# Act
	var tags: Array = heroes.plan_tags(HERO_WAR)

	# Assert
	assert_array(tags).is_equal(WAR_PLAN_TAGS)


func test_plan_tags_of_an_id_of_another_record_type_logs_and_returns_empty() -> void:
	# Arrange — `has` is true for any record type; `hero` would assert on this one
	var heroes: Heroes = Heroes.new(_loaded())
	var box: Dictionary = {"value": ["untouched"]}

	# Act
	await assert_error(func() -> void: box.value = heroes.plan_tags(CARD_ID)) \
		.is_push_error("Heroes.plan_tags(): no HeroDef \"%s\"" % CARD_ID)

	# Assert
	assert_array(box.value).is_empty()


# --- AC-3 (GDD AC-1, MVP-0 batch) ----------------------------------------------------

func test_the_shipped_data_loads_with_no_error() -> void:
	# Act
	var db: CardDatabase = _loaded()

	# Assert — error severity: a pending validator is `E_DELEGATED` at warning
	# severity in a debug build (`boot_validator_map_test.gd`), which is not a fault
	assert_array(db.report().errors()).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_launch_heroes_on_shipped_data_are_the_three_of_h2() -> void:
	# Arrange
	var heroes: Heroes = Heroes.new(_loaded())

	# Act
	var launch: Array = heroes.launch_heroes()

	# Assert
	assert_array(_ids(launch)).contains_exactly_in_any_order([HERO_WAR, "hero_decay", "hero_knowledge"])
	for hero: Dictionary in launch:
		assert_int(int(hero.health)).override_failure_message(str(hero.id)).is_equal(TestConstants.PLAYER_STARTING_HEALTH)


func test_wars_hero_power_resolves_through_the_database() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var heroes: Heroes = Heroes.new(db)

	# Act
	var power_id: String = str(heroes.hero(HERO_WAR).hero_power)

	# Assert
	assert_bool(db.has(power_id)).is_true()
	assert_str(str(db.hero_power(power_id).id)).is_equal(power_id)


func test_wars_starter_is_15_non_token_cards_of_its_set_or_neutral() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var heroes: Heroes = Heroes.new(db)

	# Act
	var starter: Array = Array(heroes.hero(HERO_WAR).starter_deck)

	# Assert
	assert_int(starter.size()).is_equal(TestConstants.STARTER_DECK_SIZE)
	for card_id: Variant in starter:
		var card: Dictionary = db.card(str(card_id))
		assert_bool(bool(card.get("token", false))).override_failure_message("%s is a token" % card_id).is_false()
		assert_array(WAR_STARTER_SETS).contains([str(card.set)])


func test_hero_of_an_unknown_id_is_null_as_the_database_answers() -> void:
	# Arrange
	var heroes: Heroes = Heroes.new(_loaded())
	var box: Dictionary = {"value": "untouched"}
	var message: String = "CardDatabase.hero(): no HeroDef \"%s\"" % HERO_UNKNOWN

	# Act — `db.hero` logs and, in a debug build, asserts beside the log (CR-6)
	var call: Callable = func() -> void: box.value = heroes.hero(HERO_UNKNOWN)
	if OS.is_debug_build():
		await assert_error(call).is_runtime_error("Assertion failed: " + message)
	else:
		await assert_error(call).is_push_error(message)

	# Assert
	assert_that(box.value).is_null()


# --- AC-4 (GDD AC-6) -----------------------------------------------------------------

func test_the_tokens_are_shipped_as_tokens() -> void:
	# Arrange — without these the two pool tests below would pass on absent ids
	var db: CardDatabase = _loaded()

	# Act / Assert
	for token: String in TOKENS:
		assert_bool(db.has(token)).override_failure_message("%s is not shipped" % token).is_true()
		assert_bool(bool(db.card(token).get("token", false))).override_failure_message("%s is no token" % token).is_true()


func test_no_token_is_in_any_collectible_pool() -> void:
	# Arrange
	var db: CardDatabase = _loaded()

	# Act / Assert
	for set_id: String in SETS_PRESENT:
		var pool: Array = _ids(db.collectible_pool(set_id))
		for token: String in TOKENS:
			assert_bool(pool.has(token)).override_failure_message("%s in collectible_pool(%s)" % [token, set_id]).is_false()


func test_no_token_is_in_any_bundle_pool() -> void:
	# Arrange
	var db: CardDatabase = _loaded()

	# Act / Assert
	for set_id: String in SETS_PRESENT:
		for bundle: Dictionary in db.bundle_pool(set_id):
			for token: String in TOKENS:
				assert_bool(Array(bundle.cards).has(token)).override_failure_message("%s in bundle %s" % [token, bundle.id]).is_false()
