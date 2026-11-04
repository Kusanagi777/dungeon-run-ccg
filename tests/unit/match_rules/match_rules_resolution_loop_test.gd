## Unit tests for the C10 resolution loop (story match-rules/story-009;
## design/gdd/match-rules.md C10 Death resolution and trigger ordering, C12
## Deathrattle / Aura rows, F6 aura loss, Edge Cases "Board and summoning" and
## the `RESOLUTION_STEP_CAP` row, DD-M11; ADR-0007 Decision 1 — the engine owns
## the loop, the queue and candidate order; ADR-0005 rule 4 — a trigger hook
## entry is its own step followed by the full loop).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan (turn 1, player Main). Minions are placed with `MatchFactory.summon`;
## who responds to a trigger point is scripted on the `TestEffectResolver`
## (`add_trigger`, `add_deathrattle_summon`, `add_heal_ping_pong`, `auras`).
## Fixture actions run through `RulesEngine.run_action(step)`, the same C10
## entry point every command handler and engine step uses.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
## AC-30: the step cap the story sets for the ping-pong fixture (a boundary
## value — the exact number is the point; the shipped knob is 1000).
const TEST_STEP_CAP: int = 50
## Steps per action in the per-action reset test: under the cap, twice over.
const STEPS_PER_ACTION: int = 30
## A survivor's health for "1 damage to all" (survives with health left).
const STURDY_HEALTH: int = 5
## AC-29: the Deathrattle token and its stats.
const DEF_TOKEN: String = "neutral_test_token"
const TOKEN_STATS: int = 2
## The index of the Deathrattle minion on a full board (AC-29).
const FULL_BOARD_DR_INDEX: int = 3
## A weapon definition with durability left.
const DEF_AXE: String = "war_test_axe"
const DEF_BLADE: String = "war_test_blade"
const MARKER: StringName = &"test_pass_marker"


## `CardDatabase.has(id)` / `card(id)` stand-in with the fixture definitions.
class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


# --- helpers -----------------------------------------------------------------

func _db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	db.cards[DEF_TOKEN] = CardFactory.make_minion(DEF_TOKEN, 1, TOKEN_STATS, TOKEN_STATS)
	db.cards[DEF_AXE] = CardFactory.make_weapon(DEF_AXE, 2, 3, 2)
	db.cards[DEF_BLADE] = CardFactory.make_weapon(DEF_BLADE, 1, 1, 3)
	return db


func _engine(log: TestEventLog, resolver: TestEffectResolver, overrides: Dictionary = {}, rules_overrides: Dictionary = {}) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, overrides, rules_overrides, resolver, _db())
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	return engine


func _board(engine: RulesEngine, side: String) -> Array:
	return engine.state().players[side].board


func _ids(minions: Array) -> Array[int]:
	var out: Array[int] = []
	for minion: Dictionary in minions:
		out.append(int(minion.entity_id))
	return out


