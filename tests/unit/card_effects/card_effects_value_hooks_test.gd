## card-effects story 014 — value triggers: `EffectResolver.apply_value_hook`
## folds for cost, damage, heal, starting hand and max attacks
## (design/gdd/card-effects.md C2 value class and scope keys, C5 `modify_value`,
## C9, Edge Cases "Hooks and passives"; AC-33, AC-34, AC-35; ADR-0005 Decisions
## 3–4: entry *n*'s output is entry *n + 1*'s input, the engine clamps once after
## the whole fold, `scope` reads relative to `entry.side`).
##
## The engine is the real `RulesEngine` with a `TestRngService` and a
## `TestEventLog`, bound to the real `EffectResolver`, over the committed C11
## fixture (`tests/fixtures/cards_effects_test.json`, rows 18, 36, 39, 40, 43, 44)
## and the inline hosts below. Installers go in through `MatchConfig`, so the
## registry, the resolver's `bind` and the engine's call sites all run for real.
extends GdUnitTestSuite

const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
## Row 18: "Deal 3 damage" (spell, `chosen`).
const ROW_18: String = "knowledge_fx_row_18_bolt"
## Row 36: boss passive "Your opponent's minions cost (1) more".
const ROW_36: String = "boss_fx_row_36_toll_keeper"
## Row 39: treasure "Your hero power costs (0)".
const ROW_39: String = "treasure_fx_row_39_free_power"
## Row 40: treasure "Your spells deal 1 more damage".
const ROW_40: String = "treasure_fx_row_40_spell_focus"
## Row 43: treasure "Your hero can attack twice each turn".
const ROW_43: String = "treasure_fx_row_43_twin_strikes"
## Row 44: hero power "Deal 1 damage".
const ROW_44: String = "power_fx_row_44_brand"
const ROW_18_DAMAGE: int = 3
const ROW_40_DELTA: int = 1
const ROW_44_DAMAGE: int = 1
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const TREASURE: StringName = HookInstaller.HOST_KIND_TREASURE
const PASSIVE: StringName = HookInstaller.HOST_KIND_PASSIVE

## Inline hosts (test-only defs; ids carry their set prefix).
const MINION_0: String = "neutral_test_zero_cost_minion"
const MINION_3: String = "neutral_test_three_cost_minion"
const SPELL_3: String = "neutral_test_three_cost_spell"
const VOLLEY: String = "neutral_test_volley"
const MEND: String = "neutral_test_mend"
const AXE: String = "neutral_test_axe"
## "Your cards cost (1) less": a hand aura on a minion, for DD-X26's entry.
const HAND_LORD: String = "neutral_test_hand_lord"
const COST_3: int = 3
const VOLLEY_DAMAGE: int = 1
const MEND_AMOUNT: int = 3
const AXE_ATTACK: int = 2
const AXE_DURABILITY: int = 5
## The damage the player's hero starts a heal test with.
const WOUND: int = 4
## Value-op magnitudes the fold cases use.
const CHEAPER: Dictionary = {"op": "modify_value", "delta": -1}
const DEARER: Dictionary = {"op": "modify_value", "delta": 1}
const DOUBLED: Dictionary = {"op": "modify_value", "mul": 2}
const SET_1: Dictionary = {"op": "modify_value", "set": 1}
const SET_3: Dictionary = {"op": "modify_value", "set": 3}


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


## The C11 fixture, the vanilla set and the inline hosts.
func _db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	var flat: JSON = load(FLAT)
	for record: Dictionary in flat.data:
		by_id[record.id] = record
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	by_id[MINION_0] = CardFactory.make_minion(MINION_0, 0, 1, 1)
	by_id[MINION_3] = CardFactory.make_minion(MINION_3, COST_3, 3, 3)
	by_id[SPELL_3] = CardFactory.make_spell(SPELL_3, COST_3)
	by_id[VOLLEY] = CardFactory.make_spell(VOLLEY, 1, [
		CardFactory.make_effect("cast", [CardFactory.make_op("damage", {"amount": VOLLEY_DAMAGE})], {"selector": "all_enemy_characters"}),
	])
	by_id[MEND] = CardFactory.make_spell(MEND, 1, [
		CardFactory.make_effect("cast", [CardFactory.make_op("heal", {"amount": MEND_AMOUNT})], {"selector": "chosen", "filter": {"kind": "any"}}),
	])
	by_id[AXE] = CardFactory.make_weapon(AXE, 1, AXE_ATTACK, AXE_DURABILITY)
	by_id[HAND_LORD] = CardFactory.make_minion(HAND_LORD, 1, 1, 1, ["aura"], {"effects": [
		{"trigger": "aura", "scope": {"zone": "hand"}, "ops": [{"op": "aura", "cost": -1}]},
	]})
	_records = by_id
	return FakeCardDatabase.new(by_id)


