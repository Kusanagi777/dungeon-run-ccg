## The golden logs of the rules engine (match-rules story 019 AC-2; QA plan
## sprint 5 NC-3): each golden is the canonical text of what one fixture does,
## recorded on the unchanged engine, so an engine optimisation has to leave
## every event, `legal_commands()` list, `state_snapshot()`, `CommandResult` and
## `MatchResult` byte-identical.
##
## [method capture] builds a golden's text from the code under test, and it is
## the one builder: `tools/match_rules/record_golden_logs.gd` writes it to
## [constant GOLDEN_DIR], and `tests/unit/match_rules/match_rules_golden_log_test.gd`
## compares it with the committed file. A golden is one canonical-JSON object per
## line, LF, so a failure names the first line that moved.
## - [constant CHAIN]: the 56-pass Deathrattle chain `submit`, live and on a clone.
## - [constant FULL_BOARD]: the full-board `legal_commands()` list.
## - `state_<fixture>`: every legal command of a `tests/fixtures/match_states/`
##   state, each on a fresh clone. A row holds only the entities that moved from
##   the state's base dump, so the rows stay small and lose nothing.
## - [constant SCRIPTED]: the AC-38 200-command match.
## - [constant AURAS]: the C10 aura pass: an aura source's whole life, then each
##   primitive in [constant RulesEngine.PRIMITIVES] called from inside the pass.
## - [constant AURA_HOLDERS]: one aura on one holder alone, for each kind the C10
##   strip walks, so a holder the strip or its scan misses shows as an aura that
##   stacks on every recompute. In [constant AURAS] a source always holds several.
## - [constant TRIGGERS]: the engine's observer order. Every other golden has no
##   observer responding, so `ctx.candidates` could change unseen: here every
##   character and weapon answers every observer point, so the `trigger_queued`
##   order **is** the candidate order, and one `on_damage` raises `on_summon`
##   from inside `resolve()`, so a reused buffer that the nested raise overwrites
##   queues a trigger the raise-time list did not hold.
##
## **Regenerating is a design event, never a fix.** A golden changes only with a
## reviewed rules change, in that change's own commit (QA plan Cross-cutting 3).
## [codeblock]
## var golden := MatchGoldenLogs.new()
## for name: String in golden.names():
##     print(golden.capture(name).length())
## [/codeblock]
class_name MatchGoldenLogs
extends RefCounted

const GOLDEN_DIR: String = "res://tests/fixtures/match_rules/golden_logs/"
const GOLDEN_EXTENSION: String = ".jsonl"
const CHAIN: String = "chain_submit"
const FULL_BOARD: String = "full_board_legal"
const SCRIPTED: String = "scripted_match"
const AURAS: String = "aura_passes"
const AURA_HOLDERS: String = "aura_holders"
const TRIGGERS: String = "trigger_order"
const STATE_PREFIX: String = "state_"

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
## The hero power both seats hold, as in the story 017 suite.
const REPLAY_POWER: String = "war_test_power"
## AC-38 match, kept in step with `match_rules_clone_replay_test.gd`, whose
## constants are private: commands, decks, healths, policy.
const COMMAND_COUNT: int = 200
const REPLAY_PLAYER_DECK: Array = [["fx_grunt", 8], ["fx_brute", 6], ["fx_scout", 4], ["fx_axe", 2], ["fx_bolt", 4], ["fx_frost", 2], ["fx_seer", 4]]
const REPLAY_BOSS_DECK: Array = [["fx_wall", 14], ["fx_grunt", 6], ["fx_seer", 6], ["fx_frost", 4]]
const REPLAY_BOSS_HEALTH: int = 300
const REPLAY_PLAYER_HEALTH: int = 40
const POLICY_ORDER: Array[String] = [MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_USE_HERO_POWER, MatchRecords.CMD_ATTACK, MatchRecords.CMD_END_TURN]
## The rotation of the policy's pick, the story 017 suite's.
const POLICY_STRIDE: int = 7
## `state().effects.counters` key: an aura-pass primitive runs on the first
## recompute only, so the pass stays one observable change.
const ONCE_KEY: String = "golden_once"
## The observer points [constant TRIGGERS] answers on every character and weapon.
const OBSERVER_POINTS: Array[StringName] = [
	&"on_damage", &"on_heal", &"on_summon", &"on_draw", &"on_minion_died", &"turn_start",
	&"turn_end", &"on_attack", &"on_card_played", &"on_play", &"after_cast", &"on_hero_power",
	&"on_weapon_equipped",
]
## Every kind of aura holder the C10 strip walks (characters, weapons, hands).
const HOLDER_KINDS: Array[String] = ["player_hero", "player_minion", "player_weapon", "player_hand", "boss_hero", "boss_minion", "boss_weapon", "boss_hand"]
## `state().effects.counters` key: the holder's aura is live while it is set.
const HOLDER_AURA_KEY: String = "golden_holder_aura"
## How many recomputes [constant AURA_HOLDERS] runs with the aura on, then off:
## a second recompute is what shows an unstripped aura stacking.
const HOLDER_RECOMPUTES: int = 2
## How far past `next_entity_id` the trigger golden's new entities land.
const NEW_ENTITIES: Array[int] = [0, 1, 2]
## `state().effects.counters` key of [method _summon_inside_resolve].
const NESTED_KEY: String = "golden_nested"
## Every zone a dump lists by id.
const CARD_ZONES: Array[String] = ["deck", "hand", "graveyard", "resolving"]

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()


