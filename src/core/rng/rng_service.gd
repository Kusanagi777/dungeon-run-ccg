## The run's seeded randomness service (rng-event-log rules 1-3, 6; F1-F3;
## ADR-0003 Decision 1-2, 4).
##
## One injected `RefCounted` per run, created with `(run_seed, data_version)`
## by `RunMachine` / `MatchDriver` on the rules side and by tests directly with
## a literal seed — never through `Boot`, a static or an autoload. Every rules
## module receives a named [RngStream] from [method stream] (DD-T03); there is
## no global seeded RNG (TD-007).
##
## [method stream] takes root names only (rule 3: a `/` name is refused, `null`;
## any other bad name is a programmer bug: logged, still served), creates the
## stream on first use with the F2 seed and returns the same object
## thereafter, position intact. Forks (`stream.fork(label)`, rule 5 / F3) are
## memoised on their parent stream and are the only source of `/` names.
## [codeblock]
## var rng: RngService = RngService.new(run_seed, db.data_version())
## var deck_rng: RngStream = rng.stream("match_3")   # F2-seeded, memoised
## deck_rng.shuffle(deck)
## var sim: RngStream = rng.stream("ai_3").fork("sim_1")   # "ai_3/sim_1", F3
## RngService.to_hex_u64(run_seed)   # "000000000000002A" — the persisted form
## [/codeblock]
##
## The static derivations are the project-wide arithmetic for every 64-bit
## seed and hash: unsigned 64-bit modulo 2^64 computed in GDScript's signed
## `int`, constants written as their signed equivalents, `>>>` emulated as
## `(x >> n) & ((1 << (64 - n)) - 1)`. Every persisted 64-bit value crosses
## JSON as 16 uppercase hex digits ([method to_hex_u64] / [method parse_hex_u64];
## ADR-0004 inherits the rule) because JSON numbers are doubles, exact only to
## 2^53 (probe E).
##
## Save and resume (rule 10, F5; story 003): [method snapshot] records each
## stream's `draws` — forks under their full `"<parent>/<label>"` name plus the
## parent position each fork was taken at — and [method restore] rebuilds them
## by reseed-and-discard, forks through `stream(parent).fork(label)`, never by
## persisting `RandomNumberGenerator.state`. A snapshot is refused while a
## command is open ([method begin_command] / [method end_command]); the
## persisted form ([method snapshot_to_json_dict]) carries `run_seed_hex`.
## [codeblock]
## var save: Dictionary = rng.snapshot_to_json_dict()  # between commands only
## var snap: Dictionary = RngService.snapshot_from_json_dict(loaded)
## var resumed: RngService = RngService.new(snap.run_seed, db.data_version())
## if resumed.restore(snap) != OK: pass  # data_version changed: run abandoned
## [/codeblock]
##
## NOT SOURCEABLE: signed-int64 wraparound of the F2/F3 constants has no page
## in `docs/engine-reference/godot/`; it is pinned on the installed engine by
## the GDD example values in `tests/unit/rng_event_log/rng_service_test.gd`
## (probe D7). Single-thread-only: a worker thread uses its own fork or a
## cloned engine's streams, never this service (ADR-0006/0008).
class_name RngService
extends RefCounted

