## card-effects story 003 — `EffectValidator.validate_effects`: schema, trigger,
## selector, filter, op, reference and warning checks (design/gdd/card-effects.md
## C1–C5, C10; AC-02, AC-03, AC-04, AC-06; ADR-0007 Decision 8).
##
## Effect objects are written as JSON text and parsed with `JSON.parse_string`,
## the way the loader reads them, so numbers arrive as floats (DSL spike
## finding 11). The database is a local lookup double (`FixtureDb`) answering
## only `has(id)` / `card(id)` — what Card Database answers during stage 7b
## (ADR-0002 Decision 4). Caps come from `TestConstants`; no file is read.
extends GdUnitTestSuite

const ENTRY_KEYS: Array[String] = ["code", "host_id", "effect_id", "path", "message"]
## card-effects C10, in table order (13 names).
const C10_CODES: Array[String] = [
	"E_FX_SCHEMA", "E_FX_TRIGGER", "E_FX_SELECTOR", "E_FX_FILTER", "E_FX_OP",
	"E_FX_OP_TARGET", "E_FX_OP_UNAVAILABLE", "E_FX_REF", "E_FX_REF_PATH",
	"E_FX_CHOSEN", "E_FX_BUDGET", "W_FX_KEYWORD_MISMATCH", "W_FX_UNREACHABLE",
]

# --- Fixture ids ----------------------------------------------------------------
const MINION_HOST: String = "neutral_test_fx_minion"
const SPELL_HOST: String = "neutral_test_fx_spell"
const WEAPON_HOST: String = "neutral_test_fx_weapon"
const POWER_HOST: String = "power_test_fx"
const TREASURE_HOST: String = "treasure_test_fx"
const BOSS_HOST: String = "boss_test_fx"
const HUSK: String = "decay_husk"
const AXE: String = "war_token_axe"
const BLADE: String = "war_whetstone_blade"
const SHEEP: String = "neutral_sheep"
const BOLT: String = "neutral_test_bolt"


## A lookup-only stand-in for `CardDatabase` in `Loading` (stage 7b): `has` and
## `card` over a fixed record set; nothing else.
class FixtureDb:
	extends RefCounted
	var _records: Dictionary = {}

	func _init(records: Array) -> void:
		for r: Dictionary in records:
			_records[r.id] = r

	func has(id: String) -> bool:
		return _records.has(id)

	func card(id: String) -> Variant:
		return _records.get(id)


# --- Helpers --------------------------------------------------------------------

func _caps() -> Dictionary:
	return {
		# snake_case keys: the `card_effects.json` spelling (DD-T01, story 002).
		"max_ops_per_effect": TestConstants.MAX_OPS_PER_EFFECT,
		"max_repeat": TestConstants.MAX_REPEAT,
		# card-effects F6: MAX_SUMMON_COUNT default 7 (= BOARD_SIZE).
		"max_summon_count": TestConstants.BOARD_SIZE,
		"effect_static_step_limit": TestConstants.EFFECT_STATIC_STEP_LIMIT,
		"discover_count": TestConstants.DISCOVER_COUNT,
		# match-rules' HAND_SIZE, which F6 needs (story 004) — folded into the
		# caps at stage 7b by `EffectValidator.stage7_caps`.
		"hand_size": TestConstants.HAND_SIZE,
	}


## The referenced cards plus one host record per card type; `host_keywords`
## goes on every card host (display keywords, C1 rule 2).
func _db(host_keywords: Array = []) -> FixtureDb:
	return FixtureDb.new([
		CardFactory.make_minion(HUSK, 1, 1, 1, [], {"set": "decay", "token": true}),
		CardFactory.make_weapon(AXE, 2, 3, 2, {"set": "war", "token": true}),
		CardFactory.make_weapon(BLADE, 1, 1, 2, {"set": "war", "token": true}),
		CardFactory.make_minion(SHEEP, 1, 1, 1, [], {"token": true}),
		CardFactory.make_spell(BOLT, 1),
		CardFactory.make_minion(MINION_HOST, 2, 2, 2, host_keywords),
		CardFactory.make_spell(SPELL_HOST, 2, [], {"keywords": host_keywords.duplicate()}),
		CardFactory.make_weapon(WEAPON_HOST, 2, 2, 2, {"keywords": host_keywords.duplicate()}),
	])


## Parses one effect object or an array of them into the `effects` Array.
func _fx(json_text: String) -> Array:
	var parsed: Variant = JSON.parse_string(json_text)
	assert_bool(parsed != null).override_failure_message("fixture JSON does not parse: %s" % json_text).is_true()
	if parsed is Array:
		return parsed
	return [parsed]


func _run(host_kind: StringName, host_id: String, json_text: String, host_keywords: Array = []) -> Array:
	return EffectValidator.validate_effects(host_kind, host_id, _fx(json_text), _db(host_keywords), _caps())


func _codes(report: Array) -> Array:
	return report.map(func(e: Dictionary) -> String: return str(e.code))


func _with_code(report: Array, code: String) -> Array:
	return report.filter(func(e: Dictionary) -> bool: return str(e.code) == code)


## The first entry, or `{}` when there is none (so a failed size assertion
## does not abort the suite with an out-of-bounds index).
func _first(report: Array) -> Dictionary:
	return report[0] if not report.is_empty() else {}


func _assert_has_code(report: Array, code: String) -> void:
	assert_array(_codes(report)).override_failure_message("expected %s in %s" % [code, str(report)]).contains([code])


func _assert_clean(report: Array) -> void:
	assert_array(report).override_failure_message("expected no entries, got %s" % str(report)).is_empty()


# --- AC-02: E_FX_CHOSEN -------------------------------------------------------------

func test_two_chosen_play_effects_report_e_fx_chosen_naming_host_and_second_default_id() -> void:
	# Arrange — two cast effects, neither with an explicit id.
	var json: String = '[{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":1}]},{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"heal","amount":1}]}]'

	# Act
	var report: Array = _run(&"card", SPELL_HOST, json)

	# Assert
	var chosen: Array = _with_code(report, "E_FX_CHOSEN")
	assert_int(chosen.size()).is_equal(1)
	assert_str(str(_first(chosen).get("host_id"))).is_equal(SPELL_HOST)
	assert_str(str(_first(chosen).get("effect_id"))).is_equal("%s.1" % SPELL_HOST)


func test_chosen_on_a_non_play_trigger_is_e_fx_chosen() -> void:
	var report: Array = _run(&"card", MINION_HOST,
		'{"trigger":"deathrattle","targets":{"selector":"chosen"},"ops":[{"op":"damage","amount":1}]}', ["deathrattle"])

	_assert_has_code(report, "E_FX_CHOSEN")


func test_chosen_inside_a_choose_one_option_is_e_fx_chosen() -> void:
	# The effect-level `chosen` is legal; only the option's own `chosen` is not.
	var report: Array = _run(&"card", SPELL_HOST,
		'{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"choose_one","options":[{"label_key":"opt.a","ops":[{"op":"damage","amount":2,"targets":{"selector":"chosen","filter":{"kind":"any"}}}]},{"label_key":"opt.b","ops":[{"op":"draw","count":1}]}]}]}')

	assert_array(_codes(report)).contains_exactly(["E_FX_CHOSEN"])
	assert_str(str(_first(report).get("path"))).is_equal("effects/0/ops/0/options/0/ops/0/targets")