## The events of [param types] after [param before], in log order.
func _of(log: TestEventLog, before: int, types: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in log.events.slice(before):
		if types.has(String(event.type)):
			out.append(event)
	return out


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in events:
		out.append(String(event.type))
	return out


## `[type, entity id]` per event — `entity_id` for deaths, `source_id` for triggers.
func _tagged(events: Array[Dictionary]) -> Array:
	var out: Array = []
	for event: Dictionary in events:
		var id: Variant = event.payload.get("entity_id", event.payload.get("source_id"))
		out.append([String(event.type), int(id)])
	return out


## Step: 1 damage to every minion on both boards (player board L→R, then boss).
func _hit_all_minions(engine: RulesEngine) -> void:
	for side: String in MatchRecords.SIDES:
		for id: int in _ids(_board(engine, side)):
			@warning_ignore("return_value_discarded")
			engine.apply_damage(id, 1, null)


## Pass: draws one card for the controller of the snapshot source.
func _draw_one(engine: RulesEngine, ctx: Dictionary) -> void:
	engine.draw(str(ctx.snapshot.controller), 1)


## Pass: emits [constant MARKER] naming the effect.
func _mark(engine: RulesEngine, ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(MARKER, {"effect_id": str(ctx.effect_id)})


## Hook: destroys the first player minion.
func _destroy_first(engine: RulesEngine, _entry: Dictionary, _side: StringName, _ctx: Dictionary) -> void:
	engine.destroy(int(engine.state().players[SIDE_PLAYER].board[0].entity_id))


## Hook: emits [constant MARKER] for the hook entry.
func _hook_mark(engine: RulesEngine, entry: Dictionary, _side: StringName, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(MARKER, {"effect_id": str(entry.effect_id)})


func _noop(_engine: RulesEngine) -> void:
	pass


# --- AC-27: death check order, Deathrattle queue, observers -------------------

func test_simultaneous_deaths_leave_in_dd_m11_order_and_queue_deathrattles_in_that_order() -> void:
	# Arrange: player [A(dr), B(dr), D], boss [C(dr)]; A, B, C at 1 health; every
	# minion also observes on_minion_died
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var state: MatchState = engine.state()
	var a: int = int(MatchFactory.summon(state, SIDE_PLAYER, 1, 1).entity_id)
	var b: int = int(MatchFactory.summon(state, SIDE_PLAYER, 1, 1).entity_id)
	var d: int = int(MatchFactory.summon(state, SIDE_PLAYER, 1, STURDY_HEALTH).entity_id)
	var c: int = int(MatchFactory.summon(state, SIDE_BOSS, 1, 1).entity_id)
	for id: int in [a, b, c]:
		resolver.add_trigger(&"deathrattle", id, "dr.%d" % id)
	for id: int in [a, b, c, d]:
		resolver.add_trigger(&"on_minion_died", id, "obs.%d" % id)
	var before: int = log.events.size()

	# Act
	engine.run_action(_hit_all_minions.bind(engine))

	# Assert: minion_died A, B, C, then their Deathrattles A, B, C, then D observes 3×
	var deaths: Array[Dictionary] = _of(log, before, ["minion_died"])
	assert_array(_tagged(deaths)).is_equal([["minion_died", a], ["minion_died", b], ["minion_died", c]])
	var resolved: Array[Dictionary] = _of(log, before, ["trigger_resolved"])
	assert_array(_tagged(resolved)).is_equal([
		["trigger_resolved", a], ["trigger_resolved", b], ["trigger_resolved", c],
		["trigger_resolved", d], ["trigger_resolved", d], ["trigger_resolved", d],
	])
	assert_bool(int(resolved[0].seq) > int(deaths[2].seq)).is_true()
	# each trigger_resolved carries the seq of the minion_died that queued it
	for i: int in deaths.size():
		assert_int(int(resolved[i].cause_seq)).is_equal(int(deaths[i].seq))
		assert_str(str(resolved[i].payload.point)).is_equal("deathrattle")
		assert_int(int(resolved[i + 3].cause_seq)).is_equal(int(deaths[i].seq))
	# a minion that died in the same check observes nothing
	assert_array(resolver.pass_ids(&"on_minion_died")).is_equal(["obs.%d" % d, "obs.%d" % d, "obs.%d" % d])
	assert_array(_ids(_board(engine, SIDE_PLAYER))).is_equal([d])
	assert_array(_board(engine, SIDE_BOSS)).is_empty()
	# Deathrattle resolve calls: one per dead entity, candidates [that entity]
	assert_array(resolver.candidates_for(&"deathrattle")).is_equal([[a], [b], [c]])
	assert_dict(deaths[0].payload).is_equal({"side": SIDE_PLAYER, "entity_id": a, "card_id": "", "position": 0})


func test_a_broken_weapon_leaves_after_the_minions_and_its_deathrattle_queues_after_theirs() -> void:
	# Arrange: a boss minion at 1 health with a Deathrattle; the player's weapon
	# (with a Deathrattle) at durability 1
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var minion: int = int(MatchFactory.summon(engine.state(), SIDE_BOSS, 1, 1).entity_id)
	var axe: int = engine.equip_weapon(SIDE_PLAYER, DEF_AXE)
	resolver.add_trigger(&"deathrattle", minion, "dr.minion")
	resolver.add_trigger(&"deathrattle", axe, "dr.axe")
	var durability: int = int(engine.state().players[SIDE_PLAYER].weapon.durability)
	var before: int = log.events.size()

	# Act: one step — the swing's durability loss and the hit
	engine.run_action(func() -> void:
		engine.modify_durability(axe, -durability)
		engine.apply_damage(minion, 1, null))

	# Assert
	var leaving: Array[Dictionary] = _of(log, before, ["minion_died", "weapon_destroyed"])
	assert_array(_tagged(leaving)).is_equal([["minion_died", minion], ["weapon_destroyed", axe]])
	assert_dict(leaving[1].payload).is_equal({"side": SIDE_PLAYER, "entity_id": axe, "card_id": DEF_AXE, "reason": RulesEngine.WEAPON_BROKEN})
	assert_array(resolver.pass_ids(&"deathrattle")).is_equal(["dr.minion", "dr.axe"])
	assert_that(engine.state().players[SIDE_PLAYER].weapon).is_null()


func test_replacing_a_weapon_queues_the_old_weapons_deathrattle() -> void:
	# Arrange: the player holds an axe with a Deathrattle
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var axe: int = engine.equip_weapon(SIDE_PLAYER, DEF_AXE)
	resolver.add_trigger(&"deathrattle", axe, "dr.axe", _mark)
	var before: int = log.events.size()

	# Act: an effect equips a blade
	engine.run_action(func() -> void: engine.equip_weapon(SIDE_PLAYER, DEF_BLADE))

	# Assert: replaced, queued, equipped — then the old weapon's Deathrattle resolves
	var events: Array[Dictionary] = _of(log, before, ["weapon_destroyed", "trigger_queued", "weapon_equipped", "trigger_resolved", String(MARKER)])
	assert_array(_types(events)).is_equal(["weapon_destroyed", "trigger_queued", "weapon_equipped", "trigger_resolved", String(MARKER)])
	assert_int(int(events[3].cause_seq)).is_equal(int(events[0].seq))


# --- AC-28: on_damage before Deathrattles; queued triggers always resolve -------

func test_on_damage_trigger_resolves_before_its_own_deathrattle_from_the_raise_time_snapshot() -> void:
	# Arrange: a 1/1 with "on_damage: draw 1" and a Deathrattle
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var id: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	resolver.add_trigger(&"on_damage", id, "m.on_damage", _draw_one, resolver.subject_is.bind(id))
	resolver.add_trigger(&"deathrattle", id, "m.dr")
	var before: int = log.events.size()

	# Act
	engine.run_action(func() -> void: engine.apply_damage(id, 1, null))

	# Assert: damage_dealt → card_drawn → trigger_resolved(deathrattle)
	var events: Array[Dictionary] = _of(log, before, ["damage_dealt", "minion_died", "card_drawn", "trigger_resolved"])
	assert_array(_types(events)).is_equal(["damage_dealt", "minion_died", "trigger_resolved", "card_drawn", "trigger_resolved"])
	assert_str(str(events[2].payload.point)).is_equal("on_damage")
	assert_str(str(events[4].payload.point)).is_equal("deathrattle")
	# the on_damage trigger was queued at the damage step and carries damage_dealt's seq
	assert_int(int(events[2].cause_seq)).is_equal(int(events[0].seq))
	# it resolved though its source had left play, from the raise-time snapshot
	var pass_ctx: Dictionary = resolver.passes[0].ctx
	assert_int(int(pass_ctx.snapshot.entity_id)).is_equal(id)
	assert_int(int(pass_ctx.snapshot.damage_taken)).is_equal(1)
	assert_bool(_ids(_board(engine, SIDE_PLAYER)).has(id)).is_false()


func test_nothing_is_queued_for_a_source_not_in_play_at_raise_time() -> void:
	# Arrange: the resolver answers on_damage with an entry whose source left play
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var target: int = int(MatchFactory.summon(engine.state(), SIDE_BOSS, 1, STURDY_HEALTH).entity_id)
	resolver.queued[&"on_damage"] = [{"source_id": MatchState.FIRST_ENTITY_ID - 1, "effect_id": "ghost.0"}]
	var before: int = log.events.size()

	# Act
	engine.run_action(func() -> void: engine.apply_damage(target, 1, null))

	# Assert
	assert_array(_of(log, before, ["trigger_queued", "trigger_resolved"])).is_empty()
	assert_array(resolver.passes).is_empty()


# --- AC-29: summons in the loop, board space, aura loss ------------------------

func test_deathrattle_summon_on_a_full_board_takes_the_dead_minions_index() -> void:
	# Arrange: 7 friendly minions; board[3] is a 1/1 with "Deathrattle: summon a 2/2"
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	for i: int in TestConstants.BOARD_SIZE:
		MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1 if i == FULL_BOARD_DR_INDEX else STURDY_HEALTH)
	var dying: int = int(_board(engine, SIDE_PLAYER)[FULL_BOARD_DR_INDEX].entity_id)
	resolver.add_deathrattle_summon(dying, DEF_TOKEN)

	# Act
	engine.run_action(func() -> void: engine.destroy(dying))

	# Assert: dead minions leave before Deathrattles run, so 6 + 1 fits at index 3
	var board: Array = _board(engine, SIDE_PLAYER)
	assert_int(board.size()).is_equal(TestConstants.BOARD_SIZE)
	assert_str(str(board[FULL_BOARD_DR_INDEX].def_id)).is_equal(DEF_TOKEN)
	assert_int(int(log.first(&"minion_summoned").payload.position)).is_equal(FULL_BOARD_DR_INDEX)
	assert_int(log.count(&"summon_failed")).is_equal(0)


func test_a_second_simultaneous_summon_on_the_refilled_board_fails() -> void:
	# Arrange: 6 others plus a Deathrattle that summons two
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	for i: int in TestConstants.BOARD_SIZE:
		MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, STURDY_HEALTH)
	var dying: int = int(_board(engine, SIDE_PLAYER)[FULL_BOARD_DR_INDEX].entity_id)
	resolver.add_deathrattle_summon(dying, DEF_TOKEN, 2)
	var before: int = log.events.size()

	# Act
	engine.run_action(func() -> void: engine.destroy(dying))

	# Assert
	assert_array(_types(_of(log, before, ["minion_summoned", "summon_failed"]))).is_equal(["minion_summoned", "summon_failed"])
	assert_dict(log.first(&"summon_failed").payload).is_equal({"side": SIDE_PLAYER, "card_id": DEF_TOKEN, "reason": RulesEngine.SUMMON_FAILED_BOARD_FULL})
	assert_int(_board(engine, SIDE_PLAYER).size()).is_equal(TestConstants.BOARD_SIZE)


func test_deathrattle_summon_past_the_board_end_goes_rightmost() -> void:
	# Arrange: [x, y, z(dr)] — y and z die together, so z's former index 2 is past the end
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var x: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, STURDY_HEALTH).entity_id)
	var y: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	var z: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	resolver.add_deathrattle_summon(z, DEF_TOKEN)

	# Act
	engine.run_action(func() -> void:
		engine.destroy(y)
		engine.destroy(z))

	# Assert
	var board: Array = _board(engine, SIDE_PLAYER)
	assert_int(board.size()).is_equal(2)
	assert_int(int(board[0].entity_id)).is_equal(x)
	assert_str(str(board[1].def_id)).is_equal(DEF_TOKEN)
	assert_int(int(log.first(&"minion_summoned").payload.position)).is_equal(1)


