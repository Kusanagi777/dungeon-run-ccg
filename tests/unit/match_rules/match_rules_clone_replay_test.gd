## Unit tests for `RulesEngine.clone()` and replay equivalence (story
## match-rules/story-017; design/gdd/match-rules.md C2 `MatchState.clone()`
## paragraph, C3 step 1, AC-38, AC-39, Definition of Done "replay
## equivalence"; ADR-0007 Decision 3, ADR-0005 Decision 7, ADR-0006, ADR-0003
## F6 `replay_equal`; card-effects story 002 AC-1's clone clause, moved here
## 2026-11-03).
##
## Every match runs over one fixture card pool ([constant POOL_SPECS]) and the
## `TestEffectResolver` double scripted by this suite: `on_cast` /
## `battlecry` dispatch on `ctx.card_id` (freeze the enemy hero, Discover,
## summon swarms, deal damage), each counting into
## `state().effects.counters` so `EffectRuntime` is never empty; the
## Discover's `resume` adds the pick to hand. Every script takes the engine as
## its first argument, so a clone's resolver runs it against the clone.
##
## AC-39 fixture states are loaded by Implementation Notes option (a): each
## `tests/fixtures/match_states/*.json` is `{name, sample_seed, decks,
## boss_health?, rules_overrides?, commands[], expect}` replayed from `start`
## — no engine seam. A command is a literal C2 command, or a pick `{pick:
## <type>, issuer?, card_id?, optional?}` (the first entry of that type in
## `legal_commands()`, for a hand card of `card_id` when given), or a block
## `{repeat: n, commands: [...]}`; `expect` is asserted so a fixture that no
## longer reaches its state fails instead of passing vacuously.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const FIXTURE_DIR: String = "res://tests/fixtures/match_states/"
const FIXTURE_COUNT: int = 10
## AC-38 / AC-39: commands per scripted match and per fixture sample.
const COMMAND_COUNT: int = 200
## C2 isolation: commands submitted on the clone.
const CLONE_COMMANDS: int = 20
## AC-38: the seed of both engines (`TestRngService`, the only literal seed).
const REPLAY_SEED: int = 42
## Fixture card pool: `[id, type, cost, attack, health_or_durability, keywords]`.
const POOL_SPECS: Array = [
	["fx_grunt", "minion", 1, 1, 2, []],
	["fx_brute", "minion", 3, 3, 3, []],
	["fx_wall", "minion", 0, 0, 4, ["taunt"]],
	["fx_shade", "minion", 0, 1, 1, ["stealth"]],
	["fx_runner", "minion", 0, 1, 1, ["charge"]],
	["fx_seer", "minion", 2, 2, 2, ["battlecry", "discover"]],
	["fx_axe", "weapon", 0, 2, 2, []],
	["fx_frost", "spell", 0, 0, 0, ["freeze"]],
	["fx_scout", "spell", 0, 0, 0, ["discover"]],
	["fx_swarm", "spell", 0, 0, 0, []],
	["fx_guard", "spell", 0, 0, 0, []],
	["fx_bolt", "spell", 1, 0, 0, []],
]
const DISCOVER_OPTIONS: Array = ["fx_grunt", "fx_brute", "fx_runner"]
const DISCOVER_EFFECT_ID: String = "fx.discover"
## `fx_bolt` damage, and its scripted legal targets: the two heroes (C1 ids 1, 2).
const BOLT_DAMAGE: int = 2
const BOLT_TARGETS: Array[int] = [MatchFactory.PLAYER_HERO_ENTITY_ID, MatchFactory.BOSS_HERO_ENTITY_ID]
## AC-38 match: decks, healths (rules override within the safe range).
const REPLAY_PLAYER_DECK: Array = [["fx_grunt", 8], ["fx_brute", 6], ["fx_scout", 4], ["fx_axe", 2], ["fx_bolt", 4], ["fx_frost", 2], ["fx_seer", 4]]
const REPLAY_BOSS_DECK: Array = [["fx_wall", 14], ["fx_grunt", 6], ["fx_seer", 6], ["fx_frost", 4]]
const REPLAY_BOSS_HEALTH: int = 300
const REPLAY_PLAYER_HEALTH: int = 40
## AC-38 policy: command types in preference order; a turn plays, uses the
## power, attacks, then ends.
const POLICY_ORDER: Array[String] = [MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_USE_HERO_POWER, MatchRecords.CMD_ATTACK, MatchRecords.CMD_END_TURN]
## AC-38: the command types the scripted match must contain.
const REQUIRED_TYPES: Array[String] = [
	MatchRecords.CMD_MULLIGAN, MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_ATTACK,
	MatchRecords.CMD_USE_HERO_POWER, MatchRecords.CMD_CHOOSE, MatchRecords.CMD_END_TURN,
]
## AC-39 sample: the command types drawn (`concede` excluded — C2 never lists
## it and the player may always concede, so it cannot be "absent and rejected").
const SAMPLE_TYPES: Array[String] = [
	MatchRecords.CMD_MULLIGAN, MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_ATTACK,
	MatchRecords.CMD_USE_HERO_POWER, MatchRecords.CMD_CHOOSE, MatchRecords.CMD_END_TURN,
]
## AC-39 sample ranges: one past each valid range on both sides.
const SAMPLE_MAX_INDEX: int = 11
const SAMPLE_MAX_POSITION: int = 8
const SAMPLE_MAX_OPTION: int = 3
const SAMPLE_NULL_ONE_IN: int = 4
const SAMPLE_RANGE_PAD: int = 2
## C2 isolation fixture: two treasures and a boss passive (value + trigger points).
const BOSS_MANA: int = 10
const COUNTER_PROBE: int = 99
## Real-resolver fixture: the War hero set, its collectible spells, the
## Discover spell (`discover {pool: collectible, filter: spell}` then 2 damage
## to the enemy hero), a vanilla deck card and the seed.
const HERO_SET: String = "war"
const POOL_SPELL_COUNT: int = 6
const STUDY: String = "war_test_study"
const GRUNT: String = "war_test_grunt"
const STUDY_DAMAGE: int = 2
const REAL_SEED: int = 7
const REAL_DECK_SIZE: int = 15
const REAL_MANA: int = 10


