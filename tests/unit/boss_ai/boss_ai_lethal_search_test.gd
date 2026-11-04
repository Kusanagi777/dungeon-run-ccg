## Unit tests for the Boss AI lethal search (story
## boss-ai-match-driver/story-007; design/gdd/boss-ai.md C3, F4, F7, F9
## `lethal_search`, Edge Cases "Lethal and defence", A6-A9; ADR-0006;
## TR-boss-ai-001).
##
## Every case is a board under `tests/fixtures/boss_ai/` played on the production
## `EffectResolver` ([BossAiBoard]); F4's worked numbers are read from the
## fixture. `search` is a coroutine, so the tests await it with an
## `ImmediatePlannerTask` (no worker thread, ADR-0006). What a found plan does
## to a turn (the `ai_decision` clauses of A6, A7, A9) is story 008's and lives
## in `boss_ai_plan_turn_test.gd`.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
## A budget no fixture here reaches.
const AMPLE_NODES: int = 100000


## A [PlannerTask] that counts `checkpoint()` calls.
class CountingPlanner:
	extends PlannerTask

	var checkpoints: int = 0

	func start(work: Callable) -> void:
		_result = work.call()
		return

	func poll() -> bool:
		return true

	func checkpoint() -> void:
		checkpoints += 1
		return


## An engine that remembers the clones taken from it.
class TrackingEngine:
	extends RulesEngine

	var clones: Array[RulesEngine] = []

	func clone(rng_override: RngStream = null) -> RulesEngine:
		var made: RulesEngine = super(rng_override)
		clones.append(made)
		return made


# --- helpers -----------------------------------------------------------------

func _board(name: String, band: int = -1) -> Dictionary:
	var fixture: Dictionary = BossAiBoard.read(name)
	if band > 0:
		fixture.band = band
	return _laid_out(fixture)


func _laid_out(fixture: Dictionary) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var lethal: LethalSearch = LethalSearch.new(db, CandidateSet.new(db, BossAiBoard.stub_config().op_values, profile.synergy_tags))
	return {"fixture": fixture, "db": db, "engine": engine, "profile": profile, "lethal": lethal}


## The search over a clone of [param board]'s engine.
func _search(board: Dictionary, nodes: int = AMPLE_NODES, planner: PlannerTask = ImmediatePlannerTask.new(), sim: RngStream = null) -> Variant:
	var base: RulesEngine = (board.engine as RulesEngine).clone()
	var budgets: Dictionary = (board.profile.budgets as Dictionary).duplicate()
	budgets.lethal_max_nodes = nodes
	var plan: Variant = await (board.lethal as LethalSearch).search(base, board.profile, budgets, planner, sim)
	base.end_match()
	return plan


## The player's health after [param plan] runs on a clone; every step must be
## accepted.
func _health_after(board: Dictionary, plan: Array) -> int:
	var base: RulesEngine = (board.engine as RulesEngine).clone()
	for step: Dictionary in plan:
		assert_bool(base.submit(step.duplicate(true)).accepted).is_true()
	var health: int = base.health(base.state().players[SIDE_PLAYER].hero)
	base.end_match()
	return health


func _types(plan: Array) -> Array:
	return plan.map(func(step: Dictionary) -> String: return str(step.type))


func _burn_effects(bolt: Dictionary, amount: int) -> Array:
	var effects: Array = (bolt.effects as Array).duplicate(true)
	effects[0].ops[0].amount = amount
	return effects


# --- A6: open face, every band ---------------------------------------------------

func test_attackers_summing_to_the_players_health_are_lethal_in_every_band() -> void:
	for band: int in [1, 2, 3]:
		# Arrange
		var board: Dictionary = _board("lethal_open_face", band)

		# Act
		var plan: Variant = await _search(board)

		# Assert
		assert_str(String(board.lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_FOUND))
		assert_int(_health_after(board, plan)).is_less_equal(0)
		assert_array(_types(plan)).contains_exactly([MatchRecords.CMD_ATTACK, MatchRecords.CMD_ATTACK, MatchRecords.CMD_ATTACK])


# --- A7: through a Taunt ----------------------------------------------------------

