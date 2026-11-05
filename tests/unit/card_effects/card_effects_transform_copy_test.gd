## card-effects story 013 — `transform`, `copy_to_hand`, `return_to_hand` and an
## `aura` hosted on a treasure (design/gdd/card-effects.md C5, C6.5, C7, C9, Edge
## Cases "Summons, transforms and copies"; AC-30, AC-31, AC-32; ADR-0005: a
## treasure is a live source while installed and its `aura` is recomputed, never
## a `HookEntry`).
##
## The engine is the real `RulesEngine` with a `TestRngService` and a
## `TestEventLog`, bound to the real `EffectResolver`, over the committed C11
## fixture (`tests/fixtures/cards_effects_test.json`, rows 31, 32, 42) and the
## inline hosts below. Boards are laid out with `MatchFactory.summon` (a fixture
## move, no event); a played card goes through `submit`.
extends GdUnitTestSuite

const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
## Row 31: "Battlecry: Transform an enemy minion into a 1/1 Sheep".
const ROW_31: String = "neutral_fx_row_31_polymorpher"
## Row 32: "Battlecry: Add a copy of a friendly minion to your hand".
const ROW_32: String = "neutral_fx_row_32_mimic"
## Row 42: treasure "Your minions have Rush".
const ROW_42: String = "treasure_fx_row_42_rush_banner"
const SHEEP: String = "neutral_sheep"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const TREASURE: StringName = HookInstaller.HOST_KIND_TREASURE
const PASSIVE: StringName = HookInstaller.HOST_KIND_PASSIVE
const KEYWORD_RUSH: String = "rush"
const KEYWORD_TAUNT: String = "taunt"

## Inline hosts (test-only defs; ids carry their set prefix).
## A 5/5 with Taunt and a Deathrattle (AC-30).
const OGRE: String = "neutral_test_ogre"
const OGRE_STAT: int = 5
const OGRE_DEATHRATTLE_DAMAGE: int = 3
## A 1/1 whose own Battlecry draws: transforming into it must not fire it.
const LOUD_SHEEP: String = "neutral_test_loud_sheep"
## "Battlecry: transform this into a Sheep; gain Taunt" as two ops of one effect.
const SHIFTER: String = "neutral_test_shifter"
## The same text as two effects of one play point.
const SPLIT_SHIFTER: String = "neutral_test_split_shifter"
## "Whenever this takes damage, deal its Attack to the enemy hero."
const GRUDGE: String = "neutral_test_grudge"
const GRUDGE_ATTACK: int = 4
## Spell: "Deal 1 damage to a minion, then transform it into a Sheep".
const HIT_AND_SHIFT: String = "neutral_test_hit_and_shift"
## Spell: "Transform a minion into a Loud Sheep".
const SHIFT: String = "neutral_test_shift"
## Spell: "Return a minion to its owner's hand".
const BOUNCE: String = "neutral_test_bounce"
## Spell: "Copy each friendly minion into your hand".
const COPY_ALL: String = "neutral_test_copy_all"
## Spell: "Add 2 copies of a minion to your opponent's hand".
const COPY_TWO_ENEMY: String = "neutral_test_copy_two_enemy"
## Spell: "Add a copy of each card in your hand to your hand".
const COPY_HAND: String = "neutral_test_copy_hand"
## A vanilla 3/4 at cost 3 (card factory set).
const VANILLA: String = "neutral_test_vanilla_3_4"
const VANILLA_COST: int = 3
const VANILLA_ATTACK: int = 3
const VANILLA_HEALTH: int = 4
const TAUNTER: String = "neutral_test_taunt"
## "Your minions have +1 Attack" as a minion (C7 order).
const LORD: String = "neutral_test_lord"
const BUFF_DELTA: int = 2


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
var _log: TestEventLog = null
var _records: Dictionary = {}


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null
	_log = null
	_records = {}


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


