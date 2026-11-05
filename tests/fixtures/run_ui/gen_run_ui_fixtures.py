"""Writes tests/fixtures/run_ui/*.json (run-ui U10) from the shipped data, so every id
resolves. Run from the repo root: python tests/fixtures/run_ui/gen_run_ui_fixtures.py
"""
import json
import pathlib

ROOT = pathlib.Path("assets/data")
OUT = pathlib.Path("tests/fixtures/run_ui")


def records(name):
    return json.loads((ROOT / name).read_text(encoding="utf8"))["records"]


HERO = records("heroes.json")[0]
BOSSES = {band: [b for b in records("bosses.json") if b["band"] == band] for band in (1, 2, 3)}
TREASURES = records("treasures.json")
BUNDLES = [b for b in records("bundles.json") if b["set"] in ("war", "neutral")]
SEQUENCE = []
for band, count in ((1, 3), (2, 3), (3, 2)):
    pool = BOSSES[band]
    SEQUENCE += [pool[i % len(pool)]["id"] for i in range(count)]
STARTED = 1793000000
SEED = "48A10CC0B2ED54EC"


def summary(floor, reason, attempt=1, result="win"):
    cards = HERO["starter_deck"][:4]
    return {
        "floor": floor, "result": result, "reason": reason, "turns": 9, "cards_played": 12,
        "damage_by_card": {card: 12 - i * 2 for i, card in enumerate(cards)},
        "boss_id": SEQUENCE[floor - 1], "band": 1 if floor <= 3 else 2 if floor <= 6 else 3,
        "attempt": attempt, "duration_s": 180,
    }


def record(status, floor, summaries, treasures=2, bundles=3, result=None):
    picked = [t["id"] for t in TREASURES[:treasures]]
    drafts = []
    for i, treasure in enumerate(picked):
        drafts.append({"floor": 1 + i * 2, "kind": "treasure", "offered_ids": [treasure], "picked_id": treasure, "card_ids_added": []})
    deck = list(HERO["starter_deck"])
    for i in range(bundles):
        bundle = BUNDLES[i % len(BUNDLES)]
        drafts.append({"floor": i + 1, "kind": "bundle", "offered_ids": [bundle["id"]], "picked_id": bundle["id"], "card_ids_added": bundle["cards"]})
        deck += bundle["cards"]
    damage = {}
    for row in summaries:
        for card, amount in row["damage_by_card"].items():
            damage[card] = damage.get(card, 0) + amount
    rec = {
        "run_id": "%s-%d" % (SEED, STARTED), "run_seed_hex": SEED, "seed_source": "random",
        "hero_id": HERO["id"], "floors_per_run": 8, "band_split": [3, 3, 2], "treasure_floors": [1, 3, 5],
        "boss_sequence": SEQUENCE, "floor": floor, "status": status, "deck": deck, "treasures": picked,
        "drafts": drafts, "match_attempts": {str(r["floor"]): r["attempt"] for r in summaries},
        "match_summaries": summaries, "started_at": STARTED, "updated_at": STARTED + 3000,
        "play_seconds": 1394,
        "totals": {"matches_played": len(summaries), "turns": 9 * len(summaries), "damage_by_card": damage, "cards_drafted": bundles * 3, "treasures_taken": treasures},
    }
    if result is not None:
        rec["result"] = result
        rec["ended_at"] = STARTED + 3000
    return rec


def mid_run():
    return record("pre_match", 4, [summary(1, "hero_dead"), summary(2, "hero_dead"), summary(3, "hero_dead")])


def victory():
    rows = [summary(f, "hero_dead") for f in range(1, 9)]
    return record("victory", 8, rows, 3, 7, {"outcome": "victory", "floors_cleared": 8, "floor_reached": 8, "total_turns": 72, "ended_by": None, "abandon_reason": None})


def defeat():
    rows = [summary(1, "hero_dead"), summary(2, "hero_dead"), summary(3, "hero_dead", 2), summary(4, "hero_dead"), summary(5, "hero_dead", 1, "loss")]
    return record("defeat", 5, rows, 2, 4, {"outcome": "defeat", "floors_cleared": 4, "floor_reached": 5, "total_turns": 45, "ended_by": SEQUENCE[4], "abandon_reason": None})


def abandoned():
    rows = [summary(1, "hero_dead"), summary(2, "hero_dead")]
    return record("abandoned", 3, rows, 1, 2, {"outcome": "abandoned", "floors_cleared": 2, "floor_reached": 3, "total_turns": 18, "ended_by": None, "abandon_reason": "player"})


