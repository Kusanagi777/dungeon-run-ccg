# res://data/enums/minion_tags.gd
## Dual Tag System - Role Tags (Tag 1) and Biology Tags (Tag 2)
## Minions can have one Role tag and one Biology tag
class_name MinionTags

## =============================================================================
## TAG 1: ROLE TAGS (Class function/playstyle)
## =============================================================================

enum Role {
	NONE = 0,
	WARRIOR = 1,    # Frontline/Tank - Defensive, high health
	RAIDER = 2,     # Speed/DPS - Fast attackers, charge/rush
	SAVANT = 3,     # Utility/Magic - Spell effects, card draw
	COMMANDER = 4,  # Buffer/Synergy - Buffs other minions
	ZEALOT = 5,     # Suicide/Risk - High risk/reward, self-damage
	TITAN = 6       # Boss/Finisher - Expensive, game-ending threats
}

## Role tag display names
const ROLE_NAMES := {
	Role.NONE: "",
	Role.WARRIOR: "Warrior",
	Role.RAIDER: "Raider",
	Role.SAVANT: "Savant",
	Role.COMMANDER: "Commander",
	Role.ZEALOT: "Zealot",
	Role.TITAN: "Titan"
}

## Role tag descriptions
const ROLE_DESCRIPTIONS := {
	Role.NONE: "",
	Role.WARRIOR: "Frontline/Tank - Defensive minions that protect allies",
	Role.RAIDER: "Speed/DPS - Fast attackers focused on damage",
	Role.SAVANT: "Utility/Magic - Spell-like effects and card manipulation",
	Role.COMMANDER: "Buffer/Synergy - Strengthens and coordinates other minions",
	Role.ZEALOT: "Suicide/Risk - High risk, high reward playstyle",
	Role.TITAN: "Boss/Finisher - Powerful late-game threats"
}


## =============================================================================
## TAG 2: BIOLOGY TAGS (Creature type/origin)
## =============================================================================

enum Biology {
	HUMANOID = 0,
	BEAST = 1,      # Animals/Monsters
	CONSTRUCT = 2,  # Mechs/Golems
	ELEMENTAL = 3,  # Fire/Void/Energy
	FLORA = 4,      # Plants/Fungi
	HORROR = 5,     # Eldritch/Mutants
	UNDEAD = 6,     # Zombies/Spirits
	VERMIN = 7,     # Insects/Rats
	CELESTIAL = 8   # Angels/Light
}

## Biology tag display names
const BIOLOGY_NAMES := {
	Biology.HUMANOID: "Humanaoid",
	Biology.BEAST: "Beast",
	Biology.CONSTRUCT: "Construct",
	Biology.ELEMENTAL: "Elemental",
	Biology.FLORA: "Flora",
	Biology.HORROR: "Horror",
	Biology.UNDEAD: "Undead",
	Biology.VERMIN: "Vermin",
	Biology.CELESTIAL: "Celestial"
}

## Biology tag descriptions
const BIOLOGY_DESCRIPTIONS := {
	Biology.HUMANOID: "The Dominant species of the worlds",
	Biology.BEAST: "Animals and Monsters - Natural creatures",
	Biology.CONSTRUCT: "Mechs and Golems - Artificial beings",
	Biology.ELEMENTAL: "Fire, Void, Energy - Pure elemental forces",
	Biology.FLORA: "Plants and Fungi - Nature's growth",
	Biology.HORROR: "Eldritch and Mutants - Twisted aberrations",
	Biology.UNDEAD: "Zombies and Spirits - Death-touched beings",
	Biology.VERMIN: "Insects and Rats - Swarm creatures",
	Biology.CELESTIAL: "Angels and Light - Divine beings"
}


## =============================================================================
## FACTION DISTRIBUTION - ROLE TAGS
## =============================================================================

## Distribution levels for card generation weighting
enum Distribution {
	BANNED = 0,     # Cannot appear in this faction
	RARE = 1,       # Very few cards (1-2 per set)
	SECONDARY = 2,  # Supporting presence (3-5 per set)
	PRIMARY = 3     # Core identity (6+ per set)
}

