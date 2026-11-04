## card-effects story 006 code-review fixes (2026-11-04, sprint 4 L4): an op
## the engine cannot honour yet is recorded `skipped` with a reason, and
## calls no primitive, instead of claiming `applied`
## (design/gdd/card-effects.md C4 value expressions, C5 `mana`, Interactions
## `effect_resolved.ops[].outcome`).
##   - `mana` with `duration: this_turn`: temporary crystals are match-rules
##     story 011 (`RulesEngine.add_mana` refuses them until then);
##   - a computed value (`{ref}`, `{count}`, `{add}`, …) in a numeric param:
##     value expressions are card-effects story 007.
## `EffectOps.run` is driven directly against a real started `RulesEngine`
## (`MatchFactory`, `TestEventLog`); no file I/O, no wall clock.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const AMOUNT: int = 2

var _engine: RulesEngine = null


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null


## A started engine past a keep-all mulligan (player Main, turn 1).
func _main_phase() -> RulesEngine:
	_engine = MatchFactory.make_started_engine()
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	return _engine


## The pass context `EffectOps.run` takes: the player's hero as the source.
func _run_ctx(engine: RulesEngine) -> Dictionary:
	return {
		"owner": SIDE_PLAYER,
		"source_id": int(engine.state().players[SIDE_PLAYER].hero.entity_id),
		"target_id": null,
		"effect": {},
	}


func _log_size(engine: RulesEngine) -> int:
	return (engine.state().log as TestEventLog).events.size()


func _run(engine: RulesEngine, op_json: String) -> Dictionary:
	var op: Dictionary = JSON.parse_string(op_json)
	var out: Dictionary = {}
	await assert_error(func() -> void: out.entry = EffectOps.new().run(engine, op, _run_ctx(engine))).is_success()
	return out.entry


# --- mana, duration this_turn (match-rules story 011) ---------------------------

func test_temporary_mana_is_skipped_naming_match_rules_story_011_and_emits_nothing() -> void:
	# Arrange
	var engine: RulesEngine = _main_phase()
	var before: int = _log_size(engine)
	var bonus: int = int(engine.state().players[SIDE_PLAYER].crystal_bonus)

	# Act
	var entry: Dictionary = await _run(engine, '{"op":"mana","amount":%d,"duration":"this_turn"}' % AMOUNT)

	# Assert
	assert_str(entry.outcome).is_equal(EffectOps.SKIPPED)
	assert_str(str(entry.values.reason)).contains("match-rules story 011")
	assert_int(_log_size(engine)).is_equal(before)
	assert_int(int(engine.state().players[SIDE_PLAYER].crystal_bonus)).is_equal(bonus)


func test_permanent_mana_still_applies_and_emits_mana_added() -> void:
	# Arrange
	var engine: RulesEngine = _main_phase()
	var before: int = _log_size(engine)

	# Act
	var entry: Dictionary = await _run(engine, '{"op":"mana","amount":%d}' % AMOUNT)

	# Assert
	assert_str(entry.outcome).is_equal(EffectOps.APPLIED)
	var events: Array = (engine.state().log as TestEventLog).events.slice(before)
	assert_int(EventLogAssertions.count_type(events, &"mana_added")).is_equal(1)

