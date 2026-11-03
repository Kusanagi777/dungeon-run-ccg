## The Card Effects static validator (design/gdd/card-effects.md C10; ADR-0007
## Decision 8): checks every effect object of one host against the DSL in
## `EffectSchema` and returns the problems it finds.
##
## Static and pure: no instance, no static mutable state, no engine, no RNG, no
## file, no error logging. It reads nothing but its arguments and allocates a new report
## per call, so Card Database stage 7b, `tools/content/validate.gd` and CI all
## run it headless. `db` is used for lookups only (`has`, `card`) — during stage
## 7 the database is `Loading` and answers nothing else (ADR-0002 Decision 4).
##
## Each entry is `{code, host_id, effect_id, path, message}` (C10): `code` is
## one of [constant CODES]; `effect_id` is the effect's `id`, or the default
## `<host_id>.<index>`, or `null` for a host-level warning; `path` is a
## JSON-pointer-like location under the host's field (`effects/1/ops/0/card_id`,
## or `passive/0/…` for a boss passive). `W_FX_*` codes are warnings and never
## fail the host; Card Database's merge maps them by prefix.
##
## Story 003 covers every code except `E_FX_BUDGET` and `E_FX_OP_TARGET`
## (story 004, with `step_bound` and `derive_targeting_spec`); both are in the
## closed set already.
##
## [codeblock]
## # Boot's stage-7b adapter (ADR-0002 Decision 4):
## func(kind, id, fx, db, configs): return EffectValidator.validate_effects(kind, id, fx, db, configs["card_effects"])
##
## var report: Array = EffectValidator.validate_effects(&"card", "war_raise_dead", effects, db, caps)
## report[0].code    # &"E_FX_REF"
## report[0].path    # "effects/0/ops/0/card_id"
## [/codeblock]
class_name EffectValidator
extends RefCounted

## Missing/extra field, wrong type, `ops` empty or over `MAX_OPS_PER_EFFECT`,
## duplicate `id` within the host.
const E_FX_SCHEMA: StringName = &"E_FX_SCHEMA"
## Unknown trigger, trigger illegal for the host kind (C2 Hosts), unknown scope key.
const E_FX_TRIGGER: StringName = &"E_FX_TRIGGER"
## Unknown selector; `self` on a treasure/passive; `adjacent` `of: self` on a
## non-minion host; `of: target` without `chosen`.
const E_FX_SELECTOR: StringName = &"E_FX_SELECTOR"
## Unknown filter predicate (or a predicate value outside its enum).
const E_FX_FILTER: StringName = &"E_FX_FILTER"
## Unknown op; op illegal under the trigger class; param out of range.
const E_FX_OP: StringName = &"E_FX_OP"
## Op on a selector that can never yield a legal kind (story 004).
const E_FX_OP_TARGET: StringName = &"E_FX_OP_TARGET"
## Op whose primitive the primitive table does not list.
const E_FX_OP_UNAVAILABLE: StringName = &"E_FX_OP_UNAVAILABLE"
## `card_id` not found via `has(id)`; summon/transform of a non-minion; equip of a non-weapon.
const E_FX_REF: StringName = &"E_FX_REF"
## Unknown `ref` path, or a context ref not available under this trigger.
const E_FX_REF_PATH: StringName = &"E_FX_REF_PATH"
## More than one `chosen` play effect per host; `chosen` on a non-play trigger
## or inside `choose_one` options.
const E_FX_CHOSEN: StringName = &"E_FX_CHOSEN"
## F6 static step bound over `EFFECT_STATIC_STEP_LIMIT` (story 004).
const E_FX_BUDGET: StringName = &"E_FX_BUDGET"
## Warning: display keyword without a matching effect/op, or vice versa.
const W_FX_KEYWORD_MISMATCH: StringName = &"W_FX_KEYWORD_MISMATCH"
## Warning: constant-false `condition`, or `repeat` with `times: 0`.
const W_FX_UNREACHABLE: StringName = &"W_FX_UNREACHABLE"

## The closed C10 code set. A code outside it is never emitted, and none is
## added without a card-effects GDD change (control manifest, Core Forbidden).
const CODES: Array[StringName] = [
	E_FX_SCHEMA, E_FX_TRIGGER, E_FX_SELECTOR, E_FX_FILTER, E_FX_OP,
	E_FX_OP_TARGET, E_FX_OP_UNAVAILABLE, E_FX_REF, E_FX_REF_PATH,
	E_FX_CHOSEN, E_FX_BUDGET, W_FX_KEYWORD_MISMATCH, W_FX_UNREACHABLE,
]

## The `caps` keys [method validate_effects] reads (the `card_effects` config
## body, card-effects Tuning Knobs). The GDD and ADR-0007 name the knobs
## UPPER_CASE (`MAX_REPEAT`); the file key is the snake_case spelling
## (`max_repeat`, DD-T01 — settled by story 002), and only that spelling is
## read. A missing cap skips its bound check: [method validate_config]
## (stage 7a) is what reports a missing knob.
const CAP_MAX_OPS_PER_EFFECT: String = "max_ops_per_effect"
const CAP_MAX_REPEAT: String = "max_repeat"
const CAP_MAX_SUMMON_COUNT: String = "max_summon_count"

## Host kinds Card Database stage 7b passes (card-database story 004), plus the
## C2 spellings. `card` resolves to the record `type` through `db.card(host_id)`;
## `boss` is the BossDef `passive` host.
const HOST_KIND_CARD: StringName = &"card"
const HOST_KIND_BOSS: StringName = &"boss"