func test_aura_loss_kills_the_buffed_minion_in_the_next_pass_after_the_sources_deathrattle() -> void:
	# Arrange: [S (aura +0/+1, dr), A 1/1 (dr)]; the aura is applied by a first action
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var s: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	var a: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	resolver.auras[s] = {"health_delta": 1}
	resolver.add_trigger(&"deathrattle", s, "dr.s")
	resolver.add_trigger(&"deathrattle", a, "dr.a")
	var settle: int = log.events.size()
	engine.run_action(_noop.bind(engine))
	var applied: Array[Dictionary] = _of(log, settle, ["auras_recomputed", "enchantment_applied"])
	var idle: int = log.events.size()
	engine.run_action(_noop.bind(engine))
	var before: int = log.events.size()

	# Act: 1 damage to both — S dies, A (1/2) survives this pass at 1 health
	engine.run_action(_hit_all_minions.bind(engine))

	# Assert: one auras_recomputed per pass with net changes, none when nothing changed
	assert_array(_types(applied)).is_equal(["auras_recomputed"])
	assert_array(applied[0].payload.changes).is_equal([{"entity_id": a, "attack": 1, "health": 2, "max_health": 2}])
	assert_array(log.events.slice(idle, before)).is_empty()
	var events: Array[Dictionary] = _of(log, before, ["minion_died", "auras_recomputed", "trigger_resolved"])
	assert_array(_tagged(events.filter(func(e: Dictionary) -> bool: return e.type != "auras_recomputed"))).is_equal([
		["minion_died", s], ["trigger_resolved", s], ["minion_died", a], ["trigger_resolved", a],
	])
	assert_array(_types(events)).is_equal(["minion_died", "auras_recomputed", "trigger_resolved", "minion_died", "trigger_resolved"])
	assert_array(events[1].payload.changes).is_equal([{"entity_id": a, "attack": 1, "health": 0, "max_health": 1}])
	assert_array(_board(engine, SIDE_PLAYER)).is_empty()


