## Unit tests for `Treasures.pool(unlocked_keys, exclude_ids)`, the one
## membership predicate (story treasures/story-009; design/gdd/treasures.md T6,
## Edge Cases "State and persistence", AC-11, AC-12; ADR-0005 Decision rule 10;
## DD-X12).
##
## `pool` returns TreasureDef records (T6); the ACs read their ids. Runs on the
## 20 T8 records through the real `CardDatabase` pipeline. AC-MVP runs on the 10
## MVP records of that fixture: shipped `treasures.json` has none until content
## 006, so its shipped-data half is NOT ASSESSED here.
extends GdUnitTestSuite

const SIGNET: String = "treasure_worn_signet"
const TITHE: String = "treasure_grave_tithe"
const ARMORY: String = "treasure_living_armory"
const STATE_V1: Dictionary = {"schema_version": 1, "by_treasure": {}}


## A database whose `treasure_pool()` is the real one reversed, so a `pool` that
## re-sorts can be told from one that keeps the order it is given.
class ReversedPoolDatabase:
	extends CardDatabase

	var _reversed: Array = []

	func _init(source: CardDatabase) -> void:
		_reversed = source.treasure_pool().duplicate()
		_reversed.reverse()

	func treasure_pool() -> Array:
		return _reversed


func _treasures(db: CardDatabase = TreasureFixtures.database()) -> Treasures:
	return Treasures.new(db, {})


func _ids(defs: Array) -> Array:
	return defs.map(func(def: Dictionary) -> String: return def.id)


## [param keys] as the set `pool` takes (ADR-0005 Key Interfaces).
func _key_set(keys: Array) -> Dictionary:
	var out: Dictionary = {}
	for key: String in keys:
		out[key] = true
	return out


# --- AC-12: membership -------------------------------------------------------------

func test_pool_with_no_keys_is_the_16_default_treasures_ascending() -> void:
	# Act
	var ids: Array = _ids(_treasures().pool({}, []))

	# Assert
	assert_int(ids.size()).is_equal(16)
	GameAssertions.assert_sorted_ascending(ids)
	for locked: String in [TITHE, ARMORY, "treasure_plague_bell", "treasure_dogeared_grimoire"]:
		assert_array(ids).not_contains([locked])


func test_pool_with_the_four_keys_is_all_20() -> void:
	# Act
	var ids: Array = _ids(_treasures().pool(_key_set(TreasureFixtures.UNLOCK_KEYS), []))

	# Assert
	assert_int(ids.size()).is_equal(20)
	GameAssertions.assert_sorted_ascending(ids)


func test_pool_excluding_an_id_leaves_15_without_it() -> void:
	# Act
	var ids: Array = _ids(_treasures().pool({}, [SIGNET]))

	# Assert
	assert_int(ids.size()).is_equal(15)
	assert_array(ids).not_contains([SIGNET])


func test_one_key_unlocks_only_its_own_record() -> void:
	# Act
	var ids: Array = _ids(_treasures().pool(_key_set(["first_victory"]), []))

	# Assert
	assert_int(ids.size()).is_equal(17)
	assert_array(ids).contains([ARMORY])


func test_the_reserved_key_unlocks_nothing() -> void:
	# Act — DD-X12: `bosses_defeated_16` stays defined, and no treasure uses it
	var ids: Array = _ids(_treasures().pool(_key_set(["bosses_defeated_16"]), []))

	# Assert
	assert_int(ids.size()).is_equal(16)
	assert_array(ids).not_contains([ARMORY])


func test_an_exclusion_beats_an_unlock() -> void:
	# Act
	var ids: Array = _ids(_treasures().pool(_key_set(TreasureFixtures.UNLOCK_KEYS), [TITHE]))

	# Assert
	assert_int(ids.size()).is_equal(19)
	assert_array(ids).not_contains([TITHE])


func test_excluding_an_id_outside_the_pool_changes_nothing() -> void:
	# Act
	var ids: Array = _ids(_treasures().pool({}, [TITHE, "treasure_not_a_record"]))

	# Assert — Grave Tithe is locked already
	assert_int(ids.size()).is_equal(16)


