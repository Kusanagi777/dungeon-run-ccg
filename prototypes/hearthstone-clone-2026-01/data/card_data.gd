# res://data/card_data.gd
class_name CardData
extends Resource

## Enumeration for card types (simplified - no locations or class powers)
enum CardType {
	MINION,
	ACTION,
	ASPECT
}

## Enumeration for card rarity
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## Minion Tags - Bitflag constants for minion types
class minion_tags:
	const HUMANOID: int = 0
	const BEAST: int = 1 << 0     # 1
	const CONSTRUCT: int = 1 << 1      # 2
	const ELEMENTAL: int = 1 << 2      # 4
	const FLORA: int = 1 << 3    # 8
	const HORROR: int = 1 << 4    # 16
	const UNDEAD: int = 1 << 5
	const VERMIN: int = 1 << 6
	const CELESTIAL: int = 1 << 7
	const ALL: int = HUMANOID | BEAST | CONSTRUCT | ELEMENTAL | FLORA | HORROR | UNDEAD | VERMIN | CELESTIAL

## Unique identifier for this card
@export var id: String = ""

## Display name shown on the card
@export var card_name: String = ""

## Mana cost to play this card
@export_range(0, 10) var cost: int = 0

## Base attack value (for minions)
@export_range(0, 20) var attack: int = 0

## Base health value (for minions)
@export_range(0, 20) var health: int = 0

@export var min_tags: int = 0

## Card type determines behavior and valid targets
@export var card_type: CardType = CardType.MINION

## Rarity affects visual styling and deck limits
@export var rarity: Rarity = Rarity.COMMON

## Card art displayed in the frame
@export var texture: Texture2D

## Description text - supports BBCode for formatting
@export_multiline var description: String = ""

## Tags/Keywords for special abilities
## KEYWORDS:
## "Charge"      - Can attack when summoned
## "Taunt"       - Protects other minions in the same row from being targeted
## "Shielded"    - Next damage instance is reduced to 0
## "Aggressive"  - Can attack twice per turn
## "Drain"       - Damage dealt heals your hero
## "Lethal"      - Any damage dealt destroys the target minion
## "On-play"     - Effect triggers when summoned (Battlecry)
## "On-death"    - Effect triggers when destroyed (Deathrattle)
## "Rush"        - Can attack minions (not heroes) when summoned
## "Hidden"      - Cannot be targeted by opponent's cards
## "Persistent"  - Returns with 1 HP when destroyed, then loses this keyword
## "Snipe"       - Can target/attack back row regardless of front row
## "Draft"       - Player chooses from 3 cards, places result on field/hand/deck
## "Bully"       - Bonus effect when attacking weaker target
## "Huddle"      - Can be played in occupied space, buffs front minion
## "Ritual"      - Optionally sacrifice friendly minions for bonus effect
## "Fated"       - Bonus effect if played same turn as drawn
@export var keywords: Array[String] = []

@export var role_tag: MinionTags.Role = MinionTags.Role.NONE
@export var biology_tag: MinionTags.Biology = MinionTags.Biology.HUMANOID

## Runtime-only fields (not saved to resource)
var _runtime_id: String = ""


## =============================================================================
## INITIALIZATION
## =============================================================================

func _init() -> void:
	_runtime_id = ""


## Create a duplicate for actual gameplay (preserves original resource)
func duplicate_for_play() -> CardData:
	var copy := self.duplicate(true) as CardData
	copy._runtime_id = _generate_runtime_id()
	return copy


func _generate_runtime_id() -> String:
	return "%s_%d_%d" % [id, Time.get_ticks_msec(), randi()]


## Get the runtime unique ID (for tracking specific card instances)
func get_runtime_id() -> String:
	if _runtime_id.is_empty():
		_runtime_id = _generate_runtime_id()
	return _runtime_id


## =============================================================================
## KEYWORD HELPER FUNCTIONS
## =============================================================================

