## The Boss AI action scorer (design/gdd/boss-ai.md C4, C5, C6, F1, F2, F3,
## F5, Edge Cases "board full" and "sandbox `resolution_overflow`"; ADR-0006,
## ADR-0001; TR-boss-ai-001; boss-ai-match-driver story 004).
##
## Each candidate command is scored by **one-ply simulation**: the base
## sandbox is cloned (`RulesEngine.clone()`, match-rules story 017), the
## candidate is submitted on the copy, and the eleven F1 features are the
## deltas between the base (before) and the copy (after). The score is
## `Σ w_i · f_i` with the resolved profile's weights. Nothing here touches the
## live engine: [method score_all] takes a **clone** as its base and every
## trial is a clone of that clone, ended with `end_match()` once read.
##
## **Clone discipline** (match-rules 015/017 code review, 2026-11-04, notes
## 3, 5, 6): every trial clone is ended with `end_match()` on every path,
## early returns included (a dropped clone leaks: engine and resolver hold each
## other); `rng_match` is never forked on a clone (the clone's fork memo is
## not carried, so its forks diverge from live — planner randomness comes from
## the `ai_<floor>` stream's `sim_<turn>` fork); and candidates must be taken
## from `legal_commands()` — `submit` accepts and ignores a stray `position`
## or `target_id`, so a synthesised command could score as a duplicate.
##
## **What the scorer reads.** The candidate list comes from the caller (the
## clone's `legal_commands()`, story 005 filters it); the rest is read from the
## two sandboxes only — `phase()`, `active_side()`, `pending_choice()`,
## `result()`, `rule("board_size")`, the derived values `health()`,
## `max_health()`, `attack()`, `has_windfury()`, and, because no `MatchQuery`
## exists yet, the clone's own `state()` for the boards, hand **counts**, mana,
## weapons and own-hand definitions — read-only, never the live engine's
## (story 004 readiness note). The player's hand is read as a count only (C1.3:
## no hidden information).
##
## **`end_turn`** is always scored and never simulated: F1/C2 define its
## features as the "do nothing" deltas plus the mana-waste penalty, so it is
## scored with `after = before` (submitting it would run the player's Start
## step and score the player's draw, not the boss's action).
##
## **Not here** (their stories): candidate enumeration, the `op_value`
## pre-filter and position handling ([CandidateSet], story 005, which also
## owns the F9 `hero_power` rule this file applies as `f_hp`); the tie-break and `ai_<floor>` draws
## (story 006); DEFENSIVE weight multipliers (story 009 — the scorer takes the
## already-multiplied weights and branches on mode only for the Taunt BV bonus);
## `choose` scoring for a sandbox Discover (story 010 — until then a boss-side
## Choice raised in a trial is answered with option 0 and the entry is flagged
## `sim_choice_placeholder`); installing the `sim_<turn>` fork on the turn's
## base sandbox (story 008 `plan_turn`; every trial copies the base's
## `rng_match`, so trials of one turn start from the same stream position).
## [codeblock]
## var scorer := Scorer.new(db, db.config("ai_profiles").keyword_values)
## var base: RulesEngine = engine.clone()
## var scored: Array = await scorer.score_all(base, base.legal_commands(), profile, Scorer.MODE_NORMAL, {"aoe_seen": false}, planner)
## scored[0].command   # the best candidate; scored[0].features carries the eleven F1 keys
## base.end_match()
## [/codeblock]
class_name Scorer
extends RefCounted

## Planner modes (C2, States and Transitions). The scorer branches on
## [constant MODE_DEFENSIVE] only (the Taunt BV bonus, F2 / States).
const MODE_NORMAL: StringName = &"NORMAL"
const MODE_LETHAL: StringName = &"LETHAL"
const MODE_DEFENSIVE: StringName = &"DEFENSIVE"

## C9 `ai_decision.alternatives[≤3]` — a payload shape, not a tuning knob.
const ALTERNATIVES_MAX: int = 3
## The [method score] context key for the F9 `spare_mana` test.
const CONTEXT_CARD_PLAYABLE: String = "card_playable"

