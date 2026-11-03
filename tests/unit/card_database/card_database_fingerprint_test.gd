## Unit tests for the CR-9 `data_version` fingerprint (story
## card-database/story-007; card-database CR-9, CR-5 step 9, Acceptance
## Criteria "Pools and determinism"; ADR-0002 Decision 5, Verification
## Required item 2).
##
## Fixtures, all committed and read-only:
## - `fingerprint/` — a byte copy of `clean/` (every required file, no
##   optional set file such as `cards_decay.json`);
## - `fingerprint_reordered/` — the same parsed content with every `records`
##   list reversed, every object's keys in reverse order and 4-space indent;
## - `fingerprint_changed/` — `fingerprint/` with `war_shield_bearer.attack`
##   raised by 1.
## `JSON.stringify(sort_keys, full_precision)` and `HashingContext` SHA-256 on
## 4.7.2 are NOT SOURCEABLE from the engine reference: the known-answer
## constants below are the proof, and each one was computed independently of
## the code under test (Python `hashlib.sha256` over the same canonical form)
## before the first green run matched it.
extends GdUnitTestSuite

const DATA: String = "res://tests/fixtures/data/"
## `data_version()` of `fingerprint/`. Recorded 2026-11-03 on Linux x86_64
## (Godot 4.7.2.stable.official.ed1daf0bf, the CI container), equal to the
## independent Python reference (sha256 over `name` + canonical body per
## manifest row, records id-sorted, first 16 hex). The epic's Definition of
## Done re-checks it on the owner's Windows machine (open).
const KNOWN_ANSWER: String = "4667ce6e5d01302f"
## `sha256("a.json" + "{\"k\":1}")[:16]` (Python hashlib) — HashingContext KAT.
const ONE_BODY_ANSWER: String = "d2b1dfb91002d169"
## `sha256("a.json{\"k\":1}b.json[]")[:16]` — two entries, in order, one context.
const TWO_BODY_ANSWER: String = "190916df75a960ea"
## Data roots grepped for an authored version key (CR-9: never authored).
const VERSION_KEY_ROOTS: Array[String] = ["res://tests/fixtures/data/", "res://assets/data/"]
const VERSION_KEYS: Array[String] = ["\"data_version\"", "\"content_version\""]


func _ready_db(case_name: String) -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(DATA + case_name + "/"))
	db.load(ValidatorStubs.accept_all())
	GameAssertions.fail_if(db.state() != CardDatabase.State.READY, "%s/ did not load:\n%s" % [case_name, db.report().to_text()])
	return db


## Every CR-6 query of [param db] as canonical JSON, keyed by the query, so two
## databases can be compared sequence for sequence (same records, same order).
func _all_queries(db: CardDatabase) -> Dictionary:
	var out: Dictionary = {}
	for set_id: String in RecordSchemas.SETS:
		out["cards_by_set:" + set_id] = DataLoader.canonical_json(db.cards_by_set(set_id))
		out["collectible_pool:" + set_id] = DataLoader.canonical_json(db.collectible_pool(set_id))
		out["bundle_pool:" + set_id] = DataLoader.canonical_json(db.bundle_pool(set_id))
	for type: String in ["minion", "spell", "weapon"]:
		out["cards_by_type:" + type] = DataLoader.canonical_json(db.cards_by_type(type))
	for band: int in [1, 2, 3]:
		out["bosses_in_band:%d" % band] = DataLoader.canonical_json(db.bosses_in_band(band))
	out["treasure_pool"] = DataLoader.canonical_json(db.treasure_pool())
	out["heroes"] = DataLoader.canonical_json(db.heroes())
	return out


## `[{name, body}]` for every manifest file present under [param root], in
## manifest order, parsed by the test itself (a committed fixture read).
func _bodies_on_disk(root: String) -> Array[Dictionary]:
	var bodies: Array[Dictionary] = []
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		var path: String = root + row.name
		if not FileAccess.file_exists(path):
			continue
		bodies.append({"name": row.name, "body": JSON.parse_string(FileAccess.get_file_as_string(path))})
	return bodies


# --- AC-1: order, keys and whitespace are irrelevant; a value change is not ----------

