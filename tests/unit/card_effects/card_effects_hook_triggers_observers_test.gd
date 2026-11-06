## card-effects story 015 — trigger hooks as synchronous steps, and hook-less
## event triggers as hero-slot observers (design/gdd/card-effects.md C2 hook
## column, C6.0, C6.3 order table, C6.5, C6.7, C9, Edge Cases "Hooks and
## passives"; AC-16, AC-25, AC-36, AC-45; ADR-0005 Decisions 1–4, 8–9, 11;
## ADR-0007 Key Interfaces).
##
## The engine is the real `RulesEngine` with a `TestRngService` and a
## `TestEventLog`, bound to the real `EffectResolver`, over the committed C11
## fixture (`tests/fixtures/cards_effects_test.json`, rows 11, 34, 37, 38, 41) and
## the inline hosts below. Treasures and passives go in through `MatchConfig`, so
## the registry, `bind` and the engine's call sites all run for real. The hook
## fixtures use the shipped DSL words (`turn_start`, `turn_end`, `on_summon`,
## `on_damage_taken`), never the hook-point names: the C2 mapping is what is under
## test (review X2). The last section runs every shipped boss passive on the
## shipped data.
extends GdUnitTestSuite

const BOOT_SCRIPT: GDScript = preload("res://src/core/boot.gd")
const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
const SHIPPED: String = "res://assets/data"
## Row 11: "Whenever a friendly minion dies, gain +1/+1".
const ROW_11: String = "decay_fx_row_11_grave_feeder"
## Row 34: "At the start of your turn, deal 1 damage to a random enemy minion, twice".
const ROW_34: String = "neutral_fx_row_34_twin_pinger"
## Row 37: boss passive "Whenever the player heals, deal 1 damage to their hero".
const ROW_37: String = "boss_fx_row_37_blood_priest"
## Row 38: treasure "At the start of the match, gain 10 Armor".
const ROW_38: String = "treasure_fx_row_38_iron_hide"
## Row 41: treasure "Whenever you draw a card, it costs (1) less".
const ROW_41: String = "treasure_fx_row_41_quick_draw"
const ROW_38_ARMOR: int = 10
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const TREASURE: StringName = HookInstaller.HOST_KIND_TREASURE
const PASSIVE: StringName = HookInstaller.HOST_KIND_PASSIVE
const HUSK: String = "decay_husk"
const VANILLA: String = "neutral_test_vanilla_3_4"
const TEST_TREASURE: String = "treasure_test_hook"
const TEST_PASSIVE: String = "boss_test_passive"
## A treasure id with digits in it: `int()` of it reads 42, an entity id.
const DIGIT_TREASURE: String = "treasure_row_42"

## The armour amounts that tell the hook from the card observer in a log.
const HOOK_ARMOR: int = 1
const CARD_ARMOR: int = 2
const LATER_ARMOR: int = 5
const WOUND: int = 4
const HAND_SIZE: int = TestConstants.HAND_SIZE

## Inline hosts (test-only defs; ids carry their set prefix).
const END_WATCHER: String = "neutral_test_end_watcher"
const PLAYED_WATCHER: String = "neutral_test_played_watcher"
const SUMMON_WATCHER: String = "neutral_test_summon_watcher"
const DRAW_WATCHER: String = "neutral_test_draw_watcher"
const HEAL_FED: String = "neutral_test_heal_fed"
const ANY_DEATH_WATCHER: String = "neutral_test_any_death_watcher"
const STATS_WATCHER: String = "neutral_test_stats_watcher"
const SOURCE_WATCHER: String = "neutral_test_source_watcher"
const SNAPSHOT_SHEEP: String = "neutral_test_snapshot_sheep"
const LOUD_SHEEP: String = "neutral_test_loud_sheep"
const INTO_LOUD_SHEEP: String = "neutral_test_into_loud_sheep"
const FREE_MINION: String = "neutral_test_free_minion"
const SUMMONER: String = "neutral_test_summoner_spell"
const DRAWER: String = "neutral_test_drawer_spell"
const MEND: String = "neutral_test_mend"
const SWEEP_OWN: String = "neutral_test_sweep_own"
const SWEEP_ENEMY: String = "neutral_test_sweep_enemy"
const DEPTH_WATCHER: String = "neutral_test_depth_watcher"
const SHEEP: String = "neutral_sheep"


## `has` / `card` / `hero_power` from a map (the engine and the resolver ask
## nothing else in a match). `boss` and `treasure` stay unreachable: a host is
## never looked up as a card (`card()` of one asserts in the real database).
class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}

	func _init(by_id: Dictionary) -> void:
		records = by_id

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		var record: Variant = records.get(id)
		assert(not id.begins_with("treasure_") and not id.begins_with("boss_fx"), "a host id must never reach card(): %s" % id)
		return record

	func hero_power(id: String) -> Variant:
		return records.get(id)


var _engine: RulesEngine = null
var _sandbox: RulesEngine = null
var _log: TestEventLog = null
var _records: Dictionary = {}


func after_test() -> void:
	if _sandbox != null:
		_sandbox.end_match()
	if _engine != null:
		_engine.end_match()
	_sandbox = null
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


## An `armor` op of [param amount] on the owner.
func _armor(amount: Variant) -> Dictionary:
	return {"op": "armor", "amount": amount}


## One minion def whose effects are [param effects].
func _watcher(id: String, effects: Array, attack: int = 1, health: int = 5) -> Dictionary:
	return CardFactory.make_minion(id, 1, attack, health, [], {"effects": effects})


