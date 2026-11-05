## The rules-tier read model the UI queries (ADR-0008 Decision 6 and its erratum
## 2026-11-03; match-ui U2). `MatchDriver.query()` builds one over the live engine,
## the database and the settings, and it answers at all times: no worker ever
## touches the live engine. Every answer is a value copy: changing one changes
## nothing a later call returns.
##
## **Hidden information** (match-ui U2, U3 rule 2). A boss Choice's options never
## leave here: the player sees only that the boss is choosing ("If a Choice is
## raised during the boss turn"), so [method pending_choice] answers it with
## `options` empty. [method hand] of the boss is a count, and [method entity] of a
## card in a deck or in the boss's hand is `{}`, so no `card_id` the log would hide
## can be read here. [method legal_commands] is the one exception today: during a
## boss Choice it lists one `choose` per option, which shows their number
## (review question Q-5, open for the owner).
##
## The UI calls these for hover and highlighting only. Numbers on screen come from
## the projection (`MatchViewState`, U3); [method snapshot] exists to prove the two
## agree (match-ui AC L2), not to render from.
##
## It reads through value copies only (ADR-0007 Decision 4):
## [method RulesEngine.state_snapshot] and [method RulesEngine.side_snapshot], so no
## live record is held here.
## [codeblock]
## var query: MatchQuery = driver.query()
## var choice: Variant = query.pending_choice()
## if choice != null and choice.side == MatchRecords.SIDE_PLAYER:
##     show_options(choice.options)
## for card: Dictionary in query.hand("player"):
##     tint(card.instance_id, card.playable)
## [/codeblock]
class_name MatchQuery
extends RefCounted

## [method hero_power_state] `state` values (U2: `Ready | Blocked{reason_code} | Used`).
const POWER_READY: String = "ready"
const POWER_BLOCKED: String = "blocked"
const POWER_USED: String = "used"
## [method entity] `zone` of a hero and of a weapon, which sit in none of
## [constant MatchRecords.ZONES].
const ZONE_HERO: String = "hero"
const ZONE_WEAPON: String = "weapon"
const ZONE_BOARD: String = "board"
const ZONE_HAND: String = "hand"
const ZONE_DECK: String = "deck"
## [method card_text] `name_key` (content: "`card.<id>.name`", derived, not stored).
const NAME_KEY_FORMAT: String = "card.%s.name"

var _engine: RulesEngine
var _db: CardDatabase
var _settings: Dictionary


## A query over [param engine], the live one, [param db] and the settings
## snapshot [param settings].
func _init(engine: RulesEngine, db: CardDatabase, settings: Dictionary) -> void:
	_engine = engine
	_db = db
	_settings = settings


## The current phase, one of [constant MatchState.PHASES].
func phase() -> String:
	return _engine.phase()


## The side whose turn it is, the other half of U2's `phase()` row.
## [codeblock]
## var mine: bool = query.phase() == MatchState.PHASE_MAIN and query.active_side() == "player"
## [/codeblock]
func active_side() -> String:
	return String(_engine.active_side())


## A value copy of the pending `ChoiceRequest`, or null. A boss Choice comes back
## with `options` empty: see the class description.
func pending_choice() -> Variant:
	var choice: Variant = _engine.pending_choice()
	if choice is Dictionary and str(choice.side) == MatchRecords.SIDE_BOSS:
		choice.options = []
	return choice


## U2 `entity(instance_id)`: a hero, minion, weapon or card that the player may see,
## as `{card_id, side, zone, attack, health, max_health, durability, keywords,
## flags{frozen, stealth, divine_shield, silenced, summoning_sick, pending_destroy},
## enchantments[{source_id, delta{attack, health}}]}`. `{}` for an unknown id and for
## a card in a deck or the boss's hand. `card_id` of a hero is `""`; `durability` is
## null but on a weapon; `attack` and `health` of a card are printed values, and
## `health` and `max_health` of a weapon are null.
## [codeblock]
## var token: Dictionary = query.entity(hovered_id)
## if not token.is_empty(): tooltip(token.keywords, token.enchantments)
## [/codeblock]
func entity(instance_id: int) -> Dictionary:
	var record: Dictionary = _engine.state_snapshot(instance_id)
	if record.is_empty():
		return {}
	if record.has("kind"):
		return _character_view(record)
	if record.has("durability"):
		return _weapon_view(record)
	return _card_view(record)


