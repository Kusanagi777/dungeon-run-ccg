## card-effects story 009 — the raise-time snapshot, `once_per_turn`,
## Silence-after-queue and counters (design/gdd/card-effects.md C5 `add_counter`
## / `set_counter`, C6.2, C6.5, C6.7, C6.8, Edge Cases "Resolution order and the
## queue"; AC-19, AC-20, AC-21, AC-46; ADR-0007 Decisions 1 and 5; 2026-11-04,
## DD-X21). Match-rules AC-46 is pinned in `match_rules_freeze_silence_test.gd`.
##
## The engine is the real `RulesEngine` from `MatchFactory`'s config with a
## `TestRngService` and `TestEventLog`, bound to the real `EffectResolver`, over
## the committed C11 fixture `tests/fixtures/cards_effects_test.json` (rows 11,
## 12, 26, 45, 46) and the inline hosts below. `damage_dealt`'s field is `dealt`
## (match-rules C15); the event has no `amount`.
extends GdUnitTestSuite

const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
const ROW_11: String = "decay_fx_row_11_grave_feeder"
const ROW_12: String = "decay_fx_row_12_spiteful_corpse"
const ROW_26: String = "neutral_fx_row_26_aura_lord"
const ROW_45: String = "neutral_fx_row_45_death_counter"
const ROW_46: String = "decay_fx_row_46_husk_purge"
const HUSK: String = "decay_husk"
const VANILLA: String = "neutral_test_vanilla"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS

## Row 11 with `once_per_turn: true` (AC-19).
const ONCE_FEEDER: String = "neutral_test_once_feeder"
## "Battlecry, once per turn: gain 1 Armor" — a play trigger (C6.7 "queued or run").
const ONCE_CRY: String = "neutral_test_once_cry"
## "Deathrattle: deal 2 damage to the enemy hero" (a fixed amount).
const DR_TWO: String = "neutral_test_dr_two"
## "Whenever this takes damage, gain 1 Armor" (Silence-after-queue).
const WINCING: String = "neutral_test_wincing"
## "Deathrattle: deal 2 damage to all enemy minions": kills row 45 between its
## raise and its `add_counter` (card-effects Edge Cases, DSL spike finding 4).
const AOE_DR: String = "neutral_test_aoe_dr"
## `chosen` spells, in the op order their names give.
const DESTROY_SILENCE: String = "neutral_test_destroy_silence"
const SILENCE_DESTROY: String = "neutral_test_silence_destroy"
const DAMAGE_SILENCE: String = "neutral_test_damage_silence"
## Counter ops on the spell's own instance (C5; row 46's host).
const COUNTER_SPELL: String = "neutral_test_counter_spell"
## "Deathrattle: deal damage equal to this weapon's Attack to the enemy hero".
const DR_WEAPON: String = "neutral_test_dr_weapon"
## "Deathrattle: summon two Husks" with no `position` (C5 default `source_slot`).
const DR_SUMMON: String = "neutral_test_dr_summon"

## The C6.5 field list, sorted: the snapshot holds these and nothing more.
const SNAPSHOT_FIELDS: Array[String] = ["attack", "board_index", "counters", "def_id", "health", "keywords", "max_health", "owner", "source_id"]
const KEY_SEEN: String = "seen"
const BASE_HEALTH: int = 2
## Row 12 at 4 base Attack, plus row 26's +1 aura (AC-20).
const AURA_BASE_ATTACK: int = 4
const AURA_ATTACK: int = 5
## An enchantment that must not reach a post-Silence snapshot.
const ATTACK_BUFF: int = 3
## The fixed Deathrattle's and row 12's printed damage.
const DR_DAMAGE: int = 2


## `has` / `card` / `hero_power` from a map (the engine and the resolver ask
## nothing else in a match).
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
var _resolver: EffectResolver = null
var _log: TestEventLog = null


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null
	_resolver = null
	_log = null


# --- helpers -------------------------------------------------------------------

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


func _chosen_spell(id: String, ops: String) -> Dictionary:
	return CardFactory.make_spell(id, 1, _fx('{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":%s}' % ops))


