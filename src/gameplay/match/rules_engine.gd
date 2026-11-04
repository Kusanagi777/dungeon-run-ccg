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
## the full [method draw] (burn, fatigue, `on_draw`); story 007 F2 in
## [method apply_damage] and the healing fold; story 008 the C14 end —
## `win_loss_check` at the end of every action, `concede`, [method fault],
## the full `MatchResult` ([method result]), `resolver.unbind()` at `Ended`
## and the idempotent teardown [method end_match]; story 009 the C10 loop —
## [method run_action], the engine-owned trigger queue Q, the DD-M11 death
## check with Deathrattles and `on_minion_died`, `recompute_auras` after every
## step and the `resolution_step_cap` fault — with every command handler, C4
## sub-step and step-boundary hook entry run as its own step; story 010 the
## `play_card` (minions, spells, weapons) and `use_hero_power` handlers in
## C6 / C7 check order, the `legal_commands()` expansion, the F1 base
## [method effective_cost] and the F7 [method spell_damage] total; story 011
## the F1 `modify_cost` fold ([method effective_cost], [method hero_power_cost])
## and temporary crystals ([method add_mana], End step 5); story 016 the
## `Choice` phase — every command handler as plain-data stages, [method
## discover] pausing them, `choose` resuming them (contract on [method discover]).
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
## The per-band knobs (match-rules Tuning Knobs rows with one value per boss
## band): each is a list of whole numbers, band 1 first, exactly one per
## [constant CONFIG_BAND_SAFE_RANGES] row. Kept apart from
## [constant CONFIG_KEYS] because [method rule] answers one `int`.
## `boss_starting_health_by_band` (DD-M02, registry
## `boss_starting_health_by_band`) is the band default a boss's `health` is
## checked against at load (card-database CR-5 stage 8, `W_BAND_HEALTH`); the
## engine itself takes the boss's health from `MatchConfig.boss.health` (C3
## step 2) and never reads it.
const CONFIG_BAND_KEYS: Array[String] = ["boss_starting_health_by_band"]
## The Tuning Knobs "Safe range" column for [constant CONFIG_BAND_KEYS]: per
## key, one inclusive `[min, max]` per band, band 1 first. Validation bounds,
## like [constant CONFIG_SAFE_RANGES]; the integration suite pins them to the
## GDD row.
const CONFIG_BAND_SAFE_RANGES: Dictionary[String, Array] = {
	"boss_starting_health_by_band": [[25, 35], [35, 45], [45, 60]],
}
## The file [method validate_rules_config] reports against (DD-T01 name).
const CONFIG_FILE: String = "match_rules.json"
## Owner code: a [constant CONFIG_KEYS] key is absent from the body.
const E_RULES_MISSING_KNOB: StringName = &"E_RULES_MISSING_KNOB"
## Owner code: a knob is not a whole number (a fraction, string, bool, null…).
const E_RULES_NOT_INTEGER: StringName = &"E_RULES_NOT_INTEGER"
## Owner code: a knob lies outside its [constant CONFIG_SAFE_RANGES] row (or
## a band's entry outside its [constant CONFIG_BAND_SAFE_RANGES] bounds).
const E_RULES_OUT_OF_RANGE: StringName = &"E_RULES_OUT_OF_RANGE"
## Owner code: a [constant CONFIG_BAND_KEYS] knob is not a list with exactly
## one entry per band.
const E_RULES_NOT_BAND_LIST: StringName = &"E_RULES_NOT_BAND_LIST"

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
const R_INVALID_CHOICE: String = "INVALID_CHOICE"
## Emitted once, after `match_ended` reached the log's subscribers and the
## resolver was unbound, with the `MatchResult`. A unit-test convenience only:
## never connected in production (ADR-0008 — `MatchDriver` emits its own).
signal match_ended(result: Dictionary)

## C14 `MatchResult.reason` for the `TURN_CAP` termination guarantee.
const REASON_TURN_CAP: String = MatchRecords.REASON_TURN_CAP
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
## Fatigue damage has **no source** (F5, DD-X14): [method draw] passes `null`
## to [method apply_damage], so a source-filtered `modify_damage` hook never
## matches it while target-side reductions still apply; `damage_dealt.source`
## is `null` and `fatigue_damage` names the cause. Kept as the documented
## value of that `source`.
const SOURCE_FATIGUE: Variant = null
## `enchantment_removed.reason` for [method remove_enchantment] (the End-step
## expiry uses `MatchRecords.EXPIRES_END_OF_TURN`).
const REMOVE_REASON_EFFECT: String = "effect"
## `enchantment_applied.reason` for the enchantment [method set_stats] writes.
const ENCHANT_REASON_SET_STATS: String = "set_stats"
## `summon_failed.reason` on a full board (C10, Edge Cases).
const SUMMON_FAILED_BOARD_FULL: String = "board_full"
## `weapon_destroyed.reason` when [method equip_weapon] replaces a weapon.
const WEAPON_REPLACED: String = "replaced"
## `weapon_destroyed.reason` when the death check breaks a weapon at
## durability ≤ 0 (or marked `pending_destroy`, C10).
const WEAPON_BROKEN: String = "broken"
## The `ctx` key the engine sets to `true` when it executes a queued trigger:
## `resolver.resolve(point, ctx)` with it runs that one effect pass (one C10
## step) instead of collecting responders (story 009; card-effects C6.6).
const CTX_QUEUED: String = "queued"
## `targeting_spec(def_id).mode` values (card-effects C1; ADR-0007 Key
## Interfaces): C6 / C7 validate a `target_id` against them.
const TARGETING_NONE: String = "none"
const TARGETING_OPTIONAL: String = "optional"
const TARGETING_REQUIRED: String = "required"
## The card types `play_card` accepts (card-database CR-3 `type`).
const CARD_MINION: String = "minion"
const CARD_SPELL: String = "spell"
const CARD_WEAPON: String = "weapon"
const R_INVALID_INDEX: String = "INVALID_INDEX"
const R_INVALID_POSITION: String = "INVALID_POSITION"
const R_NOT_ENOUGH_MANA: String = "NOT_ENOUGH_MANA"
const R_BOARD_FULL: String = "BOARD_FULL"
const R_TARGET_REQUIRED: String = "TARGET_REQUIRED"
const R_NO_LEGAL_TARGET: String = "NO_LEGAL_TARGET"
const R_ILLEGAL_TARGET: String = "ILLEGAL_TARGET"
const R_HERO_POWER_USED: String = "HERO_POWER_USED"
## The keyword whose magnitude (`CardDef.spell_damage`) F7 sums.
const KEYWORD_SPELL_DAMAGE: String = "spell_damage"
## `ctx.kind` of a `modify_cost` fold (story 011; card-effects C2 `modify_cost`
## row, Treasures R-13): `card` — `ctx.card` is the hand `CardInstance`;
## `hero_power` — `ctx.card` is the side's `PlayerState.hero_power` record
## `{def_id, used_this_turn}`. A scope `card` filter without `kind` matches the
## first only, `kind: hero_power` the second, `kind: any` both.
const COST_KIND_CARD: String = "card"
const COST_KIND_HERO_POWER: String = "hero_power"
## What an entity-creating primitive returns when it created nothing (C1 ids
## start at `MatchState.FIRST_ENTITY_ID`).
const NO_ENTITY: int = -1
## Stage kinds (story 016): every command handler builds its steps as a list
## of plain-data stages `{stage, side, …}` over one frame, run in order by
## [method _run_stages], so a `Choice` can park the rest of the command on
## `MatchState.suspended_action` and `choose` can run it later. See
## [method discover].
const STAGE_MULLIGAN: String = "mulligan"
const STAGE_TURN_BEGIN: String = "turn_begin"
const STAGE_HOOK: String = "hook"
const STAGE_TURN_POINT: String = "turn_point"
const STAGE_TURN_DRAW: String = "turn_draw"
const STAGE_TURN_MAIN: String = "turn_main"
const STAGE_TURN_ENDING: String = "turn_ending"
const STAGE_TURN_EXPIRE: String = "turn_expire"
const STAGE_TURN_ENDED: String = "turn_ended"
const STAGE_ACCEPT: String = "accept"
const STAGE_EQUIP: String = "equip"
const STAGE_PLAY_POINT: String = "play_point"
const STAGE_PLAY_HOOK: String = "play_hook"
const STAGE_OBSERVERS: String = "observers"
const STAGE_SPELL_DONE: String = "spell_done"
## `STAGE_ACCEPT.type` of the hero power's acceptance step.
const STAGE_TYPE_HERO_POWER: String = "hero_power"
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
## returns the triggers it queues and the engine appends them here): step
## Dictionaries `{point, ctx, cause_seq}` — `ctx` is the resolver's entry
## (`source_id`, `effect_id`, …) carrying the source's raise-time `snapshot`,
## `cause_seq` the event that raised it. Drained by [method _drain].
var _queue: Array[Dictionary] = []
## Steps executed by the current action — one [method submit], one
## [method run_action] or the setup of [method start] — counted across every
## sub-step of it (a play's trigger steps, the C4 Start and End sub-steps) and
## reset only when the next action begins (code review 2026-11-03: a reset per
## sub-step gave one command `cap × sub-steps`).
var _steps: int = 0
## The current command's remaining stages, front first, and the frame they
## share — `{side, instance_id, def_id, target, cause, id}` for a play
## (`cause` the `card_played` / `spell_cast` / `hero_power_used` seq, `id` the
## played entity: the minion, the spell instance, the weapon, the hero), `{}`
## otherwise. Plain data only (story 016): parked as is in `Choice`.
var _stages: Array[Dictionary] = []
var _frame: Dictionary = {}
## The trigger hook points whose entries are running right now (ADR-0005
## rule-4 exception, erratum 2026-11-03): a primitive that reaches the same
## point again inside one of them faults `resolution_overflow` instead of
## recursing (a self-feeding `on_hero_damaged` hook must not overflow the call
## stack). See [method _enter_hook_point].
var _hook_points_running: Dictionary[StringName, bool] = {}
## True while `resolver.recompute_auras()` runs: the aura enchantments it
## re-applies are silent (one `auras_recomputed` lists the net changes).
var _recomputing_auras: bool = false
## The `{source, target}` contexts of the `modify_damage` / `modify_heal`
## folds, reused on every call (ADR-0005: the fold allocates nothing; the
## engine does not build a context per hit either).
var _damage_ctx: Dictionary = {"source": null, "target": 0}
var _heal_ctx: Dictionary = {"source": null, "target": 0}
## The `{card, kind}` context of the `modify_cost` fold, reused on every F1
## evaluation for the same reason (story 011: `effective_cost` runs per hand
## card on every `legal_commands()` call).
var _cost_ctx: Dictionary = {"card": null, "kind": COST_KIND_CARD}
## True from `resolver.bind` in [method start] until `resolver.unbind()`
## (at `Ended`, or [method end_match]) — unbind runs exactly once.
var _bound: bool = false
## True once [method end_match] tore a live (not Ended) match down: every
## later `submit` is `MATCH_ENDED`, unlogged (code review 2026-11-03).
var _torn_down: bool = false


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
## Returns one error per problem, in [constant CONFIG_KEYS] order then
## [constant CONFIG_BAND_KEYS] order, each in the
## `ValidationReport` entry shape `{severity, code, file, record_id, field,
## message}` (`severity` error, `file` [constant CONFIG_FILE], `record_id`
## `null`, `field` the knob key); `[]` when the body is valid:
## - a missing key is [constant E_RULES_MISSING_KNOB];
## - a value that is not a whole number (JSON numbers parse as `float`, so
##   `7.0` passes and `7.5`, `"7"`, `true` fail) is [constant E_RULES_NOT_INTEGER];
## - a whole number outside its [constant CONFIG_SAFE_RANGES] row is
##   [constant E_RULES_OUT_OF_RANGE];
## - a per-band knob that is not an Array with one entry per band is
##   [constant E_RULES_NOT_BAND_LIST]; otherwise each band's entry is checked
##   like a whole-number knob against its own bounds (one error per bad band,
##   band order, the message naming the band).
## [codeblock]
## var errors: Array = RulesEngine.validate_rules_config({"board_size": 9.0}, null)
## errors[0].code   # &"E_RULES_OUT_OF_RANGE" (board_size), then 14 missing knobs
## [/codeblock]
static func validate_rules_config(body: Dictionary, _db: Variant) -> Array:
	var errors: Array[Dictionary] = []
	for key: String in CONFIG_KEYS:
		if not body.has(key):
			errors.append(_config_error(E_RULES_MISSING_KNOB, key, "missing knob `%s` (match-rules Tuning Knobs)" % key))
			continue
		var raw: Variant = body[key]
		if not _is_whole(raw):
			errors.append(_config_error(E_RULES_NOT_INTEGER, key, "`%s` must be a whole number, found %s (%s)" % [key, str(raw), type_string(typeof(raw))]))
			continue
		var value: int = int(raw)
		var bounds: Array = CONFIG_SAFE_RANGES[key]
		if value < int(bounds[0]) or value > int(bounds[1]):
			errors.append(_config_error(E_RULES_OUT_OF_RANGE, key, "`%s` is %d, outside the safe range %d–%d" % [key, value, int(bounds[0]), int(bounds[1])]))
	for key: String in CONFIG_BAND_KEYS:
		errors.append_array(_validate_band_knob(body, key))
	return errors