## The keys of the `card_effects.json` config body: the card-effects Tuning
## Knobs, snake_case (DD-T01), whole-number knobs first — the order
## [method validate_config] reports in. Every knob is required; no other key is
## allowed.
const CONFIG_KEYS: Array[String] = [
	"discover_count", "max_ops_per_effect", "max_repeat", "max_summon_count",
	"effect_static_step_limit", "discover_exclude_hand", "spell_damage_default",
	"hooks_before_triggers",
]
## The whole-number Tuning Knobs of `card_effects.json` and their safe ranges
## `[min, max]`, inclusive (design/gdd/card-effects.md Tuning Knobs; F6
## variables). Validation bounds, not knob values: like
## `RulesEngine.CONFIG_SAFE_RANGES` they cannot come from the file they check.
## `tests/integration/card_effects/card_effects_config_file_test.gd` pins
## them, and the shipped values, to the GDD table.
const CONFIG_INT_RANGES: Dictionary[String, Array] = {
	"discover_count": [1, 5],
	"max_ops_per_effect": [4, 12],
	"max_repeat": [2, 20],
	"max_summon_count": [1, 7],
	"effect_static_step_limit": [50, 1000],
}
## The other Tuning Knobs and the only values their safe range allows
## (compared with type equality, so `"true"` is not `true`).
const CONFIG_ALLOWED_VALUES: Dictionary[String, Array] = {
	"discover_exclude_hand": [true, false],
	"spell_damage_default": ["auto", false],
	"hooks_before_triggers": [true],
}


## Validates every effect object of one host and returns a new report
## (`[{code, host_id, effect_id, path, message}]`, empty when clean).
## [param host_kind]: `card`, `hero_power`, `treasure`, `passive` / `boss`
## (or a card type `minion` / `spell` / `weapon` directly).
## [param host_id]: the record id; default effect ids are `<host_id>.<index>`.
## [param effects]: the record's `effects[]` (BossDef: `passive`).
## [param db]: the `CardDatabase` (lookups `has` / `card` only).
## TODO(card-database story 004): type [param db] as `CardDatabase` once its
## stage-7 lookups exist; until then a lookup double stands in for tests.
## [param caps]: the `card_effects` config body.
## [param primitives]: the match-rules primitive names `E_FX_OP_UNAVAILABLE`
## checks against; defaults to [constant EffectSchema.V1_PRIMITIVES]. Stage 7b
## passes five arguments and gets the default.
## Example: `EffectValidator.validate_effects(&"treasure", "neutral_grave_tithe", fx, db, caps)`.
static func validate_effects(host_kind: StringName, host_id: String, effects: Array, db: Variant, caps: Dictionary, primitives: PackedStringArray = EffectSchema.V1_PRIMITIVES) -> Array:
	var report: Array = []
	var record: Dictionary = _host_record(host_kind, host_id, db)
	var host: StringName = _host_type(host_kind, record)
	var root: String = "passive" if host == EffectSchema.HOST_PASSIVE else "effects"
	var seen_ids: Dictionary = {}
	var chosen_play_effects: int = 0
	for i: int in effects.size():
		var path: String = "%s/%d" % [root, i]
		var ctx: Dictionary = {
			"report": report, "host_id": host_id, "effect_id": "%s.%d" % [host_id, i],
			"host": host, "db": db, "caps": caps, "primitives": primitives,
			"trigger_known": false, "trigger_class": &"", "context": [],
			"has_chosen": false, "chosen_play": false, "in_option": false,
		}
		if not effects[i] is Dictionary:
			_add(ctx, E_FX_SCHEMA, path, "an effect is a JSON object, found %s" % type_string(typeof(effects[i])))
			continue
		var effect: Dictionary = effects[i]
		if effect.has("id"):
			if effect.id is String and not (effect.id as String).is_empty():
				ctx.effect_id = effect.id
			else:
				_add(ctx, E_FX_SCHEMA, path + "/id", "`id` must be a non-empty string")
		if seen_ids.has(ctx.effect_id):
			_add(ctx, E_FX_SCHEMA, path, "effect id `%s` is used twice in host `%s`" % [ctx.effect_id, host_id])
		seen_ids[ctx.effect_id] = true
		_check_effect(effect, path, ctx)
		if ctx.chosen_play:
			chosen_play_effects += 1
			if chosen_play_effects > 1:
				_add(ctx, E_FX_CHOSEN, path + "/targets", "host `%s` has more than one play effect with `chosen` (C1 rule 1: one `chosen` per play)" % host_id)
	if not record.is_empty():
		_check_display_keywords(record, effects, {
			"report": report, "host_id": host_id, "effect_id": null,
		})
	return report


## The `card_effects` config validator (card-database CR-5 stage 7a; ADR-0002
## Decision 4: `call(body, db) -> Array`), registered by `Boot` as
## `configs.card_effects` (story 002 AC-41 — it replaces the interim one of
## the 2026-11-03 code review under the same name). Keys are the snake_case
## [constant CONFIG_KEYS] (DD-T01); the GDD's UPPER_CASE names are not file
## keys. Static and pure ([param _db] is unused). Returns one `E_FX_SCHEMA`
## entry `{code, host_id: null, field, message}` per problem, `field` the file
## key, in [constant CONFIG_KEYS] order then unknown keys in body order; `[]`
## when the body is valid:
## - a knob that is absent;
## - a [constant CONFIG_INT_RANGES] knob that is not a whole number (JSON
##   numbers parse as `float`: `8.0` passes, `8.5`, `"8"`, `true` fail), or a
##   whole number outside its range;
## - a [constant CONFIG_ALLOWED_VALUES] knob holding any other value;
## - a key that is not a knob (a misspelt knob would otherwise go unnoticed
##   while the real one is reported missing).
## [codeblock]
## var errors: Array = EffectValidator.validate_config({"max_repeat": 30.0}, null)
## errors[0].field   # "discover_count" (missing); errors[2] is max_repeat out of range
## [/codeblock]
static func validate_config(body: Dictionary, _db: Variant) -> Array:
	var errors: Array = []
	for knob: String in CONFIG_KEYS:
		if not body.has(knob):
			errors.append(_config_error(knob, "missing knob `%s` (card-effects Tuning Knobs)" % knob))
		elif CONFIG_INT_RANGES.has(knob):
			var raw: Variant = body[knob]
			var is_number: bool = typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT
			var bounds: Array = CONFIG_INT_RANGES[knob]
			if not is_number or float(raw) != floorf(float(raw)):
				errors.append(_config_error(knob, "`%s` must be a whole number, found %s (%s)" % [knob, str(raw), type_string(typeof(raw))]))
			elif int(raw) < int(bounds[0]) or int(raw) > int(bounds[1]):
				errors.append(_config_error(knob, "`%s` is %d, outside the safe range %d–%d" % [knob, int(raw), int(bounds[0]), int(bounds[1])]))
		elif not _enum_has(CONFIG_ALLOWED_VALUES[knob], body[knob]):
			errors.append(_config_error(knob, "`%s` is one of %s, found %s" % [knob, str(CONFIG_ALLOWED_VALUES[knob]), str(body[knob])]))
	for key: Variant in body:
		if not CONFIG_KEYS.has(str(key)):
			errors.append(_config_error(str(key), "unknown knob `%s` (card-effects Tuning Knobs: %s)" % [key, ", ".join(CONFIG_KEYS)]))
	return errors


