## C3 selection over the live board (design/gdd/card-effects.md C3, F5;
## match-rules C12 Stealth): canonical-order enumeration and the filter
## grammar, read-only. Used by `EffectResolver.legal_targets` (story 004) and
## the one effect pass (story 006); random and area selectors grow here in
## story 007.
##
## Static and stateless: every function reads the state it is handed (the
## bound engine's `state()`, its derived `attack` / `health`, and definitions
## through the resolver's memo) and writes nothing — no field write, no event,
## no draw (ADR-0007 gate G7).
##
## **Canonical order** (C3): player board left to right, boss board left to
## right, player hero, boss hero, then weapons (player, boss). "Friendly" and
## "enemy" are relative to the effect **owner**. Selectors never yield a
## **dying** entity (`health ≤ 0` or `pending_destroy`, C6.0); only explicit
## references (`self`, `target`/`chosen`, `trigger_subject`) may.
## [codeblock]
## for character: Dictionary in EffectSelectors.characters(engine.state()):
##     if EffectSelectors.matches(resolver, character, {"kind": "minion", "side": "enemy"}, "player", source_id): …
## [/codeblock]
class_name EffectSelectors
extends RefCounted

## The keyword that keeps an enemy minion out of `chosen` (match-rules C12).
const KEYWORD_STEALTH: String = "stealth"
## The keyword `has_divine_shield` tests (DD-M09).
const KEYWORD_DIVINE_SHIELD: String = "divine_shield"
## Filter `kind` / `side` values (C3 filter grammar).
const KIND_ANY: String = "any"
const SIDE_FRIENDLY: String = "friendly"
const SIDE_ENEMY: String = "enemy"
const SIDE_ANY: String = "any"