# --- AC-30: RESOLUTION_STEP_CAP ------------------------------------------------

func test_heal_ping_pong_faults_resolution_overflow_after_exactly_the_step_cap() -> void:
	# Arrange: two full-health friendly minions that heal each other forever
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, {}, {"resolution_step_cap": TEST_STEP_CAP})
	var first: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	var second: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	resolver.add_heal_ping_pong(first, second)
	var before: int = log.events.size()

	# Act: either is healed
	engine.run_action(func() -> void: engine.apply_heal(first, 1, null))

	# Assert: the initial step + 49 queued steps = 50, then the fault
	var outcome: Dictionary = engine.result()
	assert_array([outcome.result, outcome.winner, outcome.reason]).is_equal([MatchRecords.RESULT_FAULT, null, MatchRecords.REASON_RESOLUTION_OVERFLOW])
	assert_int(log.count(&"trigger_resolved")).is_equal(TEST_STEP_CAP - 1)
	assert_int(_of(log, before, ["healed"]).size()).is_equal(TEST_STEP_CAP)
	var types: Array[String] = log.types()
	assert_str(types[types.size() - 2]).is_equal("resolution_overflow")
	EventLogAssertions.assert_last_type(log, &"match_ended")
	assert_dict(log.first(&"resolution_overflow").payload).is_equal({"steps": TEST_STEP_CAP})
	assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)


