## Utilities for scene-based integration tests (Match UI, Run UI). The rules
## layer has no Nodes (DD-T02), so unit suites never need this file. For input
## simulation and frame stepping use gdUnit4's own `scene_runner()` from
## inside the suite.
##
## Plain class, so the runner never discovers it as a suite with zero tests.
class_name SceneRunnerHelper
extends RefCounted


## Instantiate `scene` (a `res://` path or a PackedScene) under `host` — the
## calling test suite passes `self` — and wait one frame so `_ready()` has
## run. The caller owns the node: wrap the result in `auto_free(...)` or free
## it in `after_test()`, or gdUnit4 reports an orphan (exit 101).
static func load_scene_and_wait(host: Node, scene: Variant) -> Node:
	var packed: PackedScene = scene if scene is PackedScene else load(str(scene)) as PackedScene
	if packed == null:
		GameAssertions.fail_if(true, "SceneRunnerHelper: '%s' is not a PackedScene" % str(scene))
		return null
	var instance: Node = packed.instantiate()
	host.add_child(instance)
	await host.get_tree().process_frame
	return instance
