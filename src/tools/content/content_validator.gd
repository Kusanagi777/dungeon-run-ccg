## The Content validator: static checks over the content data set (content.md
## CN-6 steps 2-3; ADR-0002 Key Interfaces, "configs.content_budgets →
## ContentValidator.validate_config").
##
## Story 007 ships [method validate_config], the stage-7a validator of
## `content_budgets.json`; story 008 adds the F1-F5 checks ([method run_checks]:
## `W_STARTER_CURVE`, `W_HERO_HEALTH`, `W_SET_SHARE`, `W_CURVE`, `W_BUDGET`,
## `E_TEXT_LENGTH`, `E_COVERAGE` / `W_COVERAGE` / `W_COVERAGE_UNUSED`), which
## `ContentValidateCommand.run` merges into the report `tools/content/validate.gd`
## prints after a `Ready` load. Static functions only, no state, no file I/O:
## `Boot` registers [method validate_config] in its validator map and the
## validate command composes the same map, so the class lives under `src/`
## (exported) rather than `tools/` (`export_presets.cfg` excludes `tools/*`).
##
## Everything below is **format knowledge**: the CN-6 step 2 key list and the
## content.md Tuning Knobs **safe ranges** (the bounds a value is checked
## against). No knob value lives here; the values are `content_budgets.json`'s.
## A key whose Tuning Knobs row states no safe range is checked for type and
## the bound its meaning implies (a share in 0-1, a tolerance ≥ 0) and says so
## in its `row`.
##
## [codeblock]
## var rows: Array = ContentValidator.validate_config(db_body, null)   # [] when clean
## rows[0]   # {code: &"E_RANGE", host_id: null, field: "text_max_chars", message: "…"}
## [/codeblock]
## Single-thread-only is not required: the functions read only constants.
class_name ContentValidator
extends RefCounted

## A CN-6 step 2 key is absent.
const E_MISSING_FIELD: StringName = &"E_MISSING_FIELD"
## A key holds the wrong JSON type, a fractional integer knob, a list of the
## wrong length, or an `ops_exempt` entry that names no card-effects C5 op.
const E_SCHEMA: StringName = &"E_SCHEMA"
## A number lies outside its content.md Tuning Knobs safe range, or a
## min / max pair is inverted.
const E_RANGE: StringName = &"E_RANGE"
## A key the CN-6 step 2 list does not name (a typo is caught, not ignored).
const E_UNKNOWN_FIELD: StringName = &"E_UNKNOWN_FIELD"

## Spec kinds.
const K_OBJECT: StringName = &"object"        # nested `fields`, exactly those keys
const K_NUMBER: StringName = &"number"        # any finite JSON number in `range`
const K_INT: StringName = &"int"              # a whole JSON number in `range`
const K_NUMBER_LIST: StringName = &"number_list"  # exactly `size` numbers, each in `range`
const K_NUMBER_MAP: StringName = &"number_map"    # {<key>: number in `range`}; `keys` limits the keys
const K_OP_LIST: StringName = &"op_list"      # card-effects C5 op names (`EffectSchema.OPS`)

## Keys allowed in `budget.keyword_tax`: the DD-M09 keyword ids (card-database CR-4).
const KEYWORD_KEYS: StringName = &"keywords"

## The `content_budgets.json` body (content CN-6 step 2), field → spec.
## `range` is `[min, max]` inclusive; `null` means unbounded on that side.
## `row` names the GDD row the spec comes from.
const BUDGETS_SPEC: Dictionary = {
	"curve": {"kind": K_OBJECT, "row": "F2 / Tuning Knobs", "fields": {
		"avg_min": {"kind": K_NUMBER, "range": [2.6, 3.8], "row": "CURVE_AVG_MIN, safe 2.6-3.8"},
		"avg_max": {"kind": K_NUMBER, "range": [2.6, 3.8], "row": "CURVE_AVG_MAX, safe 2.6-3.8"},
		"bucket": {"kind": K_NUMBER_LIST, "size": 6, "range": [0.0, 1.0], "row": "CURVE_BUCKET[k1..k6_plus], a share 0-1"},
		"bucket_tol": {"kind": K_NUMBER, "range": [0.04, 0.15], "row": "BUCKET_TOL, safe 0.04-0.15"},
		"early_max": {"kind": K_NUMBER, "range": [2.0, 3.0], "row": "EARLY_MAX, safe 2-3"},
		"mid_max": {"kind": K_NUMBER, "range": [3.5, 5.0], "row": "MID_MAX, safe 3.5-5"},
	}},
	"budget": {"kind": K_OBJECT, "row": "F3 / Tuning Knobs", "fields": {
		"tol": {"kind": K_OBJECT, "row": "BUDGET_TOL", "fields": {
			"common": {"kind": K_NUMBER, "range": [1.0, 4.0], "row": "BUDGET_TOL common, safe 1-4"},
			"rare": {"kind": K_NUMBER, "range": [1.0, 4.0], "row": "BUDGET_TOL rare, safe 1-4"},
			"legendary": {"kind": K_NUMBER, "range": [1.0, 4.0], "row": "BUDGET_TOL legendary, safe 1-4"},
		}},
		"keyword_tax": {"kind": K_NUMBER_MAP, "keys": KEYWORD_KEYS, "range": [0.0, null], "row": "F3 keyword_tax (±50 % per entry is a review range, not a bound)"},
		"effect_points": {"kind": K_NUMBER_MAP, "range": [null, null], "row": "F3 effect_points (self-cost is negative)"},
	}},
	"pressure": {"kind": K_OBJECT, "row": "F4 / Tuning Knobs", "fields": {
		"band": {"kind": K_NUMBER_LIST, "size": 3, "range": [5.0, 14.0], "row": "PRESSURE_BAND[band], safe 5-14"},
		"tol": {"kind": K_NUMBER, "range": [0.0, null], "row": "PRESSURE_TOL (no safe range stated; ≥ 0)"},
		"passive_cap": {"kind": K_NUMBER_LIST, "size": 3, "range": [1.0, 8.0], "row": "PASSIVE_CAP[band], safe 1-8"},
	}},
	"coverage": {"kind": K_OBJECT, "row": "F5 / Tuning Knobs", "fields": {
		"kw_min": {"kind": K_INT, "range": [1, 4], "row": "KW_MIN, safe 1-4"},
		"bundle_coverage_min": {"kind": K_NUMBER, "range": [0.7, 1.0], "row": "BUNDLE_COVERAGE_MIN, safe 0.7-1.0"},
		"ops_exempt": {"kind": K_OP_LIST, "row": "F5 OPS_EXEMPT (card-effects C5 op names)"},
	}},
	"text_max_chars": {"kind": K_INT, "range": [70, 110], "row": "TEXT_MAX_CHARS, safe 70-110"},
	"pick_rate": {"kind": K_OBJECT, "row": "Tuning Knobs PICK_RATE_MIN / MAX", "fields": {
		"min": {"kind": K_NUMBER, "range": [0.05, 0.25], "row": "PICK_RATE_MIN, safe 0.05-0.25"},
		"max": {"kind": K_NUMBER, "range": [0.4, 0.7], "row": "PICK_RATE_MAX, safe 0.4-0.7"},
		"min_sample": {"kind": K_INT, "range": [20, 200], "row": "min_sample (run-structure Tuning Knobs, safe 20-200)"},
	}},
	"time": {"kind": K_OBJECT, "row": "F6", "fields": {
		"t_card": {"kind": K_NUMBER, "range": [0.3, 0.6], "row": "T_CARD, F6 0.3-0.6 h"},
		"t_boss_card": {"kind": K_NUMBER, "range": [0.2, 0.4], "row": "T_BOSS_CARD, F6 0.2-0.4 h"},
		"t_boss": {"kind": K_NUMBER, "range": [1.5, 4.0], "row": "T_BOSS, F6 1.5-4 h"},
		"t_bundle": {"kind": K_NUMBER, "range": [0.1, 0.3], "row": "T_BUNDLE, F6 0.1-0.3 h"},
		"t_balance": {"kind": K_NUMBER, "range": [2.0, 6.0], "row": "T_BALANCE, F6 2-6 h"},
	}},
	"set_share": {"kind": K_OBJECT, "row": "F1 SET_SHARE (neutral and boss rows)", "fields": {
		"neutral": {"kind": K_OBJECT, "row": "SET_SHARE[neutral]", "fields": {
			"minion": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
			"spell": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
			"weapon": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
		}},
		"boss": {"kind": K_OBJECT, "row": "SET_SHARE[boss]", "fields": {
			"minion": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
			"spell": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
			"weapon": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
		}},
	}},
	"share_tol": {"kind": K_NUMBER, "range": [0.04, 0.15], "row": "SHARE_TOL (heroes Tuning Knobs SET_SHARE tolerance, safe 0.04-0.15)"},
}

