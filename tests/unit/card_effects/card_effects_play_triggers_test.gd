## card-effects story 006 — play triggers, `chosen` targeting and the one-pass
## contract (design/gdd/card-effects.md C2 play class, C3 `chosen`, C5, C6.0,
## C6.4, C6.6, Interactions `effect_resolved` payload; AC-08, AC-09, AC-39;
## ADR-0007 Decisions 1, 5, 6).
##
## The engine is the real `RulesEngine` started from `MatchFactory`'s config
## with a `TestRngService` and `TestEventLog`, bound to the real
## `EffectResolver`. Its database is an in-memory `CardDatabase` subclass over
## the committed C11 fixture `tests/fixtures/cards_effects_test.json` (read as
## the imported JSON resource, never `FileAccess`), `CardFactory`'s vanilla
## set, and the few inline test hosts below.
##
## **AC-08 contract with match-rules C6 step 3a** (recorded in the story): a
## Battlecry whose `required` `chosen` has no legal target is never handed to
## the resolver — the engine's `_play_plan` marks it `fizzles` and does not
## raise `battlecry` at all — so nothing is emitted for it.
extends GdUnitTestSuite

const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
const ROW_10: String = "decay_fx_row_10_sacrifice"
const ROW_18: String = "knowledge_fx_row_18_bolt"
const ROW_44: String = "power_fx_row_44_brand"
const VANILLA: String = "neutral_test_vanilla"
## A friendly minion with a Deathrattle, so every play row's `chosen` has a
## target on the board (row 14 asks for `has_trigger: deathrattle`).
const FRIEND_DEF: String = "decay_fx_row_09_husk_summoner"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
## The engine trigger point each DSL play trigger binds to (C2).
const PLAY_TRIGGERS: Array[String] = ["battlecry", "cast", "hero_power"]
## The `effect_resolved` payload fields (card-effects Interactions;
## rng-event-log catalogue row).
const PAYLOAD_KEYS: Array[String] = ["effect_id", "host_id", "host_kind", "source_id", "owner", "trigger", "depth", "fizzled", "ops"]
const OP_KEYS: Array[String] = ["op", "targets", "values", "outcome"]
## The commands' own events (C6.6).
const COMMAND_EVENTS: Array[String] = ["card_played", "spell_cast", "hero_power_used"]

## Inline hosts (test-only defs; ids carry their set prefix, CR-2).
const NO_TARGET_THEN_ARMOR: String = "war_test_weaponless"
const CONDITION_FALSE: String = "war_test_not_my_turn"
const DESTROY_THEN_BUFF: String = "decay_test_reach_dying"
const SUMMON_PAIR: String = "decay_test_pair"
const KEYWORD_TWICE: String = "neutral_test_taunt_twice"


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

	## F4 `base(collectible)` (story 010): empty here, so row 20's Discover
	## is `empty_pool` and raises no Choice.
	func collectible_pool(_hero_set: String) -> Array:
		return []


## The hero set the resolver is built with (story 010: F4's collectible pool).
const HERO_SET: String = "knowledge"

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


func _flat() -> Array:
	var resource: JSON = load(FLAT)
	return resource.data


func _fx(json_text: String) -> Array:
	var parsed: Variant = JSON.parse_string(json_text)
	assert_bool(parsed != null).override_failure_message("fixture JSON does not parse: %s" % json_text).is_true()
	return parsed if parsed is Array else [parsed]


