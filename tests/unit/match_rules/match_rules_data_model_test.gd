## Unit tests for the match data model, derived values and rules config
## (story match-rules/story-001; design/gdd/match-rules.md C1, C3 step 1, F6,
## F9, Tuning Knobs; AC-41).
##
## The engine is built directly with `RulesEngine.new(db, rules_config,
## resolver)` and a fixture state — never through `Boot` (ADR-0001). No
## `CardDatabase` or `EffectResolver` exists yet; both are passed as `null`
## (the constructor only stores them). The rules body is
## `MatchFactory.make_rules_config()`, built from `TestConstants`.
##
## No test here reads a file: the AC-41 checks that read the shipped
## `assets/data/match_rules.json` (through `DataLoader`), the GDD Tuning Knobs
## table and the `src/` tree live in
## `tests/integration/match_rules/match_rules_config_file_test.gd`.
extends GdUnitTestSuite

## Field names a derived value would carry if it were (wrongly) stored (C1).
const DERIVED_FIELDS: Array[String] = ["health", "max_health", "attack", "max_attacks", "attacks_remaining", "has_windfury"]

## C1 field lists (normative; `tests/helpers/match_factory.gd` produces them).
const CHARACTER_FIELDS: Array[String] = [
	"entity_id", "controller", "base_attack", "base_health", "enchantments", "damage_taken",
	"keywords", "attacks_used", "frozen", "frozen_on_turn", "silenced",
]
const HERO_EXTRA_FIELDS: Array[String] = ["kind", "armor"]
const MINION_EXTRA_FIELDS: Array[String] = ["kind", "def_id", "summoning_sick", "summoned_on_turn"]
const PLAYER_STATE_FIELDS: Array[String] = [
	"hero", "mana_current", "mana_max", "crystal_bonus", "temporary_crystals", "deck", "hand", "board", "weapon",
	"hero_power", "fatigue_counter", "graveyard", "resolving", "turns_taken", "stats",
]
const ENCHANTMENT_FIELDS: Array[String] = ["source_entity_id", "attack_delta", "health_delta", "keywords_added", "is_aura", "expires"]
const WEAPON_FIELDS: Array[String] = ["entity_id", "def_id", "attack", "durability", "keywords", "enchantments"]
const CARD_INSTANCE_FIELDS: Array[String] = ["instance_id", "def_id", "zone", "cost_modifiers"]
const COMMAND_RESULT_FIELDS: Array[String] = ["accepted", "rejection", "events"]
const MATCH_RESULT_FIELDS: Array[String] = ["result", "winner", "reason", "floor", "turns", "turns_per_side", "stats", "final_health"]
const MATCH_STATE_FIELDS: Array[String] = [
	"turn", "active_side", "phase", "players", "pending_choice", "result", "next_entity_id",
	"hooks", "effects", "floor", "log", "rng_match",
	# match-rules story 016: the action a pending choice paused (plain data)
	"suspended_queue", "suspended_steps", "suspended_action",
]
const EFFECT_RUNTIME_FIELDS: Array[String] = ["once_marks", "counters", "per_turn", "pending_choice", "aura_hosts"]


# --- helpers -----------------------------------------------------------------

func _engine(overrides: Dictionary = {}) -> RulesEngine:
	return RulesEngine.new(null, MatchFactory.make_rules_config(overrides), null)


func _engine_with_state(state: MatchState, overrides: Dictionary = {}) -> RulesEngine:
	var engine: RulesEngine = _engine(overrides)
	engine.load_state(state)
	return engine


func _sorted(items: Array) -> Array:
	var out: Array = items.duplicate()
	out.sort()
	return out


## Every key of every Dictionary reachable from `value`, depth-first.
func _collect_keys(value: Variant, out: Array) -> Array:
	if value is Dictionary:
		for key: Variant in value:
			out.append(str(key))
			_collect_keys(value[key], out)
	elif value is Array:
		for item: Variant in value:
			_collect_keys(item, out)
	return out


## Every Object reachable from `value`, depth-first.
func _collect_objects(value: Variant, out: Array) -> Array:
	if value is Object:
		out.append(value)
	elif value is Dictionary:
		for key: Variant in value:
			_collect_objects(value[key], out)
	elif value is Array:
		for item: Variant in value:
			_collect_objects(item, out)
	return out


func _script_fields(object: Object) -> Array:
	var fields: Array = []
	for property: Dictionary in object.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property.name)
	return fields


func _hero_with_weapon(state: MatchState, weapon_keywords: Array) -> Dictionary:
	var player: Dictionary = state.players[MatchFactory.SIDE_PLAYER]
	player.weapon = MatchFactory.make_weapon(MatchFactory.alloc_entity_id(state), TestConstants.MAX_ATTACKS_WINDFURY, TestConstants.MAX_ATTACKS_WINDFURY, "test_axe", weapon_keywords)
	return player.hero


