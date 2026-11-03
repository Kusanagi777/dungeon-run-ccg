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
## `end_turn` handler, [method add_mana] (permanent) and the `TURN_CAP` end;
## story 006 the primitive API ([constant PRIMITIVES], match-rules
## Interactions) — each validates its arguments (a missing entity is a no-op
## with no event), mutates the plain-data state, emits its one event through
## [method emit] and returns, never running the death check or auras — and
## the full [method draw] (burn, fatigue, `on_draw`).
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
## The engine primitive API (match-rules Interactions; ADR-0007 Decision 1):
## the only calls that mutate a started match, each leaving one event. The
## 24th call, `recompute_auras`, is the resolver's, run by the C10 loop.
const PRIMITIVES: Array[StringName] = [
	&"draw", &"apply_damage", &"apply_heal", &"apply_armor", &"apply_enchantment",
	&"remove_enchantment", &"summon_minion", &"destroy", &"silence", &"freeze",
	&"add_keyword", &"return_to_hand", &"transform", &"add_mana", &"equip_weapon",
	&"discover", &"add_card_to_hand", &"set_stats", &"remove_keyword",
	&"add_card_to_deck", &"modify_durability", &"refresh_hero_power", &"discard",
]
## The `source` of fatigue damage (C11, F2): a sentinel with no keywords, no
## controller and no `damage_dealt_by_card` attribution.
const SOURCE_FATIGUE: String = "fatigue"
## `enchantment_removed.reason` for [method remove_enchantment] (the End-step
## expiry uses `MatchRecords.EXPIRES_END_OF_TURN`).
const REMOVE_REASON_EFFECT: String = "effect"
## `enchantment_applied.reason` for the enchantment [method set_stats] writes.
const ENCHANT_REASON_SET_STATS: String = "set_stats"
## `summon_failed.reason` on a full board (C10, Edge Cases).
const SUMMON_FAILED_BOARD_FULL: String = "board_full"
## `weapon_destroyed.reason` when [method equip_weapon] replaces a weapon.
const WEAPON_REPLACED: String = "replaced"
## What an entity-creating primitive returns when it created nothing (C1 ids
## start at `MatchState.FIRST_ENTITY_ID`).
const NO_ENTITY: int = -1
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
## The `{source, target}` contexts of the `modify_damage` / `modify_heal`
## folds, reused on every call (ADR-0005: the fold allocates nothing; the
## engine does not build a context per hit either).
var _damage_ctx: Dictionary = {"source": null, "target": 0}
var _heal_ctx: Dictionary = {"source": null, "target": 0}


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
	# Typed as ADR-0007's `bind(engine, installers: Array[HookInstaller])`: a
	# plain Array into that typed parameter is a SCRIPT ERROR on 4.7.2.
	var installers: Array[HookInstaller] = []
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
## cards, one per-card draw at a time ("draw N" is N draws). Each draw:
## - empty deck → `fatigue_counter += 1` (per side, never reset) and F5
##   `fatigue_base + (k − 1) × fatigue_step` damage to the hero through
##   [method apply_damage] with [constant SOURCE_FATIGUE] (armour applies),
##   then `fatigue_damage {side, amount, counter}` (DD-M07);
## - else the top card (index 0) leaves the deck; a hand already at
##   `hand_size` sends it to the graveyard with `card_burned {side,
##   instance_id, card_id}` and no `on_draw` (DD-M06); otherwise it joins the
##   right end of the hand with `card_drawn {side, instance_id, card_id,
##   hand_size}`, the `on_draw` hooks run, then trigger point `on_draw` is
##   raised (its triggers join queue Q).
## A 0-card deck at setup takes fatigue like any other draw (Edge Cases).
## [codeblock]
## engine.draw("player", 2)
## [/codeblock]
func draw(side: String, n: int) -> void:
	var player: Dictionary = _state.players[side]
	for _i: int in n:
		if player.deck.is_empty():
			player.fatigue_counter = int(player.fatigue_counter) + 1
			var k: int = player.fatigue_counter
			var amount: int = rule("fatigue_base") + (k - 1) * rule("fatigue_step")
			@warning_ignore("return_value_discarded")
			apply_damage(int(player.hero.entity_id), amount, SOURCE_FATIGUE)
			emit(&"fatigue_damage", {"side": side, "amount": amount, "counter": k})
			continue
		var card: Dictionary = player.deck.pop_front()
		var instance_id: int = int(card.instance_id)
		var def_id: String = str(card.def_id)
		if player.hand.size() >= rule("hand_size"):
			card.zone = "graveyard"
			player.graveyard.append(card)
			emit(&"card_burned", {"side": side, "instance_id": instance_id, "card_id": def_id})
			continue
		card.zone = "hand"
		player.hand.append(card)
		emit(&"card_drawn", {"side": side, "instance_id": instance_id, "card_id": def_id, "hand_size": player.hand.size()})
		_state.hooks.run_triggers(&"on_draw", StringName(side), {"instance_id": instance_id, "card_id": def_id})
		_raise(&"on_draw", {"side": side, "candidates": _candidates_in_order(), "subject": instance_id, "card_id": def_id})


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