## min / max pairs that must not be inverted: `[low path, high path]`.
const ORDERED_PAIRS: Array = [
	["curve.avg_min", "curve.avg_max"],
	["curve.early_max", "curve.mid_max"],
	["pick_rate.min", "pick_rate.max"],
]


## Stage-7a validator of `content_budgets.json` (card-database CR-5 stage 7;
## ADR-0002 Decision 4: `call(body, db) -> Array`). Returns `[]` for a body
## that holds exactly the CN-6 step 2 keys with values of the right type
## inside their safe ranges; otherwise one `{code, host_id: null, field,
## message}` entry per fault — `field` is the dotted key path (list entries
## as `key[i]`) and the message names it. Every fault is reported, not only
## the first. [param _db] is unused (the body is self-contained).
## [codeblock]
## ContentValidator.validate_config({"text_max_chars": 200.0, …}, null)[0].code   # &"E_RANGE"
## [/codeblock]
static func validate_config(body: Dictionary, _db: Variant) -> Array:
	var rows: Array[Dictionary] = []
	_check_object(rows, body, BUDGETS_SPEC, "")
	for pair: Array in ORDERED_PAIRS:
		var low: Variant = _at(body, pair[0])
		var high: Variant = _at(body, pair[1])
		if _is_number(low) and _is_number(high) and float(low) > float(high):
			rows.append(_row(E_RANGE, pair[0], "`%s` is %s, above `%s` %s (min must not exceed max)" % [pair[0], str(low), pair[1], str(high)]))
	return rows


## Whether [param value] is a finite JSON number (`int` or `float`, never `bool`).
## Example: `ContentValidator.is_number(3.0) == true`.
static func is_number(value: Variant) -> bool:
	return _is_number(value)


# --- Story 008: the F1-F5 content checks (content.md CN-6 step 3) -------------
#
# Each check is `check_*(pool, budgets, heroes_balance) -> Array[Dictionary]`
# over a plain pool view ([method pool_of]) and returns CR-5 report entries
# `{severity, code, file, record_id, field, message}`; the severity follows
# the code prefix (`E_` error, `W_` warning). Every constant is read from the
# two config bodies (or `match_rules` in the pool) — a knob that is absent or
# not a number makes the check report "not checked" under its own code, never
# pass. The constants below are format knowledge (codes, the F3 formula shape,
# which selector is which F3 rate), not knob values.

## Heroes F1: a starter deck breaks the starter curve (or the curve knobs are unreadable).
const W_STARTER_CURVE: StringName = &"W_STARTER_CURVE"
## Heroes Edge Cases: a `HeroDef.health` other than match-rules `starting_health_player`.
const W_HERO_HEALTH: StringName = &"W_HERO_HEALTH"
## F1 / Heroes F4: a set's type share outside `SET_SHARE[set][type] ± tolerance`.
const W_SET_SHARE: StringName = &"W_SET_SHARE"
## F2: a collectible set's average cost or a cost bucket off target.
const W_CURVE: StringName = &"W_CURVE"
## F3: a collectible card's points outside `budget.tol[rarity]`, or not valued.
const W_BUDGET: StringName = &"W_BUDGET"
## CN-6 step 6: a card `text.en` longer than `text_max_chars`.
const E_TEXT_LENGTH: StringName = &"E_TEXT_LENGTH"
## F5 at the Alpha pool: an unmet coverage requirement.
const E_COVERAGE: StringName = &"E_COVERAGE"
## F5 at the MVP pool (and "not checked" coverage notes): an unmet requirement listed.
const W_COVERAGE: StringName = &"W_COVERAGE"
## F5: an `OPS_EXEMPT` op no collectible card uses (never `E_COVERAGE`).
const W_COVERAGE_UNUSED: StringName = &"W_COVERAGE_UNUSED"