func test_a_taunt_line_is_found_in_bands_two_and_three() -> void:
	for band: int in [2, 3]:
		# Arrange
		var board: Dictionary = _board("lethal_through_taunt", band)

		# Act
		var plan: Variant = await _search(board)

		# Assert — the Taunt falls first, then two attacks go face
		assert_int(_health_after(board, plan)).is_less_equal(0)
		var wall: int = BossAiBoard.ids_of(board.engine, SIDE_PLAYER, "bai_wall")[0]
		assert_int(int(plan[0].target_id)).is_equal(wall)


func test_a_taunt_line_is_beyond_the_shallow_search_of_band_one() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_through_taunt", 1)

	# Act
	var plan: Variant = await _search(board)

	# Assert
	assert_that(plan).is_null()
	assert_str(String(board.lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_SHALLOW_NONE))


# --- A8: weapon, swing, spell ------------------------------------------------------

func test_a_weapon_swing_and_a_spell_are_lethal_in_band_three() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_weapon_spell", 3)

	# Act
	var plan: Variant = await _search(board)

	# Assert — "that or an equivalent order": the end state, not the order
	assert_int(_health_after(board, plan)).is_less_equal(0)
	assert_array(_types(plan)).contains([MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_ATTACK])


# --- A9: F4 ---------------------------------------------------------------------------

func test_f4_worked_example_prunes_at_the_root_expanding_no_node() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_pruned_root")
	var base: RulesEngine = (board.engine as RulesEngine).clone()
	var lethal: LethalSearch = board.lethal

	# Act
	var potential: int = lethal.potential(base)
	var taunt_hp: int = lethal.taunt_hp(base)
	var plan: Variant = await lethal.search(base, board.profile, board.profile.budgets, ImmediatePlannerTask.new())
	base.end_match()

	# Assert
	assert_int(potential).is_equal(int(board.fixture.expect.potential))
	assert_int(taunt_hp).is_equal(int(board.fixture.expect.taunt_hp))
	assert_that(plan).is_null()
	assert_int(lethal.nodes).is_equal(0)
	assert_str(String(lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_NONE))


func test_f4_equality_does_not_prune_and_one_short_does() -> void:
	# Arrange — potential 12, taunt_hp 5: 7 reaches health 7, not health 7 + armor 1
	var fixture: Dictionary = BossAiBoard.read("lethal_pruned_root")
	fixture.player.health = 7
	var board: Dictionary = _laid_out(fixture)
	var lethal: LethalSearch = board.lethal
	var base: RulesEngine = (board.engine as RulesEngine).clone()

	# Act
	var at_equality: bool = lethal.prunes(base)
	base.state().players[SIDE_PLAYER].hero.armor = 1
	var with_armor: bool = lethal.prunes(base)
	base.end_match()

	# Assert — armor counts towards the bound (F4, against A9's shorter text)
	assert_bool(at_equality).is_false()
	assert_bool(with_armor).is_true()


func test_f4_counts_hand_damage_greedily_by_damage_per_mana_within_mana() -> void:
	# Arrange — 4 mana: greedy takes the 1-cost 3-damage spell, then the 3-cost
	# 4-damage one, over the 4-cost 5-damage spell (3/1 > 4/3 > 5/4)
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	var bolt: Dictionary = fixture.cards[3]
	fixture.cards.append({"id": "bai_jab", "type": "spell", "cost": 1, "effects": _burn_effects(bolt, 3)})
	fixture.cards.append({"id": "bai_blast", "type": "spell", "cost": 3, "effects": _burn_effects(bolt, 4)})
	fixture.cards.append({"id": "bai_nova", "type": "spell", "cost": 4, "effects": _burn_effects(bolt, 5)})
	fixture.boss.hand = ["bai_nova", "bai_blast", "bai_jab"]
	var board: Dictionary = _laid_out(fixture)
	var base: RulesEngine = (board.engine as RulesEngine).clone()

	# Act
	var potential: int = (board.lethal as LethalSearch).potential(base)
	base.end_match()

	# Assert
	assert_int(potential).is_equal(3 + 4)


