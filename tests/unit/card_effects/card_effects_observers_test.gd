## card-effects story 008 — event triggers: who responds, scope and queueing
## order (design/gdd/card-effects.md C2 event class and scope keys, C6.2, C6.3
## order table and observer candidate order, Edge Cases "Resolution order and
## the queue"; AC-17, AC-18, AC-22; ADR-0007 Decision 1 and erratum
## 2026-11-03: `resolve` returns the triggers it queues, the engine owns Q).
##
## The engine is the real `RulesEngine` from `MatchFactory`'s config with a
## `TestRngService` and `TestEventLog`, bound to the real `EffectResolver`,
## over the committed C11 fixture `tests/fixtures/cards_effects_test.json`
## (rows 9, 18, 21, 44) and the inline observer hosts below. Event names and
## payload fields are match-rules C15's (DD-X04): `trigger_queued` /
## `trigger_resolved {point, source_id, effect_id}`, `enchantment_applied
## {instance_id, …}`, `card_drawn`, `spell_cast`.
extends GdUnitTestSuite

const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
const ROW_09: String = "decay_fx_row_09_husk_summoner"
const ROW_18: String = "knowledge_fx_row_18_bolt"
const ROW_21: String = "knowledge_fx_row_21_scribe"
const ROW_44: String = "power_fx_row_44_brand"
const HUSK: String = "decay_husk"
const VANILLA: String = "neutral_test_vanilla"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS

## Inline hosts (test-only defs; ids carry their set prefix, CR-2).
## "Whenever a friendly minion is played or summoned, give it +1/+1": one
## `on_play` and one `on_summon` effect (AC-17).
const WELCOMER: String = "neutral_test_welcomer"
## "Whenever this takes damage, draw a card. Deathrattle: gain 1 Armor" (AC-18).
const WINCING: String = "neutral_test_wincing"
## "At the start of your opponent's turn, gain 1 Armor" (AC-22; boss side).
const OPP_WATCHER: String = "neutral_test_opp_watcher"
## "At the start of your turn, gain 1 Armor" (AC-22; player side).
const OWN_WATCHER: String = "neutral_test_own_watcher"
## "Whenever this takes 3 or more damage, draw a card" (`min_amount`).
const THICK_SKIN: String = "neutral_test_thick_skin"


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
	by_id[WELCOMER] = CardFactory.make_minion(WELCOMER, 1, 1, 3, [], {"effects": _fx(
		'[{"trigger":"on_play","targets":"trigger_subject","ops":[{"op":"buff","attack":1,"health":1}]},'
		+ '{"trigger":"on_summon","targets":"trigger_subject","ops":[{"op":"buff","attack":1,"health":1}]}]')})
	by_id[WINCING] = CardFactory.make_minion(WINCING, 1, 1, 1, ["deathrattle"], {"effects": _fx(
		'[{"trigger":"on_damage_taken","ops":[{"op":"draw","count":1}]},'
		+ '{"trigger":"deathrattle","ops":[{"op":"armor","targets":"owner","amount":1}]}]')})
	by_id[OPP_WATCHER] = CardFactory.make_minion(OPP_WATCHER, 1, 1, 3, [], {"effects": _fx(
		'{"trigger":"turn_start","scope":{"side":"opponent"},"ops":[{"op":"armor","targets":"owner","amount":1}]}')})
	by_id[OWN_WATCHER] = CardFactory.make_minion(OWN_WATCHER, 1, 1, 3, [], {"effects": _fx(
		'{"trigger":"turn_start","scope":{"side":"owner"},"ops":[{"op":"armor","targets":"owner","amount":1}]}')})
	by_id[THICK_SKIN] = CardFactory.make_minion(THICK_SKIN, 1, 1, 5, [], {"effects": _fx(
		'{"trigger":"on_damage_taken","scope":{"min_amount":3},"ops":[{"op":"draw","count":1}]}')})
	return FakeCardDatabase.new(by_id)


## A started engine bound to a real `EffectResolver`, past a keep-all
## mulligan (player Main, turn 1), the hand replaced by [param hand], 10 mana.
func _main_phase(hand: Array) -> RulesEngine:
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log)
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
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


## The events appended from [param from_seq] on (exclusive).
func _since(from_seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq)


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return str(e.type))


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


## `[point, source_id]` of every `trigger_resolved` in [param events], in order.
func _resolved_triggers(events: Array) -> Array:
	return _of_type(events, "trigger_resolved").map(func(e: Dictionary) -> Array: return [str(e.payload.point), int(e.payload.source_id)])


func _index_of(events: Array, predicate: Callable) -> int:
	for i: int in events.size():
		if predicate.call(events[i]):
			return i
	return -1


