# Current card taxonomy review

Date: 2026-11-07

Reviewed all 342 current card definitions: 218 units, 111 spells, and 13 weapons. Includes collectible cards, tokens, and boss-only cards. The seven proposed endgame sets are outside this review.

## Rules

- Units use `tribes`; spells use `schools`. Both are arrays and support multiple identities. Weapons retain their weapon type without tribe or school tags.
- Existing `tags` describe draft themes and archetypes. They stay independent of printed taxonomy: Pack support is not automatically a Beast, and a Plague card is not automatically Undead.
- Spell schools describe the source of an ability: Martial for physical tactics, Alchemy for prepared poisons, tonics and smoke, Artifice for repair and reconstruction, and magical schools for actual magic. Healing need not be Holy; drawing need not be Arcane. Lightning belongs to Nature.
- A dual-tag card matches either tag. Silence preserves printed identity; transformation uses the new card definition. Effect filters use `tribe` and `school`.
- Runtime and authoring schemas validate registered IDs, duplicate entries, and type restrictions. Taxonomy is optional for old fixtures; all current units and spells have explicit assignments.

## Unit tribes

| Tribe | Units | Meaning |
| --- | ---: | --- |
| Human | 126 | Ordinary fighters, scholars, healers, merchants and other people. |
| Beast | 34 | Animals, including birds, spiders and snakes; sickness alone does not imply undeath. |
| Undead | 20 | Animated corpses, skeletons and haunting spirits. |
| Demon | 3 | Imps and demonic creatures. |
| Elemental | 8 | Bodies formed from magic or elemental forces. |
| Construct | 25 | Animated or assembled artifacts, golems, fortifications and deployable objects. |
| Mech | 1 | Mechanical automata; currently Slot Machine, also a Construct. |
| Plant | 1 | Vegetation and fungi, currently Sporeling. |
| Giant | 2 | Giant creatures, including Grave Titan. |
| Ogre | 1 | Ogres, currently Ogre Porter. |
| Dragon | 1 | Draconic creatures, currently Ancient Wyrm. |
| Harpy | 1 | Harpies, currently Storm Harpy. |
| Aberration | 1 | Unnatural monster biology, currently Mimic. |

## Spell schools

| School | Spells | Meaning |
| --- | ---: | --- |
| Arcane | 17 | Runes, study, transformation, probability and luck magic. |
| Fire | 5 | Flames and explosive fire. |
| Frost | 12 | Cold, ice and winter magic. |
| Nature | 11 | Weather, growth, animal instincts, biological blight and natural forces. |
| Holy | 6 | Blessings, sacred wards and divine restoration. |
| Shadow | 16 | Necromancy, souls, blood rites and supernatural darkness. |
| Martial | 30 | Combat techniques, commands, physical tricks and transactions. |
| Alchemy | 12 | Poisons, prepared fumes, medicine, tonics and chemical explosives. |
| Artifice | 6 | Technical repair, salvage and reconstruction. |

Counts include each identity of dual-tag cards, so column totals exceed the number of cards.

## Editorial assumptions

These assignments establish a consistent working taxonomy where card names and rules do not fully specify species or magical source. Placeholder art does not override the printed concept.

- Ordinary role-based characters default to Human, including Crooked Croupier, High Roller, Fortune's Favorite, Cold Reader, Hollow Watcher, Ambusher, Wound Tracker and the neutral profession cards. Wolf Rider classifies the rider as Human. Night Stalker is a Beast.
- Gloom Lurker and the boss Lurker are Undead spirits. Ancient Wyrm is a Dragon. Grave Titan is both Undead and Giant. Spore Host is Undead; living plague animals stay Beast.
- Ivory Sentinel, Ivory Bastion and Heart Guardian are Constructs. Carrion Bell, Salvage Bench, Strongbox and the animated Grand Grimoire are Constructs. Slot Machine is both Construct and Mech. Sporeling uses Plant, which includes fungi in this taxonomy.
- Shard Warden, Winter Runewall, Hoarfrost Colossus and Ice Mirror are both Construct and Elemental. Ink Sprite, Rime Elemental, Spark Fiend and Ember Sprite use Elemental.
- Cold Storage uses Arcane / Frost; Forbidden Tome uses Arcane / Shadow; Necrotic Mist uses Shadow / Nature; Pyre Bomb uses Alchemy / Fire.
- Fortune's supernatural luck spells use Arcane; Coin, Coin Purse and Bribe use Martial. Physical pack orders use Martial, while natural burrowing and repopulation use Nature. Repair and reconstruction use Artifice.