func test_one_effect_level_chosen_shared_by_choose_one_options_is_clean() -> void:
	# C11 row 33: the options reuse the effect-level `chosen` (C8.3).
	var report: Array = _run(&"card", SPELL_HOST,
		'{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"choose_one","options":[{"label_key":"opt.smite","ops":[{"op":"damage","amount":2}]},{"label_key":"opt.mend","ops":[{"op":"heal","amount":4}]}]}]}')

	_assert_clean(report)


# --- AC-03: E_FX_TRIGGER, E_FX_SELECTOR, E_FX_FILTER, E_FX_OP, E_FX_SCHEMA -------------

func test_boss_passive_with_battlecry_is_e_fx_trigger() -> void:
	var json: String = '{"trigger":"battlecry","targets":"enemy_hero","ops":[{"op":"damage","amount":1}]}'

	var as_passive: Array = _run(&"passive", BOSS_HOST, json)
	# Card Database stage 7b names the BossDef host kind `boss` (card-database story 004).
	var as_boss: Array = _run(&"boss", BOSS_HOST, json)

	assert_array(_codes(as_passive)).contains_exactly(["E_FX_TRIGGER"])
	assert_array(_codes(as_boss)).contains_exactly(["E_FX_TRIGGER"])


func test_unknown_trigger_and_unknown_scope_key_are_e_fx_trigger() -> void:
	var unknown: Array = _run(&"card", MINION_HOST, '{"trigger":"on_sneeze","ops":[{"op":"draw","count":1}]}')
	var bad_scope: Array = _run(&"card", MINION_HOST, '{"trigger":"turn_start","scope":{"colour":"red"},"ops":[{"op":"draw","count":1}]}')

	assert_array(_codes(unknown)).contains_exactly(["E_FX_TRIGGER"])
	assert_array(_codes(bad_scope)).contains_exactly(["E_FX_TRIGGER"])


func test_card_trigger_legality_follows_the_record_type() -> void:
	# C2 Hosts: `cast` is spell-only, `battlecry` minion/weapon only.
	var cast_on_minion: Array = _run(&"card", MINION_HOST, '{"trigger":"cast","ops":[{"op":"draw","count":1}]}')
	var battlecry_on_spell: Array = _run(&"card", SPELL_HOST, '{"trigger":"battlecry","ops":[{"op":"draw","count":1}]}', ["battlecry"])
	var battlecry_on_weapon: Array = _run(&"card", WEAPON_HOST, '{"trigger":"battlecry","ops":[{"op":"draw","count":1}]}', ["battlecry"])

	assert_array(_codes(cast_on_minion)).contains_exactly(["E_FX_TRIGGER"])
	_assert_has_code(battlecry_on_spell, "E_FX_TRIGGER")
	_assert_clean(battlecry_on_weapon)


func test_treasure_effect_targeting_self_is_e_fx_selector() -> void:
	var report: Array = _run(&"treasure", TREASURE_HOST, '{"trigger":"turn_start","targets":"self","ops":[{"op":"buff","attack":1}]}')

	assert_array(_codes(report)).contains_exactly(["E_FX_SELECTOR"])


func test_unknown_selector_and_illegal_adjacent_anchors_are_e_fx_selector() -> void:
	var unknown: Array = _run(&"card", MINION_HOST, '{"trigger":"battlecry","targets":"everyone_nearby","ops":[{"op":"damage","amount":1}]}', ["battlecry"])
	# `adjacent` defaults to `of: self`; a spell is not a minion in play.
	var of_self_on_spell: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":"adjacent","ops":[{"op":"damage","amount":1}]}')
	var of_target_without_chosen: Array = _run(&"card", MINION_HOST, '{"trigger":"battlecry","targets":{"selector":"adjacent","of":"target"},"ops":[{"op":"damage","amount":1}]}', ["battlecry"])
	var of_target_with_chosen: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"damage","amount":2},{"op":"damage","amount":1,"targets":{"selector":"adjacent","of":"target"}}]}')

	assert_array(_codes(unknown)).contains_exactly(["E_FX_SELECTOR"])
	assert_array(_codes(of_self_on_spell)).contains_exactly(["E_FX_SELECTOR"])
	assert_array(_codes(of_target_without_chosen)).contains_exactly(["E_FX_SELECTOR"])
	_assert_clean(of_target_with_chosen)


func test_taxonomy_filters_accept_registered_values_and_reject_unknown_ones() -> void:
	for pair: Array in [["tribe", "human"], ["school", "alchemy"]]:
		var effect: String = '{"trigger":"cast","targets":{"selector":"all_minions","filter":{"%s":"%s"}},"ops":[{"op":"damage","amount":1}]}'
		assert_array(_run(&"card", SPELL_HOST, effect % pair)).is_empty()
		_assert_has_code(_run(&"card", SPELL_HOST, effect % [pair[0], "unknown"]), "E_FX_FILTER")


func test_discover_auto_cast_validation_respects_school_filter() -> void:
	var db := FixtureDb.new([
		CardFactory.make_spell(SPELL_HOST, 1, [], {"keywords": ["discover"]}),
		CardFactory.make_spell(BOLT, 1, _fx('{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":1}]}'), {"schools": ["arcane"]}),
		CardFactory.make_spell("neutral_test_tonic", 1, _fx('{"trigger":"cast","ops":[{"op":"draw","count":1}]}'), {"schools": ["alchemy"]}),
	])
	var effect: String = '{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":["%s","neutral_test_tonic"],"filter":{"school":"%s"},"then":"cast"}]}'
	assert_array(EffectValidator.validate_effects(&"card", SPELL_HOST, _fx(effect % [BOLT, "alchemy"]), db, _caps())).is_empty()
	_assert_has_code(EffectValidator.validate_effects(&"card", SPELL_HOST, _fx(effect % [BOLT, "arcane"]), db, _caps()), "E_FX_OP_TARGET")


func test_unknown_filter_predicate_is_e_fx_filter() -> void:
	var in_targets: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"all_minions","filter":{"is_shiny":true}},"ops":[{"op":"damage","amount":1}]}')
	var in_scope: Array = _run(&"card", MINION_HOST, '{"trigger":"on_card_played","scope":{"by":"owner","card":{"flavour":"spicy"}},"ops":[{"op":"draw","count":1}]}')
	var bad_value: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"all_minions","filter":{"kind":"dragon"}},"ops":[{"op":"damage","amount":1}]}')

	assert_array(_codes(in_targets)).contains_exactly(["E_FX_FILTER"])
	assert_array(_codes(in_scope)).contains_exactly(["E_FX_FILTER"])
	assert_array(_codes(bad_value)).contains_exactly(["E_FX_FILTER"])


func test_aura_op_outside_a_static_trigger_is_e_fx_op() -> void:
	var report: Array = _run(&"card", MINION_HOST, '{"trigger":"battlecry","targets":"all_friendly_minions","ops":[{"op":"aura","attack":1}]}', ["battlecry"])

	assert_array(_codes(report)).contains_exactly(["E_FX_OP"])


