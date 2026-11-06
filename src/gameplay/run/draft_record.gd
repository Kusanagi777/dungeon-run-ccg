## One completed draft step, as the run persists it (run-structure R1 `drafts[]`):
## `{floor, kind, offered_ids[], picked_id, card_ids_added[]}`. `picked_id` is
## `null` and `card_ids_added` is `[]` for a skipped step (R5.7) or a "take nothing"
## (reward-draft D9). Reward Draft derives exclusion and pity from these records
## (D3), so nothing else keeps that history.
## [codeblock]
## var record := DraftRecord.make(3, DraftRecord.KIND_TREASURE, offer.option_ids, id, [])
## var round_trip: DraftRecord = DraftRecord.from_dict(record.to_dict())
## [/codeblock]
class_name DraftRecord
extends RefCounted

## The two draft kinds (R1 `reward_step`, reward-draft D1).
const KIND_TREASURE: String = "treasure"
const KIND_BUNDLE: String = "bundle"
const KINDS: Array[String] = [KIND_TREASURE, KIND_BUNDLE]

## The floor the draft followed.
var floor: int = 0
## [constant KIND_TREASURE] or [constant KIND_BUNDLE].
var kind: String = ""
## `Offer.option_ids` as it stood (the naming rule, reward-draft D11).
var offered_ids: Array[String] = []
## The id taken, or null when none was.
var picked_id: Variant = null
## The bundle's cards in data order; `[]` for a treasure or a skipped step.
var card_ids_added: Array[String] = []


## A record of the step on [param floor_number]. The lists are copied.
static func make(floor_number: int, step_kind: String, offered: Array, picked: Variant, added: Array) -> DraftRecord:
	var record: DraftRecord = DraftRecord.new()
	record.floor = floor_number
	record.kind = step_kind
	record.offered_ids.assign(offered)
	record.picked_id = picked
	record.card_ids_added.assign(added)
	return record


## The R5.7 record of a step whose offer came back empty.
static func skipped(floor_number: int, step_kind: String) -> DraftRecord:
	return make(floor_number, step_kind, [], null, [])


## The JSON form (R1).
func to_dict() -> Dictionary:
	return {
		"floor": floor,
		"kind": kind,
		"offered_ids": Array(offered_ids).duplicate(),
		"picked_id": picked_id,
		"card_ids_added": Array(card_ids_added).duplicate(),
	}


## A record from [param d], which [method validate] has accepted, or from a damaged
## save on its way to the archive: a field of the wrong shape takes its default.
static func from_dict(d: Dictionary) -> DraftRecord:
	var record: DraftRecord = DraftRecord.new()
	var floor_value: Variant = d.get("floor")
	if floor_value is int or floor_value is float:
		record.floor = int(floor_value)
	record.kind = str(d.get("kind", ""))
	var picked: Variant = d.get("picked_id")
	record.picked_id = picked if picked is String else null
	record.offered_ids.assign(_strings_in(d.get("offered_ids")))
	record.card_ids_added.assign(_strings_in(d.get("card_ids_added")))
	return record


## True when [param d] has the R1 shape: a known kind, a positive floor, id lists,
## a `picked_id` that was offered or is null, and no cards without a pick.
static func validate(d: Variant) -> bool:
	if not d is Dictionary:
		return false
	var record: Dictionary = d
	var floor_value: Variant = record.get("floor")
	if not (floor_value is int or floor_value is float) or int(floor_value) < 1:
		return false
	if not record.get("kind") is String or not KINDS.has(record.kind) or not record.has("picked_id"):
		return false
	var offered: Variant = record.get("offered_ids")
	var added: Variant = record.get("card_ids_added")
	if not offered is Array or not added is Array:
		return false
	if _strings_in(offered).size() != (offered as Array).size() or _strings_in(added).size() != (added as Array).size():
		return false
	var picked: Variant = record.get("picked_id")
	if picked == null:
		return (added as Array).is_empty()
	return picked is String and (offered as Array).has(picked)


static func _strings_in(value: Variant) -> Array:
	if not value is Array:
		return []
	return (value as Array).filter(func(item: Variant) -> bool: return item is String)