## The C11 fixture, the vanilla set and the inline hosts.
func _db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	var flat: JSON = load(FLAT)
	for record: Dictionary in flat.data:
		by_id[record.id] = record
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	by_id[VANILLA] = CardFactory.make_minion(VANILLA, 1, 1, 1)
	by_id[ONCE_FEEDER] = CardFactory.make_minion(ONCE_FEEDER, 2, 2, 2, [], {"effects": _fx(
		'{"trigger":"on_minion_died","once_per_turn":true,"targets":"self","ops":[{"op":"buff","attack":1,"health":1}]}')})
	by_id[ONCE_CRY] = CardFactory.make_minion(ONCE_CRY, 1, 1, 1, ["battlecry"], {"effects": _fx(
		'{"trigger":"battlecry","once_per_turn":true,"ops":[{"op":"armor","targets":"owner","amount":1}]}')})
	by_id[DR_TWO] = CardFactory.make_minion(DR_TWO, 1, 1, 2, ["deathrattle"], {"effects": _fx(
		'{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":2}]}')})
	by_id[WINCING] = CardFactory.make_minion(WINCING, 1, 1, 5, [], {"effects": _fx(
		'{"trigger":"on_damage_taken","ops":[{"op":"armor","targets":"owner","amount":1}]}')})
	by_id[AOE_DR] = CardFactory.make_minion(AOE_DR, 1, 1, 1, ["deathrattle"], {"effects": _fx(
		'{"trigger":"deathrattle","targets":"all_enemy_minions","ops":[{"op":"damage","amount":2}]}')})
	by_id[DESTROY_SILENCE] = _chosen_spell(DESTROY_SILENCE, '[{"op":"destroy"},{"op":"silence"}]')
	by_id[SILENCE_DESTROY] = _chosen_spell(SILENCE_DESTROY, '[{"op":"silence"},{"op":"destroy"}]')
	by_id[DAMAGE_SILENCE] = _chosen_spell(DAMAGE_SILENCE, '[{"op":"damage","amount":1},{"op":"silence"}]')
	by_id[COUNTER_SPELL] = CardFactory.make_spell(COUNTER_SPELL, 1, _fx(
		'{"trigger":"cast","ops":[{"op":"set_counter","key":"k","value":3},{"op":"set_counter","key":"k","value":3},'
		+ '{"op":"add_counter","key":"k","amount":-1},{"op":"damage","targets":"enemy_hero","amount":{"ref":"counter.k"}}]}'))
	by_id[DR_WEAPON] = CardFactory.make_weapon(DR_WEAPON, 1, 2, 2, {"keywords": ["deathrattle"], "effects": _fx(
		'{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"source.attack"}}]}')})
	by_id[DR_SUMMON] = CardFactory.make_minion(DR_SUMMON, 1, 1, 1, ["deathrattle"], {"effects": _fx(
		'{"trigger":"deathrattle","ops":[{"op":"summon","card_id":"%s","count":2}]}' % HUSK)})
	return FakeCardDatabase.new(by_id)


## A started engine bound to a real `EffectResolver`, past a keep-all
## mulligan (player Main, turn 1), the hand replaced by [param hand], 10 mana.
func _main_phase(hand: Array = []) -> RulesEngine:
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log)
	_resolver = EffectResolver.new(db, _effects_config())
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), _resolver)
	_engine.start(config)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	_set_hand(SIDE_PLAYER, hand)
	return _engine


## Replaces [param side]'s hand with fresh instances of [param hand] and gives it 10 mana.
func _set_hand(side: String, hand: Array) -> void:
	var state: MatchState = _engine.state()
	var cards: Array = state.players[side].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[side].mana_current = 10


func _put(side: String, def_id: String, attack: int, health: int, keywords: Array = []) -> int:
	return int(MatchFactory.summon(_engine.state(), side, attack, health, -1, keywords, def_id).entity_id)


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


## Destroys [param ids] together in one step, so one death check takes them.
func _destroy(ids: Array) -> void:
	_engine.run_action(func() -> void:
		for id: Variant in ids:
			_engine.destroy(int(id)))


func _hero(side: String) -> Dictionary:
	return _engine.state().players[side].hero