## The real-resolver fixture (orchestrator note 2026-11-04, card-effects
## story 010): a `CardDatabase` answering `has` / `card` / `hero_power` /
## `collectible_pool` from maps, like `card_effects_choices_test.gd`'s.
class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}
	var pools: Dictionary = {}
	var pool_queries: Array[String] = []

	func _init(by_id: Dictionary, pools_by_set: Dictionary) -> void:
		records = by_id
		pools = pools_by_set

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		return records.get(id)

	func hero_power(id: String) -> Variant:
		return records.get(id)

	func collectible_pool(hero_set: String) -> Array:
		pool_queries.append(hero_set)
		return pools.get(hero_set, [])


class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


# --- fixture pool, resolver scripts --------------------------------------------

func _db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	for spec: Array in POOL_SPECS:
		var id: String = str(spec[0])
		match str(spec[1]):
			"minion":
				db.cards[id] = CardFactory.make_minion(id, int(spec[2]), int(spec[3]), int(spec[4]), spec[5])
			"weapon":
				db.cards[id] = CardFactory.make_weapon(id, int(spec[2]), int(spec[3]), int(spec[4]))
			"spell":
				db.cards[id] = CardFactory.make_spell(id, int(spec[2]), [], {"keywords": spec[5]})
	return db


func _resolver() -> TestEffectResolver:
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.scripts[&"on_cast"] = [_on_cast]
	resolver.scripts[&"battlecry"] = [_on_battlecry]
	resolver.resume_script = _resume
	resolver.specs_by_def["fx_bolt"] = {"mode": RulesEngine.TARGETING_REQUIRED, "filter": {}}
	resolver.targets_by_def["fx_bolt"] = BOLT_TARGETS
	return resolver


static func _enemy(side: String) -> String:
	return SIDE_BOSS if side == SIDE_PLAYER else SIDE_PLAYER


func _count(engine: RulesEngine, key: String) -> void:
	var counters: Dictionary = engine.state().effects.counters
	counters[key] = int(counters.get(key, 0)) + 1


func _on_cast(engine: RulesEngine, ctx: Dictionary) -> void:
	_count(engine, "casts")
	var side: String = str(ctx.side)
	match str(ctx.card_id):
		"fx_frost":
			engine.freeze(int(engine.state().players[_enemy(side)].hero.entity_id))
		"fx_scout":
			_discover(engine, ctx)
		"fx_swarm":
			while engine.state().players[side].board.size() < engine.rule("board_size"):
				if engine.summon_minion(side, "fx_grunt", -1) == RulesEngine.NO_ENTITY:
					break
		"fx_guard":
			@warning_ignore("return_value_discarded")
			engine.summon_minion(side, "fx_wall", -1)
			@warning_ignore("return_value_discarded")
			engine.summon_minion(side, "fx_shade", -1)
		"fx_bolt":
			if ctx.get("target_id") != null:
				@warning_ignore("return_value_discarded")
				engine.apply_damage(int(ctx.target_id), BOLT_DAMAGE, ctx.source)


func _on_battlecry(engine: RulesEngine, ctx: Dictionary) -> void:
	_count(engine, "battlecries")
	if str(ctx.card_id) == "fx_seer":
		_discover(engine, ctx)


## Discover for the caster: [constant DISCOVER_OPTIONS] shuffled with
## `rng_match` (so a Discover draws, as Card Effects' pool sampling does); the
## resolver's continuation is plain data.
func _discover(engine: RulesEngine, ctx: Dictionary) -> void:
	var options: Array = DISCOVER_OPTIONS.duplicate()
	engine.rng_match().shuffle(options)
	@warning_ignore("return_value_discarded")
	engine.discover(str(ctx.side), options, MatchRecords.CHOICE_DISCOVER, ctx.source, DISCOVER_EFFECT_ID)
	engine.state().effects.pending_choice = {"effect_id": DISCOVER_EFFECT_ID, "source": ctx.source}


func _resume(engine: RulesEngine, choice: Dictionary, index: int) -> void:
	@warning_ignore("return_value_discarded")
	engine.add_card_to_hand(str(choice.side), str(choice.options[index]))
	engine.state().effects.pending_choice = null
	_count(engine, "picks")


# --- match construction ----------------------------------------------------------

## `[[id, n], …]` → the deck list, in order.
static func _deck(spec: Array) -> Array:
	var out: Array = []
	for row: Array in spec:
		for _i: int in int(row[1]):
			out.append(str(row[0]))
	return out


