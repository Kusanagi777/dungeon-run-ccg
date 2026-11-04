## Integration: the player hero seated from its `HeroDef` (heroes story 001;
## heroes.md H-1, H-3, Edge Cases "Whetstone" and "Hero power — generic", AC-7,
## AC-8, AC-19; match-rules C3 step 2, C7).
##
## War runs on the shipped `res://assets/data/` through the real `DataLoader`,
## `CardDatabase` and `EffectResolver`, with the validator map `Boot` composes (a
## fresh, `auto_free`d Boot instance, never the autoload; debug severity). Nothing
## here sets `hero_power.def_id` or `base_health`: both are read back from what
## `RulesEngine.start` seated.
##
## `tests/fixtures/data/heroes_fixture_hero/` is the `minimal` root plus two heroes
## that exist nowhere else: `hero_fixture_wounded` (27 health: shipped War's 30
## equals the knob, so only this hero tells the record from the knob) and
## `hero_fixture_fourth` (a `fortune` set of its own and the existing
## `power_whetstone`, AC-19's data-only fourth hero). Its `power_whetstone` and
## `war_whetstone_blade` are the shipped records verbatim. `hero_fixture_scholar`
## holds the root's other power, `power_fixture_study`: every other hero here uses
## Whetstone, so only this hero tells the record from a literal (code review T1).
##
## The player has 1 mana on turn 1 and Whetstone costs 2, so every power below is
## used on the player's second turn, reached by real `end_turn` commands.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SHIPPED_ROOT: String = "res://assets/data/"
const FIXTURE_ROOT: String = "res://tests/fixtures/data/heroes_fixture_hero/"

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS

const HERO_WAR: String = "hero_war"
const HERO_WOUNDED: String = "hero_fixture_wounded"
const HERO_FOURTH: String = "hero_fixture_fourth"
const HERO_SCHOLAR: String = "hero_fixture_scholar"
const HERO_UNKNOWN: String = "hero_not_in_the_data"
const POWER_WHETSTONE: String = "power_whetstone"
const POWER_STUDY: String = "power_fixture_study"
const BLADE: String = "war_whetstone_blade"
const AXE: String = "war_rusted_axe"
## Heroes Edge Cases "Whetstone": the held Windfury weapon (`war_twin_hatchets`,
## 2/4, Windfury, the only shipped one).
const WINDFURY_WEAPON: String = "war_twin_hatchets"

## `hero_fixture_wounded.health` in the fixture root (AC-1).
const WOUNDED_HEALTH: int = 27
## The Blade's printed stats (heroes H-3, AC-7).
const BLADE_ATTACK: int = 1
const BLADE_DURABILITY: int = 2
## `war_rusted_axe`'s printed Attack and the Whetstone delta (AC-8).
const AXE_ATTACK: int = 2
const WHETSTONE_DELTA: int = 1
## `war_twin_hatchets`' printed Attack and Durability.
const WINDFURY_ATTACK: int = 2
const WINDFURY_DURABILITY: int = 4
## A `starting_health_player` no record carries, inside the knob's 25-40 safe
## range, so a seated value can only be the knob.
const KNOB_HEALTH: int = 35
## A `hero_power_cost` the `HeroPowerDef.cost` of 2 does not match, inside 1-3.
const RULE_POWER_COST: int = 1

## What `start` logs for a `hero_def_id` with no record.
const NO_RECORD_MESSAGE: String = "RulesEngine.start: no HeroDef \"%s\": seating starting_health_player, no hero power (match-rules C3 step 2)"

var _db: CardDatabase
var _engine: RulesEngine
var _log: TestEventLog


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null


func _map() -> Dictionary:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	return boot._collect_validators(null, true)


func _loaded(root: String) -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(root))
	db.load(_map())
	return db


## A `MatchConfig` seating [param hero_id] with [param deck] on both sides: only
## the player hero is under test, and `start` reads no boss record.
func _config(hero_id: String, deck: Array) -> Dictionary:
	_log = TestEventLog.new()
	return MatchFactory.make_started_config(TestRngService.new(), _log, {
		"player": {"hero_def_id": hero_id, "deck": deck.duplicate()},
		"boss": {"deck": deck.duplicate()},
	})


## An unstarted engine over [param db] and its real resolver, the `match_rules`
## body with [param rule_overrides] applied.
func _engine_over(db: CardDatabase, hero_set: String, rule_overrides: Dictionary = {}) -> RulesEngine:
	var rules: Dictionary = (db.config("match_rules") as Dictionary).duplicate(true)
	rules.merge(rule_overrides, true)
	return RulesEngine.new(db, rules, EffectResolver.new(db, db.config("card_effects"), hero_set))