## The C11 fixture, the vanilla set and the inline hosts.
func _db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	var flat: JSON = load(FLAT)
	for record: Dictionary in flat.data:
		by_id[record.id] = record
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	by_id[HUSK] = CardFactory.make_minion(HUSK, 1, 1, 1)
	by_id[SHEEP] = CardFactory.make_minion(SHEEP, 1, 1, 1)
	by_id[END_WATCHER] = _watcher(END_WATCHER, [{"trigger": "turn_end", "scope": {"side": "owner"}, "targets": "owner", "ops": [_armor(CARD_ARMOR)]}])
	by_id[PLAYED_WATCHER] = _watcher(PLAYED_WATCHER, [{"trigger": "on_card_played", "scope": {"by": "owner"}, "targets": "owner", "ops": [_armor(CARD_ARMOR)]}])
	by_id[SUMMON_WATCHER] = _watcher(SUMMON_WATCHER, [{"trigger": "on_summon", "scope": {"of": "friendly_minion"}, "targets": "owner", "ops": [_armor(CARD_ARMOR)]}])
	by_id[DRAW_WATCHER] = _watcher(DRAW_WATCHER, [{"trigger": "on_draw", "scope": {"side": "owner"}, "targets": "owner", "ops": [_armor(CARD_ARMOR)]}])
	by_id[HEAL_FED] = _watcher(HEAL_FED, [{"trigger": "on_heal", "scope": {"who": "friendly"}, "targets": "self", "ops": [{"op": "buff", "attack": 1, "health": 1}]}])
	by_id[ANY_DEATH_WATCHER] = _watcher(ANY_DEATH_WATCHER, [{"trigger": "on_minion_died", "scope": {"who": "any_minion"}, "targets": "owner", "ops": [_armor(CARD_ARMOR)]}])
	by_id[STATS_WATCHER] = _watcher(STATS_WATCHER, [{"trigger": "on_minion_died", "scope": {"who": "friendly_minion"}, "targets": "owner", "ops": [_armor({"ref": "trigger_subject.attack"})]}])
	by_id[SOURCE_WATCHER] = _watcher(SOURCE_WATCHER, [{"trigger": "on_damage_taken", "scope": {"who": "self"}, "targets": "owner", "ops": [_armor({"ref": "trigger_source.attack"})]}])
	by_id[SNAPSHOT_SHEEP] = _watcher(SNAPSHOT_SHEEP, [{"trigger": "turn_end", "scope": {"side": "owner"}, "ops": [
		{"op": "transform", "targets": "self", "card_id": SHEEP},
		{"op": "armor", "targets": "owner", "amount": {"ref": "source.attack"}},
	]}], 4, 4)
	by_id[LOUD_SHEEP] = _watcher(LOUD_SHEEP, [{"trigger": "on_play", "scope": {"by": "owner"}, "targets": "owner", "ops": [_armor(CARD_ARMOR)]}])
	by_id[INTO_LOUD_SHEEP] = _watcher(INTO_LOUD_SHEEP, [{"trigger": "battlecry", "targets": "self", "ops": [{"op": "transform", "card_id": LOUD_SHEEP}]}])
	by_id[FREE_MINION] = CardFactory.make_minion(FREE_MINION, 0, 1, 1)
	by_id[SUMMONER] = CardFactory.make_spell(SUMMONER, 1, [
		CardFactory.make_effect("cast", [CardFactory.make_op("summon", {"card_id": HUSK, "count": 1, "position": "end"})]),
	])
	by_id[DRAWER] = CardFactory.make_spell(DRAWER, 1, [
		CardFactory.make_effect("cast", [CardFactory.make_op("draw", {"count": 2})]),
	])
	by_id[MEND] = CardFactory.make_spell(MEND, 1, [
		CardFactory.make_effect("cast", [CardFactory.make_op("heal", {"amount": 3})], {"selector": "chosen", "filter": {"kind": "any"}}),
	])
	by_id[SWEEP_OWN] = CardFactory.make_spell(SWEEP_OWN, 1, [
		CardFactory.make_effect("cast", [CardFactory.make_op("damage", {"amount": 1, "spell_damage": false})], {"selector": "all_friendly_minions"}),
	])
	by_id[SWEEP_ENEMY] = CardFactory.make_spell(SWEEP_ENEMY, 1, [
		CardFactory.make_effect("cast", [CardFactory.make_op("damage", {"amount": 1, "spell_damage": false})], {"selector": "all_enemy_minions"}),
	])
	by_id[DEPTH_WATCHER] = _watcher(DEPTH_WATCHER, [{"trigger": "on_heal", "scope": {"who": "friendly"}, "ops": [{"op": "summon", "card_id": HUSK, "count": 1, "position": "end"}]}])
	_records = by_id
	return FakeCardDatabase.new(by_id)


func _start(installers: Array) -> void:
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var player: Array = installers.filter(func(i: HookInstaller) -> bool: return i.side == &"player")
	var boss: Array = installers.filter(func(i: HookInstaller) -> bool: return i.side == &"boss")
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log, {
		"player": {"hook_installers": player}, "boss": {"hook_installers": boss},
	})
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	_engine.start(config)


## A started engine past a keep-all mulligan (player Main, turn 1), both boards
## empty, [param hand] in the player's hand, 10 mana.
func _main_phase(installers: Array = [], hand: Array = []) -> RulesEngine:
	_start(installers)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	for side: String in MatchRecords.SIDES:
		_engine.state().players[side].board.clear()
	_set_hand(SIDE_PLAYER, hand)
	_set_hand(SIDE_BOSS, [])
	return _engine


func _set_hand(side: String, hand: Array) -> void:
	var state: MatchState = _engine.state()
	var cards: Array = state.players[side].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[side].mana_current = 10


## One effect on a host of [param kind] (a treasure on the player, else the passive).
func _host(id: String, side: StringName, effects: Array) -> HookInstaller:
	return HookInstaller.new(PASSIVE if side == &"boss" else TREASURE, id, side, effects)


## "At the start of your turn, gain [param amount] Armor", as a treasure.
func _start_armor(id: String = TEST_TREASURE, amount: int = HOOK_ARMOR) -> HookInstaller:
	return _host(id, &"player", [{"trigger": "turn_start", "scope": {"side": "owner"}, "targets": "owner", "ops": [_armor(amount)]}])


## Row [param id]'s treasure, as `Treasures.installers_for` builds it.
func _treasure(id: String) -> HookInstaller:
	if _records.is_empty():
		@warning_ignore("return_value_discarded")
		_db()
	return HookInstaller.new(TREASURE, id, &"player", _records[id].effects)


## "Whenever a friendly minion dies, summon a 1/1 Husk — once per turn" (Grave Tithe's shape).
func _grave_tithe() -> HookInstaller:
	return _host(TEST_TREASURE, &"player", [{
		"trigger": "on_minion_died", "scope": {"who": "friendly_minion"}, "once_per_turn": true,
		"ops": [{"op": "summon", "card_id": HUSK, "count": 1, "position": "end"}],
	}])


func _put(side: String, attack: int, health: int, def_id: String = VANILLA) -> int:
	return int(MatchFactory.summon(_engine.state(), side, attack, health, -1, [], def_id).entity_id)


func _hero(side: String) -> int:
	return int(_engine.state().players[side].hero.entity_id)


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


## Plays the minion at [param hand_index] at the right of the player's board.
func _play(hand_index: int = 0) -> void:
	_submit(MatchRecords.play_card(SIDE_PLAYER, hand_index, (_engine.state().players[SIDE_PLAYER].board as Array).size(), null))


func _cast(hand_index: int = 0, target: Variant = null, side: String = SIDE_PLAYER) -> void:
	_submit(MatchRecords.play_card(side, hand_index, null, target))


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


func _since(from_seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq)


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


func _index_of(events: Array, type: String, from: int = 0) -> int:
	for i: int in range(from, events.size()):
		if str(events[i].type) == type:
			return i
	return -1


## `amount` of every `armor_gained` in [param events], in order.
func _gains(events: Array) -> Array:
	return _of_type(events, "armor_gained").map(func(e: Dictionary) -> int: return int(e.payload.amount))


## `[point, source_id]` of every `trigger_resolved` in [param events], in order.
func _resolved(events: Array) -> Array:
	return _of_type(events, "trigger_resolved").map(func(e: Dictionary) -> Array: return [str(e.payload.point), e.payload.source_id])


## The events of the player's next Start step, from Main on the player's turn.
func _next_player_start() -> Array:
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	var before: int = _last_seq()
	_submit(MatchRecords.end_turn(SIDE_BOSS))
	return _since(before)


# --- The C2 mapping: which DSL trigger installs where ---------------------------

func test_dsl_turn_triggers_install_on_their_c2_hook_points() -> void:
	# Arrange
	var hooks: HookRegistry = HookRegistry.new()

	# Act
	assert_bool(hooks.install(_host(TEST_TREASURE, &"player", [
		{"trigger": "turn_start"}, {"trigger": "turn_end"}, {"trigger": "on_summon"},
	]))).is_true()

	# Assert
	assert_int(hooks.entries(&"on_turn_start").size()).is_equal(1)
	assert_int(hooks.entries(&"on_turn_end").size()).is_equal(1)
	assert_int(hooks.entries(&"on_minion_summoned").size()).is_equal(1)
	assert_int(hooks.entry_count()).is_equal(3)


func test_on_damage_taken_is_a_hook_with_hero_scope_only() -> void:
	# Arrange
	var hooks: HookRegistry = HookRegistry.new()

	# Act
	assert_bool(hooks.install(_host(TEST_TREASURE, &"player", [
		{"trigger": "on_damage_taken", "scope": {"who": "owner_hero"}},
		{"trigger": "on_damage_taken", "scope": {"who": "friendly"}},
		{"trigger": "on_damage_taken"},
	]))).is_true()

	# Assert — `who: friendly` and the default `self` are hero-slot observers (C2, C9)
	assert_int(hooks.entries(&"on_hero_damaged").size()).is_equal(1)
	assert_int(hooks.entry_count()).is_equal(1)


