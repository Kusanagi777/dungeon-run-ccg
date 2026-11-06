#!/usr/bin/env python3
"""card-effects story 005: writes the C11 fixture set (test tooling, not shipped).

Source list: ROWS below (C11 rows 1-46, DSL verbatim from
design/gdd/card-effects.md C11) plus TOKENS. Outputs, all from that one list:
  tests/fixtures/cards_effects_test.json        flat array of the row hosts + tokens
  tests/fixtures/data/card_effects_v1/          full DD-T01 folder (flat records
                                                + CardFactory.make_fixture_card_set()
                                                + one hero, one boss card, three
                                                bundles over three `fixture` cards)
  tests/fixtures/data/card_effects_bad_ref/     DD-T01 folder whose one card summons "nope"
Config bodies: the shipped assets/data/card_effects.json and match_rules.json;
the rest copied from tests/fixtures/data/clean/.
Run from the repo root: `python3 -I tests/fixtures/gen_cards_effects_fixture.py .`
Edit ROWS here, never the outputs: tests/integration/card_effects/
card_effects_fixture_load_test.gd fails when the folder drifts from the flat file.
"""
import json, os, shutil, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
CLEAN = os.path.join(ROOT, "tests/fixtures/data/clean")


def card(id, type, cost, set_, effects, keywords=(), attack=None, health=None, durability=None, extra=None):
    """CardFactory.make_card_def shape (same defaults, same field order)."""
    rec = {
        "id": id, "name": "Test Card", "set": set_, "type": type, "cost": cost,
        "attack": 1 if attack is None else attack, "health": 1 if health is None else health,
        "durability": 1 if durability is None else durability,
        "rarity": "common", "keywords": list(keywords), "spell_damage": 0,
        "effects": effects, "tags": [], "text": {"key": "card.%s.text" % id, "en": ""},
        "token": False, "art": "cards/%s" % id,
    }
    rec.update(extra or {})
    if type == "spell":
        for k in ("attack", "health", "durability"):
            rec.pop(k)
    elif type == "weapon":
        rec.pop("health")
    else:
        rec.pop("durability")
    return rec


def power(id, effects):
    return {"id": id, "name": "Test Power", "cost": 2, "effects": effects,
            "text": {"key": "power.%s.text" % id, "en": ""}, "art": "powers/%s" % id}


def boss(id, passive, deck):
    return {"id": id, "name": "Test Boss", "band": 1, "health": 30, "hero_power": "power_fx_row_44_brand",
            "passive": passive, "passive_text": {"key": "boss.%s.passive" % id, "en": ""},
            "deck": deck, "ai_profile": "default", "tags": [],
            "intro_text": {"key": "boss.%s.intro" % id, "en": ""}, "art": "bosses/%s" % id}


def treasure(id, effects):
    return {"id": id, "name": "Test Treasure", "rarity": "common", "tags": ["universal"], "effects": effects,
            "unlock": None, "text": {"key": "treasure.%s.text" % id, "en": ""}, "art": "treasures/%s" % id}


def fx(text):
    return json.loads("[" + text + "]")


