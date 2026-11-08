-- Nether stone family: netherrack, glowstone, ores, quartz, magma, soul sand and
-- soil, basalt, blackstone, nether bricks, ancient debris and netherite.
local S = cb_blocks.S
local node, item, tex = cb_blocks.node, cb_blocks.item, cb_blocks.tex
local E = cb_core.equiv
local stone = default.node_sound_stone_defaults()

cb_core.register_equiv("netherrack", { "nether:rack", "cb_blocks:netherrack", })
cb_core.register_equiv("glowstone", { "nether:glowstone", "cb_blocks:glowstone", })
cb_core.register_equiv("basalt", { "nether:basalt", "cb_blocks:basalt", })
cb_core.register_equiv("nether_brick", { "nether:brick", "cb_blocks:nether_bricks", })
cb_core.register_equiv("cracked_nether_brick", { "nether:brick_cracked", "cb_blocks:cracked_nether_bricks", })
cb_core.register_equiv("nether_brick_fence", { "nether:fence_nether_brick", "cb_blocks:nether_brick_fence", })

local function pillar(def)
	def.paramtype2 = "facedir"
	def.on_place = core.rotate_node
	return def
end

local function cooking(output, recipe)
	core.register_craft({ type = "cooking", output = output, recipe = recipe, })
end

node("netherrack", {
	description = S("Netherrack"),
	tiles = { tex("netherrack"), },
	groups = { cracky = 3, },
	sounds = stone,
}, { equiv = "netherrack", natural = true, })

if node("glowstone", {
	description = S("Glowstone"),
	tiles = { tex("glowstone"), },
	paramtype = "light",
	light_source = core.LIGHT_MAX,
	groups = { cracky = 3, oddly_breakable_by_hand = 3, },
	sounds = default.node_sound_glass_defaults(),
	drop = {
		max_items = 1,
		items = {
			{ items = { "cb_blocks:glowstone_dust 4", }, rarity = 3, },
			{ items = { "cb_blocks:glowstone_dust 3", }, rarity = 2, },
			{ items = { "cb_blocks:glowstone_dust 2", }, },
		},
	},
}, { equiv = "glowstone", natural = true, }) then
	item("glowstone_dust", { description = S("Glowstone Dust"), inventory_image = tex("glowstone_dust"), })
	local d = "cb_blocks:glowstone_dust"
	core.register_craft({ output = "cb_blocks:glowstone", recipe = { { d, d, }, { d, d, }, }, })
end

node("quartz_ore", {
	description = S("Nether Quartz Ore"),
	tiles = { tex("quartz_ore"), },
	groups = { cracky = 2, },
	sounds = stone,
	drop = "cb_blocks:quartz",
}, { natural = true, })

node("nether_gold_ore", {
	description = S("Nether Gold Ore"),
	tiles = { tex("nether_gold_ore"), },
	groups = { cracky = 2, },
	sounds = stone,
	drop = { max_items = 1, items = { { items = { "default:gold_lump", }, rarity = 2, }, }, },
}, { natural = true, })

item("quartz", { description = S("Nether Quartz"), inventory_image = tex("quartz"), })

local q = "cb_blocks:quartz"
node("quartz_block", {
	description = S("Block of Quartz"),
	tiles = { tex("quartz_block_top"), tex("quartz_block_bottom"), tex("quartz_block_side"), },
	groups = { cracky = 2, },
	sounds = stone,
}, { stairs = { S("Quartz Stairs"), S("Quartz Slab"), }, })
core.register_craft({ output = "cb_blocks:quartz_block", recipe = { { q, q, }, { q, q, }, }, })

node("chiseled_quartz_block", {
	description = S("Chiseled Quartz Block"),
	tiles = { tex("quartz_chiseled_top"), tex("quartz_chiseled_top"), tex("quartz_chiseled_side"), },
	groups = { cracky = 2, },
	sounds = stone,
})
local qs = "stairs:slab_cb_quartz_block"
core.register_craft({ output = "cb_blocks:chiseled_quartz_block", recipe = { { qs, }, { qs, }, }, })