## U2 `hand(side)`: `[{instance_id, card_id, effective_cost, playable}]` for the
## player, left to right, and the card count for the boss (hidden information).
## `playable` is whether `legal_commands()` lists a play of that card now.
## [codeblock]
## var cards: Array = query.hand("player")
## var boss_cards: int = query.hand("boss")
## [/codeblock]
func hand(side: String) -> Variant:
	var cards: Array = _player(side).hand
	if side == MatchRecords.SIDE_BOSS:
		return cards.size()
	var playable: Dictionary = {}
	for command: Dictionary in _engine.legal_commands():
		if str(command.type) == MatchRecords.CMD_PLAY_CARD and str(command.issuer) == side:
			playable[int(command.hand_index)] = true
	var out: Array = []
	for index: int in cards.size():
		var card: Dictionary = cards[index]
		out.append({
			"instance_id": int(card.instance_id),
			"card_id": str(card.def_id),
			"effective_cost": _engine.effective_cost(card, side),
			"playable": playable.has(index),
		})
	return out


## U2 `card_text(card_id)`: `{name_key, text_key, type, cost, attack, health,
## keywords}` from the Card Database, `{}` for an unknown id. `attack` and `health`
## are null where the definition has none.
## [codeblock]
## var text: Dictionary = query.card_text("war_sharpen")
## label.text = tr(text.text_key)
## [/codeblock]
func card_text(card_id: String) -> Dictionary:
	var record: Variant = _db.card(card_id)
	if not record is Dictionary:
		return {}
	var text: Variant = record.get("text")
	return {
		"name_key": NAME_KEY_FORMAT % card_id,
		"text_key": str(text.get("key", "")) if text is Dictionary else "",
		"type": str(record.get("type", "")),
		"cost": record.get("cost"),
		"attack": record.get("attack"),
		"health": record.get("health"),
		"keywords": (record.get("keywords", []) as Array).duplicate(),
	}


## The commands the live engine would accept now; a fresh list on every call.
func legal_commands() -> Array:
	return _engine.legal_commands()


## U2 `hero_power_state(side)`: `{state, reason_code}`, `state` one of
## [constant POWER_READY], [constant POWER_BLOCKED] and [constant POWER_USED].
## `reason_code` is null unless blocked, and then the C2 code `submit` would answer,
## in `submit`'s order: the match or phase, then the turn, then the cost, then a
## target. A side with no power reads as the engine reads it, `HERO_POWER_USED`.
## [codeblock]
## var power: Dictionary = query.hero_power_state("player")
## if power.state == MatchQuery.POWER_BLOCKED: tooltip(tr("reject." + power.reason_code))
## [/codeblock]
func hero_power_state(side: String) -> Dictionary:
	var player: Dictionary = _player(side)
	if bool(player.hero_power.used_this_turn):
		return _power(POWER_USED)
	var reason: String = _power_block(side, player)
	return _power(POWER_BLOCKED, reason) if reason != "" else _power(POWER_READY)


## What the projection must equal for [param side] (match-ui AC L2, "the `MatchQuery`
## snapshot"), in the shape of `MatchViewState.side()`: `{hero{entity_id, health,
## armor}, mana{available, max}, deck_count, hand, board}`. `hand` is the player's
## instance ids, and the count for the boss; `board` is `[{entity_id, card_id, attack,
## health, max_health, keywords, frozen, silenced, attacks_used}]`, left to right.
## Not in U2's table, and not for rendering: see the class description.
## [codeblock]
## assert(query.snapshot("boss").deck_count == view.side(&"boss").deck_count)
## [/codeblock]
func snapshot(side: String) -> Dictionary:
	var player: Dictionary = _player(side)
	var hero: Dictionary = player.hero
	var ids: Array = []
	for card: Dictionary in player.hand:
		ids.append(int(card.instance_id))
	var board: Array = []
	for minion: Dictionary in player.board:
		board.append({
			"entity_id": int(minion.entity_id),
			"card_id": str(minion.def_id),
			"attack": _engine.attack(minion),
			"health": _engine.health(minion),
			"max_health": _engine.max_health(minion),
			"keywords": _keywords_of(minion),
			"frozen": bool(minion.frozen),
			"silenced": bool(minion.silenced),
			"attacks_used": int(minion.attacks_used),
		})
	return {
		"hero": {"entity_id": int(hero.entity_id), "health": _engine.health(hero), "armor": int(hero.armor)},
		"mana": {"available": int(player.mana_current), "max": int(player.mana_max)},
		"deck_count": int(player.deck_count),
		"hand": ids.size() if side == MatchRecords.SIDE_BOSS else ids,
		"board": board,
	}


## A value copy of [param side]'s `PlayerState` in play.
func _player(side: String) -> Dictionary:
	return _engine.side_snapshot(side)


