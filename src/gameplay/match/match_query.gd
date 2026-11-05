## The rules-tier read model the UI queries (ADR-0008 Decision 6 and its erratum
## 2026-11-03; match-ui U2). `MatchDriver.query()` builds one over the live engine,
## the database and the settings, and it answers at all times: no worker ever
## touches the live engine. Every answer is a value copy.
##
## **Hidden information.** A boss Choice's options never leave here: the player sees
## only that the boss is choosing (match-ui "If a Choice is raised during the boss
## turn"), so [method pending_choice] answers it with `options` empty.
##
## `boss-ai-match-driver/story-013` needs `query()` to answer, so this file starts
## with the three reads that are pass-throughs of the engine; `match-ui/story-003`
## owns the class and adds `entity`, `hand`, `card_text` and `hero_power_state`,
## which is what [member _db] and [member _settings] are held for.
## [codeblock]
## var query: MatchQuery = driver.query()
## var choice: Variant = query.pending_choice()
## if choice != null and choice.side == MatchRecords.SIDE_PLAYER:
##     show_options(choice.options)
## [/codeblock]
class_name MatchQuery
extends RefCounted

var _engine: RulesEngine
var _db: CardDatabase
var _settings: Dictionary


## A query over [param engine], the live one, [param db] and the settings
## snapshot [param settings].
func _init(engine: RulesEngine, db: CardDatabase, settings: Dictionary) -> void:
	_engine = engine
	_db = db
	_settings = settings


## The current phase, one of [constant MatchState.PHASES].
func phase() -> String:
	return _engine.phase()


## A value copy of the pending `ChoiceRequest`, or null. A boss Choice comes back
## with `options` empty: see the class description.
func pending_choice() -> Variant:
	var choice: Variant = _engine.pending_choice()
	if choice is Dictionary and str(choice.side) == MatchRecords.SIDE_BOSS:
		choice.options = []
	return choice


## The commands the live engine would accept now; a fresh list on every call.
func legal_commands() -> Array:
	return _engine.legal_commands()
