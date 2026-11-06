## Unit tests for `Treasures.installers_for`, `installer_warnings`,
## `passive_installer` and `collect_state` (story treasures/story-001;
## design/gdd/treasures.md T3, T4, T5.2, AC-1, AC-4, AC-10; ADR-0005 Decision
## rules 5, 8 and Key Interfaces).
##
## Every case runs on the 20 T8 records through the real `CardDatabase`
## pipeline (`TreasureFixtures.database()`), so the installers are built from
## frozen records. The `run_warning` events themselves are the caller's and are
## asserted at story 011; here the assertion is on what the caller is handed.
extends GdUnitTestSuite

const SIGNET: String = "treasure_worn_signet"
const CROWN: String = "treasure_hollow_crown"
## What a stateless run's `treasure_state` holds (T4).
const STATE_V1: Dictionary = {"schema_version": 1, "by_treasure": {}}
const TREASURES_SRC: String = "res://src/gameplay/treasures/"
const HOOK_INSTALLER_SRC: String = "res://src/gameplay/match/hook_installer.gd"
## What nothing under `src/gameplay/treasures/` may name (manifest Feature
## Forbidden, ADR-0005 guidelines): no `RunState`, log, RNG, engine or Node.
const TREASURES_FORBIDDEN: Array[String] = [
	"RunState", "run_state", "EventLog", "RulesEngine", "MatchState", "RngService",
	"RandomNumberGenerator", "randi", "randf", "shuffle", "pick_random", "Node", "Services",
]
## What `HookInstaller` may not name (ADR-0005 rule 6).
const INSTALLER_FORBIDDEN: Array[String] = [
	"RulesEngine", "EventLog", "MatchState", "HookRegistry", "Node", "Services",
]


func _treasures() -> Treasures:
	var db: CardDatabase = TreasureFixtures.database()
	return Treasures.new(db, db.config("treasures_balance"))


func _dicts(installers: Array[HookInstaller]) -> Array:
	return installers.map(func(installer: HookInstaller) -> Dictionary: return installer.to_dict())


func _host_ids(installers: Array[HookInstaller]) -> Array:
	return installers.map(func(installer: HookInstaller) -> String: return installer.host_id)


## The `TREASURES_FORBIDDEN`-style [param tokens] named in the code of
## [param text], doc comments and comments left out.
func _named_in_code(text: String, tokens: Array[String]) -> Array[String]:
	var hits: Array[String] = []
	for line: String in text.split("\n"):
		var code: String = line.get_slice("#", 0)
		for token: String in tokens:
			if code.contains(token) and not hits.has(token):
				hits.append(token)
	return hits


# --- The fixture -------------------------------------------------------------------

func test_fixture_holds_the_t8_counts() -> void:
	# Act
	var records: Array = TreasureFixtures.records()

	# Assert — T8 "Counts": 11 Common / 9 Rare; 10 / 4 / 3 / 3; 16 unlocked
	var rarity: Dictionary = {}
	var affinity: Dictionary = {}
	var keys: Array = []
	for def: Dictionary in records:
		rarity[def.rarity] = int(rarity.get(def.rarity, 0)) + 1
		affinity[def.tags[0]] = int(affinity.get(def.tags[0], 0)) + 1
		if def.unlock != null:
			keys.append(def.unlock.key)
	assert_int(records.size()).is_equal(20)
	assert_dict(rarity).is_equal({"common": 11, "rare": 9})
	assert_dict(affinity).is_equal({"universal": 10, "war": 4, "decay": 3, "knowledge": 3})
	assert_array(keys).contains_exactly_in_any_order(TreasureFixtures.UNLOCK_KEYS)


func test_fixture_living_armory_unlocks_on_first_victory() -> void:
	# Arrange
	var armory: Dictionary = TreasureFixtures.database().treasure("treasure_living_armory")

	# Assert — DD-X12: the key and a condition with no hero scope (any hero)
	assert_str(str(armory.unlock.key)).is_equal("first_victory")
	assert_str(str(armory.unlock.condition.type)).is_equal("runs_won")
	assert_int(int(armory.unlock.condition.n)).is_equal(1)
	assert_bool((armory.unlock.condition as Dictionary).has("hero")).is_false()


