## Worst-case and fixture-state matches for the Match Rules budgets
## (match-rules story 018; design/gdd/match-rules.md Game Feel — Input
## Responsiveness, AC-40; ADR-0007 Performance; ADR-0005 Decision 4 fold
## guardrail). Shared by the blocking
## `tests/unit/match_rules/match_rules_hook_fold_budget_test.gd` (the
## deterministic half: step counts, list identity, entry counts) and the
## non-blocking `tests/performance/match_rules/match_rules_perf_test.gd`
## (wall-clock), so both measure the same fixture.
##
## - [method make_chain_engine]: player Main, 7 boss "chain" minions (each
##   [constant CHAIN_GENERATIONS] deep, [method TestEffectResolver.add_deathrattle_chain])
##   against 7 player walls, and a 0-cost "nova" in hand that deals 1 to every
##   enemy minion — playing it ([method chain_command]) resolves
##   `7 × (CHAIN_GENERATIONS + 1)` = 56 Deathrattle passes, under
##   `resolution_step_cap` (C10), with no fault.
## - [method make_full_board_engine]: 7 v 7, a 10-card hand holding two
##   `required`-target spells, the hero power affordable and unused, one
##   Windfury attacker (AC-40 Input Responsiveness).
## - [method make_hooked_engine] / [method make_fold_registry]: twelve
##   `modify_damage` value entries — three treasures and the boss passive,
##   three effects each (treasures F5: `(MAX_TREASURES_HELD + 1) ×
##   MAX_EFFECTS_PER_TREASURE`, [constant HookRegistry.DEBUG_MAX_ENTRIES]).
## - [method engine_for]: a `tests/fixtures/match_states/*.json` state
##   (match-rules story 017, fixture option (a)) replayed from `start` over
##   that suite's fixture pool and scripts — copied here, not shared, because
##   the story-017 suite keeps them private; keep the two in step (the
##   fixture `expect` block, checked by [method expectation_mismatch], fails
##   loudly if they drift).
##
## Boards are fixture moves (`MatchFactory.summon`), as in the attack suites.
## An instance holds the resolver scripts as bound methods taking the engine
## first, so a clone's resolver runs them against the clone.
## [codeblock]
## var fx := MatchBudgetFixtures.new()
## var engine: RulesEngine = fx.make_chain_engine(fx.make_resolver())
## var sandbox: RulesEngine = engine.clone()
## sandbox.submit(fx.chain_command(sandbox))
## [/codeblock]
class_name MatchBudgetFixtures
extends RefCounted

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const FIXTURE_DIR: String = "res://tests/fixtures/match_states/"
## The seed every fixture match starts from (story 017's `REPLAY_SEED`).
const REPLAY_SEED: int = 42

## Story 017 fixture pool: `[id, type, cost, attack, health_or_durability, keywords]`.
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
const BOLT_DAMAGE: int = 2
const BOLT_TARGETS: Array[int] = [MatchFactory.PLAYER_HERO_ENTITY_ID, MatchFactory.BOSS_HERO_ENTITY_ID]

