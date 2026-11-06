## The event feed's pure half and what reaches it (match-ui F5, L18, U10; story 014): the
## row budget, the "+N more" row, the ticker, name resolution, and hidden information.
extends GdUnitTestSuite

const ROOT_SEQ: int = 40
const COLLAPSE: int = 6
const CHAIN_CHILDREN: int = 20
const NEWEST: int = 3
const BOSS_CARD: String = "boss_rat"
const BOSS_INSTANCE: int = 77
const BOSS_HERO: int = 2
const PLAYER_HERO: int = 1


func _body() -> Dictionary:
	return MatchUiTestConfig.body()


func _chain(children: int) -> Array[Dictionary]:
	var lines: Array[Dictionary] = [{"key": "feed.spell_cast", "params": {}, "group_id": ROOT_SEQ, "seq": ROOT_SEQ}]
	for i: int in children:
		lines.append({"key": "feed.minion_died", "params": {}, "group_id": ROOT_SEQ, "seq": ROOT_SEQ + 1 + i})
	return lines


func _names() -> FeedNames:
	var names := FeedNames.new(func(card_id: String) -> Dictionary:
		return {"name_key": "name." + card_id} if card_id != "" else {})
	names.set_heroes("hero_war", "boss_torchbearer")
	return names


func _event(seq: int, type: String, payload: Dictionary) -> Dictionary:
	return {"seq": seq, "turn": 1, "type": type, "payload": payload, "cause_seq": 0}


# --- F5 ---------------------------------------------------------------------------

func test_f5_twenty_children_take_seven_rows() -> void:
	# Act / Assert
	assert_int(FeedLines.line_budget(CHAIN_CHILDREN, COLLAPSE)).is_equal(7)


func test_f5_at_the_collapse_limit_there_is_no_more_row() -> void:
	# Act / Assert
	assert_int(FeedLines.line_budget(COLLAPSE, COLLAPSE)).is_equal(COLLAPSE)
	assert_int(FeedLines.line_budget(COLLAPSE + 1, COLLAPSE)).is_equal(COLLAPSE + 1)
	assert_int(FeedLines.line_budget(0, COLLAPSE)).is_equal(0)


func test_rows_cut_a_long_group_to_six_children_and_a_more_row_with_the_rest() -> void:
	# Act
	var rows: Array[Dictionary] = FeedLines.rows(_chain(CHAIN_CHILDREN), COLLAPSE, {})

	# Assert: the head, six children, "+14 more"
	assert_int(rows.size()).is_equal(1 + COLLAPSE + 1)
	assert_str(String(rows[0].kind)).is_equal(String(FeedLines.ROW_ROOT))
	assert_str(String(rows[1].kind)).is_equal(String(FeedLines.ROW_CHILD))
	assert_str(String(rows[7].kind)).is_equal(String(FeedLines.ROW_MORE))
	assert_int(int(rows[7].hidden)).is_equal(CHAIN_CHILDREN - COLLAPSE)


func test_an_expanded_group_shows_every_child_and_no_more_row() -> void:
	# Act
	var rows: Array[Dictionary] = FeedLines.rows(_chain(CHAIN_CHILDREN), COLLAPSE, {ROOT_SEQ: true})

	# Assert
	assert_int(rows.size()).is_equal(1 + CHAIN_CHILDREN)
	for row: Dictionary in rows:
		assert_str(String(row.kind)).is_not_equal(String(FeedLines.ROW_MORE))


func test_a_group_whose_root_made_no_line_has_no_head() -> void:
	# Arrange: the root was diagnostic or silent, so every line is a child
	var lines: Array[Dictionary] = _chain(2).slice(1)

	# Act
	var rows: Array[Dictionary] = FeedLines.rows(lines, COLLAPSE, {})

	# Assert
	assert_int(rows.size()).is_equal(2)
	assert_str(String(rows[0].kind)).is_equal(String(FeedLines.ROW_CHILD))


func test_groups_keep_their_order_of_first_appearance() -> void:
	# Arrange
	var lines: Array[Dictionary] = [
		{"key": "a", "params": {}, "group_id": 9, "seq": 9},
		{"key": "b", "params": {}, "group_id": 3, "seq": 3},
		{"key": "c", "params": {}, "group_id": 9, "seq": 10},
	]

	# Act
	var rows: Array[Dictionary] = FeedLines.rows(lines, COLLAPSE, {})

	# Assert: group 9 stays together, ahead of group 3
	assert_str(str(rows[0].line.key)).is_equal("a")
	assert_str(str(rows[1].line.key)).is_equal("c")
	assert_str(str(rows[2].line.key)).is_equal("b")


