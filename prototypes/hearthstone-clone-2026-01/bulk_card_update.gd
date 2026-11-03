@tool
extends EditorScript

func _run():
	var dir = DirAccess.open("res://data/cards/")
	_scan_directory(dir, "res://data/cards/")

func _scan_directory(dir: DirAccess, path: String):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			var subdir = DirAccess.open(full_path)
			_scan_directory(subdir, full_path + "/")
		elif file_name.ends_with(".tres"):
			_check_card(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _check_card(path: String):
	var card = load(path) as CardData
	if card == null:
		return
	
	var desc = card.description.to_lower()
	var needed_tags: Array[String] = []
	
	# Check for keywords in description
	if "shielded" in desc and not card.has_keyword("Shielded"):
		needed_tags.append("Shielded")
	if "taunt" in desc and not card.has_keyword("Taunt"):
		needed_tags.append("Taunt")
	if "charge" in desc and not card.has_keyword("Charge"):
		needed_tags.append("Charge")
	if "rush" in desc and not card.has_keyword("Rush"):
		needed_tags.append("Rush")
	if "aggressive" in desc and not card.has_keyword("Aggressive"):
		needed_tags.append("Aggressive")
	if "drain" in desc and not card.has_keyword("Drain"):
		needed_tags.append("Drain")
	if "lifesteal" in desc and not card.has_keyword("Drain"):
		needed_tags.append("Drain")
	if "lethal" in desc and not card.has_keyword("Lethal"):
		needed_tags.append("Lethal")
	if "hidden" in desc and not card.has_keyword("Hidden"):
		needed_tags.append("Hidden")
	if "persistent" in desc and not card.has_keyword("Persistent"):
		needed_tags.append("Persistent")
	if "snipe" in desc and not card.has_keyword("Snipe"):
		needed_tags.append("Snipe")
	if "battlecry" in desc and not card.has_keyword("On-play"):
		needed_tags.append("On-play")
	if "deathrattle" in desc and not card.has_keyword("On-death"):
		needed_tags.append("On-death")
	
	if needed_tags.size() > 0:
		print("%s needs tags: %s" % [path, needed_tags])