static func _config_error(knob: String, message: String) -> Dictionary:
	return {"code": E_FX_SCHEMA, "host_id": null, "field": knob, "message": message}


# --- Host ------------------------------------------------------------------------

static func _host_record(host_kind: StringName, host_id: String, db: Variant) -> Dictionary:
	if host_kind != HOST_KIND_CARD or db == null or not db.has(host_id):
		return {}
	var record: Variant = db.card(host_id)
	return record if record is Dictionary else {}


## The C2 host kind. A `card` whose record cannot be read stays `card`, which
## [method _host_allows] treats as any card type.
static func _host_type(host_kind: StringName, record: Dictionary) -> StringName:
	if host_kind == HOST_KIND_BOSS:
		return EffectSchema.HOST_PASSIVE
	if host_kind == HOST_KIND_CARD and record.has("type"):
		return StringName(str(record.type))
	return host_kind


static func _host_allows(hosts: Array, host: StringName) -> bool:
	if host == HOST_KIND_CARD:
		return hosts.has("minion") or hosts.has("spell") or hosts.has("weapon")
	return hosts.has(str(host))


static func _is_hook_host(host: StringName) -> bool:
	return host == EffectSchema.HOST_TREASURE or host == EffectSchema.HOST_PASSIVE


# --- Effect (C1, C2) -------------------------------------------------------------

static func _check_effect(effect: Dictionary, path: String, ctx: Dictionary) -> void:
	for key: Variant in effect.keys():
		if not EffectSchema.EFFECT_FIELDS.has(str(key)):
			_add(ctx, E_FX_SCHEMA, "%s/%s" % [path, key], "unknown effect field `%s` (C1)" % key)
	for key: String in EffectSchema.EFFECT_REQUIRED:
		if not effect.has(key):
			_add(ctx, E_FX_SCHEMA, path, "missing required field `%s` (C1)" % key)
	_check_trigger(effect, path, ctx)
	_check_effect_chosen(effect, path, ctx)
	if effect.has("scope"):
		_check_scope(effect.scope, path + "/scope", ctx)
	if effect.has("condition"):
		if not effect.condition is Dictionary:
			_add(ctx, E_FX_SCHEMA, path + "/condition", "`condition` is a JSON object")
		elif not (effect.condition as Dictionary).is_empty():
			if _check_condition(effect.condition, path + "/condition", ctx) == false:
				_add(ctx, W_FX_UNREACHABLE, path + "/condition", "`condition` is always false; the effect never runs")
	if effect.has("targets"):
		_check_selector(effect.targets, path + "/targets", ctx, true)
	if effect.has("once_per_turn") and not effect.once_per_turn is bool:
		_add(ctx, E_FX_SCHEMA, path + "/once_per_turn", "`once_per_turn` is a bool")
	if effect.has("ops"):
		_check_ops_list(effect.ops, path + "/ops", ctx, true)


static func _check_trigger(effect: Dictionary, path: String, ctx: Dictionary) -> void:
	if not effect.has("trigger"):
		return
	var trigger: Variant = effect.trigger
	if not trigger is String:
		_add(ctx, E_FX_SCHEMA, path + "/trigger", "`trigger` is a string")
		return
	if not EffectSchema.TRIGGERS.has(trigger):
		_add(ctx, E_FX_TRIGGER, path + "/trigger", "unknown trigger `%s` (C2)" % trigger)
		return
	var row: Dictionary = EffectSchema.TRIGGERS[trigger]
	ctx.trigger_known = true
	ctx.trigger_class = row.class
	ctx.context = row.context
	ctx.trigger_row = row
	if not _host_allows(row.hosts, ctx.host):
		_add(ctx, E_FX_TRIGGER, path + "/trigger", "trigger `%s` is not legal on a %s host (C2 Hosts: %s)" % [trigger, ctx.host, ", ".join(row.hosts)])


## Effect-level `chosen` (C1 rule 1): legal only under a play trigger. It makes
## `target` available to refs, `test` and `of` whether or not it is legal, so one
## mistake is reported once.
static func _check_effect_chosen(effect: Dictionary, path: String, ctx: Dictionary) -> void:
	if not effect.has("targets") or _selector_name(effect.targets) != EffectSchema.CHOSEN:
		return
	ctx.has_chosen = true
	if not ctx.trigger_known:
		return
	if ctx.trigger_class == EffectSchema.CLASS_PLAY:
		ctx.chosen_play = true
	else:
		_add(ctx, E_FX_CHOSEN, path + "/targets", "`chosen` is legal only under a play trigger (battlecry, cast, hero_power), not `%s`" % effect.trigger)


static func _check_scope(scope: Variant, path: String, ctx: Dictionary) -> void:
	if not scope is Dictionary:
		_add(ctx, E_FX_SCHEMA, path, "`scope` is a JSON object")
		return
	if not ctx.trigger_known:
		return
	var row: Dictionary = ctx.trigger_row
	for key: Variant in (scope as Dictionary).keys():
		if not (row.scope as Array).has(str(key)):
			_add(ctx, E_FX_TRIGGER, "%s/%s" % [path, key], "unknown scope key `%s` for this trigger (C2 Scope keys: %s)" % [key, ", ".join(row.scope) if not (row.scope as Array).is_empty() else "none"])
		elif (row.filter_scope as Array).has(str(key)):
			_check_filter(scope[key], "%s/%s" % [path, key], ctx)


