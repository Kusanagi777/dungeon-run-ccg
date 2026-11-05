## The 1.5x card preview (run-ui U2 `draft_bundle`; interaction-patterns Card Inspect):
## a 225x315 parchment panel beside the hovered or focused row, clamped to y 96-310. It
## takes no input, so the row under the pointer stays hovered.
## [codeblock]
## preview.show_card(row, Vector2(438, 159))
## preview.visible = false
## [/codeblock]
class_name CardPreview
extends PanelContainer

const SIZE_PX: Vector2 = Vector2(225, 315)
const TOP_MIN: float = 96.0
const TOP_MAX: float = 310.0
const HALF_HEIGHT: float = 157.0

var _name: Label = null
var _meta: Label = null
var _text: Label = null


## Builds the panel, hidden.
func setup() -> void:
	theme_type_variation = RunUiTheme.PANEL_PARCHMENT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var column: VBoxContainer = UiKit.vbox()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_name = UiKit.label("", RunUiTheme.LABEL_INK, true)
	_meta = UiKit.label("", RunUiTheme.LABEL_INK)
	_text = UiKit.label("", RunUiTheme.LABEL_INK, true)
	column.add_child(_name)
	column.add_child(_meta)
	column.add_child(_text)


## Shows [param row] (`RunReadModels.card_row`) at x [param left], its top at
## [param row_centre_y] minus half its height, clamped.
func show_card(row: Dictionary, left: float, row_centre_y: float) -> void:
	_name.text = str(row.name)
	_meta.text = tr("card.meta").format({"cost": row.cost, "stats": row.stats})
	_text.text = str(row.text)
	UiKit.place(self, Rect2(left, clampf(row_centre_y - HALF_HEIGHT, TOP_MIN, TOP_MAX), SIZE_PX.x, SIZE_PX.y))
	visible = true