## A started engine bound to a real `EffectResolver` with [param installers]
## (player's first, as `MatchConfig` carries them), past a keep-all mulligan
## (player Main, turn 1), both boards and hands empty, 10 mana, the player's
## hero power row 44.
func _main_phase(installers: Array = []) -> RulesEngine:
	_start(installers)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	for side: String in MatchRecords.SIDES:
		_engine.state().players[side].hand.clear()
		_engine.state().players[side].board.clear()
	_engine.state().players[SIDE_PLAYER].mana_current = 10
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = ROW_44
	return _engine


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


## One installer with a single value effect.
func _hook(id: String, side: StringName, trigger: String, scope: Dictionary, op: Dictionary, condition: Variant = null) -> HookInstaller:
	var effect: Dictionary = {"trigger": trigger, "scope": scope, "ops": [op]}
	if condition != null:
		effect["condition"] = condition
	return HookInstaller.new(PASSIVE if side == &"boss" else TREASURE, id, side, [effect])


## The treasure record [param id]'s installer, as `Treasures.installers_for` builds it.
func _treasure(id: String) -> HookInstaller:
	if _records.is_empty():
		_db()
	return HookInstaller.new(TREASURE, id, &"player", _records[id].effects)


## Row 36's boss passive through the real `Treasures.passive_installer`.
func _row_36() -> HookInstaller:
	if _records.is_empty():
		_db()
	return Treasures.passive_installer(_records[ROW_36])[0]


## "Minions cost 1 less" (row-39 style, AC-33).
func _minions_cheaper() -> HookInstaller:
	return _hook("treasure_test_minions_cheaper", &"player", "modify_cost", {"card": {"side": "friendly", "type": "minion"}}, CHEAPER)


func _to_hand(side: String, def_id: String) -> Dictionary:
	var card: Dictionary = MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(_engine.state()), def_id, "hand")
	_engine.state().players[side].hand.append(card)
	return card


func _put(side: String, attack: int, health: int, def_id: String = "neutral_test_vanilla_3_4") -> int:
	return int(MatchFactory.summon(_engine.state(), side, attack, health, -1, [], def_id).entity_id)


func _hero(side: String) -> int:
	return int(_engine.state().players[side].hero.entity_id)


func _hero_record(side: String) -> Dictionary:
	return _engine.state().players[side].hero


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


func _events(from_seq: int, type: String) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq and str(e.type) == type)


## The `values` of the first op of the one `effect_resolved` after [param from_seq].
func _op_values(from_seq: int) -> Dictionary:
	var resolved: Array = _events(from_seq, "effect_resolved")
	assert_int(resolved.size()).is_equal(1)
	return resolved[0].payload.ops[0].values


## A hand card's `effective_cost` read the way the display and the payment do.
func _cost(card: Dictionary, side: String = SIDE_PLAYER) -> int:
	return _engine.effective_cost(card, side)


# --- AC-33: modify_cost ---------------------------------------------------------

func test_ac33_treasure_minus_one_then_passive_plus_one_reads_three() -> void:
	_main_phase([_minions_cheaper(), _row_36()])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3)


func test_ac33_each_hook_alone_moves_the_cost_by_its_own_delta() -> void:
	_main_phase([_minions_cheaper()])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3 - 1)
	_engine.end_match()
	_main_phase([_row_36()])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3 + 1)


## `0 − 1 + 1`: a clamp inside the fold would read `0 → 0 → 1`.
func test_ac33_zero_cost_minion_reads_zero_with_no_clamp_inside_the_fold() -> void:
	_main_phase([_minions_cheaper(), _row_36()])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_0))).is_equal(0)