## An engine over [param db] started on [param hero_id], phase Mulligan.
func _started(db: CardDatabase, hero_id: String, rule_overrides: Dictionary = {}) -> RulesEngine:
	var hero: Dictionary = db.hero(hero_id)
	_engine = _engine_over(db, str(hero.set), rule_overrides)
	_engine.start(_config(hero_id, Array(hero.starter_deck)))
	return _engine


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message("rejected: %s" % str(result.rejection)).is_true()


## Keep-all mulligan, then both `end_turn`s: the player's second Main.
func _to_second_turn() -> void:
	_submit(_engine.legal_commands()[0])
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	_submit(MatchRecords.end_turn(SIDE_BOSS))


## War on shipped data at the player's second Main, with exactly 2 mana.
func _war_second_turn(rule_overrides: Dictionary = {}) -> void:
	_db = _loaded(SHIPPED_ROOT)
	_started(_db, HERO_WAR, rule_overrides)
	_to_second_turn()
	assert_int(int(_player().mana_current)).is_equal(TestConstants.HERO_POWER_COST)


func _player() -> Dictionary:
	return _engine.state().players[SIDE_PLAYER]


func _hero_id(side: String) -> int:
	return int(_engine.state().players[side].hero.entity_id)


func _hero_attack() -> int:
	return _engine.attack(_player().hero)


func _last_seq() -> int:
	return int(_log.events.back().seq)


func _since(seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > seq)


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


# --- AC-1: C3 step 2 reads the HeroDef -----------------------------------------------

func test_war_on_shipped_data_seats_the_records_health_and_power() -> void:
	# Arrange
	var db: CardDatabase = _loaded(SHIPPED_ROOT)

	# Act
	_started(db, HERO_WAR)

	# Assert — read from the record: the test sets neither
	assert_int(int(_player().hero.base_health)).is_equal(int(db.hero(HERO_WAR).health))
	assert_int(int(_player().hero.base_health)).is_equal(TestConstants.PLAYER_STARTING_HEALTH)
	assert_str(str(_player().hero_power.def_id)).is_equal(POWER_WHETSTONE)
	assert_bool(bool(_player().hero_power.used_this_turn)).is_false()


func test_a_fixture_hero_with_27_health_seats_at_27_of_27() -> void:
	# Arrange
	var db: CardDatabase = _loaded(FIXTURE_ROOT)

	# Act
	_started(db, HERO_WOUNDED)

	# Assert
	assert_int(MatchFactory.health_of(_player().hero)).is_equal(WOUNDED_HEALTH)
	assert_int(MatchFactory.max_health_of(_player().hero)).is_equal(WOUNDED_HEALTH)


func test_the_record_outranks_the_starting_health_knob() -> void:
	# Arrange
	var db: CardDatabase = _loaded(FIXTURE_ROOT)

	# Act — a knob no record carries
	_started(db, HERO_WOUNDED, {"starting_health_player": KNOB_HEALTH})

	# Assert
	assert_int(int(_player().hero.base_health)).is_equal(WOUNDED_HEALTH)


func test_a_hero_seats_the_power_its_record_names_and_uses_it() -> void:
	# Arrange
	var db: CardDatabase = _loaded(FIXTURE_ROOT)

	# Act
	_started(db, HERO_SCHOLAR)

	# Assert — seated from the record, and it is the power that then resolves
	assert_str(str(_player().hero_power.def_id)).is_equal(POWER_STUDY)
	_to_second_turn()
	var before: int = _last_seq()
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	var events: Array = _since(before)
	assert_str(str(_of_type(events, "hero_power_used")[0].payload.power_id)).is_equal(POWER_STUDY)
	assert_array(_of_type(events, "weapon_equipped")).is_empty()


func test_the_boss_hero_still_seats_from_the_config_health() -> void:
	# Arrange
	var db: CardDatabase = _loaded(SHIPPED_ROOT)
	var hero: Dictionary = db.hero(HERO_WAR)
	var config: Dictionary = _config(HERO_WAR, Array(hero.starter_deck))
	config.boss.health = KNOB_HEALTH
	_engine = _engine_over(db, str(hero.set))

	# Act
	_engine.start(config)

	# Assert — and no boss hero power: no MVP boss has one (story 001 notes)
	assert_int(int(_engine.state().players[SIDE_BOSS].hero.base_health)).is_equal(KNOB_HEALTH)
	assert_str(str(_engine.state().players[SIDE_BOSS].hero_power.def_id)).is_empty()