func test_an_aura_granting_stealth_is_e_fx_op() -> void:
	# DD-X16 (code review MR-014 S2): an aura re-grants Stealth on the step
	# after an attack, so the attacker would stay untargetable — only a printed
	# or one-shot Stealth is legal in MVP. Card host and treasure host alike.
	var on_minion: Array = _run(&"card", MINION_HOST, '{"trigger":"aura","targets":{"selector":"all_friendly_minions","filter":{"not_self":true}},"ops":[{"op":"aura","keywords":["stealth"]}]}', ["aura"])
	var on_treasure: Array = _run(&"treasure", TREASURE_HOST, '{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","attack":1,"keywords":["rush","stealth"]}]}')

	assert_array(_codes(on_minion)).contains_exactly(["E_FX_OP"])
	assert_str(str(_first(on_minion).get("path"))).is_equal("effects/0/ops/0/keywords/0")
	assert_array(_codes(on_treasure)).contains_exactly(["E_FX_OP"])
	assert_str(str(_first(on_treasure).get("path"))).is_equal("effects/0/ops/0/keywords/1")


func test_a_one_shot_stealth_grant_and_a_non_stealth_aura_stay_legal() -> void:
	# DD-X16 rejects the aura grant only: a buff / give_keyword Stealth is a
	# one-shot enchantment that the declaration strips for good
	var buff: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"buff","attack":1,"keywords":["stealth"]}]}')
	var give: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"give_keyword","keyword":"stealth"}]}')
	var rush_aura: Array = _run(&"treasure", TREASURE_HOST, '{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","keywords":["rush"]}]}')

	_assert_clean(buff)
	_assert_clean(give)
	_assert_clean(rush_aura)


func test_an_aura_granting_divine_shield_is_e_fx_op_on_every_host() -> void:
	# DD-X25 (code review card-effects 012 S2): an aura re-grants its keywords on
	# every recompute, so the shield would return after each hit and the minion
	# could never be damaged. Card, treasure and boss-passive hosts alike.
	var on_minion: Array = _run(&"card", MINION_HOST, '{"trigger":"aura","targets":{"selector":"all_friendly_minions","filter":{"not_self":true}},"ops":[{"op":"aura","keywords":["divine_shield"]}]}', ["aura"])
	var on_treasure: Array = _run(&"treasure", TREASURE_HOST, '{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","attack":1,"keywords":["rush","divine_shield"]}]}')
	var on_passive: Array = _run(&"passive", BOSS_HOST, '{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","keywords":["divine_shield"]}]}')

	assert_array(_codes(on_minion)).contains_exactly(["E_FX_OP"])
	assert_str(str(_first(on_minion).get("path"))).is_equal("effects/0/ops/0/keywords/0")
	assert_str(str(_first(on_minion).get("message"))).contains("DD-X25")
	assert_array(_codes(on_treasure)).contains_exactly(["E_FX_OP"])
	assert_str(str(_first(on_treasure).get("path"))).is_equal("effects/0/ops/0/keywords/1")
	assert_array(_codes(on_passive)).contains_exactly(["E_FX_OP"])


func test_a_one_shot_divine_shield_grant_and_a_taunt_aura_stay_legal() -> void:
	# DD-X25 rejects the aura grant only: a popped one-shot shield stays popped
	var buff: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"buff","attack":1,"keywords":["divine_shield"]}]}')
	var give: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"give_keyword","keyword":"divine_shield"}]}')
	var taunt_aura: Array = _run(&"treasure", TREASURE_HOST, '{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","keywords":["taunt"]}]}')

	_assert_clean(buff)
	_assert_clean(give)
	_assert_clean(taunt_aura)


# --- AC-47: silence before destroy (C5, C10 `E_FX_OP`, DD-X21) ---------------------

## The DD-X21 rows of [param report]; a report may carry other codes (`target`
## is not a C3 selector, so that case also reports `E_FX_SELECTOR`).
func _order_rows(report: Array) -> Array:
	return report.filter(func(e: Dictionary) -> bool: return str(e.code) == "E_FX_OP" and str(e.message).contains("DD-X21"))


func _assert_one_order_row(report: Array, destroy_label: String, silence_label: String) -> void:
	var rows: Array = _order_rows(report)
	assert_array(rows).override_failure_message("expected one DD-X21 row, got %s" % str(report)).has_size(1)
	var message: String = str(_first(rows).get("message"))
	assert_str(message).contains("%s destroy" % destroy_label)
	assert_str(message).contains("%s silence" % silence_label)


func _assert_no_order_row(report: Array) -> void:
	assert_array(_order_rows(report)).override_failure_message("expected no DD-X21 row, got %s" % str(report)).is_empty()


## A spell whose effect-level `targets` is `chosen`, running [param ops_json];
## it shows the display keywords its ops back (C1 rule 2).
func _on_chosen(ops_json: String) -> Array:
	var keywords: Array = ["silence", "freeze"] if ops_json.contains("freeze") else ["silence"]
	return _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":%s}' % ops_json, keywords)


func test_ac47_destroy_before_silence_on_chosen_is_one_e_fx_op_naming_both_paths() -> void:
	# Act
	var report: Array = _on_chosen('[{"op":"destroy"},{"op":"silence"}]')

	# Assert — the only row, at the `silence`, in the message C5 asks for
	assert_array(_codes(report)).contains_exactly(["E_FX_OP"])
	assert_str(str(_first(report).get("path"))).is_equal("effects/0/ops/1")
	assert_str(str(_first(report).get("message"))).contains("destroy before silence on one target (DD-X21): ops[0] destroy, ops[1] silence")
	assert_str(str(_first(report).get("message"))).contains("list silence first")


func test_ac47_silence_before_destroy_on_chosen_is_clean() -> void:
	_assert_clean(_on_chosen('[{"op":"silence"},{"op":"destroy"}]'))


func test_ac47_a_gap_between_the_two_ops_changes_nothing() -> void:
	# Act — execution order, not adjacency
	var report: Array = _on_chosen('[{"op":"destroy"},{"op":"damage","amount":1},{"op":"silence"}]')

	# Assert
	assert_array(_codes(report)).contains_exactly(["E_FX_OP"])
	_assert_one_order_row(report, "ops[0]", "ops[2]")


func test_ac47_a_search_selector_never_counts_as_the_destroyed_minion() -> void:
	# Act — C3: a search never yields a dying minion, on either op
	var silence_searches: Array = _on_chosen('[{"op":"destroy"},{"op":"silence","targets":"all_enemy_minions"}]')
	var random_silence: Array = _on_chosen('[{"op":"destroy"},{"op":"silence","targets":"random_enemy_minion"}]')
	var neighbours: Array = _on_chosen('[{"op":"destroy"},{"op":"silence","targets":{"selector":"adjacent","of":"target"}}]')
	var destroy_searches: Array = _on_chosen('[{"op":"destroy","targets":"all_enemy_minions"},{"op":"silence"}]')
	var both_search: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":"all_enemy_minions","ops":[{"op":"destroy"},{"op":"silence"}]}', ["silence"])

	# Assert
	_assert_clean(silence_searches)
	_assert_clean(random_silence)
	_assert_clean(neighbours)
	_assert_clean(destroy_searches)
	_assert_clean(both_search)