## The eleven F1 features, in F1 order — the keys of every `features`
## Dictionary, so `ai_decision.features` can carry it verbatim.
const FEATURE_KEYS: Array[String] = ["f_board", "f_face", "f_self", "f_trade", "f_threat", "f_mana", "f_card", "f_over", "f_heal", "f_hp", "f_passive"]

## The normaliser table (A29: the only numbers in `src/ai/**` that are not
## read from `ai_profiles.json`). Each value is a GDD constant that F9's
## closed schema has no key for; promote a row to `rules` when F9 gains it.
## - `taunt_bonus` 1.5 — F2 `taunt_bonus` (threat of a Taunt);
## - `threat_windfury` 0.5 — F2 `threat(m) = attack · (1 + 0.5·windfury) …`;
## - `threat_deathrattle` 1 — F2 `threat(m) … + (deathrattle ? 1 : 0)`;
## - `flat_spell_damage` 2 / `flat_deathrattle` 1 / `flat_aura` 2 — F2
##   `flat_bonus` (per Spell Damage point, Deathrattle, aura);
## - `weapon_bv` 0.8 — F2 `BV(weapon) = attack · durability · 0.8`;
## - `card_norm` 3 — F1 `f_card` divisor;
## - `trade_even_band` 0.2 — F3 "`|BV(D) − BV(A)| ≤ 0.2·BV(A)` → 0";
## - `board_full_threat` 1.25 — Edge Cases "If the boss board is full",
##   closing paragraph, and C6: `w_threat × 1.25` while the player's board
##   holds `BOARD_SIZE` minions;
## - `defensive_taunt_bv` 0.5 — States and Transitions `DEFENSIVE`: "Taunt
##   minions gain +0.5 board value in F2".
const NORMALISERS: Dictionary = {
	"taunt_bonus": 1.5,
	"threat_windfury": 0.5,
	"threat_deathrattle": 1.0,
	"flat_spell_damage": 2.0,
	"flat_deathrattle": 1.0,
	"flat_aura": 2.0,
	"weapon_bv": 0.8,
	"card_norm": 3.0,
	"trade_even_band": 0.2,
	"board_full_threat": 1.25,
	"defensive_taunt_bv": 0.5,
}

## Keyword and trigger names the F2 terms read (DD-M09 keywords; Card Effects
## C2 triggers). Taunt, Windfury and Spell Damage use the rules-tier names.
const KEYWORD_DEATHRATTLE: String = "deathrattle"
const TRIGGER_AURA: String = "aura"

## C6 `aoe` derivation: the ops that count, and the selectors (from the
## caster's side) that make them area effects.
const AOE_OPS: Array[String] = ["damage", "destroy", "freeze", "silence"]
## The two stat ops of C6's "negative `buff`/`set_stats`" clause, and the
## structural op whose inner ops sit under `options[].ops`.
const OP_BUFF: String = "buff"
const OP_SET_STATS: String = "set_stats"
const OP_CHOOSE_ONE: String = "choose_one"
const AOE_SELECTORS: Array[String] = ["all_enemy_minions", "all_minions", "all_enemy_characters", "all_characters"]
## The stat fields of a `buff` / `set_stats` op (Card Effects C5).
const STAT_FIELDS: Array[String] = ["attack", "health"]

var _db: Variant
var _keyword_values: Dictionary


## [param db] answers `card(def_id)` (the frozen `CardDatabase`, or a test
## double) for the F2 flat bonuses and C6 synergy; [param keyword_values] is
## the `ai_profiles` `keyword_values` map (F2 `keyword_mult`). Both are read
## only.
func _init(db: Variant, keyword_values: Dictionary) -> void:
	_db = db
	_keyword_values = keyword_values


