## Sprint-4 review S5 (`production/reviews/2026-11-04/code-review-s4-unreviewed.md`;
## QA plan sprint 5 NC-1) — the `retrigger` op, built from the card-effects C5
## row: "Queues the target's live effects with that trigger as if raised now
## (`trigger_queued{reason: retrigger}`)", no-op `no_target` / `no_such_trigger`.
##
## NC-1 runs Mass Rites over Rot Zombies on the shipped data, through the real
## `RulesEngine` and `EffectResolver`. The other cases use the real engine and
## resolver over inline hosts and a fake database.
##
## Two details are undefined in the GDDs and deliberately **not pinned** here
## (reported to game-designer, see content story 004's notes): the op outcome
## when only some targets have a Deathrattle, and where a `source_slot` summon
## lands while its source is still on the board.
extends GdUnitTestSuite

const BOOT_SCRIPT: GDScript = preload("res://src/core/boot.gd")
const SHIPPED: String = "res://assets/data"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const HERO_SET: String = "war"
const SEED: int = 11

const MASS_RITES: String = "boss_mass_rites"
const ROT_ZOMBIE: String = "boss_rot_zombie"
const HUSK: String = "decay_husk"
const DECK_SIZE: int = 30

## `all_friendly_minions`, `retrigger deathrattle` — Mass Rites' shape.
const RITES: String = "neutral_test_rites"
## `all_friendly_minions`, `retrigger`, then `armor 1`: the op never stops the next.
const RITES_THEN_ARMOR: String = "neutral_test_rites_then_armor"
## Row 14's shape: `chosen`, `retrigger deathrattle`.
const DECAY: String = "neutral_test_decay"
## `owner_weapon`, `retrigger deathrattle`.
const ARMOURER: String = "neutral_test_armourer"
## Deathrattle: gain 1 Armor.
const WARD: String = "neutral_test_ward"
## Deathrattle: summon `TOKEN` at `source_slot` (Rot Zombie's shape).
const SPAWNER: String = "neutral_test_spawner"
## Deathrattle: give your minions +2 Attack.
const RALLIER: String = "neutral_test_rallier"
## Deathrattle: deal `source.attack` to the enemy hero (row 12's shape).
const AVENGER: String = "neutral_test_avenger"
## Deathrattle: deal 3 damage to all friendly minions.
const BURSTER: String = "neutral_test_burster"
## Deathrattle: retrigger your minions' Deathrattles (a queued retrigger).
const RELAY: String = "neutral_test_relay"
## Deathrattle: retrigger its own Deathrattle (a cycle the step cap catches).
const LOOPER: String = "neutral_test_looper"
const VANILLA: String = "neutral_test_vanilla"
const TOKEN: String = "neutral_test_token"
const RELIC: String = "neutral_test_relic"
## The step cap the cycle case runs under.
const LOW_STEP_CAP: int = 20
const RALLY_ATTACK: int = 2
const BASE_ATTACK: int = 1


## `has` / `card` / `hero_power` over a map (all the engine and resolver ask).
class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}

	func _init(by_id: Dictionary) -> void:
		records = by_id

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		return records.get(id)

	func hero_power(id: String) -> Variant:
		return records.get(id)


var _engine: RulesEngine = null
var _log: TestEventLog = null
var _clone: RulesEngine = null


func after_test() -> void:
	if _clone != null:
		_clone.end_match()
	_clone = null
	if _engine != null:
		_engine.end_match()
	_engine = null
	_log = null


# --- fixtures --------------------------------------------------------------------

func _effects_config() -> Dictionary:
	return {
		"discover_count": float(TestConstants.DISCOVER_COUNT),
		"discover_exclude_hand": false,
		"max_ops_per_effect": float(TestConstants.MAX_OPS_PER_EFFECT),
		"max_repeat": float(TestConstants.MAX_REPEAT),
		"max_summon_count": float(TestConstants.BOARD_SIZE),
		"effect_static_step_limit": float(TestConstants.EFFECT_STATIC_STEP_LIMIT),
		"spell_damage_default": "auto",
		"hooks_before_triggers": true,
	}