func test_hookless_event_triggers_never_enter_the_registry() -> void:
	# Arrange
	var hookless: Array = ["on_play", "after_cast", "on_attack", "on_damage_dealt", "on_heal", "on_minion_died", "on_hero_power", "on_weapon_equipped"]
	var hooks: HookRegistry = HookRegistry.new()

	# Act
	for trigger: String in hookless:
		assert_bool(hooks.install(_host("treasure_%s" % trigger, &"player", [{"trigger": trigger}]))).is_true()

	# Assert — every host is recorded, no entry exists
	assert_int(hooks.entry_count()).is_equal(0)
	assert_int(hooks.hosts().size()).is_equal(hookless.size())


# --- AC-16: Start and End order --------------------------------------------------

func test_ac16_the_start_hook_runs_before_row_34_and_its_pings_are_one_pass() -> void:
	# Arrange — row 34 on the player's board; one enemy minion takes both pings
	_main_phase([_start_armor()])
	@warning_ignore("return_value_discarded")
	var pinger: int = _put(SIDE_PLAYER, 2, 2, ROW_34)
	@warning_ignore("return_value_discarded")
	_put(SIDE_BOSS, 1, 5)

	# Act
	var events: Array = _next_player_start()

	# Assert
	var armor: int = _index_of(events, "armor_gained")
	var first_hit: int = _index_of(events, "damage_dealt")
	var second_hit: int = _index_of(events, "damage_dealt", first_hit + 1)
	assert_int(armor).is_greater_equal(0)
	assert_int(armor).is_less(first_hit)
	assert_int(second_hit).is_greater(first_hit)
	assert_array(_resolved(events.slice(armor, first_hit))).is_equal([["turn_start", pinger]])
	assert_array(_resolved(events.slice(first_hit, second_hit))).is_empty()
	# C6.0: `RESOLUTION_STEP_CAP` counts passes: the hook's, then row 34's.
	var passes: Array = _of_type(events, "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.trigger) == "turn_start")
	assert_array(passes.map(func(e: Dictionary) -> Variant: return e.payload.source_id)).is_equal([TEST_TREASURE, pinger])


func test_ac16_the_hook_pass_names_the_treasure_and_is_never_queued() -> void:
	# Arrange
	_main_phase([_start_armor()])

	# Act
	var events: Array = _next_player_start()

	# Assert — one step at the hook point: no `trigger_queued`, no `trigger_resolved`
	var pass_event: Dictionary = _of_type(events, "effect_resolved")[0]
	assert_str(str(pass_event.payload.host_kind)).is_equal(String(TREASURE))
	assert_str(str(pass_event.payload.host_id)).is_equal(TEST_TREASURE)
	assert_str(str(pass_event.payload.source_id)).is_equal(TEST_TREASURE)
	assert_str(str(pass_event.payload.owner)).is_equal(SIDE_PLAYER)
	assert_str(str(_of_type(events, "armor_gained")[0].payload.source_id)).is_equal(TEST_TREASURE)
	assert_array(_of_type(events, "trigger_queued")).is_empty()
	assert_array(_of_type(events, "trigger_resolved")).is_empty()


func test_a_turn_hook_runs_only_on_its_owners_turn_by_default() -> void:
	# Arrange
	_main_phase([_start_armor()])
	var before: int = _last_seq()

	# Act — the boss's Start step
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_array(_gains(_since(before))).is_empty()
	assert_array(_of_type(_since(before), "effect_resolved")).is_empty()


func test_a_side_opponent_hook_runs_on_the_opposing_turn() -> void:
	# Arrange
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "turn_start", "scope": {"side": "opponent"}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_array(_gains(_since(before))).is_equal([HOOK_ARMOR])


func test_ac16_at_the_end_step_card_observers_run_before_the_hook() -> void:
	# Arrange
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "turn_end", "scope": {"side": "owner"}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 5, END_WATCHER)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert — C6.3's one exception
	assert_array(_gains(_since(before))).is_equal([CARD_ARMOR, HOOK_ARMOR])


# --- AC-36: on_match_start --------------------------------------------------------

func test_ac36_row_38_gains_armor_before_the_first_card_is_drawn() -> void:
	# Act
	_start([_treasure(ROW_38)])

	# Assert
	var armor: int = _index_of(_log.events, "armor_gained")
	assert_int(armor).is_greater_equal(0)
	assert_int(armor).is_less(_index_of(_log.events, "card_drawn"))
	assert_array(_gains(_log.events)).is_equal([ROW_38_ARMOR])
	assert_str(str(_log.events[armor].payload.source_id)).is_equal(ROW_38)


func test_ac36_treasures_run_in_pick_order_and_the_passive_after_them_each_once() -> void:
	# Arrange
	var first: HookInstaller = _host("treasure_test_first", &"player", [{"trigger": "on_match_start", "targets": "owner", "ops": [_armor(1)]}])
	var second: HookInstaller = _host("treasure_test_second", &"player", [{"trigger": "on_match_start", "targets": "owner", "ops": [_armor(2)]}])
	var passive: HookInstaller = _host(TEST_PASSIVE, &"boss", [{"trigger": "on_match_start", "targets": "owner", "ops": [_armor(3)]}])

	# Act — the engine asks once per side; each entry still runs once
	_start([passive, first, second])

	# Assert
	assert_array(_gains(_log.events)).is_equal([1, 2, 3])
	var sides: Array = _of_type(_log.events, "armor_gained").map(func(e: Dictionary) -> String: return str(e.payload.side))
	assert_array(sides).is_equal([SIDE_PLAYER, SIDE_PLAYER, SIDE_BOSS])


func test_ac36_a_duplicate_host_id_installs_nothing_and_is_logged() -> void:
	# Act — straight to the engine: `Treasures.installers_for` would drop it first
	_start([_treasure(ROW_38), _treasure(ROW_38)])

	# Assert
	assert_array(_gains(_log.events)).is_equal([ROW_38_ARMOR])
	var skipped: Array = _of_type(_log.events, "hook_install_skipped")
	assert_int(skipped.size()).is_equal(1)
	assert_str(str(skipped[0].payload.host_id)).is_equal(ROW_38)
	assert_str(str(skipped[0].payload.reason)).is_equal(RulesEngine.SKIP_REASON_DUPLICATE)


# --- AC-25: a boss passive as a hero-slot observer --------------------------------

func _row_37() -> HookInstaller:
	if _records.is_empty():
		@warning_ignore("return_value_discarded")
		_db()
	return Treasures.passive_installer(_records[ROW_37])[0]