func test_fixture_loads_id_ascending_through_the_real_pipeline() -> void:
	# Act
	var db: CardDatabase = TreasureFixtures.database()

	# Assert — the file is in T8 order; CR-6 sorts it
	var ids: Array = db.treasure_pool().map(func(def: Dictionary) -> String: return def.id)
	assert_int(ids.size()).is_equal(20)
	GameAssertions.assert_sorted_ascending(ids)
	assert_str(str(TreasureFixtures.records()[0].id)).is_equal(CROWN)
	assert_str(str(ids[0])).is_not_equal(CROWN)


func test_fixture_effects_pass_the_real_effect_validator() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()
	var caps: Dictionary = EffectValidator.stage7_caps({"card_effects": db.config("card_effects"), "match_rules": db.config("match_rules")})
	var findings: Array = []

	# Act
	for def: Dictionary in db.treasure_pool():
		for row: Dictionary in EffectValidator.validate_effects(&"treasure", def.id, def.effects, db, caps):
			findings.append([def.id, String(row.code)])

	# Assert — the one finding is the base root's: `clean/` has no `decay_husk`
	assert_array(findings).is_equal([["treasure_grave_tithe", "E_FX_REF"]])


# --- AC-1: pure, idempotent, pick order --------------------------------------------

func test_installers_for_twice_returns_equal_results_in_pick_order() -> void:
	# Arrange
	var treasures: Treasures = _treasures()

	# Act
	var first: Array[HookInstaller] = treasures.installers_for([SIGNET, CROWN], STATE_V1)
	var second: Array[HookInstaller] = treasures.installers_for([SIGNET, CROWN], STATE_V1)

	# Assert — signet sorts after crown, so this order is pick order, not id order
	assert_array(_host_ids(first)).is_equal([SIGNET, CROWN])
	assert_array(_dicts(first)).is_equal(_dicts(second))


func test_installers_for_builds_the_t3_2_record_for_each_treasure() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()
	var treasures: Treasures = Treasures.new(db, db.config("treasures_balance"))

	# Act
	var installers: Array[HookInstaller] = treasures.installers_for([SIGNET, CROWN], STATE_V1)

	# Assert
	assert_dict(installers[0].to_dict()).is_equal({
		"host_kind": HookInstaller.HOST_KIND_TREASURE, "host_id": SIGNET, "side": &"player",
		"effects": db.treasure(SIGNET).effects, "state": {},
	})
	assert_dict(installers[1].to_dict()).is_equal({
		"host_kind": HookInstaller.HOST_KIND_TREASURE, "host_id": CROWN, "side": &"player",
		"effects": db.treasure(CROWN).effects, "state": {},
	})


func test_installers_for_gives_each_host_its_own_state_blob() -> void:
	# Arrange
	var state: Dictionary = {"schema_version": 1, "by_treasure": {SIGNET: {"charges": 2}}}

	# Act
	var installers: Array[HookInstaller] = _treasures().installers_for([SIGNET, CROWN], state)

	# Assert — T3.2: `by_treasure[host_id]` or `{}`
	assert_dict(installers[0].state).is_equal({"charges": 2})
	assert_dict(installers[1].state).is_empty()


func test_installers_for_leaves_the_treasure_state_it_was_given_unchanged() -> void:
	# Arrange
	var state: Dictionary = {"schema_version": 1, "by_treasure": {SIGNET: {"charges": 2}}}
	var before: Dictionary = state.duplicate(true)

	# Act — also write through the installer: its blob must be a copy
	var installers: Array[HookInstaller] = _treasures().installers_for([SIGNET], state)
	installers[0].state["charges"] = 9

	# Assert
	assert_dict(state).is_equal(before)


func test_installers_for_hands_out_copies_of_the_frozen_effects() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()
	var treasures: Treasures = Treasures.new(db, db.config("treasures_balance"))
	var before: Array = (db.treasure(SIGNET).effects as Array).duplicate(true)

	# Act
	var installers: Array[HookInstaller] = treasures.installers_for([SIGNET], STATE_V1)
	installers[0].effects[0]["trigger"] = "changed"

	# Assert — writable, and the record and the next call are untouched
	assert_str(str(installers[0].effects[0].trigger)).is_equal("changed")
	assert_array(db.treasure(SIGNET).effects).is_equal(before)
	assert_array(treasures.installers_for([SIGNET], STATE_V1)[0].effects).is_equal(before)