func test_ac47_chosen_counts_as_its_own_targets_as_well_as_inherited() -> void:
	# Act — `silence` reuses the effect-level `chosen`; one op inherits, the other names it
	var own_on_both: Array = _on_chosen('[{"op":"destroy","targets":"chosen"},{"op":"silence","targets":"chosen"}]')
	var own_on_silence: Array = _on_chosen('[{"op":"destroy"},{"op":"silence","targets":"chosen"}]')
	var object_form: Array = _on_chosen('[{"op":"destroy","targets":{"selector":"chosen"}},{"op":"silence"}]')

	# Assert
	_assert_one_order_row(own_on_both, "ops[0]", "ops[1]")
	_assert_one_order_row(own_on_silence, "ops[0]", "ops[1]")
	_assert_one_order_row(object_form, "ops[0]", "ops[1]")


func test_ac47_self_is_a_reference_inherited_or_its_own() -> void:
	# Act
	var inherited: Array = _run(&"card", MINION_HOST, '{"trigger":"turn_end","targets":"self","ops":[{"op":"destroy"},{"op":"silence"}]}', ["silence"])
	var own: Array = _run(&"card", MINION_HOST, '{"trigger":"turn_end","ops":[{"op":"destroy","targets":"self"},{"op":"silence","targets":"self"}]}', ["silence"])
	var right_order: Array = _run(&"card", MINION_HOST, '{"trigger":"turn_end","targets":"self","ops":[{"op":"silence"},{"op":"destroy"}]}', ["silence"])

	# Assert
	assert_array(_codes(inherited)).contains_exactly(["E_FX_OP"])
	_assert_one_order_row(inherited, "ops[0]", "ops[1]")
	assert_array(_codes(own)).contains_exactly(["E_FX_OP"])
	_assert_one_order_row(own, "ops[0]", "ops[1]")
	_assert_clean(right_order)


func test_ac47_target_is_the_same_reference_as_chosen() -> void:
	# Act — C3: `chosen` is "the same entity as `target`". `target` is not a
	# selector name, so these also report `E_FX_SELECTOR`; the order row stands.
	var both: Array = _on_chosen('[{"op":"destroy","targets":"target"},{"op":"silence","targets":"target"}]')
	var mixed: Array = _on_chosen('[{"op":"destroy"},{"op":"silence","targets":"target"}]')
	var right_order: Array = _on_chosen('[{"op":"silence","targets":"target"},{"op":"destroy"}]')

	# Assert
	_assert_one_order_row(both, "ops[0]", "ops[1]")
	_assert_one_order_row(mixed, "ops[0]", "ops[1]")
	_assert_no_order_row(right_order)


func test_ac47_trigger_subject_is_a_reference_inherited_or_its_own() -> void:
	# Act
	var inherited: Array = _run(&"card", MINION_HOST, '{"trigger":"on_attack","targets":"trigger_subject","ops":[{"op":"destroy"},{"op":"silence"}]}', ["silence"])
	var own: Array = _run(&"card", MINION_HOST, '{"trigger":"on_attack","ops":[{"op":"destroy","targets":"trigger_subject"},{"op":"silence","targets":"trigger_subject"}]}', ["silence"])

	# Assert
	assert_array(_codes(inherited)).contains_exactly(["E_FX_OP"])
	_assert_one_order_row(inherited, "ops[0]", "ops[1]")
	assert_array(_codes(own)).contains_exactly(["E_FX_OP"])
	_assert_one_order_row(own, "ops[0]", "ops[1]")


func test_ac47_trigger_source_is_a_reference_inherited_or_its_own() -> void:
	# Act
	var inherited: Array = _run(&"card", MINION_HOST, '{"trigger":"on_attack","targets":"trigger_source","ops":[{"op":"destroy"},{"op":"silence"}]}', ["silence"])
	var own: Array = _run(&"card", MINION_HOST, '{"trigger":"on_attack","ops":[{"op":"destroy","targets":"trigger_source"},{"op":"silence","targets":"trigger_source"}]}', ["silence"])

	# Assert
	assert_array(_codes(inherited)).contains_exactly(["E_FX_OP"])
	_assert_one_order_row(inherited, "ops[0]", "ops[1]")
	assert_array(_codes(own)).contains_exactly(["E_FX_OP"])
	_assert_one_order_row(own, "ops[0]", "ops[1]")


func test_ac47_two_different_references_are_two_minions() -> void:
	# Act — "the same minion" means the same reference (C5)
	var subject_then_source: Array = _run(&"card", MINION_HOST, '{"trigger":"on_attack","ops":[{"op":"destroy","targets":"trigger_subject"},{"op":"silence","targets":"trigger_source"}]}', ["silence"])
	var self_then_chosen: Array = _run(&"card", MINION_HOST, '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"destroy","targets":"self"},{"op":"silence"}]}', ["battlecry", "silence"])

	# Assert
	_assert_clean(subject_then_source)
	_assert_clean(self_then_chosen)


func test_ac47_a_repeat_holding_both_ops_counts_in_either_order() -> void:
	# Act — iteration 2's `silence` follows iteration 1's `destroy` (C10)
	var silence_first: Array = _on_chosen('[{"op":"repeat","times":2,"ops":[{"op":"silence"},{"op":"destroy"}]}]')
	var destroy_first: Array = _on_chosen('[{"op":"repeat","times":2,"ops":[{"op":"destroy"},{"op":"silence"}]}]')

	# Assert — one row each: the second walk of the body repeats no row
	assert_array(_codes(silence_first)).contains_exactly(["E_FX_OP"])
	_assert_one_order_row(silence_first, "ops[0].ops[1]", "ops[0].ops[0]")
	assert_array(_codes(destroy_first)).contains_exactly(["E_FX_OP"])
	_assert_one_order_row(destroy_first, "ops[0].ops[0]", "ops[0].ops[1]")


func test_ac47_a_repeat_holding_one_of_the_ops_orders_like_a_plain_op() -> void:
	# Act
	var silence_in_repeat_after: Array = _on_chosen('[{"op":"destroy"},{"op":"repeat","times":2,"ops":[{"op":"silence"}]}]')
	var destroy_in_repeat_after: Array = _on_chosen('[{"op":"silence"},{"op":"repeat","times":2,"ops":[{"op":"destroy"}]}]')

	# Assert
	_assert_one_order_row(silence_in_repeat_after, "ops[0]", "ops[1].ops[0]")
	_assert_clean(destroy_in_repeat_after)


func test_ac47_a_then_and_its_else_never_order_against_each_other() -> void:
	# Act
	var report: Array = _on_chosen('[{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"destroy"}],"else":[{"op":"silence"}]}]')

	# Assert
	_assert_clean(report)


func test_ac47_two_choose_one_options_never_order_against_each_other() -> void:
	# Act
	var report: Array = _on_chosen('[{"op":"choose_one","options":[{"label_key":"a","ops":[{"op":"destroy"}]},{"label_key":"b","ops":[{"op":"silence"}]}]}]')

	# Assert
	_assert_clean(report)


func test_ac47_ops_after_a_branch_see_a_destroy_from_either_arm() -> void:
	# Act — the ops after a branch see the union of its arms
	var from_then: Array = _on_chosen('[{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"destroy"}]},{"op":"silence"}]')
	var from_else: Array = _on_chosen('[{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"freeze"}],"else":[{"op":"destroy"}]},{"op":"silence"}]')
	var from_option: Array = _on_chosen('[{"op":"choose_one","options":[{"label_key":"a","ops":[{"op":"freeze"}]},{"label_key":"b","ops":[{"op":"destroy"}]}]},{"op":"silence"}]')

	# Assert
	_assert_one_order_row(from_then, "ops[0].then[0]", "ops[1]")
	_assert_one_order_row(from_else, "ops[0].else[0]", "ops[1]")
	_assert_one_order_row(from_option, "ops[0].options[1].ops[0]", "ops[1]")


