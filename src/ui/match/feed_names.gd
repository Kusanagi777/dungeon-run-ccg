## Entity ids to names for feed lines (match-ui U10): every name resolves through
## `card_text(card_id).name_key`, or a hero or boss name key, never a payload string.
## It learns ids from the lines themselves, so a dead minion keeps its name, and it can
## only ever know what the view-state let through: a boss card in hand has no `card_id`
## in its line (U3.2), so it stays nameless until it is played.
## [codeblock]
## var names := FeedNames.new(query.card_text)
## names.set_heroes("hero_war", "boss_torchbearer")
## names.learn(line)
## names.of(12)   # "Torch Imp"
## [/codeblock]
class_name FeedNames
extends RefCounted

## The name an id takes when no line has introduced it.
const KEY_SOMEONE: String = "feed.someone"
## The name a card takes when its id is not shown, as a boss draw.
const KEY_A_CARD: String = "feed.a_card"

const _ID_FIELDS: Array[String] = ["entity_id", "instance_id"]
const _KEY_MATCH_STARTED: String = "feed.match_started"

var _card_text: Callable = Callable()
var _hero_key: String = ""
var _boss_key: String = ""
# entity or instance id → name key.
var _keys: Dictionary = {}


## [param card_text] is `MatchQuery.card_text`.
func _init(card_text: Callable) -> void:
	_card_text = card_text


## The name keys the two heroes read as, from the `MatchConfig`.
func set_heroes(hero_def_id: String, boss_def_id: String) -> void:
	_hero_key = MatchStrings.HERO_NAME_KEY % hero_def_id if hero_def_id != "" else ""
	_boss_key = MatchStrings.BOSS_NAME_KEY % boss_def_id if boss_def_id != "" else ""


## Takes every id [param line] introduces.
func learn(line: Dictionary) -> void:
	var params: Dictionary = line.get("params", {})
	if str(line.get("key", "")) == _KEY_MATCH_STARTED:
		_keys[int(params.get("hero_id", 0))] = _hero_key
		_keys[int(params.get("boss_id", 0))] = _boss_key
		return
	if not params.has("card_id"):
		return
	var key: String = card_key(str(params.card_id))
	if key == "":
		return
	for field: String in _ID_FIELDS:
		if params.get(field) != null:
			_keys[int(params[field])] = key


## The name of entity [param id], which may be null or a non-id: a fatigue source has none,
## and a treasure's hook names its treasure by String id.
func of(id: Variant) -> String:
	if id is String and TranslationServer.translate(MatchStrings.TREASURE_NAME_KEY % id) != MatchStrings.TREASURE_NAME_KEY % id:
		return _translate(MatchStrings.TREASURE_NAME_KEY % id)
	var known: bool = (id is int or id is float) and str(_keys.get(int(id), "")) != ""
	return _translate(str(_keys[int(id)]) if known else KEY_SOMEONE)


## The name key of [param card_id] through `card_text`, or `""` for an unknown card.
func card_key(card_id: String) -> String:
	if card_id == "" or not _card_text.is_valid():
		return ""
	var text: Dictionary = _card_text.call(card_id)
	return str(text.get("name_key", ""))


## The name of [param card_id], or "a card" when it is unknown or hidden.
func card(card_id: String) -> String:
	var key: String = card_key(card_id)
	return _translate(key if key != "" else KEY_A_CARD)


static func _translate(key: String) -> String:
	return String(TranslationServer.translate(key))