# --- AC-41: knobs come from the injected rules_config -------------------------

func test_engine_reads_every_knob_from_the_injected_rules_config() -> void:
	# Arrange — every knob shifted off its default, so a literal cannot pass
	var shifted: Dictionary = {}
	for i: int in RulesEngine.CONFIG_KEYS.size():
		var key: String = RulesEngine.CONFIG_KEYS[i]
		shifted[key] = int(MatchFactory.make_rules_config()[key]) + i + 1
	var body: Dictionary = MatchFactory.make_rules_config(shifted)

	# Act
	var engine: RulesEngine = RulesEngine.new(null, body, null)

	# Assert — read once at construction and kept as a reference
	assert_bool(is_same(engine.rules_config(), body)).is_true()
	for key: String in RulesEngine.CONFIG_KEYS:
		assert_int(engine.rule(key)).override_failure_message("rule(%s)" % key).is_equal(int(shifted[key]))


# --- C1 derived values --------------------------------------------------------

func test_buffed_damaged_minion_derives_max_health_and_health() -> void:
	# Arrange — base_health 2, one enchantment health_delta +2, damage_taken 3
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state)
	var minion: Dictionary = MatchFactory.summon(state, MatchFactory.SIDE_PLAYER, 2, 2)
	minion.enchantments.append(MatchFactory.make_enchantment(0, 2))
	minion.damage_taken = 3

	# Act / Assert
	assert_int(engine.max_health(minion)).is_equal(4)
	assert_int(engine.health(minion)).is_equal(1)


func test_hero_with_windfury_weapon_derives_attack_and_two_attacks() -> void:
	# Arrange — a hero with a 2-attack Windfury weapon
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state)
	var hero: Dictionary = _hero_with_weapon(state, [MatchRecords.KEYWORD_WINDFURY])

	# Act / Assert
	assert_int(engine.attack(hero)).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)
	assert_bool(engine.has_windfury(hero)).is_true()
	assert_int(engine.max_attacks(hero)).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)
	for used: int in [0, 1, 2]:
		hero.attacks_used = used
		assert_int(engine.attacks_remaining(hero)).is_equal(TestConstants.MAX_ATTACKS_WINDFURY - used)


func test_hero_enchantment_grants_windfury_without_a_weapon() -> void:
	# Arrange — "your hero has Windfury this turn" (C1)
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state)
	var hero: Dictionary = state.players[MatchFactory.SIDE_PLAYER].hero
	hero.enchantments.append(MatchFactory.make_enchantment(0, 0, [MatchRecords.KEYWORD_WINDFURY], null, false, MatchRecords.EXPIRES_END_OF_TURN))

	# Act / Assert
	assert_bool(engine.has_windfury(hero)).is_true()
	assert_int(engine.max_attacks(hero)).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)
	assert_int(engine.attack(hero)).is_zero()


func test_weapon_without_windfury_leaves_one_attack() -> void:
	# Arrange — edge case: the hero's weapon loses (here: never had) Windfury
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state)
	var hero: Dictionary = _hero_with_weapon(state, [])

	# Act / Assert
	assert_bool(engine.has_windfury(hero)).is_false()
	assert_int(engine.max_attacks(hero)).is_equal(engine.max_attacks(MatchFactory.summon(state, MatchFactory.SIDE_BOSS, 1, 1)))
	assert_int(engine.max_attacks(hero)).is_equal(RulesEngine.ATTACKS_PER_TURN)


func test_removing_windfury_weapon_returns_max_attacks_to_one() -> void:
	# Arrange
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state)
	var hero: Dictionary = _hero_with_weapon(state, [MatchRecords.KEYWORD_WINDFURY])
	assert_int(engine.max_attacks(hero)).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)

	# Act
	state.players[MatchFactory.SIDE_PLAYER].weapon = null

	# Assert — nothing stored went stale
	assert_bool(engine.has_windfury(hero)).is_false()
	assert_int(engine.max_attacks(hero)).is_equal(RulesEngine.ATTACKS_PER_TURN)
	assert_int(engine.attack(hero)).is_zero()


func test_max_attacks_is_clamped_to_max_attacks_cap_from_config() -> void:
	# Arrange — a cap below Windfury's count (data, not code, sets the bound)
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state, {"max_attacks_cap": RulesEngine.ATTACKS_PER_TURN})
	var hero: Dictionary = _hero_with_weapon(state, [MatchRecords.KEYWORD_WINDFURY])

	# Act / Assert
	assert_bool(engine.has_windfury(hero)).is_true()
	assert_int(engine.max_attacks(hero)).is_equal(RulesEngine.ATTACKS_PER_TURN)