## Scores every command of [param candidates] on [param sandbox] (a
## `RulesEngine.clone()` of the live engine — never the live engine) and
## returns the entries of [method score] sorted best first (equal scores keep
## candidate order; each entry gains `index`, its position in
## [param candidates]). A **coroutine** (ADR-0006 erratum): it awaits
## `planner.checkpoint()` after every evaluation, so every caller awaits it.
## [param planner] is the running [PlannerTask].
## [codeblock]
## var scored: Array = await scorer.score_all(base, cmds, profile, Scorer.MODE_NORMAL, {"aoe_seen": seen}, planner)
## [/codeblock]
func score_all(sandbox: RulesEngine, candidates: Array, profile: Dictionary, mode: StringName, context: Dictionary, planner: PlannerTask) -> Array:
	var shared: Dictionary = context.duplicate()
	if not shared.has(CONTEXT_CARD_PLAYABLE):
		shared[CONTEXT_CARD_PLAYABLE] = card_playable(sandbox)
	var scored: Array[Dictionary] = []
	for index: int in candidates.size():
		var entry: Dictionary = score(candidates[index], sandbox, profile, mode, shared)
		entry["index"] = index
		scored.append(entry)
		await planner.checkpoint()
	scored.sort_custom(_better)
	return scored


## One candidate's one-ply score (F1). [param sandbox_before] is the base
## clone; [param profile] the resolved profile (`weights` already multiplied
## for DEFENSIVE by story 009; `rules.BV_NORM`, `THREAT_NORM`, `trade_ratio`,
## `overextend_cap_aoe`, `assume_aoe` read from it); [param mode] one of the
## `MODE_*` constants; [param context] `{aoe_seen: bool, card_playable:
## bool}` (`aoe_seen`: C1.3, F5 — see [method aoe_seen_in]; `card_playable`:
## whether a `play_card` is legal on the base, for the F9 `spare_mana` rule —
## [method score_all] fills it once, else a `use_hero_power` candidate reads it
## from the base's `legal_commands()`). Returns `{command, score, features, sim_overflow,
## sim_choice_placeholder}`: `features` has exactly [constant FEATURE_KEYS],
## each in [−1, 1] (C5); a trial that faults `resolution_overflow`, or is
## rejected, scores `-INF` with zero features (`sim_overflow` true for the
## former; Edge Cases).
## [codeblock]
## var entry: Dictionary = scorer.score(MatchRecords.end_turn("boss"), base, profile, Scorer.MODE_NORMAL, {})
## entry.features.f_mana   # −mana_left / mana_max
## [/codeblock]
func score(candidate: Dictionary, sandbox_before: RulesEngine, profile: Dictionary, mode: StringName, context: Dictionary) -> Dictionary:
	var own: String = String(sandbox_before.active_side())
	var before: Dictionary = _measure(sandbox_before, mode)
	var entry: Dictionary = {"command": candidate, "score": 0.0, "features": {}, "sim_overflow": false, "sim_choice_placeholder": false}
	var after: Dictionary = before
	if str(candidate.get("type")) != MatchRecords.CMD_END_TURN:
		var trial: RulesEngine = sandbox_before.clone()
		var result: Dictionary = trial.submit(candidate.duplicate(true))
		if result.accepted:
			entry.sim_choice_placeholder = _answer_choices(trial, own)
		var outcome: Variant = trial.result()
		var overflow: bool = outcome is Dictionary and str(outcome.get("reason")) == MatchRecords.REASON_RESOLUTION_OVERFLOW
		if not result.accepted or overflow:
			trial.end_match()
			entry.sim_overflow = overflow
			entry.score = -INF
			entry.features = _zero_features()
			return entry
		after = _measure(trial, mode)
		trial.end_match()
	var features: Dictionary = _features(candidate, own, before, after, profile, context, sandbox_before)
	entry.features = features
	entry.score = weighted_sum(features, effective_weights(profile, before[other_side(own)].board_size == sandbox_before.rule("board_size")))
	return entry


## Whether [param sandbox]'s `legal_commands()` hold a `play_card` (F9
## `spare_mana`: "no card is playable with the remaining mana").
static func card_playable(sandbox: RulesEngine) -> bool:
	for command: Dictionary in sandbox.legal_commands():
		if str(command.type) == MatchRecords.CMD_PLAY_CARD:
			return true
	return false


