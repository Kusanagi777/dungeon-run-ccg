## Integration: the shipped data set boots and holds what content CN-1 says (card-database
## story 010 AC 1-2 and the static half of AC 3; content CN-1, CN-6 step 3, AC-3).
##
## AC 3's exported-build check is a documented smoke run, not this suite. The database is
## composed as `Boot` composes it, with its validator map, in debug severity. The expected
## counts are the one block below; CN-1 is the source of truth when the batch changes.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const EXPORT_PRESETS: String = "res://export_presets.cfg"
const WINDOWS_PRESET: String = "Windows Desktop"
const DATA_FILTER: String = "assets/data/*.json"

## CN-1, Alpha column.
const COLLECTIBLE_BY_SET: Dictionary = {"war": 25, "decay": 25, "knowledge": 25, "neutral": 45}
const TOKENS: int = 7
const BOSS_CARDS: int = 32
const BOSSES_BY_BAND: Dictionary = {1: 6, 2: 6, 3: 4}
const BUNDLES_BY_HERO_SET: Dictionary = {"war": 8, "decay": 8, "knowledge": 8}
const NEUTRAL_BUNDLES: int = 12
const TREASURES: int = 20
const HEROES: int = 3
## 3 hero + 4 boss.
const HERO_POWERS: Array[String] = [
	"power_whetstone", "power_rot", "power_insight",
	"power_mend", "power_drain", "power_reinforce", "power_brand",
]
const SETS: Array[String] = ["war", "decay", "knowledge", "neutral", "boss"]

var _db: CardDatabase = null


func before() -> void:
	_db = ShippedMatch.database()


func after() -> void:
	_db = null


func _is_token(card: Dictionary) -> bool:
	return card.get("token", false) == true


func _config_names() -> Array[String]:
	var names: Array[String] = []
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		if str(row.class) == "config":
			names.append(str(row.name).get_basename())
	return names


func test_shipped_data_loads_ready_with_no_error() -> void:
	# Assert
	assert_int(_db.state()).is_equal(CardDatabase.State.READY)
	assert_array(_db.report().errors()).is_empty()


func test_boot_on_shipped_data_ends_ready() -> void:
	# Arrange
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new(DataLoader.new(ShippedMatch.SHIPPED_ROOT))

	# Act
	var result: BootResult = boot.boot({"card_database": db, "meta": MetaStub.new(_db)})

	# Assert
	assert_bool(result.ok).is_true()
	assert_str(String(result.load_status)).is_equal("Ready")


func test_collectible_counts_equal_cn1() -> void:
	# Act / Assert
	for set_id: String in COLLECTIBLE_BY_SET:
		var collectible: Array = _db.cards_by_set(set_id).filter(func(card: Dictionary) -> bool: return not _is_token(card))
		assert_int(collectible.size()).override_failure_message(set_id).is_equal(int(COLLECTIBLE_BY_SET[set_id]))


func test_token_count_equals_cn1() -> void:
	# Act
	var tokens: int = 0
	for set_id: String in SETS:
		tokens += _db.cards_by_set(set_id).filter(_is_token).size()

	# Assert
	assert_int(tokens).is_equal(TOKENS)


func test_boss_card_count_equals_cn1() -> void:
	# Act
	var cards: Array = _db.cards_by_set("boss").filter(func(card: Dictionary) -> bool: return not _is_token(card))

	# Assert
	assert_int(cards.size()).is_equal(BOSS_CARDS)


func test_boss_counts_equal_cn1_per_band() -> void:
	# Act / Assert
	for band: int in BOSSES_BY_BAND:
		assert_int(_db.bosses_in_band(band).size()).override_failure_message(str(band)).is_equal(int(BOSSES_BY_BAND[band]))


func test_bundle_counts_equal_cn1() -> void:
	# Act / Assert — `bundle_pool` answers a hero's and the neutral ones together
	for hero_set: String in BUNDLES_BY_HERO_SET:
		assert_int(_db.bundle_pool(hero_set).size()).override_failure_message(hero_set).is_equal(int(BUNDLES_BY_HERO_SET[hero_set]) + NEUTRAL_BUNDLES)


func test_treasure_count_equals_cn1() -> void:
	# Assert
	assert_int(_db.treasure_pool().size()).is_equal(TREASURES)


func test_hero_and_hero_power_counts_equal_cn1() -> void:
	# Assert
	assert_int(_db.heroes().size()).is_equal(HEROES)
	for power_id: String in HERO_POWERS:
		assert_that(_db.hero_power(power_id)).override_failure_message(power_id).is_not_null()


func test_every_config_is_a_frozen_dictionary() -> void:
	# Act / Assert
	for name: String in _config_names():
		var body: Variant = _db.config(name)
		assert_bool(body is Dictionary).override_failure_message(name).is_true()
		assert_bool((body as Dictionary).is_read_only()).override_failure_message(name).is_true()


func test_the_config_list_holds_the_stories_thirteen_names() -> void:
	# Act
	var names: Array[String] = _config_names()

	# Assert — a rename in the manifest must not quietly shrink the case above
	assert_array(names).contains([
		"match_rules", "card_effects", "ai_profiles", "run_structure", "reward_draft",
		"treasures_balance", "heroes_balance", "match_ui", "run_ui", "profile_defaults",
		"card_database", "content_budgets", "rng_event_log",
	])


func test_alpha_data_leaves_no_warning() -> void:
	# Assert — CN-6 step 3: `W_POOL_SIZE` is MVP-0 only, none past it
	assert_array(_db.report().warnings()).is_empty()


func test_data_version_is_sixteen_hex() -> void:
	# Act
	var version: String = _db.data_version()

	# Assert
	assert_int(version.length()).is_equal(16)
	assert_bool(version.is_valid_hex_number()).is_true()


func test_windows_export_preset_includes_the_data_files() -> void:
	# Arrange
	var presets: ConfigFile = ConfigFile.new()
	assert_int(presets.load(EXPORT_PRESETS)).is_equal(OK)

	# Act
	var filter: String = ""
	for section: String in presets.get_sections():
		if str(presets.get_value(section, "name", "")) == WINDOWS_PRESET:
			filter = str(presets.get_value(section, "include_filter", ""))

	# Assert
	assert_str(filter).contains(DATA_FILTER)
