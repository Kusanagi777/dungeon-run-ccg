## `ChoiceRequest` — the one outstanding Discover / Choose One choice
## (design/gdd/card-effects.md C8; match-rules C1 `pending_choice`, C2;
## ADR-0007 Key Interfaces): `{side, kind, options, source_id, effect_id}`.
##
## Shape only (story 002). The record is plain data built by
## `MatchRecords.choice_request` — the engine's `discover` primitive stores it
## as `MatchState.pending_choice` — so this script names the shape for the
## resolver and builds nothing of its own. Story 010 wires the continuation.
## - `side`: who chooses (`"player"` / `"boss"`).
## - `kind`: one of [constant KINDS].
## - `options`: definition ids for Discover, option records for Choose One.
## - `source_id`: the entity id of the card that offered it (or null).
## - `effect_id`: the offering effect's id.
## [codeblock]
## var req: Dictionary = ChoiceRequest.make("player", ChoiceRequest.KIND_DISCOVER, ["a_01", "b_02", "c_03"], 7, "scout.0")
## [/codeblock]
class_name ChoiceRequest
extends RefCounted

## The record's keys, exactly these.
const FIELDS: Array[String] = ["side", "kind", "options", "source_id", "effect_id"]
const KIND_DISCOVER: String = MatchRecords.CHOICE_DISCOVER
const KIND_CHOOSE_ONE: String = MatchRecords.CHOICE_CHOOSE_ONE
## The C8 choice kinds.
const KINDS: Array[String] = [KIND_DISCOVER, KIND_CHOOSE_ONE]


## A ChoiceRequest record — `MatchRecords.choice_request` with the same
## arguments (one shape, one builder). [param options] is stored as given.
static func make(side: String, kind: String, options: Array, source_id: Variant, effect_id: String) -> Dictionary:
	return MatchRecords.choice_request(side, kind, options, source_id, effect_id)