func test_ac25_the_players_observer_resolves_before_the_boss_hero_slot_observer() -> void:
	# Arrange
	_main_phase([_row_37()], [MEND])
	var fed: int = _put(SIDE_PLAYER, 1, 5, HEAL_FED)
	_engine.state().players[SIDE_PLAYER].hero.damage_taken = WOUND
	var before: int = _last_seq()

	# Act
	_cast(0, _hero(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	var healed: int = _index_of(events, "healed")
	var buffed: int = _index_of(events, "enchantment_applied", healed)
	var hit: int = _index_of(events, "damage_dealt", buffed)
	assert_int(healed).is_greater_equal(0)
	assert_int(buffed).is_greater(healed)
	assert_int(hit).is_greater(buffed)
	assert_int(int(events[hit].payload.dealt)).is_equal(1)
	assert_str(str(events[hit].payload.source)).is_equal(ROW_37)
	assert_str(str(events[hit].payload.source_id)).is_equal(ROW_37)
	assert_array(_resolved(events)).is_equal([["on_heal", fed], ["on_heal", ROW_37]])


func test_a_hero_slot_entry_names_its_host_in_every_queue_event() -> void:
	# Arrange
	_main_phase([_row_37()], [MEND])
	_engine.state().players[SIDE_PLAYER].hero.damage_taken = WOUND
	var before: int = _last_seq()

	# Act
	_cast(0, _hero(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	var queued: Array = _of_type(events, "trigger_queued")
	assert_int(queued.size()).is_equal(1)
	assert_str(str(queued[0].payload.source_id)).is_equal(ROW_37)
	var pass_event: Dictionary = _of_type(events, "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.trigger) == "on_heal")[0]
	assert_str(str(pass_event.payload.host_kind)).is_equal(String(PASSIVE))
	assert_str(str(pass_event.payload.host_id)).is_equal(ROW_37)
	assert_int(int(pass_event.payload.depth)).is_equal(1)


func test_row_37_min_amount_does_not_fire_on_a_heal_restoring_zero() -> void:
	# Arrange — the player's hero is undamaged
	_main_phase([_row_37()], [MEND])
	var before: int = _last_seq()

	# Act
	_cast(0, _hero(SIDE_PLAYER))

	# Assert — `healed 0` is still emitted (match-rules C9)
	var events: Array = _since(before)
	assert_int(int(_of_type(events, "healed")[0].payload.amount)).is_equal(0)
	assert_array(_of_type(events, "trigger_queued")).is_empty()
	assert_array(_of_type(events, "damage_dealt")).is_empty()


func test_the_player_hero_slot_precedes_the_boss_board_in_candidate_order() -> void:
	# Arrange
	_main_phase([_grave_tithe()], [SWEEP_OWN])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 1)
	var watcher: int = _put(SIDE_BOSS, 1, 5, ANY_DEATH_WATCHER)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — C6.3: player board, weapon, hero slot, then the boss side
	assert_array(_resolved(_since(before))).is_equal([["on_minion_died", TEST_TREASURE], ["on_minion_died", watcher]])


# --- AC-45: Grave Tithe -----------------------------------------------------------

func test_ac45_two_deaths_summon_one_husk_after_row_11s_two_triggers() -> void:
	# Arrange
	_main_phase([_grave_tithe()], [SWEEP_OWN])
	var feeder: int = _put(SIDE_PLAYER, 1, 5, ROW_11)
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 1)
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 1)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	var events: Array = _since(before)
	assert_array(_resolved(events)).is_equal([["on_minion_died", feeder], ["on_minion_died", feeder], ["on_minion_died", TEST_TREASURE]])
	var summoned: Array = _of_type(events, "minion_summoned")
	assert_int(summoned.size()).is_equal(1)
	assert_str(str(summoned[0].payload.card_id)).is_equal(HUSK)
	assert_str(str(summoned[0].payload.source_id)).is_equal(TEST_TREASURE)


func test_ac45_the_mark_is_keyed_on_the_treasure_id() -> void:
	# Arrange
	_main_phase([_grave_tithe()], [SWEEP_OWN])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 1)

	# Act
	_cast()

	# Assert
	var key: String = EffectRuntime.once_key("%s.0" % TEST_TREASURE, TEST_TREASURE, int(_engine.state().turn))
	assert_bool(EffectRuntime.once_marked(_engine.state().effects, key)).is_true()


func test_a_full_board_fails_the_summon_and_still_spends_the_mark() -> void:
	# Arrange — six survivors and one 1-health minion: the Husk's slot is free
	# only after the death, so fill the board back before the observer resolves.
	_main_phase([_host(TEST_TREASURE, &"player", [{
		"trigger": "on_minion_died", "scope": {"who": "friendly_minion"}, "once_per_turn": true,
		"ops": [{"op": "summon", "card_id": HUSK, "count": 1, "position": "end"}, {"op": "summon", "card_id": HUSK, "count": 1, "position": "end"}],
	}])], [SWEEP_OWN])
	for i: int in TestConstants.BOARD_SIZE - 1:
		@warning_ignore("return_value_discarded")
		_put(SIDE_PLAYER, 1, 5)
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 1)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — one slot opened: the first Husk lands, the second fails, nothing crashes
	var events: Array = _since(before)
	assert_int(_of_type(events, "minion_summoned").size()).is_equal(1)
	var failed: Array = _of_type(events, "summon_failed")
	assert_int(failed.size()).is_equal(1)
	assert_str(str(failed[0].payload.reason)).is_equal(RulesEngine.SUMMON_FAILED_BOARD_FULL)
	var key: String = EffectRuntime.once_key("%s.0" % TEST_TREASURE, TEST_TREASURE, int(_engine.state().turn))
	assert_bool(EffectRuntime.once_marked(_engine.state().effects, key)).is_true()


func test_once_per_turn_counts_the_global_turn_so_each_side_allows_one() -> void:
	# Arrange
	_main_phase([_grave_tithe()], [SWEEP_OWN])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 1)
	_cast()
	assert_int(_of_type(_log.events, "minion_summoned").size()).is_equal(1)
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	_set_hand(SIDE_BOSS, [SWEEP_ENEMY])
	var before: int = _last_seq()

	# Act — the boss's turn kills the Husk
	_cast(0, null, SIDE_BOSS)

	# Assert — a new `match.turn`, so a new Husk
	assert_int(_of_type(_since(before), "minion_summoned").size()).is_equal(1)


func test_once_per_turn_on_a_hook_entry_runs_once_in_a_turn() -> void:
	# Arrange
	var once: HookInstaller = _host(TEST_TREASURE, &"player", [{"trigger": "on_draw", "scope": {"side": "owner"}, "once_per_turn": true, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])
	_main_phase([once], [DRAWER])
	(_engine.state().effects.once_marks as Dictionary).clear()   # the Start draw of turn 1 spent it
	var before: int = _last_seq()

	# Act — one spell, two draws
	_cast()

	# Assert
	assert_int(_of_type(_since(before), "card_drawn").size()).is_equal(2)
	assert_array(_gains(_since(before))).is_equal([HOOK_ARMOR])


# --- The C6.3 rows the ACs skip ---------------------------------------------------

func test_the_on_card_played_hook_runs_before_its_observers() -> void:
	# Arrange
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "on_card_played", "scope": {"by": "owner"}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])], [FREE_MINION])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 5, PLAYED_WATCHER)
	var before: int = _last_seq()

	# Act
	_play()

	# Assert
	assert_array(_gains(_since(before))).is_equal([HOOK_ARMOR, CARD_ARMOR])


func test_the_on_card_played_hook_reads_its_card_filter_on_the_played_card() -> void:
	# Arrange — a spell-only hook; a minion is played
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "on_card_played", "scope": {"by": "owner", "card": {"type": "spell"}}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])], [FREE_MINION, SUMMONER])
	var before: int = _last_seq()

	# Act
	_play(0)
	var after_minion: Array = _gains(_since(before))
	_cast(0)

	# Assert
	assert_array(after_minion).is_empty()
	assert_array(_gains(_since(before))).is_equal([HOOK_ARMOR])


func test_the_summon_hook_runs_before_on_summon_observers_for_a_played_minion() -> void:
	# Arrange
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "on_summon", "scope": {"of": "friendly_minion"}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])], [FREE_MINION])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 5, SUMMON_WATCHER)
	var before: int = _last_seq()

	# Act
	_play()

	# Assert
	assert_array(_gains(_since(before))).is_equal([HOOK_ARMOR, CARD_ARMOR])


