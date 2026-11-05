## The text behind every `tr()` key of Run UI (run-ui U1.4). No translation file ships
## yet, so one `Translation` is built from `config("run_ui").strings`, once per process,
## the way `MatchStrings` does for the match. Data text follows Card Database's rule:
## its key when a string table has it, else `text.en`.
## [codeblock]
## RunText.install(db.config("run_ui"))
## RunText.t("summary.headline.defeat", {"n": 5, "boss": "Rat King"})
## RunText.data({"key": "boss.x.passive", "en": "At the end of the boss's turn..."})
## [/codeblock]
class_name RunText
extends RefCounted

const LOCALE: String = "en"

static var _installed: bool = false


## Adds the translation to `TranslationServer`, once.
static func install(ui_config: Dictionary) -> void:
	if _installed:
		return
	_installed = true
	var table: Translation = Translation.new()
	table.locale = LOCALE
	var strings: Dictionary = ui_config.get("strings", {})
	for key: String in strings:
		table.add_message(key, str(strings[key]))
	TranslationServer.add_translation(table)


## The text of [param key], its `{name}` fields filled from [param args].
static func t(key: String, args: Dictionary = {}) -> String:
	var text: String = String(TranslationServer.translate(key))
	return text.format(args) if not args.is_empty() else text


## The display text of a data `text` object, `""` for anything else.
static func data(text: Variant) -> String:
	if not text is Dictionary:
		return ""
	var key: String = str(text.get("key", ""))
	if not key.is_empty():
		var resolved: String = String(TranslationServer.translate(key))
		if resolved != key:
			return resolved
	return str(text.get("en", ""))
