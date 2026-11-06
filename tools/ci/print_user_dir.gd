## Prints this process's `user://` folder and quits, for `tools/bin/godot --self-check`.
extends SceneTree


func _init() -> void:
	print(OS.get_user_data_dir())
	quit()
