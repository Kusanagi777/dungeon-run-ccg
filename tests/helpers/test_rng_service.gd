## RNG service test double for RNG & Event Log rules 2, 3 and 10.
##
## Created with `(run_seed, data_version)`; `stream(name)` returns a memoised
## `TestRngStream` seeded by F2 `stream_seed(run_seed, name)`, so two services
## built with the same seed hand out identical sequences (match-rules AC-01,
## rng-event-log AC "two services created with run_seed = 42"). `snapshot()` and
## `restore()` follow rule 10 / F5. A test that needs a scripted or constant
## stream registers it with `install(stream)` before the code under test asks.
##
## TODO(E1 story): swap to the production RngService once it exists.
class_name TestRngService
extends RefCounted

## The run's single 64-bit seed (rule 1).
var run_seed: int = 0
## Card Database `data_version` the service was created under (rule 10).
var data_version: String = ""

var _streams: Dictionary = {}


func _init(seed_value: int = TestConstants.DEFAULT_TEST_SEED, version: String = "test") -> void:
	run_seed = seed_value
	data_version = version


## Rule 2: the memoised stream for `stream_name`, created on first use with
## F2's seed. Logs an error for a name outside rule 3's pattern (still served).
func stream(stream_name: String) -> TestRngStream:
	if not TestRngStream.is_valid_stream_name(stream_name):
		push_error("TestRngService.stream: '%s' violates the rule 3 name pattern" % stream_name)
	if not _streams.has(stream_name):
		_streams[stream_name] = TestRngStream.seeded(stream_name, TestRngStream.stream_seed_for(run_seed, stream_name))
	return _streams[stream_name]


## Register a prepared stream (scripted, constant or recording) under its own
## name so `stream(name)` returns it. Replaces any memoised stream of that name.
func install(prepared: TestRngStream) -> TestRngStream:
	_streams[prepared.name] = prepared
	return prepared


## True when `stream_name` has been requested or installed in this service.
func has_stream(stream_name: String) -> bool:
	return _streams.has(stream_name)


## Rule 10: `{run_seed, data_version, streams: {name: draws}}`, JSON-only.
func snapshot() -> Dictionary:
	var positions: Dictionary = {}
	for stream_name: String in _streams:
		positions[stream_name] = (_streams[stream_name] as TestRngStream).draws
	return {"run_seed": run_seed, "data_version": data_version, "streams": positions}


## Rule 10 / F5: rebuild every stream named in `snapshot` at its recorded
## position. Returns an error when `data_version` differs (rng-event-log
## Edge Cases "saved run with a different data_version") and creates nothing.
func restore(snap: Dictionary) -> Error:
	if str(snap.get("data_version", "")) != data_version:
		return ERR_INVALID_DATA
	run_seed = int(snap.get("run_seed", run_seed))
	_streams.clear()
	var positions: Dictionary = snap.get("streams", {})
	for stream_name: String in positions:
		stream(stream_name).restore(int(positions[stream_name]))
	return OK


## Total draws across every stream — AC-01's "no RNG call outside rng_match"
## becomes `draws_outside(["match_1"]) == 0`.
func draws_outside(allowed: Array) -> int:
	var total: int = 0
	for stream_name: String in _streams:
		if not allowed.has(stream_name):
			total += (_streams[stream_name] as TestRngStream).draws
	return total