## Primitive (F2, C9): [param requested] damage to the character
## [param target_id] from [param source] — an entity id (a minion, a hero, the
## weapon a hero attacks with — its keywords then count for the attack — or a
## card instance) or [constant SOURCE_FATIGUE] — evaluated in one step:
## 1. `amount = maxi(0, hooks.fold(&"modify_damage", source_side, requested,
##    {source, target}))` — the engine's one clamp, after the whole fold
##    (ADR-0005 rule 4). `source_side` is the source's side; fatigue, which
##    has none, folds with the target's side.
## 2. Divine Shield and `amount > 0`: `prevented = amount`, `amount = 0`, the
##    shield keyword is removed, `divine_shield_popped {entity_id, prevented}`.
## 3. Armour absorbs first (heroes only): `armor_lost {side, entity_id,
##    amount, armor}` when > 0; the rest raises `damage_taken`.
## 4. `dealt = armor_absorbed + to_health`; `damage_dealt {source, target,
##    requested, prevented, armor_absorbed, dealt, health_after}`
##    (`health_after` may be negative); stats: the target side's
##    `damage_taken` and the source side's `damage_dealt_by_card[def_id]`.
## 5. When `dealt > 0`: a Poisonous source marks a minion target
##    `pending_destroy` (heroes immune); a Lifesteal source heals its side's
##    hero by `dealt` ([method apply_heal]); a hero target runs the
##    `on_hero_damaged` hooks `{amount_dealt, source}`; trigger point
##    `on_damage {subject, amount, source}` is raised (its triggers join Q).
## Returns `dealt`. A missing target is a no-op returning 0. Never runs the
## death check (C10), so a Poisonous attacker killed by its defender still
## poisons it.
## [codeblock]
## var dealt: int = engine.apply_damage(target_id, 3, attacker_id)
## [/codeblock]
func apply_damage(target_id: int, requested: int, source: Variant) -> int:
	var target: Dictionary = _character(target_id)
	if target.is_empty():
		return 0
	var target_side: String = str(target.controller)
	var source_side: String = _owner_of(source) if typeof(source) == TYPE_INT else ""
	var fold_side: String = source_side if source_side != "" else target_side
	_damage_ctx.source = source
	_damage_ctx.target = target_id
	var amount: int = maxi(0, _state.hooks.fold(&"modify_damage", StringName(fold_side), requested, _damage_ctx))
	var prevented: int = 0
	if amount > 0 and _has_keyword(target, MatchRecords.KEYWORD_DIVINE_SHIELD):
		prevented = amount
		amount = 0
		_strip_keyword(target, MatchRecords.KEYWORD_DIVINE_SHIELD)
		emit(&"divine_shield_popped", {"entity_id": target_id, "prevented": prevented})
	var armor_absorbed: int = 0
	if target.kind == MatchRecords.KIND_HERO:
		armor_absorbed = mini(int(target.armor), amount)
		if armor_absorbed > 0:
			target.armor = int(target.armor) - armor_absorbed
			emit(&"armor_lost", {"side": target_side, "entity_id": target_id, "amount": armor_absorbed, "armor": int(target.armor)})
	var to_health: int = amount - armor_absorbed
	target.damage_taken = int(target.damage_taken) + to_health
	var dealt: int = armor_absorbed + to_health
	emit(&"damage_dealt", {
		"source": source, "target": target_id, "requested": requested, "prevented": prevented,
		"armor_absorbed": armor_absorbed, "dealt": dealt, "health_after": health(target),
	})
	if dealt <= 0:
		return dealt
	_record_damage_stats(target_side, source, source_side, dealt)
	if target.kind == MatchRecords.KIND_MINION and _source_has(source, MatchRecords.KEYWORD_POISONOUS):
		target["pending_destroy"] = true
	if source_side != "" and _source_has(source, MatchRecords.KEYWORD_LIFESTEAL):
		@warning_ignore("return_value_discarded")
		apply_heal(int(_state.players[source_side].hero.entity_id), dealt, source)
	if target.kind == MatchRecords.KIND_HERO:
		_state.hooks.run_triggers(&"on_hero_damaged", StringName(target_side), {"amount_dealt": dealt, "source": source})
	_raise(&"on_damage", {"side": target_side, "candidates": _candidates_in_order(), "subject": target_id, "amount": dealt, "source": source})
	return dealt