## Every golden's name, sorted within each kind: the file stem under
## [constant GOLDEN_DIR].
func names() -> Array[String]:
	var out: Array[String] = [CHAIN, FULL_BOARD, SCRIPTED, AURAS, AURA_HOLDERS, TRIGGERS]
	for path: String in MatchBudgetFixtures.fixture_paths():
		out.append(STATE_PREFIX + str(MatchBudgetFixtures.read_fixture(path).name))
	return out


## The committed path of [param name].
static func path_of(name: String) -> String:
	return GOLDEN_DIR + name + GOLDEN_EXTENSION


## The text of golden [param name], built from the engine under test.
func capture(name: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	match name:
		CHAIN:
			_capture_chain(lines)
		FULL_BOARD:
			_capture_full_board(lines)
		SCRIPTED:
			_capture_scripted(lines)
		AURAS:
			_capture_auras(lines)
		AURA_HOLDERS:
			_capture_aura_holders(lines)
		TRIGGERS:
			_capture_triggers(lines)
		_:
			_capture_state(name, lines)
	return "\n".join(lines) + "\n"


# --- the goldens -----------------------------------------------------------------

func _capture_chain(lines: PackedStringArray) -> void:
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(false), log)
	var sandbox: RulesEngine = engine.clone()
	var on_clone: Dictionary = sandbox.submit(_fx.chain_command(sandbox))
	_row(lines, {"clone_result": on_clone})
	_rows(lines, "clone_event", sandbox.state().log.events_since(0))
	_row(lines, {"clone_dump": _dump(sandbox)})
	sandbox.end_match()
	var live: Dictionary = engine.submit(_fx.chain_command(engine))
	_row(lines, {"result": live})
	_rows(lines, "event", log.events)
	_row(lines, {"dump": _dump(engine)})
	engine.end_match()


func _capture_full_board(lines: PackedStringArray) -> void:
	var engine: RulesEngine = _fx.make_full_board_engine(_fx.make_resolver(false))
	_rows(lines, "legal", engine.legal_commands())
	engine.end_match()


func _capture_state(name: String, lines: PackedStringArray) -> void:
	var fixture: Dictionary = _fixture_named(name.trim_prefix(STATE_PREFIX))
	var engine: RulesEngine = _fx.engine_for(fixture, false, REPLAY_POWER)
	assert(engine != null, "golden %s: %s" % [name, _fx.last_error])
	var log: TestEventLog = engine.state().log
	_rows(lines, "event", log.events)
	var legal: Array = engine.legal_commands()
	_rows(lines, "legal", legal)
	var base: Dictionary = _dump(engine)
	_row(lines, {"base": base})
	for command: Dictionary in legal:
		var sandbox: RulesEngine = engine.clone()
		var result: Dictionary = sandbox.submit(command.duplicate(true))
		_row(lines, {"command": command, "result": result})
		_rows(lines, "command_event", sandbox.state().log.events_since(0))
		_row(lines, {"after": _delta(base, _dump(sandbox))})
		sandbox.end_match()
	engine.end_match()