func test_installers_for_no_ids_is_empty() -> void:
	# Act
	var installers: Array[HookInstaller] = _treasures().installers_for([], STATE_V1)

	# Assert
	assert_array(installers).is_empty()


# --- AC-4: a repeated id -----------------------------------------------------------

func test_repeated_id_keeps_the_first_occurrence_only() -> void:
	# Act
	var installers: Array[HookInstaller] = _treasures().installers_for([SIGNET, CROWN, SIGNET], STATE_V1)

	# Assert
	assert_array(_host_ids(installers)).is_equal([SIGNET, CROWN])


func test_repeated_id_is_reported_to_the_caller() -> void:
	# Act
	var warnings: Array[Dictionary] = Treasures.installer_warnings([SIGNET, CROWN, SIGNET], STATE_V1)

	# Assert
	assert_array(warnings).is_equal([{"code": Treasures.WARNING_DUPLICATE_TREASURE, "treasure_id": SIGNET}])
	assert_str(Treasures.WARNING_DUPLICATE_TREASURE).is_equal("duplicate_treasure")


func test_distinct_ids_and_a_v1_state_report_nothing() -> void:
	# Act
	var warnings: Array[Dictionary] = Treasures.installer_warnings([SIGNET, CROWN], STATE_V1)

	# Assert
	assert_array(warnings).is_empty()


# --- AC-10: collect_state and an unknown schema_version ----------------------------

func test_collect_state_returns_the_v1_shape_for_any_subset() -> void:
	# Arrange
	var treasures: Treasures = _treasures()
	var result: Dictionary = MatchRecords.match_result(MatchRecords.RESULT_WIN, MatchRecords.SIDE_PLAYER, MatchRecords.REASON_HERO_DEAD, 1, 9)
	var all_ids: Array = TreasureFixtures.records().map(func(def: Dictionary) -> String: return def.id)

	for ids: Array in [[], [SIGNET], [SIGNET, CROWN], all_ids.slice(0, 3)]:
		var hooks: HookRegistry = HookRegistry.new()
		for installer: HookInstaller in treasures.installers_for(ids, STATE_V1):
			hooks.install(installer)

		# Act
		var collected: Dictionary = treasures.collect_state(hooks, result)

		# Assert
		assert_dict(collected).is_equal({"schema_version": 1, "by_treasure": {}})


func test_collect_state_does_not_depend_on_the_match_result() -> void:
	# Arrange
	var treasures: Treasures = _treasures()
	var hooks: HookRegistry = HookRegistry.new()
	var win: Dictionary = MatchRecords.match_result(MatchRecords.RESULT_WIN, MatchRecords.SIDE_PLAYER, MatchRecords.REASON_HERO_DEAD, 1, 9)
	var fault: Dictionary = MatchRecords.match_result(MatchRecords.RESULT_FAULT, null, MatchRecords.REASON_EVENT_CAP, 4, 30)

	# Act / Assert
	assert_dict(treasures.collect_state(hooks, win)).is_equal(treasures.collect_state(hooks, fault))


func test_collect_state_returns_a_new_blob_each_call() -> void:
	# Arrange
	var treasures: Treasures = _treasures()
	var hooks: HookRegistry = HookRegistry.new()
	var result: Dictionary = MatchRecords.match_result(MatchRecords.RESULT_WIN, MatchRecords.SIDE_PLAYER, MatchRecords.REASON_HERO_DEAD, 1, 9)

	# Act — the run owns what it stores
	var first: Dictionary = treasures.collect_state(hooks, result)
	first.by_treasure["x"] = {}

	# Assert
	assert_dict(treasures.collect_state(hooks, result).by_treasure).is_empty()


