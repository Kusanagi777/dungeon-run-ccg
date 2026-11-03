## The Card Effects DSL vocabulary as data (design/gdd/card-effects.md C1–C5):
## the effect-object fields, the trigger table (C2), the selector and filter
## tables (C3), the reference paths and value / condition forms (C4) and the op
## table with each op's primitives (C5). Shared by `EffectValidator` (story 003)
## and the resolver (story 006 on), so the two never read different tables.
##
## Pure `const` data and no logic: a new trigger, selector, predicate, ref path
## or op is a card-effects GDD change first (C1 rule 4), then a row here.
##
## [codeblock]
## EffectSchema.TRIGGERS["battlecry"].class            # &"play"
## EffectSchema.TRIGGERS["cast"].hosts                 # ["spell"]
## EffectSchema.OPS["summon"].primitives               # ["summon_minion"]
## EffectSchema.V1_PRIMITIVES.has("add_card_to_deck")  # true
## [/codeblock]
class_name EffectSchema
extends RefCounted

# --- C1: the effect object ----------------------------------------------------

## The fields an effect object may carry (C1 table). Any other key is
## `E_FX_SCHEMA` — Card Database stores no `targeting` field (CR-3).
const EFFECT_FIELDS: PackedStringArray = ["id", "trigger", "scope", "condition", "targets", "ops", "once_per_turn"]
## The fields an effect object must carry (C1 "Req" column).
const EFFECT_REQUIRED: PackedStringArray = ["trigger", "ops"]

# --- C2: triggers ----------------------------------------------------------------

## Trigger classes (C2): play triggers resolve at once, event triggers queue,
## static triggers are recomputed by `recompute_auras()`, value triggers fold.
const CLASS_PLAY: StringName = &"play"
const CLASS_EVENT: StringName = &"event"
const CLASS_STATIC: StringName = &"static"
const CLASS_VALUE: StringName = &"value"

## Host kinds of the C2 "Hosts" column. A CardDef host is one of the first
## three, by its record `type`; a BossDef `passive` is `passive`.
const HOST_MINION: StringName = &"minion"
const HOST_SPELL: StringName = &"spell"
const HOST_WEAPON: StringName = &"weapon"
const HOST_HERO_POWER: StringName = &"hero_power"
const HOST_TREASURE: StringName = &"treasure"
const HOST_PASSIVE: StringName = &"passive"

