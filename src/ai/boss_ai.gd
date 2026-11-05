## The Boss AI (design/gdd/boss-ai.md; ADR-0006, ADR-0002 Decision 4).
##
## Two halves. The load-time half (story 002): the `ai_profiles.json` schema
## knowledge and the two static, pure validators Card Database runs at CR-5 stage
## 7; [ProfileResolver] builds the profile. The planner (story 008): one instance
## per match, whose [method plan_turn] runs the C2 action loop on a
## `RulesEngine.clone()` and returns a [TurnPlan] for the driver to replay;
## [method forecast] (story 011) runs the same loop as a dry run and returns an
## [Intent]. A boss Choice is answered inside the plan, by the [Chooser] that
## [method choose] (story 010) fronts: one its own action raises, on the sandbox, and
## one standing when the plan starts, which it opens by answering (DD-X31). The driver
## runs no separate choose task.
##
## **The planner** reads the sandbox through `legal_commands()`, its derived
## values and, like [Scorer], its `state()`, and mutates only through `submit` on
## that sandbox: no live engine, no live log, no signal, no Node (ADR-0006). Per
## loop pass (C2): `[end_turn]` or the action cap ends the turn; then the lethal
## search, then one action through `collect → score_all → pick`. Modes are
## `NORMAL`, `LETHAL` and, after the search, `DEFENSIVE` (story 009: F6 through
## [ThreatEstimate], re-evaluated on every pass, so a clear drops back to `NORMAL`
## within the turn; the profile's weights are multiplied for that pass only).
##
## **One search per turn, plus one after an abort.** C2's pseudocode calls
## `lethal_search` on every pass, but C3 allows "one more search per turn", F7
## counts `lethal_nodes` once per run, and A7 needs band 1 to record no `LETHAL`
## even when scoring opens the way; C3's "the AI may still stumble into lethal"
## says the same. So a pass searches only while a search is due: the first, and
## one more after `ai_plan_aborted`.
##
## **The forecast** (C8.1, story 011) needs the boss's Main, which a clone taken in
## `PlayerTurn.Main` is not: `legal_commands()` and `submit` serve the side to move.
## So [method forecast] submits the player's `end_turn` on a clone carrying the
## `forecast_<turn>` fork, and the engine's own End and Start steps give it
## `mana_max_by_turn(t_side + 1)`, the C13 thaw and the reset attacks with no write
## to `MatchState`. The Start step also draws, and so may any card the dry run
## plays: the forecast is of the **current** hand and the deck is hidden (C1.3), so
## every card that came from the deck goes back out through the `discard` primitive
## before anything reads it: after the Start step, after each accepted action, and
## at each lethal-search node ([method LethalSearch.drop_unseen]; BAI-011 review D1).
## A one-ply trial keeps its draw, for `f_card`: it reads the count, not the card. An
## effect that reads a drawn card's identity in the same action (an `on_draw` filter,
## `deck_top`, a `deck` Discover) would still see it; no shipped card has one.
##
## **`alternatives`** (C9, review N4): what was scored, best first, at most
## [constant Scorer.ALTERNATIVES_MAX], the pick always among them (A16, Edge
## Cases "one alternative"); `[]` when nothing was scored: a forced `end_turn`
## and every `LETHAL` step (A24, C2).
##
## Validators (ADR-0002 stage-7 calling convention; both registered by `Boot`):
## - [method validate_profiles_config] — **7a**, `call(body, db)`, the config
##   validator for `ai_profiles.json` (`configs.ai_profiles`);
## - [method validate_ai_profile] — **7b**, `call(host_kind, host_id, value, db,
##   configs)`, the record validator for `BossDef.ai_profile` (`ai_profile`),
##   a thin adapter over [method validate_profile_key].
## Both are `static` and allocate their own rows (control manifest: never a
## `RefCounted` validator instance with cached database access). Every row is
## a `ValidationReport` entry `{severity, code, file, record_id, field,
## message}` with severity `error`: CI treats every `E_AI_*` as a failure
## (C10), and at runtime [ProfileResolver] falls back as C10 and the Edge Cases
## say.
##
## The closed code set (C10, Edge Cases) and what maps to which:
## - [constant E_AI_PROFILE_UNKNOWN] — a key that names no profile: a BossDef's
##   `ai_profile`, or a `boss_overrides` entry's `extends`;
## - [constant E_AI_WEIGHT_RANGE] — any numeric value that is missing where
##   required, not a number, non-finite, fractional for an integer knob, or
##   outside its [constant RANGES] row (weights, rules, budgets, `op_values`,
##   `keyword_values`, `choice_preference`, `presentation`, `runtime` timings);
## - [constant E_AI_UNKNOWN_FIELD] — every other schema fault: an unknown key
##   (closed set per section, underscore-prefixed keys included), a missing
##   section or non-numeric field, a wrong container type, an enum value
##   outside its set, `hidden` outside `boss_overrides` (C8.4, D-04), `extends`
##   outside `boss_overrides`;
## - [constant E_AI_OP_UNVALUED] — an op type a loaded card uses with no
##   `op_values` row, once per op type per load.
## Single-thread-only at load; the validators touch no shared state.
class_name BossAI
extends RefCounted

## The DD-T01 config file the profile rows report against.
const PROFILES_FILE: String = "ai_profiles.json"
## The CR-1 definition file holding `BossDef.ai_profile` (record rows).
const BOSSES_FILE: String = "bosses.json"

## A BossDef's `ai_profile`, or an override's `extends`, names no profile (C10, A25).
const E_AI_PROFILE_UNKNOWN: StringName = &"E_AI_PROFILE_UNKNOWN"
## A numeric value is outside its range, non-finite, not a number or absent (C10, A26).
const E_AI_WEIGHT_RANGE: StringName = &"E_AI_WEIGHT_RANGE"
## A key, section, container or enum value outside the F9 schema (C10).
const E_AI_UNKNOWN_FIELD: StringName = &"E_AI_UNKNOWN_FIELD"
## An op type used by a loaded card has no `op_values` row (Edge Cases).
const E_AI_OP_UNVALUED: StringName = &"E_AI_OP_UNVALUED"

## The value ranges, inclusive, each naming the formula or Tuning Knobs row it
## comes from — the only numbers allowed in `src/ai/**` outside normalisers
## (A29). Validation bounds, not knob values: like
## `DataLoader.SCHEMA_VERSION_CURRENT` they cannot come from the file they
## validate. `integral` knobs must be whole numbers (JSON parses every number
## as `float`, ADR-0002). Keys are the F9 field names; `op_value`,
## `keyword_value` and `choice_preference` range every entry of those maps.
const RANGES: Dictionary = {
	"w_board": {"min": 0.0, "max": 5.0, "integral": false, "row": "F1 w_board"},
	"w_face": {"min": 0.0, "max": 5.0, "integral": false, "row": "F1 w_face"},
	"w_self": {"min": 0.0, "max": 5.0, "integral": false, "row": "F1 w_self"},
	"w_trade": {"min": 0.0, "max": 3.0, "integral": false, "row": "F1 w_trade"},
	"w_threat": {"min": 0.0, "max": 5.0, "integral": false, "row": "F1 w_threat"},
	"w_mana": {"min": 0.0, "max": 3.0, "integral": false, "row": "F1 w_mana"},
	"w_card": {"min": 0.0, "max": 3.0, "integral": false, "row": "F1 w_card"},
	"w_over": {"min": 0.0, "max": 3.0, "integral": false, "row": "F1 w_over"},
	"w_heal": {"min": 0.0, "max": 3.0, "integral": false, "row": "F1 w_heal"},
	"w_hp": {"min": 0.0, "max": 2.0, "integral": false, "row": "F1 w_hp"},
	"w_passive": {"min": 0.0, "max": 5.0, "integral": false, "row": "F1 w_passive"},
	"BV_NORM": {"min": 5.0, "max": 20.0, "integral": false, "row": "F1 BV_NORM, THREAT_NORM"},
	"THREAT_NORM": {"min": 5.0, "max": 20.0, "integral": false, "row": "F1 BV_NORM, THREAT_NORM"},
	"trade_ratio": {"min": 0.5, "max": 2.0, "integral": false, "row": "F3 trade_ratio"},
	"tie_epsilon": {"min": 0.0, "max": 0.5, "integral": false, "row": "F8 tie_epsilon"},
	"overextend_cap_aoe": {"min": 2.0, "max": 7.0, "integral": true, "row": "F5 overextend_cap_aoe"},
	"burn_per_mana": {"min": 0.0, "max": 2.0, "integral": false, "row": "F6 burn_per_mana"},
	"defensive_margin": {"min": 0.0, "max": 10.0, "integral": true, "row": "F6 defensive_margin"},
	"lethal_max_nodes": {"min": 10.0, "max": 20000.0, "integral": true, "row": "Tuning Knobs lethal_max_nodes (F7)"},
	"max_evals_per_action": {"min": 10.0, "max": 1000.0, "integral": true, "row": "Tuning Knobs max_evals_per_action (F7)"},
	"max_actions_per_turn": {"min": 10.0, "max": 100.0, "integral": true, "row": "Tuning Knobs max_actions_per_turn (F7)"},
	"op_value": {"min": 0.0, "max": 5.0, "integral": false, "row": "F9 op_values"},
	"keyword_value": {"min": 1.0, "max": 1.5, "integral": false, "row": "F2 keyword_mult"},
	"choice_preference": {"min": 0.0, "max": 1.0, "integral": false, "row": "F9 choice_preference"},
	"action_delay_s": {"min": 0.3, "max": 1.2, "integral": false, "row": "Tuning Knobs presentation.action_delay_s"},
	"max_turn_playback_s": {"min": 6.0, "max": 20.0, "integral": false, "row": "Tuning Knobs presentation.max_turn_playback_s"},
	"intent_banner_s": {"min": 0.2, "max": 0.6, "integral": false, "row": "Tuning Knobs presentation.intent_banner_s"},
	"plan_changed_s": {"min": 0.6, "max": 2.0, "integral": false, "row": "Tuning Knobs presentation.plan_changed_s"},
	"planner_target_ms": {"min": 50.0, "max": 1000.0, "integral": false, "row": "Tuning Knobs planner_target_ms"},
}