## Primitive (C9): heals the character [param target_id] from
## [param source]: `heal = maxi(0, hooks.fold(&"modify_heal", source_side,
## amount, {source, target}))` — floored once, so a hook can reduce a heal to
## nothing but never turn it into damage (Treasures R-4); then `restored =
## min(heal, damage_taken)` (health never exceeds `max_health`). Emits
## `healed {source, target, requested, amount: restored}` always — a
## full-health target heals 0 and still emits — then raises trigger point
## `on_heal {subject, amount, source}`. Returns `restored`; a missing target
## is a no-op returning 0. A source with no side folds with the target's.
## [codeblock]
## engine.apply_heal(hero_id, 10, source_id)   # restores at most damage_taken
## [/codeblock]
func apply_heal(target_id: int, amount: int, source: Variant) -> int:
	var target: Dictionary = _character(target_id)
	if target.is_empty():
		return 0
	var target_side: String = str(target.controller)
	var source_side: String = _owner_of(source) if typeof(source) == TYPE_INT else ""
	_heal_ctx.source = source
	_heal_ctx.target = target_id
	var heal: int = maxi(0, _state.hooks.fold(&"modify_heal", StringName(source_side if source_side != "" else target_side), amount, _heal_ctx))
	var restored: int = mini(heal, int(target.damage_taken))
	target.damage_taken = int(target.damage_taken) - restored
	emit(&"healed", {"source": source, "target": target_id, "requested": amount, "amount": restored})
	_raise(&"on_heal", {"side": target_side, "candidates": _candidates_in_order(), "subject": target_id, "amount": restored, "source": source})
	return restored


## Primitive (C9): [param side]'s hero gains [param amount] armour, uncapped;
## emits `armor_gained {side, entity_id, amount, armor}`.
## [codeblock]
## engine.apply_armor("player", 4)
## [/codeblock]
func apply_armor(side: String, amount: int) -> void:
	var hero: Dictionary = _state.players[side].hero
	hero.armor = int(hero.armor) + amount
	emit(&"armor_gained", {"side": side, "entity_id": int(hero.entity_id), "amount": amount, "armor": int(hero.armor)})


## Primitive (C1, C9): appends an Enchantment built from [param enchantment]
## (`{attack_delta, health_delta, keywords_added, source_entity_id, is_aura,
## expires}`, missing keys defaulted by `MatchRecords.enchantment`;
## `cost_delta` kept when given) to [param target_id] — a character's or
## weapon's `enchantments`, or a card instance's `cost_modifiers` — and
## emits `enchantment_applied {instance_id, attack_delta, health_delta,
## keywords_added, source_entity_id, is_aura, expires}`. Never writes `base_*`.
## [codeblock]
## engine.apply_enchantment(minion_id, {"attack_delta": 2, "health_delta": 2})
## [/codeblock]
func apply_enchantment(target_id: int, enchantment: Dictionary) -> void:
	var record: Dictionary = _find_record(target_id)
	if record.is_empty():
		return
	var applied: Dictionary = MatchRecords.enchantment(
		int(enchantment.get("attack_delta", 0)), int(enchantment.get("health_delta", 0)),
		enchantment.get("keywords_added", []), enchantment.get("source_entity_id"),
		bool(enchantment.get("is_aura", false)), enchantment.get("expires"))
	if enchantment.has("cost_delta"):
		applied["cost_delta"] = int(enchantment.cost_delta)
	_enchantments_of(record).append(applied)
	emit(&"enchantment_applied", _enchantment_payload(target_id, applied))


## Primitive (C1): removes the enchantment at [param index] of
## [param target_id]'s `enchantments` (`cost_modifiers` for a card instance)
## and emits `enchantment_removed {instance_id, attack_delta, health_delta,
## keywords_added, reason: "effect"}`. Enchantments carry no id of their
## own, so the GDD's `remove_enchantment(target, id)` is the list index here.
## An index outside the list is a no-op.
## [codeblock]
## engine.remove_enchantment(minion_id, 0)
## [/codeblock]
func remove_enchantment(target_id: int, index: int) -> void:
	var record: Dictionary = _find_record(target_id)
	if record.is_empty():
		return
	var list: Array = _enchantments_of(record)
	if index < 0 or index >= list.size():
		return
	var removed: Dictionary = list[index]
	list.remove_at(index)
	emit(&"enchantment_removed", {
		"instance_id": target_id,
		"attack_delta": removed.attack_delta,
		"health_delta": removed.health_delta,
		"keywords_added": removed.keywords_added,
		"reason": REMOVE_REASON_EFFECT,
	})