## The events appended from [param from_seq] on (exclusive).
func _since(from_seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq)


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


## The `trigger_queued` / `trigger_resolved` events of [param source_id].
func _triggers_of(events: Array, type: String, source_id: int) -> Array:
	return _of_type(events, type).filter(func(e: Dictionary) -> bool: return int(e.payload.source_id) == source_id)


## The one `effect_resolved` payload of trigger [param trigger] in [param events].
func _resolved(events: Array, trigger: String) -> Dictionary:
	var found: Array = _of_type(events, "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.trigger) == trigger)
	assert_int(found.size()).override_failure_message("effect_resolved{%s}: %d" % [trigger, found.size()]).is_equal(1)
	return found[0].payload if not found.is_empty() else {}


func _effect_id(def_id: String, index: int) -> String:
	return "%s.%d" % [def_id, index]


# --- AC-19: row 11 and once_per_turn --------------------------------------------

func test_row11_two_friendly_deaths_in_one_check_gain_two_buffs() -> void:
	# Arrange
	_main_phase()
	var feeder: int = _put(SIDE_PLAYER, ROW_11, 2, 2)
	var victims: Array = [_put(SIDE_PLAYER, VANILLA, 1, 1), _put(SIDE_PLAYER, VANILLA, 1, 1)]
	var before: int = _last_seq()

	# Act
	_destroy(victims)

	# Assert — two queued triggers, two passes, +2/+2
	var events: Array = _since(before)
	assert_int(_triggers_of(events, "trigger_queued", feeder).size()).is_equal(2)
	assert_int(_of_type(events, "effect_resolved").size()).is_equal(2)
	var minion: Dictionary = EffectSelectors.find(_engine.state(), feeder)
	assert_int(_engine.attack(minion)).is_equal(2 + 2)
	assert_int(_engine.health(minion)).is_equal(2 + 2)


func test_once_per_turn_two_deaths_in_one_check_queue_one_trigger_and_one_buff() -> void:
	# Arrange
	_main_phase()
	var feeder: int = _put(SIDE_PLAYER, ONCE_FEEDER, 2, 2)
	var victims: Array = [_put(SIDE_PLAYER, VANILLA, 1, 1), _put(SIDE_PLAYER, VANILLA, 1, 1)]
	var before: int = _last_seq()

	# Act
	_destroy(victims)

	# Assert — the second raise is dropped silently
	var events: Array = _since(before)
	assert_int(_triggers_of(events, "trigger_queued", feeder).size()).is_equal(1)
	assert_int(_triggers_of(events, "trigger_resolved", feeder).size()).is_equal(1)
	assert_int(_of_type(events, "effect_resolved").size()).is_equal(1)
	var minion: Dictionary = EffectSelectors.find(_engine.state(), feeder)
	assert_int(_engine.attack(minion)).is_equal(2 + 1)
	assert_int(_engine.health(minion)).is_equal(2 + 1)


func test_once_per_turn_mark_is_keyed_by_effect_source_and_turn() -> void:
	# Arrange
	_main_phase()
	var feeder: int = _put(SIDE_PLAYER, ONCE_FEEDER, 2, 2)
	var victim: int = _put(SIDE_PLAYER, VANILLA, 1, 1)

	# Act
	_destroy([victim])

	# Assert — `effect_id:source_id:turn`, true, and nothing else (story 009 notes)
	var key: String = "%s:%d:%d" % [_effect_id(ONCE_FEEDER, 0), feeder, int(_engine.state().turn)]
	assert_dict(_engine.state().effects.once_marks).is_equal({key: true})


func test_once_per_turn_does_not_mark_an_effect_without_the_flag() -> void:
	# Arrange
	_main_phase()
	var _feeder: int = _put(SIDE_PLAYER, ROW_11, 2, 2)
	var victim: int = _put(SIDE_PLAYER, VANILLA, 1, 1)

	# Act
	_destroy([victim])

	# Assert
	assert_dict(_engine.state().effects.once_marks).is_empty()


func test_once_per_turn_mark_of_one_source_leaves_another_source_clear() -> void:
	# Arrange — two feeders of one definition: same `effect_id`, two sources
	_main_phase()
	var first: int = _put(SIDE_PLAYER, ONCE_FEEDER, 2, 2)
	var second: int = _put(SIDE_PLAYER, ONCE_FEEDER, 2, 2)
	var victims: Array = [_put(SIDE_PLAYER, VANILLA, 1, 1), _put(SIDE_PLAYER, VANILLA, 1, 1)]
	var before: int = _last_seq()

	# Act
	_destroy(victims)

	# Assert
	var events: Array = _since(before)
	assert_int(_triggers_of(events, "trigger_queued", first).size()).is_equal(1)
	assert_int(_triggers_of(events, "trigger_queued", second).size()).is_equal(1)


func test_once_per_turn_a_new_turn_clears_the_mark_with_no_reset() -> void:
	# Arrange — the mark is spent on turn 1
	_main_phase()
	var feeder: int = _put(SIDE_PLAYER, ONCE_FEEDER, 2, 2)
	_destroy([_put(SIDE_PLAYER, VANILLA, 1, 1)])
	var spent_turn: int = int(_engine.state().turn)
	var victim: int = _put(SIDE_PLAYER, VANILLA, 1, 1)

	# Act — the boss's turn: the global `turn` has moved on
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	var before: int = _last_seq()
	_destroy([victim])

	# Assert
	assert_int(int(_engine.state().turn)).is_greater(spent_turn)
	assert_int(_triggers_of(_since(before), "trigger_queued", feeder).size()).is_equal(1)
	assert_int((_engine.state().effects.once_marks as Dictionary).size()).is_equal(2)


func test_once_per_turn_a_play_trigger_runs_once_for_one_source() -> void:
	# Arrange
	_main_phase()
	var host: int = _put(SIDE_PLAYER, ONCE_CRY, 1, 1)
	var ctx: Dictionary = {"side": SIDE_PLAYER, "candidates": [host], "source": host, "target_id": null, "card_id": ONCE_CRY}
	var before: int = _last_seq()

	# Act — the play point fires twice in one turn (C6.7: "queued or run")
	_engine.run_action(func() -> void:
		@warning_ignore("return_value_discarded")
		_resolver.resolve(&"battlecry", ctx.duplicate())
		@warning_ignore("return_value_discarded")
		_resolver.resolve(&"battlecry", ctx.duplicate()))

	# Assert
	assert_int(_of_type(_since(before), "effect_resolved").size()).is_equal(1)
	assert_int(int(_hero(SIDE_PLAYER).armor)).is_equal(1)


# --- AC-20: the raise-time snapshot ---------------------------------------------

func test_row12_buffed_by_an_aura_lord_dying_in_the_same_step_deals_the_snapshot_attack() -> void:
	# Arrange — row 26 gives row 12 +1 Attack: 4 base, 5 buffed
	_main_phase()
	var corpse: int = _put(SIDE_PLAYER, ROW_12, AURA_BASE_ATTACK, BASE_HEALTH, ["deathrattle"])
	var lord: int = _put(SIDE_PLAYER, ROW_26, 2, 2, ["aura"])
	_engine.run_action(func() -> void: pass)
	assert_int(_engine.attack(EffectSelectors.find(_engine.state(), corpse))).is_equal(AURA_ATTACK)
	var before: int = _last_seq()

	# Act
	_destroy([corpse, lord])

	# Assert
	var hits: Array = _of_type(_since(before), "damage_dealt")
	assert_int(hits.size()).is_equal(1)
	assert_int(int(hits[0].payload.target)).is_equal(int(_hero(SIDE_BOSS).entity_id))
	assert_int(int(hits[0].payload.dealt)).is_equal(AURA_ATTACK)


func test_a_queued_entry_snapshot_is_exactly_the_c6_5_field_list() -> void:
	# Arrange — row 45 with a counter, 3/4 at board index 1, one enchantment
	_main_phase()
	var _left: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	var counter: int = _put(SIDE_PLAYER, ROW_45, 2, 5, ["deathrattle"])
	_engine.run_action(func() -> void:
		_engine.apply_enchantment(counter, {"attack_delta": 1, "keywords_added": ["taunt"]})
		_engine.apply_damage(counter, 1, null))
	EffectRuntime.write_counter(_engine.state().effects, counter, KEY_SEEN, 2)
	var ctx: Dictionary = {"side": SIDE_BOSS, "candidates": [counter], "subject": 999}

	# Act
	var entries: Array[Dictionary] = _resolver.resolve(&"on_minion_died", ctx)

	# Assert
	assert_int(entries.size()).is_equal(1)
	var snapshot: Dictionary = entries[0].snapshot
	var fields: Array = snapshot.keys()
	fields.sort()
	assert_array(fields).is_equal(SNAPSHOT_FIELDS)
	assert_dict(snapshot).is_equal({
		"source_id": counter, "def_id": ROW_45, "owner": SIDE_PLAYER,
		"attack": 3, "health": 4, "max_health": 5, "board_index": 1,
		"keywords": ["deathrattle", "taunt"], "counters": {KEY_SEEN: 2},
	})
	GameAssertions.assert_json_representable(snapshot)


func test_a_snapshot_keeps_its_counters_when_the_live_bucket_moves_on() -> void:
	# Arrange
	_main_phase()
	var counter: int = _put(SIDE_PLAYER, ROW_45, 2, 2, ["deathrattle"])
	EffectRuntime.write_counter(_engine.state().effects, counter, KEY_SEEN, 1)
	var ctx: Dictionary = {"side": SIDE_BOSS, "candidates": [counter], "subject": 999}
	var entries: Array[Dictionary] = _resolver.resolve(&"on_minion_died", ctx)

	# Act
	EffectRuntime.write_counter(_engine.state().effects, counter, KEY_SEEN, 7)

	# Assert — a value copy, not the bucket
	assert_dict(entries[0].snapshot.counters).is_equal({KEY_SEEN: 1})


func test_a_weapon_deathrattle_reads_its_buffed_attack_from_the_snapshot() -> void:
	# Arrange — a 2-Attack weapon with a +3 enchantment (C5 `buff` on weapons)
	_main_phase()
	var state: MatchState = _engine.state()
	var id: int = MatchFactory.alloc_entity_id(state)
	state.players[SIDE_PLAYER].weapon = MatchRecords.weapon(id, DR_WEAPON, 2, 2, ["deathrattle"])
	_engine.run_action(func() -> void: _engine.apply_enchantment(id, {"attack_delta": ATTACK_BUFF}))
	var before: int = _last_seq()

	# Act
	_destroy([id])

	# Assert
	var hits: Array = _of_type(_since(before), "damage_dealt")
	assert_int(hits.size()).is_equal(1)
	assert_int(int(hits[0].payload.dealt)).is_equal(2 + ATTACK_BUFF)


func test_a_deathrattle_summon_with_no_position_lands_in_the_dead_minions_slot() -> void:
	# Arrange — [vanilla, summoner, vanilla]
	_main_phase()
	var _left: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	var summoner: int = _put(SIDE_PLAYER, DR_SUMMON, 1, 1, ["deathrattle"])
	var _right: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	var before: int = _last_seq()

	# Act
	_destroy([summoner])

	# Assert — C5 default `source_slot` from `board_index`; copies left to right
	var events: Array = _since(before)
	var summoned: Array = _of_type(events, "minion_summoned")
	assert_int(summoned.size()).is_equal(2)
	assert_int(int(summoned[0].payload.position)).is_equal(1)
	assert_int(int(summoned[1].payload.position)).is_equal(2)
	assert_str(str(_resolved(events, "deathrattle").ops[0].values.position)).is_equal(EffectOps.POSITION_SOURCE_SLOT)


# --- AC-21: Silence-after-queue -------------------------------------------------

func test_destroy_then_silence_in_one_effect_still_resolves_the_deathrattle() -> void:
	# Arrange
	_main_phase([DESTROY_SILENCE])
	var host: int = _put(SIDE_PLAYER, DR_TWO, 1, 2, ["deathrattle"])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, host))

	# Assert
	var events: Array = _since(before)
	assert_int(_triggers_of(events, "trigger_queued", host).size()).is_equal(1)
	assert_int(_triggers_of(events, "trigger_resolved", host).size()).is_equal(1)
	assert_int(int(_of_type(events, "damage_dealt")[0].payload.dealt)).is_equal(DR_DAMAGE)


