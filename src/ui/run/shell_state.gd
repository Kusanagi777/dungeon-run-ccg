## What the shell is showing (ADR-0011 Decision 1; run-ui States and Transitions):
## plain data, mirroring Run Structure's phase, never holding run data. The controller
## writes `base`, `overlays` and `committed`; the shell writes `transitioning`.
## [codeblock]
## var state := ShellState.new()
## state.base = &"boss_intro"
## state.top()   # &"boss_intro", or the top overlay
## [/codeblock]
class_name ShellState
extends RefCounted

## The base screen id (run-ui U2), `&"match"` during the hand-off.
var base: StringName = &""
## The overlay stack, top-most last.
var overlays: Array[StringName] = []
## A base-change transition is running: every intent but `skip` is dropped (U4).
var transitioning: bool = false
## The top screen sent a terminal intent and waits for the swap (U4).
var committed: bool = false


## The screen that takes input: the top overlay, else the base.
func top() -> StringName:
	return overlays[overlays.size() - 1] if not overlays.is_empty() else base