## The C11 fixture, the vanilla set and the inline hosts.
func _db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	var flat: JSON = load(FLAT)
	for record: Dictionary in flat.data:
		by_id[record.id] = record
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	by_id[OGRE] = CardFactory.make_minion(OGRE, 5, OGRE_STAT, OGRE_STAT, [KEYWORD_TAUNT, "deathrattle"], {"effects": _fx(
		'{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":%d}]}' % OGRE_DEATHRATTLE_DAMAGE)})
	by_id[LOUD_SHEEP] = CardFactory.make_minion(LOUD_SHEEP, 1, 1, 1, ["battlecry"], {"effects": _fx(
		'{"trigger":"battlecry","targets":"owner","ops":[{"op":"draw","count":1}]}')})
	by_id[SHIFTER] = CardFactory.make_minion(SHIFTER, 1, 2, 2, ["battlecry"], {"effects": _fx(
		'{"trigger":"battlecry","targets":"self","ops":[{"op":"transform","card_id":"%s"},{"op":"give_keyword","keyword":"taunt"}]}' % SHEEP)})
	by_id[SPLIT_SHIFTER] = CardFactory.make_minion(SPLIT_SHIFTER, 1, 2, 2, ["battlecry"], {"effects": _fx(
		'[{"trigger":"battlecry","targets":"self","ops":[{"op":"transform","card_id":"%s"}]},{"trigger":"battlecry","targets":"self","ops":[{"op":"give_keyword","keyword":"taunt"}]}]' % SHEEP)})
	by_id[GRUDGE] = CardFactory.make_minion(GRUDGE, 3, GRUDGE_ATTACK, 6, [], {"effects": _fx(
		'{"trigger":"on_damage_taken","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"source.attack"}}]}')})
	by_id[HIT_AND_SHIFT] = CardFactory.make_spell(HIT_AND_SHIFT, 1, _fx(
		'{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"damage","amount":1,"spell_damage":false},{"op":"transform","card_id":"%s"}]}' % SHEEP))
	by_id[SHIFT] = CardFactory.make_spell(SHIFT, 1, _fx(
		'{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"transform","card_id":"%s"}]}' % LOUD_SHEEP))
	by_id[BOUNCE] = CardFactory.make_spell(BOUNCE, 1, _fx(
		'{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"return_to_hand"}]}'))
	by_id[COPY_ALL] = CardFactory.make_spell(COPY_ALL, 1, _fx(
		'{"trigger":"cast","targets":"all_friendly_minions","ops":[{"op":"copy_to_hand"}]}'))
	by_id[COPY_TWO_ENEMY] = CardFactory.make_spell(COPY_TWO_ENEMY, 1, _fx(
		'{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"copy_to_hand","count":2,"side":"opponent"}]}'))
	by_id[COPY_HAND] = CardFactory.make_spell(COPY_HAND, 1, _fx(
		'{"trigger":"cast","targets":"hand","ops":[{"op":"copy_to_hand"}]}'))
	by_id[LORD] = CardFactory.make_minion(LORD, 1, 1, 1, ["aura"], {"effects": _fx(
		'{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","attack":1}]}')})
	_records = by_id
	return FakeCardDatabase.new(by_id)


## A started engine bound to a real `EffectResolver` with [param installers],
## past a keep-all mulligan (player Main, turn 1), both boards and hands empty,
## 10 mana.
func _main_phase(installers: Array = []) -> RulesEngine:
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var player: Array = installers.filter(func(i: HookInstaller) -> bool: return i.side == &"player")
	var boss: Array = installers.filter(func(i: HookInstaller) -> bool: return i.side == &"boss")
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log, {
		"player": {"hook_installers": player}, "boss": {"hook_installers": boss},
	})
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	_engine.start(config)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	for side: String in MatchRecords.SIDES:
		_engine.state().players[side].hand.clear()
		_engine.state().players[side].board.clear()
	_engine.state().players[SIDE_PLAYER].mana_current = 10
	return _engine


## The treasure record [param id]'s installer, as `Treasures.installers_for` builds it.
func _treasure(id: String) -> HookInstaller:
	if _records.is_empty():
		_db()
	return HookInstaller.new(TREASURE, id, &"player", _records[id].effects)


func _put(side: String, def_id: String, attack: int, health: int, keywords: Array = []) -> int:
	return int(MatchFactory.summon(_engine.state(), side, attack, health, -1, keywords, def_id).entity_id)


func _to_hand(side: String, def_id: String) -> Dictionary:
	var card: Dictionary = MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(_engine.state()), def_id, "hand")
	_engine.state().players[side].hand.append(card)
	return card


func _fill_hand(side: String) -> void:
	while (_engine.state().players[side].hand as Array).size() < _engine.rule("hand_size"):
		_to_hand(side, VANILLA)


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