M, S, W = "minion", "spell", "weapon"
# (row, kind, id, type, set, keywords, DSL, extra) — DSL verbatim from C11.
ROWS = [
    (1, "card", "war_fx_row_01_weapon_buff", M, "war", ["battlecry"], '{"trigger":"battlecry","targets":"owner_weapon","ops":[{"op":"buff","attack":1}]}', None),
    (2, "card", "war_fx_row_02_axe_equip", M, "war", ["battlecry"], '{"trigger":"battlecry","ops":[{"op":"equip","card_id":"war_token_axe"}]}', None),
    (3, "card", "war_fx_row_03_charge_sweep", M, "war", ["charge", "battlecry"], '{"trigger":"battlecry","targets":"all_enemy_minions","ops":[{"op":"damage","amount":1}]}', None),
    (4, "card", "war_fx_row_04_armed_taunt", M, "war", ["taunt", "battlecry"], '{"trigger":"battlecry","condition":{"exists":"owner_weapon"},"targets":"self","ops":[{"op":"buff","attack":2,"health":2}]}', None),
    (5, "card", "war_fx_row_05_hero_armor", M, "war", [], '{"trigger":"on_attack","scope":{"attacker":"owner_hero"},"targets":"owner","ops":[{"op":"armor","amount":2}]}', None),
    (6, "card", "war_fx_row_06_weapon_strike", S, "war", [], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"damage","amount":{"ref":"owner.weapon_attack"},"spell_damage":false}]}', None),
    (7, "card", "war_fx_row_07_deathrattle_axe", W, "war", ["deathrattle"], '{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":2}]}', {"attack": 2, "durability": 2}),
    (8, "hero_power", "power_fx_row_08_whetstone", None, None, None, '{"trigger":"hero_power","ops":[{"op":"conditional","if":{"exists":"owner_weapon"},"then":[{"op":"buff","targets":"owner_weapon","attack":1,"duration":"until_end_of_turn"}],"else":[{"op":"equip","card_id":"war_whetstone_blade"}]}]}', None),
    (9, "card", "decay_fx_row_09_husk_summoner", M, "decay", ["deathrattle"], '{"trigger":"deathrattle","ops":[{"op":"summon","card_id":"decay_husk","count":2,"position":"source_slot"}]}', None),
    (10, "card", "decay_fx_row_10_sacrifice", M, "decay", ["battlecry"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"destroy"},{"op":"draw","count":2}]}', None),
    (11, "card", "decay_fx_row_11_grave_feeder", M, "decay", [], '{"trigger":"on_minion_died","scope":{"who":"friendly_minion"},"targets":"self","ops":[{"op":"buff","attack":1,"health":1}]}', None),
    (12, "card", "decay_fx_row_12_spiteful_corpse", M, "decay", ["deathrattle"], '{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"source.attack"}}]}', None),
    (13, "card", "decay_fx_row_13_plague_bearer", M, "decay", ["poisonous", "deathrattle"], '{"trigger":"deathrattle","ops":[{"op":"add_to_hand","from":{"pool":"collectible","filter":{"set":"decay"}},"count":1}]}', None),
    (14, "card", "decay_fx_row_14_reanimate", S, "decay", [], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly","has_trigger":"deathrattle"}},"ops":[{"op":"retrigger","trigger":"deathrattle"}]}', None),
    (15, "card", "decay_fx_row_15_rot_armor", S, "decay", [], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"conditional","if":{"test":["target",{"has_trigger":"deathrattle"}]},"then":[{"op":"buff","attack":4,"health":4}],"else":[{"op":"buff","attack":2,"health":2}]},{"op":"give_keyword","keyword":"taunt"}]}', None),
    (16, "hero_power", "power_fx_row_16_rot", None, None, None, '{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"damage","amount":1},{"op":"conditional","if":{"test":["target",{"is_dying":true}]},"then":[{"op":"summon","card_id":"decay_husk","position":"end"}]}]}', None),
    (17, "card", "knowledge_fx_row_17_apprentice", M, "knowledge", ["spell_damage"], None, {"spell_damage": 1}),
    (18, "card", "knowledge_fx_row_18_bolt", S, "knowledge", [], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":3}]}', None),
    (19, "card", "knowledge_fx_row_19_storm", S, "knowledge", [], '{"trigger":"cast","targets":"all_enemy_characters","ops":[{"op":"damage","amount":2}]}', None),
    (20, "card", "knowledge_fx_row_20_study", S, "knowledge", ["discover"], '{"trigger":"cast","ops":[{"op":"discover","pool":"collectible","filter":{"type":"spell"}}]}', None),
    (21, "card", "knowledge_fx_row_21_scribe", M, "knowledge", [], '{"trigger":"on_card_played","scope":{"by":"owner","card":{"type":"spell"}},"ops":[{"op":"draw","count":1}]}', None),
    (22, "card", "knowledge_fx_row_22_hoarder", M, "knowledge", [], '{"trigger":"turn_end","scope":{"side":"owner"},"condition":{"cmp":[{"ref":"owner.hand_size"},">=",5]},"targets":{"selector":"random_enemy_character"},"ops":[{"op":"damage","amount":3,"spell_damage":false}]}', None),
    (23, "card", "knowledge_fx_row_23_deep_freeze", S, "knowledge", ["freeze"], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"destroy"}],"else":[{"op":"freeze"}]}]}', None),
    (24, "card", "knowledge_fx_row_24_archivist", M, "knowledge", ["aura"], '{"trigger":"aura","scope":{"zone":"hand"},"targets":{"selector":"hand","filter":{"type":"spell"}},"ops":[{"op":"aura","cost":-1}]}', None),
    (25, "hero_power", "power_fx_row_25_insight", None, None, None, '{"trigger":"hero_power","ops":[{"op":"buff","targets":{"selector":"deck_top","n":1},"cost":1,"duration":"until_end_of_turn"},{"op":"draw","count":1}]}', None),
    (26, "card", "neutral_fx_row_26_aura_lord", M, "neutral", ["aura"], '{"trigger":"aura","targets":{"selector":"all_friendly_minions","filter":{"not_self":true}},"ops":[{"op":"aura","attack":1,"health":1}]}', None),
    (27, "card", "neutral_fx_row_27_flank_banner", M, "neutral", ["aura"], '{"trigger":"aura","targets":"adjacent","ops":[{"op":"aura","attack":2}]}', None),
    (28, "card", "neutral_fx_row_28_taunt_wall", M, "neutral", ["taunt", "divine_shield"], None, None),
    (29, "card", "neutral_fx_row_29_silencer", M, "neutral", ["battlecry", "silence"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"silence"}]}', None),
    (30, "card", "neutral_fx_row_30_recaller", M, "neutral", ["battlecry"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"return_to_hand"}]}', None),
    (31, "card", "neutral_fx_row_31_polymorpher", M, "neutral", ["battlecry"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"transform","card_id":"neutral_sheep"}]}', None),
    (32, "card", "neutral_fx_row_32_mimic", M, "neutral", ["battlecry"], '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"copy_to_hand"}]}', None),
    (33, "card", "neutral_fx_row_33_smite_or_mend", S, "neutral", [], '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"choose_one","options":[{"label_key":"opt.smite","ops":[{"op":"damage","amount":2}]},{"label_key":"opt.mend","ops":[{"op":"heal","amount":4}]}]}]}', None),
    (34, "card", "neutral_fx_row_34_twin_pinger", M, "neutral", [], '{"trigger":"turn_start","scope":{"side":"owner"},"ops":[{"op":"repeat","times":2,"ops":[{"op":"damage","targets":"random_enemy_minion","amount":1}]}]}', None),
    (35, "passive", "boss_fx_row_35_mending_warden", None, None, None, '{"trigger":"turn_start","scope":{"side":"owner"},"targets":"owner_hero","ops":[{"op":"heal","amount":5}]}', None),
    (36, "passive", "boss_fx_row_36_toll_keeper", None, None, None, '{"trigger":"modify_cost","scope":{"card":{"side":"enemy","type":"minion"}},"ops":[{"op":"modify_value","delta":1}]}', None),
    (37, "passive", "boss_fx_row_37_blood_priest", None, None, None, '{"trigger":"on_heal","scope":{"who":"enemy","min_amount":1},"targets":"enemy_hero","ops":[{"op":"damage","amount":1}]}', None),
    (38, "treasure", "treasure_fx_row_38_iron_hide", None, None, None, '{"trigger":"on_match_start","targets":"owner","ops":[{"op":"armor","amount":10}]}', None),
    (39, "treasure", "treasure_fx_row_39_free_power", None, None, None, '{"trigger":"modify_cost","scope":{"card":{"side":"friendly","kind":"hero_power"}},"ops":[{"op":"modify_value","set":0}]}', None),
    (40, "treasure", "treasure_fx_row_40_spell_focus", None, None, None, '{"trigger":"modify_damage","scope":{"source":{"side":"friendly","type":"spell"}},"ops":[{"op":"modify_value","delta":1}]}', None),
    (41, "treasure", "treasure_fx_row_41_quick_draw", None, None, None, '{"trigger":"on_draw","scope":{"side":"owner"},"targets":"trigger_subject","ops":[{"op":"buff","cost":-1}]}', None),
    (42, "treasure", "treasure_fx_row_42_rush_banner", None, None, None, '{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","keywords":["rush"]}]}', None),
    (43, "treasure", "treasure_fx_row_43_twin_strikes", None, None, None, '{"trigger":"modify_max_attacks","scope":{"who":"owner_hero"},"ops":[{"op":"modify_value","set":2}]}', None),
    (44, "hero_power", "power_fx_row_44_brand", None, None, None, '{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":1}]}', None),
    (45, "card", "neutral_fx_row_45_death_counter", M, "neutral", ["deathrattle"], '{"trigger":"on_minion_died","scope":{"who":"any_minion"},"ops":[{"op":"add_counter","key":"seen","amount":1}]}, {"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"counter.seen"}}]}', None),
    (46, "card", "decay_fx_row_46_husk_purge", S, "decay", [], '{"trigger":"cast","ops":[{"op":"set_counter","key":"n","value":{"count":{"selector":"all_friendly_minions","filter":{"tag":"husk"}}}},{"op":"destroy","targets":{"selector":"all_friendly_minions","filter":{"tag":"husk"}}},{"op":"damage","targets":"all_enemy_characters","amount":{"ref":"counter.n"}}]}', None),
]
# The tokens the rows summon, equip or transform into (CR-3 `token: true`).
TOKENS = [
    card("war_token_axe", W, 2, "war", [], attack=3, durability=2, extra={"token": True}),
    card("war_whetstone_blade", W, 1, "war", [], attack=1, durability=2, extra={"token": True}),
    card("decay_husk", M, 1, "decay", [], attack=1, health=1, extra={"token": True, "tags": ["husk"]}),
    card("neutral_sheep", M, 1, "neutral", [], attack=1, health=1, extra={"token": True}),
]
BOSS_DECK = ["boss_fx_grave_rat", "neutral_test_vanilla_1_1"]


