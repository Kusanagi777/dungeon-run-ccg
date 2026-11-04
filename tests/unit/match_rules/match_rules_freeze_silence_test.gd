## Unit tests for Freeze, the thaw rule and Silence (story
## match-rules/story-015; design/gdd/match-rules.md C13 Freeze and Silence
## semantics, F6 Health, buff loss and Silence clamp, C4 End step 4 — thaw,
## Edge Cases "Keywords and status"; ADR-0007 — `silenced` is plain state the
## resolver reads to skip the entity's own triggers and aura emission).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan (turn 1, player Main). Minions are fixture moves
## (`MatchFactory.summon`), mutated through the engine primitives inside
## `run_action` so each action runs its C10 loop. The resolver is the
## `TestEffectResolver` double: it skips a silenced candidate's triggers and a
## silenced source's aura, as Card Effects will.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
## AC-24 / F6 worked example: a 2/2 with +2 health and `damage_taken 3`.
const BASE_ATTACK: int = 2
const BASE_HEALTH: int = 2
const HEALTH_BUFF: int = 2
const DAMAGE_TAKEN: int = 3
## F6: `max(0, 3 − (4 − 2))`.
const DAMAGE_AFTER_SILENCE: int = 1
## A ready attacker and a defender that survives it (thaw cases).
const ATK: int = 1
const SAFE_HEALTH: int = 10
const MARKER: StringName = &"test_deathrattle_marker"


# --- helpers -----------------------------------------------------------------

func _engine(log: TestEventLog, resolver: TestEffectResolver = null) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {}, {}, resolver)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	return engine


## A ready (not summoning-sick) minion on [param side]'s board; its record.
func _minion(engine: RulesEngine, side: String, attack: int, health: int, keywords: Array = []) -> Dictionary:
	var minion: Dictionary = MatchFactory.summon(engine.state(), side, attack, health, -1, keywords)
	minion.summoning_sick = false
	return minion


func _hero_id(engine: RulesEngine, side: String) -> int:
	return int(engine.state().players[side].hero.entity_id)


