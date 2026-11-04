## card-effects story 012 — auras through `recompute_auras()`, the hand-cost
## aura and the enchantment lifecycle (design/gdd/card-effects.md C7, F1
## `hand_aura_delta`, F2, F3, Edge Cases "Buffs, auras and Silence"; AC-26,
## AC-27, AC-28, AC-29; ADR-0007 Decision 1: the engine's C10 loop strips
## every `is_aura` enchantment and calls the resolver, which re-applies every
## live aura through `apply_enchantment(…, is_aura: true)`).
##
## The engine is the real `RulesEngine` from `MatchFactory`'s config with a
## `TestRngService` and a `TestEventLog`, bound to the real `EffectResolver`,
## over the committed C11 fixture (`tests/fixtures/cards_effects_test.json`,
## rows 24 / 26 / 27) and the inline hosts below. Boards are laid out with
## `MatchFactory.summon` (a fixture move, no event); `engine.run_action` is
## the engine-initiated step whose C10 loop recomputes the auras.
extends GdUnitTestSuite

const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
## "Your spells cost (1) less" (`aura`, `zone: hand`, `hand` + `type: spell`).
const ROW_24: String = "knowledge_fx_row_24_archivist"
## "Other friendly minions have +1/+1" (`all_friendly_minions` + `not_self`).
const ROW_26: String = "neutral_fx_row_26_aura_lord"
## "Adjacent minions have +2 Attack" (`adjacent`).
const ROW_27: String = "neutral_fx_row_27_flank_banner"
const VANILLA: String = "neutral_test_vanilla"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
## The fixture aura minions' printed stats (rows 24 / 26 / 27, all 2/2).
const ROW_ATTACK: int = 2
const ROW_HEALTH: int = 2
## Row 26's `+1/+1`, row 27's `+2` Attack, row 24's `(1) less`.
const LORD_DELTA: int = 1
const BANNER_ATTACK: int = 2
const ARCHIVIST_COST_DELTA: int = -1
const KEYWORDS_AURA: Array = ["aura"]

## Inline hosts (test-only defs; ids carry their set prefix).
## A 3-cost and a 1-cost spell with no effect, and a 3-cost minion (row 24's
## filter is `type: spell`).
const SPELL_3: String = "knowledge_test_three_cost_spell"
const SPELL_1: String = "knowledge_test_one_cost_spell"
const MINION_3: String = "knowledge_test_three_cost_minion"
const SPELL_3_COST: int = 3
const SPELL_1_COST: int = 1
## "+4/+4 until end of turn" on a chosen minion (AC-28).
const TEMP_BUFF: String = "war_test_temp_buff"
const TEMP_BUFF_DELTA: int = 4
## "Give a minion −2 Health" (AC-28, the negative `buff`).
const WEAKEN: String = "war_test_weaken"
const WEAKEN_DELTA: int = -2
## A 4-cost minion with `passive_hand`: "costs (1) less for each minion that
## died this turn" (C7 — the self-only hand aura, a value expression).
const PASSIVE_HAND: String = "decay_test_passive_hand"
const PASSIVE_HAND_COST: int = 4


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


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null
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


## The C11 fixture, the vanilla set and the inline hosts.
func _db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	var flat: JSON = load(FLAT)
	for record: Dictionary in flat.data:
		by_id[record.id] = record
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	by_id[VANILLA] = CardFactory.make_minion(VANILLA, 1, 1, 1)
	by_id[SPELL_3] = CardFactory.make_spell(SPELL_3, SPELL_3_COST, [], {"set": "knowledge"})
	by_id[SPELL_1] = CardFactory.make_spell(SPELL_1, SPELL_1_COST, [], {"set": "knowledge"})
	by_id[MINION_3] = CardFactory.make_minion(MINION_3, SPELL_3_COST, 3, 3, [], {"set": "knowledge"})
	by_id[TEMP_BUFF] = CardFactory.make_spell(TEMP_BUFF, 1, _fx(
		'{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"buff","attack":4,"health":4,"duration":"until_end_of_turn"}]}'),
		{"set": "war"})
	by_id[WEAKEN] = CardFactory.make_spell(WEAKEN, 1, _fx(
		'{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"buff","health":-2}]}'),
		{"set": "war"})
	by_id[PASSIVE_HAND] = CardFactory.make_minion(PASSIVE_HAND, PASSIVE_HAND_COST, 4, 4, [], {"set": "decay", "effects": _fx(
		'{"trigger":"passive_hand","ops":[{"op":"aura","cost":{"mul":[-1,{"ref":"owner.minions_died_this_turn"}]}}]}')})
	return FakeCardDatabase.new(by_id)