## The `ai_decision.alternatives` of [param scored] (C9: at most
## [constant ALTERNATIVES_MAX] of `{command, score, features}`, best first) —
## [param scored] as [method score_all] returns it.
static func alternatives(scored: Array) -> Array:
	var out: Array = []
	for entry: Dictionary in scored.slice(0, ALTERNATIVES_MAX):
		out.append({"command": entry.command, "score": entry.score, "features": entry.features})
	return out


## The weights a score uses: [param profile]'s `weights`, with `w_threat`
## multiplied by the `board_full_threat` normaliser when
## [param player_board_full] (Edge Cases "board full", A18). A new Dictionary.
static func effective_weights(profile: Dictionary, player_board_full: bool) -> Dictionary:
	var weights: Dictionary = (profile.weights as Dictionary).duplicate()
	if player_board_full:
		weights["w_threat"] = float(weights["w_threat"]) * float(NORMALISERS.board_full_threat)
	return weights


## F1: `Σ w_i · f_i` over [constant FEATURE_KEYS] (`f_board` pairs with
## `w_board`, …). Every weight must be present: there is no code default (A29).
static func weighted_sum(features: Dictionary, weights: Dictionary) -> float:
	var total: float = 0.0
	for key: String in FEATURE_KEYS:
		total += float(weights["w" + key.substr(1)]) * float(features[key])
	return total


## F2 `BV(m) = (attack + health) · Π keyword_mult(k) + Σ flat_bonus(k)` for a
## minion with [param attack], [param health] and [param keywords];
## [param keyword_values] is the `keyword_mult` map (a keyword with no row
## multiplies by 1); [param spell_damage] its Spell Damage points,
## [param has_aura] whether it holds an aura, [param defensive] adds the
## DEFENSIVE Taunt bonus.
## [codeblock]
## Scorer.board_value(3, 2, ["divine_shield", "taunt"], {"taunt": 1.2, "divine_shield": 1.3})   # 7.8 (F2 example)
## [/codeblock]
static func board_value(attack: int, health: int, keywords: Array, keyword_values: Dictionary, spell_damage: int = 0, has_aura: bool = false, defensive: bool = false) -> float:
	var value: float = float(attack + health)
	for keyword: Variant in keywords:
		value *= float(keyword_values.get(keyword, 1.0))
	value += float(spell_damage) * float(NORMALISERS.flat_spell_damage)
	if keywords.has(KEYWORD_DEATHRATTLE):
		value += float(NORMALISERS.flat_deathrattle)
	if has_aura:
		value += float(NORMALISERS.flat_aura)
	if defensive and keywords.has(MatchRecords.KEYWORD_TAUNT):
		value += float(NORMALISERS.defensive_taunt_bv)
	return value


## F2 `threat(m) = attack · (1 + 0.5·windfury) + taunt_bonus + (deathrattle ? 1 : 0)`.
## [codeblock]
## Scorer.threat(3, ["taunt"], false)   # 4.5 (F2 example)
## [/codeblock]
static func threat(attack: int, keywords: Array, windfury: bool) -> float:
	var value: float = float(attack) * (1.0 + (float(NORMALISERS.threat_windfury) if windfury else 0.0))
	if keywords.has(MatchRecords.KEYWORD_TAUNT):
		value += float(NORMALISERS.taunt_bonus)
	if keywords.has(KEYWORD_DEATHRATTLE):
		value += float(NORMALISERS.threat_deathrattle)
	return value


## F2 `BV(weapon) = attack · durability · 0.8`.
static func weapon_value(attack: int, durability: int) -> float:
	return float(attack * durability) * float(NORMALISERS.weapon_bv)


