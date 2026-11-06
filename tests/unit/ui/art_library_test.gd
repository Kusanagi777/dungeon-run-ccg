## Art map resolution: every shipped card, hero and boss reaches a real texture,
## and an unknown id falls through set then type instead of inventing a path.
extends GdUnitTestSuite

const CARD_FILES: Array[String] = [
	"cards_war.json", "cards_decay.json", "cards_knowledge.json", "cards_neutral.json", "cards_boss.json",
]


func test_surfaces_load_at_the_authored_sizes() -> void:
	var art: ArtLibrary = ArtLibrary.load_map()
	var card: Texture2D = art.surface("parchment_card")
	var table: Texture2D = art.surface("table")
	assert_object(card).is_not_null()
	assert_object(table).is_not_null()
	assert_int(card.get_width()).is_equal(300)
	assert_int(card.get_height()).is_equal(420)
	assert_int(table.get_width()).is_equal(1280)
	assert_int(table.get_height()).is_equal(720)


func test_a_known_card_resolves_to_its_stamp_and_an_unknown_one_falls_back() -> void:
	var art: ArtLibrary = ArtLibrary.load_map()
	var axe: Dictionary = art.card_stamp("war_rusted_axe", "weapon", "war")
	assert_str(str(axe.get("key", ""))).is_equal("axe")
	assert_object(axe.get("texture")).is_not_null()
	assert_str(art.stamp_key("no_such_card", "minion", "decay")).is_equal("skull_warm")
	assert_str(art.stamp_key("no_such_card", "spell", "")).is_equal("scroll")
	assert_str(art.stamp_key("", "", "")).is_equal("")
	assert_bool(art.card_stamp("", "", "").is_empty()).is_true()


func test_every_shipped_card_hero_and_boss_has_a_texture() -> void:
	var art: ArtLibrary = ArtLibrary.load_map()
	for file_name: String in CARD_FILES:
		var parsed: Dictionary = JsonText.parse(FileAccess.get_file_as_string("res://assets/data/%s" % file_name))
		assert_bool(parsed.ok).is_true()
		for record: Variant in (parsed.data as Dictionary).records:
			var row: Dictionary = record
			var stamp: Dictionary = art.card_stamp(str(row.id), str(row.type), str(row.set))
			assert_object(stamp.get("texture")).override_failure_message(str(row.id)).is_not_null()
	for record: Variant in _records("heroes.json"):
		var hero: Dictionary = art.portrait("heroes", str(record.id))
		assert_object(hero.get("texture")).override_failure_message(str(record.id)).is_not_null()
	for record: Variant in _records("bosses.json"):
		var boss: Dictionary = art.portrait("bosses", str(record.id))
		assert_object(boss.get("texture")).override_failure_message(str(record.id)).is_not_null()


func test_keyword_glyphs_load_and_a_missing_one_drops_the_row() -> void:
	var art: ArtLibrary = ArtLibrary.load_map()
	assert_object(art.glyph_texture("taunt")).is_not_null()
	assert_object(art.glyph_texture("attack")).is_not_null()
	assert_object(art.glyph_texture("not_a_glyph")).is_null()
	var names: PackedStringArray = ["taunt", "not_a_glyph"]
	assert_int(art.glyph_row(names).size()).is_equal(0)
	var known: PackedStringArray = ["taunt", "divine_shield"]
	assert_int(art.glyph_row(known).size()).is_equal(2)


func test_every_mapped_path_loads() -> void:
	var art: ArtLibrary = ArtLibrary.load_map()
	for path: String in art.mapped_paths():
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()


func _records(file_name: String) -> Array:
	var parsed: Dictionary = JsonText.parse(FileAccess.get_file_as_string("res://assets/data/%s" % file_name))
	return (parsed.data as Dictionary).records