func test_ac33_the_engine_clamps_once_after_the_fold_which_itself_reads_negative() -> void:
	var second: HookInstaller = _hook("treasure_test_second", &"player", "modify_cost", {"card": {"side": "friendly"}}, CHEAPER)
	_main_phase([_minions_cheaper(), second])
	var card: Dictionary = _to_hand(SIDE_PLAYER, "neutral_test_vanilla_1_1")
	assert_int(_engine.state().hooks.fold(&"modify_cost", &"player", 1, {"card": card, "kind": RulesEngine.COST_KIND_CARD})).is_equal(-1)
	assert_int(_cost(card)).is_equal(0)


func test_ac33_row_39_makes_the_hero_power_free_and_it_stays_once_per_turn() -> void:
	_main_phase([_treasure(ROW_39)])
	assert_int(_engine.hero_power_cost(SIDE_PLAYER)).is_equal(0)
	var mana: int = int(_engine.state().players[SIDE_PLAYER].mana_current)
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, _hero(SIDE_BOSS)))
	assert_int(int(_engine.state().players[SIDE_PLAYER].mana_current)).is_equal(mana)
	var again: Dictionary = _engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER, _hero(SIDE_BOSS)))
	assert_bool(again.accepted).is_false()
	assert_str(str(again.rejection.code)).is_equal(RulesEngine.R_HERO_POWER_USED)


func test_card_scope_without_kind_matches_card_instances_only() -> void:
	_main_phase([_hook("treasure_test_cards", &"player", "modify_cost", {"card": {"side": "friendly"}}, CHEAPER)])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3 - 1)
	assert_int(_engine.hero_power_cost(SIDE_PLAYER)).is_equal(_engine.rule("hero_power_cost"))


func test_card_scope_kind_hero_power_matches_the_hero_power_only() -> void:
	_main_phase([_treasure(ROW_39)])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3)


func test_card_scope_kind_any_matches_both() -> void:
	_main_phase([_hook("treasure_test_any", &"player", "modify_cost", {"card": {"side": "friendly", "kind": "any"}}, CHEAPER)])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3 - 1)
	assert_int(_engine.hero_power_cost(SIDE_PLAYER)).is_equal(_engine.rule("hero_power_cost") - 1)


## `scope` is relative to `entry.side`, never to the fold's side (ADR-0005 rule 3).
func test_scope_reads_relative_to_the_entry_side() -> void:
	_main_phase([_row_36(), _minions_cheaper()])
	assert_int(_cost(_to_hand(SIDE_BOSS, MINION_3), SIDE_BOSS)).is_equal(COST_3)
	_engine.end_match()
	_main_phase([_row_36()])
	assert_int(_cost(_to_hand(SIDE_BOSS, MINION_3), SIDE_BOSS)).is_equal(COST_3)
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3 + 1)


func test_card_filter_reads_the_definition_type() -> void:
	_main_phase([_row_36()])
	assert_int(_cost(_to_hand(SIDE_PLAYER, SPELL_3))).is_equal(COST_3)


func test_two_hooks_that_disagree_fold_in_installation_order_to_the_same_net() -> void:
	var cheaper: HookInstaller = _hook("treasure_test_a", &"player", "modify_cost", {"card": {"side": "friendly"}}, CHEAPER)
	var dearer: HookInstaller = _hook("treasure_test_b", &"player", "modify_cost", {"card": {"side": "friendly"}}, DEARER)
	_main_phase([cheaper, dearer])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3)
	_engine.end_match()
	_main_phase([dearer, cheaper])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3)


func test_mul_multiplies_in_its_place_in_the_fold() -> void:
	var cheaper: HookInstaller = _hook("treasure_test_a", &"player", "modify_cost", {"card": {"side": "friendly"}}, CHEAPER)
	var doubled: HookInstaller = _hook("treasure_test_b", &"player", "modify_cost", {"card": {"side": "friendly"}}, DOUBLED)
	_main_phase([cheaper, doubled])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal((COST_3 - 1) * 2)
	_engine.end_match()
	_main_phase([doubled, cheaper])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3 * 2 - 1)


## Treasures F3: the passive installs last, so its `set` wins.
func test_set_replaces_so_the_passive_set_after_a_treasure_set_reads_its_value() -> void:
	var treasure: HookInstaller = _hook("treasure_test_set", &"player", "modify_cost", {"card": {"side": "friendly"}}, SET_1)
	var passive: HookInstaller = _hook("boss_test_set", &"boss", "modify_cost", {"card": {"side": "enemy"}}, SET_3)
	_main_phase([treasure, passive])
	assert_int(_cost(_to_hand(SIDE_PLAYER, "neutral_test_vanilla_2_5"))).is_equal(3)