## Casts the only spell in hand, or the one at [param index], at [param target].
func _cast(target: Variant = null, index: int = 0) -> void:
	_submit(MatchRecords.play_card(SIDE_PLAYER, index, null, target))


## Plays the minion at hand [param index] to the right of the board.
func _play(index: int = 0, target: Variant = null) -> void:
	var position: int = (_engine.state().players[SIDE_PLAYER].board as Array).size()
	_submit(MatchRecords.play_card(SIDE_PLAYER, index, position, target))


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


func _events(from_seq: int, type: String) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq and str(e.type) == type)


func _resolved_of(from_seq: int, host_id: String) -> Array:
	return _events(from_seq, "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.host_id) == host_id).map(
		func(e: Dictionary) -> Dictionary: return e.payload)


func _board(side: String) -> Array:
	return _engine.state().players[side].board


func _hand(side: String) -> Array:
	return _engine.state().players[side].hand


func _hero(side: String) -> int:
	return int(_engine.state().players[side].hero.entity_id)


func _hero_health(side: String) -> int:
	return _engine.health(_engine.state().players[side].hero)


func _has(record: Dictionary, keyword: String) -> bool:
	return EffectSelectors.has_keyword(record, keyword)


## Runs one empty engine step, so its C10 loop recomputes the auras.
func _recompute() -> void:
	_engine.run_action(func() -> void: pass)


# --- AC-30: transform -----------------------------------------------------------

func test_ac30_row_31_makes_a_new_1_1_sheep_with_no_keywords_in_the_same_slot() -> void:
	_main_phase()
	_put(SIDE_BOSS, VANILLA, 1, 1)
	var ogre: int = _put(SIDE_BOSS, OGRE, OGRE_STAT, OGRE_STAT, [KEYWORD_TAUNT, "deathrattle"])
	_to_hand(SIDE_PLAYER, ROW_31)
	_play(0, ogre)
	var sheep: Dictionary = _board(SIDE_BOSS)[1]
	assert_int(int(sheep.entity_id)).is_not_equal(ogre)
	assert_str(str(sheep.def_id)).is_equal(SHEEP)
	assert_int(_engine.attack(sheep)).is_equal(1)
	assert_int(_engine.health(sheep)).is_equal(1)
	assert_array(sheep.keywords).is_empty()


func test_ac30_the_entry_logs_the_old_target_and_the_new_id() -> void:
	_main_phase()
	var ogre: int = _put(SIDE_BOSS, OGRE, OGRE_STAT, OGRE_STAT)
	_to_hand(SIDE_PLAYER, ROW_31)
	var before: int = _last_seq()
	_play(0, ogre)
	var op: Dictionary = _resolved_of(before, ROW_31)[0].ops[0]
	assert_str(str(op.outcome)).is_equal(EffectOps.APPLIED)
	assert_array(op.targets).is_equal([ogre])
	assert_array(op.values.new_ids).is_equal([int(_board(SIDE_BOSS)[0].entity_id)])
	assert_str(str(op.values.card_id)).is_equal(SHEEP)


func test_ac30_the_new_bodys_battlecry_does_not_fire() -> void:
	_main_phase()
	var target: int = _put(SIDE_BOSS, VANILLA, 1, 1)
	_to_hand(SIDE_PLAYER, SHIFT)
	var deck: int = (_engine.state().players[SIDE_PLAYER].deck as Array).size()
	var before: int = _last_seq()
	_cast(target)
	assert_str(str(_board(SIDE_BOSS)[0].def_id)).is_equal(LOUD_SHEEP)
	assert_array(_resolved_of(before, LOUD_SHEEP)).is_empty()
	assert_int((_engine.state().players[SIDE_PLAYER].deck as Array).size()).is_equal(deck)


func test_ac30_a_sheep_that_later_dies_fires_no_deathrattle() -> void:
	_main_phase()
	var ogre: int = _put(SIDE_BOSS, OGRE, OGRE_STAT, OGRE_STAT, [KEYWORD_TAUNT, "deathrattle"])
	_to_hand(SIDE_PLAYER, ROW_31)
	_play(0, ogre)
	var player_health: int = _hero_health(SIDE_PLAYER)
	var sheep: int = int(_board(SIDE_BOSS)[0].entity_id)
	var before: int = _last_seq()
	_engine.run_action(func() -> void: _engine.destroy(sheep))
	assert_array(_board(SIDE_BOSS)).is_empty()
	assert_array(_resolved_of(before, OGRE)).is_empty()
	assert_int(_hero_health(SIDE_PLAYER)).is_equal(player_health)