## Role tag distribution by faction
## Format: { Role: { "War": Distribution, "Knowledge": Distribution, ... } }
const ROLE_DISTRIBUTION := {
	Role.WARRIOR: {
		"War": Distribution.PRIMARY,
		"Knowledge": Distribution.RARE,
		"Decay": Distribution.SECONDARY,
		"Fortune": Distribution.SECONDARY,
		"Order": Distribution.PRIMARY,
		"Shadow": Distribution.RARE
	},
	Role.RAIDER: {
		"War": Distribution.SECONDARY,
		"Knowledge": Distribution.RARE,
		"Decay": Distribution.SECONDARY,
		"Fortune": Distribution.PRIMARY,
		"Order": Distribution.RARE,
		"Shadow": Distribution.PRIMARY
	},
	Role.SAVANT: {
		"War": Distribution.RARE,
		"Knowledge": Distribution.PRIMARY,
		"Decay": Distribution.SECONDARY,
		"Fortune": Distribution.SECONDARY,
		"Order": Distribution.SECONDARY,
		"Shadow": Distribution.SECONDARY
	},
	Role.COMMANDER: {
		"War": Distribution.SECONDARY,
		"Knowledge": Distribution.SECONDARY,
		"Decay": Distribution.RARE,
		"Fortune": Distribution.PRIMARY,
		"Order": Distribution.PRIMARY,
		"Shadow": Distribution.RARE
	},
	Role.ZEALOT: {
		"War": Distribution.SECONDARY,
		"Knowledge": Distribution.SECONDARY,
		"Decay": Distribution.PRIMARY,
		"Fortune": Distribution.RARE,
		"Order": Distribution.RARE,
		"Shadow": Distribution.SECONDARY
	},
	Role.TITAN: {
		"War": Distribution.PRIMARY,
		"Knowledge": Distribution.RARE,
		"Decay": Distribution.RARE,
		"Fortune": Distribution.PRIMARY,
		"Order": Distribution.SECONDARY,
		"Shadow": Distribution.RARE
	}
}

## =============================================================================
## FACTION DISTRIBUTION - BIOLOGY TAGS
## =============================================================================

## Biology tag distribution by faction
const BIOLOGY_DISTRIBUTION := {
	Biology.BEAST: {
		"War": Distribution.PRIMARY,
		"Knowledge": Distribution.BANNED,
		"Decay": Distribution.SECONDARY,
		"Fortune": Distribution.RARE,
		"Order": Distribution.BANNED,
		"Shadow": Distribution.SECONDARY
	},
	Biology.CONSTRUCT: {
		"War": Distribution.RARE,
		"Knowledge": Distribution.SECONDARY,
		"Decay": Distribution.BANNED,
		"Fortune": Distribution.RARE,
		"Order": Distribution.PRIMARY,
		"Shadow": Distribution.BANNED
	},
	Biology.ELEMENTAL: {
		"War": Distribution.SECONDARY,
		"Knowledge": Distribution.PRIMARY,
		"Decay": Distribution.BANNED,
		"Fortune": Distribution.BANNED,
		"Order": Distribution.RARE,
		"Shadow": Distribution.SECONDARY
	},
	Biology.FLORA: {
		"War": Distribution.RARE,
		"Knowledge": Distribution.BANNED,
		"Decay": Distribution.PRIMARY,
		"Fortune": Distribution.BANNED,
		"Order": Distribution.BANNED,
		"Shadow": Distribution.RARE
	},
	Biology.HORROR: {
		"War": Distribution.BANNED,
		"Knowledge": Distribution.RARE,
		"Decay": Distribution.SECONDARY,
		"Fortune": Distribution.BANNED,
		"Order": Distribution.BANNED,
		"Shadow": Distribution.RARE
	},
	Biology.UNDEAD: {
		"War": Distribution.BANNED,
		"Knowledge": Distribution.BANNED,
		"Decay": Distribution.PRIMARY,
		"Fortune": Distribution.BANNED,
		"Order": Distribution.BANNED,
		"Shadow": Distribution.RARE
	},
	Biology.VERMIN: {
		"War": Distribution.BANNED,
		"Knowledge": Distribution.BANNED,
		"Decay": Distribution.PRIMARY,
		"Fortune": Distribution.BANNED,
		"Order": Distribution.BANNED,
		"Shadow": Distribution.BANNED
	},
	Biology.CELESTIAL: {
		"War": Distribution.RARE,
		"Knowledge": Distribution.SECONDARY,
		"Decay": Distribution.BANNED,
		"Fortune": Distribution.BANNED,
		"Order": Distribution.PRIMARY,
		"Shadow": Distribution.BANNED
	}
}