func _capture_scripted(lines: PackedStringArray) -> void:
	var log: TestEventLog = TestEventLog.new()
	var boss: Dictionary = {"deck": MatchBudgetFixtures._deck(REPLAY_BOSS_DECK), "hook_installers": [], "health": REPLAY_BOSS_HEALTH}
	var overrides: Dictionary = {"player": {"deck": MatchBudgetFixtures._deck(REPLAY_PLAYER_DECK), "hook_installers": []}, "boss": boss}
	var engine: RulesEngine = MatchFactory.make_started_engine(TestRngService.new(MatchBudgetFixtures.REPLAY_SEED), log, overrides, {"starting_health_player": REPLAY_PLAYER_HEALTH}, _fx.make_resolver(false), _fx.make_db())
	for side: String in MatchRecords.SIDES:
		engine.state().players[side].hero_power.def_id = REPLAY_POWER
	for step: int in COMMAND_COUNT - 1:
		if engine.phase() == MatchState.PHASE_ENDED:
			break
		var command: Dictionary = _policy(engine, step)
		_row(lines, {"command": command.duplicate(true), "result": engine.submit(command)})
	if engine.phase() != MatchState.PHASE_ENDED:
		var concede: Dictionary = MatchRecords.concede(SIDE_PLAYER)
		_row(lines, {"command": concede, "result": engine.submit(concede)})
	_rows(lines, "event", log.events)
	_row(lines, {"match_result": engine.result()})
	_row(lines, {"dump": _dump(engine)})
	engine.end_match()


func _capture_auras(lines: PackedStringArray) -> void:
	_capture_aura_source_life(lines)
	for primitive: StringName in RulesEngine.PRIMITIVES:
		var log: TestEventLog = TestEventLog.new()
		var resolver: TestEffectResolver = _fx.make_resolver(false)
		var engine: RulesEngine = _fx.make_aura_board(resolver, log)
		var mark: int = log.events.size()
		resolver.aura_scripts.append(primitive_once.bind(primitive))
		engine.run_action(_no_step)
		_row(lines, {"scenario": String(primitive)})
		_rows(lines, "event", log.events.slice(mark))
		_row(lines, {"dump": _dump(engine)})
		engine.end_match()


## An aura source's life on one board: first applied, re-applied with nothing
## net (no event), Silenced, quiet with no aura left, then a new source summoned
## and killed, and a health aura whose loss kills what it held up (F6).
func _capture_aura_source_life(lines: PackedStringArray) -> void:
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver, log)
	var source_id: int = _fx.add_aura_source(resolver, engine)
	var first_id: int = int(engine.state().players[SIDE_PLAYER].board[0].entity_id)
	var steps: Array = [
		["first_apply", _no_step],
		["no_net_change", _no_step],
		["source_silenced", func() -> void: engine.silence(source_id)],
		["no_aura_left", _no_step],
		["minion_at_aura_health", func() -> void:
			resolver.auras[first_id] = {"attack_delta": MatchBudgetFixtures.AURA_ATTACK, "health_delta": MatchBudgetFixtures.AURA_HEALTH}],
		["second_source_damaged", func() -> void:
			var others: Array = engine.state().players[SIDE_PLAYER].board
			var held: int = int(others[1].entity_id)
			engine.apply_damage(held, MatchBudgetFixtures.GRUNT_HEALTH, null)],
		["source_dies_and_its_aura_with_it", func() -> void: engine.destroy(first_id)],
		["no_aura_left_again", _no_step],
	]
	for row: Array in steps:
		var mark: int = log.events.size()
		engine.run_action(row[1])
		_row(lines, {"scenario": str(row[0])})
		_rows(lines, "event", log.events.slice(mark))
		_row(lines, {"dump": _dump(engine)})
	engine.end_match()