func _fx(json_text: String) -> Array:
	var parsed: Variant = JSON.parse_string(json_text)
	assert_bool(parsed != null).override_failure_message("fixture JSON does not parse: %s" % json_text).is_true()
	return parsed if parsed is Array else [parsed]


func _deathrattle_minion(id: String, json_ops: String, attack: int = BASE_ATTACK, health: int = 5) -> Dictionary:
	return CardFactory.make_minion(id, 1, attack, health, ["deathrattle"], {"effects": _fx('{"trigger":"deathrattle",%s}' % json_ops)})


func _make_db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	var retrigger: String = '{"op":"retrigger","trigger":"deathrattle"}'
	by_id[RITES] = CardFactory.make_spell(RITES, 1, _fx('{"trigger":"cast","targets":"all_friendly_minions","ops":[%s]}' % retrigger))
	by_id[RITES_THEN_ARMOR] = CardFactory.make_spell(RITES_THEN_ARMOR, 1, _fx(
		'{"trigger":"cast","targets":"all_friendly_minions","ops":[%s,{"op":"armor","targets":"owner","amount":1}]}' % retrigger))
	by_id[DECAY] = CardFactory.make_spell(DECAY, 1, _fx(
		'{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly","has_trigger":"deathrattle"}},"ops":[%s]}' % retrigger))
	by_id[ARMOURER] = CardFactory.make_spell(ARMOURER, 1, _fx('{"trigger":"cast","targets":"owner_weapon","ops":[%s]}' % retrigger))
	by_id[WARD] = _deathrattle_minion(WARD, '"ops":[{"op":"armor","targets":"owner","amount":1}]')
	by_id[SPAWNER] = _deathrattle_minion(SPAWNER, '"ops":[{"op":"summon","card_id":"%s","count":1,"position":"source_slot"}]' % TOKEN)
	by_id[RALLIER] = _deathrattle_minion(RALLIER, '"targets":"all_friendly_minions","ops":[{"op":"buff","attack":%d}]' % RALLY_ATTACK)
	by_id[AVENGER] = _deathrattle_minion(AVENGER, '"ops":[{"op":"damage","targets":"enemy_hero","amount":{"ref":"source.attack"}}]')
	by_id[BURSTER] = _deathrattle_minion(BURSTER, '"targets":"all_friendly_minions","ops":[{"op":"damage","amount":3}]')
	by_id[RELAY] = _deathrattle_minion(RELAY, '"targets":"right_neighbour","ops":[%s]' % retrigger)
	by_id[LOOPER] = _deathrattle_minion(LOOPER, '"targets":"self","ops":[%s]' % retrigger)
	by_id[VANILLA] = CardFactory.make_minion(VANILLA, 1, 1, 1)
	by_id[TOKEN] = CardFactory.make_minion(TOKEN, 1, 1, 1)
	by_id[RELIC] = CardFactory.make_weapon(RELIC, 1, 1, 3, {"keywords": ["deathrattle"], "effects": _fx('{"trigger":"deathrattle","ops":[{"op":"armor","targets":"owner","amount":1}]}')})
	return FakeCardDatabase.new(by_id)


## A started engine past a keep-all mulligan (player Main), the player's hand
## replaced by [param hand].
func _main_phase(hand: Array, rules_overrides: Dictionary = {}, seed_value: int = SEED) -> RulesEngine:
	var db: FakeCardDatabase = _make_db()
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(seed_value), _log)
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(rules_overrides), EffectResolver.new(db, _effects_config(), HERO_SET))
	_engine.start(config)
	_submit(_engine.legal_commands()[0])
	_set_hand(SIDE_PLAYER, hand)
	return _engine


func _set_hand(side: String, hand: Array) -> void:
	var state: MatchState = _engine.state()
	var cards: Array = state.players[side].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[side].mana_current = 10
	state.players[side].mana_max = 10


func _put(def_id: String, attack: int = BASE_ATTACK, health: int = 5, side: String = SIDE_PLAYER) -> int:
	return int(MatchFactory.summon(_engine.state(), side, attack, health, -1, [], def_id).entity_id)


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