## Every character in play in canonical order: player board left to right,
## boss board left to right, player hero, boss hero. Dying characters are
## included (the caller decides; see [method is_dying]).
## Example: `EffectSelectors.characters(engine.state())`.
static func characters(state: MatchState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for side: String in MatchRecords.SIDES:
		out.append_array(state.players[side].board)
	for side: String in MatchRecords.SIDES:
		var hero: Variant = state.players[side].hero
		if hero != null:
			out.append(hero)
	return out


## The other side. Example: `EffectSelectors.other_side("player") == "boss"`.
static func other_side(side: String) -> String:
	return MatchRecords.SIDE_BOSS if side == MatchRecords.SIDE_PLAYER else MatchRecords.SIDE_PLAYER


## True for a character that the death check after this pass will remove:
## `health ≤ 0` or `pending_destroy` (C6.0; a popped Divine Shield leaves
## `health` unchanged). Example: `EffectSelectors.is_dying(engine, minion)`.
static func is_dying(engine: RulesEngine, character: Dictionary) -> bool:
	return engine.health(character) <= 0 or bool(character.get("pending_destroy", false))


## True when [param record] holds [param keyword] in its own `keywords` or
## through an enchantment's `keywords_added` (match-rules C1).
static func has_keyword(record: Dictionary, keyword: String) -> bool:
	if (record.get("keywords", []) as Array).has(keyword):
		return true
	for enchantment: Variant in record.get("enchantments", []):
		if ((enchantment as Dictionary).get("keywords_added", []) as Array).has(keyword):
			return true
	return false


## The `chosen` candidates of a targeting spec's [param filter] for an effect
## owned by [param owner] whose source is [param source_id]: every character
## in canonical order that is not dying, is not an **enemy** Stealth minion
## (match-rules C12 — the only runtime rule beyond the filter) and matches the
## filter. Example: `EffectSelectors.chosen_candidates(resolver, spec.filter, "player", card_id)`.
static func chosen_candidates(resolver: EffectResolver, filter: Dictionary, owner: String, source_id: int) -> Array[int]:
	var engine: RulesEngine = resolver.bound_engine()
	var out: Array[int] = []
	for character: Dictionary in characters(engine.state()):
		if is_dying(engine, character):
			continue
		if str(character.controller) != owner and has_keyword(character, KEYWORD_STEALTH):
			continue
		if matches(resolver, character, filter, owner, source_id):
			out.append(int(character.entity_id))
	return out


## Whether the character [param entity] satisfies every predicate of
## [param filter] (C3: AND over the predicates), "friendly" / "enemy" relative
## to [param owner], `not_self` against [param source_id]. Definition fields
## (`cost`, `set`, `type`, `tag`, `rarity`, `token`, `has_trigger`) are read
## from the entity's `def_id` through the resolver's memo; a hero has no
## definition, so they never match it. Value predicates take int literals.
## TODO(story 007): value-expression predicates (`attack_le: {ref: …}`) — until
## then a non-literal value never matches (no target rather than a wrong one).
## Example: `EffectSelectors.matches(resolver, minion, {"kind": "minion"}, "player", 7)`.
static func matches(resolver: EffectResolver, entity: Dictionary, filter: Dictionary, owner: String, source_id: int) -> bool:
	var engine: RulesEngine = resolver.bound_engine()
	for key: Variant in filter:
		var want: Variant = filter[key]
		match str(key):
			"kind":
				if str(want) != KIND_ANY and str(entity.get("kind", "")) != str(want):
					return false
			"side":
				var friendly: bool = str(entity.get("controller", "")) == owner
				if (str(want) == SIDE_FRIENDLY and not friendly) or (str(want) == SIDE_ENEMY and friendly):
					return false
			"has_keyword", "lacks_keyword":
				var wanted: Array = want if want is Array else [want]
				for kw: Variant in wanted:
					if has_keyword(entity, str(kw)) != (str(key) == "has_keyword"):
						return false
			"has_trigger":
				if not _has_live_trigger(resolver, entity, str(want)):
					return false
			"is_damaged":
				if (int(entity.get("damage_taken", 0)) > 0) != bool(want):
					return false
			"is_frozen":
				if bool(entity.get("frozen", false)) != bool(want):
					return false
			"is_silenced":
				if bool(entity.get("silenced", false)) != bool(want):
					return false
			"is_summoning_sick":
				if bool(entity.get("summoning_sick", false)) != bool(want):
					return false
			"has_divine_shield":
				if has_keyword(entity, KEYWORD_DIVINE_SHIELD) != bool(want):
					return false
			"is_dying":
				if is_dying(engine, entity) != bool(want):
					return false
			"not_self":
				if bool(want) and int(entity.get("entity_id", -1)) == source_id:
					return false
			"attack_le", "attack_ge", "health_le", "health_ge":
				var stat: int = engine.attack(entity) if str(key).begins_with("attack") else engine.health(entity)
				if not _compare(stat, str(key), want):
					return false
			"cost_le", "cost_ge", "cost_eq":
				var def: Dictionary = resolver.definition(str(entity.get("def_id", "")))
				if def.is_empty() or not _compare(int(def.get("cost", 0)), str(key), want):
					return false
			"type", "set", "rarity":
				var def: Dictionary = resolver.definition(str(entity.get("def_id", "")))
				if def.is_empty() or str(def.get(str(key), "")) != str(want):
					return false
			"tag":
				var def: Dictionary = resolver.definition(str(entity.get("def_id", "")))
				if not (def.get("tags", []) as Array).has(want):
					return false
			"token":
				var def: Dictionary = resolver.definition(str(entity.get("def_id", "")))
				if bool(def.get("token", false)) != bool(want):
					return false
			_:
				# The validator rejects any other predicate at load (E_FX_FILTER).
				return false
	return true


## `has_trigger` (C3): a live (unsilenced) definition effect with
## [param trigger]. Enchantment-granted effects arrive with story 012.
static func _has_live_trigger(resolver: EffectResolver, entity: Dictionary, trigger: String) -> bool:
	if bool(entity.get("silenced", false)) or not entity.has("def_id"):
		return false
	for effect: Variant in resolver.effects_of(str(entity.def_id)):
		if effect is Dictionary and str((effect as Dictionary).get("trigger", "")) == trigger:
			return true
	return false


## `<stat>_le` / `_ge` / `_eq` against an int literal (JSON numbers are floats).
static func _compare(stat: int, predicate: String, want: Variant) -> bool:
	if typeof(want) != TYPE_INT and typeof(want) != TYPE_FLOAT:
		return false
	var bound: int = int(want)
	if predicate.ends_with("_le"):
		return stat <= bound
	if predicate.ends_with("_ge"):
		return stat >= bound
	return stat == bound