def vanilla_set():
    """CardFactory.make_fixture_card_set(), field for field."""
    out = [card("neutral_test_vanilla_1_1", M, 1, "neutral", [], attack=1, health=1),
           card("neutral_test_vanilla_2_2", M, 2, "neutral", [], attack=2, health=2),
           card("neutral_test_vanilla_3_4", M, 3, "neutral", [], attack=3, health=4),
           card("neutral_test_vanilla_2_5", M, 4, "neutral", [], attack=2, health=5)]
    for kw in ["taunt", "charge", "rush", "divine_shield", "windfury", "stealth", "lifesteal", "poisonous"]:
        out.append(card("neutral_test_%s" % kw, M, 2, "neutral", [], [kw], attack=2, health=2))
    out.append(card("neutral_test_weapon_2_2", W, 2, "neutral", [], attack=2, durability=2))
    eff = lambda ops, targets=None: dict({"trigger": "cast", "scope": {}, "condition": {}, "ops": ops, "once_per_turn": False}, **({"targets": targets} if targets else {}))
    out.append(card("neutral_test_bolt", S, 1, "neutral", [eff([{"op": "damage", "amount": 1}], {"selector": "chosen", "filter": {"kind": "any"}})]))
    out.append(card("neutral_test_draw_two", S, 2, "neutral", [eff([{"op": "draw", "count": 2}])]))
    return out