## Primitive (C10): summons [param def_id] (a minion definition from the
## Card Database) for [param side] at [param position] — a board index;
## negative or beyond the end means the rightmost slot. The minion is
## `summoning_sick` with `summoned_on_turn = turn`; `stats.minions_summoned`
## rises; emits `minion_summoned {side, entity_id, card_id, position, attack,
## health}`, then runs the `on_minion_summoned` hooks. A full board is a
## no-op with `summon_failed {side, card_id, reason: board_full}`. Returns the
## new entity id, or [constant NO_ENTITY].
## [codeblock]
## var id: int = engine.summon_minion("boss", "boss_imp", -1)
## [/codeblock]
func summon_minion(side: String, def_id: String, position: int) -> int:
	var player: Dictionary = _state.players[side]
	var board: Array = player.board
	if board.size() >= rule("board_size"):
		emit(&"summon_failed", {"side": side, "card_id": def_id, "reason": SUMMON_FAILED_BOARD_FULL})
		return NO_ENTITY
	var def: Dictionary = _card_def(def_id)
	if def.is_empty():
		return NO_ENTITY
	var minion: Dictionary = _minion_from_def(def_id, def, side)
	var index: int = board.size() if position < 0 or position > board.size() else position
	board.insert(index, minion)
	player.stats.minions_summoned = int(player.stats.minions_summoned) + 1
	emit(&"minion_summoned", {
		"side": side, "entity_id": int(minion.entity_id), "card_id": def_id, "position": index,
		"attack": attack(minion), "health": health(minion),
	})
	_state.hooks.run_triggers(&"on_minion_summoned", StringName(side), {"entity_id": int(minion.entity_id), "card_id": def_id})
	return int(minion.entity_id)


## Primitive (C10, States "pending_destroy"): marks the minion or weapon
## [param target_id] `pending_destroy`; it leaves play in the next death check
## (story 009), whose `minion_died` / `weapon_destroyed` is the event — C15
## has no event for the mark itself.
## [codeblock]
## engine.destroy(minion_id)
## [/codeblock]
func destroy(target_id: int) -> void:
	var record: Dictionary = _minion(target_id)
	if record.is_empty():
		record = _weapon(target_id)
	if record.is_empty():
		return
	record["pending_destroy"] = true


## Primitive (C13): silences the minion [param target_id] — `silenced = true`
## and `silenced {entity_id}`.
## TODO(story 015): strip enchantments and keywords, the F6 clamp, thaw.
## [codeblock]
## engine.silence(minion_id)
## [/codeblock]
func silence(target_id: int) -> void:
	var minion: Dictionary = _minion(target_id)
	if minion.is_empty():
		return
	minion.silenced = true
	emit(&"silenced", {"entity_id": target_id})


## Primitive (C13): freezes the character [param target_id] — `frozen =
## true`, `frozen_on_turn = turn` (a second freeze re-stamps it) — and emits
## `frozen {entity_id, frozen_on_turn}`.
## [codeblock]
## engine.freeze(hero_id)
## [/codeblock]
func freeze(target_id: int) -> void:
	var character: Dictionary = _character(target_id)
	if character.is_empty():
		return
	character.frozen = true
	character.frozen_on_turn = _state.turn
	emit(&"frozen", {"entity_id": target_id, "frozen_on_turn": _state.turn})


## Primitive (C1 `keywords`): grants [param keyword] to the character or
## weapon [param target_id] as an enchantment with `keywords_added =
## [keyword]` (so Silence strips it with the enchantments) — one
## `enchantment_applied`. A keyword already held is a no-op.
## [codeblock]
## engine.add_keyword(minion_id, "taunt")
## [/codeblock]
func add_keyword(target_id: int, keyword: String) -> void:
	var record: Dictionary = _character(target_id)
	if record.is_empty():
		record = _weapon(target_id)
	if record.is_empty() or _has_keyword(record, keyword):
		return
	apply_enchantment(target_id, {"keywords_added": [keyword]})


