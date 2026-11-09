## What every match presenter reads and never writes: the `config("match_ui")` body,
## the palette as colours, the card faces and the live read model. `MatchView` builds
## one in `_ready` (ADR-0009: every value read once there) and hands it to each
## presenter, so no presenter names `Boot` or the database.
## [codeblock]
## var ctx := MatchUiContext.new(db.config("match_ui"), db)
## panel.color = ctx.color("table_lit")
## var row: Rect2 = ctx.rect("player_row")
## [/codeblock]
class_name MatchUiContext
extends RefCounted

## A set's colours are the palette tokens `<set>` and `<set>2`; a set without them reads as
## neutral, so a new set needs palette data and no code. Boss cards use the band colour.
## The tag a Masked minion carries (The Midnight Masquerade, Unmask).
const TAG_MASKED: String = "masked"
const BOSS_SET: String = "boss"
const BOSS_SET_TOKEN: String = "boss_band_1"
const FALLBACK_TOKEN: String = "neutral"
const BAND_TOKEN: String = "boss_band_%d"

## The `config("match_ui")` body. Read only.
var config: Dictionary = {}
## The live read model, for hover and highlighting only (match-ui U2). Null until a
## controller is set.
var query: MatchQuery = null
## `func(entity_id: int) -> Vector2`, the screen centre of a drawn entity.
var locate: Callable = Callable()
## The DD-X07 `reduce_motion` setting: pulses go static and pops fade in place.
var reduce_motion: bool = false

var _db: CardDatabase = null
var _colors: Dictionary = {}
var _art: ArtLibrary = null


## A context over [param ui_config]; [param db] gives card sets. A test may pass null.
func _init(ui_config: Dictionary, db: CardDatabase = null) -> void:
	config = ui_config
	_db = db
	_art = ArtLibrary.shared()
	var palette: Dictionary = config.get("palette", {})
	for token: String in palette:
		_colors[token] = Color.html(str(palette[token]))


## The colour of palette [param token]; an unknown token reports and reads as magenta.
func color(token: String) -> Color:
	if not _colors.has(token):
		push_error("MatchUiContext: no palette token '%s'" % token)
		return Color.MAGENTA
	return _colors[token]


## `high_contrast_states`: the tokens of `palette_high_contrast` take their swap, or
## go back to the palette (hud.md §10.1). Target, freeze and actionable never swap.
func set_high_contrast(on: bool) -> void:
	var swaps: Dictionary = config.get("palette_high_contrast", {})
	var palette: Dictionary = config.get("palette", {})
	for token: String in swaps:
		_colors[token] = Color.html(str(swaps[token] if on else palette[token]))


## The F6 rectangle [param zone] of `layout`.
func rect(zone: String) -> Rect2:
	var values: Array = (config.layout as Dictionary).get(zone, [])
	if values.size() != 4:
		push_error("MatchUiContext: no layout rect '%s'" % zone)
		return Rect2()
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


## The palette token of [param card_set], with [param suffix] `""` for primary or `"2"`
## for secondary.
func set_token(card_set: String, suffix: String = "") -> String:
	if card_set == BOSS_SET:
		return BOSS_SET_TOKEN
	var token: String = card_set + suffix
	return token if _colors.has(token) else FALLBACK_TOKEN


## The art library (parchment, stamps, glyphs). Never null.
func art() -> ArtLibrary:
	if _art == null:
		_art = ArtLibrary.shared()
	return _art


## `{name_key, text_key, type, cost, attack, health, keywords, primary, secondary, card_id, set}`
## for [param card_id]: `card_text` plus its frame colours. `{}` for an unknown id.
func card_face(card_id: String) -> Dictionary:
	var face: Dictionary = query.card_text(card_id) if query != null and card_id != "" else {}
	if face.is_empty():
		return {}
	var card_set: String = ""
	if _db != null:
		var record: Variant = _db.card(card_id)
		if record is Dictionary:
			card_set = str(record.get("set", ""))
	var tags: Array = []
	if _db != null:
		var tagged: Variant = _db.card(card_id)
		if tagged is Dictionary:
			tags = (tagged.get("tags", []) as Array).duplicate()
	face["tags"] = tags
	face["masked"] = tags.has(TAG_MASKED)
	face["primary"] = color(set_token(card_set))
	face["secondary"] = color(set_token(card_set, "2"))
	face["card_id"] = card_id
	face["set"] = card_set
	return face