func test_silence_before_death_queues_no_deathrattle() -> void:
	# Arrange
	_main_phase([SILENCE_DESTROY])
	var host: int = _put(SIDE_PLAYER, DR_TWO, 1, 2, ["deathrattle"])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, host))

	# Assert
	var events: Array = _since(before)
	assert_int(_of_type(events, "minion_died").size()).is_equal(1)
	assert_array(_triggers_of(events, "trigger_queued", host)).is_empty()
	assert_array(_of_type(events, "damage_dealt")).is_empty()


func test_a_second_silence_after_the_mark_does_not_restore_a_stripped_deathrattle() -> void:
	# Arrange — Silenced first, so it held no Deathrattle when marked
	_main_phase()
	var host: int = _put(SIDE_PLAYER, DR_TWO, 1, 2, ["deathrattle"])
	var before: int = _last_seq()

	# Act
	_engine.run_action(func() -> void:
		_engine.silence(host)
		_engine.destroy(host)
		_engine.silence(host))

	# Assert
	var events: Array = _since(before)
	assert_int(_of_type(events, "minion_died").size()).is_equal(1)
	assert_array(_triggers_of(events, "trigger_queued", host)).is_empty()


func test_a_trigger_queued_before_silence_still_resolves_and_the_source_then_fires_nothing() -> void:
	# Arrange — one effect hits row "wincing" (raising on_damage_taken), then Silences it
	_main_phase([DAMAGE_SILENCE])
	var host: int = _put(SIDE_PLAYER, WINCING, 1, 5)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, host))

	# Assert — queued = earned: the Armor lands
	var events: Array = _since(before)
	assert_int(_triggers_of(events, "trigger_resolved", host).size()).is_equal(1)
	assert_int(int(_hero(SIDE_PLAYER).armor)).is_equal(1)

	# Act — a later hit on the Silenced source
	var after: int = _last_seq()
	_engine.run_action(func() -> void: _engine.apply_damage(host, 1, null))

	# Assert — `Disarmed`: nothing queues
	assert_array(_triggers_of(_since(after), "trigger_queued", host)).is_empty()