## Primitive (card-effects `return_to_hand`): the minion [param target_id]
## leaves the board (no death, no Deathrattle) and its controller gets a
## fresh card instance of its `def_id` — `card_added_to_hand {side,
## instance_id, card_id, hand_size, returned_entity_id}`, or on a full hand
## `card_burned {…, returned_entity_id}` with the card in the graveyard.
## Returns the new instance id, or [constant NO_ENTITY].
## [codeblock]
## var card_id: int = engine.return_to_hand(minion_id)
## [/codeblock]
func return_to_hand(target_id: int) -> int:
	var minion: Dictionary = _minion(target_id)
	if minion.is_empty():
		return NO_ENTITY
	var side: String = str(minion.controller)
	var board: Array = _state.players[side].board
	board.remove_at(board.find(minion))
	return _add_to_hand(side, str(minion.def_id), target_id)


## Primitive (card-effects `transform`): replaces the minion [param target_id]
## in its board slot with a new minion of [param def_id] with a **new**
## `entity_id`, base stats and keywords from the definition and no
## enchantments or damage. Summoning sickness, `summoned_on_turn` and
## `attacks_used` carry over (no sickness reset). Emits `minion_transformed
## {side, old_entity_id, entity_id, card_id, position}`. Returns the new id,
## or [constant NO_ENTITY].
## [codeblock]
## var sheep_id: int = engine.transform(target_id, "neutral_sheep")
## [/codeblock]
func transform(target_id: int, def_id: String) -> int:
	var old: Dictionary = _minion(target_id)
	if old.is_empty():
		return NO_ENTITY
	var def: Dictionary = _card_def(def_id)
	if def.is_empty():
		return NO_ENTITY
	var side: String = str(old.controller)
	var board: Array = _state.players[side].board
	var index: int = board.find(old)
	var minion: Dictionary = _minion_from_def(def_id, def, side)
	minion.summoning_sick = old.summoning_sick
	minion.summoned_on_turn = old.summoned_on_turn
	minion.attacks_used = old.attacks_used
	board[index] = minion
	emit(&"minion_transformed", {
		"side": side, "old_entity_id": target_id, "entity_id": int(minion.entity_id),
		"card_id": def_id, "position": index,
	})
	return int(minion.entity_id)


## Primitive (C6 weapons): [param side] equips [param def_id] (a weapon
## definition). A held weapon is destroyed first — `weapon_destroyed {side,
## entity_id, card_id, reason: replaced}` — then `weapon_equipped {side,
## entity_id, card_id, attack, durability}`. Returns the new weapon's id, or
## [constant NO_ENTITY].
## TODO(story 009): queue the replaced weapon's Deathrattle.
## [codeblock]
## var axe_id: int = engine.equip_weapon("player", "war_iron_axe")
## [/codeblock]
func equip_weapon(side: String, def_id: String) -> int:
	var def: Dictionary = _card_def(def_id)
	if def.is_empty():
		return NO_ENTITY
	var player: Dictionary = _state.players[side]
	if player.weapon != null:
		var old: Dictionary = player.weapon
		player.weapon = null
		emit(&"weapon_destroyed", {"side": side, "entity_id": int(old.entity_id), "card_id": str(old.def_id), "reason": WEAPON_REPLACED})
	var weapon: Dictionary = MatchRecords.weapon(_take_entity_id(), def_id, int(def.get("attack", 0)), int(def.get("durability", 0)), def.get("keywords", []))
	player.weapon = weapon
	emit(&"weapon_equipped", {
		"side": side, "entity_id": int(weapon.entity_id), "card_id": def_id,
		"attack": int(weapon.attack), "durability": int(weapon.durability),
	})
	return int(weapon.entity_id)


## Primitive (C2 `Choice`, Discover): creates the `ChoiceRequest {side, kind,
## options, source_id, effect_id}` ([method MatchRecords.choice_request]),
## stores it as `pending_choice`, emits `choice_requested` with it and
## returns it. The resolver keeps the continuation (ADR-0007).
## TODO(story 016): enter the `Choice` phase and resume on `choose`.
## [codeblock]
## var req: Dictionary = engine.discover("player", ["a_01", "b_02", "c_03"], MatchRecords.CHOICE_DISCOVER, source_id, "scout.0")
## [/codeblock]
func discover(side: String, options: Array, kind: String = MatchRecords.CHOICE_DISCOVER, source_id: Variant = null, effect_id: String = "") -> Dictionary:
	var request: Dictionary = MatchRecords.choice_request(side, kind, options, source_id, effect_id)
	_state.pending_choice = request
	emit(&"choice_requested", request)
	return request