## The C11 fixture, the vanilla set and the inline hosts.
func _db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	for record: Dictionary in _flat():
		by_id[record.id] = record
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	by_id[VANILLA] = CardFactory.make_minion(VANILLA, 1, 1, 1)
	by_id[NO_TARGET_THEN_ARMOR] = CardFactory.make_minion(NO_TARGET_THEN_ARMOR, 1, 1, 1, ["battlecry"], {"set": "war", "effects": _fx(
		'{"trigger":"battlecry","ops":[{"op":"buff","targets":"owner_weapon","attack":1},{"op":"armor","targets":"owner","amount":2}]}')})
	by_id[CONDITION_FALSE] = CardFactory.make_minion(CONDITION_FALSE, 1, 1, 1, ["battlecry"], {"set": "war", "effects": _fx(
		'{"trigger":"battlecry","condition":{"not":{"is_owner_turn":true}},"ops":[{"op":"armor","targets":"owner","amount":2},{"op":"draw","count":1}]}')})
	by_id[DESTROY_THEN_BUFF] = CardFactory.make_minion(DESTROY_THEN_BUFF, 1, 1, 1, ["battlecry"], {"set": "decay", "effects": _fx(
		'{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"destroy"},{"op":"buff","attack":1,"health":1}]}')})
	by_id[SUMMON_PAIR] = CardFactory.make_minion(SUMMON_PAIR, 1, 1, 1, ["battlecry"], {"set": "decay", "effects": _fx(
		'{"trigger":"battlecry","ops":[{"op":"summon","card_id":"decay_husk","count":2}]}')})
	by_id[KEYWORD_TWICE] = CardFactory.make_minion(KEYWORD_TWICE, 1, 1, 1, ["battlecry"], {"effects": _fx(
		'{"trigger":"battlecry","targets":"self","ops":[{"op":"give_keyword","keyword":"taunt"},{"op":"give_keyword","keyword":"taunt"}]}')})
	return FakeCardDatabase.new(by_id)


## A started engine bound to a real `EffectResolver`, past a keep-all
## mulligan (player Main, turn 1), the hand replaced by [param hand], 10 mana.
func _main_phase(hand: Array) -> RulesEngine:
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log)
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config(), HERO_SET))
	_engine.start(config)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = _engine.state()
	var cards: Array = state.players[SIDE_PLAYER].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[SIDE_PLAYER].mana_current = 10
	return _engine


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


## The `effect_resolved.ops` entries one op yields (story 007: a
## `conditional` logs one entry per op of both branches — the branch not
## taken `skipped` — and a literal `repeat` its inner ops × `times`).
func _entry_count(op: Dictionary) -> int:
	match str(op.get("op", "")):
		"conditional":
			var n: int = 0
			for inner: Dictionary in op.get("then", []) + op.get("else", []):
				n += _entry_count(inner)
			return n
		"repeat":
			var per: int = 0
			for inner: Dictionary in op.get("ops", []):
				per += _entry_count(inner)
			return per * int(op.get("times", 1))
		"choose_one":
			# story 010: its own entry, then option 0's ops inline (the loop picks 0)
			var picked: int = 1
			for inner: Dictionary in (op.get("options", [{}])[0] as Dictionary).get("ops", []):
				picked += _entry_count(inner)
			return picked
	return 1


func _one_resolved(events: Array) -> Dictionary:
	var resolved: Array = _of_type(events, "effect_resolved")
	assert_int(resolved.size()).override_failure_message(str(_types(events))).is_equal(1)
	return resolved[0] if not resolved.is_empty() else {"payload": {}, "cause_seq": -1}


# --- AC-08: a Battlecry with no legal target never starts ---------------------------

func test_row_10_with_no_friendly_minion_pays_mana_places_the_body_and_emits_no_effect() -> void:
	# Arrange — only an enemy minion on the board.
	_main_phase([ROW_10])
	MatchFactory.summon(_engine.state(), SIDE_BOSS, 2, 2)
	var cost: int = int(_db().card(ROW_10).cost)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert
	var events: Array = _since(before)
	EventLogAssertions.assert_payload(events, &"mana_spent", {"amount": cost, "mana_current": 10 - cost})
	assert_array(_types(events)).contains(["card_played", "minion_summoned"])
	var board: Array = _engine.state().players[SIDE_PLAYER].board
	assert_int(board.size()).is_equal(1)
	assert_str(str(board[0].def_id)).is_equal(ROW_10)
	assert_array(_of_type(events, "effect_resolved")).is_empty()
	assert_array(_of_type(events, "card_drawn")).is_empty()