func test_a_kept_deathrattle_reads_the_post_silence_snapshot() -> void:
	# Arrange — row 12 at 2 Attack with +3 from an enchantment
	_main_phase([DESTROY_SILENCE])
	var host: int = _put(SIDE_PLAYER, ROW_12, DR_DAMAGE, BASE_HEALTH, ["deathrattle"])
	_engine.run_action(func() -> void: _engine.apply_enchantment(host, {"attack_delta": ATTACK_BUFF}))
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, host))

	# Assert — the unbuffed Attack, not 5 (C13 step 2)
	var hits: Array = _of_type(_since(before), "damage_dealt")
	assert_int(hits.size()).is_equal(1)
	assert_int(int(hits[0].payload.dealt)).is_equal(DR_DAMAGE)


# --- AC-46: counters ------------------------------------------------------------

func test_row45_after_three_deaths_deals_three_read_from_the_snapshot() -> void:
	# Arrange — three minions (either side) die while row 45 is in play
	_main_phase()
	var counter: int = _put(SIDE_PLAYER, ROW_45, 2, 2, ["deathrattle"])
	var before: int = _last_seq()
	_destroy([_put(SIDE_PLAYER, VANILLA, 1, 1)])
	_destroy([_put(SIDE_BOSS, VANILLA, 1, 1), _put(SIDE_BOSS, VANILLA, 1, 1)])
	var changes: Array = _of_type(_since(before), "counter_changed").map(func(e: Dictionary) -> Dictionary: return e.payload)
	var after: int = _last_seq()

	# Act
	_destroy([counter])

	# Assert
	assert_array(changes).is_equal([
		{"source_id": counter, "key": KEY_SEEN, "value": 1},
		{"source_id": counter, "key": KEY_SEEN, "value": 2},
		{"source_id": counter, "key": KEY_SEEN, "value": 3},
	])
	var events: Array = _since(after)
	var hits: Array = _of_type(events, "damage_dealt")
	assert_int(hits.size()).is_equal(1)
	assert_int(int(hits[0].payload.target)).is_equal(int(_hero(SIDE_BOSS).entity_id))
	assert_int(int(hits[0].payload.dealt)).is_equal(3)
	assert_str(str(_resolved(events, "deathrattle").ops[0].values.read_from)).is_equal("snapshot")


