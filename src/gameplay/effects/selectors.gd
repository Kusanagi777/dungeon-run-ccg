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
## A card instance in hand or deck as an op target (C5 `buff cost`; story
## 011) — never returned by [method kind_of], which names in-play kinds only.
const KIND_CARD: String = "card"
## The zones whose card instances [method is_card_instance] accepts (C5
## `buff`: "card instances in hand **or deck**").
const CARD_TARGET_ZONES: Array[String] = ["hand", "deck"]
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
## The selectors [method entities] resolves as references or single slots
## (no pool, no draw).
const REFERENCE_SELECTORS: Array[String] = [
	"self", "chosen", "owner_hero", "enemy_hero", "owner_weapon", "enemy_weapon",
	"trigger_subject", "trigger_source", "owner", "opponent",
]
## Area and random character selectors (C3) → `[minions?, heroes?, side]`,
## `side` relative to the owner: `friendly`, `enemy` or `any`.
const CHARACTER_POOLS: Dictionary[String, Array] = {
	"all_friendly_minions": [true, false, SIDE_FRIENDLY],
	"all_enemy_minions": [true, false, SIDE_ENEMY],
	"all_minions": [true, false, SIDE_ANY],
	"all_friendly_characters": [true, true, SIDE_FRIENDLY],
	"all_enemy_characters": [true, true, SIDE_ENEMY],
	"all_characters": [true, true, SIDE_ANY],
	"random_friendly_minion": [true, false, SIDE_FRIENDLY],
	"random_enemy_minion": [true, false, SIDE_ENEMY],
	"random_minion": [true, false, SIDE_ANY],
	"random_friendly_character": [true, true, SIDE_FRIENDLY],
	"random_enemy_character": [true, true, SIDE_ENEMY],
	"random_character": [true, true, SIDE_ANY],
}
## The selectors that draw from the stream (F5). `hand` draws only with an `n`.
const RANDOM_SELECTORS: Array[String] = [
	"random_friendly_minion", "random_enemy_minion", "random_minion",
	"random_friendly_character", "random_enemy_character", "random_character",
	"enemy_hand_random", "deck_random",
]
## The board-neighbour selectors (C3) and their `of` default.
const NEIGHBOUR_SELECTORS: Array[String] = ["adjacent", "left_neighbour", "right_neighbour"]
const OF_SELF: String = "self"
const OF_TARGET: String = "target"
const OF_TRIGGER_SUBJECT: String = "trigger_subject"
## Run-context flag set by `EffectResolver.recompute_auras()` (story 012): the
## engine has just stripped every aura enchantment, so a `health ≤ 0` read now
## is the transient stripped state, not a death — the death check already ran
## before the recompute (match-rules C10). Under it a pool leaves out only
## `pending_destroy` characters ([method _left_out]).
const RUN_AURA_RECOMPUTE: String = "aura_recompute"


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
## Every other selector (story 007) is its [method pool] — area, neighbour,
## hand and deck selectors as listed; a **random** one ([constant
## RANDOM_SELECTORS]) picks `k = min(n, |pool|)` of it by F5: `k` draws of
## `engine.rng_match().randi_range(0, |pool| − 1)` with removal, in pick
## order, and no draw for an empty pool (ADR-0007 Decision 7). Those need
## `run.resolver`, the bound [EffectResolver].
## Example: `EffectSelectors.entities(state, "enemy_hero", {"owner": "player", "source_id": 7, "target_id": null})`.
static func entities(state: MatchState, selector: Variant, run: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var owner: String = str(run.owner)
	var id: Variant = null
	var name: String = selector_name(selector)
	if not REFERENCE_SELECTORS.has(name):
		if not run.get("resolver") is EffectResolver:
			return out
		var resolver: EffectResolver = run.resolver
		var candidates: Array[int] = pool(resolver, selector, run)
		if not RANDOM_SELECTORS.has(name):
			return candidates
		var k: int = pick_count(selector, candidates.size())
		var stream: Variant = resolver.bound_engine().rng_match()
		for _i: int in k:
			var j: int = stream.randi_range(0, candidates.size() - 1)
			out.append(candidates[j])
			candidates.remove_at(j)
		return out
	match name:
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


## The candidates of a pool selector [param selector] before any random
## pick (C3, story 007), in canonical order, with the selector's `filter`
## (AND, [method matches] — value-expression predicates evaluated in
## [param run]) applied and dying characters left out:
## - [constant CHARACTER_POOLS]: minions (player board L→R, boss board L→R)
##   then heroes (player, boss), on the pool's side relative to the owner;
## - `adjacent` (left then right) / `left_neighbour` / `right_neighbour` of
##   `of` — `self` (default), `target` or `trigger_subject` — empty unless
##   that is a minion in play;
## - `hand` / `enemy_hand_random` → that side's hand instance ids; `deck_top`
##   → the owner's top `n` (default 1) deck instances, index 0 first, no
##   filter; `deck_random` → the owner's deck instances.
## A reference or side selector has no pool (`[]`). Draws nothing.
## Example: `EffectSelectors.pool(resolver, {"selector": "all_enemy_minions"}, run)`.
static func pool(resolver: EffectResolver, selector: Variant, run: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var engine: RulesEngine = resolver.bound_engine()
	var state: MatchState = engine.state()
	var name: String = selector_name(selector)
	var owner: String = str(run.owner)
	var source_id: int = int(run.get("source_id", -1))
	var filter: Dictionary = {}
	if selector is Dictionary and (selector as Dictionary).get("filter") is Dictionary:
		filter = selector.filter
	if CHARACTER_POOLS.has(name):
		var shape: Array = CHARACTER_POOLS[name]
		var records: Array[Dictionary] = []
		for side: String in MatchRecords.SIDES:
			if bool(shape[0]) and _side_wanted(str(shape[2]), side, owner):
				records.append_array(state.players[side].board)
		for side: String in MatchRecords.SIDES:
			if bool(shape[1]) and _side_wanted(str(shape[2]), side, owner) and state.players[side].hero != null:
				records.append(state.players[side].hero)
		for record: Dictionary in records:
			if not _left_out(engine, record, run) and matches(resolver, record, filter, owner, source_id, run):
				out.append(int(record.entity_id))
		return out
	if NEIGHBOUR_SELECTORS.has(name):
		return _neighbours(resolver, name, selector, filter, run)
	match name:
		"hand":
			return hand_cards(resolver, owner, filter, run)
		"enemy_hand_random":
			return hand_cards(resolver, other_side(owner), filter, run)
		"deck_top":
			var deck: Array = state.players[owner].deck
			var n: int = _n(selector)
			for i: int in mini(n, deck.size()):
				out.append(int(deck[i].instance_id))
		"deck_random":
			for card: Dictionary in state.players[owner].deck:
				if matches(resolver, _card_view(card, owner), filter, owner, source_id, run):
					out.append(int(card.instance_id))
	return out


## How many picks a selector makes from a pool of [param pool_size]: `min(n,
## |pool|)` for a random one (`n` default 1, F5) or a `hand` with an `n`;
## the whole pool otherwise. Example: `EffectSelectors.pick_count("random_minion", 3) == 1`.
static func pick_count(selector: Variant, pool_size: int) -> int:
	var name: String = selector_name(selector)
	if RANDOM_SELECTORS.has(name) or (name == "hand" and selector is Dictionary and (selector as Dictionary).has("n")):
		return mini(_n(selector), pool_size)
	return pool_size


## [param side]'s hand instance ids whose card matches [param filter] (C3
## `hand`; C4 `holding`), in hand order. A card is filtered as `{entity_id:
## instance_id, def_id, controller: side}` (definition predicates read its
## `def_id`). Example: `EffectSelectors.hand_cards(resolver, "player", {"type": "spell"}, run)`.
static func hand_cards(resolver: EffectResolver, side: String, filter: Dictionary, run: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var owner: String = str(run.get("owner", side))
	for card: Dictionary in resolver.bound_engine().state().players[side].hand:
		if matches(resolver, _card_view(card, side), filter, owner, int(run.get("source_id", -1)), run):
			out.append(int(card.instance_id))
	return out


static func _card_view(card: Dictionary, side: String) -> Dictionary:
	return {"entity_id": int(card.instance_id), "def_id": str(card.def_id), "controller": side}


## `n` of a selector (C3; default 1).
static func _n(selector: Variant) -> int:
	if selector is Dictionary and typeof((selector as Dictionary).get("n")) in [TYPE_INT, TYPE_FLOAT]:
		return int(selector.n)
	return 1


static func _side_wanted(want: String, side: String, owner: String) -> bool:
	return want == SIDE_ANY or (side == owner) == (want == SIDE_FRIENDLY)


## The board neighbours (C3) of the selector's `of` entity, not dying, filtered.
static func _neighbours(resolver: EffectResolver, name: String, selector: Variant, filter: Dictionary, run: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var engine: RulesEngine = resolver.bound_engine()
	var state: MatchState = engine.state()
	var of: String = str((selector as Dictionary).get("of", OF_SELF)) if selector is Dictionary else OF_SELF
	var anchor: Variant = {OF_SELF: run.get("source_id"), OF_TARGET: run.get("target_id"), OF_TRIGGER_SUBJECT: run.get("trigger_subject")}.get(of)
	if typeof(anchor) != TYPE_INT and typeof(anchor) != TYPE_FLOAT:
		return out
	for side: String in MatchRecords.SIDES:
		var board: Array = state.players[side].board
		for index: int in board.size():
			if int(board[index].entity_id) != int(anchor):
				continue
			var picks: Array[int] = []
			if name != "right_neighbour" and index > 0:
				picks.append(index - 1)
			if name != "left_neighbour" and index + 1 < board.size():
				picks.append(index + 1)
			for pick: int in picks:
				var minion: Dictionary = board[pick]
				if not _left_out(engine, minion, run) and matches(resolver, minion, filter, str(run.owner), int(run.get("source_id", -1)), run):
					out.append(int(minion.entity_id))
			return out
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


## True when [param instance_id] is a card instance in a hand or deck
## ([constant CARD_TARGET_ZONES]) — what `hand`, `deck_top` and
## `deck_random` yield (C3; story 011). Reads only.
## Example: `if EffectSelectors.is_card_instance(state, id): …`.
static func is_card_instance(state: MatchState, instance_id: int) -> bool:
	for side: String in MatchRecords.SIDES:
		for zone: String in CARD_TARGET_ZONES:
			for card: Dictionary in state.players[side][zone]:
				if int(card.instance_id) == instance_id:
					return true
	return false


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


## Whether a pool leaves [param character] out: a dying one ([method
## is_dying]) — or, during an aura recompute ([constant RUN_AURA_RECOMPUTE] in
## [param run]), only a `pending_destroy` one: its health is read with every
## aura stripped, so a minion alive only through an aura is still a recipient.
static func _left_out(engine: RulesEngine, character: Dictionary, run: Dictionary) -> bool:
	if bool(run.get(RUN_AURA_RECOMPUTE, false)):
		return bool(character.get("pending_destroy", false))
	return is_dying(engine, character)


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
## definition, so they never match it. Value predicates take an int or a C4
## value expression, evaluated in pass context [param run] (story 007);
## without a pass context (`legal_targets` at command time) a non-literal
## never matches. Stat predicates need a character (`base_attack`).
## Example: `EffectSelectors.matches(resolver, minion, {"kind": "minion"}, "player", 7)`.
static func matches(resolver: EffectResolver, entity: Dictionary, filter: Dictionary, owner: String, source_id: int, run: Dictionary = {}) -> bool:
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
				if not entity.has("base_attack"):
					return false
				var stat: int = engine.attack(entity) if str(key).begins_with("attack") else engine.health(entity)
				if not _compare(stat, str(key), want, run):
					return false
			"cost_le", "cost_ge", "cost_eq":
				var def: Dictionary = resolver.definition(str(entity.get("def_id", "")))
				if def.is_empty() or not _compare(int(def.get("cost", 0)), str(key), want, run):
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


## `<stat>_le` / `_ge` / `_eq` against an int literal (JSON numbers are
## floats) or a value expression evaluated in [param run].
static func _compare(stat: int, predicate: String, want: Variant, run: Dictionary = {}) -> bool:
	var bound: int = 0
	if typeof(want) == TYPE_INT or typeof(want) == TYPE_FLOAT:
		bound = int(want)
	elif want is Dictionary and run.get("resolver") is EffectResolver:
		bound = EffectValues.eval(want, run)
	else:
		return false
	if predicate.ends_with("_le"):
		return stat <= bound
	if predicate.ends_with("_ge"):
		return stat >= bound
	return stat == bound
