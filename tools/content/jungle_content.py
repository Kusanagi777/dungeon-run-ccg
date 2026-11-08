"""Author and audit the staged Law of the Jungle collection (standard library only)."""
import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/data/law-of-the-jungle"
SET = "law-of-the-jungle"
CARDS, META = [], {}
CLASS, PACKAGE, ROLE = "neutral", "apex_succession", "enabler"


def op(name, targets=None, **values):
    return {"op": name, **({"targets": targets} if targets else {}), **values}


def fx(trigger, *ops, targets=None, condition=None, **extra):
    def chosen_target(node):
        if isinstance(node, dict):
            if node.get("selector") == "chosen":
                return node
            return next((found for value in node.values() if (found := chosen_target(value))), None)
        if isinstance(node, (list, tuple)):
            return next((found for value in node if (found := chosen_target(value))), None)
        return None
    targets = targets or chosen_target(ops)
    return {"trigger": trigger, **({"targets": targets} if targets else {}),
            **({"condition": condition} if condition else {}), "ops": list(ops), **extra}


def sel(selector, **filters):
    return {"selector": selector, "filter": filters}


def chosen(side="any", **filters):
    return sel("chosen", kind="minion", side=side, **filters)


def prey(tribe):
    return {"exists": sel("all_minions", tribe=tribe, not_self=True)}


def predator(tribe, *ops):
    return fx("battlecry", *ops, condition=prey(tribe))


def summon(card="seedling", count=1, **extra):
    return op("summon", card_id="neutral_jungle_" + card, count=count, position="end", **extra)


def draw(n=1):
    return op("draw", count=n)


def buff(targets="self", attack=1, health=1, **extra):
    return op("buff", targets, attack=attack, health=health, **extra)


def damage(targets, amount):
    return op("damage", targets, amount=amount)


def heal(targets, amount):
    return op("heal", targets, amount=amount)


def kw(targets, keyword):
    return op("give_keyword", targets, keyword=keyword)


def card(slug, name, cost, stats, text, effects=(), rarity="common", keywords=(), tribe="beast", tags=(), **extra):
    cid = CLASS + "_jungle_" + slug
    effects = list(effects)
    kws = list(keywords)
    tree = json.dumps(effects)
    triggers = {e["trigger"] for e in effects}
    for keyword, marker in [("battlecry", '"battlecry"'), ("deathrattle", '"deathrattle"'),
                            ("aura", '"aura"'), ("freeze", '"freeze"'),
                            ("silence", '"silence"'), ("discover", '"discover"')]:
        matched = keyword in triggers if keyword in ("battlecry", "deathrattle", "aura") else marker in tree
        if matched and keyword not in kws:
            kws.append(keyword)
    record = dict(id=cid, name=name, set=CLASS, type="minion" if stats else "spell",
                  cost=cost, rarity=rarity, keywords=kws, effects=effects,
                  tags=list(dict.fromkeys([PACKAGE, *tags])), collection_id=SET,
                  text={"key": "card." + cid + ".text", "en": text})
    if stats:
        record.update(attack=stats[0], health=stats[1], tribes=[tribe])
    else:
        record["schools"] = [dict(war="martial", decay="nature", knowledge="arcane", fortune="alchemy", order="holy", shadow="shadow").get(CLASS, "nature")]
    record.update(extra)
    CARDS.append(record)
    META[cid] = {"package": PACKAGE, "role": ROLE}
    return cid


def m(slug, name, cost, attack, health, text="", *effects, **extra):
    return card(slug, name, cost, (attack, health), text, effects, **extra)


def s(slug, name, cost, text, *ops, rarity="common", **extra):
    return card(slug, name, cost, None, text, [fx("cast", *ops)], rarity=rarity, **extra)


