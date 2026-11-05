## Unit tests for the MatchViewState projection (match-ui story 001;
## design/gdd/match-ui.md U3 rules 1-5 and the event → projection → step
## table, AC L1, L3, L4, L9; ADR-0009 Decision 2 `group_id`).
##
## L1 projects the committed full-match fixture
## (`tests/fixtures/match_ui/streams/full_match_torchbearer.json`, hand-built
## from C15 events — QA plan "Fixture provenance"); the other tests build small
## streams with [method _event]. Durations come from
## `MatchUiTestConfig.body()` (the `match_ui` fixture body), never literals.
extends GdUnitTestSuite

const SIDE_PLAYER: StringName = &"player"
const SIDE_BOSS: StringName = &"boss"
## A boss card id that appears in no other event of the small streams below.
const HIDDEN_CARD_ID: String = "boss_secret_plan"
## Ids for the small hand-built streams (boundary-free: any distinct ints).
const PLAYER_HERO_ID: int = 1
const BOSS_HERO_ID: int = 2
const BOSS_CARD_INSTANCE: int = 40
const MINION_IDS: Array[int] = [31, 32, 33, 34]


# --- helpers -----------------------------------------------------------------

## A rule 11 envelope `{seq, turn, type, payload, cause_seq}`.
func _event(seq: int, type: String, payload: Dictionary, cause_seq: int = 0, turn: int = 1) -> Dictionary:
	return {"seq": seq, "turn": turn, "type": type, "payload": payload, "cause_seq": cause_seq}


func _view(config: Dictionary = MatchUiTestConfig.body()) -> MatchViewState:
	return MatchViewState.new(config)


## Projects [param events] in order; returns every step produced.
func _project(view: MatchViewState, events: Array) -> Array[AnimStep]:
	var steps: Array[AnimStep] = []
	for event: Dictionary in events:
		steps.append_array(view.apply(event))
	return steps


func _signatures(steps: Array[AnimStep]) -> Array:
	var out: Array = []
	for step: AnimStep in steps:
		out.append(step.signature())
	return out


## A small opening: both decks, a player minion and a boss minion on the board.
func _opening() -> Array:
	return [
		_event(1, "deck_shuffled", {"side": "player", "instance_ids": [10, 11, 12]}),
		_event(2, "deck_shuffled", {"side": "boss", "instance_ids": [BOSS_CARD_INSTANCE, 41, 42]}),
		_event(3, "match_started", {"floor": 1, "hero_id": PLAYER_HERO_ID, "boss_id": BOSS_HERO_ID, "player_deck_size": 3, "boss_deck_size": 3}),
		_event(4, "minion_summoned", {"side": "player", "entity_id": MINION_IDS[0], "card_id": "neutral_test_vanilla_2_2", "position": 0, "attack": 2, "health": 2}),
		_event(5, "minion_summoned", {"side": "boss", "entity_id": MINION_IDS[1], "card_id": "boss_tinder_imp", "position": 0, "attack": 1, "health": 1}),
	]


## Every String value anywhere inside [param value] (recursive), for L3.
func _strings_in(value: Variant, out: Array[String]) -> Array[String]:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(String(value))
		TYPE_DICTIONARY:
			for key: Variant in value:
				_strings_in(key, out)
				_strings_in(value[key], out)
		TYPE_ARRAY:
			for item: Variant in value:
				_strings_in(item, out)
	return out


## The snapshot with `feed_lines` taken out, for "nothing else changed".
func _without_feed(snapshot: Dictionary) -> Dictionary:
	var copy: Dictionary = snapshot.duplicate(true)
	copy.erase("feed_lines")
	return copy


# --- L1: projection is pure ----------------------------------------------------

