## RNG service test double for RNG & Event Log rules 2, 3 and 10.
##
## This double **is** the production [RngService] (`extends RngService`,
## ADR-0003 Migration Plan step 2: the `TODO(E1)` swap is a type change, not a
## rename): `stream(name)` is the production memoised, rule-3-checked,
## F2-seeded `stream()`, so two services built with the same seed hand out
## identical sequences (match-rules AC-01, rng-event-log AC "two services
## created with run_seed = 42"). What the double adds:
##   - defaults `(TestConstants.DEFAULT_TEST_SEED, "test")`, so a test may
##     write `TestRngService.new()`;
##   - streams are `TestRngStream`s (seeded mode — the production generator),
##     so `calls`, `count_calls` and `restore` work on every served stream;
##   - `install(stream)` registers a scripted, constant or recording stream
##     under its own name before the code under test asks for it;
##   - `snapshot()` / `restore()` per rule 10 / F5 until the production ones
##     land (rng-event-log story 003), and `draws_outside([...])`.
class_name TestRngService
extends RngService


func _init(seed_value: int = TestConstants.DEFAULT_TEST_SEED, version: String = "test") -> void:
	super(seed_value, version)


## Rule 2: the production memoised stream for `stream_name`, as the
## `TestRngStream` it was built as (or the one [method install] registered).
func stream(stream_name: String) -> TestRngStream:
	return super(stream_name)


## Register a prepared stream (scripted, constant or recording) under its own
## name so `stream(name)` returns it. Replaces any memoised stream of that name.
func install(prepared: TestRngStream) -> TestRngStream:
	_streams[prepared.name] = prepared
	return prepared


## Rule 10: `{run_seed, data_version, streams: {name: draws}}`, JSON-only.
func snapshot() -> Dictionary:
	var positions: Dictionary = {}
	for stream_name: String in _streams:
		positions[stream_name] = (_streams[stream_name] as RngStream).draws
	return {"run_seed": run_seed, "data_version": data_version, "streams": positions}


## Rule 10 / F5: rebuild every stream named in `snap` at its recorded
## position. Returns an error when `data_version` differs (rng-event-log
## Edge Cases "saved run with a different data_version") and creates nothing.
func restore(snap: Dictionary) -> Error:
	if str(snap.get("data_version", "")) != data_version:
		return ERR_INVALID_DATA
	# The production fields are read-only; the double rewrites the backing one.
	_run_seed = int(snap.get("run_seed", run_seed))
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
			total += (_streams[stream_name] as RngStream).draws
	return total


## Streams this service builds are `TestRngStream`s in seeded mode, seeded by
## F2 exactly as production (the production construction seam).
func _make_stream(stream_name: String, stream_seed: int) -> RngStream:
	return TestRngStream.seeded(stream_name, stream_seed)
