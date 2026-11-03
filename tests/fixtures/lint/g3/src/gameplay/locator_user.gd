## G3 planted violation: rules code reading the composition root (TD-001).
extends RefCounted


func database() -> RefCounted:
	return Boot.services().card_database