func test_f4_potential_adds_the_boss_spell_damage_to_each_burn() -> void:
	# Arrange — one Spell Damage minion on the boss board
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.cards.append({"id": "bai_sage", "type": "minion", "cost": 2, "attack": 0, "health": 2, "keywords": ["spell_damage"], "spell_damage": 1})
	fixture.boss.board = ["bai_sage"]
	fixture.boss.hand = ["bai_bolt"]
	var board: Dictionary = _laid_out(fixture)
	var base: RulesEngine = (board.engine as RulesEngine).clone()

	# Act
	var potential: int = (board.lethal as LethalSearch).potential(base)
	base.end_match()

	# Assert
	assert_int(potential).is_equal(3 + 1)


func test_f4_does_not_prune_on_a_burn_it_cannot_price() -> void:
	# Arrange — the amount is an expression (shipped war cards read weapon_attack)
	var fixture: Dictionary = BossAiBoard.read("lethal_pruned_root")
	fixture.cards[3].effects[0].ops[0].amount = {"ref": "owner.weapon_attack"}
	var board: Dictionary = _laid_out(fixture)
	var base: RulesEngine = (board.engine as RulesEngine).clone()

	# Act
	var pruned: bool = (board.lethal as LethalSearch).prunes(base)
	base.end_match()

	# Assert
	assert_bool(pruned).is_false()


# --- A9: the node budget -------------------------------------------------------------

func test_a_budget_of_exactly_the_nodes_needed_finds_the_leaf_and_one_fewer_returns_null() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_through_taunt", 2)
	var plan: Variant = await _search(board)
	var needed: int = (board.lethal as LethalSearch).nodes
	assert_that(plan).is_not_null()

	# Act
	var exact: Variant = await _search(board, needed)
	var short: Variant = await _search(board, needed - 1)

	# Assert
	assert_that(exact).is_equal(plan)
	assert_that(short).is_null()
	assert_str(String(board.lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_EXHAUSTED))
	assert_int((board.lethal as LethalSearch).nodes).is_equal(needed - 1)


func test_budgets_come_from_the_resolved_profile_and_move_the_cut_off() -> void:
	# Arrange — the same no-lethal board under the band budget and a fixture one
	var cut: Dictionary = BossAiBoard.read("lethal_shield_wall")
	var cut_nodes: int = 30
	cut["budgets"] = {"lethal_max_nodes": cut_nodes}
	var capped: Dictionary = _laid_out(cut)
	var full: Dictionary = _board("lethal_shield_wall")
	var capped_base: RulesEngine = (capped.engine as RulesEngine).clone()
	var full_base: RulesEngine = (full.engine as RulesEngine).clone()

	# Act
	var capped_plan: Variant = await (capped.lethal as LethalSearch).search(capped_base, capped.profile, capped.profile.budgets, ImmediatePlannerTask.new())
	var full_plan: Variant = await (full.lethal as LethalSearch).search(full_base, full.profile, full.profile.budgets, ImmediatePlannerTask.new())
	capped_base.end_match()
	full_base.end_match()

	# Assert — one exhausts at its count; the other ends its tree with no leaf
	assert_that(capped_plan).is_null()
	assert_int((capped.lethal as LethalSearch).nodes).is_equal(cut_nodes)
	assert_str(String(capped.lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_EXHAUSTED))
	assert_that(full_plan).is_null()
	assert_int((full.lethal as LethalSearch).nodes).is_greater(cut_nodes)
	assert_str(String(full.lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_NONE))


func test_the_band_budgets_resolve_to_the_f7_counts() -> void:
	# Arrange — F7's row; the counts come from data, never from the search
	var expected: Dictionary = {1: 50, 2: 500, 3: 4000}

	for band: int in expected:
		# Act
		var profile: Dictionary = _board("lethal_open_face", band).profile

		# Assert
		assert_int(int(profile.budgets.lethal_max_nodes)).is_equal(expected[band])


# --- shallow and off -----------------------------------------------------------------

func test_shallow_takes_direct_attacks_plus_one_burn() -> void:
	# Arrange — a 3/3 and one 3-damage spell against a player at 6
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.band = 1
	fixture.boss.board = ["bai_brute"]
	fixture.boss.hand = ["bai_bolt"]
	var board: Dictionary = _laid_out(fixture)

	# Act
	var plan: Variant = await _search(board)

	# Assert
	assert_int(_health_after(board, plan)).is_less_equal(0)