# --- C3 step 2's default: a `hero_def_id` with no record -----------------------------

func test_an_unknown_hero_def_id_seats_the_knob_and_logs_the_error() -> void:
	# Arrange
	var db: CardDatabase = _loaded(SHIPPED_ROOT)
	var config: Dictionary = _config(HERO_UNKNOWN, Array(db.hero(HERO_WAR).starter_deck))
	_engine = _engine_over(db, "war", {"starting_health_player": KNOB_HEALTH})
	var engine: RulesEngine = _engine

	# Act
	await assert_error(func() -> void: engine.start(config)).is_push_error(NO_RECORD_MESSAGE % HERO_UNKNOWN)

	# Assert — C3 defaults the health. It names no hero power, so none is
	# invented: `def_id` keeps `make_player_state`'s empty value (GDD gap)
	assert_int(int(_player().hero.base_health)).is_equal(KNOB_HEALTH)
	assert_str(str(_player().hero_power.def_id)).is_empty()


func test_a_hero_def_id_naming_another_record_type_seats_the_knob_and_logs_the_error() -> void:
	# Arrange — `has` is true for any record type; `hero` would assert on this one
	var db: CardDatabase = _loaded(SHIPPED_ROOT)
	var config: Dictionary = _config(AXE, Array(db.hero(HERO_WAR).starter_deck))
	_engine = _engine_over(db, "war", {"starting_health_player": KNOB_HEALTH})
	var engine: RulesEngine = _engine

	# Act
	await assert_error(func() -> void: engine.start(config)).is_push_error(NO_RECORD_MESSAGE % AXE)

	# Assert
	assert_int(int(_player().hero.base_health)).is_equal(KNOB_HEALTH)
	assert_str(str(_player().hero_power.def_id)).is_empty()


func test_an_engine_with_no_database_seats_the_knob() -> void:
	# Arrange — the seam every match-rules suite without a card lookup starts through

	# Act
	_engine = MatchFactory.make_started_engine(null, null, {}, {"starting_health_player": KNOB_HEALTH})

	# Assert
	assert_int(int(_player().hero.base_health)).is_equal(KNOB_HEALTH)
	assert_str(str(_player().hero_power.def_id)).is_empty()


# --- AC-7: Whetstone equips on shipped data ------------------------------------------

func test_whetstone_with_no_weapon_equips_the_blade_on_shipped_data() -> void:
	# Arrange
	_war_second_turn()
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	EventLogAssertions.assert_order(events, ["hero_power_used", "weapon_equipped"])
	assert_str(str(_of_type(events, "hero_power_used")[0].payload.power_id)).is_equal(POWER_WHETSTONE)
	assert_str(str(_of_type(events, "weapon_equipped")[0].payload.card_id)).is_equal(BLADE)
	assert_int(_hero_attack()).is_equal(BLADE_ATTACK)
	assert_int(int(_player().weapon.durability)).is_equal(BLADE_DURABILITY)
	assert_int(int(_player().mana_current)).is_equal(0)


func test_the_power_cost_is_the_rule_and_not_the_hero_power_record() -> void:
	# Arrange — `HeroPowerDef.cost` stays 2 (match-rules C7 / F1)
	_war_second_turn({"hero_power_cost": RULE_POWER_COST})

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	assert_int(int(_player().mana_current)).is_equal(TestConstants.HERO_POWER_COST - RULE_POWER_COST)


# --- AC-8: Whetstone sharpens a held weapon ------------------------------------------

func test_whetstone_on_a_held_axe_adds_1_attack_until_the_end_step() -> void:
	# Arrange
	_war_second_turn()
	_engine.equip_weapon(SIDE_PLAYER, AXE)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert — never destroyed; 3 this turn
	assert_array(_of_type(_since(before), "weapon_destroyed")).is_empty()
	assert_str(str(_player().weapon.def_id)).is_equal(AXE)
	assert_int(_hero_attack()).is_equal(AXE_ATTACK + WHETSTONE_DELTA)

	# Act — the End step
	var after_power: int = _last_seq()
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert — 2 afterwards
	var removed: Array = _of_type(_since(after_power), "enchantment_removed")
	assert_int(removed.size()).is_equal(1)
	assert_int(int(removed[0].payload.attack_delta)).is_equal(WHETSTONE_DELTA)
	assert_int(_hero_attack()).is_equal(AXE_ATTACK)


