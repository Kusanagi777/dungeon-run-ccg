# Treasures

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob (owner) + Claude (`/design-system treasures`, tier standard, guided, lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 1 (every run builds a deck you couldn't have planned) · Pillar 4 (readable, deterministic rules)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` `systems-designer` and `qa-lead` not consulted for Formulas / Acceptance Criteria — Lean mode, no Agent tool in this session; review manually before production. Technical feasibility: category `Gameplay`, rule-only → Scripting domain; no engine reference for `scripting` under `docs/engine-reference/godot/modules/`, so feasibility was **not** checked against the pinned engine (the design has no engine surface: plain `RefCounted` data, DD-T02). Prior art: `docs/architecture/modifier-hook-chain.md` (reverse-documented prototype, not an ADR).

## Summary

[To be designed]

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `[To be designed]`

## Overview

A treasure is a passive, run-long rule change the player picks after winning on floors 1, 3 and 5
(DD-R05): "your hero power costs (1)", "your minions have Rush", "start each match with an extra
Mana Crystal". The player does nothing with a treasure during a match — it sits in a tray on the
HUD and bends the rules in their favour every match for the rest of the run. Mechanically a
treasure is a `TreasureDef` record whose `effects[]` are written in the Card Effects DSL using the
hook-hosted triggers; at every match start Run Structure hands Treasures the run's picked ids in
pick order, Treasures returns one hook installer per treasure, and Match Rules installs them into
the match's own `HookRegistry` — treasures first in pick order, the boss passive last. Nothing is
applied at pick time and nothing survives the match except the id list, which is what makes
save/resume and restart idempotent. The system exists because Pillar 1 needs a draft pick that
changes *how the deck plays*, not just what is in it (the concept doc: "treasures are run-defining
rather than stat bumps"), and because boss passives need the same machinery from the other side of
the board (Pillar 2). It retires TD-009 — the prototype's global, singleton-backed modifier
manager — with a per-match, owner-scoped chain that holds no Node and no back-reference.

## Player Fantasy

`creative-director` not consulted — Lean mode. Review manually before production.

**Framing: direct.** The player chooses a treasure, reads it on the HUD every match and watches
the event feed credit it by name ("Thornhide Cloak: +1 Armour"). The feeling is **getting away
with something**: the rules everyone else plays by have one clause crossed out for you. A treasure
pick should feel like the moment in Monster Train or Dungeon Run where you stop asking "is this
card good?" and start asking "what does my run *do* now?" — the pick that turns a pile of drafted
cards into a plan. Pillar 1's design test applies verbatim: between a treasure that is "generically
good" and one that is "strong only with a plan", the pool leans to the plan-dependent one, so
roughly half the pool carries a hero or plan tag (Husks, weapons, spells) and the universal half
still changes a decision every turn (first card cheaper, hero power cheaper) rather than adding a
number nobody notices.

Three anchor moments: (1) **the reveal** — three cards face up after a win, each one sentence,
each obviously bending a different rule; (2) **the first fire** — the next match's first turn,
when the treasure visibly does its thing before any card is drawn (an extra crystal, a bigger
hand, a flare on the tray); (3) **the lean-in** — two floors later, passing a stronger bundle for
the one that feeds the treasure. Anti-reference: Slay the Spire's early-act relics that only add
+N to a stat — legible, but they never change a decision. Pillar 4 keeps the fantasy honest: every
treasure effect is one log line with the treasure as `source_id`, so "why did that cost 1?" is
always answerable.

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
