## Integration: unlock definitions through a real stage-7b load, with `Boot`'s real
## validator map over the shipped data (design/gdd/meta-progression.md M2.4, AC-25;
## card-database CR-5; ADR-0002 Decision 4). No fake database: `db` is a `CardDatabase`
## in its stage-7 window, so `has()`, `heroes()`, `treasure_pool()` and `bundle_pool()`
## answer from the staging, which only a real load exercises. The overlay loader changes
## one record of what the shipped files hold.
extends GdUnitTestSuite

## `DataLoader` over the shipped root with [member edit] applied to the parsed files.
class OverlayLoader:
	extends DataLoader

	var _edit: Callable

	func _init(edit: Callable) -> void:
		super()
		_edit = edit

	func _read_and_parse(report: ValidationReport) -> Array[Dictionary]:
		var staged: Array[Dictionary] = super(report)
		for item: Dictionary in staged:
			_edit.call(item)
		return staged


const BOOT_SCRIPT_PATH: String = "res://src/core/boot.gd"
const ARMORY: String = ProfileFixtures.ARMORY
const OPEN_TREASURE: String = "treasure_worn_signet"
const LOCKED_TREASURES: int = 4


func _validators() -> Dictionary:
	var boot: Node = auto_free(load(BOOT_SCRIPT_PATH).new())
	return boot._collect_validators(null)


func _load(edit: Callable) -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(OverlayLoader.new(edit))
	db.load(_validators())
	return db


func _treasure_edit(treasure_id: String, unlock: Variant) -> Callable:
	return func(item: Dictionary) -> void:
		if item.row.name == "treasures.json":
			for record: Dictionary in item.body.records:
				if record.id == treasure_id:
					record["unlock"] = unlock


func _delegated(report: ValidationReport, text: String) -> Array:
	return report.errors().filter(func(entry: Dictionary) -> bool:
		return entry.code == ValidationReport.E_DELEGATED and String(entry.message).contains(text))


func _nested_condition(levels: int) -> Dictionary:
	var condition: Dictionary = {"type": "runs_won", "n": 1}
	for _level: int in levels:
		condition = {"type": "all_of", "of": [condition]}
	return condition


func test_shipped_data_loads_with_the_real_unlock_validator() -> void:
	# Act
	var db: CardDatabase = _load(func(_item: Dictionary) -> void: pass)

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_array(db.report().errors()).is_empty()


func test_shipped_data_locks_the_four_m10_treasures_and_no_hero() -> void:
	# Act
	var db: CardDatabase = _load(func(_item: Dictionary) -> void: pass)

	# Assert
	var locked: Dictionary = {}
	for treasure: Dictionary in db.treasure_pool():
		if treasure.unlock != null:
			locked[treasure.id] = treasure.unlock.key
	assert_dict(locked).is_equal({
		ProfileFixtures.TITHE: ProfileFixtures.DECAY_WIN_KEY,
		ProfileFixtures.BELL: ProfileFixtures.DECAY_FLOOR_KEY,
		ProfileFixtures.GRIMOIRE: ProfileFixtures.KNOWLEDGE_WIN_KEY,
		ARMORY: ProfileFixtures.FIRST_VICTORY_KEY,
	})
	for hero: Dictionary in db.heroes():
		assert_that(hero.unlock).override_failure_message(hero.id).is_null()


func test_load_ac25_unknown_boss_fails_with_e_unlock_unknown_id_naming_the_key() -> void:
	# Arrange
	var unlock: Dictionary = {"key": "first_victory", "condition": {"type": "boss_defeated", "boss_id": "boss_nope"}}

	# Act
	var db: CardDatabase = _load(_treasure_edit(ARMORY, unlock))

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	var hits: Array = _delegated(db.report(), String(UnlockEvaluator.E_UNLOCK_UNKNOWN_ID))
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("first_victory")
	assert_str(str(hits[0].record_id)).is_equal(ARMORY)
	assert_str(str(hits[0].field)).is_equal("unlock")


