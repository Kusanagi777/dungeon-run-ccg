## The `--ai-debug` overlay (match-ui U11, UI Requirements; hud.md §5): every
## `ai_decision` of the view-state's `debug_buffer`, newest last, over the feed's drawer
## rect. A developer tool: debug builds only, loaded by path by `MatchDebugLoader`, left
## out of the release export, and so its text is the payload, not localised copy.
## [codeblock]
## var overlay: AiDebugOverlay = load(AiDebugOverlay.SCENE_PATH).instantiate()
## view.add_child(overlay)
## overlay.attach(view.view_state(), view.ui_context())
## [/codeblock]
class_name AiDebugOverlay
extends Control

const SCENE_PATH: String = "res://src/ui/match/ai_debug_overlay.tscn"
const FONT_PX: int = 13
const MARGIN_PX: float = 8.0
## Characters of a decision's payload that one entry shows.
const PAYLOAD_CHARS: int = 160

var _view: MatchViewState = null
var _text: RichTextLabel = null
var _shown: int = 0


## Places the overlay and reads [param view_state]'s buffer from now on.
func attach(view_state: MatchViewState, context: MatchUiContext) -> void:
	_view = view_state
	var rect: Rect2 = context.rect("feed_drawer")
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = context.color("ink")
	fill.size = rect.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	_text = RichTextLabel.new()
	_text.position = Vector2.ONE * MARGIN_PX
	_text.size = rect.size - Vector2.ONE * MARGIN_PX * 2.0
	_text.scroll_following = true
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", FONT_PX)
	_text.add_theme_color_override("default_color", context.color("text_muted"))
	add_child(_text)


func _process(_delta: float) -> void:
	if _view == null or _view.debug_buffer.size() == _shown:
		return
	for entry: Dictionary in _view.debug_buffer.slice(_shown):
		_text.add_text("%d %s\n" % [int(entry.seq), JSON.stringify(entry.payload).left(PAYLOAD_CHARS)])
	_shown = _view.debug_buffer.size()