# --- Selectors and filters (C3) -------------------------------------------------

static func _selector_name(selector: Variant) -> String:
	if selector is String:
		return selector
	if selector is Dictionary and (selector as Dictionary).get("selector") is String:
		return selector.selector
	return ""


## [param effect_level]: the effect's own `targets` (its `chosen` is checked by
## [method _check_effect_chosen]); otherwise an op-level `targets`, a `count`
## or an `exists` selector.
static func _check_selector(selector: Variant, path: String, ctx: Dictionary, effect_level: bool) -> void:
	var fields: Dictionary = {}
	if selector is Dictionary:
		fields = selector
		for key: Variant in fields.keys():
			if not EffectSchema.SELECTOR_FIELDS.has(str(key)):
				_add(ctx, E_FX_SELECTOR, "%s/%s" % [path, key], "unknown selector field `%s` (C3)" % key)
		if not fields.get("selector") is String:
			_add(ctx, E_FX_SELECTOR, path + "/selector", "an object selector names its `selector` as a string")
			return
	elif not selector is String:
		_add(ctx, E_FX_SELECTOR, path, "a selector is a name or an object (C3)")
		return
	var name: String = _selector_name(selector)
	if not EffectSchema.SELECTORS.has(name):
		_add(ctx, E_FX_SELECTOR, path, "unknown selector `%s` (C3)" % name)
		return
	if name == EffectSchema.CHOSEN and not effect_level:
		_check_inner_chosen(path, ctx)
	if name == EffectSchema.SELF and _is_hook_host(ctx.host):
		_add(ctx, E_FX_SELECTOR, path, "`self` is illegal on a %s host: it is not an entity in play (C3)" % ctx.host)
	if (name == "trigger_subject" or name == "trigger_source") and ctx.trigger_known and not (ctx.context as Array).has(name):
		_add(ctx, E_FX_SELECTOR, path, "`%s` is not available under this trigger (C2 Context refs)" % name)
	if fields.has("of") or EffectSchema.NEIGHBOUR_SELECTORS.has(name):
		_check_neighbour_anchor(name, fields, path, ctx)
	if fields.has("filter"):
		_check_filter(fields.filter, path + "/filter", ctx)
	if fields.has("n"):
		var n: Variant = _check_value(fields.n, path + "/n", ctx)
		if n != null and int(n) < 1:
			_add(ctx, E_FX_SELECTOR, path + "/n", "`n` must be at least 1, found %d" % int(n))
	if fields.has("optional") and not fields.optional is bool:
		_add(ctx, E_FX_SELECTOR, path + "/optional", "`optional` is a bool")


## A `chosen` below effect level: legal only as a reuse of the effect-level
## `chosen` of a play effect, never inside `choose_one` options (C5, C10).
static func _check_inner_chosen(path: String, ctx: Dictionary) -> void:
	if ctx.in_option:
		_add(ctx, E_FX_CHOSEN, path, "`chosen` inside a `choose_one` option is illegal; declare it at effect level (C8.3)")
	elif ctx.trigger_known and ctx.trigger_class != EffectSchema.CLASS_PLAY:
		_add(ctx, E_FX_CHOSEN, path, "`chosen` is legal only under a play trigger")
	elif not ctx.has_chosen:
		_add(ctx, E_FX_CHOSEN, path, "`chosen` below effect level must reuse an effect-level `chosen` (C1 rule 1: the targeting spec is the effect's `targets`)")


static func _check_neighbour_anchor(name: String, fields: Dictionary, path: String, ctx: Dictionary) -> void:
	if not EffectSchema.NEIGHBOUR_SELECTORS.has(name):
		_add(ctx, E_FX_SELECTOR, path + "/of", "`of` applies only to %s" % ", ".join(EffectSchema.NEIGHBOUR_SELECTORS))
		return
	var anchor: Variant = fields.get("of", EffectSchema.SELF)
	if not anchor is String or not EffectSchema.NEIGHBOUR_ANCHORS.has(anchor):
		_add(ctx, E_FX_SELECTOR, path + "/of", "`of` is one of %s" % ", ".join(EffectSchema.NEIGHBOUR_ANCHORS))
	elif anchor == EffectSchema.SELF and ctx.host != EffectSchema.HOST_MINION and ctx.host != HOST_KIND_CARD:
		_add(ctx, E_FX_SELECTOR, path, "`%s` of `self` needs a minion host; a %s is never a minion in play (C3)" % [name, ctx.host])
	elif anchor == "target" and not ctx.has_chosen:
		_add(ctx, E_FX_SELECTOR, path + "/of", "`of: target` needs an effect-level `chosen` (C3)")
	elif anchor == "trigger_subject" and ctx.trigger_known and not (ctx.context as Array).has("trigger_subject"):
		_add(ctx, E_FX_SELECTOR, path + "/of", "`of: trigger_subject` is not available under this trigger (C2 Context refs)")


static func _check_filter(filter: Variant, path: String, ctx: Dictionary) -> void:
	if not filter is Dictionary:
		_add(ctx, E_FX_FILTER, path, "a filter is a JSON object of predicates (C3)")
		return
	for key: Variant in (filter as Dictionary).keys():
		var where: String = "%s/%s" % [path, key]
		var value: Variant = filter[key]
		if not EffectSchema.FILTER_PREDICATES.has(key):
			_add(ctx, E_FX_FILTER, where, "unknown filter predicate `%s` (C3)" % key)
			continue
		match EffectSchema.FILTER_PREDICATES[key]:
			EffectSchema.PRED_ENUM:
				var allowed: Array = EffectSchema.FILTER_ENUMS[key]
				if not value is String or not allowed.has(value):
					_add(ctx, E_FX_FILTER, where, "`%s` is one of %s, found %s" % [key, ", ".join(allowed), str(value)])
			EffectSchema.PRED_BOOL:
				if not value is bool:
					_add(ctx, E_FX_FILTER, where, "`%s` is a bool" % key)
			EffectSchema.PRED_VALUE:
				_check_value(value, where, ctx)
			EffectSchema.PRED_KEYWORDS:
				var keywords: Array = value if value is Array else [value]
				for kw: Variant in keywords:
					if not kw is String or not EffectSchema.KEYWORDS.has(kw):
						_add(ctx, E_FX_FILTER, where, "`%s` names a DD-M09 keyword, found %s" % [key, str(kw)])
			EffectSchema.PRED_TRIGGER:
				if not value is String or not EffectSchema.TRIGGERS.has(value):
					_add(ctx, E_FX_FILTER, where, "`has_trigger` names a C2 trigger, found %s" % str(value))
			EffectSchema.PRED_STRING:
				if not value is String:
					_add(ctx, E_FX_FILTER, where, "`%s` is a string" % key)


