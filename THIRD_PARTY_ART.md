# Third-party art

The game code in this repository is under the MIT license in `LICENSE`. That license does **not** cover the files under `assets/art/`. Those files keep the license of their source. Do not relicense them as MIT.

Runtime mapping lives in `assets/art/art_map.json`. How the screens use it is `design/art/runtime-art.md`.

Licenses below were read on the source page and, where a file was committed, inside the download, on 2026-11-06. A page claim alone is not treated as the archive's license.

## Used

### Parchment — cron, CC0

- Source: https://opengameart.org/content/old-parchment-paper
- Page license field: CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/), author cron.
- Download: `parchment.png` (served as `parchment_1.png`). The file is a bare image; the page has no separate license file inside a zip.
- Committed:
  - `assets/art/surfaces/parchment_card.png` — 300×420, the 2× card face. Colour pulled toward `#E8DCC4` so 12 px ink stays above 7:1 on the darkest pixel (measured 9.27:1). Corners rounded at 16 px (8 px logical).
  - `assets/art/surfaces/parchment_tile.png` — 256×256 tile for tooltips, the reading panel, and parchment panels.
- `parchment_alpha.png` from the same page was not used.

### Wood table — Texture Haven, CC0

- Source: https://cc0-textures.com/t/th-wood-table-001
- The site title is "CC0 Public Domain Textures". The texture record is "Wood Table 001" by Texture Haven. The zip itself contains no license document, only the maps below.
- Download: `wood_table_001_4K-JPG.zip`. Used only `wood_table_001/wood_table_001_diff_4k.jpg`. Discarded, not committed: displacement, AO, roughness, and both normal maps.
- Committed: `assets/art/surfaces/table_wood.png` (1280×720). The colour map is darkened toward `table_lit` (`#4A3626`) and vignetted to `bg_edge` (`#141820`) at the corners.

### Open Sketchbook — Hunter Stout, CC0

- Source: https://hunterstoutstudio.itch.io/open-sketchbook
- Page text: the images are published under CC0 1.0 and dedicated to the public domain. Credit is not required; this file credits Hunter Stout anyway.
- Archive `Open Sketchbook.zip` (upload dated 02 April 2025) contains no license file. Its only images are `001_pots.png`, `002_pots.png`, `003_skull.png`, and `004_skull.png` (2048×2048). `__MACOSX` junk was discarded.
- The pack does not contain weapons, books, animals, or portraits. Only the vessel and skull studies are used, and only on cards whose subject is a vessel or a skull. Other subjects use game-icons silhouettes.
- Committed stamps (near-black background removed, one study cropped, longest side 256):

| File | Source image | Crop box (x0, y0, x1, y1) before padding |
| --- | --- | --- |
| `assets/art/stamps/jug.png` | `001_pots.png` | 340, 369, 1133, 1202 |
| `assets/art/stamps/pot.png` | `001_pots.png` | 1022, 1195, 1581, 1674 |
| `assets/art/stamps/cup.png` | `001_pots.png` | 1319, 699, 1704, 1006 |
| `assets/art/stamps/urn.png` | `002_pots.png` | 1032, 925, 1766, 1695 |
| `assets/art/stamps/amphora.png` | `002_pots.png` | 349, 632, 801, 1365 |
| `assets/art/stamps/flask.png` | `002_pots.png` | 972, 344, 1219, 796 |
| `assets/art/stamps/skull_warm.png` | `003_skull.png` | 453, 314, 1556, 1586 |
| `assets/art/stamps/skull_cool.png` | `004_skull.png` | 553, 309, 1511, 1683 |

### game-icons — CC BY 3.0

- Source repository: https://github.com/game-icons/icons
- License file: https://raw.githubusercontent.com/game-icons/icons/master/license.txt
- The copy in the cloned repository matched that URL and is preserved at `assets/art/licenses/game-icons-license.txt`.
- Every icon used here is CC BY 3.0. The license file marks only Viscious Speed and Zeromancer as CC0, and neither author's icons are used.
- Upstream SVG: black square plus a white silhouette. The black rectangle was removed and the silhouette was rasterized to a transparent PNG (128 px stamps, 64 px glyphs) so the game can tint it. Glyphs are tinted `text_light` on the ink stamps. Card stamps are tinted ink (`#1F1A14`) on parchment. Portrait stamps are tinted cream (`#F2E9D8`) on the dark hero panel.
- Please keep the notice the license asks for: **Icons made by Lorc, Delapouite, Carl Olsen, Caro Asercion, Skoll, and HeavenlyDog**, from https://game-icons.net / https://github.com/game-icons/icons, CC BY 3.0.