## Budget fixture cards (story 018): the chain host and its token, the walls
## that soak the chain, the nova, two `required`-target spells, a vanilla
## minion, an untargeted spell and a weapon for the full hand.
const CHAIN: String = "pb_chain"
const WALL: String = "pb_wall"
const NOVA: String = "pb_nova"
const BOLT_A: String = "pb_bolt"
const BOLT_B: String = "pb_lance"
const GRUNT: String = "pb_grunt"
const BLANK: String = "pb_blank"
const AXE: String = "pb_axe"
const BUDGET_SPECS: Array = [
	[CHAIN, "minion", 1, 1, 1, ["deathrattle"]],
	[WALL, "minion", 1, WALL_ATTACK, WALL_HEALTH, []],
	[GRUNT, "minion", 1, GRUNT_ATTACK, GRUNT_HEALTH, []],
	[NOVA, "spell", 0, 0, 0, []],
	[BOLT_A, "spell", 1, 0, 0, []],
	[BOLT_B, "spell", 2, 0, 0, []],
	[BLANK, "spell", 1, 0, 0, []],
	[AXE, "weapon", 2, 3, 2, []],
]
## AC-40: "a 7-minion Deathrattle chain … a ≥ 50-step chain under the cap".
## Each host resolves `CHAIN_GENERATIONS + 1` passes: 7 × 8 = 56.
const CHAIN_HOSTS: int = 7
const CHAIN_GENERATIONS: int = 7
## The chain's damage to every minion per pass, and the nova's to every enemy minion.
const CHAIN_DAMAGE: int = 1
const NOVA_DAMAGE: int = 1
## Wall stats: health above the chain's total damage (56 passes × 1), so the
## walls soak the whole chain and the boards stabilise. Grunt stats: an
## attacker that survives one swing (the full board attacks nothing here).
const WALL_ATTACK: int = 2
const WALL_HEALTH: int = 100
const GRUNT_ATTACK: int = 2
const GRUNT_HEALTH: int = 3
## The minimum Deathrattle passes the AC names.
const CHAIN_MIN_STEPS: int = 50
## Full-board fixture: the 10-card hand (hand_size), in hand order.
const FULL_HAND: Array[String] = [BOLT_A, BOLT_B, GRUNT, GRUNT, GRUNT, GRUNT, BLANK, BLANK, AXE, NOVA]
## Mana for the budget fixtures (`max_mana`): every card and the power affordable.
const FIXTURE_MANA: int = TestConstants.MAX_MANA_CRYSTALS
## Deck cards for the budget fixtures (no card outside the pool is ever drawn).
const FIXTURE_DECK_SIZE: int = 15
## Fold fixture: hosts × effects per host = HookRegistry.DEBUG_MAX_ENTRIES.
const FOLD_HOSTS: int = 4
const FOLD_EFFECTS_PER_HOST: int = 3
const FOLD_DELTA: int = 1


## The card lookup the engine reads definitions from (`has` / `card`).
class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


## Every story 017 pool card and every budget card.
func make_db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	for spec: Array in POOL_SPECS + BUDGET_SPECS:
		var id: String = str(spec[0])
		match str(spec[1]):
			"minion":
				db.cards[id] = CardFactory.make_minion(id, int(spec[2]), int(spec[3]), int(spec[4]), spec[5])
			"weapon":
				db.cards[id] = CardFactory.make_weapon(id, int(spec[2]), int(spec[3]), int(spec[4]))
			"spell":
				db.cards[id] = CardFactory.make_spell(id, int(spec[2]), [], {"keywords": spec[5]})
	return db


## The scripted resolver of every fixture here: story 017's `on_cast` /
## `battlecry` / `resume` scripts plus the nova; the two budget bolts are
## `required`-target spells (their targets are set by
## [method make_full_board_engine]). [param recording] off keeps the double's
## bookkeeping out of a timed call.
func make_resolver(recording: bool = true) -> TestEffectResolver:
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.recording = recording
	resolver.scripts[&"on_cast"] = [_on_cast]
	resolver.scripts[&"battlecry"] = [_on_battlecry]
	resolver.resume_script = _resume
	resolver.specs_by_def["fx_bolt"] = {"mode": RulesEngine.TARGETING_REQUIRED, "filter": {}}
	resolver.targets_by_def["fx_bolt"] = BOLT_TARGETS
	for bolt: String in [BOLT_A, BOLT_B]:
		resolver.specs_by_def[bolt] = {"mode": RulesEngine.TARGETING_REQUIRED, "filter": {}}
	return resolver


# --- budget fixtures -------------------------------------------------------------

## A started match past a keep-all mulligan (turn 1, player Main) over
## [method make_db], both decks [param deck_card], [param installers] on the
## player (treasures) and [param boss_installers] on the boss.
func start_main(resolver: TestEffectResolver, log: TestEventLog = null, installers: Array = [], boss_installers: Array = []) -> RulesEngine:
	var deck: Array = []
	for _i: int in FIXTURE_DECK_SIZE:
		deck.append(GRUNT)
	var overrides: Dictionary = {
		"player": {"deck": deck.duplicate(), "hook_installers": installers},
		"boss": {"deck": deck.duplicate(), "hook_installers": boss_installers},
	}
	var engine: RulesEngine = MatchFactory.make_started_engine(TestRngService.new(REPLAY_SEED), log, overrides, {}, resolver, make_db())
	@warning_ignore("return_value_discarded")
	engine.submit(engine.legal_commands()[0])
	return engine