## Check if card has a specific keyword
func has_keyword(keyword: String) -> bool:
	return keywords.has(keyword.to_lower()) or keywords.has(keyword.capitalize())


## Add a keyword
func add_keyword(keyword: String) -> void:
	var kw := keyword.to_lower()
	if not keywords.has(kw):
		keywords.append(kw)


## Remove a keyword
func remove_keyword(keyword: String) -> void:
	var kw := keyword.to_lower()
	keywords.erase(kw)
	keywords.erase(keyword.capitalize())


## Get keyword tooltip description
func get_keyword_description(keyword: String) -> String:
	match keyword.to_lower():
		# === COMBAT KEYWORDS ===
		"charge":
			return "Can attack immediately when summoned."
		"rush":
			return "Can attack minions the turn it is summoned, but cannot attack heroes."
		"aggressive":
			return "This minion can attack twice per turn."
		"taunt":
			return "Opposing minions cannot select another minion who shares a row with this minion as a target."
		"pierce":
			return "When this minion attacks, any damage dealt above the target's current health is dealt to the controlling player."
		"snipe":
			return "Can attack from the back row and can target back row minions regardless of front row."
		"bully":
			return "Bonus effect triggers when attacking a target with less Attack than this minion."
		"lethal":
			return "Any damage dealt by this minion destroys the target minion."
		"stun":
			return "Target minion is unable to attack this turn."
		"weakened":
			return "Reduce the attack of a minion by X amount until the end of the turn."
		
		# === DEFENSIVE KEYWORDS ===
		"shielded":
			return "The next instance of damage is reduced to 0 and Shielded is removed."
		"ward":
			return "This minion cannot be targeted by action cards."
		"hidden":
			return "Cannot be targeted by opponent's cards. Removed when this minion attacks."
		"resist":
			return "This minion takes X less damage whenever it is damaged."
		"illusion":
			return "When anything interacts with this minion (damaged, targeted, attacked), this minion dies."
		
		# === TRIGGER KEYWORDS ===
		"deploy", "on-play":
			return "When this minion is summoned, an effect takes place."
		"last words", "on-death":
			return "When this minion is destroyed, an effect takes place."
		"bounty":
			return "When this minion is sent to the graveyard, the opponent receives a reward."
		"empowered":
			return "This card gains an additional benefit if played immediately after an action card."
		"fated":
			return "Bonus effect triggers if played the same turn it was drawn."
		
		# === RESOURCE KEYWORDS ===
		"drain":
			return "Damage dealt by this minion is restored to the controlling player's health."
		"affinity":
			return "Costs 1 less mana for every minion with the specified tag on your field."
		"sacrifice":
			return "Send X number of friendly minions to the graveyard to activate this effect."
		"ritual":
			return "Optionally sacrifice friendly minions to trigger a bonus effect."
		"conduit":
			return "Friendly action cards deal X more damage while this minion is on the field."
		
		# === UTILITY KEYWORDS ===
		"echo":
			return "After this card is played, a copy is created in your hand. It leaves your hand at the end of your turn."
		"draft":
			return "Choose one of three randomly selected cards from your deck."
		"cycle":
			return "Spend 1 mana to shuffle this card back into your deck and draw 1."
		"scout":
			return "Look at the top card of your deck. You may leave it or move it to the bottom."
		"silence":
			return "Remove all text and keywords from the target minion."
		
		# === SPECIAL KEYWORDS ===
		"persistent":
			return "Upon death, this minion revives with 1 health and loses Persistent."
		"huddle":
			return "Can be played in an occupied space. Buffs the front minion and takes over when it dies."
		_:
			return ""


