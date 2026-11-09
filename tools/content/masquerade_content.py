"""Author and audit The Midnight Masquerade collection.

Usage:
    python tools/content/masquerade_content.py          # write the staged files
    python tools/content/masquerade_content.py --check  # audit only; exit 1 on a failure

The design is design/expansions/midnight-masquerade.md. Every Masked minion
carries one Unmask effect: the first time it survives damage it transforms into
its printed true form, a token record in the same file. Some true forms are
upgrades (theme `grand_reveal`), some are downgrades (theme `keep_the_mask`).
"""

from __future__ import annotations

import collections
import glob
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "assets" / "data"
SET_ID = "midnight-masquerade"
OUT = DATA / SET_ID
CLASSES = ["war", "decay", "knowledge", "fortune", "order", "shadow"]
HEROES = {c: "hero_" + c for c in CLASSES}
REVEAL = "grand_reveal"
KEEP = "keep_the_mask"
CLASS_THEME = {"war": REVEAL, "decay": REVEAL, "fortune": REVEAL,
               "knowledge": KEEP, "order": KEEP, "shadow": KEEP}

cards: list[dict] = []
metadata: dict[str, dict] = {}


def text(kind: str, rid: str, en: str) -> dict:
    return {"key": f"{kind}.{rid}.text", "en": en}


def chosen(side: str | None = None, kind: str = "minion") -> dict:
    f = {"kind": kind}
    if side:
        f["side"] = side
    return {"selector": "chosen", "filter": f}


def unmask(true_id: str) -> dict:
    """The Unmask rule: survive damage, transform into the printed true form."""
    return {"trigger": "on_damage_taken", "scope": {"who": "self"},
            "condition": {"cmp": [{"ref": "trigger_subject.health"}, ">", 0]},
            "targets": "self", "ops": [{"op": "transform", "card_id": true_id}]}


def unmask_flip(heads_id: str, tails_id: str) -> dict:
    """Fortune's Unmask: a coin picks which printed true form appears."""
    return {"trigger": "on_damage_taken", "scope": {"who": "self"},
            "condition": {"cmp": [{"ref": "trigger_subject.health"}, ">", 0]},
            "targets": "self", "ops": [{"op": "conditional", "if": {"flip": 50},
                                        "then": [{"op": "transform", "card_id": heads_id}],
                                        "else": [{"op": "transform", "card_id": tails_id}]}]}


def minion(set_: str, slug: str, name: str, cost: int, atk: int, hp: int, rarity: str, en: str,
           theme: str, *, keywords=(), effects=(), tribes=None, role="body", package=None,
           playstyle=None, enablers=None, token=False, tags_extra=()) -> str:
    cid = f"{set_}_masq_{slug}"
    rec = {"id": cid, "name": name, "set": set_, "type": "minion", "cost": cost, "rarity": rarity,
           "keywords": list(keywords), "effects": list(effects),
           "tags": ([theme] if theme else []) + list(tags_extra), "collection_id": SET_ID,
           "text": text("card", cid, en), "attack": atk, "health": hp}
    if tribes:
        rec["tribes"] = tribes
    if token:
        rec["token"] = True
    cards.append(rec)
    if not token:
        row = {"package": package or theme, "role": role}
        if playstyle:
            row["playstyle"] = playstyle
            row["enablers"] = list(enablers or [])
        metadata[cid] = row
    return cid


def spell(set_: str, slug: str, name: str, cost: int, rarity: str, en: str, theme: str, effects,
          *, school="shadow", role="answer", package=None, playstyle=None, enablers=None, keywords=()) -> str:
    cid = f"{set_}_masq_{slug}"
    cards.append({"id": cid, "name": name, "set": set_, "type": "spell", "cost": cost, "rarity": rarity,
                  "keywords": list(keywords), "effects": list(effects), "tags": [theme], "collection_id": SET_ID,
                  "text": text("card", cid, en), "schools": [school]})
    row = {"package": package or theme, "role": role}
    if playstyle:
        row["playstyle"] = playstyle
        row["enablers"] = list(enablers or [])
    metadata[cid] = row
    return cid


def true_form(set_: str, slug: str, name: str, cost: int, atk: int, hp: int, en: str = "",
              keywords=(), effects=(), tribes=None, extra=None) -> str:
    cid_ = minion(set_, slug, name, cost, atk, hp, "common", en, "", keywords=keywords,
                  effects=effects, tribes=tribes, token=True, tags_extra=["unmasked"])
    cards[-1].update(extra or {})
    return cid_


def masked(set_: str, slug: str, name: str, cost: int, atk: int, hp: int, rarity: str, before: str,
           true_id: str, true_desc: str, theme: str, **kw) -> str:
    """A Masked minion. [param before] is any printed text ahead of the Unmask line."""
    en = (before + " " if before else "") + f"Unmask: {true_desc}."
    effects = list(kw.pop("effects", ())) + [unmask(true_id)]
    return minion(set_, slug, name, cost, atk, hp, rarity, en, theme, effects=effects,
                  tags_extra=["masked"], **kw)


def dmg(amount: int, targets) -> dict:
    return {"op": "damage", "targets": targets, "amount": amount}


FRIENDLY_OTHERS = {"selector": "all_friendly_minions", "filter": {"not_self": True}}
FRIENDLY_MASKED = {"selector": "all_friendly_minions", "filter": {"tag": "masked"}}