## =============================================================================
## UTILITY FUNCTIONS - ROLE TAGS
## =============================================================================

## Get role name from enum
static func get_role_name(role: Role) -> String:
	return ROLE_NAMES.get(role, "")


## Get role description
static func get_role_description(role: Role) -> String:
	return ROLE_DESCRIPTIONS.get(role, "")


## Get role enum from string name
static func get_role_from_name(name: String) -> Role:
	match name.to_lower().strip_edges():
		"warrior":
			return Role.WARRIOR
		"raider":
			return Role.RAIDER
		"savant":
			return Role.SAVANT
		"commander":
			return Role.COMMANDER
		"zealot":
			return Role.ZEALOT
		"titan":
			return Role.TITAN
		_:
			return Role.NONE


## Get all valid roles for a faction
static func get_valid_roles_for_faction(faction: String) -> Array[Role]:
	var valid: Array[Role] = []
	for role in ROLE_DISTRIBUTION.keys():
		var dist: Dictionary = ROLE_DISTRIBUTION[role]
		if dist.get(faction, Distribution.BANNED) != Distribution.BANNED:
			valid.append(role)
	return valid


## Get primary roles for a faction
static func get_primary_roles_for_faction(faction: String) -> Array[Role]:
	var primary: Array[Role] = []
	for role in ROLE_DISTRIBUTION.keys():
		var dist: Dictionary = ROLE_DISTRIBUTION[role]
		if dist.get(faction, Distribution.BANNED) == Distribution.PRIMARY:
			primary.append(role)
	return primary


## Get role distribution for faction
static func get_role_distribution(role: Role, faction: String) -> Distribution:
	if role == Role.NONE:
		return Distribution.BANNED
	var dist: Dictionary = ROLE_DISTRIBUTION.get(role, {})
	return dist.get(faction, Distribution.BANNED)


## =============================================================================
## UTILITY FUNCTIONS - BIOLOGY TAGS
## =============================================================================

## Get biology name from enum
static func get_biology_name(biology: Biology) -> String:
	return BIOLOGY_NAMES.get(biology, "")


## Get biology description
static func get_biology_description(biology: Biology) -> String:
	return BIOLOGY_DESCRIPTIONS.get(biology, "")


## Get biology enum from string name
static func get_biology_from_name(name: String) -> Biology:
	match name.to_lower().strip_edges():
		"beast":
			return Biology.BEAST
		"construct":
			return Biology.CONSTRUCT
		"elemental":
			return Biology.ELEMENTAL
		"flora":
			return Biology.FLORA
		"horror":
			return Biology.HORROR
		"undead":
			return Biology.UNDEAD
		"vermin":
			return Biology.VERMIN
		"celestial":
			return Biology.CELESTIAL
		_:
			return Biology.HUMANOID


## Get all valid biologies for a faction
static func get_valid_biologies_for_faction(faction: String) -> Array[Biology]:
	var valid: Array[Biology] = []
	for bio in BIOLOGY_DISTRIBUTION.keys():
		var dist: Dictionary = BIOLOGY_DISTRIBUTION[bio]
		if dist.get(faction, Distribution.BANNED) != Distribution.BANNED:
			valid.append(bio)
	return valid


## Get primary biologies for a faction
static func get_primary_biologies_for_faction(faction: String) -> Array[Biology]:
	var primary: Array[Biology] = []
	for bio in BIOLOGY_DISTRIBUTION.keys():
		var dist: Dictionary = BIOLOGY_DISTRIBUTION[bio]
		if dist.get(faction, Distribution.BANNED) == Distribution.PRIMARY:
			primary.append(bio)
	return primary


## Get biology distribution for faction
static func get_biology_distribution(biology: Biology, faction: String) -> Distribution:
	if biology == Biology.HUMANOID:
		return Distribution.BANNED
	var dist: Dictionary = BIOLOGY_DISTRIBUTION.get(biology, {})
	return dist.get(faction, Distribution.BANNED)