## F3 trade quality of a minion attacking a minion: +1 when the defender dies
## and the attacker survives, or both die and `BV(D) ≥ BV(A)·trade_ratio`; 0
## when both die and `|BV(D) − BV(A)| ≤ 0.2·BV(A)`; −1 otherwise (the attacker
## dies for nothing, or neither dies). BVs are the pre-attack values.
## [codeblock]
## Scorer.trade_quality(8.0, 7.0, true, true, 1.0)   # 0 (F3 example: a 4/4 into a 5/2)
## [/codeblock]
static func trade_quality(attacker_bv: float, defender_bv: float, attacker_dies: bool, defender_dies: bool, trade_ratio: float) -> int:
	if defender_dies and not attacker_dies:
		return 1
	if defender_dies and defender_bv >= attacker_bv * trade_ratio:
		return 1
	if defender_dies and absf(defender_bv - attacker_bv) <= float(NORMALISERS.trade_even_band) * attacker_bv:
		return 0
	return -1


## C6 `aoe`: whether any effect of the card definition [param def] has a
## `damage`, `destroy`, `freeze` or `silence` op — or a `buff` with a negative
## `attack`/`health`, or a `set_stats` — whose selector (the op's own
## `targets`, else its effect's) is one of [constant AOE_SELECTORS]. Inner ops
## of `conditional` / `repeat` / `choose_one` count. A `set_stats` counts
## whatever its values (it overwrites the stats of every minion it reaches).
## Pure; story 005's `derive_annotations` reuses it.
static func is_aoe(def: Variant) -> bool:
	if not def is Dictionary or not def.get("effects") is Array:
		return false
	for effect: Variant in def.effects:
		if effect is Dictionary and effect.get("ops") is Array and _ops_aoe(effect.ops, effect.get("targets")):
			return true
	return false


## C1.3 / F5: whether [param events] (public log events, in order) hold a
## `card_played` by [param opponent] of a card that [method is_aoe] calls an
## area effect; [param db] answers `card(card_id)`. Reads only `card_played`
## (public: the card was revealed by being played), never `card_drawn` or any
## hand field. The caller ORs the result into its one cross-turn memory.
## [codeblock]
## aoe_seen = aoe_seen or Scorer.aoe_seen_in(log.events_since(last_seq), db, "player")
## [/codeblock]
static func aoe_seen_in(events: Array, db: Variant, opponent: String) -> bool:
	for event: Variant in events:
		if not event is Dictionary or StringName(str(event.get("type"))) != &"card_played":
			continue
		var payload: Dictionary = event.get("payload", {})
		if str(payload.get("side")) == opponent and is_aoe(_definition(db, str(payload.get("card_id")))):
			return true
	return false


## C6 `synergy_match(card, tags)`: the definition [param def] has a Card
## Database `tags` entry, a keyword, or an effect trigger name in [param tags].
static func synergy_match(def: Variant, tags: Array) -> bool:
	if tags.is_empty() or not def is Dictionary:
		return false
	for field: String in ["tags", "keywords"]:
		for value: Variant in def.get(field, []):
			if tags.has(value):
				return true
	for effect: Variant in def.get("effects", []):
		if effect is Dictionary and tags.has(effect.get("trigger")):
			return true
	return false


# --- internals -------------------------------------------------------------------

## Answers boss-side Choices the trial raised with option 0 until story 010's
## `choose` exists; returns whether it answered any.
func _answer_choices(trial: RulesEngine, own: String) -> bool:
	var answered: bool = false
	while trial.phase() == MatchState.PHASE_CHOICE:
		var pending: Variant = trial.pending_choice()
		if not pending is Dictionary or str(pending.side) != own:
			break
		answered = true
		if not trial.submit(MatchRecords.choose(own, 0)).accepted:
			break
	return answered