func test_full_match_projected_twice_gives_equal_states_and_step_lists() -> void:
	# Arrange
	var events: Array[Dictionary] = MatchUiTestConfig.full_match_events()
	assert_int(events.size()).is_greater(0)
	var first: MatchViewState = _view()
	var second: MatchViewState = _view()

	# Act
	var steps_a: Array[AnimStep] = _project(first, events)
	var steps_b: Array[AnimStep] = _project(second, events)

	# Assert
	assert_dict(first.snapshot()).is_equal(second.snapshot())
	assert_array(_signatures(steps_a)).is_equal(_signatures(steps_b))
	assert_int(steps_a.size()).is_greater(0)


func test_full_match_projection_reaches_the_final_match_state() -> void:
	# Arrange
	var events: Array[Dictionary] = MatchUiTestConfig.full_match_events()
	var view: MatchViewState = _view()

	# Act
	var steps: Array[AnimStep] = _project(view, events)

	# Assert: the fixture's last turn — numbers come from the events only
	var player: Dictionary = view.side(SIDE_PLAYER)
	var boss: Dictionary = view.side(SIDE_BOSS)
	assert_int(int(player.hero.health)).is_equal(25)
	assert_int(int(player.hero.armor)).is_equal(0)
	assert_int(int(player.hero.weapon.durability)).is_equal(1)
	assert_int(int(boss.hero.health)).is_equal(-1)
	assert_array(player.board.map(func(t: Dictionary) -> int: return int(t.entity_id))).is_equal([10])
	assert_array(boss.board.map(func(t: Dictionary) -> int: return int(t.entity_id))).is_equal([17, 19])
	assert_bool(boss.board[0].silenced).is_true()
	assert_array(boss.board[1].keywords).is_empty()
	assert_array(player.hand.map(func(c: Dictionary) -> int: return int(c.instance_id))).is_equal([6, 8, 21])
	assert_int(int(boss.hand)).is_equal(4)
	assert_int(int(player.deck_count)).is_equal(2)
	assert_int(int(boss.deck_count)).is_equal(0)
	assert_dict(player.mana).is_equal({"available": 2, "max": 5, "temporary": 0})
	assert_int(view.turn).is_equal(9)
	assert_str(str(view.result.result)).is_equal("win")
	assert_that(view.pending_choice).is_null()
	assert_dict(view.counters).is_equal({4: {"buffs_given": 1}})
	# every C15 type in the fixture is in the U3 table or the silent set
	var unknown: Array = view.feed_lines.filter(func(line: Dictionary) -> bool: return line.key == MatchViewState.FEED_UNKNOWN)
	assert_array(unknown).is_empty()
	assert_str(String(steps[-1].kind)).is_equal(String(AnimStep.END_BANNER))


# --- L3: hidden information ------------------------------------------------------

func test_boss_card_drawn_increments_the_hand_count_and_stores_no_card_id() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())
	var before: int = int(view.side(SIDE_BOSS).hand)

	# Act
	var steps: Array[AnimStep] = view.apply(_event(6, "card_drawn", {"side": "boss", "instance_id": BOSS_CARD_INSTANCE, "card_id": HIDDEN_CARD_ID, "hand_size": 1}))

	# Assert
	assert_int(int(view.side(SIDE_BOSS).hand)).is_equal(before + 1)
	assert_int(int(view.side(SIDE_BOSS).deck_count)).is_equal(2)
	assert_array(_strings_in(view.snapshot(), [])).not_contains([HIDDEN_CARD_ID])
	assert_array(_strings_in(_signatures(steps), [])).not_contains([HIDDEN_CARD_ID])
	assert_int(steps.size()).is_equal(1)
	assert_str(String(steps[0].kind)).is_equal(String(AnimStep.DRAW))


