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

## Palette tokens of a card's border and art box by set; another set reads as neutral.
const SET_PRIMARY: Dictionary = {"war": "war", "decay": "decay", "knowledge": "knowledge", "boss": "boss_band_1"}
const SET_SECONDARY: Dictionary = {"war": "war2", "decay": "decay2", "knowledge": "knowledge2", "boss": "boss_band_1"}
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
	face["primary"] = color(str(SET_PRIMARY.get(card_set, FALLBACK_TOKEN)))
	face["secondary"] = color(str(SET_SECONDARY.get(card_set, FALLBACK_TOKEN)))
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
		"primary": color(str(SET_PRIMARY.get(str(record.get("set", "")), FALLBACK_TOKEN))),
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
func glyph(keyword: String) -> String:
	return str((config.get("glyphs", {}) as Dictionary).get(keyword, keyword.left(1).to_upper()))