# --- Neutral: 18 collectibles (12 common, 6 rare) ------------------------------------------

t = true_form("neutral", "reveler_unveiled", "Reveler Unveiled", 2, 4, 3, tribes=["human"])
N_REVELER = masked("neutral", "masked_reveler", "Masked Reveler", 2, 2, 2, "common", "", t,
                   "Becomes a 4/3 Reveler Unveiled", REVEAL, tribes=["human"], role="teaching")
t = true_form("neutral", "trembling_footman", "Trembling Footman", 2, 1, 1, tribes=["human"])
N_FINERY = masked("neutral", "borrowed_finery", "Borrowed Finery", 2, 3, 2, "common", "", t,
                  "Becomes a 1/1 Trembling Footman", KEEP, tribes=["human"], role="early")
N_PAGE = minion("neutral", "candle_page", "Candle Page", 1, 1, 1, "common",
                "Battlecry: Deal 1 damage to a minion.", REVEAL, keywords=["battlecry"],
                effects=[{"trigger": "battlecry", "targets": chosen(), "ops": [dmg(1, chosen())]}],
                tribes=["human"], role="enabler")
t = true_form("neutral", "tattling_maid", "Tattling Maid", 3, 2, 2, tribes=["human"])
N_DUCHESS = masked("neutral", "gossiping_duchess", "Gossiping Duchess", 3, 4, 3, "common", "", t,
                   "Becomes a 2/2 Tattling Maid", KEEP, tribes=["human"])
N_STEWARD = minion("neutral", "wine_steward", "Wine Steward", 2, 2, 2, "common",
                   "Battlecry: Give a friendly minion Poisonous.", KEEP, keywords=["battlecry"],
                   effects=[{"trigger": "battlecry", "targets": chosen("friendly"),
                             "ops": [{"op": "give_keyword", "targets": chosen("friendly"), "keyword": "poisonous"}]}],
                   tribes=["human"], role="support_poisonous", package="support_poisonous")
N_CHALICE = spell("neutral", "poisoned_chalice", "Poisoned Chalice", 1, "common",
                  "Give a friendly minion Poisonous. Deal 1 damage to it.", REVEAL,
                  [{"trigger": "cast", "targets": chosen("friendly"),
                    "ops": [{"op": "give_keyword", "targets": chosen("friendly"), "keyword": "poisonous"},
                            dmg(1, chosen("friendly"))]}],
                  school="alchemy", role="support_poisonous", package="support_poisonous")
t = true_form("neutral", "duelist_revealed", "Duelist Revealed", 3, 5, 4, "Rush.", keywords=["rush"], tribes=["human"])
N_DUELIST = masked("neutral", "masked_duelist", "Masked Duelist", 3, 2, 4, "common", "Rush.", t,
                   "Becomes a 5/4 Duelist Revealed with Rush", REVEAL, keywords=["rush"], tribes=["human"])
N_USHER = minion("neutral", "velvet_usher", "Velvet Usher", 4, 3, 5, "common",
                 "Taunt. Battlecry: Give a friendly minion Divine Shield.", KEEP, keywords=["taunt", "battlecry"],
                 effects=[{"trigger": "battlecry", "targets": chosen("friendly"),
                           "ops": [{"op": "give_keyword", "targets": chosen("friendly"), "keyword": "divine_shield"}]}],
                 tribes=["human"], role="protection")
t = true_form("neutral", "sommelier_revealed", "Thirsting Sommelier", 3, 4, 4, "Lifesteal.", keywords=["lifesteal"], tribes=["undead"])
N_SOMMELIER = masked("neutral", "blood_sommelier", "Blood Sommelier", 3, 2, 4, "common", "Lifesteal.", t,
                     "Becomes a 4/4 Thirsting Sommelier with Lifesteal", REVEAL, keywords=["lifesteal"],
                     tribes=["human"], role="support_lifesteal", package="support_lifesteal")
N_CURTAIN = spell("neutral", "curtain_call", "Curtain Call", 2, "common", "Deal 1 damage to all minions.", REVEAL,
                  [{"trigger": "cast", "ops": [dmg(1, "all_minions")]}], school="arcane", role="enabler")
cards[-1]["tags"].append(KEEP)
t = true_form("neutral", "shy_dancer", "Shy Dancer", 1, 1, 1, tribes=["human"])
N_DANCER = masked("neutral", "mirror_dancer", "Mirror Dancer", 1, 2, 2, "common", "", t,
                  "Becomes a 1/1 Shy Dancer", KEEP, tribes=["human"], role="early")
t = true_form("neutral", "crimson_count_revealed", "Crimson Count", 4, 5, 5, "Lifesteal.", keywords=["lifesteal"], tribes=["undead"])
N_CRIMSON = masked("neutral", "crimson_guest", "Crimson Guest", 4, 3, 4, "common", "", t,
                   "Becomes a 5/5 Crimson Count with Lifesteal", REVEAL, tribes=["human"],
                   role="support_lifesteal", package="support_lifesteal")

N_BELL = minion("neutral", "midnight_bell_ringer", "Midnight Bell-Ringer", 5, 3, 6, "rare",
                "At the end of your turn, deal 1 damage to your other minions.", REVEAL,
                effects=[{"trigger": "turn_end", "scope": {"side": "owner"}, "ops": [dmg(1, FRIENDLY_OTHERS)]}],
                tribes=["human"], role="engine")