func _of(log: TestEventLog, since: int, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in log.events.slice(since):
		if String(event.type) == type:
			out.append(event)
	return out


func _types(log: TestEventLog, since: int) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in log.events.slice(since):
		out.append(String(event.type))
	return out


func _end_turn(engine: RulesEngine) -> void:
	assert_bool(engine.submit(MatchRecords.end_turn(String(engine.active_side()))).accepted).is_true()


func _noop() -> void:
	pass


func _mark(engine: RulesEngine, ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(MARKER, {"source_id": int(ctx.source_id)})


# --- AC-24: Silence, F6 clamp, buff loss --------------------------------------

func test_silence_strips_a_buffed_damaged_minion_and_clamps_damage_by_f6() -> void:
	# Arrange: a Frozen Taunt 2/2 with +2 health (max 4) and damage_taken 3 → 2/1
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = _minion(engine, SIDE_BOSS, BASE_ATTACK, BASE_HEALTH, ["taunt"])
	var id: int = int(minion.entity_id)
	minion.enchantments.append(MatchFactory.make_enchantment(0, HEALTH_BUFF, ["windfury"]))
	minion.damage_taken = DAMAGE_TAKEN
	engine.freeze(id)
	var before: int = log.events.size()

	# Act
	engine.run_action(func() -> void: engine.silence(id))

	# Assert: F6 — max 2, damage 1, health 1; everything stripped in one event
	assert_int(engine.max_health(minion)).is_equal(BASE_HEALTH)
	assert_int(int(minion.damage_taken)).is_equal(DAMAGE_AFTER_SILENCE)
	assert_int(engine.health(minion)).is_equal(BASE_HEALTH - DAMAGE_AFTER_SILENCE)
	assert_array(minion.keywords).is_empty()
	assert_array(minion.enchantments).is_empty()
	assert_bool(bool(minion.frozen)).is_false()
	assert_bool(bool(minion.silenced)).is_true()
	var silenced: Array[Dictionary] = _of(log, before, "silenced")
	assert_int(silenced.size()).is_equal(1)
	assert_int(int(silenced[0].payload.entity_id)).is_equal(id)
	assert_array(silenced[0].payload.removed_keywords).is_equal(["taunt", "windfury"])
	assert_int((silenced[0].payload.removed_enchantments as Array).size()).is_equal(1)
	assert_int(int(silenced[0].payload.removed_enchantments[0].health_delta)).is_equal(HEALTH_BUFF)
	assert_array(_of(log, before, "enchantment_removed")).is_empty()
	assert_array(_of(log, before, "keyword_removed")).is_empty()
	assert_array(_of(log, before, "thawed")).is_empty()
	assert_array(_of(log, before, "minion_died")).is_empty()


func test_aura_loss_leaves_damage_and_kills_the_minion_after_its_source_in_one_loop() -> void:
	# Arrange: source S emits +0/+2 to A (2/2 → 2/4); A has damage_taken 3
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var source: Dictionary = _minion(engine, SIDE_PLAYER, 1, 1)
	var buffed: Dictionary = _minion(engine, SIDE_PLAYER, BASE_ATTACK, BASE_HEALTH)
	resolver.auras[int(source.entity_id)] = {"health_delta": HEALTH_BUFF}
	engine.run_action(_noop)
	buffed.damage_taken = DAMAGE_TAKEN
	assert_int(engine.health(buffed)).is_equal(BASE_HEALTH + HEALTH_BUFF - DAMAGE_TAKEN)
	var before: int = log.events.size()

	# Act: the source dies
	engine.run_action(func() -> void: engine.destroy(int(source.entity_id)))

	# Assert: damage untouched; A dies in the same loop, after S
	assert_int(int(buffed.damage_taken)).is_equal(DAMAGE_TAKEN)
	var died: Array[Dictionary] = _of(log, before, "minion_died")
	assert_int(died.size()).is_equal(2)
	assert_int(int(died[0].payload.entity_id)).is_equal(int(source.entity_id))
	assert_int(int(died[1].payload.entity_id)).is_equal(int(buffed.entity_id))
	assert_int(int(died[0].seq)).is_less(int(died[1].seq))
	assert_array(engine.state().players[SIDE_PLAYER].board).is_empty()


func test_silence_removes_divine_shield_taunt_and_deathrattle_and_it_never_fires() -> void:
	# Arrange: a Divine Shield, Taunt minion with a Deathrattle
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var minion: Dictionary = _minion(engine, SIDE_BOSS, BASE_ATTACK, BASE_HEALTH, ["divine_shield", "taunt", "deathrattle"])
	var id: int = int(minion.entity_id)
	resolver.add_trigger(&"deathrattle", id, "dr.%d" % id, _mark)
	var before: int = log.events.size()

	# Act: silenced in one step, then destroyed
	engine.run_action(func() -> void: engine.silence(id))
	var silenced_at: int = log.events.size()
	engine.run_action(func() -> void: engine.destroy(id))

	# Assert: one step, one event; the death raises no Deathrattle
	assert_array(_types(log, before)).contains(["silenced"])
	assert_int(_of(log, before, "silenced").size()).is_equal(1)
	assert_array(_of(log, before, "silenced")[0].payload.removed_keywords).is_equal(["divine_shield", "taunt", "deathrattle"])
	assert_array(_of(log, silenced_at, "minion_died")).has_size(1)
	assert_array(_of(log, silenced_at, "trigger_queued")).is_empty()
	assert_array(_of(log, silenced_at, "trigger_resolved")).is_empty()
	assert_array(_of(log, silenced_at, String(MARKER))).is_empty()
	assert_array(resolver.pass_ids(&"deathrattle")).is_empty()


func test_an_unsilenced_deathrattle_still_fires_under_the_same_fixture() -> void:
	# Arrange: the control case — the same minion, not silenced
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var id: int = int(_minion(engine, SIDE_BOSS, BASE_ATTACK, BASE_HEALTH, ["deathrattle"]).entity_id)
	resolver.add_trigger(&"deathrattle", id, "dr.%d" % id, _mark)
	var before: int = log.events.size()

	# Act
	engine.run_action(func() -> void: engine.destroy(id))

	# Assert
	assert_array(_of(log, before, "trigger_resolved")).has_size(1)
	assert_array(_of(log, before, String(MARKER))).has_size(1)


func test_silence_does_not_restore_a_popped_divine_shield() -> void:
	# Arrange: the shield is popped by a hit first
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = _minion(engine, SIDE_BOSS, BASE_ATTACK, SAFE_HEALTH, ["divine_shield"])
	var id: int = int(minion.entity_id)
	engine.run_action(func() -> void: engine.apply_damage(id, ATK, null))
	assert_bool(engine.state_snapshot(id).keywords.has("divine_shield")).is_false()
	var before: int = log.events.size()

	# Act
	engine.run_action(func() -> void: engine.silence(id))

	# Assert: still no shield, nothing reported removed
	assert_bool(minion.keywords.has("divine_shield")).is_false()
	assert_array(_of(log, before, "silenced")[0].payload.removed_keywords).is_empty()
	assert_array(_of(log, before, "divine_shield_popped")).is_empty()


# --- AC-25: thaw rule at End step 4 --------------------------------------------

func test_a_minion_frozen_on_the_opponents_turn_thaws_at_its_controllers_end_step() -> void:
	# Arrange: turn 1 (player); a boss minion is frozen
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = _minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH)
	var id: int = int(minion.entity_id)
	engine.run_action(func() -> void: engine.freeze(id))
	_end_turn(engine)   # player End: not the boss's character — stays frozen
	assert_bool(bool(minion.frozen)).is_true()
	var before: int = log.events.size()

	# Act: the boss's End step (turn 2; frozen_on_turn 1 < 2)
	_end_turn(engine)

	# Assert
	assert_bool(bool(minion.frozen)).is_false()
	var thawed: Array[Dictionary] = _of(log, before, "thawed")
	assert_int(thawed.size()).is_equal(1)
	assert_int(int(thawed[0].payload.entity_id)).is_equal(id)
	assert_int(int(thawed[0].turn)).is_equal(2)


func test_a_minion_frozen_on_its_own_turn_before_attacking_stays_frozen_until_its_next_end_step() -> void:
	# Arrange: turn 1; a ready player minion frozen before it attacked
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var id: int = int(minion.entity_id)
	engine.run_action(func() -> void: engine.freeze(id))
	var before: int = log.events.size()

	# Act: its own End step (turn 1), the boss's turn, then its next turn
	_end_turn(engine)
	var after_first_end: bool = bool(minion.frozen)
	var thawed_at_first_end: int = _of(log, before, "thawed").size()
	_end_turn(engine)
	var attack_on_turn_3: String = str(engine.can_attack(id, _hero_id(engine, SIDE_BOSS)).code)
	var before_second_end: int = log.events.size()
	_end_turn(engine)

	# Assert: frozen through turn 3 (cannot attack), thawed at the turn-3 End step
	assert_bool(after_first_end).is_true()
	assert_int(thawed_at_first_end).is_equal(0)
	assert_int(_of(log, before, "thawed").size()).is_equal(1)
	assert_int(_of(log, before_second_end, "thawed").size()).is_equal(1)
	assert_str(attack_on_turn_3).is_equal("ATTACKER_FROZEN")
	assert_bool(bool(minion.frozen)).is_false()
	assert_int(int(_of(log, before, "thawed")[0].turn)).is_equal(3)


func test_a_minion_frozen_after_using_its_attacks_thaws_at_this_end_step() -> void:
	# Arrange: turn 1; the minion attacks, then is frozen (attacks_remaining 0)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var id: int = int(minion.entity_id)
	assert_bool(engine.submit(MatchRecords.attack(SIDE_PLAYER, id, _hero_id(engine, SIDE_BOSS))).accepted).is_true()
	engine.run_action(func() -> void: engine.freeze(id))
	assert_int(engine.attacks_remaining(minion)).is_equal(0)
	var before: int = log.events.size()

	# Act
	_end_turn(engine)

	# Assert
	assert_bool(bool(minion.frozen)).is_false()
	assert_int(_of(log, before, "thawed").size()).is_equal(1)


func test_freezing_twice_restamps_frozen_on_turn_and_thaws_once() -> void:
	# Arrange: frozen on the player's turn 1, then again on the boss's turn 2
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var id: int = int(minion.entity_id)
	engine.run_action(func() -> void: engine.freeze(id))
	_end_turn(engine)
	engine.run_action(func() -> void: engine.freeze(id))
	assert_int(int(minion.frozen_on_turn)).is_equal(2)
	_end_turn(engine)
	var before: int = log.events.size()

	# Act: the player's turn-3 End step (2 < 3)
	_end_turn(engine)

	# Assert: one evaluation, one thawed
	assert_int(_of(log, before, "thawed").size()).is_equal(1)
	assert_bool(bool(minion.frozen)).is_false()


func test_the_thaw_runs_after_on_turn_end_hooks_and_before_end_of_turn_expiry() -> void:
	# Arrange: a frozen boss minion with an end_of_turn enchantment; boss turn
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = _minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH)
	var id: int = int(minion.entity_id)
	engine.run_action(func() -> void: engine.freeze(id))
	_end_turn(engine)
	minion.enchantments.append(MatchFactory.make_enchantment(1, 0, [], null, false, MatchRecords.EXPIRES_END_OF_TURN))
	var before: int = log.events.size()

	# Act
	_end_turn(engine)

	# Assert: C4 End order — turn_ending, thawed, enchantment_removed, turn_ended
	EventLogAssertions.assert_order(log.events.slice(before), ["turn_ending", "thawed", "enchantment_removed", "turn_ended"])