## F9 top-level sections of the `config` body, in F9 order; all required.
const TOP_LEVEL_SECTIONS: Array[String] = ["op_values", "keyword_values", "profiles", "bands", "boss_overrides", "presentation", "runtime"]
## F9 Profile sections; `extends` is legal (and required) in `boss_overrides` only.
const PROFILE_SECTIONS: Array[String] = ["weights", "rules", "budgets", "intent_mode", "choice_preference", "synergy_tags"]
## The F9 `boss_overrides` key naming the `profiles` entry an override builds on.
const EXTENDS_KEY: String = "extends"
## The `profiles` entry every resolution starts from (C10).
const DEFAULT_PROFILE: String = "default"
## F1's eleven weights, in F1 order.
const WEIGHT_KEYS: Array[String] = ["w_board", "w_face", "w_self", "w_trade", "w_threat", "w_mana", "w_card", "w_over", "w_heal", "w_hp", "w_passive"]
## F9 `rules` keys, in F9 order.
const RULE_KEYS: Array[String] = ["hero_power", "trade_ratio", "tie_epsilon", "overextend_cap_aoe", "assume_aoe", "defensive", "defensive_margin", "burn_per_mana", "defensive_multipliers", "lethal_search", "BV_NORM", "THREAT_NORM"]
## F9 `rules` enums.
const RULE_ENUMS: Dictionary = {
	"hero_power": ["always", "spare_mana", "never", "value"],
	"lethal_search": ["shallow", "full", "off"],
}
## F9 `rules` booleans.
const RULE_FLAGS: Array[String] = ["assume_aoe", "defensive"]
## F9 `rules.defensive_multipliers {w_*: float}` — one value, replaced whole by a later layer.
const DEFENSIVE_MULTIPLIERS_KEY: String = "defensive_multipliers"
## F7 budget keys (F9 `budgets`).
const BUDGET_KEYS: Array[String] = ["lethal_max_nodes", "max_evals_per_action", "max_actions_per_turn"]
## C8.4 `intent_mode` values, most to least shown.
const INTENT_MODES: Array[String] = ["full", "class_only", "hidden"]
## The `intent_mode` legal only in a `boss_overrides` entry (C8.4, D-04).
const OVERRIDE_ONLY_INTENT: String = "hidden"
## F9 `bands` keys.
const BAND_KEYS: Array[String] = ["1", "2", "3"]
## F9 `presentation` keys (all ranged in [constant RANGES]).
const PRESENTATION_KEYS: Array[String] = ["action_delay_s", "max_turn_playback_s", "intent_banner_s", "plan_changed_s"]
## F9 / ADR-0006 `runtime.planner_mode` values (`PlannerTask` implementations).
const PLANNER_MODES: Array[String] = ["worker", "time_sliced", "immediate"]
## F9 / ADR-0006 `runtime` timing keys: positive finite milliseconds.
const RUNTIME_TIMING_KEYS: Array[String] = ["slice_ms", "replay_budget_ms"]
## The `runtime` enum key.
const PLANNER_MODE_KEY: String = "planner_mode"
## The `runtime` measurement target (Tuning Knobs, DD-X18): validated here and
## read by perf gates and the UI's commit beat. Never a runtime clock: no
## planner or rules code reads it.
const PLANNER_TARGET_KEY: String = "planner_target_ms"
## Card Effects C5 structural ops, valued as the sum of their inner ops (C6):
## each maps to the param keys holding inner `op[]` arrays; `choose_one`
## holds them under `options[].ops`.
const STRUCTURAL_OPS: Dictionary = {
	"conditional": ["then", "else"],
	"repeat": ["ops"],
	"choose_one": ["options"],
}
## C6: ops valued through another op's row.
const VALUED_AS: Dictionary = {"aura": "buff", "modify_value": "buff"}
## CR-3 card `type` values (DD-M08), the lookups the op-coverage check walks.
const CARD_TYPES: Array[String] = ["minion", "spell", "weapon"]
## The stage-7 `configs` key of this file's parsed body.
const CONFIG_NAME: String = "ai_profiles"

## The diagnostic events of a [TurnPlan] (rng-event-log rule 12a).
const EVENT_DECISION: String = "ai_decision"
const EVENT_PLAN_ABORTED: String = "ai_plan_aborted"
const EVENT_FAULT: String = "ai_fault"
## The intent events (rng-event-log §D): the driver appends the first, a [TurnPlan]
## carries the second as its first diagnostic. Neither is flagged `diagnostic`.
const EVENT_INTENT_SHOWN: StringName = &"ai_intent_shown"
const EVENT_INTENT_COMMITTED: StringName = &"ai_intent_committed"
## C9 `ai_decision.kind`.
const KIND_ACTION: String = "action"
const KIND_CHOICE: String = "choice"
## `ai_decision.reason` of a forced `end_turn` (C2; A24, A27).
const REASON_ONLY_MOVE: String = "only_move"
const REASON_ACTION_CAP: String = "action_cap"
## `ai_fault.reason` (Edge Cases "Legality and the command loop", States `Faulted`).
const FAULT_NO_LEGAL_COMMANDS: String = "no_legal_commands"
const FAULT_END_TURN_REJECTED: String = "end_turn_rejected"
## The side's own Choice could not be answered: no option, or the sandbox refused it.
const FAULT_CHOICE_UNANSWERED: String = "choice_unanswered"
## `ai_plan_aborted.reason` (C3): a step no longer legal, one the sandbox
## rejected, or a plan that ran out with the player alive.
const ABORT_DIVERGED: String = "diverged"
const ABORT_REJECTED: String = "rejected"
const ABORT_NOT_LETHAL: String = "not_lethal"
## C8.4 `telegraph_mode` values (Meta Progression M9, DD-X03).
const TELEGRAPH_FULL: String = "full"
const TELEGRAPH_BRIEF: String = "brief"
const TELEGRAPH_OFF: String = "off"
## C8.4 `full > class_only ≡ brief > hidden ≡ off`: each setting's place in the
## `effective_mode` order.
const TELEGRAPH_AS_MODE: Dictionary = {
	TELEGRAPH_FULL: Intent.MODE_FULL,
	TELEGRAPH_BRIEF: Intent.MODE_CLASS_ONLY,
	TELEGRAPH_OFF: Intent.MODE_HIDDEN,
}
## C2: rejected commands in one turn before `end_turn` is forced. A guard on a
## state that cannot arise single-threaded (A23), not a tuning knob.
const MAX_REJECTIONS: int = 3

# Profile-entry contexts for `_check_profile`.
enum _Context { PROFILE, BAND, OVERRIDE }

## The [PlannerTask] of a [method plan_turn] called with none: never yields.
class _NoYield:
	extends PlannerTask

	func start(work: Callable) -> void:
		_result = work.call()
		return

	func poll() -> bool:
		return true