## AC-40 worst case: see the class description. The returned engine is in
## player Main; [method chain_command] is the command to time.
func make_chain_engine(resolver: TestEffectResolver, log: TestEventLog = null) -> RulesEngine:
	var engine: RulesEngine = start_main(resolver, log)
	var state: MatchState = engine.state()
	for _i: int in CHAIN_HOSTS:
		var host: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 1, 1, -1, ["deathrattle"], CHAIN)
		resolver.add_deathrattle_chain(int(host.entity_id), CHAIN, CHAIN_GENERATIONS, CHAIN_DAMAGE)
	for _i: int in TestConstants.BOARD_SIZE:
		var wall: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, WALL_ATTACK, WALL_HEALTH, -1, [], WALL)
		wall.summoning_sick = false
	_set_hand(state, SIDE_PLAYER, [NOVA])
	_fill_mana(state, SIDE_PLAYER)
	return engine


## The play of the nova (hand index 0) on [param engine] — a clone's own
## hand, so the command is valid on every fresh clone.
func chain_command(engine: RulesEngine) -> Dictionary:
	assert(str(engine.state().players[SIDE_PLAYER].hand[0].def_id) == NOVA, "chain fixture: the nova is not at hand index 0")
	return MatchRecords.play_card(SIDE_PLAYER, 0)


## The full board's hero power: a side with none is never offered the command,
## so the list [method make_full_board_engine] gives would lose its width.
const FULL_BOARD_POWER: String = "war_test_power"


## AC-40 Input Responsiveness: 7 v 7 (every player minion ready, the
## leftmost Windfury), the 10-card [constant FULL_HAND], the hero power
## affordable and unused, both bolts able to target every character.
func make_full_board_engine(resolver: TestEffectResolver) -> RulesEngine:
	var engine: RulesEngine = start_main(resolver)
	var state: MatchState = engine.state()
	for i: int in TestConstants.BOARD_SIZE:
		var keywords: Array = ["windfury"] if i == 0 else []
		var mine: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, GRUNT_ATTACK, GRUNT_HEALTH, -1, keywords, GRUNT)
		mine.summoning_sick = false
		@warning_ignore("return_value_discarded")
		MatchFactory.summon(state, SIDE_BOSS, GRUNT_ATTACK, GRUNT_HEALTH, -1, [], GRUNT)
	_set_hand(state, SIDE_PLAYER, FULL_HAND)
	_fill_mana(state, SIDE_PLAYER)
	state.players[SIDE_PLAYER].hero_power.def_id = FULL_BOARD_POWER
	var targets: Array[int] = []
	for side: String in MatchRecords.SIDES:
		for minion: Dictionary in state.players[side].board:
			targets.append(int(minion.entity_id))
	targets.append_array(BOLT_TARGETS)
	for bolt: String in [BOLT_A, BOLT_B]:
		resolver.targets_by_def[bolt] = targets
	return engine


## [constant FOLD_HOSTS] installers with [constant FOLD_EFFECTS_PER_HOST]
## `modify_damage` `delta +FOLD_DELTA` effects each: the first
## `FOLD_HOSTS − 1` player treasures, the last the boss passive. Scope `any`
## so every entry applies to either side's fold.
func make_fold_installers(hosts: int = FOLD_HOSTS) -> Array[HookInstaller]:
	var out: Array[HookInstaller] = []
	for h: int in hosts:
		var host_id: String = "budget_host_%d" % h
		var effects: Array[Dictionary] = []
		for e: int in FOLD_EFFECTS_PER_HOST:
			effects.append({
				"id": "%s.%d" % [host_id, e], "trigger": "modify_damage",
				"scope": {"side": TestEffectResolver.SCOPE_ANY}, "condition": {},
				"ops": [{"op": TestEffectResolver.OP_MODIFY_VALUE, "delta": FOLD_DELTA}], "once_per_turn": false,
			})
		var is_boss: bool = h == FOLD_HOSTS - 1
		var kind: StringName = HookInstaller.HOST_KIND_PASSIVE if is_boss else HookInstaller.HOST_KIND_TREASURE
		out.append(HookInstaller.new(kind, host_id, StringName(SIDE_BOSS if is_boss else SIDE_PLAYER), effects))
	return out


## A started match (player Main) with the twelve fold entries installed
## through `start` (treasures on the player, the passive on the boss).
func make_hooked_engine(resolver: TestEffectResolver) -> RulesEngine:
	var all: Array[HookInstaller] = make_fold_installers()
	var player: Array = all.slice(0, FOLD_HOSTS - 1)
	var boss: Array = all.slice(FOLD_HOSTS - 1)
	return start_main(resolver, null, player, boss)