## Parse keyword value (for keywords like "Resist (2)" or "Conduit (3)")
func get_keyword_value(keyword: String) -> int:
	# Check if keyword is in format "Keyword (X)" or "Keyword X"
	for kw in keywords:
		var kw_lower := kw.to_lower()
		var base_keyword := keyword.to_lower()
		
		# Match "resist (2)", "resist 2", "resist(2)"
		if kw_lower.begins_with(base_keyword):
			var remainder := kw_lower.replace(base_keyword, "").strip_edges()
			remainder = remainder.trim_prefix("(").trim_suffix(")")
			if remainder.is_valid_int():
				return remainder.to_int()
	
	# Default values for specific keywords
	match keyword.to_lower():
		"resist":
			return 1
		"conduit":
			return 1
		"sacrifice":
			return 1
		"weakened":
			return 1
		"affinity":
			return 1
	
	return 0


## Get all keywords that have this base (e.g., "resist" returns ["resist (2)"])
func get_keywords_with_base(base: String) -> Array[String]:
	var result: Array[String] = []
	var base_lower := base.to_lower()
	
	for kw in keywords:
		if kw.to_lower().begins_with(base_lower):
			result.append(kw)
	
	return result


## Check if card has a keyword (supports parameterized keywords)
func has_keyword_base(keyword: String) -> bool:
	var kw_lower := keyword.to_lower()
	for k in keywords:
		if k.to_lower().begins_with(kw_lower):
			return true
	return false


## Get ritual sacrifice cost (for cards with Ritual keyword)
func get_ritual_cost() -> int:
	if not has_keyword("ritual"):
		return 0
	# Default ritual cost is 1, can be overridden in description parsing
	return 1


## =============================================================================
## MINION TAG HELPER FUNCTIONS
## =============================================================================

## Check if this card has a specific minion tag
func has_minion_tag(tag: int) -> bool:
	return (min_tags & tag) != 0


## Add a minion tag
func add_minion_tag(tag: int) -> void:
	min_tags |= tag


## Remove a minion tag
func remove_minion_tag(tag: int) -> void:
	min_tags &= ~tag


## Get all minion tags as an array of strings
func get_minion_tag_names() -> Array[String]:
	var names: Array[String] = []
	if has_minion_tag(minion_tags.BEAST):
		names.append("Beast")
	if has_minion_tag(minion_tags.CONSTRUCT):
		names.append("Construct")
	if has_minion_tag(minion_tags.ELEMENTAL):
		names.append("Elemental")
	if has_minion_tag(minion_tags.UNDEAD):
		names.append("Undead")
	if has_minion_tag(minion_tags.FLORA):
		names.append("Flora")
	if has_minion_tag(minion_tags.HORROR):
		names.append("Horror")
	if has_minion_tag(minion_tags.VERMIN):
		names.append("Vermin")
	if has_minion_tag(minion_tags.CELESTIAL):
		names.append("Celestial")
	if has_minion_tag(minion_tags.HUMANOID):
		names.append("Humanoid")
	return names


## =============================================================================
## CARD TYPE HELPERS
## =============================================================================

## Get display string for card type
func get_type_string() -> String:
	match card_type:
		CardType.MINION:
			var type_parts: Array[String] = get_minion_tag_names()
			if type_parts.is_empty():
				return "Minion"
			return " ".join(type_parts) + " Minion"
		CardType.ACTION:
			return "Action"
		_:
			return "Unknown"


## Check if this is a minion card
func is_minion() -> bool:
	return card_type == CardType.MINION


## Check if this is an action card
func is_action() -> bool:
	return card_type == CardType.ACTION


## =============================================================================
## UTILITY
## =============================================================================

## Get formatted description with keyword highlights
func get_formatted_description() -> String:
	var result := description
	
	# Bold keywords in description
	for kw in keywords:
		var capitalized := kw.capitalize()
		result = result.replace(capitalized, "[b]%s[/b]" % capitalized)
	
	return result


## Debug string representation
func _to_string() -> String:
	return "[CardData: %s (%d/%d) Cost:%d]" % [card_name, attack, health, cost]