func _start(seed_value: int, log: TestEventLog, player_deck: Array, boss_deck: Array, boss_health: Variant = null, rules_overrides: Dictionary = {}, player_hooks: Array = [], boss_hooks: Array = []) -> Array:
	var resolver: TestEffectResolver = _resolver()
	var boss: Dictionary = {"deck": _deck(boss_deck), "hook_installers": boss_hooks}
	if boss_health != null:
		boss["health"] = int(boss_health)
	var overrides: Dictionary = {"player": {"deck": _deck(player_deck), "hook_installers": player_hooks}, "boss": boss}
	var engine: RulesEngine = MatchFactory.make_started_engine(TestRngService.new(seed_value), log, overrides, rules_overrides, resolver, _db())
	return [engine, resolver]


# --- AC-39 fixture loading ---------------------------------------------------------

func _fixture_paths() -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(FIXTURE_DIR):
		if file.ends_with(".json"):
			out.append(FIXTURE_DIR + file)
	out.sort()
	return out


func _read_fixture(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(parsed is Dictionary).override_failure_message("%s is not a JSON object" % path).is_true()
	return parsed if parsed is Dictionary else {}


## The fixture's engine after its commands, or null (with a failure) when a
## command could not be found or was rejected.
func _engine_for(fixture: Dictionary) -> RulesEngine:
	var decks: Dictionary = fixture.decks
	var started: Array = _start(REPLAY_SEED, TestEventLog.new(), decks.player, decks.boss, fixture.get("boss_health"), fixture.get("rules_overrides", {}))
	var engine: RulesEngine = started[0]
	if not _run_script(engine, fixture.commands, str(fixture.name)):
		return null
	return engine


func _run_script(engine: RulesEngine, commands: Array, name: String) -> bool:
	for raw: Dictionary in commands:
		if raw.has("repeat"):
			for _i: int in int(raw.repeat):
				if not _run_script(engine, raw.commands, name):
					return false
			continue
		var command: Variant = _pick(engine, raw) if raw.has("pick") else raw
		if command == null:
			if bool(raw.get("optional", false)):
				continue
			assert_bool(false).override_failure_message("%s: no legal %s for %s" % [name, str(raw.pick), str(raw)]).is_true()
			return false
		var result: Dictionary = engine.submit(command)
		if not result.accepted:
			assert_bool(false).override_failure_message("%s: %s rejected %s" % [name, str(command), str(result.rejection)]).is_true()
			return false
	return true


## The first `legal_commands()` entry of the pick's type (and issuer, and hand
## card `card_id` for a play), or null.
func _pick(engine: RulesEngine, spec: Dictionary) -> Variant:
	var issuer: String = str(spec.get("issuer", engine.active_side()))
	for command: Dictionary in engine.legal_commands():
		if str(command.type) != str(spec.pick):
			continue
		if str(command.issuer) != issuer and str(spec.pick) != MatchRecords.CMD_MULLIGAN:
			continue
		if spec.has("card_id"):
			var card: Dictionary = engine.state().players[issuer].hand[int(command.hand_index)]
			if str(card.def_id) != str(spec.card_id):
				continue
		return command
	return null


func _assert_expectations(engine: RulesEngine, fixture: Dictionary) -> void:
	var name: String = str(fixture.name)
	var expect: Dictionary = fixture.expect
	var state: MatchState = engine.state()
	assert_str(engine.phase()).override_failure_message("%s: phase" % name).is_equal(str(expect.phase))
	assert_str(String(engine.active_side())).override_failure_message("%s: active side" % name).is_equal(str(expect.active_side))
	assert_int(state.turn).override_failure_message("%s: turn" % name).is_equal(int(expect.turn))
	for side: String in expect.get("boards", {}):
		assert_int(state.players[side].board.size()).override_failure_message("%s: %s board" % [name, side]).is_equal(int(expect.boards[side]))
	for side: String in expect.get("decks", {}):
		assert_int(state.players[side].deck.size()).override_failure_message("%s: %s deck" % [name, side]).is_equal(int(expect.decks[side]))
	if expect.has("weapon"):
		assert_bool(state.players[str(expect.weapon)].weapon != null).override_failure_message("%s: weapon" % name).is_true()
	if expect.has("frozen_hero"):
		assert_bool(bool(state.players[str(expect.frozen_hero)].hero.frozen)).override_failure_message("%s: frozen hero" % name).is_true()


# --- AC-39 random commands ----------------------------------------------------------

## One structurally plausible command drawn from [param stream]: a random
## type, issuer, ids, indices and positions (each range one past valid).
func _random_command(engine: RulesEngine, stream: TestRngStream) -> Dictionary:
	var type: String = SAMPLE_TYPES[stream.randi_range(0, SAMPLE_TYPES.size() - 1)]
	var issuer: String = MatchRecords.SIDES[stream.randi_range(0, MatchRecords.SIDES.size() - 1)]
	var max_id: int = engine.state().next_entity_id + SAMPLE_RANGE_PAD
	match type:
		MatchRecords.CMD_MULLIGAN:
			var hand: int = engine.state().players[SIDE_PLAYER].hand.size()
			var mask: Array[bool] = []
			for _i: int in stream.randi_range(maxi(0, hand - 1), hand + 1):
				mask.append(stream.randi_range(0, 1) == 1)
			return MatchRecords.mulligan(mask, issuer)
		MatchRecords.CMD_PLAY_CARD:
			var position: Variant = _maybe(stream, stream.randi_range(-1, SAMPLE_MAX_POSITION))
			return MatchRecords.play_card(issuer, stream.randi_range(-1, SAMPLE_MAX_INDEX), position, _maybe(stream, stream.randi_range(0, max_id)))
		MatchRecords.CMD_ATTACK:
			return MatchRecords.attack(issuer, stream.randi_range(0, max_id), stream.randi_range(0, max_id))
		MatchRecords.CMD_USE_HERO_POWER:
			return MatchRecords.use_hero_power(issuer, _maybe(stream, stream.randi_range(0, max_id)))
		MatchRecords.CMD_CHOOSE:
			return MatchRecords.choose(issuer, stream.randi_range(-1, SAMPLE_MAX_OPTION))
	return MatchRecords.end_turn(issuer)


## [param value], or null one time in [constant SAMPLE_NULL_ONE_IN] (the draw is always taken).
static func _maybe(stream: TestRngStream, value: int) -> Variant:
	return null if stream.randi_range(1, SAMPLE_NULL_ONE_IN) == 1 else value


## Whether [param command] should be accepted: listed in [param legal] once
## its don't-care arguments are dropped (C2: `position` is for minions only,
## and a `target_id` given to a card or power whose targeting is `none` — or
## to a Battlecry body whose `required` target has no legal choice — is
## ignored, so `legal_commands()` lists them as null), or one of C2's
## accepted-but-unlisted shapes: a Mulligan mask other than "keep all" (only
## keep-all is listed; `concede` is not sampled).
func _expected_accepted(engine: RulesEngine, command: Dictionary, legal: Array) -> bool:
	if legal.has(_canonical(engine, command)):
		return true
	if command.type == MatchRecords.CMD_MULLIGAN and engine.phase() == MatchState.PHASE_MULLIGAN and command.issuer == SIDE_PLAYER:
		return (command.keep_mask as Array).size() == engine.state().players[SIDE_PLAYER].hand.size()
	return false


## [param command] with the arguments C2 ignores set to null (see
## [method _expected_accepted]); a copy, unchanged when its hand index names
## no card of the issuer.
func _canonical(engine: RulesEngine, command: Dictionary) -> Dictionary:
	var out: Dictionary = command.duplicate(true)
	var lookup: TestEffectResolver = _resolver()
	match str(command.type):
		MatchRecords.CMD_PLAY_CARD:
			var hand: Array = engine.state().players[str(command.issuer)].hand
			var index: int = int(command.hand_index)
			if index < 0 or index >= hand.size():
				return out
			var def_id: String = str(hand[index].def_id)
			var type: String = str(_db().card(def_id).type)
			if type != RulesEngine.CARD_MINION:
				out.erase("position")   # `MatchRecords.play_card` omits a null position
			var mode: String = str(lookup.targeting_spec(def_id).mode)
			var no_target: bool = type != RulesEngine.CARD_SPELL and lookup.legal_targets(def_id, {}).is_empty()
			if mode == RulesEngine.TARGETING_NONE or (mode == RulesEngine.TARGETING_REQUIRED and no_target):
				out.target_id = null
		MatchRecords.CMD_USE_HERO_POWER:
			var power_id: String = str(engine.state().players[str(command.issuer)].hero_power.def_id)
			if str(lookup.targeting_spec(power_id).mode) == RulesEngine.TARGETING_NONE:
				out.target_id = null
	return out


# --- AC-38: replay policy ------------------------------------------------------------

## The scripted match's command at [param step]: a mulligan that replaces the
## first card, a rotating Discover pick, else the first available type of
## [constant POLICY_ORDER] — an attack on a minion when one is legal — chosen
## by a rotating index.
func _policy(engine: RulesEngine, step: int) -> Dictionary:
	match engine.phase():
		MatchState.PHASE_MULLIGAN:
			var mask: Array[bool] = []
			for i: int in engine.state().players[SIDE_PLAYER].hand.size():
				mask.append(i != 0)
			return MatchRecords.mulligan(mask)
		MatchState.PHASE_CHOICE:
			var choice: Dictionary = engine.pending_choice()
			return MatchRecords.choose(str(choice.side), step % (choice.options as Array).size())
	var legal: Array = engine.legal_commands()
	for type: String in POLICY_ORDER:
		var of_type: Array = legal.filter(func(c: Dictionary) -> bool: return c.type == type)
		if type == MatchRecords.CMD_ATTACK:
			var at_minions: Array = of_type.filter(func(c: Dictionary) -> bool: return not BOLT_TARGETS.has(int(c.target_id)))
			if not at_minions.is_empty():
				of_type = at_minions
		if not of_type.is_empty():
			return of_type[(step * 7) % of_type.size()]
	return MatchRecords.end_turn(String(engine.active_side()))


## Plays the AC-38 match on [param engine]: 199 policy commands, then the
## player's concede. Returns the commands (deep copies) and their results.
func _play_scripted_match(engine: RulesEngine) -> Array:
	var commands: Array = []
	var results: Array = []
	for step: int in COMMAND_COUNT - 1:
		if engine.phase() == MatchState.PHASE_ENDED:
			break
		var command: Dictionary = _policy(engine, step)
		commands.append(command.duplicate(true))
		results.append(engine.submit(command))
	if engine.phase() != MatchState.PHASE_ENDED:
		var concede: Dictionary = MatchRecords.concede(SIDE_PLAYER)
		commands.append(concede)
		results.append(engine.submit(concede))
	return [commands, results]


# --- C2 isolation fixture --------------------------------------------------------------

## A live match at BossTurn.Main with two treasures, a boss passive, a
## non-empty `effects` and a pending boss Discover (the boss's Seer
## Battlecry). Returns `[engine, resolver]`.
func _boss_discover_fixture(log: TestEventLog) -> Array:
	var treasures: Array = [
		MatchFactory.make_hook_installer("treasure_a", SIDE_PLAYER, ["modify_cost", "on_turn_start"]),
		MatchFactory.make_hook_installer("treasure_b", SIDE_PLAYER, ["on_turn_end", "modify_damage"]),
	]
	var passive: Array = [MatchFactory.make_hook_installer("boss_passive", SIDE_BOSS, ["modify_max_attacks", "on_turn_start"])]
	var started: Array = _start(REPLAY_SEED, log, [["fx_grunt", 15]], [["fx_seer", 15]], null, {}, treasures, passive)
	var engine: RulesEngine = started[0]
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()   # a grunt
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	engine.state().players[SIDE_BOSS].mana_current = BOSS_MANA
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_BOSS, 0, 0, null)).accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_str(String(engine.active_side())).is_equal(SIDE_BOSS)
	return started


