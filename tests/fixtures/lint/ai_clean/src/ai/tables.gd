## Must not hit: the named tables, strings, comments, identifiers, indices.
extends RefCounted

const RANGES: Dictionary = {
	"w_board": {"min": 0.0, "max": 5.0, "integral": false, "row": "F1 w_board"},
}
const NORMALISERS: Dictionary = {
	"card_norm": 3.0,
}
const BOARD_SELECTORS: Dictionary = {
	"all_characters": [1, 1, 2],
}
const ALTERNATIVES_MAX: int = 3
const MAX_REJECTIONS: int = 3
const UNBOUNDED: int = 9223372036854775807
const NOT_A_NUMBER: String = "7"

var node_2d_count: int = 0

func score(weights: Array, name: String) -> float:
	var label: String = "stage 7b, C8.4, D-04, \"quoted 9\" %s" % name  # a comment with 42
	var third: int = int(weights[2])
	var none: int = -1
	return float(third + none) * 1.0 + 0.0 + label.length()