## One row per C2 trigger: `class`, legal `hosts`, legal `scope` keys, the scope
## keys whose value is a C3 filter, and the context refs the trigger makes
## available (`trigger_subject`, `trigger_source`, `context.amount`,
## `context.value`; `target` is available exactly when the effect has a
## `chosen` selector, C4). Rows marked "same" in C2 repeat the row above.
const TRIGGERS: Dictionary = {
	"battlecry": {"class": CLASS_PLAY, "hosts": ["minion", "weapon"], "scope": [], "filter_scope": [], "context": []},
	"cast": {"class": CLASS_PLAY, "hosts": ["spell"], "scope": [], "filter_scope": [], "context": []},
	"hero_power": {"class": CLASS_PLAY, "hosts": ["hero_power"], "scope": [], "filter_scope": [], "context": []},
	"deathrattle": {"class": CLASS_EVENT, "hosts": ["minion", "weapon"], "scope": [], "filter_scope": [], "context": []},
	"turn_start": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["side"], "filter_scope": [], "context": []},
	"turn_end": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["side"], "filter_scope": [], "context": []},
	"on_play": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "treasure", "passive"], "scope": ["by", "card"], "filter_scope": ["card"], "context": ["trigger_subject"]},
	"on_summon": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "treasure", "passive"], "scope": ["of", "card"], "filter_scope": ["card"], "context": ["trigger_subject"]},
	"on_card_played": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "treasure", "passive"], "scope": ["by", "card"], "filter_scope": ["card"], "context": ["trigger_subject"]},
	"after_cast": {"class": CLASS_EVENT, "hosts": ["minion", "treasure", "passive"], "scope": ["by", "card"], "filter_scope": ["card"], "context": ["trigger_subject"]},
	"on_attack": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["attacker", "defender"], "filter_scope": ["defender"], "context": ["trigger_source", "trigger_subject"]},
	"on_damage_taken": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["who", "min_amount"], "filter_scope": [], "context": ["trigger_subject", "trigger_source", "context.amount"]},
	"on_damage_dealt": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["by", "to"], "filter_scope": ["to"], "context": ["trigger_subject", "trigger_source", "context.amount"]},
	"on_heal": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["who", "min_amount"], "filter_scope": [], "context": ["trigger_subject", "context.amount"]},
	"on_minion_died": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["who", "card"], "filter_scope": ["card"], "context": ["trigger_subject"]},
	"on_draw": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["side", "card"], "filter_scope": ["card"], "context": ["trigger_subject"]},
	"on_hero_power": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["by"], "filter_scope": [], "context": []},
	"on_weapon_equipped": {"class": CLASS_EVENT, "hosts": ["minion", "weapon", "hero_power", "treasure", "passive"], "scope": ["side"], "filter_scope": [], "context": ["trigger_subject"]},
	"on_match_start": {"class": CLASS_EVENT, "hosts": ["treasure", "passive"], "scope": [], "filter_scope": [], "context": []},
	"aura": {"class": CLASS_STATIC, "hosts": ["minion", "weapon", "treasure", "passive"], "scope": ["zone"], "filter_scope": [], "context": []},
	"passive_hand": {"class": CLASS_STATIC, "hosts": ["minion", "spell", "weapon"], "scope": [], "filter_scope": [], "context": []},
	"modify_cost": {"class": CLASS_VALUE, "hosts": ["treasure", "passive"], "scope": ["card"], "filter_scope": ["card"], "context": ["context.value"]},
	"modify_damage": {"class": CLASS_VALUE, "hosts": ["treasure", "passive"], "scope": ["source", "target"], "filter_scope": ["source", "target"], "context": ["context.value", "trigger_source", "trigger_subject"]},
	"modify_heal": {"class": CLASS_VALUE, "hosts": ["treasure", "passive"], "scope": ["source", "target"], "filter_scope": ["source", "target"], "context": ["context.value", "trigger_source", "trigger_subject"]},
	"modify_starting_hand_size": {"class": CLASS_VALUE, "hosts": ["treasure", "passive"], "scope": ["side"], "filter_scope": [], "context": ["context.value"]},
	"modify_max_attacks": {"class": CLASS_VALUE, "hosts": ["treasure", "passive"], "scope": ["who"], "filter_scope": [], "context": ["context.value"]},
}

# --- C3: selectors and filters ----------------------------------------------------

## Every C3 selector name.
const SELECTORS: PackedStringArray = [
	"self", "owner_hero", "enemy_hero", "owner_weapon", "enemy_weapon", "chosen",
	"trigger_subject", "trigger_source",
	"all_friendly_minions", "all_enemy_minions", "all_minions",
	"all_friendly_characters", "all_enemy_characters", "all_characters",
	"random_friendly_minion", "random_enemy_minion", "random_minion",
	"random_enemy_character", "random_friendly_character", "random_character",
	"adjacent", "left_neighbour", "right_neighbour",
	"hand", "enemy_hand_random", "deck_top", "deck_random", "owner", "opponent",
]
## The keys of an object-form selector (C3: `{selector, filter, n, optional}`,
## plus `of` for the neighbour selectors).
const SELECTOR_FIELDS: PackedStringArray = ["selector", "filter", "n", "optional", "of"]
## Selectors that read board neighbours and take `of` (C3).
const NEIGHBOUR_SELECTORS: PackedStringArray = ["adjacent", "left_neighbour", "right_neighbour"]
## The anchors `of` may name (C3; default `self`).
const NEIGHBOUR_ANCHORS: PackedStringArray = ["self", "target", "trigger_subject"]
## The C3 selector that names the command's `target_id` (C1 rule 1).
const CHOSEN: String = "chosen"
## The C3 selector illegal on treasure / passive hosts.
const SELF: String = "self"

## Predicate kinds for the C3 filter grammar.
const PRED_ENUM: StringName = &"enum"
const PRED_BOOL: StringName = &"bool"
const PRED_VALUE: StringName = &"value"
const PRED_KEYWORDS: StringName = &"keywords"
const PRED_TRIGGER: StringName = &"trigger"
const PRED_STRING: StringName = &"string"