## Value copies of every entity the state holds, the hook entries per point,
## and every plain-data `MatchState` field — what "the live match is
## unchanged" compares.
func _fingerprint(engine: RulesEngine) -> Dictionary:
	var state: MatchState = engine.state()
	var entities: Dictionary = {}
	for id: int in range(MatchState.FIRST_ENTITY_ID, state.next_entity_id):
		entities[id] = engine.state_snapshot(id)
	var hooks: Dictionary = {}
	for point: StringName in HookRegistry.TRIGGER_POINTS + HookRegistry.VALUE_POINTS:
		hooks[point] = state.hooks.entries(point).duplicate(true)
	return {
		"entities": entities, "hooks": hooks, "turn": state.turn, "active_side": state.active_side,
		"phase": state.phase, "players": state.players.duplicate(true),
		"pending_choice": engine.pending_choice(), "result": engine.result(),
		"next_entity_id": state.next_entity_id, "effects": state.effects.duplicate(true),
		"suspended_queue": state.suspended_queue.duplicate(true), "suspended_steps": state.suspended_steps,
		"suspended_action": state.suspended_action.duplicate(true),
	}


## The clone's resolver (the double records its last clone as a weak reference).
static func _clone_resolver(live: TestEffectResolver) -> TestEffectResolver:
	return live.last_clone.get_ref() if live.last_clone != null else null