func test_a_delta_after_a_set_applies_on_top() -> void:
	var treasure: HookInstaller = _hook("treasure_test_set", &"player", "modify_cost", {"card": {"side": "friendly"}}, SET_1)
	var passive: HookInstaller = _hook("boss_test_tax", &"boss", "modify_cost", {"card": {"side": "enemy"}}, DEARER)
	_main_phase([treasure, passive])
	assert_int(_cost(_to_hand(SIDE_PLAYER, "neutral_test_vanilla_2_5"))).is_equal(2)


## A value expression sees `context.value`, the previous entry's output.
func test_a_value_expression_reads_context_value_from_the_previous_entry() -> void:
	var cheaper: HookInstaller = _hook("treasure_test_a", &"player", "modify_cost", {"card": {"side": "friendly"}}, CHEAPER)
	var doubled: HookInstaller = _hook("treasure_test_b", &"player", "modify_cost", {"card": {"side": "friendly"}},
		{"op": "modify_value", "delta": {"ref": "context.value"}})
	_main_phase([cheaper, doubled])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal((COST_3 - 1) * 2)


func test_the_folded_cost_is_what_is_paid() -> void:
	_main_phase([_minions_cheaper()])
	_to_hand(SIDE_PLAYER, MINION_3)
	var before: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	assert_int(int(_events(before, "mana_spent")[0].payload.amount)).is_equal(COST_3 - 1)


func test_a_clone_folds_through_its_own_resolver_to_the_same_cost() -> void:
	_main_phase([_minions_cheaper()])
	_to_hand(SIDE_PLAYER, MINION_3)
	var sandbox: RulesEngine = _engine.clone()
	var card: Dictionary = sandbox.state().players[SIDE_PLAYER].hand[0]
	assert_int(sandbox.effective_cost(card, SIDE_PLAYER)).is_equal(COST_3 - 1)
	sandbox.end_match()


## DD-X26: an entry reports `effective_cost`, F1 whole, so it holds the fold too.
func test_an_auras_recomputed_hand_entry_carries_the_folded_cost() -> void:
	_main_phase([_minions_cheaper()])
	var card: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)
	MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 1, -1, ["aura"], HAND_LORD)
	var before: int = _last_seq()
	_engine.run_action(func() -> void: pass)
	var changes: Array = _events(before, "auras_recomputed")[0].payload.changes
	var entry: Array = changes.filter(func(c: Dictionary) -> bool: return int(c.get("instance_id", -1)) == int(card.instance_id))
	assert_int(int(entry[0].effective_cost)).is_equal(COST_3 - 2)


# --- Conditions on a value trigger ----------------------------------------------

## Treasures R-2 (Vanguard's Banner): true for the first card, false after it.
func test_a_condition_is_re_evaluated_on_each_fold_call() -> void:
	var banner: HookInstaller = _hook("treasure_test_banner", &"player", "modify_cost", {"card": {"side": "friendly"}}, CHEAPER,
		{"cmp": [{"ref": "owner.cards_played_this_turn"}, "==", 0]})
	_main_phase([banner])
	_to_hand(SIDE_PLAYER, "neutral_test_vanilla_1_1")
	var later: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)
	assert_int(_cost(later)).is_equal(COST_3 - 1)
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	assert_int(_cost(later)).is_equal(COST_3)


func test_a_false_condition_leaves_the_value_unchanged_for_the_next_entry() -> void:
	var never: HookInstaller = _hook("treasure_test_never", &"player", "modify_cost", {"card": {"side": "friendly"}}, SET_1,
		{"cmp": [{"ref": "context.value"}, ">", 100]})
	var cheaper: HookInstaller = _hook("treasure_test_after", &"player", "modify_cost", {"card": {"side": "friendly"}}, CHEAPER)
	_main_phase([never, cheaper])
	assert_int(_cost(_to_hand(SIDE_PLAYER, MINION_3))).is_equal(COST_3 - 1)