# --- AC-17: on_play + on_summon on a played minion; on_summon only on a token -------

func test_a_minion_played_from_hand_gets_both_observer_buffs_in_c6_3_order() -> void:
	# Arrange
	_main_phase([VANILLA])
	var welcomer: int = _put(SIDE_PLAYER, WELCOMER, 1, 3)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 1, null))

	# Assert — two queued triggers (rows 4 and 6 of the C6.3 minion row), two buffs
	var events: Array = _since(before)
	var played: int = int(_of_type(events, "minion_summoned")[0].payload.entity_id)
	assert_int(_of_type(events, "trigger_queued").size()).is_equal(2)
	assert_array(_resolved_triggers(events)).is_equal([["on_play", welcomer], ["on_summon", welcomer]])
	var buffs: Array = _of_type(events, "enchantment_applied")
	assert_int(buffs.size()).is_equal(2)
	for buff: Dictionary in buffs:
		assert_int(int(buff.payload.instance_id)).is_equal(played)
	var minion: Dictionary = EffectSelectors.find(_engine.state(), played)
	assert_int(_engine.attack(minion)).is_equal(1 + 2)
	assert_int(_engine.health(minion)).is_equal(1 + 2)


func test_husks_summoned_by_a_deathrattle_get_the_on_summon_buff_only() -> void:
	# Arrange — row 9 (Deathrattle: summon two Husks) dies to row 18's 3 damage.
	_main_phase([ROW_18])
	var welcomer: int = _put(SIDE_PLAYER, WELCOMER, 1, 3)
	var summoner: int = _put(SIDE_PLAYER, ROW_09, 2, 2, ["deathrattle"])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, summoner))

	# Assert — the Deathrattle, then one on_summon per Husk; never on_play
	var events: Array = _since(before)
	assert_array(_resolved_triggers(events)).is_equal([["deathrattle", summoner], ["on_summon", welcomer], ["on_summon", welcomer]])
	var husks: Array = (_engine.state().players[SIDE_PLAYER].board as Array).filter(func(m: Dictionary) -> bool: return str(m.def_id) == HUSK)
	assert_int(husks.size()).is_equal(2)
	for husk: Dictionary in husks:
		assert_int((husk.enchantments as Array).size()).is_equal(1)
		assert_int(_engine.attack(husk)).is_equal(1 + 1)
		assert_int(_engine.health(husk)).is_equal(1 + 1)
	var on_summon_passes: Array = _of_type(events, "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.trigger) == "on_summon")
	assert_int(on_summon_passes.size()).is_equal(2)


func test_a_summoned_observer_does_not_observe_its_own_entry() -> void:
	# Arrange — the observer itself is the minion played.
	_main_phase([WELCOMER])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert — candidates include it, but it was not in play before the raise
	var events: Array = _since(before)
	assert_array(_of_type(events, "trigger_queued")).is_empty()
	assert_array(_of_type(events, "enchantment_applied")).is_empty()


# --- AC-18: on_damage_taken resolves before the Deathrattle of the same hit ---------

func test_on_damage_taken_draw_precedes_the_deathrattle_of_the_same_hit() -> void:
	# Arrange — a 1-health WINCING; the player's hero power deals 1 to it.
	_main_phase([])
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = ROW_44
	var wincing: int = _put(SIDE_PLAYER, WINCING, 1, 1, ["deathrattle"])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, wincing))

	# Assert — queued at the damage step, before the death check queues the Deathrattle
	var events: Array = _since(before)
	assert_array(_resolved_triggers(events)).is_equal([["on_damage", wincing], ["deathrattle", wincing]])
	var drawn: int = _index_of(events, func(e: Dictionary) -> bool: return str(e.type) == "card_drawn")
	var deathrattle: int = _index_of(events, func(e: Dictionary) -> bool:
		return str(e.type) == "trigger_resolved" and str(e.payload.point) == "deathrattle")
	assert_int(drawn).is_greater(-1)
	assert_int(drawn).is_less(deathrattle)
	var queued_points: Array = _of_type(events, "trigger_queued").map(func(e: Dictionary) -> String: return str(e.payload.point))
	assert_array(queued_points).is_equal(["on_damage", "deathrattle"])
	assert_int(_index_of(events, func(e: Dictionary) -> bool: return str(e.type) == "trigger_queued")).is_less(
		_index_of(events, func(e: Dictionary) -> bool: return str(e.type) == "minion_died"))


