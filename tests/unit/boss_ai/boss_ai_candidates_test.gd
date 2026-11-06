## Unit tests for the Boss AI candidate set (story boss-ai-match-driver/
## story-005; design/gdd/boss-ai.md C4 pre-filter, C6 op values and derived
## annotations, F1 `f_hp`, F7 `max_evals_per_action`, F9 `hero_power`, A12,
## A17; ADR-0006; TR-boss-ai-001).
##
## Board setups come from `tests/fixtures/boss_ai/` through [BossAiBoard] on
## the production `EffectResolver`. `max_evals_per_action` is read from the
## resolved profile (the fixture lowers it through a `boss_overrides` entry),
## never written as 40 / 120 / 250. "Simulated" is counted as evaluations:
## `Scorer.score_all` awaits one `checkpoint()` per candidate it scores.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS


## A [PlannerTask] that counts `checkpoint()` calls (one per evaluation).
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


# --- helpers -----------------------------------------------------------------

func _candidate_set(db: BossAiBoard.FakeCardDatabase, profile: Dictionary) -> CandidateSet:
	return CandidateSet.new(db, BossAiBoard.stub_config().op_values, profile.synergy_tags)


func _hand_def(engine: RulesEngine, command: Dictionary) -> String:
	return str(engine.state().players[SIDE_BOSS].hand[int(command.hand_index)].def_id)


func _plays_of(engine: RulesEngine, commands: Array, def_id: String) -> Array:
	return commands.filter(func(c: Dictionary) -> bool: return str(c.type) == MatchRecords.CMD_PLAY_CARD and _hand_def(engine, c) == def_id)


func _of_type(commands: Array, type: String) -> Array:
	return commands.filter(func(c: Dictionary) -> bool: return str(c.type) == type)


func _score_collected(db: BossAiBoard.FakeCardDatabase, engine: RulesEngine, profile: Dictionary, planner: PlannerTask) -> Array:
	var base: RulesEngine = engine.clone()
	var candidates: Array = _candidate_set(db, profile).collect(base, profile, profile.budgets)
	var scored: Array = await Scorer.new(db, BossAiBoard.keyword_values()).score_all(base, candidates, profile, Scorer.MODE_NORMAL, {}, planner)
	base.end_match()
	return scored


# --- A12: the hero-power rule ------------------------------------------------------

func test_spare_mana_plays_the_three_cost_card_instead_of_the_hero_power() -> void:
	# Arrange — 3 mana, a 3-cost card in hand, rules.hero_power = spare_mana
	var fixture: Dictionary = BossAiBoard.read("hero_power_spare_mana")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)

	# Act
	var scored: Array = await _score_collected(db, engine, profile, ImmediatePlannerTask.new())

	# Assert
	assert_str(str(profile.rules.hero_power)).is_equal(CandidateSet.HERO_POWER_SPARE_MANA)
	assert_str(str(scored[0].command.type)).is_equal(MatchRecords.CMD_PLAY_CARD)
	var power: Array = scored.filter(func(e: Dictionary) -> bool: return str(e.command.type) == MatchRecords.CMD_USE_HERO_POWER)
	assert_int(power.size()).is_equal(1)
	assert_float(power[0].features.f_hp).is_equal(-1.0)


func test_a_boss_with_no_hero_power_collects_no_hero_power_candidate() -> void:
	# Arrange — every MVP boss: `hero_power: null` seats an empty, unused power
	var fixture: Dictionary = BossAiBoard.read("hero_power_spare_mana")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	engine.state().players[SIDE_BOSS].hero_power = {"def_id": "", "used_this_turn": false}

	# Act
	var scored: Array = await _score_collected(db, engine, profile, ImmediatePlannerTask.new())

	# Assert
	assert_array(_of_type(engine.legal_commands(), MatchRecords.CMD_USE_HERO_POWER)).is_empty()
	assert_array(scored.filter(func(e: Dictionary) -> bool: return str(e.command.type) == MatchRecords.CMD_USE_HERO_POWER)).is_empty()
	assert_int(scored.size()).is_greater(0)


