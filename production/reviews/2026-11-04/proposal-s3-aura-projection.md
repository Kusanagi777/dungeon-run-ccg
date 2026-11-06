# Proposal: S3, how aura changes reach the match view

**Decision needed:** how aura changes to keywords and hand cost reach the event log, and how `MatchViewState` projects them, so that Gatekeeper's minions show Taunt.

**Today:** `_recompute_auras` (rules_engine.gd:2975) compares only attack and health. Aura applies made during a recompute log nothing, and the view's `auras_recomputed` branch is `pass`. The docs disagree in three places:
- match-rules C10 says "net stat changes";
- match-ui U3 rule 3 says "zero steps", while its table says "Stats, keywords, flags" plus a step;
- card-effects 013 AC-32 expects an `enchantment_applied` event that a recompute never emits.

## Options

**(A) A separate `aura_changed` event for each entity**
- **Player sees:** correct badges, stats and costs, in step with playback.
- **Replay:** deterministic; adds a new type to C15, the rng-event-log §D catalogue and F6.
- **Log size:** one envelope per changed entity. A board-wide aura entering play logs up to about 15. This breaks C10's "one event" rule (spike finding 8).
- **Stories:** card-effects 012, match-ui 001, card-effects 013 AC-32.
- **Size:** M.

**(B) The view re-reads `MatchQuery` after each step**
- **Player sees:** the end-of-command state before playback reaches it, so Taunt lights up before the minion has grown in. Breaks U2.
- **Replay:** the view stops being a pure function of events (ADR-0001), and an archived log can't rebuild the board.
- **Log size:** none.
- **Stories:** match-ui 001 and 003.
- **Size:** S in code, but it reverses an ADR.

**(C) Make the existing `auras_recomputed` event carry absolute values (recommended)**
- **Payload:** still one event per non-empty recompute. Each `changes[]` entry carries the entity's full current values:
  - character or weapon: `{entity_id, attack, health, max_health, keywords[]}`, the full effective keyword set;
  - player hand card: `{instance_id, zone: "hand", effective_cost}`;
  - boss hand cards are left out (U3 rule 2: hidden information).
- **Projection:** replaces the fields (not deltas), with one parallel recolour or badge step per entry. `hand.md` §10 already expects this.
- **Player sees:** the Taunt badge, the warlord's +1 Attack and discounted cost stamps, in step with playback. Which source buffs what stays a hover query.
- **Replay:** deterministic. Five test files assert the old payload shape and need updating.
- **Log size:** no new envelopes; each entry gains a short keyword list.
- **Stories:**
  - card-effects 012: engine diff, about 20 lines;
  - match-ui 001: projection, about 30 lines;
  - card-effects 013 AC-32: reword it to check `auras_recomputed` plus `entity().enchantments[].source_id`;
  - match-ui 006: cost stamp comes from the projection.
  - GDD edits: match-rules C10/C15, match-ui U3 rule 3 and table, rng-event-log §D.
- **Size:** S to M.

## Recommendation: (C)

It is the smallest change that keeps ADR-0001's pure projection and C10's one-event rule. Absolute values make re-applying an event harmless, and one payload definition settles all three disagreements. It must land before card-effects 013/015 (Gatekeeper's passive) and match-ui 007. Decide S2 (aura Divine Shield) in the same review, because (C) makes that bug visible in the log.
