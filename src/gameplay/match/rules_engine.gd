## The match rules engine (design/gdd/match-rules.md C1 Data model, F9 Limits,
## Tuning Knobs; ADR-0001 Decision 1, ADR-0007 Decision 1–2, ADR-0002).
##
## A `RefCounted` that owns one [MatchState] and takes every collaborator in
## `_init` — the frozen Card Database, the frozen `match_rules` config body and
## the Card Effects resolver. It references no Node, autoload or scene and runs
## headless (DD-T02).
##
## Every F9 constant and Tuning Knob is read from the injected `rules_config`
## (the `config` body of `assets/data/match_rules.json`, served by
## `CardDatabase.config("match_rules")`), never from a literal: see
## [constant CONFIG_KEYS] and [method rule]. Keys are the GDD knob names in
## snake_case (`MAX_ATTACKS_CAP` → `"max_attacks_cap"`, DD-T01).
##
## Derived values (C1) are functions here, never fields: [method max_health],
## [method health], [method attack], [method has_windfury],
## [method max_attacks], [method attacks_remaining].
##
## Story 001 built the constructor, the derived values and
## [method state_snapshot]; story 003 adds [method start] (C3 setup from a
## `MatchConfig`), the resolver surface [method emit] / [method rng_match] /
## [method state], and the [method draw] primitive; story 004 the command
## channel [method submit] / [method legal_commands] with the closed
## [constant REJECTION_CODES], the [constant PHASE_COMMANDS] guard and the
## `mulligan` handler; story 005 C3 step 8, the C4 Start / End steps, the
## `end_turn` handler, [method add_mana] (permanent) and the `TURN_CAP` end.
## [method load_state] remains the seam for `clone()` and fixture states.
## [codeblock]
## var engine: RulesEngine = RulesEngine.new(db, db.config("match_rules"), resolver)
## engine.start(config)
## var hp: int = engine.health(engine.state().players["player"].hero)
## [/codeblock]
class_name RulesEngine
extends RefCounted

## The knobs `rules_config` must carry (match-rules F9 Limits and Tuning
## Knobs), in GDD order. Values are never defaulted in code.
const CONFIG_KEYS: Array[String] = [
	"board_size", "hand_size", "starting_hand_player", "starting_hand_boss",
	"max_mana", "hero_power_cost", "mulligan_rounds", "turn_cap",
	"resolution_step_cap", "max_attacks_cap", "max_attacks_windfury",
	"starting_health_player", "fatigue_base", "fatigue_step",
]
## Attacks per turn for a character without Windfury (DD-M08 / DD-M10: a
## character attacks once per turn). A rule, not a tuning knob — the GDD's
## Tuning Knobs table has no row for it.
const ATTACKS_PER_TURN: int = 1
## The match-rules Tuning Knobs "Safe range" column, `[min, max]` inclusive per
## [constant CONFIG_KEYS] key — the bounds [method validate_rules_config]
## checks. Validation bounds, not knob values: like
## `DataLoader.SCHEMA_VERSION_CURRENT` they cannot come from the file they
## validate. `tests/integration/match_rules/match_rules_config_file_test.gd`
## pins every row to the GDD table, so a GDD change that is not mirrored here
## fails the suite.
const CONFIG_SAFE_RANGES: Dictionary[String, Array] = {
	"board_size": [5, 7],
	"hand_size": [8, 12],
	"starting_hand_player": [3, 4],
	"starting_hand_boss": [3, 5],
	"max_mana": [7, 10],
	"hero_power_cost": [1, 3],
	"mulligan_rounds": [0, 1],
	"turn_cap": [40, 200],
	"resolution_step_cap": [200, 5000],
	"max_attacks_cap": [2, 4],
	"max_attacks_windfury": [2, 2],
	"starting_health_player": [25, 40],
	"fatigue_base": [1, 3],
	"fatigue_step": [1, 2],
}
## The file [method validate_rules_config] reports against (DD-T01 name).
const CONFIG_FILE: String = "match_rules.json"
## Owner code: a [constant CONFIG_KEYS] key is absent from the body.
const E_RULES_MISSING_KNOB: StringName = &"E_RULES_MISSING_KNOB"
## Owner code: a knob is not a whole number (a fraction, string, bool, null…).
const E_RULES_NOT_INTEGER: StringName = &"E_RULES_NOT_INTEGER"
## Owner code: a knob lies outside its [constant CONFIG_SAFE_RANGES] row.
const E_RULES_OUT_OF_RANGE: StringName = &"E_RULES_OUT_OF_RANGE"