## rng-event-log rule 3 stream-name pattern: every stream's full name, a root
## name plus any `/<label>` fork path (`"ai_1/sim_3"`).
const STREAM_NAME_PATTERN: String = "^[a-z]+(_[0-9]+)?(/[a-z0-9_]+)*$"
## rng-event-log rule 3: the names [method stream] accepts — root names only
## (`run`, `match_3`, `draft_2`, `ai_1`). A `/` name comes only from
## `RngStream.fork()`: `stream("ai_1/x")` and `stream("ai_1").fork("x")` would
## share a name under different seeds (F2 vs F3), so the first is refused
## (code review 2026-11-03; ADR-0003 erratum).
const ROOT_STREAM_NAME_PATTERN: String = "^[a-z]+(_[0-9]+)?$"
## F1: `entropy_u64` builds a 64-bit seed from two 32-bit words.
const SEED_WORD_BITS: int = 32
## rng-event-log F2: FNV-1a 64 offset basis 0xCBF29CE484222325 as signed int64.
const FNV_OFFSET_BASIS: int = -3750763034362895579
## rng-event-log F2: FNV-1a 64 prime 0x00000100000001B3.
const FNV_PRIME: int = 1099511628211
## rng-event-log F2: SplitMix64 multiplier 0xBF58476D1CE4E5B9 as signed int64.
const MIX_MULT_A: int = -4658895280553007687
## rng-event-log F2: SplitMix64 multiplier 0x94D049BB133111EB as signed int64.
const MIX_MULT_B: int = -7723592293110705685
## rng-event-log F1: a 16-hex-digit seed field, optional lowercase `0x`.
const _HEX_SEED_PATTERN: String = "^(0x)?[0-9A-Fa-f]{16}$"
## rng-event-log F1: a decimal seed field of 1-19 digits, optional `-`.
const _DECIMAL_SEED_PATTERN: String = "^-?[0-9]{1,19}$"
const _HEX_DIGITS: String = "0123456789ABCDEF"

## The F1 / rule 3 patterns, compiled once for every service.
static var _name_regex: RegEx = RegEx.create_from_string(STREAM_NAME_PATTERN)
static var _root_name_regex: RegEx = RegEx.create_from_string(ROOT_STREAM_NAME_PATTERN)
static var _hex_seed_regex: RegEx = RegEx.create_from_string(_HEX_SEED_PATTERN)
static var _decimal_seed_regex: RegEx = RegEx.create_from_string(_DECIMAL_SEED_PATTERN)

## The run's single 64-bit seed (rule 1), stored signed. Read-only: set at
## construction; a write is logged and ignored.
## Example: `RngService.new(42, "v").run_seed == 42`.
var run_seed: int:
	get:
		return _run_seed
	set(_value):
		push_error("RngService.run_seed is read-only; set at construction")
## Card Database `data_version` the service was created under (rule 10).
## Read-only like [member run_seed].
## Example: `RngService.new(42, db.data_version()).data_version`.
var data_version: String:
	get:
		return _data_version
	set(_value):
		push_error("RngService.data_version is read-only; set at construction")

var _run_seed: int = 0
var _data_version: String = ""
var _streams: Dictionary = {}
## Open [method begin_command] calls not yet matched by [method end_command].
var _open_commands: int = 0


## A service for `seed_value` under `version`. Creates no stream and takes no
## draw (rule 8). Example: `var rng: RngService = RngService.new(42, "test")`.
func _init(seed_value: int, version: String) -> void:
	_run_seed = seed_value
	_data_version = version


## Rule 2: the memoised stream `stream_name`, created on first use seeded by
## `stream_seed_for(run_seed, stream_name)` (F2); later calls return the same
## object with its draw position intact. Root names only
## ([constant ROOT_STREAM_NAME_PATTERN]): a name holding `/` is a fork path,
## reachable only through `stream(root).fork(label)`, and is refused like
## `fork("a/b")` — asserts (debug) or logs (release), returns `null`, creates
## no stream. Any other name outside the pattern is a programmer bug:
## `push_error`, then served anyway (ADR-0003 Decision 2).
## Example: `rng.stream("match_3").randi_range(1, 6)`.
func stream(stream_name: String) -> RngStream:
	if stream_name.contains("/"):
		_reject("RngService.stream: \"%s\" is a fork path; stream() takes root names only, use stream(root).fork(label)" % stream_name.c_escape())
		return null
	if not _whole_match(_root_name_regex, stream_name):
		push_error("RngService.stream: \"%s\" violates the rule 3 name pattern" % stream_name.c_escape())
	if not _streams.has(stream_name):
		_streams[stream_name] = _make_stream(stream_name, stream_seed_for(run_seed, stream_name))
	return _streams[stream_name]


## True when `stream_name` has been requested from this service.
## Example: `rng.has_stream("draft_2")`.
func has_stream(stream_name: String) -> bool:
	return _streams.has(stream_name)


