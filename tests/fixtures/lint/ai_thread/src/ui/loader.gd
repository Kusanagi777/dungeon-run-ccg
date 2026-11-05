## Must hit AI-THREAD on line 5, and not on this doc comment's `Thread`.
extends RefCounted

func load_async() -> void:
	var worker: Thread = Thread.new()
	worker.start(_work)

func _work() -> void:
	pass
