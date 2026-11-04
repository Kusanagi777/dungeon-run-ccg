## Unit tests for the `Heroes` accessor (heroes story 002; heroes.md H-2, H-5, H-7,
## AC-16 data half; architecture.md API Boundaries, Heroes row).
##
## `FakeCardDatabase` below is a `CardDatabase` subclass answering the four queries
## the accessor uses from `CardFactory` records, frozen as CR-7 freezes real ones,
## with no load. It counts `config` calls so "read once at construction" is
## observable. The shipped data is `tests/integration/heroes/heroes_shipped_data_test.gd`.
extends GdUnitTestSuite


class FakeCardDatabase:
	extends CardDatabase

	var config_calls: int = 0
	var _balance: Dictionary
	var _heroes: Array

	func _init(heroes_in_id_order: Array, balance: Dictionary) -> void:
		_heroes = heroes_in_id_order
		for record: Dictionary in _heroes:
			record.make_read_only()
		_balance = balance
		_balance.make_read_only()

	func has(id: String) -> bool:
		return _heroes.any(func(h: Dictionary) -> bool: return h.id == id)

	func hero(id: String) -> Variant:
		for record: Dictionary in _heroes:
			if record.id == id:
				return record
		return null

	func heroes() -> Array:
		return _heroes

	func config(_config_name: String) -> Variant:
		config_calls += 1
		return _balance


const HERO_FIRST: String = "hero_alpha"
## Sorts between the two launch heroes, so a filter that stops at the first locked
## hero or drops by position fails.
const HERO_LOCKED: String = "hero_locked"
const HERO_LAST: String = "hero_zeta"
const HERO_UNKNOWN: String = "hero_not_in_the_data"
## A `plan_tags.war` list no shipped body holds (AC-2's "different list").
const FIXTURE_TAGS: Array = ["fixture_tag_one", "fixture_tag_two"]
## A H-7 `unlock {key, condition}` object (DD-X01).
const LOCKED_UNLOCK: Dictionary = {"key": "unlock.hero_locked", "condition": {"type": "wins", "count": 1}}


func _balance() -> Dictionary:
	return {"plan_tags": {"war": FIXTURE_TAGS.duplicate()}}


func _db() -> FakeCardDatabase:
	return FakeCardDatabase.new([
		CardFactory.make_hero_def(HERO_FIRST),
		CardFactory.make_hero_def(HERO_LOCKED, "war", {"unlock": LOCKED_UNLOCK.duplicate(true)}),
		CardFactory.make_hero_def(HERO_LAST),
	], _balance())


func _ids(records: Array) -> Array:
	return records.map(func(r: Dictionary) -> String: return str(r.id))


# --- AC-1: launch_heroes and hero ----------------------------------------------------

func test_launch_heroes_returns_the_unlock_null_heroes_in_id_order() -> void:
	# Arrange
	var heroes: Heroes = Heroes.new(_db())

	# Act
	var launch: Array = heroes.launch_heroes()

	# Assert
	assert_array(_ids(launch)).is_equal([HERO_FIRST, HERO_LAST])


func test_hero_returns_the_same_frozen_record_as_the_database() -> void:
	# Arrange
	var db: FakeCardDatabase = _db()
	var heroes: Heroes = Heroes.new(db)

	# Act
	var record: Variant = heroes.hero(HERO_LOCKED)

	# Assert — the very Dictionary, a locked hero included: `hero` is not `launch_heroes`
	assert_bool(is_same(record, db.hero(HERO_LOCKED))).is_true()
	assert_bool((record as Dictionary).is_read_only()).is_true()


func test_hero_of_an_unknown_id_is_null() -> void:
	# Arrange
	var heroes: Heroes = Heroes.new(_db())

	# Act / Assert
	assert_that(heroes.hero(HERO_UNKNOWN)).is_null()


# --- AC-2: plan_tags -----------------------------------------------------------------

func test_plan_tags_returns_the_list_for_the_heros_set_from_the_config_body() -> void:
	# Arrange
	var heroes: Heroes = Heroes.new(_db())

	# Act
	var tags: Array = heroes.plan_tags(HERO_FIRST)

	# Assert
	assert_array(tags).is_equal(FIXTURE_TAGS)


func test_plan_tags_returns_a_writable_copy_of_the_frozen_list() -> void:
	# Arrange
	var heroes: Heroes = Heroes.new(_db())

	# Act
	var tags: Array = heroes.plan_tags(HERO_FIRST)
	tags.append("caller_tag")

	# Assert
	assert_array(heroes.plan_tags(HERO_FIRST)).is_equal(FIXTURE_TAGS)


func test_plan_tags_of_an_unknown_hero_logs_and_returns_empty() -> void:
	# Arrange
	var heroes: Heroes = Heroes.new(_db())
	var box: Dictionary = {"value": ["untouched"]}

	# Act
	await assert_error(func() -> void: box.value = heroes.plan_tags(HERO_UNKNOWN)) \
		.is_push_error("Heroes.plan_tags(): no HeroDef \"%s\"" % HERO_UNKNOWN)

	# Assert
	assert_array(box.value).is_empty()


func test_plan_tags_of_a_set_with_no_row_logs_and_returns_empty() -> void:
	# Arrange — a `fortune` hero before `heroes_balance` has a row for the set
	var db: FakeCardDatabase = FakeCardDatabase.new([CardFactory.make_hero_def("hero_fortune", "fortune")], _balance())
	var heroes: Heroes = Heroes.new(db)
	var box: Dictionary = {"value": ["untouched"]}

	# Act
	await assert_error(func() -> void: box.value = heroes.plan_tags("hero_fortune")) \
		.is_push_error("Heroes.plan_tags(): heroes_balance has no plan_tags row for set \"fortune\"")

	# Assert
	assert_array(box.value).is_empty()


# --- ADR-0002: the owner reads its body once -----------------------------------------

func test_the_config_body_is_read_once_at_construction() -> void:
	# Arrange
	var db: FakeCardDatabase = _db()

	# Act
	var heroes: Heroes = Heroes.new(db)
	heroes.plan_tags(HERO_FIRST)
	heroes.plan_tags(HERO_LAST)
	heroes.launch_heroes()
	heroes.hero(HERO_FIRST)

	# Assert
	assert_int(db.config_calls).is_equal(1)