func test_spare_mana_uses_the_hero_power_when_no_card_is_playable() -> void:
	# Arrange — 2 mana and no 2-cost card
	var fixture: Dictionary = BossAiBoard.read("hero_power_spare_mana")
	fixture.boss.mana = int(fixture.expect.short_mana)
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)

	# Act
	var scored: Array = await _score_collected(db, engine, profile, ImmediatePlannerTask.new())

	# Assert
	assert_array(_of_type(engine.legal_commands(), MatchRecords.CMD_PLAY_CARD)).is_empty()
	assert_str(str(scored[0].command.type)).is_equal(MatchRecords.CMD_USE_HERO_POWER)
	assert_float(scored[0].features.f_hp).is_equal(1.0)


func test_hero_power_feature_follows_each_f9_rule() -> void:
	# Act / Assert — F9: always +1, spare_mana +1 only with no playable card else −1, never −1, value 0
	assert_float(CandidateSet.hero_power_feature(CandidateSet.HERO_POWER_ALWAYS, true)).is_equal(1.0)
	assert_float(CandidateSet.hero_power_feature(CandidateSet.HERO_POWER_ALWAYS, false)).is_equal(1.0)
	assert_float(CandidateSet.hero_power_feature(CandidateSet.HERO_POWER_SPARE_MANA, true)).is_equal(-1.0)
	assert_float(CandidateSet.hero_power_feature(CandidateSet.HERO_POWER_SPARE_MANA, false)).is_equal(1.0)
	assert_float(CandidateSet.hero_power_feature(CandidateSet.HERO_POWER_NEVER, false)).is_equal(-1.0)
	assert_float(CandidateSet.hero_power_feature(CandidateSet.HERO_POWER_VALUE, false)).is_equal(0.0)


func test_scored_hero_power_carries_the_profile_rule_and_other_actions_carry_zero() -> void:
	# Arrange — the same board under `never` and `value`
	var fixture: Dictionary = BossAiBoard.read("hero_power_spare_mana")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var never: Dictionary = BossAiBoard.profile(fixture)
	never.rules.hero_power = CandidateSet.HERO_POWER_NEVER
	var value: Dictionary = BossAiBoard.profile(fixture)
	value.rules.hero_power = CandidateSet.HERO_POWER_VALUE

	# Act
	var under_never: Array = await _score_collected(db, engine, never, ImmediatePlannerTask.new())
	var under_value: Array = await _score_collected(db, engine, value, ImmediatePlannerTask.new())

	# Assert
	for entry: Dictionary in under_never:
		var expected: float = -1.0 if str(entry.command.type) == MatchRecords.CMD_USE_HERO_POWER else 0.0
		assert_float(entry.features.f_hp).override_failure_message(str(entry.command)).is_equal(expected)
	for entry: Dictionary in under_value:
		assert_float(entry.features.f_hp).is_equal(0.0)


# --- A17: positions -------------------------------------------------------------------

func test_position_sensitive_minion_keeps_every_offered_position() -> void:
	# Arrange — 3 boss minions: legal_commands offers 4 positions per minion play
	var fixture: Dictionary = BossAiBoard.read("adjacent_minion")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var positions: int = int(fixture.expect.positions)
	var planner: CountingPlanner = CountingPlanner.new()

	# Act
	var base: RulesEngine = engine.clone()
	var candidates: Array = _candidate_set(db, profile).collect(base, profile, profile.budgets)
	var scored: Array = await Scorer.new(db, BossAiBoard.keyword_values()).score_all(base, candidates, profile, Scorer.MODE_NORMAL, {}, planner)
	base.end_match()

	# Assert — the adjacent-Battlecry minion: 4 simulated; the plain one: 1, at board.size
	assert_int(_plays_of(engine, engine.legal_commands(), str(fixture.expect.sensitive)).size()).is_equal(positions)
	assert_int(_plays_of(engine, candidates, str(fixture.expect.sensitive)).size()).is_equal(positions)
	var plain: Array = _plays_of(engine, candidates, str(fixture.expect.plain))
	assert_int(plain.size()).is_equal(1)
	assert_int(int(plain[0].position)).is_equal(engine.state().players[SIDE_BOSS].board.size())
	assert_int(planner.checkpoints).is_equal(candidates.size())
	assert_int(scored.size()).is_equal(candidates.size())