N_VEILS = minion("neutral", "lady_of_veils", "Lady of Veils", 4, 3, 4, "rare",
                 "Battlecry: Silence another friendly minion and give it +1/+1.", KEEP, keywords=["battlecry", "silence"],
                 effects=[{"trigger": "battlecry", "targets": {"selector": "chosen", "filter": {"kind": "minion", "side": "friendly", "not_self": True}},
                           "ops": [{"op": "silence", "targets": {"selector": "chosen", "filter": {"kind": "minion", "side": "friendly", "not_self": True}}},
                                   {"op": "buff", "targets": {"selector": "chosen", "filter": {"kind": "minion", "side": "friendly", "not_self": True}}, "attack": 1, "health": 1}]}],
                 tribes=["human"], role="engine", package="support_silence")
t = true_form("neutral", "taster_revealed", "Hired Poisoner", 2, 3, 2, "Poisonous.", keywords=["poisonous"], tribes=["human"])
N_TASTER = masked("neutral", "poison_taster", "Poison Taster", 2, 1, 3, "rare", "", t,
                  "Becomes a 3/2 Hired Poisoner with Poisonous", REVEAL, tribes=["human"],
                  role="support_poisonous", package="support_poisonous")
N_UNVEILING = spell("neutral", "public_unveiling", "Public Unveiling", 3, "rare",
                    "Silence an enemy minion, then deal 2 damage to it.", KEEP,
                    [{"trigger": "cast", "targets": chosen("enemy"),
                      "ops": [{"op": "silence", "targets": chosen("enemy")}, dmg(2, chosen("enemy"))]}],
                    school="holy", role="answer", package="support_silence", keywords=["silence"])
N_RIVAL = minion("neutral", "jealous_rival", "Jealous Rival", 3, 3, 2, "rare",
                 "Battlecry: Deal 1 damage to another friendly minion and draw a card.", REVEAL, keywords=["battlecry"],
                 effects=[{"trigger": "battlecry", "targets": {"selector": "chosen", "filter": {"kind": "minion", "side": "friendly", "not_self": True}},
                           "ops": [dmg(1, {"selector": "chosen", "filter": {"kind": "minion", "side": "friendly", "not_self": True}}),
                                   {"op": "draw", "count": 1}]}],
                 tribes=["human"], role="recovery")
t = true_form("neutral", "double_revealed", "Unwound Double", 4, 2, 3, tribes=["construct"])
N_DOUBLE = masked("neutral", "clockwork_double", "Clockwork Double", 4, 5, 4, "rare", "", t,
                  "Becomes a 2/3 Unwound Double", KEEP, tribes=["construct"], role="threat")

# --- War: takes the hits ------------------------------------------------------------------
t = true_form("war", "gladiator_revealed", "Gladiator Unbound", 3, 5, 5,
              "Whenever this takes damage, gain +1 Attack.",
              effects=[{"trigger": "on_damage_taken", "scope": {"who": "self"}, "targets": "self", "ops": [{"op": "buff", "attack": 1}]}],
              tribes=["human"])
W_GLAD = masked("war", "scarred_gladiator", "Scarred Gladiator", 3, 2, 4, "common", "", t,
                "Becomes a 5/5 that gains +1 Attack whenever it takes damage", REVEAL, tribes=["human"])
W_PARRY = spell("war", "parry_and_riposte", "Parry and Riposte", 1, "common",
                "Deal 1 damage to a friendly minion. Give it +2 Attack.", REVEAL,
                [{"trigger": "cast", "targets": chosen("friendly"),
                  "ops": [dmg(1, chosen("friendly")), {"op": "buff", "targets": chosen("friendly"), "attack": 2}]}],
                school="martial", role="enabler")
t = true_form("war", "baron_revealed", "Bloodied Baron", 4, 6, 5, "Lifesteal.", keywords=["lifesteal"], tribes=["undead"])
W_BARON = masked("war", "masked_baron", "Masked Baron", 4, 3, 4, "rare", "", t,
                 "Becomes a 6/5 Bloodied Baron with Lifesteal", REVEAL, tribes=["human"],
                 role="support_lifesteal", package="support_lifesteal")
t = true_form("war", "varrus_revealed", "Varrus, Blade Unsheathed", 5, 6, 6, "Windfury.", keywords=["windfury"], tribes=["human"])
masked("war", "count_varrus", "Count Varrus, the Smiling Blade", 5, 4, 6, "legendary", "", t,
       "Becomes a 6/6 with Windfury", REVEAL, tribes=["human"], role="legendary",
       package="varrus_aggro", playstyle="aggro", enablers=[W_PARRY, W_GLAD])
minion("war", "madame_steel", "Madame Steel, the Ringmaster", 6, 5, 7, "legendary",
       "Taunt. At the end of your turn, deal 1 damage to all other minions.", REVEAL, keywords=["taunt"],
       effects=[{"trigger": "turn_end", "scope": {"side": "owner"},
                 "ops": [dmg(1, {"selector": "all_minions", "filter": {"not_self": True}})]}],
       tribes=["human"], role="legendary", package="steel_control", playstyle="control",
       enablers=[W_BARON, W_GLAD])

