## Runtime art for the Torchlit Ledger pass: parchment, the wood table, and the
## stamp a card, hero, or boss resolves to. Paths live in `assets/art/art_map.json`
## (not `assets/data/`, which stays the card database's only JSON). A missing file
## resolves to nothing and the caller keeps the flat placeholder.
## [codeblock]
## var stamp: Dictionary = ArtLibrary.shared().card_stamp("war_rusted_axe", "weapon", "war")
## stamp.texture  # the axe silhouette
## stamp.tint     # ink, so a white glyph reads as a stamp
## [/codeblock]
class_name ArtLibrary
extends RefCounted

## The shipped map.
const MAP_PATH: String = "res://assets/art/art_map.json"
## Ink on a white game-icon silhouette.
const INK: Color = Color("1f1a14")
## Cream on a white silhouette sitting on a dark portrait panel.
const LIGHT: Color = Color("f2e9d8")

static var _shared: ArtLibrary = null

var _surfaces: Dictionary = {}
var _stamps: Dictionary = {}
var _glyphs: Dictionary = {}
var _cards: Dictionary = {}
var _fallback_set: Dictionary = {}
var _fallback_type: Dictionary = {}
var _heroes: Dictionary = {}
var _bosses: Dictionary = {}
var _treasures: Dictionary = {}
var _powers: Dictionary = {}
var _intents: Dictionary = {}
var _cache: Dictionary = {}


## The process-wide library. Loads once; a failed map is an empty library.
static func shared() -> ArtLibrary:
	if _shared == null:
		_shared = load_map(MAP_PATH)
	return _shared


## A library over [param path]. Tests build their own instead of [method shared].
static func load_map(path: String = MAP_PATH) -> ArtLibrary:
	var library := ArtLibrary.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ArtLibrary: cannot read %s" % path)
		return library
	var parsed: Dictionary = JsonText.parse(file.get_as_text())
	if not parsed.ok or not parsed.data is Dictionary:
		push_error("ArtLibrary: %s is not a JSON object" % path)
		return library
	var body: Dictionary = parsed.data
	library._surfaces = body.get("surfaces", {})
	library._stamps = body.get("stamps", {})
	library._glyphs = body.get("glyphs", {})
	library._cards = body.get("cards", {})
	library._fallback_set = body.get("fallback_set", {})
	library._fallback_type = body.get("fallback_type", {})
	library._heroes = body.get("heroes", {})
	library._bosses = body.get("bosses", {})
	library._treasures = body.get("treasures", {})
	library._powers = body.get("powers", {})
	library._intents = body.get("intents", {})
	return library


## The stamp key [param card_id] resolves to, else the set, else the type, else `""`.
func stamp_key(card_id: String, card_type: String = "", card_set: String = "") -> String:
	var key: String = str(_cards.get(card_id, ""))
	if key == "":
		key = str(_fallback_set.get(card_set, ""))
	if key == "":
		key = str(_fallback_type.get(card_type, ""))
	return key if _stamps.has(key) else ""


## `{texture, tint, key}` for [param card_id], or `{}` when nothing resolves.
## `tint` is [constant INK] for a white silhouette and white for a coloured study.
func card_stamp(card_id: String, card_type: String = "", card_set: String = "") -> Dictionary:
	var key: String = stamp_key(card_id, card_type, card_set)
	return _colored(key, false)


## `{texture, tint, key}` for a hero or boss portrait. [param group] is `heroes` or `bosses`.
## Silhouettes are tinted [constant LIGHT] so they read on the dark panel.
func portrait(group: String, id_name: String) -> Dictionary:
	var table: Dictionary = _heroes if group == "heroes" else _bosses
	return _colored(str(table.get(id_name, "")), true)


## `{texture, tint, key}` for treasure [param treasure_id], tinted to sit on parchment.
func treasure_stamp(treasure_id: String) -> Dictionary:
	return _colored(str(_treasures.get(treasure_id, "")), false)


## `{texture, tint, key}` for hero power [param power_id], tinted to sit on a dark button.
func power_stamp(power_id: String) -> Dictionary:
	return _colored(str(_powers.get(power_id, "")), true)


## `{texture, tint, key}` for boss intent [param intent_key], tinted to sit on a dark plate.
func intent_stamp(intent_key: String) -> Dictionary:
	return _colored(str(_intents.get(intent_key, "")), true)


