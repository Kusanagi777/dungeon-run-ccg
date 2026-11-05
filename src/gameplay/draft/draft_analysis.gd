## The analysis formulas of Reward Draft (design/gdd/reward-draft.md F7, F8): how
## coherent a deck came out and how far the starter is diluted. Nothing in play reads
## these; `/balance-check` and the sweep harness do. Static and pure.
## [codeblock]
## DraftAnalysis.p_no_starter_hand(36, 15, 3)   # 1330 / 7140
## DraftAnalysis.plan_share(deck, plan_tags, db)
## [/codeblock]
class_name DraftAnalysis
extends RefCounted


## F7 `plan_share`: the share of [param deck] carrying any of [param plan_tags].
static func plan_share(deck: Array, plan_tags: Array, db: CardDatabase) -> float:
	if deck.is_empty():
		return 0.0
	var on_plan: int = 0
	for card_id: Variant in deck:
		for tag: Variant in db.card(str(card_id)).tags:
			if plan_tags.has(tag):
				on_plan += 1
				break
	return float(on_plan) / float(deck.size())


## F7 `top_tag_share`: the largest `n_tag` over [param deck], as a share of it.
static func top_tag_share(deck: Array, db: CardDatabase) -> float:
	if deck.is_empty():
		return 0.0
	var counts: Dictionary = {}
	var top: int = 0
	for card_id: Variant in deck:
		for tag: Variant in db.card(str(card_id)).tags:
			counts[tag] = int(counts.get(tag, 0)) + 1
			top = maxi(top, counts[tag])
	return float(top) / float(deck.size())


## F8 `p_starter`.
static func p_starter(deck_size: int, starter_size: int) -> float:
	return float(starter_size) / float(deck_size)


## F8 `E_starter_seen` over the first [param cards_seen] cards.
static func expected_starter_seen(deck_size: int, starter_size: int, cards_seen: int) -> float:
	return float(cards_seen) * p_starter(deck_size, starter_size)


## F8 `P_no_starter_hand`: an opening hand of [param hand_size] with no starter card.
static func p_no_starter_hand(deck_size: int, starter_size: int, hand_size: int) -> float:
	return float(_choose(deck_size - starter_size, hand_size)) / float(_choose(deck_size, hand_size))


## F8 `P_card_seen`: one specific card in the first [param cards_seen].
static func p_card_seen(deck_size: int, cards_seen: int) -> float:
	return float(cards_seen) / float(deck_size)


## `C(n, k)`, exact in integers at deck sizes; 0 when `k > n`.
static func _choose(n: int, k: int) -> int:
	if k > n or k < 0:
		return 0
	var result: int = 1
	for i: int in range(k):
		@warning_ignore("integer_division")
		result = result * (n - i) / (i + 1)
	return result
