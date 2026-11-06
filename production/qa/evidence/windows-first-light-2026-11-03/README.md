# Windows first light — 2026-11-03

**Gate:** Pre-Production entry condition 8 (owner launches the Windows export once); TD-PHASE-GATE entry condition 4 (first Forward+ frame on Windows); boot-composition-root story 008 open item.

**Build:** CI artifact `deckdelve-windows-5f45742b9fc2df859bf8327f9b2383856d711d15` from the Windows Export run https://github.com/Kusanagi777/dungeon-run-ccg/actions/runs/41726788096 (head `6ea1937`, release export, Forward+ renderer as shipped).

**Run by:** Jacob (owner), on his Windows PC, 2026-11-03.

**Observed (owner's screenshot, sent in the session chat):**
- A native Windows window titled "Dungeon Run CCG" with the Godot icon, minimise / maximise / close controls; client area 1280x720-ish.
- Background the art bible's `table_dark` near-black navy (`#141820`).
- Centred title "Deckdelve — boot" in `text_light` cream (`#F2E9D8`), large sans-serif, anti-aliased; the em dash renders correctly (UTF-8 text path OK).
- Bottom-left build stamp "Dungeon Run CCG — Godot 4.7.2-stable (official)" in `text_muted` (`#B8AC96`).
- No error dialog, no console, no rendering artefacts.

**Verdict:** PASS — the release export launches and the shipped Forward+ renderer (Direct3D 12 / Vulkan on Windows) draws the boot screen as the xvfb/Compatibility capture in `production/qa/evidence/rig-check-2026-11-03/01-boot.png` predicted. ADR-0010's renderer-parity risk is observed clean for this screen.

**Image file:** the screenshot reached the session only as a chat attachment, not as a file in the cloud container, so `01-boot-windows.png` is not stored here yet. To retain it, add it to this folder (e.g. GitHub web UI → Add file → Upload files on branch `bootstrap/ccgs-template`).
