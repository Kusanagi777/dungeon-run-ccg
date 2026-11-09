# Third-party audio

Every sound and music file in `assets/audio/sfx/` is CC0 (public domain). Credit is not required by the license; it is given here anyway. Downloaded 2026-11-08. The cue each file answers is its stem, mapped from the event ids in `assets/data/run_ui.json` → `sfx.events`.

## Kenney — CC0

- Packs: Casino Audio, Impact Sounds, Interface Sounds, RPG Audio, Music Jingles, by Kenney Vleugels (https://kenney.nl). Pages: https://kenney.nl/assets/casino-audio, …/impact-sounds, …/interface-sounds, …/rpg-audio, …/music-jingles.
- License: Creative Commons Zero, https://creativecommons.org/publicdomain/zero/1.0/. The pack's License.txt is kept at `assets/audio/licenses/kenney-cc0-license.txt`.

## OpenGameArt — CC0

- `match_ambient.ogg`: "Dark Cavern Ambient" (dark_cavern_ambient_001.ogg) by Paul Wortmann, https://opengameart.org/content/dark-cavern-ambient, CC0.
- `run_ambient.ogg`: "Dungeon Ambience" (dungeon002.ogg) by yd, https://opengameart.org/content/dungeon-ambience, CC0.
- Both are imported with looping on.

## File map

| File (`assets/audio/sfx/`) | Source | Used for |
| --- | --- | --- |
| `ui_card_lift.ogg` | Casino Audio: `card-slide-1.ogg` | card lifted from the hand |
| `ui_card_play.ogg` | Casino Audio: `card-place-1.ogg` | card slapped down |
| `ui_attack_whoosh.ogg` | RPG Audio: `drawKnife1.ogg` | blade swish of a lunge |
| `ui_impact_light.ogg` | Impact Sounds: `impactPunch_medium_000.ogg` | light combat hit |
| `ui_impact_heavy.ogg` | Impact Sounds: `impactPunch_heavy_000.ogg` | heavy combat hit |
| `ui_damage.ogg` | Impact Sounds: `impactSoft_medium_000.ogg` | damage taken |
| `ui_heal.ogg` | Interface Sounds: `glass_002.ogg` | soft chime |
| `ui_shield_pop.ogg` | Impact Sounds: `impactGlass_light_000.ogg` | match-rules: glass-crack ping |
| `ui_death_thud.ogg` | Impact Sounds: `impactSoft_heavy_000.ogg` | short death thud |
| `ui_draw.ogg` | Casino Audio: `card-slide-3.ogg` | card slides from the deck |
| `ui_burn.ogg` | Interface Sounds: `scratch_002.ogg` | burn sizzle |
| `ui_heartbeat.ogg` | Impact Sounds: `impactSoft_medium_002.ogg` | fatigue heartbeat |
| `ui_end_turn.ogg` | Interface Sounds: `switch_002.ogg` | button press |
| `ui_turn_chime.ogg` | Impact Sounds: `impactBell_heavy_000.ogg` | boss turn bell |
| `ui_page_turn.ogg` | RPG Audio: `bookFlip1.ogg` | intent shown |
| `ui_plan_changed.ogg` | RPG Audio: `bookFlip3.ogg` | intent changed |
| `ui_deny.ogg` | Interface Sounds: `error_004.ogg` | soft deny |
| `ui_overlay.ogg` | Interface Sounds: `maximize_003.ogg` | overlay opens |
| `ui_spell_cast.ogg` | Interface Sounds: `glass_005.ogg` | spell resolves |
| `ui_status.ogg` | Interface Sounds: `tick_002.ogg` | soft status cue |
| `ui_summon.ogg` | Casino Audio: `card-shove-2.ogg` | minion enters the row |
| `ui_summon_failed.ogg` | Impact Sounds: `impactWood_heavy_000.ogg` | match-rules: dull thump |
| `ui_discard.ogg` | Casino Audio: `card-shove-4.ogg` | card thrown away |
| `ui_deck_add.ogg` | Casino Audio: `card-shuffle.ogg` | card shuffled into the deck |
| `ui_weapon_equip.ogg` | RPG Audio: `drawKnife2.ogg` | weapon drawn |
| `ui_weapon_break.ogg` | Impact Sounds: `impactMetal_heavy_000.ogg` | weapon shatters |
| `ui_power_chime.ogg` | Interface Sounds: `confirmation_002.ogg` | match-rules: power chime |
| `ui_fizzle.ogg` | Interface Sounds: `scratch_004.ogg` | effect fizzles |
| `ui_transform.ogg` | Impact Sounds: `impactGlass_medium_000.ogg` | the mask cracks off (Unmask) |
| `ui_return.ogg` | Casino Audio: `card-fan-1.ogg` | card returns to the hand |
| `ui_hover.ogg` | Interface Sounds: `select_001.ogg` | menu hover |
| `ui_select.ogg` | Interface Sounds: `click_001.ogg` | menu select |
| `ui_slider_tick.ogg` | Interface Sounds: `scroll_001.ogg` | slider step |
| `ui_pick.ogg` | Interface Sounds: `confirmation_001.ogg` | draft pick |
| `ui_draft_reveal.ogg` | Casino Audio: `cards-pack-open-1.ogg` | draft offer revealed |
| `run_start.ogg` | RPG Audio: `doorOpen_1.ogg` | into the dungeon |
| `ui_victory.ogg` | Music Jingles: `jingles_HIT00.ogg` | match won |
| `ui_defeat.ogg` | Music Jingles: `jingles_HIT01.ogg` | match lost |
| `ui_unlock.ogg` | Music Jingles: `jingles_PIZZI00.ogg` | unlock toast |
| `run_victory.ogg` | Music Jingles: `jingles_HIT03.ogg` | run won |
| `run_defeat.ogg` | Music Jingles: `jingles_HIT04.ogg` | run lost |
| `boss_intro_1.ogg` | Music Jingles: `jingles_HIT05.ogg` | band 1 boss intro |
| `boss_intro_2.ogg` | Music Jingles: `jingles_HIT06.ogg` | band 2 boss intro |
| `boss_intro_3.ogg` | Music Jingles: `jingles_HIT07.ogg` | band 3 boss intro |
| `hero_sting_hero_war.ogg` | Music Jingles: `jingles_HIT08.ogg` | hero select sting |
| `hero_sting_hero_decay.ogg` | Music Jingles: `jingles_HIT09.ogg` | hero select sting |
| `hero_sting_hero_knowledge.ogg` | Music Jingles: `jingles_HIT10.ogg` | hero select sting |
| `match_ambient.ogg` | OpenGameArt: `dark_cavern_ambient_001.ogg` | match loop |
| `run_ambient.ogg` | OpenGameArt: `dungeon002.ogg` | menu and run-map loop |

## Picked by name, not by ear

The stingers (`ui_victory`, `ui_defeat`, `ui_unlock`, `run_*`, `boss_intro_*`, `hero_sting_*`) were chosen from the Hit and Pizzicato jingle sets by file name, without listening. Swap any of them by replacing the file under the same stem; nothing else changes.