## The [method validate_rules_config] checks of per-band knob [param key].
static func _validate_band_knob(body: Dictionary, key: String) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	if not body.has(key):
		errors.append(_config_error(E_RULES_MISSING_KNOB, key, "missing knob `%s` (match-rules Tuning Knobs)" % key))
		return errors
	var raw: Variant = body[key]
	var band_bounds: Array = CONFIG_BAND_SAFE_RANGES[key]
	if not raw is Array or (raw as Array).size() != band_bounds.size():
		errors.append(_config_error(E_RULES_NOT_BAND_LIST, key, "`%s` must be a list of %d whole numbers, band 1 first, found %s (%s)" % [key, band_bounds.size(), str(raw), type_string(typeof(raw))]))
		return errors
	for i: int in band_bounds.size():
		var entry: Variant = raw[i]
		var band: int = i + 1
		if not _is_whole(entry):
			errors.append(_config_error(E_RULES_NOT_INTEGER, key, "`%s` band %d must be a whole number, found %s (%s)" % [key, band, str(entry), type_string(typeof(entry))]))
			continue
		var bounds: Array = band_bounds[i]
		if int(entry) < int(bounds[0]) or int(entry) > int(bounds[1]):
			errors.append(_config_error(E_RULES_OUT_OF_RANGE, key, "`%s` band %d is %d, outside the safe range %d–%d" % [key, band, int(entry), int(bounds[0]), int(bounds[1])]))
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
	_steps = 0
	_resolving = true
	# C3 step 1: the registry, then bind (installs entries, registers evaluators)
	_state.hooks = HookRegistry.new()
	# Typed as ADR-0007's `bind(engine, installers: Array[HookInstaller])`: a
	# plain Array into that typed parameter is a SCRIPT ERROR on 4.7.2.
	var installers: Array[HookInstaller] = []
	installers.append_array(config.player.hook_installers)
	installers.append_array(config.boss.hook_installers)
	_resolver.bind(self, installers)
	_bound = true
	_log_skipped_installers(installers)
	# C3 step 2: heroes
	# TODO(card-database story 006): read the hero record's `health` (defaulting
	# to this knob) and its hero power id once `CardDatabase` answers queries.
	_state.players[MatchRecords.SIDE_PLAYER].hero = MatchRecords.hero(_take_entity_id(), MatchRecords.SIDE_PLAYER, rule("starting_health_player"))
	_state.players[MatchRecords.SIDE_BOSS].hero = MatchRecords.hero(_take_entity_id(), MatchRecords.SIDE_BOSS, int(config.boss.health))
	# C3 step 3: decks, player first
	_build_deck(MatchRecords.SIDE_PLAYER, config.player.deck)
	_build_deck(MatchRecords.SIDE_BOSS, config.boss.deck)
	# C3 step 4: on_match_start, before any card is drawn — each entry a step
	for side: String in MatchRecords.SIDES:
		_run_hook_steps(&"on_match_start", side, {})
	# C3 step 5: starting hands, fold then clamp once
	_draw(MatchRecords.SIDE_PLAYER, _starting_hand_size(MatchRecords.SIDE_PLAYER, rule("starting_hand_player")), false)
	_draw(MatchRecords.SIDE_BOSS, _starting_hand_size(MatchRecords.SIDE_BOSS, rule("starting_hand_boss")), false)
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
## failing reason wins. Synchronous: no `await`. Every accepted action ends
## with its C10 loop and `win_loss_check` (C14); `concede` (PLAYER, any phase
## but Ended) ends the match for the boss, and once `Ended` every command is
## `MATCH_ENDED`.
## [codeblock]
## var r: Dictionary = engine.submit(MatchRecords.mulligan([true, false, false]))
## if not r.accepted: show(r.rejection.code)
## [/codeblock]
func submit(command: Dictionary) -> Dictionary:
	if _torn_down:
		return MatchRecords.command_result(false, R_MATCH_ENDED, "torn down by end_match", 0, 0)
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
	_steps = 0
	_call_first_seq = 0
	_call_last_seq = 0
	_stages.clear()
	_frame = {}
	match type:
		MatchRecords.CMD_MULLIGAN:
			_do_mulligan(command.keep_mask)
		MatchRecords.CMD_PLAY_CARD:
			_do_play_card(command)
		MatchRecords.CMD_ATTACK:
			_do_attack(command)
		MatchRecords.CMD_USE_HERO_POWER:
			_do_hero_power(command)
		MatchRecords.CMD_END_TURN:
			_stages.append_array(_end_stages(_state.active_side))
		MatchRecords.CMD_CHOOSE:
			_do_choose(int(command.option_index))
		MatchRecords.CMD_CONCEDE:
			_abandon_choice()
			_end_match(MatchRecords.SIDE_BOSS, MatchRecords.REASON_CONCEDE)
	_run_stages()
	# The end of every action: its C10 loop drained (the stages run their
	# steps through _run_step, so this is normally already stable), then C14 —
	# unless a Discover paused it: then the rest waits on MatchState (Choice).
	if _suspended():
		_park()
	elif not _halted():
		_drain()
		@warning_ignore("return_value_discarded")
		_win_loss_check()
	if _halted():
		_abandon_stages()
	_resolving = false
	return MatchRecords.command_result(true, "", "", _call_first_seq, _call_last_seq)


## Runs one action through the C10 loop (story 009; GDD C10 `run_action`):
## [param initial_step] (a Callable with no arguments — mutations through
## primitives) is executed as step 1, then the loop drains: death check →
## `recompute_auras()` → pop queue Q → execute, until no one died and Q is
## empty; a step past `resolution_step_cap` is `fault(resolution_overflow)`.
## Then `win_loss_check()` (C14). The step counter starts at 0 per action —
## per `run_action` and per [method submit], never per sub-step.
## Every command handler and engine step runs this way internally; this
## public entry drives an engine-initiated fixture step (tests, the card-
## effects suites). Called while the engine is resolving it does nothing and
## reports an error: triggers queue, never nest.
## [codeblock]
## engine.run_action(func() -> void: engine.apply_damage(target_id, 1, null))
## [/codeblock]
func run_action(initial_step: Callable) -> void:
	if _resolving:
		push_error("RulesEngine.run_action: called while resolving — triggers queue, never nest (C10)")
		return
	if _halted() or _torn_down:
		return
	_resolving = true
	_cause_seq = 0
	_steps = 0
	_stages.clear()
	_frame = {}
	_run_step(initial_step)
	if _suspended():
		_park()
	else:
		@warning_ignore("return_value_discarded")
		_win_loss_check()
	_resolving = false


## Every command the engine would accept now (C2): in Mulligan the "keep
## all" mulligan; in Main, for the active side, each playable hand card (hand
## order) × each valid position (minions, `0..board.size`) × each legal target
## — a `required` card lists one command per legal target (a spell or power
## with none is absent; a minion or weapon whose Battlecry has none is listed
## with `target_id = null`), `optional` lists `null` then each legal target,
## `none` lists `null` — then each attacker × each defender F3 accepts
## (story 012, [method can_attack]), then the hero power the same way as a
## card, then `end_turn` (`concede` is not listed, C2). `[]` in any other
## phase. Legality is derived from the same checks [method submit] runs,
## never by trial-submitting; `targeting_spec` is the resolver's memo.
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
			var side: String = _state.active_side
			var player: Dictionary = _state.players[side]
			for index: int in player.hand.size():
				_append_play_commands(legal, side, index)
			_append_attack_commands(legal, side)
			if not player.hero_power.used_this_turn and hero_power_cost(side) <= int(player.mana_current):
				var power_id: String = str(player.hero_power.def_id)
				for target: Variant in _listed_targets(power_id, _power_source(side), true):
					legal.append(MatchRecords.use_hero_power(side, target))
			legal.append(MatchRecords.end_turn(side))
		MatchState.PHASE_CHOICE:
			# States `Choice` (story 016): one `choose` per option for the side
			# the request names, then the player's `concede`.
			var choice: Dictionary = _state.pending_choice
			for index: int in (choice.options as Array).size():
				legal.append(MatchRecords.choose(str(choice.side), index))
			legal.append(MatchRecords.concede(MatchRecords.SIDE_PLAYER))
	return legal


## C5 / F1 (stories 010, 011): the effective cost of the hand card
## [param card] (a CardInstance) held by [param side], used for display
## (`legal_commands`) and for payment alike. A fixed-order sum, floored once:
## 1. the definition's printed `cost`;
## 2. `+ Σ cost_modifiers[].cost_delta` — the card's own enchantments **and**
##    the hand-scoped aura deltas: `recompute_auras` writes those into
##    `cost_modifiers` tagged `is_aura`, so this one sum counts each exactly
##    once (there is no separate aura pass);
## 3. the `modify_cost` hook fold over the result, entries in installation
##    order, `ctx {card, kind: COST_KIND_CARD}` (ADR-0005 Decision 4);
## 4. `maxi(0, …)` — the one clamp, after the whole chain, never inside it.
## Pure and allocation-free: the fold context is the reused `_cost_ctx`.
## [param side] "" reads the card's holder from the state.
## [codeblock]
## if engine.effective_cost(card, "player") <= mana: highlight(card)
## [/codeblock]
func effective_cost(card: Dictionary, side: String = "") -> int:
	var total: int = int(_lookup_def(str(card.def_id)).get("cost", 0))
	for modifier: Dictionary in card.cost_modifiers:
		total += int(modifier.get("cost_delta", 0))
	var holder: String = side if side != "" else _owner_of(int(card.instance_id))
	return _fold_cost(holder, total, card, COST_KIND_CARD)


## C5 / C7 (story 011): [param side]'s hero power cost — `hero_power_cost`
## (`rules_config`) through the same F1 pipeline: the `modify_cost` fold with
## `ctx {card: players[side].hero_power, kind: COST_KIND_HERO_POWER}`, then
## the one clamp at 0. A power at 0 is still once per turn (C7).
## [codeblock]
## var cost: int = engine.hero_power_cost("player")   # 2, or 0 with a "set 0" treasure
## [/codeblock]
func hero_power_cost(side: String) -> int:
	return _fold_cost(side, rule("hero_power_cost"), _state.players[side].hero_power, COST_KIND_HERO_POWER)


## F1 steps 3–4: `maxi(0, hooks.fold(&"modify_cost", side, cost_so_far,
## {card, kind}))`. A state without a registry (a bare fixture) folds nothing.
func _fold_cost(side: String, cost_so_far: int, card: Dictionary, kind: String) -> int:
	var folded: int = cost_so_far
	if _state.hooks != null:
		_cost_ctx.card = card
		_cost_ctx.kind = kind
		folded = _state.hooks.fold(&"modify_cost", StringName(side), cost_so_far, _cost_ctx)
		_cost_ctx.card = null
	return maxi(0, folded)


## F7: [param side]'s Spell Damage total — `Σ CardDef.spell_damage` over its
## board minions that hold the `spell_damage` keyword (a Silenced minion has
## lost it). Card Effects adds it to spell damage ops; the engine reports it
## in `spell_cast`.
## [codeblock]
## var bonus: int = engine.spell_damage("player")
## [/codeblock]
func spell_damage(side: String) -> int:
	var total: int = 0
	for minion: Dictionary in _state.players[side].board:
		if _has_keyword(minion, KEYWORD_SPELL_DAMAGE):
			total += int(_lookup_def(str(minion.def_id)).get("spell_damage", 0))
	return total


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


## A value copy of the `MatchResult` once `Ended`, else null (C14): `{result:
## win | loss | fault (from the player's side), winner, reason, floor, turns,
## turns_per_side, stats{player, boss}, final_health{player, boss}}` — no
## seed (DD-R09).
func result() -> Variant:
	var outcome: Variant = _state.result
	return outcome.duplicate(true) if outcome is Dictionary else outcome


## Appends one event to the match log with the engine's current `cause_seq`
## and returns its `seq` (ADR-0007 Decision 6). Every engine mutation emits
## through here, and so does the resolver (`effect_resolved`,
## `counter_changed`, …), so `log.append` call sites stay inside the engine.
## A refused append (`-1`) on a match that has not ended is the log's
## overflow (ADR-0003 Decision 8: the log has appended `log_overflow` and
## accepts exactly one more event): the engine answers with
## `fault(event_cap)`, whose `match_ended` is that event, and stops — every
## primitive and step is a no-op from then on. Once `Ended`, emit appends
## nothing (returns `-1`): the log is sealed.
## [codeblock]
## var seq: int = engine.emit(&"counter_changed", {"source_id": 7, "key": "seen", "value": 2})
## [/codeblock]
func emit(type: StringName, payload: Dictionary) -> int:
	# Once Ended the only event left is the match's own match_ended; anything
	# else would be an append to a sealed log (a caller bug, ADR-0003).
	if _halted() and type != &"match_ended":
		return -1
	# TODO(rng-event-log story 005): type the log as `EventLog`.
	var log: Variant = _state.log
	var seq: int = log.append(type, payload, _cause_seq)
	if seq > 0:
		if _call_first_seq == 0:
			_call_first_seq = seq
		_call_last_seq = seq
	elif not _halted():
		fault(MatchRecords.REASON_EVENT_CAP)
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
## Fatigue damage has no source (DD-X14). Starting-hand and mulligan draws
## (C3 steps 5 and 7) fire neither the `on_draw` hooks nor the `on_draw`
## trigger point (DD-X13): `on_draw` is for draws during play only.
## [codeblock]
## engine.draw("player", 2)
## [/codeblock]
func draw(side: String, n: int) -> void:
	_draw(side, n, true)


## [method draw] with [param fire_on_draw] false for the setup and mulligan
## draws (DD-X13).
func _draw(side: String, n: int, fire_on_draw: bool) -> void:
	var player: Dictionary = _state.players[side]
	for _i: int in n:
		if _halted():
			return
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
		var drawn_seq: int = emit(&"card_drawn", {"side": side, "instance_id": instance_id, "card_id": def_id, "hand_size": player.hand.size()})
		if _halted():
			return
		if not fire_on_draw:
			continue
		_run_inline_hooks(&"on_draw", side, {"instance_id": instance_id, "card_id": def_id})
		_raise(&"on_draw", {"side": side, "candidates": _candidates_in_order(), "subject": instance_id, "card_id": def_id}, drawn_seq)