func test_ac30_enchantments_and_damage_do_not_survive_a_transform() -> void:
	_main_phase()
	var target: int = _put(SIDE_BOSS, VANILLA, VANILLA_ATTACK, VANILLA_HEALTH)
	_engine.apply_enchantment(target, {"attack_delta": BUFF_DELTA, "health_delta": BUFF_DELTA})
	_board(SIDE_BOSS)[0].damage_taken = 1
	_to_hand(SIDE_PLAYER, ROW_31)
	_play(0, target)
	var sheep: Dictionary = _board(SIDE_BOSS)[0]
	assert_array(sheep.enchantments).is_empty()
	assert_int(int(sheep.damage_taken)).is_equal(0)


func test_ac30_a_minion_transformed_in_its_own_battlecry_takes_the_later_self_ops() -> void:
	_main_phase()
	_to_hand(SIDE_PLAYER, SHIFTER)
	var before: int = _last_seq()
	_play()
	var sheep: Dictionary = _board(SIDE_PLAYER)[0]
	assert_str(str(sheep.def_id)).is_equal(SHEEP)
	assert_bool(_has(sheep, KEYWORD_TAUNT)).is_true()
	var ops: Array = _resolved_of(before, SHIFTER)[0].ops
	assert_array(ops[1].targets).is_equal([int(sheep.entity_id)])


## C6.5 names the effect, but a later effect of the same play point is still `self`.
func test_a_later_effect_of_the_same_play_point_acts_on_the_new_body() -> void:
	_main_phase()
	_to_hand(SIDE_PLAYER, SPLIT_SHIFTER)
	_play()
	assert_bool(_has(_board(SIDE_PLAYER)[0], KEYWORD_TAUNT)).is_true()


func test_ac30_a_queued_trigger_of_the_old_entity_resolves_from_its_snapshot() -> void:
	_main_phase()
	var grudge: int = _put(SIDE_PLAYER, GRUDGE, GRUDGE_ATTACK, 6)
	_to_hand(SIDE_PLAYER, HIT_AND_SHIFT)
	var boss_health: int = _hero_health(SIDE_BOSS)
	var before: int = _last_seq()
	_cast(grudge)
	assert_str(str(_board(SIDE_PLAYER)[0].def_id)).is_equal(SHEEP)
	assert_int(_resolved_of(before, GRUDGE).size()).is_equal(1)
	assert_int(_hero_health(SIDE_BOSS)).is_equal(boss_health - GRUDGE_ATTACK)


func test_transform_does_not_reset_summoning_sickness() -> void:
	_main_phase()
	var rested: int = _put(SIDE_BOSS, VANILLA, 1, 1)
	var fresh: int = _put(SIDE_BOSS, VANILLA, 1, 1)
	_board(SIDE_BOSS)[0].summoning_sick = false
	_board(SIDE_BOSS)[1].summoning_sick = true
	_to_hand(SIDE_PLAYER, SHIFT)
	_to_hand(SIDE_PLAYER, SHIFT)
	_cast(rested)
	_cast(fresh)
	assert_str(str(_board(SIDE_BOSS)[0].def_id)).is_equal(LOUD_SHEEP)
	assert_str(str(_board(SIDE_BOSS)[1].def_id)).is_equal(LOUD_SHEEP)
	assert_bool(bool(_board(SIDE_BOSS)[0].summoning_sick)).is_false()
	assert_bool(bool(_board(SIDE_BOSS)[1].summoning_sick)).is_true()


# --- AC-31: copy_to_hand --------------------------------------------------------