func test_ac47_each_arm_sees_a_destroy_before_the_branch() -> void:
	# Act
	var in_then: Array = _on_chosen('[{"op":"destroy"},{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"silence"}]}]')
	var in_else: Array = _on_chosen('[{"op":"destroy"},{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"freeze"}],"else":[{"op":"silence"}]}]')
	var in_option: Array = _on_chosen('[{"op":"destroy"},{"op":"choose_one","options":[{"label_key":"a","ops":[{"op":"freeze"}]},{"label_key":"b","ops":[{"op":"silence"}]}]}]')

	# Assert
	_assert_one_order_row(in_then, "ops[0]", "ops[1].then[0]")
	_assert_one_order_row(in_else, "ops[0]", "ops[1].else[0]")
	_assert_one_order_row(in_option, "ops[0]", "ops[1].options[1].ops[0]")


func test_ac47_silence_first_stays_clean_around_a_branch() -> void:
	# Act
	var destroy_in_then: Array = _on_chosen('[{"op":"silence"},{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"destroy"}]}]')
	var silence_in_then: Array = _on_chosen('[{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"silence"}]},{"op":"destroy"}]')

	# Assert
	_assert_clean(destroy_in_then)
	_assert_clean(silence_in_then)


func test_ac47_one_arm_does_not_leak_its_destroy_into_the_next_arm() -> void:
	# Act — `else` must not see `then`'s destroy, nested inside a `repeat` too
	var nested: Array = _on_chosen('[{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"repeat","times":2,"ops":[{"op":"destroy"}]}],"else":[{"op":"repeat","times":2,"ops":[{"op":"silence"}]}]}]')

	# Assert
	_assert_clean(nested)


func test_ac47_the_rule_is_per_effect() -> void:
	# Act — two effects are two passes with a death check between them (C6.0)
	var report: Array = _run(&"card", MINION_HOST, '[{"trigger":"turn_end","targets":"self","ops":[{"op":"destroy"}]},{"trigger":"turn_end","targets":"self","ops":[{"op":"silence"}]}]', ["silence"])

	# Assert
	_assert_clean(report)


func test_ac47_every_silence_after_the_destroy_is_named_once() -> void:
	# Act
	var report: Array = _on_chosen('[{"op":"destroy"},{"op":"silence"},{"op":"silence"}]')

	# Assert — one row per offending `silence`, each at its own path
	var paths: Array = _order_rows(report).map(func(e: Dictionary) -> String: return str(e.path))
	assert_array(paths).contains_exactly(["effects/0/ops/1", "effects/0/ops/2"])


func test_ac47_a_malformed_tree_is_reported_by_the_schema_checks_and_not_walked() -> void:
	# Act — none of these may fault the walk: `then` not an array, an op not an
	# object, `options` not an array, an option not an object
	var bad_then: Array = _on_chosen('[{"op":"destroy"},{"op":"conditional","if":{"is_owner_turn":true},"then":"silence"},{"op":"silence"}]')
	var bad_op: Array = _on_chosen('[7,{"op":"destroy"},{"op":"silence"}]')
	var bad_options: Array = _on_chosen('[{"op":"silence"},{"op":"destroy"},{"op":"choose_one","options":3}]')
	var bad_option: Array = _on_chosen('[{"op":"destroy"},{"op":"choose_one","options":[1,{"label_key":"a","ops":[{"op":"silence"}]}]}]')

	# Assert — the well-formed part is still judged
	_assert_one_order_row(bad_then, "ops[0]", "ops[2]")
	_assert_one_order_row(bad_op, "ops[1]", "ops[2]")
	_assert_no_order_row(bad_options)
	_assert_one_order_row(bad_option, "ops[0]", "ops[1].options[1].ops[0]")


func test_non_modify_value_op_under_a_value_trigger_is_e_fx_op() -> void:
	var under_value: Array = _run(&"treasure", TREASURE_HOST, '{"trigger":"modify_damage","ops":[{"op":"draw","count":1}]}')
	var nested_under_value: Array = _run(&"treasure", TREASURE_HOST, '{"trigger":"modify_cost","ops":[{"op":"conditional","if":{"is_owner_turn":true},"then":[{"op":"modify_value","delta":1}]}]}')
	var modify_value_outside: Array = _run(&"card", MINION_HOST, '{"trigger":"battlecry","ops":[{"op":"modify_value","delta":1}]}', ["battlecry"])

	assert_array(_codes(under_value)).contains_exactly(["E_FX_OP"])
	_assert_has_code(nested_under_value, "E_FX_OP")
	assert_array(_codes(modify_value_outside)).contains_exactly(["E_FX_OP"])


func test_unknown_op_and_out_of_range_params_are_e_fx_op() -> void:
	var unknown: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"explode"}]}')
	var bad_enum: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"summon","card_id":"decay_husk","position":"middle"}]}')
	var summon_over_cap: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"summon","card_id":"decay_husk","count":%d}]}' % (TestConstants.BOARD_SIZE + 1))
	var repeat_over_cap: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"repeat","times":%d,"ops":[{"op":"draw","count":1}]}]}' % (TestConstants.MAX_REPEAT + 1))
	var one_option: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"choose_one","options":[{"label_key":"opt.a","ops":[{"op":"draw","count":1}]}]}]}')
	var forbidden_keyword: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":"all_friendly_minions","ops":[{"op":"give_keyword","keyword":"deathrattle"}]}')

	assert_array(_codes(unknown)).contains_exactly(["E_FX_OP"])
	assert_array(_codes(bad_enum)).contains_exactly(["E_FX_OP"])
	assert_array(_codes(summon_over_cap)).contains_exactly(["E_FX_OP"])
	assert_array(_codes(repeat_over_cap)).contains_exactly(["E_FX_OP"])
	assert_array(_codes(one_option)).contains_exactly(["E_FX_OP"])
	assert_array(_codes(forbidden_keyword)).contains_exactly(["E_FX_OP"])


func test_summon_count_and_repeat_times_at_their_caps_are_clean() -> void:
	var summon_at_cap: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"summon","card_id":"decay_husk","count":%d}]}' % TestConstants.BOARD_SIZE)
	var repeat_at_cap: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"repeat","times":%d,"ops":[{"op":"draw","count":1}]}]}' % TestConstants.MAX_REPEAT)

	_assert_clean(summon_at_cap)
	_assert_clean(repeat_at_cap)


func test_empty_ops_is_e_fx_schema() -> void:
	var report: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[]}')

	assert_array(_codes(report)).contains_exactly(["E_FX_SCHEMA"])


func test_ops_over_max_ops_per_effect_is_e_fx_schema_and_exactly_max_is_clean() -> void:
	var draw: String = '{"op":"draw","count":1}'
	var at_max: Array = []
	at_max.resize(TestConstants.MAX_OPS_PER_EFFECT)
	at_max.fill(draw)
	var over_max: Array = at_max.duplicate()
	over_max.append(draw)

	var report_at: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[%s]}' % ",".join(at_max))
	var report_over: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[%s]}' % ",".join(over_max))

	_assert_clean(report_at)
	assert_array(_codes(report_over)).contains_exactly(["E_FX_SCHEMA"])