## The F1 features of [param candidate] from the two measurements.
func _features(candidate: Dictionary, own: String, before: Dictionary, after: Dictionary, profile: Dictionary, context: Dictionary, base: RulesEngine) -> Dictionary:
	var rules: Dictionary = profile.rules
	var opp: String = other_side(own)
	var b_own: Dictionary = before[own]
	var a_own: Dictionary = after[own]
	var b_opp: Dictionary = before[opp]
	var a_opp: Dictionary = after[opp]
	var type: String = str(candidate.get("type"))
	var board_size: int = base.rule("board_size")
	var features: Dictionary = _zero_features()

	features.f_board = ((a_own.bv - b_own.bv) - (a_opp.bv - b_opp.bv)) / float(rules.BV_NORM)
	features.f_face = float(maxi(0, b_opp.effective_hp - a_opp.effective_hp)) / float(maxi(1, b_opp.health))
	features.f_self = -float(maxi(0, b_own.effective_hp - a_own.effective_hp)) / float(maxi(1, b_own.health))
	if type == MatchRecords.CMD_ATTACK:
		var attacker_id: int = int(candidate.get("attacker_id", RulesEngine.NO_ENTITY))
		var target_id: int = int(candidate.get("target_id", RulesEngine.NO_ENTITY))
		if b_own.minions.has(attacker_id) and b_opp.minions.has(target_id):
			features.f_trade = float(trade_quality(b_own.minions[attacker_id].bv, b_opp.minions[target_id].bv,
				not a_own.minions.has(attacker_id), not a_opp.minions.has(target_id), float(rules.trade_ratio)))
	var removed_threat: float = 0.0
	for id: int in b_opp.minions:
		if not a_opp.minions.has(id):
			removed_threat += b_opp.minions[id].threat
	features.f_threat = removed_threat / float(rules.THREAT_NORM)
	if type == MatchRecords.CMD_END_TURN:
		features.f_mana = -float(b_own.mana_current) / float(maxi(1, b_own.mana_max))
	else:
		features.f_mana = float(maxi(0, b_own.mana_current - a_own.mana_current)) / float(maxi(1, b_own.mana_max))
	features.f_card = float((a_own.count - b_own.count) - (a_opp.count - b_opp.count)) / float(NORMALISERS.card_norm)
	var aoe_seen: bool = bool(context.get("aoe_seen", false)) or bool(rules.get("assume_aoe", false))
	var cap: int = int(rules.overextend_cap_aoe) if aoe_seen else board_size
	features.f_over = -float(maxi(0, a_own.board_size - cap)) / float(board_size)
	features.f_heal = float(maxi(0, a_own.health - b_own.health)) / float(maxi(1, b_own.max_health - b_own.health))
	if type == MatchRecords.CMD_USE_HERO_POWER:
		var playable: bool = bool(context[CONTEXT_CARD_PLAYABLE]) if context.has(CONTEXT_CARD_PLAYABLE) else card_playable(base)
		features.f_hp = CandidateSet.hero_power_feature(str(rules.hero_power), playable)
	if type == MatchRecords.CMD_PLAY_CARD:
		var hand_index: int = int(candidate.get("hand_index", -1))
		if hand_index >= 0 and hand_index < b_own.hand_defs.size():
			features.f_passive = 1.0 if synergy_match(_definition(_db, b_own.hand_defs[hand_index]), profile.get("synergy_tags", [])) else 0.0
	for key: String in FEATURE_KEYS:
		features[key] = clampf(features[key], -1.0, 1.0)
	return features