## Every C3 filter predicate and the kind of value it takes. Enum predicates
## list their values in [constant FILTER_ENUMS].
const FILTER_PREDICATES: Dictionary = {
	"kind": PRED_ENUM, "side": PRED_ENUM, "type": PRED_ENUM, "set": PRED_ENUM, "rarity": PRED_ENUM,
	"has_keyword": PRED_KEYWORDS, "lacks_keyword": PRED_KEYWORDS,
	"has_trigger": PRED_TRIGGER,
	"is_damaged": PRED_BOOL, "is_frozen": PRED_BOOL, "is_silenced": PRED_BOOL,
	"is_summoning_sick": PRED_BOOL, "has_divine_shield": PRED_BOOL, "is_dying": PRED_BOOL,
	"token": PRED_BOOL, "not_self": PRED_BOOL,
	"attack_le": PRED_VALUE, "attack_ge": PRED_VALUE, "health_le": PRED_VALUE, "health_ge": PRED_VALUE,
	"cost_le": PRED_VALUE, "cost_ge": PRED_VALUE, "cost_eq": PRED_VALUE,
	"tag": PRED_STRING,
}
## Enum predicate values. `kind: hero_power` is the C2 `modify_cost` scope
## form (Treasures R-13). `type`, `set` and `rarity` are Card Database's CR-3 /
## CR-4 enums, mirrored here.
## TODO(card-database): read `set` / `type` / `rarity` from the Card Database
## enum constants once its schema story exposes them.
const FILTER_ENUMS: Dictionary = {
	"kind": ["minion", "hero", "any", "hero_power"],
	"side": ["friendly", "enemy", "any"],
	"type": ["minion", "spell", "weapon"],
	"set": ["war", "decay", "knowledge", "neutral", "boss", "fortune", "order", "shadow"],
	"rarity": ["common", "rare", "legendary"],
}

## DD-M09 keyword ids (match-rules C12, card-database CR-4).
## TODO(match-rules): read from the match-rules keyword constant once it exists.
const KEYWORDS: PackedStringArray = [
	"taunt", "charge", "rush", "divine_shield", "windfury", "stealth", "lifesteal",
	"poisonous", "freeze", "silence", "battlecry", "deathrattle", "spell_damage",
	"discover", "aura",
]
## Keywords `give_keyword` / `aura` may not grant (C5, C7): effect-shaped or
## display-only ones.
const UNGRANTABLE_KEYWORDS: PackedStringArray = ["battlecry", "deathrattle", "discover", "aura", "silence", "freeze"]

## Display keywords (C1 rule 2) and what in the effects backs each one: a
## trigger name (`trigger`) or an op anywhere in the ops tree (`op`).
## `W_FX_KEYWORD_MISMATCH` when keyword and effects disagree either way.
const DISPLAY_KEYWORDS: Dictionary = {
	"battlecry": {"trigger": "battlecry"},
	"deathrattle": {"trigger": "deathrattle"},
	"aura": {"trigger": "aura"},
	"discover": {"op": "discover"},
	"freeze": {"op": "freeze"},
	"silence": {"op": "silence"},
}

# --- C4: values, references, conditions -------------------------------------------

## The one-key operators of a C4 value expression and their arity
## (`-1` = one or more values; `count` takes a selector, `ref` a path).
const VALUE_OPERATORS: Dictionary = {
	"ref": 0, "count": 0, "add": -1, "sub": 2, "mul": 2, "min": -1, "max": -1, "clamp": 3,
}
## Entity reference roots and the fields each reads (C4).
const REF_ENTITY_ROOTS: PackedStringArray = ["source", "target", "trigger_subject", "trigger_source"]
const REF_ENTITY_FIELDS: PackedStringArray = ["attack", "health", "max_health", "damage_taken", "cost"]
## Side reference roots and the fields each reads (C4).
const REF_SIDE_ROOTS: PackedStringArray = ["owner", "opponent"]
const REF_SIDE_FIELDS: PackedStringArray = [
	"mana_current", "mana_max", "hand_size", "deck_size", "board_size", "armor", "hero_health",
	"cards_played_this_turn", "minions_died_this_turn", "spells_cast_this_turn",
	"weapon_attack", "weapon_durability", "fatigue_counter", "turns_taken",
]
## The fixed one-segment paths (C4). `context.*` is trigger-gated (C2 last column).
const REF_FIXED_PATHS: PackedStringArray = ["context.amount", "context.value", "match.turn"]
## `counter.<key>` reads a C5 counter.
const REF_COUNTER_ROOT: String = "counter"

