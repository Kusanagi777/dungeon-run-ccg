## Must not hit: a pinned row and a pinned constant, in their own file.
extends RefCounted

const RANGES: Dictionary = {
	"w_board": {"min": 0.0, "max": 5.0, "integral": false, "row": "F1 w_board"},
}
const MAX_REJECTIONS: int = 3