func test_derive_annotations_reads_selectors_triggers_and_tags() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("adjacent_minion")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var candidates: CandidateSet = CandidateSet.new(db, BossAiBoard.stub_config().op_values, ["battlecry", "wall"])
	var tagged: Dictionary = CardFactory.make_minion("bai_test_wall", 1, 0, 4, [], {"tags": ["wall"]})

	# Act
	var sensitive: Dictionary = candidates.derive_annotations(db.card(str(fixture.expect.sensitive)))
	var plain: Dictionary = candidates.derive_annotations(db.card(str(fixture.expect.plain)))
	var wall: Dictionary = candidates.derive_annotations(tagged)

	# Assert
	assert_bool(sensitive.position_sensitive).is_true()
	assert_bool(sensitive.aoe).is_false()
	assert_array(sensitive.synergy_tags_hit).contains_exactly(["battlecry"])
	assert_bool(plain.position_sensitive).is_false()
	assert_array(plain.synergy_tags_hit).is_empty()
	assert_array(wall.synergy_tags_hit).contains_exactly(["wall"])


func test_annotation_memo_is_per_candidate_set_instance() -> void:
	# Arrange — a definition edited after its first derivation
	var fixture: Dictionary = BossAiBoard.read("adjacent_minion")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var op_values: Dictionary = BossAiBoard.stub_config().op_values
	var first: CandidateSet = CandidateSet.new(db, op_values, [])
	var second: CandidateSet = CandidateSet.new(db, op_values, [])
	var def: Dictionary = (db.card(str(fixture.expect.plain)) as Dictionary).duplicate(true)
	var before: bool = first.derive_annotations(def).position_sensitive
	def.effects = (db.card(str(fixture.expect.sensitive)) as Dictionary).effects.duplicate(true)

	# Act
	var memoised: bool = first.derive_annotations(def).position_sensitive
	var fresh: bool = second.derive_annotations(def).position_sensitive

	# Assert — the first instance answers from its memo; the second derives its own
	assert_bool(before).is_false()
	assert_bool(memoised).is_false()
	assert_bool(fresh).is_true()


# --- C4 / C6: the op_value pre-filter ---------------------------------------------------

func test_prefilter_keeps_exactly_max_evals_ranked_by_op_value_with_end_turn() -> void:
	# Arrange — 24 candidates after position filtering, max_evals_per_action from the profile
	var fixture: Dictionary = BossAiBoard.read("wide_hand_prefilter")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var cap: int = int(profile.budgets.max_evals_per_action)
	var picker: CandidateSet = _candidate_set(db, profile)
	var base: RulesEngine = engine.clone()
	var all: Array = picker.collect(base, profile, {"max_evals_per_action": int(fixture.expect.filtered)})
	var planner: CountingPlanner = CountingPlanner.new()

	# Act
	var kept: Array = picker.collect(base, profile, profile.budgets)
	var scored: Array = await Scorer.new(db, BossAiBoard.keyword_values()).score_all(base, kept, profile, Scorer.MODE_NORMAL, {}, planner)

	# Assert — exactly `cap` simulated, end_turn among them, ranked by op_value × targets
	assert_int(all.size()).is_equal(int(fixture.expect.filtered))
	assert_int(kept.size()).is_equal(cap)
	assert_int(planner.checkpoints).is_equal(cap)
	assert_int(_of_type(kept, MatchRecords.CMD_END_TURN).size()).is_equal(1)
	assert_int(_plays_of(engine, kept, str(fixture.expect.aoe)).size()).is_equal(1)
	assert_array(_plays_of(engine, kept, str(fixture.expect.body))).is_empty()
	var lowest_kept: float = INF
	for command: Dictionary in kept:
		if str(command.type) != MatchRecords.CMD_END_TURN:
			lowest_kept = minf(lowest_kept, picker.op_value(command, base))
	for command: Dictionary in all:
		if not kept.has(command):
			assert_float(picker.op_value(command, base)).override_failure_message(str(command)).is_less_equal(lowest_kept)
	# no unsimulated candidate is chosen; the decision carries at most 3 alternatives
	assert_bool(kept.has(scored[0].command)).is_true()
	assert_int(Scorer.alternatives(scored).size()).is_equal(Scorer.ALTERNATIVES_MAX)
	base.end_match()