## The working state of one [method plan_turn]: C2's locals, and the keys the next
## `ai_decision` picks up.
class _Turn:
	var sandbox: RulesEngine
	var planner: PlannerTask
	var side: String
	## Where a tie or a Choice draws: the `ai_<floor>` stream, or in a forecast a copy
	## of its fork (C8.1).
	var stream: RngStream
	## The turn's `sim_<turn>` fork (C4), shared by every sandbox of the turn; in a
	## forecast the `forecast_<turn>` fork.
	var sim: RngStream = null
	var plan: TurnPlan = TurnPlan.new()
	var mode: StringName = Scorer.MODE_NORMAL
	var actions: int = 0
	var rejections: int = 0
	## The exact commands rejected this turn (Edge Cases).
	var excluded: Array = []
	var searches_due: int = 1
	var aborted: bool = false
	var finished: bool = false
	## Keys for the next `ai_decision`: the last search's result, a mode change.
	var note: Dictionary = {}
	## A forecast's undrawn deck, as instance ids ([method LethalSearch.drop_unseen]);
	## empty in a real plan, where a draw is real. A search draws on neither: it gets
	## [method _deck_ids] in both.
	var unseen: Array = []
	## `{entity_id: attack}` of the side's characters when the plan began: C8.3's
	## "attackers that exist now", at the attack they have now.
	var attackers: Dictionary = {}

	func _init(engine: RulesEngine, task: PlannerTask, own: String, draws_from: RngStream) -> void:
		sandbox = engine
		planner = task
		side = own
		stream = draws_from


## The `ai_decision {kind: choice}` of the last [method choose]: `choose` itself
## returns the index alone (C1.4), and [method plan_turn] folds it into its own
## diagnostics.
var last_choice: Dictionary = {}
## The forecast the driver last told this AI of ([method note_forecast]), until a
## plan commits against it (States `Idle`). A stale forecast never gets here.
var last_forecast: Intent = null

var _boss_def: Dictionary = {}
var _profile: Dictionary = {}
var _band: int = 0
var _ai_stream: RngStream = null
var _log: Variant = null
var _db: Variant = null
var _op_values: Dictionary = {}
var _picker: CandidateSet = null
var _scorer: Scorer = null
var _lethal: LethalSearch = null
## C1.3: the one thing the AI remembers across turns, and how far it has read.
var _aoe_seen: bool = false
var _log_cursor: int = 0
## C8.4: absent at MVP → `full`. Written only when no task is live (ADR-0008
## Decision 7), so it takes no lock.
var _telegraph_mode: String = TELEGRAPH_FULL


## C1.1, built once per match. [param ai_stream] is the injected `ai_<floor>`
## stream; [param log] the match log, read on the main thread for `card_played`
## alone (C1.3) and never handed to a worker; [param db] and
## [param keyword_values] (`ai_profiles.keyword_values`) serve the [Scorer] and
## [CandidateSet], which the C1.1 list leaves out.
## [codeblock]
## var ai := BossAI.new(boss_def, profile, band, config.rng_ai, body.op_values, config.log, db, body.keyword_values)
## [/codeblock]
func _init(boss_def: Dictionary, resolved_profile: Dictionary, band: int, ai_stream: RngStream, op_values: Dictionary, log: Variant, db: Variant, keyword_values: Dictionary) -> void:
	_boss_def = boss_def
	_profile = resolved_profile
	_band = band
	_ai_stream = ai_stream
	_log = log
	_db = db
	_op_values = op_values
	_picker = CandidateSet.new(db, op_values, resolved_profile.synergy_tags)
	_scorer = Scorer.new(db, keyword_values, op_values)
	_lethal = LethalSearch.new(db, _picker)


## The `ai_profiles` config validator (CR-5 stage **7a**, `call(body, db)`;
## ADR-0002 Decision 4), registered by `Boot` as `configs.ai_profiles`.
## Checks the whole F9 schema of [param body] (the parsed `config` object) —
## closed key sets per section, enums, [constant RANGES], `hidden` only in
## `boss_overrides`, every override's `extends`, `profiles.default` carrying
## every weight, rule and `intent_mode`, every band carrying every budget, and
## `runtime {planner_mode, slice_ms, replay_budget_ms, planner_target_ms}` — then runs
## [method validate_op_coverage] over the cards [param db] can list.
## [param db] is the `CardDatabase` in `Loading` (stage-7 lookups, ADR-0002
## Decision 4) or `null`; it is asked only for `cards_by_type(type)` per
## [constant CARD_TYPES], and only when it has that method (card-database
## story 006 adds it; until then the op check sees no cards).
## Returns `[]` for a valid body. Static and pure: it reads its arguments only.
## [codeblock]
## var rows: Array = BossAI.validate_profiles_config(db_body, null)
## rows.is_empty()   # true for the shipped file (story 003)
## [/codeblock]
static func validate_profiles_config(body: Dictionary, db: Variant = null) -> Array:
	var rows: Array[Dictionary] = []
	for key: Variant in body:
		if not TOP_LEVEL_SECTIONS.has(key):
			rows.append(_row(E_AI_UNKNOWN_FIELD, null, str(key), "unknown section `%s` (F9: %s)" % [key, ", ".join(TOP_LEVEL_SECTIONS)]))
	for section: String in TOP_LEVEL_SECTIONS:
		if not body.has(section):
			rows.append(_row(E_AI_UNKNOWN_FIELD, null, section, "missing section `%s` (F9)" % section))
	_check_number_map(rows, body, "op_values", "op_value")
	_check_number_map(rows, body, "keyword_values", "keyword_value")
	var profiles: Dictionary = {}
	if body.has("profiles"):
		if body.profiles is Dictionary:
			profiles = body.profiles
			_check_profiles(rows, profiles)
		else:
			rows.append(_row(E_AI_UNKNOWN_FIELD, null, "profiles", "`profiles` must be an object"))
	if body.has("bands"):
		if body.bands is Dictionary:
			_check_bands(rows, body.bands)
		else:
			rows.append(_row(E_AI_UNKNOWN_FIELD, null, "bands", "`bands` must be an object"))
	if body.has("boss_overrides"):
		if body.boss_overrides is Dictionary:
			for boss_id: Variant in body.boss_overrides:
				_check_profile(rows, "boss_overrides.%s" % boss_id, body.boss_overrides[boss_id], _Context.OVERRIDE, profiles)
		else:
			rows.append(_row(E_AI_UNKNOWN_FIELD, null, "boss_overrides", "`boss_overrides` must be an object"))
	_check_presentation(rows, body)
	_check_runtime(rows, body)
	var op_values: Variant = body.get("op_values")
	if op_values is Dictionary:
		rows.append_array(validate_op_coverage(op_values, _loaded_cards(db)))
	return rows


## The `BossDef.ai_profile` record validator (CR-5 stage **7b**,
## `call(host_kind, host_id, value, db, configs)`; ADR-0002 Decision 4),
## registered by `Boot` as `ai_profile`. [param value] is the BossDef's
## `ai_profile`; it must name a `profiles` or `boss_overrides` key of
## `configs["ai_profiles"]`. A missing or non-string value, an unknown key, or
## an `ai_profiles` body absent from [param configs] (the file failed 7a) is
## [constant E_AI_PROFILE_UNKNOWN] with `record_id` [param host_id] — never a
## silent pass. [param _db] is the 7b calling convention and unused.
## [codeblock]
## BossAI.validate_ai_profile(&"boss", "boss_x", "does_not_exist", db, configs)[0].code
## # &"E_AI_PROFILE_UNKNOWN" (A25)
## [/codeblock]
static func validate_ai_profile(host_kind: StringName, host_id: String, value: Variant, _db: Variant, configs: Dictionary) -> Array:
	var body: Variant = configs.get(CONFIG_NAME)
	var rows: Array = []
	if not body is Dictionary:
		rows.append(_row(E_AI_PROFILE_UNKNOWN, null, "ai_profile",
			"%s `%s` names ai_profile %s, but no valid `%s` body reached stage 7b; it cannot be resolved" % [host_kind, host_id, str(value), PROFILES_FILE]))
	else:
		rows = validate_profile_key(value, body)
	for row: Dictionary in rows:
		row.file = BOSSES_FILE
		row.record_id = host_id
	return rows