func _cast(target: Variant = null) -> void:
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, target))


func _since(from_seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq)


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


## The `effect_resolved.ops` entry of the op called [param op] in [param events].
func _op_entry(events: Array, op: String) -> Dictionary:
	for event: Dictionary in _of_type(events, "effect_resolved"):
		for entry: Dictionary in event.payload.ops:
			if str(entry.op) == op:
				return entry
	return {}


func _queued_sources(events: Array) -> Array:
	return _of_type(events, "trigger_queued").map(func(e: Dictionary) -> int: return int(e.payload.source_id))


func _resolved_sources(events: Array) -> Array:
	return _of_type(events, "trigger_resolved").map(func(e: Dictionary) -> int: return int(e.payload.source_id))


func _armor(side: String = SIDE_PLAYER) -> int:
	return int(_engine.state().players[side].hero.armor)


func _board_defs(side: String = SIDE_PLAYER) -> Array:
	return (_engine.state().players[side].board as Array).map(func(m: Dictionary) -> String: return str(m.def_id))


# --- NC-1: Mass Rites over Rot Zombies on the shipped data ------------------------

func _shipped_db() -> CardDatabase:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED))
	db.load(boot._collect_validators(null, true))
	return db


## A shipped-data match at the boss's Main: every deck is Mass Rites, so no
## record outside the shipped set is drawn, and the boss holds one to cast.
func _shipped_boss_main(db: CardDatabase) -> void:
	_log = TestEventLog.new()
	var deck: Array = []
	deck.resize(DECK_SIZE)
	deck.fill(MASS_RITES)
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(SEED), _log, {"player": {"deck": deck.duplicate()}, "boss": {"deck": deck.duplicate()}})
	_engine = RulesEngine.new(db, db.config("match_rules"), EffectResolver.new(db, db.config("card_effects"), HERO_SET))
	_engine.start(config)
	_submit(_engine.legal_commands()[0])
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	assert_str(str(_engine.active_side())).is_equal(SIDE_BOSS)
	_set_hand(SIDE_BOSS, [MASS_RITES])


func test_mass_rites_over_three_rot_zombies_on_shipped_data_queues_each_deathrattle() -> void:
	# Arrange
	var db: CardDatabase = _shipped_db()
	assert_str(str(db.card(MASS_RITES).effects[0].ops[0].op)).is_equal("retrigger")
	_shipped_boss_main(db)
	var zombies: Array = [
		_put(ROT_ZOMBIE, 2, 3, SIDE_BOSS), _put(ROT_ZOMBIE, 2, 3, SIDE_BOSS), _put(ROT_ZOMBIE, 2, 3, SIDE_BOSS),
	]
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_BOSS, 0))

	# Assert — NC-1: three queued, three resolved, three Husks, no death
	var events: Array = _since(before)
	var queued: Array = _of_type(events, "trigger_queued")
	assert_int(queued.size()).is_equal(3)
	for event: Dictionary in queued:
		assert_str(str(event.payload.reason)).is_equal("retrigger")
		assert_str(str(event.payload.point)).is_equal("deathrattle")
	assert_array(_queued_sources(events)).is_equal(zombies)
	assert_array(_resolved_sources(events)).is_equal(zombies)
	var summoned: Array = _of_type(events, "minion_summoned")
	assert_array(summoned.map(func(e: Dictionary) -> String: return str(e.payload.card_id))).is_equal([HUSK, HUSK, HUSK])
	assert_int(_of_type(events, "minion_died").size()).is_equal(0)
	var entry: Dictionary = _op_entry(events, "retrigger")
	assert_str(str(entry.get("outcome", ""))).is_equal(EffectOps.APPLIED)
	assert_array(Array(entry.get("targets", []))).is_equal(zombies)
	for zombie: Variant in zombies:
		assert_bool(EffectSelectors.find(_engine.state(), int(zombie)).is_empty()).is_false()


# --- C5 / C6.0 / C6.3: order, steps, cause ------------------------------------------