## The clone's next command: a rotating non-concede legal command.
static func _clone_step(engine: RulesEngine, step: int) -> Dictionary:
	var legal: Array = engine.legal_commands().filter(func(c: Dictionary) -> bool: return c.type != MatchRecords.CMD_CONCEDE)
	return legal[(step * 5) % legal.size()]


# --- AC-38 ---------------------------------------------------------------------------

func test_a_200_command_match_replays_byte_identical_with_an_equal_result() -> void:
	# Arrange: engine A plays the scripted match; its commands are recorded
	var log_a: TestEventLog = TestEventLog.new()
	var a: RulesEngine = _start(REPLAY_SEED, log_a, REPLAY_PLAYER_DECK, REPLAY_BOSS_DECK, REPLAY_BOSS_HEALTH, {"starting_health_player": REPLAY_PLAYER_HEALTH})[0]
	var played: Array = _play_scripted_match(a)
	var commands: Array = played[0]
	var results_a: Array = played[1]

	# Act: the same seed and commands on a fresh engine
	var log_b: TestEventLog = TestEventLog.new()
	var b: RulesEngine = _start(REPLAY_SEED, log_b, REPLAY_PLAYER_DECK, REPLAY_BOSS_DECK, REPLAY_BOSS_HEALTH, {"starting_health_player": REPLAY_PLAYER_HEALTH})[0]
	var results_b: Array = []
	for command: Dictionary in commands:
		results_b.append(b.submit(command.duplicate(true)))

	# Assert: the script is the AC's (200 accepted commands of every kind, ends Ended)
	assert_int(commands.size()).override_failure_message("the match ended after %d commands: %s" % [commands.size(), str(a.result())]).is_equal(COMMAND_COUNT)
	for result: Dictionary in results_a:
		assert_bool(result.accepted).override_failure_message("scripted command rejected: %s" % str(result.rejection)).is_true()
	var types: Array = commands.map(func(c: Dictionary) -> String: return str(c.type))
	for type: String in REQUIRED_TYPES:
		assert_bool(types.has(type)).override_failure_message("the scripted match has no %s" % type).is_true()
	assert_str(str(types.back())).is_equal(MatchRecords.CMD_CONCEDE)
	assert_str(a.phase()).is_equal(MatchState.PHASE_ENDED)
	# byte-identical logs, equal results
	EventLogAssertions.assert_replay_equal(log_a.events, log_b.events)
	assert_str(log_b.to_json()).is_equal(log_a.to_json())
	assert_array(results_b).is_equal(results_a)
	assert_dict(b.result()).is_equal(a.result())


# --- AC-39 ---------------------------------------------------------------------------

