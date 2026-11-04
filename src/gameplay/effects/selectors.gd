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
## What [method kind_of] calls a weapon in play (weapons carry no `kind` field).
const KIND_WEAPON: String = "weapon"
## The reference and side selectors one effect pass resolves (C3; story 006).
const SELECTOR_SELF: String = "self"
const SELECTOR_CHOSEN: String = "chosen"
const SELECTOR_OWNER_HERO: String = "owner_hero"
const SELECTOR_ENEMY_HERO: String = "enemy_hero"
const SELECTOR_OWNER_WEAPON: String = "owner_weapon"
const SELECTOR_ENEMY_WEAPON: String = "enemy_weapon"
const SELECTOR_OWNER: String = "owner"
const SELECTOR_OPPONENT: String = "opponent"
## The trigger-context references (C3; story 008): the entity the trigger
## context names, a reference like `self` (a dying one is still yielded).
const SELECTOR_TRIGGER_SUBJECT: String = "trigger_subject"
const SELECTOR_TRIGGER_SOURCE: String = "trigger_source"


## The selector name of [param selector] — a bare string or `{selector, …}`
## (C3) — or "" when there is none.
## Example: `EffectSelectors.selector_name({"selector": "chosen"}) == "chosen"`.
static func selector_name(selector: Variant) -> String:
	if selector is String or selector is StringName:
		return str(selector)
	if selector is Dictionary:
		return str((selector as Dictionary).get("selector", ""))
	return ""


## The entity ids [param selector] yields for one effect pass, in canonical
## order (C3). [param run] carries `owner` (side), `source_id` and
## `target_id` (the command's `chosen`, or null). Story 006 resolves the
## references and the one-entity selectors:
## - `self` → the source, `chosen` → `target_id` — explicit references, so a
##   **dying** entity is still yielded (C3, DSL spike finding 5); an entity no
##   longer in play is not;
## - `owner_hero` / `enemy_hero` → that hero; `owner_weapon` /
##   `enemy_weapon` → that weapon, or nothing;
## - `trigger_subject` / `trigger_source` → the entity the queued trigger's
##   context names (`run.trigger_subject` / `run.trigger_source`, story 008)
##   while it is in play — one that has left play yields nothing, so the op
##   is `no_target` (Edge Cases: refs read the snapshot, ops need a live
##   target).
## A reference's `filter` is not re-applied (for `chosen` it is the legality
## spec the engine already checked at command time, C1 rule 1).
## TODO(story 007): area, random, neighbour and hand/deck selectors — until
## then they yield nothing (`no_target`).
## Example: `EffectSelectors.entities(state, "enemy_hero", {"owner": "player", "source_id": 7, "target_id": null})`.
static func entities(state: MatchState, selector: Variant, run: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var owner: String = str(run.owner)
	var id: Variant = null
	match selector_name(selector):
		SELECTOR_SELF:
			id = run.source_id
		SELECTOR_CHOSEN:
			id = run.target_id
		SELECTOR_OWNER_HERO:
			id = _entity_id(state.players[owner].hero)
		SELECTOR_ENEMY_HERO:
			id = _entity_id(state.players[other_side(owner)].hero)
		SELECTOR_OWNER_WEAPON:
			id = _entity_id(state.players[owner].weapon)
		SELECTOR_ENEMY_WEAPON:
			id = _entity_id(state.players[other_side(owner)].weapon)
		SELECTOR_TRIGGER_SUBJECT, SELECTOR_TRIGGER_SOURCE:
			var named: Variant = run.get(selector_name(selector))
			id = int(named) if typeof(named) == TYPE_INT or typeof(named) == TYPE_FLOAT else null
	if id != null and kind_of(state, int(id)) != "":
		out.append(int(id))
	return out


## The side a side-scoped op acts for (C3 `owner` / `opponent`, C5 `side`
## params): [param which] `opponent` is the other side of [param owner];
## anything else (`owner`, absent) is [param owner].
## Example: `EffectSelectors.side_of("opponent", "player") == "boss"`.
static func side_of(which: Variant, owner: String) -> String:
	return other_side(owner) if str(which) == SELECTOR_OPPONENT else owner


## True for the side selectors `owner` / `opponent` (C3).
static func is_side_selector(selector: Variant) -> bool:
	var name: String = selector_name(selector)
	return name == SELECTOR_OWNER or name == SELECTOR_OPPONENT


## What [param entity_id] is in play: `minion` (on a board), `hero`,
## `weapon` (equipped), or "" when nothing in play has that id (a card
## instance in hand, deck or `resolving`, or an entity that left play).
## Example: `if EffectSelectors.kind_of(state, id) == "minion": …`.
static func kind_of(state: MatchState, entity_id: int) -> String:
	var found: Dictionary = find(state, entity_id)
	if found.is_empty():
		return ""
	if found.has("kind"):
		return str(found.kind)
	return KIND_WEAPON


## The in-play record (hero, board minion or equipped weapon) of
## [param entity_id], or `{}`. Read it, never write it (ADR-0007 gate G7).
static func find(state: MatchState, entity_id: int) -> Dictionary:
	for character: Dictionary in characters(state):
		if int(character.entity_id) == entity_id:
			return character
	for side: String in MatchRecords.SIDES:
		var weapon: Variant = state.players[side].weapon
		if weapon != null and int(weapon.entity_id) == entity_id:
			return weapon
	return {}


static func _entity_id(record: Variant) -> Variant:
	return int(record.entity_id) if record is Dictionary else null


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
