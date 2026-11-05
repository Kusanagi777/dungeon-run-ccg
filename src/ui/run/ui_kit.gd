## Small constructors for Run UI widgets, so a screen reads as its layout. Everything
## here styles through `RunUiTheme` variations; no text, no state.
## [codeblock]
## var title: Label = UiKit.label(tr("menu.title"), RunUiTheme.LABEL_HERO)
## var start: Button = UiKit.button(tr("hero.start"), true)
## UiKit.chain_focus([start, back])
## [/codeblock]
class_name UiKit
extends RefCounted

## The project's minimum hit size (accessibility Motor).
const MIN_HIT_PX: float = 44.0
const BUTTON_W_PX: float = 160.0
## How far a committed or unavailable element dims.
const DIM_ALPHA: float = 0.45


## A `Label` of [param variation]; [param wrap] turns on word wrap.
static func label(text: String, variation: StringName = &"", wrap: bool = false) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.theme_type_variation = variation
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


## A `Button` at least 160x44; [param primary] uses the lit style.
static func button(text: String, primary: bool = false) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(BUTTON_W_PX, MIN_HIT_PX)
	if primary:
		node.theme_type_variation = RunUiTheme.BUTTON_PRIMARY
	return node


## A `VBoxContainer` with [param gap] pixels between rows.
static func vbox(gap: int = 8) -> VBoxContainer:
	var node: VBoxContainer = VBoxContainer.new()
	node.add_theme_constant_override(&"separation", gap)
	return node


## An `HBoxContainer` with [param gap] pixels between columns.
static func hbox(gap: int = 8) -> HBoxContainer:
	var node: HBoxContainer = HBoxContainer.new()
	node.add_theme_constant_override(&"separation", gap)
	return node


## A `PanelContainer` of a `RunUiTheme.PANEL_*` [param variation].
static func panel(variation: StringName) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	node.theme_type_variation = variation
	return node


## A vertical `ScrollContainer` that keeps the focused child in view.
static func scroll() -> ScrollContainer:
	var node: ScrollContainer = ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.follow_focus = true
	return node


## A full-rect `ColorRect`: a screen's background or a dim layer. It stops the mouse.
static func backdrop(fill: Color) -> ColorRect:
	var node: ColorRect = ColorRect.new()
	node.color = fill
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	return node


## A flexible spacer for a box container.
static func spacer() -> Control:
	var node: Control = Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A `MarginContainer` filling its parent, [param margin] pixels in on every side.
static func margin(margin_px: int) -> MarginContainer:
	var node: MarginContainer = MarginContainer.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		node.add_theme_constant_override(side, margin_px)
	return node


## Places [param node] at a fixed design rect (F4 geometry is absolute, 1280x720).
static func place(node: Control, rect: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = rect.position
	node.size = rect.size


## Wires [param order] as one `Tab` cycle, the screen's Focus Order table
## (interaction-patterns Focus Management). Every control must be in the tree.
static func chain_focus(order: Array[Control]) -> void:
	var count: int = order.size()
	for i: int in count:
		var node: Control = order[i]
		node.focus_next = node.get_path_to(order[(i + 1) % count])
		node.focus_previous = node.get_path_to(order[(i - 1 + count) % count])


## Makes a list row a focus stop, so a keyboard can scroll a [method scroll] list.
static func focus_row(node: Control) -> void:
	node.focus_mode = Control.FOCUS_ALL
	node.mouse_filter = Control.MOUSE_FILTER_PASS