func test_load_a_real_boss_id_passes() -> void:
	# Arrange: the same shape, with an id the staging holds
	var shipped: CardDatabase = _load(func(_item: Dictionary) -> void: pass)
	var boss_id: String = shipped.bosses_in_band(1)[0].id
	var unlock: Dictionary = {"key": "first_victory", "condition": {"type": "boss_defeated", "boss_id": boss_id}}

	# Act
	var db: CardDatabase = _load(_treasure_edit(ARMORY, unlock))

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_load_ac25_condition_nested_four_deep_is_e_unlock_shape() -> void:
	# Arrange
	var unlock: Dictionary = {"key": "first_victory", "condition": _nested_condition(3)}

	# Act
	var db: CardDatabase = _load(_treasure_edit(ARMORY, unlock))

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_int(_delegated(db.report(), String(UnlockEvaluator.E_UNLOCK_SHAPE)).size()).is_equal(1)


func test_load_condition_three_deep_passes() -> void:
	# Arrange
	var unlock: Dictionary = {"key": "first_victory", "condition": _nested_condition(2)}

	# Act
	var db: CardDatabase = _load(_treasure_edit(ARMORY, unlock))

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_load_key_carried_by_two_files_fails_on_both_records() -> void:
	# Arrange: a hero and a treasure share one key (M2.1)
	var shared: Dictionary = {"key": "first_victory", "condition": {"type": "runs_won", "n": 1}}
	var edit: Callable = func(item: Dictionary) -> void:
		if item.row.name == "heroes.json":
			item.body.records[0]["unlock"] = shared

	# Act
	var db: CardDatabase = _load(edit)

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	var hits: Array = _delegated(db.report(), "more than one record")
	assert_int(hits.size()).is_equal(2)


func test_load_treasure_requiring_its_own_pick_warns_and_stays_ready() -> void:
	# Arrange
	var unlock: Dictionary = {"key": "first_victory", "condition": {"type": "treasure_picked", "treasure_id": ARMORY}}

	# Act
	var db: CardDatabase = _load(_treasure_edit(ARMORY, unlock))

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	var warnings: Array = db.report().warnings().filter(func(entry: Dictionary) -> bool:
		return String(entry.message).contains(String(UnlockEvaluator.W_UNLOCK_SELF)))
	assert_int(warnings.size()).is_equal(1)


func test_load_a_failed_profile_defaults_gives_each_non_null_unlock_one_e_delegated() -> void:
	# Arrange: the 7a validator refuses the knobs, so the limits are unknown
	var edit: Callable = func(item: Dictionary) -> void:
		if item.row.name == "profile_defaults.json":
			item.body.config.knobs["run_log_cap"] = 1

	# Act
	var db: CardDatabase = _load(edit)

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	var hits: Array = _delegated(db.report(), "profile_defaults config failed stage 7a")
	assert_int(hits.size()).is_equal(LOCKED_TREASURES)
	assert_array(hits.map(func(entry: Dictionary) -> String: return str(entry.record_id))).contains([ARMORY])
	assert_array(hits.map(func(entry: Dictionary) -> String: return str(entry.record_id))).not_contains([OPEN_TREASURE])


func test_load_a_failed_profile_defaults_still_reports_its_own_knob() -> void:
	# Arrange
	var edit: Callable = func(item: Dictionary) -> void:
		if item.row.name == "profile_defaults.json":
			item.body.config.knobs["run_log_cap"] = 1

	# Act
	var db: CardDatabase = _load(edit)

	# Assert
	var hits: Array = db.report().errors().filter(func(entry: Dictionary) -> bool: return entry.file == "profile_defaults.json")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("run_log_cap")


