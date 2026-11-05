## The English text behind every `tr()` key the match view uses. No translation file
## ships yet, so the view registers one `Translation` built from the data it already
## has: `config("match_ui").strings`, and each record's own name and `text.en`.
## Keys follow the content rule (`card.<id>.name`, `MatchQuery.NAME_KEY_FORMAT`) and
## the records' `text.key`. Installed once per process.
## [codeblock]
## MatchStrings.install(db, db.config("match_ui"))
## label.text = tr("card.war_sharpen.name")
## [/codeblock]
class_name MatchStrings
extends RefCounted

const LOCALE: String = "en"
## `CardDatabase.cards_by_type` covers every card through these.
const CARD_TYPES: Array[String] = ["minion", "spell", "weapon"]
const BANDS: Array[int] = [1, 2, 3]
const HERO_NAME_KEY: String = "hero.%s.name"
const BOSS_NAME_KEY: String = "boss.%s.name"
const POWER_NAME_KEY: String = "power.%s.name"
const POWER_TEXT_KEY: String = "power.%s.text"
const TREASURE_NAME_KEY: String = "treasure.%s.name"

static var _installed: bool = false


## Adds the translation to `TranslationServer`, once. Later calls do nothing.
static func install(db: CardDatabase, ui_config: Dictionary) -> void:
	if _installed:
		return
	_installed = true
	var table: Translation = Translation.new()
	table.locale = LOCALE
	var strings: Dictionary = ui_config.get("strings", {})
	for key: String in strings:
		table.add_message(key, str(strings[key]))
	for type: String in CARD_TYPES:
		for card: Dictionary in db.cards_by_type(type):
			table.add_message(MatchQuery.NAME_KEY_FORMAT % str(card.id), str(card.get("name", card.id)))
			_add_text(table, card.get("text"))
	for hero: Dictionary in db.heroes():
		table.add_message(HERO_NAME_KEY % str(hero.id), str(hero.get("name", hero.id)))
		_add_text(table, hero.get("text"))
		var power: Variant = db.hero_power(str(hero.hero_power))
		if power is Dictionary:
			table.add_message(POWER_NAME_KEY % str(power.id), str(power.get("name", power.id)))
			_add_text(table, power.get("text"))
	for band: int in BANDS:
		for boss: Dictionary in db.bosses_in_band(band):
			table.add_message(BOSS_NAME_KEY % str(boss.id), str(boss.get("name", boss.id)))
			_add_text(table, boss.get("passive_text"))
	for treasure: Variant in db.treasure_pool():
		if treasure is Dictionary:
			table.add_message(TREASURE_NAME_KEY % str(treasure.id), str(treasure.get("name", treasure.id)))
			_add_text(table, treasure.get("text"))
	TranslationServer.add_translation(table)


static func _add_text(table: Translation, text: Variant) -> void:
	if text is Dictionary and str(text.get("key", "")) != "":
		table.add_message(str(text.key), str(text.get("en", "")))
