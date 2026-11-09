## The unified effect grammar (2026-11-08): every engine event the view projects
## becomes a step with data the presenters animate, and every keyword or state has
## one badge (icon, letter) shared by the token, the card face and the reading panel.
## Covers the two events the view used to drop (`minion_transformed`, which hid every
## Unmask, and `minion_returned`).
extends GdUnitTestSuite

const PLAYER_HERO_ID: int = 1
const BOSS_HERO_ID: int = 2
const MINION: int = 31
const BOSS_MINION: int = 32
const SHIPPED_MATCH_UI: String = "res://assets/data/match_ui.json"
## Steps that are deliberately silent: the spec gives them no sound (match-ui
## Visual/Audio "stat recolour … none", hud.md "Armour gained … —", rim glow, commit
## beat), or their sound comes from elsewhere (end banner: victory/defeat; reject:
## deny; gap close and attack return belong to a step that already sounded).
const SILENT_KINDS: Array[StringName] = [
	AnimStep.STAT_RECOLOUR, AnimStep.ARMOR_POP, AnimStep.RIM_GLOW, AnimStep.INTENT_COMMIT,
	AnimStep.END_BANNER, AnimStep.REJECT_SHAKE, AnimStep.GAP_CLOSE, AnimStep.ATTACK_RETURN,
	AnimStep.MULLIGAN_FLIP, AnimStep.POWER_RELIGHT, AnimStep.TREASURE_FLARE,
]


func _event(seq: int, type: String, payload: Dictionary, cause_seq: int = 0) -> Dictionary:
	return {"seq": seq, "turn": 1, "type": type, "payload": payload, "cause_seq": cause_seq}


func _view() -> MatchViewState:
	var view := MatchViewState.new(MatchUiTestConfig.body())
	for event: Dictionary in [
		_event(1, "match_started", {"floor": 1, "hero_id": PLAYER_HERO_ID, "boss_id": BOSS_HERO_ID, "player_deck_size": 0, "boss_deck_size": 0}),
		_event(2, "minion_summoned", {"side": "player", "entity_id": MINION, "card_id": "neutral_masq_masked_reveler", "position": 0, "attack": 2, "health": 2, "keywords": []}),
		_event(3, "minion_summoned", {"side": "boss", "entity_id": BOSS_MINION, "card_id": "neutral_masq_borrowed_finery", "position": 0, "attack": 3, "health": 2, "keywords": []}),
	]:
		view.apply(event)
	return view


func _kinds(steps: Array[AnimStep]) -> Array:
	return steps.map(func(s: AnimStep) -> StringName: return s.kind)


func _shipped() -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string(SHIPPED_MATCH_UI)) as Dictionary).config


# --- transform (Unmask) -------------------------------------------------------------

func test_transform_replaces_the_token_in_its_slot_with_the_new_minion() -> void:
	var view: MatchViewState = _view()
	var steps: Array[AnimStep] = view.apply(_event(10, "minion_transformed", {
		"side": "player", "entity_id": 77, "from_card_id": "neutral_masq_masked_reveler",
		"to_card_id": "neutral_masq_reveler_unveiled", "old_entity_id": MINION, "position": 0,
		"attack": 4, "health": 3, "keywords": [],
	}))
	var board: Array = view.side(&"player").board
	assert_int(board.size()).is_equal(1)
	assert_int(int(board[0].entity_id)).is_equal(77)
	assert_str(str(board[0].card_id)).is_equal("neutral_masq_reveler_unveiled")
	assert_array([board[0].attack, board[0].health, board[0].max_health]).is_equal([4, 3, 3])
	assert_array(_kinds(steps)).is_equal([AnimStep.TRANSFORM])
	assert_int(int(steps[0].data.old_entity_id)).is_equal(MINION)


func test_transform_of_a_frozen_minion_shows_a_thawed_true_form() -> void:
	var view: MatchViewState = _view()
	view.apply(_event(9, "frozen", {"entity_id": MINION, "frozen_on_turn": 1}))
	view.apply(_event(10, "minion_transformed", {
		"side": "player", "entity_id": 77, "from_card_id": "a", "to_card_id": "b",
		"old_entity_id": MINION, "position": 0, "attack": 4, "health": 3, "keywords": [],
	}))
	assert_bool(bool(view.side(&"player").board[0].frozen)).is_false()