# --- Values, references, conditions (C4) ----------------------------------------

## Checks a C4 value expression; returns its int when it is a literal, else
## `null`. JSON numbers arrive as floats; a whole float is an int literal.
static func _check_value(value: Variant, path: String, ctx: Dictionary) -> Variant:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		if float(value) != floorf(float(value)):
			_add(ctx, E_FX_SCHEMA, path, "values are whole numbers, found %s" % str(value))
			return null
		return int(value)
	if not value is Dictionary or (value as Dictionary).size() != 1:
		_add(ctx, E_FX_SCHEMA, path, "a value is an int or a one-key expression (C4), found %s" % str(value))
		return null
	var operator: String = str((value as Dictionary).keys()[0])
	var arg: Variant = value[operator]
	var where: String = "%s/%s" % [path, operator]
	if not EffectSchema.VALUE_OPERATORS.has(operator):
		_add(ctx, E_FX_SCHEMA, where, "unknown value expression `%s` (C4)" % operator)
	elif operator == "ref":
		_check_ref(arg, where, ctx)
	elif operator == "count":
		_check_selector(arg, where, ctx, false)
	else:
		var arity: int = EffectSchema.VALUE_OPERATORS[operator]
		if not arg is Array or (arity == -1 and (arg as Array).is_empty()) or (arity > 0 and (arg as Array).size() != arity):
			_add(ctx, E_FX_SCHEMA, where, "`%s` takes %s" % [operator, "one or more values" if arity == -1 else "%d values" % arity])
		else:
			for i: int in (arg as Array).size():
				_check_value(arg[i], "%s/%d" % [where, i], ctx)
	return null


## A C4 reference path: closed set, and trigger-gated context refs.
static func _check_ref(ref: Variant, path: String, ctx: Dictionary) -> void:
	if not ref is String:
		_add(ctx, E_FX_REF_PATH, path, "`ref` is a path string (C4)")
		return
	var parts: PackedStringArray = (ref as String).split(".")
	if parts.size() != 2 or parts[1].is_empty():
		_add(ctx, E_FX_REF_PATH, path, "unknown ref path `%s` (C4)" % ref)
		return
	var root: String = parts[0]
	var field: String = parts[1]
	if EffectSchema.REF_ENTITY_ROOTS.has(root):
		if not EffectSchema.REF_ENTITY_FIELDS.has(field):
			_add(ctx, E_FX_REF_PATH, path, "unknown ref path `%s` (C4: %s.%s)" % [ref, root, "|".join(EffectSchema.REF_ENTITY_FIELDS)])
		else:
			_check_ref_root_available(root, ref, path, ctx)
	elif EffectSchema.REF_SIDE_ROOTS.has(root):
		if not EffectSchema.REF_SIDE_FIELDS.has(field):
			_add(ctx, E_FX_REF_PATH, path, "unknown ref path `%s` (C4: %s.%s)" % [ref, root, "|".join(EffectSchema.REF_SIDE_FIELDS)])
	elif root == EffectSchema.REF_COUNTER_ROOT:
		pass
	elif not EffectSchema.REF_FIXED_PATHS.has(ref):
		_add(ctx, E_FX_REF_PATH, path, "unknown ref path `%s` (C4)" % ref)
	elif root == "context" and ctx.trigger_known and not (ctx.context as Array).has(ref):
		_add(ctx, E_FX_REF_PATH, path, "`%s` is not available under this trigger (C2 Context refs)" % ref)


## `target` needs an effect-level `chosen`; `trigger_subject` / `trigger_source`
## need a trigger that supplies them (C4, C2 last column).
static func _check_ref_root_available(root: String, ref: String, path: String, ctx: Dictionary) -> void:
	if root == "target" and not ctx.has_chosen:
		_add(ctx, E_FX_REF_PATH, path, "`%s` reads the `chosen` entity, and this effect has no `chosen` (C4)" % ref)
	elif (root == "trigger_subject" or root == "trigger_source") and ctx.trigger_known and not (ctx.context as Array).has(root):
		_add(ctx, E_FX_REF_PATH, path, "`%s` is not available under this trigger (C2 Context refs)" % ref)


## Checks a C4 condition; returns `true` / `false` when it is constant, else
## `null` (used for `W_FX_UNREACHABLE`).
static func _check_condition(condition: Variant, path: String, ctx: Dictionary) -> Variant:
	if not condition is Dictionary or (condition as Dictionary).size() != 1:
		_add(ctx, E_FX_SCHEMA, path, "a condition is a one-key object (C4)")
		return null
	var form: String = str((condition as Dictionary).keys()[0])
	var arg: Variant = condition[form]
	var where: String = "%s/%s" % [path, form]
	match form:
		"cmp":
			if not arg is Array or (arg as Array).size() != 3 or not EffectSchema.CMP_OPERATORS.has(arg[1]):
				_add(ctx, E_FX_SCHEMA, where, "`cmp` is [value, op, value] with op in %s" % " ".join(EffectSchema.CMP_OPERATORS))
				return null
			var lhs: Variant = _check_value(arg[0], where + "/0", ctx)
			var rhs: Variant = _check_value(arg[2], where + "/2", ctx)
			if lhs == null or rhs == null:
				return null
			return _compare(int(lhs), str(arg[1]), int(rhs))
		"exists":
			_check_selector(arg, where, ctx, false)
		"test":
			_check_test(arg, where, ctx)
		"holding":
			_check_filter(arg, where, ctx)
		"is_owner_turn":
			if not arg is bool:
				_add(ctx, E_FX_SCHEMA, where, "`is_owner_turn` is a bool")
		"all", "any":
			if not arg is Array:
				_add(ctx, E_FX_SCHEMA, where, "`%s` takes an array of conditions" % form)
				return null
			return _fold(form, arg, where, ctx)
		"not":
			var inner: Variant = _check_condition(arg, where, ctx)
			return null if inner == null else not bool(inner)
		_:
			_add(ctx, E_FX_SCHEMA, where, "unknown condition `%s` (C4)" % form)
	return null