## `hook_install_skipped.reason` for a second installer with an installed
## `host_id` (ADR-0005 rule 5).
const SKIP_REASON_DUPLICATE: String = "duplicate"
## The C2 rejection codes — a closed set, spelled and ordered as C2 lists
## them. Adding one is a match-rules GDD change.
const REJECTION_CODES: Array[String] = [
	"MATCH_ENDED", "NOT_YOUR_TURN", "WRONG_PHASE", "CHOICE_PENDING", "ENGINE_BUSY",
	"INVALID_INDEX", "INVALID_POSITION", "INVALID_MASK", "INVALID_CHOICE", "NOT_ENOUGH_MANA",
	"BOARD_FULL", "TARGET_REQUIRED", "NO_LEGAL_TARGET", "ILLEGAL_TARGET", "TARGET_STEALTHED",
	"MUST_ATTACK_TAUNT", "CANNOT_ATTACK", "ATTACKER_FROZEN", "SUMMONING_SICK",
	"RUSH_CANNOT_HIT_HERO", "HERO_POWER_USED",
]
const R_MATCH_ENDED: String = "MATCH_ENDED"
const R_NOT_YOUR_TURN: String = "NOT_YOUR_TURN"
const R_WRONG_PHASE: String = "WRONG_PHASE"
const R_CHOICE_PENDING: String = "CHOICE_PENDING"
const R_ENGINE_BUSY: String = "ENGINE_BUSY"
const R_INVALID_MASK: String = "INVALID_MASK"
## C14 `MatchResult.reason` for the `TURN_CAP` termination guarantee.
const REASON_TURN_CAP: String = "turn_cap"
## The phase guard (match-rules States and Transitions): per phase, the
## command types it accepts and from whom — `"active"` (the issuer must be
## the active side, else `NOT_YOUR_TURN`), `"player"` (PLAYER only) or
## `"choice"` (the side named in `pending_choice`, else `NOT_YOUR_TURN`).
## Any (phase, command) pair not listed is `WRONG_PHASE`; a listed pair from
## a disallowed issuer of a `"player"` row is `WRONG_PHASE` too (the boss has
## no mulligan row and no concede row). In `choice`, an unlisted command is
## `CHOICE_PENDING`. `setup`, `start` and `end` accept nothing.
const PHASE_COMMANDS: Dictionary[String, Dictionary] = {
	MatchState.PHASE_MULLIGAN: {MatchRecords.CMD_MULLIGAN: "player", MatchRecords.CMD_CONCEDE: "player"},
	MatchState.PHASE_MAIN: {
		MatchRecords.CMD_PLAY_CARD: "active", MatchRecords.CMD_ATTACK: "active",
		MatchRecords.CMD_USE_HERO_POWER: "active", MatchRecords.CMD_END_TURN: "active",
		MatchRecords.CMD_CONCEDE: "player",
	},
	MatchState.PHASE_CHOICE: {MatchRecords.CMD_CHOOSE: "choice", MatchRecords.CMD_CONCEDE: "player"},
}

var _db: Variant
var _rules_config: Dictionary
var _resolver: Variant
var _state: MatchState = null
## The `cause_seq` [method emit] stamps: 0 during setup and for the direct
## consequences of a command (C15); story 009's C10 loop sets it per step.
var _cause_seq: int = 0
## True for the whole of a `submit` call or engine step (the `Resolving`
## state): a nested `submit` answers `ENGINE_BUSY`. A plain instance field —
## never a captured local (lambdas capture by value).
var _resolving: bool = false
## `seq` of the first and last event the current `submit` produced (its
## `CommandResult.events`); diagnostics appended meanwhile are not counted.
var _call_first_seq: int = 0
var _call_last_seq: int = 0
## The engine-owned trigger queue Q (C10; ADR-0007 erratum: `resolve()`
## returns the triggers it queues and the engine appends them here). Drained
## by the C10 loop (story 009).
var _queue: Array[Dictionary] = []


## Stores the collaborators (ADR-0001 constructor shape):
## [param db] the frozen `CardDatabase`, [param rules_config] the frozen
## `match_rules` body (read once here and kept as a reference — owners never
## re-query), [param resolver] the `EffectResolver` (bound in `start`,
## story 003).
## TODO(card-database, card-effects): type [param db] as `CardDatabase` and
## [param resolver] as `EffectResolver` once those classes exist.
func _init(db: Variant, rules_config: Dictionary, resolver: Variant) -> void:
	_db = db
	_rules_config = rules_config
	_resolver = resolver


## The `match_rules` config body this engine was built with (the same
## reference passed to `_init`).
func rules_config() -> Dictionary:
	return _rules_config


## The `match_rules` config validator (card-database CR-5 stage 7a; ADR-0002
## Decision 4: `call(body, db) -> Array`), registered by `Boot` as
## `configs.match_rules`. Static and pure: it reads [param body] only
## ([param _db] is the stage-7a calling convention and is unused here).
## Returns one error per problem, in [constant CONFIG_KEYS] order, each in the
## `ValidationReport` entry shape `{severity, code, file, record_id, field,
## message}` (`severity` error, `file` [constant CONFIG_FILE], `record_id`
## `null`, `field` the knob key); `[]` when the body is valid:
## - a missing key is [constant E_RULES_MISSING_KNOB];
## - a value that is not a whole number (JSON numbers parse as `float`, so
##   `7.0` passes and `7.5`, `"7"`, `true` fail) is [constant E_RULES_NOT_INTEGER];
## - a whole number outside its [constant CONFIG_SAFE_RANGES] row is
##   [constant E_RULES_OUT_OF_RANGE].
## [codeblock]
## var errors: Array = RulesEngine.validate_rules_config({"board_size": 9.0}, null)
## errors[0].code   # &"E_RULES_OUT_OF_RANGE" (board_size), then 13 missing knobs
## [/codeblock]
static func validate_rules_config(body: Dictionary, _db: Variant) -> Array:
	var errors: Array[Dictionary] = []
	for key: String in CONFIG_KEYS:
		if not body.has(key):
			errors.append(_config_error(E_RULES_MISSING_KNOB, key, "missing knob `%s` (match-rules Tuning Knobs)" % key))
			continue
		var raw: Variant = body[key]
		var is_number: bool = typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT
		if not is_number or float(raw) != floorf(float(raw)):
			errors.append(_config_error(E_RULES_NOT_INTEGER, key, "`%s` must be a whole number, found %s (%s)" % [key, str(raw), type_string(typeof(raw))]))
			continue
		var value: int = int(raw)
		var bounds: Array = CONFIG_SAFE_RANGES[key]
		if value < int(bounds[0]) or value > int(bounds[1]):
			errors.append(_config_error(E_RULES_OUT_OF_RANGE, key, "`%s` is %d, outside the safe range %d–%d" % [key, value, int(bounds[0]), int(bounds[1])]))
	return errors


