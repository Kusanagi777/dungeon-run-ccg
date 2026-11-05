## The minimal audio seam of the match view (match-ui Visual/Audio; ui-code.md: sounds
## go through the audio event system by key). No audio ships yet, so this records the
## cue ids it is asked for, in debug builds, and a test reads them.
## [codeblock]
## sfx.play(&"sfx.ui.victory")
## assert(sfx.played(&"sfx.ui.victory"))
## [/codeblock]
class_name SfxStub
extends RefCounted

const CUE_VICTORY: StringName = &"sfx.ui.victory"
const CUE_DEFEAT: StringName = &"sfx.ui.defeat"

## Every cue asked for, as `{frame, cue}`, in debug builds.
var log: Array[Dictionary] = []


## Asks for cue [param cue].
func play(cue: StringName) -> void:
	if OS.is_debug_build():
		log.append({"frame": Engine.get_process_frames(), "cue": cue})


## True when [param cue] was asked for this match.
func played(cue: StringName) -> bool:
	for entry: Dictionary in log:
		if entry.cue == cue:
			return true
	return false