func test_on_damage_taken_below_min_amount_queues_nothing() -> void:
	# Arrange — `min_amount: 3`, hit for 1.
	_main_phase([])
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = ROW_44
	var thick: int = _put(SIDE_PLAYER, THICK_SKIN, 1, 5)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, thick))

	# Assert
	assert_array(_of_type(_since(before), "trigger_queued")).is_empty()


func test_a_silenced_observer_does_not_respond() -> void:
	# Arrange
	_main_phase([])
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = ROW_44
	var wincing: int = _put(SIDE_PLAYER, WINCING, 1, 3, ["deathrattle"])
	EffectSelectors.find(_engine.state(), wincing)["silenced"] = true
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, wincing))

	# Assert
	assert_array(_of_type(_since(before), "trigger_queued")).is_empty()


# --- AC-22: spell observers after the host cast; scope by; candidate order ----------

func test_row_21_draws_after_spell_cast_and_after_the_spells_own_effect_resolved() -> void:
	# Arrange
	_main_phase([ROW_18])
	var scribe: int = _put(SIDE_PLAYER, ROW_21, 2, 2)
	var boss_hero: int = int(_engine.state().players[SIDE_BOSS].hero.entity_id)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, boss_hero))

	# Assert — host `cast` first, then the `on_card_played` observer as a queued pass
	var events: Array = _since(before)
	var cast_at: int = _index_of(events, func(e: Dictionary) -> bool: return str(e.type) == "spell_cast")
	var host_at: int = _index_of(events, func(e: Dictionary) -> bool:
		return str(e.type) == "effect_resolved" and str(e.payload.trigger) == "cast")
	var drawn_at: int = _index_of(events, func(e: Dictionary) -> bool: return str(e.type) == "card_drawn")
	assert_int(cast_at).is_greater(-1)
	assert_int(host_at).is_greater(cast_at)
	assert_int(drawn_at).is_greater(host_at)
	assert_array(_resolved_triggers(events)).is_equal([["on_card_played", scribe]])
	var resolved: Dictionary = _of_type(events, "trigger_resolved")[0]
	var observer: Array = _of_type(events, "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.trigger) == "on_card_played")
	assert_int(observer.size()).is_equal(1)
	assert_int(int(observer[0].cause_seq)).is_equal(int(resolved.seq))
	assert_int(int(observer[0].payload.source_id)).is_equal(scribe)
	assert_int(int(observer[0].payload.depth)).is_equal(1)
	assert_int(int(events[drawn_at].cause_seq)).is_equal(int(resolved.seq))


func test_row_21_does_not_draw_when_the_opponent_casts_a_spell() -> void:
	# Arrange — the boss casts row 18 on its own turn.
	_main_phase([])
	var scribe: int = _put(SIDE_PLAYER, ROW_21, 2, 2)
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	_set_hand(SIDE_BOSS, [ROW_18])
	var player_hero: int = int(_engine.state().players[SIDE_PLAYER].hero.entity_id)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_BOSS, 0, null, player_hero))

	# Assert — scope `by: owner` excludes the opponent's spell
	var events: Array = _since(before)
	assert_array(_of_type(events, "spell_cast")).is_not_empty()
	var from_scribe: Array = _of_type(events, "trigger_queued").filter(func(e: Dictionary) -> bool: return int(e.payload.source_id) == scribe)
	assert_array(from_scribe).is_empty()
	assert_array(_of_type(events, "card_drawn")).is_empty()


func test_a_boss_side_opponent_turn_start_observer_resolves_in_its_candidate_position() -> void:
	# Arrange — a player-side `side: owner` and a boss-side `side: opponent`
	# turn_start observer; reach the player's next Start step.
	_main_phase([])
	var own: int = _put(SIDE_PLAYER, OWN_WATCHER, 1, 3)
	var opp: int = _put(SIDE_BOSS, OPP_WATCHER, 1, 3)
	var mark: int = _last_seq()
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	var boss_start: Array = _resolved_triggers(_since(mark))
	var before: int = _last_seq()

	# Act — the boss ends its turn: the player's Start step runs
	_submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert — player side first (the one observer order), then the boss-side candidate
	var events: Array = _since(before)
	assert_array(_resolved_triggers(events)).is_equal([["turn_start", own], ["turn_start", opp]])
	var gains: Array = _of_type(events, "armor_gained").map(func(e: Dictionary) -> String: return str(e.payload.side))
	assert_array(gains).is_equal([SIDE_PLAYER, SIDE_BOSS])
	var started: int = _index_of(events, func(e: Dictionary) -> bool: return str(e.type) == "turn_started")
	assert_str(str(events[started].payload.side)).is_equal(SIDE_PLAYER)
	# …and neither responded at the boss's own Start step.
	assert_array(boss_start).is_empty()
