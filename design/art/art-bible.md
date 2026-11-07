# Art Bible: Deckdelve (working title)

> **Status**: Approved — §1–4 (owner Jacob, 2026-11-04: "approve the art direction"; sections 5–9 remain deferred stubs)
> **Owned By**: art-director
> **Last Updated**: 2026-11-06
> **Art Director Sign-Off (AD-ART-BIBLE)**: SKIPPED 2026-11-03 — lean mode
> **Review notes**: `AD-ART-BIBLE skipped — Lean mode.` Authored at `workflow: standard`,
> `docs.density: balanced`, `automation: guided`. Scope this run: sections 1–4 (the `standard`
> minimum) with real content; sections 5–9 are deferred stubs — v1 ships placeholder art
> (flat shapes, solid fills, system text) and the final 2D stylized illustration style is an
> Alpha concern. `/asset-spec` owns per-asset specs when that time comes.
> **REVISED 2026-11-03 (ux-review)**: §4 Text table — one row added, `text_muted` (`#B8AC96`) on `table_lit` (`#4A3626`) at 5.08:1 (computed; AA at every size, AAA large only), so the HUD skip hint and the summary sub-labels can cite it instead of substituting `text_light`. Nothing else changed.
> **REVISED 2026-11-06 (runtime art)**: §1–4 are unchanged. A licensed texture pass now fills the slots those sections already fixed (parchment card, warm table, ink stamp, glyphs). It is recorded in §10 and `design/art/runtime-art.md`. Frames, radii, and the 150×210 / 90×126 / 120×160 boxes were not redrawn.
> **Foundation**: the "Torchlit Ledger" Visual Identity Anchor from
> `design/gdd/game-concept.md`, built from directly. Constants cited from
> `design/design-decisions.md` (DD-M01, DD-M08, DD-M09, DD-R01, DD-T05).

`/art-bible` writes these nine sections in this order and replaces each
section's `[To be designed]` line as that section is approved. A section still
holding its placeholder is incomplete; a later run fills only those.

## 1. Visual Identity Statement

**One-line visual rule: everything the player must read is lit; everything decorative sits in
shadow.**

This is the "Torchlit Ledger". Deckdelve is a game about reading a board, a hand and a boss
passive, then making a decision the rules will resolve deterministically (Pillar 4). The visual
identity therefore treats *light* as the one resource the art spends: brightness goes to
information, and whatever is not information — frames, table edges, chrome, flourish — recedes
into warm or cool dark. When any two things compete for the eye, the one the player has to read
wins, and it wins by being brighter, not by being busier.

Three supporting principles make the rule operational. Each is anchored in a pillar and carries a
design test that resolves ambiguity without a meeting.

1. **Cards are documents.** A card is a ledger entry: high-contrast type on a paper-coloured
   field, with fixed slots for cost, attack, health, name and rules text that never move between
   cards or card types (DD-M08: Minion, Spell, Weapon). Illustration is a stamp on the document,
   not the document itself. *Serves Pillar 4 (readable, deterministic rules) and Pillar 3 (lose
   fast, learn fast): a loss is only legible if every card could be read at the moment it mattered.*
   **Design test**: when an art treatment and text contrast are in tension, the art loses.

2. **The board is a table in a dungeon.** The play area is a torchlit tabletop — warm light
   pooled on the surface where cards are played — and the screen edges, menus and event log are
   the cool dark room around it. Light falls off from the centre outward, so the board is always
   the brightest region of the screen and UI chrome is always darker than the board. *Serves
   Pillar 2 (bosses are puzzles): the puzzle is on the table, and the table is where the eye is
   held.* **Design test**: UI chrome never competes with the play area for brightness; if a
   panel is as bright as the table, darken the panel.