# --- C13 exclusions -------------------------------------------------------------

func test_a_frozen_minion_silenced_thaws_at_once_and_may_attack_this_turn() -> void:
	# Arrange: a ready player minion frozen on its own turn
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var id: int = int(minion.entity_id)
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)
	engine.run_action(func() -> void: engine.freeze(id))
	assert_str(str(engine.can_attack(id, boss_hero).code)).is_equal("ATTACKER_FROZEN")

	# Act
	engine.run_action(func() -> void: engine.silence(id))

	# Assert
	assert_bool(bool(minion.frozen)).is_false()
	assert_bool(bool(engine.can_attack(id, boss_hero).ok)).is_true()
	assert_bool(engine.submit(MatchRecords.attack(SIDE_PLAYER, id, boss_hero)).accepted).is_true()


func test_silence_keeps_sickness_attacks_used_pending_destroy_base_stats_and_damage() -> void:
	# Arrange: a sick minion that has attacked (fixture), marked for destruction
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, BASE_ATTACK, SAFE_HEALTH, -1, ["charge"])
	var id: int = int(minion.entity_id)
	minion.attacks_used = 1
	minion.damage_taken = DAMAGE_TAKEN
	minion.pending_destroy = true

	# Act: silenced directly (no loop — the death check would remove it)
	engine.silence(id)

	# Assert
	assert_bool(bool(minion.summoning_sick)).is_true()
	assert_int(int(minion.attacks_used)).is_equal(1)
	assert_bool(bool(minion.pending_destroy)).is_true()
	assert_int(int(minion.base_attack)).is_equal(BASE_ATTACK)
	assert_int(int(minion.base_health)).is_equal(SAFE_HEALTH)
	assert_int(int(minion.damage_taken)).is_equal(DAMAGE_TAKEN)
	assert_array(minion.keywords).is_empty()


func test_a_silenced_minion_keeps_received_auras_and_stops_emitting_its_own() -> void:
	# Arrange: A and B buff each other (+1/+1 each way)
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var a: Dictionary = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var b: Dictionary = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	resolver.auras[int(a.entity_id)] = {"attack_delta": 1, "health_delta": 1}
	resolver.auras[int(b.entity_id)] = {"attack_delta": 1, "health_delta": 1}
	engine.run_action(_noop)
	assert_int(engine.attack(a)).is_equal(ATK + 1)
	assert_int(engine.attack(b)).is_equal(ATK + 1)

	# Act: B is silenced
	engine.run_action(func() -> void: engine.silence(int(b.entity_id)))

	# Assert: B still has A's aura; A lost B's
	assert_int(engine.attack(b)).is_equal(ATK + 1)
	assert_int(engine.max_health(b)).is_equal(SAFE_HEALTH + 1)
	assert_int(engine.attack(a)).is_equal(ATK)
	assert_int(engine.max_health(a)).is_equal(SAFE_HEALTH)