func test_boss_discover_offered_and_choice_requested_store_no_options() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())
	var options: Array = ["boss_secret_a", "boss_secret_b", "boss_secret_c"]

	# Act
	var steps: Array[AnimStep] = _project(view, [
		_event(6, "discover_offered", {"side": "boss", "source_id": MINION_IDS[1], "effect_id": "boss_x.0", "kind": "discover", "option_card_ids": options}),
		_event(7, "choice_requested", {"side": "boss", "kind": "discover", "options": options, "source_id": MINION_IDS[1], "effect_id": "boss_x.0"}),
	])

	# Assert
	assert_str(str(view.pending_choice.side)).is_equal("boss")
	assert_bool((view.pending_choice as Dictionary).has("options")).is_false()
	var stored: Array[String] = _strings_in(view.snapshot(), [])
	for option: String in options:
		assert_array(stored).not_contains([option])
	assert_array(steps).is_empty()


func test_player_discover_pair_opens_the_overlay_once_on_the_second_event_either_order() -> void:
	for order: Array in [["discover_offered", "choice_requested"], ["choice_requested", "discover_offered"]]:
		# Arrange
		var view: MatchViewState = _view()
		_project(view, _opening())
		var options: Array = ["war_whetstone_blade", "war_iron_resolve", "war_pit_brawler"]
		var payloads: Dictionary = {
			"discover_offered": {"side": "player", "source_id": MINION_IDS[0], "effect_id": "war_sharpen.0", "kind": "discover", "option_card_ids": options},
			"choice_requested": {"side": "player", "kind": "discover", "options": options, "source_id": MINION_IDS[0], "effect_id": "war_sharpen.0"},
		}

		# Act
		var first: Array[AnimStep] = view.apply(_event(6, order[0], payloads[order[0]]))
		var second: Array[AnimStep] = view.apply(_event(7, order[1], payloads[order[1]], 6))

		# Assert
		assert_array(first).is_empty()
		assert_int(second.size()).is_equal(1)
		assert_str(String(second[0].kind)).is_equal(String(AnimStep.OVERLAY_OPEN))
		assert_array(view.pending_choice.options).is_equal(options)


# --- L4: unknown types never fail -----------------------------------------------------

func test_unknown_event_type_adds_only_one_feed_unknown_line_and_no_step() -> void:
	for type: String in ["totally_new_event", "mana_changed", "weapon_broken"]:
		# Arrange: `mana_changed` / `weapon_broken` are deleted legacy aliases (U3)
		var view: MatchViewState = _view()
		_project(view, _opening())
		var before: Dictionary = view.snapshot()

		# Act
		var steps: Array[AnimStep] = view.apply(_event(6, type, {"side": "player", "value": 3}))

		# Assert
		assert_array(steps).is_empty()
		assert_dict(_without_feed(view.snapshot())).is_equal(_without_feed(before))
		assert_int(view.feed_lines.size()).is_equal(before.feed_lines.size() + 1)
		var line: Dictionary = view.feed_lines[-1]
		assert_str(line.key).is_equal(MatchViewState.FEED_UNKNOWN)
		assert_str(str(line.params.type)).is_equal(type)


func test_silent_types_change_nothing_and_add_no_line() -> void:
	for type: String in MatchUiTestConfig.body().silent_types:
		# Arrange
		var view: MatchViewState = _view()
		_project(view, _opening())
		var before: Dictionary = view.snapshot()

		# Act
		var steps: Array[AnimStep] = view.apply(_event(6, type, {"side": "player", "entity_ids": [PLAYER_HERO_ID]}))

		# Assert
		assert_array(steps).is_empty()
		assert_dict(view.snapshot()).is_equal(before)


func test_silent_set_is_read_from_config() -> void:
	# Arrange: a config whose silent set names an otherwise-unknown type
	var config: Dictionary = MatchUiTestConfig.body()
	config.silent_types = ["totally_new_event"]
	var view: MatchViewState = _view(config)
	_project(view, _opening())
	var before: Dictionary = view.snapshot()

	# Act
	var silent: Array[AnimStep] = view.apply(_event(6, "totally_new_event", {}))
	var now_unknown: Array[AnimStep] = view.apply(_event(7, "turn_reset", {"side": "player", "entity_ids": []}))

	# Assert
	assert_array(silent).is_empty()
	assert_array(now_unknown).is_empty()
	assert_int(view.feed_lines.size()).is_equal(before.feed_lines.size() + 1)
	assert_str(str(view.feed_lines[-1].params.type)).is_equal("turn_reset")


