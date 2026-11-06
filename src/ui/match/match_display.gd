## The display settings of the match view (match-ui Interactions, Meta Progression row;
## hud.md §10; ADR-0009): `gamma`, `text_scale` and `high_contrast_states`, each applied
## live from `settings_changed`.
##
## `gamma` is the one [CanvasModulate] and never a colour token. `text_scale` is discrete
## (1.0, 1.25, 1.5): the view's theme takes the default size, and every size a node
## overrides is scaled from its own base, so a second change never compounds. Cards and
## tokens are fixed slots and are left alone (hud.md §10.2). High contrast swaps only the
## tokens `palette_high_contrast` lists; a presenter repaints in [method Presenter.restyle].
## [codeblock]
## var display := MatchDisplay.new(self, ui)
## display.set_gamma(1.2)
## display.set_text_scale(1.5)
## [/codeblock]
class_name MatchDisplay
extends RefCounted

const FONT_SIZE: StringName = &"font_size"
const RICH_FONT_SIZE: StringName = &"normal_font_size"
const GAMMA_NODE: String = "Gamma"

var _root: Control = null
var _ui: MatchUiContext = null
var _gamma: CanvasModulate = null
var _theme: Theme = null
var _scale: float = 1.0
# Node instance id → the size it was built with.
var _base: Dictionary = {}


## Adds the [CanvasModulate] and the scaled theme to [param root].
func _init(root: Control, ui: MatchUiContext) -> void:
	_root = root
	_ui = ui
	_gamma = CanvasModulate.new()
	_gamma.name = GAMMA_NODE
	root.add_child(_gamma)
	_theme = Theme.new()
	root.theme = _theme


## The scale now shown; a test reads it.
func text_scale() -> float:
	return _scale


## Sets the one modulate: 1.0 is neutral, the setting runs 0.8 to 1.4.
func set_gamma(gamma: float) -> void:
	_gamma.color = Color(gamma, gamma, gamma)


## Scales every overriding node under the view to [param scale].
func set_text_scale(scale: float) -> void:
	_scale = scale
	_theme.default_font_size = roundi(float(_ui.config.text_scale.base_font_px) * scale)
	refresh()


## Scales nodes built since the last pass, such as a new tooltip.
func refresh() -> void:
	_walk(_root)


func _walk(node: Node) -> void:
	if node is CardFrame or node is MinionToken:
		return
	if node is Label or node is Button:
		_scale_size(node, FONT_SIZE)
	elif node is RichTextLabel:
		_scale_size(node, RICH_FONT_SIZE)
	for child: Node in node.get_children():
		_walk(child)


func _scale_size(control: Control, key: StringName) -> void:
	if not control.has_theme_font_size_override(key):
		return
	var id: int = control.get_instance_id()
	if not _base.has(id):
		_base[id] = control.get_theme_font_size(key)
	control.add_theme_font_size_override(key, roundi(float(_base[id]) * _scale))