func test_shallow_never_casts_a_second_burn() -> void:
	# Arrange — two bolts make lethal: full finds it, shallow stops at one
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.boss.hand = ["bai_bolt", "bai_bolt"]
	var full: Dictionary = _laid_out(fixture.duplicate(true))
	fixture.band = 1
	var shallow: Dictionary = _laid_out(fixture)

	# Act
	var full_plan: Variant = await _search(full)
	var shallow_plan: Variant = await _search(shallow)

	# Assert
	assert_int(_health_after(full, full_plan)).is_less_equal(0)
	assert_that(shallow_plan).is_null()
	assert_str(String(shallow.lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_SHALLOW_NONE))


func test_shallow_does_not_take_the_weapon_line() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_weapon_spell", 1)

	# Act
	var plan: Variant = await _search(board)

	# Assert
	assert_that(plan).is_null()
	assert_str(String(board.lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_SHALLOW_NONE))


func test_lethal_search_off_expands_nothing() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_open_face")
	board.profile.rules.lethal_search = LethalSearch.RULE_OFF

	# Act
	var plan: Variant = await _search(board)

	# Assert
	assert_that(plan).is_null()
	assert_int((board.lethal as LethalSearch).nodes).is_equal(0)
	assert_str(String(board.lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_OFF))


# --- the damage subset ---------------------------------------------------------------

func test_a_charge_minion_in_hand_is_played_and_swings_for_lethal() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.cards.append({"id": "bai_lancer", "type": "minion", "cost": 4, "attack": 6, "health": 1, "keywords": ["charge"]})
	fixture.boss.hand = ["bai_lancer"]
	var board: Dictionary = _laid_out(fixture)

	# Act
	var plan: Variant = await _search(board)

	# Assert
	assert_array(_types(plan)).contains_exactly([MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_ATTACK])
	assert_int(_health_after(board, plan)).is_less_equal(0)


func test_a_rush_minion_clears_a_taunt_for_the_face_attack() -> void:
	# Arrange — the 3/1 Rush kills the 1/1 Taunt; the 5/5 goes face for 5
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.cards.append({"id": "bai_rusher", "type": "minion", "cost": 3, "attack": 3, "health": 1, "keywords": ["rush"]})
	fixture.cards.append({"id": "bai_five", "type": "minion", "cost": 5, "attack": 5, "health": 5})
	fixture.cards.append({"id": "bai_pawn", "type": "minion", "cost": 1, "attack": 1, "health": 1, "keywords": ["taunt"]})
	fixture.boss.board = ["bai_five"]
	fixture.boss.hand = ["bai_rusher"]
	fixture.player.board = ["bai_pawn"]
	fixture.player.health = 5
	var board: Dictionary = _laid_out(fixture)

	# Act
	var plan: Variant = await _search(board)

	# Assert
	assert_str(str(plan[0].type)).is_equal(MatchRecords.CMD_PLAY_CARD)
	assert_int(_health_after(board, plan)).is_less_equal(0)


func test_a_vanilla_minion_is_outside_the_damage_subset() -> void:
	# Arrange — a plain 6/6 cannot swing this turn; nothing else can act
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.cards.append({"id": "bai_plain", "type": "minion", "cost": 4, "attack": 6, "health": 6})
	fixture.boss.hand = ["bai_plain"]
	var board: Dictionary = _laid_out(fixture)

	# Act
	var plan: Variant = await _search(board)

	# Assert
	assert_that(plan).is_null()
	assert_int((board.lethal as LethalSearch).nodes).is_equal(0)


func test_a_minion_only_removal_spell_is_outside_the_damage_subset() -> void:
	# Arrange — its `chosen` filter cannot reach the hero (C3)
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.cards[3].effects[0].targets.filter.kind = "minion"
	fixture.cards.append({"id": "bai_pawn", "type": "minion", "cost": 1, "attack": 1, "health": 1})
	fixture.boss.hand = ["bai_bolt"]
	fixture.player.board = ["bai_pawn"]
	var board: Dictionary = _laid_out(fixture)
	var base: RulesEngine = (board.engine as RulesEngine).clone()

	# Act
	var potential: int = (board.lethal as LethalSearch).potential(base)
	base.end_match()

	# Assert
	assert_int(potential).is_equal(0)