## The pool is Alpha when a HeroDef of one of these sets exists, else MVP
## (story 008 Implementation Notes; CN-6 batch table: Decay joins at Alpha-A,
## Knowledge at Alpha-B). Derived from the data, never a flag in it.
const ALPHA_HERO_SETS: Array[String] = ["decay", "knowledge"]
## Boss-only cards are not collectible (CR-6): no F2 curve, F3 budget or F5 use.
const BOSS_SET: String = "boss"
## F5: the value-only op counted against boss passives and treasures.
const MODIFY_VALUE_OP: String = "modify_value"
## F3: effects on this trigger are delayed (× `effect_points.deathrattle_factor`).
const DEATHRATTLE_TRIGGER: String = "deathrattle"
## F3 `budget(cost)` shape per type: `per_cost × cost + flat + floor(cost / floor_div)`
## (minion 2c + 1, weapon 2c + floor(c / 3), spell 2c). The formula itself, not
## a Tuning Knobs row; content_budgets.json holds no key for it.
const BUDGET_FORMULA: Dictionary = {
	"minion": {"per_cost": 2, "flat": 1, "floor_div": 0},
	"weapon": {"per_cost": 2, "flat": 0, "floor_div": 3},
	"spell": {"per_cost": 2, "flat": 0, "floor_div": 0},
}
## F3 damage rate keys (`budget.effect_points`) by C3 selector: targeted, random,
## enemy-board AoE, and AoE that also hits the own board (both rates). A fixed
## single enemy target (`enemy_hero`, `opponent`) takes the untargeted per-point
## rate. A selector not listed here is not valued (reported, never guessed).
const DAMAGE_RATE_KEYS: Dictionary = {
	"chosen": ["damage_targeted"],
	"random_enemy_minion": ["damage_random"], "random_enemy_character": ["damage_random"],
	"random_minion": ["damage_random"], "random_character": ["damage_random"],
	"enemy_hero": ["damage_random"], "opponent": ["damage_random"],
	"all_enemy_minions": ["damage_aoe_enemy"], "all_enemy_characters": ["damage_aoe_enemy"],
	"all_minions": ["damage_aoe_enemy", "damage_aoe_own"], "all_characters": ["damage_aoe_enemy", "damage_aoe_own"],
}
## C3 selectors that name one entity: the F3 per-target rates (heal, buff,
## give_keyword, freeze, silence, transform) apply to these only.
const SINGLE_SELECTORS: Array[String] = [
	"chosen", "self", "owner_hero", "owner_weapon", "enemy_hero", "enemy_weapon",
	"trigger_subject", "trigger_source", "random_friendly_minion", "random_enemy_minion",
	"random_minion", "random_enemy_character", "random_friendly_character", "random_character",
]
## C3 selectors on the owner's side: `destroy` there is the F3 self-cost.
const FRIENDLY_SELECTORS: Array[String] = [
	"self", "owner_hero", "owner_weapon", "random_friendly_minion", "random_friendly_character",
	"all_friendly_minions", "all_friendly_characters",
]
## F3 flat-rate ops on one target: op → `effect_points` key.
const FLAT_OP_KEYS: Dictionary = {"freeze": "freeze", "silence": "silence", "transform": "transform"}
## F3 per-point ops (`amount` × rate, any target): op → `effect_points` key.
const AMOUNT_OP_KEYS: Dictionary = {"armor": "armor", "mana": "mana"}


## The plain pool view every `check_*` reads, from a `Ready` [param db]'s
## frozen snapshot: `{cards, heroes, bosses, treasures, bundles: Array of the
## frozen records, match_rules: the match_rules config body}`. Read-only.
## Example: `ContentValidator.check_text(ContentValidator.pool_of(db), budgets, balance)`.
static func pool_of(db: CardDatabase) -> Dictionary:
	var by_type: Dictionary = db.snapshot_handle().get("records_by_type", {})
	var match_rules: Variant = db.config("match_rules")
	return {
		"cards": by_type.get("CardDef", []), "heroes": by_type.get("HeroDef", []),
		"bosses": by_type.get("BossDef", []), "treasures": by_type.get("TreasureDef", []),
		"bundles": by_type.get("BundleDef", []),
		"match_rules": match_rules if match_rules is Dictionary else {},
	}


## Runs every F1-F5 check over a `Ready` [param db] with the
## `content_budgets` and `heroes_balance` config bodies and returns their
## entries (heroes, set share, curve, budget, text, coverage, in that order).
## The validate command merges them into its report. O(records).
## Example: `ContentValidator.run_checks(db, db.config("content_budgets"), db.config("heroes_balance"))`.
static func run_checks(db: CardDatabase, budgets: Dictionary, heroes_balance: Dictionary) -> Array[Dictionary]:
	return check_all(pool_of(db), budgets, heroes_balance)


