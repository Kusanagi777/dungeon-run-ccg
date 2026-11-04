## Unit tests for the F1 / F2 terms the story-004 acceptance fixtures leave
## at 0 (code review 2026-11-04, BAI-004 S2: the f_self sign, f_heal,
## f_passive, the weapon BV, the Spell Damage and aura flat bonuses, DEFENSIVE
## through [method Scorer.score], the `aoe_seen_in` side filter, the [−1, 1]
## clamp; story boss-ai-match-driver/story-004; design/gdd/boss-ai.md C1.3,
## C5, F1, F2, F5, States and Transitions `DEFENSIVE`; TR-boss-ai-001).
##
## Each test isolates one term on `tests/fixtures/boss_ai/feature_terms.json`
## (production `EffectResolver`, [BossAiBoard]): two candidates that differ
## only in that term, or one whose only non-zero delta is it. The F2 flat
## bonuses are written out as the GDD states them (F2 variable table:
## Spell Damage +2 per point, aura +2; `BV(weapon) = attack · durability ·
## 0.8`; DEFENSIVE Taunt +0.5), because the number is the point.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const EPSILON: float = 1e-9
## F2 `flat_bonus`: Spell Damage per point, aura.
const GDD_FLAT_SPELL_DAMAGE: float = 2.0
const GDD_FLAT_AURA: float = 2.0
## F2 `BV(weapon)` factor.
const GDD_WEAPON_FACTOR: float = 0.8
## States and Transitions `DEFENSIVE`: Taunt minions gain +0.5 BV.
const GDD_DEFENSIVE_TAUNT_BV: float = 0.5


# --- helpers -----------------------------------------------------------------

## `[engine, db, profile, fixture]` at the boss's Main, its hero damaged by
## `expect.boss_damage`.
func _board(fixture_name: String = "feature_terms") -> Array:
	var fixture: Dictionary = BossAiBoard.read(fixture_name)
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	if fixture.expect.has("boss_damage"):
		engine.state().players[SIDE_BOSS].hero.damage_taken = int(fixture.expect.boss_damage)
	return [engine, db, BossAiBoard.profile(fixture), fixture]


func _score_all(engine: RulesEngine, db: Variant, profile: Dictionary, mode: StringName = Scorer.MODE_NORMAL) -> Array:
	var base: RulesEngine = engine.clone()
	var scored: Array = await Scorer.new(db, BossAiBoard.keyword_values()).score_all(base, base.legal_commands(), profile, mode, {}, ImmediatePlannerTask.new())
	base.end_match()
	return scored


## The scored `play_card` of the boss's hand card [param def_id].
func _play(scored: Array, engine: RulesEngine, def_id: String) -> Dictionary:
	var hand: Array = engine.state().players[SIDE_BOSS].hand
	for entry: Dictionary in scored:
		var command: Dictionary = entry.command
		if str(command.type) == MatchRecords.CMD_PLAY_CARD and str(hand[int(command.hand_index)].def_id) == def_id:
			return entry
	return {}


func _bv_norm(profile: Dictionary) -> float:
	return float(profile.rules.BV_NORM)


# --- F2 flat bonuses and the weapon BV, measured on the board --------------------

func test_spell_damage_minion_scores_two_board_value_per_point_above_a_vanilla_twin() -> void:
	# Arrange
	var setup: Array = _board()
	var engine: RulesEngine = setup[0]
	var expect: Dictionary = setup[3].expect

	# Act
	var scored: Array = await _score_all(engine, setup[1], setup[2])

	# Assert
	var sage: Dictionary = _play(scored, engine, str(expect.spell_damage))
	var pup: Dictionary = _play(scored, engine, str(expect.vanilla))
	var bonus: float = GDD_FLAT_SPELL_DAMAGE * float(expect.spell_damage_points)
	assert_float(sage.features.f_board - pup.features.f_board).is_equal_approx(bonus / _bv_norm(setup[2]), EPSILON)