## Primitive (C15 `card_added_to_hand`): a fresh card instance of
## [param def_id] for [param side]'s hand — `card_added_to_hand {side,
## instance_id, card_id, hand_size}`, or on a full hand `card_burned {side,
## instance_id, card_id}` with the card in the graveyard. No `on_draw`.
## Returns the new instance id.
## [codeblock]
## engine.add_card_to_hand("player", "neutral_coin")
## [/codeblock]
func add_card_to_hand(side: String, def_id: String) -> int:
	return _add_to_hand(side, def_id, NO_ENTITY)


## Primitive (C9 "Set/raise health"): sets the minion [param target_id]'s
## attack and/or health (null leaves that stat alone) through one
## enchantment whose deltas reach the new values — `base_*` are never
## written. Setting health clears `damage_taken`, so `health == max_health ==
## health`. Emits `enchantment_applied` with `reason: set_stats`.
## [codeblock]
## engine.set_stats(minion_id, 4, 1)
## [/codeblock]
func set_stats(target_id: int, new_attack: Variant = null, new_health: Variant = null) -> void:
	var minion: Dictionary = _minion(target_id)
	if minion.is_empty():
		return
	var attack_delta: int = 0 if new_attack == null else int(new_attack) - attack(minion)
	var health_delta: int = 0 if new_health == null else int(new_health) - max_health(minion)
	var applied: Dictionary = MatchRecords.enchantment(attack_delta, health_delta)
	minion.enchantments.append(applied)
	if new_health != null:
		minion.damage_taken = 0
	var payload: Dictionary = _enchantment_payload(target_id, applied)
	payload["reason"] = ENCHANT_REASON_SET_STATS
	emit(&"enchantment_applied", payload)


## Primitive (match-rules Interactions, added 2026-11-03): removes
## [param keyword] from the character or weapon [param target_id] — from its
## definition set and from every enchantment that grants it — and emits
## `keyword_removed {entity_id, keyword}`. Takes effect at the next legality
## or damage evaluation. A keyword not held is a no-op.
## [codeblock]
## engine.remove_keyword(minion_id, "taunt")
## [/codeblock]
func remove_keyword(target_id: int, keyword: String) -> void:
	var record: Dictionary = _character(target_id)
	if record.is_empty():
		record = _weapon(target_id)
	if record.is_empty() or not _has_keyword(record, keyword):
		return
	_strip_keyword(record, keyword)
	emit(&"keyword_removed", {"entity_id": target_id, "keyword": keyword})


## Primitive (match-rules Interactions, added 2026-11-03): a fresh card
## instance of [param def_id] into [param side]'s deck at [param position] —
## `top` (index 0), `bottom`, or `random` (exactly one
## `rng_match.randi_range(0, deck.size())`, nothing from any other stream).
## Emits `card_added_to_deck {side, instance_id, card_id, position, index,
## deck_size}`. Returns the instance id, or [constant NO_ENTITY] for an
## unknown position.
## [codeblock]
## engine.add_card_to_deck("boss", "boss_bomb", MatchRecords.POSITION_RANDOM)
## [/codeblock]
func add_card_to_deck(side: String, def_id: String, position: String = MatchRecords.POSITION_RANDOM) -> int:
	var deck: Array = _state.players[side].deck
	var index: int
	match position:
		MatchRecords.POSITION_TOP:
			index = 0
		MatchRecords.POSITION_BOTTOM:
			index = deck.size()
		MatchRecords.POSITION_RANDOM:
			var stream: Variant = _state.rng_match
			index = stream.randi_range(0, deck.size())
		_:
			push_warning("RulesEngine.add_card_to_deck: unknown position '%s'" % position)
			return NO_ENTITY
	var card: Dictionary = MatchRecords.card_instance(_take_entity_id(), def_id, "deck")
	deck.insert(index, card)
	emit(&"card_added_to_deck", {
		"side": side, "instance_id": int(card.instance_id), "card_id": def_id,
		"position": position, "index": index, "deck_size": deck.size(),
	})
	return int(card.instance_id)


## Primitive (match-rules Interactions, added 2026-11-03): changes the weapon
## [param weapon_id]'s durability by [param delta] and emits
## `weapon_durability_changed {side, entity_id, delta, durability}`; a weapon
## at ≤ 0 breaks in the next death check (story 009).
## [codeblock]
## engine.modify_durability(axe_id, -1)
## [/codeblock]
func modify_durability(weapon_id: int, delta: int) -> void:
	var weapon: Dictionary = _weapon(weapon_id)
	if weapon.is_empty():
		return
	weapon.durability = int(weapon.durability) + delta
	emit(&"weapon_durability_changed", {
		"side": _owner_of(weapon_id), "entity_id": weapon_id, "delta": delta,
		"durability": int(weapon.durability),
	})