## The `owner` of a condition is the entry's side, not the fold's.
func test_a_condition_reads_the_entry_sides_tallies() -> void:
	var passive: HookInstaller = _hook("boss_test_first", &"boss", "modify_cost", {"card": {"side": "enemy"}}, DEARER,
		{"cmp": [{"ref": "owner.cards_played_this_turn"}, "==", 0]})
	_main_phase([passive])
	_to_hand(SIDE_PLAYER, "neutral_test_vanilla_1_1")
	var later: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	assert_int(_cost(later)).is_equal(COST_3 + 1)


## The story's guard: an entry on the wrong trigger passes the value through.
func test_apply_value_hook_returns_the_value_for_a_non_value_trigger() -> void:
	_main_phase()
	var resolver: EffectResolver = _engine._resolver
	var entry: Dictionary = {"side": &"player", "host_id": "treasure_test", "effect": {"trigger": "turn_start", "ops": [SET_1]}}
	assert_int(resolver.apply_value_hook(entry, &"player", 7, {})).is_equal(7)


# --- AC-34: modify_damage -------------------------------------------------------

func test_ac34_row_40_row_18_deals_four_and_effect_resolved_carries_hook_delta() -> void:
	_main_phase([_treasure(ROW_40)])
	_to_hand(SIDE_PLAYER, ROW_18)
	var target: int = _hero(SIDE_BOSS)
	var before: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, target))
	var damage: Dictionary = _events(before, "damage_dealt")[0].payload
	assert_int(int(damage.dealt)).is_equal(ROW_18_DAMAGE + ROW_40_DELTA)
	assert_int(int(damage.requested)).is_equal(ROW_18_DAMAGE)
	var values: Dictionary = _op_values(before)
	assert_int(int(values.requested)).is_equal(ROW_18_DAMAGE)
	assert_array(values.hook_delta).is_equal([ROW_40_DELTA])
	assert_array(values.dealt).is_equal([ROW_18_DAMAGE + ROW_40_DELTA])


func test_ac34_row_44_hero_power_is_not_a_spell_and_deals_one() -> void:
	_main_phase([_treasure(ROW_40)])
	var before: int = _last_seq()
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, _hero(SIDE_BOSS)))
	assert_int(int(_events(before, "damage_dealt")[0].payload.dealt)).is_equal(ROW_44_DAMAGE)
	assert_bool(_op_values(before).has("hook_delta")).is_false()


## No hook changed anything, so the entry keeps its pre-hook shape.
func test_no_hook_delta_when_no_fold_changed_the_value() -> void:
	_main_phase()
	_to_hand(SIDE_PLAYER, ROW_18)
	var before: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, _hero(SIDE_BOSS)))
	var values: Dictionary = _op_values(before)
	assert_bool(values.has("hook_delta")).is_false()
	assert_bool(values.has("dealt")).is_false()


## Treasures AC-27's shape: one entry per target, parallel to `targets`.
func test_hook_delta_is_recorded_per_target_of_an_area_op() -> void:
	_main_phase([_treasure(ROW_40)])
	_put(SIDE_BOSS, 1, 5)
	_put(SIDE_BOSS, 1, 5)
	_to_hand(SIDE_PLAYER, VOLLEY)
	var before: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))
	var values: Dictionary = _op_values(before)
	assert_array(values.hook_delta).is_equal([ROW_40_DELTA, ROW_40_DELTA, ROW_40_DELTA])
	assert_array(values.dealt).is_equal([VOLLEY_DAMAGE + ROW_40_DELTA, VOLLEY_DAMAGE + ROW_40_DELTA, VOLLEY_DAMAGE + ROW_40_DELTA])


func test_a_target_filter_changes_only_the_targets_it_matches() -> void:
	_main_phase([_hook("treasure_test_face", &"player", "modify_damage", {"target": {"kind": "hero", "side": "enemy"}}, DEARER)])
	_put(SIDE_BOSS, 1, 5)
	_to_hand(SIDE_PLAYER, VOLLEY)
	var before: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))
	var values: Dictionary = _op_values(before)
	assert_array(values.hook_delta).is_equal([0, 1])
	assert_array(values.dealt).is_equal([VOLLEY_DAMAGE, VOLLEY_DAMAGE + 1])