## `{texture, tint, key}` for the stamp [param key] itself, tinted to sit on parchment.
func named_stamp(key: String) -> Dictionary:
	return _colored(key, false)


## The glyph texture for [param name] (a keyword or `attack` / `health` / `durability` / `cost`).
func glyph_texture(glyph_name: String) -> Texture2D:
	return _texture(str(_glyphs.get(glyph_name, "")))


## One texture per [param names] entry, or an empty array if any name has no glyph,
## so the caller can keep the letter backup instead of a broken row.
func glyph_row(names: PackedStringArray) -> Array[Texture2D]:
	var row: Array[Texture2D] = []
	for glyph_name: String in names:
		var tex: Texture2D = glyph_texture(glyph_name)
		if tex == null:
			row.clear()
			return row
		row.append(tex)
	return row


## The surface texture [param surface_name] (`parchment_card`, `parchment_tile`, `table`).
func surface(surface_name: String) -> Texture2D:
	return _texture(str(_surfaces.get(surface_name, "")))


## A parchment [StyleBoxTexture] with [param margin_px] of content inset, or `null`.
func parchment_panel(margin_px: int) -> StyleBox:
	var tex: Texture2D = surface("parchment_tile")
	if tex == null:
		return null
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.set_content_margin_all(margin_px)
	return box


## The torn-edge card sheet as a [StyleBoxTexture] with [param margin_px] inset, or `null`.
func parchment_sheet(margin_px: int) -> StyleBox:
	var tex: Texture2D = surface("parchment_card")
	if tex == null:
		return null
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.set_content_margin_all(margin_px)
	return box


## Clears [param style]'s fill and paints the parchment tile behind [param panel].
## [param panel] is a plain `Panel` (a `PanelContainer` should use [method parchment_panel]).
func lay_parchment(panel: Control, style: StyleBoxFlat) -> void:
	var tex: Texture2D = surface("parchment_tile")
	if tex == null:
		return
	style.bg_color.a = 0.0
	var node := TextureRect.new()
	node.name = "Parchment"
	node.texture = tex
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.show_behind_parent = true
	panel.add_child(node)
	panel.move_child(node, 0)


## Fills [param parent] with the surface [param surface_name]. The rect ignores the mouse.
func mount_fill(parent: Control, surface_name: String) -> TextureRect:
	var tex: Texture2D = surface(surface_name)
	if tex == null:
		return null
	var node := TextureRect.new()
	node.name = "ArtSurface"
	node.texture = tex
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	parent.add_child(node)
	return node


## Every path the map names, for the load test.
func mapped_paths() -> PackedStringArray:
	var out: PackedStringArray = []
	_collect_paths(_surfaces, out)
	for key: Variant in _stamps:
		out.append(str((_stamps[key] as Dictionary).get("path", "")))
	_collect_paths(_glyphs, out)
	return out


## [param texture] drawn inside [param bounds] with its aspect kept and [param pad] inset.
static func fit_rect(texture: Texture2D, bounds: Rect2, pad: float = 2.0) -> Rect2:
	var inner: Rect2 = bounds.grow(-pad)
	var size: Vector2 = texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return inner
	var scale: float = minf(inner.size.x / size.x, inner.size.y / size.y)
	var dest: Vector2 = size * scale
	return Rect2(inner.position + (inner.size - dest) * 0.5, dest)


func _colored(key: String, on_dark: bool) -> Dictionary:
	var spec: Variant = _stamps.get(key, {})
	if not spec is Dictionary or (spec as Dictionary).is_empty():
		return {}
	var tex: Texture2D = _texture(str((spec as Dictionary).get("path", "")))
	if tex == null:
		return {}
	var tint: Color = Color.WHITE
	if str((spec as Dictionary).get("tint", "")) == "ink":
		tint = LIGHT if on_dark else INK
	return {"texture": tex, "tint": tint, "key": key}


func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	else:
		push_error("ArtLibrary: missing %s" % path)
	_cache[path] = tex
	return tex


func _collect_paths(table: Dictionary, out: PackedStringArray) -> void:
	for key: Variant in table:
		var value: Variant = table[key]
		if value is String and str(value) != "":
			out.append(str(value))