# --- rule 4a + L9: diagnostics ------------------------------------------------------

func test_player_command_rejected_changes_only_feed_lines_and_yields_one_reject_shake() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())
	var before: Dictionary = view.snapshot()
	var command: Dictionary = {"type": "attack", "issuer": "player", "attacker_id": MINION_IDS[0], "defender_id": BOSS_HERO_ID}

	# Act
	var steps: Array[AnimStep] = view.apply(_event(6, "command_rejected", {"side": "player", "command": command, "code": "MUST_ATTACK_TAUNT", "detail": "", "diagnostic": true}))

	# Assert
	assert_dict(_without_feed(view.snapshot())).is_equal(_without_feed(before))
	assert_int(steps.size()).is_equal(1)
	assert_str(String(steps[0].kind)).is_equal(String(AnimStep.REJECT_SHAKE))
	assert_str(str(steps[0].data.code)).is_equal("MUST_ATTACK_TAUNT")
	assert_float(steps[0].base_duration_s).is_equal(float(MatchUiTestConfig.body().d_base.reject_shake))
	assert_int(view.feed_lines.size()).is_equal(before.feed_lines.size() + 1)
	var line: Dictionary = view.feed_lines[-1]
	assert_str(line.key).is_equal("feed.command_rejected")
	assert_dict(line.params).is_equal({"command": command, "code": "MUST_ATTACK_TAUNT"})


func test_boss_command_rejected_yields_no_step_and_no_line() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())
	var before: Dictionary = view.snapshot()

	# Act
	var steps: Array[AnimStep] = view.apply(_event(6, "command_rejected", {"side": "boss", "command": {"type": "end_turn", "issuer": "boss"}, "code": "NOT_YOUR_TURN", "detail": "", "diagnostic": true}))

	# Assert
	assert_array(steps).is_empty()
	assert_dict(view.snapshot()).is_equal(before)


func test_ai_diagnostics_are_filtered_not_unknown() -> void:
	for type: String in ["ai_decision", "ai_plan_aborted", "ai_fault"]:
		# Arrange
		var view: MatchViewState = _view()
		_project(view, _opening())
		var before: Dictionary = view.snapshot()

		# Act
		var steps: Array[AnimStep] = view.apply(_event(6, type, {"diagnostic": true, "reason": "x"}))

		# Assert: no step, no line, no change — and never `feed.unknown`
		assert_array(steps).is_empty()
		assert_dict(view.snapshot()).is_equal(before)
		assert_array(view.debug_buffer).is_empty()


func test_debug_overlay_buffers_ai_decision_and_shows_diagnostic_lines() -> void:
	# Arrange
	var view: MatchViewState = _view()
	view.set_debug_overlay(true)
	_project(view, _opening())
	var before: Dictionary = view.snapshot()

	# Act
	var steps: Array[AnimStep] = _project(view, [
		_event(6, "ai_decision", {"diagnostic": true, "chosen": "end_turn"}),
		_event(7, "ai_fault", {"diagnostic": true, "reason": "timeout"}),
	])

	# Assert
	assert_array(steps).is_empty()
	assert_int(view.debug_buffer.size()).is_equal(1)
	assert_str(str(view.debug_buffer[0].type)).is_equal("ai_decision")
	var keys: Array = view.feed_lines.slice(before.feed_lines.size()).map(func(line: Dictionary) -> String: return line.key)
	assert_array(keys).is_equal(["feed.diag.ai_decision", "feed.diag.ai_fault"])


# --- U3 rule 3 groupings and ADR-0009 group_id ----------------------------------------------