func test_the_source_filter_side_is_relative_to_the_entry_side() -> void:
	_main_phase([_treasure(ROW_40)])
	var card: Dictionary = _to_hand(SIDE_BOSS, ROW_18)
	var before: int = _last_seq()
	@warning_ignore("return_value_discarded")
	_engine.apply_damage(_hero(SIDE_PLAYER), ROW_18_DAMAGE, int(card.instance_id))
	assert_int(int(_events(before, "damage_dealt")[0].payload.dealt)).is_equal(ROW_18_DAMAGE)


func test_a_minion_source_filter_matches_a_combat_hit() -> void:
	_main_phase([_hook("treasure_test_claws", &"player", "modify_damage", {"source": {"side": "friendly", "type": "minion"}}, DEARER)])
	var attacker: int = _put(SIDE_PLAYER, 2, 5)
	var defender: int = _put(SIDE_BOSS, 1, 9)
	_engine.state().players[SIDE_PLAYER].board[0].summoning_sick = false
	var before: int = _last_seq()
	_submit(MatchRecords.attack(SIDE_PLAYER, attacker, defender))
	var hits: Array = _events(before, "damage_dealt")
	assert_int(int(hits[0].payload.dealt)).is_equal(3)
	assert_int(int(hits[1].payload.dealt)).is_equal(1)


func test_a_negative_fold_floors_at_zero_at_the_engine_and_logs_the_raw_delta() -> void:
	_main_phase([_hook("treasure_test_ward", &"player", "modify_damage", {"source": {"side": "friendly", "type": "spell"}}, {"op": "modify_value", "delta": -5})])
	_to_hand(SIDE_PLAYER, ROW_18)
	var target: int = _hero(SIDE_BOSS)
	var health: int = _engine.health(_hero_record(SIDE_BOSS))
	var before: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, target))
	assert_int(int(_events(before, "damage_dealt")[0].payload.dealt)).is_equal(0)
	assert_int(_engine.health(_hero_record(SIDE_BOSS))).is_equal(health)
	assert_array(_op_values(before).hook_delta).is_equal([-5])


# --- Fatigue (match-rules F5, DD-X14): the source is null ------------------------

func test_a_source_filtered_modify_damage_never_matches_fatigue() -> void:
	_main_phase([_hook("treasure_test_any_source", &"player", "modify_damage", {"source": {"side": "any"}}, DEARER)])
	_engine.state().players[SIDE_PLAYER].deck.clear()
	var before: int = _last_seq()
	_engine.draw(SIDE_PLAYER, 1)
	assert_int(int(_events(before, "damage_dealt")[0].payload.dealt)).is_equal(1)


func test_a_target_filtered_modify_damage_matches_fatigue() -> void:
	_main_phase([_hook("treasure_test_frail", &"player", "modify_damage", {"target": {"kind": "hero", "side": "friendly"}}, DEARER)])
	_engine.state().players[SIDE_PLAYER].deck.clear()
	var before: int = _last_seq()
	_engine.draw(SIDE_PLAYER, 1)
	assert_int(int(_events(before, "damage_dealt")[0].payload.dealt)).is_equal(2)


# --- modify_heal -----------------------------------------------------------------

func test_a_negative_heal_fold_floors_at_zero_and_healed_zero_still_emits() -> void:
	_main_phase([_hook("boss_test_blight", &"boss", "modify_heal", {"target": {"side": "enemy"}}, {"op": "modify_value", "delta": -5})])
	_hero_record(SIDE_PLAYER).damage_taken = WOUND
	_to_hand(SIDE_PLAYER, MEND)
	var before: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, _hero(SIDE_PLAYER)))
	var healed: Array = _events(before, "healed")
	assert_int(healed.size()).is_equal(1)
	assert_int(int(healed[0].payload.amount)).is_equal(0)
	assert_int(int(_hero_record(SIDE_PLAYER).damage_taken)).is_equal(WOUND)
	var values: Dictionary = _op_values(before)
	assert_array(values.hook_delta).is_equal([-5])
	assert_array(values.restored).is_equal([0])


func test_a_heal_fold_raises_the_amount_restored() -> void:
	_main_phase([_hook("treasure_test_balm", &"player", "modify_heal", {"source": {"side": "friendly"}}, DEARER)])
	_hero_record(SIDE_PLAYER).damage_taken = WOUND + WOUND
	_to_hand(SIDE_PLAYER, MEND)
	var before: int = _last_seq()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, _hero(SIDE_PLAYER)))
	assert_int(int(_events(before, "healed")[0].payload.amount)).is_equal(MEND_AMOUNT + 1)


