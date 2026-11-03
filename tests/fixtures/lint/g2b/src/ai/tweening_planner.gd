## G2b planted violation (ai scope): awaiting a presentation signal.
extends RefCounted


func plan(anim: Tween) -> void:
	await anim.finished