func test_duplicate_effect_id_within_the_host_is_e_fx_schema() -> void:
	# The explicit id of effect 0 collides with effect 1's default `<host_id>.1`.
	var report: Array = _run(&"card", SPELL_HOST,
		'[{"id":"%s.1","trigger":"cast","ops":[{"op":"draw","count":1}]},{"trigger":"cast","ops":[{"op":"draw","count":1}]}]' % SPELL_HOST)

	var dup: Array = _with_code(report, "E_FX_SCHEMA")
	assert_int(dup.size()).is_equal(1)
	assert_str(str(_first(dup).get("effect_id"))).is_equal("%s.1" % SPELL_HOST)
	assert_str(str(_first(dup).get("path"))).is_equal("effects/1")


func test_unknown_field_missing_trigger_and_wrong_types_are_e_fx_schema() -> void:
	var extra: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targeting":"required","ops":[{"op":"draw","count":1}]}')
	var missing_trigger: Array = _run(&"card", SPELL_HOST, '{"ops":[{"op":"draw","count":1}]}')
	var not_an_object: Array = _run(&"card", SPELL_HOST, '["cast"]')
	var bad_once: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","once_per_turn":"yes","ops":[{"op":"draw","count":1}]}')
	var unknown_param: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"draw","count":1,"colour":"red"}]}')
	var missing_param: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":"enemy_hero","ops":[{"op":"damage"}]}')

	assert_array(_codes(extra)).contains_exactly(["E_FX_SCHEMA"])
	assert_array(_codes(missing_trigger)).contains_exactly(["E_FX_SCHEMA"])
	assert_array(_codes(not_an_object)).contains_exactly(["E_FX_SCHEMA"])
	assert_array(_codes(bad_once)).contains_exactly(["E_FX_SCHEMA"])
	assert_array(_codes(unknown_param)).contains_exactly(["E_FX_SCHEMA"])
	assert_array(_codes(missing_param)).contains_exactly(["E_FX_SCHEMA"])


# --- AC-04: E_FX_REF, E_FX_REF_PATH ---------------------------------------------------

func test_summon_of_an_unknown_card_id_is_e_fx_ref() -> void:
	var report: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"summon","card_id":"nope"}]}')

	assert_array(_codes(report)).contains_exactly(["E_FX_REF"])
	assert_str(str(_first(report).get("path"))).is_equal("effects/0/ops/0/card_id")


func test_summon_of_a_spell_transform_into_a_spell_and_equip_of_a_non_weapon_are_e_fx_ref() -> void:
	var summon_spell: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"summon","card_id":"%s"}]}' % BOLT)
	var transform_spell: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"transform","card_id":"%s"}]}' % BOLT)
	var equip_minion: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"equip","card_id":"%s"}]}' % HUSK)
	var add_unknown: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"add_to_hand","card_id":"nope"}]}')
	var discover_unknown: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":["%s","nope"]}]}' % BOLT, ["discover"])

	assert_array(_codes(summon_spell)).contains_exactly(["E_FX_REF"])
	assert_array(_codes(transform_spell)).contains_exactly(["E_FX_REF"])
	assert_array(_codes(equip_minion)).contains_exactly(["E_FX_REF"])
	assert_array(_codes(add_unknown)).contains_exactly(["E_FX_REF"])
	assert_array(_codes(discover_unknown)).contains_exactly(["E_FX_REF"])
	assert_str(str(_first(discover_unknown).get("path"))).is_equal("effects/0/ops/0/list/1")


func test_summon_of_a_minion_and_equip_of_a_weapon_are_clean() -> void:
	var report: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"summon","card_id":"%s","count":2},{"op":"equip","card_id":"%s"}]}' % [HUSK, AXE])

	_assert_clean(report)


func test_unknown_ref_path_is_e_fx_ref_path() -> void:
	var report: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"owner.bananas"}}]}')

	assert_array(_codes(report)).contains_exactly(["E_FX_REF_PATH"])
	assert_str(str(_first(report).get("path"))).is_equal("effects/0/ops/0/amount/ref")


func test_target_ref_under_an_effect_without_chosen_is_e_fx_ref_path() -> void:
	var on_deathrattle: Array = _run(&"card", MINION_HOST, '{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"target.attack"}}]}', ["deathrattle"])
	var in_test_condition: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","condition":{"test":["target",{"is_damaged":true}]},"ops":[{"op":"draw","count":1}]}')
	var with_chosen: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"destroy"},{"op":"mana","amount":{"ref":"target.cost"},"duration":"this_turn","targets":"owner"}]}')

	assert_array(_codes(on_deathrattle)).contains_exactly(["E_FX_REF_PATH"])
	assert_array(_codes(in_test_condition)).contains_exactly(["E_FX_REF_PATH"])
	_assert_clean(with_chosen)


func test_context_ref_unavailable_under_the_trigger_is_e_fx_ref_path() -> void:
	var amount_on_battlecry: Array = _run(&"card", MINION_HOST, '{"trigger":"battlecry","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"context.amount"}}]}', ["battlecry"])
	var amount_on_damage_taken: Array = _run(&"card", MINION_HOST, '{"trigger":"on_damage_taken","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"context.amount"}}]}')
	var nested_in_expression: Array = _run(&"card", MINION_HOST, '{"trigger":"turn_end","targets":"enemy_hero","ops":[{"op":"damage","amount":{"add":[1,{"ref":"trigger_subject.attack"}]}}]}')

	assert_array(_codes(amount_on_battlecry)).contains_exactly(["E_FX_REF_PATH"])
	_assert_clean(amount_on_damage_taken)
	assert_array(_codes(nested_in_expression)).contains_exactly(["E_FX_REF_PATH"])


# --- AC-06: E_FX_OP_UNAVAILABLE and the two warnings ---------------------------------

func test_the_five_newer_ops_raise_no_op_unavailable_against_the_v1_primitive_table() -> void:
	var report: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"shuffle_into_deck","card_id":"%s","count":2,"position":"random"},' % HUSK + '{"op":"discard","count":1,"random":true},{"op":"weapon_durability","amount":1,"targets":"owner_weapon"},{"op":"hero_power_refresh"},{"op":"remove_keyword","keyword":"taunt","targets":"all_enemy_minions"}]}')

	_assert_clean(report)


func test_a_primitive_table_lacking_add_card_to_deck_makes_shuffle_into_deck_op_unavailable() -> void:
	# Arrange
	var primitives: PackedStringArray = EffectSchema.V1_PRIMITIVES.duplicate()
	primitives.remove_at(primitives.find("add_card_to_deck"))
	var effects: Array = _fx('{"trigger":"cast","ops":[{"op":"draw","count":1},{"op":"shuffle_into_deck","card_id":"%s"}]}' % HUSK)

	# Act
	var report: Array = EffectValidator.validate_effects(&"card", SPELL_HOST, effects, _db(), _caps(), primitives)

	# Assert
	assert_array(_codes(report)).contains_exactly(["E_FX_OP_UNAVAILABLE"])
	assert_str(str(_first(report).get("message"))).contains("shuffle_into_deck").contains("add_card_to_deck")
	assert_str(str(_first(report).get("path"))).is_equal("effects/0/ops/1")