## One aura on one holder and nothing else on the board: on for two recomputes
## (the second must change nothing), then off for two.
func _capture_aura_holders(lines: PackedStringArray) -> void:
	for holder: String in HOLDER_KINDS:
		var log: TestEventLog = TestEventLog.new()
		var resolver: TestEffectResolver = _fx.make_resolver(false)
		var engine: RulesEngine = _fx.make_aura_board(resolver, log)
		var state: MatchState = engine.state()
		state.players[SIDE_BOSS].weapon = MatchRecords.weapon(MatchFactory.alloc_entity_id(state), MatchBudgetFixtures.AXE, MatchBudgetFixtures.AURA_WEAPON_ATTACK, MatchBudgetFixtures.AURA_WEAPON_DURABILITY, [])
		MatchBudgetFixtures._set_hand(state, SIDE_BOSS, [MatchBudgetFixtures.GRUNT, MatchBudgetFixtures.BLANK])
		var aura: Dictionary = {"is_aura": true}
		if holder.ends_with("_hand"):
			aura["cost_delta"] = MatchBudgetFixtures.AURA_COST
		else:
			aura["attack_delta"] = MatchBudgetFixtures.AURA_ATTACK
		resolver.aura_scripts.append(_holder_aura.bind(_holder_id(state, holder), aura))
		var mark: int = log.events.size()
		_row(lines, {"scenario": holder})
		state.effects.counters[HOLDER_AURA_KEY] = 1
		for _i: int in HOLDER_RECOMPUTES:
			engine.run_action(_no_step)
		_row(lines, {"aura_on": _dump(engine)})
		@warning_ignore("return_value_discarded")
		state.effects.counters.erase(HOLDER_AURA_KEY)
		for _i: int in HOLDER_RECOMPUTES:
			engine.run_action(_no_step)
		_rows(lines, "event", log.events.slice(mark))
		_row(lines, {"aura_off": _dump(engine)})
		engine.end_match()


## The id of the first holder of [param holder]'s kind.
func _holder_id(state: MatchState, holder: String) -> int:
	var player: Dictionary = state.players[SIDE_PLAYER if holder.begins_with(SIDE_PLAYER) else SIDE_BOSS]
	if holder.ends_with("_hero"):
		return int(player.hero.entity_id)
	if holder.ends_with("_minion"):
		return int(player.board[0].entity_id)
	if holder.ends_with("_weapon"):
		return int(player.weapon.entity_id)
	return int(player.hand[0].instance_id)


## An aura-script entry: [param aura] on [param target] while the key is set.
func _holder_aura(engine: RulesEngine, target: int, aura: Dictionary) -> void:
	if engine.state().effects.counters.has(HOLDER_AURA_KEY):
		engine.apply_enchantment(target, aura)


## Each observer point fired with every candidate answering, on the live engine
## and then on a clone (the double copies its triggers). See [constant TRIGGERS].
func _capture_triggers(lines: PackedStringArray) -> void:
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver, log)
	var state: MatchState = engine.state()
	# before the ids below: dealing the hand takes entity ids too
	MatchBudgetFixtures._set_hand(state, SIDE_PLAYER, [MatchBudgetFixtures.GRUNT, MatchBudgetFixtures.BLANK, MatchBudgetFixtures.AXE])
	var ids: Array[int] = []
	for side: String in MatchRecords.SIDES:
		for minion: Dictionary in state.players[side].board:
			ids.append(int(minion.entity_id))
		ids.append(int(state.players[side].hero.entity_id))
	ids.append(int(state.players[SIDE_PLAYER].weapon.entity_id))
	# what the steps below will make (the played minion, the weapon, the nested
	# summon), so they answer too
	for offset: int in NEW_ENTITIES:
		ids.append(state.next_entity_id + offset)
	for point: StringName in OBSERVER_POINTS:
		for id: int in ids:
			resolver.add_trigger(point, id, "%s.%d" % [point, id])
	var mark: int = log.events.size()
	var minion: int = int(state.players[SIDE_PLAYER].board[0].entity_id)
	var enemy: int = int(state.players[SIDE_BOSS].board[0].entity_id)
	var steps: Array = [
		["play_minion", func() -> Dictionary: return engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))],
		["cast_spell", func() -> Dictionary: return engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0))],
		["play_weapon", func() -> Dictionary: return engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0))],
		["hero_power", func() -> Dictionary:
			state.players[SIDE_PLAYER].hero_power.used_this_turn = false
			return engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER, null))],
		["attack", func() -> Dictionary: return engine.submit(MatchRecords.attack(SIDE_PLAYER, minion, enemy))],
		["heal", func() -> Dictionary:
			engine.run_action(_heal_a_hero.bind(engine))
			return {}],
		["end_turn", func() -> Dictionary: return engine.submit(MatchRecords.end_turn(SIDE_PLAYER))],
	]
	for row: Array in steps:
		_row(lines, {"scenario": str(row[0]), "result": (row[1] as Callable).call()})
		_rows(lines, "event", log.events.slice(mark))
		mark = log.events.size()
	# the nested raise: `on_damage`'s collecting `resolve()` summons before it
	# walks its candidates, and that summon raises `on_summon`
	resolver.scripts[&"on_damage"] = [_summon_inside_resolve]
	engine.run_action(_damage_a_hero.bind(engine))
	_row(lines, {"scenario": "nested_raise_keeps_the_raise_time_candidates"})
	_rows(lines, "event", log.events.slice(mark))
	_row(lines, {"dump": _dump(engine)})
	var sandbox: RulesEngine = engine.clone()
	var on_clone: Dictionary = sandbox.submit(MatchRecords.end_turn(String(sandbox.active_side())))
	_row(lines, {"scenario": "clone_end_turn", "result": on_clone})
	_rows(lines, "clone_event", sandbox.state().log.events_since(0))
	sandbox.end_match()
	engine.end_match()