## The integer value of knob [param key] (one of [constant CONFIG_KEYS]) from
## `rules_config`. JSON numbers parse as float; the value is coerced to `int`.
## A missing key is a data error [method validate_rules_config] reports at
## load — this asserts in debug builds and never falls back to a default.
## [codeblock]
## var cap: int = engine.rule("max_attacks_cap")   # 4 with the shipped data
## [/codeblock]
func rule(key: String) -> int:
	assert(_rules_config.has(key), "match_rules config lacks '%s'" % key)
	return int(_rules_config[key])


## Installs [param state] as the match this engine owns. `start(config)`
## (story 003) builds its own state; this is the seam for `clone()` (story 017)
## and for tests that construct a fixture state directly.
func load_state(state: MatchState) -> void:
	_state = state


## The live [MatchState] (ADR-0007 Decision 4: a live reference, called only
## from `src/gameplay/effects/**` and tests; `MatchQuery` and Boss AI use
## [method state_snapshot] / `clone()`).
func state() -> MatchState:
	return _state


## Begins a match from [param config], the `MatchConfig` Dictionary (C3 step 1,
## Run Structure R3: `{floor, band, rng_match, rng_ai, log, player:
## {hero_def_id, deck, hook_installers}, boss: {boss_def_id, deck, health,
## hook_installers, ai_id}}`) — the engine's only input and the only way a
## match begins. Runs C3 steps 1–6 in one fixed order, ending in phase
## `mulligan` with `mulligan_offered` the last event:
## 1. `state.hooks = HookRegistry.new()`, then
##    `resolver.bind(self, player.hook_installers + boss.hook_installers)`;
##    one `hook_install_skipped {host_id, reason: duplicate}` per installer
##    whose `host_id` an earlier one already installed (ADR-0005, ADR-0007).
## 2. Heroes: player `base_health` = `starting_health_player`, boss
##    `base_health = config.boss.health` (never the boss definition's).
## 3. Each deck to `CardInstance`s in list order, shuffled with `rng_match` —
##    player first; one `deck_shuffled {side, instance_ids}` per side.
## 4. `on_match_start` hooks, player side then boss side.
## 5. Starting hands, player then boss: `clampi(fold(modify_starting_hand_size,
##    starting_hand_*), 0, hand_size)` cards each.
## 6. `phase = mulligan`; `mulligan_offered {side: player, instance_ids}`.
## `rng_match` is stored as given and `rng_ai` is never touched: the engine
## never creates, seeds or forks a stream (DD-T03). Every event of setup has
## `cause_seq = 0`.
## [codeblock]
## var engine := RulesEngine.new(db, db.config("match_rules"), resolver)
## engine.start(config)
## engine.state().phase   # "mulligan"
## [/codeblock]
func start(config: Dictionary) -> void:
	assert(_state == null, "RulesEngine.start: a match was already started on this engine")
	_state = MatchState.from_config(config)
	_cause_seq = 0
	_resolving = true
	# C3 step 1: the registry, then bind (installs entries, registers evaluators)
	_state.hooks = HookRegistry.new()
	var installers: Array = []
	installers.append_array(config.player.hook_installers)
	installers.append_array(config.boss.hook_installers)
	_resolver.bind(self, installers)
	_log_skipped_installers(installers)
	# C3 step 2: heroes
	# TODO(card-database story 006): read the hero record's `health` (defaulting
	# to this knob) and its hero power id once `CardDatabase` answers queries.
	_state.players[MatchRecords.SIDE_PLAYER].hero = MatchRecords.hero(_take_entity_id(), MatchRecords.SIDE_PLAYER, rule("starting_health_player"))
	_state.players[MatchRecords.SIDE_BOSS].hero = MatchRecords.hero(_take_entity_id(), MatchRecords.SIDE_BOSS, int(config.boss.health))
	# C3 step 3: decks, player first
	_build_deck(MatchRecords.SIDE_PLAYER, config.player.deck)
	_build_deck(MatchRecords.SIDE_BOSS, config.boss.deck)
	# C3 step 4: on_match_start, before any card is drawn
	for side: String in MatchRecords.SIDES:
		_state.hooks.run_triggers(&"on_match_start", StringName(side), {})
	# C3 step 5: starting hands, fold then clamp once
	draw(MatchRecords.SIDE_PLAYER, _starting_hand_size(MatchRecords.SIDE_PLAYER, rule("starting_hand_player")))
	draw(MatchRecords.SIDE_BOSS, _starting_hand_size(MatchRecords.SIDE_BOSS, rule("starting_hand_boss")))
	# C3 step 6
	_state.phase = MatchState.PHASE_MULLIGAN
	emit(&"mulligan_offered", {"side": MatchRecords.SIDE_PLAYER, "instance_ids": _instance_ids(_state.players[MatchRecords.SIDE_PLAYER].hand)})
	_resolving = false


