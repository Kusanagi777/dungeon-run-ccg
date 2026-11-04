## The `RunShell` stub: the root of everything outside a match (ADR-0011
## Decision 1; run-ui U1 and S1/S2), standing in until the Run UI epic
## replaces its body and keeps its file names (boot-composition-root story 006).
##
## Display only (`.claude/rules/ui-code.md`): it owns no game state, sends no
## commands and has no interactive element yet (focus and gamepad rules are the
## Run UI epic's). `main.gd` boots and hands the `Services` bag over with
## [method bind] **before** adding the shell to the tree; the bag is stored on
## this root only and passed nowhere deeper (ADR-0001: scene roots receive
## services by argument). Launched directly as a scene, with no bag bound, it
## falls back to `Boot.services()` once in `_ready()` (the `--run-ui-screen`
## path the Run UI epic adds) — the only other `Boot` reference under `src/ui/`.
##
## Two placeholder states, chosen once from the Card Database's load state:
## - `main_menu` (load `Ready`): the title and a "Run UI pending" line;
## - `data_error` (load `Failed`, or no database): a heading and one `Label`
##   per `ValidationReport.to_text()` row (card-database CR-8 shape). `Failed`
##   has no main menu (TD-008).
## Colours are the art bible §4 tokens set as theme overrides in
## `run_shell.tscn` (`bg_edge`, `text_light`, `text_muted`); every visible
## copy string goes through `tr()` (report rows are data, shown verbatim).
## [codeblock]
## var shell: RunShell = preload("res://src/ui/run/run_shell.tscn").instantiate()
## shell.bind(Boot.services())
## add_child(shell)
## shell.screen()   # &"main_menu" or &"data_error"
## [/codeblock]
class_name RunShell
extends Control

## The `main_menu` title (a `tr()` source string).
const TITLE_TEXT := "Deckdelve"
## The `main_menu` placeholder line until the Run UI epic lands.
const PENDING_TEXT := "Run UI pending"
## The `data_error` heading.
const DATA_ERROR_TEXT := "The game data failed to load"
## The `data_error` sub-line; `%d` is the number of report rows.
const DATA_ERROR_COUNT_TEXT := "%d problems — fix the data files and restart"
## Screen ids (run-ui U2 rows).
const SCREEN_MAIN_MENU: StringName = &"main_menu"
const SCREEN_DATA_ERROR: StringName = &"data_error"

var _services: Services = null
var _screen: StringName = &""

@onready var _main_menu: Control = %MainMenu
@onready var _data_error: Control = %DataError
@onready var _title_label: Label = %TitleLabel
@onready var _pending_label: Label = %PendingLabel
@onready var _error_title_label: Label = %ErrorTitleLabel
@onready var _error_count_label: Label = %ErrorCountLabel
@onready var _error_rows: VBoxContainer = %ErrorRows
@onready var _error_row_template: Label = %ErrorRowTemplate


## Hands the shell its services. Call before `add_child`; `_ready()` reads it.
## Example: `shell.bind(Boot.services())`.
func bind(services: Services) -> void:
	_services = services


## The services bag this shell was bound to (or fell back to). Example: `shell.services().card_database`.
func services() -> Services:
	return _services


## The placeholder state shown: [constant SCREEN_MAIN_MENU] or
## [constant SCREEN_DATA_ERROR]; `&""` before `_ready()`.
## Example: `shell.screen() == &"main_menu"`.
func screen() -> StringName:
	return _screen


func _ready() -> void:
	if _services == null:
		_services = Boot.services()
	_title_label.text = tr(TITLE_TEXT)
	_pending_label.text = tr(PENDING_TEXT)
	_error_title_label.text = tr(DATA_ERROR_TEXT)
	_error_row_template.visible = false
	var db: CardDatabase = _services.card_database if _services != null else null
	if db != null and db.state() == CardDatabase.State.READY:
		_show(SCREEN_MAIN_MENU)
		return
	var lines: PackedStringArray = []
	if db != null and not db.report().to_text().is_empty():
		lines = db.report().to_text().split("\n")
	_error_count_label.text = tr(DATA_ERROR_COUNT_TEXT) % lines.size()
	for line: String in lines:
		var row: Label = _error_row_template.duplicate() as Label
		row.text = line
		row.visible = true
		_error_rows.add_child(row)
	_show(SCREEN_DATA_ERROR)


func _show(id: StringName) -> void:
	_screen = id
	_main_menu.visible = id == SCREEN_MAIN_MENU
	_data_error.visible = id == SCREEN_DATA_ERROR