func test_reordered_root_gives_identical_query_sequences() -> void:
	# Arrange
	var a: CardDatabase = _ready_db("fingerprint")
	var b: CardDatabase = _ready_db("fingerprint_reordered")

	# Act
	var qa: Dictionary = _all_queries(a)
	var qb: Dictionary = _all_queries(b)

	# Assert — CR-6: id order, never file order, key order or whitespace
	for key: String in qa:
		assert_str(qb[key]).override_failure_message(key).is_equal(qa[key])
	assert_array(a.cards_by_set("war")).is_not_empty()


func test_reordered_fixture_really_differs_in_record_order_keys_and_whitespace() -> void:
	# Arrange — guards the test above against a fixture that is a plain copy
	var path_a: String = DATA + "fingerprint/cards_war.json"
	var path_b: String = DATA + "fingerprint_reordered/cards_war.json"
	var a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path_a))
	var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path_b))

	# Assert
	assert_str(b.records[0].id).is_not_equal(a.records[0].id)
	assert_str(str(b.keys()[0])).is_not_equal(str(a.keys()[0]))
	assert_str(FileAccess.get_file_as_string(path_b)).is_not_equal(FileAccess.get_file_as_string(path_a))


func test_reordered_root_gives_the_same_data_version() -> void:
	# Act
	var a: String = _ready_db("fingerprint").data_version()
	var b: String = _ready_db("fingerprint_reordered").data_version()

	# Assert
	assert_str(a).is_not_empty()
	assert_str(b).is_equal(a)


func test_data_version_is_sixteen_lowercase_hex_characters() -> void:
	# Act
	var version: String = _ready_db("fingerprint").data_version()

	# Assert
	assert_int(version.length()).is_equal(16)
	assert_bool(version.is_valid_hex_number(false)).override_failure_message(version).is_true()
	assert_str(version).is_equal(version.to_lower())


func test_one_attack_changed_by_one_gives_a_different_data_version() -> void:
	# Arrange
	var before: CardDatabase = _ready_db("fingerprint")
	var after: CardDatabase = _ready_db("fingerprint_changed")

	# Act / Assert — the fixture differs in exactly that one value
	assert_int(int(after.card("war_shield_bearer").attack)).is_equal(int(before.card("war_shield_bearer").attack) + 1)
	assert_str(after.data_version()).is_not_equal(before.data_version())
	assert_int(after.data_version().length()).is_equal(16)


# --- AC-2: known answer; the static function needs no database -----------------------

func test_data_version_of_the_fingerprint_root_is_the_known_answer() -> void:
	assert_str(_ready_db("fingerprint").data_version()).is_equal(KNOWN_ANSWER)


func test_static_fingerprint_over_the_same_bodies_equals_data_version() -> void:
	# Arrange — the files as parsed, no CardDatabase, no loader
	var bodies: Array[Dictionary] = _bodies_on_disk(DATA + "fingerprint/")

	# Act
	var static_version: String = DataLoader.fingerprint(bodies)

	# Assert
	assert_str(static_version).is_equal(KNOWN_ANSWER)
	assert_str(static_version).is_equal(_ready_db("fingerprint").data_version())


func test_static_fingerprint_is_sha256_of_name_then_canonical_body() -> void:
	# Act / Assert — HashingContext SHA-256 against an outside reference
	assert_str(DataLoader.fingerprint([{"name": "a.json", "body": {"k": 1}}])).is_equal(ONE_BODY_ANSWER)
	assert_str(DataLoader.fingerprint([{"name": "a.json", "body": {"k": 1}}, {"name": "b.json", "body": []}])) \
		.is_equal(TWO_BODY_ANSWER)


func test_static_fingerprint_depends_on_entry_order() -> void:
	# Arrange — manifest order is part of the contract, so it must matter
	var ab: Array[Dictionary] = [{"name": "a.json", "body": {"k": 1}}, {"name": "b.json", "body": []}]
	var ba: Array[Dictionary] = [{"name": "b.json", "body": []}, {"name": "a.json", "body": {"k": 1}}]

	# Act / Assert
	assert_str(DataLoader.fingerprint(ba)).is_not_equal(DataLoader.fingerprint(ab))


func test_static_fingerprint_ignores_record_order_within_a_file() -> void:
	# Arrange — CR-6 / manifest "never depend on authoring order"
	var forward: Array[Dictionary] = [{"name": "x.json", "body": {"schema_version": 1, "records": [{"id": "a_1"}, {"id": "b_2"}]}}]
	var backward: Array[Dictionary] = [{"name": "x.json", "body": {"schema_version": 1, "records": [{"id": "b_2"}, {"id": "a_1"}]}}]

	# Act / Assert
	assert_str(DataLoader.fingerprint(backward)).is_equal(DataLoader.fingerprint(forward))


