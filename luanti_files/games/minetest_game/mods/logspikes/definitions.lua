--[[
    Log Spikes — adds log spikes to Minetest
    Copyright © 2021‒2023, Silver Sandstone <@SilverSandstone@craftodon.social>

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
]]


--- Spike definitions.
-- @module definitions


-- MineClone:
logspikes.register_log_spike('logspikes:mcl_oak_spike',                 'mcl_core:tree');
logspikes.register_log_spike('logspikes:mcl_spruce_spike',              'mcl_core:sprucetree');
logspikes.register_log_spike('logspikes:mcl_birch_spike',               'mcl_core:birchtree');
logspikes.register_log_spike('logspikes:mcl_jungle_spike',              'mcl_core:jungletree');
logspikes.register_log_spike('logspikes:mcl_acacia_spike',              'mcl_core:acaciatree');
logspikes.register_log_spike('logspikes:mcl_dark_oak_spike',            'mcl_core:darktree');
logspikes.register_log_spike('logspikes:mcl_warped_spike',              'mcl_crimson:warped_hyphae');
logspikes.register_log_spike('logspikes:mcl_crimson_spike',             'mcl_crimson:crimson_hyphae');
logspikes.register_log_spike('logspikes:mcl_mangrove_spike',            'mcl_mangrove:mangrove_tree');
logspikes.register_log_spike('logspikes:mcl_cherry_spike',              'mcl_cherry_blossom:cherrytree');

logspikes.register_log_spike('logspikes:mcl_oak_spike_stripped',        'mcl_core:stripped_oak');
logspikes.register_log_spike('logspikes:mcl_spruce_spike_stripped',     'mcl_core:stripped_spruce');
logspikes.register_log_spike('logspikes:mcl_birch_spike_stripped',      'mcl_core:stripped_birch');
logspikes.register_log_spike('logspikes:mcl_jungle_spike_stripped',     'mcl_core:stripped_jungle');
logspikes.register_log_spike('logspikes:mcl_acacia_spike_stripped',     'mcl_core:stripped_acacia');
logspikes.register_log_spike('logspikes:mcl_dark_oak_spike_stripped',   'mcl_core:stripped_dark_oak');
logspikes.register_log_spike('logspikes:mcl_crimson_spike_stripped',    'mcl_crimson:stripped_crimson_hyphae');
logspikes.register_log_spike('logspikes:mcl_warped_spike_stripped',     'mcl_crimson:stripped_warped_hyphae');
logspikes.register_log_spike('logspikes:mcl_mangrove_spike_stripped',   'mcl_mangrove:mangrove_stripped_trunk');
logspikes.register_log_spike('logspikes:mcl_cherry_spike_stripped',     'mcl_cherry_blossom:stripped_cherrytree');

-- Rubber Addon for MineClone:
logspikes.register_log_spike('logspikes:mcl_rubber_spike',              'mcl_rubber:rubbertree');
logspikes.register_log_spike('logspikes:mcl_rubber_stripped',           'mcl_rubber:stripped_rubbertree');

-- Repixture:
logspikes.register_log_spike('logspikes:rp_tree_spike',                 'rp_default:tree');
logspikes.register_log_spike('logspikes:rp_oak_spike',                  'rp_default:tree_oak');
logspikes.register_log_spike('logspikes:rp_birch_spike',                'rp_default:tree_birch');

-- KSurvive:
logspikes.register_log_spike('logspikes:ks_holly_spike',                'ks_flora:holly_log');
logspikes.register_log_spike('logspikes:ks_juniper_spike',              'ks_flora:juniper_log');
logspikes.register_log_spike('logspikes:ks_douglasfir_spike',           'ks_flora:douglasfir_log');

-- Exile:
logspikes.register_log_spike('logspikes:exile_kagum_spike',             'nodes_nature:kagum_tree');
logspikes.register_log_spike('logspikes:exile_maraka_spike',            'nodes_nature:maraka_tree');
logspikes.register_log_spike('logspikes:exile_sasaran_spike',           'nodes_nature:sasaran_tree');
logspikes.register_log_spike('logspikes:exile_tangkal_spike',           'nodes_nature:tangkal_tree');