static func _check_test(arg: Variant, path: String, ctx: Dictionary) -> void:
	if not arg is Array or (arg as Array).size() != 2 or not arg[0] is String:
		_add(ctx, E_FX_SCHEMA, path, "`test` is [reference, filter] (C4)")
		return
	if not EffectSchema.TEST_REFS.has(arg[0]):
		_add(ctx, E_FX_REF_PATH, path + "/0", "`test` names one of %s, found `%s`" % [", ".join(EffectSchema.TEST_REFS), arg[0]])
	else:
		_check_ref_root_available(arg[0], arg[0], path + "/0", ctx)
	_check_filter(arg[1], path + "/1", ctx)


## Three-valued `all` / `any` over the members' constant values.
static func _fold(form: String, members: Array, path: String, ctx: Dictionary) -> Variant:
	var decided: bool = form == "any"      # `any` is decided by a true member, `all` by a false one
	var unknown: bool = false
	var hit: bool = false
	for i: int in members.size():
		var value: Variant = _check_condition(members[i], "%s/%d" % [path, i], ctx)
		if value == null:
			unknown = true
		elif bool(value) == decided:
			hit = true
	if hit:
		return decided
	return null if unknown else not decided


static func _compare(lhs: int, operator: String, rhs: int) -> bool:
	match operator:
		"==":
			return lhs == rhs
		"!=":
			return lhs != rhs
		"<":
			return lhs < rhs
		"<=":
			return lhs <= rhs
		">":
			return lhs > rhs
	return lhs >= rhs


# --- Ops (C5) ------------------------------------------------------------------

## [param top_level]: the effect's own `ops` (bounded by `MAX_OPS_PER_EFFECT`).
static func _check_ops_list(ops: Variant, path: String, ctx: Dictionary, top_level: bool) -> void:
	if not ops is Array:
		_add(ctx, E_FX_SCHEMA, path, "`ops` is an array of ops")
		return
	if (ops as Array).is_empty():
		_add(ctx, E_FX_SCHEMA, path, "`ops` is empty; an effect runs 1 or more ops (C1)")
		return
	var max_ops: Variant = _cap(ctx.caps, CAP_MAX_OPS_PER_EFFECT)
	if top_level and max_ops != null and (ops as Array).size() > int(max_ops):
		_add(ctx, E_FX_SCHEMA, path, "%d ops, over MAX_OPS_PER_EFFECT %d (C1)" % [(ops as Array).size(), int(max_ops)])
	for i: int in (ops as Array).size():
		_check_op(ops[i], "%s/%d" % [path, i], ctx)


static func _check_op(op: Variant, path: String, ctx: Dictionary) -> void:
	if not op is Dictionary or not (op as Dictionary).get("op") is String:
		_add(ctx, E_FX_SCHEMA, path, "an op is a JSON object with a string `op` (C5)")
		return
	var name: String = op.op
	if not EffectSchema.OPS.has(name):
		_add(ctx, E_FX_OP, path + "/op", "unknown op `%s` (C5)" % name)
		return
	var row: Dictionary = EffectSchema.OPS[name]
	_check_op_class(name, path, ctx)
	_check_op_primitives(name, op, path, ctx)
	var params: Dictionary = row.params
	for key: Variant in (op as Dictionary).keys():
		if key != "op" and key != "targets" and not params.has(key):
			_add(ctx, E_FX_SCHEMA, "%s/%s" % [path, key], "unknown param `%s` for op `%s` (C5)" % [key, name])
	for key: String in row.required:
		if not op.has(key):
			_add(ctx, E_FX_SCHEMA, path, "op `%s` needs `%s` (C5)" % [name, key])
	if row.has("one_of"):
		var present: Array = (row.one_of as Array).filter(func(k: String) -> bool: return op.has(k))
		if present.size() != 1:
			_add(ctx, E_FX_SCHEMA, path, "op `%s` takes exactly one of %s (C5)" % [name, ", ".join(row.one_of)])
	if name == "discover" and op.get("pool") == "list" and not op.has("list"):
		_add(ctx, E_FX_SCHEMA, path, "`discover` with `pool: list` needs `list` (C5)")
	if op.has("targets"):
		_check_selector(op.targets, path + "/targets", ctx, false)
	for key: Variant in (op as Dictionary).keys():
		if params.has(key):
			_check_param(name, key, params[key], op[key], "%s/%s" % [path, key], ctx)


## Trigger-class legality (C5, C10): `modify_value` alone under value triggers,
## `aura` only under static triggers.
static func _check_op_class(name: String, path: String, ctx: Dictionary) -> void:
	if not ctx.trigger_known:
		return
	var trigger_class: StringName = ctx.trigger_class
	if trigger_class == EffectSchema.CLASS_VALUE and name != EffectSchema.VALUE_ONLY_OP:
		_add(ctx, E_FX_OP, path + "/op", "only `modify_value` may run under a value trigger, found `%s` (C2)" % name)
	elif name == EffectSchema.VALUE_ONLY_OP and trigger_class != EffectSchema.CLASS_VALUE:
		_add(ctx, E_FX_OP, path + "/op", "`modify_value` is legal only under a value trigger (C5)")
	elif name == EffectSchema.STATIC_ONLY_OP and trigger_class != EffectSchema.CLASS_STATIC:
		_add(ctx, E_FX_OP, path + "/op", "`aura` is legal only under `aura` / `passive_hand` (C5)")