## Primitive (C5, match-rules Interactions): [param side] gains [param n]
## crystals. Permanent (`temporary = false`, an `on_match_start` hook such as
## Hollow Crown): raises `crystal_bonus`, which every later Start step reads
## (F4) — mana itself moves at the next Start step — and emits
## `mana_added {side, n, temporary: false}`.
## Temporary (`temporary = true`, the card-effects `mana` op with `duration:
## this_turn`; story 011): `n` crystals until [param side]'s End step —
## `temp = min(n, max_mana − mana_max)`, `mana_max += temp`, `mana_current =
## min(mana_current + n, max_mana)`, `temporary_crystals += temp`, then
## `mana_added {side, n, temporary: true}`. `crystal_bonus` is untouched, so
## the next Start-step refill (F4) ignores them; the End step takes them back
## ([method _expire_end_of_turn]). `mana_current ≤ mana_max` holds throughout.
## [codeblock]
## engine.add_mana("player", 1, false)   # 2/2 on the player's first turn
## engine.add_mana("player", 2, true)    # 1/3 → 3/5 this turn only
## [/codeblock]
func add_mana(side: String, n: int, temporary: bool = false) -> void:
	if _halted():
		return
	var player: Dictionary = _state.players[side]
	if temporary:
		var cap: int = rule("max_mana")
		var gained: int = mini(n, cap - int(player.mana_max))
		player.mana_max = int(player.mana_max) + gained
		player.mana_current = mini(int(player.mana_current) + n, cap)
		player.temporary_crystals = int(player.temporary_crystals) + gained
		emit(&"mana_added", {"side": side, "n": n, "temporary": true})
		return
	player.crystal_bonus = int(player.crystal_bonus) + n
	emit(&"mana_added", {"side": side, "n": n, "temporary": false})


## Primitive (F2, C9): [param requested] damage to the character
## [param target_id] from [param source] — an entity id (a minion, a hero, the
## weapon a hero attacks with — its keywords then count for the attack — or a
## card instance) or `null` (fatigue, DD-X14) — evaluated in one step:
## 1. `amount = maxi(0, hooks.fold(&"modify_damage", source_side, requested,
##    {source, target}))` — the engine's one clamp, after the whole fold
##    (ADR-0005 rule 4). `source_side` is the source's side; a null source
##    (fatigue) folds with the target's side.
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
	if _halted():
		return 0
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
		if _halted():
			return 0
	var armor_absorbed: int = 0
	if target.kind == MatchRecords.KIND_HERO:
		armor_absorbed = mini(int(target.armor), amount)
		if armor_absorbed > 0:
			target.armor = int(target.armor) - armor_absorbed
			emit(&"armor_lost", {"side": target_side, "entity_id": target_id, "amount": armor_absorbed, "armor": int(target.armor)})
			if _halted():
				return 0
	var to_health: int = amount - armor_absorbed
	target.damage_taken = int(target.damage_taken) + to_health
	var dealt: int = armor_absorbed + to_health
	var dealt_seq: int = emit(&"damage_dealt", {
		"source": source, "target": target_id, "requested": requested, "prevented": prevented,
		"armor_absorbed": armor_absorbed, "dealt": dealt, "health_after": health(target),
	})
	if dealt > 0 and not _halted():
		_after_damage_dealt(target, source, source_side, dealt, dealt_seq)
	return dealt


## F2 step 5, once `dealt > 0`: stats, Poisonous, Lifesteal, the
## `on_hero_damaged` hooks and trigger point `on_damage` (in that order) —
## its triggers queue with `cause_seq` [param dealt_seq], the `damage_dealt`.
func _after_damage_dealt(target: Dictionary, source: Variant, source_side: String, dealt: int, dealt_seq: int) -> void:
	var target_id: int = int(target.entity_id)
	var target_side: String = str(target.controller)
	_record_damage_stats(target_side, source, source_side, dealt)
	if target.kind == MatchRecords.KIND_MINION and _source_has(source, MatchRecords.KEYWORD_POISONOUS):
		target["pending_destroy"] = true
	if source_side != "" and _source_has(source, MatchRecords.KEYWORD_LIFESTEAL):
		@warning_ignore("return_value_discarded")
		apply_heal(int(_state.players[source_side].hero.entity_id), dealt, source)
	if target.kind == MatchRecords.KIND_HERO:
		_run_inline_hooks(&"on_hero_damaged", target_side, {"amount_dealt": dealt, "source": source})
	_raise(&"on_damage", {"side": target_side, "candidates": _candidates_in_order(), "subject": target_id, "amount": dealt, "source": source}, dealt_seq)


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
	if _halted():
		return 0
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
	var healed_seq: int = emit(&"healed", {"source": source, "target": target_id, "requested": amount, "amount": restored})
	_raise(&"on_heal", {"side": target_side, "candidates": _candidates_in_order(), "subject": target_id, "amount": restored, "source": source}, healed_seq)
	return restored


## Primitive (C9): [param side]'s hero gains [param amount] armour, uncapped;
## emits `armor_gained {side, entity_id, amount, armor}`.
## [codeblock]
## engine.apply_armor("player", 4)
## [/codeblock]
func apply_armor(side: String, amount: int) -> void:
	if _halted():
		return
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
	if _halted():
		return
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
	# An aura re-applied by the C10 recompute is silent: the pass's one
	# `auras_recomputed` lists the net changes (C10, DSL spike finding 8).
	if applied.is_aura and _recomputing_auras:
		return
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
	if _halted():
		return
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
## health}`, then runs the `on_minion_summoned` hooks, then raises trigger
## point `on_summon {subject, card_id}` (its observers join Q under
## `minion_summoned`) — card-effects C6.3 "Minion summoned by an effect": no
## `battlecry`, no `on_play` (a minion played from hand is placed by the
## `play_card` handler, which runs its own C6.3 steps). A full board is a
## no-op with `summon_failed {side, card_id, reason: board_full}`. Returns the
## new entity id, or [constant NO_ENTITY].
## [codeblock]
## var id: int = engine.summon_minion("boss", "boss_imp", -1)
## [/codeblock]
func summon_minion(side: String, def_id: String, position: int) -> int:
	if _halted():
		return NO_ENTITY
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
	var id: int = int(minion.entity_id)
	var summoned_seq: int = emit(&"minion_summoned", {
		"side": side, "entity_id": id, "card_id": def_id, "position": index,
		"attack": attack(minion), "health": health(minion),
	})
	_run_inline_hooks(&"on_minion_summoned", side, {"entity_id": id, "card_id": def_id})
	_raise(&"on_summon", {"side": side, "candidates": _candidates_in_order(), "subject": id, "card_id": def_id}, summoned_seq)
	return id


## Primitive (C10, States "pending_destroy"): marks the minion or weapon
## [param target_id] `pending_destroy`; it leaves play in the next death check
## (C10, after the current step), whose `minion_died` / `weapon_destroyed` is
## the event — C15 has no event for the mark itself.
## [codeblock]
## engine.destroy(minion_id)
## [/codeblock]
func destroy(target_id: int) -> void:
	if _halted():
		return
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
	if _halted():
		return
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
	if _halted():
		return
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
	if _halted():
		return
	var record: Dictionary = _character(target_id)
	if record.is_empty():
		record = _weapon(target_id)
	if record.is_empty() or _has_keyword(record, keyword):
		return
	apply_enchantment(target_id, {"keywords_added": [keyword]})


## Primitive (card-effects `return_to_hand`, C15 `minion_returned`): the
## minion [param target_id] leaves the board (no death, no Deathrattle) and
## its controller gets a fresh card instance of its `def_id` in hand — or, on
## a full hand, in the graveyard. One event either way: `minion_returned
## {side, entity_id, card_id, instance_id, burned}` (`burned: true` on a full
## hand; never `card_added_to_hand` or `card_burned`, so add-to-hand
## observers do not fire on a bounce). Returns the new instance id, or
## [constant NO_ENTITY].
## [codeblock]
## var card_id: int = engine.return_to_hand(minion_id)
## [/codeblock]
func return_to_hand(target_id: int) -> int:
	if _halted():
		return NO_ENTITY
	var minion: Dictionary = _minion(target_id)
	if minion.is_empty():
		return NO_ENTITY
	var side: String = str(minion.controller)
	var player: Dictionary = _state.players[side]
	var board: Array = player.board
	board.remove_at(board.find(minion))
	var def_id: String = str(minion.def_id)
	var card: Dictionary = MatchRecords.card_instance(_take_entity_id(), def_id, "hand")
	var burned: bool = player.hand.size() >= rule("hand_size")
	if burned:
		card.zone = "graveyard"
		player.graveyard.append(card)
	else:
		player.hand.append(card)
	emit(&"minion_returned", {
		"side": side, "entity_id": target_id, "card_id": def_id,
		"instance_id": int(card.instance_id), "burned": burned,
	})
	return int(card.instance_id)


## Primitive (card-effects `transform`): replaces the minion [param target_id]
## in its board slot with a new minion of [param def_id] with a **new**
## `entity_id`, base stats and keywords from the definition and no
## enchantments or damage. Summoning sickness, `summoned_on_turn` and
## `attacks_used` carry over (no sickness reset). Emits `minion_transformed
## {side, entity_id, from_card_id, to_card_id}` (the C15 row; `entity_id` is
## the new minion's) plus `old_entity_id` and `position`, so the log ties the
## two ids together. Returns the new id, or [constant NO_ENTITY].
## [codeblock]
## var sheep_id: int = engine.transform(target_id, "neutral_sheep")
## [/codeblock]
func transform(target_id: int, def_id: String) -> int:
	if _halted():
		return NO_ENTITY
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
		"side": side, "entity_id": int(minion.entity_id), "from_card_id": str(old.def_id),
		"to_card_id": def_id, "old_entity_id": target_id, "position": index,
	})
	return int(minion.entity_id)


## Primitive (C6 weapons): [param side] equips [param def_id] (a weapon
## definition). A held weapon is destroyed first — `weapon_destroyed {side,
## entity_id, card_id, reason: replaced}` and its Deathrattle queued (it
## resolves after the current step, C10) — then `weapon_equipped {side,
## entity_id, card_id, attack, durability}`. Returns the new weapon's id, or
## [constant NO_ENTITY].
## [codeblock]
## var axe_id: int = engine.equip_weapon("player", "war_iron_axe")
## [/codeblock]
func equip_weapon(side: String, def_id: String) -> int:
	if _halted():
		return NO_ENTITY
	var def: Dictionary = _card_def(def_id)
	if def.is_empty():
		return NO_ENTITY
	var player: Dictionary = _state.players[side]
	if player.weapon != null:
		_weapon_leaves(side, WEAPON_REPLACED)
		if _halted():
			return NO_ENTITY
	var weapon: Dictionary = MatchRecords.weapon(_take_entity_id(), def_id, int(def.get("attack", 0)), int(def.get("durability", 0)), def.get("keywords", []))
	player.weapon = weapon
	emit(&"weapon_equipped", {
		"side": side, "entity_id": int(weapon.entity_id), "card_id": def_id,
		"attack": int(weapon.attack), "durability": int(weapon.durability),
	})
	return int(weapon.entity_id)


## Primitive (C2 `Choice`, Discover): creates the `ChoiceRequest {side, kind,
## options, source_id, effect_id}` ([method MatchRecords.choice_request]),
## stores it as `pending_choice`, records the paused step
## (`suspended_action {origin_phase, cause_seq}` — the phase it was raised in
## and the `cause_seq` its primitives ran under), enters `Choice`
## (`phase_changed {phase: choice}`), emits `choice_requested` with the request
## (DD-X04: not Card Effects' `discover_offered`) and returns it (story 016).
## A second request while one is pending is a resolver defect (card-effects
## C8: exactly one outstanding): logged, nothing changes, `{}` returned.
##
## **The pause** (ADR-0007 Decision 1; the contract card-effects story 010's
## pass suspension builds on). After this call the resolver must **return
## from its pass without running the effect's later ops**, keeping them as
## its own continuation in `state().effects.pending_choice` (plain data: no
## Callable, Node or object — `clone()` copies it by value). The engine then:
## - runs no death check, `recompute_auras` or queue pop after that pass —
##   the pass is one C10 step and is not finished;
## - skips every later step of the command: the rest of its stages (the
##   play's hooks and observers, `after_cast`, the spell's move out of
##   `resolving`, the Start step's draw…) and the C14 check;
## - parks, as plain data on `MatchState`: Q (`suspended_queue`), the step
##   count (`suspended_steps`), and the stages and their frame
##   (`suspended_action.stages` / `.frame`); `submit` returns accepted.
## On `choose{option_index}` (validated: `NOT_YOUR_TURN`, `INVALID_CHOICE`)
## the engine emits `choice_made {side, option_index}`, clears
## `pending_choice`, restores the origin phase, Q and the step count, and calls
## `resolver.resume(choice, option_index)` **under the paused step's
## `cause_seq`**: the resolver adds the pick (`add_card_to_hand`) and runs the
## rest of that same pass. Then that step's C10 loop drains the restored Q, the
## parked stages run in order — each exactly once — and C14 closes the action.
## `resume` may raise the next request (a second Discover in the same effect):
## the engine pauses again the same way. `concede` in `Choice` abandons it.
## [codeblock]
## var req: Dictionary = engine.discover("player", ["a_01", "b_02", "c_03"], MatchRecords.CHOICE_DISCOVER, source_id, "scout.0")
## engine.state().effects.pending_choice = {"effect_id": "scout.0", "next_op": 1}   # the resolver's own data
## [/codeblock]
func discover(side: String, options: Array, kind: String = MatchRecords.CHOICE_DISCOVER, source_id: Variant = null, effect_id: String = "") -> Dictionary:
	if _halted():
		return {}
	if _state.pending_choice != null:
		push_error("RulesEngine.discover: a ChoiceRequest is already pending (card-effects C8: exactly one outstanding)")
		return {}
	var request: Dictionary = MatchRecords.choice_request(side, kind, options.duplicate(true), source_id, effect_id)
	_state.pending_choice = request
	_state.suspended_action = {"origin_phase": _state.phase, "cause_seq": _cause_seq, "frame": {}, "stages": []}
	_set_phase(MatchState.PHASE_CHOICE)
	emit(&"choice_requested", request.duplicate(true))
	return request.duplicate(true)