## Primitive (match-rules Interactions, added 2026-11-03): [param side]'s
## hero power may be used again this turn — `used_this_turn = false`, no mana
## refund, `hero_power_refreshed {side}`. An unused power is a no-op.
## [codeblock]
## engine.refresh_hero_power("player")
## [/codeblock]
func refresh_hero_power(side: String) -> void:
	var power: Dictionary = _state.players[side].hero_power
	if not power.used_this_turn:
		return
	power.used_this_turn = false
	emit(&"hero_power_refreshed", {"side": side})


## Primitive (match-rules Interactions, added 2026-11-03): [param side]
## discards the hand card at [param which] — a hand index, or
## `MatchRecords.PICK_RANDOM` for exactly one `rng_match.randi_range(0,
## hand.size() − 1)`. The card goes to the graveyard (no burn, no `on_draw`)
## with `card_discarded {side, instance_id, card_id, hand_index}`. Returns the
## instance id; an empty hand or a bad index is a no-op returning
## [constant NO_ENTITY] (and draws nothing).
## [codeblock]
## engine.discard("player", MatchRecords.PICK_RANDOM)
## [/codeblock]
func discard(side: String, which: Variant = MatchRecords.PICK_RANDOM) -> int:
	var player: Dictionary = _state.players[side]
	var hand: Array = player.hand
	if hand.is_empty():
		return NO_ENTITY
	var index: int
	if typeof(which) == TYPE_INT:
		index = which
	elif str(which) == MatchRecords.PICK_RANDOM:
		var stream: Variant = _state.rng_match
		index = stream.randi_range(0, hand.size() - 1)
	else:
		return NO_ENTITY
	if index < 0 or index >= hand.size():
		return NO_ENTITY
	var card: Dictionary = hand[index]
	hand.remove_at(index)
	card.zone = "graveyard"
	player.graveyard.append(card)
	emit(&"card_discarded", {"side": side, "instance_id": int(card.instance_id), "card_id": str(card.def_id), "hand_index": index})
	return int(card.instance_id)


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
## installer, and reads what was skipped from the registry after `bind`
## rather than re-deriving the duplicate rule (ADR-0005 rule 5:
## `install()` refuses a duplicate `host_id`). The resolver installs
## [param installers] in order, so `hooks.hosts()` is the installed ones in
## that order; an installer that is not the next installed host was refused.
func _log_skipped_installers(installers: Array[HookInstaller]) -> void:
	var installed: Array[Dictionary] = _state.hooks.hosts()
	var next: int = 0
	for installer: HookInstaller in installers:
		if next < installed.size() and installed[next].host_id == installer.host_id:
			next += 1
		else:
			emit(&"hook_install_skipped", {"host_id": installer.host_id, "reason": SKIP_REASON_DUPLICATE})


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


## The hero or board minion [param entity_id] (a character in play), else `{}`.
func _character(entity_id: int) -> Dictionary:
	for side: String in MatchRecords.SIDES:
		var hero: Variant = _state.players[side].hero
		if hero != null and int(hero.entity_id) == entity_id:
			return hero
	return _minion(entity_id)


## The board minion [param entity_id], else `{}`.
func _minion(entity_id: int) -> Dictionary:
	for side: String in MatchRecords.SIDES:
		for minion: Dictionary in _state.players[side].board:
			if int(minion.entity_id) == entity_id:
				return minion
	return {}


## The equipped weapon [param entity_id], else `{}`.
func _weapon(entity_id: int) -> Dictionary:
	for side: String in MatchRecords.SIDES:
		var weapon: Variant = _state.players[side].weapon
		if weapon != null and int(weapon.entity_id) == entity_id:
			return weapon
	return {}


## The side that holds [param entity_id] in any zone, or "" when none does.
func _owner_of(entity_id: int) -> String:
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = _state.players[side]
		for slot: String in ["hero", "weapon"]:
			var record: Variant = player[slot]
			if record != null and int(record.entity_id) == entity_id:
				return side
		for minion: Dictionary in player.board:
			if int(minion.entity_id) == entity_id:
				return side
		for zone: String in ["hand", "deck", "graveyard"]:
			for card: Dictionary in player[zone]:
				if int(card.instance_id) == entity_id:
					return side
	return ""


## The Card Database definition of [param def_id] (`CardDatabase.card(id)`),
## or `{}` with a warning when there is no database or no such card — the
## primitive that asked is then a no-op (a content bug, not a crash).
func _card_def(def_id: String) -> Dictionary:
	var def: Variant = _db.card(def_id) if _db != null else null
	if def is Dictionary:
		return def
	push_warning("RulesEngine: no card definition '%s'" % def_id)
	return {}


