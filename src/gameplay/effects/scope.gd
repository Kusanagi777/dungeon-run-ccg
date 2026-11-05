## C2 scope matching (design/gdd/card-effects.md C2 "Scope keys", C3 filter
## grammar; ADR-0007 Decision 1: the resolver decides *who responds*): does
## one occurrence of an engine trigger point count for an event effect owned
## by [code]owner[/code] whose source is [code]source_id[/code]?
##
## Static and read-only, like [EffectSelectors]: it reads the engine's trigger
## `ctx` (match-rules C15 payload shapes — `side`, `subject`, `source`,
## `amount`, `card_id`, `instance_id`, `snapshot`, `attacker`, `defender`, each
## naming entity ids) and the live state, and writes nothing.
##
## Per trigger, the scope keys and their defaults (C2 table; an absent key is
## its default):
## - `turn_start` / `turn_end` / `on_draw` / `on_weapon_equipped`: `side:
##   owner | opponent | any` (default `owner`) against `ctx.side`;
## - `on_play` / `on_card_played` / `after_cast` / `on_hero_power`: `by: owner
##   | opponent | any` (default `owner`) against `ctx.side`, the player who
##   played;
## - `on_summon`: `of: friendly_minion | enemy_minion | any_minion` (default
##   friendly); `on_minion_died`: `who`, the same values (default friendly);
## - `on_damage_taken`: `who: self | owner_hero | friendly | enemy | any`
##   (default `self`) on the damaged `ctx.subject`; `on_heal`: the same keys
##   (default `friendly`); both take `min_amount` against `ctx.amount`;
## - `on_damage_dealt`: `by: self | owner_hero | owner_weapon | friendly |
##   any` (default `self`) on the damager `ctx.source`; `to: filter` on the
##   damaged character;
## - `on_attack`: `attacker` (the `who` values, default `self`) on
##   `ctx.attacker`; `defender: filter` on `ctx.defender`;
## - `card: filter` (on the triggers whose C2 row lists it) on the trigger
##   subject — the entity in play, the dead minion's snapshot for
##   `on_minion_died`, else the card instance as `{entity_id, def_id,
##   controller}` (a spell in `resolving`, a drawn card).
##
## Value triggers (C2 value class; story 014) have their own entry point,
## [method matches_value], because a fold's `ctx` is not a trigger `ctx`:
## - `modify_cost`: `card: filter` on `ctx.card`, a card instance or, with
##   `ctx.kind == hero_power`, the hero power. `card` without `kind` matches
##   card instances only, `kind: hero_power` the hero power only, `kind: any`
##   both (Treasures R-13);
## - `modify_damage` / `modify_heal`: `source: filter` on `ctx.source`,
##   `target: filter` on `ctx.target`. A `null` source (fatigue, DD-X14) and a
##   source that has left play match no `source` filter;
## - `modify_max_attacks`: `who` on `ctx.who` — the character values above and
##   `friendly_minion` / `enemy_minion` / `any_minion`; an absent `who` is `any`;
## - `modify_starting_hand_size`: `side` (default `owner`) on the fold's side.
## [codeblock]
## if EffectScope.matches(resolver, "on_card_played", effect.get("scope"), ctx, source_id, "player"): …
## [/codeblock]
class_name EffectScope
extends RefCounted

## Scope values (C2).
const OWNER: String = "owner"
const OPPONENT: String = "opponent"
const ANY: String = "any"
const SELF: String = "self"
const OWNER_HERO: String = "owner_hero"
const OWNER_WEAPON: String = "owner_weapon"
const FRIENDLY: String = "friendly"
const ENEMY: String = "enemy"
const FRIENDLY_MINION: String = "friendly_minion"
const ENEMY_MINION: String = "enemy_minion"
const ANY_MINION: String = "any_minion"
## The card zones a non-board subject or source can sit in (match-rules C1).
const CARD_ZONES: Array[String] = ["resolving", "hand", "graveyard", "deck"]
## What a fold reads for an absent scope or a subject that is nowhere: shared and
## never written, so a fold allocates nothing for it.
const _NONE: Dictionary = {}