# --- Decay: pings its own guests -----------------------------------------------------------
t = true_form("decay", "widow_revealed", "Widow in Black", 2, 3, 3, "Deathrattle: Summon a 1/1 Husk.",
              keywords=["deathrattle"],
              effects=[{"trigger": "deathrattle", "ops": [{"op": "summon", "card_id": "decay_husk", "count": 1, "position": "source_slot"}]}],
              tribes=["undead"])
D_WIDOW = masked("decay", "mourning_widow", "Mourning Widow", 2, 1, 3, "common", "", t,
                 "Becomes a 3/3 with 'Deathrattle: Summon a 1/1 Husk'", REVEAL, tribes=["human"])
D_TOAST = spell("decay", "toxic_toast", "Toxic Toast", 2, "common",
                "Deal 1 damage to all friendly minions. Draw a card.", REVEAL,
                [{"trigger": "cast", "ops": [dmg(1, "all_friendly_minions"), {"op": "draw", "count": 1}]}],
                school="alchemy", role="enabler")
t = true_form("decay", "doctor_revealed", "Plague Doctor Unmasked", 3, 4, 4, "Poisonous.", keywords=["poisonous"], tribes=["undead"])
D_DOCTOR = masked("decay", "beaked_physician", "Beaked Physician", 3, 2, 3, "rare", "", t,
                  "Becomes a 4/4 with Poisonous", REVEAL, tribes=["human"],
                  role="support_poisonous", package="support_poisonous")
minion("decay", "lady_ashgrave", "Lady Ashgrave, the Widow Bride", 4, 3, 4, "legendary",
       "Battlecry: Destroy another friendly minion. Gain its Attack and Health.", REVEAL, keywords=["battlecry"],
       effects=[{"trigger": "battlecry",
                 "targets": {"selector": "chosen", "filter": {"kind": "minion", "side": "friendly", "not_self": True}},
                 "ops": [{"op": "buff", "targets": "self", "attack": {"ref": "target.attack"}, "health": {"ref": "target.health"}},
                         {"op": "destroy", "targets": {"selector": "chosen", "filter": {"kind": "minion", "side": "friendly", "not_self": True}}}]}],
       tribes=["undead"], role="legendary", package="ashgrave_sacrifice", playstyle="sacrifice",
       enablers=[D_WIDOW, D_TOAST])
minion("decay", "the_last_dancer", "The Last Dancer", 5, 4, 5, "legendary",
       "Deathrattle: Summon two Masked Revelers.", REVEAL, keywords=["deathrattle"],
       effects=[{"trigger": "deathrattle", "ops": [{"op": "summon", "card_id": N_REVELER, "count": 2, "position": "source_slot"}]}],
       tribes=["undead"], role="legendary", package="last_dance_attrition", playstyle="attrition",
       enablers=[D_DOCTOR, D_TOAST])

# --- Knowledge: freezes and silences -------------------------------------------------------
K_HUSH = spell("knowledge", "hush", "Hush", 1, "common", "Silence a minion. Draw a card.", KEEP,
               [{"trigger": "cast", "targets": chosen(),
                 "ops": [{"op": "silence", "targets": chosen()}, {"op": "draw", "count": 1}]}],
               school="arcane", role="support_silence", package="support_silence", keywords=["silence"])
t = true_form("knowledge", "scholar_revealed", "Bespectacled Scholar", 3, 2, 3, "Spell Damage +1.", keywords=["spell_damage"], tribes=["human"], extra={"spell_damage": 1})
K_SCHOLAR = masked("knowledge", "frost_masked_scholar", "Frost-Masked Scholar", 3, 4, 3, "common", "", t,
                   "Becomes a 2/3 with Spell Damage +1", KEEP, tribes=["human"])
K_MAGE = minion("knowledge", "mirror_mage", "Mirror Mage", 4, 3, 4, "rare",
                "Battlecry: Deal 2 damage to an enemy minion and Freeze it.", KEEP, keywords=["battlecry", "freeze"],
                effects=[{"trigger": "battlecry", "targets": chosen("enemy"),
                          "ops": [dmg(2, chosen("enemy")), {"op": "freeze", "targets": chosen("enemy")}]}],
                tribes=["human"], role="answer")
minion("knowledge", "archivist_of_faces", "The Archivist of Faces", 6, 4, 6, "legendary",
       "Battlecry: Silence all enemy minions.", KEEP, keywords=["battlecry", "silence"],
       effects=[{"trigger": "battlecry", "ops": [{"op": "silence", "targets": "all_enemy_minions"}]}],
       tribes=["human"], role="legendary", package="archivist_control", playstyle="control",
       enablers=[K_HUSH, K_MAGE])
t = true_form("knowledge", "velisande_revealed", "Velisande Unveiled", 3, 4, 5, "Spell Damage +2.", keywords=["spell_damage"], tribes=["human"], extra={"spell_damage": 2})
masked("knowledge", "velisande", "Velisande, Veiled Sorceress", 3, 2, 4, "legendary", "", t,
       "Becomes a 4/5 with Spell Damage +2", KEEP, tribes=["human"], role="legendary",
       package="velisande_combo", playstyle="combo", enablers=[K_SCHOLAR, N_CURTAIN])