## The single command channel (C2; ADR-0001): validates [param command]
## (`{type, issuer, ...args}`, see [method MatchRecords.command]) in full and
## either rejects it — no mutation, exactly one `command_rejected {side,
## command, code, detail, diagnostic: true}` on the match log (rng-event-log
## rule 12a) — or runs it to completion inside this call. Returns the C2
## `CommandResult` `{accepted, rejection: {code, detail} | null, events:
## [seq_first, seq_last]}` ([method MatchRecords.command_result]); a
## rejection's range is its own `command_rejected` event.
## Check order: `ENGINE_BUSY` (a nested call while resolving) →
## `MATCH_ENDED` → the phase guard [constant PHASE_COMMANDS] (`WRONG_PHASE`,
## `NOT_YOUR_TURN`, `CHOICE_PENDING`) → the command's own C2 row, first
## failing reason wins. Synchronous: no `await`.
## [codeblock]
## var r: Dictionary = engine.submit(MatchRecords.mulligan([true, false, false]))
## if not r.accepted: show(r.rejection.code)
## [/codeblock]
func submit(command: Dictionary) -> Dictionary:
	if _resolving:
		return _reject(command, R_ENGINE_BUSY, "nested submit while resolving")
	if _state.phase == MatchState.PHASE_ENDED:
		return _reject(command, R_MATCH_ENDED, "")
	var guard: String = _phase_guard(command)
	if guard != "":
		return _reject(command, guard, "phase %s, active %s" % [_state.phase, _state.active_side])
	var type: String = str(command.get("type", ""))
	var invalid: String = _validate(type, command)
	if invalid != "":
		return _reject(command, invalid, "")
	_resolving = true
	_cause_seq = 0
	_call_first_seq = 0
	_call_last_seq = 0
	match type:
		MatchRecords.CMD_MULLIGAN:
			_do_mulligan(command.keep_mask)
		MatchRecords.CMD_END_TURN:
			_end_step(_state.active_side)
	# TODO(story 009): the C10 loop; TODO(story 008): win_loss_check.
	_resolving = false
	return MatchRecords.command_result(true, "", "", _call_first_seq, _call_last_seq)


## Every command the engine would accept now (C2): in Mulligan the "keep
## all" mulligan; in Main the active side's `end_turn`; `[]` in any other
## phase. The handler stories (008 `concede`, 010–016) extend it. Allocates
## only the result array.
## [codeblock]
## for cmd: Dictionary in engine.legal_commands(): print(cmd.type)
## [/codeblock]
func legal_commands() -> Array:
	var legal: Array = []
	match _state.phase:
		MatchState.PHASE_MULLIGAN:
			var keep_all: Array[bool] = []
			for _card: Dictionary in _state.players[MatchRecords.SIDE_PLAYER].hand:
				keep_all.append(true)
			legal.append(MatchRecords.mulligan(keep_all))
		MatchState.PHASE_MAIN:
			legal.append(MatchRecords.end_turn(_state.active_side))
	return legal


## The current phase, one of [constant MatchState.PHASES]. `resolving` is
## never returned: between calls the engine is always in its originating
## phase (States "Resolving").
func phase() -> String:
	return _state.phase


## The side whose turn it is (`&"player"` / `&"boss"`).
func active_side() -> StringName:
	return StringName(_state.active_side)


## A value copy of the pending `ChoiceRequest`, or null (C1, C2).
func pending_choice() -> Variant:
	var choice: Variant = _state.pending_choice
	return choice.duplicate(true) if choice is Dictionary else choice


## A value copy of the `MatchResult` once `Ended`, else null (C14).
func result() -> Variant:
	var outcome: Variant = _state.result
	return outcome.duplicate(true) if outcome is Dictionary else outcome


## Appends one event to the match log with the engine's current `cause_seq`
## and returns its `seq` (ADR-0007 Decision 6). Every engine mutation emits
## through here, and so does the resolver (`effect_resolved`,
## `counter_changed`, …), so `log.append` call sites stay inside the engine.
## [codeblock]
## var seq: int = engine.emit(&"counter_changed", {"source_id": 7, "key": "seen", "value": 2})
## [/codeblock]
func emit(type: StringName, payload: Dictionary) -> int:
	# TODO(rng-event-log story 005): type the log as `EventLog`.
	var log: Variant = _state.log
	var seq: int = log.append(type, payload, _cause_seq)
	if seq > 0:
		if _call_first_seq == 0:
			_call_first_seq = seq
		_call_last_seq = seq
	return seq


