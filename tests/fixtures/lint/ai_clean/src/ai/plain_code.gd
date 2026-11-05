## Must not hit: strings, comments, identifiers, indices, 0 and 1.
extends RefCounted

const NOT_A_NUMBER: String = "7"

var node_2d_count: int = 0

func score(weights: Array, name: String) -> float:
	var label: String = "stage 7b, C8.4, D-04, \"quoted 9\" %s" % name  # a comment with 42
	var third: int = int(weights[2])
	var none: int = -1
	return float(third + none) * 1.0 + 0.0 + label.length()