## True when the occurrence [param ctx] of [param trigger]'s engine point is
## in [param scope] for an effect owned by [param owner] whose source is
## [param source_id] (see the class description for the keys and defaults).
## A trigger with no scope keys (`deathrattle`) always matches.
## Example: `EffectScope.matches(resolver, "turn_start", {"side": "opponent"}, ctx, 12, "boss")`.
static func matches(resolver: EffectResolver, trigger: String, scope: Variant, ctx: Dictionary, source_id: int, owner: String) -> bool:
	var s: Dictionary = scope if scope is Dictionary else {}
	var state: MatchState = resolver.bound_engine().state()
	var side: String = str(ctx.get("side", ""))
	match trigger:
		"turn_start", "turn_end", "on_draw", "on_weapon_equipped":
			if not _side_in(str(s.get("side", OWNER)), side, owner):
				return false
		"on_play", "on_card_played", "after_cast", "on_hero_power":
			if not _side_in(str(s.get("by", OWNER)), side, owner):
				return false
		"on_summon":
			if not _minion_side_in(str(s.get("of", FRIENDLY_MINION)), side, owner):
				return false
		"on_minion_died":
			if not _minion_side_in(str(s.get("who", FRIENDLY_MINION)), side, owner):
				return false
		"on_damage_taken", "on_heal":
			var who: String = str(s.get("who", SELF if trigger == "on_damage_taken" else FRIENDLY))
			if not _character_in(state, who, ctx.get("subject"), source_id, owner):
				return false
			if s.has("min_amount") and int(ctx.get("amount", 0)) < int(s.min_amount):
				return false
		"on_damage_dealt":
			if not _character_in(state, str(s.get("by", SELF)), ctx.get("source"), source_id, owner):
				return false
			if s.get("to") is Dictionary and not _filter_holds(resolver, state, s.to, ctx.get("subject"), ctx, owner, source_id):
				return false
		"on_attack":
			if not _character_in(state, str(s.get("attacker", SELF)), ctx.get("attacker"), source_id, owner):
				return false
			if s.get("defender") is Dictionary and not _filter_holds(resolver, state, s.defender, ctx.get("defender"), ctx, owner, source_id):
				return false
	if s.get("card") is Dictionary and (EffectSchema.TRIGGERS.get(trigger, {}).get("filter_scope", []) as Array).has("card"):
		var subject: Variant = ctx.get("instance_id", ctx.get("subject")) if trigger == "on_card_played" else ctx.get("subject")
		if not _filter_holds(resolver, state, s.card, subject, ctx, owner, source_id):
			return false
	return true


## True when the fold occurrence [param ctx] of value trigger [param trigger] is
## in [param scope] for an entry owned by [param owner], "friendly" and "enemy"
## relative to [param owner] (see the class description; ADR-0005 rule 3).
## [param side] is the fold's side. [param view] is a Dictionary the caller owns,
## refilled here for a subject that has no record in play, and [param run] the
## pass context for value-expression predicates, so nothing is allocated.
## Any trigger that is not a value trigger is false.
## Example: `EffectScope.matches_value(resolver, "modify_max_attacks", {"who": "owner_hero"}, "player", {"who": 3}, "player", view, run)`.
static func matches_value(resolver: EffectResolver, trigger: String, scope: Variant, side: String, ctx: Dictionary, owner: String, view: Dictionary, run: Dictionary) -> bool:
	var s: Dictionary = scope if scope is Dictionary else _NONE
	var state: MatchState = resolver.bound_engine().state()
	match trigger:
		"modify_cost":
			return _card_in(resolver, s.get("card"), side, ctx, owner, view, run)
		"modify_damage", "modify_heal":
			return _subject_in(resolver, state, s.get("source"), ctx.get("source"), owner, view, run) \
					and _subject_in(resolver, state, s.get("target"), ctx.get("target"), owner, view, run)
		"modify_max_attacks":
			return _who_in(state, str(s.get("who", ANY)), ctx.get("who"), owner)
		"modify_starting_hand_size":
			return _side_in(str(s.get("side", OWNER)), side, owner)
	return false


## `modify_cost`'s `card` filter (C2; Treasures R-13). The hero power has no
## `controller`: it is [param side]'s, the side the fold runs for.
static func _card_in(resolver: EffectResolver, filter: Variant, side: String, ctx: Dictionary, owner: String, view: Dictionary, run: Dictionary) -> bool:
	var wanted: Dictionary = filter if filter is Dictionary else _NONE
	var hero_power: bool = str(ctx.get("kind", "")) == RulesEngine.COST_KIND_HERO_POWER
	if hero_power and not wanted.has("kind"):
		return false
	var card: Dictionary = ctx.card
	view.entity_id = int(card.get("instance_id", -1))
	view.def_id = str(card.def_id)
	view.controller = side
	view.kind = RulesEngine.COST_KIND_HERO_POWER if hero_power else ""
	return EffectSelectors.matches(resolver, view, wanted, owner, -1, run)


## A `source` / `target` filter of a damage or heal fold on [param subject]. No
## filter matches anything, a null fatigue source included; a filter needs a
## subject ([method _fold_subject]).
static func _subject_in(resolver: EffectResolver, state: MatchState, filter: Variant, subject: Variant, owner: String, view: Dictionary, run: Dictionary) -> bool:
	if not filter is Dictionary:
		return true
	var record: Dictionary = _fold_subject(state, subject, view)
	return not record.is_empty() and EffectSelectors.matches(resolver, record, filter, owner, -1, run)


## What a filter reads for [param id] in a fold: a hero's or minion's own record,
## else [param view] refilled as `{entity_id, def_id, controller, kind}` for an
## equipped weapon or a card instance in a zone (a spell in `resolving`), else
## nothing. Walks the state directly because [method EffectSelectors.find] builds
## an array, and a fold allocates nothing.
static func _fold_subject(state: MatchState, id: Variant, view: Dictionary) -> Dictionary:
	if typeof(id) != TYPE_INT and typeof(id) != TYPE_FLOAT:
		return _NONE
	var entity_id: int = int(id)
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = state.players[side]
		if player.hero != null and int(player.hero.entity_id) == entity_id:
			return player.hero
		for minion: Dictionary in player.board:
			if int(minion.entity_id) == entity_id:
				return minion
		if player.weapon != null and int(player.weapon.entity_id) == entity_id:
			return _fill_view(view, entity_id, str(player.weapon.def_id), side, EffectSelectors.KIND_WEAPON)
		for zone: String in CARD_ZONES:
			for card: Dictionary in player[zone]:
				if int(card.instance_id) == entity_id:
					return _fill_view(view, entity_id, str(card.def_id), side, "")
	return _NONE