func test_prefilter_keeps_end_turn_even_when_it_ranks_last() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("wide_hand_prefilter")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var picker: CandidateSet = _candidate_set(db, profile)
	var base: RulesEngine = engine.clone()

	# Act
	var kept: Array = picker.collect(base, profile, profile.budgets)
	var end_turn: Dictionary = _of_type(kept, MatchRecords.CMD_END_TURN)[0]

	# Assert — end_turn's op value is the lowest of all, yet it is kept
	for command: Dictionary in kept:
		assert_float(picker.op_value(command, base)).is_greater_equal(picker.op_value(end_turn, base))
	assert_int(_of_type(kept, MatchRecords.CMD_END_TURN).size()).is_equal(1)
	base.end_match()


func test_prefilter_is_off_when_candidates_equal_max_evals() -> void:
	# Arrange — the boundary: exactly as many candidates as the budget
	var fixture: Dictionary = BossAiBoard.read("wide_hand_prefilter")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var base: RulesEngine = engine.clone()
	var filtered: int = int(fixture.expect.filtered)

	# Act
	var kept: Array = _candidate_set(db, profile).collect(base, profile, {"max_evals_per_action": filtered})

	# Assert — nothing dropped: both vanilla bodies (the lowest-ranked plays) stay
	assert_int(kept.size()).is_equal(filtered)
	assert_int(_plays_of(engine, kept, str(fixture.expect.body)).size()).is_equal(2)
	base.end_match()


func test_op_value_multiplies_by_targets_and_values_structural_ops() -> void:
	# Arrange — the aoe spell reaches 3 enemy minions; a body is C7's buff × (atk + hp) / 4
	var fixture: Dictionary = BossAiBoard.read("wide_hand_prefilter")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var op_values: Dictionary = BossAiBoard.stub_config().op_values
	var picker: CandidateSet = _candidate_set(db, profile)
	var base: RulesEngine = engine.clone()
	var legal: Array = base.legal_commands()
	var enemies: int = engine.state().players[SIDE_PLAYER].board.size()
	var nested: Dictionary = CardFactory.make_spell("bai_test_twice", 1, [CardFactory.make_effect("cast", [
		CardFactory.make_op("repeat", {"times": 2, "ops": [CardFactory.make_op("damage", {"amount": 1, "targets": "enemy_hero"})]}),
		CardFactory.make_op("aura", {}),
		CardFactory.make_op("discard", {}),
	])])

	# Act
	var aoe: float = picker.op_value(_plays_of(engine, legal, str(fixture.expect.aoe))[0], base)
	var body: float = picker.op_value(_plays_of(engine, legal, str(fixture.expect.body))[0], base)
	var structural: float = picker.def_value(nested, base, SIDE_BOSS)

	# Assert — damage × 3; buff × (2+2)/4; repeat → its inner damage, aura → buff, unvalued `discard` → 1.0
	assert_float(aoe).is_equal_approx(float(op_values.damage) * enemies, 1e-9)
	assert_float(body).is_equal_approx(float(op_values.buff) * 1.0, 1e-9)
	assert_float(structural).is_equal_approx(float(op_values.damage) + float(op_values.buff) + CandidateSet.OP_UNVALUED, 1e-9)
	base.end_match()


func test_op_value_counts_two_adjacent_targets_and_adds_the_equip_row_for_a_weapon() -> void:
	# Arrange — two boss minions on board (wide_hand_prefilter); a 2/3 weapon in hand (feature_terms)
	var fixture: Dictionary = BossAiBoard.read("wide_hand_prefilter")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var op_values: Dictionary = BossAiBoard.stub_config().op_values
	var base: RulesEngine = engine.clone()
	var own_minions: int = engine.state().players[SIDE_BOSS].board.size()
	var adjacent: Dictionary = CardFactory.make_spell("bai_test_rally_near", 1, [CardFactory.make_effect("cast", [CardFactory.make_op("buff", {"attack": 1})], {}, {"targets": "adjacent"})])
	var armoury: Dictionary = BossAiBoard.read("feature_terms")
	var armoury_db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(armoury)
	var armed: RulesEngine = BossAiBoard.engine(armoury, armoury_db)
	var armed_base: RulesEngine = armed.clone()
	var weapon_play: Array = _plays_of(armed, armed_base.legal_commands(), str(armoury.expect.weapon))

	# Act
	var near: float = _candidate_set(db, profile).def_value(adjacent, base, SIDE_BOSS)
	var weapon: float = _candidate_set(armoury_db, BossAiBoard.profile(armoury)).op_value(weapon_play[0], armed_base)

	# Assert — `adjacent` yields up to 2 of the owner's minions (C6, F6
	# max_targets); a weapon with no effects is its `equip` row alone (the stub
	# has none: the Edge Cases' unvalued 1.0)
	assert_int(own_minions).is_greater_equal(EffectSchema.F6_MAX_TARGETS_ADJACENT)
	assert_float(near).is_equal_approx(float(op_values.buff) * EffectSchema.F6_MAX_TARGETS_ADJACENT, 1e-9)
	assert_float(weapon).is_equal_approx(float(op_values.get("equip", CandidateSet.OP_UNVALUED)), 1e-9)
	base.end_match()
	armed_base.end_match()