func test_aura_minion_scores_the_aura_flat_bonus_above_a_vanilla_twin() -> void:
	# Arrange
	var setup: Array = _board()
	var engine: RulesEngine = setup[0]
	var expect: Dictionary = setup[3].expect

	# Act
	var scored: Array = await _score_all(engine, setup[1], setup[2])

	# Assert — the aura reaches no other friendly minion, so +2 is the whole gap
	var lord: Dictionary = _play(scored, engine, str(expect.aura))
	var pup: Dictionary = _play(scored, engine, str(expect.vanilla))
	assert_float(lord.features.f_board - pup.features.f_board).is_equal_approx(GDD_FLAT_AURA / _bv_norm(setup[2]), EPSILON)


func test_weapon_play_scores_the_f2_weapon_board_value() -> void:
	# Arrange
	var setup: Array = _board()
	var engine: RulesEngine = setup[0]
	var expect: Dictionary = setup[3].expect

	# Act
	var scored: Array = await _score_all(engine, setup[1], setup[2])

	# Assert — BV(weapon) = 2 · 3 · 0.8, the only board change
	var axe: Dictionary = _play(scored, engine, str(expect.weapon))
	var value: float = float(expect.weapon_attack) * float(expect.weapon_durability) * GDD_WEAPON_FACTOR
	assert_float(axe.features.f_board).is_equal_approx(value / _bv_norm(setup[2]), EPSILON)


func test_defensive_mode_raises_a_taunt_play_by_the_taunt_bonus_through_score() -> void:
	# Arrange
	var setup: Array = _board()
	var engine: RulesEngine = setup[0]
	var expect: Dictionary = setup[3].expect

	# Act
	var normal: Array = await _score_all(engine, setup[1], setup[2], Scorer.MODE_NORMAL)
	var defensive: Array = await _score_all(engine, setup[1], setup[2], Scorer.MODE_DEFENSIVE)

	# Assert — the Taunt play gains +0.5 BV; a non-Taunt play does not
	var taunt_gap: float = _play(defensive, engine, str(expect.taunt)).features.f_board - _play(normal, engine, str(expect.taunt)).features.f_board
	var vanilla_gap: float = _play(defensive, engine, str(expect.vanilla)).features.f_board - _play(normal, engine, str(expect.vanilla)).features.f_board
	assert_float(taunt_gap).is_equal_approx(GDD_DEFENSIVE_TAUNT_BV / _bv_norm(setup[2]), EPSILON)
	assert_float(vanilla_gap).is_equal_approx(0.0, EPSILON)


# --- f_heal, f_self, f_passive ------------------------------------------------------

func test_heal_on_the_damaged_boss_hero_scores_healing_over_missing_health() -> void:
	# Arrange — boss hero missing 10, heal 4
	var setup: Array = _board()
	var engine: RulesEngine = setup[0]
	var expect: Dictionary = setup[3].expect

	# Act
	var scored: Array = await _score_all(engine, setup[1], setup[2])

	# Assert — F1 f_heal = 4 / 10; the vanilla play heals nothing
	var mend: Dictionary = _play(scored, engine, str(expect.heal))
	assert_float(mend.features.f_heal).is_equal_approx(float(expect.heal_amount) / float(expect.boss_damage), EPSILON)
	assert_float(_play(scored, engine, str(expect.vanilla)).features.f_heal).is_equal(0.0)


