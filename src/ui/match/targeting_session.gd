## The one session object of targeting.md §5.3: what a source may do, derived only from
## its `legal_commands()` entries (§6), plus the order `Tab` walks (§7.1). A plain
## Dictionary, so a test can read it and [InputRouter] can hand it to the view as it is:
## `{source{kind, id}, entered_by, phase, entries, legal, positions, targets, stops, gap,
## hovered, pos, lit, snap, dim_zone, null_allowed, position, chip_rect, ghost_rect}`.
## `position` is the gap a Phase P chose, and the two rects are the view's, written on
## the phase's opening.
##
## A minion with a Battlecry target opens in Phase P; [method narrow] then keeps only the
## entries at the chosen gap, and Phase T opens on what they allow (§6, review A5).
## [codeblock]
## var session: Dictionary = TargetingSession.open(source, entries, legal, TargetingSession.ENTERED_KEY, pos, view)
## if TargetingSession.narrows_to_target(session, gap):
##     TargetingSession.narrow(session, gap, view)
## [/codeblock]
class_name TargetingSession
extends RefCounted

## How the session was entered (targeting.md §5.3).
const ENTERED_DRAG: StringName = &"drag"
const ENTERED_POINTER: StringName = &"pointer"
const ENTERED_KEY: StringName = &"key"
## targeting.md §6 phases.
const PHASE_POSITION: StringName = &"P"
const PHASE_TARGET: StringName = &"T"
const PHASE_CAST: StringName = &"C"
const NO_GAP: int = -1
const NO_TARGET: int = -1
## `hovered` on the "No target" chip: the last stop of the cycle (§6 `optional`).
const NO_TARGET_CHIP: int = -2


## A session on [param source]. [param entries] are the source's commands and
## [param legal] the whole snapshot, read once here for re-selection.
static func open(source: Dictionary, entries: Array[Dictionary], legal: Array[Dictionary], entered_by: StringName, pos: Vector2, view: MatchViewState) -> Dictionary:
	var positions: Array[int] = []
	for entry: Dictionary in entries:
		if entry.get("position") != null and not positions.has(int(entry.position)):
			positions.append(int(entry.position))
	positions.sort()
	var session: Dictionary = {
		"source": source, "entered_by": entered_by, "phase": PHASE_CAST, "entries": entries,
		"legal": legal, "positions": positions, "targets": {}, "stops": [] as Array[int],
		"gap": NO_GAP, "hovered": NO_TARGET, "pos": pos, "lit": false, "snap": false,
		"dim_zone": false, "null_allowed": false, "position": null,
		"chip_rect": Rect2(), "ghost_rect": Rect2(),
	}
	_read_targets(session, view)
	if not positions.is_empty():
		session.phase = PHASE_POSITION
	elif not (session.targets as Dictionary).is_empty():
		session.phase = PHASE_TARGET
	return session


## True when choosing [param position] leaves a target to pick. A Battlecry with no
## legal target there is `(p, null)` alone, and choosing the gap submits it (§6).
static func narrows_to_target(session: Dictionary, position: int) -> bool:
	for entry: Dictionary in session.entries:
		if entry.get("position") != null and int(entry.position) == position and entry.get("target_id") != null:
			return true
	return false


## Phase P → T: keeps the entries at [param position] and re-derives the targets, the
## null entry and the stops from them alone (§6, review A5).
static func narrow(session: Dictionary, position: int, view: MatchViewState) -> void:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in session.entries:
		if entry.get("position") != null and int(entry.position) == position:
			kept.append(entry)
	session.entries = kept
	session.position = position
	session.phase = PHASE_TARGET
	_read_targets(session, view)


static func _read_targets(session: Dictionary, view: MatchViewState) -> void:
	var targets: Dictionary = {}
	var has_null: bool = false
	for entry: Dictionary in session.entries:
		if entry.get("target_id") != null:
			targets[int(entry.target_id)] = true
		else:
			has_null = true
	session.targets = targets
	session.null_allowed = has_null and not targets.is_empty()
	var stops: Array[int] = target_stops(view, targets)
	if session.null_allowed:
		stops.append(NO_TARGET_CHIP)
	session.stops = stops


## True when [param a] and [param b] name the same source.
static func same_source(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("kind", "")) == str(b.get("kind", "")) and int(a.get("id", 0)) == int(b.get("id", 0))


## §7.1 cycle order, legal entries only: enemy row left to right, enemy hero, friendly
## row left to right, friendly hero.
static func target_stops(view: MatchViewState, targets: Dictionary) -> Array[int]:
	var stops: Array[int] = []
	for side_name: StringName in [&"boss", &"player"]:
		var data: Dictionary = view.side(side_name)
		for token: Dictionary in data.board:
			if targets.has(int(token.entity_id)):
				stops.append(int(token.entity_id))
		var hero: Variant = data.hero.entity_id
		if hero != null and targets.has(int(hero)):
			stops.append(int(hero))
	return stops


## The stop [param step] away from [param current] in [param stops], wrapping. A
## current value that is not a stop starts from the first.
static func cycled(stops: Array[int], current: int, step: int) -> int:
	if stops.is_empty():
		return current
	var index: int = stops.find(current)
	if index < 0:
		return stops[0]
	return stops[posmod(index + step, stops.size())]