func test_row45_bounced_and_replayed_reads_a_counter_of_zero() -> void:
	# Arrange — row 45 saw one death, then goes back to hand
	_main_phase()
	var old: int = _put(SIDE_PLAYER, ROW_45, 2, 2, ["deathrattle"])
	_destroy([_put(SIDE_BOSS, VANILLA, 1, 1)])
	assert_int(EffectRuntime.counter(_engine.state().effects, old, KEY_SEEN)).is_equal(1)
	_engine.run_action(func() -> void:
		@warning_ignore("return_value_discarded")
		_engine.return_to_hand(old))

	# Act — replayed from hand: a new entity_id
	var replayed_at: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))
	var fresh: int = int(_of_type(_since(replayed_at), "minion_summoned")[0].payload.entity_id)
	var before: int = _last_seq()
	_destroy([fresh])

	# Assert
	assert_int(fresh).is_not_equal(old)
	assert_int(EffectRuntime.counter(_engine.state().effects, fresh, KEY_SEEN)).is_equal(0)
	assert_int(int(_of_type(_since(before), "damage_dealt")[0].payload.dealt)).is_equal(0)


func test_row45_counter_raised_before_death_but_resolved_after_is_not_in_snapshot() -> void:
	# Arrange — the boss minion dies; Q gets [its Deathrattle, row 45's add_counter].
	# The Deathrattle kills row 45 before add_counter resolves, so row 45's own
	# Deathrattle is raised with seen == 0 and the late add_counter raises only
	# the live bucket: the snapshot wins (Edge Cases, DSL spike finding 4).
	_main_phase()
	var counter: int = _put(SIDE_PLAYER, ROW_45, 2, 2, ["deathrattle"])
	var killer: int = _put(SIDE_BOSS, AOE_DR, 1, 1, ["deathrattle"])
	var before: int = _last_seq()

	# Act
	_destroy([killer])

	# Assert
	var events: Array = _since(before)
	var change: Array = _of_type(events, "counter_changed")
	assert_int(change.size()).is_equal(1)
	assert_dict(change[0].payload).is_equal({"source_id": counter, "key": KEY_SEEN, "value": 1})
	var hit: Dictionary = _of_type(events, "damage_dealt").back().payload
	assert_int(int(hit.target)).is_equal(int(_hero(SIDE_BOSS).entity_id))
	assert_int(int(hit.dealt)).is_equal(0)
	var resolved: Dictionary = _of_type(events, "effect_resolved").back().payload
	assert_str(str(resolved.ops[0].values.read_from)).is_equal("snapshot")