-- Hades Revisited:
logspikes.register_log_spike('logspikes:hades_tree_spike',              'hades_trees:tree');
logspikes.register_log_spike('logspikes:hades_pale_spike',              'hades_trees:pale_tree');
logspikes.register_log_spike('logspikes:hades_birch_spike',             'hades_trees:birch_tree');
logspikes.register_log_spike('logspikes:hades_canvas_spike',            'hades_trees:canvas_tree');
logspikes.register_log_spike('logspikes:hades_jungle_spike',            'hades_trees:jungle_tree');
logspikes.register_log_spike('logspikes:hades_orange_spike',            'hades_trees:orange_tree');
logspikes.register_log_spike('logspikes:hades_charred_spike',           'hades_trees:charred_tree');

-- Lord of the Test:
logspikes.register_log_spike('logspikes:lott_mossy_tree_spike',         'lottblocks:tree_mossy');
logspikes.register_log_spike('logspikes:lott_vine_tree_spike',          'lottblocks:tree_vine');
logspikes.register_log_spike('logspikes:lott_decay_tree_spike',         'lottfarming:decay_tree');
logspikes.register_log_spike('logspikes:lott_alder_spike',              'lottplants:alder_tree');
logspikes.register_log_spike('logspikes:lott_birch_spike',              'lottplants:birch_tree');
logspikes.register_log_spike('logspikes:lott_lebethron_spike',          'lottplants:lebethron_tree');
logspikes.register_log_spike('logspikes:lott_mallorn_spike',            'lottplants:mallorn_tree');
logspikes.register_log_spike('logspikes:lott_pine_spike',               'lottplants:pine_tree');

-- Minetest Game: (This should be the last game to avoid aliases.)
logspikes.register_log_spike('logspikes:default_tree_spike',            'default:tree');
logspikes.register_log_spike('logspikes:default_pine_spike',            'default:pine_tree');
logspikes.register_log_spike('logspikes:default_aspen_spike',           'default:aspen_tree');
logspikes.register_log_spike('logspikes:default_jungle_spike',          'default:jungletree');
logspikes.register_log_spike('logspikes:default_acacia_spike',          'default:acacia_tree');

-- More Trees:
logspikes.register_log_spike('logspikes:moretrees_acacia_spike',        'moretrees:acacia_trunk');
logspikes.register_log_spike('logspikes:moretrees_apple_spike',         'moretrees:apple_tree_trunk');
logspikes.register_log_spike('logspikes:moretrees_beech_spike',         'moretrees:beech_trunk');
logspikes.register_log_spike('logspikes:moretrees_birch_spike',         'moretrees:birch_trunk');
logspikes.register_log_spike('logspikes:moretrees_cedar_spike',         'moretrees:cedar_trunk');
logspikes.register_log_spike('logspikes:moretrees_date_palm_spike',     'moretrees:date_palm_trunk');
logspikes.register_log_spike('logspikes:moretrees_fir_spike',           'moretrees:fir_trunk');
logspikes.register_log_spike('logspikes:moretrees_jungle_spike',        'moretrees:jungletree_trunk');
logspikes.register_log_spike('logspikes:moretrees_oak_spike',           'moretrees:oak_trunk');
logspikes.register_log_spike('logspikes:moretrees_palm_spike',          'moretrees:palm_trunk');
logspikes.register_log_spike('logspikes:moretrees_poplar_spike',        'moretrees:poplar_trunk');
logspikes.register_log_spike('logspikes:moretrees_rubber_spike',        'moretrees:rubber_tree_trunk');
logspikes.register_log_spike('logspikes:moretrees_sequoia_spike',       'moretrees:sequoia_trunk');
logspikes.register_log_spike('logspikes:moretrees_spruce_spike',        'moretrees:spruce_trunk');
logspikes.register_log_spike('logspikes:moretrees_willow_spike',        'moretrees:willow_trunk');

-- Ethereal:
logspikes.register_log_spike('logspikes:ethereal_banana_spike',         'ethereal:banana_trunk');
logspikes.register_log_spike('logspikes:ethereal_frost_spike',          'ethereal:frost_tree');
logspikes.register_log_spike('logspikes:ethereal_mushroom_spike',       'ethereal:mushroom_trunk');
logspikes.register_log_spike('logspikes:ethereal_olive_spike',          'ethereal:olive_trunk');
logspikes.register_log_spike('logspikes:ethereal_palm_spike',           'ethereal:palm_trunk');
logspikes.register_log_spike('logspikes:ethereal_redwood_spike',        'ethereal:redwood_trunk');
logspikes.register_log_spike('logspikes:ethereal_sakura_spike',         'ethereal:sakura_trunk');
logspikes.register_log_spike('logspikes:ethereal_willow_spike',         'ethereal:willow_trunk');
logspikes.register_log_spike('logspikes:ethereal_yellow_spike',         'ethereal:yellow_trunk');