## A new minion of [param def_id] for [param side] from its definition
## [param def]: base stats and keywords, sick, summoned this turn (C1, C10).
func _minion_from_def(def_id: String, def: Dictionary, side: String) -> Dictionary:
	return MatchRecords.minion(_take_entity_id(), side, int(def.get("attack", 0)), int(def.get("health", 0)), def.get("keywords", []), def_id, _state.turn)


## Where an enchantment on [param record] lives: a card instance's
## `cost_modifiers`, else the character's or weapon's `enchantments`.
static func _enchantments_of(record: Dictionary) -> Array:
	return record.cost_modifiers if record.has("cost_modifiers") else record.enchantments


static func _enchantment_payload(owner_id: int, enchantment: Dictionary) -> Dictionary:
	var payload: Dictionary = {
		"instance_id": owner_id,
		"attack_delta": enchantment.attack_delta,
		"health_delta": enchantment.health_delta,
		"keywords_added": enchantment.keywords_added,
		"source_entity_id": enchantment.source_entity_id,
		"is_aura": enchantment.is_aura,
		"expires": enchantment.expires,
	}
	if enchantment.has("cost_delta"):
		payload["cost_delta"] = enchantment.cost_delta
	return payload


## C1 stats for one `apply_damage`: [param target_side]'s `damage_taken` and
## [param source_side]'s `damage_dealt_by_card[def_id]` move by
## [param dealt]. A source without a `def_id` (a hero,
## [constant SOURCE_FATIGUE], one that left every zone) attributes nothing.
func _record_damage_stats(target_side: String, source: Variant, source_side: String, dealt: int) -> void:
	var target_stats: Dictionary = _state.players[target_side].stats
	target_stats.damage_taken = int(target_stats.damage_taken) + dealt
	if source_side == "":
		return
	var def_id: String = str(_find_record(source).get("def_id", ""))
	if def_id == "":
		return
	var by_card: Dictionary = _state.players[source_side].stats.damage_dealt_by_card
	by_card[def_id] = int(by_card.get(def_id, 0)) + dealt


## Whether damage [param source] has [param keyword] (C12, F2): a character's
## or weapon's keywords (definition plus enchantments — a weapon's count for
## the hero attacking with it, story 013 passes the weapon as the source), a
## card instance's definition keywords. [constant SOURCE_FATIGUE], null and a
## source that left every zone have none.
func _source_has(source: Variant, keyword: String) -> bool:
	if typeof(source) != TYPE_INT:
		return false
	var record: Dictionary = _find_record(source)
	if record.is_empty():
		return false
	if record.has("keywords"):
		return _has_keyword(record, keyword)
	var def: Variant = _db.card(str(record.def_id)) if _db != null else null
	return def is Dictionary and (def as Dictionary).get("keywords", []).has(keyword)


## A fresh card instance of [param def_id] into [param side]'s hand, or the
## graveyard on a full hand; one `card_added_to_hand` or `card_burned`.
## [param returned_from] is the minion `return_to_hand` bounced
## ([constant NO_ENTITY] for `add_card_to_hand`).
func _add_to_hand(side: String, def_id: String, returned_from: int) -> int:
	var player: Dictionary = _state.players[side]
	var card: Dictionary = MatchRecords.card_instance(_take_entity_id(), def_id, "hand")
	var payload: Dictionary = {"side": side, "instance_id": int(card.instance_id), "card_id": def_id}
	if returned_from != NO_ENTITY:
		payload["returned_entity_id"] = returned_from
	if player.hand.size() >= rule("hand_size"):
		card.zone = "graveyard"
		player.graveyard.append(card)
		emit(&"card_burned", payload)
		return int(card.instance_id)
	player.hand.append(card)
	payload["hand_size"] = player.hand.size()
	emit(&"card_added_to_hand", payload)
	return int(card.instance_id)


## Removes [param keyword] from [param record]'s definition set and from every
## enchantment that grants it.
static func _strip_keyword(record: Dictionary, keyword: String) -> void:
	record.keywords.erase(keyword)
	for enchantment: Dictionary in record.enchantments:
		enchantment.keywords_added.erase(keyword)


## Raises trigger point [param point] mid-step (ADR-0007 erratum): the
## triggers the resolver returns join queue Q; the C10 loop runs after the
## step, never here.
func _raise(point: StringName, ctx: Dictionary) -> void:
	var queued: Array[Dictionary] = _resolver.resolve(point, ctx)
	_queue.append_array(queued)


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