func test_unknown_schema_version_builds_a_stateless_run() -> void:
	# Arrange
	var treasures: Treasures = _treasures()
	var stale: Dictionary = {"schema_version": 99, "by_treasure": {SIGNET: {"charges": 2}}}

	# Act
	var installers: Array[HookInstaller] = treasures.installers_for([SIGNET, CROWN], stale)

	# Assert
	assert_array(_dicts(installers)).is_equal(_dicts(treasures.installers_for([SIGNET, CROWN], STATE_V1)))
	assert_dict(installers[0].state).is_empty()


func test_unknown_schema_version_is_reported_to_the_caller() -> void:
	# Act
	var warnings: Array[Dictionary] = Treasures.installer_warnings([SIGNET], {"schema_version": 99, "by_treasure": {}})

	# Assert
	assert_array(warnings).is_equal([{"code": Treasures.WARNING_TREASURE_STATE_RESET}])
	assert_str(Treasures.WARNING_TREASURE_STATE_RESET).is_equal("treasure_state_reset")


func test_missing_schema_version_is_unknown() -> void:
	# Arrange — run-structure R1: "a missing or unknown version is repaired on resume"
	var state: Dictionary = {"by_treasure": {SIGNET: {"charges": 2}}}

	# Act
	var installers: Array[HookInstaller] = _treasures().installers_for([SIGNET], state)
	var warnings: Array[Dictionary] = Treasures.installer_warnings([SIGNET], state)

	# Assert
	assert_dict(installers[0].state).is_empty()
	assert_array(warnings).is_equal([{"code": Treasures.WARNING_TREASURE_STATE_RESET}])


func test_schema_version_of_another_type_is_unknown() -> void:
	# Arrange — a hand-edited save
	var state: Dictionary = {"schema_version": "1", "by_treasure": {SIGNET: {"charges": 2}}}

	# Act
	var installers: Array[HookInstaller] = _treasures().installers_for([SIGNET], state)
	var warnings: Array[Dictionary] = Treasures.installer_warnings([SIGNET], state)

	# Assert
	assert_dict(installers[0].state).is_empty()
	assert_array(warnings).is_equal([{"code": Treasures.WARNING_TREASURE_STATE_RESET}])


func test_schema_version_read_back_from_json_is_known() -> void:
	# Arrange — a save round trip turns 1 into 1.0
	var state: Dictionary = JSON.parse_string(JSON.stringify({"schema_version": 1, "by_treasure": {SIGNET: {"charges": 2}}}))

	# Act
	var installers: Array[HookInstaller] = _treasures().installers_for([SIGNET], state)
	var warnings: Array[Dictionary] = Treasures.installer_warnings([SIGNET], state)

	# Assert
	assert_dict(installers[0].state).is_not_empty()
	assert_array(warnings).is_empty()


func test_a_repeated_id_and_a_reset_are_both_reported() -> void:
	# Act
	var warnings: Array[Dictionary] = Treasures.installer_warnings([SIGNET, SIGNET], {"schema_version": 99})

	# Assert
	assert_array(warnings).contains_exactly_in_any_order([
		{"code": Treasures.WARNING_DUPLICATE_TREASURE, "treasure_id": SIGNET},
		{"code": Treasures.WARNING_TREASURE_STATE_RESET},
	])


# --- AC-T3.1: the boss passive -----------------------------------------------------

func test_passive_installer_of_a_boss_with_no_passive_is_empty() -> void:
	# Arrange
	var boss: Dictionary = CardFactory.make_boss_def("boss_test_plain", 1)

	# Act
	var installers: Array[HookInstaller] = Treasures.passive_installer(boss)

	# Assert
	assert_array(installers).is_empty()


func test_passive_installer_of_the_taxman_is_one_boss_side_installer() -> void:
	# Arrange
	var boss: Dictionary = TreasureFixtures.make_boss_test_taxman()

	# Act
	var installers: Array[HookInstaller] = Treasures.passive_installer(boss)

	# Assert — `passive` is one effect object, wrapped into `effects`
	assert_int(installers.size()).is_equal(1)
	assert_dict(installers[0].to_dict()).is_equal({
		"host_kind": HookInstaller.HOST_KIND_PASSIVE, "host_id": "boss_test_taxman", "side": &"boss",
		"effects": [boss.passive], "state": {},
	})