func test_the_step_counter_resets_per_action() -> void:
	# Arrange: a ping-pong that stops after STEPS_PER_ACTION heals (a counter in the pass)
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, {}, {"resolution_step_cap": TEST_STEP_CAP})
	var id: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	var budget: Dictionary = {"left": 0}
	var self_heal: Callable = func(e: RulesEngine, _ctx: Dictionary) -> void:
		budget.left -= 1
		e.apply_heal(id, 1, id)
	var still_going: Callable = func(_e: RulesEngine, ctx: Dictionary) -> bool:
		return ctx.get("subject") == id and budget.left > 0
	resolver.add_trigger(&"on_heal", id, "loop.0", self_heal, still_going)

	# Act: two actions of STEPS_PER_ACTION steps each (60 in total, cap 50)
	for _i: int in 2:
		budget.left = STEPS_PER_ACTION - 1
		engine.run_action(func() -> void: engine.apply_heal(id, 1, null))

	# Assert
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_int(log.count(&"trigger_resolved")).is_equal(2 * (STEPS_PER_ACTION - 1))
	assert_int(log.count(&"resolution_overflow")).is_equal(0)


# --- ADR-0005 rule 4: each trigger hook entry is its own step -------------------

func test_each_hook_trigger_entry_is_followed_by_the_full_loop() -> void:
	# Arrange: two on_turn_end entries — the first destroys a minion with a
	# Deathrattle, the second only marks; the Deathrattle must resolve between them
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_dusk.0"] = _destroy_first
	resolver.hook_scripts["t_dusk.1"] = _hook_mark
	var dusk: HookInstaller = MatchFactory.make_hook_installer("t_dusk", SIDE_PLAYER, [&"on_turn_end", &"on_turn_end"])
	var engine: RulesEngine = _engine(log, resolver, {"player": {"hook_installers": [dusk]}})
	var id: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, STURDY_HEALTH).entity_id)
	resolver.add_trigger(&"deathrattle", id, "dr.0", _mark)
	var before: int = log.events.size()

	# Act
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert: entry 0 → its loop (death, Deathrattle) → entry 1
	var events: Array[Dictionary] = _of(log, before, ["minion_died", "trigger_resolved", String(MARKER)])
	assert_array(_types(events)).is_equal(["minion_died", "trigger_resolved", String(MARKER), String(MARKER)])
	assert_str(str(events[2].payload.effect_id)).is_equal("dr.0")
	assert_str(str(events[3].payload.effect_id)).is_equal("t_dusk.1")