## Per side of [param engine] (a sandbox clone): hero `health`, `max_health`,
## `effective_hp` (health + armor), mana, `count` (hand + board), `board_size`,
## `bv` (F2 over the board plus the weapon), `minions {entity_id: {bv,
## threat}}` and `hand_defs` (definition ids; read for the active side only,
## C1.3).
func _measure(engine: RulesEngine, mode: StringName) -> Dictionary:
	var state: MatchState = engine.state()
	var active: String = String(engine.active_side())
	var out: Dictionary = {}
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = state.players[side]
		var hero: Dictionary = player.hero
		var minions: Dictionary = {}
		var bv: float = 0.0
		for minion: Dictionary in player.board:
			var keywords: Array = _keywords(minion)
			var def: Variant = _definition(_db, str(minion.def_id))
			var silenced: bool = bool(minion.get("silenced", false))
			var spell_damage: int = int(def.get("spell_damage", 0)) if def is Dictionary and keywords.has(RulesEngine.KEYWORD_SPELL_DAMAGE) else 0
			var has_aura: bool = not silenced and def is Dictionary and _has_trigger(def, TRIGGER_AURA)
			var value: float = board_value(engine.attack(minion), engine.health(minion), keywords, _keyword_values, spell_damage, has_aura, mode == MODE_DEFENSIVE)
			minions[int(minion.entity_id)] = {"bv": value, "threat": threat(engine.attack(minion), keywords, engine.has_windfury(minion))}
			bv += value
		var weapon: Variant = player.weapon
		if weapon is Dictionary:
			var weapon_attack: int = int(weapon.attack)
			for enchantment: Dictionary in weapon.enchantments:
				weapon_attack += int(enchantment.attack_delta)
			bv += weapon_value(weapon_attack, int(weapon.durability))
		var hand_defs: Array = []
		if side == active:
			for card: Dictionary in player.hand:
				hand_defs.append(str(card.def_id))
		var health: int = engine.health(hero)
		out[side] = {
			"health": health,
			"max_health": engine.max_health(hero),
			"effective_hp": health + int(hero.armor),
			"mana_current": int(player.mana_current),
			"mana_max": int(player.mana_max),
			"count": (player.hand as Array).size() + (player.board as Array).size(),
			"board_size": (player.board as Array).size(),
			"bv": bv,
			"minions": minions,
			"hand_defs": hand_defs,
		}
	return out


## The keywords of [param character] (a minion or hero record): its own set
## plus every enchantment's `keywords_added`, without duplicates.
static func keywords_of(character: Dictionary) -> Array:
	return _keywords(character)


static func _keywords(character: Dictionary) -> Array:
	var keywords: Array = (character.keywords as Array).duplicate()
	for enchantment: Dictionary in character.enchantments:
		for keyword: Variant in enchantment.keywords_added:
			if not keywords.has(keyword):
				keywords.append(keyword)
	return keywords


static func _has_trigger(def: Dictionary, trigger: String) -> bool:
	for effect: Variant in def.get("effects", []):
		if effect is Dictionary and str(effect.get("trigger")) == trigger:
			return true
	return false


static func _ops_aoe(ops: Array, inherited: Variant) -> bool:
	for op: Variant in ops:
		if not op is Dictionary:
			continue
		var op_name: String = str(op.get("op"))
		var selector: Variant = op.get("targets", inherited)
		if BossAI.STRUCTURAL_OPS.has(op_name):
			for param: String in BossAI.STRUCTURAL_OPS[op_name]:
				var inner: Variant = op.get(param)
				if not inner is Array:
					continue
				if op_name == OP_CHOOSE_ONE:
					for option: Variant in inner:
						if option is Dictionary and option.get("ops") is Array and _ops_aoe(option.ops, selector):
							return true
				elif _ops_aoe(inner, selector):
					return true
			continue
		if not AOE_SELECTORS.has(selector_name(selector)):
			continue
		if AOE_OPS.has(op_name) or op_name == OP_SET_STATS:
			return true
		if op_name == OP_BUFF:
			for field: String in STAT_FIELDS:
				var value: Variant = op.get(field)
				if BossAI.is_number(value) and float(value) < 0.0:
					return true
	return false


## The Card Effects C3 selector name of [param selector] — a String, or the
## `selector` of an object-form selector; "" for none.
static func selector_name(selector: Variant) -> String:
	if selector is Dictionary:
		return str(selector.get("selector", ""))
	return str(selector) if selector is String else ""


static func _definition(db: Variant, def_id: String) -> Variant:
	if db == null or def_id.is_empty():
		return null
	return db.card(def_id)


## The opponent of [param side] (`player` ↔ `boss`).
static func other_side(side: String) -> String:
	return MatchRecords.SIDE_PLAYER if side == MatchRecords.SIDE_BOSS else MatchRecords.SIDE_BOSS


static func _zero_features() -> Dictionary:
	var features: Dictionary = {}
	for key: String in FEATURE_KEYS:
		features[key] = 0.0
	return features


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if a.score != b.score:
		return a.score > b.score
	return int(a.index) < int(b.index)