func test_passive_installer_reads_a_frozen_boss_record() -> void:
	# Arrange — `db.boss()` hands out deep read-only records
	var boss: Dictionary = TreasureFixtures.make_boss_test_taxman()
	(boss.passive as Dictionary).make_read_only()
	boss.make_read_only()

	# Act
	var installers: Array[HookInstaller] = Treasures.passive_installer(boss)
	installers[0].effects[0]["trigger"] = "changed"

	# Assert — the installer's copy is writable and the record is not touched
	assert_str(str(installers[0].effects[0].trigger)).is_equal("changed")
	assert_str(str(boss.passive.trigger)).is_equal("modify_cost")


func test_the_taxman_passive_installs_one_modify_cost_entry() -> void:
	# Arrange
	var hooks: HookRegistry = HookRegistry.new()

	# Act
	hooks.install(Treasures.passive_installer(TreasureFixtures.make_boss_test_taxman())[0])

	# Assert
	var entries: Array = hooks.entries(&"modify_cost")
	assert_int(entries.size()).is_equal(1)
	assert_str(str(entries[0].host_id)).is_equal("boss_test_taxman")
	assert_str(String(entries[0].side)).is_equal("boss")
	assert_str(str(entries[0].effect_id)).is_equal("boss_test_taxman.0")


func test_the_taxman_fixture_adds_one_to_cards_and_the_hero_power() -> void:
	# Act
	var passive: Dictionary = TreasureFixtures.make_boss_test_taxman().passive

	# Assert — C2: `kind: any` matches cards and the hero power; without it, cards only.
	# DD-X28: `enemy` taxes the player; T2.4 reads `friendly` from the entry's boss side
	assert_str(str(passive.trigger)).is_equal("modify_cost")
	assert_str(str(passive.scope.card.kind)).is_equal("any")
	assert_str(str(passive.scope.card.side)).is_equal("enemy")
	assert_array(passive.ops).is_equal([{"op": "modify_value", "delta": 1}])


func test_the_taxman_fixture_is_a_valid_bossdef() -> void:
	# Arrange
	var report: ValidationReport = ValidationReport.new()

	# Act
	var clean: bool = RecordSchemas.check_record("BossDef", "bosses.json", 0, TreasureFixtures.make_boss_test_taxman(), report)

	# Assert
	assert_array(report.entries()).is_empty()
	assert_bool(clean).is_true()


func test_the_taxman_passive_passes_the_real_effect_validator() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()
	var caps: Dictionary = EffectValidator.stage7_caps({"card_effects": db.config("card_effects"), "match_rules": db.config("match_rules")})
	var boss: Dictionary = TreasureFixtures.make_boss_test_taxman()

	# Act
	var findings: Array = EffectValidator.validate_effects(&"boss", boss.id, [boss.passive], db, caps)

	# Assert
	assert_array(findings).is_empty()


# --- Forbidden references ----------------------------------------------------------

func test_scan_finds_a_forbidden_name_in_code_and_skips_comments() -> void:
	# Act / Assert — so a clean scan below means the scan looked
	assert_array(_named_in_code("var log: EventLog", TREASURES_FORBIDDEN)).is_equal(["EventLog"])
	assert_array(_named_in_code("## no EventLog here", TREASURES_FORBIDDEN)).is_empty()
	assert_array(_named_in_code("var x: int = 1  # no EventLog", TREASURES_FORBIDDEN)).is_empty()


func test_nothing_under_treasures_names_run_state_a_log_or_rng() -> void:
	# Arrange
	var files: PackedStringArray = DirAccess.get_files_at(TREASURES_SRC)
	var scanned: int = 0
	var hits: Array[String] = []

	# Act
	for file: String in files:
		if file.get_extension() == "gd":
			scanned += 1
			hits.append_array(_named_in_code(FileAccess.get_file_as_string(TREASURES_SRC + file), TREASURES_FORBIDDEN))

	# Assert
	assert_int(scanned).is_greater(0)
	assert_array(hits).is_empty()


func test_hook_installer_names_no_engine_log_registry_or_node() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string(HOOK_INSTALLER_SRC)

	# Act
	var hits: Array[String] = _named_in_code(text, INSTALLER_FORBIDDEN)

	# Assert
	assert_str(text).contains("class_name HookInstaller")
	assert_array(hits).is_empty()
