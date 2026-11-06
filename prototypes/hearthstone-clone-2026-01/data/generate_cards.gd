@tool
extends EditorScript

# DEFINITION OF ALL 35 CARDS
# This array holds the raw data for the Base Set.
var card_db = [
	# --- WAR ---
	{"id": "war_01_goblin_grunt", "name": "Goblin Grunt", "cost": 1, "type": "Unit", "atk": 2, "hp": 1, "tags": ["Beast", "Warrior"], "rarity": "Common", "text": "Deploy: If you have another [Beast], gain +1 Attack."},
	{"id": "war_02_blood_frenzy", "name": "Blood Frenzy", "cost": 1, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Common", "text": "Give a friendly unit +2 Attack and Pierce this turn."},
	{"id": "war_03_ogre_bully", "name": "Ogre Bully", "cost": 3, "type": "Unit", "atk": 3, "hp": 4, "tags": ["Humanoid", "Raider"], "rarity": "Common", "text": "Bully: Gain +2 Attack when attacking."},
	{"id": "war_04_execute", "name": "Execute", "cost": 2, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Rare", "text": "Deal 4 damage to a unit. If this kills it, gain +1 Worship."},
	{"id": "war_05_iron_behemoth", "name": "Iron Behemoth", "cost": 5, "type": "Unit", "atk": 5, "hp": 5, "tags": ["Construct", "Titan"], "rarity": "Epic", "text": "Aggressive. Pierce."},

	# --- KNOWLEDGE ---
	{"id": "know_01_archive_drone", "name": "Archive Drone", "cost": 2, "type": "Unit", "atk": 1, "hp": 3, "tags": ["Construct", "Savant"], "rarity": "Common", "text": "Conduit (1)."},
	{"id": "know_02_precognition", "name": "Precognition", "cost": 1, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Common", "text": "Scout. Then, Draw 1 card."},
	{"id": "know_03_aether_binder", "name": "Aether Binder", "cost": 3, "type": "Unit", "atk": 2, "hp": 4, "tags": ["Elemental", "Savant"], "rarity": "Rare", "text": "Deploy: Stun target enemy unit."},
	{"id": "know_04_chain_lightning", "name": "Chain Lightning", "cost": 4, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Rare", "text": "Deal 3 damage to 3 random enemies."},
	{"id": "know_05_storm_avatar", "name": "Storm Avatar", "cost": 6, "type": "Unit", "atk": 4, "hp": 6, "tags": ["Elemental", "Titan"], "rarity": "Epic", "text": "Deploy: Silence all enemy units."},

	# --- DECAY ---
	{"id": "decay_01_rotting_rat", "name": "Rotting Rat", "cost": 1, "type": "Unit", "atk": 1, "hp": 1, "tags": ["Vermin", "Raider"], "rarity": "Common", "text": "Persistent."},
	{"id": "decay_02_corpse_explosion", "name": "Corpse Explosion", "cost": 2, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Common", "text": "Sacrifice (1): Deal 3 damage to the enemy Hero and heal yourself for 3."},
	{"id": "decay_03_cultist_butcher", "name": "Cultist Butcher", "cost": 2, "type": "Unit", "atk": 2, "hp": 3, "tags": ["Undead", "Zealot"], "rarity": "Rare", "text": "Sacrifice (1): Gain +2/+2."},
	{"id": "decay_04_brood_mother", "name": "Brood Mother", "cost": 4, "type": "Unit", "atk": 2, "hp": 4, "tags": ["Vermin", "Commander"], "rarity": "Rare", "text": "Deploy: Summon two 1/1 [Vermin] Rats."},
	{"id": "decay_05_grave_titan", "name": "Grave Titan", "cost": 6, "type": "Unit", "atk": 5, "hp": 5, "tags": ["Undead", "Titan"], "rarity": "Epic", "text": "Affinity ([Undead]). Deploy: Return a unit from your graveyard to hand."},

	# --- FORTUNE ---
	{"id": "fort_01_lucky_coin", "name": "Lucky Coin", "cost": 0, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Common", "text": "Gain 1 Mana this turn. Fated: Gain 2 Mana instead."},
	{"id": "fort_02_bounty_hunter", "name": "Bounty Hunter", "cost": 2, "type": "Unit", "atk": 2, "hp": 2, "tags": ["Humanoid", "Raider"], "rarity": "Common", "text": "Bounty: You draw 1 card."},
	{"id": "fort_03_mercenary_captain", "name": "Mercenary Captain", "cost": 4, "type": "Unit", "atk": 4, "hp": 4, "tags": ["Humanoid", "Commander"], "rarity": "Rare", "text": "Deploy: If you have 5+ Mana remaining, give this unit +2/+2."},
	{"id": "fort_04_jackpot", "name": "Jackpot", "cost": 3, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Rare", "text": "Draw 2 cards. If you played a card costing (4) or more this turn, Draw 3 instead."},
	{"id": "fort_05_gilded_colossus", "name": "Gilded Colossus", "cost": 7, "type": "Unit", "atk": 7, "hp": 7, "tags": ["Construct", "Titan"], "rarity": "Epic", "text": "Taunt. Deploy: If played, gain 2 Gold."},

	# --- ORDER ---
	{"id": "order_01_phalanx_guard", "name": "Phalanx Guard", "cost": 2, "type": "Unit", "atk": 1, "hp": 4, "tags": ["Humanoid", "Warrior"], "rarity": "Common", "text": "Taunt."},
	{"id": "order_02_stand_firm", "name": "Stand Firm", "cost": 1, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Common", "text": "Give a unit Taunt and Resist (1) this turn."},
	{"id": "order_03_crystal_sentinel", "name": "Crystal Sentinel", "cost": 3, "type": "Unit", "atk": 2, "hp": 4, "tags": ["Construct", "Warrior"], "rarity": "Rare", "text": "Shielded."},
	{"id": "order_04_mend", "name": "Mend", "cost": 2, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Rare", "text": "Restore 5 Health to a unit. If it is fully healed, Draw 1 card."},
	{"id": "order_05_marble_guardian", "name": "Marble Guardian", "cost": 5, "type": "Unit", "atk": 3, "hp": 6, "tags": ["Construct", "Titan"], "rarity": "Epic", "text": "Ward. Resist (1)."},

	# --- SHADOW ---
	{"id": "shadow_01_mist_walker", "name": "Mist Walker", "cost": 1, "type": "Unit", "atk": 2, "hp": 1, "tags": ["Humanoid", "Raider"], "rarity": "Common", "text": "Hidden."},
	{"id": "shadow_02_shuriken", "name": "Shuriken", "cost": 0, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Common", "text": "Deal 1 damage. Echo."},
	{"id": "shadow_03_smoke_bomb", "name": "Smoke Bomb", "cost": 2, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Rare", "text": "Return an enemy unit to its owner's hand."},
	{"id": "shadow_04_nightblade", "name": "Nightblade", "cost": 4, "type": "Unit", "atk": 4, "hp": 2, "tags": ["Humanoid", "Zealot"], "rarity": "Rare", "text": "Snipe. Lethal."},
	{"id": "shadow_05_shadow_mimic", "name": "Shadow Mimic", "cost": 3, "type": "Unit", "atk": 3, "hp": 3, "tags": ["Horror", "Savant"], "rarity": "Epic", "text": "Deploy: Create an Echo copy of the last Action card you played."},

	# --- NEUTRAL ---
	{"id": "neut_01_traveling_merchant", "name": "Traveling Merchant", "cost": 1, "type": "Unit", "atk": 1, "hp": 2, "tags": ["Humanoid", "Savant"], "rarity": "Common", "text": "Deploy: Heal your Hero for 2."},
	{"id": "neut_02_forest_wolf", "name": "Forest Wolf", "cost": 2, "type": "Unit", "atk": 3, "hp": 2, "tags": ["Beast", "Raider"], "rarity": "Common", "text": ""},
	{"id": "neut_03_iron_pike", "name": "Iron Pike", "cost": 2, "type": "Action", "atk": 0, "hp": 0, "tags": [], "rarity": "Common", "text": "Deal 2 damage to a unit."},
	{"id": "neut_04_stone_golem", "name": "Stone Golem", "cost": 3, "type": "Unit", "atk": 3, "hp": 4, "tags": ["Elemental", "Warrior"], "rarity": "Rare", "text": ""},
	{"id": "neut_05_giant_eagle", "name": "Giant Eagle", "cost": 4, "type": "Unit", "atk": 4, "hp": 3, "tags": ["Beast", "Raider"], "rarity": "Rare", "text": "Snipe."}
]

func _run():
	print("--- Starting Card Generation ---")
	
	# 1. Create directory if it doesn't exist
	var dir = DirAccess.open("res://data")
	if not dir.dir_exists("cards"):
		dir.make_dir("cards")
		print("Created folder: res://data/cards")
	
	# 2. Iterate through DB and create resources
	for data in card_db:
		var new_card = CardData.new()

		new_card.card_name = data["name"]
		new_card.cost = data["cost"]
		new_card.card_type = data["type"]
		new_card.attack = data["atk"]
		new_card.health = data["hp"]

		# Parse tags into role and biology
		for tag_name in data["tags"]:
			var role = MinionTags.get_role_from_name(tag_name)
			if role != MinionTags.Role.NONE:
				new_card.role_tag = role
				continue

			var bio = MinionTags.get_biology_from_name(tag_name)
			if bio != MinionTags.Biology.HUMANOID or tag_name.to_lower() == "humanoid":
				new_card.biology_tag = bio

		new_card.rarity = data["rarity"]
		new_card.description = data["text"]
		
		# 3. Save to disk
		var file_path = "res://data/cards/" + data["id"] + ".tres"
		var error = ResourceSaver.save(new_card, file_path)
		
		if error == OK:
			print("Saved: " + file_path)
		else:
			print("ERROR saving " + file_path + ": " + str(error))
			
	print("--- Generation Complete. Rescan FileSystem if needed. ---")