func test_ac31_row_32_copies_the_definition_never_the_buffed_damaged_instance() -> void:
	_main_phase()
	var target: int = _put(SIDE_PLAYER, VANILLA, VANILLA_ATTACK, VANILLA_HEALTH)
	_engine.apply_enchantment(target, {"attack_delta": BUFF_DELTA, "health_delta": BUFF_DELTA})
	_board(SIDE_PLAYER)[0].damage_taken = 1
	_to_hand(SIDE_PLAYER, ROW_32)
	_play(0, target)
	var card: Dictionary = _hand(SIDE_PLAYER)[0]
	assert_str(str(card.def_id)).is_equal(VANILLA)
	assert_int(_engine.effective_cost(card, SIDE_PLAYER)).is_equal(VANILLA_COST)
	_play()
	var copy: Dictionary = _board(SIDE_PLAYER).back()
	assert_int(_engine.attack(copy)).is_equal(VANILLA_ATTACK)
	assert_int(_engine.health(copy)).is_equal(VANILLA_HEALTH)
	assert_int(_engine.max_health(copy)).is_equal(VANILLA_HEALTH)


func test_copy_to_hand_of_a_silenced_minion_gives_the_bare_unsilenced_definition() -> void:
	_main_phase()
	var target: int = _put(SIDE_PLAYER, TAUNTER, 2, 2, [KEYWORD_TAUNT])
	_engine.run_action(func() -> void: _engine.silence(target))
	_to_hand(SIDE_PLAYER, ROW_32)
	_play(0, target)
	_play()
	var copy: Dictionary = _board(SIDE_PLAYER).back()
	assert_bool(bool(copy.silenced)).is_false()
	assert_bool(_has(copy, KEYWORD_TAUNT)).is_true()


func test_copy_to_hand_at_a_full_hand_burns_with_outcome_burned() -> void:
	_main_phase()
	var target: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	_fill_hand(SIDE_BOSS)
	_to_hand(SIDE_PLAYER, COPY_TWO_ENEMY)
	var before: int = _last_seq()
	_cast(target)
	assert_int(_events(before, "card_burned").size()).is_equal(2)
	assert_array(_events(before, "card_added_to_hand")).is_empty()
	assert_str(str(_resolved_of(before, COPY_TWO_ENEMY)[0].ops[0].outcome)).is_equal(EffectOps.BURNED)


func test_copy_to_hand_count_and_side_put_the_copies_in_the_opponents_hand() -> void:
	_main_phase()
	var target: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	_to_hand(SIDE_PLAYER, COPY_TWO_ENEMY)
	var before: int = _last_seq()
	_cast(target)
	assert_int(_hand(SIDE_BOSS).size()).is_equal(2)
	assert_str(str(_hand(SIDE_BOSS)[1].def_id)).is_equal(VANILLA)
	assert_str(str(_resolved_of(before, COPY_TWO_ENEMY)[0].ops[0].outcome)).is_equal(EffectOps.APPLIED)


## C5 legal targets: "characters (minions), hand/deck cards".
func test_copy_to_hand_copies_a_card_instance_in_hand() -> void:
	_main_phase()
	_to_hand(SIDE_PLAYER, COPY_HAND)
	var source: Dictionary = _to_hand(SIDE_PLAYER, VANILLA)
	_cast()
	assert_int(_hand(SIDE_PLAYER).size()).is_equal(2)
	assert_str(str(_hand(SIDE_PLAYER)[1].def_id)).is_equal(VANILLA)
	assert_int(int(_hand(SIDE_PLAYER)[1].instance_id)).is_not_equal(int(source.instance_id))


func test_copy_to_hand_with_no_target_is_no_target() -> void:
	_main_phase()
	_to_hand(SIDE_PLAYER, COPY_ALL)
	var before: int = _last_seq()
	_cast()
	assert_str(str(_resolved_of(before, COPY_ALL)[0].ops[0].outcome)).is_equal(EffectOps.NO_TARGET)


# --- AC-31: return_to_hand ------------------------------------------------------

func test_ac31_return_to_hand_is_a_fresh_instance_at_printed_cost_with_the_buffs_gone() -> void:
	_main_phase()
	var target: int = _put(SIDE_PLAYER, VANILLA, VANILLA_ATTACK, VANILLA_HEALTH)
	_engine.apply_enchantment(target, {"attack_delta": BUFF_DELTA, "expires": MatchRecords.EXPIRES_END_OF_TURN})
	_to_hand(SIDE_PLAYER, BOUNCE)
	var before: int = _last_seq()
	_cast(target)
	assert_array(_board(SIDE_PLAYER)).is_empty()
	var card: Dictionary = _hand(SIDE_PLAYER)[0]
	assert_int(int(card.instance_id)).is_not_equal(target)
	assert_array(card.cost_modifiers).is_empty()
	assert_int(_engine.effective_cost(card, SIDE_PLAYER)).is_equal(VANILLA_COST)
	var op: Dictionary = _resolved_of(before, BOUNCE)[0].ops[0]
	assert_str(str(op.outcome)).is_equal(EffectOps.APPLIED)
	assert_array(op.targets).is_equal([target])
	_play()
	var replayed: Dictionary = _board(SIDE_PLAYER)[0]
	assert_int(_engine.attack(replayed)).is_equal(VANILLA_ATTACK)
	assert_array(replayed.enchantments).is_empty()


