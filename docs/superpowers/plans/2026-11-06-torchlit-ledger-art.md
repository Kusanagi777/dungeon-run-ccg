# Torchlit Ledger runtime art

> **For agentic workers:** This pass is implemented on `cursor/torchlit-ledger-art-2de0` from `main`. Do not retarget onto another open PR branch.

**Goal:** Show licensed parchment, warm wood, ink stamps, and keyword glyphs on the existing Deckdelve screens without replacing the Godot-drawn frames or the 1280×720 layout.

**Architecture:** `assets/art/art_map.json` maps card, hero, and boss ids to stamp keys, with set and type fallbacks. `ArtLibrary` loads that map (not `assets/data/`, so the card-database parser gate stays the only reader of game data). `CardFrame`, `MinionToken`, the match table, the menu/draft/hero/victory backdrops, tooltips, the draft card preview, and hero/boss portrait panels ask the library for a texture and keep the current flat fill when a file is missing.

**Tech stack:** Godot 4.7.2, GDScript, existing `CardFrame` / `MatchUiContext` / `UiKit` UI.

## Global constraints

- Viewport stays 1280×720, `canvas_items`, aspect `keep`. Do not edit `project.godot` window settings.
- Card slot stays 150×210 (art box 134×54). Board token stays 90×126. Portraits stay 120×160. Frames, radii, and stamp positions stay the Godot-drawn layout in art bible §4.
- Saturated colour stays reserved for state. Wood is darkened into the warm table; screen edges stay cool and near `bg_edge`.
- No network loads at runtime. Commit only files the game references. Do not commit source zips, PBR maps, or `.godot` import caches.
- Repo MIT does not cover third-party art. Attribution lives in `THIRD_PARTY_ART.md` and `assets/art/licenses/`.
- Keyword letter labels stay populated (`MinionToken` tests read them). Icons are the visible glyph when a texture exists.

## What is in and what is out

- In: cron parchment (card body + tooltip/reading panels), Texture Haven `wood_table_001` color map only (match table, menu, hero select, draft, victory), Hunter Stout Open Sketchbook crops where the subject is a vessel or a skull, game-icons silhouettes as the other stamps and as attack/health/durability/cost/keyword glyphs.
- Out: Kenney RPG UI (CC0, but beveled coloured buttons fight art bible §3 "no bevels"), Kenney particles (no sprite effect hook; impact is shake and an sfx stub), System G6 pixel avatars (CC0, wrong scale and style), pauliuw icons (CC0 alternative, unused because game-icons covers the glyphs), quartxio sweeps (CC0, heroic/cosmic illustration, not a ledger stamp).

## Tasks

- [x] Process and commit only the used textures, plus the license notice and `art_map.json`.
- [x] Add `ArtLibrary` and draw stamps, parchment, wood, and glyphs from the existing controls.
- [x] Unit-test resolution and fallbacks. Capture the menu and a match at 1280×720.