## Primitive (C15 `card_added_to_hand`): a fresh card instance of
## [param def_id] for [param side]'s hand — `card_added_to_hand {side,
## instance_id, card_id, hand_size}`, or on a full hand `card_burned {side,
## instance_id, card_id}` with the card in the graveyard. No `on_draw`.
## Returns the new instance id.
## [codeblock]
## engine.add_card_to_hand("player", "neutral_coin")
## [/codeblock]
func add_card_to_hand(side: String, def_id: String) -> int:
	if _halted():
		return NO_ENTITY
	return _add_to_hand(side, def_id)


## Primitive (C9 "Set/raise health"): sets the minion [param target_id]'s
## attack and/or health (null leaves that stat alone) through one
## enchantment whose deltas reach the new values — `base_*` are never
## written. Setting health clears `damage_taken`, so `health == max_health ==
## health`. Emits `enchantment_applied` with `reason: set_stats`.
## [codeblock]
## engine.set_stats(minion_id, 4, 1)
## [/codeblock]
func set_stats(target_id: int, new_attack: Variant = null, new_health: Variant = null) -> void:
	if _halted():
		return
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
	if _halted():
		return
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
	if _halted():
		return NO_ENTITY
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
## at ≤ 0 breaks in the next death check (C10).
## [codeblock]
## engine.modify_durability(axe_id, -1)
## [/codeblock]
func modify_durability(weapon_id: int, delta: int) -> void:
	if _halted():
		return
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
	if _halted():
		return
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
	if _halted():
		return NO_ENTITY
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


## C1 / F3: `max_attacks = clampi(hooks.fold(&"modify_max_attacks",
## controller, n, {who}), 0, MAX_ATTACKS_CAP)` with `n = MAX_ATTACKS_WINDFURY
## if has_windfury else 1` — the one clamp, after the whole fold (ADR-0005
## rule 4); `who` is the character's entity id. Derived live on every call, so
## gaining or losing Windfury mid-turn changes it at once. Without a loaded
## state or registry the fold is skipped.
func max_attacks(character: Dictionary) -> int:
	var n: int = rule("max_attacks_windfury") if has_windfury(character) else ATTACKS_PER_TURN
	if _state != null and _state.hooks != null:
		_max_attacks_ctx.who = int(character.entity_id)
		n = _state.hooks.fold(&"modify_max_attacks", StringName(str(character.controller)), n, _max_attacks_ctx)
	return clampi(n, 0, rule("max_attacks_cap"))


## C1: `attacks_remaining = max_attacks − attacks_used`.
func attacks_remaining(character: Dictionary) -> int:
	return max_attacks(character) - int(character.attacks_used)


# --- C8 / F3: attacking (stories 012–014) -------------------------------------

## The F3 rejection codes of the C2 closed set (story 012).
const R_TARGET_STEALTHED: String = "TARGET_STEALTHED"
const R_MUST_ATTACK_TAUNT: String = "MUST_ATTACK_TAUNT"
const R_CANNOT_ATTACK: String = "CANNOT_ATTACK"
const R_ATTACKER_FROZEN: String = "ATTACKER_FROZEN"
const R_SUMMONING_SICK: String = "SUMMONING_SICK"
const R_RUSH_CANNOT_HIT_HERO: String = "RUSH_CANNOT_HIT_HERO"

## The `{who}` context of the `modify_max_attacks` fold (ADR-0005), reused on
## every evaluation — the fold allocates nothing, and neither does the
## engine per call. `who` is the character's entity id.
var _max_attacks_ctx: Dictionary = {"who": 0}


## F3 `can_attack(A, D)` for the character [param attacker_id] attacking
## [param target_id]: `{ok: bool, code: String}` — `code` is "" when ok, else
## the rejection of the first false term, left to right:
## `phase == Main(A.controller)` (`WRONG_PHASE` / `NOT_YOUR_TURN`) →
## `attack(A) > 0 ∧ attacks_remaining(A) > 0` (`CANNOT_ATTACK`; an attacker
## that is no character in play cannot attack either) → `¬A.frozen`
## (`ATTACKER_FROZEN`) → `A is hero ∨ ¬A.summoning_sick ∨ charge(A) ∨ (rush(A)
## ∧ D is minion)` (`RUSH_CANNOT_HIT_HERO` when A has Rush and D is a hero, else
## `SUMMONING_SICK`) → `D.controller ≠ A.controller ∧ D in play`
## (`ILLEGAL_TARGET`) → `¬(D is minion ∧ stealth(D))` (`TARGET_STEALTHED`) →
## `taunters(D.controller) = ∅ ∨ D ∈ taunters` (`MUST_ATTACK_TAUNT`), where
## `taunters(side) = {m ∈ board : taunt(m) ∧ ¬stealth(m)}`. Keywords are read
## live — definition plus enchantment `keywords_added` — so `add_keyword` /
## `remove_keyword` take effect at the next call.
## [codeblock]
## var check: Dictionary = engine.can_attack(minion_id, boss_hero_id)
## if not check.ok: show(check.code)
## [/codeblock]
func can_attack(attacker_id: Variant, target_id: Variant) -> Dictionary:
	var attacker: Dictionary = _character(int(attacker_id)) if _is_whole(attacker_id) else {}
	var target: Dictionary = _character(int(target_id)) if _is_whole(target_id) else {}
	var taunters: Array[int] = []
	if not target.is_empty():
		taunters = _taunters(str(target.controller))
	var code: String = _attack_rejection(attacker, target, taunters)
	return {"ok": code == "", "code": code}


## The F3 conjunction over records ([param attacker] / [param target] `{}`
## when not in play), with [param taunters] of the target's side computed
## once by the caller ([method legal_commands] evaluates every pair).
func _attack_rejection(attacker: Dictionary, target: Dictionary, taunters: Array[int]) -> String:
	if _state.phase != MatchState.PHASE_MAIN:
		return R_WRONG_PHASE
	if attacker.is_empty():
		return R_CANNOT_ATTACK
	if str(attacker.controller) != str(_state.active_side):
		return R_NOT_YOUR_TURN
	if attack(attacker) <= 0 or attacks_remaining(attacker) <= 0:
		return R_CANNOT_ATTACK
	if bool(attacker.frozen):
		return R_ATTACKER_FROZEN
	var target_kind: String = str(target.get("kind", ""))
	if attacker.kind == MatchRecords.KIND_MINION and bool(attacker.summoning_sick) and not _has_keyword(attacker, MatchRecords.KEYWORD_CHARGE):
		var rush: bool = _has_keyword(attacker, MatchRecords.KEYWORD_RUSH)
		if not (rush and target_kind == MatchRecords.KIND_MINION):
			return R_RUSH_CANNOT_HIT_HERO if rush and target_kind == MatchRecords.KIND_HERO else R_SUMMONING_SICK
	if target.is_empty() or str(target.controller) == str(attacker.controller):
		return R_ILLEGAL_TARGET
	if target_kind == MatchRecords.KIND_MINION and _has_keyword(target, MatchRecords.KEYWORD_STEALTH):
		return R_TARGET_STEALTHED
	if not taunters.is_empty() and not taunters.has(int(target.entity_id)):
		return R_MUST_ATTACK_TAUNT
	return ""


## F3 `taunters(side)`: the entity ids of [param side]'s board minions with
## Taunt and without Stealth, in board order.
func _taunters(side: String) -> Array[int]:
	var ids: Array[int] = []
	for minion: Dictionary in _state.players[side].board:
		if _has_keyword(minion, MatchRecords.KEYWORD_TAUNT) and not _has_keyword(minion, MatchRecords.KEYWORD_STEALTH):
			ids.append(int(minion.entity_id))
	return ids


## C2 `attack` validation after the phase guard: F3 on the command's
## `attacker_id` / `target_id`.
func _validate_attack(command: Dictionary) -> String:
	return str(can_attack(command.get("attacker_id"), command.get("target_id")).code)


## C2 `legal_commands()` attack expansion: for each of [param side]'s
## characters with `attacks_remaining > 0` (hero, then board left to right),
## each enemy character (hero, then board) for which F3 holds. `taunters` is
## computed once per call, not per pair.
func _append_attack_commands(legal: Array, side: String) -> void:
	var enemy: String = MatchRecords.SIDE_BOSS if side == MatchRecords.SIDE_PLAYER else MatchRecords.SIDE_PLAYER
	var taunters: Array[int] = _taunters(enemy)
	var defenders: Array[Dictionary] = _characters_of(enemy)
	for attacker: Dictionary in _characters_of(side):
		if attacks_remaining(attacker) <= 0:
			continue
		for defender: Dictionary in defenders:
			if _attack_rejection(attacker, defender, taunters) == "":
				legal.append(MatchRecords.attack(side, int(attacker.entity_id), int(defender.entity_id)))


## The attack's stage kinds (story 016's staged model, sprint 4 lane 1
## merge): C8 steps 1, 2, 3–6 and 7, run by [method _attack_stage] over the
## frame `{side, attacker, defender, cause}` (`cause` the `attack_declared`
## seq), so a Discover raised by an `on_attack` trigger parks the rest of the
## attack and `choose` runs it.
const STAGE_ATTACK_DECLARE: String = "attack_declare"
const STAGE_ATTACK_POINT: String = "attack_point"
const STAGE_ATTACK_DAMAGE: String = "attack_damage"
const STAGE_ATTACK_RESOLVED: String = "attack_resolved"


## An accepted `attack` (C8 resolution, story 013) as four stages over one
## frame, each numbered step its own engine step with its C10 loop:
## 1. `attack_declared {attacker, defender}`; a Stealth attacker loses it
##    (`stealth_lost`).
## 2. Trigger point `on_attack {side, candidates, attacker, defender, source:
##    attacker, subject: defender}` under `attack_declared`; each response is
##    a queued step with the full loop.
## 3. Re-check: A or D no longer in play (died, bounced, transformed) →
##    `attack_cancelled {attacker, defender}`, A's `attacks_used += 1` when A
##    is still there; legality is **not** re-evaluated (a Taunt gained or lost
##    in step 2 changes nothing).
## 4.–5. [method _attack_damage_step]: both hits in one step, then
##    `attacks_used += 1`.
## 6. The C10 loop of that step (`on_damage` triggers, deaths, auras; a
##    weapon at durability ≤ 0 breaks there).
## 7. `attack_resolved {attacker, defender}`; [method submit] then runs
##    `win_loss_check()`.
## A Discover raised in step 2 parks steps 3–7 (see [method discover]).
func _do_attack(command: Dictionary) -> void:
	var attacker_id: int = int(command.attacker_id)
	var side: String = str(_character(attacker_id).controller)
	_frame = {"side": side, "attacker": attacker_id, "defender": int(command.target_id), "cause": 0}
	for kind: String in [STAGE_ATTACK_DECLARE, STAGE_ATTACK_POINT, STAGE_ATTACK_DAMAGE, STAGE_ATTACK_RESOLVED]:
		_stage({"stage": kind, "side": side})


## Executes one attack stage of [method _do_attack] over [member _frame].
func _attack_stage(stage: Dictionary) -> void:
	var attacker_id: int = int(_frame.attacker)
	var defender_id: int = int(_frame.defender)
	var payload: Dictionary = {"attacker": attacker_id, "defender": defender_id}
	match str(stage.stage):
		STAGE_ATTACK_DECLARE:
			_run_step(_declare_attack_step.bind(payload, _frame))
		STAGE_ATTACK_POINT:
			var ctx: Dictionary = {
				"side": str(stage.side), "candidates": _candidates_in_order(), "attacker": attacker_id,
				"defender": defender_id, "source": attacker_id, "subject": defender_id,
			}
			_run_step(_resolve_step.bind(&"on_attack", ctx), int(_frame.cause))
		STAGE_ATTACK_DAMAGE:
			if _character(attacker_id).is_empty() or _character(defender_id).is_empty():
				_run_step(_cancel_attack_step.bind(payload))
			else:
				_run_step(_attack_damage_step.bind(attacker_id, defender_id))
		STAGE_ATTACK_RESOLVED:
			emit(&"attack_resolved", payload)


## C8 step 1: `attack_declared`; its `seq` goes into [param declared]`.cause`
## (the `on_attack` step runs under it). An attacker with Stealth loses it
## now (story 014, C12): the keyword leaves its definition set and every
## granting enchantment, and `stealth_lost {entity_id}` is emitted — the
## combat event, not `keyword_removed` (C15) — so from here on it is a legal
## enemy target and its Taunt binds.
func _declare_attack_step(payload: Dictionary, declared: Dictionary) -> void:
	declared.cause = emit(&"attack_declared", payload)
	var attacker: Dictionary = _character(int(payload.attacker))
	if _halted() or not _has_keyword(attacker, MatchRecords.KEYWORD_STEALTH):
		return
	_strip_keyword(attacker, MatchRecords.KEYWORD_STEALTH)
	emit(&"stealth_lost", {"entity_id": int(payload.attacker)})


## C8 step 3, the attack cancelled: `attack_cancelled`, and the swing still
## counts for an attacker that is still in play.
func _cancel_attack_step(payload: Dictionary) -> void:
	emit(&"attack_cancelled", payload)
	var attacker: Dictionary = _character(int(payload.attacker))
	if not attacker.is_empty():
		attacker.attacks_used = int(attacker.attacks_used) + 1