# --- Heroes Edge Cases: Whetstone and the generic power rows -------------------------

func test_a_frozen_hero_can_still_equip_with_whetstone_but_cannot_swing() -> void:
	# Arrange
	_war_second_turn()
	_engine.freeze(_hero_id(SIDE_PLAYER))

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	assert_str(str(_player().weapon.def_id)).is_equal(BLADE)
	var swing: Dictionary = _engine.submit(MatchRecords.attack(SIDE_PLAYER, _hero_id(SIDE_PLAYER), _hero_id(SIDE_BOSS)))
	assert_bool(swing.accepted).is_false()
	assert_str(str(swing.rejection.code)).is_equal(RulesEngine.R_ATTACKER_FROZEN)


func test_a_frozen_hero_can_still_sharpen_with_whetstone_but_cannot_swing() -> void:
	# Arrange
	_war_second_turn()
	_engine.equip_weapon(SIDE_PLAYER, AXE)
	_engine.freeze(_hero_id(SIDE_PLAYER))

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	assert_int(_hero_attack()).is_equal(AXE_ATTACK + WHETSTONE_DELTA)
	var swing: Dictionary = _engine.submit(MatchRecords.attack(SIDE_PLAYER, _hero_id(SIDE_PLAYER), _hero_id(SIDE_BOSS)))
	assert_bool(swing.accepted).is_false()
	assert_str(str(swing.rejection.code)).is_equal(RulesEngine.R_ATTACKER_FROZEN)


func test_whetstones_attack_applies_to_both_windfury_swings() -> void:
	# Arrange
	_war_second_turn()
	_engine.equip_weapon(SIDE_PLAYER, WINDFURY_WEAPON)
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	var before: int = _last_seq()

	# Act — two swings at the boss
	_submit(MatchRecords.attack(SIDE_PLAYER, _hero_id(SIDE_PLAYER), _hero_id(SIDE_BOSS)))
	_submit(MatchRecords.attack(SIDE_PLAYER, _hero_id(SIDE_PLAYER), _hero_id(SIDE_BOSS)))

	# Assert
	var dealt: Array = _of_type(_since(before), "damage_dealt")
	assert_int(dealt.size()).is_equal(2)
	assert_int(int(dealt[0].payload.dealt)).is_equal(WINDFURY_ATTACK + WHETSTONE_DELTA)
	assert_int(int(dealt[1].payload.dealt)).is_equal(WINDFURY_ATTACK + WHETSTONE_DELTA)
	assert_int(int(_player().weapon.durability)).is_equal(WINDFURY_DURABILITY - 2)


func test_a_weapon_card_played_over_the_blade_destroys_it_with_no_refund() -> void:
	# Arrange — the Blade held, the Axe in hand, exactly its cost in mana
	_war_second_turn()
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	var state: MatchState = _engine.state()
	_player().hand.clear()
	_player().hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), AXE, "hand"))
	_player().mana_current = int(_db.card(AXE).cost)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null))

	# Assert
	var events: Array = _since(before)
	EventLogAssertions.assert_order(events, ["weapon_destroyed", "weapon_equipped"])
	assert_str(str(_of_type(events, "weapon_equipped")[0].payload.card_id)).is_equal(AXE)
	assert_str(str(_player().weapon.def_id)).is_equal(AXE)
	assert_int(int(_player().mana_current)).is_equal(0)


# --- AC-19: a fourth hero is data only -----------------------------------------------

func test_a_fourth_hero_loads_and_plays_a_scripted_turn_with_no_code_change() -> void:
	# Arrange
	var db: CardDatabase = _loaded(FIXTURE_ROOT)
	assert_array(db.report().errors()).is_empty()

	# Act — mulligan, the second turn's power, end turn
	_started(db, HERO_FOURTH)
	_to_second_turn()
	var before: int = _last_seq()
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert — an existing power, on a set no shipped hero uses
	assert_str(str(db.hero(HERO_FOURTH).set)).is_equal("fortune")
	assert_str(str(_player().hero_power.def_id)).is_equal(POWER_WHETSTONE)
	assert_str(str(_of_type(_since(before), "weapon_equipped")[0].payload.card_id)).is_equal(BLADE)
	assert_str(str(_engine.active_side())).is_equal(SIDE_BOSS)