## =============================================================================
## COMBINED TAG UTILITIES
## =============================================================================

## Get full type string for display (e.g., "Raider Beast" or "Zealot Undead")
static func get_type_string(role: Role, biology: Biology) -> String:
	var parts: Array[String] = []
	
	var role_name := get_role_name(role)
	if not role_name.is_empty():
		parts.append(role_name)
	
	var bio_name := get_biology_name(biology)
	if not bio_name.is_empty():
		parts.append(bio_name)
	
	if parts.is_empty():
		return "Minion"
	
	return " ".join(parts)


## Check if a tag combination is valid for a faction
static func is_valid_for_faction(role: Role, biology: Biology, faction: String) -> bool:
	var role_dist := get_role_distribution(role, faction)
	var bio_dist := get_biology_distribution(biology, faction)
	
	# Both tags must not be banned (NONE tags are always valid)
	if role != Role.NONE and role_dist == Distribution.BANNED:
		return false
	if biology != Biology.HUMANOID and bio_dist == Distribution.BANNED:
		return false
	
	return true


## Get weighted random role for faction (respects distribution)
static func get_random_role_for_faction(faction: String, rng: RandomNumberGenerator = null) -> Role:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	
	var weights: Array[float] = []
	var roles: Array[Role] = []
	
	for role in [Role.WARRIOR, Role.RAIDER, Role.SAVANT, Role.COMMANDER, Role.ZEALOT, Role.TITAN]:
		var dist := get_role_distribution(role, faction)
		if dist != Distribution.BANNED:
			roles.append(role)
			match dist:
				Distribution.PRIMARY:
					weights.append(3.0)
				Distribution.SECONDARY:
					weights.append(2.0)
				Distribution.RARE:
					weights.append(0.5)
	
	if roles.is_empty():
		return Role.NONE
	
	# Weighted random selection
	var total_weight := 0.0
	for w in weights:
		total_weight += w
	
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	
	for i in range(roles.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return roles[i]
	
	return roles[-1]


## Get weighted random biology for faction (respects distribution)
static func get_random_biology_for_faction(faction: String, rng: RandomNumberGenerator = null) -> Biology:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	
	var weights: Array[float] = []
	var biologies: Array[Biology] = []
	
	for bio in [Biology.BEAST, Biology.CONSTRUCT, Biology.ELEMENTAL, Biology.FLORA, 
				Biology.HORROR, Biology.UNDEAD, Biology.VERMIN, Biology.CELESTIAL]:
		var dist := get_biology_distribution(bio, faction)
		if dist != Distribution.BANNED:
			biologies.append(bio)
			match dist:
				Distribution.PRIMARY:
					weights.append(3.0)
				Distribution.SECONDARY:
					weights.append(2.0)
				Distribution.RARE:
					weights.append(0.5)
	
	if biologies.is_empty():
		return Biology.HUMANOID
	
	# Weighted random selection
	var total_weight := 0.0
	for w in weights:
		total_weight += w
	
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	
	for i in range(biologies.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return biologies[i]
	
	return biologies[-1]


## =============================================================================
## SYNERGY HELPERS
## =============================================================================

## Check if two minions share a role tag
static func share_role(role1: Role, role2: Role) -> bool:
	return role1 != Role.NONE and role1 == role2


## Check if two minions share a biology tag
static func share_biology(bio1: Biology, bio2: Biology) -> bool:
	return bio1 != Biology.HUMANOID and bio1 == bio2


## Check if two minions share any tag
static func share_any_tag(role1: Role, bio1: Biology, role2: Role, bio2: Biology) -> bool:
	return share_role(role1, role2) or share_biology(bio1, bio2)


## Count minions with matching role on a board
static func count_role_on_board(board: Array, target_role: Role) -> int:
	var count := 0
	for minion in board:
		if is_instance_valid(minion) and minion.role_tag == target_role:
			count += 1
	return count


## Count minions with matching biology on a board
static func count_biology_on_board(board: Array, target_biology: Biology) -> int:
	var count := 0
	for minion in board:
		if is_instance_valid(minion) and minion.biology_tag == target_biology:
			count += 1
	return count