## C8 steps 4–5 as one step (DD-M11): `a_atk = attack(A)` and `d_atk =
## attack(D)` are read once, before either hit (the snapshot); then
## `apply_damage(D, a_atk, source)` and — only when `d_atk > 0` and D is a
## **minion** — `apply_damage(A, d_atk, D)`: a defending hero never deals
## damage back, weapon or not (DD-X11). No death check between the hits; F2
## applies Divine Shield, Poisonous and Lifesteal inside each. A hero attacking
## with a weapon hits with the weapon as the source (its keywords count, and
## `damage_dealt_by_card` attributes to the weapon's `def_id`) and the weapon
## loses 1 durability in this step. Then `A.attacks_used += 1`.
func _attack_damage_step(attacker_id: int, defender_id: int) -> void:
	var attacker: Dictionary = _character(attacker_id)
	var defender: Dictionary = _character(defender_id)
	var a_atk: int = attack(attacker)
	var d_atk: int = attack(defender)
	var defender_is_minion: bool = defender.kind == MatchRecords.KIND_MINION
	var weapon: Variant = _weapon_of(attacker)
	var source: int = int(weapon.entity_id) if weapon != null else attacker_id
	@warning_ignore("return_value_discarded")
	apply_damage(defender_id, a_atk, source)
	if d_atk > 0 and defender_is_minion:
		@warning_ignore("return_value_discarded")
		apply_damage(attacker_id, d_atk, defender_id)
	if weapon != null:
		modify_durability(int(weapon.entity_id), -1)
	attacker.attacks_used = int(attacker.attacks_used) + 1


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
## same log, outside the current call's event range (rule 12a). After
## `match_ended` the log is sealed (rule 15), so a `MATCH_ENDED` rejection is
## not logged and its range is `[0, 0]`. A diagnostic the log refuses on a
## live match is its overflow: `fault(event_cap)`, as in [method emit], and
## the rejection's range is `[0, 0]` (nothing of it was logged).
func _reject(command: Dictionary, code: String, detail: String) -> Dictionary:
	assert(REJECTION_CODES.has(code), "rejection code '%s' is outside the closed C2 set" % code)
	if _state.result != null:
		return MatchRecords.command_result(false, code, detail, 0, 0)
	var log: Variant = _state.log
	var seq: int = log.append(&"command_rejected", {
		"side": str(command.get("issuer", "")),
		"command": command.duplicate(true),
		"code": code,
		"detail": detail,
		"diagnostic": true,
	}, 0)
	if seq < 0:
		if not _halted():
			fault(MatchRecords.REASON_EVENT_CAP)
		seq = 0
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
		MatchRecords.CMD_PLAY_CARD:
			return _validate_play_card(command)
		MatchRecords.CMD_USE_HERO_POWER:
			return _validate_hero_power(command)
		MatchRecords.CMD_ATTACK:
			return _validate_attack(command)
		MatchRecords.CMD_END_TURN, MatchRecords.CMD_CONCEDE:
			return ""
		MatchRecords.CMD_CHOOSE:
			# C2 `choose` (story 016): the phase guard already matched the issuer
			# to `pending_choice.side`; the index must name an option.
			var index: Variant = command.get("option_index")
			var count: int = ((_state.pending_choice as Dictionary).options as Array).size()
			if not _is_whole(index) or int(index) < 0 or int(index) >= count:
				return R_INVALID_CHOICE
			return ""
	# TODO(story 012): the attack handler. Until it exists its command is not
	# accepted in any phase.
	return R_WRONG_PHASE


# --- C6 / C7: playing cards and the hero power (story 010) --------------------

## C6 validation after the phase guard, in row order: `hand_index` in range
## (`INVALID_INDEX`) → a minion / spell / weapon definition (else
## `INVALID_INDEX`) → `effective_cost ≤ mana_current` (`NOT_ENOUGH_MANA`) →
## minions: `BOARD_FULL`, then `0 ≤ position ≤ board.size` (`INVALID_POSITION`)
## → targeting ([method _target_rejection], spells by the spell rule).
func _validate_play_card(command: Dictionary) -> String:
	var side: String = str(command.issuer)
	var player: Dictionary = _state.players[side]
	var index: Variant = command.get("hand_index")
	if not _is_whole(index) or int(index) < 0 or int(index) >= player.hand.size():
		return R_INVALID_INDEX
	var card: Dictionary = player.hand[int(index)]
	var type: String = _card_type(card)
	if type == "":
		return R_INVALID_INDEX
	if effective_cost(card, side) > int(player.mana_current):
		return R_NOT_ENOUGH_MANA
	if type == CARD_MINION:
		if player.board.size() >= rule("board_size"):
			return R_BOARD_FULL
		var position: Variant = command.get("position")
		if not _is_whole(position) or int(position) < 0 or int(position) > player.board.size():
			return R_INVALID_POSITION
	return _target_rejection(str(card.def_id), _card_source(side, card), command.get("target_id"), type == CARD_SPELL)


## C7 validation after the phase guard: `used_this_turn` (`HERO_POWER_USED`,
## before cost — a 0-cost power is still once per turn) → cost → targeting by
## the spell rule.
func _validate_hero_power(command: Dictionary) -> String:
	var side: String = str(command.issuer)
	var player: Dictionary = _state.players[side]
	if player.hero_power.used_this_turn:
		return R_HERO_POWER_USED
	if hero_power_cost(side) > int(player.mana_current):
		return R_NOT_ENOUGH_MANA
	return _target_rejection(str(player.hero_power.def_id), _power_source(side), command.get("target_id"), true)


## C6 targeting against `resolver.targeting_spec(def_id).mode` and
## `resolver.legal_targets(def_id, source)`: `none` ignores [param target_id];
## `optional` accepts null or a legal target; `required` with ≥ 1 legal target
## needs one (`TARGET_REQUIRED` / `ILLEGAL_TARGET`); `required` with none is
## `NO_LEGAL_TARGET` under [param spell_rule] (spells, the hero power) and
## playable otherwise (a Battlecry body — its Battlecry will not resolve).
func _target_rejection(def_id: String, source: Dictionary, target_id: Variant, spell_rule: bool) -> String:
	var mode: String = _targeting_mode(def_id)
	if mode == TARGETING_NONE:
		return ""
	var legal: Array[int] = _resolver.legal_targets(def_id, source)
	if mode == TARGETING_REQUIRED:
		if legal.is_empty():
			return R_NO_LEGAL_TARGET if spell_rule else ""
		if target_id == null:
			return R_TARGET_REQUIRED
	if target_id == null:
		return ""
	if not _is_whole(target_id) or not legal.has(int(target_id)):
		return R_ILLEGAL_TARGET
	return ""


## What an accepted play resolves with: `{target}` — null for `none`, or for a
## `required` Battlecry with no legal target — and `{fizzles}`, true for that
## Battlecry (its trigger point is then not fired at all, C6 step 1).
func _play_plan(def_id: String, source: Dictionary, target_id: Variant) -> Dictionary:
	var mode: String = _targeting_mode(def_id)
	if mode == TARGETING_NONE:
		return {"target": null, "fizzles": false}
	if mode == TARGETING_REQUIRED and _resolver.legal_targets(def_id, source).is_empty():
		return {"target": null, "fizzles": true}
	return {"target": null if target_id == null else int(target_id), "fizzles": false}


## The `target_id`s `legal_commands()` lists for [param def_id] (see there).
func _listed_targets(def_id: String, source: Dictionary, spell_rule: bool) -> Array:
	var mode: String = _targeting_mode(def_id)
	if mode == TARGETING_NONE:
		return [null]
	var legal: Array[int] = _resolver.legal_targets(def_id, source)
	var out: Array = []
	if mode == TARGETING_REQUIRED:
		if legal.is_empty():
			return [] if spell_rule else [null]
	else:
		out.append(null)
	out.append_array(legal)
	return out


## `legal_commands()` rows for the hand card at [param index] of [param side].
func _append_play_commands(legal: Array, side: String, index: int) -> void:
	var player: Dictionary = _state.players[side]
	var card: Dictionary = player.hand[index]
	var type: String = _card_type(card)
	if type == "" or effective_cost(card, side) > int(player.mana_current):
		return
	if type == CARD_MINION and player.board.size() >= rule("board_size"):
		return
	var targets: Array = _listed_targets(str(card.def_id), _card_source(side, card), type == CARD_SPELL)
	var positions: Array = range(player.board.size() + 1) if type == CARD_MINION else [null]
	for position: Variant in positions:
		for target: Variant in targets:
			legal.append(MatchRecords.play_card(side, index, position, target))


func _targeting_mode(def_id: String) -> String:
	return str(_resolver.targeting_spec(def_id).get("mode", TARGETING_NONE))


## The `source` [method legal_targets] reads for a hand card: `{side,
## source_id: instance_id, card_id}`.
static func _card_source(side: String, card: Dictionary) -> Dictionary:
	return {"side": side, "source_id": int(card.instance_id), "card_id": str(card.def_id)}


## The `source` for [param side]'s hero power: `{side, source_id: hero id,
## card_id: the power's def_id}`.
func _power_source(side: String) -> Dictionary:
	var player: Dictionary = _state.players[side]
	return {"side": side, "source_id": int(player.hero.entity_id), "card_id": str(player.hero_power.def_id)}


## The playable type of the CardInstance [param card] (`minion`, `spell`,
## `weapon`), or "" when its definition is missing or of another type.
func _card_type(card: Dictionary) -> String:
	var type: String = str(_lookup_def(str(card.def_id)).get("type", ""))
	return type if [CARD_MINION, CARD_SPELL, CARD_WEAPON].has(type) else ""


static func _is_whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and float(value) == floorf(float(value))


## An accepted `play_card` (validated in full): the acceptance step — mana
## paid (`mana_spent`), the card leaves the hand (`stats.cards_played`),
## `card_played` — then the type's play steps, each with its C10 loop. Built
## as stages over one frame (story 016) so a Discover can pause it anywhere.
func _do_play_card(command: Dictionary) -> void:
	var side: String = str(command.issuer)
	var card: Dictionary = _state.players[side].hand[int(command.hand_index)]
	var def_id: String = str(card.def_id)
	var plan: Dictionary = _play_plan(def_id, _card_source(side, card), command.get("target_id"))
	var instance_id: int = int(card.instance_id)
	_frame = {"side": side, "instance_id": instance_id, "def_id": def_id, "target": plan.target, "cause": 0, "id": NO_ENTITY}
	match _card_type(card):
		CARD_MINION:
			_play_minion(side, int(command.position), plan)
		CARD_SPELL:
			_frame.id = instance_id
			_cast_spell(side, plan)
		CARD_WEAPON:
			_play_weapon(side, plan)


## C6 minions: accept and place the minion at `board[position]` (sick,
## `summoned_on_turn = turn`; `card_played` then `minion_summoned`), then the
## card-effects C6.3 steps: (1) `battlecry` (unless it fizzles), (2)
## `on_card_played` hooks, (3) `on_card_played` observers, (4) `on_play`, (5)
## `on_minion_summoned` hooks, (6) `on_summon` — each its own step.
func _play_minion(side: String, position: int, plan: Dictionary) -> void:
	_stage({"stage": STAGE_ACCEPT, "side": side, "type": CARD_MINION, "position": position})
	if not plan.fizzles:
		_stage({"stage": STAGE_PLAY_POINT, "side": side, "point": "battlecry"})
	_stages.append_array(_hook_stages(&"on_card_played", side, STAGE_PLAY_HOOK))
	_stage({"stage": STAGE_OBSERVERS, "side": side, "point": "on_card_played", "instance": true})
	_stage({"stage": STAGE_OBSERVERS, "side": side, "point": "on_play", "instance": false})
	_stages.append_array(_hook_stages(&"on_minion_summoned", side, STAGE_PLAY_HOOK))
	_stage({"stage": STAGE_OBSERVERS, "side": side, "point": "on_summon", "instance": false})


func _accept_minion(side: String, card: Dictionary, position: int, target: Variant, played: Dictionary) -> void:
	played.cause = _accept_card(side, card, CARD_MINION, target)
	if _halted():
		return
	var player: Dictionary = _state.players[side]
	var def_id: String = str(card.def_id)
	var minion: Dictionary = _minion_from_def(def_id, _lookup_def(def_id), side)
	player.board.insert(position, minion)
	player.stats.minions_summoned = int(player.stats.minions_summoned) + 1
	played.id = int(minion.entity_id)
	emit(&"minion_summoned", {
		"side": side, "entity_id": int(minion.entity_id), "card_id": def_id, "position": position,
		"attack": attack(minion), "health": health(minion),
	})


## C6 spells: accept, the card into zone `resolving` ([member
## MatchState] `players[side].resolving`, so it is the damage source Lifesteal,
## Poisonous and the stats find), `spell_cast {…, spell_damage: F7}`; then
## (1) `on_cast` — the spell's effect, (2) `on_card_played` hooks, (3)
## `on_card_played` observers, (4) `after_cast`; then `card_to_graveyard`.
## A fault or `event_cap` that stops the match mid-resolution still moves the
## card out of `resolving` into the graveyard — with no event, the log being
## sealed (code review 2026-11-03: it was left in `resolving`). A Discover in
## `on_cast` pauses everything after it, the card staying in `resolving`
## (story 016; quick-design 2026-11-04): the later ops of the spell's own
## effect are the resolver's continuation, the steps (2)–(4) and the move to
## the graveyard are parked stages, and both run once, in this order, after
## `choose`.
func _cast_spell(side: String, plan: Dictionary) -> void:
	_stage({"stage": STAGE_ACCEPT, "side": side, "type": CARD_SPELL})
	_stage({"stage": STAGE_PLAY_POINT, "side": side, "point": "on_cast"})
	_stages.append_array(_hook_stages(&"on_card_played", side, STAGE_PLAY_HOOK))
	_stage({"stage": STAGE_OBSERVERS, "side": side, "point": "on_card_played", "instance": true})
	_stage({"stage": STAGE_OBSERVERS, "side": side, "point": "after_cast", "instance": false})
	_stage({"stage": STAGE_SPELL_DONE, "side": side, "instance_id": int(_frame.instance_id), "def_id": str(_frame.def_id)})


## The move out of `resolving` that ends a cast (the stage after `after_cast`,
## and the cleanup of a cast a fault, an `event_cap` or a concede in `Choice`
## stopped): the card to the graveyard, `card_to_graveyard` while the match
## runs (none once Ended: the log is sealed).
func _spell_done(stage: Dictionary) -> void:
	var side: String = str(stage.side)
	var player: Dictionary = _state.players[side]
	var id: int = int(stage.instance_id)
	var card: Dictionary = {}
	for held: Dictionary in player.resolving:
		if int(held.instance_id) == id:
			card = held
	if card.is_empty():
		return
	player.resolving.erase(card)
	card.zone = "graveyard"
	player.graveyard.append(card)
	if _halted():
		return
	emit(&"card_to_graveyard", {"side": side, "instance_id": id, "card_id": str(stage.def_id)})


