## The Boss AI tie-break (design/gdd/boss-ai.md F8, C9; ADR-0003 rule 5,
## ADR-0006; TR-boss-ai-001; boss-ai-match-driver story 006).
##
## F8: `ties = sort_canonical({a : score(best) − score(a) ≤ tie_epsilon})`;
## `pick = ties[ai_stream.randi_range(0, |ties| − 1)]` when `|ties| > 1`,
## else `ties[0]` with **no draw**. So one decision consumes 0 or 1
## `ai_<floor>` draws — together with one parent draw per new fork label
## ([method sim_label], [method forecast_label]; ADR-0003 rule 5) these are
## the only live `ai_<floor>` draws (C9), which keeps the per-turn draw count
## a function of the state (what `restore()` relies on). Forking, and the
## per-turn `TurnPlan.ai_draws` sum, are story 008's (`plan_turn`); nothing
## here touches the `match_<floor>` stream or a `RandomNumberGenerator`.
##
## Canonical order (C9): command type (`play_card`, `attack`,
## `use_hero_power`, `choose`, `end_turn` — the C2 order `legal_commands()`
## lists them in), then `hand_index`, `attacker_id`, `target_id`, `position`,
## each ascending with an absent or null field first.
## A candidate scored `-INF` (a sandbox overflow, Edge Cases) is never in a tie
## set unless every candidate is, in which case the set is the canonically
## first of them alone (no draw).
## [codeblock]
## var decision: Dictionary = TieBreak.pick(scored, float(profile.rules.tie_epsilon), ai_stream)
## engine.submit(decision.chosen.command)
## [/codeblock]
class_name TieBreak
extends RefCounted

## C2 command types in canonical order (`mulligan` and `concede` are never a
## Boss AI candidate; they sort first and last for completeness).
const TYPE_ORDER: Array[String] = [
	MatchRecords.CMD_MULLIGAN, MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_ATTACK,
	MatchRecords.CMD_USE_HERO_POWER, MatchRecords.CMD_CHOOSE, MatchRecords.CMD_END_TURN,
	MatchRecords.CMD_CONCEDE,
]
## The C9 tie-break fields after the type, in order.
const KEY_FIELDS: Array[String] = ["hand_index", "attacker_id", "target_id", "position"]
## The sort value of an absent or null field (every real value is ≥ 0).
const ABSENT: int = -1
## C4 / C8.1 fork label prefixes (`ai_stream.fork("sim_<turn>")`, `fork("forecast_<turn>")`).
const SIM_PREFIX: String = "sim_"
const FORECAST_PREFIX: String = "forecast_"


## F8 over [param scored] (entries `{command, score, …}` as
## `Scorer.score_all` returns them, any order) with [param tie_epsilon] (the
## profile's `rules.tie_epsilon`) and [param ai_stream] (the `ai_<floor>`
## stream). Returns `{chosen, ties, draws}`: `chosen` the picked entry (null
## for an empty list), `ties` the tie set in canonical order, `draws` the
## `ai_stream` draws taken (0 or 1).
static func pick(scored: Array, tie_epsilon: float, ai_stream: RefCounted) -> Dictionary:
	var ties: Array = tie_set(scored, tie_epsilon)
	if ties.is_empty():
		return {"chosen": null, "ties": ties, "draws": 0}
	if ties.size() == 1:
		return {"chosen": ties[0], "ties": ties, "draws": 0}
	var index: int = ai_stream.randi_range(0, ties.size() - 1)
	return {"chosen": ties[index], "ties": ties, "draws": 1}


## The F8 tie set of [param scored] in canonical order: every entry whose
## score is within [param tie_epsilon] of the best finite score (see the class
## doc for `-INF`).
static func tie_set(scored: Array, tie_epsilon: float) -> Array:
	if scored.is_empty():
		return []
	var best: float = -INF
	for entry: Dictionary in scored:
		best = maxf(best, float(entry.score))
	if is_inf(best):
		return [sort_canonical(scored)[0]]
	var ties: Array = []
	for entry: Dictionary in scored:
		var score: float = float(entry.score)
		if not is_inf(score) and best - score <= tie_epsilon:
			ties.append(entry)
	return sort_canonical(ties)


## [param entries] (each with a `command`) sorted into C9 canonical order; a
## new Array.
static func sort_canonical(entries: Array) -> Array:
	var out: Array = entries.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _before(_key(a.command), _key(b.command)))
	return out


## The `sim_<turn>` fork label of [param turn] (C4: every sandbox of one turn
## shares it).
static func sim_label(turn: int) -> String:
	return "%s%d" % [SIM_PREFIX, turn]


## The `forecast_<turn>` fork label of [param turn] (C8.1).
static func forecast_label(turn: int) -> String:
	return "%s%d" % [FORECAST_PREFIX, turn]


static func _key(command: Dictionary) -> Array[int]:
	var key: Array[int] = [TYPE_ORDER.find(str(command.get("type")))]
	for field: String in KEY_FIELDS:
		var value: Variant = command.get(field)
		key.append(int(value) if value != null else ABSENT)
	return key


static func _before(a: Array[int], b: Array[int]) -> bool:
	for i: int in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false