# --- C4 / C6: attacks under the pre-filter (code review 2026-11-04, BAI-005 S4) ---------------

func test_prefilter_never_drops_a_lethal_face_attack_or_the_best_move() -> void:
	# Arrange — 32 candidates, cap 10; both face attacks are lethal
	var fixture: Dictionary = BossAiBoard.read("prefilter_lethal_attack")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var picker: CandidateSet = _candidate_set(db, profile)
	var scorer: Scorer = Scorer.new(db, BossAiBoard.keyword_values())
	var base: RulesEngine = engine.clone()
	var hero: int = int(engine.state().players[SIDE_PLAYER].hero.entity_id)
	var legal: Array = base.legal_commands()
	var face_attacks: Array = _of_type(legal, MatchRecords.CMD_ATTACK).filter(func(c: Dictionary) -> bool: return int(c.target_id) == hero)

	# Act
	var kept: Array = picker.collect(base, profile, profile.budgets)
	var over_kept: Array = await scorer.score_all(base, kept, profile, Scorer.MODE_NORMAL, {}, ImmediatePlannerTask.new())
	var over_all: Array = await scorer.score_all(base, legal, profile, Scorer.MODE_NORMAL, {}, ImmediatePlannerTask.new())

	# Assert — the cap engaged, every lethal face attack survived it, and the
	# best move over the kept set is the best over every legal command
	assert_int(legal.size()).is_equal(int(fixture.expect.legal))
	assert_int(kept.size()).is_equal(int(profile.budgets.max_evals_per_action))
	assert_int(face_attacks.size()).is_equal(engine.state().players[SIDE_BOSS].board.size())
	for attack: Dictionary in face_attacks:
		assert_bool(kept.has(attack)).override_failure_message("lethal %s dropped" % str(attack)).is_true()
	assert_dict(over_kept[0].command).is_equal(over_all[0].command)
	assert_float(over_kept[0].score).is_equal(over_all[0].score)
	base.end_match()


func test_attack_op_value_adds_the_destroy_row_for_a_kill_and_ranks_lethal_first() -> void:
	# Arrange — a 1-attack minion into a 1/1 (kills), into a 1/2 (does not), into the hero at 1
	var fixture: Dictionary = BossAiBoard.read("prefilter_lethal_attack")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var op_values: Dictionary = BossAiBoard.stub_config().op_values
	var picker: CandidateSet = _candidate_set(db, profile)
	var base: RulesEngine = engine.clone()
	var attacker: int = int(engine.state().players[SIDE_BOSS].board[0].entity_id)
	var killable: int = BossAiBoard.ids_of(engine, SIDE_PLAYER, str(fixture.expect.killable))[0]
	var survivor: int = BossAiBoard.ids_of(engine, SIDE_PLAYER, str(fixture.expect.survivor))[0]
	var hero: int = int(engine.state().players[SIDE_PLAYER].hero.entity_id)

	# Act
	var kill: float = picker.op_value(MatchRecords.attack(SIDE_BOSS, attacker, killable), base)
	var chip: float = picker.op_value(MatchRecords.attack(SIDE_BOSS, attacker, survivor), base)
	var lethal: float = picker.op_value(MatchRecords.attack(SIDE_BOSS, attacker, hero), base)

	# Assert — one damage op on one target; a kill adds the `destroy` row (the
	# stub has none: the Edge Cases' unvalued 1.0); a lethal face attack ranks first
	assert_float(chip).is_equal_approx(float(op_values.damage), 1e-9)
	assert_float(kill).is_equal_approx(float(op_values.damage) + float(op_values.get("destroy", CandidateSet.OP_UNVALUED)), 1e-9)
	assert_float(lethal).is_equal(CandidateSet.LETHAL_RANK)
	base.end_match()