## The pure core of [method validate_ai_profile] (ADR-0002's
## `validate_profile_key(key, profiles)`): `[]` when [param key] is a String
## naming a `profiles` or `boss_overrides` entry of [param config] (the parsed
## `ai_profiles` body), else one [constant E_AI_PROFILE_UNKNOWN] row (`file`
## `bosses.json`, `record_id` null, `field` `ai_profile`).
## [codeblock]
## BossAI.validate_profile_key("aggro", body)   # []
## [/codeblock]
static func validate_profile_key(key: Variant, config: Dictionary) -> Array:
	var profiles: Dictionary = config.get("profiles") if config.get("profiles") is Dictionary else {}
	var overrides: Dictionary = config.get("boss_overrides") if config.get("boss_overrides") is Dictionary else {}
	if key is String and (profiles.has(key) or overrides.has(key)):
		return []
	var found: String = "missing" if key == null else "`%s`" % str(key)
	var row: Dictionary = _row(E_AI_PROFILE_UNKNOWN, null, "ai_profile",
		"ai_profile %s names no `profiles` or `boss_overrides` key of %s; the boss plays `default` with its band overlay" % [found, PROFILES_FILE])
	row.file = BOSSES_FILE
	return [row]


## The Edge Cases' "op type with no `op_values` row" check: every op name
## reached in the `effects[].ops[]` of [param cards] (CR-3 records), inner ops
## of the [constant STRUCTURAL_OPS] included and the structural ops themselves
## excluded, valued through [constant VALUED_AS] (`aura`, `modify_value` →
## `buff`), that has no row in [param op_values]. One
## [constant E_AI_OP_UNVALUED] row per op type (`field` `op_values.<op>`), in
## op-name order; `[]` when every op is valued.
## [codeblock]
## BossAI.validate_op_coverage({"damage": 1.0}, [card_using_discard])[0].field   # "op_values.discard"
## [/codeblock]
static func validate_op_coverage(op_values: Dictionary, cards: Array) -> Array:
	var first_user: Dictionary = {}  # op type → first card id using it
	for card: Variant in cards:
		if not card is Dictionary or not card.get("effects") is Array:
			continue
		for effect: Variant in card.effects:
			if effect is Dictionary and effect.get("ops") is Array:
				_collect_unvalued(effect.ops, op_values, str(card.get("id")), first_user)
	var names: Array = first_user.keys()
	names.sort()
	var rows: Array[Dictionary] = []
	for op_name: String in names:
		rows.append(_row(E_AI_OP_UNVALUED, null, "op_values.%s" % op_name,
			"op `%s` (first used by `%s`) has no op_values row; Boss AI values it at the C6 fallback" % [op_name, first_user[op_name]]))
	return rows


## Whether [param value] is a JSON number (`int` or `float`, never `bool`).
static func is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


## Why [param value] cannot be used for the [constant RANGES] row
## [param range_key] as given — `""` when it is a finite number, whole if the
## row is integral, inside the row's bounds. `"out_of_range"` is the only
## reason [ProfileResolver] repairs (by clamping); the others make it keep the
## earlier layer's value.
## [codeblock]
## BossAI.range_problem("w_face", 9.0)   # "out_of_range"
## [/codeblock]
static func range_problem(range_key: String, value: Variant) -> String:
	if not is_number(value):
		return "not_a_number"
	var number: float = float(value)
	if not is_finite(number):
		return "not_finite"
	var bounds: Dictionary = RANGES[range_key]
	if bounds.integral and number != floorf(number):
		return "not_whole"
	if number < bounds.min or number > bounds.max:
		return "out_of_range"
	return ""


# --- the planner (story 008) ------------------------------------------------------

## The task body for one boss turn (ADR-0006 erratum 2026-11-03: built here so
## `match_driver.gd` stays `await`-free; `work.call()` is the dynamic path). Called
## on the main thread, it first reads the public log, so the worker never touches
## it. [param planner] is required, and is the task that will run the Callable:
## `checkpoint()` yields on it, so without it a time-sliced task would run the whole
## plan inside `start()`. The caller owns [param sandbox] and ends
## it once the plan is back.
## [codeblock]
## task.start(boss_ai.plan_task(sandbox, task))
## [/codeblock]
func plan_task(sandbox: RulesEngine, planner: PlannerTask) -> Callable:
	_read_public_log()
	return func() -> Variant: return await plan_turn(sandbox, planner)


## The task body for one forecast: [method plan_task]'s shape, and like it called on
## the main thread and given the running task, required (code review 2026-11-04,
## BAI-008 D-1). [param sandbox] is a clone taken at `PlayerTurn.Main`; the caller
## owns it and ends it once the [Intent] is back.
## [codeblock]
## task.start(boss_ai.forecast_task(sandbox, task))
## [/codeblock]
func forecast_task(sandbox: RulesEngine, planner: PlannerTask) -> Callable:
	_read_public_log()
	return func() -> Variant: return await forecast(sandbox, planner)


## The C2 action loop on [param sandbox] (a `RulesEngine.clone()`, never the live
## engine) at its own Main: returns the [TurnPlan]. A **coroutine** (ADR-0006
## erratum): every caller awaits it. Forks `sim_<turn>` once, for every sandbox of
## the turn (C4), and leaves the root's `rng_match` to move only by what it accepts,
## or the replay would diverge.
##
## A Choice standing on [param sandbox] is answered first, for the side it names, and
## the loop runs only if that reaches the side's Main (DD-X31). So a boss Choice from a
## Start step opens the turn's plan, and one raised on the player's turn gives a plan of
## the `choose` alone, with no intent committed: the turn is not the boss's. Anywhere
## else outside the side-to-move's Main the plan is empty. The caller owns
## [param sandbox] and ends it with `end_match()`. With no [param planner] nothing
## yields: for tests and the harness, never a task body.
## [codeblock]
## var plan: TurnPlan = await boss_ai.plan_turn(sandbox)
## [/codeblock]
func plan_turn(sandbox: RulesEngine, planner: PlannerTask = null) -> TurnPlan:
	var pending: Variant = sandbox.pending_choice()
	var side: String = str(pending.side) if pending is Dictionary else String(sandbox.active_side())
	var turn: _Turn = _Turn.new(sandbox, planner if planner != null else _NoYield.new(), side, _ai_stream)
	turn.plan.mode_trace.append(turn.mode)
	var scratch: Variant = sandbox.state().log
	var scratch_start: int = int(scratch.size())
	if pending is Dictionary:
		await turn.planner.checkpoint()
		_answer_choices(turn)
	if _is_own_main(turn):
		var draws_before: int = _ai_stream.draws
		turn.sim = _ai_stream.fork(TieBreak.sim_label(int(sandbox.state().turn)))
		turn.plan.ai_draws += _ai_stream.draws - draws_before
		await _run_loop(turn)
		_commit_intent(turn)
	turn.plan.expected_checksum = TurnPlan.checksum(scratch.events_since(scratch_start))
	return turn.plan


## C1.4 / C8.1: what the boss would do next turn, as an [Intent], from
## [param sandbox], a clone taken at the opponent's Main: the C2 loop as a dry run
## on its own clone, as if [param side]'s turn had begun (see the class doc). A
## **coroutine** like [method plan_turn]. Every draw comes from
## `ai_stream.fork("forecast_<turn>")`, working on copies, so the only live draw is
## that label's first fork and a second forecast of the turn gives the same answer.
## Stores nothing: the driver calls [method note_forecast] if it keeps the result.
## Null outside the opponent's Main (States: `Idle` guard). The caller owns
## [param sandbox]. With no [param planner] nothing yields: for tests, never a task
## body.
## [codeblock]
## var intent: Intent = await boss_ai.forecast(sandbox)
## [/codeblock]
func forecast(sandbox: RulesEngine, planner: PlannerTask = null, side: String = MatchRecords.SIDE_BOSS) -> Intent:
	if sandbox.phase() != MatchState.PHASE_MAIN or String(sandbox.active_side()) != Scorer.other_side(side):
		return null
	var fork: RngStream = _ai_stream.fork(TieBreak.forecast_label(int(sandbox.state().turn)))
	var dry_run: RulesEngine = sandbox.clone(fork.copy())
	var turn: _Turn = _Turn.new(dry_run, planner if planner != null else _NoYield.new(), side, fork.copy())
	turn.sim = fork
	turn.plan.mode_trace.append(turn.mode)
	_begin_own_turn(turn)
	await _run_loop(turn)
	dry_run.end_match()
	return intent_from_plan(turn.plan)


## The dominant action of [param plan] as an [Intent] (C8.1, C8.3): the first step
## of a proven lethal, else the highest-scoring action, the earlier on a tie, else
## `pass`. `amount` sums the plan's face damage from the attackers that existed when
## it began, for `attack_face` and `lethal`. Carries [method effective_mode].
## [codeblock]
## boss_ai.intent_from_plan(plan).intent_key   # "attack_face"
## [/codeblock]
func intent_from_plan(plan: TurnPlan) -> Intent:
	var dominant: Dictionary = _dominant_row(plan.intent_rows)
	var key: String = Intent.KEY_PASS
	if not dominant.is_empty():
		key = Intent.KEY_LETHAL if bool(dominant.lethal) else str(dominant.key)
	var amount: Variant = null
	if key == Intent.KEY_ATTACK_FACE or key == Intent.KEY_LETHAL:
		amount = 0
		for row: Dictionary in plan.intent_rows:
			amount += int(row.face)
	return Intent.new(str(_boss_def.get("id")), key, dominant.get("target_id"), amount, effective_mode())


