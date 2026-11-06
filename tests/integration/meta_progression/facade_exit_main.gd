## The child process of `meta_facade_teardown_test.gd` (TD-013): loads the shipped data,
## composes a `MetaFacade` over a scratch store, exercises it, and quits with the facade
## still referenced, the shape of a game closed with a profile open. No inner class: an
## unanchored one is TD-013's fault in its own right.
##
##   godot --headless --path . -s res://tests/integration/meta_progression/facade_exit_main.gd
extends SceneTree

const BOOT_PATH: String = "res://src/core/boot.gd"
const SCRATCH: String = "user://meta_exit_probe_%d"
const EXIT_CLEAN: int = 0
const EXIT_NOT_RUN: int = 2

var _meta: MetaFacade = null
var _clock_now: int = 1800000000


func _initialize() -> void:
	var boot: Node = (load(BOOT_PATH) as GDScript).new()
	var db: CardDatabase = CardDatabase.new()
	db.load(boot._collect_validators(null))
	boot.free()
	if db.state() != CardDatabase.State.READY:
		quit(EXIT_NOT_RUN)
		return
	var root: String = SCRATCH % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(root)
	var body: Dictionary = db.config("profile_defaults")
	var knobs: Dictionary = body[ProfileStore.KNOBS_KEY]
	var lock: ProfileLock = ProfileLock.new(root.path_join("profile.lock"), int(knobs.lock_stale_s), _clock)
	var store: ProfileStore = ProfileStore.new(ProfileStore.settings_defaults(body), knobs, AtomicFileWriter.new(), lock, _clock, root)
	_meta = MetaFacade.new(store, UnlockEvaluator.new(db, knobs), StatsFold.new(true))
	_meta.load_profile()
	_meta.set_setting(&"gamma", 1.2)
	_meta.save_active_run({"run_id": "run_exit"})
	_meta.clear_active_run()
	store.release_lock()
	_remove(root)
	quit(EXIT_CLEAN)


func _clock() -> int:
	return _clock_now


func _remove(root: String) -> void:
	for file: String in DirAccess.get_files_at(root):
		DirAccess.remove_absolute(root.path_join(file))
	DirAccess.remove_absolute(root)