func test_group_id_is_the_seq_of_the_command_root() -> void:
	# Arrange: 6 (cause 0) → 7 → 8 → 9; 10 is a new root
	var view: MatchViewState = _view()
	_project(view, _opening())

	# Act
	var steps: Array[AnimStep] = _project(view, [
		_event(6, "attack_declared", {"attacker_id": MINION_IDS[0], "defender_id": MINION_IDS[1]}),
		_event(7, "damage_dealt", {"source": MINION_IDS[0], "target": MINION_IDS[1], "requested": 2, "prevented": 0, "armor_absorbed": 0, "dealt": 2, "health_after": -1}, 6),
		_event(8, "minion_died", {"instance_id": MINION_IDS[1], "card_id": "boss_tinder_imp", "side": "boss", "board_index": 0}, 7),
		_event(9, "healed", {"source": PLAYER_HERO_ID, "target": PLAYER_HERO_ID, "requested": 1, "amount": 1}, 8),
		_event(10, "healed", {"source": PLAYER_HERO_ID, "target": PLAYER_HERO_ID, "requested": 1, "amount": 1}),
	])

	# Assert
	assert_array(steps.map(func(s: AnimStep) -> int: return s.group_id)).is_equal([6, 6, 6, 6, 6, 10])
	assert_array(steps.map(func(s: AnimStep) -> String: return String(s.kind))).is_equal(
		["attack_lunge", "damage_pop", "death_group", "gap_close", "heal_pop", "heal_pop"])


func test_minion_died_run_sharing_a_cause_projects_one_death_group_then_one_gap_close() -> void:
	# Arrange: summon four more player minions, then an AoE effect kills all four
	var view: MatchViewState = _view()
	_project(view, _opening())
	var summons: Array = []
	for i: int in MINION_IDS.size():
		summons.append(_event(6 + i, "minion_summoned", {"side": "boss", "entity_id": 50 + i, "card_id": "boss_tinder_imp", "position": i + 1, "attack": 1, "health": 1}))
	_project(view, summons)
	var deaths: Array = []
	for i: int in MINION_IDS.size():
		deaths.append(_event(11 + i, "minion_died", {"instance_id": 50 + i, "card_id": "boss_tinder_imp", "side": "boss", "board_index": 1}, 10))

	# Act
	var steps: Array[AnimStep] = _project(view, deaths)

	# Assert
	assert_array(steps.map(func(s: AnimStep) -> String: return String(s.kind))).is_equal(["death_group", "gap_close"])
	assert_array(steps[0].entity_ids).is_equal([50, 51, 52, 53])
	assert_array(view.side(SIDE_BOSS).board.map(func(t: Dictionary) -> int: return int(t.entity_id))).is_equal([MINION_IDS[1]])


func test_mana_events_and_an_empty_aura_event_produce_zero_steps() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())

	# Act
	var steps: Array[AnimStep] = _project(view, [
		_event(6, "crystal_gained", {"side": "player", "mana_max": 3, "gained": 1}),
		_event(7, "mana_refilled", {"side": "player", "mana_available": 3, "mana_max": 3}),
		_event(8, "mana_spent", {"side": "player", "amount": 2, "mana_available": 1}),
		_event(9, "mana_added", {"side": "player", "n": 1, "temporary": false}),
		_event(10, "auras_recomputed", {}),
	])

	# Assert
	assert_array(steps).is_empty()
	assert_dict(view.side(SIDE_PLAYER).mana).is_equal({"available": 1, "max": 3, "temporary": 0})


# --- DD-X26: `auras_recomputed` replaces fields, one parallel step per entry ------

func _aura_entry(id: int, attack: int, health: int, max_health: int, keywords: Array) -> Dictionary:
	return {"entity_id": id, "attack": attack, "health": health, "max_health": max_health, "keywords": keywords}