# --- The contract ------------------------------------------------------------------

func test_pool_returns_the_treasure_def_records() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()

	# Act
	var defs: Array = _treasures(db).pool({}, [])

	# Assert — T6: TreasureDef[]; Reward Draft reads `rarity` and `tags`
	assert_int(defs.size()).is_equal(16)
	for def: Dictionary in defs:
		assert_dict(def).is_equal(db.treasure(def.id))


func test_pool_keeps_the_order_of_the_card_database() -> void:
	# Arrange
	var source: CardDatabase = TreasureFixtures.database()
	var reversed: ReversedPoolDatabase = ReversedPoolDatabase.new(source)
	var expected: Array = _ids(reversed.treasure_pool().filter(func(def: Dictionary) -> bool: return def.unlock == null))

	# Act
	var ids: Array = _ids(_treasures(reversed).pool({}, []))

	# Assert — filtered, never re-sorted (CR-6 already sorted it)
	assert_array(ids).is_equal(expected)
	assert_str(str(ids[0])).is_equal(str(expected[0]))


func test_pool_leaves_its_arguments_and_the_database_unchanged() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()
	var keys: Dictionary = _key_set(["first_victory"])
	var exclude: Array = [SIGNET]

	# Act — also write to the result: it is the caller's list
	var result: Array = _treasures(db).pool(keys, exclude)
	result.clear()

	# Assert
	assert_dict(keys).is_equal(_key_set(["first_victory"]))
	assert_array(exclude).is_equal([SIGNET])
	assert_int(db.treasure_pool().size()).is_equal(20)


# --- AC-11: an unlock revoked mid-run ----------------------------------------------

func test_a_revoked_unlock_keeps_the_held_treasure_installed_and_out_of_the_pool() -> void:
	# Arrange — a run holds Grave Tithe; its key has left the profile
	var treasures: Treasures = _treasures()
	var keys: Dictionary = _key_set(["hero_decay_floor_5", "hero_knowledge_first_win", "first_victory"])

	# Act
	var installers: Array[HookInstaller] = treasures.installers_for([TITHE], STATE_V1)
	var ids: Array = _ids(treasures.pool(keys, []))

	# Assert
	assert_int(installers.size()).is_equal(1)
	assert_str(installers[0].host_id).is_equal(TITHE)
	assert_array(ids).not_contains([TITHE])


# --- AC-MVP: Meta Progression absent -----------------------------------------------

func test_the_mvp_records_are_all_unlocked_by_default() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database(TreasureFixtures.MVP_IDS)

	# Assert — DD-H06: 10 of 10 have `unlock: null`
	assert_int(db.treasure_pool().size()).is_equal(10)
	for def: Dictionary in db.treasure_pool():
		assert_that(def.unlock).is_null()


func test_the_mvp_pool_under_meta_stub_is_all_ten_ascending() -> void:
	# Arrange — `MetaStub.unlocked_keys()` reads the data, so it is empty over
	# these 10 records and holds the 4 keys over all 20
	var db: CardDatabase = TreasureFixtures.database(TreasureFixtures.MVP_IDS)
	var meta: MetaStub = MetaStub.new(db)
	var keys: Array = meta.unlocked_keys()
	var min_treasure_pool: int = TestConstants.TREASURE_FLOORS.size() * TestConstants.OFFERS_PER_DRAFT

	# Act
	var ids: Array = _ids(_treasures(db).pool(_key_set(keys), []))

	# Assert
	assert_array(keys).is_empty()
	assert_array(ids).is_equal(TreasureFixtures.MVP_IDS)
	GameAssertions.assert_sorted_ascending(ids)
	assert_int(ids.size()).is_greater_equal(min_treasure_pool)


func test_two_mvp_pool_calls_with_the_same_arguments_are_equal() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database(TreasureFixtures.MVP_IDS)
	var treasures: Treasures = _treasures(db)

	# Act
	var first: Array = treasures.pool({}, [])
	var second: Array = treasures.pool({}, [])

	# Assert
	assert_array(_ids(first)).is_equal(_ids(second))
	assert_int(first.size()).is_equal(10)