## Opens a command (rule 8): from here until the matching [method end_command]
## a draw sequence is in progress and [method snapshot] is refused. Commands
## nest; the guard holds until the outermost `end_command()`. Called by
## `MatchDriver` and `RunMachine` around command processing.
## Example: `rng.begin_command(); engine.apply(cmd); rng.end_command()`.
func begin_command() -> void:
	_open_commands += 1


## Closes the innermost open command. Without an open command it is a caller
## bug: `push_error`, and the guard stays balanced (nothing is closed).
## Example: see [method begin_command].
func end_command() -> void:
	if _open_commands == 0:
		push_error("RngService.end_command: no command is open")
		return
	_open_commands -= 1


## Rule 10: `{run_seed: int, data_version: String, streams: {name: draws},
## fork_points: {fork_name: parent_draws_before_fork}}` — every stream this
## service has served, forks included under their full `"<parent>/<label>"`
## name (recursively). Every value is JSON-safe except `run_seed`, which stays
## an `int` in memory (persist with [method snapshot_to_json_dict]). Refused
## between [method begin_command] and [method end_command]: `push_error` and
## `{}` (Edge Cases "mid-command"). Takes no draw.
## Example: `rng.snapshot().streams["match_3"] == 37`.
func snapshot() -> Dictionary:
	if _open_commands > 0:
		push_error("RngService.snapshot: refused while a command is open (begin_command() without end_command())")
		return {}
	var positions: Dictionary = {}
	var fork_points: Dictionary = {}
	for stream_name: String in _streams:
		_record_positions(_streams[stream_name], positions, fork_points)
	return {"run_seed": run_seed, "data_version": data_version, "streams": positions, "fork_points": fork_points}


## Rule 10 / F5: puts every stream back at the position `snap` records.
## Returns `ERR_INVALID_DATA` having changed nothing when `snap.data_version`
## differs from this service's (Edge Cases "saved run with a different
## data_version" — Run Structure ends the run `abandoned`), and, with a
## `push_error`, when `snap.run_seed` is not this service's or an entry is
## malformed (a non-`int` or negative `draws`, a fork whose parent is absent,
## whose name breaks rule 3, or whose fork point is missing, outside the
## parent's draws or shared with a sibling). Otherwise each root is restored in
## place (`stream(name)`; held references stay valid), its forks re-taken
## through `fork(label)` at their recorded parent positions so their F3 seeds
## match, every cached fork the snapshot does not hold is dropped, and streams
## the snapshot lacks are removed. Returns `OK`.
## Example: `RngService.new(snap.run_seed, "1.1").restore(snap) == ERR_INVALID_DATA` for a `"1.0"` snap.
func restore(snap: Dictionary) -> Error:
	if snap.get("data_version") != data_version:
		return ERR_INVALID_DATA
	var problem: String = _snapshot_problem(snap)
	if not problem.is_empty():
		push_error("RngService.restore: %s" % problem)
		return ERR_INVALID_DATA
	var positions: Dictionary = snap.streams
	for stream_name: String in _streams.keys():
		if not positions.has(stream_name):
			_streams.erase(stream_name)
	for stream_name: String in positions:
		if not stream_name.contains("/"):
			_rebuild(stream(stream_name), positions, snap.get("fork_points", {}))
	return OK


## The persisted form of [method snapshot] (rule 10; ADR-0003 Decision 4,
## ADR-0004): `run_seed` replaced by `run_seed_hex`, 16 uppercase hex digits,
## because a JSON number is exact only to 2^53 (probe E). `{}` (and the
## snapshot's error) while a command is open.
## Example: `RngService.new(42, "v").snapshot_to_json_dict().run_seed_hex == "000000000000002A"`.
func snapshot_to_json_dict() -> Dictionary:
	var snap: Dictionary = snapshot()
	if snap.is_empty():
		return {}
	return {
		"run_seed_hex": to_hex_u64(snap.run_seed),
		"data_version": snap.data_version,
		"streams": snap.streams,
		"fork_points": snap.fork_points,
	}