func test_a_plain_minion_is_tried_at_one_position_only() -> void:
	# Arrange — a Charge minion with three friendly minions on the board: four
	# positions offered, one tried (C6)
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.cards.append({"id": "bai_lancer", "type": "minion", "cost": 4, "attack": 1, "health": 1, "keywords": ["charge"]})
	fixture.cards.append({"id": "bai_idol", "type": "minion", "cost": 1, "attack": 0, "health": 1})
	fixture.boss.board = ["bai_idol", "bai_idol", "bai_idol"]
	fixture.boss.hand = ["bai_lancer"]
	fixture.player.health = 1
	var board: Dictionary = _laid_out(fixture)

	# Act
	var plan: Variant = await _search(board)

	# Assert — the play, then the swing: two nodes, no position sweep
	assert_int(int(plan[0].position)).is_equal((fixture.boss.board as Array).size())
	assert_int((board.lethal as LethalSearch).nodes).is_equal(2)


# --- isolation -------------------------------------------------------------------------

func test_the_search_leaves_the_live_engine_untouched() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_through_taunt", 3)
	var engine: RulesEngine = board.engine
	var log: TestEventLog = engine.state().log
	var events: int = log.events.size()
	var draws: int = (engine.rng_match() as RngStream).draws
	var hero_id: int = int(engine.state().players[SIDE_PLAYER].hero.entity_id)
	var wall_id: int = BossAiBoard.ids_of(engine, SIDE_PLAYER, "bai_wall")[0]
	var hero: Dictionary = engine.state_snapshot(hero_id)
	var wall: Dictionary = engine.state_snapshot(wall_id)

	# Act
	var plan: Variant = await _search(board)

	# Assert
	assert_that(plan).is_not_null()
	assert_int(log.events.size()).is_equal(events)
	assert_int((engine.rng_match() as RngStream).draws).is_equal(draws)
	assert_that(engine.state_snapshot(hero_id)).is_equal(hero)
	assert_that(engine.state_snapshot(wall_id)).is_equal(wall)


func test_every_clone_of_the_sandbox_is_ended_on_each_exit_path() -> void:
	for nodes: int in [AMPLE_NODES, 1]:
		# Arrange — the found path, then the exhausted one
		var board: Dictionary = _board("lethal_through_taunt", 3)
		var sandbox: TrackingEngine = BossAiBoard.adopt(TrackingEngine, board.engine, board.db)
		var budgets: Dictionary = (board.profile.budgets as Dictionary).duplicate()
		budgets.lethal_max_nodes = nodes

		# Act
		@warning_ignore("return_value_discarded")
		await (board.lethal as LethalSearch).search(sandbox, board.profile, budgets, ImmediatePlannerTask.new())

		# Assert
		assert_int(sandbox.clones.size()).is_greater(0)
		for clone: RulesEngine in sandbox.clones:
			assert_bool(clone._bound).is_false()
		sandbox.end_match()


func test_the_callers_sandbox_is_never_submitted_to() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_through_taunt", 3)
	var base: RulesEngine = (board.engine as RulesEngine).clone()
	var scratch: EventLog = base.state().log
	var events: int = scratch.size()

	# Act
	@warning_ignore("return_value_discarded")
	await (board.lethal as LethalSearch).search(base, board.profile, board.profile.budgets, ImmediatePlannerTask.new())

	# Assert
	assert_int(scratch.size()).is_equal(events)
	assert_str(base.phase()).is_equal(MatchState.PHASE_MAIN)
	base.end_match()


func test_checkpoint_runs_once_per_expanded_node() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_through_taunt", 3)
	var planner: CountingPlanner = CountingPlanner.new()

	# Act
	@warning_ignore("return_value_discarded")
	await _search(board, AMPLE_NODES, planner)

	# Assert
	assert_int((board.lethal as LethalSearch).nodes).is_greater(0)
	assert_int(planner.checkpoints).is_equal((board.lethal as LethalSearch).nodes)