## Full card ledger

Each row identifies its source record. Weapons appear for completeness with no tribe or school.

### War

| Card | Type | Tribe / school | Record |
| --- | --- | --- | --- |
| Armorer | Unit | Human | `war_armorer` |
| Blade Apprentice | Unit | Human | `war_blade_apprentice` |
| Blade Strike | Spell | Martial | `war_blade_strike` |
| Blood Price | Spell | Martial | `war_blood_price` |
| Bone Setter | Unit | Human | `war_bone_setter` |
| Cellar Raider | Unit | Human | `war_cellar_raider` |
| Chain Breaker | Unit | Human | `war_chain_breaker` |
| Challenge Blade | Weapon | — | `war_challenge_blade` |
| Cleave Through | Spell | Martial | `war_cleave_through` |
| Crowd Favorite | Unit | Human | `war_crowd_favorite` |
| Duelist's Edge | Weapon | — | `war_duelists_edge` |
| Headsman | Unit | Human | `war_headsman` |
| Heavy Maul | Weapon | — | `war_heavy_maul` |
| Iron Nerve | Spell | Martial | `war_iron_nerve` |
| Iron Resolve | Spell | Martial | `war_iron_resolve` |
| Iron Vanguard | Unit | Human | `war_iron_vanguard` |
| Kingsblade | Weapon | — | `war_kingsblade` |
| Open Wound | Spell | Martial | `war_open_wound` |
| Pit Barrier | Unit | Human | `war_pit_barrier` |
| Pit Berserker | Unit | Human | `war_berserker` |
| Pit Brawler | Unit | Human | `war_pit_brawler` |
| Pit Champion | Unit | Human | `war_pit_champion` |
| Pit Medic | Unit | Human | `war_pit_medic` |
| Pit Quartermaster | Unit | Human | `war_pit_quartermaster` |
| Pit Survivor | Unit | Human | `war_pit_survivor` |
| Pit Tyrant | Unit | Human | `war_pit_tyrant` |
| Quartermaster | Unit | Human | `war_quartermaster` |
| Rally | Spell | Martial | `war_rally` |
| Red Reckoning | Spell | Martial | `war_red_reckoning` |
| Riot Axe | Weapon | — | `war_riot_axe` |
| Riot Spark | Spell | Fire | `war_riot_spark` |
| Rusted Axe | Weapon | — | `war_rusted_axe` |
| Scar Captain | Unit | Human | `war_scar_captain` |
| Scarred Vanguard | Unit | Human | `war_scarred_vanguard` |
| Second Wind | Spell | Martial | `war_second_wind` |
| Sharpen | Spell | Martial | `war_sharpen` |
| Shield Maiden | Unit | Human | `war_shield_maiden` |
| Shield Squire | Unit | Human | `war_shield_squire` |
| Shieldwall Veteran | Unit | Human | `war_shieldwall_veteran` |
| Split the Pit | Spell | Martial | `war_split_the_pit` |
| Stung Recruit | Unit | Human | `war_stung_recruit` |
| Throwing Axe | Weapon | — | `war_throwing_axe` |
| Twin Hatchets | Weapon | — | `war_twin_hatchets` |
| Warcry | Spell | Martial | `war_warcry` |
| Warlord of the Pit | Unit | Human | `war_warlord` |
| Whetstone Blade | Weapon | — | `war_whetstone_blade` |
| Wound Tracker | Unit | Human | `war_wound_tracker` |

### Decay