## C4 condition forms. Each condition is a one-key object.
const CONDITION_FORMS: PackedStringArray = ["cmp", "exists", "test", "holding", "is_owner_turn", "all", "any", "not"]
## `cmp` comparison operators (C4).
const CMP_OPERATORS: PackedStringArray = ["==", "!=", "<", "<=", ">", ">="]
## The references a `test` condition may name (C4).
const TEST_REFS: PackedStringArray = ["source", "target", "trigger_subject", "trigger_source"]

# --- C5: operations ------------------------------------------------------------------

## Op parameter kinds. An Array in a `params` row is an enum of allowed values.
const P_VALUE: StringName = &"value"             # C4 value expression, any int
const P_COUNT: StringName = &"count"             # C4 value; a literal must be ≥ 1
const P_STRING: StringName = &"string"
const P_CARD_ID: StringName = &"card_id"         # resolved through `db.has(id)` (E_FX_REF)
const P_CARD_LIST: StringName = &"card_list"     # Array of card ids
const P_KEYWORD: StringName = &"keyword"         # one DD-M09 id
const P_GRANT_KEYWORD: StringName = &"grant_keyword"   # one DD-M09 id outside UNGRANTABLE_KEYWORDS
const P_GRANT_KEYWORDS: StringName = &"grant_keywords" # Array of those
const P_FILTER: StringName = &"filter"
const P_FROM: StringName = &"from"               # {pool, filter, list}
const P_CONDITION: StringName = &"condition"
const P_OPS: StringName = &"ops"                 # nested op[]
const P_OPTIONS: StringName = &"options"         # choose_one [{label_key, ops}]
const P_NON_NEG_INT: StringName = &"non_neg_int" # int literal ≥ 0

## `discover` / `add_to_hand.from` pools (C5).
const DISCOVER_POOLS: Array = ["collectible", "list", "deck", "hand"]
## `choose_one` option count range (C5: 2–4).
const CHOOSE_ONE_OPTIONS_MIN: int = 2
const CHOOSE_ONE_OPTIONS_MAX: int = 4
## The fields of one `choose_one` option and of an `add_to_hand.from` object.
const OPTION_FIELDS: PackedStringArray = ["label_key", "ops"]
const FROM_FIELDS: PackedStringArray = ["pool", "filter", "list"]