func test_an_aura_entry_replaces_a_tokens_fields_rather_than_adding_to_them() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())
	var entry: Dictionary = _aura_entry(MINION_IDS[0], 3, 2, 3, ["charge", "taunt"])

	# Act: the same absolute event twice lands on the same numbers
	_project(view, [_event(6, "auras_recomputed", {"changes": [entry]})])
	var first: Dictionary = view.entity(MINION_IDS[0])
	_project(view, [_event(7, "auras_recomputed", {"changes": [entry]})])
	var second: Dictionary = view.entity(MINION_IDS[0])

	# Assert
	assert_dict(second).is_equal(first)
	assert_int(int(second.attack)).is_equal(3)
	assert_int(int(second.health)).is_equal(2)
	assert_int(int(second.max_health)).is_equal(3)
	assert_array(second.keywords).is_equal(["charge", "taunt"])


func test_each_aura_entry_is_one_parallel_step_recolour_for_stats_badge_for_keywords() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())

	# Act: the player's token gains Attack; the boss's token only gains Taunt
	var steps: Array[AnimStep] = _project(view, [_event(6, "auras_recomputed", {"changes": [
		_aura_entry(MINION_IDS[0], 3, 2, 2, []),
		_aura_entry(MINION_IDS[1], 1, 1, 1, ["taunt"]),
	]})])

	# Assert
	assert_array(steps.map(func(s: AnimStep) -> Array: return [s.kind, s.entity_ids, s.parallel_ok])).is_equal([
		[AnimStep.STAT_RECOLOUR, [MINION_IDS[0]], true],
		[AnimStep.BADGE, [MINION_IDS[1]], true],
	])


func test_an_aura_entry_sets_a_heroes_health_and_a_weapons_attack_and_keywords() -> void:
	# Arrange
	var view: MatchViewState = _view()
	var weapon_id: int = 50
	_project(view, _opening())
	_project(view, [_event(6, "weapon_equipped", {"side": "player", "entity_id": weapon_id, "card_id": "war_test_axe", "attack": 3, "durability": 2})])

	# Act
	var steps: Array[AnimStep] = _project(view, [_event(7, "auras_recomputed", {"changes": [
		_aura_entry(PLAYER_HERO_ID, 4, 21, 30, []),
		_aura_entry(weapon_id, 4, 2, 2, ["poisonous"]),
	]})])

	# Assert: durability stays with `weapon_durability_changed`
	var hero: Dictionary = view.side(SIDE_PLAYER).hero
	assert_int(int(hero.health)).is_equal(21)
	assert_int(int(hero.weapon.attack)).is_equal(4)
	assert_int(int(hero.weapon.durability)).is_equal(2)
	assert_array(hero.weapon.keywords).is_equal(["poisonous"])
	assert_array(steps.map(func(s: AnimStep) -> Array: return s.entity_ids)).is_equal([[PLAYER_HERO_ID], [weapon_id]])


func test_a_hand_entry_stamps_the_players_card_with_its_effective_cost() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())
	_project(view, [_event(6, "card_drawn", {"side": "player", "instance_id": 10, "card_id": "neutral_test_vanilla_2_2", "hand_size": 1})])

	# Act
	var steps: Array[AnimStep] = _project(view, [_event(7, "auras_recomputed", {"changes": [
		{"instance_id": 10, "zone": "hand", "effective_cost": 2},
	]})])

	# Assert
	assert_array(view.side(SIDE_PLAYER).hand).is_equal([{"instance_id": 10, "card_id": "neutral_test_vanilla_2_2", "effective_cost": 2}])
	assert_array(steps.map(func(s: AnimStep) -> Array: return [s.kind, s.entity_ids, s.parallel_ok])).is_equal([
		[AnimStep.STAT_RECOLOUR, [10], true],
	])


func test_an_aura_entry_for_an_unknown_id_changes_nothing_and_yields_no_step() -> void:
	# Arrange: 41 is a boss card, hidden and never in the player's hand
	var view: MatchViewState = _view()
	_project(view, _opening())
	var before: Dictionary = view.side(SIDE_PLAYER)

	# Act
	var steps: Array[AnimStep] = _project(view, [_event(6, "auras_recomputed", {"changes": [
		_aura_entry(999, 1, 1, 1, []),
		{"instance_id": 41, "zone": "hand", "effective_cost": 1},
	]})])

	# Assert
	assert_array(steps).is_empty()
	assert_dict(view.side(SIDE_PLAYER)).is_equal(before)