static func _check_op_primitives(name: String, op: Dictionary, path: String, ctx: Dictionary) -> void:
	var needed: Array = (EffectSchema.OPS[name].primitives as Array).duplicate()
	if name == "discover":
		needed.append_array(EffectSchema.DISCOVER_THEN_PRIMITIVES.get(op.get("then", "add_to_hand"), []))
	var table: PackedStringArray = ctx.primitives
	for primitive: String in needed:
		if not table.has(primitive):
			_add(ctx, E_FX_OP_UNAVAILABLE, path, "op `%s` needs primitive `%s`, which match-rules does not expose" % [name, primitive])


static func _check_param(op_name: String, key: String, kind: Variant, value: Variant, path: String, ctx: Dictionary) -> void:
	if kind is Array:
		if not _enum_has(kind, value):
			_add(ctx, E_FX_OP, path, "`%s` is one of %s, found %s" % [key, ", ".join((kind as Array).map(func(v: Variant) -> String: return str(v))), str(value)])
		return
	match kind:
		EffectSchema.P_VALUE:
			var literal: Variant = _check_value(value, path, ctx)
			if op_name == "repeat" and key == "times" and literal != null:
				_check_repeat_times(int(literal), path, ctx)
		EffectSchema.P_COUNT:
			var count: Variant = _check_value(value, path, ctx)
			if count != null:
				_check_count(op_name, int(count), path, ctx)
		EffectSchema.P_STRING:
			if not value is String or (value as String).is_empty():
				_add(ctx, E_FX_SCHEMA, path, "`%s` is a non-empty string" % key)
		EffectSchema.P_CARD_ID:
			if not value is String:
				_add(ctx, E_FX_SCHEMA, path, "`%s` is a card id string" % key)
			else:
				_check_card_ref(op_name, value, path, ctx)
		EffectSchema.P_CARD_LIST:
			_check_card_list(value, path, ctx)
		EffectSchema.P_KEYWORD:
			if not value is String or not EffectSchema.KEYWORDS.has(value):
				_add(ctx, E_FX_OP, path, "`%s` is a DD-M09 keyword, found %s" % [key, str(value)])
		EffectSchema.P_GRANT_KEYWORD:
			_check_grant_keyword(value, path, ctx)
		EffectSchema.P_GRANT_KEYWORDS:
			if not value is Array:
				_add(ctx, E_FX_SCHEMA, path, "`%s` is an array of keywords" % key)
			else:
				for i: int in (value as Array).size():
					_check_grant_keyword(value[i], "%s/%d" % [path, i], ctx)
		EffectSchema.P_FILTER:
			_check_filter(value, path, ctx)
		EffectSchema.P_FROM:
			_check_from(value, path, ctx)
		EffectSchema.P_CONDITION:
			_check_condition(value, path, ctx)
		EffectSchema.P_OPS:
			_check_ops_list(value, path, ctx, false)
		EffectSchema.P_OPTIONS:
			_check_options(value, path, ctx)
		EffectSchema.P_NON_NEG_INT:
			var number: Variant = _check_value(value, path, ctx)
			if not value is Dictionary and number != null and int(number) < 0:
				_add(ctx, E_FX_OP, path, "`%s` is an int ≥ 0, found %d" % [key, int(number)])
			elif value is Dictionary:
				_add(ctx, E_FX_SCHEMA, path, "`%s` is an int literal" % key)


## Enum membership with type equality, so `true` never matches `"true"` and a
## JSON bool is compared only with the enum's bools.
static func _enum_has(allowed: Array, value: Variant) -> bool:
	for candidate: Variant in allowed:
		if typeof(candidate) == typeof(value) and candidate == value:
			return true
	return false


## `repeat.times` (C5: 1–`MAX_REPEAT`); a literal 0 is reachable data that does
## nothing, so it warns instead (C10 `W_FX_UNREACHABLE`).
static func _check_repeat_times(times: int, path: String, ctx: Dictionary) -> void:
	var max_repeat: Variant = _cap(ctx.caps, CAP_MAX_REPEAT)
	if times == 0:
		_add(ctx, W_FX_UNREACHABLE, path, "`repeat` with `times: 0` never runs its ops")
	elif times < 0 or (max_repeat != null and times > int(max_repeat)):
		_add(ctx, E_FX_OP, path, "`times` is 1–MAX_REPEAT (%s), found %d (C5)" % [str(max_repeat), times])


## A literal `count` is at least 1; `summon` is capped at `MAX_SUMMON_COUNT` (C5).
static func _check_count(op_name: String, count: int, path: String, ctx: Dictionary) -> void:
	var max_summon: Variant = _cap(ctx.caps, CAP_MAX_SUMMON_COUNT)
	if count < 1:
		_add(ctx, E_FX_OP, path, "`count` is at least 1, found %d" % count)
	elif op_name == "summon" and max_summon != null and count > int(max_summon):
		_add(ctx, E_FX_OP, path, "`summon` `count` is 1–MAX_SUMMON_COUNT (%d), found %d (C5)" % [int(max_summon), count])


static func _check_grant_keyword(value: Variant, path: String, ctx: Dictionary) -> void:
	if not value is String or not EffectSchema.KEYWORDS.has(value):
		_add(ctx, E_FX_OP, path, "a granted keyword is a DD-M09 id, found %s" % str(value))
	elif EffectSchema.UNGRANTABLE_KEYWORDS.has(value):
		_add(ctx, E_FX_OP, path, "`%s` cannot be granted (C5 give_keyword, C7)" % value)