| Card | Type | Tribe / school | Record |
| --- | --- | --- | --- |
| Blight | Spell | Nature | `decay_blight` |
| Blight Ledger | Spell | Shadow | `decay_blight_ledger` |
| Blight Rat | Unit | Beast | `decay_blight_rat` |
| Blight Tender | Unit | Human | `decay_blight_tender` |
| Boneyard Brute | Unit | Undead | `decay_boneyard_brute` |
| Burial Attendant | Unit | Undead | `decay_burial_attendant` |
| Carrion Bell | Unit | Construct | `decay_carrion_bell` |
| Carrion Crow | Unit | Beast | `decay_carrion_crow` |
| Carrion Picker | Unit | Beast | `decay_carrion_picker` |
| Coffin Golem | Unit | Construct | `decay_coffin_golem` |
| Corpse Collector | Unit | Undead | `decay_corpse_collector` |
| Crypt Leech | Unit | Beast | `decay_crypt_leech` |
| Culling | Spell | Martial | `decay_culling` |
| Feast of Worms | Spell | Shadow | `decay_feast_of_worms` |
| Final Contagion | Spell | Nature | `decay_final_contagion` |
| Fume Cask | Spell | Alchemy | `decay_fume_cask` |
| Ghoul | Unit | Undead | `decay_ghoul` |
| Grave Antidote | Spell | Alchemy | `decay_grave_antidote` |
| Grave Rat | Unit | Beast | `decay_grave_rat` |
| Grave Robber | Unit | Human | `decay_grave_robber` |
| Grave Titan | Unit | Undead / Giant | `decay_grave_titan` |
| Grave Warden | Unit | Undead | `decay_grave_warden` |
| Husk | Unit | Undead | `decay_husk` |
| Husk Herder | Unit | Human | `decay_husk_herder` |
| Husk Mother | Unit | Undead | `decay_husk_mother` |
| Husk Tender | Unit | Human | `decay_husk_tender` |
| Isolation | Spell | Alchemy | `decay_isolation` |
| Last Rites | Spell | Shadow | `decay_last_rites` |
| Mass Grave | Spell | Shadow | `decay_mass_grave` |
| Miasma Leech | Unit | Beast | `decay_miasma_leech` |
| Morbane, Plague Regent | Unit | Undead | `decay_morbane` |
| Necrotic Mist | Spell | Shadow / Nature | `decay_necrotic_mist` |
| Plague Rat | Unit | Beast | `decay_plague_rat` |
| Plague of Rot | Spell | Shadow | `decay_plague_of_rot` |
| Plaguebearer | Unit | Undead | `decay_plaguebearer` |
| Quarantine Keeper | Unit | Human | `decay_quarantine_keeper` |
| Raise Dead | Spell | Shadow | `decay_raise_dead` |
| Relic Keeper | Unit | Undead | `decay_relic_keeper` |
| Rot Beetle | Unit | Beast | `decay_rot_beetle` |
| Rot Feast | Spell | Nature | `decay_rot_feast` |
| Rot Keeper | Unit | Undead | `decay_rot_keeper` |
| Shambling Heap | Unit | Undead | `decay_shambling_heap` |
| Skeleton | Unit | Undead | `decay_skeleton` |
| Soul Tithe | Spell | Shadow | `decay_soul_tithe` |
| Spore Host | Unit | Undead | `decay_spore_host` |
| Spore Satchel | Spell | Alchemy | `decay_spore_satchel` |
| Sporeling | Unit | Plant | `decay_sporeling` |
| Tomb Spider | Unit | Beast | `decay_tomb_spider` |
| Wake Tender | Unit | Human | `decay_wake_tender` |

### Knowledge