## The injected `match_<floor>` stream from `MatchConfig.rng_match` (ADR-0007
## Decision 7; C3 step 1) — the one stream rules and the resolver draw from.
## Typed `RefCounted` so the production `RngStream` and the test double fit.
## [codeblock]
## var i: int = engine.rng_match().randi_range(0, pool.size() - 1)
## [/codeblock]
func rng_match() -> RefCounted:
	return _state.rng_match


## Primitive (C11, match-rules Interactions): [param side] draws [param n]
## cards. Each draw pops the top of the deck (index 0); into the right end of
## the hand with `card_drawn {side, instance_id, card_id, hand_size}`, or —
## when the hand already holds `hand_size` — into the graveyard with
## `card_burned {side, instance_id, card_id}` (DD-M06).
## TODO(story 006): the fatigue branch (empty deck: this draw does nothing
## yet) and the `on_draw` hook / trigger after a successful draw.
## [codeblock]
## engine.draw("player", 2)
## [/codeblock]
func draw(side: String, n: int) -> void:
	var player: Dictionary = _state.players[side]
	for _i: int in n:
		if player.deck.is_empty():
			continue
		var card: Dictionary = player.deck.pop_front()
		if player.hand.size() >= rule("hand_size"):
			card.zone = "graveyard"
			player.graveyard.append(card)
			emit(&"card_burned", {"side": side, "instance_id": card.instance_id, "card_id": card.def_id})
			continue
		card.zone = "hand"
		player.hand.append(card)
		emit(&"card_drawn", {"side": side, "instance_id": card.instance_id, "card_id": card.def_id, "hand_size": player.hand.size()})


## Primitive (C5, match-rules Interactions): [param side] gains [param n]
## crystals. Permanent (`temporary = false`, an `on_match_start` hook such as
## Hollow Crown): raises `crystal_bonus`, which every later Start step reads
## (F4) — mana itself moves at the next Start step — and emits
## `mana_added {side, n, temporary: false}`.
## TODO(story 011): the temporary branch (this-turn crystals, End-step
## expiry); until then it logs an error and changes nothing.
## [codeblock]
## engine.add_mana("player", 1, false)   # 2/2 on the player's first turn
## [/codeblock]
func add_mana(side: String, n: int, temporary: bool = false) -> void:
	if temporary:
		push_error("RulesEngine.add_mana: temporary crystals are match-rules story 011")
		return
	var player: Dictionary = _state.players[side]
	player.crystal_bonus = int(player.crystal_bonus) + n
	emit(&"mana_added", {"side": side, "n": n, "temporary": false})


## C1: `max_health = base_health + Σ enchantment.health_delta`.
## [codeblock]
## # base_health 2 with one +2 enchantment
## engine.max_health(minion)   # 4
## [/codeblock]
func max_health(character: Dictionary) -> int:
	var total: int = int(character.base_health)
	for enchantment: Dictionary in character.enchantments:
		total += int(enchantment.health_delta)
	return total


## C1 / F6: `health = max_health − damage_taken`; may be ≤ 0 transiently (the
## character dies at the next death check, C10).
func health(character: Dictionary) -> int:
	return max_health(character) - int(character.damage_taken)


## C1: `attack = max(0, base_attack + Σ attack_delta + weapon.attack if hero)`.
## A hero's weapon is its controller's `PlayerState.weapon` in the loaded state.
func attack(character: Dictionary) -> int:
	var total: int = int(character.base_attack)
	for enchantment: Dictionary in character.enchantments:
		total += int(enchantment.attack_delta)
	var weapon: Variant = _weapon_of(character)
	if weapon != null:
		total += int(weapon.attack)
	return maxi(0, total)


## C1: `has_windfury = Windfury ∈ keywords ∨ (hero ∧ weapon ≠ null ∧ Windfury ∈
## weapon.keywords)`. `keywords` covers the definition's set and keywords
## granted by enchantments (`keywords_added`), so a hero gains Windfury from
## its weapon or from an enchantment.
func has_windfury(character: Dictionary) -> bool:
	if _has_keyword(character, MatchRecords.KEYWORD_WINDFURY):
		return true
	var weapon: Variant = _weapon_of(character)
	return weapon != null and weapon.keywords.has(MatchRecords.KEYWORD_WINDFURY)


## C1: `max_attacks = clamp(n, 0, MAX_ATTACKS_CAP)` with
## `n = MAX_ATTACKS_WINDFURY if has_windfury else 1`. The `modify_max_attacks`
## hook fold (ADR-0005) is applied to `n` before the single clamp once the
## engine wires its hook sites (match-rules story 012).
func max_attacks(character: Dictionary) -> int:
	var n: int = rule("max_attacks_windfury") if has_windfury(character) else ATTACKS_PER_TURN
	return clampi(n, 0, rule("max_attacks_cap"))


## C1: `attacks_remaining = max_attacks − attacks_used`.
func attacks_remaining(character: Dictionary) -> int:
	return max_attacks(character) - int(character.attacks_used)


## A value copy (`duplicate(true)`) of the record with [param entity_id] —
## a hero, minion, weapon or card instance in any zone — for `MatchQuery`;
## never a live object. `{}` when no record has that id or no state is loaded.
## [codeblock]
## var snap: Dictionary = engine.state_snapshot(minion_id)
## snap.damage_taken = 99   # the live record is unchanged
## [/codeblock]
func state_snapshot(entity_id: int) -> Dictionary:
	var record: Dictionary = _find_record(entity_id)
	return record.duplicate(true)