## An `effect_resolved` payload in the shape `EffectResolver._run_pass` emits
## (card-effects Interactions): `fizzled` is `null` or the reason String.
func _effect_resolved(seq: int, source_id: int, fizzled: Variant) -> Dictionary:
	return _event(seq, "effect_resolved", {
		"effect_id": "neutral_test_vanilla_2_2.0", "host_id": "neutral_test_vanilla_2_2", "host_kind": "card",
		"source_id": source_id, "owner": "player", "trigger": "battlecry", "depth": 0,
		"fizzled": fizzled, "ops": [{"op": "damage", "targets": [], "values": {}, "outcome": "skipped"}],
	}, 4)


func test_effect_resolved_with_a_fizzle_reason_yields_one_fizzle_step_keeping_the_reason() -> void:
	# Arrange — code review 2026-11-03: the engine never sends `fizzled: true`
	var view: MatchViewState = _view()
	_project(view, _opening())

	# Act
	var steps: Array[AnimStep] = view.apply(_effect_resolved(6, MINION_IDS[0], EffectResolver.FIZZLED_CONDITION_FALSE))

	# Assert — one wisp on the source, the reason kept for display
	assert_int(steps.size()).is_equal(1)
	assert_str(String(steps[0].kind)).is_equal(String(AnimStep.FIZZLE))
	assert_array(steps[0].entity_ids).is_equal([MINION_IDS[0]])
	assert_dict(steps[0].data).is_equal({"reason": EffectResolver.FIZZLED_CONDITION_FALSE})


func test_effect_resolved_with_null_fizzled_yields_no_step() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())

	# Act
	var steps: Array[AnimStep] = view.apply(_effect_resolved(6, MINION_IDS[0], null))

	# Assert
	assert_array(steps).is_empty()


func test_step_durations_come_from_the_config_body() -> void:
	# Arrange: a config whose draw duration differs from the shipped body
	var config: Dictionary = MatchUiTestConfig.body()
	config.d_base.draw = float(config.d_base.draw) * 3.0
	var view: MatchViewState = _view(config)
	_project(view, _opening())

	# Act
	var steps: Array[AnimStep] = view.apply(_event(6, "card_drawn", {"side": "player", "instance_id": 10, "card_id": "neutral_test_vanilla_1_1", "hand_size": 1}))

	# Assert
	assert_float(steps[0].base_duration_s).is_equal(float(config.d_base.draw))


func test_side_returns_value_copies() -> void:
	# Arrange
	var view: MatchViewState = _view()
	_project(view, _opening())

	# Act
	var copy: Dictionary = view.side(SIDE_PLAYER)
	copy.board[0].attack = 99
	copy.hero.armor = 99

	# Assert
	assert_int(int(view.side(SIDE_PLAYER).board[0].attack)).is_equal(2)
	assert_int(int(view.side(SIDE_PLAYER).hero.armor)).is_equal(0)


# --- U3 `silenced`: stats, keywords, flags (code review 2026-11-04, MR-015 S1) ---

## A `silenced` envelope as match-rules C13 step 6 emits it: value copies of
## the removed (non-aura) enchantments and the keywords lost.
func _silenced(seq: int, id: int, removed: Array, keywords: Array) -> Dictionary:
	return _event(seq, "silenced", {"entity_id": id, "removed_enchantments": removed, "removed_keywords": keywords})


## An enchantment record in the MatchRecords shape (also the
## `enchantment_applied` payload, less `instance_id`).
func _buff(attack_delta: int, health_delta: int, keywords_added: Array = []) -> Dictionary:
	return {"source_entity_id": null, "attack_delta": attack_delta, "health_delta": health_delta,
		"keywords_added": keywords_added, "is_aura": false, "expires": null}