func test_there_are_ten_fixture_states_and_each_reaches_its_expected_state() -> void:
	# Arrange
	var paths: Array[String] = _fixture_paths()

	# Act / Assert
	assert_int(paths.size()).is_equal(FIXTURE_COUNT)
	for path: String in paths:
		var fixture: Dictionary = _read_fixture(path)
		var engine: RulesEngine = _engine_for(fixture)
		assert_object(engine).override_failure_message("%s did not load" % path).is_not_null()
		if engine != null:
			_assert_expectations(engine, fixture)
			assert_array(engine.legal_commands()).override_failure_message("%s lists no command" % path).is_not_empty()
			engine.end_match()


func test_every_legal_command_of_every_fixture_state_is_accepted_on_a_fresh_clone() -> void:
	for path: String in _fixture_paths():
		# Arrange
		var engine: RulesEngine = _engine_for(_read_fixture(path))
		if engine == null:
			continue
		var legal: Array = engine.legal_commands()
		for command: Dictionary in legal:
			# Act
			var sandbox: RulesEngine = engine.clone()
			var result: Dictionary = sandbox.submit(command.duplicate(true))

			# Assert
			assert_bool(result.accepted).override_failure_message("%s: listed %s rejected %s" % [path, str(command), str(result.rejection)]).is_true()
			sandbox.end_match()
		engine.end_match()


func test_200_sampled_commands_absent_from_legal_commands_are_rejected_in_every_fixture_state() -> void:
	for path: String in _fixture_paths():
		# Arrange: the fixture's own seeded stream
		var fixture: Dictionary = _read_fixture(path)
		var engine: RulesEngine = _engine_for(fixture)
		if engine == null:
			continue
		var stream: TestRngStream = TestRngStream.seeded("sample", int(fixture.sample_seed))
		var legal: Array = engine.legal_commands()
		var rejected: int = 0
		for _i: int in COMMAND_COUNT:
			var command: Dictionary = _random_command(engine, stream)
			var expected: bool = _expected_accepted(engine, command, legal)

			# Act
			var sandbox: RulesEngine = engine.clone()
			var result: Dictionary = sandbox.submit(command)

			# Assert: accepted exactly when listed (or one of C2's two unlisted shapes)
			assert_bool(result.accepted).override_failure_message("%s: %s accepted=%s, expected %s (%s)" % [path, str(command), str(result.accepted), str(expected), str(result.rejection)]).is_equal(expected)
			if not result.accepted:
				rejected += 1
			sandbox.end_match()
		assert_int(rejected).override_failure_message("%s: the sample rejected nothing" % path).is_greater(0)
		engine.end_match()


# --- C2 clone isolation ----------------------------------------------------------------

func test_twenty_commands_on_a_clone_leave_the_live_match_log_and_stream_unchanged() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var started: Array = _boss_discover_fixture(log)
	var live: RulesEngine = started[0]
	var seq: int = log.events.size()
	var draws: int = live.rng_match().draws
	var before: Dictionary = _fingerprint(live)

	# Act
	var sandbox: RulesEngine = live.clone()
	var submitted: int = 0
	for step: int in CLONE_COMMANDS:
		if sandbox.phase() == MatchState.PHASE_ENDED:
			break
		assert_bool(sandbox.submit(_clone_step(sandbox, step)).accepted).is_true()
		submitted += 1

	# Assert: the clone did 20 things; nothing live moved
	assert_int(submitted).is_equal(CLONE_COMMANDS)
	assert_int((sandbox.state().log as EventLog).size()).is_greater(0)
	assert_int(sandbox.rng_match().draws).override_failure_message("the clone drew nothing: the stream check is vacuous").is_greater(draws)
	assert_int(log.events.size()).is_equal(seq)
	assert_int(live.rng_match().draws).is_equal(draws)
	assert_dict(_fingerprint(live)).is_equal(before)
	sandbox.end_match()


func test_a_clone_copies_hooks_by_value_and_binds_a_fresh_resolver_with_no_installers() -> void:
	# Arrange
	var started: Array = _boss_discover_fixture(TestEventLog.new())
	var live: RulesEngine = started[0]
	var live_resolver: TestEffectResolver = started[1]
	var live_calls: int = live_resolver.hook_calls.size()

	# Act
	var sandbox: RulesEngine = live.clone()
	var resolver: TestEffectResolver = _clone_resolver(live_resolver)
	@warning_ignore("return_value_discarded")
	sandbox.hero_power_cost(SIDE_PLAYER)   # one modify_cost fold on the clone's registry

	# Assert: same entries by value, never the same Dictionaries
	assert_int(sandbox.state().hooks.entry_count()).is_equal(live.state().hooks.entry_count())
	assert_object(sandbox.state().hooks).is_not_same(live.state().hooks)
	for point: StringName in HookRegistry.TRIGGER_POINTS + HookRegistry.VALUE_POINTS:
		var mine: Array = sandbox.state().hooks.entries(point)
		var theirs: Array = live.state().hooks.entries(point)
		assert_array(mine).is_equal(theirs)
		for i: int in mine.size():
			assert_bool(is_same(mine[i], theirs[i])).override_failure_message("entry %s[%d] is shared" % [point, i]).is_false()
	# a different resolver, bound to the clone with no installers; evaluators on the clone only
	assert_object(resolver).is_not_null()
	assert_object(resolver).is_not_same(live_resolver)
	assert_object(resolver.engine).is_same(sandbox)
	assert_object(live_resolver.engine).is_same(live)
	assert_int(resolver.bind_calls.size()).is_equal(1)
	assert_array(resolver.bind_calls[0].installers).is_empty()
	assert_int(resolver.hook_calls.size()).is_equal(1)
	assert_int(live_resolver.hook_calls.size()).is_equal(live_calls)
	assert_str(str(resolver.hook_calls[0].effect_id)).is_equal("treasure_a.0")
	sandbox.end_match()