func test_the_summon_hook_runs_before_on_summon_observers_for_an_effect_summon() -> void:
	# Arrange
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "on_summon", "scope": {"of": "friendly_minion"}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])], [SUMMONER])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 5, SUMMON_WATCHER)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	assert_array(_gains(_since(before))).is_equal([HOOK_ARMOR, CARD_ARMOR])


## Thornhide Cloak's shape.
func _cloak() -> HookInstaller:
	return _host(TEST_TREASURE, &"player", [{"trigger": "on_damage_taken", "scope": {"who": "owner_hero"}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])


func test_the_hero_damaged_hook_runs_synchronously_inside_the_hit() -> void:
	# Arrange
	_main_phase([_cloak()])
	var before: int = _last_seq()

	# Act — the bare primitive: no C10 loop runs, so a queued pass could not have
	@warning_ignore("return_value_discarded")
	_engine.apply_damage(_hero(SIDE_PLAYER), 3, null)

	# Assert
	var events: Array = _since(before)
	assert_int(_index_of(events, "armor_gained")).is_greater(_index_of(events, "damage_dealt"))
	assert_array(_gains(events)).is_equal([HOOK_ARMOR])
	assert_array(_of_type(events, "trigger_queued")).is_empty()


func test_the_hero_damaged_hook_ignores_the_other_hero() -> void:
	# Arrange
	_main_phase([_cloak()])
	var before: int = _last_seq()

	# Act
	@warning_ignore("return_value_discarded")
	_engine.apply_damage(_hero(SIDE_BOSS), 3, null)

	# Assert
	assert_array(_gains(_since(before))).is_empty()


func test_the_hero_damaged_hook_reads_min_amount_and_the_amount_dealt() -> void:
	# Arrange
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "on_damage_taken", "scope": {"who": "owner_hero", "min_amount": 2}, "targets": "owner", "ops": [_armor({"ref": "context.amount"})]}])])
	var before: int = _last_seq()

	# Act
	@warning_ignore("return_value_discarded")
	_engine.apply_damage(_hero(SIDE_PLAYER), 1, null)
	@warning_ignore("return_value_discarded")
	_engine.apply_damage(_hero(SIDE_PLAYER), 3, null)

	# Assert
	assert_array(_gains(_since(before))).is_equal([3])


func test_the_draw_hook_runs_before_on_draw_observers() -> void:
	# Arrange
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "on_draw", "scope": {"side": "owner"}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])], [DRAWER])
	_engine.state().players[SIDE_PLAYER].deck.resize(1)
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 5, DRAW_WATCHER)
	var before: int = _last_seq()

	# Act — one card left: one draw, then fatigue
	_cast()

	# Assert
	assert_array(_gains(_since(before))).is_equal([HOOK_ARMOR, CARD_ARMOR])


func test_the_draw_hook_never_runs_on_a_burn() -> void:
	# Arrange — the spell leaves the hand one short of full, the first draw fills it
	var hand: Array = [DRAWER]
	for i: int in HAND_SIZE - 1:
		hand.append(VANILLA)
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "on_draw", "scope": {"side": "owner"}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])], hand)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	assert_int(_of_type(_since(before), "card_drawn").size()).is_equal(1)
	assert_int(_of_type(_since(before), "card_burned").size()).is_equal(1)
	assert_array(_gains(_since(before))).is_equal([HOOK_ARMOR])


func test_row_41_makes_the_drawn_card_cheaper_through_trigger_subject() -> void:
	# Arrange
	_main_phase([_treasure(ROW_41)], [DRAWER])
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	var drawn: Array = _of_type(_since(before), "card_drawn")
	assert_int(drawn.size()).is_equal(2)
	for card: Dictionary in _engine.state().players[SIDE_PLAYER].hand:
		assert_int((card.cost_modifiers as Array).size()).is_equal(1)


func test_a_hook_inside_a_queued_pass_keeps_the_outer_pass_depth() -> void:
	# Arrange — a queued `on_heal` pass summons, which runs the summon hook inline
	_main_phase([_host(TEST_TREASURE, &"player", [{"trigger": "on_summon", "scope": {"of": "friendly_minion"}, "targets": "owner", "ops": [_armor(HOOK_ARMOR)]}])], [MEND])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 5, DEPTH_WATCHER)
	_engine.state().players[SIDE_PLAYER].hero.damage_taken = WOUND
	var before: int = _last_seq()

	# Act
	_cast(0, _hero(SIDE_PLAYER))

	# Assert — the hook is one deeper; the pass it ran inside keeps its own depth
	var passes: Dictionary = {}
	for event: Dictionary in _of_type(_since(before), "effect_resolved"):
		passes[str(event.payload.trigger)] = int(event.payload.depth)
	assert_int(int(passes.on_heal)).is_equal(1)
	assert_int(int(passes.on_summon)).is_equal(2)


# --- Discover from a hook (C6.0; match-rules C3 step 4) ---------------------------

## A Choose One then a later op, on [param trigger].
func _choosing(trigger: String, scope: Dictionary) -> HookInstaller:
	return _host(TEST_TREASURE, &"player", [{"trigger": trigger, "scope": scope, "targets": "owner", "ops": [
		{"op": "choose_one", "options": [
			{"label_key": "opt.small", "ops": [_armor(HOOK_ARMOR)]},
			{"label_key": "opt.large", "ops": [_armor(CARD_ARMOR)]},
		]},
		_armor(LATER_ARMOR),
	]}])


func test_a_turn_start_hook_pauses_into_choice_and_resumes_the_start_step() -> void:
	# Arrange
	_start([_choosing("turn_start", {"side": "owner"})])
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	_submit(MatchRecords.choose(SIDE_PLAYER, 0))   # the first Start step pauses as well
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert — paused, before the draw
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_array(_of_type(_since(before), "card_drawn")).is_empty()

	# Act
	_submit(MatchRecords.choose(SIDE_PLAYER, 1))

	# Assert — the pick, the later op, then the rest of the Start step
	assert_array(_gains(_since(before))).is_equal([CARD_ARMOR, LATER_ARMOR])
	assert_int(_of_type(_since(before), "card_drawn").size()).is_equal(1)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MAIN)
	var resolved: Array = _of_type(_since(before), "effect_resolved")
	assert_int(resolved.size()).is_equal(1)
	assert_str(str(resolved[0].payload.source_id)).is_equal(TEST_TREASURE)


func test_an_on_card_played_hook_pauses_into_choice() -> void:
	# Arrange
	_main_phase([_choosing("on_card_played", {"by": "owner"})], [FREE_MINION])

	# Act
	_play()

	# Assert
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	_submit(MatchRecords.choose(SIDE_PLAYER, 0))
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_array(_gains(_log.events)).is_equal([HOOK_ARMOR, LATER_ARMOR])


func test_a_discover_in_an_on_draw_hook_is_refused_and_stops_the_effect() -> void:
	# Arrange
	_main_phase([_choosing("on_draw", {"side": "owner"})], [DRAWER])
	_engine.state().players[SIDE_PLAYER].deck.resize(1)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert — no Choice, and the effect's later op does not run (C6.0)
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_array(_gains(_since(before))).is_empty()
	var hook_pass: Array = _of_type(_since(before), "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.trigger) == "on_draw")
	assert_int(hook_pass.size()).is_equal(1)
	assert_str(str(hook_pass[0].payload.ops[0].outcome)).is_equal(EffectOps.SKIPPED)
	assert_int((hook_pass[0].payload.ops as Array).size()).is_equal(1)


func test_a_discover_in_an_on_match_start_hook_is_refused_and_stops_the_effect() -> void:
	# Act
	_start([_choosing("on_match_start", {})])

	# Assert
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MULLIGAN)
	assert_array(_gains(_log.events)).is_empty()