func test_a_counter_read_on_a_source_never_given_one_is_zero() -> void:
	# Arrange
	_main_phase()
	var counter: int = _put(SIDE_PLAYER, ROW_45, 2, 2, ["deathrattle"])
	var before: int = _last_seq()

	# Act
	_destroy([counter])

	# Assert
	assert_int(EffectRuntime.counter(_engine.state().effects, counter, KEY_SEEN)).is_equal(0)
	assert_int(int(_of_type(_since(before), "damage_dealt")[0].payload.dealt)).is_equal(0)


func test_row46_set_counter_counts_the_live_board_before_the_destroy() -> void:
	# Arrange — two Husks and a vanilla; row 46's counter lives on the spell instance
	_main_phase([ROW_46])
	var _husk_a: int = _put(SIDE_PLAYER, HUSK, 1, 1)
	var _husk_b: int = _put(SIDE_PLAYER, HUSK, 1, 1)
	var _vanilla: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	var instance: int = int(_engine.state().players[SIDE_PLAYER].hand[0].instance_id)
	var boss_hero: int = int(_hero(SIDE_BOSS).entity_id)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))

	# Assert
	var events: Array = _since(before)
	var changes: Array = _of_type(events, "counter_changed")
	assert_int(changes.size()).is_equal(1)
	assert_dict(changes[0].payload).is_equal({"source_id": instance, "key": "n", "value": 2})
	assert_int(_of_type(events, "minion_died").size()).is_equal(2)
	var hits: Array = _of_type(events, "damage_dealt").filter(func(e: Dictionary) -> bool: return int(e.payload.target) == boss_hero)
	assert_int(hits.size()).is_equal(1)
	assert_int(int(hits[0].payload.dealt)).is_equal(2)