## Keeps [param intent] as the forecast the next plan commits against: the driver
## calls it on the main thread for a forecast whose premise held (ADR-0008 Decision
## 4), never for a stale one.
func note_forecast(intent: Intent) -> void:
	last_forecast = intent


## Applies the player's `telegraph_mode` [param mode], one of
## [constant TELEGRAPH_AS_MODE]. The driver calls it only when no task is live
## (ADR-0008 Decision 7). An unknown value changes nothing.
func set_telegraph_mode(mode: String) -> void:
	if not TELEGRAPH_AS_MODE.has(mode):
		push_warning("BossAI.set_telegraph_mode: unknown mode `%s`" % mode)
		return
	_telegraph_mode = mode


## C8.4 `min(intent_mode, telegraph_mode)` over `full > class_only ≡ brief > hidden
## ≡ off`.
## [codeblock]
## boss_ai.set_telegraph_mode(BossAI.TELEGRAPH_BRIEF)
## boss_ai.effective_mode()   # "class_only" on a `full` boss
## [/codeblock]
func effective_mode() -> String:
	var boss_rank: int = Intent.MODES.find(str(_profile.get("intent_mode", Intent.MODE_FULL)))
	var player_rank: int = Intent.MODES.find(str(TELEGRAPH_AS_MODE[_telegraph_mode]))
	return Intent.MODES[mini(boss_rank, player_rank)]


## C1.4 for the sim harness only, on the calling thread: [method plan_turn] on a
## clone of [param engine], then the immediate replay through `submit`, each
## diagnostic ahead of its command through `engine.emit`. Production replays in
## `MatchDriver.tick()`. A coroutine; never hand it a live engine on a worker.
## [codeblock]
## await boss_ai.play_turn(engine)
## [/codeblock]
func play_turn(engine: RulesEngine, planner: PlannerTask = null) -> void:
	_read_public_log()
	var sandbox: RulesEngine = engine.clone()
	var plan: TurnPlan = await plan_turn(sandbox, planner)
	sandbox.end_match()
	for index: int in plan.commands.size() + 1:
		for diagnostic: Dictionary in plan.diagnostics_before(index):
			@warning_ignore("return_value_discarded")
			engine.emit(StringName(str(diagnostic[TurnPlan.EVENT_KEY])), TurnPlan.event_payload(diagnostic))
		if index < plan.commands.size():
			@warning_ignore("return_value_discarded")
			engine.submit(plan.commands[index])


## C1.4 / C7: the option the boss takes for the `ChoiceRequest` [param request]
## on [param sandbox], a clone (ADR-0006: a task body like the others). Pure over
## the clone; a tie takes one draw from the `ai_<floor>` stream. The caller submits
## `choose{issuer: boss, option_index}`. [param mode] is logged in
## [member last_choice]. Returns [constant Chooser.NO_OPTION] for a request it
## must not answer. The driver has no use for it: a plan answers every Choice
## (DD-X31).
## [codeblock]
## var index: int = boss_ai.choose(sandbox, sandbox.pending_choice())
## engine.submit(MatchRecords.choose(MatchRecords.SIDE_BOSS, index))
## [/codeblock]
func choose(sandbox: RulesEngine, request: Dictionary, mode: StringName = Scorer.MODE_NORMAL) -> int:
	return _choose_as(sandbox, request, MatchRecords.SIDE_BOSS, _ai_stream, mode)


## [method choose] for [param side], a tie drawing from [param stream].
func _choose_as(sandbox: RulesEngine, request: Dictionary, side: String, stream: RngStream, mode: StringName) -> int:
	var decision: Dictionary = Chooser.choose(sandbox, request, _profile, _op_values, stream, _db, side, mode)
	last_choice = decision.diagnostic
	return int(decision.index)


## The C2 loop on [param turn] from the side's Main to the end of its turn. A
## coroutine.
func _run_loop(turn: _Turn) -> void:
	_note_attackers(turn)
	while _is_own_main(turn) and not turn.finished:
		await _plan_pass(turn)
	var outcome: Variant = turn.sandbox.result()
	if outcome is Dictionary and str(outcome.get("result")) == MatchRecords.RESULT_FAULT:
		_record(turn, _fault(str(outcome.get("reason"))))


## Takes the forecast's clone to the side's Main (see the class doc): notes the
## undrawn deck, then the opponent's `end_turn`, and what follows any action.
func _begin_own_turn(turn: _Turn) -> void:
	turn.unseen = _deck_ids(turn)
	if turn.sandbox.submit(MatchRecords.end_turn(Scorer.other_side(turn.side))).accepted:
		_settle(turn)


## The side's deck on the sandbox now, as instance ids: what a lethal search may not
## read in any plan (C1.3), and all a forecast may not keep.
func _deck_ids(turn: _Turn) -> Array:
	var deck: Array = turn.sandbox.state().players[turn.side].deck
	return deck.map(func(card: Dictionary) -> int: return int(card.instance_id))


## What follows an accepted action: the Choices the side owes, then, in a forecast,
## the cards that action drew.
func _settle(turn: _Turn) -> void:
	_answer_choices(turn)
	LethalSearch.drop_unseen(turn.sandbox, turn.side, turn.unseen)


## Records the side's characters and their attack (see [member _Turn.attackers]).
func _note_attackers(turn: _Turn) -> void:
	var player: Dictionary = turn.sandbox.state().players[turn.side]
	turn.attackers[int(player.hero.entity_id)] = turn.sandbox.attack(player.hero)
	for minion: Dictionary in player.board:
		turn.attackers[int(minion.entity_id)] = turn.sandbox.attack(minion)


## C2 / C8.2: the plan's intent as its first diagnostic, routed before its first
## command. Answers [member last_forecast] and spends it, so a later turn whose
## forecast was discarded is not compared with an old one: with no forecast `kept`
## is false.
func _commit_intent(turn: _Turn) -> void:
	var intent: Intent = intent_from_plan(turn.plan)
	var kept: bool = last_forecast != null and last_forecast.intent_key == intent.intent_key
	last_forecast = null
	var diagnostic: Dictionary = intent.committed_payload(kept)
	diagnostic[TurnPlan.EVENT_KEY] = String(EVENT_INTENT_COMMITTED)
	diagnostic[TurnPlan.COMMAND_INDEX_KEY] = 0
	turn.plan.diagnostics.insert(0, diagnostic)