# --- String host ids --------------------------------------------------------------

func test_a_host_id_with_digits_keeps_its_own_counter_bucket() -> void:
	# Arrange
	var counting: HookInstaller = _host(DIGIT_TREASURE, &"player", [{"trigger": "turn_start", "scope": {"side": "owner"}, "ops": [
		{"op": "add_counter", "key": "seen", "amount": 1},
		{"op": "armor", "targets": "owner", "amount": {"ref": "counter.seen"}},
	]}])
	_main_phase([counting])

	# Act
	var events: Array = _next_player_start()

	# Assert — the first Start step counted one already
	assert_int(EffectRuntime.counter(_engine.state().effects, DIGIT_TREASURE, "seen")).is_equal(2)
	assert_int(EffectRuntime.counter(_engine.state().effects, 42, "seen")).is_equal(0)
	assert_str(str(_of_type(events, "counter_changed")[0].payload.source_id)).is_equal(DIGIT_TREASURE)
	assert_array(_gains(events)).is_equal([2])


func test_a_host_id_with_digits_summons_at_the_end_not_beside_an_entity() -> void:
	# Arrange — the board's first minion takes entity id 42, which `int()` of the host reads
	var summoning: HookInstaller = _host(DIGIT_TREASURE, &"player", [{"trigger": "turn_start", "scope": {"side": "owner"}, "ops": [
		{"op": "summon", "card_id": HUSK, "count": 1, "position": "right_of_source"},
	]}])
	_main_phase([summoning])
	var first: Dictionary = MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 5, -1, [], VANILLA)
	first.entity_id = 42
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 5)

	# Act
	@warning_ignore("return_value_discarded")
	_next_player_start()

	# Assert — C5: a passive or treasure has no slot, so `end`
	var board: Array = _engine.state().players[SIDE_PLAYER].board
	assert_str(str(board.back().def_id)).is_equal(HUSK)


# --- clone(): the clone's hosts are its own (ADR-0007 Decision 3) -----------------

func test_a_clone_runs_its_hook_entries_and_its_hero_slot_observers() -> void:
	# Arrange
	_main_phase([_start_armor(), _grave_tithe_as("treasure_test_tithe")], [SWEEP_OWN])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 1)
	_sandbox = _engine.clone()
	var live_board: int = (_engine.state().players[SIDE_PLAYER].board as Array).size()
	var live_seq: int = _last_seq()

	# Act — the sandbox casts and turns over: the live match sees nothing
	assert_bool(_sandbox.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()
	assert_bool(_sandbox.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_bool(_sandbox.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()

	# Assert
	var husks: Array = (_sandbox.state().players[SIDE_PLAYER].board as Array).filter(func(m: Dictionary) -> bool: return str(m.def_id) == HUSK)
	assert_int(husks.size()).is_equal(1)
	assert_int(int(_sandbox.state().players[SIDE_PLAYER].hero.armor)).is_equal(2 * HOOK_ARMOR)
	assert_int((_engine.state().players[SIDE_PLAYER].board as Array).size()).is_equal(live_board)
	assert_int(int(_engine.state().players[SIDE_PLAYER].hero.armor)).is_equal(HOOK_ARMOR)
	assert_int(_last_seq()).is_equal(live_seq)


func _grave_tithe_as(id: String) -> HookInstaller:
	var source: HookInstaller = _grave_tithe()
	return HookInstaller.new(TREASURE, id, &"player", source.effects)


func test_aura_hosts_stay_isolated_between_a_clone_and_its_source() -> void:
	# Arrange — an aura host and a hero-slot host
	var aura: HookInstaller = _host("treasure_test_aura", &"player", [{"trigger": "aura", "targets": "all_friendly_minions", "ops": [{"op": "aura", "keywords": ["rush"]}]}])
	_main_phase([aura, _grave_tithe()])
	_sandbox = _engine.clone()
	var source_hosts: Array = _engine.state().effects.aura_hosts
	var clone_hosts: Array = _sandbox.state().effects.aura_hosts
	var before: Array = source_hosts.duplicate(true)
	assert_array(clone_hosts).is_equal(before)

	# Act — write through the clone, at every depth
	(clone_hosts[0].effects[0].ops[0].keywords as Array).append("taunt")
	(clone_hosts[0].effects as Array).clear()
	clone_hosts.pop_back()

	# Assert — the source is untouched
	assert_array(source_hosts).is_equal(before)

	# Act — and the other way
	var clone_after: Array = clone_hosts.duplicate(true)
	source_hosts[0].host_id = "treasure_test_moved"

	# Assert
	assert_array(clone_hosts).is_equal(clone_after)


# --- C3, C6.5: snapshots ----------------------------------------------------------

func test_trigger_subject_stats_read_the_dead_minions_snapshot() -> void:
	# Arrange — a 3-Attack minion dies; the observer reads its Attack afterwards
	_main_phase([], [SWEEP_OWN])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 1, 5, STATS_WATCHER)
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 3, 1)
	var before: int = _last_seq()

	# Act
	_cast()

	# Assert
	assert_array(_gains(_since(before))).is_equal([3])


func test_trigger_source_stats_read_the_raise_time_snapshot_of_a_departed_attacker() -> void:
	# Arrange — a 3/1 attacks the watcher and dies on the same hit
	_main_phase([])
	@warning_ignore("return_value_discarded")
	_put(SIDE_BOSS, 1, 5, SOURCE_WATCHER)
	var attacker: Dictionary = MatchFactory.summon(_engine.state(), SIDE_PLAYER, 3, 1, -1, [], VANILLA)
	attacker.summoning_sick = false
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.attack(SIDE_PLAYER, int(attacker.entity_id), int(_engine.state().players[SIDE_BOSS].board[0].entity_id)))

	# Assert
	assert_array(_gains(_since(before))).is_equal([3])


func test_a_self_transform_in_a_queued_pass_keeps_reading_its_snapshot() -> void:
	# Arrange — a 4/4 whose queued `turn_end` turns it into a 1/1, then reads `source.attack`
	_main_phase([])
	@warning_ignore("return_value_discarded")
	_put(SIDE_PLAYER, 4, 4, SNAPSHOT_SHEEP)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert — C6.5: the same `entity_id` is gone, so the snapshot, not the Sheep
	var events: Array = _since(before)
	assert_int(_of_type(events, "minion_transformed").size()).is_equal(1)
	assert_array(_gains(events)).is_equal([4])


func test_the_new_body_does_not_observe_its_own_entry() -> void:
	# Arrange
	_main_phase([], [INTO_LOUD_SHEEP])
	var before: int = _last_seq()

	# Act — it transforms into a body with an `on_play` observer
	_play()

	# Assert
	assert_str(str(_engine.state().players[SIDE_PLAYER].board[0].def_id)).is_equal(LOUD_SHEEP)
	assert_array(_gains(_since(before))).is_empty()


# --- Shipped data: every boss passive installs and fires --------------------------

