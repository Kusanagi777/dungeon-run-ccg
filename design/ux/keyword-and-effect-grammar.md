# Keyword and effect grammar

Status: built 2026-11-08. This is the one reference for how every keyword, state
and match event looks and sounds. It implements the art bible §4 state table,
hud.md's board-token and portrait rows, interaction-patterns' Board Token
states, and the match-ui and match-rules Visual/Audio tables. Where those
documents say "letters in v1", read this page.

## One table, three surfaces

The badge table is `assets/data/match_ui.json`:

| Key | Holds |
| --- | --- |
| `badges.order` | Every badge name, in display order |
| `badges.board` | The subset a minion token shows |
| `badges.flash` | The colour a badge flashes when it is gained |
| `glyphs` | Each badge's letter, its non-colour fallback |
| `strings.badge.<name>` | Each badge's name, for reading |

Icons are `assets/art/art_map.json` → `glyphs`. They are all game-icons
silhouettes, credited in `THIRD_PARTY_ART.md`.

The code paths:
- `MatchUiContext.badges(names, board)` is the single lookup.
- `BadgeRow.draw` is the single drawer, used by the board token and the card face.
- The reading panel shows the same icons with their names.

Each badge falls back to its letter on its own, so one missing icon never
turns the whole row into letters.

| Badge | Icon | Letter | On a token | Persistent token treatment |
| --- | --- | --- | --- | --- |
| Taunt | defensive wall | T | yes | Thicker frame (4 px) |
| Divine Shield | shield reflect | DS | yes | Light halo around the token; ring burst when it pops |
| Stealth | hood | S | yes | Alpha shimmer, 0.55–0.85; a static 0.7 under `reduce_motion` |
| Windfury | whirlwind | W | yes | — |
| Rush | sprint | R | yes | — |
| Charge | charging bull | C | yes | — |
| Poisonous | poison bottle | P | yes | Gaining it flashes `state_danger` |
| Lifesteal | heart bottle | L | yes | — |
| Spell Damage | magic swirl | SD | yes | The cast spell shows "Spell Damage +N" |
| Deathrattle | tombstone | DR | yes | — |
| Aura | aura | A | yes | — |
| Battlecry | shouting | BC | card only | — |
| Discover | magnifying glass | Dv | card only | — |
| Freeze (effect) | snowflake | F | card only | — |
| Silence (effect) | silence | Si | card only | — |
| Masked | domino mask | M | yes, until silenced | Gaining it flashes `state_target` |
| Frozen | snowflake | F | yes | `state_freeze` outline; a frozen hero gets the outline and a snowflake |
| Silenced | silence | Si | yes | Greyed art box plus `state_freeze` outline |
| Summoning sick | hourglass | z | yes | — |
| Already attacked | check mark | ✓ | player row | Shown once a minion has attacked and can no longer attack |

Letters are unique, except where a keyword and the state it causes share one:
Freeze/Frozen are both F, and Silence/Silenced are both Si.

Damaged and buffed show as glyphs beside the numerals, not as badges:
- **Damaged:** a crack glyph and a `state_danger` numeral. The hero gets the
  crack beside its health stamp.
- **Buffed:** an up-arrow and a `state_buff` numeral.

An armed trigger draws a rim glow until it resolves.

## Effects: one treatment per kind of change

Every event the engine sends becomes one animation step:
- `MatchViewState._project` maps each event to its step.
- `config.match_ui.d_base` sets each step's duration.
- `config.match_ui.sfx_steps` sets each step's sound.

Every step is skippable. Under `reduce_motion`, motion becomes a fade or
nothing, and the state change stays visible.