## The inverse of [method snapshot_to_json_dict] for a parsed JSON Dictionary:
## `run_seed_hex` → `run_seed` ([method parse_hex_u64]) and every integral
## float in `streams` / `fork_points` back to `int` (every JSON number parses
## as a float). A missing or malformed `run_seed_hex` (not exactly 16 hex
## digits) or a `streams` / `fork_points` that is not a Dictionary is a data
## fault: `push_error` and `{}` (which [method restore] rejects). Other bad
## values are passed through for [method restore] to reject. The caller parses
## the text (the profile loader, ADR-0004); this takes the parsed Dictionary.
## Example: `RngService.snapshot_from_json_dict(parsed_save.rng_snapshot).run_seed`.
static func snapshot_from_json_dict(d: Dictionary) -> Dictionary:
	var hex: Variant = d.get("run_seed_hex")
	if typeof(hex) != TYPE_STRING or hex.begins_with("0x") or not _whole_match(_hex_seed_regex, hex):
		push_error("RngService.snapshot_from_json_dict: run_seed_hex %s is not 16 hex digits" % str(hex).c_escape())
		return {}
	var streams: Variant = d.get("streams")
	var fork_points: Variant = d.get("fork_points", {})
	if typeof(streams) != TYPE_DICTIONARY or typeof(fork_points) != TYPE_DICTIONARY:
		push_error("RngService.snapshot_from_json_dict: streams and fork_points must be objects")
		return {}
	return {
		"run_seed": parse_hex_u64(hex),
		"data_version": d.get("data_version"),
		"streams": _whole_floats_to_int(streams),
		"fork_points": _whole_floats_to_int(fork_points),
	}


## Builds the stream [method stream] memoises. The one construction seam: a
## test double (`TestRngService`) returns its own [RngStream] subclass here.
func _make_stream(stream_name: String, stream_seed: int) -> RngStream:
	return RngStream.new(stream_name, stream_seed)


# --- F1 / F2 / F3 (static, pure) ------------------------------------------------

## F1's `entropy_u64()`: the one permitted global RNG call (ADR-0003 Decision 10(b)),
## the default of `RunMachine.entropy`. It lives here because gate G6 and rng-event-log
## rule 7 keep the rules tree free of global RNG, and `src/core/rng/` is outside both.
static func entropy_u64() -> int:
	return (randi() << SEED_WORD_BITS) | randi()


## F1: the run seed from the hero-select seed field. `input` is trimmed; then
## empty → `entropy.call()` (exactly once, the only branch that calls it —
## Run Structure's run-creation command hands in the one permitted
## global-entropy call); `^(0x)?[0-9A-Fa-f]{16}$` → [method parse_hex_u64];
## `^-?[0-9]{1,19}$` → the decimal value mod 2^64 (a negative decimal becomes
## its two's-complement pattern, a 19-digit value above 2^63 − 1 wraps);
## otherwise `fnv1a64(utf8(input))`.
## Example: `RngService.run_seed_from_input("deckdelve", entropy)` → `0x48A10CC0B2ED54EC`.
static func run_seed_from_input(input: String, entropy: Callable) -> int:
	var trimmed: String = input.strip_edges()
	if trimmed.is_empty():
		return int(entropy.call())
	if _whole_match(_hex_seed_regex, trimmed):
		return parse_hex_u64(trimmed.trim_prefix("0x"))
	if _whole_match(_decimal_seed_regex, trimmed):
		return _parse_decimal_mod_2_64(trimmed)
	return fnv1a64(trimmed.to_utf8_buffer())


## F2: `mix64(fnv1a64(le_bytes8(run_seed) ++ utf8(stream_name)))`.
## Example: `RngService.to_hex_u64(RngService.stream_seed_for(42, "run")) == "60FB31FFA0FECE9A"`.
static func stream_seed_for(seed_value: int, stream_name: String) -> int:
	var bytes: PackedByteArray = le_bytes8(seed_value)
	bytes.append_array(stream_name.to_utf8_buffer())
	return mix64(fnv1a64(bytes))