# --- AC-09: one pass, then the death check ---------------------------------------

func test_row_10_on_a_friendly_minion_draws_twice_while_it_is_dying_then_it_dies() -> void:
	# Arrange
	_main_phase([ROW_10])
	var friend: int = int(MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 1, friend))

	# Assert — card_played, minion_summoned, card_drawn ×2, effect_resolved,
	# then minion_died (the death check runs after the pass).
	var events: Array = _since(before)
	var watched: Array = _types(events).filter(func(t: String) -> bool:
		return ["card_played", "minion_summoned", "card_drawn", "effect_resolved", "minion_died"].has(t))
	assert_array(watched).is_equal(["card_played", "minion_summoned", "card_drawn", "card_drawn", "effect_resolved", "minion_died"])
	var died: Dictionary = _of_type(events, "minion_died")[0]
	assert_int(int(died.payload.entity_id)).is_equal(friend)
	var resolved: Dictionary = _one_resolved(events)
	assert_array(resolved.payload.ops).is_equal([
		{"op": "destroy", "targets": [friend], "values": {}, "outcome": "applied"},
		{"op": "draw", "targets": [], "values": {"count": 2, "side": SIDE_PLAYER}, "outcome": "applied"},
	])


func test_an_op_after_destroy_still_reaches_the_dying_chosen_minion() -> void:
	# Arrange — destroy, then buff the same `chosen` (C3: a reference, not a search).
	_main_phase([DESTROY_THEN_BUFF])
	var friend: int = int(MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 1, friend))

	# Assert — the buff lands on the dying minion before the death check removes it
	var events: Array = _since(before)
	var ops: Array = _one_resolved(events).payload.ops
	assert_str(str(ops[1].outcome)).is_equal("applied")
	assert_array(ops[1].targets).is_equal([friend])
	assert_array(_types(events)).contains(["enchantment_applied"])
	var order: Array = _types(events)
	assert_int(order.find("enchantment_applied")).is_less(order.find("minion_died"))


func test_an_op_with_no_target_does_not_stop_the_next_op() -> void:
	# Arrange — no weapon equipped.
	_main_phase([NO_TARGET_THEN_ARMOR])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert
	var events: Array = _since(before)
	var ops: Array = _one_resolved(events).payload.ops
	assert_array(ops.map(func(o: Dictionary) -> String: return str(o.outcome))).is_equal(["no_target", "applied"])
	EventLogAssertions.assert_payload(events, &"armor_gained", {"side": SIDE_PLAYER, "amount": 2})
	assert_array(_of_type(events, "enchantment_applied")).is_empty()


func test_a_false_condition_fizzles_the_pass_with_every_op_skipped() -> void:
	# Arrange — `not is_owner_turn` on the owner's own turn.
	_main_phase([CONDITION_FALSE])
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert — one effect_resolved{fizzled: condition_false}, no op's event
	var events: Array = _since(before)
	var payload: Dictionary = _one_resolved(events).payload
	assert_str(str(payload.fizzled)).is_equal("condition_false")
	assert_array(payload.ops).is_equal([
		{"op": "armor", "targets": [], "values": {}, "outcome": "skipped"},
		{"op": "draw", "targets": [], "values": {}, "outcome": "skipped"},
	])
	assert_array(_of_type(events, "armor_gained")).is_empty()
	assert_array(_of_type(events, "card_drawn")).is_empty()


func test_summon_places_each_copy_right_of_the_source_left_to_right() -> void:
	# Arrange — one minion left of where the host lands.
	_main_phase([SUMMON_PAIR])
	var left: int = int(MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 1)
	var before: int = _last_seq()

	# Act — the host at position 1, between the two
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 1, null))

	# Assert — [left, host, husk, husk, right]
	var board: Array = _engine.state().players[SIDE_PLAYER].board
	assert_array(board.map(func(m: Dictionary) -> String: return str(m.def_id))).is_equal(["", SUMMON_PAIR, "decay_husk", "decay_husk", ""])
	assert_int(int(board[0].entity_id)).is_equal(left)
	var ops: Array = _one_resolved(_since(before)).payload.ops
	assert_str(str(ops[0].outcome)).is_equal("applied")
	assert_array(ops[0].targets).is_equal([int(board[2].entity_id), int(board[3].entity_id)])