func test_a_sandbox_resolution_overflow_prunes_that_branch_and_the_search_goes_on() -> void:
	# Arrange — each attacker kills the 1-health Taunt, whose queued Deathrattle
	# passes a step cap of one: every branch faults on its clone
	var fixture: Dictionary = BossAiBoard.read("lethal_through_taunt")
	fixture.cards[3].health = 1
	fixture.cards[3].effects = [{"trigger": "deathrattle", "targets": "owner_hero", "ops": [{"op": "heal", "amount": 1}]}]
	var board: Dictionary = _laid_out(fixture)
	var sandbox: RulesEngine = BossAiBoard.adopt(RulesEngine, board.engine, board.db, {"resolution_step_cap": 1})

	# Act
	var plan: Variant = await (board.lethal as LethalSearch).search(sandbox, board.profile, board.profile.budgets, ImmediatePlannerTask.new())
	sandbox.end_match()

	# Assert — each root move was tried and cut; none is taken for a leaf
	assert_that(plan).is_null()
	assert_str(String(board.lethal.outcome)).is_equal(String(LethalSearch.OUTCOME_NONE))
	assert_int((board.lethal as LethalSearch).nodes).is_equal((fixture.boss.board as Array).size())


func test_a_lethal_blow_that_overflows_is_no_leaf() -> void:
	# Arrange — one area burn kills the hero and a Deathrattle minion; the queued
	# Deathrattle passes the step cap, so the match faults with the hero at ≤ 0
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.cards[3].effects[0].targets = "all_enemy_characters"
	fixture.cards[3].effects[0].ops[0].amount = 6
	fixture.cards.append({"id": "bai_pawn", "type": "minion", "cost": 1, "attack": 1, "health": 1, "effects": [{"trigger": "deathrattle", "targets": "owner_hero", "ops": [{"op": "armor", "amount": 1}]}]})
	fixture.boss.hand = ["bai_bolt"]
	fixture.player.board = ["bai_pawn"]
	var board: Dictionary = _laid_out(fixture)
	var sandbox: RulesEngine = BossAiBoard.adopt(RulesEngine, board.engine, board.db, {"resolution_step_cap": 1})

	# Act
	var plan: Variant = await (board.lethal as LethalSearch).search(sandbox, board.profile, board.profile.budgets, ImmediatePlannerTask.new())
	sandbox.end_match()

	# Assert
	assert_that(plan).is_null()
	assert_int((board.lethal as LethalSearch).nodes).is_equal(1)


## The search of a board whose one burn hits a random enemy character (the
## player's hero, or a 1/1), with the live stream advanced [param offset] draws.
func _random_burn_plan(offset: int, sim: RngStream) -> Variant:
	var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
	fixture.cards[3].effects[0].targets = "random_enemy_character"
	fixture.cards.append({"id": "bai_pawn", "type": "minion", "cost": 1, "attack": 1, "health": 1})
	fixture.boss.hand = ["bai_bolt"]
	fixture.player.board = ["bai_pawn"]
	fixture.player.health = 3
	var board: Dictionary = _laid_out(fixture)
	var stream: RngStream = (board.engine as RulesEngine).rng_match()
	for _i: int in offset:
		@warning_ignore("return_value_discarded")
		stream.randi32()
	var draws: int = stream.draws
	var plan: Variant = await _search(board, AMPLE_NODES, ImmediatePlannerTask.new(), sim)
	assert_int(stream.draws).is_equal(draws)
	return plan


func test_search_randomness_comes_from_the_sim_fork_not_the_live_stream() -> void:
	# Arrange — the same fork over twelve live stream positions; the sim seed
	# makes the burn hit the hero on the fork
	var offsets: Array = range(12)
	var sim: RngStream = TestRngStream.seeded("ai_1", 5).fork(TieBreak.sim_label(2))
	var sim_draws: int = sim.draws
	var with_fork: Array = []
	var on_live_copy: Array = []

	# Act
	for offset: int in offsets:
		with_fork.append((await _random_burn_plan(offset, sim)) != null)
		on_live_copy.append((await _random_burn_plan(offset, null)) != null)

	# Assert — the live copy's outcome follows the stream, the fork's does not
	assert_bool(on_live_copy.has(true) and on_live_copy.has(false)).is_true()
	assert_bool(with_fork.has(true) and with_fork.has(false)).is_false()
	assert_int(sim.draws).is_equal(sim_draws)