| Card | Type | Tribe / school | Record |
| --- | --- | --- | --- |
| Apprentice | Unit | Human | `knowledge_apprentice` |
| Archive Seeker | Unit | Human | `knowledge_archive_seeker` |
| Break the Ice | Spell | Frost | `knowledge_break_the_ice` |
| Candle Acolyte | Unit | Human | `knowledge_candle_acolyte` |
| Chain Lightning | Spell | Nature | `knowledge_chain_lightning` |
| Chill Scribe | Unit | Human | `knowledge_chill_scribe` |
| Cold Front | Spell | Frost | `knowledge_cold_front` |
| Cold Reader | Unit | Human | `knowledge_cold_reader` |
| Cold Storage | Spell | Arcane / Frost | `knowledge_cold_storage` |
| Deep Study | Spell | Arcane | `knowledge_deep_study` |
| Flamewave | Spell | Fire | `knowledge_flamewave` |
| Forbidden Tome | Spell | Arcane / Shadow | `knowledge_forbidden_tome` |
| Frost Lance | Spell | Frost | `knowledge_frost_lance` |
| Frost Ward | Spell | Frost | `knowledge_frost_ward` |
| Frostglass | Spell | Frost | `knowledge_frostglass` |
| Glacial Wind | Spell | Frost | `knowledge_glacial_wind` |
| Glyph Wards | Spell | Arcane | `knowledge_glyph_wards` |
| Grand Grimoire | Unit | Construct | `knowledge_grand_grimoire` |
| Hoarfrost Colossus | Unit | Construct / Elemental | `knowledge_hoarfrost_colossus` |
| Ice Mirror | Unit | Construct / Elemental | `knowledge_ice_mirror` |
| Icebound Page | Unit | Construct | `knowledge_icebound_page` |
| Ilyra, Winter's End | Unit | Human | `knowledge_ilyra` |
| Ink Sprite | Unit | Elemental | `knowledge_ink_sprite` |
| Lightning Lash | Spell | Nature | `knowledge_lightning_lash` |
| Lorekeeper | Unit | Human | `knowledge_lorekeeper` |
| Lost Page | Spell | Arcane | `knowledge_lost_page` |
| Meteor Bolt | Spell | Fire | `knowledge_meteor_bolt` |
| Rime Binder | Unit | Human | `knowledge_rime_binder` |
| Rime Elemental | Unit | Elemental | `knowledge_rime_elemental` |
| Rime Needle | Spell | Frost | `knowledge_rime_needle` |
| Rune Warden | Unit | Human | `knowledge_rune_warden` |
| Scribe | Unit | Human | `knowledge_scribe` |
| Scrying | Spell | Arcane | `knowledge_scrying` |
| Shard Channeler | Unit | Human | `knowledge_shard_channeler` |
| Shard Strike | Spell | Frost | `knowledge_shard_strike` |
| Shard Warden | Unit | Construct / Elemental | `knowledge_shard_warden` |
| Sleetwall | Spell | Frost | `knowledge_sleetwall` |
| Snowbound Scribe | Unit | Human | `knowledge_snowbound_scribe` |
| Spark | Spell | Nature | `knowledge_spark` |
| Star Reader | Unit | Human | `knowledge_star_reader` |
| Study | Spell | Arcane | `knowledge_study` |
| Transmute | Spell | Arcane | `knowledge_transmute` |
| Vault Golem | Unit | Construct | `knowledge_vault_golem` |
| Ward | Unit | Construct | `knowledge_ward` |
| Whiteout | Spell | Frost | `knowledge_whiteout` |
| Winter Lecturer | Unit | Human | `knowledge_winter_lecturer` |
| Winter Runewall | Unit | Construct / Elemental | `knowledge_winter_runewall` |

### Fortune

| Card | Type | Tribe / school | Record |
| --- | --- | --- | --- |
| All In | Spell | Arcane | `fortune_all_in` |
| Big Spender | Unit | Human | `fortune_big_spender` |
| Bribe | Spell | Martial | `fortune_bribe` |
| Card Sharp | Unit | Human | `fortune_card_sharp` |
| Cheat Fate | Spell | Arcane | `fortune_cheat_fate` |
| Coin | Spell | Martial | `fortune_coin` |
| Coin Purse | Spell | Martial | `fortune_coin_purse` |
| Crooked Croupier | Unit | Human | `fortune_crooked_croupier` |
| Dice Thrower | Unit | Human | `fortune_dice_thrower` |
| Double Down | Spell | Arcane | `fortune_double_down` |
| Fortune's Favorite | Unit | Human | `fortune_fortunes_favorite` |
| Gilded Guard | Unit | Human | `fortune_gilded_guard` |
| High Roller | Unit | Human | `fortune_high_roller` |
| Jackpot | Spell | Arcane | `fortune_jackpot` |
| Loaded Bones | Spell | Arcane | `fortune_loaded_bones` |
| Lucky Rat | Unit | Beast | `fortune_lucky_rat` |
| Moneylender | Unit | Human | `fortune_moneylender` |
| Pickpocket | Unit | Human | `fortune_pickpocket` |
| Roulette | Spell | Arcane | `fortune_roulette` |
| Slot Machine | Unit | Construct / Mech | `fortune_slot_machine` |
| Strongbox | Unit | Construct | `fortune_strongbox` |
| Tax Collector | Unit | Human | `fortune_tax_collector` |
| Treasurer | Unit | Human | `fortune_treasurer` |
| Tumbler | Unit | Demon | `fortune_tumbler` |
| Wild Card | Spell | Arcane | `fortune_wild_card` |
| Wishing Well | Spell | Arcane | `fortune_wishing_well` |

### Order