func test_the_ticker_holds_the_newest_lines_oldest_first() -> void:
	# Arrange
	var lines: Array[Dictionary] = _chain(5)

	# Act
	var ticker: Array[Dictionary] = FeedLines.newest(lines, NEWEST)

	# Assert
	assert_int(ticker.size()).is_equal(NEWEST)
	assert_int(int(ticker[0].seq)).is_equal(ROOT_SEQ + 3)
	assert_int(int(ticker[2].seq)).is_equal(ROOT_SEQ + 5)


func test_a_shorter_list_than_the_ticker_comes_back_whole() -> void:
	# Act / Assert
	assert_int(FeedLines.newest(_chain(1), NEWEST).size()).is_equal(2)


func test_quiet_types_are_kept_out_of_what_is_shown_only() -> void:
	# Arrange
	var quiet: Dictionary = FeedLines.quiet_keys(["spell_cast"])

	# Act
	var shown: Array[Dictionary] = FeedLines.shown(_chain(2), quiet)

	# Assert
	assert_int(shown.size()).is_equal(2)
	assert_str(str(shown[0].key)).is_equal("feed.minion_died")


func test_the_view_state_retains_only_feed_max_lines_and_counts_every_one() -> void:
	# Arrange
	var body: Dictionary = _body()
	var view := MatchViewState.new(body)
	var cap: int = int(body.feed_max_lines)

	# Act
	for i: int in cap + 5:
		view.apply(_event(i + 1, "counter_changed", {"source_id": 1, "key": "k", "value": i}))

	# Assert
	assert_int(view.feed_lines.size()).is_equal(cap)
	assert_int(view.feed_total).is_equal(cap + 5)
	assert_int(int(view.feed_lines[0].seq)).is_equal(6)


# --- L18 --------------------------------------------------------------------------

func test_l18_diagnostics_make_no_step_no_line_and_no_state_change() -> void:
	for type: String in ["ai_decision", "ai_plan_aborted", "ai_fault"]:
		# Arrange
		var view := MatchViewState.new(_body())
		var before: Dictionary = view.snapshot()

		# Act
		var steps: Array[AnimStep] = view.apply(_event(1, type, {"diagnostic": true, "side": "boss"}))

		# Assert
		assert_array(steps).override_failure_message(type).is_empty()
		assert_array(view.feed_lines).override_failure_message(type).is_empty()
		assert_dict(view.snapshot()).override_failure_message(type).is_equal(before)
		assert_array(view.debug_buffer).override_failure_message(type).is_empty()


func test_l18_silent_events_make_no_step_and_no_line() -> void:
	for type: String in ["turn_reset", "card_to_graveyard"]:
		# Arrange
		var view := MatchViewState.new(_body())

		# Act
		var steps: Array[AnimStep] = view.apply(_event(1, type, {"side": "player"}))

		# Assert
		assert_array(steps).override_failure_message(type).is_empty()
		assert_int(view.feed_total).override_failure_message(type).is_equal(0)


func test_l18_with_the_overlay_on_ai_decision_fills_the_buffer_and_a_diag_line() -> void:
	# Arrange
	var view := MatchViewState.new(_body())
	view.set_debug_overlay(true)

	# Act
	var steps: Array[AnimStep] = view.apply(_event(1, "ai_decision", {"diagnostic": true, "side": "boss"}))

	# Assert
	assert_array(steps).is_empty()
	assert_int(view.debug_buffer.size()).is_equal(1)
	assert_str(str(view.feed_lines[0].key)).is_equal("feed.diag.ai_decision")


func test_l18_counter_changed_sets_the_counter_with_one_line_and_no_step() -> void:
	# Arrange
	var view := MatchViewState.new(_body())

	# Act
	var steps: Array[AnimStep] = view.apply(_event(1, "counter_changed", {"source_id": 12, "key": "charges", "value": 3}))

	# Assert
	assert_array(steps).is_empty()
	assert_int(int(view.counters[12]["charges"])).is_equal(3)
	assert_int(view.feed_lines.size()).is_equal(1)
	assert_str(str(view.feed_lines[0].key)).is_equal("feed.counter_changed")


# --- names and hidden information --------------------------------------------------

func test_a_boss_draw_leaves_no_card_id_in_its_line() -> void:
	# Arrange
	var view := MatchViewState.new(_body())

	# Act
	view.apply(_event(1, "card_drawn", {"side": "boss", "instance_id": BOSS_INSTANCE, "card_id": BOSS_CARD, "hand_size": 4}))

	# Assert
	assert_bool((view.feed_lines[0].params as Dictionary).has("card_id")).is_false()
	assert_str(str(view.feed_lines[0])).not_contains(BOSS_CARD)


