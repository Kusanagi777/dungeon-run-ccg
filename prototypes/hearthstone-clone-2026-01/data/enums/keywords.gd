# res://data/enums/keywords.gd
## Keyword Constants and Utilities
## Use these for type-safe keyword checking and consistency
class_name Keywords

## =============================================================================
## KEYWORD STRING CONSTANTS
## =============================================================================

# Combat Keywords
const CHARGE := "Charge"
const RUSH := "Rush"  
const AGGRESSIVE := "Aggressive"
const TAUNT := "Taunt"
const PIERCE := "Pierce"
const SNIPE := "Snipe"
const BULLY := "Bully"
const LETHAL := "Lethal"
const STUN := "Stun"

# Defensive Keywords
const SHIELDED := "Shielded"
const WARD := "Ward"
const HIDDEN := "Hidden"
const ILLUSION := "Illusion"
const RESIST := "Resist"  # Parameterized: "Resist (2)"

# Trigger Keywords
const DEPLOY := "Deploy"
const ON_PLAY := "On-play"
const LAST_WORDS := "Last words"
const ON_DEATH := "On-death"
const BOUNTY := "Bounty"
const EMPOWERED := "Empowered"
const FATED := "Fated"

# Resource Keywords
const DRAIN := "Drain"
const AFFINITY := "Affinity"  # Parameterized: "Affinity: Beast"
const SACRIFICE := "Sacrifice"  # Parameterized: "Sacrifice (2)"
const RITUAL := "Ritual"
const CONDUIT := "Conduit"  # Parameterized: "Conduit (2)"

# Utility Keywords
const ECHO := "Echo"
const DRAFT := "Draft"
const CYCLE := "Cycle"
const SCOUT := "Scout"
const SILENCE := "Silence"
const WEAKENED := "Weakened"  # Effect keyword: "Weakened (2)"

# Special Keywords
const PERSISTENT := "Persistent"
const HUDDLE := "Huddle"


## =============================================================================
## KEYWORD CATEGORIES
## =============================================================================

static var COMBAT_KEYWORDS: Array[String] = [
	CHARGE, RUSH, AGGRESSIVE, TAUNT, PIERCE, SNIPE, BULLY, LETHAL, STUN
]

static var DEFENSIVE_KEYWORDS: Array[String] = [
	SHIELDED, WARD, HIDDEN, ILLUSION, RESIST
]

static var TRIGGER_KEYWORDS: Array[String] = [
	DEPLOY, ON_PLAY, LAST_WORDS, ON_DEATH, BOUNTY, EMPOWERED, FATED
]

static var RESOURCE_KEYWORDS: Array[String] = [
	DRAIN, AFFINITY, SACRIFICE, RITUAL, CONDUIT
]

static var UTILITY_KEYWORDS: Array[String] = [
	ECHO, DRAFT, CYCLE, SCOUT, SILENCE, WEAKENED
]

static var SPECIAL_KEYWORDS: Array[String] = [
	PERSISTENT, HUDDLE
]

static var ALL_KEYWORDS: Array[String] = [
	# Combat
	CHARGE, RUSH, AGGRESSIVE, TAUNT, PIERCE, SNIPE, BULLY, LETHAL, STUN,
	# Defensive
	SHIELDED, WARD, HIDDEN, ILLUSION, RESIST,
	# Trigger
	DEPLOY, ON_PLAY, LAST_WORDS, ON_DEATH, BOUNTY, EMPOWERED, FATED,
	# Resource
	DRAIN, AFFINITY, SACRIFICE, RITUAL, CONDUIT,
	# Utility
	ECHO, DRAFT, CYCLE, SCOUT, SILENCE, WEAKENED,
	# Special
	PERSISTENT, HUDDLE
]

## Parameterized keywords (can have numeric values)
static var PARAMETERIZED_KEYWORDS: Array[String] = [
	RESIST, SACRIFICE, CONDUIT, WEAKENED, AFFINITY
]


## =============================================================================
## FACTION KEYWORD DISTRIBUTION
## Based on Key_Words.xlsx faction preferences
## =============================================================================

## War faction - Aggressive combat focus
static var WAR_MAJORITY: Array[String] = [AGGRESSIVE, CHARGE, RUSH, PIERCE]
static var WAR_AVERAGE: Array[String] = [DEPLOY, TAUNT, BOUNTY, WARD, SHIELDED]

## Knowledge faction - Control and utility
static var KNOWLEDGE_MAJORITY: Array[String] = [DEPLOY, EMPOWERED, DRAFT, CONDUIT]
static var KNOWLEDGE_EXCLUSIVE: Array[String] = [SILENCE, SCOUT]

## Decay faction - Death and sacrifice themes
static var DECAY_MAJORITY: Array[String] = [LAST_WORDS, DRAIN, AFFINITY, WEAKENED]
static var DECAY_EXCLUSIVE: Array[String] = [PERSISTENT, SACRIFICE]

## Fortune faction - Luck and timing
static var FORTUNE_MAJORITY: Array[String] = [DEPLOY, BOUNTY, SNIPE]
static var FORTUNE_EXCLUSIVE: Array[String] = [FATED]

## Order faction - Protection and control
static var ORDER_MAJORITY: Array[String] = [TAUNT, WARD, SHIELDED, STUN]
static var ORDER_EXCLUSIVE: Array[String] = [RESIST]

## Shadow faction - Stealth and trickery
static var SHADOW_MAJORITY: Array[String] = [LETHAL, SNIPE, ECHO, ILLUSION, CYCLE]
static var SHADOW_EXCLUSIVE: Array[String] = [HIDDEN]


## =============================================================================
## UTILITY FUNCTIONS
## =============================================================================

## Check if a keyword is parameterized (takes a numeric value)
static func is_parameterized(keyword: String) -> bool:
	var base := keyword.split(" ")[0].split("(")[0].strip_edges()
	return base in PARAMETERIZED_KEYWORDS


## Get the base keyword name from a parameterized keyword
## e.g., "Resist (2)" -> "Resist"
static func get_base_keyword(keyword: String) -> String:
	var base := keyword.split(" ")[0].split("(")[0].strip_edges()
	return base


## Parse the numeric value from a parameterized keyword
## e.g., "Resist (2)" -> 2, "Conduit 3" -> 3
static func parse_value(keyword: String) -> int:
	var parts := keyword.replace("(", " ").replace(")", " ").split(" ")
	for part in parts:
		part = part.strip_edges()
		if part.is_valid_int():
			return part.to_int()
	return 0


## Get category of a keyword
static func get_category(keyword: String) -> String:
	var base := get_base_keyword(keyword)
	if base in COMBAT_KEYWORDS:
		return "Combat"
	elif base in DEFENSIVE_KEYWORDS:
		return "Defensive"
	elif base in TRIGGER_KEYWORDS:
		return "Trigger"
	elif base in RESOURCE_KEYWORDS:
		return "Resource"
	elif base in UTILITY_KEYWORDS:
		return "Utility"
	elif base in SPECIAL_KEYWORDS:
		return "Special"
	return "Unknown"


## Check if keyword is valid
static func is_valid_keyword(keyword: String) -> bool:
	var base := get_base_keyword(keyword)
	return base in ALL_KEYWORDS


## Format keyword for display (with tooltip hint)
static func format_for_display(keyword: String) -> String:
	var base := get_base_keyword(keyword)
	var value := parse_value(keyword)
	
	if value > 0:
		return "%s (%d)" % [base, value]
	return base