func test_a_clone_carries_the_pending_discover_and_choose_resumes_it_on_the_clone_only() -> void:
	# Arrange
	var started: Array = _boss_discover_fixture(TestEventLog.new())
	var live: RulesEngine = started[0]
	var boss_hand: int = live.state().players[SIDE_BOSS].hand.size()
	var offered: Array = live.pending_choice().options

	# Act
	var sandbox: RulesEngine = live.clone()
	var same_choice: bool = sandbox.pending_choice() == live.pending_choice()
	var same_continuation: bool = sandbox.state().effects.pending_choice == live.state().effects.pending_choice
	var same_action: bool = sandbox.state().suspended_action == live.state().suspended_action
	var result: Dictionary = sandbox.submit(MatchRecords.choose(SIDE_BOSS, 1))

	# Assert: equal before; resumed on the clone (pick in hand, back to Main); live still pending
	assert_bool(same_choice).is_true()
	assert_bool(same_continuation).is_true()
	assert_bool(same_action).is_true()
	assert_object(live.state().effects.pending_choice).is_not_null()
	assert_bool(result.accepted).is_true()
	assert_str(sandbox.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_int(sandbox.state().players[SIDE_BOSS].hand.size()).is_equal(boss_hand + 1)
	assert_str(str(sandbox.state().players[SIDE_BOSS].hand.back().def_id)).is_equal(str(offered[1]))
	assert_object(sandbox.state().effects.pending_choice).is_null()
	EventLogAssertions.assert_order((sandbox.state().log as EventLog).events_since(0), ["choice_made", "phase_changed", "card_added_to_hand"])
	assert_str(live.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_int(live.state().players[SIDE_BOSS].hand.size()).is_equal(boss_hand)
	sandbox.end_match()


func test_the_clones_first_rng_draw_is_the_live_streams_next_draw() -> void:
	# Arrange
	var started: Array = _boss_discover_fixture(TestEventLog.new())
	var live: RulesEngine = started[0]
	var sandbox: RulesEngine = live.clone()

	# Act: the clone draws first, then the live stream
	var from_clone: int = sandbox.rng_match().randi_range(0, RngStream.MAX_RANGE_SPAN - 1)
	var from_live: int = live.rng_match().randi_range(0, RngStream.MAX_RANGE_SPAN - 1)

	# Assert: same value, separate streams
	assert_int(from_clone).is_equal(from_live)
	assert_object(sandbox.rng_match()).is_not_same(live.rng_match())
	assert_str(str(sandbox.rng_match().name)).is_equal(str(live.rng_match().name))
	sandbox.end_match()


func test_the_clones_scratch_log_is_detached_and_discarded_with_the_clone() -> void:
	# Arrange: a live subscriber counts deliveries
	var log: TestEventLog = TestEventLog.new()
	var started: Array = _boss_discover_fixture(log)
	var live: RulesEngine = started[0]
	var delivered: Dictionary = {"n": 0}
	log.subscribe(func(_e: Dictionary) -> void: delivered.n += 1)
	var sandbox: RulesEngine = live.clone()
	var scratch: EventLog = sandbox.state().log as EventLog

	# Act
	assert_bool(sandbox.submit(MatchRecords.choose(SIDE_BOSS, 0)).accepted).is_true()
	var scratch_events: int = scratch.size()
	var scratch_ref: WeakRef = weakref(scratch)
	var sandbox_ref: WeakRef = weakref(sandbox)
	scratch = null
	sandbox.end_match()
	sandbox = null

	# Assert: the clone's events went to its own log only; both are freed
	assert_object(scratch_ref).is_not_null()
	assert_int(scratch_events).is_greater(0)
	assert_int(int(delivered.n)).is_equal(0)
	assert_object(live.state().log).is_same(log)
	assert_object(sandbox_ref.get_ref()).is_null()
	assert_object(scratch_ref.get_ref()).is_null()


func test_a_clones_effect_runtime_is_equal_by_value_and_its_counters_are_isolated() -> void:
	# Arrange (moved from card-effects story 002 AC-1)
	var started: Array = _boss_discover_fixture(TestEventLog.new())
	var live: RulesEngine = started[0]
	assert_dict(live.state().effects.counters).is_not_empty()
	var original: Dictionary = live.state().effects.duplicate(true)

	# Act
	var sandbox: RulesEngine = live.clone()
	var equal_at_clone: bool = sandbox.state().effects == live.state().effects
	sandbox.state().effects.counters["casts"] = COUNTER_PROBE
	sandbox.state().effects.once_marks["probe"] = true

	# Assert
	assert_bool(equal_at_clone).is_true()
	assert_object(sandbox.state().effects).is_not_same(live.state().effects)
	assert_dict(live.state().effects).is_equal(original)
	assert_int(int(sandbox.state().effects.counters.casts)).is_equal(COUNTER_PROBE)
	sandbox.end_match()


func test_a_clone_of_an_ended_match_is_ended_and_binds_no_resolver() -> void:
	# Arrange
	var started: Array = _boss_discover_fixture(TestEventLog.new())
	var live: RulesEngine = started[0]
	var live_resolver: TestEffectResolver = started[1]
	assert_bool(live.submit(MatchRecords.concede(SIDE_PLAYER)).accepted).is_true()

	# Act
	var sandbox: RulesEngine = live.clone()
	var result: Dictionary = sandbox.submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	assert_str(sandbox.phase()).is_equal(MatchState.PHASE_ENDED)
	assert_dict(sandbox.result()).is_equal(live.result())
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_MATCH_ENDED)
	assert_array(_clone_resolver(live_resolver).bind_calls).is_empty()


# --- C2 isolation with the production resolver (card-effects story 010) -------------

func _real_db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	var pool: Array = []
	for i: int in POOL_SPELL_COUNT:
		var spell: Dictionary = CardFactory.make_spell("war_test_spell_%02d" % i, 1, [], {"set": HERO_SET})
		by_id[spell.id] = spell
		pool.append(spell)
	var study_effects: Variant = JSON.parse_string(
		'[{"trigger":"cast","ops":[{"op":"discover","pool":"collectible","filter":{"type":"spell"}},'
		+ '{"op":"damage","targets":"enemy_hero","amount":%d}]}]' % STUDY_DAMAGE)
	by_id[STUDY] = CardFactory.make_spell(STUDY, 1, study_effects, {"set": HERO_SET, "keywords": ["discover"]})
	by_id[GRUNT] = CardFactory.make_minion(GRUNT, 1, 1, 2, [], {"set": HERO_SET})
	pool.append(by_id[STUDY])
	pool.append(by_id[GRUNT])
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	return FakeCardDatabase.new(by_id, {HERO_SET: pool})


func _real_effects_config() -> Dictionary:
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


## A live engine on the production `EffectResolver` (War hero set), player
## Main with two Study spells in hand, the first cast and paused on its
## collectible Discover. Returns the engine.
func _real_paused_engine(db: FakeCardDatabase, log: TestEventLog) -> RulesEngine:
	var deck: Array = []
	for _i: int in REAL_DECK_SIZE:
		deck.append(GRUNT)
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(REAL_SEED), log, {"player": {"deck": deck}, "boss": {"deck": deck}})
	var engine: RulesEngine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _real_effects_config(), HERO_SET))
	engine.start(config)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = engine.state()
	var hand: Array = state.players[SIDE_PLAYER].hand
	hand.clear()
	for _i: int in 2:
		hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), STUDY, "hand"))
	state.players[SIDE_PLAYER].mana_current = REAL_MANA
	state.players[SIDE_PLAYER].mana_max = REAL_MANA
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null)).accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	return engine