## The opening plus a boss minion [param id] of [param attack]/[param health].
func _with_boss_minion(id: int, attack: int, health: int, keywords: Array = []) -> Array:
	var events: Array = _opening()
	events.append(_event(6, "minion_summoned", {"side": "boss", "entity_id": id, "card_id": "boss_test_minion",
		"position": 1, "attack": attack, "health": health, "keywords": keywords}))
	return events


func test_a_silenced_buffed_taunt_shows_its_base_stats_and_no_taunt() -> void:
	# Arrange: a 2/2 Taunt buffed +2/+2 (shows 4/4)
	var view: MatchViewState = _view()
	var id: int = MINION_IDS[2]
	var buff: Dictionary = _buff(2, 2)
	var events: Array = _with_boss_minion(id, 2, 2, ["taunt"])
	events.append(_event(7, "enchantment_applied", {"instance_id": id}.merged(buff)))
	_project(view, events)
	assert_int(int(view.side(SIDE_BOSS).board[1].attack)).is_equal(4)

	# Act
	var steps: Array[AnimStep] = view.apply(_silenced(8, id, [buff], ["taunt"]))

	# Assert: the engine's post-Silence 2/2, no keywords, flagged silenced
	var token: Dictionary = view.side(SIDE_BOSS).board[1]
	assert_int(int(token.attack)).is_equal(2)
	assert_int(int(token.health)).is_equal(2)
	assert_int(int(token.max_health)).is_equal(2)
	assert_array(token.keywords).is_empty()
	assert_bool(token.silenced).is_true()
	assert_int(steps.size()).is_equal(1)


func test_a_silenced_damaged_frozen_minion_keeps_its_health_by_f6_and_thaws() -> void:
	# Arrange: the F6 worked example — a 2/2 Taunt with +2 health and a granted
	# Windfury, 3 damage (2/1), then frozen
	var view: MatchViewState = _view()
	var id: int = MINION_IDS[2]
	var buff: Dictionary = _buff(0, 2, ["windfury"])
	var events: Array = _with_boss_minion(id, 2, 2, ["taunt"])
	events.append(_event(7, "enchantment_applied", {"instance_id": id}.merged(buff)))
	events.append(_event(8, "damage_dealt", {"target": id, "dealt": 3, "health_after": 1, "source": null}))
	events.append(_event(9, "frozen", {"entity_id": id, "frozen_on_turn": 1}))
	_project(view, events)

	# Act
	view.apply(_silenced(10, id, [buff], ["taunt", "windfury"]))

	# Assert: max 2, damage max(0, 3 − (4 − 2)) = 1 → health 1; thawed, no keywords
	var token: Dictionary = view.side(SIDE_BOSS).board[1]
	assert_int(int(token.max_health)).is_equal(2)
	assert_int(int(token.health)).is_equal(1)
	assert_array(token.keywords).is_empty()
	assert_bool(token.frozen).is_false()


func test_silencing_a_debuffed_damaged_minion_restores_its_maximum_and_keeps_the_damage() -> void:
	# Arrange: a 2/5 with a −2 health debuff (max 3), then 1 damage (health 2)
	var view: MatchViewState = _view()
	var id: int = MINION_IDS[2]
	var debuff: Dictionary = _buff(0, -2)
	var events: Array = _with_boss_minion(id, 2, 5)
	events.append(_event(7, "enchantment_applied", {"instance_id": id}.merged(debuff)))
	events.append(_event(8, "damage_dealt", {"target": id, "dealt": 1, "health_after": 2, "source": null}))
	_project(view, events)

	# Act
	view.apply(_silenced(9, id, [debuff], []))

	# Assert: max back to 5 and the 1 damage kept (match-rules F6; MR-015 S2)
	var token: Dictionary = view.side(SIDE_BOSS).board[1]
	assert_int(int(token.max_health)).is_equal(5)
	assert_int(int(token.health)).is_equal(4)