| Committed file | Author | Upstream file |
| --- | --- | --- |
| `stamps/sword.png`, `glyphs/attack.png` | Lorc | `lorc/crossed-swords.svg` |
| `stamps/axe.png` | Delapouite | `delapouite/war-axe.svg` |
| `stamps/shield.png`, `glyphs/durability.png` | Lorc | `lorc/crenulated-shield.svg` |
| `stamps/helmet.png` | Lorc | `lorc/visored-helm.svg` |
| `stamps/banner.png` | Delapouite | `delapouite/knight-banner.svg` |
| `stamps/barbarian.png` | Delapouite | `delapouite/barbarian.svg` |
| `stamps/hammer.png` | Lorc | `lorc/hammer-drop.svg` |
| `stamps/crown.png` | Lorc | `lorc/queen-crown.svg` |
| `stamps/dagger.png` | Lorc | `lorc/plain-dagger.svg` |
| `stamps/rat.png` | Delapouite | `delapouite/rat.svg` |
| `stamps/raven.png` | Lorc | `lorc/raven.svg` |
| `stamps/poison.png`, `glyphs/poisonous.png` | Lorc | `lorc/poison-bottle.svg` |
| `stamps/grave.png` | Lorc | `lorc/tombstone.svg` |
| `stamps/spider.png` | Carl Olsen | `carl-olsen/spider-alt.svg` |
| `stamps/book.png` | Lorc | `lorc/open-book.svg` |
| `stamps/scroll.png` | Lorc | `lorc/scroll-unfurled.svg` |
| `stamps/candle.png` | Lorc | `lorc/candle-flame.svg` |
| `stamps/lightning.png` | Lorc | `lorc/lightning-helix.svg` |
| `stamps/crystal.png` | Lorc | `lorc/crystal-ball.svg` |
| `stamps/frost.png`, `glyphs/frozen.png` | Lorc | `lorc/snowflake-1.svg` |
| `stamps/fire.png` | Carl Olsen | `carl-olsen/flame.svg` |
| `stamps/golem.png` | Delapouite | `delapouite/golem-head.svg` |
| `stamps/person.png` | Delapouite | `delapouite/person.svg` |
| `stamps/owl.png` | Lorc | `lorc/owl.svg` |
| `stamps/wolf.png` | Lorc | `lorc/wolf-head.svg` |
| `stamps/ogre.png` | Delapouite | `delapouite/ogre.svg` |
| `stamps/wizard.png` | Delapouite | `delapouite/wizard-face.svg` |
| `stamps/heart.png` | Lorc | `lorc/heart-organ.svg` |
| `stamps/hood.png`, `glyphs/stealth.png` | Lorc | `lorc/hood.svg` |
| `stamps/chest.png` | Delapouite | `delapouite/chest.svg` |
| `stamps/map.png` | Lorc | `lorc/treasure-map.svg` |
| `stamps/boar.png` | Caro Asercion | `caro-asercion/boar.svg` |
| `stamps/pick.png` | Lorc | `lorc/mining.svg` |
| `stamps/harpy.png` | Lorc | `lorc/harpy.svg` |
| `stamps/giant.png` | Delapouite | `delapouite/giant.svg` |
| `stamps/mammoth.png` | Delapouite | `delapouite/mammoth.svg` |
| `stamps/gate.png` | Delapouite | `delapouite/closed-doors.svg` |
| `stamps/hound.png` | Lorc | `lorc/hound.svg` |
| `stamps/hourglass.png`, `glyphs/summoning_sick.png` | Lorc | `lorc/hourglass.svg` |
| `stamps/sheep.png` | Delapouite | `delapouite/sheep.svg` |
| `stamps/imp.png` | Lorc | `lorc/imp.svg` |
| `stamps/lantern.png` | Lorc | `lorc/lantern.svg` |
| `stamps/ghost.png` | Lorc | `lorc/ghost.svg` |
| `stamps/bone.png` | Delapouite | `delapouite/bone-knife.svg` |
| `stamps/crab.png` | Lorc | `lorc/crab.svg` |
| `stamps/frog.png` | Lorc | `lorc/frog.svg` |
| `stamps/witch.png` | Lorc | `lorc/witch-flight.svg` |
| `stamps/coins.png` | Delapouite | `delapouite/two-coins.svg` |
| `stamps/torch.png` | Delapouite | `delapouite/torch.svg` |
| `stamps/mirror.png` | Lorc | `lorc/mirror-mirror.svg` |
| `stamps/potion.png` | Lorc | `lorc/potion-ball.svg` |
| `glyphs/health.png` | Skoll | `skoll/hearts.svg` |
| `glyphs/cost.png` | Lorc | `lorc/cut-diamond.svg` |
| `glyphs/taunt.png` | HeavenlyDog | `heavenly-dog/defensive-wall.svg` |
| `glyphs/divine_shield.png` | Lorc | `lorc/shield-reflect.svg` |
| `glyphs/windfury.png` | Lorc | `lorc/whirlwind.svg` |
| `glyphs/silenced.png` | Lorc | `lorc/silence.svg` |
| `glyphs/rush.png` | Lorc | `lorc/sprint.svg` |
| `glyphs/charge.png` | Delapouite | `delapouite/charging-bull.svg` |
| `glyphs/lifesteal.png` | Lorc | `lorc/heart-bottle.svg` |
| `glyphs/battlecry.png` | Lorc | `lorc/shouting.svg` |
| `glyphs/deathrattle.png` | Lorc | `lorc/tombstone.svg` |
| `glyphs/discover.png` | Lorc | `lorc/magnifying-glass.svg` |
| `glyphs/aura.png` | Lorc | `lorc/aura.svg` |
| `glyphs/spell_damage.png` | Lorc | `lorc/magic-swirl.svg` |
| `glyphs/masked.png` | Lorc | `lorc/domino-mask.svg` |
| `glyphs/damaged.png` | Lorc | `lorc/cracked-glass.svg` |
| `glyphs/buffed.png` | Delapouite | `delapouite/upgrade.svg` |
| `glyphs/attacked.png` | Delapouite | `delapouite/check-mark.svg` |

