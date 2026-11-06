## card-effects story 006 code-review fix (2026-11-04, sprint 4 L4): a `mana`
## op with `duration: this_turn` must grant what it logs. The review found it
## logged `applied` while `RulesEngine.add_mana` refused temporary crystals;
## match-rules story 011 now grants them, so this suite proves the op end to
## end: a real `RulesEngine` bound to the real `EffectResolver`, a spell whose
## `cast` effect is the op, played through `submit` — the crystals are
## granted, the op is logged `applied`, and they expire at the End step
## (design/gdd/card-effects.md C5 `mana`, Interactions `effect_resolved`;
## match-rules F2 temporary crystals). In-memory definitions; no file I/O,
## no wall clock.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SURGE: String = "war_test_surge"
const LASTING_SURGE: String = "war_test_lasting_surge"
const AMOUNT: int = 2


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


## A 0-cost spell whose cast effect is one `mana` op; `duration` "" = absent.
func _surge(id: String, duration: String) -> Dictionary:
	var op: Dictionary = {"op": "mana", "targets": "owner", "amount": AMOUNT}
	if duration != "":
		op["duration"] = duration
	return CardFactory.make_spell(id, 0, [{"id": id + ".0", "trigger": "cast", "ops": [op]}], {"set": "war"})


## A started engine bound to a real `EffectResolver`, past a keep-all
## mulligan (player Main, turn 1), the hand replaced by [param hand].
func _main_phase(hand: Array) -> RulesEngine:
	var db: FakeCardDatabase = FakeCardDatabase.new({
		SURGE: _surge(SURGE, "this_turn"),
		LASTING_SURGE: _surge(LASTING_SURGE, ""),
	})
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log)
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	_engine.start(config)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = _engine.state()
	var cards: Array = state.players[SIDE_PLAYER].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	return _engine


func _events_after(before: int, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in _log.events.slice(before):
		if event.type == type:
			out.append(event)
	return out


func test_a_this_turn_mana_op_grants_temporary_crystals_logs_applied_and_they_expire() -> void:
	# Arrange
	var engine: RulesEngine = _main_phase([SURGE])
	var player: Dictionary = engine.state().players[SIDE_PLAYER]
	var max_before: int = int(player.mana_max)
	var current_before: int = int(player.mana_current)
	var cap: int = TestConstants.MAX_MANA_CRYSTALS
	var before: int = _log.events.size()

	# Act
	var played: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0))

	# Assert — the op ran, granted the crystals and says so
	assert_bool(played.accepted).is_true()
	var resolved: Array[Dictionary] = _events_after(before, "effect_resolved")
	assert_int(resolved.size()).is_equal(1)
	var op_entry: Dictionary = (resolved[0].payload.ops as Array)[0]
	assert_str(op_entry.op).is_equal("mana")
	assert_str(op_entry.outcome).is_equal(EffectOps.APPLIED)
	var added: Array[Dictionary] = _events_after(before, "mana_added")
	assert_int(added.size()).is_equal(1)
	assert_bool(added[0].payload.temporary).is_true()
	assert_int(int(player.mana_max)).is_equal(mini(max_before + AMOUNT, cap))
	assert_int(int(player.mana_current)).is_equal(mini(current_before + AMOUNT, cap))
	assert_int(int(player.temporary_crystals)).is_equal(mini(max_before + AMOUNT, cap) - max_before)

	# Assert — the End step takes the temporary crystals back
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_int(int(player.mana_max)).is_equal(max_before)
	assert_int(int(player.temporary_crystals)).is_equal(0)


func test_a_mana_op_without_duration_adds_permanent_crystal_bonus() -> void:
	# Arrange
	var engine: RulesEngine = _main_phase([LASTING_SURGE])
	var player: Dictionary = engine.state().players[SIDE_PLAYER]
	var bonus_before: int = int(player.crystal_bonus)
	var before: int = _log.events.size()

	# Act
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()

	# Assert
	var op_entry: Dictionary = (_events_after(before, "effect_resolved")[0].payload.ops as Array)[0]
	assert_str(op_entry.outcome).is_equal(EffectOps.APPLIED)
	var added: Array[Dictionary] = _events_after(before, "mana_added")
	assert_int(added.size()).is_equal(1)
	assert_bool(added[0].payload.temporary).is_false()
	assert_int(int(player.crystal_bonus)).is_equal(bonus_before + AMOUNT)
	assert_int(int(player.temporary_crystals)).is_equal(0)