-- DFCaverns:
logspikes.register_log_spike('logspikes:df_giant_fern_spike',           'df_primordial_items:giant_fern_tree');
logspikes.register_log_spike('logspikes:df_glownode_spike',             'df_primordial_items:glownode_stalk');
logspikes.register_log_spike('logspikes:df_jungle_mushroom_spike',      'df_primordial_items:jungle_mushroom_trunk');
logspikes.register_log_spike('logspikes:df_jungle_spike',               'df_primordial_items:jungle_tree');
logspikes.register_log_spike('logspikes:df_glowing_jungle_spike',       'df_primordial_items:jungle_tree_glowing');
logspikes.register_log_spike('logspikes:df_mossy_jungle_spike',         'df_primordial_items:jungle_tree_mossy');
logspikes.register_log_spike('logspikes:df_spore_spike',                'df_trees:spore_tree');

-- Cool Trees:
logspikes.register_log_spike('logspikes:cooltrees_bald_cypress_spike',  'baldcypress:trunk');
logspikes.register_log_spike('logspikes:cooltrees_birch_spike',         'birch:trunk');
logspikes.register_log_spike('logspikes:cooltrees_cacao_spike',         'cacaotree:trunk');
logspikes.register_log_spike('logspikes:cooltrees_cherry_spike',        'cherrytree:trunk');
logspikes.register_log_spike('logspikes:cooltrees_chestnut_spike',      'chestnuttree:trunk');
logspikes.register_log_spike('logspikes:cooltrees_clementine_spike',    'clementinetree:trunk');
logspikes.register_log_spike('logspikes:cooltrees_ebony_spike',         'ebony:trunk');
logspikes.register_log_spike('logspikes:cooltrees_holly_spike',         'hollytree:trunk');
logspikes.register_log_spike('logspikes:cooltrees_jacaranda_spike',     'jacaranda:trunk');
logspikes.register_log_spike('logspikes:cooltrees_larch_spike',         'larch:trunk');
logspikes.register_log_spike('logspikes:cooltrees_lemon_spike',         'lemontree:trunk');
logspikes.register_log_spike('logspikes:cooltrees_mahogany_spike',      'mahogany:trunk');
logspikes.register_log_spike('logspikes:cooltrees_maple_spike',         'maple:trunk');
logspikes.register_log_spike('logspikes:cooltrees_oak_spike',           'oak:trunk');
logspikes.register_log_spike('logspikes:cooltrees_palm_spike',          'palm:trunk');
logspikes.register_log_spike('logspikes:cooltrees_plum_spike',          'plumtree:trunk');
logspikes.register_log_spike('logspikes:cooltrees_pomegranate_spike',   'pomegranate:trunk');
logspikes.register_log_spike('logspikes:cooltrees_sequoia_spike',       'sequoia:trunk');
logspikes.register_log_spike('logspikes:cooltrees_willow_spike',        'willow:trunk');

-- Everness:
logspikes.register_log_spike('logspikes:everness_baobab_spike',         'everness:baobab_tree');
logspikes.register_log_spike('logspikes:everness_crystal_spike',        'everness:crystal_tree');
logspikes.register_log_spike('logspikes:everness_dry_spike',            'everness:dry_tree');
logspikes.register_log_spike('logspikes:everness_mese_spike',           'everness:mese_tree');
logspikes.register_log_spike('logspikes:everness_sequoia_spike',        'everness:sequoia_tree');
logspikes.register_log_spike('logspikes:everness_willow_spike',         'everness:willow_tree');