static func _config_error(code: StringName, key: String, message: String) -> Dictionary:
	return {
		"severity": ValidationReport.SEVERITY_ERROR,
		"code": code,
		"file": CONFIG_FILE,
		"record_id": null,
		"field": key,
		"message": message,
	}


## A rejection (C2): no mutation; one diagnostic `command_rejected` on the
## same log, outside the current call's event range (rule 12a).
func _reject(command: Dictionary, code: String, detail: String) -> Dictionary:
	assert(REJECTION_CODES.has(code), "rejection code '%s' is outside the closed C2 set" % code)
	var log: Variant = _state.log
	var seq: int = log.append(&"command_rejected", {
		"side": str(command.get("issuer", "")),
		"command": command.duplicate(true),
		"code": code,
		"detail": detail,
		"diagnostic": true,
	}, 0)
	return MatchRecords.command_result(false, code, detail, seq, seq)


## The States-table guard: "" when [param command]'s type is accepted in the
## current phase from its issuer, else the rejection code ([constant PHASE_COMMANDS]).
func _phase_guard(command: Dictionary) -> String:
	var type: String = str(command.get("type", ""))
	var issuer: String = str(command.get("issuer", ""))
	var accepted: Dictionary = PHASE_COMMANDS.get(_state.phase, {})
	if not accepted.has(type):
		return R_CHOICE_PENDING if _state.phase == MatchState.PHASE_CHOICE else R_WRONG_PHASE
	match str(accepted[type]):
		"player":
			return "" if issuer == MatchRecords.SIDE_PLAYER else R_WRONG_PHASE
		"active":
			if not MatchRecords.SIDES.has(issuer):
				return R_WRONG_PHASE
			return "" if issuer == _state.active_side else R_NOT_YOUR_TURN
		"choice":
			var owed: Variant = _state.pending_choice
			var owed_side: String = str((owed as Dictionary).get("side", "")) if owed is Dictionary else ""
			return "" if issuer == owed_side else R_NOT_YOUR_TURN
	return R_WRONG_PHASE


## The command's own C2 row, checked in row order before any mutation: ""
## when valid, else the first failing code.
func _validate(type: String, command: Dictionary) -> String:
	match type:
		MatchRecords.CMD_MULLIGAN:
			var mask: Variant = command.get("keep_mask")
			if not mask is Array or (mask as Array).size() != _state.players[MatchRecords.SIDE_PLAYER].hand.size():
				return R_INVALID_MASK
			for bit: Variant in mask:
				if typeof(bit) != TYPE_BOOL:
					return R_INVALID_MASK
			return ""
		MatchRecords.CMD_END_TURN:
			return ""
	# TODO(stories 008, 010, 012, 016): concede, play_card,
	# use_hero_power, attack and choose handlers. Until one exists its
	# command is not accepted in any phase.
	return R_WRONG_PHASE


## C3 step 7 (DD-M05): unkept cards return to the bottom of the deck in hand
## order **before** one shuffle of the whole deck, then the same number is
## drawn; `mulligan_resolved {side, replaced_instance_ids}`. Kept cards keep
## their hand order; redraws append right.
func _do_mulligan(keep_mask: Array) -> void:
	var player: Dictionary = _state.players[MatchRecords.SIDE_PLAYER]
	var kept: Array[Dictionary] = []
	var replaced: Array[int] = []
	for i: int in keep_mask.size():
		var card: Dictionary = player.hand[i]
		if keep_mask[i]:
			kept.append(card)
		else:
			card.zone = "deck"
			player.deck.append(card)
			replaced.append(int(card.instance_id))
	player.hand.assign(kept)
	var stream: Variant = _state.rng_match
	stream.shuffle(player.deck)
	emit(&"deck_shuffled", {"side": MatchRecords.SIDE_PLAYER, "instance_ids": _instance_ids(player.deck)})
	draw(MatchRecords.SIDE_PLAYER, replaced.size())
	emit(&"mulligan_resolved", {"side": MatchRecords.SIDE_PLAYER, "replaced_instance_ids": replaced})
	# C3 step 8: match_started, then the player's first Start step (DD-M03)
	emit(&"match_started", {
		"floor": _state.floor,
		"hero_id": int(_state.players[MatchRecords.SIDE_PLAYER].hero.entity_id),
		"boss_id": int(_state.players[MatchRecords.SIDE_BOSS].hero.entity_id),
		"player_deck_size": _state.players[MatchRecords.SIDE_PLAYER].deck.size(),
		"boss_deck_size": _state.players[MatchRecords.SIDE_BOSS].deck.size(),
	})
	_start_step(MatchRecords.SIDE_PLAYER)