3. **Heroes own a colour.** War is red-bronze, Decay is green-violet, Knowledge is blue-gold,
   and bosses wear a desaturated version of their floor band's colour (DD-R01). A hero's colour is
   carried by the hero portrait panel, the card-frame border of their class cards and the hero
   power button — identification surfaces, not information surfaces. *Serves Pillar 1 (every run
   builds a deck you couldn't have planned): the drafted deck's identity should be visible as a
   colour mix in the hand.* **Design test**: a screenshot identifies the hero without reading any
   text; if it cannot, the hero colour is being spent on something that is not the hero.

A fourth statement follows from the three and is treated as a hard constraint rather than a
principle: **saturated colour is reserved for state changes** — damage, buffs, targeting,
freeze, and what is currently actionable. The base world is warm-dark and desaturated so that
when something saturated appears, it means something just happened or something can be done.

**Placeholder translation (v1).** Flat fills, system text, no illustration. The rule survives
intact: lit = the parchment card field, the lit table rectangle, the light text; shadow = the
dark table surround and cooler screen edges. If a placeholder screen does not read correctly
with flat fills alone, the final art will not fix it.

## 2. Mood & Atmosphere

Deckdelve has few states and they must look different from each other at a glance, because the
player moves between them many times per run (eight matches, up to seven drafts, one ending).
The mood of every state is a variation on one room: a lone adventurer at a table under a torch,
deeper in the dungeon each floor. Light temperature and how much of the table is lit are the two
dials; nothing else changes between states. In v1 every "lighting" note below is implemented as
which of the four surface fills from Section 4 covers how much of the screen.

| State | Emotional target | Lighting character | Descriptors | Energy |
| --- | --- | --- | --- | --- |
| **Main menu / hero select** | Anticipation; a deliberate, unhurried choice | Cool dark room, one warm pool of light on the three hero panels; low ambient, high contrast between panel and surround | quiet, expectant, uncluttered, candlelit | contemplative |
| **Match — player turn** | Focused calm; "I can see everything I need" | Warm torchlight across the full table (`table_lit` covers both rows and the hand); edges cool and dark; highest overall brightness of any state | warm, orderly, legible, tabletop | measured |
| **Match — boss turn** | Watchful tension; the table is not yours right now | Same table, light pulled in slightly toward the boss side (the boss row and portrait at full `table_lit`, the player hand dimmed one step to `table_dark`); nothing saturated except what the boss does | held breath, dimmer, cooler at the player's edge | measured, brisk — boss turns resolve quickly |
| **Targeting / attack moment** | Commitment; a decision about to become irreversible | No lighting change — the one saturated targeting colour (amber) appears as an arrow and a ring on valid targets; everything else holds still | sharp, single-point, decisive | brief spike, then release |
| **Reward draft** | Curiosity and greed, pleasantly | Three bundles (or three treasures) in a row under the same torch; the table is cleared, so the light pool is smaller and the three offers are the only lit objects | tempting, spare, "one of three" | contemplative with a 30-second clock in the player's head, not on screen |
| **Victory (floor 8)** | Earned relief, a little disbelief | The table at full warmth plus the one time the hero colour is allowed to saturate: the hero portrait panel brightens to its full hero colour | warm, bright, generous | release, then quiet (run summary) |
| **Defeat / death screen** | Clear-eyed loss ("I see why") — never punishment | Torch out: the whole screen drops to `bg_edge` cool dark with the run summary and event log lit in light text; no red wash, no shake | cold, still, factual, legible | low — restart is one click away (Pillar 3) |

Two rules cut across all states. First, the event log is lit in every state including defeat —
it is the player's receipt for the run, and Pillar 4 says it must always be readable. Second,
darker never means less readable: dimming the player's hand on the boss turn lowers the fill
behind the cards, not the contrast of the cards themselves.

**Boss band atmosphere (DD-R01).** The dungeon gets deeper, not darker. Floors 1–3 (band 1)
tint the boss side's portrait panel and card frames muted ochre, floors 4–6 (band 2) muted rust,
floors 7–8 (band 3) muted slate-violet. Table light does not change across bands; the boss's
colour does. That keeps readability constant across a run while still telling the player, from
colour alone, roughly how deep they are.

## 3. Shape Language

Deckdelve's shape vocabulary is a ledger's: rectangles for documents, circles for stamps, and
almost nothing else. The restraint is deliberate — a game about reading state needs its shapes
to carry meaning, and that is only possible when there are few of them. Each shape class below
names what it communicates and which pillar it serves.

**Documents are rectangles (cards, panels, the table).** Every card is a 5:7 rectangle with an
8 px corner radius; the table, the hero panels, the event log and buttons are rectangles with a
4 px radius. Rounded-but-not-soft corners read as "manufactured object on a table" rather than
"UI widget floating on glass", which serves the tabletop fantasy of Principle 2. A card of any
type is the same rectangle: type is told by its slots (a spell has no attack/health stamps, a
weapon shows durability instead of health — DD-M08), never by a different silhouette, so the hand
stays a uniform row the eye can scan (Pillar 4).

**Numbers are circles (cost, attack, health, durability).** Every number the rules care about
lives in a circular stamp. Circles are the only round shapes on a card, so "round = a number the
rules will use" is learnable in one match, and the stamps' fixed positions (cost top-left,
attack bottom-left, health bottom-right) mean the eye finds them without reading (Pillar 3).
State changes modify the numeral's colour, never the circle's shape or position.