const SHIPPED_DECK_CARD: String = "neutral_tunnel_rat"
const DECK_SIZE: int = 30
## Every shipped boss with a passive, each with a case below (content CN-3 B1).
const SHIPPED_BOSSES: Array[String] = [
	"boss_torchbearer", "boss_rat_king", "boss_gatekeeper", "boss_rot_warden", "boss_hollow_king",
	"boss_blood_abbess", "boss_iron_tollman", "boss_lich_archivist", "boss_bog_witch", "boss_frost_hag",
	"boss_shadow_of_the_delve", "boss_scrap_golem", "boss_pyre_sergeant", "boss_mirror_sage", "boss_dungeon_heart",
]
## CN-3: "a passive or a hero power". This one has the power and no passive.
const SHIPPED_BOSS_WITHOUT_PASSIVE: String = "boss_cellar_hermit"
## `boss_pyre_bomb`'s printed damage, and the shipped cards the cases below name.
const PYRE_BOMB: String = "boss_pyre_bomb"
const PYRE_BOMB_DAMAGE: int = 3
const SHIPPED_AXE: String = "war_rusted_axe"
const SHIPPED_BANDS: Array[int] = [1, 2, 3]


func _shipped_db() -> CardDatabase:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED))
	db.load(boot._collect_validators(null, true))
	return db


## A shipped-data match of boss [param boss_id], through the real
## `Treasures.passive_installer`, at the player's Main with empty boards.
func _shipped_main(db: CardDatabase, boss_id: String) -> void:
	_log = TestEventLog.new()
	var deck: Array = []
	deck.resize(DECK_SIZE)
	deck.fill(SHIPPED_DECK_CARD)
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log, {
		"player": {"deck": deck.duplicate()},
		"boss": {"deck": deck.duplicate(), "hook_installers": Treasures.passive_installer(db.boss(boss_id))},
	})
	_engine = RulesEngine.new(db, db.config("match_rules"), EffectResolver.new(db, db.config("card_effects"), "war"))
	_engine.start(config)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	for side: String in MatchRecords.SIDES:
		_engine.state().players[side].board.clear()


## The one passive `effect_resolved` in [param events].
func _passive_pass(events: Array, boss_id: String) -> Dictionary:
	var passes: Array = _of_type(events, "effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.source_id) == boss_id)
	assert_int(passes.size()).override_failure_message("%s: passes %s" % [boss_id, passes]).is_equal(1)
	if passes.is_empty():
		return {}
	assert_str(str(passes[0].payload.host_kind)).is_equal(String(PASSIVE))
	assert_str(str(passes[0].payload.host_id)).is_equal(boss_id)
	return passes[0]


func test_the_cases_below_cover_every_shipped_boss() -> void:
	# Arrange
	var db: CardDatabase = _shipped_db()
	var shipped: Array = []

	# Act
	for band: int in SHIPPED_BANDS:
		shipped.append_array(db.bosses_in_band(band).map(func(b: Dictionary) -> String: return str(b.id)))

	# Assert — a new boss fails here until it has a case
	assert_array(shipped).contains_exactly_in_any_order(SHIPPED_BOSSES + [SHIPPED_BOSS_WITHOUT_PASSIVE])


func test_every_shipped_passive_lands_in_the_registry_or_on_the_hero_slot() -> void:
	# Arrange
	var db: CardDatabase = _shipped_db()

	for boss_id: String in SHIPPED_BOSSES:
		# Act
		_shipped_main(db, boss_id)

		# Assert — never silently dropped (review X2)
		var hooked: int = _engine.state().hooks.entry_count()
		var hosted: int = (_engine.state().effects.aura_hosts as Array).size()
		assert_int(hooked + hosted).override_failure_message("%s installed nothing" % boss_id).is_equal(1)
		_engine.end_match()
		_engine = null


func test_shipped_cellar_hermit_has_a_hero_power_and_installs_no_passive() -> void:
	# Arrange
	var db: CardDatabase = _shipped_db()

	# Act
	_shipped_main(db, SHIPPED_BOSS_WITHOUT_PASSIVE)

	# Assert — CN-3: a boss with no passive carries a hero power instead
	assert_that(db.boss(SHIPPED_BOSS_WITHOUT_PASSIVE).passive).is_null()
	assert_bool(db.has(str(db.boss(SHIPPED_BOSS_WITHOUT_PASSIVE).hero_power))).is_true()
	assert_int(_engine.state().hooks.entry_count()).is_equal(0)
	assert_array(_engine.state().effects.aura_hosts as Array).is_empty()


func test_shipped_blood_abbess_heals_the_boss_at_the_start_of_its_turn() -> void:
	# Arrange
	var boss_id: String = "boss_blood_abbess"
	_shipped_main(_shipped_db(), boss_id)
	var hero: Dictionary = _engine.state().players[SIDE_BOSS].hero
	hero.damage_taken = WOUND * 2
	var health: int = _engine.health(hero)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_str(str(_passive_pass(_since(before), boss_id).payload.trigger)).is_equal("turn_start")
	assert_int(_engine.health(hero)).is_equal(health + 5)


func test_shipped_iron_tollman_raises_only_the_players_minions_by_one() -> void:
	# Arrange
	_shipped_main(_shipped_db(), "boss_iron_tollman")
	_set_hand(SIDE_PLAYER, [SHIPPED_DECK_CARD, MEND])
	_set_hand(SIDE_BOSS, [SHIPPED_DECK_CARD])

	# Act
	var state: MatchState = _engine.state()
	var printed: int = int(_engine._db.card(SHIPPED_DECK_CARD).cost)
	var player_minion: int = _engine.effective_cost(state.players[SIDE_PLAYER].hand[0], SIDE_PLAYER)
	var boss_minion: int = _engine.effective_cost(state.players[SIDE_BOSS].hand[0], SIDE_BOSS)

	# Assert
	assert_int(player_minion).is_equal(printed + 1)
	assert_int(boss_minion).is_equal(printed)


func test_shipped_lich_archivist_adds_two_to_the_bosss_spell_damage() -> void:
	# Arrange
	_shipped_main(_shipped_db(), "boss_lich_archivist")
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	_set_hand(SIDE_BOSS, [PYRE_BOMB])
	var hero: Dictionary = _engine.state().players[SIDE_PLAYER].hero
	var health: int = _engine.health(hero)

	# Act
	_cast(0, null, SIDE_BOSS)

	# Assert
	assert_int(_engine.health(hero)).is_equal(health - PYRE_BOMB_DAMAGE - 2)


func test_shipped_bog_witch_draws_when_a_boss_minion_dies() -> void:
	# Arrange
	var boss_id: String = "boss_bog_witch"
	_shipped_main(_shipped_db(), boss_id)
	var minion: Dictionary = MatchFactory.summon(_engine.state(), SIDE_BOSS, 1, 1, -1, [], SHIPPED_DECK_CARD)
	var attacker: Dictionary = MatchFactory.summon(_engine.state(), SIDE_PLAYER, 3, 5, -1, [], SHIPPED_DECK_CARD)
	attacker.summoning_sick = false
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.attack(SIDE_PLAYER, int(attacker.entity_id), int(minion.entity_id)))

	# Assert
	var events: Array = _since(before)
	assert_str(str(_passive_pass(events, boss_id).payload.trigger)).is_equal("on_minion_died")
	var drawn: Array = _of_type(events, "card_drawn")
	assert_int(drawn.size()).is_equal(1)
	assert_str(str(drawn[0].payload.side)).is_equal(SIDE_BOSS)


func test_shipped_frost_hag_freezes_a_player_minion_at_the_end_of_its_turn() -> void:
	# Arrange
	var boss_id: String = "boss_frost_hag"
	_shipped_main(_shipped_db(), boss_id)
	var minion: Dictionary = MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 5, -1, [], SHIPPED_DECK_CARD)
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	var events: Array = _since(before)
	assert_str(str(_passive_pass(events, boss_id).payload.trigger)).is_equal("turn_end")
	var frozen: Array = _of_type(events, "frozen")
	assert_int(frozen.size()).is_equal(1)
	assert_int(int(frozen[0].payload.entity_id)).is_equal(int(minion.entity_id))


