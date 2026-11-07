# Runtime art — Torchlit Ledger pass

The approved direction is unchanged: documents on parchment, on a warm lit table, with cool dark edges. Saturated colour is still only for state. This pass fills the existing slots. It does not redraw the frames.

Sizes, checked against the current project rather than an earlier note:

| Surface | Size | Where |
| --- | --- | --- |
| Viewport | 1280×720 | `project.godot`, `project.yaml` `commands.run` |
| Card | 150×210, authored at 300×420 | `CardFrame.SIZE`, `parchment_card.png` |
| Art box | 134×54 at (8, 64) | `CardFrame.ART_RECT` |
| Board token | 90×126 | `match_ui.json` `board.token_w` / `token_h` |
| Portrait | 120×160 | `match_ui.json` `player_portrait` / `boss_portrait` |

## What is drawn

- **Card body.** `parchment_card.png` inside the existing 2 px Godot frame. The ink name band, rules text, and circular stamps stay drawn in code.
- **Art box and token.** A stamp from `art_map.json`, aspect-fit on the class or band colour. If the map and the fallbacks miss, the old type initial (or the token's name initial) stays.
- **Stamps on the circles.** Attack / health / durability / cost glyphs as a low-alpha watermark behind the numeral (art bible §11). Keyword icons are 12 px on an ink pill along the art box. The letter backup stays in the label and is shown when a glyph file is missing.
- **Table.** `table_wood.png`, regraded (art bible §11), on the match table, the main menu, hero select, the draft, and the victory summary. Boss-turn and pause dim the texture. Defeat stays flat `bg_edge`.
- **Parchment panels.** Tooltips, the reading panel, and `RunUiTheme` parchment panels use `parchment_tile.png`.
- **Portraits.** The same stamp language inside the existing colour panel: War barbarian, Decay witch, Knowledge wizard, and one stamp per boss. The boss stamp stops above the passive plate, which overlaps the portrait's bottom 48 px. The initial letter remains when no stamp resolves.

## Mapping

`assets/art/art_map.json` is the only map. `ArtLibrary` does not read `assets/data/`.

Card resolution order:

1. `cards[card_id]`
2. `fallback_set[set]` — war sword, decay warm skull, knowledge book, neutral lantern, boss gate
3. `fallback_type[type]` — minion person, spell scroll, weapon sword
4. nothing — the flat placeholder

Every shipped card id, the three heroes, all sixteen bosses, every treasure and hero power, and every boss intent but `pass` have an explicit entry. Sketchbook studies are only assigned where the subject is a vessel or a skull. Everything else is a game-icons silhouette. The full file list, authors, and licenses are in `THIRD_PARTY_ART.md`.

Tint: coloured studies are drawn as authored. White silhouettes are tinted ink on cards and cream on dark portraits.