def infra():
    """Folder-only records: a boss card for boss decks, and three neutral
    cards tagged `fixture` behind three bundles (DD-R04 `min_bundle_pool` 3)."""
    cards = [card("boss_fx_grave_rat", M, 1, "boss", [], attack=1, health=1)]
    for i in (1, 2, 3):
        cards.append(card("neutral_fx_infra_%d" % i, M, 1, "neutral", [], attack=1, health=1, extra={"tags": ["fixture"]}))
    bundles = [{"id": "bundle_neutral_fx_%s" % x, "name": "Test Bundle", "set": "neutral", "theme": "fixture",
                "cards": ["neutral_fx_infra_1", "neutral_fx_infra_2", "neutral_fx_infra_3"], "unlock": None,
                "text": {"key": "bundle.bundle_neutral_fx_%s.text" % x, "en": ""}} for x in ("a", "b", "c")]
    return cards + bundles


def row_records():
    records = []
    for row, kind, id_, type_, set_, kws, dsl, extra in ROWS:
        effects = fx(dsl) if dsl else []
        if kind == "card":
            stats = {}
            if extra and "attack" in extra:
                stats = {"attack": extra["attack"], "durability": extra.get("durability")}
            rec = card(id_, type_, 2, set_, effects, kws, attack=stats.get("attack", 2), health=2,
                       durability=stats.get("durability", 2), extra={k: v for k, v in (extra or {}).items() if k not in ("attack", "durability")})
        elif kind == "hero_power":
            rec = power(id_, effects)
        elif kind == "passive":
            rec = boss(id_, effects[0], BOSS_DECK)
        else:
            rec = treasure(id_, effects)
        records.append(rec)
    return records