static func _fill_view(view: Dictionary, entity_id: int, def_id: String, controller: String, kind: String) -> Dictionary:
	view.entity_id = entity_id
	view.def_id = def_id
	view.controller = controller
	view.kind = kind
	return view


## `modify_max_attacks`' `who` against the character [param id] (C2). A value
## entry has no `self`: a treasure is not an entity (Edge Cases).
static func _who_in(state: MatchState, want: String, id: Variant, owner: String) -> bool:
	match want:
		FRIENDLY_MINION:
			return _on_board(state, owner, id)
		ENEMY_MINION:
			return _on_board(state, EffectSelectors.other_side(owner), id)
		ANY_MINION:
			return _on_board(state, owner, id) or _on_board(state, EffectSelectors.other_side(owner), id)
	return _character_in(state, want, id, -1, owner)


static func _on_board(state: MatchState, side: String, id: Variant) -> bool:
	for minion: Dictionary in state.players[side].board:
		if int(minion.entity_id) == int(id):
			return true
	return false


## The side controlling [param id] — a character or weapon in play, else a
## card instance in a zone (`resolving`, `hand`, `graveyard`, `deck`) — or ""
## (a `null` fatigue source, an id that is nowhere).
## Example: `EffectScope.controller_of(state, spell_instance_id) == "player"`.
static func controller_of(state: MatchState, id: Variant) -> String:
	if typeof(id) != TYPE_INT and typeof(id) != TYPE_FLOAT:
		return ""
	var entity_id: int = int(id)
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = state.players[side]
		if player.weapon != null and int(player.weapon.entity_id) == entity_id:
			return side
	var found: Dictionary = EffectSelectors.find(state, entity_id)
	if not found.is_empty():
		return str(found.get("controller", ""))
	for side: String in MatchRecords.SIDES:
		for zone: String in CARD_ZONES:
			for card: Dictionary in state.players[side][zone]:
				if int(card.instance_id) == entity_id:
					return side
	return ""


## The record a filter is applied to for [param subject]: the dead minion's
## snapshot when `ctx.snapshot` names it, the entity in play, else the card
## instance as `{entity_id, def_id: ctx.card_id, controller: ctx.side}`.
static func subject_view(state: MatchState, subject: Variant, ctx: Dictionary) -> Dictionary:
	if typeof(subject) != TYPE_INT and typeof(subject) != TYPE_FLOAT:
		return {}
	var snapshot: Variant = ctx.get("snapshot")
	if snapshot is Dictionary and int((snapshot as Dictionary).get("entity_id", -1)) == int(subject):
		return snapshot
	var found: Dictionary = EffectSelectors.find(state, int(subject))
	if not found.is_empty():
		return found
	return {"entity_id": int(subject), "def_id": str(ctx.get("card_id", "")), "controller": str(ctx.get("side", ""))}


## `side` / `by` values against the acting [param side].
static func _side_in(want: String, side: String, owner: String) -> bool:
	match want:
		OWNER:
			return side == owner
		OPPONENT:
			return side != "" and side != owner
		ANY:
			return true
	return false


## `of` / `who` minion values against the subject's [param side].
static func _minion_side_in(want: String, side: String, owner: String) -> bool:
	match want:
		FRIENDLY_MINION:
			return side == owner
		ENEMY_MINION:
			return side != "" and side != owner
		ANY_MINION:
			return true
	return false


## `who` / `by` / `attacker` character values against entity [param id].
static func _character_in(state: MatchState, want: String, id: Variant, source_id: int, owner: String) -> bool:
	if want == ANY:
		return true
	if typeof(id) != TYPE_INT and typeof(id) != TYPE_FLOAT:
		return false
	var entity_id: int = int(id)
	var player: Dictionary = state.players[owner]
	match want:
		SELF:
			return entity_id == source_id
		OWNER_HERO:
			return player.hero != null and int(player.hero.entity_id) == entity_id
		OWNER_WEAPON:
			return player.weapon != null and int(player.weapon.entity_id) == entity_id
		FRIENDLY:
			return controller_of(state, entity_id) == owner
		ENEMY:
			var side: String = controller_of(state, entity_id)
			return side != "" and side != owner
	return false


static func _filter_holds(resolver: EffectResolver, state: MatchState, filter: Dictionary, subject: Variant, ctx: Dictionary, owner: String, source_id: int) -> bool:
	var view: Dictionary = subject_view(state, subject, ctx)
	return not view.is_empty() and EffectSelectors.matches(resolver, view, filter, owner, source_id)