func test_summon_onto_a_full_board_is_board_full_per_failed_copy() -> void:
	# Arrange — six minions: the host fills the seventh slot.
	_main_phase([SUMMON_PAIR])
	for _i: int in TestConstants.BOARD_SIZE - 1:
		MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 1)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert
	var events: Array = _since(before)
	assert_int(_of_type(events, "summon_failed").size()).is_equal(2)
	var ops: Array = _one_resolved(events).payload.ops
	assert_str(str(ops[0].outcome)).is_equal("board_full")
	assert_array(ops[0].targets).is_empty()


func test_granting_a_keyword_already_held_is_already_has() -> void:
	_main_phase([KEYWORD_TWICE])
	var before: int = _last_seq()

	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	var events: Array = _since(before)
	var ops: Array = _one_resolved(events).payload.ops
	assert_array(ops.map(func(o: Dictionary) -> String: return str(o.outcome))).is_equal(["applied", "already_has"])
	assert_int(_of_type(events, "enchantment_applied").size()).is_equal(1)


# --- AC-39: the payload and its cause_seq ------------------------------------------

func test_a_spell_effect_resolved_carries_the_payload_and_the_spell_cast_cause() -> void:
	# Arrange — row 18 "Deal 3" at the enemy hero.
	_main_phase([ROW_18])
	var instance_id: int = int(_engine.state().players[SIDE_PLAYER].hand[0].instance_id)
	var boss_hero: int = int(_engine.state().players[SIDE_BOSS].hero.entity_id)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, boss_hero))

	# Assert
	var events: Array = _since(before)
	var cast: Dictionary = _of_type(events, "spell_cast")[0]
	var resolved: Dictionary = _one_resolved(events)
	assert_int(int(resolved.cause_seq)).is_equal(int(cast.seq))
	assert_dict(resolved.payload).is_equal({
		"effect_id": "%s.0" % ROW_18, "host_id": ROW_18, "host_kind": "card", "source_id": instance_id,
		"owner": SIDE_PLAYER, "trigger": "cast", "depth": 0, "fizzled": null,
		"ops": [{"op": "damage", "targets": [boss_hero], "values": {"amount": 3, "requested": 3}, "outcome": "applied"}],
	})
	var dealt: Dictionary = _of_type(events, "damage_dealt")[0]
	assert_int(int(dealt.cause_seq)).is_equal(int(cast.seq))
	assert_int(int(dealt.payload.source)).is_equal(instance_id)
	assert_int(int(dealt.seq)).is_less(int(resolved.seq))


func test_a_hero_power_effect_resolved_is_caused_by_hero_power_used() -> void:
	# Arrange — row 44 "Deal 1" as the player's hero power.
	_main_phase([])
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = ROW_44
	var hero: int = int(_engine.state().players[SIDE_PLAYER].hero.entity_id)
	var boss_hero: int = int(_engine.state().players[SIDE_BOSS].hero.entity_id)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER, boss_hero))

	# Assert
	var events: Array = _since(before)
	var used: Dictionary = _of_type(events, "hero_power_used")[0]
	var resolved: Dictionary = _one_resolved(events)
	assert_int(int(resolved.cause_seq)).is_equal(int(used.seq))
	assert_str(str(resolved.payload.host_kind)).is_equal("hero_power")
	assert_str(str(resolved.payload.trigger)).is_equal("hero_power")
	assert_int(int(resolved.payload.source_id)).is_equal(hero)
	assert_array(resolved.payload.ops[0].targets).is_equal([boss_hero])