## C4 Start step for [param side] (engine-driven; no command is accepted
## until Main). Step 0 is the States guard `*Turn.Start` with
## `turn > TURN_CAP`: the match ends for the boss, reason `turn_cap` (C14).
func _start_step(side: String) -> void:
	if _state.turn + 1 > rule("turn_cap"):
		_end_match(MatchRecords.SIDE_BOSS, REASON_TURN_CAP)
		return
	var player: Dictionary = _state.players[side]
	# 1. phase, the global and own turn counters
	_state.phase = MatchState.PHASE_START
	_state.active_side = side
	_state.turn += 1
	player.turns_taken = int(player.turns_taken) + 1
	_stamp_log_turn(_state.turn)
	emit(&"turn_started", {"turn": _state.turn, "side": side})
	# 2. mana (F4): crystals from own turns plus the permanent bonus, then refill
	var old_max: int = int(player.mana_max)
	player.mana_max = mini(int(player.turns_taken) + int(player.crystal_bonus), rule("max_mana"))
	if int(player.mana_max) > old_max:
		emit(&"crystal_gained", {"side": side, "mana_max": player.mana_max, "gained": int(player.mana_max) - old_max})
	player.mana_current = player.mana_max
	emit(&"mana_refilled", {"side": side, "mana_available": player.mana_current, "mana_max": player.mana_max})
	# 3. one bulk reset, one event (DD-T04)
	var reset_ids: Array[int] = []
	for character: Dictionary in _characters_of(side):
		character.attacks_used = 0
		if character.get("kind", "") == MatchRecords.KIND_MINION:
			character.summoning_sick = false
		reset_ids.append(int(character.entity_id))
	player.hero_power.used_this_turn = false
	emit(&"turn_reset", {"side": side, "entity_ids": reset_ids})
	# 4. on_turn_start hooks; 5. turn_start triggers in engine candidate order
	_state.hooks.run_triggers(&"on_turn_start", StringName(side), {})
	_run_resolution_loop()
	_fire_trigger_point(&"turn_start", side)
	# 6. draw one, turn 1 included; 7. win/loss, then Main
	draw(side, 1)
	if _win_loss_check():
		return
	_set_phase(MatchState.PHASE_MAIN)


## C4 End step for the active [param side], entered by `end_turn`; runs the
## other side's Start step when the match goes on.
func _end_step(side: String) -> void:
	# 1.
	_state.phase = MatchState.PHASE_END
	emit(&"turn_ending", {"turn": _state.turn, "side": side})
	# 2. turn_end triggers (same candidate order); 3. on_turn_end hooks
	_fire_trigger_point(&"turn_end", side)
	_state.hooks.run_triggers(&"on_turn_end", StringName(side), {})
	_run_resolution_loop()
	# 4. TODO(story 015): the thaw rule (C13) for every `side` character.
	# 5. end_of_turn enchantments on everything `side` owns, then auras
	#    TODO(story 011): temporary crystals expire here too.
	_expire_end_of_turn(side)
	_resolver.recompute_auras()
	# 6.
	if _win_loss_check():
		return
	emit(&"turn_ended", {"turn": _state.turn, "side": side})
	_start_step(MatchRecords.SIDE_BOSS if side == MatchRecords.SIDE_PLAYER else MatchRecords.SIDE_PLAYER)


## Fires trigger point [param point] for [param side] (ADR-0007 Decision 1):
## `ctx.candidates` in the engine's one observer order; the triggers the
## resolver returns join the engine's queue Q, then the C10 loop runs.
func _fire_trigger_point(point: StringName, side: String) -> void:
	var queued: Array[Dictionary] = _resolver.resolve(point, {"side": side, "candidates": _candidates_in_order()})
	_queue.append_array(queued)
	_run_resolution_loop()


## The one observer order (C4 step 5, C10; cross-review C-16c): player board
## left to right, player weapon, player hero (hero power and hero
## enchantments live on it), then the boss side the same way — player side
## first regardless of whose turn it is.
func _candidates_in_order() -> Array[int]:
	var ids: Array[int] = []
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = _state.players[side]
		for minion: Dictionary in player.board:
			ids.append(int(minion.entity_id))
		if player.weapon != null:
			ids.append(int(player.weapon.entity_id))
		if player.hero != null:
			ids.append(int(player.hero.entity_id))
	return ids


## C4 End step 5: removes every `expires = end_of_turn` enchantment on what
## [param side] owns — its hero and minions, its weapon, and the
## `cost_modifiers` of its hand and deck cards — one `enchantment_removed`
## each, in that order.
func _expire_end_of_turn(side: String) -> void:
	var player: Dictionary = _state.players[side]
	for character: Dictionary in _characters_of(side):
		_expire_in(character.enchantments, int(character.entity_id))
	if player.weapon != null:
		_expire_in(player.weapon.enchantments, int(player.weapon.entity_id))
	for zone: String in ["hand", "deck"]:
		for card: Dictionary in player[zone]:
			_expire_in(card.cost_modifiers, int(card.instance_id))


func _expire_in(enchantments: Array, owner_id: int) -> void:
	var i: int = 0
	while i < enchantments.size():
		var enchantment: Dictionary = enchantments[i]
		if enchantment.get("expires") == MatchRecords.EXPIRES_END_OF_TURN:
			enchantments.remove_at(i)
			emit(&"enchantment_removed", {
				"instance_id": owner_id,
				"attack_delta": enchantment.attack_delta,
				"health_delta": enchantment.health_delta,
				"keywords_added": enchantment.keywords_added,
				"reason": MatchRecords.EXPIRES_END_OF_TURN,
			})
		else:
			i += 1