func test_canonical_json_is_compact_sorted_at_every_depth() -> void:
	# Act
	var text: String = DataLoader.canonical_json({"b": 2, "a": {"d": [1, 2], "c": "x"}})

	# Assert — no whitespace, keys sorted in nested objects, list order kept
	assert_str(text).is_equal("{\"a\":{\"c\":\"x\",\"d\":[1,2]},\"b\":2}")


func test_canonical_json_renders_parsed_numbers_with_full_precision() -> void:
	# Arrange — JSON numbers parse as float; 0.1 needs full precision to round-trip
	var parsed: Variant = JSON.parse_string("{\"n\": 2, \"f\": 0.1}")

	# Act / Assert — observed 4.7.2 form: integral floats as `2.0`
	assert_str(DataLoader.canonical_json(parsed)).is_equal("{\"f\":0.1,\"n\":2.0}")


# --- AC-3: not Ready; absent optional files; never authored --------------------------

func test_data_version_when_unloaded_returns_empty_with_one_logged_error() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(DataLoader.new(DATA + "fingerprint/"))
	var box: Dictionary = {"value": "untouched"}

	# Act / Assert
	await assert_error(func() -> void: box.value = db.data_version()) \
		.is_push_error("CardDatabase.data_version() is illegal in state UNLOADED (before Ready)")
	assert_str(box.value).is_empty()


func test_data_version_when_failed_returns_empty_with_one_logged_error() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(DataLoader.new(DATA + "parse_error/"))
	db.load(ValidatorStubs.accept_all())
	var box: Dictionary = {"value": "untouched"}

	# Act / Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	await assert_error(func() -> void: box.value = db.data_version()) \
		.is_push_error("CardDatabase.data_version() is illegal in state FAILED (before Ready)")
	assert_str(box.value).is_empty()


func test_snapshot_carries_the_data_version() -> void:
	# Arrange
	var db: CardDatabase = _ready_db("fingerprint")

	# Assert — stored at freeze (story 006 reserved the key)
	assert_str(db._snapshot.data_version).is_equal(db.data_version())


func test_fingerprint_covers_only_the_files_loaded() -> void:
	# Arrange — `fingerprint/` has no optional set file; hashing an absent
	# file as an empty body would give a different string
	var bodies: Array[Dictionary] = _bodies_on_disk(DATA + "fingerprint/")
	var names: Array = bodies.map(func(b: Dictionary) -> String: return b.name)
	var with_decay: Array[Dictionary] = bodies.duplicate()
	with_decay.insert(3, {"name": "cards_decay.json", "body": {"schema_version": 1, "records": []}})

	# Act / Assert
	assert_bool(names.has("cards_decay.json")).is_false()
	assert_str(_ready_db("fingerprint").data_version()).is_equal(DataLoader.fingerprint(bodies))
	assert_str(DataLoader.fingerprint(with_decay)).is_not_equal(DataLoader.fingerprint(bodies))


## The `.json` files under [param dir], recursively.
func _json_files_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.get_extension() == "json":
			out.append(dir + file_name)
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_json_files_under(dir + sub + "/"))
	return out


## The version keys present in [param text].
func _version_keys_in(text: String) -> Array[String]:
	var out: Array[String] = []
	for key: String in VERSION_KEYS:
		if text.contains(key):
			out.append(key)
	return out


func test_version_key_matcher_finds_an_authored_version_key() -> void:
	# Assert — the gate below has been seen to fail
	assert_array(_version_keys_in("{\"schema_version\": 1, \"data_version\": \"x\"}")).is_equal(["\"data_version\""])
	assert_array(_version_keys_in("{\"content_version\": 3}")).is_equal(["\"content_version\""])
	assert_array(_version_keys_in("{\"schema_version\": 1}")).is_empty()


func test_no_fixture_or_shipped_data_file_authors_a_version_string() -> void:
	# Arrange
	var files: Array[String] = []
	for root: String in VERSION_KEY_ROOTS:
		files.append_array(_json_files_under(root))
	var hits: Array[String] = []

	# Act
	for path: String in files:
		for key: String in _version_keys_in(FileAccess.get_file_as_string(path)):
			hits.append("%s: %s" % [path, key])

	# Assert — CR-9: data_version is derived, never authored
	assert_int(files.size()).is_greater(100)
	assert_array(hits).is_empty()