# --- return to hand --------------------------------------------------------------------

func test_return_moves_the_minion_from_board_to_hand() -> void:
	var view: MatchViewState = _view()
	var steps: Array[AnimStep] = view.apply(_event(10, "minion_returned", {
		"side": "player", "entity_id": MINION, "card_id": "neutral_masq_masked_reveler", "instance_id": 90, "burned": false,
	}))
	assert_array(view.side(&"player").board).is_empty()
	var hand: Array = view.side(&"player").hand
	assert_int(int(hand[0].instance_id)).is_equal(90)
	assert_str(str(hand[0].card_id)).is_equal("neutral_masq_masked_reveler")
	assert_array(_kinds(steps)).is_equal([AnimStep.RETURN, AnimStep.DRAW])
	assert_int(int(steps[1].data.returned_from)).is_equal(MINION)


func test_return_into_a_full_hand_burns_and_adds_no_card() -> void:
	var view: MatchViewState = _view()
	var steps: Array[AnimStep] = view.apply(_event(10, "minion_returned", {
		"side": "player", "entity_id": MINION, "card_id": "neutral_masq_masked_reveler", "instance_id": 90, "burned": true,
	}))
	assert_array(view.side(&"player").hand).is_empty()
	assert_array(_kinds(steps)).is_equal([AnimStep.RETURN, AnimStep.BURN])


func test_a_boss_return_keeps_the_card_hidden_in_its_hand() -> void:
	var view: MatchViewState = _view()
	view.apply(_event(10, "minion_returned", {
		"side": "boss", "entity_id": BOSS_MINION, "card_id": "neutral_masq_borrowed_finery", "instance_id": 91, "burned": false,
	}))
	assert_array(view.side(&"boss").board).is_empty()
	assert_int(int(view.side(&"boss").hand)).is_equal(1)


# --- one treatment per kind of change ---------------------------------------------------

func test_armour_is_its_own_pop_not_a_heal() -> void:
	var view: MatchViewState = _view()
	var steps: Array[AnimStep] = view.apply(_event(10, "armor_gained", {"side": "player", "entity_id": PLAYER_HERO_ID, "amount": 2, "armor": 2}))
	assert_array(_kinds(steps)).is_equal([AnimStep.ARMOR_POP])


func test_status_steps_name_what_was_gained_and_lost() -> void:
	var view: MatchViewState = _view()
	var frozen: Array[AnimStep] = view.apply(_event(10, "frozen", {"entity_id": MINION, "frozen_on_turn": 1}))
	var thawed: Array[AnimStep] = view.apply(_event(11, "thawed", {"entity_id": MINION}))
	assert_array(frozen[0].data.added).is_equal(["frozen"])
	assert_array(thawed[0].data.removed).is_equal(["frozen"])
	var granted: Array[AnimStep] = view.apply(_event(12, "enchantment_applied", {"instance_id": MINION, "keywords_added": ["taunt"]}))
	assert_str(String(granted[0].kind)).is_equal(String(AnimStep.BADGE))
	assert_array(granted[0].data.added).is_equal(["taunt"])


func test_stat_steps_say_whether_it_was_a_buff_or_a_debuff() -> void:
	var view: MatchViewState = _view()
	var buff: Array[AnimStep] = view.apply(_event(10, "enchantment_applied", {"instance_id": MINION, "attack_delta": 2, "health_delta": 0}))
	var removed: Array[AnimStep] = view.apply(_event(11, "enchantment_removed", {"instance_id": MINION, "attack_delta": 2, "health_delta": 0}))
	assert_bool(bool(buff[0].data.up)).is_true()
	assert_bool(bool(removed[0].data.up)).is_false()


