## The display face: Alegreya (OFL, `assets/fonts/`) for titles, names, buttons and
## numerals, with lining figures so a stat reads as one height. Rules text and log lines
## keep the engine's plain sans. A missing file resolves to null and the caller keeps
## the default font.
## [codeblock]
## UiFonts.apply(label)                       # medium
## UiFonts.apply(stamp, UiFonts.WEIGHT_BOLD)  # a numeral on an ink stamp
## theme.set_font(&"font", &"Button", UiFonts.serif())
## [/codeblock]
class_name UiFonts
extends RefCounted

const SERIF_PATH: String = "res://assets/fonts/Alegreya-VariableFont_wght.ttf"
const WEIGHT_MEDIUM: int = 500
const WEIGHT_BOLD: int = 700

static var _cache: Dictionary = {}


## The display face at [param weight], or null when the file is missing.
static func serif(weight: int = WEIGHT_MEDIUM) -> Font:
	if _cache.has(weight):
		return _cache[weight] as Font
	var font: FontVariation = null
	if ResourceLoader.exists(SERIF_PATH):
		var server: TextServer = TextServerManager.get_primary_interface()
		font = FontVariation.new()
		font.base_font = load(SERIF_PATH) as Font
		font.variation_opentype = {server.name_to_tag("wght"): weight}
		font.opentype_features = {server.name_to_tag("lnum"): 1}
	_cache[weight] = font
	return font


## Sets the display face on [param control] at [param weight].
static func apply(control: Control, weight: int = WEIGHT_MEDIUM) -> void:
	var font: Font = serif(weight)
	if font != null:
		control.add_theme_font_override(&"font", font)
