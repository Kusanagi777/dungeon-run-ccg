## The audio seam of the match view (match-ui Visual/Audio; ui-code.md: sounds go through
## the audio event system by key). It records the cue ids it is asked for, in debug builds,
## for a test to read, and hands each to [member sink], which [SfxPlayer] fills.
## [codeblock]
## sfx.play(&"sfx.ui.victory")
## assert(sfx.played(&"sfx.ui.victory"))
## [/codeblock]
class_name SfxStub
extends RefCounted

const CUE_VICTORY: StringName = &"sfx.ui.victory"
const CUE_DEFEAT: StringName = &"sfx.ui.defeat"
const CUE_DENY: StringName = &"sfx.ui.deny"
const CUE_OVERLAY: StringName = &"sfx.ui.overlay"
const CUE_CARD_LIFT: StringName = &"sfx.ui.card_lift"
const CUE_END_TURN: StringName = &"sfx.ui.end_turn"
const CUE_IMPACT_LIGHT: StringName = &"sfx.ui.impact_light"
const CUE_IMPACT_HEAVY: StringName = &"sfx.ui.impact_heavy"
const CUE_PLAN_CHANGED: StringName = &"sfx.ui.plan_changed"
const MUSIC_AMBIENT: StringName = &"music.match_ambient"

## Every cue asked for, as `{frame, cue}`, in debug builds.
var log: Array[Dictionary] = []
## `func(cue: StringName)`, what makes the sound; unset, nothing does.
var sink: Callable = Callable()


## Asks for cue [param cue].
func play(cue: StringName) -> void:
	if OS.is_debug_build():
		log.append({"frame": Engine.get_process_frames(), "cue": cue})
	if sink.is_valid():
		sink.call(cue)


## True when [param cue] was asked for this match.
func played(cue: StringName) -> bool:
	for entry: Dictionary in log:
		if entry.cue == cue:
			return true
	return false
