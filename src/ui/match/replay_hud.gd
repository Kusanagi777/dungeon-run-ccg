## What a replay adds to the match view: a "Replay" badge and the way out, the Exit button
## or `Esc`. An open feed drawer takes `Esc` first. Skip works as in a live match, so
## `Space` runs the current burst to its end.
## [codeblock]
## var hud := ReplayHud.new()
## view.add_child(hud)
## hud.attach(view.ui_context(), view.feed())
## hud.exit_requested.connect(view.close_replay)
## [/codeblock]
class_name ReplayHud
extends Control

## The player left the replay.
signal exit_requested()

var _feed: FeedPresenter = null


## Builds the badge and the button at their rects.
func attach(context: MatchUiContext, feed: FeedPresenter) -> void:
	_feed = feed
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_rect: Rect2 = context.rect("replay_badge")
	var badge := Label.new()
	badge.text = tr("replay.badge")
	badge.position = badge_rect.position
	badge.size = badge_rect.size
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_color_override("font_color", context.color("state_target"))
	add_child(badge)
	var exit_rect: Rect2 = context.rect("replay_exit")
	var button := Button.new()
	button.text = tr("replay.exit")
	button.position = exit_rect.position
	button.size = exit_rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: exit_requested.emit())
	add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if _feed == null or not _feed.is_open():
			exit_requested.emit()
			get_viewport().set_input_as_handled()
