# Credits

Cubeborn ports content from [Mineclonia](https://codeberg.org/mineclonia/mineclonia).

## Textures

| File | Source | Author | License |
|---|---|---|---|
| `cb_dimensions/textures/cb_dimensions_barrier.png` | Mineclonia `mcl_core_bedrock.png` (Pixel Perfection) | XSSheep | CC BY-SA 4.0 |
| `cb_blocks/textures/cb_blocks_*.png`, `cb_core/textures/cb_core_effect_*.png`, `cb_portals/textures/*.png`, `cb_items/textures/*.png`, `cb_archaeology/textures/*.png`, `cb_potions/textures/*.png` (bottles, overlays, ingredients; the turtle shell from secret_terra `st_mobs`), `cb_items/models/cb_items_end_crystal.b3d`, `cb_structures/textures/cb_structures_blaze_spawner.png` | Mineclonia `mcl_nether`, `mcl_blackstone`, `mcl_crimson`, `mcl_portals`, `mcl_end`, `mcl_throwing`, `mcl_mobitems`, `mcl_core`, `mcl_mobspawners`, `mcl_armor`, `mcl_tools` and `mcl_farming` (netherite gear), `mcl_heads`, `mcl_barrels`, `mcl_blast_furnace`, `mcl_cartography_table`, `mcl_cauldrons`, `mcl_composters`, `mcl_fletching_table`, `mcl_grindstone`, `mcl_lectern`, `mcl_loom`, `mcl_brewing` (brewing stand model and textures), `mcl_smithing_table`, `mcl_smoker`, `mcl_stonecutter`, `mcl_potions`, `mcl_totems`, `mcl_compass`, `mcl_sus_nodes`, `mcl_pottery_sherds`, `mcl_armor` (armor trims; raiser, shaper, host from secret_terra `st_items`), `mcl_ocean`, `mcl_sponges`, `mobs_mc` (hero of the village icon) textures (Pixel Perfection; crimson/warped fungus by debiankaios); list and source names in `tools/port_textures.py`; door textures re-laid out for minetest_game | XSSheep, Nova Wostra, debiankaios, Mineclonia contributors | CC BY-SA 4.0 |
| `cb_blocks/textures/cb_blocks_{cracked,mossy}_stone_bricks.png` | minetest_game `default_stone_brick.png`, `default_mossycobble.png`, modified by `tools/make_brick_textures.py` | minetest_game contributors (see its `mods/default/license.txt`) | CC BY-SA 3.0 |
| `cb_blocks/models/cb_blocks_shulker_box.obj` | Mineclonia `mcl_chests_shulker.obj` | Mineclonia contributors | GPLv3 |
| `cb_blocks/models/cb_blocks_dragon_head_*.obj` | Mineclonia `mcl_heads_dragon_*.obj` | Mineclonia contributors | GPLv3 |
| `cb_blocks/models/cb_blocks_lectern.obj` | Mineclonia `mcl_lectern_lectern.obj` | Mineclonia contributors | GPLv3 |
| `cb_blocks/models/cb_blocks_lantern_*.obj`, `cb_blocks_chain.obj`, `textures/cb_blocks_lantern*.png`, `cb_blocks_chain*.png` | Mineclonia `mcl_lanterns` models and textures | AFCMS, Mineclonia contributors | CC BY-SA 3.0 (models), CC BY-SA 4.0 (textures) |
| `cb_blocks/sounds/cb_blocks_bell.ogg` | Mineclonia `mcl_bells_bell_stroke.ogg` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_items/textures/cb_items_*_netherite_preview.png` | 3d_armor `3d_armor_*_diamond_preview.png`, darkened by `tools/make_netherite_previews.py` | stu (3d_armor) | CC BY-SA 3.0 |
| `cb_beacon/textures/*.png`, `cb_beacon/models/cb_beacon_beacon.b3d` | Mineclonia `mcl_beacons` (beacon model and texture), `mcl_conduits`, `mcl_core` (emerald block), `mcl_nether` (netherite block), `mcl_mobitems` (heart of the sea), `mcl_beds` (respawn anchor); `mobs_mc` haste and conduit power icons in `cb_core/textures` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_items/textures/cb_items_firework_rocket.png`, `cb_items_fire_charge.png`, `cb_items_gold_nugget.png`, `cb_items_iron_nugget.png` | Mineclonia `mcl_fireworks`, `mcl_fire`, `mcl_core` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_items/textures/cb_items_firework_star*.png`, `cb_items_firework_spark.png`, `cb_items/sounds/cb_items_firework_*.ogg` | Made for Cubeborn (`tools/items/fireworks_art.py`, `tools/sounds/fireworks_sfx.py`, no recordings) | Cubeborn | CC BY-SA 4.0 |
| `cb_items/textures/cb_items_bundle*.png`, `cb_items/sounds/cb_items_bundle_*.ogg` | Secret Terra `st_items` bundle (own art and generated sounds; code ported from it) | Secret Terra | CC BY-SA 4.0 |
| `cb_items/textures/cb_items_lodestone_*.png` | Mineclonia `mcl_compass` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_blocks/models/cb_blocks_campfire.obj`, `cb_blocks/textures/cb_blocks_campfire_*.png`, `cb_blocks_scaffolding_*.png` | Mineclonia `mcl_campfires`, `mcl_bamboo` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_items/sounds/cb_items_disc_*.ogg`, `cb_items/textures/cb_items_disc_*.png` (but cat, stal, ward, 11) | Secret Terra `st_items` discs (music synthesized by `tools/sounds/music.py`, own art) | Secret Terra | CC BY-SA 4.0 |
| `cb_items/textures/cb_items_disc_{cat,stal,ward,11}.png`, `cb_items_jukebox_*.png` | Mineclonia `mcl_jukebox` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_banners/textures/*.png` | Mineclonia `mcl_banners` textures | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_banners/models/cb_banners_banner*.b3d` | Mineclonia `amc_banner*.b3d` | 22i, Sheepy (ellesheepy) | GPLv3 |

Chest loot tables: numbers from Secret Terra's st_world chest loot (Bedrock loot tables), converted by tools/gen_loot.py.

`cb_structures/fortress_pieces.lua`: code ported by tools/port_fortress.py from Mineclonia `mcl_levelgen/fortress_bastion.lua` (GPLv3, Mineclonia contributors).

`cb_structures/mineshaft_pieces.lua`: code ported by tools/port_mineshaft.py from Mineclonia `mcl_levelgen/mineshaft.lua` (GPLv3, Mineclonia contributors).

`cb_structures/desert_temple_pieces.lua`: code ported by tools/port_desert_temple.py from Mineclonia `mcl_levelgen/desert_pyramid.lua` (GPLv3, Mineclonia contributors).

`cb_structures/witch_hut_pieces.lua`: code ported by tools/port_witch_hut.py from Mineclonia `mcl_levelgen/swamp_hut.lua` (GPLv3, Mineclonia contributors).

`cb_structures/stronghold_pieces.lua`: code ported by tools/port_stronghold.py from Mineclonia `mcl_levelgen/stronghold.lua` (GPLv3, Mineclonia contributors).

`cb_structures/village_schems.lua`: schematics ported by tools/port_villages.py from Mineclonia mcl_villages/schematics/new_villages (CC BY-SA 4.0, MysticTempest, Codiac).

`cb_mobs_village/trades.lua`: numbers from Bedrock's villager trade tables (game mechanics data, no assets), converted by tools/gen_trades.py.

`cb_structures/mansion_schems.lua`: woodland mansion schematics ported by tools/port_mansion.py from Mineclonia `mcl_levelgen/schematics` (GPLv3 / CC BY-SA, Mineclonia contributors). `cb_structures/mansion_grid.lua`, `cb_structures/mansion.lua`: code ported from Mineclonia `mcl_levelgen/woodland_mansion.lua` (GPLv3, Mineclonia contributors).

`cb_structures/templates/*.dat`: End city structure templates from Mineclonia `mcl_end/templates`, `jungle_temple.dat`, `igloo_*.dat`, `bastion_*.dat`, `shipwreck_*.dat` and `ocean_ruins_*.dat` from `mcl_levelgen/templates` (GPLv3, Mineclonia contributors). `cb_structures/shipwreck.lua`: placement and loot from Mineclonia `mcl_levelgen/shipwreck.lua`; `cb_structures/ocean_ruin.lua`: cluster, weathering and sand fall from `mcl_levelgen/ocean_ruins.lua`; `cb_structures/schematics/mcl_levelgen_ruined_portal_*.mts` from `mcl_levelgen/schematics` and `cb_structures/ruined_portal.lua`: setups, processors and netherrack spread from `mcl_levelgen/ruined_portal.lua` (GPLv3 / CC BY-SA, Mineclonia contributors). `cb_structures/bastion.lua`: pools, weathering and piglin tables from Mineclonia `mcl_levelgen/fortress_bastion.lua` (GPLv3, Mineclonia contributors). `cb_structures/bastion_builds.lua`: housing unit, hoglin stable and bridge layouts and their Bedrock loot numbers from Secret Terra `st_world/bastion.lua` and `st_world/loot.lua`.

## Mobs (`cb_mobs_dim`)

Ported from Mineclonia `mobs_mc` by `tools/port_textures.py` (list and source names there).

| File | Source | Author | License |
|---|---|---|---|
| `cb_mobs_dim/models/cb_mobs_dim_{blaze,enderman}.b3d` | `mobs_mc_blaze.b3d`, `mobs_mc_enderman.b3d` | 22i | GPLv3 |
| `cb_mobs_dim/textures/cb_mobs_dim_blaze.png` | `mobs_mc_blaze.png` (Pixel Perfection) | XSSheep | CC BY-SA 4.0 |
| `cb_mobs_dim/textures/cb_mobs_dim_enderman.png`, `cb_mobs_dim_enderman_eyes.png` | `mobs_mc_enderman*.png` (Pixel Perfection, modified) | XSSheep, MysticTempest | CC BY-SA 4.0 |
| `cb_mobs_dim/textures/cb_mobs_dim_fireball.png` | `mcl_fire_fire_charge.png` (Pixel Perfection) | XSSheep | CC BY-SA 4.0 |
| `cb_mobs_dim/sounds/cb_mobs_dim_blaze_breath.ogg`, `cb_mobs_dim_blaze_died.ogg` | `mobs_mc_blaze_*.ogg` | daufinsyd | MIT |
| `cb_mobs_dim/sounds/cb_mobs_dim_blaze_hurt.ogg` | `mobs_mc_blaze_hurt.ogg` ([source](https://freesound.org/people/thefilmbakery/sounds/137836/)) | thefilmbakery | CC0 |
| `cb_mobs_dim/sounds/cb_mobs_dim_enderman_death.ogg`, `cb_mobs_dim_enderman_hurt.*.ogg` | `mobs_mc_enderman_*.ogg` ([source](https://freesound.org/people/griffinjennings/sounds/463972/), modified) | griffinjennings | CC BY 3.0 |
| `cb_mobs_dim/sounds/cb_mobs_dim_enderman_random.1.ogg` | `mobs_mc_enderman_random.1.ogg` ([source](https://freesound.org/people/Soundscapes55/sounds/434973/)) | Soundscapes55 | CC0 |
| `cb_mobs_dim/sounds/cb_mobs_dim_enderman_teleport_*.ogg` | `mobs_mc_enderman_teleport_*.ogg` ([source](https://opengameart.org/content/80-cc0-creature-sfx)) | rubberduck | CC0 |
| `cb_mobs_dim/models/cb_mobs_dim_dragon.b3d` | `mobs_mc_dragon.b3d` | 22i | GPLv3 |
| `cb_mobs_dim/textures/cb_mobs_dim_dragon.png`, `cb_mobs_dim_dragon_breath.png` | `mobs_mc_dragon.png`, `mcl_particles_dragon_breath_1.png` (Pixel Perfection) | XSSheep | CC BY-SA 4.0 |
| `cb_mobs_dim/sounds/cb_mobs_dim_ender_dragon_attack.ogg`, `cb_mobs_dim_ender_dragon_shoot.ogg` | `mobs_mc_ender_dragon_*.ogg` | NPXcoot | CC BY-SA 4.0 |
| `cb_mobs_dim/models/cb_mobs_dim_shulker.b3d`, `cb_mobs_dim_shulker_bullet.b3d` | `mobs_mc_shulker.b3d`, `mobs_mc_shulkerbullet.b3d` | 22i | GPLv3 |
| `cb_mobs_dim/textures/cb_mobs_dim_shulker_bullet.png`, `cb_blocks/textures/cb_blocks_shulker_*.png` | `mobs_mc_shulkerbullet.png`, `mobs_mc_shulker_*.png` (Pixel Perfection) | XSSheep | CC BY-SA 4.0 |

## Mobs (`cb_mobs_village`)

Ported from Mineclonia `mobs_mc` by `tools/port_textures.py` (list and source names there).

| File | Source | Author | License |
|---|---|---|---|
| `cb_mobs_village/models/*.b3d` | `mobs_mc_villager.b3d`, `mobs_mc_villager_zombie.b3d`, `mobs_mc_iron_golem.b3d`, `mobs_mc_spider.b3d`, `mobs_mc_witch.b3d` | 22i, Mineclonia contributors | GPLv3 |
| `cb_mobs_village/textures/*.png` | `mobs_mc_villager_*.png`, `mobs_mc_zombie_villager_*.png`, `mobs_mc_iron_golem.png`, `mobs_mc_cave_spider.png`, `mobs_mc_spider_eyes.png`, `mobs_mc_witch.png`, `mobs_mc_villager_profession_*.png`, `mcl_potions_splash_bottle.png` (Pixel Perfection) | XSSheep, Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_village/sounds/cb_mobs_village_villager*.ogg` (not `_death`), `cb_mobs_village_iron_golem_hurt.ogg`, `cb_mobs_village_spider_*.ogg` | `mobs_mc_villager*.ogg`, `mobs_mc_iron_golem_hurt.ogg`, `mobs_mc_spider_*.ogg` | Mineclonia contributors (see mobs_mc credits) | CC BY-SA 4.0 / CC0 as listed there |

## Mobs (`cb_mobs_illager`)

Ported from Mineclonia `mobs_mc` by `tools/port_textures.py` (list and source names there).

| File | Source | Author | License |
|---|---|---|---|
| `cb_mobs_illager/models/*.b3d` | `mobs_mc_{pillager,vindicator,evoker,vex,evoker_fangs,ravager}.b3d` | Mineclonia contributors | GPLv3 |
| `cb_mobs_illager/textures/*.png` | `mobs_mc_{pillager,vindicator,evoker,vex,evoker_fangs,ravager}.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_illager/sounds/cb_mobs_illager_pillager_*.ogg`, `cb_mobs_illager_vex_hurt.ogg`, `cb_mobs_illager_vex_death.ogg` | `mobs_mc_pillager_*.ogg`, `mobs_mc_vex_*.ogg` | Mineclonia contributors (see mobs_mc credits) | CC BY-SA 4.0 / CC0 as listed there |

## Wandering trader and llamas (`cb_mobs_trader`)

| File | Source | Author | License |
|---|---|---|---|
| `cb_mobs_trader/models/cb_mobs_trader_llama.b3d` | `mobs_mc_llama.b3d` | Mineclonia contributors | GPLv3 |
| `cb_mobs_trader/textures/*.png` | `mobs_mc_villager_wandering_trader.png`, `mobs_mc_llama_{brown,creamy,gray,white}.png`, `mobs_mc_llama_decor_wandering_trader.png`, `mobs_mc_llama_decor_<colour>.png`, `mobs_mc_llama_spit.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_trader/sounds/cb_mobs_trader_llama.ogg` | `mobs_mc_llama.ogg` | Mineclonia contributors (see mobs_mc credits) | CC BY-SA 4.0 / CC0 as listed there |

Workstations: composter logic after Mineclonia `mcl_composters` (kabou, GPLv3); the smoker and blast furnace timer after minetest_game `default/furnace.lua` (LGPL 2.1).

Banners: `cb_banners` code after Mineclonia `mcl_banners`, `mcl_loom` and `mcl_raids` (GPLv3, Mineclonia contributors).

## cb_mobs_overworld

| File | Source | Author | License |
|---|---|---|---|
| `cb_mobs_overworld/models/cb_mobs_overworld_zombie.b3d`, `textures/cb_mobs_overworld_zombie.png`, `cb_mobs_overworld_husk.png` | Mineclonia `mobs_mc_zombie.b3d`, `mobs_mc_zombie.png`, `mobs_mc_husk.png` | Mineclonia contributors (zombie texture by MysticTempest) | CC BY-SA 4.0 |
| `cb_mobs_overworld/sounds/cb_mobs_overworld_zombie_growl.ogg` | `mobs_mc_zombie_growl.ogg` ([source](https://freesound.org/people/Under7dude/sounds/163445/)) | Under7dude | CC0 |
| `cb_mobs_overworld/sounds/cb_mobs_overworld_zombie_hurt.ogg`, `_death.ogg` | `mobs_mc_zombie_*.ogg` ([source](https://freesound.org/people/haratman/sounds/393749/)) | haratman | CC0 |
| `cb_mobs_illager/models/cb_mobs_illager_arrow.b3d`, `textures/cb_mobs_illager_arrow.png` | Mineclonia `mcl_bows_arrow.b3d`, `mcl_bows_arrow.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_overworld/models/cb_mobs_overworld_creeper.b3d`, `textures/cb_mobs_overworld_creeper*.png` | Mineclonia `mobs_mc_creeper.b3d`, `mobs_mc_creeper*.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_overworld/sounds/cb_mobs_overworld_creeper_death.ogg` | `mobs_mc_creeper_death.ogg` ([source](https://freesound.org/people/j1987/sounds/111325)) | j1987 | CC0 |
| `cb_mobs_overworld/sounds/cb_mobs_overworld_creeper_hurt.ogg` | `mobs_mc_creeper_hurt.ogg` ([source](https://opengameart.org/content/simple-fuse-sound)) | themightyglider | CC0 |
| `cb_mobs_overworld/models/cb_mobs_overworld_skeleton.b3d`, `textures/cb_mobs_overworld_stray*.png`, `cb_mobs_overworld_arrow.png` | Mineclonia `mobs_mc_skeleton.b3d`, `mobs_mc_stray*.png`, `mcl_bows_arrow_inv.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_overworld/sounds/cb_mobs_overworld_skeleton_random.*.ogg` | `mobs_mc_skeleton_random.*.ogg` ([source](https://opengameart.org/content/walking-skeleton)) | Baŝto (remix), kantouth | CC BY 3.0 |
| `cb_mobs_overworld/sounds/cb_mobs_overworld_skeleton_death.ogg` | `mobs_mc_skeleton_death.ogg` ([source](https://freesound.org/people/spookymodem/sounds/202091/)) | spookymodem | CC0 |
| `cb_mobs_overworld/sounds/cb_mobs_overworld_skeleton_hurt.ogg` | `mobs_mc_skeleton_hurt.ogg` ([source](https://freesound.org/people/Cribbler/sounds/381859/)) | Cribbler | CC0 |
| `cb_mobs_overworld/models/cb_mobs_overworld_silverfish.b3d`, `_endermite.b3d`, `textures/cb_mobs_overworld_silverfish.png`, `_endermite.png` | Mineclonia `mobs_mc_silverfish.*`, `mobs_mc_endermite.*` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_overworld/sounds/cb_mobs_overworld_silverfish_*.ogg` | `mobs_mc_silverfish_*.ogg` ([source](https://forum.minetest.net/viewtopic.php?f=17&t=10013)) | Inocodum | CC BY-SA 4.0 |
| `cb_mobs_overworld/sounds/cb_mobs_overworld_endermite_*.ogg` | `mobs_mc_endermite_*.ogg` | rubberduck | CC0 |
| `cb_mobs_overworld/models/cb_mobs_overworld_phantom.b3d`, `textures/cb_mobs_overworld_phantom.png`, `sounds/cb_mobs_overworld_phantom_*.ogg`, `cb_items/textures/cb_items_phantom_membrane.png` | Secret Terra `st_mobs` phantom (own model, texture and generated sounds) | Secret Terra | CC BY-SA 4.0 |
| `cb_mobs_overworld/models/cb_mobs_overworld_drowned.b3d`, `textures/cb_mobs_overworld_drowned*.png`, `cb_mobs_overworld_trident.png` | Mineclonia `mobs_mc_drowned.b3d`, `mobs_mc_drowned*.png`, `mcl_tridents_trident_item.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_items/textures/cb_items_rotten_flesh.png`, `cb_core/textures/cb_core_effect_hunger.png` | Mineclonia `mcl_mobitems_rotten_flesh.png`, `mcl_potions_effect_food_poisoning.png` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |

## cb_xp

| File | Source | Author | License |
|---|---|---|---|
| `cb_xp/textures/cb_xp_bar.png`, `cb_xp_bar_bg.png` | Mineclonia `mcl_experience_bar.png`, `mcl_experience_bar_background.png` | Oil_boi, Wuzzy, kay27, Fleckenstein (Mineclonia `mcl_experience`) | GPLv3 |
| `cb_xp/textures/cb_xp_orb.png` | Mineclonia `mcl_experience_orb.png` | Gerold55 (Mineclonia `mcl_experience`) | GPLv3 |

## cb_enchanting

| File | Source | Author | License |
|---|---|---|---|
| `cb_enchanting/data.lua` (enchantment weights, power ranges, compatibility), `cb_enchanting/random.lua` (random rolls) | Mineclonia `mcl_enchanting/enchantments.lua`, `engine.lua`, `mcl_armor/register.lua` | Wuzzy, Fleckenstein, Mineclonia contributors | GPLv3 |
| `cb_enchanting/textures/cb_enchanting_glint.png` | own | Cubeborn | CC BY-SA 4.0 |

## cb_mobs_animals

| File | Source | Author | License |
|---|---|---|---|
| `cb_mobs_animals/models/cb_mobs_animals_pig.b3d`, `textures/cb_mobs_animals_pig*.png` | Mineclonia `mobs_mc_pig.b3d`, `mobs_mc_pig*.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/textures/cb_mobs_animals_carrot_on_a_stick.png` | Mineclonia `mcl_mobitems_carrot_on_a_stick.png` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_pig.ogg`, `_pig_death.ogg` | `mobs_pig.ogg`, `mobs_pig_angry.ogg` (mobs_animal) | TenPlus1 | MIT |
| `cb_mobs_animals/models/cb_mobs_animals_cow.b3d`, `textures/cb_mobs_animals_mooshroom*.png`, `cb_mobs_animals_mushroom_*.png` | Mineclonia `mobs_mc_cow.b3d`, `mobs_mc_mooshroom*.png`, `mobs_mc_mushroom_*.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_cow.ogg` | `mobs_mc_cow.ogg` ([source](https://www.freesound.org/people/Zozzy/sounds/59245/)) | Zozzy | CC0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_cow_hurt.ogg` | `mobs_mc_cow_hurt.ogg` ([source](https://freesound.org/people/Bird_man/packs/16972/)) | Bird_man | CC0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_cow_stew.ogg` | `mobs_mc_cow_mushroom_stew.ogg` ([source](https://freesound.org/people/Hitrison/sounds/251411/)) | Hitrison | CC BY 3.0 |
| `cb_mobs_animals/models/cb_mobs_animals_horse.b3d`, `textures/cb_mobs_animals_donkey.png`, `_mule.png`, `_horse_skeleton.png`, `_horse_zombie.png` | Mineclonia `mobs_mc_horse.b3d`, `mobs_mc_donkey.png`, `mobs_mc_mule.png`, `mobs_mc_horse_skeleton.png`, `mobs_mc_horse_zombie.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_donkey_random.1.ogg`, `_hurt.ogg`, `_death.ogg` | `mobs_mc_donkey_*.ogg` ([source](https://freesound.org/people/Garuda1982/sounds/539505/)) | Garuda1982 | CC BY 3.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_donkey_random.2.ogg` | `mobs_mc_donkey_random.2.ogg` ([source](https://freesound.org/people/JarredGibb/sounds/233131/)) | JarredGibb | CC0 |
| `cb_mobs_animals/models/cb_mobs_animals_wolf.b3d`, `textures/cb_mobs_animals_wolf*.png` | Mineclonia `mobs_mc_wolf.b3d`, `mobs_mc_wolf*.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_wolf_{bark,growl,hurt,death}*.ogg` | `mobs_mc_wolf_*.ogg` (from the "dogblocks" mod, modified) | Hybrid Dog | CC0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_wolf_take_bone.ogg` | `mobs_mc_wolf_take_bone.ogg` ([source](https://freesound.org/people/cliftonmcarlson/sounds/392883/)) | cliftonmcarlson | CC0 |
| `cb_mobs_animals/models/cb_mobs_animals_fox.b3d`, `textures/cb_mobs_animals_fox.png`, `_fox_snow.png` | Secret Terra `st_mobs` fox (own model and textures) | Secret Terra | CC BY-SA 4.0 |
| `cb_mobs_animals/models/cb_mobs_animals_cat.b3d`, `textures/cb_mobs_animals_ocelot.png` | Mineclonia `mobs_mc_cat.b3d`, `mobs_mc_cat_ocelot.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_ocelot_hurt.ogg` | `mobs_mc_ocelot_hurt.ogg` ([source](https://freesound.org/people/ebcrosby/sounds/332979/)) | ebcrosby | CC BY 3.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_cat_idle.1.ogg` | `mobs_mc_cat_idle.1.ogg` (mobs_animal) | TenPlus1 | MIT |
| `cb_mobs_animals/sounds/cb_mobs_animals_cat_idle.2.ogg` | `mobs_mc_cat_idle.2.ogg` ([source](https://freesound.org/people/SelsRoyalNavy/sounds/427081/)) | SelsRoyalNavy | CC0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_cat_hiss.ogg` | `mobs_mc_cat_hiss.ogg` ([source](https://freesound.org/people/cmusounddesign/sounds/71899/)) | cmusounddesign | CC BY 3.0 |
| `cb_mobs_animals/models/cb_mobs_animals_parrot.b3d`, `textures/cb_mobs_animals_parrot_*.png` | Mineclonia `mobs_mc_parrot.b3d`, `mobs_mc_parrot_*.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_parrot_*.ogg` | `mobs_mc_parrot_*.ogg` ([source](https://freesound.org/people/contramundum/sounds/388417/)) | contramundum | as on the source page (Mineclonia states none) |
| `cb_mobs_animals/models/cb_mobs_animals_goat.b3d`, `textures/cb_mobs_animals_goat.png`, `_goat_horn.png`, `sounds/cb_mobs_animals_goat_horn_*.ogg` | Secret Terra `st_mobs` goat and goat horns (own model, textures and sounds) | Secret Terra | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_goat.ogg` | `mobs_sheep.ogg` (mobs_animal) | TenPlus1 | MIT |
| `cb_mobs_animals/models/cb_mobs_animals_frog.b3d`, `_tadpole.b3d`, `textures/cb_mobs_animals_frog*.png`, `_tadpole*.png`, `_*_froglight_*.png`, `sounds/cb_mobs_animals_frog_croak.*.ogg`, `_frog_hurt.ogg` | Secret Terra `st_mobs` frog, tadpole and froglights (own models, textures and sounds) | Secret Terra | CC BY-SA 4.0 |
| `cb_mobs_animals/models/cb_mobs_animals_axolotl.b3d`, `textures/cb_mobs_animals_axolotl_*.png` | Mineclonia `mobs_mc_axolotl.b3d`, `mobs_mc_axolotl_*.png` (mesh and animation by JoeEnderman, textures by Nova Wustra) | JoeEnderman, Nova Wustra | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_axolotl.*.ogg`, `_axolotl_hurt.ogg`, `textures/cb_mobs_animals_axolotl_bucket.png` | Mineclonia `mobs_mc_axolotl*.ogg`, `mcl_buckets` `axolotl_bucket.png` | Mineclonia contributors | as in Mineclonia (not listed in its media licence file) |
| `cb_mobs_animals/models/cb_mobs_animals_polar_bear.b3d`, `textures/cb_mobs_animals_polar_bear.png` | Mineclonia `mobs_mc_polarbear.b3d`, `mobs_mc_polarbear.png` (mesh and animation by toby109tt) | toby109tt, Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_bear_random.*.ogg`, `_bear_growl.*.ogg` | `mobs_mc_bear_random.*.ogg`, `_growl.*.ogg` ([source](https://freesound.org/people/tbsounddesigns/sounds/416853/)) | tbsounddesigns | CC BY 3.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_bear_attack.*.ogg`, `_bear_death.1.ogg`, `_bear_hurt.1.ogg` | `mobs_mc_bear_attack.*.ogg`, `_death`, `_hurt` (modified; [source](https://freesound.org/people/YleArkisto/sounds/249441/)) | YleArkisto | CC BY 3.0 |
| `cb_mobs_animals/models/cb_mobs_animals_camel.b3d`, `textures/cb_mobs_animals_camel.png` | Secret Terra `st_mobs` camel (own model and texture) | Secret Terra | CC BY-SA 4.0 |
| `cb_mobs_animals/models/cb_mobs_animals_sniffer.b3d`, `_copper_golem.b3d`, `_allay.b3d`, `textures/cb_mobs_animals_sniffer*.png`, `_torchflower*.png`, `_pitcher*.png`, `_copper_golem*.png`, `_allay.png`, `sounds/cb_mobs_animals_copper_golem_*.ogg`, `_allay_*.ogg` | Secret Terra `st_mobs` sniffer, ancient plants, copper golem and allay (own models, textures and sounds) | Secret Terra | CC BY-SA 4.0 |
| `cb_mobs_animals/models/cb_mobs_animals_snow_golem.b3d`, `textures/cb_mobs_animals_snow_golem.png` | Mineclonia `mobs_mc_snowman.b3d`, `mobs_mc_snowman.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/textures/cb_mobs_animals_snowball.png` | Mineclonia `mcl_throwing_snowball.png` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_animals/sounds/cb_mobs_animals_snow_golem_hurt.*.ogg`, `_death.*.ogg` | `mobs_mc_snowman_*.ogg` ([kyles](https://freesound.org/people/kyles/sounds/450848/), [alexo400](https://freesound.org/people/alexo400/sounds/543385/), [cabled_mess](https://freesound.org/people/cabled_mess/sounds/384424/)) | kyles, alexo400, cabled_mess | CC0 |
| `cb_mobs_animals/models/cb_mobs_animals_armadillo.b3d`, `textures/cb_mobs_animals_armadillo.png`, `_armadillo_scute.png`, `_wolf_armor.png`, `_wolf_armor_layer.png` | Secret Terra `st_mobs` armadillo and wolf armour (own model and textures) | Secret Terra | CC BY-SA 4.0 |

## cb_mobs_water

| File | Source | Author | License |
|---|---|---|---|
| `cb_mobs_water/models/cb_mobs_water_squid.b3d`, `textures/cb_mobs_water_squid.png`, `_glow_squid.png`, `_ink.png`, `_glow_ink.png`, `_pufferfish*.png`, `models/cb_mobs_water_pufferfish_*.b3d` | Mineclonia `mobs_mc` squid, glow squid and pufferfish | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_water/models/cb_mobs_water_cod.b3d`, `_salmon.b3d`, `_dolphin.b3d`, `textures/cb_mobs_water_cod.png`, `_salmon.png`, `_dolphin.png` | Mineclonia `extra_mobs_*` (epCode's extra_mobs) | epCode, Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_water/textures/cb_mobs_water_ink_sac.png`, `_glow_ink_sac.png`, `_nautilus_shell.png`, `_cod_bucket.png`, `_salmon_bucket.png`, `_pufferfish_bucket.png`, `_pufferfish_item.png` | Mineclonia `mcl_mobitems`, `mcl_fishing` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_water/sounds/cb_mobs_water_squid_hurt.*.ogg`, `_squid_death.1.ogg` | `mobs_mc_squid_*.ogg` (changed; [source](https://opengameart.org/content/slime-monster)) | qubodup | CC BY 3.0 |
| `cb_mobs_water/sounds/cb_mobs_water_fish_flop.*.ogg` | `mobs_mc_squid_flop.*.ogg` ([source](https://freesound.org/people/kyles/sounds/450830/)) | kyles | CC0 |
| `cb_mobs_water/sounds/cb_mobs_water_dolphin_*.ogg` | Mineclonia `mobs_mc_dolphin_*.ogg` | Mineclonia contributors | as in Mineclonia (not listed in its media licence file) |
| `cb_mobs_water/models/cb_mobs_water_nautilus.b3d`, `textures/cb_mobs_water_nautilus.png`, `sounds/cb_mobs_water_nautilus_*.ogg` | Secret Terra `st_mobs` nautilus (own model, texture and sounds) | Secret Terra | CC BY-SA 4.0 |
| `cb_mobs_water/models/cb_mobs_water_guardian.b3d`, `textures/cb_mobs_water_guardian.png`, `_guardian_elder.png`, `cb_core/textures/cb_core_effect_mining_fatigue.png` | Mineclonia `mobs_mc_guardian*`, `mcl_potions_effect_fatigue.png` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_water/sounds/cb_mobs_water_guardian_random.1.ogg` | `mobs_mc_guardian_random.1.ogg` ([source](https://freesound.org/people/pointparkcinema/sounds/407252/)) | pointparkcinema | CC0 |
| `cb_mobs_water/sounds/cb_mobs_water_guardian_random.2.ogg`, `.3.ogg`, `_guardian_hurt.*.ogg` | `mobs_mc_guardian_*.ogg` (modified; [source](https://freesound.org/people/nornalbion/sounds/195733/)) | nornalbion | CC BY 3.0 |
| `cb_mobs_water/sounds/cb_mobs_water_guardian_death.ogg` | `mobs_mc_guardian_death.ogg` | TheBuilder15 | CC0 |
| `cb_structures/ocean_monument_pieces.lua` (code) | Mineclonia `mcl_levelgen/ocean_monument.lua`, ported by `tools/port_ocean_monument.py` | Mineclonia contributors | GPLv3 |
| `cb_core/textures/cb_core_effect_dolphins_grace.png` | Mineclonia `mcl_potions_effect_dolphin_grace.png` | Mineclonia contributors | CC BY-SA 4.0 |

## cb_mobs_nether

| File | Source | Author | License |
|---|---|---|---|
| `cb_mobs_nether/models/*.b3d`, `textures/cb_mobs_nether_magma_cube.png`, `_ghast.png`, `_piglin.png`, `_zombified_piglin.png`, `_hoglin.png`, `_zoglin.png`, `_strider*.png`, `_wither_skeleton.png`, `_piglin_brute.png` | Mineclonia `mobs_mc` (magma cube, ghast, piglin, hoglin, strider, wither skeleton; `extra_mobs_*` by epCode) | Mineclonia contributors, epCode | CC BY-SA 4.0 |
| `cb_mobs_nether/textures/cb_mobs_nether_magma_cream.png`, `_ghast_tear.png`, `_ghast_fireball.png`, `_warped_fungus_on_a_stick.png`, `_wither_skeleton_skull.png`, `cb_core/textures/cb_core_effect_wither.png` | Mineclonia `mcl_mobitems`, `mcl_fire`, `mcl_heads`, `mcl_potions` | Pixel Perfection (XSSheep), Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_nether/models/cb_mobs_nether_wither.b3d` | `mobs_mc_wither.b3d` | 22i | GPLv3 |
| `cb_mobs_nether/textures/cb_mobs_nether_wither*.png` (not `_skeleton*`), `_nether_star.png`, `_wither_skeleton_head.png` | `mobs_mc_wither*.png`, `mcl_mobitems_nether_star.png`, `mcl_heads_wither_skeleton.png` (Pixel Perfection) | XSSheep, Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_nether/models/cb_mobs_nether_head_floor.obj` | Mineclonia `mcl_heads_floor.obj` | Mineclonia contributors | GPLv3 |
| `cb_blocks/textures/cb_blocks_*deepslate*.png`, `_soul_lantern*.png`, `_candle*.png` (wax tinted with Mineclonia's natural candle colour), `_skeleton_head.png`, `_skeleton_skull.png` (cut from the head), `cb_core/textures/cb_core_effect_darkness.png` | Mineclonia `mcl_deepslate`, `mcl_lanterns`, `mcl_candles`, `mcl_heads`, `mobs_mc` (Pixel Perfection) | XSSheep, Mineclonia contributors | CC BY-SA 4.0 |
| `cb_blocks/models/cb_blocks_candle_*.obj`, `cb_blocks_head_floor.obj` | Mineclonia `mcl_candles_candle_lit_*.obj`, `mcl_heads_floor.obj` | Mineclonia contributors | GPLv3 |
| `cb_mobs_deep/textures/cb_mobs_deep_sculk*.png` (not `_active`), `_echo_shard.png` | Mineclonia `mcl_sculk` (Pixel Perfection) | XSSheep, cora, Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_deep/sounds/cb_mobs_deep_sculk_block.ogg` | Mineclonia `mcl_sculk_block.ogg` | cora, Mineclonia contributors | CC BY-SA 3.0 |
| `cb_mobs_deep/textures/cb_mobs_deep_sculk_sensor_*_active.png`, `sounds/cb_mobs_deep_sculk_click.ogg`, `_sculk_shriek.ogg` | Secret Terra `st_mobs` sculk sensor and shrieker (own textures and sounds) | Secret Terra | CC BY-SA 4.0 |
| `cb_structures/ancient_city.lua` (layout) | Secret Terra `st_world/ancient_city.lua` (own layout) | Secret Terra | GPLv3 |
| `cb_mobs_trial/models/cb_mobs_trial_breeze.b3d`, `textures/cb_mobs_trial_breeze.png`, `_bogged*.png`, `sounds/cb_mobs_trial_breeze_*.ogg` | Secret Terra `st_mobs` breeze and bogged (own model, textures and sounds) | Secret Terra | CC BY-SA 4.0 |
| `cb_mobs_trial/models/cb_mobs_trial_creaking.b3d`, `textures/cb_mobs_trial_creaking*.png`, `sounds/cb_mobs_trial_creaking_*.ogg` | Secret Terra `st_mobs` creaking and creaking heart (own model, textures and sounds) | Secret Terra | CC BY-SA 4.0 |
| `cb_blocks/textures/cb_blocks_pale_*.png`, `_resin_*.png`, `_chiseled_resin_bricks.png`, `_pale_oak_door.png` (assembled from the door halves) | Mineclonia `mcl_pale_oak` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_mobs_trial/models/cb_mobs_trial_happy_ghast.b3d`, `textures/cb_mobs_trial_happy_ghast*.png`, `_harness_*.png`, `_dried_ghast_*.png`, `_parched*.png`, `_camel_husk.png`, `sounds/cb_mobs_trial_happy_ghast_*.ogg`, `_ghastling_idle.ogg`, `_dried_ghast_*.ogg`, `_harness_equip.ogg` | Secret Terra `st_mobs` happy ghast, parched and camel husk (own model, textures and sounds) | Secret Terra | CC BY-SA 4.0 |
| `cb_mobs_trial/models/cb_mobs_trial_wind_charge.obj` | Mineclonia `mcl_charges` `wind_charge.obj` | Mineclonia contributors | GPLv3 |
| `cb_mobs_trial/textures/cb_mobs_trial_wind_*.png`, `_breeze_rod.png`, `_spawner_*.png`, `_vault_*.png`, `_trial_key.png`, `_mace.png`, `_heavy_core_*.png`; `cb_blocks/textures/cb_blocks_*tuff*.png`, `cb_blocks_copper_*.png` | Mineclonia `mcl_charges`, `mcl_mobitems`, `mcl_trial_spawners`, `mcl_vaults`, `mcl_tools`, `mcl_deepslate`, `mcl_copper` | Mineclonia contributors | CC BY-SA 4.0 |
| `cb_structures/templates/trial_chambers_*.dat`, `cb_structures/trial_chambers.lua` (pools) | Mineclonia `mcl_levelgen` trial chambers | Mineclonia contributors | GPLv3 |
| `cb_structures/templates/trail_ruins_*.dat`, `cb_structures/trail_ruins.lua` (pools, processors) | Mineclonia `mcl_levelgen` trail ruins | Mineclonia contributors | GPLv3 |
| `cb_mobs_deep/models/cb_mobs_deep_warden.b3d`, `textures/cb_mobs_deep_warden.png`, `sounds/cb_mobs_deep_warden_*.ogg` | Made for Cubeborn: box model and texture from `tools/boxmodel/mobs/warden.py` (Secret Terra's boxmodel tool), sounds synthesized by `tools/sounds/warden_sfx.py` (no recordings) | Cubeborn | CC BY-SA 4.0 |
| `cb_core/textures/cb_core_darkness.png` | Made for Cubeborn (generated vignette) | Cubeborn | CC BY-SA 4.0 |
| `cb_mobs_nether/sounds/cb_mobs_nether_wither_spawn.ogg` | `mobs_mc_wither_spawn.ogg` ([source](https://freesound.org/people/bevibeldesign/sounds/366095/)) | bevibeldesign | CC0 |
| `cb_mobs_nether/sounds/cb_mobs_nether_hoglin*.ogg` | `extra_mobs_hoglin*.ogg` ([source](https://git.minetest.land/epCode/extra_mobs/src/branch/master/sounds)) | epCode | LGPL 3.0 |
| `cb_mobs_nether/sounds/cb_mobs_nether_magma_cube_*.ogg`, `_ghast_*.ogg` (not `_moan`), `_zombiepig_*.ogg`, `_skeleton_*.ogg` | Mineclonia `mobs_mc` sounds of the same names | as listed in Mineclonia's `mobs_mc/LICENSE-media.md` | as there |

## Generated sounds

Made for Cubeborn with `tools/sounds/cb_sfx.py` (procedural synthesis, no recordings), under the
pack's media licence (CC BY-SA 4.0): every other `.ogg` in the pack, i.e. the enderman scream, shulker,
ender dragon growl and death, witch, drinking, zombie villager, iron golem attack and death, villager
death, ravager, crossbow, evoker cast, vex charge, illager death, llama spit/hurt/death, End portal
eye/opening, teleport, raid horn/victory/defeat, Bad Omen, totem, throw, loom, stonecutter, grindstone
and smithing sounds, the zombie door blows, the drowned voice, the creeper fuse, the experience pickup and
level-up, shearing, the armadillo, the fox, the goat's hurt, death and ram, the frog eating, the ghast's moan, the strider.

`cb_archaeology/suspicious.lua`: brushing ported from Mineclonia `mcl_sus_nodes` (GPLv3, Mineclonia contributors); find tables use its numbers.
