# Match UI

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob (owner) + Claude (`/design-system match-ui`, tier standard, guided, lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 4 (readable, deterministic rules — the UI is a projection of the event log); Pillar 3 (lose fast, learn fast — every loss is legible on screen); Sensation aesthetic (crisp card feedback)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` No `Agent` tool in this run: `game-designer`, `ux-designer`, `ui-programmer`, `art-director`, `systems-designer` and `qa-lead` not consulted — Lean mode. Review manually before production.
> **Scope boundary**: this GDD defines the Match UI as a *system* — what it must do, its architecture and its contracts with the rules engine. Per-screen UX specs (pixel layout, copy, focus order) are produced later by `/ux-design` into `design/ux/` and cite this document.

## Summary

[To be designed]

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Match Rules, Card Effects, Boss AI, Card Database, RNG & Event Log`

## Overview

The Match UI is the Godot scene layer that turns a match into something the player can see and
touch: a hand fan, two rows of minion tokens, two hero portraits with health, armour, weapon and
hero power, a mana bar, a targeting arrow, the boss's intent banner, a mulligan screen, a Choice
overlay for Discover and Choose One, an event feed, and the end-of-match banner. The player plays
by dragging cards from the hand to the board or onto a target, dragging an attacker onto a
defender, pressing the hero power, and pressing End Turn; everything else on screen is feedback.
Underneath, the system is deliberately thin and one-directional (DD-T02, DD-T04): it **sends
commands** to the rules engine through a `MatchController`, **receives events** from the event log
through `subscribe` / `events_since`, projects those events into a presentation model, and plays
the difference as a queue of short, skippable animations. It never reads or writes `MatchState`
directly; the only read path is a read-only `MatchQuery` for hover text and legal-move
highlighting. The game would lose nothing in its rules without this system — the engine runs
headless — but it would lose the game: Pillar 4 promises that the player can always tell *why*
something happened, and the Match UI is where that promise is kept.

## Player Fantasy

`creative-director` not consulted — Lean mode. Framing: **direct** — the player operates this
system every second of a match.

The feeling is **a table you can read at a glance and a hand that obeys you**. Picking up a card
should feel like picking up a physical card: it lifts, it follows the cursor without lag, legal
places to put it light up, and when it lands it lands with a thump and *does something visible*.
Attacks commit — the attacker lunges, both numbers change on the same frame, the row settles.
The boss's turn is a short, legible sequence of beats the player watches with the intent banner
still in view, so a loss reads as "I saw it and could not stop it" (Pillar 3), never "what just
happened". Reference: Hearthstone's card handling and attack simultaneity; Slay the Spire's
intent icons. Anti-reference: any UI where the player must open a log to find out what a card did
— here the feed is a confirmation, not a necessity, because the board already showed it.
Sensation (concept aesthetic 5) is delivered entirely by this system: snappy drag, impact on
attack, clear effect resolution, and the discipline that nothing on screen ever contradicts the
event log.

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