-- Aotearoa:
logspikes.register_log_spike('logspikes:aotearoa_black_beech_spike',    'aotearoa:black_beech_tree');
logspikes.register_log_spike('logspikes:aotearoa_black_maire_spike',    'aotearoa:black_maire_tree');
logspikes.register_log_spike('logspikes:aotearoa_hinau_spike',          'aotearoa:hinau_tree');
logspikes.register_log_spike('logspikes:aotearoa_kahikatea_spike',      'aotearoa:kahikatea_tree');
logspikes.register_log_spike('logspikes:aotearoa_kamahi_spike',         'aotearoa:kamahi_tree');
logspikes.register_log_spike('logspikes:aotearoa_karaka_spike',         'aotearoa:karaka_tree');
logspikes.register_log_spike('logspikes:aotearoa_kauri_spike',          'aotearoa:kauri_tree');
logspikes.register_log_spike('logspikes:aotearoa_kowhai_spike',         'aotearoa:kowhai_tree');
logspikes.register_log_spike('logspikes:aotearoa_miro_spike',           'aotearoa:miro_tree');
logspikes.register_log_spike('logspikes:aotearoa_mountain_beech_spike', 'aotearoa:mountain_beech_tree');
logspikes.register_log_spike('logspikes:aotearoa_pahautea_spike',       'aotearoa:pahautea_tree');
logspikes.register_log_spike('logspikes:aotearoa_pohutukawa_spike',     'aotearoa:pohutukawa_tree');
logspikes.register_log_spike('logspikes:aotearoa_rimu_spike',           'aotearoa:rimu_tree');
logspikes.register_log_spike('logspikes:aotearoa_silver_beech_spike',   'aotearoa:silver_beech_tree');
logspikes.register_log_spike('logspikes:aotearoa_tawa_spike',           'aotearoa:tawa_tree');
logspikes.register_log_spike('logspikes:aotearoa_totara_spike',         'aotearoa:totara_tree');

-- Wilhelmines Natural Biomes:
logspikes.register_log_spike('logspikes:naturalbiomes_alder_spike',     'naturalbiomes:alder_trunk');
logspikes.register_log_spike('logspikes:naturalbiomes_acacia_spike',    'naturalbiomes:acacia_trunk');
logspikes.register_log_spike('logspikes:naturalbiomes_pine_trunk',      'naturalbiomes:pine_trunk');
logspikes.register_log_spike('logspikes:naturalbiomes_alppine2_spike',  'naturalbiomes:alppine2_trunk');
logspikes.register_log_spike('logspikes:naturalbiomes_palm_spike',      'naturalbiomes:palm_trunk');
logspikes.register_log_spike('logspikes:naturalbiomes_alppine1_spike',  'naturalbiomes:alppine1_trunk');
logspikes.register_log_spike('logspikes:naturalbiomes_olive_spike',     'naturalbiomes:olive_trunk');
logspikes.register_log_spike('logspikes:naturalbiomes_outback_spike',   'naturalbiomes:outback_trunk');

-- Wilhelmines Living Jungle:
logspikes.register_log_spike('logspikes:livingjungle_samauma_spike',    'livingjungle:samauma_trunk');

-- Badland:
logspikes.register_log_spike('logspikes:badland_badland_spike',         'badland:badland_tree');

-- Japanese Forest:
logspikes.register_log_spike('logspikes:japaneseforest_japanese_spike', 'japaneseforest:japanese_tree');

-- Nightshade:
logspikes.register_log_spike('logspikes:nightshade_nightshade_spike',   'nightshade:nightshade_tree');

-- Frost Land:
logspikes.register_log_spike('logspikes:frostland_frost_land_spike',    'frost_land:frost_land_tree');

-- Better Farming:
logspikes.register_log_spike('logspikes:betterfarming_candy_cane_spike','better_farming:candy_cane_block');

-- Conifer:
logspikes.register_log_spike('logspikes:conifer_conifer_spike',         'conifer:tree');

-- Maple:
logspikes.register_log_spike('logspikes:maple_maple_spike',             'maple:maple_tree');

-- Swamp:
logspikes.register_log_spike('logspikes:swamp_mangrove_spike',          'swamp:mangrove_tree');

-- Coconut Trees (AwesomeDragon97):
logspikes.register_log_spike('logspikes:coconuttrees_coconut_spike',    'coconut_trees:coconut_tree');

-- Coconut Trees (Neuromancer):
logspikes.register_log_spike('logspikes:coconuttree_coconut_spike',     'coconut_tree:coconut_tree');