| Card | Type | Tribe / school | Record |
| --- | --- | --- | --- |
| Aegis | Spell | Holy | `order_aegis` |
| Aegis Knight | Unit | Human | `order_aegis_knight` |
| Bless Arms | Spell | Holy | `order_bless_arms` |
| Close Ranks | Spell | Martial | `order_close_ranks` |
| Drillmaster | Unit | Human | `order_drillmaster` |
| Field Marshal | Unit | Human | `order_marshal` |
| High Warden | Unit | Human | `order_high_warden` |
| Hold the Line | Spell | Martial | `order_hold_the_line` |
| Ivory Acolyte | Unit | Human | `order_temple_guard` |
| Ivory Sentinel | Unit | Construct | `order_ivory_sentinel` |
| Line Sergeant | Unit | Human | `order_line_sergeant` |
| Muster Call | Spell | Martial | `order_muster_call` |
| Oath of Iron | Spell | Holy | `order_oath_of_iron` |
| Oathbound | Unit | Human | `order_oathbound` |
| Order Squire | Unit | Human | `order_squire` |
| Phalanx | Unit | Human | `order_phalanx` |
| Recruit | Unit | Human | `order_recruit` |
| Renewal | Spell | Holy | `order_renewal` |
| Shield Priest | Unit | Human | `order_shield_priest` |
| Standard Bearer | Unit | Human | `order_standard_bearer` |
| Sworn Blessing | Spell | Holy | `order_sworn_blessing` |
| Temple Mender | Unit | Human | `order_mender` |
| The Ivory Bastion | Unit | Construct | `order_ivory_bastion` |
| The Unbroken | Unit | Human | `order_the_unbroken` |
| Vow Keeper | Unit | Human | `order_vow_keeper` |
| Warded Recruit | Unit | Human | `order_warded_recruit` |

### Shadow

| Card | Type | Tribe / school | Record |
| --- | --- | --- | --- |
| Alley Cutter | Unit | Human | `shadow_cutpurse` |
| Ambusher | Unit | Human | `shadow_ambusher` |
| Ancient Wyrm | Unit | Dragon | `shadow_ancient_wyrm` |
| Assassin's Mark | Spell | Martial | `shadow_assassins_mark` |
| Backstab | Spell | Martial | `shadow_backstab` |
| Bloody Work | Spell | Martial | `shadow_bloody_work` |
| Cellar Adder | Unit | Beast | `shadow_adder` |
| Cutthroat | Unit | Human | `shadow_cutthroat` |
| Duskblade | Unit | Human | `shadow_duskblade` |
| Envenomed Blade | Spell | Alchemy | `shadow_envenom_blade` |
| Footpad | Unit | Human | `shadow_footpad` |
| Gloom Lurker | Unit | Undead | `shadow_lurker` |
| Hollow Watcher | Unit | Human | `shadow_hollow_watcher` |
| Knife Thrower | Unit | Human | `shadow_knife_thrower` |
| Last Light | Spell | Shadow | `shadow_last_light` |
| Night Stalker | Unit | Beast | `shadow_night_stalker` |
| Poisoner | Unit | Human | `shadow_poisoner` |
| Quick Step | Spell | Martial | `shadow_quick_step` |
| Smoke Bomb | Spell | Alchemy | `shadow_smoke_bomb` |
| Spiderling | Unit | Beast | `shadow_spiderling` |
| The Night Queen | Unit | Human | `shadow_night_queen` |
| Toxic Cloud | Spell | Alchemy | `shadow_toxic_cloud` |
| Tunnel Widow | Unit | Beast | `shadow_widow` |
| Veil | Spell | Shadow | `shadow_veil` |
| Venom Dart | Spell | Alchemy | `shadow_venom_dart` |

### Neutral