# --- Fortune: reveals at random ------------------------------------------------------------
heads = true_form("fortune", "gambler_heads", "Lucky Gambler", 2, 5, 4, tribes=["human"])
tails = true_form("fortune", "gambler_tails", "Ruined Gambler", 2, 1, 1, tribes=["human"])
cid = "fortune_masq_gamblers_mask"
cards.append({"id": cid, "name": "Gambler's Mask", "set": "fortune", "type": "minion", "cost": 2,
              "rarity": "common", "keywords": [], "effects": [unmask_flip(heads, tails)],
              "tags": [REVEAL, "masked"], "collection_id": SET_ID,
              "text": text("card", cid, "Unmask: Flip a coin. Heads: becomes a 5/4. Tails: becomes a 1/1."),
              "attack": 2, "health": 2, "tribes": ["human"]})
metadata[cid] = {"package": REVEAL, "role": "body"}
F_MASK = cid
F_DICE = spell("fortune", "dice_of_the_ball", "Dice of the Ball", 1, "common",
               "Deal 1 damage to a random minion twice.", REVEAL,
               [{"trigger": "cast", "ops": [{"op": "repeat", "times": 2, "ops": [dmg(1, "random_minion")]}]}],
               school="arcane", role="enabler")
t = true_form("fortune", "noble_revealed", "Penniless Noble", 3, 3, 3, "Deathrattle: Add two Coins to your hand.",
              keywords=["deathrattle"],
              effects=[{"trigger": "deathrattle", "ops": [{"op": "add_to_hand", "card_id": "fortune_coin", "count": 2}]}],
              tribes=["human"])
F_NOBLE = masked("fortune", "gilded_noble", "Gilded Noble", 3, 2, 3, "rare", "", t,
                 "Becomes a 3/3 with 'Deathrattle: Add two Coins to your hand'", REVEAL, tribes=["human"], role="recovery")
minion("fortune", "fortunata", "Fortunata, the Lucky Debutante", 4, 3, 5, "legendary",
       "Battlecry: Deal 1 damage to your other minions. Draw 2 cards.", REVEAL, keywords=["battlecry"],
       effects=[{"trigger": "battlecry", "ops": [dmg(1, FRIENDLY_OTHERS), {"op": "draw", "count": 2}]}],
       tribes=["human"], role="legendary", package="fortunata_value", playstyle="value",
       enablers=[F_MASK, F_NOBLE])
spell("fortune", "house_always_wins", "The House Always Wins", 6, "legendary",
      "Three times: Heads, deal 3 damage to a random enemy minion. Tails, deal 1 to all minions.",
      REVEAL,
      [{"trigger": "cast", "ops": [{"op": "repeat", "times": 3, "ops": [
          {"op": "conditional", "if": {"flip": 50},
           "then": [dmg(3, "random_enemy_minion")], "else": [dmg(1, "all_minions")]}]}]}],
      school="arcane", role="legendary", package="house_control", playstyle="control",
      enablers=[F_DICE, F_NOBLE])

# --- Order: Divine Shield keeps strong masks on --------------------------------------------
t = true_form("order", "debutante_revealed", "Blushing Debutante", 2, 1, 1, tribes=["human"])
O_DEB = masked("order", "shielded_debutante", "Shielded Debutante", 2, 2, 2, "common", "Divine Shield.", t,
               "Becomes a 1/1 Blushing Debutante", KEEP, keywords=["divine_shield"], tribes=["human"])
O_GUARD = spell("order", "guard_the_guests", "Guard the Guests", 1, "common",
                "Give a friendly minion Divine Shield and +1 Health.", KEEP,
                [{"trigger": "cast", "targets": chosen("friendly"),
                  "ops": [{"op": "give_keyword", "targets": chosen("friendly"), "keyword": "divine_shield"},
                          {"op": "buff", "targets": chosen("friendly"), "health": 1}]}],
                school="holy", role="protection")
O_STEWARD = minion("order", "hall_steward", "Steward of the Hall", 4, 3, 4, "rare",
                   "Taunt. Battlecry: Give your Masked minions Divine Shield.", KEEP, keywords=["taunt", "battlecry"],
                   effects=[{"trigger": "battlecry", "ops": [{"op": "give_keyword", "targets": FRIENDLY_MASKED, "keyword": "divine_shield"}]}],
                   tribes=["human"], role="engine")
t = true_form("order", "aurel_revealed", "Aurel, Tarnished", 4, 2, 4, "Lifesteal.", keywords=["lifesteal"], tribes=["human"])
masked("order", "sir_aurel", "Sir Aurel, the Gilded Mask", 5, 4, 5, "legendary", "Taunt. Divine Shield.", t,
       "Becomes a 2/4 with Lifesteal", KEEP, keywords=["taunt", "divine_shield"], tribes=["human"],
       role="legendary", package="aurel_control", playstyle="control", enablers=[O_GUARD, O_STEWARD])
spell("order", "grand_procession", "Grand Procession", 5, "legendary",
      "Summon two Borrowed Finery and give your minions Divine Shield.", KEEP,
      [{"trigger": "cast", "ops": [{"op": "summon", "card_id": N_FINERY, "count": 2, "position": "end"},
                                   {"op": "give_keyword", "targets": "all_friendly_minions", "keyword": "divine_shield"}]}],
      school="holy", role="legendary", package="procession_summon", playstyle="summon",
      enablers=[O_DEB, O_GUARD])

# --- Shadow: Stealth hides the mask; poison ------------------------------------------------
t = true_form("shadow", "cutpurse_revealed", "Caught Cutpurse", 2, 1, 2, tribes=["human"])
S_CUT = masked("shadow", "veiled_cutpurse", "Veiled Cutpurse", 2, 2, 2, "common", "Stealth.", t,
               "Becomes a 1/2 Caught Cutpurse", KEEP, keywords=["stealth"], tribes=["human"])