## `[type, payload]` of [param events] — what two logs whose `seq` numbering
## differs (live vs scratch) must agree on.
static func _shapes(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> Array: return [str(e.type), e.payload])


func test_a_clone_on_the_production_resolver_resumes_a_collectible_discover_and_draws_the_same_pool() -> void:
	# Arrange: paused on the first Study's Discover (options from collectible_pool("war"))
	var db: FakeCardDatabase = _real_db()
	var log: TestEventLog = TestEventLog.new()
	var live: RulesEngine = _real_paused_engine(db, log)
	var offered: Array = live.pending_choice().options
	var sandbox: RulesEngine = live.clone()
	var scratch: EventLog = sandbox.state().log as EventLog
	var queries_before: int = db.pool_queries.size()
	var live_mark: int = log.events.size()

	# Act: the same commands on both — the pick, then the second Study (a fresh pool draw)
	var commands: Array = [MatchRecords.choose(SIDE_PLAYER, 1), MatchRecords.play_card(SIDE_PLAYER, 0, null, null), MatchRecords.choose(SIDE_PLAYER, 0)]
	for command: Dictionary in commands:
		assert_bool(sandbox.submit(command.duplicate(true)).accepted).is_true()
	var sandbox_queries: Array[String] = db.pool_queries.slice(queries_before)
	for command: Dictionary in commands:
		assert_bool(live.submit(command.duplicate(true)).accepted).is_true()

	# Assert: the continuation resumed identically, and the clone's resolver
	# drew from the same hero set's pool (by value — the live one did too)
	assert_bool(EffectRuntime.is_runtime(sandbox.state().effects)).is_true()
	assert_array(offered).is_not_empty()
	assert_array(sandbox_queries).contains([HERO_SET])
	assert_array(_shapes(scratch.events_since(0))).is_equal(_shapes(log.events.slice(live_mark)))
	assert_int(EventLogAssertions.count_type(scratch.events_since(0), &"discover_offered")).is_equal(1)
	assert_int(EventLogAssertions.count_type(scratch.events_since(0), &"discover_picked")).is_equal(2)
	var picks: Array = sandbox.state().players[SIDE_PLAYER].hand.map(func(c: Dictionary) -> String: return str(c.def_id))
	assert_bool(picks.has(str(offered[1]))).is_true()
	assert_array(picks).is_equal(live.state().players[SIDE_PLAYER].hand.map(func(c: Dictionary) -> String: return str(c.def_id)))
	assert_int(sandbox.health(sandbox.state().players[SIDE_BOSS].hero)).is_equal(live.health(live.state().players[SIDE_BOSS].hero))
	assert_int(sandbox.rng_match().draws).is_equal(live.rng_match().draws)
	sandbox.end_match()
	live.end_match()