Paths above are under `assets/art/`.

## Checked and not shipped

| Source | License found | Why it is not in the tree |
| --- | --- | --- |
| https://kenney.nl/assets/ui-pack-rpg-expansion | Page and `license.txt` inside the zip: CC0. Kenney Vleugels. | Beveled coloured buttons. Art bible §3 forbids bevels, and saturated button colours fight "saturated colour is only for state". Frames stay the existing `StyleBoxFlat`s. |
| https://kenney.nl/assets/particle-pack and https://kenney.nl/assets/smoke-particles | Each page's license row links CC0. Archives were not downloaded. | Nothing in the match view draws a sprite effect. Impact is a shake plus an sfx stub (`impact_presenter` / `sfx_stub.gd`). |
| https://opengameart.org/content/skill-item-and-spell-icons | Page license field: CC0, author pauliuw. Archive not downloaded. | game-icons already supplies the glyphs. |
| https://opengameart.org/content/rpg-characters-avatars | Page license field: CC0, author System G6. The page describes a 128×128 pixel atlas. Archive not opened. | Pixel avatars do not match the ink-stamp direction. Portraits use the same silhouette stamps as the cards. |
| https://opengameart.org/content/card-game-art | Page license field: CC0, author quartxio. One sheet (`vesselsweep`) was opened to judge the style and was not committed. | The sheet is a winged heroic figure, not a ledger stamp. Mixing it with the sketchbook studies would break the document look. |

## Fonts

| File | Font | Author | License | Source |
| --- | --- | --- | --- | --- |
| `assets/fonts/Alegreya-VariableFont_wght.ttf` | Alegreya | The Alegreya Project Authors (Huerta Tipográfica) | SIL Open Font License 1.1, `assets/fonts/OFL-Alegreya.txt` | [google/fonts](https://github.com/google/fonts/tree/main/ofl/alegreya) |

`assets/art/surfaces/table_wood.png` was regraded on 2026-11-06 (saturation and level only); its source and license are unchanged.

### Kenney Particle Pack — CC0

- Source: https://kenney.nl/assets/particle-pack, by Kenney Vleugels. Downloaded 2026-11-08.
- License: Creative Commons Zero (CC0). The pack's License.txt is kept at `assets/art/licenses/kenney-particle-pack-license.txt`.
- Sixteen of its transparent PNGs were resized from 512 px to 128 px for the match view's particle layer (`design/ux/keyword-and-effect-grammar.md`).

| Committed file (`assets/art/fx/`) | Upstream file |
| --- | --- |
| `spark.png` | `spark_03.png` |
| `slash.png` | `slash_02.png` |
| `star.png` | `star_04.png` |
| `sparkle.png` | `star_06.png` |
| `heart.png` | `symbol_01.png` |
| `light.png` | `light_01.png` |
| `ring.png` | `circle_03.png` |
| `smoke.png` | `smoke_07.png` |
| `dust.png` | `dirt_02.png` |
| `magic.png` | `magic_03.png` |
| `rune.png` | `magic_02.png` |
| `twirl.png` | `twirl_02.png` |
| `fire.png` | `flame_05.png` |
| `trace.png` | `trace_04.png` |
| `puff.png` | `smoke_03.png` |
| `soft.png` | `circle_05.png` |
