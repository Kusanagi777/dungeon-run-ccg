## A weight of 2.5 in a doc comment must not hit.
extends RefCounted

var weight: float = 2.5
var delay_ms: int = 300

func score(value: float) -> float:
	var scaled: float = value * 1.5
	var big: int = 1_000
	var mask: int = 0x10
	var tiny: float = .5
	var huge: float = 1e3
	return scaled + big + mask + tiny + huge