func test_ac31_counters_read_zero_when_the_bounced_minion_is_replayed() -> void:
	_main_phase()
	var target: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	EffectRuntime.write_counter(_engine.state().effects, target, "seen", 3)
	_to_hand(SIDE_PLAYER, BOUNCE)
	_cast(target)
	_play()
	var replayed: int = int(_board(SIDE_PLAYER)[0].entity_id)
	assert_int(EffectRuntime.counter(_engine.state().effects, replayed, "seen")).is_equal(0)


func test_return_to_hand_goes_to_the_minions_controller() -> void:
	_main_phase()
	var target: int = _put(SIDE_BOSS, VANILLA, 1, 1)
	_to_hand(SIDE_PLAYER, BOUNCE)
	_cast(target)
	assert_int(_hand(SIDE_BOSS).size()).is_equal(1)
	assert_array(_hand(SIDE_PLAYER)).is_empty()


func test_return_to_hand_at_a_full_hand_is_burned_with_no_card_burned_or_added() -> void:
	_main_phase()
	var target: int = _put(SIDE_BOSS, VANILLA, 1, 1)
	_fill_hand(SIDE_BOSS)
	_to_hand(SIDE_PLAYER, BOUNCE)
	var before: int = _last_seq()
	_cast(target)
	var returned: Array = _events(before, "minion_returned")
	assert_int(returned.size()).is_equal(1)
	assert_bool(bool(returned[0].payload.burned)).is_true()
	assert_array(_events(before, "card_burned")).is_empty()
	assert_array(_events(before, "card_added_to_hand")).is_empty()
	assert_str(str(_resolved_of(before, BOUNCE)[0].ops[0].outcome)).is_equal(EffectOps.BURNED)


# --- AC-32: a keyword aura hosted on a treasure ----------------------------------

func _rush_minion_and_defender() -> Array[int]:
	var defender: int = _put(SIDE_BOSS, VANILLA, 1, 9)
	_to_hand(SIDE_PLAYER, "neutral_test_vanilla_2_2")
	_play()
	return [int(_board(SIDE_PLAYER)[0].entity_id), defender]


func test_ac32_with_row_42_a_played_minion_may_attack_a_minion_the_same_turn() -> void:
	_main_phase([_treasure(ROW_42)])
	var ids: Array[int] = _rush_minion_and_defender()
	assert_bool(_engine.submit(MatchRecords.attack(SIDE_PLAYER, ids[0], ids[1])).accepted).is_true()


func test_ac32_with_row_42_attacking_the_hero_is_rush_cannot_hit_hero() -> void:
	_main_phase([_treasure(ROW_42)])
	var ids: Array[int] = _rush_minion_and_defender()
	var result: Dictionary = _engine.submit(MatchRecords.attack(SIDE_PLAYER, ids[0], _hero(SIDE_BOSS)))
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_RUSH_CANNOT_HIT_HERO)


func test_ac32_without_the_treasure_the_attack_is_summoning_sick() -> void:
	_main_phase()
	var ids: Array[int] = _rush_minion_and_defender()
	var result: Dictionary = _engine.submit(MatchRecords.attack(SIDE_PLAYER, ids[0], ids[1]))
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_SUMMONING_SICK)


func test_ac32_auras_recomputed_lists_rush_and_the_enchantment_names_the_treasure() -> void:
	_main_phase([_treasure(ROW_42)])
	_to_hand(SIDE_PLAYER, "neutral_test_vanilla_2_2")
	var before: int = _last_seq()
	_play()
	var minion: Dictionary = _board(SIDE_PLAYER)[0]
	var entries: Array = []
	for event: Dictionary in _events(before, "auras_recomputed"):
		entries.append_array((event.payload.changes as Array).filter(func(c: Dictionary) -> bool: return int(c.get("entity_id", -1)) == int(minion.entity_id)))
	assert_bool(entries.is_empty()).is_false()
	assert_array(entries.back().keywords).contains([KEYWORD_RUSH])
	assert_int((minion.enchantments as Array).size()).is_equal(1)
	assert_str(str(minion.enchantments[0].source_entity_id)).is_equal(ROW_42)
	assert_bool(bool(minion.enchantments[0].is_aura)).is_true()