func test_counter_changed_fires_once_per_real_change_and_a_live_read_says_live() -> void:
	# Arrange — set 3, set 3 again, add −1, then damage = counter.k
	_main_phase([COUNTER_SPELL])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))

	# Assert — the repeat is no change; all three ops still report `applied`
	var events: Array = _since(before)
	var values: Array = _of_type(events, "counter_changed").map(func(e: Dictionary) -> int: return int(e.payload.value))
	assert_array(values).is_equal([3, 2])
	var ops: Array = _resolved(events, "cast").ops
	assert_array(ops.slice(0, 3).map(func(o: Dictionary) -> String: return str(o.outcome))).is_equal(["applied", "applied", "applied"])
	assert_int(int(_of_type(events, "damage_dealt")[0].payload.dealt)).is_equal(2)
	assert_str(str(ops[3].values.read_from)).is_equal("live")


# --- runtime state --------------------------------------------------------------

func test_effect_runtime_stays_plain_data_with_marks_and_counters() -> void:
	# Arrange
	_main_phase()
	var _feeder: int = _put(SIDE_PLAYER, ONCE_FEEDER, 2, 2)
	var _counter: int = _put(SIDE_PLAYER, ROW_45, 2, 2, ["deathrattle"])

	# Act
	_destroy([_put(SIDE_PLAYER, VANILLA, 1, 1)])

	# Assert
	var effects: Dictionary = _engine.state().effects
	assert_bool((effects.once_marks as Dictionary).is_empty()).is_false()
	assert_bool((effects.counters as Dictionary).is_empty()).is_false()
	assert_bool(EffectRuntime.is_runtime(effects)).is_true()
	GameAssertions.assert_json_representable(effects)


func test_a_clone_carries_marks_and_counters_and_its_writes_leave_the_original() -> void:
	# Arrange — one mark and one counter on the live match
	_main_phase()
	var feeder: int = _put(SIDE_PLAYER, ONCE_FEEDER, 2, 2)
	var counter: int = _put(SIDE_PLAYER, ROW_45, 2, 2, ["deathrattle"])
	_destroy([_put(SIDE_PLAYER, VANILLA, 1, 1)])
	var victim: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	var marks: Dictionary = (_engine.state().effects.once_marks as Dictionary).duplicate(true)

	# Act — a planner-style sandbox kills one more
	var sandbox: RulesEngine = _engine.clone()
	var carried_marks: Dictionary = (sandbox.state().effects.once_marks as Dictionary).duplicate(true)
	var carried_seen: int = EffectRuntime.counter(sandbox.state().effects, counter, KEY_SEEN)
	sandbox.run_action(func() -> void: sandbox.destroy(victim))
	var sandbox_seen: int = EffectRuntime.counter(sandbox.state().effects, counter, KEY_SEEN)
	var sandbox_attack: int = sandbox.attack(EffectSelectors.find(sandbox.state(), feeder))
	sandbox.end_match()

	# Assert — carried by value; the carried mark drops the second buff on the clone
	assert_dict(carried_marks).is_equal(marks)
	assert_int(carried_seen).is_equal(1)
	assert_int(sandbox_seen).is_equal(2)
	assert_int(EffectRuntime.counter(_engine.state().effects, counter, KEY_SEEN)).is_equal(1)
	assert_dict(_engine.state().effects.once_marks).is_equal(marks)
	assert_int(sandbox_attack).is_equal(2 + 1)
