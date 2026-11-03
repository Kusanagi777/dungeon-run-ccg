# Match Rules

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: `/design-system` (game-designer role) for the owner. `systems-designer`, `ai-programmer`, `qa-lead` and `art-director` not consulted — Lean mode (no `Agent` tool available in this run). Review manually before production.
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 4 (Readable, deterministic rules) primarily; Pillar 2 (Bosses are puzzles) and Pillar 3 (Lose fast, learn fast) secondarily
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` Feasibility: no engine reference for `scripting` under `docs/engine-reference/godot/modules/`; feasibility not checked against the pinned engine (this system is pure GDScript `RefCounted` logic with no engine surface, DD-T02). No ADRs exist yet; DD-T02/DD-T03 cite ADR-0001/ADR-0003 as planned.
> **Design decisions honoured**: DD-M01–DD-M13, DD-T02–DD-T04 (`design/design-decisions.md`). Numbers refined only in Tuning Knobs; owner rows unchanged.

## Summary

[To be designed]

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Card Database, RNG & Event Log`

## Overview

Match Rules is the referee of a single Deckdelve duel: the player's hero against one boss, each
with a deck, a hand, a row of up to seven minions, mana crystals that grow by one per turn, and a
hero power. It owns everything that makes a move legal or illegal and everything that happens when
a move resolves — turn structure, mana and costs, playing minions, spells and weapons, attacking,
damage and armour math, the fifteen v1 keywords (DD-M09), death and trigger ordering, hand burn,
fatigue, and the win/loss decision. It is a pure, engine-free `RulesEngine` over a plain
`MatchState` (DD-T02): callers (the Match UI for the player, Boss AI for the boss) send a small set
of **commands** — `mulligan`, `play_card`, `attack`, `use_hero_power`, `choose`, `end_turn`,
`concede` — and receive either an accepted result or a **typed rejection**; every state mutation
emits exactly one event to the RNG & Event Log (DD-T04). The engine never decides what a card
*does* — card text is resolved by Card Effects through hook points this document names — it decides
*when* effects fire, *in what order*, and *what the board looks like afterwards*.

For the player, this system is the whole moment-to-moment game: reading the board, spending mana,
choosing attacks, watching the boss answer. Without it there is no "inner game" for the run to
wrap (systems-index: "two games stacked"); with it done right, every loss is explainable from the
event log alone, which is what Pillar 4 demands and what Pillars 2 and 3 need in order to make
bosses learnable puzzles.

## Player Fantasy

*Framing: Direct — the player operates this system on every turn.* `creative-director` not
consulted — Lean mode. Review manually before production.

**The fantasy is total legibility under pressure.** The player should feel like a chess player
who can see the whole board, not a gambler waiting on a roll: "I have 6 mana, their Taunt has 3
health, my weapon has 2 swings left — if I trade here and go face there, that is exactly lethal."
When the plan works, the pleasure is the plan; when it fails, the player should be able to point
at the event log and say "*that* is the line I missed." This is Pillar 4 verbatim: *"If the player
cannot tell why they lost, the rules failed."*

- **Reference feeling**: Hearthstone's attack-and-trade clarity (one row, attacker and defender both
  hurt, numbers visible on the card) combined with Slay the Spire's telegraphed enemy intents —
  the board tells you what will happen before you commit. We borrow the *certainty of outcome*
  from both.
- **Anti-reference**: hidden-information engines where an off-screen passive or an undocumented
  trigger order changes a result. A boss passive (Pillar 2) is allowed to bend the rules; it is
  never allowed to do so silently.
- **The anchor moment**: the end of a turn where the player counts lethal, executes it in three
  commands, and the engine resolves every step in the order they expected. The secondary moment is
  the *near miss*: the boss survives at 1 because a Divine Shield they forgot ate one point, and the
  log shows exactly that.
- **Emotional texture**: deliberate, never frantic. There are no timers (MDA: Submission — low
  stress), so the engine's job is to be *trustworthy*, not *fast*; speed is the Match UI's job.

## Detailed Design

### Core Rules

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## Game Feel

[To be designed]

## UI Requirements

[To be designed]

## Cross-References

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