func test_load_limits_come_from_the_profile_defaults_body() -> void:
	# Arrange: the file allows four levels, so four-deep passes
	var unlock: Dictionary = {"key": "first_victory", "condition": _nested_condition(3)}
	var treasure_edit: Callable = _treasure_edit(ARMORY, unlock)
	var edit: Callable = func(item: Dictionary) -> void:
		treasure_edit.call(item)
		if item.row.name == "profile_defaults.json":
			item.body.config.knobs["max_condition_depth"] = 4

	# Act
	var db: CardDatabase = _load(edit)

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_facade_validator_reports_the_same_rules_after_the_load() -> void:
	# Arrange
	var db: CardDatabase = _load(func(_item: Dictionary) -> void: pass)
	var root: String = ProfileFixtures.new_root()
	var clock: ProfileFixtures.ManualClock = ProfileFixtures.ManualClock.new()
	var meta: MetaFacade = ProfileFixtures.facade(ProfileFixtures.store(root, clock), db)
	var unlock: Dictionary = {"key": "a_new_key", "condition": {"type": "boss_defeated", "boss_id": "boss_nope"}}

	# Act
	var rows: Array = meta.validate_unlock_defs([{"host_kind": &"treasure", "host_id": ARMORY, "unlock": unlock}])

	# Assert
	assert_int(rows.size()).is_equal(1)
	assert_str(String(rows[0].code)).is_equal(String(UnlockEvaluator.E_UNLOCK_UNKNOWN_ID))
	ProfileFixtures.remove_root(root)


func test_compose_over_shipped_data_defines_the_four_keys_and_each_treasure_opens() -> void:
	# Arrange: a real database, a scratch store, M10's milestones end to end
	var db: CardDatabase = _load(func(_item: Dictionary) -> void: pass)
	var root: String = ProfileFixtures.new_root()
	var clock: ProfileFixtures.ManualClock = ProfileFixtures.ManualClock.new()
	var meta: MetaFacade = ProfileFixtures.facade(ProfileFixtures.store(root, clock), db)
	meta.load_profile()

	# Act
	var war: Dictionary = meta.archive_run(ProfileFixtures.victory("run_1", ProfileFixtures.HERO_WAR))
	var decay: Dictionary = meta.archive_run(ProfileFixtures.victory("run_2", ProfileFixtures.HERO_DECAY))
	var knowledge: Dictionary = meta.archive_run(ProfileFixtures.victory("run_3", ProfileFixtures.HERO_KNOWLEDGE))

	# Assert
	assert_array(war.unlocks_granted).is_equal([ProfileFixtures.FIRST_VICTORY_KEY])
	assert_array(decay.unlocks_granted).contains_exactly_in_any_order([ProfileFixtures.DECAY_WIN_KEY, ProfileFixtures.DECAY_FLOOR_KEY])
	assert_array(knowledge.unlocks_granted).is_equal([ProfileFixtures.KNOWLEDGE_WIN_KEY])
	assert_int(meta.unlocked_ids(&"treasure").size()).is_equal(db.treasure_pool().size())
	ProfileFixtures.remove_root(root)


func test_living_armory_hint_on_shipped_data_settles_ac24_at_target_one() -> void:
	# Arrange
	var db: CardDatabase = _load(func(_item: Dictionary) -> void: pass)
	var root: String = ProfileFixtures.new_root()
	var clock: ProfileFixtures.ManualClock = ProfileFixtures.ManualClock.new()
	var meta: MetaFacade = ProfileFixtures.facade(ProfileFixtures.store(root, clock), db)
	meta.load_profile()

	# Act
	var hint: Dictionary = meta.unlock_hint(ARMORY)

	# Assert: M10 / DD-X12, not AC-24's stale `target == 16`
	assert_int(hint.target).is_equal(1)
	assert_float(hint.progress).is_equal(0.0)
	assert_str(hint.text_key).is_equal(UnlockEvaluator.TEXT_KEY_PREFIX + "runs_won")
	ProfileFixtures.remove_root(root)


func test_reserved_key_has_no_definition_in_shipped_data() -> void:
	# Arrange
	var db: CardDatabase = _load(func(_item: Dictionary) -> void: pass)
	var root: String = ProfileFixtures.new_root()
	var clock: ProfileFixtures.ManualClock = ProfileFixtures.ManualClock.new()
	var meta: MetaFacade = ProfileFixtures.facade(ProfileFixtures.store(root, clock), db)
	meta.load_profile()

	# Act
	var model: Dictionary = meta.unlock_progress(ProfileFixtures.BOSSES_KEY)

	# Assert (M10: "reserved key, no treasure yet")
	assert_bool(model.met).is_false()
	assert_float(model.progress).is_equal(0.0)
	ProfileFixtures.remove_root(root)