func test_a_boss_card_added_to_hand_leaves_no_card_id_in_its_line() -> void:
	# Arrange
	var view := MatchViewState.new(_body())

	# Act
	view.apply(_event(1, "card_added_to_hand", {"side": "boss", "instance_id": BOSS_INSTANCE, "card_id": BOSS_CARD, "hand_size": 4}))

	# Assert
	assert_str(str(view.feed_lines[0])).not_contains(BOSS_CARD)


func test_a_boss_discover_shows_no_option_in_any_line() -> void:
	# Arrange
	var view := MatchViewState.new(_body())

	# Act
	view.apply(_event(1, "discover_offered", {"side": "boss", "kind": "discover", "option_card_ids": [BOSS_CARD], "source_id": 9, "effect_id": "e"}))
	view.apply(_event(2, "choice_requested", {"side": "boss", "kind": "discover", "options": [BOSS_CARD], "source_id": 9, "effect_id": "e"}))

	# Assert
	assert_str(str(view.feed_lines)).not_contains(BOSS_CARD)
	assert_str(str(view.pending_choice)).not_contains(BOSS_CARD)


func test_a_boss_discover_pick_shows_no_card_in_its_line() -> void:
	# Arrange: the pick goes to the boss's hand, and U10 keeps that hidden until played
	var view := MatchViewState.new(_body())

	# Act
	view.apply(_event(1, "discover_picked", {"side": "boss", "picked_index": 0, "picked_card_id": BOSS_CARD}))

	# Assert
	assert_str(str(view.feed_lines)).not_contains(BOSS_CARD)


func test_a_player_discover_pick_keeps_its_card_in_the_line() -> void:
	# Arrange
	var view := MatchViewState.new(_body())

	# Act
	view.apply(_event(1, "discover_picked", {"side": "player", "picked_index": 0, "picked_card_id": BOSS_CARD}))

	# Assert: `{card}` names the pick
	assert_str(str(view.feed_lines)).contains(BOSS_CARD)
	assert_str(str(FeedLines.values_for(view.feed_lines[0], _names()).card)).is_equal("name." + BOSS_CARD)


func test_a_card_the_names_never_met_reads_as_a_card() -> void:
	# Arrange
	var names: FeedNames = _names()
	var line: Dictionary = {"key": "feed.card_drawn", "params": {"side": "boss", "instance_id": BOSS_INSTANCE}, "group_id": 1, "seq": 1}
	names.learn(line)

	# Act
	var values: Dictionary = FeedLines.values_for(line, names)

	# Assert: nothing named it, so its id stays someone and its card stays a card
	assert_str(str(values.card)).is_equal(String(TranslationServer.translate(FeedNames.KEY_A_CARD)))
	assert_str(names.of(BOSS_INSTANCE)).is_equal(String(TranslationServer.translate(FeedNames.KEY_SOMEONE)))


func test_an_id_is_learned_from_a_line_and_outlives_the_entity() -> void:
	# Arrange
	var names: FeedNames = _names()

	# Act
	names.learn({"key": "feed.minion_summoned", "params": {"entity_id": 31, "card_id": "neutral_x"}})

	# Assert: the key comes back through `card_text`, never the payload's string
	assert_str(names.of(31)).is_equal("name.neutral_x")


func test_match_started_names_the_two_heroes() -> void:
	# Arrange
	var names: FeedNames = _names()

	# Act
	names.learn({"key": "feed.match_started", "params": {"hero_id": PLAYER_HERO, "boss_id": BOSS_HERO}})

	# Assert
	assert_str(names.of(PLAYER_HERO)).is_equal(tr("hero.hero_war.name"))
	assert_str(names.of(BOSS_HERO)).is_equal(tr("boss.boss_torchbearer.name"))


func test_a_null_source_reads_as_someone_without_an_error() -> void:
	# Arrange
	var names: FeedNames = _names()

	# Act / Assert: a fatigue source has no id
	assert_str(names.of(null)).is_equal(String(TranslationServer.translate(FeedNames.KEY_SOMEONE)))


func test_nested_params_never_reach_the_format_values() -> void:
	# Arrange
	var line: Dictionary = {"key": "k", "params": {"amount": 3, "command": {"type": "attack"}, "list": [1]}}

	# Act
	var values: Dictionary = FeedLines.values_for(line, _names())

	# Assert
	assert_int(int(values.amount)).is_equal(3)
	assert_bool(values.has("command")).is_false()
	assert_bool(values.has("list")).is_false()


func test_a_key_with_no_string_reads_as_the_key_so_the_gap_shows() -> void:
	# Act / Assert
	assert_str(FeedLines.text({"key": "feed.no_such_key", "params": {}}, _names())).is_equal("feed.no_such_key")