func _accept_spell(side: String, card: Dictionary, target: Variant, cast: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	_accept_card(side, card, CARD_SPELL, target)
	# Into `resolving` even when the log refused the acceptance: the card has
	# left the hand, and [method _cast_spell] moves it on from here.
	card.zone = "resolving"
	_state.players[side].resolving.append(card)
	if _halted():
		return
	cast.cause = emit(&"spell_cast", {
		"side": side, "instance_id": int(card.instance_id), "card_id": str(card.def_id),
		"target_id": target, "spell_damage": spell_damage(side),
	})


## C6 weapons: accept — a held weapon is destroyed first (`weapon_destroyed`,
## its Deathrattle queued and resolved in this step's loop) — then the equip
## step (`weapon_equipped`; `attacks_used` untouched), then (1) `battlecry`
## (unless it fizzles), (2) `on_card_played` hooks, (3) `on_card_played`
## observers, (4) `on_weapon_equipped`.
func _play_weapon(side: String, plan: Dictionary) -> void:
	_stage({"stage": STAGE_ACCEPT, "side": side, "type": CARD_WEAPON})
	_stage({"stage": STAGE_EQUIP, "side": side})
	if not plan.fizzles:
		_stage({"stage": STAGE_PLAY_POINT, "side": side, "point": "battlecry"})
	_stages.append_array(_hook_stages(&"on_card_played", side, STAGE_PLAY_HOOK))
	_stage({"stage": STAGE_OBSERVERS, "side": side, "point": "on_card_played", "instance": true})
	_stage({"stage": STAGE_OBSERVERS, "side": side, "point": "on_weapon_equipped", "instance": false})


func _accept_weapon(side: String, card: Dictionary, target: Variant, played: Dictionary) -> void:
	played.cause = _accept_card(side, card, CARD_WEAPON, target)
	if not _halted() and _state.players[side].weapon != null:
		_weapon_leaves(side, WEAPON_REPLACED)


func _equip_step(side: String, def_id: String, played: Dictionary) -> void:
	played.id = equip_weapon(side, def_id)


## The common C6 acceptance: pay [param card]'s effective cost (`mana_spent
## {side, amount, mana_current}`), take it out of the hand, `stats.cards_played
## += 1`, `card_played {side, instance_id, card_id, type, hand_index,
## target_id}`. Returns the `card_played` seq (the `cause_seq` of the play's
## trigger steps, card-effects C6.6).
func _accept_card(side: String, card: Dictionary, type: String, target: Variant) -> int:
	var player: Dictionary = _state.players[side]
	var cost: int = effective_cost(card, side)
	var index: int = player.hand.find(card)
	player.mana_current = int(player.mana_current) - cost
	emit(&"mana_spent", {"side": side, "amount": cost, "mana_current": int(player.mana_current)})
	player.hand.remove_at(index)
	player.stats.cards_played = int(player.stats.cards_played) + 1
	return emit(&"card_played", {
		"side": side, "instance_id": int(card.instance_id), "card_id": str(card.def_id),
		"type": type, "hand_index": index, "target_id": target,
	})


## An accepted `use_hero_power` (C7): pay `hero_power_cost` (`mana_spent`),
## `used_this_turn = true`, `hero_power_used {side, power_id, target_id}`,
## then the card-effects C6.3 "Hero power used" row, each its own step under
## `hero_power_used`: (1) trigger point `hero_power` from the hero (the host
## power's effect), (2) the `on_hero_power` observers, `subject` the hero.
func _do_hero_power(command: Dictionary) -> void:
	var side: String = str(command.issuer)
	var player: Dictionary = _state.players[side]
	var power_id: String = str(player.hero_power.def_id)
	var plan: Dictionary = _play_plan(power_id, _power_source(side), command.get("target_id"))
	_frame = {"side": side, "instance_id": NO_ENTITY, "def_id": power_id, "target": plan.target, "cause": 0, "id": int(player.hero.entity_id)}
	_stage({"stage": STAGE_ACCEPT, "side": side, "type": STAGE_TYPE_HERO_POWER})
	_stage({"stage": STAGE_PLAY_POINT, "side": side, "point": "hero_power"})
	_stage({"stage": STAGE_OBSERVERS, "side": side, "point": "on_hero_power", "instance": false})


func _accept_hero_power(side: String, target: Variant, used: Dictionary) -> void:
	var player: Dictionary = _state.players[side]
	var cost: int = hero_power_cost(side)
	player.mana_current = int(player.mana_current) - cost
	emit(&"mana_spent", {"side": side, "amount": cost, "mana_current": int(player.mana_current)})
	player.hero_power.used_this_turn = true
	used.cause = emit(&"hero_power_used", {"side": side, "power_id": str(player.hero_power.def_id), "target_id": target})


## A play trigger point (`battlecry`, `on_cast`, `hero_power`) as one step
## under [param cause]: the single candidate is the host [param source_id];
## `ctx {side, candidates: [source], source, target_id, card_id}`. The
## resolver runs the host's effect now (card-effects C6.2) and may return
## queued triggers.
func _play_point(point: StringName, side: String, source_id: int, target: Variant, card_id: String, cause: int) -> void:
	var candidates: Array[int] = [source_id]
	var ctx: Dictionary = {"side": side, "candidates": candidates, "source": source_id, "target_id": target, "card_id": card_id}
	_run_step(_resolve_step.bind(point, ctx), cause)


## An observer trigger point of the play order (`on_card_played`, `on_play`,
## `on_summon`, `after_cast`, `on_weapon_equipped`, `on_hero_power`) as one
## step under [param cause]: candidates in engine order, `subject` the played
## entity (the hero for `on_hero_power`). [param instance_id], when given,
## joins the ctx as `instance_id` — the played card instance, card-effects C2's
## `trigger_subject` of `on_card_played` (a minion's or weapon's `subject` is
## its new entity, so the instance is named separately; code review 2026-11-03).
func _fire_observers(point: StringName, side: String, subject: int, card_id: String, cause: int, instance_id: int = NO_ENTITY) -> void:
	if _halted():
		return
	var ctx: Dictionary = {"side": side, "candidates": _candidates_in_order(), "subject": subject, "card_id": card_id}
	if instance_id != NO_ENTITY:
		ctx["instance_id"] = instance_id
	_run_step(_resolve_step.bind(point, ctx), cause)


## C3 step 7 (DD-M05): unkept cards return to the bottom of the deck in hand
## order **before** one shuffle of the whole deck, then the same number is
## drawn; `mulligan_resolved {side, replaced_instance_ids}`. Kept cards keep
## their hand order; redraws append right. The mulligan through
## `match_started` (C3 step 8) is one step with its C10 loop; then the
## player's first Start step (DD-M03).
func _do_mulligan(keep_mask: Array) -> void:
	_stage({"stage": STAGE_MULLIGAN, "side": MatchRecords.SIDE_PLAYER, "keep_mask": keep_mask.duplicate()})
	_stages.append_array(_start_stages(MatchRecords.SIDE_PLAYER))


func _mulligan_step(keep_mask: Array) -> void:
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
	_draw(MatchRecords.SIDE_PLAYER, replaced.size(), false)
	if _halted():
		return
	emit(&"mulligan_resolved", {"side": MatchRecords.SIDE_PLAYER, "replaced_instance_ids": replaced})
	if _halted():
		return
	# C3 step 8: match_started
	emit(&"match_started", {
		"floor": _state.floor,
		"hero_id": int(_state.players[MatchRecords.SIDE_PLAYER].hero.entity_id),
		"boss_id": int(_state.players[MatchRecords.SIDE_BOSS].hero.entity_id),
		"player_deck_size": _state.players[MatchRecords.SIDE_PLAYER].deck.size(),
		"boss_deck_size": _state.players[MatchRecords.SIDE_BOSS].deck.size(),
	})


## C4 Start step for [param side] (engine-driven; no command is accepted
## until Main) as stages (story 016): steps 0–3 ([method _turn_begin]), one
## stage per `on_turn_start` hook entry (4), the `turn_start` triggers (5),
## the draw (6), win/loss then Main (7). A Discover in steps 4–5 pauses the
## rest; `choose` runs the draw and Main after the pick.
func _start_stages(side: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"stage": STAGE_TURN_BEGIN, "side": side}]
	out.append_array(_hook_stages(&"on_turn_start", side, STAGE_HOOK))
	out.append({"stage": STAGE_TURN_POINT, "side": side, "point": "turn_start"})
	out.append({"stage": STAGE_TURN_DRAW, "side": side})
	out.append({"stage": STAGE_TURN_MAIN, "side": side})
	return out


## C4 Start steps 0–3 for [param side]. Step 0 is the States guard
## `*Turn.Start` with `turn > TURN_CAP`: the match ends for the boss, reason
## `turn_cap` (C14). Stops at the first event the log refuses (`event_cap`,
## [method emit]).
func _turn_begin(side: String) -> void:
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
	if _halted():
		return
	# 2. mana (F4): crystals from own turns plus the permanent bonus, then refill
	var old_max: int = int(player.mana_max)
	player.mana_max = mini(int(player.turns_taken) + int(player.crystal_bonus), rule("max_mana"))
	if int(player.mana_max) > old_max:
		emit(&"crystal_gained", {"side": side, "mana_max": player.mana_max, "gained": int(player.mana_max) - old_max})
		if _halted():
			return
	player.mana_current = player.mana_max
	emit(&"mana_refilled", {"side": side, "mana_available": player.mana_current, "mana_max": player.mana_max})
	if _halted():
		return
	# 3. one bulk reset, one event (DD-T04)
	var reset_ids: Array[int] = []
	for character: Dictionary in _characters_of(side):
		character.attacks_used = 0
		if character.get("kind", "") == MatchRecords.KIND_MINION:
			character.summoning_sick = false
		reset_ids.append(int(character.entity_id))
	player.hero_power.used_this_turn = false
	emit(&"turn_reset", {"side": side, "entity_ids": reset_ids})
	# 4. on_turn_start hooks, each entry a step; 5. turn_start triggers in
	#    engine candidate order (one step); each followed by its C10 loop;
	#    6. draw one, turn 1 included (a step); 7. win/loss, then Main — the
	#    stages after this one ([method _start_stages]).


## C4 End step for the active [param side], entered by `end_turn`, as stages
## (story 016): (1) `phase = end`, `turn_ending`; (2) the `turn_end` triggers
## (same candidate order); (3) one stage per `on_turn_end` hook entry, each a
## step with its C10 loop; (4)–(5) [method _expire_end_of_turn] as one step;
## (6) win/loss, `turn_ended`, then the other side's Start stages. Stops at
## the first event the log refuses (`event_cap`, [method emit]).
func _end_stages(side: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"stage": STAGE_TURN_ENDING, "side": side}]
	out.append({"stage": STAGE_TURN_POINT, "side": side, "point": "turn_end"})
	out.append_array(_hook_stages(&"on_turn_end", side, STAGE_HOOK))
	# 4. TODO(story 015): the thaw rule (C13) for every `side` character.
	# 5. end_of_turn enchantments on everything `side` owns — one step, whose
	#    C10 loop recomputes the auras (and kills what lost its health buff);
	#    the side's temporary crystals expire in the same step (story 011)
	out.append({"stage": STAGE_TURN_EXPIRE, "side": side})
	out.append({"stage": STAGE_TURN_ENDED, "side": side})
	return out


## C4 End step 6: win/loss, `turn_ended`, then queue the other side's Start
## stages behind this one.
func _turn_ended(side: String) -> void:
	if _win_loss_check():
		return
	emit(&"turn_ended", {"turn": _state.turn, "side": side})
	if _halted():
		return
	_stages.append_array(_start_stages(MatchRecords.SIDE_BOSS if side == MatchRecords.SIDE_PLAYER else MatchRecords.SIDE_PLAYER))


## Fires trigger point [param point] for [param side] as one step (ADR-0007
## Decision 1): `ctx.candidates` in the engine's one observer order; the
## triggers the resolver returns join the engine's queue Q, then the C10 loop
## drains.
func _fire_trigger_point(point: StringName, side: String) -> void:
	_run_step(_resolve_step.bind(point, {"side": side, "candidates": _candidates_in_order()}))


## One trigger-point step: `resolver.resolve(point, ctx)`; what it returns
## joins Q, raised by the event the step runs under.
func _resolve_step(point: StringName, ctx: Dictionary) -> void:
	_enqueue(point, _resolver.resolve(point, ctx), _cause_seq)


## A trigger hook point at a step boundary (C3 step 4, C4 Start 4 / End 3;
## story 010's `on_card_played`): each entry on [param point] for
## [param side] runs as its own step followed by the full C10 loop (ADR-0005
## rule 4). Hook points reached inside a primitive (`on_draw`,
## `on_hero_damaged`, `on_minion_summoned`) run synchronously within the
## current step instead ([method _run_inline_hooks]) — a C10 loop there would
## run a death check between the ops of one effect pass (ADR-0007,
## card-effects C6.0).
func _run_hook_steps(point: StringName, side: String, ctx: Dictionary, cause: int = -1) -> void:
	for index: int in _state.hooks.entries(point).size():
		if _halted():
			return
		_run_step(_run_hook_entry.bind(point, index, side, ctx), cause)


## One step-boundary hook entry (the step [method _run_hook_steps] runs):
## the entry at [param index] on [param point], with [param point] marked
## running for the entry itself — not for the C10 loop after it, whose queued
## triggers may reach the point again legitimately.
func _run_hook_entry(point: StringName, index: int, side: String, ctx: Dictionary) -> void:
	if not _enter_hook_point(point):
		return
	_state.hooks.run_trigger_entry(point, index, StringName(side), ctx)
	_hook_points_running[point] = false


## A trigger hook point reached inside a primitive (`on_draw`,
## `on_hero_damaged`, `on_minion_summoned` — ADR-0005 rule-4 exception,
## erratum 2026-11-03): its entries run synchronously within the current step,
## back to back, with no C10 loop between them. A primitive one of them calls
## that reaches [param point] again faults `resolution_overflow`
## ([method _enter_hook_point]); any other point may still be reached.
func _run_inline_hooks(point: StringName, side: String, ctx: Dictionary) -> void:
	if _halted() or not _enter_hook_point(point):
		return
	_state.hooks.run_triggers(point, StringName(side), ctx)
	_hook_points_running[point] = false


