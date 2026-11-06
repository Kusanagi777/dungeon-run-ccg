## The audio event seam of v1 (ui-code rule 5; interaction-patterns Audio; run-ui
## Visual/Audio): a screen or presenter raises an event by key, never a file. The
## `config("run_ui").sfx` body names the folder, the buses and each event's file stem; an
## event with no row uses its own id as the stem.
##
## No audio ships yet, so a missing file is the normal case: it is a silent no-op, looked
## up once, and never a warning. Dropping `<root><stem>.ogg` in is all an asset needs.
## [codeblock]
## var sfx := SfxPlayer.new()
## add_child(sfx)
## sfx.configure(db.config("run_ui").sfx)
## sfx.play(&"sfx.ui.deny")
## sfx.play_music(&"music.match_ambient")
## [/codeblock]
class_name SfxPlayer
extends Node

const DEFAULT_VOICES: int = 1

var _root: String = ""
var _extensions: Array = []
var _events: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music: AudioStreamPlayer = null
# Event id to its stream, or null once a lookup found no file.
var _streams: Dictionary = {}


## Builds the voices from [param cfg] (`{root, extensions, voices, bus, music_bus,
## events}`). An empty [param cfg] leaves every call a no-op.
func configure(cfg: Dictionary) -> void:
	_root = str(cfg.get("root", ""))
	_extensions = cfg.get("extensions", [])
	_events = cfg.get("events", {})
	for i: int in int(cfg.get("voices", DEFAULT_VOICES)):
		var voice := AudioStreamPlayer.new()
		voice.bus = StringName(str(cfg.get("bus", "Master")))
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.bus = StringName(str(cfg.get("music_bus", "Master")))
	add_child(_music)


## Raises [param event]: plays its file on a free voice, or the oldest when none is free.
func play(event: StringName) -> void:
	var stream: AudioStream = _stream(event)
	if stream == null or _voices.is_empty():
		return
	var voice: AudioStreamPlayer = _voices[_free_voice()]
	voice.stream = stream
	voice.play()


# The next voice not sounding from the oldest on, else the oldest; moves the turn past it.
func _free_voice() -> int:
	var chosen: int = _next_voice
	for i: int in _voices.size():
		var index: int = (_next_voice + i) % _voices.size()
		if not _voices[index].playing:
			chosen = index
			break
	_next_voice = (chosen + 1) % _voices.size()
	return chosen


## Starts the loop of [param event] on the music bus, unless it is playing already.
func play_music(event: StringName) -> void:
	var stream: AudioStream = _stream(event)
	if stream == null or _music == null or (_music.playing and _music.stream == stream):
		return
	_music.stream = stream
	_music.play()


func _stream(event: StringName) -> AudioStream:
	if _streams.has(event):
		return _streams[event]
	var found: AudioStream = null
	var stem: String = str(_events.get(String(event), String(event)))
	for extension: Variant in _extensions:
		var path: String = "%s%s.%s" % [_root, stem, str(extension)]
		if ResourceLoader.exists(path):
			found = load(path) as AudioStream
			break
	_streams[event] = found
	return found