## F3: `mix64(fnv1a64(le_bytes8(parent_draw) ++ utf8(parent_name + "/" + label)))`,
## where `parent_draw` is the one parent `randi32()` the fork consumed.
## Example: `RngService.fork_seed(draw, "ai_1", "sim_3")`.
static func fork_seed(parent_draw: int, parent_name: String, label: String) -> int:
	var bytes: PackedByteArray = le_bytes8(parent_draw)
	bytes.append_array(("%s/%s" % [parent_name, label]).to_utf8_buffer())
	return mix64(fnv1a64(bytes))


## FNV-1a 64 over `bytes`, int64 wraparound arithmetic (F2 `fnv1a64`).
## Example: `RngService.fnv1a64("deckdelve".to_utf8_buffer())`.
static func fnv1a64(bytes: PackedByteArray) -> int:
	var h: int = FNV_OFFSET_BASIS
	for b: int in bytes:
		h = (h ^ b) * FNV_PRIME
	return h


## The SplitMix64 finaliser (F2 `mix64`), `>>>` emulated.
## Example: `RngService.mix64(RngService.fnv1a64(bytes))`.
static func mix64(x: int) -> int:
	var z: int = (x ^ ushr64(x, 30)) * MIX_MULT_A
	z = (z ^ ushr64(z, 27)) * MIX_MULT_B
	return z ^ ushr64(z, 31)


## Logical (unsigned) right shift of a signed int64 by `n` in 1..63.
## Example: `RngService.ushr64(-1, 60) == 15`.
static func ushr64(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)


## The 8 little-endian bytes of an int64 (F2 `le_bytes8`).
## Example: `RngService.le_bytes8(42)` → `[42, 0, 0, 0, 0, 0, 0, 0]`.
static func le_bytes8(value: int) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	for i: int in range(8):
		bytes.append((value >> (8 * i)) & 0xFF)
	return bytes


## 16 uppercase hex digits, the unsigned view of `value`'s bits — the display
## form (DD-R09) and the persisted form of every 64-bit value.
## Example: `RngService.to_hex_u64(-1) == "FFFFFFFFFFFFFFFF"`.
static func to_hex_u64(value: int) -> String:
	var out: String = ""
	for i: int in range(15, -1, -1):
		out += _HEX_DIGITS[(value >> (4 * i)) & 0xF]
	return out


## The 64-bit pattern of exactly 16 hex digits (either case), stored signed —
## the inverse of [method to_hex_u64]. Anything else (a prefix, another length,
## a non-hex digit) is a data fault: `push_error` and 0, never an assert.
## Example: `RngService.parse_hex_u64("FFFFFFFFFFFFFFFF") == -1`.
static func parse_hex_u64(hex16: String) -> int:
	# Digits are checked one by one: `String.is_valid_hex_number` also accepts a sign.
	var digits: String = hex16.to_upper()
	var valid: bool = digits.length() == 16
	var value: int = 0
	for ch: String in digits:
		var nibble: int = _HEX_DIGITS.find(ch)
		valid = valid and nibble >= 0
		value = (value << 4) | maxi(nibble, 0)
	if not valid:
		push_error("RngService.parse_hex_u64: \"%s\" is not 16 hex digits" % hex16.c_escape())
		return 0
	return value


## True when `stream_name` matches the whole rule 3 pattern.
## Example: `RngService.is_valid_stream_name("ai_1/sim_3")` → true.
static func is_valid_stream_name(stream_name: String) -> bool:
	return _whole_match(_name_regex, stream_name)


# --- snapshot / restore internals ----------------------------------------------

# Records `stream` and, recursively, its cached forks into the two maps.
func _record_positions(stream: RngStream, positions: Dictionary, fork_points: Dictionary) -> void:
	positions[stream.name] = stream.draws
	for child: RngStream in stream._forks.values():
		fork_points[child.name] = child.forked_at
		_record_positions(child, positions, fork_points)