## Marks [param point] running and returns `true`; when it is already running
## — a re-entry within one of its entries — ends the match with
## `fault(resolution_overflow, steps)` (ADR-0005 erratum 2026-11-03: a
## self-feeding hook ends the match as a fault, never overflows the call
## stack) and returns `false`. The caller clears the mark after the entries.
func _enter_hook_point(point: StringName) -> bool:
	if _hook_points_running.get(point, false):
		fault(MatchRecords.REASON_RESOLUTION_OVERFLOW, _steps)
		return false
	_hook_points_running[point] = true
	return true


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
## each, in that order. Then its temporary crystals expire (C5, story 011):
## `mana_max −= temporary_crystals`, `mana_current = max(0, mana_current −
## temporary_crystals)`, `temporary_crystals = 0` — no event of its own (the
## GDD names none; the `turn_ending` / `turn_ended` pair brackets it).
func _expire_end_of_turn(side: String) -> void:
	var player: Dictionary = _state.players[side]
	for character: Dictionary in _characters_of(side):
		_expire_in(character.enchantments, int(character.entity_id))
	if player.weapon != null:
		_expire_in(player.weapon.enchantments, int(player.weapon.entity_id))
	for zone: String in ["hand", "deck"]:
		for card: Dictionary in player[zone]:
			_expire_in(card.cost_modifiers, int(card.instance_id))
	var temporary: int = int(player.temporary_crystals)
	if temporary > 0:
		player.mana_max = int(player.mana_max) - temporary
		player.mana_current = maxi(0, int(player.mana_current) - temporary)
		player.temporary_crystals = 0


func _expire_in(enchantments: Array, owner_id: int) -> void:
	var i: int = 0
	while i < enchantments.size() and not _halted():
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


# --- Stages and the Choice continuation (story 016) ------------------------

## Appends [param stage] to the current command's stages.
func _stage(stage: Dictionary) -> void:
	_stages.append(stage)


