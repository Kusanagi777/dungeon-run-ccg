## G2 planted violation: rules code reaching into the scene tree (TD-003).
extends RefCounted


func board_size() -> int:
	return get_tree().get_nodes_in_group("minions").size()