## The row of [param rows] an [Intent] names: the first proven lethal step, else the
## best score, the earlier on a tie; `{}` for none.
static func _dominant_row(rows: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	for row: Dictionary in rows:
		if bool(row.lethal):
			return row
		if best.is_empty() or float(row.score) > float(best.score):
			best = row
	return best


## The [member TurnPlan.intent_rows] row of [param command], read before it is
## submitted, while its hand index still names its card.
func _intent_row(turn: _Turn, command: Dictionary, score: float) -> Dictionary:
	var state: MatchState = turn.sandbox.state()
	var enemy: Dictionary = state.players[Scorer.other_side(turn.side)]
	var enemy_minions: Array = (enemy.board as Array).map(func(minion: Dictionary) -> int: return int(minion.entity_id))
	var def: Variant = null
	if str(command.type) == MatchRecords.CMD_PLAY_CARD:
		def = _db.card(str(state.players[turn.side].hand[int(command.hand_index)].def_id))
	var key: String = Intent.key_of(command, def, int(enemy.hero.entity_id), enemy_minions)
	var face: int = int(turn.attackers.get(command.get("attacker_id"), 0)) if key == Intent.KEY_ATTACK_FACE else 0
	return {"key": key, "target_id": Intent.named_target(key, command), "face": face, "score": score, "lethal": false}


## One pass of the C2 loop. A coroutine.
func _plan_pass(turn: _Turn) -> void:
	var cmds: Array = _open(turn, turn.sandbox.legal_commands())
	if cmds.is_empty():
		_record(turn, _fault(FAULT_NO_LEGAL_COMMANDS))
		_end_turn(turn)
		return
	var cap: int = int(_profile.budgets.max_actions_per_turn)
	var only_move: bool = cmds.size() == 1 and str(cmds[0].type) == MatchRecords.CMD_END_TURN
	if only_move or turn.actions >= cap:
		_decide_end_turn(turn, REASON_ONLY_MOVE if only_move else REASON_ACTION_CAP)
		return
	if turn.mode == Scorer.MODE_LETHAL:
		_enter_mode(turn, Scorer.MODE_NORMAL)
	if turn.searches_due > 0:
		turn.searches_due -= 1
		var budgets: Dictionary = (_profile.budgets as Dictionary).duplicate()
		budgets.max_actions_per_turn = cap - turn.actions
		var steps: Variant = await _lethal.search(turn.sandbox, _profile, budgets, turn.planner, turn.sim, _deck_ids(turn))
		_note_search(turn)
		if steps != null:
			_enter_mode(turn, Scorer.MODE_LETHAL)
			await _execute_lethal(turn, steps)
			return
	_enter_mode(turn, _scoring_mode(turn))
	var candidates: Array = _open(turn, _picker.collect(turn.sandbox, _profile, _profile.budgets))
	var context: Dictionary = {"aoe_seen": _aoe_seen, Scorer.CONTEXT_SIM_STREAM: turn.sim, Scorer.CONTEXT_SIDE: turn.side}
	var scored: Array = await _scorer.score_all(turn.sandbox, candidates, _scoring_profile(turn.mode), turn.mode, context, turn.planner)
	var picked: Dictionary = TieBreak.pick(scored, float(_profile.rules.tie_epsilon), turn.stream)
	turn.plan.ai_draws += int(picked.draws)
	var decision: Dictionary = _decision(turn, picked.chosen.command, _alternatives(scored, picked.chosen))
	decision["tie_set_size"] = (picked.ties as Array).size()
	if scored.any(func(entry: Dictionary) -> bool: return bool(entry.sim_overflow)):
		decision["sim_overflow"] = true
	_submit_action(turn, picked.chosen.command, decision, float(picked.chosen.score))


## C2 / F6: the mode this pass scores in. Lethal was checked first.
func _scoring_mode(turn: _Turn) -> StringName:
	if bool(_profile.rules.defensive) and ThreatEstimate.defensive(turn.sandbox, _profile.rules, turn.side):
		return Scorer.MODE_DEFENSIVE
	return Scorer.MODE_NORMAL


## The profile [param mode] scores with: DEFENSIVE's is a copy whose `weights` are
## multiplied by `rules.defensive_multipliers` (States "Modes"). A weight with no
## multiplier stands.
func _scoring_profile(mode: StringName) -> Dictionary:
	if mode != Scorer.MODE_DEFENSIVE:
		return _profile
	var weights: Dictionary = (_profile.weights as Dictionary).duplicate()
	var multipliers: Dictionary = _profile.rules.defensive_multipliers
	for key: String in multipliers:
		weights[key] = float(weights[key]) * float(multipliers[key])
	var scoring: Dictionary = _profile.duplicate()
	scoring.weights = weights
	return scoring


## Submits the scored [param command]. A rejection is logged on [param decision],
## excludes that exact command, and after [constant MAX_REJECTIONS] forces
## `end_turn` (C2); a rejected `end_turn` is `Faulted`. [param score] is the
## command's, for the intent.
func _submit_action(turn: _Turn, command: Dictionary, decision: Dictionary, score: float) -> void:
	var row: Dictionary = _intent_row(turn, command, score)
	var result: Dictionary = turn.sandbox.submit(command.duplicate(true))
	turn.actions += 1
	if result.accepted:
		if str(command.type) != MatchRecords.CMD_END_TURN:
			turn.plan.intent_rows.append(row)
		_accept(turn, command, decision)
		_settle(turn)
		return
	decision["rejection"] = str(result.rejection.code)
	_record(turn, decision)
	if str(command.type) == MatchRecords.CMD_END_TURN:
		_record(turn, _fault(FAULT_END_TURN_REJECTED))
		turn.finished = true
		return
	turn.excluded.append(command)
	turn.rejections += 1
	if turn.rejections >= MAX_REJECTIONS:
		_decide_end_turn(turn, "")


## The forced `end_turn` of C2 with its decision ([param reason] empty for the
## rejection cap, which C2's closed `reason` set does not name).
func _decide_end_turn(turn: _Turn, reason: String) -> void:
	var decision: Dictionary = _decision(turn, MatchRecords.end_turn(turn.side), [])
	if not reason.is_empty():
		decision["reason"] = reason
	_record(turn, decision)
	_end_turn(turn)


## Submits `end_turn` once and stops the loop whatever came of it: the planner
## never spins (Edge Cases).
func _end_turn(turn: _Turn) -> void:
	var command: Dictionary = MatchRecords.end_turn(turn.side)
	turn.finished = true
	if turn.sandbox.submit(command.duplicate(true)).accepted:
		turn.plan.commands.append(command)
		_answer_choices(turn)
	else:
		_record(turn, _fault(FAULT_END_TURN_REJECTED))


## C3: runs [param steps] on the sandbox, one `ai_decision` each, a coroutine with a
## checkpoint ahead of each, so a time-sliced task yields inside a long lethal (A30). A
## step `legal_commands()` no longer lists (a Taunt appeared, the target is gone) or
## the sandbox rejects, or a plan that ends with the player alive, is a divergence: the
## search's randomness is only an estimate of the sandbox's.
func _execute_lethal(turn: _Turn, steps: Array) -> void:
	var first_row: int = turn.plan.intent_rows.size()
	for index: int in steps.size():
		await turn.planner.checkpoint()
		if not _is_own_main(turn):
			return
		var step: Dictionary = steps[index]
		if not turn.sandbox.legal_commands().has(step):
			_abort_plan(turn, ABORT_DIVERGED, index)
			return
		var decision: Dictionary = _decision(turn, step, [])
		var row: Dictionary = _intent_row(turn, step, -INF)
		var result: Dictionary = turn.sandbox.submit(step.duplicate(true))
		turn.actions += 1
		if not result.accepted:
			decision["rejection"] = str(result.rejection.code)
			_record(turn, decision)
			turn.excluded.append(step)
			turn.rejections += 1
			_abort_plan(turn, ABORT_REJECTED, index)
			return
		turn.plan.intent_rows.append(row)
		_accept(turn, step, decision)
		_settle(turn)
	if _is_own_main(turn):
		_abort_plan(turn, ABORT_NOT_LETHAL, steps.size())
		return
	for index: int in range(first_row, turn.plan.intent_rows.size()):
		turn.plan.intent_rows[index].lethal = true


## Discards the plan: `ai_plan_aborted`, and the one more search C3 allows.
func _abort_plan(turn: _Turn, reason: String, step: int) -> void:
	_record(turn, {
		TurnPlan.EVENT_KEY: EVENT_PLAN_ABORTED,
		"reason": reason,
		"at_step": step,
		TurnPlan.DIAGNOSTIC_KEY: true,
	})
	if not turn.aborted:
		turn.aborted = true
		turn.searches_due += 1


## Answers boss-side Choices on the sandbox like [method choose] (C2's inner
## `while`): the root sandbox, so a tie draws from the turn's stream, in a real plan
## the live `ai_<floor>` stream, counted in `TurnPlan.ai_draws` (C9), and the command
## is replayed like any other. A Choice for the other side is theirs, and stops here. A
## Choice of its own it cannot answer ends the plan with a fault (Edge Cases: the
## planner never spins); the driver then closes it.
func _answer_choices(turn: _Turn) -> void:
	while turn.sandbox.phase() == MatchState.PHASE_CHOICE:
		var pending: Variant = turn.sandbox.pending_choice()
		if not pending is Dictionary or str(pending.side) != turn.side:
			return
		var index: int = _choose_as(turn.sandbox, pending, turn.side, turn.stream, turn.mode)
		if index == Chooser.NO_OPTION:
			_give_up_choice(turn)
			return
		var command: Dictionary = MatchRecords.choose(turn.side, index)
		var decision: Dictionary = _decision(turn, command, last_choice.alternatives)
		decision["kind"] = KIND_CHOICE
		decision["draws"] = int(last_choice.draws)
		turn.plan.ai_draws += int(last_choice.draws)
		var result: Dictionary = turn.sandbox.submit(command.duplicate(true))
		if not result.accepted:
			decision["rejection"] = str(result.rejection.code)
			_record(turn, decision)
			_give_up_choice(turn)
			return
		_accept(turn, command, decision)


## Records the fault and stops the loop.
func _give_up_choice(turn: _Turn) -> void:
	_record(turn, _fault(FAULT_CHOICE_UNANSWERED))
	turn.finished = true


func _accept(turn: _Turn, command: Dictionary, decision: Dictionary) -> void:
	_record(turn, decision)
	turn.plan.commands.append(command.duplicate(true))


## An `ai_decision` payload (C9). Takes the pending `_Turn.note`.
func _decision(turn: _Turn, chosen: Dictionary, alternatives: Array) -> Dictionary:
	var decision: Dictionary = {
		TurnPlan.EVENT_KEY: EVENT_DECISION,
		"kind": KIND_ACTION,
		"chosen": chosen.duplicate(true),
		"mode": String(turn.mode),
		"alternatives": alternatives,
		TurnPlan.DIAGNOSTIC_KEY: true,
	}
	decision.merge(turn.note, true)
	turn.note = {}
	return decision


## An `ai_fault` payload.
func _fault(reason: String) -> Dictionary:
	return {TurnPlan.EVENT_KEY: EVENT_FAULT, "reason": reason, TurnPlan.DIAGNOSTIC_KEY: true}


## Routes [param diagnostic] before the next command.
func _record(turn: _Turn, diagnostic: Dictionary) -> void:
	diagnostic[TurnPlan.COMMAND_INDEX_KEY] = turn.plan.commands.size()
	turn.plan.diagnostics.append(diagnostic)


## C9's alternatives of the pick, JSON-safe: a `-INF` overflow is dropped, and the
## decision carries `sim_overflow` instead (Edge Cases).
func _alternatives(scored: Array, chosen: Dictionary) -> Array:
	var kept: Array = []
	for alternative: Dictionary in Scorer.alternatives(scored, chosen):
		if not is_inf(float(alternative.score)):
			kept.append(alternative.duplicate(true))
	return kept


## What the search leaves for the next decision: its node count, and A7's and A9's
## records. An exhausted search is written into `mode` as the Edge Cases say; the
## mode played stays in `mode_trace`.
func _note_search(turn: _Turn) -> void:
	turn.note["lethal_nodes"] = _lethal.nodes
	match _lethal.outcome:
		LethalSearch.OUTCOME_SHALLOW_NONE:
			turn.note["lethal_search"] = String(LethalSearch.OUTCOME_SHALLOW_NONE)
		LethalSearch.OUTCOME_EXHAUSTED:
			turn.note["mode"] = String(LethalSearch.OUTCOME_EXHAUSTED)


## Enters [param mode], logging a transition on the next decision (C9).
func _enter_mode(turn: _Turn, mode: StringName) -> void:
	if turn.mode == mode:
		return
	turn.note["mode_transition"] = {"from": String(turn.mode), "to": String(mode)}
	turn.mode = mode
	turn.plan.mode_trace.append(mode)


## [param commands] minus the turn's excluded ones.
func _open(turn: _Turn, commands: Array) -> Array:
	return commands.filter(func(command: Dictionary) -> bool: return not turn.excluded.has(command))


func _is_own_main(turn: _Turn) -> bool:
	return turn.sandbox.phase() == MatchState.PHASE_MAIN and String(turn.sandbox.active_side()) == turn.side


## C1.3 / F5: folds the `card_played` events the live log gained since the last
## read into `aoe_seen`. Main thread only. The opponent is the player whichever side
## is to move: a forecast task is built on the player's turn.
func _read_public_log() -> void:
	if _log == null:
		return
	var events: Array = _log.events_since(_log_cursor)
	if events.is_empty():
		return
	_log_cursor = int((events.back() as Dictionary).seq)
	_aoe_seen = _aoe_seen or Scorer.aoe_seen_in(events, _db, MatchRecords.SIDE_PLAYER)


# --- schema walk ---------------------------------------------------------------

static func _check_profiles(rows: Array[Dictionary], profiles: Dictionary) -> void:
	if not profiles.has(DEFAULT_PROFILE):
		rows.append(_row(E_AI_UNKNOWN_FIELD, null, "profiles.%s" % DEFAULT_PROFILE, "missing `profiles.%s` — every resolution starts from it (C10)" % DEFAULT_PROFILE))
	for profile_name: Variant in profiles:
		_check_profile(rows, "profiles.%s" % profile_name, profiles[profile_name], _Context.PROFILE, profiles)
	var default_profile: Variant = profiles.get(DEFAULT_PROFILE)
	if not default_profile is Dictionary:
		return
	# No code default exists (A29): `default` must carry every weight and rule.
	var record_id: String = "profiles.%s" % DEFAULT_PROFILE
	var weights: Dictionary = default_profile.get("weights") if default_profile.get("weights") is Dictionary else {}
	for key: String in WEIGHT_KEYS:
		if not weights.has(key):
			rows.append(_row(E_AI_WEIGHT_RANGE, record_id, "weights.%s" % key, "`profiles.default` must set `%s` (%s)" % [key, RANGES[key].row]))
	var rules: Dictionary = default_profile.get("rules") if default_profile.get("rules") is Dictionary else {}
	for key: String in RULE_KEYS:
		if not rules.has(key):
			var code: StringName = E_AI_WEIGHT_RANGE if RANGES.has(key) else E_AI_UNKNOWN_FIELD
			rows.append(_row(code, record_id, "rules.%s" % key, "`profiles.default` must set rule `%s` (F9)" % key))
	if not default_profile.has("intent_mode"):
		rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, "intent_mode", "`profiles.default` must set `intent_mode` (C8.4)"))


