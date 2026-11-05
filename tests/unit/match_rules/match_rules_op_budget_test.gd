## Blocking op-count and allocation budgets of the rules engine (story
## match-rules/story-019 AC-1; design/gdd/match-rules.md C10, AC-40; ADR-0007
## Performance; ADR-0005). Deterministic: every assertion is a count from
## `RulesEngine.op_counts()` or an equality, never a wall clock. The timed half
## is `tests/performance/match_rules/`.
##
## The fixtures are `tests/helpers/match_budget_fixtures.gd`, shared with the
## timing suites, so both measure one thing. Allocation budgets are counted at
## their allocation sites because `docs/engine-reference/godot/` documents no
## allocation monitor for `Array` or `Dictionary` (story 019 Engine Notes).
extends GdUnitTestSuite

## R1 (story 019 AC-1): the chain fixture has no aura source, so no recompute
## has anything to compare. Baseline on the unchanged engine: 122, two per
## recompute.
const CHAIN_STAT_MAP_PASSES: int = 0
## R1 (story 019 AC-1): at most these per recompute with an aura or a primitive:
## the `before` and `after` of [method RulesEngine._recompute_auras].
const MAX_STAT_MAP_PASSES_PER_RECOMPUTE: int = 2
## R3 (story 019 AC-1): `candidate_buffers` may exceed `drain_iterations` by this.
const CANDIDATE_BUFFER_MARGIN: int = 1
## The moves of a candidate in the R3 one-action test: summon, transform, bounce,
## equip.
const CANDIDATE_MOVES: int = 4
## Summons in one step of the R3 refill test.
const CONSECUTIVE_SUMMONS: int = 3
## Quiet recomputes the R1 aura test runs after the last aura has gone.
const QUIET_RECOMPUTES: int = 3

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()
var _golden: MatchGoldenLogs = MatchGoldenLogs.new()


## The chain engine after one measured `submit`, and its `op_counts()`.
func _chain_counts() -> Dictionary:
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(false))
	var command: Dictionary = _fx.chain_command(engine)
	engine.reset_op_counts()
	var result: Dictionary = engine.submit(command)
	assert_bool(result.accepted).is_true()
	var counts: Dictionary = engine.op_counts()
	engine.end_match()
	return counts


func test_the_c10_loop_runs_one_recompute_per_drain_iteration_on_the_chain() -> void:
	# Act
	var counts: Dictionary = _chain_counts()

	# Assert: the loop's shape is unchanged (death check, recompute, queue pop)
	assert_int(int(counts.recompute_calls)).is_equal(int(counts.drain_iterations))


# --- R1: `_recompute_auras` skips both stat passes when nothing can have moved ------

func test_the_chain_with_no_aura_source_makes_no_stat_map_pass() -> void:
	# Act
	var counts: Dictionary = _chain_counts()

	# Assert
	assert_int(int(counts.stat_map_passes)).is_equal(CHAIN_STAT_MAP_PASSES)


func _no_step() -> void:
	pass


func test_an_aura_board_passes_at_most_twice_per_recompute_and_never_once_the_aura_has_gone() -> void:
	# Arrange: the running stat-pass total, read inside every recompute
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var source_id: int = _fx.add_aura_source(resolver, engine)
	var totals: Array[int] = []
	resolver.aura_scripts.append(func(e: RulesEngine) -> void: totals.append(int(e.op_counts().stat_map_passes)))
	engine.reset_op_counts()

	# Act: applied, re-applied, Silenced (the last strip), then quiet recomputes
	engine.run_action(_no_step)
	engine.run_action(_no_step)
	engine.run_action(func() -> void: engine.silence(source_id))
	var before_quiet: int = int(engine.op_counts().stat_map_passes)
	for _i: int in QUIET_RECOMPUTES:
		engine.run_action(_no_step)
	var counts: Dictionary = engine.op_counts()

	# Assert: every gap between two recomputes holds at most one recompute's passes
	assert_int(totals.size()).is_greater_equal(QUIET_RECOMPUTES)
	for i: int in range(1, totals.size()):
		assert_int(totals[i] - totals[i - 1]).is_less_equal(MAX_STAT_MAP_PASSES_PER_RECOMPUTE)
	assert_int(int(counts.stat_map_passes)).override_failure_message("a recompute with no aura left made a stat pass").is_equal(before_quiet)
	engine.end_match()


