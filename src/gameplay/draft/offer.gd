## One draft offer (reward-draft D1, D11; architecture.md `Offer`): the ids, the
## `flags[]`, and the per-option numbers Run UI's hint line reads. Held in memory by
## the run and never saved: resume regenerates it (run-structure R5.3).
## [codeblock]
## var offer: Offer = draft.offer(&"bundle", run_state, stream)
## offer.option_ids          # id-sorted, 3 normally, 1-2 when flagged short, [] to skip
## offer.read_model(deck_size, bundle_size, false).options[0].n_tag
## [/codeblock]
class_name Offer
extends RefCounted

## `flags[]` vocabulary (reward-draft D11).
const FLAG_PITY_FORCED: StringName = &"pity_forced"
const FLAG_COVERAGE_FORCED: StringName = &"coverage_forced"
const FLAG_UNIVERSAL_FORCED: StringName = &"universal_forced"
const FLAG_UNIVERSAL_MISSING: StringName = &"universal_missing"
const FLAG_REOFFER: StringName = &"reoffer"
const FLAG_SHORT: StringName = &"short"

## `DraftRecord.KIND_TREASURE` or `DraftRecord.KIND_BUNDLE`.
var kind: String = ""
## The floor this offer follows.
var floor: int = 0
## Ascending by id, so a slot index says nothing about a forced slot (D6 step 4).
var option_ids: Array[String] = []
var flags: Array[StringName] = []
## One row per [member option_ids] entry, same order: `{id, theme, n_tag}` for a
## bundle, `{id, affine}` for a treasure. Never a weight (reward-draft UI Requirements).
var per_option: Array[Dictionary] = []


## The Dictionary the draft picker renders (design/ux/draft-picker.md). The hint
## numbers sit in `options`; `deck_size` and `deck_size_after` feed "Deck a -> b".
## [param bundle_size] is the cards a bundle adds, [param allow_skip] shows
## "Take nothing".
func read_model(deck_size: int, bundle_size: int, allow_skip: bool) -> Dictionary:
	var flag_names: Array[String] = []
	for flag: StringName in flags:
		flag_names.append(String(flag))
	return {
		"kind": kind,
		"floor": floor,
		"option_ids": Array(option_ids).duplicate(),
		"flags": flag_names,
		"options": Array(per_option).duplicate(true),
		"deck_size": deck_size,
		"deck_size_after": deck_size + bundle_size if kind == DraftRecord.KIND_BUNDLE else deck_size,
		"allow_skip": allow_skip,
	}
