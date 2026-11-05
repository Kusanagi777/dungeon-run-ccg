## Must not hit: `RulesEngine.emit` is a method, no signal.
extends RefCounted

func replay(engine: RulesEngine) -> void:
	engine.emit(&"ai_decision", {})