func test_retrigger_queues_in_board_order_then_each_effect_resolves_as_its_own_step() -> void:
	# Arrange
	_main_phase([RITES])
	var ids: Array = [_put(WARD), _put(SPAWNER), _put(WARD)]
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — queued during the cast pass, resolved after it, left to right
	var events: Array = _since(before)
	assert_array(_queued_sources(events)).is_equal(ids)
	assert_array(_resolved_sources(events)).is_equal(ids)
	var passes: Array = _of_type(events, "effect_resolved")
	assert_int(passes.size()).is_equal(4)
	var queued: Array = _of_type(events, "trigger_queued")
	assert_int(int(queued.back().seq)).is_less(int(passes[0].seq))
	var resolved: Array = _of_type(events, "trigger_resolved")
	for i: int in resolved.size():
		# Each trigger_resolved sits between the pass before it and its own pass.
		assert_int(int(passes[i].seq)).is_less(int(resolved[i].seq))
		assert_int(int(resolved[i].seq)).is_less(int(passes[i + 1].seq))


func test_retriggered_effect_runs_at_depth_one_under_its_trigger_resolved() -> void:
	# Arrange
	_main_phase([RITES])
	@warning_ignore("return_value_discarded")
	_put(WARD)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — C6.6: the pass and its primitives run under trigger_resolved
	var events: Array = _since(before)
	var resolved: Dictionary = _of_type(events, "trigger_resolved")[0]
	var dr_pass: Dictionary = _of_type(events, "effect_resolved").back()
	assert_int(int(dr_pass.payload.depth)).is_equal(1)
	assert_str(str(dr_pass.payload.trigger)).is_equal("deathrattle")
	assert_int(int(dr_pass.cause_seq)).is_equal(int(resolved.seq))
	assert_int(int(resolved.cause_seq)).is_equal(int(_of_type(events, "trigger_queued")[0].cause_seq))


func test_retrigger_from_a_queued_pass_queues_one_depth_deeper() -> void:
	# Arrange — RELAY's own Deathrattle retriggers WARD
	_main_phase([RITES])
	var relay: int = _put(RELAY)
	var ward: int = _put(WARD)
	var before: int = _last_seq()

	# Act — the cast raises both; RELAY's pass raises WARD once more
	_cast()

	# Assert
	var events: Array = _since(before)
	assert_array(_queued_sources(events)).is_equal([relay, ward, ward])
	assert_int(_armor()).is_equal(2)
	var depths: Array = _of_type(events, "effect_resolved").map(func(e: Dictionary) -> int: return int(e.payload.depth))
	assert_array(depths).is_equal([0, 1, 1, 2])


func test_row_14_chosen_retrigger_queues_only_the_chosen_minion() -> void:
	# Arrange
	_main_phase([DECAY])
	@warning_ignore("return_value_discarded")
	_put(WARD)
	var chosen: int = _put(WARD)
	var before: int = _last_seq()

	# Act
	_cast(chosen)

	# Assert
	assert_array(_queued_sources(_since(before))).is_equal([chosen])
	assert_int(_armor()).is_equal(1)


# --- C5 failure semantics -----------------------------------------------------------

func test_no_friendly_minions_is_no_target_and_queues_nothing() -> void:
	# Arrange — an enemy Deathrattle minion is not a target
	_main_phase([RITES])
	@warning_ignore("return_value_discarded")
	_put(WARD, BASE_ATTACK, 5, SIDE_BOSS)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	var events: Array = _since(before)
	assert_str(str(_op_entry(events, "retrigger").get("outcome", ""))).is_equal(EffectOps.NO_TARGET)
	assert_int(_of_type(events, "trigger_queued").size()).is_equal(0)


func test_friendly_minions_without_a_deathrattle_are_no_such_trigger() -> void:
	# Arrange
	_main_phase([RITES])
	@warning_ignore("return_value_discarded")
	_put(VANILLA)
	@warning_ignore("return_value_discarded")
	_put(VANILLA)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	var events: Array = _since(before)
	assert_str(str(_op_entry(events, "retrigger").get("outcome", ""))).is_equal(EffectOps.NO_SUCH_TRIGGER)
	assert_int(_of_type(events, "trigger_queued").size()).is_equal(0)