func test_a_primitive_called_in_the_aura_pass_reports_the_auras_recomputed_of_its_golden() -> void:
	# Arrange: `{primitive: its golden auras_recomputed payloads}`
	var recorded: Dictionary = _golden_aura_payloads()
	var reported: int = 0
	for primitive: StringName in RulesEngine.PRIMITIVES:
		var log: TestEventLog = TestEventLog.new()
		var resolver: TestEffectResolver = _fx.make_resolver(false)
		var engine: RulesEngine = _fx.make_aura_board(resolver, log)
		var mark: int = log.events.size()
		resolver.aura_scripts.append(_golden.primitive_once.bind(primitive))

		# Act: no aura enchantment exists, so only the primitive can move a value
		engine.run_action(_no_step)

		# Assert
		var payloads: Array = []
		for event: Dictionary in log.events.slice(mark):
			if StringName(event.type) == &"auras_recomputed":
				payloads.append(EventLogAssertions.canonical_json(event.payload))
		assert_array(payloads).override_failure_message("%s in the aura pass" % primitive).is_equal(recorded.get(String(primitive), []))
		reported += payloads.size()
		engine.end_match()
	assert_int(reported).override_failure_message("no primitive reported a change: the test proves nothing").is_greater(0)


## The `auras_recomputed` payloads of each primitive scenario of the aura golden.
func _golden_aura_payloads() -> Dictionary:
	var out: Dictionary = {}
	var scenario: String = ""
	var text: String = FileAccess.get_file_as_string(MatchGoldenLogs.path_of(MatchGoldenLogs.AURAS))
	for line: String in text.split("\n", false):
		var row: Dictionary = JSON.parse_string(line)
		if row.has("scenario"):
			scenario = str(row.scenario)
		elif row.has("event") and str(row.event.type) == "auras_recomputed":
			if not out.has(scenario):
				out[scenario] = []
			# the line, not the parsed row: JSON numbers parse back as floats
			var payload: String = line.substr(line.find("\"payload\":") + "\"payload\":".length())
			(out[scenario] as Array).append(payload.left(payload.rfind(",\"seq\":")))
	return out


func test_the_op_counters_stay_out_of_the_log_the_snapshot_and_the_result() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(false), log)

	# Act
	@warning_ignore("return_value_discarded")
	engine.submit(_fx.chain_command(engine))
	@warning_ignore("return_value_discarded")
	engine.submit(MatchRecords.concede(MatchRecords.SIDE_PLAYER))
	var seen: String = log.to_json() + str(engine.result()) + str(engine.state_snapshot(MatchFactory.PLAYER_HERO_ENTITY_ID))

	# Assert
	for counter: String in engine.op_counts():
		assert_bool(seen.contains(counter)).override_failure_message("%s reached the match record" % counter).is_false()
	engine.end_match()


func test_a_clone_starts_its_op_counts_at_zero() -> void:
	# Arrange
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(false))
	@warning_ignore("return_value_discarded")
	engine.legal_commands()
	var live_ran: RulesEngine = engine.clone()
	@warning_ignore("return_value_discarded")
	live_ran.submit(_fx.chain_command(live_ran))

	# Act
	var fresh: RulesEngine = live_ran.clone()

	# Assert
	for counter: String in fresh.op_counts():
		assert_int(int(fresh.op_counts()[counter])).override_failure_message(counter).is_equal(0)
	fresh.end_match()
	live_ran.end_match()
	engine.end_match()


# --- R2: a lookup touches one record ---------------------------------------------------

func test_on_the_chain_each_lookup_touches_at_most_one_record() -> void:
	# Act
	var counts: Dictionary = _chain_counts()

	# Assert: baseline 13,944 visits over 917 lookups
	assert_int(int(counts.record_lookups)).is_greater(0)
	assert_int(int(counts.record_visits)).is_less_equal(int(counts.record_lookups))


## Asserts [param id] is found in one touch and answers [param expected_side].
func _assert_one_touch(engine: RulesEngine, id: int, expected_side: String, move: String) -> void:
	engine.reset_op_counts()
	var snapshot: Dictionary = engine.state_snapshot(id)
	var counts: Dictionary = engine.op_counts()
	assert_bool(snapshot.is_empty()).override_failure_message("%s: %d is gone" % [move, id]).is_false()
	assert_int(int(counts.record_visits)).override_failure_message("%s: %d took %d touches" % [move, id, counts.record_visits]).is_equal(int(counts.record_lookups))
	assert_str(engine._owner_of(id)).override_failure_message(move).is_equal(expected_side)