| Card | Type | Tribe / school | Record |
| --- | --- | --- | --- |
| Appraisal Clerk | Unit | Human | `neutral_appraisal_clerk` |
| Banner Captain | Unit | Human | `neutral_banner_captain` |
| Battle Plan | Spell | Martial | `neutral_battle_plan` |
| Blood Tick | Unit | Beast | `neutral_blood_tick` |
| Bulwark Smith | Unit | Human | `neutral_bulwark_smith` |
| Burrow Burst | Spell | Nature | `neutral_burrow_burst` |
| Burrow Guide | Unit | Human | `neutral_burrow_guide` |
| Burrow Lookout | Unit | Beast | `neutral_burrow_lookout` |
| Burrow Pup | Unit | Beast | `neutral_burrow_pup` |
| Burrow Shepherd | Unit | Human | `neutral_burrow_shepherd` |
| Cache Keeper | Unit | Human | `neutral_cache_keeper` |
| Cellar Guard | Unit | Human | `neutral_cellar_guard` |
| Charging Boar | Unit | Beast | `neutral_charging_boar` |
| Crypt Brute | Unit | Undead | `neutral_crypt_brute` |
| Cutpurse | Unit | Human | `neutral_cutpurse` |
| Den Guardian | Unit | Beast | `neutral_den_guardian` |
| Den Herbalist | Unit | Human | `neutral_den_herbalist` |
| Den Marshal | Unit | Human | `neutral_den_marshal` |
| Den Nurse | Unit | Human | `neutral_den_nurse` |
| Den Runner | Unit | Beast | `neutral_den_runner` |
| Den Shield | Unit | Human | `neutral_den_shield` |
| Dungeon Delver | Unit | Human | `neutral_dungeon_delver` |
| Dungeon Warden | Unit | Human | `neutral_dungeon_warden` |
| Ember Sprite | Unit | Elemental | `neutral_ember_sprite` |
| Field Medic | Unit | Human | `neutral_field_medic` |
| Field Repairs | Spell | Artifice | `neutral_field_repairs` |
| Foundry Clerk | Unit | Human | `neutral_foundry_clerk` |
| Gate Guardian | Unit | Construct | `neutral_gate_guardian` |
| Gravekeeper | Unit | Human | `neutral_gravekeeper` |
| Great Cleaver | Weapon | — | `neutral_great_cleaver` |
| Greymaw, Den Sovereign | Unit | Beast | `neutral_greymaw` |
| Hedge Wizard | Unit | Human | `neutral_hedge_wizard` |
| Hex Doctor | Unit | Human | `neutral_hex_doctor` |
| Hill Giant | Unit | Giant | `neutral_hill_giant` |
| Hourglass Mage | Unit | Human | `neutral_hourglass_mage` |
| Hush Owl | Unit | Beast | `neutral_hush_owl` |
| Lantern Bearer | Unit | Human | `neutral_lantern_bearer` |
| Mimic | Unit | Aberration | `neutral_mimic` |
| Miner's Pick | Weapon | — | `neutral_miners_pick` |
| Muzzle | Spell | Martial | `neutral_muzzle` |
| Novice Scout | Unit | Human | `neutral_novice_scout` |
| Ogre Porter | Unit | Ogre | `neutral_ogre_porter` |
| Old Lamplighter | Unit | Human | `neutral_old_lamplighter` |
| Orla, Scrap Sovereign | Unit | Human | `neutral_orla` |
| Overrun | Spell | Martial | `neutral_overrun` |
| Pack Banner | Unit | Human | `neutral_pack_banner` |
| Pack Howler | Unit | Beast | `neutral_pack_howler` |
| Pack Hunter | Unit | Beast | `neutral_pack_hunter` |
| Pack Scout | Unit | Beast | `neutral_pack_scout` |
| Pack Surge | Spell | Martial | `neutral_pack_surge` |
| Pack Trainer | Unit | Human | `neutral_pack_trainer` |
| Pit Hound | Unit | Beast | `neutral_pit_hound` |
| Plate Broker | Unit | Human | `neutral_plate_broker` |
| Pocket Parts | Spell | Artifice | `neutral_pocket_parts` |
| Powder Keg | Unit | Construct | `neutral_powder_keg` |
| Rebuild | Spell | Artifice | `neutral_rebuild` |
| Relic Hunter | Unit | Human | `neutral_relic_hunter` |
| Repopulate | Spell | Nature | `neutral_repopulate` |
| Rivet Runner | Unit | Human | `neutral_rivet_runner` |
| Rockfall | Spell | Nature | `neutral_rockfall` |
| Rusty Dagger | Weapon | — | `neutral_rusty_dagger` |
| Salvage Bench | Unit | Construct | `neutral_salvage_bench` |
| Salvage Tinker | Unit | Human | `neutral_salvage_tinker` |
| Scrap Broker | Unit | Human | `neutral_scrap_broker` |
| Scrap Jammer | Unit | Human | `neutral_scrap_jammer` |
| Scrap Smelter | Unit | Human | `neutral_scrap_smelter` |
| Scrap Sorter | Unit | Human | `neutral_scrap_sorter` |
| Second Shift | Spell | Artifice | `neutral_second_shift` |
| Sheep | Unit | Beast | `neutral_sheep` |
| Shield Golem | Unit | Construct | `neutral_shield_golem` |
| Smite or Mend | Spell | Holy | `neutral_smite_or_mend` |
| Smoke Break | Spell | Alchemy | `neutral_smoke_break` |
| Spare Golem | Unit | Construct | `neutral_spare_golem` |
| Spare Shieldwright | Unit | Human | `neutral_spare_shieldwright` |
| Spark Fiend | Unit | Elemental | `neutral_spark_fiend` |
| Stone Sentinel | Unit | Construct | `neutral_stone_sentinel` |
| Storm Harpy | Unit | Harpy | `neutral_storm_harpy` |
| Temple Guard | Unit | Human | `neutral_temple_guard` |
| The Collector | Unit | Human | `neutral_the_collector` |
| The Last Foundry | Spell | Artifice | `neutral_last_foundry` |
| Torch Imp | Unit | Demon | `neutral_torch_imp` |
| Treasure Map | Spell | Martial | `neutral_treasure_map` |
| Tunnel Ambush | Spell | Martial | `neutral_tunnel_ambush` |
| Tunnel Rat | Unit | Beast | `neutral_tunnel_rat` |
| Tunnel Shaman | Unit | Human | `neutral_tunnel_shaman` |
| War Mammoth | Unit | Beast | `neutral_war_mammoth` |
| Wolf Rider | Unit | Human | `neutral_wolf_rider` |
| Workshop Appraiser | Unit | Human | `neutral_workshop_appraiser` |
| Workshop Foreman | Unit | Human | `neutral_workshop_foreman` |

