## G2b planted violation (gameplay scope): a coroutine in rules code.
extends RefCounted


func resolve(step: Callable) -> void:
	await step.call()