func test_every_zone_move_leaves_the_records_it_moved_one_touch_away() -> void:
	# Arrange
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var state: MatchState = engine.state()
	var player: Dictionary = state.players[MatchRecords.SIDE_PLAYER]
	var boss: Dictionary = state.players[MatchRecords.SIDE_BOSS]
	var side: String = MatchRecords.SIDE_PLAYER

	# Act / Assert: each move, then each record it shifted
	var summoned: int = engine.summon_minion(side, MatchBudgetFixtures.GRUNT, 0)
	for minion: Dictionary in player.board:
		_assert_one_touch(engine, int(minion.entity_id), side, "summon")

	engine.draw(side, 1)
	_assert_one_touch(engine, int(player.hand.back().instance_id), side, "draw")

	var bounced_to: int = engine.return_to_hand(summoned)
	_assert_one_touch(engine, bounced_to, side, "bounce into hand")
	for minion: Dictionary in player.board:
		_assert_one_touch(engine, int(minion.entity_id), side, "bounce off the board")

	var discarded: int = engine.discard(side, 0)
	_assert_one_touch(engine, discarded, side, "discard into the graveyard")
	for card: Dictionary in player.hand:
		_assert_one_touch(engine, int(card.instance_id), side, "discard shifts the hand")

	var transformed: int = engine.transform(int(player.board[0].entity_id), MatchBudgetFixtures.WALL)
	_assert_one_touch(engine, transformed, side, "transform")

	var added: int = engine.add_card_to_hand(side, MatchBudgetFixtures.GRUNT)
	_assert_one_touch(engine, added, side, "add to hand")

	var equipped: int = engine.equip_weapon(side, MatchBudgetFixtures.AXE)
	_assert_one_touch(engine, equipped, side, "equip")

	var victim: int = int(boss.board[0].entity_id)
	var left: Array[int] = []
	for minion: Dictionary in player.board:
		left.append(int(minion.entity_id))
	engine.run_action(func() -> void: engine.destroy(left[0]))
	left.remove_at(0)
	for id: int in left:
		_assert_one_touch(engine, id, side, "death shifts the board")
	_assert_one_touch(engine, victim, MatchRecords.SIDE_BOSS, "the other board is untouched")

	engine.end_match()


func test_playing_a_card_leaves_the_hand_and_the_board_one_touch_away() -> void:
	# Arrange: hand [grunt, blank, nova]
	var engine: RulesEngine = _fx.make_aura_board(_fx.make_resolver(false))
	var player: Dictionary = engine.state().players[MatchRecords.SIDE_PLAYER]
	var side: String = MatchRecords.SIDE_PLAYER

	# Act
	assert_bool(engine.submit(MatchRecords.play_card(side, 0, 0, null)).accepted).is_true()

	# Assert
	for minion: Dictionary in player.board:
		_assert_one_touch(engine, int(minion.entity_id), side, "play a minion")
	for card: Dictionary in player.hand:
		_assert_one_touch(engine, int(card.instance_id), side, "the play shifts the hand")

	# Act: a spell passes through `resolving` to the graveyard
	var spell: int = int(player.hand[0].instance_id)
	assert_bool(engine.submit(MatchRecords.play_card(side, 0)).accepted).is_true()

	# Assert
	_assert_one_touch(engine, spell, side, "a cast spell in the graveyard")
	engine.end_match()


func test_a_zone_written_directly_gets_the_scans_answer_not_a_stale_one() -> void:
	# Arrange: every record hinted, then the boards rewritten behind the engine's back
	var engine: RulesEngine = _fx.make_aura_board(_fx.make_resolver(false))
	var player: Dictionary = engine.state().players[MatchRecords.SIDE_PLAYER]
	var board: Array = player.board
	var first: Dictionary = board[0]
	var last: Dictionary = board[board.size() - 1]
	var first_id: int = int(first.entity_id)
	var last_id: int = int(last.entity_id)
	board.reverse()
	var gone: Dictionary = board.pop_back()
	var fresh_hero: Dictionary = MatchRecords.hero(int(player.hero.entity_id), MatchRecords.SIDE_PLAYER, TestConstants.PLAYER_STARTING_HEALTH)
	player.hero = fresh_hero

	# Act / Assert: the moved record is found where it now is, the removed one is not
	assert_bool(is_same(engine._minion(last_id), last)).is_true()
	assert_bool(is_same(engine._minion(int(gone.entity_id)), {})).is_false()
	assert_dict(engine._minion(first_id)).is_empty()
	assert_bool(is_same(engine._character(int(fresh_hero.entity_id)), fresh_hero)).override_failure_message("a replaced hero must be read from the state").is_true()
	engine.end_match()