func _heal_a_hero(engine: RulesEngine) -> void:
	@warning_ignore("return_value_discarded")
	engine.apply_heal(int(engine.state().players[SIDE_PLAYER].hero.entity_id), 1, null)


func _damage_a_hero(engine: RulesEngine) -> void:
	@warning_ignore("return_value_discarded")
	engine.apply_damage(int(engine.state().players[SIDE_BOSS].hero.entity_id), 1, null)


## A `resolve` script (it runs before the double walks `ctx.candidates`): one
## summon, whose own `on_summon` raise happens while this resolve is running.
func _summon_inside_resolve(engine: RulesEngine, _ctx: Dictionary) -> void:
	var counters: Dictionary = engine.state().effects.counters
	if counters.has(NESTED_KEY):
		return
	counters[NESTED_KEY] = 1
	@warning_ignore("return_value_discarded")
	engine.summon_minion(SIDE_PLAYER, MatchBudgetFixtures.GRUNT, 0)


func _no_step() -> void:
	pass


## An aura-script entry: calls [param primitive] once, on the first recompute,
## on the aura board ([method MatchBudgetFixtures.make_aura_board]).
func primitive_once(engine: RulesEngine, primitive: StringName) -> void:
	var counters: Dictionary = engine.state().effects.counters
	if counters.has(ONCE_KEY):
		return
	counters[ONCE_KEY] = 1
	var state: MatchState = engine.state()
	var player: Dictionary = state.players[SIDE_PLAYER]
	var minion: int = int(player.board[0].entity_id)
	var enemy: int = int(state.players[SIDE_BOSS].board[0].entity_id)
	var card: int = int(player.hand[0].instance_id)
	var weapon: int = int(player.weapon.entity_id)
	match primitive:
		&"draw":
			engine.draw(SIDE_PLAYER, 1)
		&"apply_damage":
			@warning_ignore("return_value_discarded")
			engine.apply_damage(minion, 1, null)
		&"apply_heal":
			@warning_ignore("return_value_discarded")
			engine.apply_heal(minion, 1, null)
		&"apply_armor":
			engine.apply_armor(SIDE_PLAYER, 1)
		&"apply_enchantment":
			engine.apply_enchantment(card, {"cost_delta": MatchBudgetFixtures.AURA_COST})
		&"remove_enchantment":
			engine.remove_enchantment(minion, 0)
		&"summon_minion":
			@warning_ignore("return_value_discarded")
			engine.summon_minion(SIDE_PLAYER, MatchBudgetFixtures.GRUNT, 0)
		&"destroy":
			engine.destroy(enemy)
		&"silence":
			engine.silence(minion)
		&"freeze":
			engine.freeze(enemy)
		&"add_keyword":
			engine.add_keyword(enemy, "windfury")
		&"return_to_hand":
			@warning_ignore("return_value_discarded")
			engine.return_to_hand(minion)
		&"transform":
			@warning_ignore("return_value_discarded")
			engine.transform(minion, MatchBudgetFixtures.WALL)
		&"add_mana":
			engine.add_mana(SIDE_PLAYER, 1, true)
		&"equip_weapon":
			@warning_ignore("return_value_discarded")
			engine.equip_weapon(SIDE_PLAYER, MatchBudgetFixtures.AXE)
		&"discover":
			@warning_ignore("return_value_discarded")
			engine.discover(SIDE_PLAYER, MatchBudgetFixtures.DISCOVER_OPTIONS.duplicate())
		&"add_card_to_hand":
			@warning_ignore("return_value_discarded")
			engine.add_card_to_hand(SIDE_PLAYER, MatchBudgetFixtures.GRUNT)
		&"set_stats":
			engine.set_stats(minion, MatchBudgetFixtures.WALL_ATTACK, MatchBudgetFixtures.GRUNT_HEALTH)
		&"remove_keyword":
			engine.remove_keyword(enemy, "taunt")
		&"add_card_to_deck":
			@warning_ignore("return_value_discarded")
			engine.add_card_to_deck(SIDE_PLAYER, MatchBudgetFixtures.GRUNT, MatchRecords.POSITION_TOP)
		&"modify_durability":
			engine.modify_durability(weapon, -1)
		&"refresh_hero_power":
			engine.refresh_hero_power(SIDE_PLAYER)
		&"discard":
			@warning_ignore("return_value_discarded")
			engine.discard(SIDE_PLAYER, 0)
		_:
			assert(false, "golden aura pass: no script for primitive %s" % primitive)