def stage():
    global CLASS, PACKAGE, ROLE
    # The three prey tokens are excluded from the 138 collectible records.
    PACKAGE = "token"
    m("seedling", "Canopy Seedling", 1, 1, 1, tribe="plant", token=True)
    m("hatchling", "Canopy Hatchling", 1, 1, 1, token=True)
    m("vineguard", "Canopy Vineguard", 2, 1, 3, "Taunt.", keywords=["taunt"], tribe="plant", token=True)

    # 14 shared Apex cards: six enablers, three engines, three answers, two recovery.
    PACKAGE, ROLE = "apex_succession", "enabler"
    m("seedling_keeper", "Seedling Keeper", 1, 1, 2, tribe="plant")
    m("nest_tender", "Nest Tender", 2, 1, 2, "Battlecry: Summon a 1/1 Beast.", fx("battlecry", summon("hatchling")), tribe="human")
    m("canopy_stalker", "Canopy Stalker", 3, 3, 3, "Predator (Plant): Gain +1/+1.", predator("plant", buff()))
    m("amber_grazer", "Amber Grazer", 2, 2, 3)
    m("thornback_yearling", "Thornback Yearling", 3, 2, 4, "Taunt.", keywords=["taunt"])
    m("fossil_sprout", "Fossil Sprout", 2, 1, 3, "Deathrattle: Summon a 1/1 Plant.", fx("deathrattle", summon()), tribe="plant")
    ROLE = "engine"
    m("trophy_sifter", "Trophy Sifter", 4, 3, 4, "Predator (Beast): Draw a card.", predator("beast", draw()), tribe="human")
    m("ancient_browser", "Ancient Browser", 5, 4, 5, "Predator (Plant): Gain Taunt.", predator("plant", kw("self", "taunt")))
    m("canopy_cartographer", "Canopy Cartographer", 4, 2, 5, "At the end of your turn, if you have a Plant, restore 2 Health to your hero.", fx("turn_end", heal("owner_hero", 2), condition={"exists": sel("all_friendly_minions", tribe="plant")}, scope={"side": "owner"}), rarity="rare", tribe="human")
    ROLE = "answer"
    s("crushing_tail", "Crushing Tail", 4, "Deal 5 damage to an enemy minion.", damage(chosen("enemy"), 5))
    m("boulderhide", "Boulderhide", 6, 4, 7, "Taunt. Predator (Beast): Gain +2 Attack.", predator("beast", buff(attack=2, health=0)), keywords=["taunt"], rarity="rare")
    s("amber_shell", "Amber Shell", 2, "Give a friendly minion +0/+3 and Taunt.", buff(chosen("friendly"), 0, 3), kw(chosen("friendly"), "taunt"), rarity="rare")
    ROLE = "recovery"
    m("fossil_excavator", "Fossil Excavator", 5, 3, 5, "Battlecry: Draw a card.", fx("battlecry", draw()), rarity="rare", tribe="human")
    m("sheltered_colossus", "Sheltered Colossus", 7, 6, 7, "Predator (Plant): Restore 4 Health to your hero.", predator("plant", heal("owner_hero", 4)))

    PACKAGE, ROLE = "living_canopy", "enabler"
    m("fern_hopper", "Fern Hopper", 1, 1, 2)
    m("spore_nursery", "Spore Nursery", 2, 1, 2, "Battlecry: Summon a 1/1 Plant.", fx("battlecry", summon()), tribe="plant")
    m("root_watcher", "Root Watcher", 2, 2, 2, "Predator (Beast): Gain +0/+2.", predator("beast", buff(attack=0, health=2)), tribe="plant")
    m("shelter_fern", "Shelter Fern", 3, 1, 5, "Taunt.", keywords=["taunt"], tribe="plant")
    m("regrowth_runner", "Regrowth Runner", 3, 3, 2, "Deathrattle: Summon a 1/1 Plant.", fx("deathrattle", summon()), tribe="human")
    s("scattered_seeds", "Scattered Seeds", 2, "Summon two 1/1 Plants.", summon(count=2))
    ROLE = "engine"
    m("rainfall_herbalist", "Rainfall Herbalist", 3, 2, 3, "At the end of your turn, restore 1 Health to your minions.", fx("turn_end", heal("all_friendly_minions", 1), scope={"side": "owner"}), rarity="rare", tribe="human")
    m("waking_banyan", "Waking Banyan", 5, 3, 6, "Deathrattle: Summon two 1/1 Plants.", fx("deathrattle", summon(count=2)), tribe="plant")
    m("mossjaw", "Mossjaw", 4, 3, 4, "Lifesteal. Predator (Plant): Gain +1 Attack.", predator("plant", buff(attack=1, health=0)), keywords=["lifesteal"], rarity="rare")
    ROLE = "answer"
    m("vine_sentry", "Vine Sentry", 4, 2, 5, "Taunt. Predator (Beast): Restore 3 Health to your hero.", predator("beast", heal("owner_hero", 3)), keywords=["taunt"], tribe="plant")
    s("tangled_path", "Tangled Path", 3, "Give an enemy minion -3 Attack this turn. Draw a card.", buff(chosen("enemy"), -3, 0, duration="until_end_of_turn"), draw())
    m("canopy_medic", "Canopy Medic", 4, 3, 4, "Battlecry: Restore 4 Health to a friendly character.", fx("battlecry", heal(sel("chosen", side="friendly"), 4)), rarity="rare", tribe="human")
    ROLE = "recovery"
    s("seed_reserve", "Seed Reserve", 3, "Draw a card. Add two 1/1 Plants to your hand.", draw(), op("add_to_hand", card_id="neutral_jungle_seedling", count=2), rarity="rare")
    m("rain_drinker", "Rain Drinker", 6, 4, 6, "Lifesteal. Predator (Plant): Gain +0/+2.", predator("plant", buff(attack=0, health=2)), keywords=["lifesteal"], rarity="rare")

    PACKAGE, ROLE = "primal_hunt", "enabler"
    m("reed_ambusher", "Reed Ambusher", 2, 2, 2, "Predator (Beast): Gain +1 Attack.", predator("beast", buff(attack=1, health=0)))
    m("trail_falcon", "Trail Falcon", 1, 2, 1)
    m("nest_guard", "Nest Guard", 2, 2, 2, "Deathrattle: Summon a 1/1 Beast.", fx("deathrattle", summon("hatchling")))
    m("brush_raptor", "Brush Raptor", 3, 3, 2, "Rush.", keywords=["rush"])
    m("thorn_runner", "Thorn Runner", 3, 2, 3, "Rush. Predator (Plant): Gain +1 Attack.", predator("plant", buff(attack=1, health=0)), keywords=["rush"])
    m("pathfinder", "Jungle Pathfinder", 2, 2, 1, "Battlecry: Add a 1/1 Beast to your hand.", fx("battlecry", op("add_to_hand", card_id="neutral_jungle_hatchling", count=1)), tribe="human")
    ROLE = "engine"
    m("pack_outrider", "Pack Outrider", 4, 3, 4, "Your other Beasts have +1 Attack.", fx("aura", op("aura", attack=1), targets=sel("all_friendly_minions", tribe="beast", not_self=True)), rarity="rare", tribe="human")
    m("scent_tracker", "Scent Tracker", 3, 2, 3, "Predator (Beast): Draw a card.", predator("beast", draw()), rarity="rare")
    m("chase_caller", "Chase Caller", 4, 3, 3, "Battlecry: Give another friendly Beast Rush.", fx("battlecry", kw(chosen("friendly", tribe="beast", not_self=True), "rush")), rarity="rare", tribe="human")
    ROLE = "answer"
    s("coordinated_pounce", "Coordinated Pounce", 2, "Deal 3 damage to a damaged enemy minion.", damage(chosen("enemy", is_damaged=True), 3))
    m("razorbeak", "Razorbeak", 5, 4, 4, "Rush. Predator (Beast): Gain +1/+1.", predator("beast", buff()), keywords=["rush"], rarity="rare")
    s("guard_the_nest", "Guard the Nest", 2, "Give a friendly minion +1/+2.", buff(chosen("friendly"), 1, 2))
    ROLE = "recovery"
    m("expedition_supplier", "Expedition Supplier", 4, 3, 3, "Battlecry: Draw a card.", fx("battlecry", draw()), tribe="human")
    s("follow_the_tracks", "Follow the Tracks", 3, "Draw two cards.", draw(2), rarity="rare")

    # Each class has two six-card packages (3C/2R/1L) and four legacy slots.
    CLASS, PACKAGE, ROLE = "war", "crown_tempo", "enabler"
    m("trail_squire", "Trail Squire", 1, 1, 2, "After your hero attacks, gain +1 Attack this turn. (Once per turn.)", fx("on_attack", buff(attack=1, health=0, duration="until_end_of_turn"), scope={"attacker": "owner_hero"}, once_per_turn=True), tribe="human")
    m("redcrest_hatchery", "Redcrest Hatchery", 2, 2, 1, "Battlecry: Summon a 1/1 Beast.", fx("battlecry", summon("hatchling")), tribe="human")
    ROLE = "engine"
    m("canopy_challenger", "Canopy Challenger", 3, 3, 3, "Predator (Beast): Gain Rush. After this attacks, gain 1 Armor.", predator("beast", kw("self", "rush")), fx("on_attack", op("armor", amount=1), scope={"attacker": "self"}))
    ROLE = "answer"
    s("hold_the_ridge", "Hold the Ridge", 2, "Give a friendly minion +2/+1 and Taunt.", buff(chosen("friendly"), 2, 1), kw(chosen("friendly"), "taunt"), rarity="rare")
    ROLE = "recovery"
    m("trophy_quartermaster", "Trophy Quartermaster", 4, 3, 4, "Predator (Plant): Draw a card.", predator("plant", draw()), rarity="rare", tribe="human")
    ROLE = "legendary"
    m("gorath", "Gorath, Crown of the Canopy", 7, 6, 6, "Rush. Predator (Beast): Give your other minions +1/+1.", predator("beast", buff(sel("all_friendly_minions", not_self=True))), keywords=["rush"], rarity="legendary")
    PACKAGE, ROLE = "extinction_aggro", "enabler"
    m("spearleaf", "Spearleaf", 1, 2, 1, tribe="plant")
    m("ridge_charger", "Ridge Charger", 2, 2, 2, "Predator (Plant): Gain +1 Attack.", predator("plant", buff(attack=1, health=0)))
    ROLE = "engine"
    m("stampede_drummer", "Stampede Drummer", 3, 2, 3, "Whenever this attacks, give another random friendly minion +1 Attack.", fx("on_attack", buff(sel("random_friendly_minion", not_self=True), 1, 0), scope={"attacker": "self"}), tribe="human")
    ROLE = "answer"
    s("break_the_thicket", "Break the Thicket", 3, "Deal 4 damage to an enemy minion. Give your minions +1 Attack this turn.", damage(chosen("enemy"), 4), buff("all_friendly_minions", 1, 0, duration="until_end_of_turn"), rarity="rare")
    ROLE = "recovery"
    s("rally_the_hunt", "Rally the Hunt", 3, "Draw two cards. Gain 1 Armor.", draw(2), op("armor", amount=1), rarity="rare")
    ROLE = "legendary"
    s("extinction_march", "Extinction March", 7, "Give your minions +2 Attack and Rush this turn. Deal 3 damage to the enemy hero.", buff("all_friendly_minions", 2, 0, keywords=["rush"], duration="until_end_of_turn"), damage("enemy_hero", 3), rarity="legendary")
    PACKAGE, ROLE = "legacy_weapons", "legacy_support"
    s("bone_honing", "Bone Honing", 1, "Give your weapon +1 Attack. Gain 2 Armor.", buff("owner_weapon", 1, 0), op("armor", amount=2), tags=["weapons"])
    m("ridge_bladesmith", "Ridge Bladesmith", 3, 2, 4, "Whenever your hero attacks, give this +1 Attack. (Once per turn.)", fx("on_attack", buff(attack=1, health=0), scope={"attacker": "owner_hero"}, once_per_turn=True), rarity="rare", tribe="human", tags=["weapons"])
    PACKAGE = "legacy_berserk"
    s("battle_scars", "Battle Scars", 2, "Give a damaged friendly minion +2/+2.", buff(chosen("friendly", is_damaged=True), 2, 2), tags=["berserk"])
    m("scarhide_veteran", "Scarhide Veteran", 4, 3, 5, "Battlecry: Give your damaged minions +1 Attack.", fx("battlecry", buff(sel("all_friendly_minions", is_damaged=True), 1, 0)), rarity="rare", tags=["berserk"])

    CLASS, PACKAGE, ROLE = "decay", "worldroot_attrition", "enabler"
    m("rotting_bulb", "Rotting Bulb", 1, 1, 1, "Deathrattle: Summon a 1/1 Plant.", fx("deathrattle", summon()), tribe="plant")
    m("mire_nibbler", "Mire Nibbler", 2, 2, 2, "Predator (Plant): Gain Lifesteal.", predator("plant", kw("self", "lifesteal")))
    ROLE = "engine"
    m("compost_keeper", "Compost Keeper", 3, 2, 3, "After a friendly Plant dies, restore 2 Health to your hero. (Once per turn.)", fx("on_minion_died", heal("owner_hero", 2), scope={"who": "friendly_minion", "card": {"tribe": "plant"}}, once_per_turn=True), tribe="undead")
    ROLE = "answer"
    s("strangling_roots", "Strangling Roots", 4, "Deal 4 damage to an enemy minion. Summon a 1/1 Plant.", damage(chosen("enemy"), 4), summon(), rarity="rare")
    ROLE = "recovery"
    m("mire_reclaimer", "Mire Reclaimer", 5, 3, 5, "Predator (Beast): Add two 1/1 Plants to your hand.", predator("beast", op("add_to_hand", card_id="neutral_jungle_seedling", count=2)), rarity="rare", tribe="plant")
    ROLE = "legendary"
    m("worldroot", "The Worldroot", 8, 5, 8, "Taunt. At the end of your turn, summon two 1/1 Plants and restore 2 Health to your hero.", fx("turn_end", summon(count=2), heal("owner_hero", 2), scope={"side": "owner"}), rarity="legendary", keywords=["taunt"], tribe="plant")
    PACKAGE, ROLE = "verdant_sacrifice", "enabler"
    m("spore_offering", "Spore Offering", 1, 1, 2, "Deathrattle: Restore 1 Health to your hero.", fx("deathrattle", heal("owner_hero", 1)), tribe="plant")
    m("carrion_gardener", "Carrion Gardener", 2, 1, 2, "Battlecry: Summon a 1/1 Plant.", fx("battlecry", summon()), tribe="undead")
    ROLE = "engine"
    m("root_feaster", "Root Feaster", 3, 2, 3, "Predator (Plant): Gain +2 Health. After a friendly Plant dies, gain +1 Attack. (1/turn)", predator("plant", buff(attack=0, health=2)), fx("on_minion_died", buff(attack=1, health=0), scope={"who": "friendly_minion", "card": {"tribe": "plant"}}, once_per_turn=True), tribe="undead")
    ROLE = "answer"
    s("feed_the_thicket", "Feed the Thicket", 2, "Destroy a friendly minion. Deal 4 damage to a random enemy minion.", op("destroy", chosen("friendly")), damage("random_enemy_minion", 4), rarity="rare")
    ROLE = "recovery"
    s("compost_ledger", "Compost Ledger", 3, "Destroy a friendly minion. Draw three cards.", op("destroy", chosen("friendly")), draw(3), rarity="rare")
    ROLE = "legendary"
    s("verdant_reclamation", "Verdant Reclamation", 6, "Destroy your minions. Summon three 1/3 Plants with Taunt. Restore 6 Health to your hero.", op("destroy", "all_friendly_minions"), summon("vineguard", 3), heal("owner_hero", 6), rarity="legendary")
    PACKAGE, ROLE = "legacy_deathrattle", "legacy_support"
    m("sporebound_relic", "Sporebound Relic", 2, 1, 3, "Deathrattle: Draw a card.", fx("deathrattle", draw()), tribe="plant", tags=["deathrattle"])
    s("buried_echo", "Buried Echo", 3, "Trigger a friendly minion's Deathrattle twice.", op("retrigger", chosen("friendly", has_trigger="deathrattle"), trigger="deathrattle"), op("retrigger", chosen("friendly", has_trigger="deathrattle"), trigger="deathrattle"), rarity="rare", tags=["deathrattle"])
    PACKAGE = "legacy_sacrifice"
    s("fertile_bargain", "Fertile Bargain", 1, "Destroy a friendly minion. Restore 5 Health to your hero.", op("destroy", chosen("friendly")), heal("owner_hero", 5), tags=["sacrifice"])
    m("offering_warden", "Offering Warden", 4, 3, 4, "After a friendly minion dies, gain +1 Health. (Once per turn.)", fx("on_minion_died", buff(attack=0, health=1), scope={"who": "friendly_minion"}, once_per_turn=True), rarity="rare", tribe="undead", tags=["sacrifice"])

    CLASS, PACKAGE, ROLE = "knowledge", "fossil_value", "enabler"
    m("field_scholar", "Field Scholar", 1, 1, 2, "Battlecry: Gain 1 Armor.", fx("battlecry", op("armor", amount=1)), tribe="human")
    s("amber_specimen", "Amber Specimen", 2, "Summon a 1/1 Beast. Draw a card.", summon("hatchling"), draw())
    ROLE = "engine"
    m("fossil_reader", "Fossil Reader", 3, 1, 3, "Predator (Beast): Draw a card. After you cast a spell, summon a 1/1 Plant. (1/turn)", predator("beast", draw()), fx("after_cast", summon(), scope={"by": "owner"}, once_per_turn=True), tribe="human")
    ROLE = "answer"
    s("amber_encasement", "Amber Encasement", 3, "Transform an enemy minion into a 1/1 Plant.", op("transform", chosen("enemy"), card_id="neutral_jungle_seedling"), rarity="rare")
    ROLE = "recovery"
    m("catalogue_keeper", "Catalogue Keeper", 4, 3, 4, "Predator (Plant): Discover a spell.", predator("plant", op("discover", pool="collectible", filter={"type": "spell", "set": "knowledge"}, count=3)), rarity="rare", tribe="human")
    ROLE = "legendary"
    m("tala", "Tala, Fossil Savant", 6, 4, 6, "Predator (Beast): Draw 2 cards. End of your turn: if you have a Plant, gain 2 Armor.", predator("beast", draw(2)), fx("turn_end", op("armor", amount=2), condition={"exists": sel("all_friendly_minions", tribe="plant")}, scope={"side": "owner"}), rarity="legendary", tribe="human")
    PACKAGE, ROLE = "archive_control", "enabler"
    m("amber_seed", "Amber Seed", 1, 1, 1, "Deathrattle: Add a 1/1 Plant to your hand.", fx("deathrattle", op("add_to_hand", card_id="neutral_jungle_seedling", count=1)), tribe="plant")
    m("quillback_student", "Quillback Student", 2, 2, 2, "Predator (Plant): Gain +0/+2.", predator("plant", buff(attack=0, health=2)))
    ROLE = "engine"
    m("canopy_observer", "Canopy Observer", 3, 2, 4, "After you cast a spell, restore 1 Health to your hero. (Once per turn.)", fx("after_cast", heal("owner_hero", 1), scope={"by": "owner"}, once_per_turn=True), tribe="human")
    ROLE = "answer"
    s("amberwave", "Amberwave", 5, "Deal 2 damage to all enemy minions. Freeze them.", damage("all_enemy_minions", 2), op("freeze", "all_enemy_minions"), rarity="rare")
    ROLE = "recovery"
    s("shelved_discovery", "Shelved Discovery", 4, "Draw two cards. Restore 3 Health to your hero.", draw(2), heal("owner_hero", 3), rarity="rare")
    ROLE = "legendary"
    s("amber_archive", "The Amber Archive", 8, "Transform all enemy minions into 1/1 Plants. Draw two cards.", op("transform", "all_enemy_minions", card_id="neutral_jungle_seedling"), draw(2), rarity="legendary")
    PACKAGE, ROLE = "legacy_frost", "legacy_support"
    s("cold_fossil", "Cold Fossil", 2, "Freeze an enemy minion. Draw a card.", op("freeze", chosen("enemy")), draw(), tags=["frost"])
    m("rime_excavator", "Rime Excavator", 4, 3, 4, "Battlecry: Deal 3 damage to a Frozen enemy minion.", fx("battlecry", damage(chosen("enemy", is_frozen=True), 3)), rarity="rare", tribe="human", tags=["frost"])
    PACKAGE = "legacy_spell_damage"
    m("prism_moth", "Prism Moth", 2, 1, 2, "Spell Damage +1.", keywords=["spell_damage"], spell_damage=1, tags=["spell_damage"])
    s("fossil_burst", "Fossil Burst", 4, "Deal 3 damage to an enemy minion. Deal 1 damage to all enemy minions.", damage(chosen("enemy"), 3), damage("all_enemy_minions", 1), rarity="rare", tags=["spell_damage"])

    CLASS, PACKAGE, ROLE = "fortune", "trophy_value", "enabler"
    m("trophy_forager", "Trophy Forager", 1, 1, 2, "After this attacks, gain 1 Armor.", fx("on_attack", op("armor", amount=1), scope={"attacker": "self"}), tribe="human")
    m("gilded_nest", "Gilded Nest", 2, 1, 3, "Deathrattle: Summon a 1/1 Beast.", fx("deathrattle", summon("hatchling")), tribe="plant")
    ROLE = "engine"
    m("amber_appraiser", "Amber Appraiser", 3, 2, 3, "After a friendly Beast dies, add a Coin to your hand. (Once per turn.)", fx("on_minion_died", op("add_to_hand", card_id="fortune_coin", count=1), scope={"who": "friendly_minion", "card": {"tribe": "beast"}}, once_per_turn=True), tribe="human")
    ROLE = "answer"
    s("trophy_exchange", "Trophy Exchange", 3, "Return a friendly minion to your hand. Draw two cards.", op("return_to_hand", chosen("friendly")), draw(2), rarity="rare")
    ROLE = "recovery"
    m("jungle_pawnbroker", "Jungle Pawnbroker", 4, 3, 4, "Predator (Plant): Draw a card.", predator("plant", draw()), rarity="rare", tribe="human")
    ROLE = "legendary"
    m("vexa", "Vexa, Trophy Broker", 6, 4, 5, "Predator (Beast): Draw two cards. Battlecry: Add a Coin to your hand.", predator("beast", draw(2)), fx("battlecry", op("add_to_hand", card_id="fortune_coin", count=1)), rarity="legendary", tribe="human")
    PACKAGE, ROLE = "wild_combo", "enabler"
    m("coinleaf", "Coinleaf", 1, 1, 1, "Deathrattle: Add a Coin to your hand.", fx("deathrattle", op("add_to_hand", card_id="fortune_coin", count=1)), tribe="plant")
    m("prize_raptor", "Prize Raptor", 2, 2, 2, "Predator (Plant): Gain +1 Attack.", predator("plant", buff(attack=1, health=0)))
    ROLE = "engine"
    m("wager_caller", "Wager Caller", 3, 2, 3, "After you play a card, gain +1 Attack this turn. (Once per turn.)", fx("on_card_played", buff(attack=1, health=0, duration="until_end_of_turn"), scope={"by": "owner"}, once_per_turn=True), tribe="human")
    ROLE = "answer"
    s("weighted_snare", "Weighted Snare", 2, "Deal 3 damage to an enemy minion. If you played two other cards this turn, deal 2 more.", damage(chosen("enemy"), 3), op("conditional", **{"if": {"cmp": [{"ref": "owner.cards_played_this_turn"}, ">=", 3]}, "then": [damage(chosen("enemy"), 2)]}), rarity="rare")
    ROLE = "recovery"
    s("cached_winnings", "Cached Winnings", 3, "Draw two cards. Add a Coin to your hand.", draw(2), op("add_to_hand", card_id="fortune_coin", count=1), rarity="rare")
    ROLE = "legendary"
    s("winner_takes_wild", "Winner Takes the Wild", 6, "Deal 4 damage to all enemies. After 3 other cards this turn, deal 3 more to enemy hero.", damage("all_enemy_characters", 4), op("conditional", **{"if": {"cmp": [{"ref": "owner.cards_played_this_turn"}, ">=", 4]}, "then": [damage("enemy_hero", 3)]}), rarity="legendary")
    PACKAGE, ROLE = "legacy_hoard", "legacy_support"
    m("amber_prospector", "Amber Prospector", 2, 2, 2, "Battlecry: Add a Coin to your hand.", fx("battlecry", op("add_to_hand", card_id="fortune_coin", count=1)), tribe="human", tags=["hoard"])
    s("buried_purse", "Buried Purse", 2, "Add two Coins to your hand. Draw a card.", op("add_to_hand", card_id="fortune_coin", count=2), draw(), rarity="rare", tags=["hoard"])
    PACKAGE = "legacy_gamble"
    m("fossil_gambler", "Fossil Gambler", 3, 3, 3, "Battlecry: Flip a coin. Heads: gain Taunt. Tails: gain Rush.", fx("battlecry", op("conditional", **{"if": {"flip": 50}, "then": [kw("self", "taunt")], "else": [kw("self", "rush")]})), tribe="human", tags=["gamble"])
    s("wild_odds", "Wild Odds", 3, "Draw a card. Flip a coin. Heads: 4 damage to a random enemy minion. Tails: gain 4 Armor.", draw(), op("conditional", **{"if": {"flip": 50}, "then": [damage("random_enemy_minion", 4)], "else": [op("armor", amount=4)]}), rarity="rare", tags=["gamble"])

    CLASS, PACKAGE, ROLE = "order", "matriarch_summon", "enabler"
    m("nursery_squire", "Nursery Squire", 1, 1, 1, "At the end of your turn, restore 1 Health to adjacent minions.", fx("turn_end", heal("adjacent", 1), scope={"side": "owner"}), tribe="human")
    m("sacred_seedbed", "Sacred Seedbed", 2, 1, 2, "Battlecry: Summon a 1/1 Plant.", fx("battlecry", summon()), tribe="plant")
    ROLE = "engine"
    m("herd_captain", "Herd Captain", 3, 2, 3, "Your other Plants have +1 Attack.", fx("aura", op("aura", attack=1), targets=sel("all_friendly_minions", tribe="plant", not_self=True)), tribe="human")
    ROLE = "answer"
    s("shelter_the_young", "Shelter the Young", 2, "Give your minions +1 Health. Summon a 1/1 Beast.", buff("all_friendly_minions", 0, 1), summon("hatchling"), rarity="rare")
    ROLE = "recovery"
    s("nursery_roll_call", "Nursery Roll Call", 3, "Draw two cards. Restore 1 Health to your hero.", draw(2), heal("owner_hero", 1), rarity="rare")
    ROLE = "legendary"
    m("bastionback_matriarch", "Bastionback Matriarch", 7, 4, 7, "Taunt. Predator (Plant): Your minions get +1 Health. Battlecry: Summon 2 1/3 Taunt Plants.", predator("plant", buff("all_friendly_minions", 0, 1)), fx("battlecry", summon("vineguard", 2)), rarity="legendary", keywords=["taunt"])
    PACKAGE, ROLE = "refuge_control", "enabler"
    m("refuge_sprout", "Refuge Sprout", 1, 1, 1, "Deathrattle: Gain 2 Armor.", fx("deathrattle", op("armor", amount=2)), tribe="plant")
    m("bastion_grazer", "Bastion Grazer", 2, 2, 2, "Predator (Plant): Gain Taunt.", predator("plant", kw("self", "taunt")))
    ROLE = "engine"
    m("spring_warden", "Spring Warden", 3, 2, 4, "At the end of your turn, if you have another Beast, restore 2 Health to your hero.", fx("turn_end", heal("owner_hero", 2), condition={"exists": sel("all_friendly_minions", tribe="beast", not_self=True)}, scope={"side": "owner"}))
    ROLE = "answer"
    s("keeper_judgment", "Keeper's Judgment", 4, "Set an enemy minion's Attack to 1. Draw a card.", op("set_stats", chosen("enemy"), attack=1), draw(), rarity="rare")
    ROLE = "recovery"
    m("canopy_hospitaller", "Canopy Hospitaller", 5, 3, 5, "Predator (Beast): Restore 5 Health to your hero.", predator("beast", heal("owner_hero", 5)), rarity="rare", tribe="human")
    ROLE = "legendary"
    s("last_refuge", "The Last Refuge", 7, "Restore 8 Health to your hero. Give your minions Divine Shield. Draw a card.", heal("owner_hero", 8), kw("all_friendly_minions", "divine_shield"), draw(), rarity="legendary")
    PACKAGE, ROLE = "legacy_aegis", "legacy_support"
    m("amber_aegis", "Amber Aegis", 2, 1, 2, "Divine Shield.", keywords=["divine_shield"], tribe="plant", tags=["aegis"])
    s("renew_the_guard", "Renew the Guard", 3, "Give a friendly minion Divine Shield and +1/+1.", kw(chosen("friendly"), "divine_shield"), buff(chosen("friendly")), rarity="rare", tags=["aegis"])
    PACKAGE = "legacy_formation"
    m("trail_standard", "Trail Standard", 2, 1, 3, "Battlecry: Give adjacent minions +1 Attack.", fx("battlecry", buff("adjacent", 1, 0)), tribe="human", tags=["formation"])
    m("canopy_marshal", "Canopy Marshal", 4, 3, 4, "Adjacent minions have +1/+1.", fx("aura", op("aura", attack=1, health=1), targets="adjacent"), rarity="rare", tribe="human", tags=["formation"])

    CLASS, PACKAGE, ROLE = "shadow", "tracks_tempo", "enabler"
    m("reed_whisper", "Reed Whisper", 1, 1, 1, "Stealth.", keywords=["stealth"], tribe="plant")
    m("dusk_hatchling", "Dusk Hatchling", 2, 2, 1, "Deathrattle: Summon a 1/1 Beast.", fx("deathrattle", summon("hatchling")))
    ROLE = "engine"
    m("shade_raptor", "Shade Raptor", 3, 2, 3, "Predator (Plant): Stealth. On attack, give another random friendly minion Stealth.", predator("plant", kw("self", "stealth")), fx("on_attack", kw(sel("random_friendly_minion", not_self=True), "stealth"), scope={"attacker": "self"}))
    ROLE = "answer"
    s("unseen_pounce", "Unseen Pounce", 2, "Give a friendly minion +2 Attack this turn and Stealth.", buff(chosen("friendly"), 2, 0, duration="until_end_of_turn"), kw(chosen("friendly"), "stealth"), rarity="rare")
    ROLE = "recovery"
    m("trail_informant", "Trail Informant", 4, 3, 4, "Predator (Beast): Draw a card.", predator("beast", draw()), rarity="rare", tribe="human")
    ROLE = "legendary"
    m("sava", "Sava, the Hundred Tracks", 6, 5, 5, "Rush. Predator (Beast): Gain Divine Shield.", predator("beast", kw("self", "divine_shield")), keywords=["rush"], rarity="legendary", tribe="human")
    PACKAGE, ROLE = "great_hunt_combo", "enabler"
    m("scent_leaf", "Scent Leaf", 1, 1, 1, "Deathrattle: Draw a card.", fx("deathrattle", draw()), tribe="plant")
    m("scent_lurker", "Scent Lurker", 2, 2, 2, "Predator (Plant): Gain +1 Attack.", predator("plant", buff(attack=1, health=0)))
    ROLE = "engine"
    m("hunt_signaller", "Hunt Signaller", 3, 2, 3, "After you play a card, another random friendly minion gains +1 Attack this turn. (1/turn)", fx("on_card_played", buff(sel("random_friendly_minion", not_self=True), 1, 0, duration="until_end_of_turn"), scope={"by": "owner"}, once_per_turn=True), tribe="human")
    ROLE = "answer"
    s("mark_the_quarry", "Mark the Quarry", 2, "Deal 3 damage to an enemy minion. If you played another card this turn, draw a card.", damage(chosen("enemy"), 3), op("conditional", **{"if": {"cmp": [{"ref": "owner.cards_played_this_turn"}, ">=", 2]}, "then": [draw()]}), rarity="rare")
    ROLE = "recovery"
    s("circle_back", "Circle Back", 3, "Return a friendly minion to your hand. Draw two cards.", op("return_to_hand", chosen("friendly")), draw(2), rarity="rare")
    ROLE = "legendary"
    s("great_hunt", "The Great Hunt", 6, "Deal 5 to an enemy. After 2 other cards this turn, give your minions +2 Attack this turn.", damage(sel("chosen", side="enemy"), 5), op("conditional", **{"if": {"cmp": [{"ref": "owner.cards_played_this_turn"}, ">=", 3]}, "then": [buff("all_friendly_minions", 2, 0, duration="until_end_of_turn")]}), rarity="legendary")
    PACKAGE, ROLE = "legacy_stealth", "legacy_support"
    m("veil_gecko", "Veil Gecko", 2, 2, 2, "Stealth.", keywords=["stealth"], tags=["stealth"])
    s("veiled_supply", "Veiled Supply", 3, "Give a friendly Stealthed minion +1/+2. Draw a card.", buff(chosen("friendly", has_keyword="stealth"), 1, 2), draw(), rarity="rare", tags=["stealth"])
    PACKAGE = "legacy_venom"
    m("sap_viper", "Sap Viper", 2, 1, 2, "Poisonous.", keywords=["poisonous"], tags=["venom"])
    m("venom_handler", "Venom Handler", 4, 3, 4, "Battlecry: Give a friendly Poisonous minion +0/+3.", fx("battlecry", buff(chosen("friendly", has_keyword="poisonous"), 0, 3)), rarity="rare", tribe="human", tags=["venom"])