static func _check_bands(rows: Array[Dictionary], bands: Dictionary) -> void:
	for band_key: Variant in bands:
		if not BAND_KEYS.has(band_key):
			rows.append(_row(E_AI_UNKNOWN_FIELD, null, "bands.%s" % band_key, "unknown band `%s` (F9: %s)" % [band_key, ", ".join(BAND_KEYS)]))
	for band_key: String in BAND_KEYS:
		if not bands.has(band_key):
			rows.append(_row(E_AI_UNKNOWN_FIELD, null, "bands.%s" % band_key, "missing band overlay `%s` (F9)" % band_key))
			continue
		var record_id: String = "bands.%s" % band_key
		var overlay: Variant = bands[band_key]
		_check_profile(rows, record_id, overlay, _Context.BAND, {})
		if not overlay is Dictionary:
			continue
		var budgets: Dictionary = overlay.get("budgets") if overlay.get("budgets") is Dictionary else {}
		for key: String in BUDGET_KEYS:
			if not budgets.has(key):
				rows.append(_row(E_AI_WEIGHT_RANGE, record_id, "budgets.%s" % key, "band %s must set `%s` (%s)" % [band_key, key, RANGES[key].row]))


static func _check_profile(rows: Array[Dictionary], record_id: String, entry: Variant, context: _Context, profiles: Dictionary) -> void:
	if not entry is Dictionary:
		rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, null, "a profile entry must be an object"))
		return
	for key: Variant in entry:
		var allowed: bool = PROFILE_SECTIONS.has(key) or (key == EXTENDS_KEY and context == _Context.OVERRIDE)
		if not allowed:
			var hint: String = " (only `boss_overrides` entries extend)" if key == EXTENDS_KEY else ""
			rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, str(key), "unknown profile field `%s`%s (F9: %s)" % [key, hint, ", ".join(PROFILE_SECTIONS)]))
	if context == _Context.OVERRIDE:
		var parent: Variant = entry.get(EXTENDS_KEY)
		if not parent is String or not profiles.has(parent):
			var found: String = "missing" if parent == null else "`%s`" % str(parent)
			rows.append(_row(E_AI_PROFILE_UNKNOWN, record_id, EXTENDS_KEY, "`extends` is %s; it must name a `profiles` key (F9)" % found))
	if entry.has("weights"):
		_check_keyed_numbers(rows, record_id, entry.weights, "weights", WEIGHT_KEYS)
	if entry.has("budgets"):
		_check_keyed_numbers(rows, record_id, entry.budgets, "budgets", BUDGET_KEYS)
	if entry.has("rules"):
		_check_rules(rows, record_id, entry.rules)
	if entry.has("intent_mode"):
		var mode: Variant = entry.intent_mode
		if not mode is String or not INTENT_MODES.has(mode):
			rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, "intent_mode", "`intent_mode` %s is not one of %s (C8.4)" % [str(mode), ", ".join(INTENT_MODES)]))
		elif mode == OVERRIDE_ONLY_INTENT and context != _Context.OVERRIDE:
			rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, "intent_mode", "`intent_mode: %s` is legal only in a `boss_overrides` entry (C8.4, D-04)" % OVERRIDE_ONLY_INTENT))
	if entry.has("choice_preference"):
		if entry.choice_preference is Dictionary:
			for tag: Variant in entry.choice_preference:
				_check_ranged(rows, record_id, "choice_preference.%s" % tag, "choice_preference", entry.choice_preference[tag])
		else:
			rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, "choice_preference", "`choice_preference` must be an object {tag: number}"))
	if entry.has("synergy_tags"):
		var tags: Variant = entry.synergy_tags
		var ok: bool = tags is Array
		if ok:
			for tag: Variant in tags:
				ok = ok and tag is String and not (tag as String).is_empty()
		if not ok:
			rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, "synergy_tags", "`synergy_tags` must be an array of non-empty strings"))


