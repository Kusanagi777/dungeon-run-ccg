## What the boss tells the player it will do (design/gdd/boss-ai.md C8; ADR-0006,
## ADR-0008; TR-boss-ai-002, TR-boss-ai-004; boss-ai-match-driver story 011).
##
## Plain data: [method BossAI.forecast] returns one, the driver appends
## [method to_dict] as `ai_intent_shown` when [method is_shown], and
## [method committed_payload] is the `ai_intent_committed` of a plan. Nothing here
## references an engine, a log or a stream, so a worker can hand one back.
##
## [method key_of] sorts a command into the closed C8.3 set. Which card a
## `play_card` plays stays hidden (C8.4): only its class leaves this file. A spell
## that fits no class (a buff, a draw, burn to the face) is `develop_board`: an
## `attack_face` is for attackers (Edge Cases "Frozen": never fabricated).
## [codeblock]
## var intent: Intent = Intent.new("boss_rot_warden", Intent.KEY_ATTACK_FACE, null, 7, Intent.MODE_FULL)
## if intent.is_shown():
##     log.append(BossAI.EVENT_INTENT_SHOWN, intent.to_dict(), 0)
## [/codeblock]
class_name Intent
extends RefCounted

## The closed C8.3 intent keys.
const KEY_LETHAL: String = "lethal"
const KEY_ATTACK_FACE: String = "attack_face"
const KEY_ATTACK_MINION: String = "attack_minion"
const KEY_PLAY_BIG_MINION: String = "play_big_minion"
const KEY_DEVELOP_BOARD: String = "develop_board"
const KEY_CAST_REMOVAL: String = "cast_removal"
const KEY_CAST_AOE: String = "cast_aoe"
const KEY_HEAL: String = "heal"
const KEY_HERO_POWER: String = "hero_power"
const KEY_EQUIP_WEAPON: String = "equip_weapon"
const KEY_PASS: String = "pass"
## Every key, in C8.3 order.
const KEYS: Array[String] = [KEY_LETHAL, KEY_ATTACK_FACE, KEY_ATTACK_MINION, KEY_PLAY_BIG_MINION, KEY_DEVELOP_BOARD, KEY_CAST_REMOVAL, KEY_CAST_AOE, KEY_HEAL, KEY_HERO_POWER, KEY_EQUIP_WEAPON, KEY_PASS]

## C8.4 `effective_mode` values, least to most shown.
const MODE_HIDDEN: String = "hidden"
const MODE_CLASS_ONLY: String = "class_only"
const MODE_FULL: String = "full"
const MODES: Array[String] = [MODE_HIDDEN, MODE_CLASS_ONLY, MODE_FULL]

## The op that makes a spell a `heal` (a [method Chooser.card_tags] tag).
const OP_HEAL: String = "heal"

## The boss definition's id.
var boss_id: String = ""
## One of [constant KEYS].
var intent_key: String = KEY_PASS
## The named target of `attack_minion` / `cast_removal`, else null.
var target_id: Variant = null
## The forecast face damage of `attack_face` / `lethal`, else null.
var amount: Variant = null
## One of [constant MODES].
var effective_mode: String = MODE_FULL


## [param mode] below `full` nulls [param target] and [param face_damage] (C8.4).
func _init(id: String, key: String, target: Variant, face_damage: Variant, mode: String) -> void:
	boss_id = id
	intent_key = key
	effective_mode = mode
	if mode == MODE_FULL:
		target_id = target
		amount = face_damage


## The `ai_intent_shown` payload (rng-event-log §D).
func to_dict() -> Dictionary:
	return {
		"boss_id": boss_id,
		"intent_key": intent_key,
		"target_id": target_id,
		"amount": amount,
		"effective_mode": effective_mode,
	}


## The `ai_intent_committed` payload (rng-event-log §D). [param kept]: the
## committed class equals the forecast (C8.2).
func committed_payload(kept: bool) -> Dictionary:
	return {
		"intent_key": intent_key,
		"target_id": target_id,
		"amount": amount,
		"kept": kept,
		"effective_mode": effective_mode,
	}


## Whether the driver appends `ai_intent_shown` (C8.4: `hidden` suppresses it).
func is_shown() -> bool:
	return effective_mode != MODE_HIDDEN


## The C8.3 class of [param command]. [param def] is the definition a `play_card`
## plays, null for any other command; [param enemy_hero_id] and
## [param enemy_minion_ids] are the opposing characters. `lethal` is never
## returned: it belongs to a proven plan, not to one command.
## [codeblock]
## Intent.key_of(MatchRecords.attack("boss", 5, hero_id), null, hero_id, [])   # "attack_face"
## [/codeblock]
static func key_of(command: Dictionary, def: Variant, enemy_hero_id: int, enemy_minion_ids: Array) -> String:
	match str(command.get("type")):
		MatchRecords.CMD_ATTACK:
			return KEY_ATTACK_FACE if command.get("target_id") == enemy_hero_id else KEY_ATTACK_MINION
		MatchRecords.CMD_USE_HERO_POWER:
			return KEY_HERO_POWER
		MatchRecords.CMD_PLAY_CARD:
			return _play_key(def, enemy_minion_ids.has(command.get("target_id")))
	return KEY_PASS


## The target [param key] names, from [param command] (C8.3: `attack_minion` and
## `cast_removal` only).
static func named_target(key: String, command: Dictionary) -> Variant:
	return command.get("target_id") if key == KEY_ATTACK_MINION or key == KEY_CAST_REMOVAL else null


static func _play_key(def: Variant, targets_enemy_minion: bool) -> String:
	if not def is Dictionary:
		return KEY_DEVELOP_BOARD
	match str(def.get("type")):
		RulesEngine.CARD_MINION:
			return KEY_PLAY_BIG_MINION if int(def.get("cost", 0)) >= int(Scorer.NORMALISERS.big_minion_cost) else KEY_DEVELOP_BOARD
		RulesEngine.CARD_WEAPON:
			return KEY_EQUIP_WEAPON
	if Scorer.is_aoe(def):
		return KEY_CAST_AOE
	if Chooser.card_tags(def).has(OP_HEAL):
		return KEY_HEAL
	return KEY_CAST_REMOVAL if targets_enemy_minion else KEY_DEVELOP_BOARD