func test_a_stale_hint_in_any_zone_never_answers_with_the_record_now_there() -> void:
	# Arrange: every zone hinted, then each one rewritten directly
	var engine: RulesEngine = _fx.make_aura_board(_fx.make_resolver(false))
	var state: MatchState = engine.state()
	var player: Dictionary = state.players[MatchRecords.SIDE_PLAYER]
	var old_hero: int = int(player.hero.entity_id)
	var old_weapon: int = int(player.weapon.entity_id)
	var hand: Array = player.hand
	var first_card: Dictionary = hand[0]
	var first_card_id: int = int(first_card.instance_id)
	var gone_card_id: int = int(hand[hand.size() - 1].instance_id)
	player.hero = MatchRecords.hero(MatchFactory.alloc_entity_id(state), MatchRecords.SIDE_PLAYER, TestConstants.PLAYER_STARTING_HEALTH)
	player.weapon = MatchRecords.weapon(MatchFactory.alloc_entity_id(state), MatchBudgetFixtures.AXE, MatchBudgetFixtures.AURA_WEAPON_ATTACK, MatchBudgetFixtures.AURA_WEAPON_DURABILITY, [])
	hand.reverse()
	@warning_ignore("return_value_discarded")
	hand.pop_front()

	# Act / Assert: the old ids answer nothing, and a shifted card is found
	assert_dict(engine._find_record(old_hero)).is_empty()
	assert_dict(engine._find_record(old_weapon)).is_empty()
	assert_dict(engine._find_record(gone_card_id)).is_empty()
	assert_bool(is_same(engine._find_record(first_card_id), first_card)).is_true()
	engine.end_match()


func test_a_finder_refuses_a_record_outside_its_zones() -> void:
	# Arrange
	var engine: RulesEngine = _fx.make_aura_board(_fx.make_resolver(false))
	var player: Dictionary = engine.state().players[MatchRecords.SIDE_PLAYER]
	var weapon_id: int = int(player.weapon.entity_id)
	var card_id: int = int(player.hand[0].instance_id)
	var deck_id: int = int(player.deck[0].instance_id)

	# Act / Assert: a hint in another zone answers nothing
	assert_dict(engine._character(weapon_id)).is_empty()
	assert_dict(engine._minion(card_id)).is_empty()
	assert_dict(engine._weapon(card_id)).is_empty()
	assert_dict(engine._live_record(deck_id)).is_empty()
	assert_bool(engine._find_record(deck_id).is_empty()).is_false()
	assert_bool(engine._live_record(card_id).is_empty()).is_false()
	engine.end_match()


func test_a_clones_location_index_is_its_own() -> void:
	# Arrange
	var engine: RulesEngine = _fx.make_aura_board(_fx.make_resolver(false))
	var sandbox: RulesEngine = engine.clone()
	var board: Array = engine.state().players[MatchRecords.SIDE_PLAYER].board
	var moved: int = int(board[board.size() - 1].entity_id)

	# Act: a summon at the left shifts the clone's board only
	@warning_ignore("return_value_discarded")
	sandbox.summon_minion(MatchRecords.SIDE_PLAYER, MatchBudgetFixtures.GRUNT, 0)

	# Assert: the live engine's hint was not moved with it
	assert_bool(is_same(engine._where, sandbox._where)).is_false()
	_assert_one_touch(engine, moved, MatchRecords.SIDE_PLAYER, "the live board did not shift")
	_assert_one_touch(sandbox, moved, MatchRecords.SIDE_PLAYER, "the clone's board did")
	sandbox.end_match()
	engine.end_match()


# --- R3: one reused candidate buffer ---------------------------------------------------

func test_the_chain_allocates_at_most_one_candidate_buffer_per_drain_iteration() -> void:
	# Act
	var counts: Dictionary = _chain_counts()

	# Assert: baseline 555, one per trigger point
	assert_int(int(counts.candidate_buffers)).is_less_equal(int(counts.drain_iterations) + CANDIDATE_BUFFER_MARGIN)