node("quartz_pillar", pillar({
	description = S("Quartz Pillar"),
	tiles = { tex("quartz_pillar_top"), tex("quartz_pillar_top"), tex("quartz_pillar_side"), },
	groups = { cracky = 2, },
	sounds = stone,
}))
local qb = "cb_blocks:quartz_block"
core.register_craft({ output = "cb_blocks:quartz_pillar 2", recipe = { { qb, }, { qb, }, }, })

node("quartz_bricks", {
	description = S("Quartz Bricks"),
	tiles = { tex("quartz_bricks"), },
	groups = { cracky = 2, },
	sounds = stone,
})
core.register_craft({ output = "cb_blocks:quartz_bricks 4", recipe = { { qb, qb, }, { qb, qb, }, }, })

node("smooth_quartz", {
	description = S("Smooth Quartz"),
	tiles = { tex("quartz_block_bottom"), },
	groups = { cracky = 2, },
	sounds = stone,
}, { stairs = { S("Smooth Quartz Stairs"), S("Smooth Quartz Slab"), }, })
cooking("cb_blocks:smooth_quartz", qb)

if node("magma", {
	description = S("Magma Block"),
	tiles = { { name = tex("magma"), animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.5, }, }, },
	paramtype = "light",
	light_source = 3,
	groups = { cracky = 2, },
	sounds = stone,
}, { natural = true, }) then
	-- Magma hurts players standing on it unless they sneak (1 HP every 0.5 s).
	function cb_blocks.magma_hurts(player)
		if player:get_player_control().sneak then
			return false
		end
		local under = vector.round(vector.offset(player:get_pos(), 0, -0.2, 0))
		return core.get_node(under).name == "cb_blocks:magma"
	end

	local timer = 0
	core.register_globalstep(function(dtime)
		timer = timer + dtime
		if timer < 0.5 then
			return
		end
		timer = 0
		for _, player in ipairs(core.get_connected_players()) do
			if player:get_hp() > 0 and cb_blocks.magma_hurts(player) then
				player:set_hp(player:get_hp() - 1, { type = "set_hp", cause = "cb_blocks:magma", })
			end
		end
	end)
end

node("soul_sand", {
	description = S("Soul Sand"),
	tiles = { tex("soul_sand"), },
	groups = { crumbly = 3, },
	sounds = default.node_sound_sand_defaults(),
}, { natural = true, })

node("soul_soil", {
	description = S("Soul Soil"),
	tiles = { tex("soul_soil"), },
	groups = { crumbly = 3, },
	sounds = default.node_sound_dirt_defaults(),
}, { natural = true, })

node("basalt", pillar({
	description = S("Basalt"),
	tiles = { tex("basalt_top"), tex("basalt_top"), tex("basalt_side"), },
	groups = { cracky = 2, },
	sounds = stone,
}), { equiv = "basalt", natural = true, })

local ba = E("basalt")
node("polished_basalt", pillar({
	description = S("Polished Basalt"),
	tiles = { tex("polished_basalt_top"), tex("polished_basalt_top"), tex("polished_basalt_side"), },
	groups = { cracky = 2, },
	sounds = stone,
}))
core.register_craft({ output = "cb_blocks:polished_basalt 4", recipe = { { ba, ba, }, { ba, ba, }, }, })

node("smooth_basalt", {
	description = S("Smooth Basalt"),
	tiles = { tex("smooth_basalt"), },
	groups = { cracky = 2, },
	sounds = stone,
})
cooking("cb_blocks:smooth_basalt", ba)