func test_shipped_shadow_of_the_delve_gives_a_summoned_boss_minion_stealth() -> void:
	# Arrange
	_shipped_main(_shipped_db(), "boss_shadow_of_the_delve")
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	_set_hand(SIDE_BOSS, [SHIPPED_DECK_CARD])

	# Act
	_submit(MatchRecords.play_card(SIDE_BOSS, 0, 0, null))

	# Assert
	var board: Array = _engine.state().players[SIDE_BOSS].board
	assert_int(board.size()).is_equal(1)
	assert_bool(MatchFactory.has_keyword(board[0], "stealth")).is_true()


func test_shipped_scrap_golem_starts_the_match_with_five_armor() -> void:
	# Act
	var boss_id: String = "boss_scrap_golem"
	_shipped_main(_shipped_db(), boss_id)

	# Assert — the hook ran once, in the match's first steps
	assert_str(str(_passive_pass(_log.events, boss_id).payload.trigger)).is_equal("on_match_start")
	assert_int(int(_engine.state().players[SIDE_BOSS].hero.armor)).is_equal(5)


func test_shipped_pyre_sergeant_burns_the_player_when_the_boss_hero_attacks() -> void:
	# Arrange
	var boss_id: String = "boss_pyre_sergeant"
	_shipped_main(_shipped_db(), boss_id)
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	@warning_ignore("return_value_discarded")
	_engine.equip_weapon(SIDE_BOSS, SHIPPED_AXE)
	var hero: Dictionary = _engine.state().players[SIDE_PLAYER].hero
	var health: int = _engine.health(hero)
	var swing: int = _engine.attack(_engine.state().players[SIDE_BOSS].hero)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.attack(SIDE_BOSS, _hero(SIDE_BOSS), _hero(SIDE_PLAYER)))

	# Assert
	assert_str(str(_passive_pass(_since(before), boss_id).payload.trigger)).is_equal("on_attack")
	assert_int(_engine.health(hero)).is_equal(health - swing - 1)


func test_shipped_mirror_sage_copies_a_minion_the_player_plays_into_the_bosss_hand() -> void:
	# Arrange
	var boss_id: String = "boss_mirror_sage"
	_shipped_main(_shipped_db(), boss_id)
	_set_hand(SIDE_PLAYER, [SHIPPED_DECK_CARD])
	_set_hand(SIDE_BOSS, [])
	var before: int = _last_seq()

	# Act
	_play()

	# Assert
	assert_str(str(_passive_pass(_since(before), boss_id).payload.trigger)).is_equal("on_play")
	var hand: Array = _engine.state().players[SIDE_BOSS].hand
	assert_int(hand.size()).is_equal(1)
	assert_str(str(hand[0].def_id)).is_equal(SHIPPED_DECK_CARD)


func test_shipped_dungeon_heart_deals_two_to_every_player_minion_at_the_start_of_its_turn() -> void:
	# Arrange
	var boss_id: String = "boss_dungeon_heart"
	_shipped_main(_shipped_db(), boss_id)
	var first: Dictionary = MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 5, -1, [], SHIPPED_DECK_CARD)
	var second: Dictionary = MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 5, -1, [], SHIPPED_DECK_CARD)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_str(str(_passive_pass(_since(before), boss_id).payload.trigger)).is_equal("turn_start")
	assert_int(_engine.health(first)).is_equal(3)
	assert_int(_engine.health(second)).is_equal(3)


func test_shipped_torchbearer_burns_the_player_at_the_end_of_its_turn() -> void:
	# Arrange
	var boss_id: String = "boss_torchbearer"
	_shipped_main(_shipped_db(), boss_id)
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	var events: Array = _since(before)
	assert_str(str(_passive_pass(events, boss_id).payload.trigger)).is_equal("turn_end")
	var hit: Dictionary = _of_type(events, "damage_dealt")[0]
	assert_int(int(hit.payload.target)).is_equal(_hero(SIDE_PLAYER))
	assert_int(int(hit.payload.dealt)).is_equal(1)
	assert_str(str(hit.payload.source)).is_equal(boss_id)
	assert_str(str(hit.payload.source_id)).is_equal(boss_id)


func test_shipped_torchbearer_does_not_burn_at_the_end_of_the_players_turn() -> void:
	# Arrange
	_shipped_main(_shipped_db(), "boss_torchbearer")
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_array(_of_type(_since(before), "damage_dealt")).is_empty()


func test_shipped_rat_king_summons_a_rat_at_the_start_of_its_turn() -> void:
	# Arrange
	var boss_id: String = "boss_rat_king"
	_shipped_main(_shipped_db(), boss_id)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	assert_str(str(_passive_pass(events, boss_id).payload.trigger)).is_equal("turn_start")
	var summoned: Array = _of_type(events, "minion_summoned")
	assert_int(summoned.size()).is_equal(1)
	assert_str(str(summoned[0].payload.card_id)).is_equal("boss_rat")
	assert_str(str(summoned[0].payload.source_id)).is_equal(boss_id)
	assert_int((_engine.state().players[SIDE_BOSS].board as Array).size()).is_equal(1)


func test_shipped_hollow_king_buffs_its_minions_at_the_start_of_its_turn() -> void:
	# Arrange
	var boss_id: String = "boss_hollow_king"
	_shipped_main(_shipped_db(), boss_id)
	var minion: Dictionary = MatchFactory.summon(_engine.state(), SIDE_BOSS, 2, 2, -1, [], SHIPPED_DECK_CARD)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	var events: Array = _since(before)
	assert_str(str(_passive_pass(events, boss_id).payload.trigger)).is_equal("turn_start")
	assert_int(_engine.attack(minion)).is_equal(3)
	assert_int(_engine.health(minion)).is_equal(3)
	assert_str(str(_of_type(events, "enchantment_applied")[0].payload.source_id)).is_equal(boss_id)


func test_shipped_rot_warden_burns_the_player_when_a_boss_minion_dies() -> void:
	# Arrange
	var boss_id: String = "boss_rot_warden"
	_shipped_main(_shipped_db(), boss_id)
	var minion: Dictionary = MatchFactory.summon(_engine.state(), SIDE_BOSS, 1, 1, -1, [], SHIPPED_DECK_CARD)
	var attacker: Dictionary = MatchFactory.summon(_engine.state(), SIDE_PLAYER, 3, 5, -1, [], SHIPPED_DECK_CARD)
	attacker.summoning_sick = false
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.attack(SIDE_PLAYER, int(attacker.entity_id), int(minion.entity_id)))

	# Assert
	var events: Array = _since(before)
	assert_array(_resolved(events)).is_equal([["on_minion_died", boss_id]])
	assert_str(str(_passive_pass(events, boss_id).payload.trigger)).is_equal("on_minion_died")
	var burn: Array = _of_type(events, "damage_dealt").filter(func(e: Dictionary) -> bool: return str(e.payload.source) == boss_id)
	assert_int(burn.size()).is_equal(1)
	assert_int(int(burn[0].payload.target)).is_equal(_hero(SIDE_PLAYER))


func test_shipped_gatekeeper_gives_its_minions_taunt() -> void:
	# Arrange
	_shipped_main(_shipped_db(), "boss_gatekeeper")
	var minion: Dictionary = MatchFactory.summon(_engine.state(), SIDE_BOSS, 1, 1, -1, [], SHIPPED_DECK_CARD)

	# Act — any step's C10 loop recomputes the auras
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	var keywords: Array = []
	for enchantment: Dictionary in minion.enchantments:
		keywords.append_array(enchantment.keywords_added)
	assert_array(keywords).contains(["taunt"])