static func _check_keyed_numbers(rows: Array[Dictionary], record_id: String, section: Variant, section_name: String, keys: Array[String]) -> void:
	if not section is Dictionary:
		rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, section_name, "`%s` must be an object" % section_name))
		return
	for key: Variant in section:
		if keys.has(key):
			_check_ranged(rows, record_id, "%s.%s" % [section_name, key], key, section[key])
		else:
			rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, "%s.%s" % [section_name, key], "unknown %s key `%s` (F9: %s)" % [section_name, key, ", ".join(keys)]))


static func _check_rules(rows: Array[Dictionary], record_id: String, rules: Variant) -> void:
	if not rules is Dictionary:
		rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, "rules", "`rules` must be an object"))
		return
	for key: Variant in rules:
		var field: String = "rules.%s" % key
		var value: Variant = rules[key]
		if not RULE_KEYS.has(key):
			rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, field, "unknown rule `%s` (F9: %s)" % [key, ", ".join(RULE_KEYS)]))
		elif RANGES.has(key):
			_check_ranged(rows, record_id, field, key, value)
		elif RULE_ENUMS.has(key):
			if not value is String or not RULE_ENUMS[key].has(value):
				rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, field, "`%s` %s is not one of %s (F9)" % [key, str(value), ", ".join(RULE_ENUMS[key])]))
		elif RULE_FLAGS.has(key):
			if typeof(value) != TYPE_BOOL:
				rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, field, "`%s` must be true or false, found %s" % [key, str(value)]))
		elif key == DEFENSIVE_MULTIPLIERS_KEY:
			_check_multipliers(rows, record_id, field, value)


static func _check_multipliers(rows: Array[Dictionary], record_id: String, field: String, value: Variant) -> void:
	if not value is Dictionary:
		rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, field, "`%s` must be an object {w_*: number}" % DEFENSIVE_MULTIPLIERS_KEY))
		return
	for key: Variant in value:
		if not WEIGHT_KEYS.has(key):
			rows.append(_row(E_AI_UNKNOWN_FIELD, record_id, "%s.%s" % [field, key], "`%s` keys are weight names (F9), found `%s`" % [DEFENSIVE_MULTIPLIERS_KEY, key]))
		elif not _is_non_negative_finite(value[key]):
			rows.append(_row(E_AI_WEIGHT_RANGE, record_id, "%s.%s" % [field, key], "multiplier `%s` must be a finite number ≥ 0, found %s" % [key, str(value[key])]))


static func _check_number_map(rows: Array[Dictionary], body: Dictionary, section: String, range_key: String) -> void:
	if not body.has(section):
		return
	if not body[section] is Dictionary:
		rows.append(_row(E_AI_UNKNOWN_FIELD, null, section, "`%s` must be an object" % section))
		return
	for key: Variant in body[section]:
		_check_ranged(rows, null, "%s.%s" % [section, key], range_key, body[section][key])


static func _check_presentation(rows: Array[Dictionary], body: Dictionary) -> void:
	if not body.has("presentation"):
		return
	var block: Variant = body.presentation
	if not block is Dictionary:
		rows.append(_row(E_AI_UNKNOWN_FIELD, null, "presentation", "`presentation` must be an object"))
		return
	for key: Variant in block:
		if not PRESENTATION_KEYS.has(key):
			rows.append(_row(E_AI_UNKNOWN_FIELD, null, "presentation.%s" % key, "unknown presentation key `%s` (F9: %s)" % [key, ", ".join(PRESENTATION_KEYS)]))
	for key: String in PRESENTATION_KEYS:
		if block.has(key):
			_check_ranged(rows, null, "presentation.%s" % key, key, block[key])
		else:
			rows.append(_row(E_AI_WEIGHT_RANGE, null, "presentation.%s" % key, "missing `presentation.%s` (%s)" % [key, RANGES[key].row]))


static func _check_runtime(rows: Array[Dictionary], body: Dictionary) -> void:
	if not body.has("runtime"):
		return
	var block: Variant = body.runtime
	if not block is Dictionary:
		rows.append(_row(E_AI_UNKNOWN_FIELD, null, "runtime", "`runtime` must be an object (ADR-0006)"))
		return
	for key: Variant in block:
		if key != PLANNER_MODE_KEY and key != PLANNER_TARGET_KEY and not RUNTIME_TIMING_KEYS.has(key):
			rows.append(_row(E_AI_UNKNOWN_FIELD, null, "runtime.%s" % key, "unknown runtime key `%s` (F9: %s, %s, %s)" % [key, PLANNER_MODE_KEY, ", ".join(RUNTIME_TIMING_KEYS), PLANNER_TARGET_KEY]))
	var mode: Variant = block.get(PLANNER_MODE_KEY)
	if not mode is String or not PLANNER_MODES.has(mode):
		var found: String = "missing" if mode == null else str(mode)
		rows.append(_row(E_AI_UNKNOWN_FIELD, null, "runtime.%s" % PLANNER_MODE_KEY, "`planner_mode` is %s; it must be one of %s (ADR-0006)" % [found, ", ".join(PLANNER_MODES)]))
	for key: String in RUNTIME_TIMING_KEYS:
		var value: Variant = block.get(key)
		if not is_number(value) or not is_finite(float(value)) or float(value) <= 0.0:
			var found: String = "missing" if value == null else str(value)
			rows.append(_row(E_AI_WEIGHT_RANGE, null, "runtime.%s" % key, "`%s` is %s; it must be a positive finite number of milliseconds (ADR-0006)" % [key, found]))
	_check_ranged(rows, null, "runtime.%s" % PLANNER_TARGET_KEY, PLANNER_TARGET_KEY, block.get(PLANNER_TARGET_KEY))


static func _check_ranged(rows: Array[Dictionary], record_id: Variant, field: String, range_key: String, value: Variant) -> void:
	var problem: String = range_problem(range_key, value)
	if problem.is_empty():
		return
	var bounds: Dictionary = RANGES[range_key]
	var kind: String = "a whole number" if bounds.integral else "a finite number"
	rows.append(_row(E_AI_WEIGHT_RANGE, record_id, field,
		"`%s` is %s; it must be %s in %s–%s (%s)" % [field, str(value), kind, str(bounds.min), str(bounds.max), bounds.row]))


static func _is_non_negative_finite(value: Variant) -> bool:
	return is_number(value) and is_finite(float(value)) and float(value) >= 0.0


# --- op coverage ---------------------------------------------------------------

static func _collect_unvalued(ops: Array, op_values: Dictionary, card_id: String, first_user: Dictionary) -> void:
	for op: Variant in ops:
		if not op is Dictionary:
			continue
		var op_name: String = str(op.get("op"))
		if STRUCTURAL_OPS.has(op_name):
			for param: String in STRUCTURAL_OPS[op_name]:
				var inner: Variant = op.get(param)
				if not inner is Array:
					continue
				if op_name == "choose_one":
					for option: Variant in inner:
						if option is Dictionary and option.get("ops") is Array:
							_collect_unvalued(option.ops, op_values, card_id, first_user)
				else:
					_collect_unvalued(inner, op_values, card_id, first_user)
			continue
		var valued_as: String = VALUED_AS.get(op_name, op_name)
		if not op_values.has(valued_as) and not first_user.has(valued_as):
			first_user[valued_as] = card_id


## Every card [param db] lists through its stage-7 lookups, or `[]` when it
## has none (null, or a `CardDatabase` before card-database story 006).
static func _loaded_cards(db: Variant) -> Array:
	var cards: Array = []
	if db is Object and (db as Object).has_method(&"cards_by_type"):
		for card_type: String in CARD_TYPES:
			var listed: Variant = (db as Object).call(&"cards_by_type", card_type)
			if listed is Array:
				cards.append_array(listed)
	return cards


static func _row(code: StringName, record_id: Variant, field: Variant, message: String) -> Dictionary:
	return {
		"severity": ValidationReport.SEVERITY_ERROR,
		"code": code,
		"file": PROFILES_FILE,
		"record_id": record_id,
		"field": field,
		"message": message,
	}