func test_a_raise_nested_in_resolve_leaves_the_outer_candidates_as_they_were_raised() -> void:
	# Arrange: an `on_damage` script that reads its list, summons (so `on_summon` is
	# raised from inside this resolve), then reads its list again
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var seen: Dictionary = {}
	resolver.scripts[&"on_damage"] = [func(e: RulesEngine, ctx: Dictionary) -> void:
		if seen.has("before"):
			return
		seen["before"] = (ctx.candidates as Array).duplicate()
		@warning_ignore("return_value_discarded")
		e.summon_minion(MatchRecords.SIDE_PLAYER, MatchBudgetFixtures.GRUNT, 0)
		seen["after"] = (ctx.candidates as Array).duplicate()]
	var boss_hero: int = int(engine.state().players[MatchRecords.SIDE_BOSS].hero.entity_id)

	# Act
	engine.run_action(func() -> void: engine.apply_damage(boss_hero, 1, null))

	# Assert
	assert_array(seen.get("after", [])).is_equal(seen.get("before", [null]))
	engine.end_match()


func test_a_board_written_directly_between_calls_reaches_the_next_candidates() -> void:
	# Arrange: the buffer filled, then a fixture's write no zone serial can see
	var engine: RulesEngine = _fx.make_aura_board(_fx.make_resolver(false))
	var before: int = engine._candidates_in_order().size()
	@warning_ignore("return_value_discarded")
	MatchFactory.summon(engine.state(), MatchRecords.SIDE_BOSS, 1, 1)

	# Act
	var after: int = engine._candidates_in_order().size()

	# Assert
	assert_int(after).is_equal(before + 1)
	engine.end_match()


func test_a_board_written_directly_between_two_actions_reaches_the_second_actions_raise() -> void:
	# Arrange: one action fills the buffer, then a fixture writes the board
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var hero: int = int(engine.state().players[MatchRecords.SIDE_PLAYER].hero.entity_id)
	var lists: Array = []
	resolver.scripts[&"on_heal"] = [func(_e: RulesEngine, ctx: Dictionary) -> void: lists.append((ctx.candidates as Array).duplicate())]
	engine.run_action(func() -> void: engine.apply_heal(hero, 1, null))
	var placed: Dictionary = MatchFactory.summon(engine.state(), MatchRecords.SIDE_BOSS, 1, 1)

	# Act
	engine.run_action(func() -> void: engine.apply_heal(hero, 1, null))

	# Assert
	assert_int(lists.size()).is_equal(2)
	assert_bool((lists[1] as Array).has(int(placed.entity_id))).override_failure_message("the second action raised a list from before the write").is_true()
	engine.end_match()


func test_a_weapon_equipped_into_an_empty_slot_reaches_the_next_raise_in_the_action() -> void:
	# Arrange: an empty slot, so only the equip itself moves a candidate
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var player: Dictionary = engine.state().players[MatchRecords.SIDE_PLAYER]
	var hero: int = int(player.hero.entity_id)
	player.weapon = null
	var lists: Array = []
	resolver.scripts[&"on_heal"] = [func(_e: RulesEngine, ctx: Dictionary) -> void: lists.append((ctx.candidates as Array).duplicate())]
	var ids: Dictionary = {}

	# Act
	engine.run_action(func() -> void:
		engine.apply_heal(hero, 1, null)
		ids["weapon"] = engine.equip_weapon(MatchRecords.SIDE_PLAYER, MatchBudgetFixtures.AXE)
		engine.apply_heal(hero, 1, null))

	# Assert
	assert_int(lists.size()).is_equal(2)
	assert_bool((lists[0] as Array).has(int(ids.weapon))).is_false()
	assert_bool((lists[1] as Array).has(int(ids.weapon))).override_failure_message("the equip did not reach the raise after it").is_true()
	engine.end_match()


func test_a_weapon_that_breaks_alone_leaves_the_candidates_of_the_next_step() -> void:
	# Arrange: a queued pass that heals, so a raise follows the death check that
	# breaks the weapon, with no board move in that check to refill the list
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var player: Dictionary = engine.state().players[MatchRecords.SIDE_PLAYER]
	var hero: int = int(player.hero.entity_id)
	var weapon: int = int(player.weapon.entity_id)
	var lists: Array = []
	resolver.scripts[&"on_heal"] = [func(_e: RulesEngine, ctx: Dictionary) -> void: lists.append((ctx.candidates as Array).duplicate())]
	var ran: Dictionary = {}
	resolver.add_trigger(&"on_heal", hero, "heal_again", func(e: RulesEngine, _ctx: Dictionary) -> void:
		if not ran.has("once"):
			ran["once"] = true
			e.apply_heal(hero, 1, null))

	# Act
	engine.run_action(func() -> void:
		engine.modify_durability(weapon, -MatchBudgetFixtures.AURA_WEAPON_DURABILITY)
		engine.apply_heal(hero, 1, null))

	# Assert: in the list at the first heal, gone from the one after it broke
	assert_int(lists.size()).is_equal(2)
	assert_bool((lists[0] as Array).has(weapon)).is_true()
	assert_bool((lists[1] as Array).has(weapon)).override_failure_message("a broken weapon stayed a candidate").is_false()
	engine.end_match()