## The AC-38 policy of `match_rules_clone_replay_test.gd`: a mulligan that
## replaces the first card, a rotating Discover pick, else the first available
## type of [constant POLICY_ORDER], an attack on a minion when one is legal.
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
			var at_minions: Array = of_type.filter(func(c: Dictionary) -> bool: return not MatchBudgetFixtures.BOLT_TARGETS.has(int(c.target_id)))
			if not at_minions.is_empty():
				of_type = at_minions
		if not of_type.is_empty():
			return of_type[(step * POLICY_STRIDE) % of_type.size()]
	return MatchRecords.end_turn(String(engine.active_side()))


# --- text --------------------------------------------------------------------------

func _fixture_named(name: String) -> Dictionary:
	for path: String in MatchBudgetFixtures.fixture_paths():
		var fixture: Dictionary = MatchBudgetFixtures.read_fixture(path)
		if str(fixture.name) == name:
			return fixture
	assert(false, "golden: no fixture state named %s" % name)
	return {}


static func _row(lines: PackedStringArray, value: Dictionary) -> void:
	lines.append(EventLogAssertions.canonical_json(value))


static func _rows(lines: PackedStringArray, key: String, values: Array) -> void:
	for value: Variant in values:
		_row(lines, {key: value})


## What the match is now, as plain data: the scalars, each side's zones by id
## and its other fields, the stream's position, and `state_snapshot()` of every
## id the match has handed out (a departed one reads `{}`).
func _dump(engine: RulesEngine) -> Dictionary:
	var state: MatchState = engine.state()
	var players: Dictionary = {}
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = state.players[side]
		var row: Dictionary = {}
		for key: String in player:
			row[key] = player[key]
		row.hero = int(player.hero.entity_id) if player.hero != null else null
		row.weapon = int(player.weapon.entity_id) if player.weapon != null else null
		var board: Array[int] = []
		for minion: Dictionary in player.board:
			board.append(int(minion.entity_id))
		row.board = board
		for zone: String in CARD_ZONES:
			var ids: Array[int] = []
			for card: Dictionary in player[zone]:
				ids.append(int(card.instance_id))
			row[zone] = ids
		players[side] = row
	var entities: Array = []
	for id: int in range(MatchState.FIRST_ENTITY_ID, state.next_entity_id):
		entities.append([id, engine.state_snapshot(id)])
	var stream: RefCounted = state.rng_match
	return {
		"turn": state.turn, "active_side": state.active_side, "phase": state.phase,
		"next_entity_id": state.next_entity_id, "pending_choice": engine.pending_choice(),
		"result": engine.result(), "effects": state.effects,
		"suspended_queue": state.suspended_queue, "suspended_steps": state.suspended_steps,
		"suspended_action": state.suspended_action, "players": players,
		"draws": stream.get(&"draws") if stream != null else null, "entities": entities,
	}


## [param now] with `entities` cut to the rows that differ from [param base]
## (rows past its end are new, so they differ).
static func _delta(base: Dictionary, now: Dictionary) -> Dictionary:
	var before: Array = base.entities
	var moved: Array = []
	var rows: Array = now.entities
	for i: int in rows.size():
		if i >= before.size() or EventLogAssertions.canonical_json(before[i]) != EventLogAssertions.canonical_json(rows[i]):
			moved.append(rows[i])
	var out: Dictionary = now.duplicate()
	out.entities = moved
	return out