S_KISS = spell("shadow", "venom_kiss", "Venom Kiss", 1, "common", "Give a friendly minion +1 Attack and Poisonous.", KEEP,
               [{"trigger": "cast", "targets": chosen("friendly"),
                 "ops": [{"op": "buff", "targets": chosen("friendly"), "attack": 1},
                         {"op": "give_keyword", "targets": chosen("friendly"), "keyword": "poisonous"}]}],
               school="shadow", role="support_poisonous", package="support_poisonous")
t = true_form("shadow", "assassin_revealed", "Assassin Revealed", 3, 2, 1, "Poisonous.", keywords=["poisonous"], tribes=["human"])
S_ASSASSIN = masked("shadow", "masked_assassin", "Masked Assassin", 3, 3, 2, "rare", "Stealth.", t,
                    "Becomes a 2/1 with Poisonous", KEEP, keywords=["stealth"], tribes=["human"], role="threat")
minion("shadow", "the_faceless", "The Faceless", 4, 4, 3, "legendary",
       "Stealth. Whenever this attacks, Silence the defender.", KEEP, keywords=["stealth", "silence"],
       effects=[{"trigger": "on_attack", "scope": {"attacker": "self"},
                 "ops": [{"op": "silence", "targets": "trigger_subject"}]}],
       tribes=["human"], role="legendary", package="faceless_tempo", playstyle="tempo",
       enablers=[S_CUT, S_KISS])
minion("shadow", "nightshade_hostess", "The Nightshade Hostess", 5, 3, 6, "legendary",
       "At the end of your turn, give a random friendly minion Poisonous.", KEEP,
       effects=[{"trigger": "turn_end", "scope": {"side": "owner"},
                 "ops": [{"op": "give_keyword", "targets": "random_friendly_minion", "keyword": "poisonous"}]}],
       tribes=["undead"], role="legendary", package="nightshade_attrition", playstyle="attrition",
       enablers=[S_ASSASSIN, S_KISS])

# --- Bundles: six per class, each three cards of the class's theme -------------------------
def collectible(set_: str) -> list[str]:
    return [c["id"] for c in cards if c["set"] == set_ and not c.get("token") and c["rarity"] != "legendary"]


def legendaries(set_: str) -> list[str]:
    return [c["id"] for c in cards if c["set"] == set_ and c["rarity"] == "legendary"]


def themed_neutral(theme: str) -> list[str]:
    return [c["id"] for c in cards if c["set"] == "neutral" and not c.get("token") and theme in c["tags"]]


THEME_NAME = {REVEAL: "Grand Reveal", KEEP: "Keep the Mask"}
bundles: list[dict] = []
for set_ in CLASSES:
    theme = CLASS_THEME[set_]
    own = collectible(set_) + legendaries(set_)
    neutral = themed_neutral(theme)
    # Each class card appears in two bundles; neutrals fill the remaining slots in a fixed rotation.
    rotation = [own[i % len(own)] for i in range(6)]
    for i in range(6):
        picks = [rotation[i], neutral[(2 * i) % len(neutral)], neutral[(2 * i + 1) % len(neutral)]]
        bid = f"bundle_{set_}_masq_{i + 1}"
        bundles.append({"id": bid, "name": f"{THEME_NAME[theme]} {i + 1}", "set": set_, "collection_id": SET_ID,
                        "theme": theme, "cards": picks, "unlock": None,
                        "text": text("bundle", bid, "Masks, guests, and a plan for the night.")})

# Every class card must appear in a bundle; tag each card with its class theme so bundles validate.
for c in cards:
    if c["set"] in CLASS_THEME and not c.get("token"):
        if CLASS_THEME[c["set"]] not in c["tags"]:
            c["tags"].insert(0, CLASS_THEME[c["set"]])

# --- Bosses ---------------------------------------------------------------------------------
def deck(*pairs) -> list[str]:
    out: list[str] = []
    for cid_, n in pairs:
        out += [cid_] * n
    return out


bosses = [
    {"id": "boss_masq_hostess", "name": "Madame Veil, Hostess of the Ball", "collection_id": SET_ID, "band": 1,
     "health": 30, "hero_power": None,
     "passive": {"trigger": "turn_end", "scope": {"side": "owner"},
                 "ops": [dmg(1, {"selector": "random_friendly_minion", "filter": {"tag": "masked"}})]},
     "passive_text": {"key": "boss.boss_masq_hostess.passive",
                      "en": "At the end of the boss's turn, deal 1 damage to one of its Masked minions."},
     "deck": deck((N_REVELER, 4), (N_DUELIST, 3), (N_SOMMELIER, 3), (N_CRIMSON, 2), (N_TASTER, 3),
                  (N_PAGE, 4), (N_CURTAIN, 3), (N_RIVAL, 2), (N_CHALICE, 2), (N_STEWARD, 2), (N_USHER, 2)),
     "ai_profile": "tempo", "tags": ["masquerade", REVEAL],
     "intro_text": {"key": "boss.boss_masq_hostess.intro",
                    "en": "Madame Veil unmasks her own guests at the end of each turn. Kill a mask before it reveals."}},
    {"id": "boss_masq_faceless_count", "name": "The Faceless Count", "collection_id": SET_ID, "band": 2,
     "health": 40, "hero_power": None,
     "passive": {"trigger": "turn_start", "scope": {"side": "owner"},
                 "ops": [{"op": "give_keyword", "targets": {"selector": "random_friendly_minion", "filter": {"tag": "masked", "lacks_keyword": ["divine_shield"]}},
                          "keyword": "divine_shield"}]},
     "passive_text": {"key": "boss.boss_masq_faceless_count.passive",
                      "en": "At the start of the boss's turn, give one of its unshielded Masked minions Divine Shield."},
     "deck": deck((N_FINERY, 4), (N_DUCHESS, 4), (N_DANCER, 3), (N_DOUBLE, 3), (N_USHER, 3), (N_STEWARD, 3),
                  (N_VEILS, 2), (N_UNVEILING, 2), (N_BELL, 2), (N_TASTER, 2), (N_REVELER, 2)),
     "ai_profile": "tempo", "tags": ["masquerade", KEEP],
     "intro_text": {"key": "boss.boss_masq_faceless_count.intro",
                    "en": "The Count's guests are stronger in costume. Pop the shield, then strike to reveal what lies beneath."}},
]

