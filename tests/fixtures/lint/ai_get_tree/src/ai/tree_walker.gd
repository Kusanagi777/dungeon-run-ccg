## Never `get_tree()` in a doc comment: must not hit.
extends RefCounted

func wait() -> void:
	var tree: Variant = get_tree()
	tree.quit()