### Boss

| Card | Type | Tribe / school | Record |
| --- | --- | --- | --- |
| Blood Chalice | Spell | Shadow | `boss_blood_chalice` |
| Bog Toad | Unit | Beast | `boss_bog_toad` |
| Bone Shard | Spell | Shadow | `boss_bone_shard` |
| Crown of Thorns | Spell | Nature | `boss_crown_of_thorns` |
| Ember Bolt | Spell | Fire | `boss_ember_bolt` |
| Frostbite | Spell | Frost | `boss_frostbite` |
| Gate Warden | Unit | Human | `boss_gate_warden` |
| Hag Servant | Unit | Human | `boss_hag_servant` |
| Heart Guardian | Unit | Construct | `boss_heart_guardian` |
| Heartbeat | Spell | Shadow | `boss_heartbeat` |
| Hermit Crab | Unit | Beast | `boss_hermit_crab` |
| Hollow Knight | Unit | Undead | `boss_hollow_knight` |
| Iron Gate | Unit | Construct | `boss_iron_gate` |
| Junk Golem | Unit | Construct | `boss_junk_golem` |
| Knife in the Dark | Spell | Martial | `boss_knife_in_the_dark` |
| Lurker | Unit | Undead | `boss_lurker` |
| Mass Rites | Spell | Shadow | `boss_mass_rites` |
| Mirror Golem | Unit | Construct | `boss_mirror_golem` |
| Moss Poultice | Spell | Alchemy | `boss_moss_poultice` |
| Pyre Bomb | Spell | Alchemy / Fire | `boss_pyre_bomb` |
| Rat | Unit | Beast | `boss_rat` |
| Rat Matriarch | Unit | Beast | `boss_rat_matriarch` |
| Rat Pack | Unit | Beast | `boss_rat_pack` |
| Reflection | Spell | Arcane | `boss_reflection` |
| Rot Zombie | Unit | Undead | `boss_rot_zombie` |
| Scrap Plating | Spell | Artifice | `boss_scrap_plating` |
| Signal Torch | Weapon | — | `boss_signal_torch` |
| Sister of Blood | Unit | Human | `boss_sister_of_blood` |
| Soul Bolt | Spell | Shadow | `boss_soul_bolt` |
| Tinder Imp | Unit | Demon | `boss_tinder_imp` |
| Toll Collector | Unit | Human | `boss_toll_collector` |
| Tollgate | Unit | Construct | `boss_tollgate` |
| Witch's Brew | Spell | Alchemy | `boss_witchs_brew` |