func test_hero_attack_into_a_minion_that_hits_back_scores_negative_f_self() -> void:
	# Arrange — equip the 2/3 weapon live, then the boss hero may attack the 3/4
	var setup: Array = _board()
	var engine: RulesEngine = setup[0]
	var expect: Dictionary = setup[3].expect
	var hand: Array = engine.state().players[SIDE_BOSS].hand
	var axe_index: int = hand.map(func(c: Dictionary) -> String: return str(c.def_id)).find(str(expect.weapon))
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_BOSS, axe_index, null, null)).accepted).is_true()
	var hero: Dictionary = engine.state().players[SIDE_BOSS].hero
	var health_before: int = engine.health(hero)
	var blocker: Dictionary = engine.state_snapshot(BossAiBoard.ids_of(engine, SIDE_PLAYER, str(expect.blocker))[0])

	# Act
	var scored: Array = await _score_all(engine, setup[1], setup[2])

	# Assert — F1 f_self = −dmg_to_boss_hero / boss_health_before (negative: the boss dislikes it)
	var hit: Dictionary = {}
	for entry: Dictionary in scored:
		if str(entry.command.type) == MatchRecords.CMD_ATTACK and int(entry.command.attacker_id) == int(hero.entity_id) and int(entry.command.target_id) == int(blocker.entity_id):
			hit = entry
	assert_dict(hit).is_not_empty()
	assert_float(hit.features.f_self).is_equal_approx(-float(engine.attack(blocker)) / float(health_before), EPSILON)
	assert_float(hit.features.f_self).is_less(0.0)


func test_synergy_tag_match_sets_f_passive_and_a_plain_card_does_not() -> void:
	# Arrange — a profile whose synergy_tags name the Taunt keyword (C6 synergy_match)
	var setup: Array = _board()
	var engine: RulesEngine = setup[0]
	var profile: Dictionary = setup[2]
	var expect: Dictionary = setup[3].expect
	profile["synergy_tags"] = [str(expect.synergy_tag)]

	# Act
	var scored: Array = await _score_all(engine, setup[1], profile)

	# Assert
	assert_float(_play(scored, engine, str(expect.taunt)).features.f_passive).is_equal(1.0)
	assert_float(_play(scored, engine, str(expect.vanilla)).features.f_passive).is_equal(0.0)


# --- C1.3 / F5: aoe_seen reads the opponent's plays only ---------------------------------

func test_aoe_seen_ignores_the_bosses_own_area_spell() -> void:
	# Arrange — the boss itself casts the all_enemy_minions spell
	var fixture: Dictionary = BossAiBoard.read("aoe_seen_board")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = BossAiBoard.engine(fixture, db, [], log)
	BossAiBoard.add_to_hand(engine, SIDE_BOSS, str(fixture.aoe_cast))
	var hand_index: int = engine.state().players[SIDE_BOSS].hand.size() - 1
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_BOSS, hand_index, null, null)).accepted).is_true()

	# Act
	var seen_by_boss: bool = Scorer.aoe_seen_in(log.events, db, SIDE_PLAYER)
	var cast_by_boss: bool = Scorer.aoe_seen_in(log.events, db, SIDE_BOSS)

	# Assert — the boss's own Flamestrike never switches on the player-AoE cap
	assert_int(log.count(&"card_played")).is_equal(1)
	assert_bool(cast_by_boss).is_true()
	assert_bool(seen_by_boss).is_false()


# --- C5: each feature is clamped to [−1, 1] -------------------------------------------------

func test_board_swing_beyond_bv_norm_is_clamped_to_one() -> void:
	# Arrange — A14: removing the 6/6 swings BV by 12 > BV_NORM 10
	var fixture: Dictionary = BossAiBoard.read("fireball_targets")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var giant: int = BossAiBoard.ids_of(engine, SIDE_PLAYER, str(fixture.expect.target))[0]
	var raw_swing: float = float(engine.attack(engine.state_snapshot(giant)) + engine.health(engine.state_snapshot(giant)))

	# Act
	var scored: Array = await _score_all(engine, db, profile)

	# Assert
	var removal: Dictionary = {}
	for entry: Dictionary in scored:
		if str(entry.command.type) == MatchRecords.CMD_PLAY_CARD and entry.command.get("target_id") == giant:
			removal = entry
	assert_float(raw_swing / _bv_norm(profile)).is_greater(1.0)
	assert_float(removal.features.f_board).is_equal(1.0)