func test_only_combat_damage_is_marked_for_the_impact_sound() -> void:
	var view: MatchViewState = _view()
	var spell: Array[AnimStep] = view.apply(_event(10, "damage_dealt", {"source": null, "target": BOSS_MINION, "dealt": 1, "prevented": 0, "health_after": 1}))
	view.apply(_event(11, "attack_declared", {"attacker": MINION, "defender": BOSS_MINION}))
	var combat: Array[AnimStep] = view.apply(_event(12, "damage_dealt", {"source": MINION, "target": BOSS_MINION, "dealt": 1, "prevented": 0, "health_after": 0}, 11))
	assert_bool(bool(spell[0].data.attack)).is_false()
	assert_bool(bool(combat[0].data.attack)).is_true()


func test_a_cast_spell_gets_its_resolving_step() -> void:
	var view: MatchViewState = _view()
	var steps: Array[AnimStep] = view.apply(_event(10, "spell_cast", {"side": "boss", "instance_id": 5, "card_id": "neutral_masq_curtain_call"}))
	var cast: Array = steps.filter(func(s: AnimStep) -> bool: return s.kind == AnimStep.SPELL_CAST)
	assert_int(cast.size()).is_equal(1)
	assert_str(str(cast[0].data.card_id)).is_equal("neutral_masq_curtain_call")


# --- the shipped tables ---------------------------------------------------------------

func test_every_step_kind_has_a_duration_and_a_sound_unless_it_is_silent_by_spec() -> void:
	var config: Dictionary = _shipped()
	var constants: Dictionary = (AnimStep as Script).get_script_constant_map()
	for name: String in constants:
		if not constants[name] is StringName:
			continue
		var kind: StringName = constants[name]
		assert_bool((config.d_base as Dictionary).has(String(kind))).override_failure_message("d_base has no %s" % kind).is_true()
		if not SILENT_KINDS.has(kind):
			assert_bool((config.sfx_steps as Dictionary).has(String(kind))).override_failure_message("sfx_steps has no %s" % kind).is_true()


func test_every_step_sound_resolves_to_an_audio_stem() -> void:
	var events: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/run_ui.json")) as Dictionary).config.sfx.events
	for kind: String in _shipped().sfx_steps:
		assert_bool(events.has(str(_shipped().sfx_steps[kind]))).override_failure_message(kind).is_true()


func test_every_keyword_and_state_has_an_icon_a_letter_and_a_place_in_the_order() -> void:
	var config: Dictionary = _shipped()
	var art: ArtLibrary = ArtLibrary.load_map()
	var names: Array = Array(EffectSchema.KEYWORDS) + ["masked", "frozen", "silenced", "summoning_sick", "attacked"]
	for name: Variant in names:
		assert_object(art.glyph_texture(str(name))).override_failure_message("no icon for %s" % name).is_not_null()
		assert_bool((config.glyphs as Dictionary).has(str(name))).override_failure_message("no letter for %s" % name).is_true()
		assert_bool((config.badges.order as Array).has(str(name))).override_failure_message("%s not in badges.order" % name).is_true()
		assert_bool((config.strings as Dictionary).has("badge." + str(name))).override_failure_message("no name string for %s" % name).is_true()


func test_badge_letters_are_unique_except_a_keyword_and_the_state_it_causes() -> void:
	var glyphs: Dictionary = _shipped().glyphs
	var shared_pairs: Dictionary = {"freeze": "frozen", "silence": "silenced"}
	var seen: Dictionary = {}
	for name: String in _shipped().badges.order:
		var letter: String = str(glyphs[name])
		if seen.has(letter):
			var other: String = seen[letter]
			assert_bool(shared_pairs.get(name) == other or shared_pairs.get(other) == name) \
				.override_failure_message("%s and %s share %s" % [name, other, letter]).is_true()
		seen[letter] = name


func test_play_time_keywords_stay_off_the_board_row() -> void:
	var board: Array = _shipped().badges.board
	for name: String in ["battlecry", "discover", "freeze", "silence"]:
		assert_bool(board.has(name)).is_false()
	for name: String in ["taunt", "deathrattle", "masked", "frozen", "silenced"]:
		assert_bool(board.has(name)).is_true()