func test_each_move_of_a_candidate_reaches_the_next_raise_in_one_action() -> void:
	# Arrange: the candidates of an `on_heal` raised after each move, all in one step
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var player: Dictionary = engine.state().players[MatchRecords.SIDE_PLAYER]
	var hero: int = int(player.hero.entity_id)
	var lists: Array = []
	resolver.scripts[&"on_heal"] = [func(_e: RulesEngine, ctx: Dictionary) -> void: lists.append((ctx.candidates as Array).duplicate())]
	var first: int = int(player.board[0].entity_id)
	var last: int = int(player.board[player.board.size() - 1].entity_id)
	var old_weapon: int = int(player.weapon.entity_id)

	# Act
	var ids: Dictionary = {}
	engine.run_action(func() -> void:
		engine.apply_heal(hero, 1, null)
		ids["summoned"] = engine.summon_minion(MatchRecords.SIDE_PLAYER, MatchBudgetFixtures.GRUNT, -1)
		engine.apply_heal(hero, 1, null)
		ids["transformed"] = engine.transform(first, MatchBudgetFixtures.WALL)
		engine.apply_heal(hero, 1, null)
		engine.return_to_hand(last)
		engine.apply_heal(hero, 1, null)
		ids["weapon"] = engine.equip_weapon(MatchRecords.SIDE_PLAYER, MatchBudgetFixtures.AXE)
		engine.apply_heal(hero, 1, null))

	# Assert: each list shows the move before it
	assert_int(lists.size()).is_equal(CANDIDATE_MOVES + 1)
	assert_bool((lists[1] as Array).has(int(ids.summoned))).override_failure_message("summon").is_true()
	assert_bool((lists[2] as Array).has(int(ids.transformed))).override_failure_message("transform in").is_true()
	assert_bool((lists[2] as Array).has(first)).override_failure_message("transform out").is_false()
	assert_bool((lists[3] as Array).has(last)).override_failure_message("bounce").is_false()
	assert_bool((lists[4] as Array).has(int(ids.weapon))).override_failure_message("equip in").is_true()
	assert_bool((lists[4] as Array).has(old_weapon)).override_failure_message("equip out").is_false()
	engine.end_match()


func test_a_death_reaches_the_candidates_of_the_on_minion_died_it_raises() -> void:
	# Arrange
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var lists: Array = []
	resolver.scripts[&"on_minion_died"] = [func(_e: RulesEngine, ctx: Dictionary) -> void: lists.append((ctx.candidates as Array).duplicate())]
	var victim: int = int(engine.state().players[MatchRecords.SIDE_BOSS].board[0].entity_id)
	var hero: int = int(engine.state().players[MatchRecords.SIDE_PLAYER].hero.entity_id)

	# Act: an earlier raise in the same action fills the buffer first
	engine.run_action(func() -> void:
		engine.apply_heal(hero, 1, null)
		engine.destroy(victim))

	# Assert
	assert_int(lists.size()).is_equal(1)
	assert_bool((lists[0] as Array).has(victim)).is_false()
	engine.end_match()


func test_consecutive_raises_each_see_the_board_as_it_is_then() -> void:
	# Arrange: the reused buffer must not answer with an earlier raise's list
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var sizes: Array[int] = []
	resolver.scripts[&"on_summon"] = [func(_e: RulesEngine, ctx: Dictionary) -> void: sizes.append((ctx.candidates as Array).size())]
	var before: int = engine._candidates_in_order().size()

	# Act
	engine.run_action(func() -> void:
		for _i: int in CONSECUTIVE_SUMMONS:
			@warning_ignore("return_value_discarded")
			engine.summon_minion(MatchRecords.SIDE_BOSS, MatchBudgetFixtures.GRUNT, -1))

	# Assert: one more candidate at each raise
	assert_int(sizes.size()).is_equal(CONSECUTIVE_SUMMONS)
	for i: int in sizes.size():
		assert_int(sizes[i]).is_equal(before + i + 1)
	engine.end_match()