def envelope(records):
    return {"schema_version": 1, "records": records}


def write(name, body):
    OUT.mkdir(parents=True, exist_ok=True)
    content = json.dumps(body, ensure_ascii=False, indent=2) + "\n"
    if "--check" in sys.argv:
        assert (OUT / name).read_text(encoding="utf-8") == content, f"Generated data drift: {name}"
    else:
        (OUT / name).write_text(content, encoding="utf-8")


def support_content():
    classes = ["war", "decay", "knowledge", "fortune", "order", "shadow"]
    condition = {"type": "all_of", "of": [
        {"type": "runs_won", "n": 20},
        *[{"type": "runs_won", "n": 2, "hero": "hero_" + cls} for cls in classes],
        {"type": "trial_completed", "trial_id": "trial_primal_crown"}]}
    unlock = {"key": "collection_law_of_the_jungle", "condition": condition}
    unlock_metadata = {
        "set_id": SET, "display_name": "Law of the Jungle",
        "description": "Master all six classes, then claim the Primal Crown.",
        "unlock": unlock, "unlock_mode": "all", "retroactive": True,
        "unlock_rewards": [],
        "unlock_requirements": [
            {"type": leaf["type"], "description": (
                "Win 20 lifetime runs." if leaf.get("n") == 20 else
                "Win two runs as " + leaf.get("hero", "").removeprefix("hero_") + "." if leaf.get("type") == "runs_won" else
                "Complete all three Primal Crown encounters in one attempt."),
             "params": {k: v for k, v in leaf.items() if k != "type"}}
            for leaf in condition["of"]]}
    write("unlock.json", {"schema_version": 1, "config": unlock})

    neutral = [c["id"] for c in CARDS if c["set"] == "neutral" and not c.get("token")]
    early = ["neutral_jungle_seedling_keeper", "neutral_jungle_fern_hopper"]
    other_neutral = [cid for cid in neutral if cid not in early]
    bundles, ni = [], 0
    legendary_styles = {
        "war": ["tempo", "aggro"], "decay": ["attrition", "sacrifice"],
        "knowledge": ["value", "control"], "fortune": ["value", "combo"],
        "order": ["summon", "control"], "shadow": ["tempo", "combo"]}
    family = {"war": "primal_hunt", "shadow": "primal_hunt", "decay": "living_canopy",
              "order": "living_canopy", "knowledge": "apex_succession", "fortune": "apex_succession"}
    # The two small vanilla prey are deliberate bridges; other shared cards
    # retain their own family so bundle themes preserve useful draft clusters.
    for c in CARDS:
        if c["set"] in classes:
            c["tags"].append(family[c["set"]])
        elif c["id"] in early:
            c["tags"] = list(dict.fromkeys(c["tags"] + list(dict.fromkeys(family.values()))))
    for cls in classes:
        own = [c for c in CARDS if c["set"] == cls]
        legacy = [c["id"] for c in own if META[c["id"]]["role"] == "legacy_support"]
        packages = list(dict.fromkeys(META[c["id"]]["package"] for c in own if c["id"] not in legacy))
        for pi, package in enumerate(packages):
            p = [c["id"] for c in own if META[c["id"]]["package"] == package]
            assert len(p) == 6
            META[p[5]].update(playstyle=legendary_styles[cls][pi], enablers=[p[0], p[1], p[2], p[4]])
            pairs = [(p[0], p[2]), (p[1], p[2]), (p[3], legacy[0]),
                     (p[4], legacy[1]), (p[5], p[1]), (legacy[2], p[0]), (legacy[3], p[4])]
            for i, pair in enumerate(pairs):
                thematic = [cid for cid in other_neutral if family[cls] in next(c["tags"] for c in CARDS if c["id"] == cid)]
                shared = early[i] if i < 2 else thematic[ni % len(thematic)]
                if i >= 2:
                    ni += 1
                bid = f"bundle_{cls}_jungle_{pi + 1}_{i + 1}"
                bundles.append(dict(id=bid, name=package.replace("_", " ").title() + f" {i + 1}",
                                    set=cls, collection_id=SET, theme=family[cls], cards=[*pair, shared], unlock=None,
                                    text={"key": f"bundle.{bid}.text", "en": "Prey, predators, and a class plan for the next hunt."}))
        for cid in legacy:
            META[cid]["legacy_mechanic"] = META[cid]["package"].removeprefix("legacy_")
    write("bundles.json", envelope(bundles))

    def boss(cid, name, band, token, deck, intro):
        return dict(id=cid, name=name, collection_id=SET, band=band, health=30 if band == 1 else 40,
                    hero_power=None, passive=fx("turn_end", summon(token), scope={"side": "owner"}),
                    passive_text={"key": f"boss.{cid}.passive", "en": f"At the end of the boss's turn, summon a 1/1 {'Plant' if token == 'seedling' else 'Beast'}."},
                    deck=["neutral_jungle_" + x for x in deck for _ in range(2)],
                    ai_profile="tempo", tags=["predator", "living_canopy" if band == 1 else "primal_hunt"],
                    intro_text={"key": f"boss.{cid}.intro", "en": intro})
    briarjaw = boss("boss_briarjaw", "Briarjaw, Nursery Stalker", 1, "seedling", [
        "seedling_keeper", "spore_nursery", "fossil_sprout", "canopy_stalker", "root_watcher",
        "thorn_runner", "reed_ambusher", "nest_guard", "fern_hopper", "shelter_fern",
        "trophy_sifter", "ancient_browser", "mossjaw", "guard_the_nest", "scent_tracker"],
        "Briarjaw grows Plants before stalking them. Clear the nursery to deny the next Predator bonus.")
    veyra = boss("boss_veyra", "Veyra, Keeper of the Hunt", 2, "hatchling", [
        "fern_hopper", "nest_tender", "nest_guard", "reed_ambusher", "root_watcher",
        "thornback_yearling", "trophy_sifter", "vine_sentry", "scent_tracker", "razorbeak",
        "boulderhide", "pack_outrider", "brush_raptor", "crushing_tail", "expedition_supplier"],
        "Veyra breeds Beasts to awaken her pack. Trade away prey before the larger hunters arrive.")
    veyra["passive"]["condition"] = {"not": {"exists": {
        "selector": "all_friendly_minions", "filter": {"tribe": "beast"}}}}
    veyra["passive_text"]["en"] = "At the end of the boss's turn, if it has no Beast, summon a 1/1 Beast."
    write("bosses.json", envelope([briarjaw, veyra]))

    def treasure(slug, name, rarity, text, effects, tags):
        cid = "treasure_jungle_" + slug
        return dict(id=cid, name=name, collection_id=SET, rarity=rarity, tags=tags,
                    effects=effects, unlock=None, text={"key": f"treasure.{cid}.text", "en": text})
    treasures = [
        treasure("trailkeeper_compass", "Trailkeeper's Compass", "rare",
                 "Start each match with a 1/1 Plant in play and a 1/1 Beast in your hand.",
                 [fx("on_match_start", summon(), op("add_to_hand", card_id="neutral_jungle_hatchling", count=1))],
                 ["universal", "tempo", "value"]),
        treasure("patient_watchglass", "Patient Watchglass", "common",
                 "At the end of your turn, if you have at least 2 unspent Mana, gain 2 Armor.",
                 [fx("turn_end", op("armor", amount=2), scope={"side": "owner"},
                     condition={"cmp": [{"ref": "owner.mana_current"}, ">=", 2]})],
                 ["universal", "defensive", "armour"]),
        treasure("last_ration", "Last Ration", "rare",
                 "At the start of your turn, if your hand is empty, draw a card.",
                 [fx("turn_start", draw(), scope={"side": "owner"},
                     condition={"cmp": [{"ref": "owner.hand_size"}, "==", 0]})],
                 ["universal", "aggro", "draw"])]
    write("treasures.json", envelope(treasures))
    manifest = {"id": SET, "name": "Law of the Jungle", "display_name": "Law of the Jungle", "version": 1,
                "trial_id": "trial_primal_crown", "unlock": unlock, "unlock_metadata": unlock_metadata,
                "card_metadata": META,
                "item_groups": {"mechanic_support": [treasures[0]["id"]], "gap_fill": [t["id"] for t in treasures[1:]]},
                "files": ["cards.json", "bosses.json", "bundles.json", "treasures.json", "unlock.json", "trial.json"]}
    write("collection.json", {"schema_version": 1, "config": manifest})
    loaner = ["neutral_jungle_" + slug for slug in [
        "seedling_keeper", "fern_hopper", "reed_ambusher", "root_watcher", "canopy_stalker",
        "thorn_runner", "scent_tracker", "mossjaw", "razorbeak", "boulderhide", "rain_drinker"]]
    loaner += ["order_jungle_" + slug for slug in [
        "sacred_seedbed", "bastion_grazer", "herd_captain", "keeper_judgment", "canopy_hospitaller", "nursery_roll_call"]]
    loaner = [cid for cid in loaner for _ in range(2)]
    loaner += ["order_jungle_bastionback_matriarch", "order_jungle_last_refuge"]
    player_order = ["neutral_jungle_" + slug for slug in [
        "seedling_keeper", "canopy_stalker", "reed_ambusher", "root_watcher", "scent_tracker", "thorn_runner",
        "fern_hopper"]]
    player_order += ["order_jungle_sacred_seedbed", "neutral_jungle_canopy_stalker",
                     "order_jungle_bastionback_matriarch", "order_jungle_last_refuge", "neutral_jungle_boulderhide"]
    enemy_order = ["neutral_jungle_" + slug for slug in [
        "fern_hopper", "reed_ambusher", "root_watcher", "canopy_stalker", "scent_tracker", "thorn_runner"]]
    encounters = []
    for index, definition in enumerate([briarjaw, veyra, veyra]):
        deck = list(definition["deck"])
        if index == 2:
            # Visible rematch variant: a faster mixed-prey deck, still the same boss.
            deck = ["neutral_jungle_" + slug for slug in [
                "seedling_keeper", "fern_hopper", "reed_ambusher", "root_watcher", "canopy_stalker",
                "scent_tracker", "thorn_runner", "nest_guard", "spore_nursery", "mossjaw",
                "razorbeak", "vine_sentry", "guard_the_nest", "crushing_tail", "expedition_supplier"] for _ in range(2)]
        valid_order = [cid for cid in enemy_order if cid in deck]
        encounters.append({"id": ["nursery", "keeper", "crown_rematch"][index],
                           "boss_id": definition["id"], "band": definition["band"], "health": definition["health"],
                           "deck": deck, "boss_draw_order": valid_order,
                           "enemy_opening_board": ["neutral_jungle_seedling_keeper", "neutral_jungle_fern_hopper"]})
    write("trial.json", {"schema_version": 1, "config": {
        "id": "trial_primal_crown", "collection": SET, "hero_id": "hero_order", "deck": loaner,
        "treasures": [t["id"] for t in treasures], "player_draw_order": player_order,
        "access_condition": {"type": "all_of", "of": condition["of"][:-1]},
        "objective": {"predator": 3, "friendly": 1, "enemy": 1}, "encounters": encounters}})