func test_a_silenced_minion_has_no_live_deathrattle_and_is_no_such_trigger() -> void:
	# Arrange
	_main_phase([RITES])
	var ward: int = _put(WARD)
	_engine.silence(ward)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — C5 "live effects"; C6.2: a Silenced source responds to nothing
	var events: Array = _since(before)
	assert_str(str(_op_entry(events, "retrigger").get("outcome", ""))).is_equal(EffectOps.NO_SUCH_TRIGGER)
	assert_int(_of_type(events, "trigger_queued").size()).is_equal(0)
	assert_int(_armor()).is_equal(0)


func test_a_mixed_board_queues_only_the_minions_with_a_live_deathrattle() -> void:
	# Arrange
	_main_phase([RITES])
	var ward: int = _put(WARD)
	@warning_ignore("return_value_discarded")
	_put(VANILLA)
	var silenced: int = _put(WARD)
	_engine.silence(silenced)
	var spawner: int = _put(SPAWNER)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — the op's outcome for this board is an open question (see the header)
	var events: Array = _since(before)
	assert_array(_queued_sources(events)).is_equal([ward, spawner])
	assert_array(_resolved_sources(events)).is_equal([ward, spawner])


func test_an_op_after_a_no_op_retrigger_still_runs() -> void:
	# Arrange
	_main_phase([RITES_THEN_ARMOR])

	# Act
	_cast()

	# Assert — C6.4: an op with no targets never stops the next
	assert_int(_armor()).is_equal(1)


func test_a_weapon_deathrattle_is_queued() -> void:
	# Arrange — no shipped weapon has one; C5 allows weapons
	_main_phase([ARMOURER])
	var weapon: int = _engine.equip_weapon(SIDE_PLAYER, RELIC)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — the weapon stays equipped
	var events: Array = _since(before)
	assert_array(_queued_sources(events)).is_equal([weapon])
	assert_str(str(_op_entry(events, "retrigger").get("outcome", ""))).is_equal(EffectOps.APPLIED)
	assert_int(_armor()).is_equal(1)
	assert_int(int(_engine.state().players[SIDE_PLAYER].weapon.entity_id)).is_equal(weapon)


# --- Edge Cases "Summons": no death frees a slot ------------------------------------

func test_a_full_board_fails_each_summon_and_the_later_triggers_still_resolve() -> void:
	# Arrange — seven Spawners: unlike a real Deathrattle, no death frees a slot
	_main_phase([RITES])
	for _i: int in TestConstants.BOARD_SIZE:
		@warning_ignore("return_value_discarded")
		_put(SPAWNER)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	var events: Array = _since(before)
	var failed: Array = _of_type(events, "summon_failed")
	assert_int(failed.size()).is_equal(TestConstants.BOARD_SIZE)
	for event: Dictionary in failed:
		assert_str(str(event.payload.reason)).is_equal("board_full")
	assert_int(_of_type(events, "trigger_resolved").size()).is_equal(TestConstants.BOARD_SIZE)
	assert_int(_of_type(events, "minion_summoned").size()).is_equal(0)
	assert_int(_board_defs().size()).is_equal(TestConstants.BOARD_SIZE)


# --- C6.5: live reads while the source is in play -----------------------------------

func test_a_retriggered_source_in_play_reads_its_live_attack_not_the_snapshot() -> void:
	# Arrange — RALLIER resolves first and buffs AVENGER after the raise
	_main_phase([RITES])
	@warning_ignore("return_value_discarded")
	_put(RALLIER)
	@warning_ignore("return_value_discarded")
	_put(AVENGER)
	var boss_hero: Dictionary = _engine.state().players[SIDE_BOSS].hero
	var before_health: int = _engine.health(boss_hero)

	# Act
	_cast()

	# Assert — the raise-time snapshot read would deal BASE_ATTACK
	assert_int(before_health - _engine.health(boss_hero)).is_equal(BASE_ATTACK + RALLY_ATTACK)