func test_health_goes_non_positive_when_damage_reaches_max_health() -> void:
	# Arrange — F6: health may be ≤ 0 transiently; no stored field clamps it
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state)
	var minion: Dictionary = MatchFactory.summon(state, MatchFactory.SIDE_BOSS, 1, 3)

	# Act
	minion.damage_taken = 5

	# Assert
	assert_int(engine.health(minion)).is_equal(-2)
	assert_int(engine.max_health(minion)).is_equal(3)


func test_enchantment_removal_lowers_health_with_damage_unchanged() -> void:
	# Arrange — F6 example: 2/2 buffed to 2/4, damaged to 2/1 (damage_taken 3)
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state)
	var minion: Dictionary = MatchFactory.summon(state, MatchFactory.SIDE_PLAYER, 2, 2)
	minion.enchantments.append(MatchFactory.make_enchantment(0, 2, [], null, true))
	minion.damage_taken = 3

	# Act — the aura leaves
	minion.enchantments.clear()

	# Assert — 2 − 3 = −1, damage_taken untouched
	assert_int(engine.health(minion)).is_equal(-1)
	assert_int(minion.damage_taken).is_equal(3)


func test_attack_never_goes_below_zero() -> void:
	# Arrange
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state)
	var minion: Dictionary = MatchFactory.summon(state, MatchFactory.SIDE_PLAYER, 1, 1)

	# Act
	minion.enchantments.append(MatchFactory.make_enchantment(-3, 0))

	# Assert
	assert_int(engine.attack(minion)).is_zero()


func test_no_record_stores_a_derived_value() -> void:
	# Arrange — every record kind, populated
	var state: MatchState = MatchFactory.make_match_state()
	var minion: Dictionary = MatchFactory.summon(state, MatchFactory.SIDE_PLAYER, 2, 2, -1, ["taunt"])
	minion.enchantments.append(MatchFactory.make_enchantment(1, 1))
	_hero_with_weapon(state, [MatchRecords.KEYWORD_WINDFURY])
	MatchFactory.deal_deck(state, MatchFactory.SIDE_BOSS, ["boss_test_card"])
	MatchFactory.draw_top(state, MatchFactory.SIDE_BOSS)

	# Act — characters (heroes, minions), their enchantments, the PlayerStates
	# and MatchState itself. A Weapon's own `attack` is stored data (C1 Weapon),
	# so weapons are not scanned for it.
	var keys: Array = _script_fields(state)
	for side: String in state.players:
		var player: Dictionary = state.players[side]
		keys.append_array(player.keys())
		keys.append_array(_collect_keys(player.hero, []))
		keys.append_array(_collect_keys(player.board, []))
	keys.append_array(_collect_keys(state.effects, []))

	# Assert
	assert_bool(keys.has("damage_taken")).is_true()
	for field: String in DERIVED_FIELDS:
		assert_bool(keys.has(field)).override_failure_message("stored derived field '%s'" % field).is_false()


# --- C1 / C3 step 1: MatchState shape, record fields, snapshot ----------------

func test_match_state_from_config_holds_exactly_c1_fields() -> void:
	# Arrange
	var rng: TestRngService = TestRngService.new()
	var log: TestEventLog = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_match_config(3, rng, log)
	var engine: RulesEngine = _engine()

	# Act
	var state: MatchState = MatchState.from_config(config)
	engine.load_state(state)

	# Assert
	assert_array(_sorted(_script_fields(state))).is_equal(_sorted(MATCH_STATE_FIELDS))
	assert_object(engine.state()).is_same(state)
	assert_object(state.log).is_same(log)
	assert_object(state.rng_match).is_same(rng.stream("match_3"))
	assert_int(state.floor).is_equal(3)
	assert_int(state.turn).is_zero()
	assert_str(state.phase).is_equal(MatchState.PHASE_SETUP)
	assert_str(state.active_side).is_equal(MatchFactory.SIDE_PLAYER)
	assert_object(state.pending_choice).is_null()
	assert_object(state.result).is_null()
	assert_int(state.next_entity_id).is_equal(MatchState.FIRST_ENTITY_ID)
	assert_array(_sorted(state.players.keys())).is_equal(_sorted([MatchFactory.SIDE_PLAYER, MatchFactory.SIDE_BOSS]))
	assert_array(_sorted(state.effects.keys())).is_equal(_sorted(EFFECT_RUNTIME_FIELDS))
	for side: String in state.players:
		assert_array(_sorted(state.players[side].keys())).is_equal(_sorted(PLAYER_STATE_FIELDS))
		assert_int(state.players[side].crystal_bonus).is_zero()