def audit():
    cards = {c["id"]: c for c in CARDS}
    collectible = [c for c in CARDS if not c.get("token")]
    assert len(cards) == len(CARDS) == 141
    assert len(collectible) == 138
    assert len({c["name"] for c in CARDS}) == len(CARDS)
    for c in CARDS:
        assert len(c["name"]) <= 32 and len(c["id"]) <= 48, c["id"]
        assert len(c["text"]["en"]) <= 90, c["id"]
        assert c["collection_id"] == SET
        assert c["id"].startswith(c["set"] + "_jungle_")
        assert not any(e.get("from", {}).get("pool") in ("deck", "hand") for fx_ in c["effects"] for e in fx_["ops"])
    classes = ["war", "decay", "knowledge", "fortune", "order", "shadow"]
    expected = Counter(common=8, rare=6, legendary=2)
    for cls in classes:
        own = [c for c in collectible if c["set"] == cls]
        assert Counter(c["rarity"] for c in own) == expected, cls
        legendary = [c for c in own if c["rarity"] == "legendary"]
        assert len({META[c["id"]]["playstyle"] for c in legendary}) == 2
        for legend in legendary:
            assert len(META[legend["id"]]["enablers"]) >= 2
            assert all(cards[cid]["rarity"] != "legendary" for cid in META[legend["id"]]["enablers"])
        legacy = [c for c in own if META[c["id"]]["role"] == "legacy_support"]
        assert len(legacy) == 4 and len({META[c["id"]]["legacy_mechanic"] for c in legacy}) == 2
    assert Counter(c["rarity"] for c in collectible if c["set"] == "neutral") == Counter(common=28, rare=14)
    def load(name, key):
        return json.loads((OUT / name).read_text(encoding="utf-8"))[key]
    bundles = load("bundles.json", "records")
    assert len(bundles) == 84
    for cls in classes:
        own = [b for b in bundles if b["set"] == cls]
        assert len(own) == 14
        assert len({tuple(b["cards"]) for b in own}) == 14
        occurrences = Counter(cid for b in own for cid in b["cards"])
        for b in own:
            assert len(set(b["cards"])) == 3
            assert any(cards[cid]["set"] == cls for cid in b["cards"])
            assert all(cards[cid]["set"] in (cls, "neutral") for cid in b["cards"])
        for c in collectible:
            if c["set"] == cls:
                assert occurrences[c["id"]] >= (2 if META[c["id"]]["role"] == "legacy_support" else 1)
    assert {cid for b in bundles for cid in b["cards"] if cards[cid]["set"] == "neutral"} == {c["id"] for c in collectible if c["set"] == "neutral"}
    bosses = load("bosses.json", "records")
    assert len(bosses) == 2
    for b in bosses:
        assert len(b["deck"]) == 30 and all(cid in cards for cid in b["deck"])
        assert any("Predator" in cards[cid]["text"]["en"] for cid in b["deck"])
        tribe = "plant" if b["band"] == 1 else "beast"
        assert sum(tribe in cards[cid].get("tribes", []) for cid in b["deck"]) >= 6
    treasures = load("treasures.json", "records")
    manifest = load("collection.json", "config")
    groups = manifest["item_groups"]
    assert len(groups["mechanic_support"]) == 1 and len(groups["gap_fill"]) == 2
    assert len(set(sum(groups.values(), []))) == len(treasures) == 3
    trial = load("trial.json", "config")
    assert len(trial["deck"]) == 36 and len(trial["encounters"]) == len(trial["treasures"]) == 3
    assert all(cards[cid]["set"] in ("neutral", "order") for cid in trial["deck"])
    assert not (Counter(trial["player_draw_order"]) - Counter(trial["deck"]))
    assert trial["objective"] == {"predator": 3, "friendly": 1, "enemy": 1}
    for e in trial["encounters"]:
        assert not (Counter(e["boss_draw_order"]) - Counter(e["deck"]))
        assert {tribe for cid in e["enemy_opening_board"] for tribe in cards[cid]["tribes"]} == {"plant", "beast"}
    # Compare raw stat totals at the same cost/rarity to the current canonical pool.
    baseline = defaultdict(list)
    for path in (ROOT / "assets/data").glob("cards_*.json"):
        for c in json.loads(path.read_text(encoding="utf-8"))["records"]:
            if c["type"] == "minion" and not c.get("token") and c["set"] != "boss":
                baseline[(c["cost"], c["rarity"])].append(c["attack"] + c["health"])
    flags = []
    for c in collectible:
        if c["type"] != "minion" or c["rarity"] == "legendary":
            continue
        values = baseline[(c["cost"], c["rarity"])]
        if not values:
            continue
        mean = sum(values) / len(values)
        sigma = math.sqrt(sum((v - mean) ** 2 for v in values) / len(values))
        total = c["attack"] + c["health"]
        if abs(total - mean) > sigma + 1e-9:
            flags.append((c, total, mean, sigma))
    print(f"Audit passed: 138 collectibles, 12 class legendaries, 24 legacy slots, 84 bundles, 2 bosses, 3 items, trial36/3/3; {len(flags)} raw-stat flags")
    return flags


