## The one session object of targeting.md §5.3: what a source may do, derived only from
## its `legal_commands()` entries (§6), plus the order `Tab` walks (§7.1). A plain
## Dictionary, so a test can read it and [InputRouter] can hand it to the view as it is:
## `{source{kind, id}, entered_by, phase, entries, legal, positions, targets, stops, gap,
## hovered, pos, lit, snap, dim_zone}`.
## [codeblock]
## var session: Dictionary = TargetingSession.open(source, entries, legal, TargetingSession.ENTERED_KEY, pos)
## var stops: Array[int] = TargetingSession.target_stops(view, session.targets)
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


## A session on [param source]. [param entries] are the source's commands and
## [param legal] the whole snapshot, read once here for re-selection.
static func open(source: Dictionary, entries: Array[Dictionary], legal: Array[Dictionary], entered_by: StringName, pos: Vector2) -> Dictionary:
	var positions: Array[int] = []
	var targets: Dictionary = {}
	for entry: Dictionary in entries:
		if entry.get("position") != null and not positions.has(int(entry.position)):
			positions.append(int(entry.position))
		if entry.get("target_id") != null:
			targets[int(entry.target_id)] = true
	positions.sort()
	var phase: StringName = PHASE_CAST
	if not targets.is_empty():
		phase = PHASE_TARGET
	elif not positions.is_empty():
		phase = PHASE_POSITION
	var stops: Array[int] = []
	return {
		"source": source, "entered_by": entered_by, "phase": phase, "entries": entries,
		"legal": legal, "positions": positions, "targets": targets, "stops": stops,
		"gap": NO_GAP, "hovered": NO_TARGET, "pos": pos, "lit": false, "snap": false,
		"dim_zone": false,
	}


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