## [method run_checks] over a pool view (tests build one with `CardFactory`).
static func check_all(pool: Dictionary, budgets: Dictionary, heroes_balance: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append_array(check_heroes(pool, budgets, heroes_balance))
	rows.append_array(check_set_share(pool, budgets, heroes_balance))
	rows.append_array(check_curve(pool, budgets, heroes_balance))
	rows.append_array(check_budget(pool, budgets, heroes_balance))
	rows.append_array(check_text(pool, budgets, heroes_balance))
	rows.append_array(check_coverage(pool, budgets, heroes_balance))
	return rows


## Heroes F1 and Edge Cases, per HeroDef: one `W_STARTER_CURVE` naming the hero
## when its starter's average cost is outside `starter_curve.avg_min`–`avg_max`,
## a card costs more than `starter_curve.max_cost`, or a cost's count is outside
## its `starter_curve.bucket` range (keys `"<cost>"` and one `"<n>_plus"`); and
## `W_HERO_HEALTH` when `health` ≠ match-rules `starting_health_player`.
## Example: `ContentValidator.check_heroes(pool, budgets, balance)[0].record_id == "hero_war"`.
static func check_heroes(pool: Dictionary, _budgets: Dictionary, heroes_balance: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var by_id: Dictionary = _index(pool.get("cards", []))
	var curve: Variant = heroes_balance.get("starter_curve")
	var curve_gap: String = _starter_curve_gap(curve)
	var health: Variant = (pool.get("match_rules", {}) as Dictionary).get("starting_health_player")
	for hero: Dictionary in pool.get("heroes", []):
		var id: String = hero.id
		if not _is_number(health):
			rows.append(_entry(W_HERO_HEALTH, "heroes.json", id, "health", "not checked — match_rules.starting_health_player is absent or not a number"))
		elif int(hero.health) != int(health):
			rows.append(_entry(W_HERO_HEALTH, "heroes.json", id, "health",
				"health %d differs from starting_health_player %d (heroes.md Edge Cases)" % [int(hero.health), int(health)]))
		if not curve_gap.is_empty():
			rows.append(_entry(W_STARTER_CURVE, "heroes.json", id, "starter_deck", "not checked — " + curve_gap))
			continue
		var faults: PackedStringArray = _starter_faults(hero.starter_deck, by_id, curve)
		if not faults.is_empty():
			rows.append(_entry(W_STARTER_CURVE, "heroes.json", id, "starter_deck",
				"starter breaks Heroes F1: " + "; ".join(faults)))
	return rows


## F1 / Heroes F4, per set present (non-token cards): one `W_SET_SHARE` per
## type whose share `count / |set|` is outside the target ± tolerance. Hero
## sets read `heroes_balance.set_share[set]` and `set_share_tol`; neutral and
## boss read `content_budgets.set_share[set]` and `share_tol`. `field` is
## `set_share.<set>.<type>`.
## Example: `ContentValidator.check_set_share(pool, budgets, balance)[0].field == "set_share.knowledge.weapon"`.
static func check_set_share(pool: Dictionary, budgets: Dictionary, heroes_balance: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var sets: Dictionary = _by_set(pool.get("cards", []), func(c: Dictionary) -> bool: return not c.get("token", false))
	for set_id: String in sets:
		var hero_set: bool = (pool.get("heroes", []) as Array).any(func(hero: Dictionary) -> bool: return str(hero["set"]) == set_id)
		var owner: Dictionary = heroes_balance if hero_set else budgets
		var tol_key: String = "set_share_tol" if hero_set else "share_tol"
		var file: String = "cards_%s.json" % set_id
		var targets: Variant = _at(owner, "set_share." + set_id)
		var tol: Variant = owner.get(tol_key)
		if not targets is Dictionary or not _is_number(tol):
			rows.append(_entry(W_SET_SHARE, file, null, "set_share.%s" % set_id,
				"not checked — %s has no set_share.%s row or no %s" % ["heroes_balance" if hero_set else "content_budgets", set_id, tol_key]))
			continue
		var cards: Array = sets[set_id]
		for type: String in RecordSchemas.TYPES:
			var field: String = "set_share.%s.%s" % [set_id, type]
			var target: Variant = (targets as Dictionary).get(type)
			if not _is_number(target):
				rows.append(_entry(W_SET_SHARE, file, null, field, "not checked — no %s target for %s" % [type, set_id]))
				continue
			var count: int = cards.filter(func(c: Dictionary) -> bool: return c.type == type).size()
			var share: float = float(count) / cards.size()
			if absf(share - float(target)) > float(tol):
				rows.append(_entry(W_SET_SHARE, file, null, field, "%s %s share %.2f (%d / %d) outside %.2f ± %s (F1)" % [
					set_id, type, share, count, cards.size(), float(target), str(tol)]))
	return rows


## F2, per collectible set (non-token, not `boss`): `W_CURVE` with `field`
## `curve.avg` when the average cost is outside `curve.avg_min`–`avg_max`, and
## `curve.bucket[i]` per cost bucket (`i` 0 = cost ≤ 1 … last = the top cost
## and above) whose share misses `curve.bucket[i]` by more than `curve.bucket_tol`.
## Example: `ContentValidator.check_curve(pool, budgets, balance)[0].field == "curve.avg"`.
static func check_curve(pool: Dictionary, budgets: Dictionary, _heroes_balance: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var avg_min: Variant = _at(budgets, "curve.avg_min")
	var avg_max: Variant = _at(budgets, "curve.avg_max")
	var bucket: Variant = _at(budgets, "curve.bucket")
	var tol: Variant = _at(budgets, "curve.bucket_tol")
	var sets: Dictionary = _by_set(pool.get("cards", []), _is_collectible)
	for set_id: String in sets:
		var file: String = "cards_%s.json" % set_id
		if not (_is_number(avg_min) and _is_number(avg_max) and _is_number(tol) and bucket is Array and not (bucket as Array).is_empty()):
			rows.append(_entry(W_CURVE, file, null, "curve", "not checked — content_budgets.curve avg_min / avg_max / bucket / bucket_tol unreadable"))
			continue
		var cards: Array = sets[set_id]
		var targets: Array = bucket
		var counts: Array[int] = []
		counts.resize(targets.size())
		var total: int = 0
		for card: Dictionary in cards:
			total += int(card.cost)
			counts[clampi(int(card.cost) - 1, 0, targets.size() - 1)] += 1
		var avg: float = float(total) / cards.size()
		if avg < float(avg_min) or avg > float(avg_max):
			rows.append(_entry(W_CURVE, file, null, "curve.avg", "avg_cost %.2f (%d cards) outside %s–%s (F2)" % [avg, cards.size(), str(avg_min), str(avg_max)]))
		for i: int in targets.size():
			var share: float = float(counts[i]) / cards.size()
			if absf(share - float(targets[i])) > float(tol):
				rows.append(_entry(W_CURVE, file, null, "curve.bucket[%d]" % i, "cost bucket %s share %.2f (%d / %d) misses %s by more than %s (F2)" % [
					_bucket_label(i, targets.size()), share, counts[i], cards.size(), str(targets[i]), str(tol)]))
	return rows


## F3, per collectible card: `W_BUDGET` naming the card with its computed
## points when `|value − budget| > budget.tol[rarity]`, or "not checked" with
## the reasons when part of its effects has no F3 rate ([method card_value]).
## Example: `ContentValidator.check_budget(pool, budgets, balance)[0].record_id`.
static func check_budget(pool: Dictionary, budgets: Dictionary, _heroes_balance: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var by_id: Dictionary = _index(pool.get("cards", []))
	for card: Dictionary in pool.get("cards", []):
		if not _is_collectible(card):
			continue
		var file: String = "cards_%s.json" % card.set
		var v: Dictionary = _card_value(card, by_id, budgets)
		var tol: Variant = _at(budgets, "budget.tol." + String(card.rarity))
		if not (v.unvalued as Array).is_empty() or not _is_number(tol):
			var reasons: Array = (v.unvalued as Array).duplicate()
			if not _is_number(tol):
				reasons.append("budget.tol.%s absent" % card.rarity)
			rows.append(_entry(W_BUDGET, file, card.id, "budget", "not checked — %s (partial value %.1f vs budget %.1f)" % [
				", ".join(reasons), v.points, v.budget]))
		elif absf(float(v.points) - float(v.budget)) > float(tol):
			rows.append(_entry(W_BUDGET, file, card.id, "budget", "value %.1f vs budget %.1f (Δ %+.1f, %s tol %s; F3)" % [
				v.points, v.budget, float(v.points) - float(v.budget), card.rarity, str(tol)]))
	return rows


## F3 for one card: `{points: float, budget: float, unvalued: Array[String]}`
## — `points` = stat points + keyword tax + effect points, `budget` the F3
## `budget(cost)` for its type, `unvalued` one reason per op or shape with no
## F3 rate (those add 0 to `points`). [param pool] resolves `summon` card ids.
## Example: `ContentValidator.card_value(card, pool, budgets).points   # 9.5 for war_shieldwall_veteran`.
static func card_value(card: Dictionary, pool: Dictionary, budgets: Dictionary) -> Dictionary:
	return _card_value(card, _index(pool.get("cards", [])), budgets)


## CN-6 step 6, every CardDef (tokens and boss cards included): `E_TEXT_LENGTH`
## naming the card when `text.en` has more characters than `text_max_chars`.
## Example: a 91-character text at `text_max_chars` 90 → one entry; 90 → none.
static func check_text(pool: Dictionary, budgets: Dictionary, _heroes_balance: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var limit: Variant = budgets.get("text_max_chars")
	if not _is_number(limit):
		rows.append(_entry(E_TEXT_LENGTH, "content_budgets.json", null, "text_max_chars", "not checked — text_max_chars is absent or not a number"))
		return rows
	for card: Dictionary in pool.get("cards", []):
		var text: String = String((card.get("text", {}) as Dictionary).get("en", ""))
		if text.length() > int(limit):
			rows.append(_entry(E_TEXT_LENGTH, "cards_%s.json" % card.set, card.id, "text.en",
				"text.en is %d characters, above text_max_chars %d (CN-6 step 6)" % [text.length(), int(limit)]))
	return rows


## F5 `OPS_COVERED`: the card-effects C5 op table (`EffectSchema.OPS`) minus
## `coverage.ops_exempt` and `modify_value`, in table order.
## Example: `ContentValidator.ops_covered(budgets).has("damage")`.
static func ops_covered(budgets: Dictionary) -> Array[String]:
	var exempt: Variant = _at(budgets, "coverage.ops_exempt")
	var out: Array[String] = []
	for op: String in EffectSchema.OPS:
		if op != MODIFY_VALUE_OP and not (exempt is Array and (exempt as Array).has(op)):
			out.append(op)
	return out


## True when [param pool] is the Alpha pool (a HeroDef in [constant ALPHA_HERO_SETS]).
static func is_alpha_pool(pool: Dictionary) -> bool:
	for hero: Dictionary in pool.get("heroes", []):
		if ALPHA_HERO_SETS.has(String(hero.set)):
			return true
	return false


## F5 over the collectible cards (non-token, not `boss`), with the unmet
## requirements as `E_COVERAGE` at the Alpha pool and `W_COVERAGE` at the MVP
## pool ([method is_alpha_pool]): every [method ops_covered] op no collectible
## card uses (`field` `coverage.ops_covered.<op>`, recursing through
## `conditional`, `repeat` and `choose_one`); `modify_value` used by no boss
## passive or treasure (`coverage.modify_value`); a DD-M09 keyword on fewer than
## `coverage.kw_min` cards (`coverage.kw_min.<keyword>`); a hero set whose
## non-starter cards are in a bundle at a share under
## `coverage.bundle_coverage_min`, with the value (`coverage.bundle_coverage_min.<set>`).
## An `ops_exempt` op no card uses is `W_COVERAGE_UNUSED` at either pool.
## Example: `ContentValidator.check_coverage(pool, budgets, balance)`.
static func check_coverage(pool: Dictionary, budgets: Dictionary, _heroes_balance: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var unmet: StringName = E_COVERAGE if is_alpha_pool(pool) else W_COVERAGE
	var file: String = "content_budgets.json"
	var collectible: Array = (pool.get("cards", []) as Array).filter(_is_collectible)
	var used: Dictionary = {}
	for card: Dictionary in collectible:
		_collect_ops(card.get("effects", []), used)
	for op: String in ops_covered(budgets):
		if not used.has(op):
			rows.append(_entry(unmet, file, null, "coverage.ops_covered." + op, "op %s is used by no collectible card (F5, %d cards)" % [op, collectible.size()]))
	var value_used: Dictionary = {}
	for boss: Dictionary in pool.get("bosses", []):
		_collect_ops(boss.get("passive"), value_used)
	for treasure: Dictionary in pool.get("treasures", []):
		_collect_ops(treasure.get("effects", []), value_used)
	if not value_used.has(MODIFY_VALUE_OP):
		rows.append(_entry(unmet, file, null, "coverage.modify_value", "op modify_value is used by no boss passive or treasure (F5)"))
	var exempt: Variant = _at(budgets, "coverage.ops_exempt")
	for op: Variant in (exempt if exempt is Array else []):
		if not used.has(String(op)):
			rows.append(_entry(W_COVERAGE_UNUSED, file, null, "coverage.ops_exempt.%s" % op, "exempt op %s is used by no collectible card (F5)" % op))
	var kw_min: Variant = _at(budgets, "coverage.kw_min")
	if not _is_number(kw_min):
		rows.append(_entry(W_COVERAGE, file, null, "coverage.kw_min", "not checked — coverage.kw_min is absent or not a number"))
	else:
		for kw: String in RecordSchemas.KEYWORDS:
			var n: int = collectible.filter(func(c: Dictionary) -> bool: return Array(c.get("keywords", [])).has(kw)).size()
			if n < int(kw_min):
				rows.append(_entry(unmet, file, null, "coverage.kw_min." + kw, "keyword %s is on %d collectible cards, under kw_min %d (F5)" % [kw, n, int(kw_min)]))
	rows.append_array(_bundle_coverage(pool, collectible, budgets, unmet))
	return rows


static func _bundle_coverage(pool: Dictionary, collectible: Array, budgets: Dictionary, unmet: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var minimum: Variant = _at(budgets, "coverage.bundle_coverage_min")
	var starters: Dictionary = {}
	var hero_sets: Dictionary = {}
	for hero: Dictionary in pool.get("heroes", []):
		hero_sets[String(hero.set)] = true
		for id: Variant in hero.get("starter_deck", []):
			starters[String(id)] = true
	var bundled: Dictionary = {}
	for bundle: Dictionary in pool.get("bundles", []):
		for id: Variant in bundle.get("cards", []):
			bundled[String(id)] = true
	for set_id: String in hero_sets:
		var field: String = "coverage.bundle_coverage_min." + set_id
		var cards: Array = collectible.filter(func(c: Dictionary) -> bool: return c.set == set_id and not starters.has(String(c.id)))
		if not _is_number(minimum) or cards.is_empty():
			rows.append(_entry(W_COVERAGE, "bundles.json", null, field, "not checked — %s" % (
				"coverage.bundle_coverage_min is absent or not a number" if not _is_number(minimum) else "%s has no non-starter collectible card" % set_id)))
			continue
		var covered: int = cards.filter(func(c: Dictionary) -> bool: return bundled.has(String(c.id))).size()
		var share: float = float(covered) / cards.size()
		if share < float(minimum):
			rows.append(_entry(unmet, "bundles.json", null, field, "%s bundle_coverage %.2f (%d / %d non-starter cards in a bundle) under %s (F5)" % [
				set_id, share, covered, cards.size(), str(minimum)]))
	return rows


## Adds every op name in [param effects] (an effect Array, one effect object,
## or null) to [param into], recursing through nested op lists.
static func _collect_ops(effects: Variant, into: Dictionary) -> void:
	var list: Array = effects if effects is Array else ([effects] if effects is Dictionary else [])
	for effect: Variant in list:
		if effect is Dictionary:
			_collect_op_list((effect as Dictionary).get("ops", []), into)


static func _collect_op_list(ops: Variant, into: Dictionary) -> void:
	if not ops is Array:
		return
	for op: Variant in ops:
		if not op is Dictionary:
			continue
		into[String(op.get("op", ""))] = true
		for nested: String in ["then", "else", "ops"]:
			_collect_op_list(op.get(nested), into)
		for option: Variant in op.get("options", []):
			if option is Dictionary:
				_collect_op_list(option.get("ops"), into)


static func _card_value(card: Dictionary, by_id: Dictionary, budgets: Dictionary) -> Dictionary:
	var ctx: Dictionary = {"rates": _at(budgets, "budget.effect_points"), "tax": _at(budgets, "budget.keyword_tax"),
		"cards": by_id, "unvalued": []}
	if not ctx.rates is Dictionary:
		ctx.rates = {}
	if not ctx.tax is Dictionary:
		ctx.tax = {}
	var type: String = card.type
	var cost: int = int(card.cost)
	var points: float = 0.0
	match type:
		"minion": points = int(card.get("attack", 0)) + int(card.get("health", 0))
		"weapon": points = int(card.get("attack", 0)) * int(card.get("durability", 0))
	for kw: Variant in card.get("keywords", []):
		if String(kw) == RecordSchemas.SPELL_DAMAGE_KEYWORD:
			points += _tax(ctx, String(kw)) * int(card.get("spell_damage", 0))
		else:
			points += _tax(ctx, String(kw))
	for effect: Variant in card.get("effects", []):
		if not effect is Dictionary:
			continue
		var value: float = _ops_points((effect as Dictionary).get("ops", []), _selector(effect), ctx)
		if String(effect.get("trigger", "")) == DEATHRATTLE_TRIGGER:
			value *= _rate(ctx, "deathrattle_factor")
		points += value
	var shape: Dictionary = BUDGET_FORMULA.get(type, {})
	var budget: float = 0.0
	if not shape.is_empty():
		budget = shape.per_cost * cost + shape.flat + (floori(float(cost) / shape.floor_div) if int(shape.floor_div) > 0 else 0)
	return {"points": points, "budget": budget, "unvalued": ctx.unvalued}


## `{selector, filter, n}` of an effect's `targets` (string or object form).
static func _selector(effect: Dictionary) -> Dictionary:
	var targets: Variant = effect.get("targets")
	if targets is String:
		return {"selector": targets, "filter": {}, "n": 1}
	if targets is Dictionary:
		var n: Variant = targets.get("n", 1)
		return {"selector": String(targets.get("selector", "")), "filter": targets.get("filter", {}), "n": int(n) if _is_number(n) else 1}
	return {"selector": "", "filter": {}, "n": 1}


static func _ops_points(ops: Variant, sel: Dictionary, ctx: Dictionary) -> float:
	var total: float = 0.0
	if ops is Array:
		for op: Variant in ops:
			if op is Dictionary:
				total += _op_points(op, sel, ctx)
	return total


static func _op_points(op: Dictionary, sel: Dictionary, ctx: Dictionary) -> float:
	var name: String = String(op.get("op", ""))
	var selector: String = sel.selector
	var single: bool = SINGLE_SELECTORS.has(selector)
	match name:
		"damage":
			var amount: Variant = _literal(op, "amount", 0, ctx)
			if not DAMAGE_RATE_KEYS.has(selector):
				return _unvalued(ctx, "damage on selector \"%s\"" % selector)
			var points: float = 0.0
			for key: String in DAMAGE_RATE_KEYS[selector]:
				points += _rate(ctx, key)
			return points * float(amount) * int(sel.n)
		"heal":
			if not single:
				return _unvalued(ctx, "heal on selector \"%s\"" % selector)
			return float(_literal(op, "amount", 0, ctx)) * _rate(ctx, "heal")
		"draw":
			if String(op.get("side", "owner")) != "owner":
				return _unvalued(ctx, "draw for the opponent")
			return float(_literal(op, "count", 1, ctx)) * _rate(ctx, "draw")
		"discover":
			return _rate(ctx, "discover")
		"summon":
			var token: Variant = (ctx.cards as Dictionary).get(String(op.get("card_id", "")))
			if not token is Dictionary:
				return _unvalued(ctx, "summon of unknown card \"%s\"" % op.get("card_id", ""))
			var stats: int = int(token.get("attack", 0)) + int(token.get("health", 0))
			return stats * _rate(ctx, "summon_stat_point") * float(_literal(op, "count", 1, ctx))
		"buff":
			if not single:
				return _unvalued(ctx, "buff on selector \"%s\"" % selector)
			if op.has("cost"):
				return _unvalued(ctx, "buff cost")
			var granted: float = 0.0
			for kw: Variant in op.get("keywords", []):
				granted += _tax(ctx, String(kw))
			return (float(_literal(op, "attack", 0, ctx)) + float(_literal(op, "health", 0, ctx))) * _rate(ctx, "buff_point") + granted
		"give_keyword":
			if not single:
				return _unvalued(ctx, "give_keyword on selector \"%s\"" % selector)
			return _tax(ctx, String(op.get("keyword", "")))
		"destroy":
			var filter: Dictionary = sel.filter if sel.filter is Dictionary else {}
			if FRIENDLY_SELECTORS.has(selector) or (selector == EffectSchema.CHOSEN and filter.get("side") == "friendly"):
				return _rate(ctx, "self_destroy")
			if selector != EffectSchema.CHOSEN:
				return _unvalued(ctx, "destroy on selector \"%s\"" % selector)
			var restricted: bool = filter.keys().any(func(k: Variant) -> bool: return k != "side")
			return _rate(ctx, "destroy_restricted" if restricted else "destroy")
		"conditional":
			return _ops_points(op.get("then"), sel, ctx)
		"repeat":
			return float(_literal(op, "times", 1, ctx)) * _ops_points(op.get("ops"), sel, ctx)
		"choose_one":
			var best: float = 0.0
			var first: bool = true
			for option: Variant in op.get("options", []):
				if option is Dictionary:
					var value: float = _ops_points(option.get("ops"), sel, ctx)
					best = value if first else maxf(best, value)
					first = false
			return best
	if FLAT_OP_KEYS.has(name):
		if not single:
			return _unvalued(ctx, "%s on selector \"%s\"" % [name, selector])
		return _rate(ctx, FLAT_OP_KEYS[name])
	if AMOUNT_OP_KEYS.has(name):
		return float(_literal(op, "amount", 0, ctx)) * _rate(ctx, AMOUNT_OP_KEYS[name])
	return _unvalued(ctx, "op %s has no F3 rate" % name)


## `op[key]` as a number, [param absent] when the key is missing; a value
## expression (C4 object) is not valued and counts as 0.
static func _literal(op: Dictionary, key: String, absent: int, ctx: Dictionary) -> float:
	if not op.has(key):
		return absent
	var value: Variant = op[key]
	if _is_number(value):
		return float(value)
	_unvalued(ctx, "%s.%s is a value expression" % [op.get("op", ""), key])
	return 0.0


static func _rate(ctx: Dictionary, key: String) -> float:
	var value: Variant = (ctx.rates as Dictionary).get(key)
	if _is_number(value):
		return float(value)
	_unvalued(ctx, "budget.effect_points.%s absent" % key)
	return 0.0


## The F3 keyword tax of [param kw]; a keyword absent from `keyword_tax` is a
## marker whose effect is valued by its ops (Battlecry, Deathrattle …): 0.
static func _tax(ctx: Dictionary, kw: String) -> float:
	var value: Variant = (ctx.tax as Dictionary).get(kw)
	return float(value) if _is_number(value) else 0.0


static func _unvalued(ctx: Dictionary, reason: String) -> float:
	(ctx.unvalued as Array).append(reason)
	return 0.0


## "" when the Heroes F1 knobs are readable, else what is missing.
static func _starter_curve_gap(curve: Variant) -> String:
	if not curve is Dictionary:
		return "heroes_balance.starter_curve is absent"
	for key: String in ["avg_min", "avg_max", "max_cost"]:
		if not _is_number(curve.get(key)):
			return "heroes_balance.starter_curve.%s is absent or not a number" % key
	var bucket: Variant = curve.get("bucket")
	if not bucket is Dictionary or (bucket as Dictionary).is_empty():
		return "heroes_balance.starter_curve.bucket is absent"
	for key: Variant in bucket:
		var range_: Variant = bucket[key]
		if _bucket_low(String(key)) < 0 or not range_ is Array or (range_ as Array).size() != 2 \
				or not _is_number(range_[0]) or not _is_number(range_[1]):
			return "heroes_balance.starter_curve.bucket[\"%s\"] is not a \"<cost>\" or \"<n>_plus\" key with a [min, max] count" % key
	return ""


static func _starter_faults(starter: Variant, by_id: Dictionary, curve: Dictionary) -> PackedStringArray:
	var faults: PackedStringArray = []
	var costs: Array[int] = []
	for id: Variant in (starter if starter is Array else []):
		var card: Variant = by_id.get(String(id))
		if not card is Dictionary:
			faults.append("unknown card %s" % id)
			continue
		costs.append(int(card.cost))
	if costs.is_empty():
		faults.append("no starter cards to evaluate")
		return faults
	var total: int = 0
	var top: int = costs[0]
	for cost: int in costs:
		total += cost
		top = maxi(top, cost)
	var avg: float = float(total) / costs.size()
	if avg < float(curve.avg_min) or avg > float(curve.avg_max):
		faults.append("avg cost %.2f outside %s–%s" % [avg, str(curve.avg_min), str(curve.avg_max)])
	if top > int(curve.max_cost):
		faults.append("max cost %d above max_cost %d" % [top, int(curve.max_cost)])
	var counts: Dictionary = {}
	for key: Variant in curve.bucket:
		counts[String(key)] = 0
	for cost: int in costs:
		var key: String = _starter_bucket(cost, curve.bucket)
		if key.is_empty():
			faults.append("cost %d has no starter_curve bucket" % cost)
		else:
			counts[key] += 1
	for key: String in counts:
		var allowed: Array = curve.bucket[key]
		if counts[key] < int(allowed[0]) or counts[key] > int(allowed[1]):
			faults.append("cost %s: %d cards, allowed %d–%d" % [key.replace("_plus", "+"), counts[key], int(allowed[0]), int(allowed[1])])
	return faults


## The `starter_curve.bucket` key holding [param cost]: `"<cost>"` exactly,
## else the `"<n>_plus"` key with the largest `n` ≤ cost; "" when none.
static func _starter_bucket(cost: int, bucket: Dictionary) -> String:
	if bucket.has(str(cost)):
		return str(cost)
	var best: String = ""
	var best_low: int = -1
	for key: Variant in bucket:
		var k: String = String(key)
		if k.ends_with("_plus") and _bucket_low(k) <= cost and _bucket_low(k) > best_low:
			best = k
			best_low = _bucket_low(k)
	return best


## The lowest cost a bucket key names (`"3"` → 3, `"6_plus"` → 6), -1 if unreadable.
static func _bucket_low(key: String) -> int:
	var digits: String = key.trim_suffix("_plus")
	return int(digits) if digits.is_valid_int() else -1


static func _bucket_label(i: int, size: int) -> String:
	if i == 0:
		return "≤%d" % (i + 1)
	if i == size - 1:
		return "%d+" % (i + 1)
	return str(i + 1)


static func _is_collectible(card: Dictionary) -> bool:
	return not card.get("token", false) and String(card.set) != BOSS_SET


static func _index(cards: Array) -> Dictionary:
	var out: Dictionary = {}
	for card: Variant in cards:
		if card is Dictionary:
			out[String(card.id)] = card
	return out


## Cards grouped by `set` (insertion order), keeping those [param keep] accepts.
static func _by_set(cards: Array, keep: Callable) -> Dictionary:
	var out: Dictionary = {}
	for card: Dictionary in cards:
		if keep.call(card):
			if not out.has(String(card.set)):
				out[String(card.set)] = []
			out[String(card.set)].append(card)
	return out


## A CR-5 report entry; severity from the code prefix (`E_` error, else warning).
static func _entry(code: StringName, file: String, record_id: Variant, field: Variant, message: String) -> Dictionary:
	var severity: StringName = ValidationReport.SEVERITY_ERROR if String(code).begins_with("E_") else ValidationReport.SEVERITY_WARNING
	return {"severity": severity, "code": code, "file": file, "record_id": record_id, "field": field, "message": message}


static func _check_object(rows: Array[Dictionary], body: Dictionary, fields: Dictionary, prefix: String) -> void:
	for key: Variant in body:
		if not fields.has(key):
			var path: String = prefix + str(key)
			rows.append(_row(E_UNKNOWN_FIELD, path, "`%s` is not a content_budgets key (content CN-6 step 2)" % path))
	for key: String in fields:
		var path: String = prefix + key
		if not body.has(key):
			rows.append(_row(E_MISSING_FIELD, path, "missing `%s` (content CN-6 step 2; %s)" % [path, fields[key].row]))
			continue
		_check_value(rows, body[key], fields[key], path)


static func _check_value(rows: Array[Dictionary], value: Variant, spec: Dictionary, path: String) -> void:
	match spec.kind:
		K_OBJECT:
			if not value is Dictionary:
				rows.append(_row(E_SCHEMA, path, "`%s` must be an object, found %s" % [path, type_string(typeof(value))]))
				return
			_check_object(rows, value, spec.fields, path + ".")
		K_NUMBER, K_INT:
			_check_number(rows, value, spec, path)
		K_NUMBER_LIST:
			if not value is Array:
				rows.append(_row(E_SCHEMA, path, "`%s` must be an array of %d numbers, found %s" % [path, spec.size, type_string(typeof(value))]))
				return
			var items: Array = value
			if items.size() != int(spec.size):
				rows.append(_row(E_SCHEMA, path, "`%s` must hold exactly %d numbers, found %d (%s)" % [path, spec.size, items.size(), spec.row]))
				return
			for i: int in items.size():
				_check_number(rows, items[i], spec, "%s[%d]" % [path, i])
		K_NUMBER_MAP:
			if not value is Dictionary:
				rows.append(_row(E_SCHEMA, path, "`%s` must be an object of numbers, found %s" % [path, type_string(typeof(value))]))
				return
			for key: Variant in value:
				var entry_path: String = "%s.%s" % [path, str(key)]
				if spec.get("keys") == KEYWORD_KEYS and not RecordSchemas.KEYWORDS.has(key):
					rows.append(_row(E_UNKNOWN_FIELD, entry_path, "`%s` names no DD-M09 keyword (card-database CR-4)" % entry_path))
					continue
				_check_number(rows, value[key], spec, entry_path)
		K_OP_LIST:
			if not value is Array:
				rows.append(_row(E_SCHEMA, path, "`%s` must be an array of op names, found %s" % [path, type_string(typeof(value))]))
				return
			var ops: Array = value
			for i: int in ops.size():
				if not ops[i] is String or not EffectSchema.OPS.has(ops[i]):
					var item_path: String = "%s[%d]" % [path, i]
					rows.append(_row(E_SCHEMA, item_path, "`%s` \"%s\" is not a card-effects C5 op" % [item_path, str(ops[i])]))


static func _check_number(rows: Array[Dictionary], value: Variant, spec: Dictionary, path: String) -> void:
	if not _is_number(value):
		rows.append(_row(E_SCHEMA, path, "`%s` must be a number, found %s (%s)" % [path, str(value), type_string(typeof(value))]))
		return
	if spec.kind == K_INT and float(value) != floorf(float(value)):
		rows.append(_row(E_SCHEMA, path, "`%s` must be a whole number, found %s" % [path, str(value)]))
		return
	var bounds: Array = spec.range
	var low: Variant = bounds[0]
	var high: Variant = bounds[1]
	if (low != null and float(value) < float(low)) or (high != null and float(value) > float(high)):
		rows.append(_row(E_RANGE, path, "`%s` is %s, outside %s–%s (%s)" % [path, str(value),
			"−∞" if low == null else str(low), "∞" if high == null else str(high), spec.row]))


## The value at dotted [param path] in [param body], or `null`.
static func _at(body: Dictionary, path: String) -> Variant:
	var node: Variant = body
	for part: String in path.split("."):
		if not node is Dictionary or not (node as Dictionary).has(part):
			return null
		node = node[part]
	return node


static func _is_number(value: Variant) -> bool:
	var t: int = typeof(value)
	return (t == TYPE_INT or t == TYPE_FLOAT) and is_finite(float(value))


static func _row(code: StringName, field: String, message: String) -> Dictionary:
	return {"code": code, "host_id": null, "field": field, "message": message}