# --- Run items ------------------------------------------------------------------------------
treasures = [
    {"id": "treasure_masq_ballroom_invitation", "name": "Ballroom Invitation", "collection_id": SET_ID, "rarity": "rare",
     "tags": ["universal", "tempo"], "unlock": None,
     "effects": [{"trigger": "on_match_start", "ops": [{"op": "summon", "card_id": N_REVELER, "count": 1, "position": "end"}]}],
     "text": text("treasure", "treasure_masq_ballroom_invitation", "Start each match with a Masked Reveler in play.")},
    {"id": "treasure_masq_hostess_bell", "name": "Hostess's Hand-Bell", "collection_id": SET_ID, "rarity": "common",
     "tags": ["universal", "value"], "unlock": None,
     "effects": [{"trigger": "turn_start", "scope": {"side": "owner"},
                  "ops": [dmg(1, {"selector": "random_friendly_minion", "filter": {"tag": "masked"}})]}],
     "text": text("treasure", "treasure_masq_hostess_bell",
                  "At the start of your turn, deal 1 damage to a random friendly Masked minion.")},
    {"id": "treasure_masq_dance_card", "name": "Dance Card", "collection_id": SET_ID, "rarity": "rare",
     "tags": ["universal", "value"], "unlock": None,
     "effects": [{"trigger": "turn_start", "scope": {"side": "owner"},
                  "condition": {"cmp": [{"ref": "owner.turns_taken"}, "==", 3]},
                  "ops": [{"op": "discover", "pool": "collectible"}]}],
     "text": text("treasure", "treasure_masq_dance_card", "At the start of your 3rd turn, Discover a card.")},
    {"id": "treasure_masq_smelling_salts", "name": "Smelling Salts", "collection_id": SET_ID, "rarity": "rare",
     "tags": ["universal", "value"], "unlock": None,
     "effects": [{"trigger": "turn_end", "scope": {"side": "owner"},
                  "ops": [{"op": "heal", "targets": "all_friendly_minions", "amount": 2}]}],
     "text": text("treasure", "treasure_masq_smelling_salts", "At the end of your turn, restore 2 Health to your minions.")},
]
ITEM_GROUPS = {"mechanic_support": ["treasure_masq_ballroom_invitation", "treasure_masq_hostess_bell"],
               "gap_fill": ["treasure_masq_dance_card", "treasure_masq_smelling_salts"]}

UNLOCK = {"key": "collection_midnight_masquerade",
          "condition": {"type": "all_of", "of": [{"type": "runs_won", "n": 3},
                                                 {"type": "boss_defeated", "boss_id": "boss_mirror_sage", "n": 1}]}}
UNLOCK_METADATA = {
    "set_id": SET_ID, "display_name": "The Midnight Masquerade",
    "description": "Win 3 runs and defeat the Mirror Sage to receive your invitation.",
    "unlock": UNLOCK, "unlock_mode": "all", "retroactive": True, "unlock_rewards": [],
    "unlock_requirements": [
        {"type": "runs_won", "description": "Win 3 lifetime runs.", "params": {"n": 3}},
        {"type": "boss_defeated", "description": "Defeat the Mirror Sage.", "params": {"boss_id": "boss_mirror_sage", "n": 1}},
    ],
}