def design_report(flags):
    lines = ["# Law of the Jungle card and balance ledger", "",
             "The staged source is `tools/content/jungle_content.py`; regenerate with Python,",
             "then run it with `--check` to verify generated JSON and structural invariants.", "",
             "## Collection and package checks", "",
             "- 138 collectible cards: 42 Neutral (28 common, 14 rare), 16 per class (8/6/2).",
             "- Each class has two distinct six-card packages and four separate legacy cards.",
             "- All 84 bundles contain three distinct legal cards and a class card. Every class",
             "  card is offered; every legacy slot appears twice; all 42 shared cards appear.",
             "- Bundle themes are Primal Hunt (War/Shadow), Living Canopy (Decay/Order), and",
             "  Apex Succession (Knowledge/Fortune). Only the two generic one-cost prey bridge",
             "  all three themes. Other shared cards retain their actual family.", "",
             "## Legendary plans and engines", "",
             "| Class | Legendary | Plan | Non-legendary enablers |", "| --- | --- | --- | --- |"]
    by_id = {c["id"]: c for c in CARDS}
    for c in CARDS:
        meta = META[c["id"]]
        if c["rarity"] == "legendary":
            enablers = ", ".join(by_id[cid]["name"] for cid in meta["enablers"])
            lines.append(f"| {c['set'].title()} | {c['name']} | {meta['playstyle']} | {enablers} |")
    lines += ["", "Every dedicated engine has a continuing effect. Challenger generates Armor on",
              "attacks; Root Feaster grows from Plant deaths; Fossil Reader grows Plant boards",
              "from spells; Appraiser converts Beast deaths into Coins; Shade Raptor conceals",
              "another friendly minion after attacking. Each can trigger on later turns without",
              "a legendary. The other seven engines use auras or printed recurring triggers.", "",
              "## Raw-stat audit", "",
              "Compare Attack + Health to all current non-token, non-boss canonical minions at",
              "the same cost and rarity. Use population standard deviation; exactly zero",
              "deviation still flags any difference. Legendary bodies are excluded. This is a",
              "screen for review, not an effect valuation or a win-rate simulation.", "",
              f"{len(flags)} bodies exceed one standard deviation. The three above-curve flags",
              "are intentional and individually compared below. The remaining bodies spend",
              "their budget on the exact printed utility shown; none has a hidden compensation.", "",
              "| Card | Stat total | Canonical mean ± σ | Review / compensation |",
              "| --- | ---: | ---: | --- |"]
    high = {
        "neutral_jungle_amber_grazer": "Vanilla 2/3 matches core Cellar Guard; Beast is a sidegrade that can enable either player's Predator.",
        "war_jungle_ridge_bladesmith": "2/4 defensive weapon engine: requires an actual hero attack; +1 Attack capped once per turn. No immediate attack or free weapon.",
        "war_jungle_scarhide_veteran": "3/5 at four mana is within core common body ranges; its class-rare bonus needs damaged survivors and adds no Health or direct damage.",
    }
    for c, total, mean, sigma in flags:
        rationale = high.get(c["id"], "Lower body pays for: " + c["text"]["en"])
        lines.append(f"| {c['name']} | {total} | {mean:.2f} ± {sigma:.2f} | {rationale} |")
    lines += ["", "Legendary envelope review: Gorath and Extinction March need a board and offer",
              "bounded tempo; Worldroot has removable recurring bodies and Reclamation resets",
              "its own board; Tala/Vexa draw finite cards, while Archive transforms rather than",
              "silences opposing Deathrattles. Matriarch is board-cap limited; Last Refuge cannot",
              "revive a cleared board. Sava is one shielded trade; Great Hunt and Winner require",
              "paid sequencing for their additional burst. No legendary reduces its own cost,",
              "repeats hero damage indefinitely, or creates an unbounded mana loop.", "",
              "## Run-item audit", "",
              "All three are new treasure IDs, offered only under the collection's eligibility",
              "and existing treasure selection rules. Duplicate IDs install once. They carry no",
              "extra persistent counters; save/resume uses the normal treasure IDs/state path.", "",
              "| Item | Group / rarity | Missing role and closest existing item | Limits and budget |",
              "| --- | --- | --- | --- |",
              "| Trailkeeper's Compass | Mechanic support / rare | Deliberate cross-tribe opening. Bottomless Satchel gives two real cards but no guaranteed prey; Compass gives a Plant body and a low-power Beast token in hand. | Once at match start; board and hand caps apply. No hidden Predator payoff. Removing the Plant disables Plant bonuses. |",
              "| Patient Watchglass | Independent gap fill / common | Rewards holding Mana. Mending Charm heals every turn; this stores Armor but requires sacrificing at least two available Mana. | Exactly 2 Armor at owner end step if Mana ≥ 2. No damage trigger and no requirement for a minion or Predator. |",
              "| Last Ration | Independent gap fill / rare | Empty-hand recovery for low-curve decks. Scholar's Candle guarantees two timed draws; Ration can draw over multiple turns but only when empty before the normal draw. | One extra card at owner start step, existing deck/fatigue/hand rules. No cost reduction, bonus Mana, or automatic emptying of hand. |", "",
              "## Encounters and trial", "",
              "Briarjaw (band 1, 30 Health) supplies Plant tokens; Veyra (band 2, 40 Health)",
              "supplies Beast tokens. Each deck has 30 real cards, cheap prey and multiple",
              "Predators. Tokens appear at boss turn end, allowing the player to clear them",
              "before the next Predator. Intent text exposes this timing and counterplay.", "",
              "The three Primal Crown encounters use Briarjaw, Veyra, and a faster mixed-prey",
              "Veyra deck variant. The 36-card Order loaner is legal without owning the set.",
              "Its fixed opening/draw prefix includes three cheap predators and friendly prey.",
              "Each encounter explicitly begins with both enemy prey tribes, and Compass",
              "provides friendly Plant prey plus a Beast in hand. The objective counts bonuses",
              "once even when both boards qualify; it also requires winning each encounter.", "",
              "## Roster read-through and limits", "",
              "These are design checks, not observed class win rates. All six class pairs are",
              "draftable through their own seven-bundle package libraries and work without",
              "drawing their legendary. Starter/core cards still provide the other run picks.", "",
              "| Opponent group | Plans and counterplay |",
              "| --- | --- |",
              "| Torchbearer / Rat King | Small prey contest the opening. War/Shadow trade then pressure; Decay/Order recover; Knowledge/Fortune draw with real bodies. Expensive legends are finishers, never required early. |",
              "| Gatekeeper / Hollow King / Cellar Hermit / Blood Abbess | Wide spell damage and finite transform/removal answer protection and recovery. War/Shadow need to trade through Taunt; Decay/Order rebuild, Knowledge/ Fortune replenish resources. Tokens and conditional stats alone do not bypass defense. |",
              "| Rot Warden / Bog Witch | Deathrattle boards punish indiscriminate clears. War/Shadow use initiative; Decay/Order can match replacement bodies; Knowledge's Archive and Fortune's bounce let the player select favorable trades without requiring a specific enemy tribe. |",
              "| Frost Hag / Lich Archivist / Mirror Sage / Shadow of the Delve / Dungeon Heart | Canopy deathrattles replenish prey; core draw and Archive/Ration recover resources. War's wide buff and Shadow's burst need surviving bodies; Decay/Order can grind but are vulnerable to clears; Knowledge/Fortune need proactive bodies alongside draw. Shield and Stealth do not stop untargeted damage. |",
              "| Scrap Golem / Pyre Sergeant / Iron Tollman | Taunts, healing, Watchglass and initiative offer counterplay to weapon pressure and Armor. War/Shadow can apply sustained attacks; Decay/Order can recover; Knowledge/Fortune need actual board damage. Fragile prey and repeat engines are removable; no card disables all hero attacks. |",
              "| Briarjaw / Veyra | All six classes can play against enemy-provided prey. Clear end-step prey to deny bonuses; leaving it alive rewards sequencing at a real board cost. The bosses also carry their own baseline bodies. |", "",
              "No card needs an enemy-only tribe to function: Predator cards have normal bodies,",
              "and every preferred tribe has cheap friendly access. No unconditional spell kills",
              "a boss hero or ignores its Health. Effects remain finite under board/hand/Mana",
              "caps. Actual runtime sweep, item rules, boss windows, unlock replay, and authored",
              "trial reachability are separate test gates and must be reported from their runs.", "",
              "## Complete card ledger", "",
              "| Card | Class | Rarity | Cost | Body | Package / role |",
              "| --- | --- | --- | ---: | --- | --- |"]
    for c in CARDS:
        if c.get("token"):
            continue
        meta = META[c["id"]]
        body = f"{c['attack']}/{c['health']}" if c["type"] == "minion" else "Spell"
        lines.append(f"| {c['name']} | {c['set']} | {c['rarity']} | {c['cost']} | {body} | {meta['package']} / {meta['role']} |")
    path = ROOT / "design/expansions/law-of-the-jungle/card-ledger.md"
    content = "\n".join(lines) + "\n"
    if "--check" in sys.argv:
        assert path.read_text(encoding="utf-8") == content, "Generated ledger drift"
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    stage()
    support_content()
    write("cards.json", envelope(CARDS))
    design_report(audit())
    print(f"Authored {len(CARDS)} records; {sum(not c.get('token', False) for c in CARDS)} collectibles")