node("blackstone", {
	description = S("Blackstone"),
	tiles = { tex("blackstone_top"), tex("blackstone_top"), tex("blackstone_side"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, { natural = true, stairs = { S("Blackstone Stairs"), S("Blackstone Slab"), }, wall = S("Blackstone Wall"), })
local bs = "cb_blocks:blackstone"

node("polished_blackstone", {
	description = S("Polished Blackstone"),
	tiles = { tex("polished_blackstone"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, { stairs = { S("Polished Blackstone Stairs"), S("Polished Blackstone Slab"), }, })
core.register_craft({ output = "cb_blocks:polished_blackstone 4", recipe = { { bs, bs, }, { bs, bs, }, }, })
local pb = "cb_blocks:polished_blackstone"

node("polished_blackstone_bricks", {
	description = S("Polished Blackstone Bricks"),
	tiles = { tex("polished_blackstone_bricks"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, {
	stairs = { S("Polished Blackstone Brick Stairs"), S("Polished Blackstone Brick Slab"), },
	wall = S("Polished Blackstone Brick Wall"),
})
core.register_craft({ output = "cb_blocks:polished_blackstone_bricks 4", recipe = { { pb, pb, }, { pb, pb, }, }, })

node("cracked_polished_blackstone_bricks", {
	description = S("Cracked Polished Blackstone Bricks"),
	tiles = { tex("cracked_polished_blackstone_bricks"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
})
cooking("cb_blocks:cracked_polished_blackstone_bricks", "cb_blocks:polished_blackstone_bricks")

-- Bastions' gold-flecked blackstone; there are no gold nuggets to drop.
node("gilded_blackstone", {
	description = S("Gilded Blackstone"),
	tiles = { tex("gilded_blackstone"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
})

node("chiseled_polished_blackstone", {
	description = S("Chiseled Polished Blackstone"),
	tiles = { tex("chiseled_polished_blackstone"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
})
local ps = "stairs:slab_cb_polished_blackstone"
core.register_craft({ output = "cb_blocks:chiseled_polished_blackstone", recipe = { { ps, }, { ps, }, }, })

item("nether_brick", { description = S("Nether Brick"), inventory_image = tex("nether_brick"), })
cooking("cb_blocks:nether_brick", E("netherrack"))
local nb = "cb_blocks:nether_brick"

node("nether_bricks", {
	description = S("Nether Bricks"),
	tiles = { tex("nether_bricks"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, {
	equiv = "nether_brick",
	stairs = { S("Nether Brick Stairs"), S("Nether Brick Slab"), },
	wall = S("Nether Brick Wall"),
})
core.register_craft({ output = E("nether_brick"), recipe = { { nb, nb, }, { nb, nb, }, }, })

node("red_nether_bricks", {
	description = S("Red Nether Bricks"),
	tiles = { tex("red_nether_bricks"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, { stairs = { S("Red Nether Brick Stairs"), S("Red Nether Brick Slab"), }, wall = S("Red Nether Brick Wall"), })

node("chiseled_nether_bricks", {
	description = S("Chiseled Nether Bricks"),
	tiles = { tex("chiseled_nether_bricks"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
})
if core.registered_nodes["stairs:slab_cb_nether_bricks"] then
	local ns = "stairs:slab_cb_nether_bricks"
	core.register_craft({ output = "cb_blocks:chiseled_nether_bricks", recipe = { { ns, }, { ns, }, }, })
end

node("cracked_nether_bricks", {
	description = S("Cracked Nether Bricks"),
	tiles = { tex("cracked_nether_bricks"), },
	groups = { cracky = 2, stone = 1, },
	sounds = stone,
}, { equiv = "cracked_nether_brick", })
cooking(E("cracked_nether_brick"), E("nether_brick"))

if not cb_core.has_external("nether_brick_fence") then
	default.register_fence("cb_blocks:nether_brick_fence", {
		description = S("Nether Brick Fence"),
		texture = tex("nether_bricks"),
		material = E("nether_brick"),
		groups = { cracky = 2, },
		sounds = stone,
	})
	cb_blocks.registered["cb_blocks:nether_brick_fence"] = true
end

node("ancient_debris", {
	description = S("Ancient Debris"),
	tiles = { tex("ancient_debris_top"), tex("ancient_debris_top"), tex("ancient_debris_side"), },
	groups = { cracky = 1, level = 3, },
	sounds = stone,
	on_blast = function()
	end,
}, { natural = true, })

item("netherite_scrap", { description = S("Netherite Scrap"), inventory_image = tex("netherite_scrap"), })
item("netherite_ingot", { description = S("Netherite Ingot"), inventory_image = tex("netherite_ingot"), })
core.register_craft({ type = "cooking", output = "cb_blocks:netherite_scrap", recipe = "cb_blocks:ancient_debris", cooktime = 10, })
local sc, gi = "cb_blocks:netherite_scrap", "default:gold_ingot"
core.register_craft({ type = "shapeless", output = "cb_blocks:netherite_ingot", recipe = { sc, sc, sc, sc, gi, gi, gi, gi, }, })
