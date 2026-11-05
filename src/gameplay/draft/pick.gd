## The answer to one accepted, or refused, `RewardDraft.pick` (reward-draft D1, D9).
## Reward Draft mutates nothing: the run reads this and appends.
## [codeblock]
## var pick: Pick = draft.pick(&"bundle", id, offer, run_state)
## if pick.error == OK:
##     run_state.deck.append_array(pick.card_ids_added)
## [/codeblock]
class_name Pick
extends RefCounted

## The id taken, or null for a "take nothing" under `allow_skip`.
var picked_id: Variant = null
## The position of [member picked_id] in the sorted `option_ids`; -1 when none.
var option_index: int = -1
## The bundle's cards in data order; `[]` for a treasure.
var card_ids_added: Array[String] = []
## `OK`, `RunCodes.E_NOT_OFFERED` or `RunCodes.E_UNKNOWN_ID`. When not `OK` nothing
## was emitted and the other fields mean nothing.
var error: Error = OK
