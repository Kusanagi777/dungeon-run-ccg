## `SfxPlayer` (ui-code rule 5; interaction-patterns Sound Standards). No audio ships yet,
## so a missing file is the normal case. `tests/fixtures/run_ui/sfx/ping.tres` stands in
## for an asset; a `.tres` loads with no import step.
extends GdUnitTestSuite

const SFX_ROOT: String = "res://tests/fixtures/run_ui/sfx/"


func _player(cfg: Dictionary) -> SfxPlayer:
	var player: SfxPlayer = auto_free(SfxPlayer.new())
	add_child(player)
	player.configure(cfg)
	return player


func _stream() -> AudioStreamGenerator:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.buffer_length = 1.0
	return stream


func _voices(player: SfxPlayer) -> Array:
	return player._voices


func test_a_missing_file_is_a_silent_no_op() -> void:
	# Arrange
	var player: SfxPlayer = _player({"root": "res://assets/audio/sfx/", "extensions": ["ogg", "wav"], "voices": 2, "bus": "SFX"})

	# Act
	player.play(&"ui_select")
	player.play_music(&"music.match_ambient")

	# Assert
	for voice: AudioStreamPlayer in _voices(player):
		assert_object(voice.stream).is_null()
		assert_bool(voice.playing).is_false()
	assert_object(player._music.stream).is_null()


func test_a_missing_file_is_looked_up_once() -> void:
	var player: SfxPlayer = _player({"root": "res://assets/audio/sfx/", "extensions": ["ogg"]})
	player.play(&"ui_select")
	assert_bool(player._streams.has(&"ui_select")).is_true()
	assert_object(player._streams[&"ui_select"]).is_null()


func test_an_unconfigured_player_does_nothing() -> void:
	var player: SfxPlayer = auto_free(SfxPlayer.new())
	add_child(player)
	player.play(&"ui_select")
	player.play_music(&"music.match_ambient")
	assert_array(player.get_children()).is_empty()


func test_an_empty_config_leaves_every_call_a_no_op() -> void:
	var player: SfxPlayer = _player({})
	player.play(&"ui_select")
	player.play_music(&"music.match_ambient")
	assert_object(_voices(player)[0].stream).is_null()


func test_configure_builds_the_voices_on_their_buses() -> void:
	var player: SfxPlayer = _player({"voices": 3, "bus": "SFX", "music_bus": "Music"})
	assert_int(_voices(player).size()).is_equal(3)
	for voice: AudioStreamPlayer in _voices(player):
		assert_str(String(voice.bus)).is_equal("SFX")
	assert_str(String(player._music.bus)).is_equal("Music")


func test_an_event_with_a_row_plays_the_file_of_that_row() -> void:
	var player: SfxPlayer = _player({"root": SFX_ROOT, "extensions": ["ogg", "tres"], "voices": 1, "events": {"sfx.ui.ping": "ping"}})
	player.play(&"sfx.ui.ping")
	assert_object(_voices(player)[0].stream).is_not_null()


func test_an_event_with_no_row_uses_its_own_id_as_the_stem() -> void:
	var player: SfxPlayer = _player({"root": SFX_ROOT, "extensions": ["tres"], "voices": 1})
	player.play(&"ping")
	assert_object(_voices(player)[0].stream).is_not_null()


func test_the_extensions_are_tried_in_order() -> void:
	var player: SfxPlayer = _player({"root": SFX_ROOT, "extensions": ["json", "tres"], "voices": 1})
	player.play(&"ping")
	assert_object(_voices(player)[0].stream).is_not_null()


func test_overlapping_sounds_take_separate_voices() -> void:
	# Arrange
	var player: SfxPlayer = _player({"voices": 2})
	player._streams[&"a"] = _stream()
	player._streams[&"b"] = _stream()

	# Act
	player.play(&"a")
	player.play(&"b")

	# Assert
	assert_object(_voices(player)[0].stream).is_same(player._streams[&"a"])
	assert_object(_voices(player)[1].stream).is_same(player._streams[&"b"])


func test_a_free_voice_is_taken_before_a_busy_one_is_cut() -> void:
	# Arrange: three voices busy, then the middle one ends
	var player: SfxPlayer = _player({"voices": 3})
	for event: StringName in [&"a", &"b", &"c", &"d"]:
		player._streams[event] = _stream()
	player.play(&"a")
	player.play(&"b")
	player.play(&"c")
	_voices(player)[1].stop()

	# Act
	player.play(&"d")

	# Assert: `a` still sounds, `d` is on the free voice
	assert_object(_voices(player)[0].stream).is_same(player._streams[&"a"])
	assert_object(_voices(player)[1].stream).is_same(player._streams[&"d"])


func test_the_oldest_voice_is_cut_when_none_is_free() -> void:
	var player: SfxPlayer = _player({"voices": 2})
	for event: StringName in [&"a", &"b", &"c"]:
		player._streams[event] = _stream()
	player.play(&"a")
	player.play(&"b")
	player.play(&"c")
	assert_object(_voices(player)[0].stream).is_same(player._streams[&"c"])
	assert_object(_voices(player)[1].stream).is_same(player._streams[&"b"])


func test_music_already_playing_is_not_restarted() -> void:
	var player: SfxPlayer = _player({"voices": 1})
	var stream: AudioStreamGenerator = _stream()
	player._streams[&"music.match_ambient"] = stream
	player.play_music(&"music.match_ambient")
	var position_marker: AudioStream = player._music.stream
	player.play_music(&"music.match_ambient")
	assert_object(player._music.stream).is_same(position_marker)
	assert_bool(player._music.playing).is_true()