func test_display_keyword_and_effects_disagreeing_either_way_warns_keyword_mismatch() -> void:
	var dr: String = '{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":1}]}'
	var keyword_without_effect: Array = _run(&"card", MINION_HOST, '{"trigger":"turn_end","ops":[{"op":"draw","count":1}]}', ["deathrattle"])
	var effect_without_keyword: Array = _run(&"card", MINION_HOST, dr, [])
	var matching: Array = _run(&"card", MINION_HOST, dr, ["deathrattle"])
	var nested_discover_without_keyword: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"repeat","times":2,"ops":[{"op":"discover","pool":"collectible","filter":{"type":"spell"}}]}]}')

	assert_array(_codes(keyword_without_effect)).contains_exactly(["W_FX_KEYWORD_MISMATCH"])
	assert_array(_codes(effect_without_keyword)).contains_exactly(["W_FX_KEYWORD_MISMATCH"])
	_assert_clean(matching)
	assert_array(_codes(nested_discover_without_keyword)).contains_exactly(["W_FX_KEYWORD_MISMATCH"])


func test_constant_false_condition_warns_unreachable() -> void:
	var literal_false: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","condition":{"cmp":[1,">",2]},"ops":[{"op":"draw","count":1}]}')
	var composed_false: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","condition":{"all":[{"exists":"owner_weapon"},{"not":{"cmp":[3,"==",3]}}]},"ops":[{"op":"draw","count":1}]}')
	var not_constant: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","condition":{"cmp":[{"ref":"owner.hand_size"},">",2]},"ops":[{"op":"draw","count":1}]}')

	assert_array(_codes(literal_false)).contains_exactly(["W_FX_UNREACHABLE"])
	assert_array(_codes(composed_false)).contains_exactly(["W_FX_UNREACHABLE"])
	_assert_clean(not_constant)


func test_repeat_with_times_zero_warns_unreachable() -> void:
	var report: Array = _run(&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"repeat","times":0,"ops":[{"op":"draw","count":1}]}]}')

	assert_array(_codes(report)).contains_exactly(["W_FX_UNREACHABLE"])
	assert_str(str(_first(report).get("path"))).is_equal("effects/0/ops/0/times")


func test_warnings_alone_carry_no_error_code_so_the_host_does_not_fail() -> void:
	var report: Array = _run(&"card", MINION_HOST,
		'{"trigger":"turn_end","condition":{"cmp":[0,"==",1]},"ops":[{"op":"repeat","times":0,"ops":[{"op":"draw","count":1}]}]}', ["battlecry"])

	assert_int(report.size()).is_equal(3)
	for code: String in _codes(report):
		assert_str(code).starts_with("W_FX_")


# --- Closed code set, entry shape, purity ---------------------------------------------

func test_the_closed_code_set_is_exactly_the_thirteen_c10_names() -> void:
	var codes: Array = Array(EffectValidator.CODES).map(func(c: StringName) -> String: return str(c))

	assert_array(codes).contains_exactly(C10_CODES)


func test_every_emitted_code_is_in_the_closed_set() -> void:
	# Arrange — one bad effect per check family, plus warnings.
	var bad: Array = [
		[&"passive", BOSS_HOST, '{"trigger":"battlecry","ops":[{"op":"draw","count":1}]}'],
		[&"treasure", TREASURE_HOST, '{"trigger":"turn_start","targets":"self","ops":[{"op":"buff","attack":1}]}'],
		[&"card", SPELL_HOST, '{"trigger":"cast","targets":{"selector":"all_minions","filter":{"x":1}},"ops":[{"op":"explode"}]}'],
		[&"card", SPELL_HOST, '{"trigger":"cast","ops":[{"op":"summon","card_id":"nope"},{"op":"draw","count":{"ref":"owner.bananas"}}]}'],
		[&"card", SPELL_HOST, '[{"trigger":"cast","targets":"chosen","ops":[]},{"trigger":"cast","targets":"chosen","extra":1,"ops":[{"op":"draw"}]}]'],
		[&"card", MINION_HOST, '{"trigger":"turn_end","condition":{"cmp":[0,"==",1]},"ops":[{"op":"repeat","times":0,"ops":[{"op":"draw","count":1}]}]}'],
	]
	var seen: Dictionary = {}

	# Act
	for row: Array in bad:
		for e: Dictionary in _run(row[0], row[1], row[2], ["aura"]):
			seen[str(e.code)] = true

	# Assert — every family fired, and nothing outside C10.
	assert_int(seen.size()).is_greater_equal(10)
	for code: String in seen.keys():
		assert_array(C10_CODES).contains([code])


func test_each_entry_has_exactly_the_five_c10_keys() -> void:
	var report: Array = _run(&"card", SPELL_HOST, '{"id":"bolt_main","trigger":"cast","ops":[{"op":"summon","card_id":"nope"}]}')

	assert_int(report.size()).is_equal(1)
	var entry: Dictionary = _first(report)
	assert_array(entry.keys()).contains_exactly_in_any_order(ENTRY_KEYS)
	assert_bool(entry.get("code") is StringName).is_true()
	assert_str(str(entry.get("host_id"))).is_equal(SPELL_HOST)
	assert_str(str(entry.get("effect_id"))).is_equal("bolt_main")
	assert_str(str(entry.get("message"))).is_not_empty()


func test_passive_host_paths_are_rooted_at_passive() -> void:
	var report: Array = _run(&"boss", BOSS_HOST, '{"trigger":"turn_start","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"owner.bananas"}}]}')

	assert_str(str(_first(report).get("path"))).is_equal("passive/0/ops/0/amount/ref")


func test_validation_is_pure_input_untouched_and_a_new_report_each_call() -> void:
	# Arrange
	var effects: Array = _fx('{"trigger":"cast","ops":[{"op":"summon","card_id":"nope"}]}')
	var before: Array = effects.duplicate(true)
	var db: FixtureDb = _db()
	var caps: Dictionary = _caps()

	# Act
	var first: Array = EffectValidator.validate_effects(&"card", SPELL_HOST, effects, db, caps)
	first.clear()
	var second: Array = EffectValidator.validate_effects(&"card", SPELL_HOST, effects, db, caps)

	# Assert — same answer, own allocation, input unchanged.
	assert_int(second.size()).is_equal(1)
	assert_bool(effects == before).is_true()
	assert_bool(caps == _caps()).is_true()


# --- No false positives on the C11 coverage rows -----------------------------------------