# --- AC-35: modify_max_attacks ---------------------------------------------------

func _equip_axe() -> void:
	@warning_ignore("return_value_discarded")
	_engine.equip_weapon(SIDE_PLAYER, AXE)


func test_ac35_row_43_hero_attacks_twice_and_the_third_is_cannot_attack() -> void:
	_main_phase([_treasure(ROW_43)])
	_equip_axe()
	var hero: int = _hero(SIDE_PLAYER)
	var boss: int = _hero(SIDE_BOSS)
	_submit(MatchRecords.attack(SIDE_PLAYER, hero, boss))
	_submit(MatchRecords.attack(SIDE_PLAYER, hero, boss))
	var third: Dictionary = _engine.submit(MatchRecords.attack(SIDE_PLAYER, hero, boss))
	assert_bool(third.accepted).is_false()
	assert_str(str(third.rejection.code)).is_equal(RulesEngine.R_CANNOT_ATTACK)


func test_who_owner_hero_matches_neither_a_minion_nor_the_enemy_hero() -> void:
	_main_phase([_treasure(ROW_43)])
	var minion: Dictionary = _engine.state().players[SIDE_PLAYER].board[_put_index(SIDE_PLAYER)]
	assert_int(_engine.max_attacks(minion)).is_equal(1)
	assert_int(_engine.max_attacks(_hero_record(SIDE_BOSS))).is_equal(1)
	assert_int(_engine.max_attacks(_hero_record(SIDE_PLAYER))).is_equal(2)


func test_who_friendly_minion_matches_a_friendly_minion_only() -> void:
	_main_phase([_hook("treasure_test_frenzy", &"player", "modify_max_attacks", {"who": "friendly_minion"}, {"op": "modify_value", "set": 2})])
	var friendly: Dictionary = _engine.state().players[SIDE_PLAYER].board[_put_index(SIDE_PLAYER)]
	var enemy: Dictionary = _engine.state().players[SIDE_BOSS].board[_put_index(SIDE_BOSS)]
	assert_int(_engine.max_attacks(friendly)).is_equal(2)
	assert_int(_engine.max_attacks(enemy)).is_equal(1)
	assert_int(_engine.max_attacks(_hero_record(SIDE_PLAYER))).is_equal(1)


func test_ac35_a_condition_on_max_attacks_reads_the_tally_at_each_evaluation() -> void:
	_main_phase([_hook("treasure_test_opener", &"player", "modify_max_attacks", {"who": "owner_hero"}, {"op": "modify_value", "set": 2},
		{"cmp": [{"ref": "owner.cards_played_this_turn"}, "==", 0]})])
	assert_int(_engine.max_attacks(_hero_record(SIDE_PLAYER))).is_equal(2)
	_to_hand(SIDE_PLAYER, "neutral_test_vanilla_1_1")
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	assert_int(_engine.max_attacks(_hero_record(SIDE_PLAYER))).is_equal(1)


func _put_index(side: String) -> int:
	@warning_ignore("return_value_discarded")
	_put(side, 1, 1)
	return (_engine.state().players[side].board as Array).size() - 1


# --- modify_starting_hand_size ---------------------------------------------------

func _hand_size(side: String) -> int:
	return (_engine.state().players[side].hand as Array).size()


func test_starting_hand_scope_side_owner_changes_the_owners_hand_only() -> void:
	_start([_hook("treasure_test_satchel", &"player", "modify_starting_hand_size", {"side": "owner"}, {"op": "modify_value", "delta": 2})])
	assert_int(_hand_size(SIDE_PLAYER)).is_equal(TestConstants.STARTING_HAND_PLAYER + 2)
	assert_int(_hand_size(SIDE_BOSS)).is_equal(TestConstants.STARTING_HAND_BOSS)


func test_starting_hand_scope_side_opponent_changes_the_other_hand() -> void:
	_start([_hook("boss_test_shrink", &"boss", "modify_starting_hand_size", {"side": "opponent"}, CHEAPER)])
	assert_int(_hand_size(SIDE_PLAYER)).is_equal(TestConstants.STARTING_HAND_PLAYER - 1)
	assert_int(_hand_size(SIDE_BOSS)).is_equal(TestConstants.STARTING_HAND_BOSS)