func test_records_carry_the_c1_field_names() -> void:
	# Act
	var hero: Dictionary = MatchRecords.hero(1, MatchRecords.SIDE_PLAYER, TestConstants.PLAYER_STARTING_HEALTH)
	var minion: Dictionary = MatchRecords.minion(3, MatchRecords.SIDE_BOSS, 1, 1)
	var hero_fields: Array = CHARACTER_FIELDS.duplicate()
	hero_fields.append_array(HERO_EXTRA_FIELDS)
	var minion_fields: Array = CHARACTER_FIELDS.duplicate()
	minion_fields.append_array(MINION_EXTRA_FIELDS)

	# Assert — production builders and the factory agree field for field
	assert_array(_sorted(hero.keys())).is_equal(_sorted(hero_fields))
	assert_int(hero.base_attack).is_zero()
	assert_array(_sorted(minion.keys())).is_equal(_sorted(minion_fields))
	assert_array(_sorted(MatchRecords.enchantment().keys())).is_equal(_sorted(ENCHANTMENT_FIELDS))
	assert_array(_sorted(MatchRecords.weapon(4, "axe", 1, 1).keys())).is_equal(_sorted(WEAPON_FIELDS))
	assert_array(_sorted(MatchRecords.card_instance(5, "card").keys())).is_equal(_sorted(CARD_INSTANCE_FIELDS))
	assert_array(_sorted(MatchRecords.command_result(true).keys())).is_equal(_sorted(COMMAND_RESULT_FIELDS))
	assert_array(_sorted(MatchRecords.match_result("fault", MatchRecords.SIDE_BOSS, "event_cap", 1, 0).keys())).is_equal(_sorted(MATCH_RESULT_FIELDS))
	assert_object(MatchRecords.match_result("fault", MatchRecords.SIDE_BOSS, "event_cap", 1, 0).winner).is_null()
	assert_dict(MatchFactory.make_hero(MatchFactory.SIDE_PLAYER)).is_equal(hero)
	assert_array(_sorted(MatchFactory.make_player_state(MatchFactory.SIDE_BOSS).keys())).is_equal(_sorted(PLAYER_STATE_FIELDS))


func test_state_snapshot_is_a_json_representable_value_copy() -> void:
	# Arrange
	var state: MatchState = MatchFactory.make_match_state()
	var engine: RulesEngine = _engine_with_state(state)
	var minion: Dictionary = MatchFactory.summon(state, MatchFactory.SIDE_BOSS, 3, 4, -1, ["taunt"])
	minion.enchantments.append(MatchFactory.make_enchantment(1, 0, ["stealth"], MatchFactory.BOSS_HERO_ENTITY_ID))
	MatchFactory.deal_deck(state, MatchFactory.SIDE_PLAYER, ["war_starter_01"])
	var card_id: int = state.players[MatchFactory.SIDE_PLAYER].deck[0].instance_id

	# Act
	var snap: Dictionary = engine.state_snapshot(minion.entity_id)
	snap.damage_taken = 99
	snap.enchantments[0].attack_delta = 99

	# Assert
	GameAssertions.assert_json_representable(engine.state_snapshot(minion.entity_id), "minion snapshot")
	GameAssertions.assert_json_representable(engine.state_snapshot(MatchFactory.PLAYER_HERO_ENTITY_ID), "hero snapshot")
	assert_int(minion.damage_taken).is_zero()
	assert_int(minion.enchantments[0].attack_delta).is_equal(1)
	assert_str(engine.state_snapshot(card_id).def_id).is_equal("war_starter_01")
	assert_dict(engine.state_snapshot(state.next_entity_id + 100)).is_empty()
	assert_dict(_engine().state_snapshot(MatchFactory.PLAYER_HERO_ENTITY_ID)).is_empty()


func test_no_record_references_a_node() -> void:
	# Arrange — a populated state wired to a log and a stream
	var rng: TestRngService = TestRngService.new()
	var log: TestEventLog = TestEventLog.new()
	var state: MatchState = MatchState.from_config(MatchFactory.make_match_config(1, rng, log))
	state.players[MatchFactory.SIDE_PLAYER] = MatchFactory.make_player_state(MatchFactory.SIDE_PLAYER)
	state.players[MatchFactory.SIDE_BOSS] = MatchFactory.make_player_state(MatchFactory.SIDE_BOSS)
	state.next_entity_id = MatchFactory.BOSS_HERO_ENTITY_ID + 1
	MatchFactory.summon(state, MatchFactory.SIDE_PLAYER, 1, 1)
	_hero_with_weapon(state, [])

	# Act
	var record_objects: Array = _collect_objects(state.players, [])
	record_objects.append_array(_collect_objects(state.effects, []))

	# Assert — records hold no object at all; the state's references are not Nodes (DD-T02)
	assert_array(record_objects).is_empty()
	GameAssertions.assert_json_representable(state.players, "players")
	GameAssertions.assert_json_representable(state.effects, "effects")
	for field: String in ["log", "rng_match", "hooks"]:
		assert_bool(state.get(field) is Node).override_failure_message("%s is a Node" % field).is_false()
	var as_object: Object = state
	assert_bool(as_object is Node).is_false()