# F5 for `stream` and its snapshotted forks: reseed (dropping every cached
# fork), replay each fork call at its recorded parent position in position
# order, then discard up to the stream's own `draws`.
func _rebuild(stream: RngStream, positions: Dictionary, fork_points: Dictionary) -> void:
	stream.restore(0)
	var prefix: String = stream.name + "/"
	var children: Array[String] = []
	for stream_name: String in positions:
		if stream_name.begins_with(prefix) and not stream_name.substr(prefix.length()).contains("/"):
			children.append(stream_name)
	children.sort_custom(func(a: String, b: String) -> bool: return fork_points[a] < fork_points[b])
	for child_name: String in children:
		stream._skip_to(fork_points[child_name])
		_rebuild(stream.fork(child_name.substr(prefix.length())), positions, fork_points)
	stream._skip_to(positions[stream.name])


# Why `snap` (data_version already matched) cannot be restored, or "".
func _snapshot_problem(snap: Dictionary) -> String:
	var seed_value: Variant = snap.get("run_seed")
	if typeof(seed_value) != TYPE_INT or seed_value != run_seed:
		var shown: String = to_hex_u64(seed_value) if typeof(seed_value) == TYPE_INT else str(seed_value)
		return "snapshot run_seed %s is not this service's %s" % [shown, to_hex_u64(run_seed)]
	var positions: Variant = snap.get("streams")
	var fork_points: Variant = snap.get("fork_points", {})
	if typeof(positions) != TYPE_DICTIONARY or typeof(fork_points) != TYPE_DICTIONARY:
		return "streams and fork_points must be Dictionaries"
	var taken: Dictionary = {}
	for key: Variant in positions:
		var draws: Variant = positions[key]
		if typeof(key) != TYPE_STRING or typeof(draws) != TYPE_INT or draws < 0:
			return "stream %s has bad draws %s" % [str(key), str(draws)]
		var stream_name: String = key
		if not stream_name.contains("/"):
			continue
		var parent: String = stream_name.substr(0, stream_name.rfind("/"))
		if not is_valid_stream_name(stream_name) or not positions.has(parent):
			return "fork %s has no parent stream or breaks rule 3" % stream_name
		var point: Variant = fork_points.get(stream_name)
		var parent_draws: Variant = positions[parent]
		if typeof(point) != TYPE_INT or point < 0 or typeof(parent_draws) != TYPE_INT or point >= parent_draws:
			return "fork %s has bad fork point %s" % [stream_name, str(point)]
		var slot: String = "%s@%d" % [parent, point]
		if taken.has(slot):
			return "forks %s and %s share fork point %d" % [taken[slot], stream_name, point]
		taken[slot] = stream_name
	for fork_name: Variant in fork_points:
		if not positions.has(fork_name) or not str(fork_name).contains("/"):
			return "fork point %s names no snapshotted fork" % str(fork_name)
	return ""


# A copy of `d` with every whole-number float value as `int` (JSON numbers
# arrive as floats); other values unchanged.
static func _whole_floats_to_int(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in d:
		var value: Variant = d[key]
		if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value):
			value = int(value)
		out[key] = value
	return out


# Caller-bug report, as `RngStream._reject`: asserts in debug builds (the
# assert aborts only this function, so the caller still returns its
# fallback), logs in release.
func _reject(message: String) -> void:
	assert(false, message)
	push_error(message)


# Whole-string match: PCRE's `$` also matches before a trailing newline.
static func _whole_match(regex: RegEx, text: String) -> bool:
	var found: RegExMatch = regex.search(text)
	return found != null and found.get_string() == text


# F1 `parse_i64(input) mod 2^64` for text matching _DECIMAL_SEED_PATTERN:
# int64 multiplication and addition wrap (probe D7), so accumulating the
# digits is already the value mod 2^64; the sign is applied last.
static func _parse_decimal_mod_2_64(text: String) -> int:
	var negative: bool = text.begins_with("-")
	var value: int = 0
	for ch: String in text.trim_prefix("-"):
		value = value * 10 + ch.to_int()
	return -value if negative else value