def write_all() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    def dump(name: str, body: dict) -> None:
        (OUT / name).write_text(json.dumps(body, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    dump("cards.json", {"schema_version": 1, "records": cards})
    dump("bundles.json", {"schema_version": 1, "records": bundles})
    dump("bosses.json", {"schema_version": 1, "records": bosses})
    dump("treasures.json", {"schema_version": 1, "records": treasures})
    dump("unlock.json", {"schema_version": 1, "config": UNLOCK})
    dump("collection.json", {"schema_version": 1, "config": {
        "id": SET_ID, "name": "The Midnight Masquerade", "display_name": "The Midnight Masquerade",
        "description": "A cursed ball where every guest wears a mask. Some are worse underneath; some are better.",
        "version": 1, "unlock": UNLOCK, "unlock_metadata": UNLOCK_METADATA, "card_metadata": metadata,
        "item_groups": ITEM_GROUPS, "files": ["cards.json", "bosses.json", "bundles.json", "treasures.json", "unlock.json"]}})
    registry_path = DATA / "collections.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    rows = registry["config"]["collections"]
    if not any(r["id"] == SET_ID for r in rows):
        rows.append({"id": SET_ID, "name": "The Midnight Masquerade", "path": SET_ID})
        registry_path.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")


def base_curve() -> dict:
    curve = collections.defaultdict(list)
    files = sorted(glob.glob(str(DATA / "cards_*.json"))) + [str(DATA / "law-of-the-jungle" / "cards.json")]
    for f in files:
        for c in json.loads(Path(f).read_text(encoding="utf-8"))["records"]:
            if c["type"] == "minion" and not c.get("token") and c["set"] != "boss":
                curve[(c["cost"], c["rarity"])].append(c["attack"] + c["health"])
    return curve


def audit() -> list[str]:
    failures: list[str] = []
    collectibles = [c for c in cards if not c.get("token")]
    by_set = collections.Counter(c["set"] for c in collectibles)
    neutral_share = by_set["neutral"] / len(collectibles)
    if not 0.30 <= neutral_share <= 0.40:
        failures.append(f"neutral share {neutral_share:.0%} outside 30-40%")
    if len({by_set[s] for s in CLASSES}) != 1:
        failures.append(f"class counts differ: {dict(by_set)}")
    for c in collectibles:
        if c["set"] == "neutral" and c["rarity"] == "legendary":
            failures.append(f"neutral legendary {c['id']}")
    for s in CLASSES:
        legs = [c["id"] for c in collectibles if c["set"] == s and c["rarity"] == "legendary"]
        styles = {metadata[i]["playstyle"] for i in legs}
        if len(legs) != 2 or len(styles) != 2:
            failures.append(f"{s}: legendaries {legs} playstyles {styles}")
        for i in legs:
            for e in metadata[i]["enablers"]:
                if e not in metadata or metadata[e]["role"] == "legendary":
                    failures.append(f"{i}: bad enabler {e}")
    ids = {c["id"] for c in cards}
    for c in cards:
        for eff in c["effects"]:
            for op in json.dumps(eff).split('"card_id": "')[1:]:
                ref = op.split('"')[0]
                if ref not in ids and ref not in ("decay_husk", "fortune_coin"):
                    failures.append(f"{c['id']}: unknown card_id {ref}")
    masks = [c for c in collectibles if "masked" in c["tags"]]
    up = down = 0
    for c in masks:
        true_ids = [x.split('"')[0] for x in json.dumps(c["effects"]).split('"card_id": "')[1:]]
        for tid in true_ids:
            t_ = next(x for x in cards if x["id"] == tid)
            if t_["attack"] + t_["health"] > c["attack"] + c["health"]:
                up += 1
            else:
                down += 1
    if up < 5 or down < 5:
        failures.append(f"Unmask direction split too narrow: {up} upgrades, {down} downgrades")
    for mech, tag in (("poisonous", "support_poisonous"), ("lifesteal", "support_lifesteal")):
        n = sum(1 for i, m in metadata.items() if m["package"] == tag)
        if n < 2:
            failures.append(f"{mech} support has {n} cards")
    if len(bosses) not in (1, 2):
        failures.append("boss count")
    for b in bosses:
        if len(b["deck"]) != 30 or any(x not in ids for x in b["deck"]):
            failures.append(f"{b['id']}: deck size {len(b['deck'])} or unknown card")
        if not any("masked" in next(c for c in cards if c["id"] == x)["tags"] for x in b["deck"]):
            failures.append(f"{b['id']}: no Masked minions")
    for g in ITEM_GROUPS.values():
        if not 1 <= len(g) <= 2:
            failures.append("item group size")
    if set(ITEM_GROUPS["mechanic_support"]) & set(ITEM_GROUPS["gap_fill"]):
        failures.append("item counted in both groups")
    bundled = {x for b in bundles for x in b["cards"]}
    for c in collectibles:
        if c["set"] != "neutral" and c["id"] not in bundled:
            failures.append(f"{c['id']} is in no bundle")
    return failures


def balance_flags() -> list[str]:
    curve = base_curve()
    flags = []
    for c in cards:
        if c.get("token") or c["type"] != "minion" or c["rarity"] == "legendary":
            continue
        v = curve.get((c["cost"], c["rarity"])) or curve.get((c["cost"], "common"))
        if not v or len(v) < 2:
            continue
        mean, sd = statistics.mean(v), statistics.pstdev(v) or 0.5
        total = c["attack"] + c["health"]
        if abs(total - mean) > sd:
            direction = "above" if total > mean else "below"
            flags.append(f"{c['id']}: {c['attack']}/{c['health']} = {total}, {direction} {mean:.2f}±{sd:.2f}")
    return flags


if __name__ == "__main__":
    if "--check" not in sys.argv:
        write_all()
        print(f"Authored {len(cards)} records; {sum(1 for c in cards if not c.get('token'))} collectibles")
    problems = audit()
    for p in problems:
        print("FAIL", p)
    flags = balance_flags()
    for f in flags:
        print("FLAG", f)
    if problems:
        sys.exit(1)
    collectibles = [c for c in cards if not c.get("token")]
    print(f"Audit passed: {len(collectibles)} collectibles, {len(bundles)} bundles, {len(bosses)} bosses, "
          f"{len(treasures)} items; {len(flags)} raw-stat flags")
