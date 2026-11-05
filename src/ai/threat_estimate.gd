## What the opposing board could do to a side next turn (design/gdd/boss-ai.md F6,
## F1 vulnerability exception; ADR-0006; TR-boss-ai-001; boss-ai-match-driver
## story 009; 2026-11-04, DD-X22).
##
## Two measures over one count, the opponent's minions at `attack × max_attacks`
## plus its weapon. `frozen` and summoning-sick minions count (F6):
## - [method incoming], F6's trigger for DEFENSIVE, adds the `burn_per_mana` guess
##   at the unknown hand;
## - [method reach], F1's test of one action, is the board alone, less the health
##   of the side's Taunts. The hand is hidden (C1.3), and the guess would flag
##   almost every late attack.
##
## Pure reads of a sandbox: its derived values and `state()`, like [Scorer]. The
## player's hand is never read.
## [codeblock]
## var rules: Dictionary = profile.rules
## ThreatEstimate.incoming(sandbox, rules, MatchRecords.SIDE_BOSS)    # 16.0 (F6 example)
## ThreatEstimate.defensive(sandbox, rules, MatchRecords.SIDE_BOSS)   # true at boss 18, margin 3
## [/codeblock]
class_name ThreatEstimate
extends RefCounted


## F6 `incoming` against [param own]: the opposing board plus `burn_per_mana ×
## mana_max_player_next_turn`. A `float`, as `burn_per_mana` is.
static func incoming(sandbox: RulesEngine, rules: Dictionary, own: String) -> float:
	var opponent: String = Scorer.other_side(own)
	return float(_board_damage(sandbox, opponent)) + float(rules.burn_per_mana) * float(Chooser.next_mana_max(sandbox, opponent))


## F6: whether [param own] should score DEFENSIVE, `incoming ≥ boss_health +
## boss_armor − defensive_margin`. The band's `rules.defensive` gate is the caller's.
static func defensive(sandbox: RulesEngine, rules: Dictionary, own: String) -> bool:
	return incoming(sandbox, rules, own) >= float(_line(sandbox, rules, own))


## F1 `reach(s)` against [param own]: the opposing board less the health of
## [param own]'s Taunts (F4's term). Can be negative.
## [codeblock]
## ThreatEstimate.reach(sandbox, MatchRecords.SIDE_BOSS)   # 9 on F1's example
## [/codeblock]
static func reach(sandbox: RulesEngine, own: String) -> int:
	return _board_damage(sandbox, Scorer.other_side(own)) - _taunt_health(sandbox, own)


## F1 `unsafe(s)`: `reach(s) ≥ boss_health + boss_armor − defensive_margin`.
static func unsafe(sandbox: RulesEngine, rules: Dictionary, own: String) -> bool:
	return reach(sandbox, own) >= _line(sandbox, rules, own)


## [param own]'s health plus armor, the side of the F1 `f_self` fraction.
static func effective_hp(sandbox: RulesEngine, own: String) -> int:
	var hero: Dictionary = sandbox.state().players[own].hero
	return sandbox.health(hero) + int(hero.armor)


static func _line(sandbox: RulesEngine, rules: Dictionary, own: String) -> int:
	return effective_hp(sandbox, own) - int(rules.defensive_margin)


static func _board_damage(sandbox: RulesEngine, side: String) -> int:
	var player: Dictionary = sandbox.state().players[side]
	var total: int = 0
	for minion: Dictionary in player.board:
		total += sandbox.attack(minion) * sandbox.max_attacks(minion)
	var weapon: Variant = player.weapon
	if weapon is Dictionary:
		total += int(weapon.attack)
		for enchantment: Dictionary in weapon.enchantments:
			total += int(enchantment.attack_delta)
	return total


static func _taunt_health(sandbox: RulesEngine, side: String) -> int:
	var total: int = 0
	for minion: Dictionary in sandbox.state().players[side].board:
		if LethalSearch.is_taunter(minion):
			total += sandbox.health(minion)
	return total