func test_c11_coverage_rows_validate_with_no_entries() -> void:
	# Arrange — [host_kind, host_id, display keywords, DSL] per C11 row (verbatim DSL).
	var rows: Array = [
		[&"card", MINION_HOST, ["battlecry"], '{"trigger":"battlecry","targets":"owner_weapon","ops":[{"op":"buff","attack":1}]}'],
		[&"card", MINION_HOST, ["battlecry"], '{"trigger":"battlecry","ops":[{"op":"equip","card_id":"war_token_axe"}]}'],
		[&"card", MINION_HOST, ["charge", "battlecry"], '{"trigger":"battlecry","targets":"all_enemy_minions","ops":[{"op":"damage","amount":1}]}'],
		[&"card", MINION_HOST, ["taunt", "battlecry"], '{"trigger":"battlecry","condition":{"exists":"owner_weapon"},"targets":"self","ops":[{"op":"buff","attack":2,"health":2}]}'],
		[&"card", MINION_HOST, [], '{"trigger":"on_attack","scope":{"attacker":"owner_hero"},"targets":"owner","ops":[{"op":"armor","amount":2}]}'],
		[&"card", SPELL_HOST, [], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"damage","amount":{"ref":"owner.weapon_attack"},"spell_damage":false}]}'],
		[&"card", WEAPON_HOST, ["deathrattle"], '{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":2}]}'],
		[&"hero_power", POWER_HOST, [], '{"trigger":"hero_power","ops":[{"op":"conditional","if":{"exists":"owner_weapon"},"then":[{"op":"buff","targets":"owner_weapon","attack":1,"duration":"until_end_of_turn"}],"else":[{"op":"equip","card_id":"war_whetstone_blade"}]}]}'],
		[&"card", MINION_HOST, ["deathrattle"], '{"trigger":"deathrattle","ops":[{"op":"summon","card_id":"decay_husk","count":2,"position":"source_slot"}]}'],
		[&"card", MINION_HOST, ["battlecry"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"destroy"},{"op":"draw","count":2}]}'],
		[&"card", MINION_HOST, [], '{"trigger":"on_minion_died","scope":{"who":"friendly_minion"},"targets":"self","ops":[{"op":"buff","attack":1,"health":1}]}'],
		[&"card", MINION_HOST, ["deathrattle"], '{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"source.attack"}}]}'],
		[&"card", MINION_HOST, ["poisonous", "deathrattle"], '{"trigger":"deathrattle","ops":[{"op":"add_to_hand","from":{"pool":"collectible","filter":{"set":"decay"}},"count":1}]}'],
		[&"card", SPELL_HOST, [], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly","has_trigger":"deathrattle"}},"ops":[{"op":"retrigger","trigger":"deathrattle"}]}'],
		[&"card", SPELL_HOST, [], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"conditional","if":{"test":["target",{"has_trigger":"deathrattle"}]},"then":[{"op":"buff","attack":4,"health":4}],"else":[{"op":"buff","attack":2,"health":2}]},{"op":"give_keyword","keyword":"taunt"}]}'],
		[&"hero_power", POWER_HOST, [], '{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"damage","amount":1},{"op":"conditional","if":{"test":["target",{"is_dying":true}]},"then":[{"op":"summon","card_id":"decay_husk","position":"end"}]}]}'],
		[&"card", SPELL_HOST, [], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":3}]}'],
		[&"card", SPELL_HOST, [], '{"trigger":"cast","targets":"all_enemy_characters","ops":[{"op":"damage","amount":2}]}'],
		[&"card", SPELL_HOST, ["discover"], '{"trigger":"cast","ops":[{"op":"discover","pool":"collectible","filter":{"type":"spell"}}]}'],
		[&"card", MINION_HOST, [], '{"trigger":"on_card_played","scope":{"by":"owner","card":{"type":"spell"}},"ops":[{"op":"draw","count":1}]}'],
		[&"card", MINION_HOST, [], '{"trigger":"turn_end","scope":{"side":"owner"},"condition":{"cmp":[{"ref":"owner.hand_size"},">=",5]},"targets":{"selector":"random_enemy_character"},"ops":[{"op":"damage","amount":3,"spell_damage":false}]}'],
		[&"card", SPELL_HOST, ["freeze"], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"destroy"}],"else":[{"op":"freeze"}]}]}'],
		[&"card", MINION_HOST, ["aura"], '{"trigger":"aura","scope":{"zone":"hand"},"targets":{"selector":"hand","filter":{"type":"spell"}},"ops":[{"op":"aura","cost":-1}]}'],
		[&"hero_power", POWER_HOST, [], '{"trigger":"hero_power","ops":[{"op":"buff","targets":{"selector":"deck_top","n":1},"cost":1,"duration":"until_end_of_turn"},{"op":"draw","count":1}]}'],
		[&"card", MINION_HOST, ["aura"], '{"trigger":"aura","targets":{"selector":"all_friendly_minions","filter":{"not_self":true}},"ops":[{"op":"aura","attack":1,"health":1}]}'],
		[&"card", MINION_HOST, ["aura"], '{"trigger":"aura","targets":"adjacent","ops":[{"op":"aura","attack":2}]}'],
		[&"card", MINION_HOST, ["battlecry", "silence"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"silence"}]}'],
		[&"card", MINION_HOST, ["battlecry"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"return_to_hand"}]}'],
		[&"card", MINION_HOST, ["battlecry"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"transform","card_id":"neutral_sheep"}]}'],
		[&"card", MINION_HOST, ["battlecry"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"copy_to_hand"}]}'],
		[&"card", MINION_HOST, [], '{"trigger":"turn_start","scope":{"side":"owner"},"ops":[{"op":"repeat","times":2,"ops":[{"op":"damage","targets":"random_enemy_minion","amount":1}]}]}'],
		[&"passive", BOSS_HOST, [], '{"trigger":"turn_start","scope":{"side":"owner"},"targets":"owner_hero","ops":[{"op":"heal","amount":5}]}'],
		[&"passive", BOSS_HOST, [], '{"trigger":"modify_cost","scope":{"card":{"side":"enemy","type":"minion"}},"ops":[{"op":"modify_value","delta":1}]}'],
		[&"passive", BOSS_HOST, [], '{"trigger":"on_heal","scope":{"who":"enemy","min_amount":1},"targets":"enemy_hero","ops":[{"op":"damage","amount":1}]}'],
		[&"treasure", TREASURE_HOST, [], '{"trigger":"on_match_start","targets":"owner","ops":[{"op":"armor","amount":10}]}'],
		[&"treasure", TREASURE_HOST, [], '{"trigger":"modify_cost","scope":{"card":{"side":"friendly","kind":"hero_power"}},"ops":[{"op":"modify_value","set":0}]}'],
		[&"treasure", TREASURE_HOST, [], '{"trigger":"modify_damage","scope":{"source":{"side":"friendly","type":"spell"}},"ops":[{"op":"modify_value","delta":1}]}'],
		[&"treasure", TREASURE_HOST, [], '{"trigger":"on_draw","scope":{"side":"owner"},"targets":"trigger_subject","ops":[{"op":"buff","cost":-1}]}'],
		[&"treasure", TREASURE_HOST, [], '{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","keywords":["rush"]}]}'],
		[&"treasure", TREASURE_HOST, [], '{"trigger":"modify_max_attacks","scope":{"who":"owner_hero"},"ops":[{"op":"modify_value","set":2}]}'],
		[&"hero_power", POWER_HOST, [], '{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":1}]}'],
		[&"card", MINION_HOST, ["deathrattle"], '[{"trigger":"on_minion_died","scope":{"who":"any_minion"},"ops":[{"op":"add_counter","key":"seen","amount":1}]}, {"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"counter.seen"}}]}]'],
		[&"card", SPELL_HOST, [], '{"trigger":"cast","ops":[{"op":"set_counter","key":"n","value":{"count":{"selector":"all_friendly_minions","filter":{"tag":"husk"}}}},{"op":"destroy","targets":{"selector":"all_friendly_minions","filter":{"tag":"husk"}}},{"op":"damage","targets":"all_enemy_characters","amount":{"ref":"counter.n"}}]}'],
	]

	# Act + Assert — one row at a time so a failure names its DSL.
	for row: Array in rows:
		var report: Array = _run(row[0], row[1], row[3], row[2])
		assert_array(report).override_failure_message("row %s should validate clean, got %s" % [row[3], str(report)]).is_empty()