# --- Code review 2026-11-03 (fix pass 2026-11-04) ------------------------------
# ADR-0005 rule-4 exception (erratum 2026-11-03): a hook point reached inside a
# primitive that is re-entered within one entry faults `resolution_overflow`;
# the step counter counts every step of one command; a malformed queue entry is
# logged and skipped.

## Hook: 1 sourceless damage to the hook owner's own hero (a self-feeding
## `on_hero_damaged` entry — "when your hero is damaged, damage your hero").
func _damage_own_hero(engine: RulesEngine, _entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.apply_damage(int(engine.state().players[String(side)].hero.entity_id), 1, null)


## Hook: gains 1 armour (no re-entry — Thornhide Cloak's shape).
func _gain_armor(engine: RulesEngine, _entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	engine.apply_armor(String(side), 1)


## Hook: draws one card for the hook owner (a self-feeding `on_draw` entry).
func _draw_for_owner(engine: RulesEngine, _entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	engine.draw(String(side), 1)


## Hook: summons a token for the hook owner (a self-feeding `on_minion_summoned` entry).
func _summon_for_owner(engine: RulesEngine, _entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.summon_minion(String(side), DEF_TOKEN, -1)


func _assert_resolution_overflow_fault(engine: RulesEngine, log: TestEventLog) -> void:
	var outcome: Dictionary = engine.result()
	assert_array([outcome.result, outcome.winner, outcome.reason]).is_equal([MatchRecords.RESULT_FAULT, null, MatchRecords.REASON_RESOLUTION_OVERFLOW])
	assert_int(log.count(&"resolution_overflow")).is_equal(1)
	EventLogAssertions.assert_last_type(log, &"match_ended")
	assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)


func test_self_feeding_on_hero_damaged_hook_faults_resolution_overflow_not_the_call_stack() -> void:
	# Arrange: a player treasure "whenever your hero is damaged, deal 1 damage to your hero"
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_ouroboros.0"] = _damage_own_hero
	var ouroboros: HookInstaller = MatchFactory.make_hook_installer("t_ouroboros", SIDE_PLAYER, [&"on_hero_damaged"])
	var engine: RulesEngine = _engine(log, resolver, {"player": {"hook_installers": [ouroboros]}})
	var hero: int = int(engine.state().players[SIDE_PLAYER].hero.entity_id)
	var before: int = log.events.size()

	# Act: the hero takes 1 damage
	engine.run_action(func() -> void: engine.apply_damage(hero, 1, null))

	# Assert: the entry ran once; its own damage re-entered on_hero_damaged and faulted
	_assert_resolution_overflow_fault(engine, log)
	assert_int(resolver.run_contexts(&"on_hero_damaged").size()).is_equal(1)
	assert_int(_of(log, before, ["damage_dealt"]).size()).is_equal(2)


func test_self_feeding_on_draw_hook_faults_resolution_overflow() -> void:
	# Arrange: "whenever you draw a card, draw a card"
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_greed.0"] = _draw_for_owner
	var greed: HookInstaller = MatchFactory.make_hook_installer("t_greed", SIDE_PLAYER, [&"on_draw"])
	var engine: RulesEngine = _engine(log, resolver, {"player": {"hook_installers": [greed]}})

	# Act
	engine.run_action(func() -> void: engine.draw(SIDE_PLAYER, 1))

	# Assert
	_assert_resolution_overflow_fault(engine, log)
	assert_int(resolver.run_contexts(&"on_draw").size()).is_equal(1)


func test_self_feeding_on_minion_summoned_hook_faults_resolution_overflow() -> void:
	# Arrange: "whenever you summon a minion, summon a 2/2"
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_brood.0"] = _summon_for_owner
	var brood: HookInstaller = MatchFactory.make_hook_installer("t_brood", SIDE_PLAYER, [&"on_minion_summoned"])
	var engine: RulesEngine = _engine(log, resolver, {"player": {"hook_installers": [brood]}})

	# Act
	engine.run_action(func() -> void: engine.summon_minion(SIDE_PLAYER, DEF_TOKEN, -1))

	# Assert: the first summon's entry summons once; that summon's hooks re-enter → fault
	_assert_resolution_overflow_fault(engine, log)
	assert_int(log.count(&"minion_summoned")).is_equal(2)


func test_an_in_primitive_hook_that_does_not_re_enter_runs_on_every_hit() -> void:
	# Arrange: "whenever your hero is damaged, gain 1 armour" (Thornhide Cloak's shape)
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_cloak.0"] = _gain_armor
	var cloak: HookInstaller = MatchFactory.make_hook_installer("t_cloak", SIDE_PLAYER, [&"on_hero_damaged"])
	var engine: RulesEngine = _engine(log, resolver, {"player": {"hook_installers": [cloak]}})
	var hero: int = int(engine.state().players[SIDE_PLAYER].hero.entity_id)

	# Act: two hits in one step, then one more action
	engine.run_action(func() -> void:
		engine.apply_damage(hero, 1, null)
		engine.apply_damage(hero, 1, null))
	engine.run_action(func() -> void: engine.apply_damage(hero, 1, null))

	# Assert: the guard is per entry, not per step or per match
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_int(log.count(&"armor_gained")).is_equal(3)
	assert_int(log.count(&"resolution_overflow")).is_equal(0)


func test_the_step_cap_counts_every_step_of_one_command() -> void:
	# Arrange: a minion whose turn_end and turn_start responses each start a
	# self-heal chain of STEPS_PER_ACTION steps; one end_turn runs both (60 > cap 50)
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, {}, {"resolution_step_cap": TEST_STEP_CAP})
	var id: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	var budget: Dictionary = {"left": 0}
	var start_chain: Callable = func(e: RulesEngine, _ctx: Dictionary) -> void:
		budget.left = STEPS_PER_ACTION - 1
		e.apply_heal(id, 1, id)
	var self_heal: Callable = func(e: RulesEngine, _ctx: Dictionary) -> void:
		budget.left -= 1
		e.apply_heal(id, 1, id)
	var still_going: Callable = func(_e: RulesEngine, ctx: Dictionary) -> bool:
		return ctx.get("subject") == id and budget.left > 0
	resolver.add_trigger(&"turn_end", id, "dusk.0", start_chain)
	resolver.add_trigger(&"turn_start", id, "dawn.0", start_chain)
	resolver.add_trigger(&"on_heal", id, "loop.0", self_heal, still_going)

	# Act
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert: one command, one step count — the cap is reached in the turn_start chain
	_assert_resolution_overflow_fault(engine, log)
	assert_dict(log.first(&"resolution_overflow").payload).is_equal({"steps": TEST_STEP_CAP})
	assert_int(log.count(&"turn_started")).is_equal(2)


func test_a_malformed_queue_entry_is_logged_and_skipped() -> void:
	# Arrange: the resolver answers on_damage with one entry lacking source_id, then a good one
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var target: int = int(MatchFactory.summon(engine.state(), SIDE_BOSS, 1, STURDY_HEALTH).entity_id)
	resolver.queued[&"on_damage"] = [{"effect_id": "broken.0"}, {"source_id": target, "effect_id": "good.0"}]

	# Act / Assert: logged, not a crash
	await assert_error(func() -> void: engine.run_action(func() -> void: engine.apply_damage(target, 1, null))) \
		.is_push_error("RulesEngine: skipped a malformed trigger entry from resolve(on_damage) (no integer source_id): { \"effect_id\": \"broken.0\" }")

	# Assert: the good entry still queued and resolved; the match goes on
	assert_array(resolver.pass_ids(&"on_damage")).is_equal(["good.0"])
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
