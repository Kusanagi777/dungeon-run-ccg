## PERFORMANCE SUITE: the treasure hook chain's cost bound (treasures story 004;
## design/gdd/treasures.md F5, AC-14; ADR-0005 Performance Implications). Not part of
## the blocking run: the `performance` job runs this folder (`tests/README.md`).
##
## The registry is built from real installers and folds through the real
## `apply_value_hook`. The ratio gate compares two arms of one scripted match on the
## same seed, interleaved run by run, because single runs swing on a dev machine.
extends GdUnitTestSuite

## AC-14's bounds.
const FOLDS: int = 10000
const PROBE_FOLDS: int = 1000
const MEAN_BUDGET_USEC: float = 50.0
const RATIO_BUDGET: float = 1.05
const ARM_RUNS: int = 5
const TURNS: int = 9
## The T8 `modify_cost` records, repeated to [constant HookRegistry.DEBUG_MAX_ENTRIES].
const COST_TREASURES: Array[String] = [
	"treasure_worn_signet", "treasure_quartermasters_ledger", "treasure_vanguards_banner",
	"treasure_rotting_bargain", "treasure_dogeared_grimoire",
]
## A 1-cost spell in the hand: the Banner and the Grimoire both move it.
const SPELL: String = "neutral_test_perf_spell"
const SPELL_COST: int = 3
const THREE_TREASURES: Array[String] = ["treasure_hollow_crown", "treasure_worn_signet", "treasure_thornhide_cloak"]

var _db: CardDatabase = null
var _measured_fold: bool = false
var _measured_ratio: bool = false


func before() -> void:
	_db = TreasureFixtures.shipped_database({}, [CardFactory.make_spell(SPELL, SPELL_COST)])


func after() -> void:
	_db = null
	if not _measured_fold:
		print(PerfGate.not_assessed("treasures hooks.fold modify_cost", "the test ended before its measurement"))
	if not _measured_ratio:
		print(PerfGate.not_assessed("treasures 9-turn ratio", "the test ended before its measurement"))


## Twelve `modify_cost` entries: the T8 records under distinct hosts.
func _twelve_installers() -> Array:
	var installers: Array = []
	for i: int in HookRegistry.DEBUG_MAX_ENTRIES:
		var id: String = COST_TREASURES[i % COST_TREASURES.size()]
		installers.append(HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, "%s_%d" % [id, i], &"player", _db.treasure(id).effects))
	return installers


## One whole scripted match to turn [constant TURNS]: the hero power from turn 2, then
## both ends of turn. Returns its wall time in usec.
func _timed_match(treasures: Array) -> int:
	var started: int = Time.get_ticks_usec()
	var game := TreasureFixtures.Match.new(_db, treasures)
	game.to_turn(1)
	for turn: int in range(1, TURNS):
		if turn > 1:
			game.play(MatchRecords.use_hero_power(MatchRecords.SIDE_PLAYER))
		game.end_round()
	var elapsed: int = Time.get_ticks_usec() - started
	game.end()
	return elapsed


func _median(samples: Array[int]) -> int:
	return int(PerfGate.stats(samples).median)


func test_ac14_twelve_entry_cost_fold_is_under_the_budget_and_allocates_nothing() -> void:
	# Arrange: keep `game` alive, since the registry's evaluators do not hold the resolver
	var game := TreasureFixtures.Match.new(_db, [], {"installers": _twelve_installers()})
	game.to_turn(1)
	game.script_hand([SPELL])
	var hooks: HookRegistry = game.engine.hooks()
	var ctx: Dictionary = {"card": game.player().hand[0], "kind": RulesEngine.COST_KIND_CARD}
	var folded: int = hooks.fold(&"modify_cost", &"player", SPELL_COST, ctx)
	var objects_before: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory_before: float = Performance.get_monitor(Performance.MEMORY_STATIC)

	# Act
	var started: int = Time.get_ticks_usec()
	for _i: int in FOLDS:
		@warning_ignore("return_value_discarded")
		hooks.fold(&"modify_cost", &"player", SPELL_COST, ctx)
	var mean: float = float(Time.get_ticks_usec() - started) / FOLDS
	var objects_after: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory_after: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	_measured_fold = true
	print("PERF treasures hooks.fold modify_cost(%d entries): mean %.2f us over %d folds (budget %.1f us), objects %+d, static %+d bytes" % [hooks.entries(&"modify_cost").size(), mean, FOLDS, MEAN_BUDGET_USEC, int(objects_after - objects_before), int(memory_after - memory_before)])
	var entries: int = hooks.entries(&"modify_cost").size()
	game.end()

	# Assert: a fold that ran no evaluator would time nothing
	assert_int(entries).is_equal(HookRegistry.DEBUG_MAX_ENTRIES)
	assert_int(folded).is_less(SPELL_COST)
	assert_float(mean).is_less(MEAN_BUDGET_USEC)
	assert_float(objects_after).is_equal(objects_before)
	assert_float(memory_after).is_equal(memory_before)


func test_ac14_the_fold_holds_nothing_allocated_at_any_evaluator_call() -> void:
	# Arrange: the loop-edge probe above cannot see an allocation freed inside the loop
	# (a `ctx.duplicate()` in the fold left it at +0, watched 2026-11-05), so sample the
	# static memory on the way into every evaluator, where a copy is still alive
	var game := TreasureFixtures.Match.new(_db, [], {"installers": _twelve_installers()})
	game.to_turn(1)
	game.script_hand([SPELL])
	var hooks: HookRegistry = game.engine.hooks()
	var real: Callable = hooks._fold_entry
	var ctx: Dictionary = {"card": game.player().hand[0], "kind": RulesEngine.COST_KIND_CARD}
	var peak: Array[int] = [0]
	hooks.set_evaluators(func(entry: Dictionary, side: StringName, value: int, fold_ctx: Dictionary) -> int:
		peak[0] = maxi(peak[0], OS.get_static_memory_usage())
		return real.call(entry, side, value, fold_ctx), hooks._run_entry)
	@warning_ignore("return_value_discarded")
	hooks.fold(&"modify_cost", &"player", SPELL_COST, ctx)
	peak[0] = 0
	var baseline: int = OS.get_static_memory_usage()

	# Act
	for _i: int in PROBE_FOLDS:
		@warning_ignore("return_value_discarded")
		hooks.fold(&"modify_cost", &"player", SPELL_COST, ctx)
	var extra: int = peak[0] - baseline
	game.end()

	# Assert
	assert_int(extra).is_equal(0)


func test_ac14_three_treasures_cost_at_most_five_percent_on_a_nine_turn_match() -> void:
	# Arrange: one warm-up of each arm, then the arms in turn
	@warning_ignore("return_value_discarded")
	_timed_match([])
	@warning_ignore("return_value_discarded")
	_timed_match(THREE_TREASURES)
	var empty: Array[int] = []
	var held: Array[int] = []

	# Act
	for _i: int in ARM_RUNS:
		empty.append(_timed_match([]))
		held.append(_timed_match(THREE_TREASURES))
	var ratio: float = float(_median(held)) / float(_median(empty))
	_measured_ratio = true
	print("PERF treasures 9-turn match: empty median %d us, 3 treasures median %d us, ratio %.3f (budget %.2f)" % [_median(empty), _median(held), ratio, RATIO_BUDGET])

	# Assert
	assert_float(ratio).is_less_equal(RATIO_BUDGET)