func _character_view(record: Dictionary) -> Dictionary:
	var is_hero: bool = str(record.kind) == MatchRecords.KIND_HERO
	var view: Dictionary = _view(str(record.get("def_id", "")), str(record.controller), ZONE_HERO if is_hero else ZONE_BOARD)
	view.attack = _engine.attack(record)
	view.health = _engine.health(record)
	view.max_health = _engine.max_health(record)
	_fill_battle_fields(view, record)
	return view


func _weapon_view(record: Dictionary) -> Dictionary:
	var view: Dictionary = _view(str(record.def_id), _engine.owner_of(int(record.entity_id)), ZONE_WEAPON)
	var attack: int = int(record.attack)
	for enchantment: Dictionary in record.enchantments:
		attack += int(enchantment.attack_delta)
	view.attack = maxi(0, attack)
	view.durability = int(record.durability)
	_fill_battle_fields(view, record)
	return view


## A card outside play. A deck's cards and the boss's hand answer `{}`: their
## `card_id` is what the log hides.
func _card_view(record: Dictionary) -> Dictionary:
	var zone: String = str(record.zone)
	var side: String = _engine.owner_of(int(record.instance_id))
	if zone == ZONE_DECK or (zone == ZONE_HAND and side == MatchRecords.SIDE_BOSS):
		return {}
	var card_id: String = str(record.def_id)
	var view: Dictionary = _view(card_id, side, zone)
	var definition: Variant = _db.card(card_id)
	if definition is Dictionary:
		view.attack = definition.get("attack")
		view.health = definition.get("health")
		view.max_health = definition.get("health")
		view.keywords = (definition.get("keywords", []) as Array).duplicate()
	return view


static func _view(card_id: String, side: String, zone: String) -> Dictionary:
	return {
		"card_id": card_id, "side": side, "zone": zone,
		"attack": null, "health": null, "max_health": null, "durability": null,
		"keywords": [],
		"flags": {
			"frozen": false, "stealth": false, "divine_shield": false,
			"silenced": false, "summoning_sick": false, "pending_destroy": false,
		},
		"enchantments": [],
	}


## The fields a character and a weapon share, from [param record].
func _fill_battle_fields(view: Dictionary, record: Dictionary) -> void:
	var keywords: Array = _keywords_of(record)
	view.keywords = keywords
	view.flags = {
		"frozen": bool(record.get("frozen", false)),
		"stealth": keywords.has(MatchRecords.KEYWORD_STEALTH),
		"divine_shield": keywords.has(MatchRecords.KEYWORD_DIVINE_SHIELD),
		"silenced": bool(record.get("silenced", false)),
		"summoning_sick": bool(record.get("summoning_sick", false)),
		"pending_destroy": bool(record.get("pending_destroy", false)),
	}
	var enchantments: Array = []
	for enchantment: Dictionary in record.enchantments:
		enchantments.append({
			"source_id": enchantment.get("source_id", enchantment.get("source_entity_id")),
			"delta": {"attack": int(enchantment.attack_delta), "health": int(enchantment.health_delta)},
		})
	view.enchantments = enchantments


## [param record]'s printed and enchantment-granted keywords, each once and sorted.
static func _keywords_of(record: Dictionary) -> Array:
	var out: Array = []
	for keyword: Variant in record.keywords:
		if not out.has(str(keyword)):
			out.append(str(keyword))
	for enchantment: Dictionary in record.enchantments:
		for keyword: Variant in enchantment.keywords_added:
			if not out.has(str(keyword)):
				out.append(str(keyword))
	out.sort()
	return out


## What stops [param side] using its power now, in `submit`'s order, or `""`.
func _power_block(side: String, player: Dictionary) -> String:
	if str(player.hero_power.def_id) == "":
		return RulesEngine.R_HERO_POWER_USED
	var now: String = _engine.phase()
	if now == MatchState.PHASE_ENDED:
		return RulesEngine.R_MATCH_ENDED
	if now == MatchState.PHASE_CHOICE:
		return RulesEngine.R_CHOICE_PENDING
	if now != MatchState.PHASE_MAIN:
		return RulesEngine.R_WRONG_PHASE
	if active_side() != side:
		return RulesEngine.R_NOT_YOUR_TURN
	if _engine.hero_power_cost(side) > int(player.mana_current):
		return RulesEngine.R_NOT_ENOUGH_MANA
	for command: Dictionary in _engine.legal_commands():
		if str(command.type) == MatchRecords.CMD_USE_HERO_POWER:
			return ""
	return RulesEngine.R_NO_LEGAL_TARGET


static func _power(state: String, reason: Variant = null) -> Dictionary:
	return {"state": state, "reason_code": reason}