| Event | Step | Visual | Sound |
| --- | --- | --- | --- |
| `damage_dealt` | `damage_pop` | `−n` pill in `state_danger`; 2-frame shake of the token or portrait | `damage`, plus `impact_light` / `impact_heavy` for combat only |
| `healed` | `heal_pop` | `+n` pill in `state_buff` | `heal` |
| `armor_gained` | `armor_pop` | `+n` pill in `text_light`; the shield-glyph armour pill pulses | none (hud.md) |
| `divine_shield_popped` | `shield_pop` | Ring burst | `shield_pop` |
| `frozen`, `thawed`, `silenced`, `stealth_lost`, `keyword_removed`, a granted keyword | `badge` | A gained badge swells and flashes its colour; a lost one shrinks out | `status` (the "soft status cue") |
| buffs, debuffs, auras, `minion_modified` | `stat_recolour` | The numerals swell and settle; the colour and glyph follow the new value | none (match-ui) |
| `minion_transformed` (Unmask, Transmute) | `transform` | The token squashes and flashes light, then reopens as the new minion in the same slot | `transform` |
| `minion_returned` | `return` + `draw` | The token lifts toward its owner's hand and fades; the card slides into the hand from the row | `return`, `draw` |
| `minion_summoned` | `summon` | Grows in | `summon` |
| `summon_failed` | `summon_failed` | A faded ghost of the card at the end of the full row | `summon_failed` |
| `minion_died` | `death_group` + `gap_close` | Fade and 2 px drop, then the row closes | `death_thud` |
| `card_played` | `play_card` | A minion travels to its row | `card_play` |
| `spell_cast` | `play_card` + `spell_cast` | The spell travels to the centre cast zone (the boss's appears there face up), with "Spell Damage +N" when above 0 | `card_play`, `spell_cast` |
| `card_drawn` / `card_added_to_hand` | `draw` | Slides from the deck | `draw` |
| `card_discarded` | `discard` | The player's card drops and fades; the boss's hand count pulses | `discard` |
| `card_burned` | `burn` | The burned card shows face up over its owner's pile and dissolves, for both sides | `burn` |
| `card_added_to_deck` | `deck_tick` | The deck count pulses | `deck_add` |
| `fatigue_damage` | `fatigue_label` | The fatigue label pulses, then the damage pop | `heartbeat` |
| `weapon_equipped` | `weapon_update` | The weapon slot pulses | `weapon_equip` |
| `weapon_destroyed` | `weapon_shatter` | Fades | `weapon_break` |
| `hero_power_used` | `power_press` | Press | `power_chime` |
| `effect_resolved` (fizzled) | `fizzle` | A muted "Fizzled" pill at the source | `fizzle` |
| `trigger_queued` / `trigger_resolved` | `rim_glow` | The source's rim glows while armed | none |
| `attack_declared` | `attack_lunge` | Lunge with a hit-stop on contact | `attack_whoosh` |

Each sound is an id under `run_ui.json` `sfx.events`, with stem `ui_<name>`. Every
cue has a file since 2026-11-08: Kenney CC0 packs and two OpenGameArt CC0 loops,
listed file by file in `THIRD_PARTY_AUDIO.md`. To swap a sound, replace the file
under the same stem. The match plays `music.match_ambient`; menus and the run map
play `music.run_ambient`.

## Particles

`FxPresenter` is a layer above the table. It plays a one-shot effect for each
step kind named in `match_ui.json` → `particles.steps`. Each effect in
`particles.effects` is a list of emitters, either bursts or single-sprite
flashes. Their textures are 16 Kenney Particle Pack sprites in
`assets/art/fx/`, and their colours are palette tokens, so
`high_contrast_states` changes them too.

| Step | Effect |
| --- | --- |
| `damage_pop` | Red sparks and a slash; heavy hits (5+) add a red ring |
| `heal_pop` | Rising green hearts and a soft light |
| `armor_pop` | A light ring and sparkles |
| `shield_pop` | A ring and gold sparkles |
| `death_group` | Smoke and falling dust |
| `summon` / `summon_failed` | A dust puff at the token's base / a grey puff at the row end |
| `transform` (Unmask) | A magic flare, a twirl and a star burst |
| `return` | Downward streaks |
| `spell_cast` | A rune circle and stars at the cast zone |
| `badge` | By the status gained: frost for Frozen, grey smoke for Silenced, a red mist for Poisonous, a gold ring for Divine Shield, violet smoke for Stealth, a ring for Taunt, sparkles otherwise. Losing a status plays nothing. |
| `stat_recolour` | Rising green stars for a buff, falling red motes for a debuff |
| `fizzle`, `burn`, `weapon_update`, `weapon_shatter`, `power_press` | Grey puff, fire over the deck, a slash, metal sparks, a light |

Effects are decorative and carry no state. A skip clears them all. Nothing
plays at `instant` or under `reduce_motion`, and `fast` plays them at the fast
rate.

## Not built

The once-per-turn trigger icon dimming to 60 % until the next turn (match-ui
Visual/Audio, "Should") is not built. Triggers that are once per turn have no
badge of their own to dim. The view tracks `exhausted_sources` for when one
exists.