func test_every_play_row_of_the_fixture_emits_one_well_formed_effect_resolved() -> void:
	# Arrange — every fixture host with a play trigger (derived, not listed).
	var rows: Array = []
	for record: Dictionary in _flat():
		for effect: Variant in record.get("effects", []):
			if PLAY_TRIGGERS.has(str((effect as Dictionary).get("trigger", ""))):
				rows.append(record)
				break
	assert_int(rows.size()).is_greater(0)

	for record: Dictionary in rows:
		# Act — a fresh match per row: a friendly and an enemy minion on board,
		# the first legal command for the host.
		var id: String = str(record.id)
		var is_power: bool = id.begins_with("power_")
		_main_phase([] if is_power else [id])
		MatchFactory.summon(_engine.state(), SIDE_PLAYER, 3, 3, -1, [], FRIEND_DEF)
		MatchFactory.summon(_engine.state(), SIDE_BOSS, 3, 3)
		if is_power:
			_engine.state().players[SIDE_PLAYER].hero_power.def_id = id
		var wanted: String = MatchRecords.CMD_USE_HERO_POWER if is_power else MatchRecords.CMD_PLAY_CARD
		var commands: Array = _engine.legal_commands().filter(func(c: Dictionary) -> bool: return c.type == wanted)
		assert_bool(commands.is_empty()).override_failure_message("%s: no legal command" % id).is_false()
		if commands.is_empty():
			continue
		var before: int = _last_seq()
		_submit(commands.back())
		# A Choose One / Discover host (row 33, story 010) resolves on `choose`.
		while _engine.phase() == MatchState.PHASE_CHOICE:
			_submit(_engine.legal_commands()[0])

		# Assert — one effect_resolved per play effect, each well formed and
		# caused by the command's own event.
		var events: Array = _since(before)
		var command_event: Array = events.filter(func(e: Dictionary) -> bool: return COMMAND_EVENTS.has(str(e.type)))
		var cause: int = int(command_event.back().seq) if not command_event.is_empty() else -1
		var plays: Array = (record.effects as Array).filter(func(e: Dictionary) -> bool: return PLAY_TRIGGERS.has(str(e.trigger)))
		# Only the play passes: a queued pass the play raised (row 10 destroys
		# row 9, whose Deathrattle resolves since story 008) is not the host's.
		var resolved: Array = _of_type(events, "effect_resolved").filter(func(e: Dictionary) -> bool: return PLAY_TRIGGERS.has(str(e.payload.trigger)))
		assert_int(resolved.size()).override_failure_message("%s: %s" % [id, str(_types(events))]).is_equal(plays.size())
		for i: int in resolved.size():
			var payload: Dictionary = resolved[i].payload
			var keys: Array = payload.keys()
			keys.sort()
			var expected_keys: Array = PAYLOAD_KEYS.duplicate()
			expected_keys.sort()
			assert_array(keys).override_failure_message(id).is_equal(expected_keys)
			assert_int(int(resolved[i].cause_seq)).override_failure_message(id).is_equal(cause)
			assert_str(str(payload.host_id)).is_equal(id)
			assert_str(str(payload.host_kind)).is_equal("hero_power" if is_power else "card")
			assert_str(str(payload.owner)).is_equal(SIDE_PLAYER)
			assert_int(int(payload.depth)).is_equal(0)
			var expected_entries: int = 0
			for op: Dictionary in plays[i].ops:
				expected_entries += _entry_count(op)
			assert_int((payload.ops as Array).size()).override_failure_message(id).is_equal(expected_entries)
			for entry: Dictionary in payload.ops:
				var entry_keys: Array = entry.keys()
				entry_keys.sort()
				assert_array(entry_keys).override_failure_message(id).is_equal(["op", "outcome", "targets", "values"])
				assert_array(EffectOps.OUTCOMES).override_failure_message("%s: %s" % [id, entry.outcome]).contains([str(entry.outcome)])
		after_test()