## [param side]'s characters in observer order: the hero, then the board left to right.
func _characters_of(side: String) -> Array[Dictionary]:
	var player: Dictionary = _state.players[side]
	var out: Array[Dictionary] = []
	if player.hero != null:
		out.append(player.hero)
	out.append_array(player.board)
	return out


## C10 resolution loop (death check → `recompute_auras()` → queue pop) after a
## step. TODO(story 009): the real loop and `RESOLUTION_STEP_CAP`; until then
## queued triggers wait in [member _queue].
func _run_resolution_loop() -> void:
	pass


## C14 `win_loss_check()`: true when the match has ended.
## TODO(story 008): the hero-dead / both-dead outcomes; this story ends a
## match only through `turn_cap`.
func _win_loss_check() -> bool:
	return _state.phase == MatchState.PHASE_ENDED


## `phase = Ended` with a `MatchResult` (C14), emitted as `match_ended` — the
## log's last event. [param winner] is a side; `result` is read from the
## player's side.
## TODO(story 008): the full `MatchResult` stats block, faults, and
## `resolver.unbind()` at Ended (breaks the engine↔resolver cycle).
func _end_match(winner: String, reason: String) -> void:
	_state.phase = MatchState.PHASE_ENDED
	var outcome: Dictionary = MatchRecords.match_result("win" if winner == MatchRecords.SIDE_PLAYER else "loss", winner, reason, _state.floor, _state.turn)
	for side: String in MatchRecords.SIDES:
		outcome.turns_per_side[side] = int(_state.players[side].turns_taken)
		outcome.final_health[side] = health(_state.players[side].hero)
	_state.result = outcome
	emit(&"match_ended", outcome)


## Sets [param phase] for the active side and emits `phase_changed {phase, side}`.
func _set_phase(new_phase: String) -> void:
	_state.phase = new_phase
	emit(&"phase_changed", {"phase": new_phase, "side": _state.active_side})


## rng-event-log rule 13: the log stamps `turn` from its current turn, which
## the engine sets immediately before appending `turn_started`.
## TODO(rng-event-log story 005): call `EventLog.set_turn` only, once the
## production log exists; `TestEventLog` exposes the `turn` property.
func _stamp_log_turn(turn_number: int) -> void:
	var log: Variant = _state.log
	if log.has_method(&"set_turn"):
		log.set_turn(turn_number)
	else:
		log.turn = turn_number


## C3 step 1: the engine, not the registry or the resolver, logs a skipped
## installer. The registry is fresh at `bind`, so an installer is skipped
## exactly when an earlier one in [param installers] has its `host_id`.
func _log_skipped_installers(installers: Array) -> void:
	var seen: Dictionary = {}
	for installer: HookInstaller in installers:
		if seen.has(installer.host_id):
			emit(&"hook_install_skipped", {"host_id": installer.host_id, "reason": SKIP_REASON_DUPLICATE})
		else:
			seen[installer.host_id] = true


## C3 step 3 for [param side]: one `CardInstance` per entry of [param def_ids]
## in list order, one `rng_match` shuffle, one `deck_shuffled`.
func _build_deck(side: String, def_ids: Array) -> void:
	var deck: Array = _state.players[side].deck
	for def_id: Variant in def_ids:
		deck.append(MatchRecords.card_instance(_take_entity_id(), str(def_id), "deck"))
	var stream: Variant = _state.rng_match
	stream.shuffle(deck)
	emit(&"deck_shuffled", {"side": side, "instance_ids": _instance_ids(deck)})


## C3 step 5: the `modify_starting_hand_size` fold over [param base], clamped
## once to `[0, hand_size]` (Interactions hook table; ADR-0005 rule 4).
func _starting_hand_size(side: String, base: int) -> int:
	var n: int = _state.hooks.fold(&"modify_starting_hand_size", StringName(side), base, {})
	return clampi(n, 0, rule("hand_size"))


## The next entity id (C1: unique per match, assigned at creation).
func _take_entity_id() -> int:
	var id: int = _state.next_entity_id
	_state.next_entity_id = id + 1
	return id


static func _instance_ids(cards: Array) -> Array[int]:
	var ids: Array[int] = []
	for card: Dictionary in cards:
		ids.append(int(card.instance_id))
	return ids


func _weapon_of(character: Dictionary) -> Variant:
	if character.get("kind", "") != MatchRecords.KIND_HERO or _state == null:
		return null
	var player: Dictionary = _state.players.get(str(character.controller), {})
	return player.get("weapon")


func _has_keyword(character: Dictionary, keyword: String) -> bool:
	if character.keywords.has(keyword):
		return true
	for enchantment: Dictionary in character.enchantments:
		if enchantment.keywords_added.has(keyword):
			return true
	return false


func _find_record(entity_id: int) -> Dictionary:
	if _state == null:
		return {}
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = _state.players[side]
		var hero: Variant = player.hero
		if hero != null and int(hero.entity_id) == entity_id:
			return hero
		var weapon: Variant = player.weapon
		if weapon != null and int(weapon.entity_id) == entity_id:
			return weapon
		for minion: Dictionary in player.board:
			if int(minion.entity_id) == entity_id:
				return minion
		for zone: String in ["hand", "deck", "graveyard"]:
			for card: Dictionary in player[zone]:
				if int(card.instance_id) == entity_id:
					return card
	return {}