## A started engine bound to a real `EffectResolver`, past a keep-all
## mulligan (player Main, turn 1), both boards and hands empty, 10 mana.
func _main_phase() -> RulesEngine:
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log)
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	_engine.start(config)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	for side: String in MatchRecords.SIDES:
		_engine.state().players[side].hand.clear()
		_engine.state().players[side].board.clear()
	_engine.state().players[SIDE_PLAYER].mana_current = 10
	return _engine


## A minion of [param def_id] at the right of [param side]'s board (base
## stats given, a fixture move); returns its entity id.
func _put(side: String, def_id: String, attack: int, health: int, keywords: Array = []) -> int:
	return int(MatchFactory.summon(_engine.state(), side, attack, health, -1, keywords, def_id).entity_id)


## A fresh card instance of [param def_id] at the end of [param side]'s hand.
func _to_hand(side: String, def_id: String) -> Dictionary:
	var card: Dictionary = MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(_engine.state()), def_id, "hand")
	_engine.state().players[side].hand.append(card)
	return card


## One engine-initiated step that does nothing: its C10 loop recomputes.
func _settle() -> void:
	_engine.run_action(func() -> void: pass)


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


func _minion(id: int) -> Dictionary:
	return EffectSelectors.find(_engine.state(), id)


func _stats(id: int) -> Array[int]:
	var minion: Dictionary = _minion(id)
	return [_engine.attack(minion), _engine.health(minion)]


## The `source_entity_id`s of [param id]'s aura enchantments, in list order.
func _aura_sources(id: int) -> Array:
	return (_minion(id).enchantments as Array).filter(func(e: Dictionary) -> bool: return bool(e.is_aura)).map(
		func(e: Dictionary) -> int: return int(e.source_entity_id))


func _since(from_seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq)


func _of_types(events: Array, types: Array) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return types.has(str(e.type)))


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return str(e.type))


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


func _cost(card: Dictionary, side: String = SIDE_PLAYER) -> int:
	return _engine.effective_cost(card, side)


# --- AC-26: recompute order, stacking, one application per (source, target) ------