def file_of(rec):
    if "band" in rec:
        return "bosses.json"
    if rec["id"].startswith("bundle_"):
        return "bundles.json"
    if rec["id"].startswith("power_"):
        return "hero_powers.json"
    if rec["id"].startswith("treasure_"):
        return "treasures.json"
    return "cards_%s.json" % rec["set"]


def write_json(path, body):
    with open(path, "w") as f:
        json.dump(body, f, indent=2)
        f.write("\n")


def write_folder(folder, records):
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)
    for name in os.listdir(CLEAN):
        if name.endswith(".json") and not name.startswith("cards_") and name not in (
                "bosses.json", "hero_powers.json", "treasures.json", "heroes.json", "bundles.json",
                "card_effects.json", "match_rules.json"):
            shutil.copy(os.path.join(CLEAN, name), os.path.join(folder, name))
    for name in ("card_effects.json", "match_rules.json"):
        shutil.copy(os.path.join(ROOT, "assets/data", name), os.path.join(folder, name))
    files = {n: [] for n in ("cards_war.json", "cards_neutral.json", "cards_boss.json", "hero_powers.json",
                             "bosses.json", "treasures.json", "bundles.json")}
    for rec in records:
        files.setdefault(file_of(rec), []).append(rec)
    hero = {"id": "hero_war", "name": "Test Hero", "set": "war", "health": 30,
            "hero_power": "power_fx_row_08_whetstone" if any(r["id"] == "power_fx_row_08_whetstone" for r in records) else "power_fx_plain",
            "starter_deck": [r["id"] for r in vanilla_set()], "unlock": None,
            "text": {"key": "hero.hero_war.text", "en": ""}, "art": "heroes/hero_war"}
    files["heroes.json"] = [hero]
    for name, recs in files.items():
        write_json(os.path.join(folder, name), {"schema_version": 1, "records": sorted(recs, key=lambda r: r["id"])})


def main():
    rows = row_records()
    flat = rows + TOKENS
    write_json(os.path.join(ROOT, "tests/fixtures/cards_effects_test.json"), flat)
    write_folder(os.path.join(ROOT, "tests/fixtures/data/card_effects_v1"), flat + vanilla_set() + infra())
    bad = card("neutral_fx_bad_ref", M, 2, "neutral", [], attack=2, health=2,
               extra={"effects": [{"trigger": "battlecry", "ops": [{"op": "summon", "card_id": "nope"}]}], "keywords": ["battlecry"]})
    plain_power = power("power_fx_plain", [])
    plain_boss = {"id": "boss_fx_plain", "name": "Test Boss", "band": 1, "health": 30, "hero_power": "power_fx_plain",
                  "passive": None, "deck": BOSS_DECK, "ai_profile": "default", "tags": [],
                  "intro_text": {"key": "boss.boss_fx_plain.intro", "en": ""}}
    write_folder(os.path.join(ROOT, "tests/fixtures/data/card_effects_bad_ref"),
                 vanilla_set() + infra() + [bad, plain_power, plain_boss])
    print("rows %d, flat %d" % (len(rows), len(flat)))


main()