## C7: player board, boss board, then the treasure auras on the hero slot.
func test_a_treasure_aura_applies_after_the_boards_in_the_recompute_source_order() -> void:
	_main_phase([_treasure(ROW_42)])
	_put(SIDE_PLAYER, LORD, 1, 1, ["aura"])
	_recompute()
	var sources: Array = (_board(SIDE_PLAYER)[0].enchantments as Array).map(func(e: Dictionary) -> Variant: return e.source_entity_id)
	assert_array(sources).is_equal([int(_board(SIDE_PLAYER)[0].entity_id), ROW_42])


func test_an_aura_on_a_boss_passive_covers_the_boss_side_only() -> void:
	var taunts: Array[Dictionary] = []
	taunts.assign(_fx('{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","keywords":["taunt"]}]}'))
	_main_phase([HookInstaller.new(PASSIVE, "boss_test_gatekeeper", &"boss", taunts)])
	_put(SIDE_BOSS, VANILLA, 1, 1)
	_put(SIDE_PLAYER, VANILLA, 1, 1)
	_recompute()
	assert_bool(_has(_board(SIDE_BOSS)[0], KEYWORD_TAUNT)).is_true()
	assert_bool(_has(_board(SIDE_PLAYER)[0], KEYWORD_TAUNT)).is_false()


func test_a_treasure_aura_reaches_the_owner_weapon_selector() -> void:
	var whetstone: Array[Dictionary] = []
	whetstone.assign(_fx('{"trigger":"aura","targets":"owner_weapon","ops":[{"op":"aura","attack":1}]}'))
	_main_phase([HookInstaller.new(TREASURE, "treasure_test_whetstone", &"player", whetstone)])
	@warning_ignore("return_value_discarded")
	_engine.equip_weapon(SIDE_PLAYER, "neutral_test_weapon_2_2")
	_recompute()
	assert_int(_engine.attack(_engine.state().players[SIDE_PLAYER].hero)).is_equal(3)


func test_a_duplicate_installer_applies_its_aura_once() -> void:
	_main_phase([_treasure(ROW_42), _treasure(ROW_42)])
	_put(SIDE_PLAYER, VANILLA, 1, 1)
	_recompute()
	assert_int((_board(SIDE_PLAYER)[0].enchantments as Array).size()).is_equal(1)


## ADR-0005 / story 013: an `aura` is not a hook entry.
func test_a_treasure_aura_is_not_a_hook_entry() -> void:
	_main_phase([_treasure(ROW_42)])
	assert_int(_engine.state().hooks.entry_count()).is_equal(0)
	assert_int(_engine.state().hooks.hosts().size()).is_equal(1)


## The clone binds a fresh resolver with no installers (ADR-0007 Decision 3): the
## aura has to travel in the copied state.
func test_a_clone_recomputes_a_treasure_aura_without_its_installer() -> void:
	_main_phase([_treasure(ROW_42)])
	_to_hand(SIDE_PLAYER, VANILLA)
	var sandbox: RulesEngine = _engine.clone()
	assert_bool(sandbox.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)).accepted).is_true()
	assert_bool(_has(sandbox.state().players[SIDE_PLAYER].board[0], KEYWORD_RUSH)).is_true()
	sandbox.end_match()


func test_the_effect_runtime_stays_plain_data_with_an_aura_host() -> void:
	_main_phase([_treasure(ROW_42)])
	assert_bool(EffectRuntime.is_runtime(_engine.state().effects)).is_true()


## `int()` of a treasure id reads the digits in it as an entity id.
func test_a_treasure_source_is_no_entity_for_a_filter() -> void:
	assert_int(EffectSelectors.run_source({"source_id": "treasure_fx_row_42_rush_banner"})).is_equal(-1)
	assert_int(EffectSelectors.run_source({"source_id": 42})).is_equal(42)
