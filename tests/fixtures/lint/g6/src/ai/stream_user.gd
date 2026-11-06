## G6 must-not-hit: calls on an injected stream, the stream's own seed field,
## and identifiers that end in a token (ADR-0001 G6 erratum 2026-11-03).
extends RefCounted

var _stream: RefCounted = null


func roll(cards: Array, rng: RandomNumberGenerator) -> float:
	_stream.shuffle(cards)
	rng.seed = 4
	var forked: int = _fork_seed(1)
	var face: int = _stream.randi_range(1, 6)
	return _stream.randf() + self.randf() + forked + face


func _fork_seed(label: int) -> int:
	return label
