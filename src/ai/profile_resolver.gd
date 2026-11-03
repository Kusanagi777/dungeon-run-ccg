## Builds the profile one boss plays with (design/gdd/boss-ai.md C10, F9,
## Edge Cases "Data and determinism"; TR-boss-ai-005).
##
## `resolve(config, boss_def, band)` returns
## `default ⊕ archetype ⊕ bands[band] ⊕ boss_override` — later layers win,
## **shallowly per section**: the map sections `weights`, `rules`, `budgets`
## and `choice_preference` merge key by key (a later key replaces the earlier
## value of that key and leaves the others), while `intent_mode` and
## `synergy_tags` are single values a later layer replaces whole. A value
## inside a section is one value too: `rules.defensive_multipliers` from a
## later layer replaces the earlier object, it is not merged into it.
##
## Which layers apply, from the BossDef's `ai_profile` key:
## - a `boss_overrides` key whose `extends` names a `profiles` entry →
##   `default ⊕ profiles[extends] ⊕ bands[band] ⊕ the override`;
## - a `profiles` key → `default ⊕ profiles[key] ⊕ bands[band]`;
## - anything else (missing, unknown, or an override whose `extends` is
##   unknown — each an `E_AI_PROFILE_UNKNOWN` at load) →
##   `default ⊕ bands[band]` (A25; C10 "any `E_AI_*` falls back to `default`").
##
## The resolver repairs what `BossAI.validate_profiles_config` reports, so a
## release build still plays (C10): a finite number outside its
## `BossAI.RANGES` row is **clamped** into it (A26 — never zeroed); a value
## that is not a number, non-finite, fractional for an integer knob, of the
## wrong type, outside its enum, or an unknown key is **skipped**, so the
## earlier layer's value stands; `intent_mode: hidden` is taken only from the
## override layer (C8.4, D-04). It supplies no default of its own: a key no
## layer sets is absent from the result (there is no runtime default — the
## file's absence is Card Database's `E_MISSING_FILE`; headless tests inject a
## stub body).
##
## The config is the frozen `config("ai_profiles")` snapshot: the resolver
## only reads it and returns newly allocated containers, so editing the result
## never reaches the snapshot. Static and pure; safe on any thread.
## [codeblock]
## var profile: Dictionary = ProfileResolver.resolve(db.config("ai_profiles"), db.boss(boss_id), band)
## profile.weights.w_face    # the resolved F1 weight
## profile.budgets           # the band's F7 budgets
## [/codeblock]
class_name ProfileResolver
extends RefCounted

## The sections merged key by key; every other section is replaced whole.
const MAP_SECTIONS: Array[String] = ["weights", "rules", "budgets", "choice_preference"]


## The resolved profile for [param boss_def] (a CR-3 BossDef; only its
## `ai_profile` is read) at [param band] (1-3, the `bands` key) from
## [param config], the parsed `ai_profiles` body. Always returns a Dictionary
## with `weights`, `rules`, `budgets`, `choice_preference` (objects) and
## `synergy_tags` (array), plus `intent_mode` when any layer sets a legal one.
## [codeblock]
## # F9: boss_rot_warden {extends: passive_driven, synergy_tags: [deathrattle], weights: {w_self: 1.5}}
## var p: Dictionary = ProfileResolver.resolve(config, rot_warden_def, 2)
## p.weights.w_passive   # 2.5 (passive_driven)
## p.weights.w_self      # 1.5 (the override)
## p.synergy_tags        # ["deathrattle"]
## [/codeblock]
static func resolve(config: Dictionary, boss_def: Dictionary, band: int) -> Dictionary:
	var profiles: Dictionary = _object(config.get("profiles"))
	var overrides: Dictionary = _object(config.get("boss_overrides"))
	var band_layer: Variant = _object(config.get("bands")).get(str(band))
	var key: Variant = boss_def.get("ai_profile")
	var archetype: Variant = null
	var override: Variant = null
	if key is String and overrides.has(key):
		var parent: Variant = _object(overrides[key]).get(BossAI.EXTENDS_KEY)
		if parent is String and profiles.has(parent):
			archetype = profiles[parent]
			override = overrides[key]
	elif key is String and profiles.has(key):
		archetype = profiles[key]

	var result: Dictionary = {"weights": {}, "rules": {}, "budgets": {}, "choice_preference": {}, "synergy_tags": []}
	_apply(result, profiles.get(BossAI.DEFAULT_PROFILE), false)
	_apply(result, archetype, false)
	_apply(result, band_layer, false)
	_apply(result, override, true)
	return result


## Layers [param layer] onto [param result]; `hidden` is accepted only when
## [param allow_hidden] (the override layer).
static func _apply(result: Dictionary, layer: Variant, allow_hidden: bool) -> void:
	if not layer is Dictionary:
		return
	for section: String in MAP_SECTIONS:
		var given: Variant = layer.get(section)
		if not given is Dictionary:
			continue
		for field: Variant in given:
			var value: Variant = _usable(section, field, given[field])
			if value != null:
				result[section][field] = value
	var mode: Variant = layer.get("intent_mode")
	if mode is String and BossAI.INTENT_MODES.has(mode) and (allow_hidden or mode != BossAI.OVERRIDE_ONLY_INTENT):
		result["intent_mode"] = mode
	var tags: Variant = layer.get("synergy_tags")
	if tags is Array:
		var kept: Array = []
		for tag: Variant in tags:
			if tag is String and not (tag as String).is_empty():
				kept.append(tag)
		result["synergy_tags"] = kept


## The value to store for [param field] of [param section], or `null` to keep
## the earlier layer's value.
static func _usable(section: String, field: Variant, value: Variant) -> Variant:
	match section:
		"weights":
			return _ranged(field, value) if BossAI.WEIGHT_KEYS.has(field) else null
		"budgets":
			return _ranged(field, value) if BossAI.BUDGET_KEYS.has(field) else null
		"choice_preference":
			return _ranged("choice_preference", value) if field is String else null
		"rules":
			return _usable_rule(field, value)
	return null


static func _usable_rule(field: Variant, value: Variant) -> Variant:
	if not BossAI.RULE_KEYS.has(field):
		return null
	if BossAI.RANGES.has(field):
		return _ranged(field, value)
	if BossAI.RULE_ENUMS.has(field):
		return value if value is String and BossAI.RULE_ENUMS[field].has(value) else null
	if BossAI.RULE_FLAGS.has(field):
		return value if typeof(value) == TYPE_BOOL else null
	if field == BossAI.DEFENSIVE_MULTIPLIERS_KEY and value is Dictionary:
		var multipliers: Dictionary = {}
		for weight: Variant in value:
			var factor: Variant = value[weight]
			if BossAI.WEIGHT_KEYS.has(weight) and BossAI.is_number(factor) and is_finite(float(factor)) and float(factor) >= 0.0:
				multipliers[weight] = float(factor)
		return multipliers
	return null


## A usable number for [constant BossAI.RANGES] row [param range_key]: the
## value as a float, clamped into the row when it is only out of range;
## `null` when it is unusable (not a number, non-finite, fractional for an
## integer knob).
static func _ranged(range_key: String, value: Variant) -> Variant:
	var problem: String = BossAI.range_problem(range_key, value)
	if problem.is_empty():
		return float(value)
	if problem == "out_of_range":
		var bounds: Dictionary = BossAI.RANGES[range_key]
		return clampf(float(value), bounds.min, bounds.max)
	return null


static func _object(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