## One row per C5 op: its `params` (name → kind or enum Array), the `required`
## params, `one_of` (exactly one of these must be present), and the match-rules
## `primitives` it calls (C5 "Primitive(s)" column; `[]` for resolver-owned and
## control ops). Every op may also carry `targets` (a C3 selector).
const OPS: Dictionary = {
	"damage": {"params": {"amount": P_VALUE, "spell_damage": ["auto", true, false]}, "required": ["amount"], "primitives": ["apply_damage"]},
	"heal": {"params": {"amount": P_VALUE}, "required": ["amount"], "primitives": ["apply_heal"]},
	"buff": {"params": {"attack": P_VALUE, "health": P_VALUE, "cost": P_VALUE, "keywords": P_GRANT_KEYWORDS, "duration": ["permanent", "until_end_of_turn"]}, "required": [], "primitives": ["apply_enchantment"]},
	"set_stats": {"params": {"attack": P_VALUE, "health": P_VALUE}, "required": [], "primitives": ["set_stats"]},
	"give_keyword": {"params": {"keyword": P_GRANT_KEYWORD}, "required": ["keyword"], "primitives": ["add_keyword"]},
	"remove_keyword": {"params": {"keyword": P_KEYWORD}, "required": ["keyword"], "primitives": ["remove_keyword"]},
	"silence": {"params": {}, "required": [], "primitives": ["silence"]},
	"freeze": {"params": {}, "required": [], "primitives": ["freeze"]},
	"destroy": {"params": {}, "required": [], "primitives": ["destroy"]},
	"summon": {"params": {"card_id": P_CARD_ID, "count": P_COUNT, "position": ["source_slot", "right_of_source", "end", "chosen_slot"], "side": ["owner", "opponent"]}, "required": ["card_id"], "primitives": ["summon_minion"]},
	"transform": {"params": {"card_id": P_CARD_ID}, "required": ["card_id"], "primitives": ["transform"]},
	"draw": {"params": {"count": P_COUNT, "side": ["owner", "opponent"]}, "required": [], "primitives": ["draw"]},
	"discover": {"params": {"pool": DISCOVER_POOLS, "list": P_CARD_LIST, "filter": P_FILTER, "count": P_COUNT, "then": ["add_to_hand", "summon", "cast"]}, "required": ["pool"], "primitives": ["discover"]},
	"add_to_hand": {"params": {"card_id": P_CARD_ID, "from": P_FROM, "count": P_COUNT, "side": ["owner", "opponent"]}, "required": [], "one_of": ["card_id", "from"], "primitives": ["add_card_to_hand"]},
	"copy_to_hand": {"params": {"count": P_COUNT, "side": ["owner", "opponent"]}, "required": [], "primitives": ["add_card_to_hand"]},
	"return_to_hand": {"params": {}, "required": [], "primitives": ["return_to_hand"]},
	"shuffle_into_deck": {"params": {"card_id": P_CARD_ID, "count": P_COUNT, "position": ["random", "top", "bottom"]}, "required": [], "primitives": ["add_card_to_deck"]},
	"discard": {"params": {"count": P_COUNT, "random": [true], "side": ["owner", "opponent"]}, "required": [], "primitives": ["discard"]},
	"mana": {"params": {"amount": P_VALUE, "duration": ["this_turn", "permanent"]}, "required": ["amount"], "primitives": ["add_mana"]},
	"armor": {"params": {"amount": P_VALUE}, "required": ["amount"], "primitives": ["apply_armor"]},
	"equip": {"params": {"card_id": P_CARD_ID}, "required": ["card_id"], "primitives": ["equip_weapon"]},
	"weapon_durability": {"params": {"amount": P_VALUE}, "required": ["amount"], "primitives": ["modify_durability"]},
	"hero_power_refresh": {"params": {}, "required": [], "primitives": ["refresh_hero_power"]},
	"retrigger": {"params": {"trigger": ["deathrattle"]}, "required": ["trigger"], "primitives": []},
	"add_counter": {"params": {"key": P_STRING, "amount": P_VALUE}, "required": ["key", "amount"], "primitives": []},
	"set_counter": {"params": {"key": P_STRING, "value": P_VALUE}, "required": ["key", "value"], "primitives": []},
	"conditional": {"params": {"if": P_CONDITION, "then": P_OPS, "else": P_OPS}, "required": ["if", "then"], "primitives": []},
	"repeat": {"params": {"times": P_VALUE, "ops": P_OPS}, "required": ["times", "ops"], "primitives": []},
	"choose_one": {"params": {"options": P_OPTIONS}, "required": ["options"], "primitives": ["discover"]},
	"aura": {"params": {"attack": P_VALUE, "health": P_VALUE, "cost": P_VALUE, "keywords": P_GRANT_KEYWORDS}, "required": [], "primitives": ["apply_enchantment"]},
	"modify_value": {"params": {"delta": P_VALUE, "set": P_VALUE, "mul": P_NON_NEG_INT}, "required": [], "one_of": ["delta", "set", "mul"], "primitives": []},
}
## The extra primitive a `discover` calls on `choose`, by its `then` (C5; `cast`
## resolves the picked card's `cast` effect and calls no further primitive).
const DISCOVER_THEN_PRIMITIVES: Dictionary = {
	"add_to_hand": ["add_card_to_hand"], "summon": ["summon_minion"], "cast": [],
}
## The op legal only under static triggers, and the one legal only (and alone)
## under value triggers (C5, C10 `E_FX_OP`).
const STATIC_ONLY_OP: String = "aura"
const VALUE_ONLY_OP: String = "modify_value"
## Ops whose `card_id` must name a minion / a weapon (C10 `E_FX_REF`).
const MINION_CARD_OPS: PackedStringArray = ["summon", "transform"]
const WEAPON_CARD_OPS: PackedStringArray = ["equip"]

## The match-rules primitive API (match-rules Interactions "Engine primitive
## API"; architecture.md §Core — Match Rules), the default primitive table the
## validator checks `E_FX_OP_UNAVAILABLE` against.
const V1_PRIMITIVES: PackedStringArray = [
	"draw", "apply_damage", "apply_heal", "apply_armor", "apply_enchantment", "remove_enchantment",
	"summon_minion", "destroy", "silence", "freeze", "add_keyword", "remove_keyword",
	"return_to_hand", "transform", "add_mana", "equip_weapon", "discover", "add_card_to_hand",
	"add_card_to_deck", "set_stats", "modify_durability", "refresh_hero_power", "discard",
]