## One stage of [param kind] (`STAGE_HOOK` / `STAGE_PLAY_HOOK`) per entry on
## hook point [param point], in installation order — each runs as its own
## step (ADR-0005 rule 4), so a pause after entry *i* parks entries *i + 1…*.
func _hook_stages(point: StringName, side: String, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index: int in _state.hooks.entries(point).size():
		out.append({"stage": kind, "side": side, "point": String(point), "index": index})
	return out


## Runs the current command's stages front first until none is left, the
## match ends, or a stage raises a `ChoiceRequest` (the rest then stays in
## [member _stages] for [method _park]).
func _run_stages() -> void:
	while not _stages.is_empty() and not _halted() and not _suspended():
		_run_stage(_stages.pop_front())


## Executes one stage (see the `STAGE_*` constants); each step it runs is a
## C10 step with its loop, exactly as the handlers ran them before story 016.
func _run_stage(stage: Dictionary) -> void:
	var side: String = str(stage.side)
	var cause: int = int(_frame.get("cause", -1))
	match str(stage.stage):
		STAGE_MULLIGAN:
			_run_step(_mulligan_step.bind(stage.keep_mask))
		STAGE_TURN_BEGIN:
			_turn_begin(side)
		STAGE_HOOK:
			_run_step(_run_hook_entry.bind(StringName(str(stage.point)), int(stage.index), side, {}))
		STAGE_TURN_POINT:
			_fire_trigger_point(StringName(str(stage.point)), side)
		STAGE_TURN_DRAW:
			_run_step(draw.bind(side, 1))
		STAGE_TURN_MAIN:
			if not _win_loss_check():
				_set_phase(MatchState.PHASE_MAIN)
		STAGE_TURN_ENDING:
			_state.phase = MatchState.PHASE_END
			emit(&"turn_ending", {"turn": _state.turn, "side": side})
		STAGE_TURN_EXPIRE:
			_run_step(_expire_end_of_turn.bind(side))
		STAGE_TURN_ENDED:
			_turn_ended(side)
		STAGE_ACCEPT:
			_accept_stage(side, str(stage.type), stage)
		STAGE_EQUIP:
			_run_step(_equip_step.bind(side, str(_frame.def_id), _frame), cause)
		STAGE_PLAY_POINT:
			_play_point(StringName(str(stage.point)), side, int(_frame.id), _frame.target, str(_frame.def_id), cause)
		STAGE_PLAY_HOOK:
			var point: StringName = StringName(str(stage.point))
			var ctx: Dictionary = {"entity_id": int(_frame.id), "card_id": str(_frame.def_id)}
			if point == &"on_card_played":
				ctx["instance_id"] = int(_frame.instance_id)
			_run_step(_run_hook_entry.bind(point, int(stage.index), side, ctx), cause)
		STAGE_OBSERVERS:
			var instance_id: int = int(_frame.instance_id) if bool(stage.instance) else NO_ENTITY
			_fire_observers(StringName(str(stage.point)), side, int(_frame.id), str(_frame.def_id), cause, instance_id)
		STAGE_SPELL_DONE:
			_spell_done(stage)
		STAGE_ATTACK_DECLARE, STAGE_ATTACK_POINT, STAGE_ATTACK_DAMAGE, STAGE_ATTACK_RESOLVED:
			_attack_stage(stage)


## The acceptance step of a play: the hand card is found by the frame's
## `instance_id` (stages hold ids, never records), and the `_accept_*` step
## writes `cause` / `id` into the frame.
func _accept_stage(side: String, type: String, stage: Dictionary) -> void:
	if type == STAGE_TYPE_HERO_POWER:
		_run_step(_accept_hero_power.bind(side, _frame.target, _frame))
		return
	var card: Dictionary = {}
	for held: Dictionary in _state.players[side].hand:
		if int(held.instance_id) == int(_frame.instance_id):
			card = held
	match type:
		CARD_MINION:
			_run_step(_accept_minion.bind(side, card, int(stage.position), _frame.target, _frame))
		CARD_SPELL:
			_run_step(_accept_spell.bind(side, card, _frame.target, _frame))
		CARD_WEAPON:
			_run_step(_accept_weapon.bind(side, card, _frame.target, _frame))


## True while a `ChoiceRequest` is pending (`phase == choice`).
func _suspended() -> bool:
	return _state.phase == MatchState.PHASE_CHOICE


## Parks the paused action on `MatchState` as plain data: Q, the step count,
## and the remaining stages with their frame (added to the
## `suspended_action {origin_phase, cause_seq}` that [method discover] began).
func _park() -> void:
	_state.suspended_queue.assign(_queue)
	_queue.clear()
	_state.suspended_steps = _steps
	_state.suspended_action["frame"] = _frame.duplicate(true)
	_state.suspended_action["stages"] = _stages.duplicate(true)
	_stages.clear()


## `choose{option_index}`, validated (see [method discover] for the whole
## contract): `choice_made`, the origin phase back, the parked Q / step count
## / stages restored, `resolver.resume(choice, option_index)` under the paused
## step's `cause_seq`, then that step's C10 loop. [method submit] runs the
## restored stages and closes the action.
func _do_choose(option_index: int) -> void:
	var choice: Dictionary = _state.pending_choice
	var action: Dictionary = _state.suspended_action
	emit(&"choice_made", {"side": str(choice.side), "option_index": option_index})
	if _halted():
		return
	_state.pending_choice = null
	_state.suspended_action = {}
	_queue.assign(_state.suspended_queue)
	_state.suspended_queue.clear()
	_steps = _state.suspended_steps
	_state.suspended_steps = 0
	_frame = (action.get("frame", {}) as Dictionary).duplicate(true)
	_stages.assign(action.get("stages", []))
	_set_phase(str(action.origin_phase))
	if _halted():
		return
	_cause_seq = int(action.cause_seq)
	_resolver.resume(choice, option_index)
	if not _suspended():
		_drain()
	_cause_seq = 0


## `concede` in `Choice` abandons the pending choice (card-effects C8): the
## request and the parked action are dropped; the parked stages come back
## to [member _stages] so the Ended cleanup ([method _abandon_stages]) still
## moves a paused spell out of `resolving`. A no-op in any other phase.
func _abandon_choice() -> void:
	if not _suspended():
		return
	var action: Dictionary = _state.suspended_action
	_stages.assign(action.get("stages", []))
	_frame = action.get("frame", {})
	_state.pending_choice = null
	_state.suspended_action = {}
	_state.suspended_queue.clear()
	_state.suspended_steps = 0


## The cleanup of a command the match ended in the middle of (a fault, the
## event cap, a concede in `Choice`): a cast spell still leaves `resolving`
## (silently — the log is sealed); every other stage is dropped.
func _abandon_stages() -> void:
	for stage: Dictionary in _stages:
		if str(stage.stage) == STAGE_SPELL_DONE:
			_spell_done(stage)
	_stages.clear()


## One action of the C10 loop without the closing `win_loss_check` (the
## C4 sub-steps check once, at Start 7 / End 6): [param step] is executed and
## counted as one step of the current action's count (reset by
## [method submit] / [method run_action] / [method start], never here), then
## [method _drain]. [param step_cause]
## (≥ 0) is the `cause_seq` the step runs under — a play's trigger steps run
## under its `card_played` / `spell_cast` / `hero_power_used` (card-effects
## C6.6); the default keeps the current one. The `cause_seq` from before is
## restored afterwards, so the next step of the same command is again a
## direct consequence of it. A step that raised a `ChoiceRequest` is counted
## but not drained — its pass resumes at `choose` (story 016) — and while
## `Choice` is pending no further step runs.
func _run_step(step: Callable, step_cause: int = -1) -> void:
	if _halted() or _suspended():
		return
	var cause: int = _cause_seq
	if step_cause >= 0:
		_cause_seq = step_cause
	step.call()
	_steps += 1
	if not _suspended():
		_drain()
	_cause_seq = cause


## The C10 loop after a step: `dead = death_check()`; `recompute_auras()`;
## stable when nobody died and Q is empty; with Q empty but deaths, check
## again (aura loss may have killed something); else pop the front of Q and
## execute it as the next step. Before a step past `resolution_step_cap` the
## match ends with `fault(resolution_overflow, steps)`. No recursion: what a
## step raises is appended to Q. A queued pass that raises a `ChoiceRequest`
## stops the loop where it is — no death check after the unfinished pass —
## leaving the rest of Q for [method _park] (story 016).
func _drain() -> void:
	while not _halted() and not _suspended():
		var dead: Array[int] = _death_check()
		if _halted():
			break
		_recompute_auras()
		if _halted():
			break
		if dead.is_empty() and _queue.is_empty():
			break
		if _queue.is_empty():
			continue
		if _steps >= rule("resolution_step_cap"):
			fault(MatchRecords.REASON_RESOLUTION_OVERFLOW, _steps)
			break
		_execute_queued(_queue.pop_front())
	if _halted():
		_queue.clear()


## Executes one queued trigger as a step: `trigger_resolved {point,
## source_id, effect_id}` with the raising event's `cause_seq` (card-effects
## C6.6), then `resolver.resolve(point, ctx)` with `ctx[CTX_QUEUED] = true` —
## the one effect pass — whose primitives are attributed to that
## `trigger_resolved`. It resolves whether or not its source is still in
## play; `ctx.snapshot` holds the source as it was at raise time.
func _execute_queued(step: Dictionary) -> void:
	var point: StringName = step.point
	var ctx: Dictionary = step.ctx
	_cause_seq = int(step.cause_seq)
	var seq: int = emit(&"trigger_resolved", {"point": String(point), "source_id": int(ctx.source_id), "effect_id": str(ctx.get("effect_id", ""))})
	if _halted():
		return
	_cause_seq = seq
	ctx[CTX_QUEUED] = true
	_enqueue(point, _resolver.resolve(point, ctx), seq)
	_steps += 1


## Appends the triggers [param entries] the resolver returned for
## [param point] to Q as steps `{point, ctx, cause_seq: raise_seq}`, each
## with `trigger_queued {point, source_id, effect_id}` (`cause_seq`
## [param raise_seq]). An entry is `{source_id: int, effect_id, …}` (an
## optional `point` overrides [param point]); it keeps its own `snapshot` or
## gets one — [param dead_snapshot] for a Deathrattle (the source has just
## left play), else a value copy of the source now. Nothing is queued for a
## source that is not in play (or in hand) at raise time (C10). An entry
## without a whole-number `source_id` is a resolver defect: it is logged
## (`push_error`) and skipped, and the entries after it still queue (code
## review 2026-11-03).
func _enqueue(point: StringName, entries: Array[Dictionary], raise_seq: int, dead_snapshot: Dictionary = {}) -> void:
	for entry: Dictionary in entries:
		if _halted():
			return
		if not _is_whole(entry.get("source_id")):
			push_error("RulesEngine: skipped a malformed trigger entry from resolve(%s) (no integer source_id): %s" % [point, entry])
			continue
		var source_id: int = int(entry.source_id)
		var snapshot: Dictionary = dead_snapshot
		if snapshot.is_empty():
			var live: Dictionary = _live_record(source_id)
			if live.is_empty():
				continue
			snapshot = live.duplicate(true)
		var ctx: Dictionary = entry.duplicate(true)
		if not ctx.has("snapshot"):
			ctx["snapshot"] = snapshot
		var step_point: StringName = StringName(str(entry.get("point", point)))
		_queue.append({"point": step_point, "ctx": ctx, "cause_seq": raise_seq})
		var cause: int = _cause_seq
		_cause_seq = raise_seq
		emit(&"trigger_queued", {"point": String(step_point), "source_id": source_id, "effect_id": str(entry.get("effect_id", ""))})
		_cause_seq = cause


## C10 `death_check()`: marks every minion with `health ≤ 0` or
## `pending_destroy` and every weapon with `durability ≤ 0` or
## `pending_destroy`; all of them leave play in this one step (they do not see
## each other die). Then, in DD-M11 order — player board left to right, boss
## board left to right, player weapon, boss weapon — one `minion_died {side,
## entity_id, card_id, position}` / `weapon_destroyed {…, reason: broken}`
## each; their Deathrattles are raised in exactly that order (one
## `resolve(&"deathrattle", …)` per entity, `cause_seq` its death); then
## `on_minion_died` is raised per dead minion for the observers still in
## play. Returns the dead entity ids.
func _death_check() -> Array[int]:
	var dead: Array[Dictionary] = []
	for side: String in MatchRecords.SIDES:
		var board: Array = _state.players[side].board
		var kept: Array[Dictionary] = []
		for index: int in board.size():
			var minion: Dictionary = board[index]
			if health(minion) <= 0 or bool(minion.get("pending_destroy", false)):
				var snapshot: Dictionary = minion.duplicate(true)
				snapshot["position"] = index
				dead.append(snapshot)
			else:
				kept.append(minion)
		if kept.size() != board.size():
			board.assign(kept)
	var broken: Array[Dictionary] = []
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = _state.players[side]
		var weapon: Variant = player.weapon
		if weapon != null and (int(weapon.durability) <= 0 or bool(weapon.get("pending_destroy", false))):
			broken.append(_take_weapon(side))
	var ids: Array[int] = []
	if dead.is_empty() and broken.is_empty():
		return ids
	var died_seqs: Array[int] = []
	for snapshot: Dictionary in dead:
		ids.append(int(snapshot.entity_id))
		died_seqs.append(emit(&"minion_died", {
			"side": str(snapshot.controller), "entity_id": int(snapshot.entity_id),
			"card_id": str(snapshot.def_id), "position": int(snapshot.position),
		}))
	for snapshot: Dictionary in broken:
		ids.append(int(snapshot.entity_id))
		died_seqs.append(emit(&"weapon_destroyed", _weapon_destroyed_payload(snapshot, WEAPON_BROKEN)))
	if _halted():
		return ids
	var leaving: Array[Dictionary] = []
	leaving.append_array(dead)
	leaving.append_array(broken)
	for i: int in leaving.size():
		_queue_deathrattle(leaving[i], died_seqs[i])
	for i: int in dead.size():
		var snapshot: Dictionary = dead[i]
		_raise(&"on_minion_died", {
			"side": str(snapshot.controller), "candidates": _candidates_in_order(),
			"subject": int(snapshot.entity_id), "snapshot": snapshot,
		}, died_seqs[i])
	return ids


## [param side]'s weapon leaves play: `player.weapon = null`; returns a value
## copy carrying `controller` (a Weapon record has none, C1).
func _take_weapon(side: String) -> Dictionary:
	var player: Dictionary = _state.players[side]
	var snapshot: Dictionary = (player.weapon as Dictionary).duplicate(true)
	snapshot["controller"] = side
	player.weapon = null
	return snapshot


static func _weapon_destroyed_payload(snapshot: Dictionary, reason: String) -> Dictionary:
	return {"side": str(snapshot.controller), "entity_id": int(snapshot.entity_id), "card_id": str(snapshot.def_id), "reason": reason}


## A held weapon replaced by [method equip_weapon] leaves play now:
## `weapon_destroyed {…, reason}` and its Deathrattle queued (C6, C10).
func _weapon_leaves(side: String, reason: String) -> void:
	var snapshot: Dictionary = _take_weapon(side)
	var seq: int = emit(&"weapon_destroyed", _weapon_destroyed_payload(snapshot, reason))
	if not _halted():
		_queue_deathrattle(snapshot, seq)


## Raises trigger point `deathrattle` for the one entity that just left play
## ([param snapshot], with its former `position` for a minion): candidates
## `[entity_id]` (several Deathrattles on it are the resolver's to order,
## enchantment order, base first); the entries queue with the death's
## [param died_seq] and the snapshot.
func _queue_deathrattle(snapshot: Dictionary, died_seq: int) -> void:
	var entity_id: int = int(snapshot.entity_id)
	var candidates: Array[int] = [entity_id]
	var ctx: Dictionary = {"side": str(snapshot.controller), "candidates": candidates, "subject": entity_id, "snapshot": snapshot}
	_enqueue(&"deathrattle", _resolver.resolve(&"deathrattle", ctx), died_seq, snapshot)


## C10 `recompute_auras()`: strips every `is_aura` enchantment (characters,
## weapons, hand `cost_modifiers`), then `resolver.recompute_auras()`
## re-applies the auras of every living source (its `apply_enchantment(…,
## is_aura = true)` calls are silent); one `auras_recomputed {changes:
## [{entity_id, attack, health, max_health}]}` lists the characters whose
## derived stats changed, in candidate order — none when nothing changed.
## Aura loss leaves `damage_taken` alone (F6): the next death check kills.
func _recompute_auras() -> void:
	var before: Dictionary = _stat_map()
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = _state.players[side]
		for character: Dictionary in _characters_of(side):
			_strip_auras(character.enchantments)
		if player.weapon != null:
			_strip_auras(player.weapon.enchantments)
		for card: Dictionary in player.hand:
			_strip_auras(card.cost_modifiers)
	_recomputing_auras = true
	_resolver.recompute_auras()
	_recomputing_auras = false
	var after: Dictionary = _stat_map()
	var changes: Array[Dictionary] = []
	for entity_id: int in after:
		var stats: Array = after[entity_id]
		if before.get(entity_id) != stats:
			changes.append({"entity_id": entity_id, "attack": int(stats[0]), "health": int(stats[1]), "max_health": int(stats[2])})
	if not changes.is_empty():
		emit(&"auras_recomputed", {"changes": changes})


## `entity_id → [attack, health, max_health]` for every character in play,
## in candidate order (board left to right, then the hero; player first).
func _stat_map() -> Dictionary:
	var out: Dictionary = {}
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = _state.players[side]
		var characters: Array = player.board.duplicate()
		if player.hero != null:
			characters.append(player.hero)
		for character: Dictionary in characters:
			out[int(character.entity_id)] = [attack(character), health(character), max_health(character)]
	return out


static func _strip_auras(enchantments: Array) -> void:
	for i: int in range(enchantments.size() - 1, -1, -1):
		if bool(enchantments[i].get("is_aura", false)):
			enchantments.remove_at(i)


## The hero, weapon, board minion, hand card or resolving spell
## [param entity_id] — a source "in play (or in hand for hand triggers)" at
## raise time (C10; a spell being cast counts, story 010) — else `{}`.
func _live_record(entity_id: int) -> Dictionary:
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = _state.players[side]
		for slot: String in ["hero", "weapon"]:
			var record: Variant = player[slot]
			if record != null and int(record.entity_id) == entity_id:
				return record
		for minion: Dictionary in player.board:
			if int(minion.entity_id) == entity_id:
				return minion
		for zone: String in ["hand", "resolving"]:
			for card: Dictionary in player[zone]:
				if int(card.instance_id) == entity_id:
					return card
	return {}


## C14 `win_loss_check()` — the one place a match ends on health, run at the
## end of every action's C10 loop and at C4 Start step 7 / End step 6, never
## mid-loop (DD-M12: a later heal in the same action still saves a hero at
## 0). Both heroes ≤ 0 → BOSS, `both_dead`; the player's ≤ 0 → BOSS,
## `hero_dead`; the boss's ≤ 0 → PLAYER, `hero_dead`. Returns true when the
## match has ended (now or before).
func _win_loss_check() -> bool:
	if _halted():
		return true
	var player_dead: bool = health(_state.players[MatchRecords.SIDE_PLAYER].hero) <= 0
	var boss_dead: bool = health(_state.players[MatchRecords.SIDE_BOSS].hero) <= 0
	if player_dead and boss_dead:
		_end_match(MatchRecords.SIDE_BOSS, MatchRecords.REASON_BOTH_DEAD)
	elif player_dead:
		_end_match(MatchRecords.SIDE_BOSS, MatchRecords.REASON_HERO_DEAD)
	elif boss_dead:
		_end_match(MatchRecords.SIDE_PLAYER, MatchRecords.REASON_HERO_DEAD)
	return _halted()


## C14 / States `Ended`: ends the match with a fault — the third outcome,
## `result = fault`, `winner = null` (Run Structure T9: the floor is not
## lost). [param reason] is `resolution_overflow` (the C10 loop's step cap,
## story 009; `resolution_overflow {steps: [param steps]}` is emitted first)
## or `event_cap` (the log's overflow — [method emit] calls this, and the
## `match_ended` is the one event the faulted log still accepts). A no-op
## once Ended.
## [codeblock]
## engine.fault(MatchRecords.REASON_RESOLUTION_OVERFLOW, steps)
## [/codeblock]
func fault(reason: String, steps: int = 0) -> void:
	assert(MatchRecords.FAULT_REASONS.has(reason), "fault reason '%s' is not one of %s" % [reason, str(MatchRecords.FAULT_REASONS)])
	if _halted():
		return
	if reason == MatchRecords.REASON_RESOLUTION_OVERFLOW:
		emit(&"resolution_overflow", {"steps": steps})
		if _halted():
			return
	_end_match(null, reason)


## The teardown entry `MatchDriver` calls on `Ended` (ADR-0008): releases
## the resolver — `resolver.unbind()` clears its engine reference and the
## registry's evaluators, breaking the engine↔resolver `RefCounted` cycle
## (ADR-0007). Idempotent: the engine already unbinds when the match ends, so
## on an ended match this does nothing; on a live one (an abandoned attempt,
## a teardown test) it unbinds without ending the match, and every later
## `submit` is rejected `MATCH_ENDED` (unlogged, range `[0, 0]`).
## [codeblock]
## if engine.phase() == MatchState.PHASE_ENDED: engine.end_match()
## [/codeblock]
func end_match() -> void:
	if _bound and not _halted():
		_torn_down = true
	_unbind()


## `phase = Ended` (C14): builds the `MatchResult`
## ([method MatchRecords.final_result]; [param winner] a side, or null for a
## fault), stores it as `state.result`, emits it as `match_ended` (the log
## seals on it — its last event), unbinds the resolver, then emits the
## test-only [signal match_ended]. A no-op once Ended.
## When the log refuses that `match_ended` — it was the append that hit
## `max_match_events` — the match is an `event_cap` fault instead (code review
## 2026-11-03): the result is rebuilt as `fault` / `event_cap` / `winner =
## null`, and a log that answered with `log_overflow` (Faulted, ADR-0003
## Decision 8) takes it as its one last event. A log that sealed itself on
## overflow (`TestEventLog`) already holds its own `match_ended(fault)`.
func _end_match(winner: Variant, reason: String) -> void:
	if _halted():
		return
	_state.phase = MatchState.PHASE_ENDED
	var final_health: Dictionary = {}
	for side: String in MatchRecords.SIDES:
		final_health[side] = health(_state.players[side].hero)
	var outcome: Dictionary = MatchRecords.final_result(_state, winner, reason, final_health)
	_state.result = outcome
	if emit(&"match_ended", outcome) < 0:
		outcome = MatchRecords.final_result(_state, null, MatchRecords.REASON_EVENT_CAP, final_health)
		_state.result = outcome
		if _log_faulted():
			emit(&"match_ended", outcome)
	_unbind()
	match_ended.emit(result())


## True when the match log is the production `EventLog` in its Faulted state
## (it appended `log_overflow` and accepts exactly one more event). Read from
## `log.state()`, never inferred from a refused append: `-1` also means sealed.
func _log_faulted() -> bool:
	var log: Variant = _state.log
	return log is EventLog and (log as EventLog).state() == EventLog.State.FAULTED


## `resolver.unbind()` exactly once per bind.
func _unbind() -> void:
	if not _bound:
		return
	_bound = false
	_resolver.unbind()


## True once the match has ended (by a dead hero, `concede`, `turn_cap` or a
## fault): every primitive and engine step is then a no-op, so a fault stops
## the current action without further mutation.
func _halted() -> bool:
	return _state.phase == MatchState.PHASE_ENDED


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
		for zone: String in ["hand", "resolving", "deck", "graveyard"]:
			for card: Dictionary in player[zone]:
				if int(card.instance_id) == entity_id:
					return side
	return ""


## The Card Database definition of [param def_id] (`CardDatabase.card(id)`),
## or `{}` with a warning when there is no database or no such card — the
## primitive that asked is then a no-op (a content bug, not a crash).
func _card_def(def_id: String) -> Dictionary:
	var def: Dictionary = _lookup_def(def_id)
	if def.is_empty():
		push_warning("RulesEngine: no card definition '%s'" % def_id)
	return def


## [param def_id]'s definition, `{}` when there is no database or no such id.
## Asks `has()` before `card()`: `CardDatabase.card()` asserts on an unknown id
## in debug builds (card-database story 006).
func _lookup_def(def_id: String) -> Dictionary:
	if _db == null or not _db.has(def_id):
		return {}
	var def: Variant = _db.card(def_id)
	return def if def is Dictionary else {}


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
	return _lookup_def(str(record.def_id)).get("keywords", []).has(keyword)


## A fresh card instance of [param def_id] into [param side]'s hand, or the
## graveyard on a full hand; one `card_added_to_hand` or `card_burned`.
func _add_to_hand(side: String, def_id: String) -> int:
	var player: Dictionary = _state.players[side]
	var card: Dictionary = MatchRecords.card_instance(_take_entity_id(), def_id, "hand")
	var payload: Dictionary = {"side": side, "instance_id": int(card.instance_id), "card_id": def_id}
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
## triggers the resolver returns join queue Q with `cause_seq`
## [param raise_seq] (the event that raised them); the C10 loop runs after
## the step, never here.
func _raise(point: StringName, ctx: Dictionary, raise_seq: int) -> void:
	if _halted():
		return
	_enqueue(point, _resolver.resolve(point, ctx), raise_seq)


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
		for zone: String in ["hand", "resolving", "deck", "graveyard"]:
			for card: Dictionary in player[zone]:
				if int(card.instance_id) == entity_id:
					return card
	return {}