func test_a_retriggered_source_that_dies_first_still_resolves_from_its_snapshot() -> void:
	# Arrange — BURSTER's retriggered pass kills AVENGER before AVENGER's pops
	_main_phase([RITES])
	var burster: int = _put(BURSTER, BASE_ATTACK, 9)
	var avenger: int = _put(AVENGER, 4, 3)
	var boss_hero: Dictionary = _engine.state().players[SIDE_BOSS].hero
	var before_health: int = _engine.health(boss_hero)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — C6.5 "queued = earned": the retriggered entry, then the real one
	var events: Array = _since(before)
	assert_array(_resolved_sources(events)).is_equal([burster, avenger, avenger])
	assert_int(_of_type(events, "minion_died").size()).is_equal(1)
	assert_int(before_health - _engine.health(boss_hero)).is_equal(8)


# --- bounds, determinism, the planner's clone ---------------------------------------

func test_a_self_retriggering_cycle_is_caught_by_the_resolution_step_cap() -> void:
	# Arrange
	_main_phase([RITES], {"resolution_step_cap": LOW_STEP_CAP})
	@warning_ignore("return_value_discarded")
	_put(LOOPER)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — C6.10: the step cap is the authority for a cycle
	var ended: Array = _of_type(_since(before), "match_ended")
	assert_int(ended.size()).is_equal(1)
	assert_str(str(ended[0].payload.reason)).is_equal(MatchRecords.REASON_RESOLUTION_OVERFLOW)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_ENDED)


func _rites_log(seed_value: int) -> String:
	_main_phase([RITES], {}, seed_value)
	@warning_ignore("return_value_discarded")
	_put(SPAWNER)
	@warning_ignore("return_value_discarded")
	_put(WARD)
	_cast()
	var text: String = _log.to_json()
	_engine.end_match()
	return text


func test_two_runs_on_one_seed_are_byte_identical() -> void:
	# Act
	var first: String = _rites_log(SEED)
	var second: String = _rites_log(SEED)

	# Assert
	assert_str(second).is_equal(first)


func test_a_clone_retriggers_on_its_own_board_and_leaves_the_live_match_alone() -> void:
	# Arrange
	_main_phase([RITES])
	var ward: int = _put(WARD)
	_clone = _engine.clone()

	# Act
	var result: Dictionary = _clone.submit(MatchRecords.play_card(SIDE_PLAYER, 0))

	# Assert
	assert_bool(result.accepted).is_true()
	assert_int(int(_clone.state().players[SIDE_PLAYER].hero.armor)).is_equal(1)
	assert_int(_armor()).is_equal(0)
	assert_bool(EffectSelectors.find(_engine.state(), ward).is_empty()).is_false()


# --- the validator's half of the C5 row ---------------------------------------------

func test_the_validator_rejects_a_retrigger_of_anything_but_deathrattle() -> void:
	# Arrange
	var caps: Dictionary = {
		"max_ops_per_effect": TestConstants.MAX_OPS_PER_EFFECT,
		"max_repeat": TestConstants.MAX_REPEAT,
		"max_summon_count": TestConstants.BOARD_SIZE,
		"effect_static_step_limit": TestConstants.EFFECT_STATIC_STEP_LIMIT,
		"discover_count": TestConstants.DISCOVER_COUNT,
		"hand_size": TestConstants.HAND_SIZE,
	}
	var db: FakeCardDatabase = FakeCardDatabase.new({RITES: CardFactory.make_spell(RITES, 1)})
	var accepted: Array = _fx('{"trigger":"cast","targets":"all_friendly_minions","ops":[{"op":"retrigger","trigger":"deathrattle"}]}')
	var refused: Array = _fx('{"trigger":"cast","targets":"all_friendly_minions","ops":[{"op":"retrigger","trigger":"battlecry"}]}')

	# Act
	var fine: Array = EffectValidator.validate_effects(&"card", RITES, accepted, db, caps)
	var report: Array = EffectValidator.validate_effects(&"card", RITES, refused, db, caps)

	# Assert — v1 allows only `deathrattle` (C5)
	assert_array(fine).is_empty()
	assert_array(report.map(func(e: Dictionary) -> String: return str(e.code))).contains(["E_FX_OP"])