## `{name_key, text_key, rarity, tags}` of treasure [param treasure_id]; `{}` when unknown.
func treasure_face(treasure_id: String) -> Dictionary:
	var record: Variant = _db.treasure(treasure_id) if _db != null else null
	if not record is Dictionary:
		return {}
	var text: Variant = record.get("text")
	return {
		"name_key": MatchStrings.TREASURE_NAME_KEY % treasure_id,
		"text_key": str(text.get("key", "")) if text is Dictionary else "",
		"rarity": str(record.get("rarity", "")),
		"tags": record.get("tags", []),
	}


## The panel identity of hero [param hero_def_id]: `{primary, initial, power_id}`.
func hero_identity(hero_def_id: String) -> Dictionary:
	var record: Variant = _db.hero(hero_def_id) if _db != null and _db.has(hero_def_id) else null
	if not record is Dictionary:
		return {"primary": color(FALLBACK_TOKEN), "initial": "", "power_id": ""}
	return {
		"id": hero_def_id,
		"primary": color(set_token(str(record.get("set", "")))),
		"initial": str(record.get("name", "")).left(1),
		"power_id": str(record.get("hero_power", "")),
		"name_key": MatchStrings.HERO_NAME_KEY % hero_def_id,
	}


## The printed cost of hero power [param power_id], until an entry reports another
## (DD-X29); 0 for an unknown id.
func power_cost(power_id: String) -> int:
	var record: Variant = _db.hero_power(power_id) if _db != null else null
	return int(record.get("cost", 0)) if record is Dictionary else 0


## The panel identity of boss [param boss_def_id]: `{primary, initial, passive_key}`.
func boss_identity(boss_def_id: String) -> Dictionary:
	var record: Variant = _db.boss(boss_def_id) if _db != null and _db.has(boss_def_id) else null
	if not record is Dictionary:
		return {"primary": color(FALLBACK_TOKEN), "initial": "", "passive_key": ""}
	var passive: Variant = record.get("passive_text")
	return {
		"id": boss_def_id,
		"primary": color(BAND_TOKEN % int(record.get("band", 1))),
		"initial": str(record.get("name", "")).left(1),
		"passive_key": str(passive.get("key", "")) if passive is Dictionary else "",
		"name_key": MatchStrings.BOSS_NAME_KEY % boss_def_id,
	}


## The letter badge of [param keyword]: a glyph is the non-colour backup (art bible §7).
## An unlisted name shows itself, never a first letter another badge may share.
func glyph(keyword: String) -> String:
	return str((config.get("glyphs", {}) as Dictionary).get(keyword, keyword))


## The badges of [param names] (keywords and states) in the one table order every
## surface shares (`config.badges.order`), each `{name, texture, letter}`: the icon
## when its glyph exists, else its letter, decided per badge. [param board] keeps
## only the names `config.badges.board` shows on a token (no Battlecry, Discover or
## spell-effect keywords once a minion is in play). Duplicates appear once.
## [codeblock]
## for badge: Dictionary in ui.badges(["taunt", "frozen"], true):
##     print(badge.name, badge.letter, badge.texture != null)
## [/codeblock]
func badges(names: Array, board: bool) -> Array[Dictionary]:
	var table: Dictionary = config.get("badges", {})
	var order: Array = table.get("order", [])
	var shown: Array = table.get("board", order)
	var wanted: Dictionary = {}
	for name: Variant in names:
		if not board or shown.has(str(name)):
			wanted[str(name)] = true
	var ordered: Array[String] = []
	for name: Variant in order:
		if wanted.has(str(name)):
			ordered.append(str(name))
	for name: String in wanted:
		if not ordered.has(name):
			ordered.append(name)
	var result: Array[Dictionary] = []
	for name: String in ordered:
		result.append({"name": name, "texture": art().glyph_texture(name), "letter": glyph(name)})
	return result


## The colour token a status flashes when it is gained (`config.badges.flash`),
## `text_light` for any other badge.
func badge_flash(badge_name: String) -> Color:
	return color(str(((config.get("badges", {}) as Dictionary).get("flash", {}) as Dictionary).get(badge_name, "text_light")))


## The printed Spell Damage of [param card_id], 0 when it has none.
func spell_damage(card_id: String) -> int:
	var record: Variant = _db.card(card_id) if _db != null and card_id != "" else null
	return int(record.get("spell_damage", 0)) if record is Dictionary else 0


## A presentation knob of `config.fx`, or [param fallback] when absent.
func fx(key: String, fallback: Variant) -> Variant:
	return (config.get("fx", {}) as Dictionary).get(key, fallback)