**Hero silhouettes (deferred to Alpha, direction fixed now).** When heroes get illustrated, each
owns one silhouette family as well as one colour: **War** is angular and front-loaded (chevrons,
wedge shoulders, a weapon line that leads), **Decay** is drooping and asymmetric (hanging forms,
one side heavier, broken outlines), **Knowledge** is circular and nested (arcs, lenses, a halo of
concentric curves). The test is that a hero reads at a 48 px portrait thumbnail from silhouette
alone; in v1 the portrait panel is a flat hero-colour rectangle with the hero's initial letter,
and the silhouette family is a note for the illustrator. Bosses borrow the vocabulary of their
band — band 1 boxy and crude, band 2 angular and armed, band 3 tall and nested — but never a
hero's exact silhouette, so that "hero vs boss" is readable before "which boss".

**Environment geometry.** The room is implied, not drawn: a rectangular lit table on a darker
rectangular floor with a cooler screen edge. Geometry stays rectilinear and axis-aligned — no
perspective tricks, no angled tables — because an angled playing surface makes seven minion
slots per side (DD-M01) harder to count. Decoration, when it arrives, lives in the dark edges and
is allowed to be organic (chains, roots, rubble) precisely because it is not lit.

**UI shape grammar.** UI echoes the world rather than adopting a separate HUD language: buttons
are small documents (rectangles, 4 px radius, light text), the event log is a strip of ledger
lines, the mana crystals are a row of ten small circles — the same "circle = a number" rule the
cards use. There are no diagonal flourishes, no ribbons, no bevels in v1; if a UI element needs
to look important it gets lighter, not more ornate (Principle 2's design test).

**Hero shapes vs supporting shapes.** The eye is drawn by brightness first, then by circles. The
lit table is the hero region of every screen; within it, the stamps on cards are the hero shapes
and the rules text is supporting; the portrait panels, hero power button and end-turn button are
supporting shapes that sit at the table's edge and are lit only when actionable. Everything in
the cool edge — menus, settings, run seed display — recedes by default.

## 4. Color System

The palette is built from two families — a warm dark world and a reserved set of saturated state
colours — plus three hero pairs. Every hex value below has been checked for contrast against the
surfaces it is allowed to sit on; the ratios are WCAG 2.1 relative-luminance contrast and the
rule for text is AA (≥ 4.5:1 for body text, ≥ 3:1 for text ≥ 18 px bold / 24 px regular and for
non-text boundaries). A programmer building the placeholder UI should be able to take these
tables as-is.

### Surfaces (the world palette)

| Token | Hex | Role | Why |
| --- | --- | --- | --- |
| `bg_edge` | `#141820` | Screen edge, menus, death screen, anything outside the table | Cool near-black: the dungeon room around the torch. Cool so the warm table reads as lit by contrast, not by being bright in absolute terms. |
| `table_dark` | `#2B2118` | Table surface outside the light pool; dimmed hand on boss turn; event log background | Warm dark wood. Same hue family as the lit table so dimming reads as "less light", not "different material". |
| `table_lit` | `#4A3626` | The lit play area: both minion rows, the hand on the player's turn, the draft offers | The torch pool. Still dark enough (9.43:1 under `text_light`) that anything lit on it pops. |
| `parchment` | `#E8DCC4` | Card body, tooltip body, hover preview | The document. The brightest large surface on screen — cards are what the player reads, so they get the light (Principle 1). |
| `ink` | `#1F1A14` | Name band, stat stamps, cost stamp, pills behind floating numbers | Ink on paper. Also the only surface state colours are allowed to sit on as text (see below). |

### Text

| Token | Hex | Used on | Contrast |
| --- | --- | --- | --- |
| `text_light` | `#F2E9D8` | `bg_edge` 14.75 · `table_dark` 13.07 · `table_lit` 9.43 · `ink` 14.33 · hero primaries 6.2–6.7 · band colours 5.5–7.4 | All AA at any size |
| `text_muted` | `#B8AC96` | Secondary labels on `bg_edge` (7.94) and `table_dark` (7.03): run seed, floor counter, log timestamps | AA |
| `text_muted` on `table_lit` | `#B8AC96` on `#4A3626` | Secondary labels inside the lit pool: HUD skip hint, summary sub-labels, draft hint lines (added 2026-11-03, ux-review — `hud.md`, `run-summary.md`) | **5.08:1** (WCAG 2.1 relative luminance) — AA at every size (≥ 4.5 body, ≥ 3 large); AAA only at large text (≥ 18 px regular / 14 px bold). 13 px `text_muted` on `table_lit` is therefore allowed; do not drop it below 12 px |
| `text_ink` | `#1F1A14` | Card rules text and card name on `parchment` (12.72); labels on `know2` gold (7.20) | AA |
| `text_ink_muted` | `#5A4E40` | Flavour text / reminder text on `parchment` (5.95) | AA |

Rule: light text on dark, ink text on parchment, never light text on parchment or ink text on
dark. There is no third text colour in v1.

### Hero and boss identification colours

Each hero has a **primary** (frame border, portrait panel fill, hero power button) and a
**secondary** (art-box placeholder fill, class-card accent). Primaries are dark enough to carry
`text_light`; secondaries are mid-tones that carry `text_ink` where noted. These are
identification colours: they are never used to signal a state.

| Hero / band | Primary | Secondary | Text on primary | Primary on `parchment` (frame border) |
| --- | --- | --- | --- | --- |
| **War** (red-bronze) | `#9B2F23` | `#B07A3A` bronze (ink text 4.68) | `text_light` 6.17 | 5.48 |
| **Decay** (green-violet) | `#355E3B` | `#6B4C8A` violet (light text 5.76) | `text_light` 6.19 | 5.49 |
| **Knowledge** (blue-gold) | `#2C4F8A` | `#C9A24A` gold (ink text 7.20) | `text_light` 6.72 | 5.97 |
| **Neutral cards** | `#6F655A` frame | — | `text_light` 4.73 | 4.20 |
| **Boss band 1** (floors 1–3) | `#6B5B3C` muted ochre | — | `text_light` 5.47 | — |
| **Boss band 2** (floors 4–6) | `#7A4A3A` muted rust | — | `text_light` 6.07 | — |
| **Boss band 3** (floors 7–8) | `#4E4660` muted slate-violet | — | `text_light` 7.35 | — |
| **Mana cost stamp** | `#3B5A82` steel blue | — | `text_light` 5.86 | 5.21 |

Why these hues: War's red-bronze is heat and metal (weapons, aggression); Decay's green-violet is
rot and poison with a bruise undertone; Knowledge's blue-gold is lapis and gilt — the colours of
an illuminated manuscript, which suits the hero who draws and casts. Boss bands are deliberately
the "dead" versions of warm, hot and cold: the dungeon's colours with the life taken out, so a
boss card is never mistaken for a hero's drafted card in the hand. The mana stamp is a desaturated
genre-standard blue: close enough to convention that lapsed Hearthstone players read it
instantly, grey enough not to compete with Knowledge's primary or any state colour.

### State colours (the only saturated colours in the game)

| State | Token | Hex | Meaning and backup cue | Contrast |
| --- | --- | --- | --- | --- |
| Damage / danger / lethal | `state_danger` | `#FF5A4D` | A number went down, or the hero is in lethal range. Backup: a leading "−" on the numeral, a 2-frame shake on the damaged card, a crack glyph on the health stamp. | on `ink` 5.61 (AA text) · on `table_lit` 3.69 (non-text OK) |
| Buff / positive change | `state_buff` | `#3DBE5A` | A number went up or a permanent positive effect applies. Backup: a leading "+", an up-arrow glyph beside the numeral. | on `ink` 7.16 · on `table_lit` 4.72 |
| Targeting / selection | `state_target` | `#F5C542` | Valid target, hovered target, the attack arrow. Backup: the arrow itself and a 3 px ring — shape, not colour, is the primary cue. | on `ink` 10.65 · on `table_lit` 7.01 |
| Frozen / debuffed | `state_freeze` | `#5AC8E0` | Freeze, Silence (grey-out plus this outline), cannot act. Backup: a snowflake glyph on the stamp, a slash glyph for Silence. | on `ink` 8.86 · on `table_lit` 5.83 |
| Actionable (playable card, legal attacker, end-turn ready) | `state_actionable` | `#F2E9D8` | "This is lit": a 2 px light outline. Deliberately *not* a hue, because the identity rule says lit = read/do. Backup: the card lifts 8 px in the hand. | on `table_lit` 9.43 |

Three rules that fall out of the ratios. **(a) State colours never sit on parchment as text** —
all three fail there (danger 2.27, buff 1.78, target 1.19). A buffed or damaged numeral is drawn
on the `ink` stamp; a floating "+2/−3" number gets an `ink` pill behind it. **(b) State colours
are outlines or numerals, never fills larger than a stamp**, which keeps "saturated = something
changed" true; the one exception is the hero portrait saturating to its own primary on victory.
**(c) State colours appear only while the state is true.** A damaged minion's health numeral stays
`state_danger` for as long as it is below max, and returns to `text_light` when healed — the
colour is a readout, not an animation.

### Colourblind safety

The pairs most likely to fail are **danger red vs buff green** (deuteranopia/protanopia) and, less
so, **target amber vs buff green**. The design does not rely on either pair being distinguishable
by hue: every state has a shape or glyph backup listed above, buffs and damage carry a sign on the
numeral, and targeting is an arrow. War's red-bronze primary and Decay's green primary are an
identification pair, not a state pair, and they are additionally separated by value (War is
lighter) and by the hero's initial letter in v1 and silhouette family later. A later
`/ux-design accessibility` pass should add a selectable high-contrast state set (e.g. danger →
orange `#FF8C42`, buff → blue `#4FA3FF`) as a settings toggle; the token names above exist so
that swap is a theme change, not a code change.

### UI palette and where it diverges from the world

The UI uses the same surfaces (`bg_edge` for chrome, `table_dark` for panels on the table,
`parchment` for tooltips) and diverges from the world in exactly one way: buttons and the
end-turn control are lit by *state*, not by hierarchy. An idle button is `table_dark` with
`text_muted`; a button the player can press now is `table_dark` with `text_light` and a
`state_actionable` outline; the end-turn button, when every mana crystal is spent or no play is
legal, gains the same outline. There is no "primary button colour" in the conventional sense —
the hero's primary is reserved for the hero.

### Typography and card readability (placeholder v1)

Two faces (changed 2026-11-06, section 11): Alegreya for titles, names, buttons and numerals, and
Godot's built-in sans for rules text and log lines. Sizes are for the 1280x720 logical
viewport (DD-T05, `canvas_items` stretch); the minimum rendered size anywhere is 12 px and
anything at 12 px must also be readable at 1.5x in the hover preview.

| Element | Size / weight | Colour |
| --- | --- | --- |
| Cost, attack, health, durability numerals (card in hand) | 20 px bold | `text_light` on `ink` stamp; `state_*` when changed |
| Card name | 14 px bold, single line, ellipsised | `text_light` on `ink` name band |
| Card rules text | 12 px regular, line height 1.3, max 4 lines; keywords bold | `text_ink` on `parchment` |
| Hover preview (card at 1.5x = 225x315) | all card text ×1.5 (18 px body) | same |
| Board minion token numerals | 14 px bold | `text_light` on `ink` stamp |
| Hero health / armour | 24 px bold | `text_light` on `ink` |
| Mana counter ("3/5") | 16 px bold | `text_light` |
| Buttons | 16 px regular | per UI palette above |
| Event log lines | 13 px regular | `text_light` / `text_muted` on `table_dark` |
| Screen titles (hero select, draft, summary) | 28 px bold | `text_light` on `bg_edge` |

### Card frame slot layout — 150x210 card at 1280x720

All coordinates are from the card's top-left, in logical pixels. The layout is identical for all
three card types; a type omits stamps it does not have.

```
 x→ 0        37  40                         110 113       150
 y
 0  ┌─────────────────────────────────────────────────────┐  frame border 2 px (hero primary /
 3  │ (cost)                                              │  neutral / boss band), radius 8,
    │  ◯ 34                                               │  body fill: parchment
37  │                                                     │
40  ├───────────── name band  (ink, 22 px high) ──────────┤  y 40–62, x 6–144
62  ├─────────────────────────────────────────────────────┤
64  │           art box  (placeholder: hero secondary     │  y 64–118, x 8–142 (134x54)
    │           fill + type initial M / S / W, 24 px)     │
118 ├─────────────────────────────────────────────────────┤
122 │  text box  (parchment, 12 px rules text, 4 lines)   │  y 122–180, x 8–142 (134x58),
180 │                                                     │  6 px inner padding
    │                                                     │
173 │ ◯ attack 34                           ◯ health 34   │  attack centre (20,190)
207 │                                                     │  health centre (130,190)
210 └─────────────────────────────────────────────────────┘
```

| Slot | Box (x, y, w, h) | Fill / stroke | Content |
| --- | --- | --- | --- |
| Card body | 0, 0, 150, 210 | `parchment`, 2 px border in frame colour, radius 8 | — |
| Cost stamp | 3, 3, 34, 34 (circle, centre 20,20) | `#3B5A82` fill, 2 px `ink` ring | 20 px bold `text_light` |
| Name band | 6, 40, 138, 22 | `ink` | 14 px bold `text_light`, left-aligned, 6 px padding |
| Art box | 8, 64, 134, 54 | hero secondary / neutral `#6F655A` / band colour | type initial, 24 px bold, `text_ink` on gold or bronze, `text_light` otherwise |
| Text box | 8, 122, 134, 58 | `parchment` (no inner border) | 12 px rules text, `text_ink` |
| Attack stamp | 3, 173, 34, 34 (circle, centre 20,190) | `ink` fill, 2 px `#6F655A` ring, sword glyph 10 px at upper-left of numeral | 20 px bold `text_light` / `state_buff` |
| Health / durability stamp | 113, 173, 34, 34 (circle, centre 130,190) | `ink` fill, 2 px `#6F655A` ring, heart glyph (minion) or shield glyph (weapon) | 20 px bold `text_light` / `state_danger` / `state_buff` |
| Keyword icon row (optional) | 8, 118, 134, 4 overlap tolerated; icons 12 px, right-aligned along the art-box bottom edge | — | Taunt / Divine Shield / etc. as 12 px glyphs; v1 may use letters |

Stamps overlap the body corner by design (3 px inset) so the three numbers sit at the card's
extreme corners where a fanned hand still shows them. Spells omit both bottom stamps and extend
the text box to y 122–200. Weapons show attack and durability. The on-board **minion token** is
90x126 (0.6x) and keeps only the art box, the two stamps (26 px circles, 14 px numerals, centres
at (15,111) and (75,111)) and the keyword icon row — no name band, no rules text; the full card
appears on hover as the 1.5x preview. Seven tokens at 90 px plus 8 px gaps is 678 px, which
leaves room on a 1280 px row for both portraits (Principle 2's table layout, DD-M01).

## 5. Character Design Direction

**Deferred to Alpha — placeholder art in v1.** In v1 a hero is a flat rectangle in its primary
colour carrying its initial letter; a boss is the same in its band colour. Constraints production
must still respect now so that the later illustration pass is a swap, not a rework:

- Portrait panels are fixed-size rectangles (hero 120x160, boss 120x160, at the table's left and
  right edges) and the hero colour is carried by the panel, so illustration must fit inside the
  panel rather than redefine it.
- Hero silhouette families are fixed in Section 3 (War angular, Decay drooping/asymmetric,
  Knowledge circular/nested) and must read at a 48 px thumbnail; boss silhouettes borrow their
  band's vocabulary and never a hero's.
- Expression, pose style and LOD philosophy are `/asset-spec`'s to define once the style is
  explored; nothing in v1 may depend on them.

## 6. Environment Design Language

**Deferred to Alpha — placeholder art in v1.** The environment in v1 is three flat rectangles:
`bg_edge` screen, `table_dark` floor, `table_lit` play area. Constraints that hold regardless:

- The lit table remains the brightest large region and stays rectilinear and axis-aligned; any
  future texture or decoration lives in the dark edges and may not raise their brightness above
  `table_dark`.
- Floor depth is told by the boss's band colour, not by changing the table or room lighting
  (Section 2), so environment variation per band is limited to the dark edges.
- Texture philosophy (painted vs stylised), prop density and environmental storytelling are not
  decided and nothing in v1 may depend on them.

## 7. UI/HUD Visual Direction

**Deferred to Alpha — placeholder art in v1**, with the readable parts already fixed by Sections
3 and 4: screen-space HUD that echoes the tabletop (rectangles with 4 px radius, circles for
numbers), the typography table and 12 px minimum, light-text-on-dark / ink-on-parchment, and
"lit by state" buttons. Constraints production must respect:

- Every readable element meets the contrast ratios in Section 4 at 1280x720; a `/ux-design` pass
  owns per-screen layout and keyboard/gamepad reachability (no hover-only information — hover
  preview duplicates, never replaces, card text).
- State-colour reservations hold in the HUD exactly as on cards: saturated colour only for
  danger, buff, target, freeze and actionable; the hero primary never acts as a "primary button"
  colour.
- Iconography style and UI animation feel are undecided; v1 uses letter glyphs and instant state
  changes.

## 8. Asset Standards

**Deferred to Alpha for a full illustration pass.** The 2026-11-06 runtime pass
(`design/art/runtime-art.md`, `THIRD_PARTY_ART.md`) fills the slots below with licensed
textures. Frames, type, and state are still drawn from the colour tokens with Godot
`Control` / `Panel` / `Label` nodes and the default theme font. Constraints that already apply:

- Colour tokens in Section 4 are the single source for every fill; they belong in one Godot
  `Theme` resource (or a constants script) so the colourblind swap and the later art pass are
  theme changes.
- Any placeholder image that does get made follows the studio naming convention
  `[category]_[name]_[variant]_[size].[ext]` and the 150x210 / 90x126 / 225x315 card sizes; PNG,
  sRGB, authored at 2x (300x420) for the 1280x720 logical viewport.
- Formats, texture tiers, memory budgets and import settings wait on `/asset-spec` and a
  `technical-artist` pass; performance budgets beyond 60 fps are `[TO BE CONFIGURED]` in
  `.claude/docs/technical-preferences.md` and are not asserted here.

## 9. Reference Direction

**Deferred to Alpha — placeholder art in v1.** The concept's references (Hearthstone Dungeon
Run for the loop and card-slot conventions, Slay the Spire for telegraphed intent, Monster Train
for run-defining treasures) are gameplay references; visual references for the 2D stylized
illustration style have not been curated and no reference is named here that a later pass would
then have to un-name. One constraint carries forward: whatever references are chosen must be
consistent with "cards are documents" — illuminated-manuscript and ledger traditions are the
starting direction, and any reference whose cards are art-first with text overlaid is a
divergence to be argued, not a default.

## 10. Runtime art pass (2026-11-06)

Sections 1–4 still govern. This pass only fills slots they already named:

- Card bodies and tooltip / parchment panels use a CC0 parchment texture, held near `#E8DCC4`.
- The match table, menu, hero select, draft, and victory summary use a darkened CC0 wood
  colour map. Corners fall to `bg_edge`. Defeat stays the flat cool edge.
- The art box and the board token carry one stamp per card. Vessel and skull subjects use
  Open Sketchbook studies. Other subjects use CC BY game-icons silhouettes, tinted ink.
  Class and band colour remain the field behind the stamp.
- Attack, health, durability, cost, and keyword glyphs are the same silhouette family, 10–12 px,
  on the ink stamps. Letters stay the fallback when a glyph is missing.
- Hero and boss portraits are stamps inside the existing 120×160 colour panel. The boss stamp
  stops above the passive plate.

Godot still draws the frame, the name band, the rules text, and the circular stamps. No
Hearthstone chrome, no cosmic sheet, and no pixel dungeon. Sources, filenames, authors,
licenses, and the packs that were checked and left out are `THIRD_PARTY_ART.md`.
The id map is `assets/art/art_map.json`.

## 11. Presentation pass (2026-11-06)

The runtime art made the default-engine chrome around it the weakest thing on screen. This pass
keeps the palette tokens and the F4 and F6 slots and changes what surrounds the documents:

- **Type.** Alegreya (OFL, `assets/fonts/`) with lining figures for titles, names, buttons and
  numerals, through `UiFonts`. The menu wordmark is 88 px. Rules text stays in the plain sans.
- **Wood.** `table_wood.png` is regraded to about 60% saturation, so the grain stops competing
  with the cards.
- **Chrome.** Secondary buttons are ink with a 1 px hairline. The one primary action on a screen
  is a slip of parchment with ink text. Focus is four corner marks in `state_actionable`, 2 px
  wide and 3 px off the control.
- **Documents.** Bundles, treasures, board tokens and run summaries are parchment with ink text
  and ruled rows. Art boxes wash the class colour 55% into the paper, so saturated colour stays
  in portraits and state.
- **Hero select.** Panels are ink; colour lives in the portrait and one identity rule. An
  unselected hero shades its portrait only, so its text stays readable.
- **Stamps replace placeholder letters.** Treasures, hero powers and boss intents resolve through
  `art_map.json`. Stat glyphs moved from 10 px rim marks to a 26 px watermark behind the numeral.
- **Boss stamps** sit on the portrait's top corner, so they no longer cover the passive plate.