## `card_id` resolution (C10 `E_FX_REF`): the id exists, and `summon` /
## `transform` name a minion, `equip` a weapon.
static func _check_card_ref(op_name: String, card_id: String, path: String, ctx: Dictionary) -> void:
	var db: Variant = ctx.db
	if db == null or not db.has(card_id):
		_add(ctx, E_FX_REF, path, "card `%s` not found in the Card Database" % card_id)
		return
	var wanted: String = ""
	if EffectSchema.MINION_CARD_OPS.has(op_name):
		wanted = "minion"
	elif EffectSchema.WEAPON_CARD_OPS.has(op_name):
		wanted = "weapon"
	if wanted.is_empty():
		return
	var record: Variant = db.card(card_id)
	var found: String = str(record.get("type", "")) if record is Dictionary else ""
	if found != wanted:
		_add(ctx, E_FX_REF, path, "`%s` needs a %s, and `%s` is a %s" % [op_name, wanted, card_id, found if not found.is_empty() else "record without a type"])


static func _check_card_list(value: Variant, path: String, ctx: Dictionary) -> void:
	if not value is Array:
		_add(ctx, E_FX_SCHEMA, path, "`list` is an array of card ids")
		return
	for i: int in (value as Array).size():
		if not value[i] is String:
			_add(ctx, E_FX_SCHEMA, "%s/%d" % [path, i], "`list` holds card id strings")
		else:
			_check_card_ref("discover", value[i], "%s/%d" % [path, i], ctx)


static func _check_from(value: Variant, path: String, ctx: Dictionary) -> void:
	if not value is Dictionary:
		_add(ctx, E_FX_SCHEMA, path, "`from` is {pool, filter} (C5)")
		return
	for key: Variant in (value as Dictionary).keys():
		if not EffectSchema.FROM_FIELDS.has(str(key)):
			_add(ctx, E_FX_SCHEMA, "%s/%s" % [path, key], "unknown `from` field `%s` (C5)" % key)
	if not value.has("pool"):
		_add(ctx, E_FX_SCHEMA, path, "`from` needs `pool` (C5)")
	elif not _enum_has(EffectSchema.DISCOVER_POOLS, value.pool):
		_add(ctx, E_FX_OP, path + "/pool", "`pool` is one of %s, found %s" % [", ".join(EffectSchema.DISCOVER_POOLS), str(value.pool)])
	if value.has("filter"):
		_check_filter(value.filter, path + "/filter", ctx)
	if value.has("list"):
		_check_card_list(value.list, path + "/list", ctx)


## `choose_one.options`: 2–4 `{label_key, ops}`; a `chosen` inside is illegal.
static func _check_options(value: Variant, path: String, ctx: Dictionary) -> void:
	if not value is Array:
		_add(ctx, E_FX_SCHEMA, path, "`options` is an array of {label_key, ops}")
		return
	var options: Array = value
	if options.size() < EffectSchema.CHOOSE_ONE_OPTIONS_MIN or options.size() > EffectSchema.CHOOSE_ONE_OPTIONS_MAX:
		_add(ctx, E_FX_OP, path, "`choose_one` has %d–%d options, found %d (C5)" % [EffectSchema.CHOOSE_ONE_OPTIONS_MIN, EffectSchema.CHOOSE_ONE_OPTIONS_MAX, options.size()])
	var was_in_option: bool = ctx.in_option
	ctx.in_option = true
	for i: int in options.size():
		var where: String = "%s/%d" % [path, i]
		if not options[i] is Dictionary:
			_add(ctx, E_FX_SCHEMA, where, "an option is {label_key, ops}")
			continue
		var option: Dictionary = options[i]
		for key: Variant in option.keys():
			if not EffectSchema.OPTION_FIELDS.has(str(key)):
				_add(ctx, E_FX_SCHEMA, "%s/%s" % [where, key], "unknown option field `%s` (C5)" % key)
		if not option.get("label_key") is String:
			_add(ctx, E_FX_SCHEMA, where, "an option needs a string `label_key`")
		if not option.has("ops"):
			_add(ctx, E_FX_SCHEMA, where, "an option needs `ops`")
		else:
			_check_ops_list(option.ops, where + "/ops", ctx, false)
	ctx.in_option = was_in_option


# --- Display keywords (C1 rule 2) -----------------------------------------------

static func _check_display_keywords(record: Dictionary, effects: Array, ctx: Dictionary) -> void:
	var keywords: Array = record.get("keywords", []) if record.get("keywords") is Array else []
	var triggers: Dictionary = {}
	var ops: Dictionary = {}
	for effect: Variant in effects:
		if effect is Dictionary:
			triggers[str(effect.get("trigger", ""))] = true
			_collect_op_names(effect.get("ops", []), ops)
	for keyword: String in EffectSchema.DISPLAY_KEYWORDS:
		var backing: Dictionary = EffectSchema.DISPLAY_KEYWORDS[keyword]
		var backed: bool = triggers.has(backing.trigger) if backing.has("trigger") else ops.has(backing.op)
		var shown: bool = keywords.has(keyword)
		if shown and not backed:
			_add(ctx, W_FX_KEYWORD_MISMATCH, "keywords", "keyword `%s` is shown but no effect backs it (C1 rule 2)" % keyword)
		elif backed and not shown:
			_add(ctx, W_FX_KEYWORD_MISMATCH, "keywords", "an effect is `%s`-shaped but `keywords[]` does not show `%s` (C1 rule 2)" % [keyword, keyword])


## Every op name in an ops tree, nested `then` / `else` / `ops` / `options` included.
static func _collect_op_names(ops: Variant, into: Dictionary) -> void:
	if not ops is Array:
		return
	for op: Variant in ops:
		if not op is Dictionary:
			continue
		into[str(op.get("op", ""))] = true
		for key: String in ["then", "else", "ops"]:
			_collect_op_names(op.get(key), into)
		if op.get("options") is Array:
			for option: Variant in op.options:
				if option is Dictionary:
					_collect_op_names(option.get("ops"), into)


# --- Report ------------------------------------------------------------------------

## The cap [param name] (a snake_case [constant CONFIG_KEYS] key) from
## [param caps], or `null` when absent.
static func _cap(caps: Dictionary, name: String) -> Variant:
	return caps.get(name)


static func _add(ctx: Dictionary, code: StringName, path: String, message: String) -> void:
	(ctx.report as Array).append({
		"code": code,
		"host_id": ctx.host_id,
		"effect_id": ctx.effect_id,
		"path": path,
		"message": message,
	})
