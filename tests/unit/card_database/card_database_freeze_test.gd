## Unit tests for the CR-5 stage-9 freeze (story card-database/story-006;
## card-database CR-5 step 9, CR-7, States table "Ready"; ADR-0002 Decision 5,
## Verification Required item 3).
##
## `make_read_only()` is not recursive on 4.7.2 (observed 2026-11-03: a
## read-only Dictionary's nested Array and Dictionary stay writable), so the
## loader walks every record and config body. A write to a read-only container
## is refused with the script error "Invalid assignment on read-only value (on
## base: '<type>')." and the value is unchanged; each write here runs inside
## `assert_error` so that expected error is captured, not reported.
## Fixture `pools/` (see card_database_queries_test.gd), validators are
## explicit `ValidatorStubs`, the fixture root is read-only.
extends GdUnitTestSuite

const ROOT: String = "res://tests/fixtures/data/pools/"
const REFUSED: String = "Invalid assignment on read-only value (on base: '%s')."


func _ready_db() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(ROOT))
	db.load(ValidatorStubs.accept_all())
	GameAssertions.fail_if(db.state() != CardDatabase.State.READY, "pools/ did not load:\n%s" % db.report().to_text())
	return db


## Every Dictionary / Array reachable from [param value] that is not read-only,
## as `"<path>"` strings.
func _writable_paths(value: Variant, path: String, out: Array) -> Array:
	if value is Dictionary:
		if not (value as Dictionary).is_read_only():
			out.append(path)
		for key: Variant in value:
			_writable_paths(value[key], "%s.%s" % [path, str(key)], out)
	elif value is Array:
		if not (value as Array).is_read_only():
			out.append(path)
		for i: int in (value as Array).size():
			_writable_paths(value[i], "%s[%d]" % [path, i], out)
	return out


# --- AC-4: every write is refused --------------------------------------------------

func test_write_to_a_returned_record_is_refused() -> void:
	# Arrange
	var record: Dictionary = _ready_db().card("war_banner")

	# Act / Assert
	await assert_error(func() -> void: record["cost"] = 9).is_runtime_error(REFUSED % "Dictionary")
	assert_int(int(record.cost)).is_equal(2)


func test_write_to_a_nested_effect_inside_a_record_is_refused() -> void:
	# Arrange
	var record: Dictionary = _ready_db().card("war_banner")

	# Act / Assert — effects[0] and its ops[0] are frozen too
	await assert_error(func() -> void: record["effects"][0]["trigger"] = "x").is_runtime_error(REFUSED % "Dictionary")
	await assert_error(func() -> void: record["effects"][0]["ops"][0]["op"] = "x").is_runtime_error(REFUSED % "Dictionary")
	await assert_error(func() -> void: record["effects"][0] = {}).is_runtime_error(REFUSED % "Array")
	assert_str(record.effects[0].trigger).is_equal("on_play")
	assert_str(record.effects[0].ops[0].op).is_equal("draw")


func test_write_to_an_element_of_a_returned_pool_is_refused() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()
	var pool: Array = db.collectible_pool("war")
	var first: Dictionary = pool[0]

	# Act / Assert — the precomputed pool keeps its record type
	await assert_error(func() -> void: pool[0] = {}).is_runtime_error(REFUSED % ("Array[Dictionary]" if pool.is_typed() else "Array"))
	assert_bool(is_same(pool[0], first)).is_true()


func test_every_list_query_returns_a_read_only_array() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act
	var lists: Dictionary = {
		"cards_by_set": db.cards_by_set("war"), "cards_by_type": db.cards_by_type("spell"),
		"cards_by_tag": db.cards_by_tag("wild"), "cards_by_cost": db.cards_by_cost(1),
		"cards_by_rarity": db.cards_by_rarity("legendary"), "collectible_pool": db.collectible_pool("war"),
		"collectible_pool unknown set": db.collectible_pool("shadow"), "bundle_pool": db.bundle_pool("war"),
		"treasure_pool": db.treasure_pool(), "bosses_in_band": db.bosses_in_band(1),
		"bosses_in_band empty": db.bosses_in_band(3), "heroes": db.heroes(),
	}

	# Assert
	for query: String in lists:
		assert_bool((lists[query] as Array).is_read_only()).override_failure_message(query).is_true()


func test_write_to_a_returned_config_body_is_refused() -> void:
	# Arrange
	var body: Dictionary = _ready_db().config("match_rules")

	# Act / Assert — the body and the Array nested in it
	await assert_error(func() -> void: body["k"] = 1).is_runtime_error(REFUSED % "Dictionary")
	await assert_error(func() -> void: body["boss_starting_health_by_band"][0] = 1).is_runtime_error(REFUSED % "Array")
	assert_bool(body.has("k")).is_false()
	assert_int(int(body.boss_starting_health_by_band[0])).is_equal(30)


func test_every_record_and_config_container_is_read_only_after_load() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act — walk the whole snapshot the queries read from
	var writable: Array = []
	_writable_paths(db._snapshot.records_by_type, "records_by_type", writable)
	_writable_paths(db._snapshot.index_of, "index_of", writable)
	_writable_paths(db._snapshot.config_bodies, "config_bodies", writable)

	# Assert
	assert_array(writable).is_empty()


func test_duplicate_true_of_a_record_is_a_writable_deep_copy() -> void:
	# Arrange
	var record: Dictionary = _ready_db().card("war_banner")

	# Act
	var copy: Dictionary = record.duplicate(true)
	copy["cost"] = 9
	copy["effects"][0]["trigger"] = "on_death"

	# Assert — the copy changed, the frozen record did not
	assert_bool(copy.is_read_only()).is_false()
	assert_int(int(copy.cost)).is_equal(9)
	assert_str(copy.effects[0].trigger).is_equal("on_death")
	assert_int(int(record.cost)).is_equal(2)
	assert_str(record.effects[0].trigger).is_equal("on_play")


func test_clean_load_report_holds_warnings_only() -> void:
	# Act
	var db: CardDatabase = _ready_db()

	# Assert — Ready: report() holds warnings only (States table)
	assert_array(db.report().errors()).is_empty()
	for entry: Dictionary in db.report().entries():
		assert_str(String(entry.severity)).is_equal(String(ValidationReport.SEVERITY_WARNING))


func test_failed_load_freezes_nothing_and_keeps_no_snapshot() -> void:
	# Arrange — parse_error/ fails at stage 2
	var db: CardDatabase = CardDatabase.new(DataLoader.new("res://tests/fixtures/data/parse_error/"))

	# Act
	db.load(ValidatorStubs.accept_all())

	# Assert — CR-5 step 9: no "load what passed" path
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_that(db._snapshot).is_null()
