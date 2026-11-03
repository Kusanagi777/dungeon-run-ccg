## G5 must-not-hit: `*_controller.gd` forwards to the driver.
extends RefCounted

var _driver: RefCounted = null


func forward(command: RefCounted) -> RefCounted:
	return _driver.submit(command)
