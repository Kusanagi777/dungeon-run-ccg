## C2 scope matching (design/gdd/card-effects.md C2 "Scope keys", C3 filter
## grammar; ADR-0007 Decision 1: the resolver decides *who responds*): does
## one occurrence of an engine trigger point count for an event effect owned
## by [code]owner[/code] whose source is [code]source_id[/code]?
##
## Static and read-only, like [EffectSelectors]: it reads the engine's trigger
## `ctx` (match-rules C15 payload shapes — `side`, `subject`, `source`,
## `amount`, `card_id`, `instance_id`, `snapshot`, `attacker`, `defender`, each
## naming entity ids) and the live state, and writes nothing. Shared with
## story 014's value hooks.
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