func test_two_lords_and_a_flank_banner_make_the_vanilla_5_3() -> void:
	# Arrange — [row 26, row 26, vanilla 1/1, row 27] left to right
	_main_phase()
	var lord_a: int = _put(SIDE_PLAYER, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var lord_b: int = _put(SIDE_PLAYER, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var vanilla: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	var banner: int = _put(SIDE_PLAYER, ROW_27, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)

	# Act
	_settle()

	# Assert — the 1/1 has +4/+2; each lord +1/+1 from the other only; row 27 +2/+2
	assert_array(_stats(vanilla)).is_equal([1 + LORD_DELTA * 2 + BANNER_ATTACK, 1 + LORD_DELTA * 2])
	assert_array(_stats(lord_a)).is_equal([ROW_ATTACK + LORD_DELTA, ROW_HEALTH + LORD_DELTA])
	assert_array(_stats(lord_b)).is_equal([ROW_ATTACK + LORD_DELTA, ROW_HEALTH + LORD_DELTA])
	assert_array(_stats(banner)).is_equal([ROW_ATTACK + LORD_DELTA * 2, ROW_HEALTH + LORD_DELTA * 2])
	# canonical source order (board left to right), one enchantment per (source, target)
	assert_array(_aura_sources(vanilla)).is_equal([lord_a, lord_b, banner])
	assert_array(_aura_sources(lord_a)).is_equal([lord_b])
	assert_array(_aura_sources(lord_b)).is_equal([lord_a])
	assert_array(_aura_sources(banner)).is_equal([lord_a, lord_b])


func test_recomputing_again_never_applies_an_aura_twice() -> void:
	# Arrange
	_main_phase()
	var lord: int = _put(SIDE_PLAYER, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var vanilla: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	_settle()

	# Act — three more steps
	_settle()
	_settle()
	_settle()

	# Assert
	assert_array(_aura_sources(vanilla)).is_equal([lord])
	assert_array(_stats(vanilla)).is_equal([1 + LORD_DELTA, 1 + LORD_DELTA])


func test_an_adjacent_aura_follows_the_board_and_the_boss_side_is_not_friendly() -> void:
	# Arrange — [banner, near, far]; the boss's lord and a boss vanilla
	_main_phase()
	var banner: int = _put(SIDE_PLAYER, ROW_27, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var near: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	var far: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	var boss_lord: int = _put(SIDE_BOSS, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var boss_vanilla: int = _put(SIDE_BOSS, VANILLA, 1, 1)
	_settle()
	assert_array(_stats(near)).is_equal([1 + BANNER_ATTACK, 1])
	assert_array(_stats(far)).is_equal([1, 1])
	assert_array(_stats(boss_vanilla)).is_equal([1 + LORD_DELTA, 1 + LORD_DELTA])
	assert_array(_aura_sources(banner)).is_empty()

	# Act — the near vanilla leaves the board: the far one is now adjacent
	_engine.run_action(func() -> void: _engine.destroy(near))

	# Assert — the selector is evaluated afresh: the far vanilla gains +2
	assert_array(_stats(far)).is_equal([1 + BANNER_ATTACK, 1])
	assert_array(_aura_sources(far)).is_equal([banner])
	assert_array(_aura_sources(boss_vanilla)).is_equal([boss_lord])


# --- AC-27: Silence on the source and on the recipient ---------------------------

func test_silencing_the_lord_kills_the_damaged_minion_it_buffed() -> void:
	# Arrange — row 26 buffing a 2/2 that then takes 2 damage (3/1)
	_main_phase()
	var lord: int = _put(SIDE_PLAYER, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var buffed: int = _put(SIDE_PLAYER, VANILLA, 2, 2)
	_settle()
	_engine.run_action(func() -> void: _engine.apply_damage(buffed, 2, null))
	assert_array(_stats(buffed)).override_failure_message("a recompute must not kill a minion its aura keeps alive").is_equal([3, 1])
	var before: int = _last_seq()

	# Act
	_engine.run_action(func() -> void: _engine.silence(lord))

	# Assert — `silenced` → `auras_recomputed` → `minion_died`; the 2/2 is gone
	var events: Array = _of_types(_since(before), ["silenced", "auras_recomputed", "minion_died"])
	assert_array(_types(events)).is_equal(["silenced", "auras_recomputed", "minion_died"])
	assert_int(int(events[2].payload.entity_id)).is_equal(buffed)
	assert_bool(_minion(buffed).is_empty()).is_true()
	assert_array(_stats(lord)).is_equal([ROW_ATTACK, ROW_HEALTH])


func test_a_silenced_recipient_keeps_the_aura_net_no_change() -> void:
	# Arrange — row 26 buffing a damaged 2/2 (3/1)
	_main_phase()
	var lord: int = _put(SIDE_PLAYER, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var buffed: int = _put(SIDE_PLAYER, VANILLA, 2, 2)
	_settle()
	_engine.run_action(func() -> void: _engine.apply_damage(buffed, 2, null))
	var before: int = _last_seq()

	# Act
	_engine.run_action(func() -> void: _engine.silence(buffed))

	# Assert — still 3/1, the aura re-applied, no stat change to report, no death
	var events: Array = _since(before)
	assert_array(_stats(buffed)).is_equal([3, 1])
	assert_array(_aura_sources(buffed)).is_equal([lord])
	assert_array(_of_types(events, ["auras_recomputed", "minion_died"])).is_empty()


func test_a_damaged_minion_that_gains_an_aura_then_is_silenced_keeps_its_stats_and_damage() -> void:
	# Arrange — a 2/2 takes 1 damage (2/1), then a lord arrives (3/2)
	_main_phase()
	var damaged: int = _put(SIDE_PLAYER, VANILLA, 2, 2)
	_engine.run_action(func() -> void: _engine.apply_damage(damaged, 1, null))
	var lord: int = _put(SIDE_PLAYER, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	_settle()
	assert_array(_stats(damaged)).is_equal([3, 2])
	var before: int = _last_seq()

	# Act
	_engine.run_action(func() -> void: _engine.silence(damaged))

	# Assert — the received aura is stripped and re-applied: still 3/2, the
	# damage untouched (F6 clamp is 0 when max_health is unchanged), no death
	assert_array(_stats(damaged)).is_equal([3, 2])
	assert_int(int(_minion(damaged).damage_taken)).is_equal(1)
	assert_array(_aura_sources(damaged)).is_equal([lord])
	assert_array(_of_types(_since(before), ["auras_recomputed", "minion_died"])).is_empty()


func test_two_damaged_lords_keep_each_other_alive_through_every_recompute() -> void:
	# Arrange — two lords, each at 1 health only through the other's aura
	_main_phase()
	var lord_a: int = _put(SIDE_PLAYER, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var lord_b: int = _put(SIDE_PLAYER, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	_settle()

	# Act — 2 damage to each, then more steps
	_engine.run_action(func() -> void:
		_engine.apply_damage(lord_a, 2, null)
		_engine.apply_damage(lord_b, 2, null))
	_settle()

	# Assert — the strip is not a death: both alive at 3/1
	assert_array(_stats(lord_a)).is_equal([ROW_ATTACK + LORD_DELTA, 1])
	assert_array(_stats(lord_b)).is_equal([ROW_ATTACK + LORD_DELTA, 1])


# --- AC-28: temporary and negative buffs (F3) -------------------------------------

func test_a_temporary_buff_expires_at_the_end_step_and_the_damaged_minion_dies() -> void:
	# Arrange — "+4/+4 until end of turn" on a 1/1, then 4 damage
	_main_phase()
	var target: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	_to_hand(SIDE_PLAYER, TEMP_BUFF)
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, target))
	var applied: Array = _of_types(_log.events, ["enchantment_applied"])
	assert_str(str(applied.back().payload.expires)).is_equal(MatchRecords.EXPIRES_END_OF_TURN)
	assert_array(_stats(target)).is_equal([1 + TEMP_BUFF_DELTA, 1 + TEMP_BUFF_DELTA])
	_engine.run_action(func() -> void: _engine.apply_damage(target, 4, null))
	assert_array(_stats(target)).is_equal([1 + TEMP_BUFF_DELTA, 1])
	var before: int = _last_seq()

	# Act — the owner's End step
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert — `enchantment_removed` then `minion_died`; damage_taken unchanged (1 + 0 − 4)
	var events: Array = _of_types(_since(before), ["enchantment_removed", "minion_died"])
	assert_array(_types(events)).is_equal(["enchantment_removed", "minion_died"])
	assert_int(int(events[0].payload.instance_id)).is_equal(target)
	assert_int(int(events[1].payload.entity_id)).is_equal(target)


func test_a_negative_health_buff_on_a_damaged_3_3_kills_it() -> void:
	# Arrange — a 3/3 with 2 damage
	_main_phase()
	var target: int = _put(SIDE_PLAYER, VANILLA, 3, 3)
	_engine.run_action(func() -> void: _engine.apply_damage(target, 2, null))
	_to_hand(SIDE_PLAYER, WEAKEN)
	var before: int = _last_seq()

	# Act — "−2 Health"
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, target))

	# Assert — applied (no clamp), then it dies at the pass's death check
	var events: Array = _of_types(_since(before), ["enchantment_applied", "minion_died"])
	assert_array(_types(events)).is_equal(["enchantment_applied", "minion_died"])
	assert_int(int(events[0].payload.health_delta)).is_equal(WEAKEN_DELTA)
	assert_that(events[0].payload.expires).is_null()
	assert_int(int(events[1].payload.entity_id)).is_equal(target)


# --- AC-29: the `zone: hand` cost aura, clamped once by F1 ------------------------

func test_one_archivist_makes_a_3_cost_spell_cost_2() -> void:
	# Arrange
	_main_phase()
	_put(SIDE_PLAYER, ROW_24, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var spell: Dictionary = _to_hand(SIDE_PLAYER, SPELL_3)
	var minion: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)

	# Act
	_settle()

	# Assert — spells only
	assert_int(_cost(spell)).is_equal(SPELL_3_COST + ARCHIVIST_COST_DELTA)
	assert_int(_cost(minion)).is_equal(SPELL_3_COST)


func test_two_archivists_stack_and_a_1_cost_spell_floors_at_0() -> void:
	# Arrange
	_main_phase()
	_put(SIDE_PLAYER, ROW_24, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	_put(SIDE_PLAYER, ROW_24, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var three: Dictionary = _to_hand(SIDE_PLAYER, SPELL_3)
	var one: Dictionary = _to_hand(SIDE_PLAYER, SPELL_1)

	# Act
	_settle()

	# Assert — 3 − 2 = 1; 1 − 2 floors once at 0 (the sum stays −1 under the clamp)
	assert_int(_cost(three)).is_equal(SPELL_3_COST + ARCHIVIST_COST_DELTA * 2)
	assert_int(_cost(one)).is_equal(0)
	assert_int((one.cost_modifiers as Array).size()).is_equal(2)


func test_an_archivist_discounts_only_its_owners_hand_and_stops_when_silenced() -> void:
	# Arrange — the boss's Archivist and the player's spell; the player's own Archivist
	_main_phase()
	_put(SIDE_BOSS, ROW_24, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var boss_spell: Dictionary = _to_hand(SIDE_BOSS, SPELL_3)
	var archivist: int = _put(SIDE_PLAYER, ROW_24, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var spell: Dictionary = _to_hand(SIDE_PLAYER, SPELL_3)
	_settle()
	assert_int(_cost(spell)).is_equal(SPELL_3_COST + ARCHIVIST_COST_DELTA)
	assert_int(_cost(boss_spell, SIDE_BOSS)).is_equal(SPELL_3_COST + ARCHIVIST_COST_DELTA)

	# Act
	_engine.run_action(func() -> void: _engine.silence(archivist))

	# Assert — the player's discount ends; the boss's is its own
	assert_int(_cost(spell)).is_equal(SPELL_3_COST)
	assert_int(_cost(boss_spell, SIDE_BOSS)).is_equal(SPELL_3_COST + ARCHIVIST_COST_DELTA)


func test_a_passive_hand_cost_reads_its_value_at_each_recompute() -> void:
	# Arrange — "costs (1) less for each minion that died this turn", in hand
	_main_phase()
	var card: Dictionary = _to_hand(SIDE_PLAYER, PASSIVE_HAND)
	_settle()
	assert_int(_cost(card)).is_equal(PASSIVE_HAND_COST)
	var first: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	var second: int = _put(SIDE_PLAYER, VANILLA, 1, 1)

	# Act — two friendly minions die
	_engine.run_action(func() -> void:
		_engine.destroy(first)
		_engine.destroy(second))

	# Assert
	assert_int(_cost(card)).is_equal(PASSIVE_HAND_COST - 2)
	assert_int((card.cost_modifiers as Array).size()).is_equal(1)


# --- clone(): auras are recomputed state, the clone's are its own -----------------

func test_a_clone_recomputes_its_own_auras_and_leaves_the_live_board_alone() -> void:
	# Arrange
	_main_phase()
	var lord: int = _put(SIDE_PLAYER, ROW_26, ROW_ATTACK, ROW_HEALTH, KEYWORDS_AURA)
	var vanilla: int = _put(SIDE_PLAYER, VANILLA, 1, 1)
	_settle()
	var runtime_before: Dictionary = _engine.state().effects.duplicate(true)

	# Act — the sandbox silences the lord
	var sandbox: RulesEngine = _engine.clone()
	sandbox.run_action(func() -> void: sandbox.silence(lord))
	var sandbox_vanilla: Dictionary = EffectSelectors.find(sandbox.state(), vanilla)
	var sandbox_stats: Array[int] = [sandbox.attack(sandbox_vanilla), sandbox.health(sandbox_vanilla)]
	sandbox.end_match()

	# Assert — the clone lost the aura; the live board and runtime did not
	assert_array(sandbox_stats).is_equal([1, 1])
	assert_array(_stats(vanilla)).is_equal([1 + LORD_DELTA, 1 + LORD_DELTA])
	assert_array(_aura_sources(vanilla)).is_equal([lord])
	assert_bool(_minion(lord).silenced).is_false()
	assert_dict(_engine.state().effects).is_equal(runtime_before)
	_settle()
	assert_array(_stats(vanilla)).is_equal([1 + LORD_DELTA, 1 + LORD_DELTA])
