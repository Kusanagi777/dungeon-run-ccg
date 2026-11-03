## Boot screen — the project's `run/main_scene` and the test-rig proof scene.
##
## Display only (`.claude/rules/ui-code.md`): it owns no game state, reads no
## autoload and sends no commands. It exists so that `commands.smoke`
## (`godot --headless --quit-after 5`) has a scene to launch into and so
## `tools/capture.sh` has something with text to photograph.
##
## Colours are the art bible §4 tokens, set as theme overrides in
## `res://src/scenes/boot.tscn` (data, not code): background `bg_edge`
## `#141820`, title `text_light` `#F2E9D8`, build stamp `text_muted` `#B8AC96`.
##
## Engine APIs used: `tr()` on every visible string
## (`docs/engine-reference/godot/modules/ui.md` § "Localization-Ready UI");
## `%UniqueName` node access (same file, § "Focus Management");
## `ProjectSettings.get_setting()` and `Engine.get_version_info()` are
## unchanged Godot 4 core APIs (not version-qualified in the reference).
class_name BootScreen
extends Control

## Title shown centred on screen. Passed through `tr()` at runtime; with no
## translation catalogue loaded it is shown verbatim.
const TITLE_TEXT := "Deckdelve — boot"

## Format of the bottom-left build stamp: `<project name> — Godot <version>`.
## A developer readout, not player copy; it is still routed through `tr()`.
const BUILD_STAMP_FORMAT := "%s — Godot %s"

@onready var _title_label: Label = %TitleLabel
@onready var _build_stamp_label: Label = %BuildStampLabel


func _ready() -> void:
	_title_label.text = tr(TITLE_TEXT)
	_build_stamp_label.text = build_stamp()


## The build stamp text: the project name from
## `application/config/name` and the running engine's version string
## (for example `Dungeon Run CCG — Godot 4.7.2.stable.official.ed1daf0bf`).
## Public so a test can compare the label against the same source.
func build_stamp() -> String:
	var project_name: String = ProjectSettings.get_setting("application/config/name", "")
	var version: Dictionary = Engine.get_version_info()
	var version_string: String = str(version.get("string", ""))
	return tr(BUILD_STAMP_FORMAT) % [project_name, version_string]