## A bare registry holding the twelve fold entries, the double's evaluators set.
func make_fold_registry(resolver: TestEffectResolver) -> HookRegistry:
	var hooks: HookRegistry = HookRegistry.new()
	for installer: HookInstaller in make_fold_installers():
		@warning_ignore("return_value_discarded")
		hooks.install(installer)
	hooks.set_evaluators(resolver.apply_value_hook, resolver.run_hook_effect)
	return hooks


## The number of Deathrattle passes [param log] recorded (`trigger_resolved`
## with point `deathrattle`) — the AC's "steps" (one queued pass is one C10 step).
static func deathrattle_passes(events: Array) -> int:
	var count: int = 0
	for event: Dictionary in events:
		if StringName(event.type) == &"trigger_resolved" and str(event.payload.point) == "deathrattle":
			count += 1
	return count


static func _set_hand(state: MatchState, side: String, def_ids: Array) -> void:
	var hand: Array = state.players[side].hand
	hand.clear()
	for def_id: Variant in def_ids:
		hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))


static func _fill_mana(state: MatchState, side: String) -> void:
	state.players[side].mana_max = FIXTURE_MANA
	state.players[side].mana_current = FIXTURE_MANA


# --- story 017 fixture states ----------------------------------------------------

## Every `tests/fixtures/match_states/*.json` path, sorted.
static func fixture_paths() -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(FIXTURE_DIR):
		if file.ends_with(".json"):
			out.append(FIXTURE_DIR + file)
	out.sort()
	return out


## The parsed fixture at [param path] (`{}` when it is not a JSON object).
static func read_fixture(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Why the last [method engine_for] returned null ("" after a success).
var last_error: String = ""


## The fixture's engine after its commands, or null when a command could not
## be found or was rejected ([member last_error] says which).
func engine_for(fixture: Dictionary, recording: bool = true) -> RulesEngine:
	last_error = ""
	var decks: Dictionary = fixture.decks
	var boss: Dictionary = {"deck": _deck(decks.boss), "hook_installers": []}
	if fixture.get("boss_health") != null:
		boss["health"] = int(fixture.boss_health)
	var overrides: Dictionary = {"player": {"deck": _deck(decks.player), "hook_installers": []}, "boss": boss}
	var engine: RulesEngine = MatchFactory.make_started_engine(TestRngService.new(REPLAY_SEED), TestEventLog.new(), overrides, fixture.get("rules_overrides", {}), make_resolver(recording), make_db())
	return engine if _run_script(engine, fixture.commands, str(fixture.name)) else null


## "" when [param engine] is in the state the fixture's `expect` names, else
## the first mismatch.
static func expectation_mismatch(engine: RulesEngine, fixture: Dictionary) -> String:
	var expect: Dictionary = fixture.expect
	var state: MatchState = engine.state()
	if engine.phase() != str(expect.phase):
		return "phase %s, expected %s" % [engine.phase(), expect.phase]
	if String(engine.active_side()) != str(expect.active_side):
		return "active side %s, expected %s" % [engine.active_side(), expect.active_side]
	if state.turn != int(expect.turn):
		return "turn %d, expected %d" % [state.turn, int(expect.turn)]
	for side: String in expect.get("boards", {}):
		if state.players[side].board.size() != int(expect.boards[side]):
			return "%s board %d, expected %d" % [side, state.players[side].board.size(), int(expect.boards[side])]
	return ""


static func _deck(spec: Array) -> Array:
	var out: Array = []
	for row: Array in spec:
		for _i: int in int(row[1]):
			out.append(str(row[0]))
	return out


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
			last_error = "%s: no legal %s for %s" % [name, str(raw.pick), str(raw)]
			return false
		var result: Dictionary = engine.submit(command)
		if not result.accepted:
			last_error = "%s: %s rejected %s" % [name, str(command), str(result.rejection)]
			return false
	return true


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


# --- resolver scripts (story 017's, plus the nova) ---------------------------------

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
		NOVA:
			var ids: Array[int] = []
			for minion: Dictionary in engine.state().players[_enemy(side)].board:
				ids.append(int(minion.entity_id))
			for id: int in ids:
				@warning_ignore("return_value_discarded")
				engine.apply_damage(id, NOVA_DAMAGE, ctx.source)


func _on_battlecry(engine: RulesEngine, ctx: Dictionary) -> void:
	_count(engine, "battlecries")
	if str(ctx.card_id) == "fx_seer":
		_discover(engine, ctx)


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