def treasure_offer(count, flags):
    ids = sorted(t["id"] for t in TREASURES if t["unlock"] is None)[:count]
    options = [{"id": ident, "affine": 1 if i == 0 else 0} for i, ident in enumerate(ids)]
    return {"kind": "treasure", "floor": 3, "option_ids": ids, "flags": flags, "options": options, "deck_size": 24, "deck_size_after": 24, "allow_skip": False}


def bundle_offer():
    picks = sorted(BUNDLES, key=lambda b: b["id"])[:3]
    options = [{"id": b["id"], "theme": b["theme"], "n_tag": 3 + i} for i, b in enumerate(picks)]
    return {"kind": "bundle", "floor": 3, "option_ids": [b["id"] for b in picks], "flags": [], "options": options, "deck_size": 24, "deck_size_after": 27, "allow_skip": False}


def post_reward():
    rec = mid_run()
    rec.update({"status": "post_match_reward", "floor": 3, "reward_step": "treasure"})
    return rec


def locked_rows():
    hints = [("Fortune", "Win a run with any hero: 0 / 1"), ("Order", "Defeat 16 bosses: 8 / 16"), ("Shadow", "Reach floor 8 with Decay: 0 / 1")]
    return [{"id": "hero_%s" % name.lower(), "name": name, "hint": hint} for name, hint in hints]


def log_rows():
    return [
        {"run_id": "a", "hero_id": HERO["id"], "hero": HERO["name"], "date": "2026-11-03", "seed": SEED, "custom_seed": True, "details": True, "result": "Victory", "floors": "8 of 8", "deck_size": 36, "top_cards": "Cleave Through, Iron Vanguard", "retried": False},
        {"run_id": "b", "hero_id": HERO["id"], "hero": HERO["name"], "date": "2026-11-02", "seed": "0123456789ABCDEF", "custom_seed": False, "details": True, "result": "Defeat on floor 5 by Bone Collector", "floors": "4 of 8", "deck_size": 27, "top_cards": "Rusted Axe", "retried": True},
        {"run_id": "c", "hero_id": HERO["id"], "hero": HERO["name"], "date": "2026-11-01", "seed": "FEDCBA9876543210", "custom_seed": False, "details": True, "result": "Abandoned", "floors": "2 of 8", "deck_size": 21, "top_cards": "", "retried": False},
    ]


TS150 = {"settings": {"text_scale": 1.5}}
FIXTURES = {
    "fresh_profile": {},
    "mid_run_floor4": {"record": mid_run()},
    "victory_sample": {"record": victory(), "unlocks_granted": ["unlock.hero_decay"], "overrides": {"unlocks": ["New hero unlocked: Mother Wythe"]}},
    "defeat_sample": {"record": defeat()},
    "abandoned_sample": {"record": abandoned()},
    "locked_heroes": {"overrides": {"locked": locked_rows()}},
    "draft_treasure_sample": {"record": post_reward(), "offer": treasure_offer(3, [])},
    "draft_bundle_sample": {"record": post_reward(), "offer": bundle_offer()},
    "draft_treasure_short": {"record": post_reward(), "offer": treasure_offer(2, ["short"])},
    "resume_prompt": {"active_run": mid_run()},
    "run_log_sample": {"overrides": {"rows": log_rows(), "filters": [{"id": HERO["id"], "name": HERO["name"]}], "stats_lines": [], "total": 3, "more": False}},
    "data_error_sample": {"overrides": {"rows": [{"file": "cards_war.json", "id": "war_%d" % i, "code": "E_SCHEMA", "message": "row %d does not fit the schema" % i} for i in range(12)], "report_text": "12 rows"}},
    "toast_sample": {"toasts": [{"kind": "unlock", "key": "unlock.a", "title": "New hero unlocked: Mother Wythe", "subtitle": "Win 1 runs", "swatch": "decay"}, {"kind": "warning", "title": "The run could not be saved. Check disk space."}, {"kind": "unlock", "key": "unlock.b", "title": "New treasure unlocked: Plague Bell", "subtitle": "Win 1 runs"}]},
}
for base in ("draft_bundle_sample", "locked_heroes", "victory_sample", "defeat_sample"):
    FIXTURES[base + "_ts150"] = dict(FIXTURES[base], **TS150)

for name, body in FIXTURES.items():
    with open(OUT / (name + ".json"), "w", encoding="utf8", newline="\n") as handle:
        json.dump(body, handle, indent=1, ensure_ascii=False)
        handle.write("\n")
