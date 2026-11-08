-- Crimson and warped forests: nylium, stems, planks with stairs, slabs, fences
-- and doors, fungi, roots, sprouts, vines, wart blocks and shroomlight.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex
local E = cb_core.equiv
local leaves = default.node_sound_leaves_defaults()
local wood = default.node_sound_wood_defaults()

local function plant(name, desc, height)
	node(name, {
		description = desc,
		drawtype = "plantlike",
		tiles = { tex(name), },
		inventory_image = tex(name),
		wield_image = tex(name),
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		floodable = true,
		groups = { snappy = 3, attached_node = 1, },
		sounds = leaves,
		selection_box = { type = "fixed", fixed = { -5 / 16, -0.5, -5 / 16, 5 / 16, height, 5 / 16, }, },
	}, { natural = true, })
end

local function vine(name, desc)
	node(name, {
		description = desc,
		drawtype = "plantlike",
		tiles = { tex(name), },
		inventory_image = tex(name),
		wield_image = tex(name),
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		climbable = true,
		groups = { snappy = 3, },
		sounds = leaves,
		selection_box = { type = "fixed", fixed = { -0.25, -0.5, -0.25, 0.25, 0.5, 0.25, }, },
	}, { natural = true, })
end

local KINDS = {
	crimson = {
		nylium = S("Crimson Nylium"), stem = S("Crimson Stem"), planks = S("Crimson Planks"),
		stair = S("Crimson Stairs"), slab = S("Crimson Slab"), fence = S("Crimson Fence"),
		door = S("Crimson Door"), fungus = S("Crimson Fungus"), roots = S("Crimson Roots"),
	},
	warped = {
		nylium = S("Warped Nylium"), stem = S("Warped Stem"), planks = S("Warped Planks"),
		stair = S("Warped Stairs"), slab = S("Warped Slab"), fence = S("Warped Fence"),
		door = S("Warped Door"), fungus = S("Warped Fungus"), roots = S("Warped Roots"),
	},
}

for kind, d in pairs(KINDS) do
	node(kind .. "_nylium", {
		description = d.nylium,
		tiles = { tex(kind .. "_nylium_top"), tex("netherrack"), tex("netherrack") .. "^" .. tex(kind .. "_nylium_side"), },
		groups = { cracky = 3, nylium = 1, },
		sounds = default.node_sound_stone_defaults(),
		drop = E("netherrack"),
	}, { natural = true, })

	node(kind .. "_stem", {
		description = d.stem,
		tiles = { tex(kind .. "_stem_top"), tex(kind .. "_stem_top"), tex(kind .. "_stem_side"), },
		paramtype2 = "facedir",
		on_place = core.rotate_node,
		groups = { choppy = 2, oddly_breakable_by_hand = 1, },
		sounds = wood,
	}, { natural = true, })

	local planks = "cb_blocks:" .. kind .. "_planks"
	node(kind .. "_planks", {
		description = d.planks,
		tiles = { tex(kind .. "_planks"), },
		groups = { choppy = 2, oddly_breakable_by_hand = 2, wood = 1, },
		sounds = wood,
	}, { stairs = { d.stair, d.slab, }, })
	core.register_craft({ output = planks .. " 4", recipe = { { "cb_blocks:" .. kind .. "_stem", }, }, })

	default.register_fence("cb_blocks:" .. kind .. "_fence", {
		description = d.fence,
		texture = tex(kind .. "_planks"),
		material = planks,
		groups = { choppy = 2, oddly_breakable_by_hand = 2, },
		sounds = wood,
	})
	cb_blocks.registered["cb_blocks:" .. kind .. "_fence"] = true

	doors.register("cb_blocks:" .. kind .. "_door", {
		tiles = { { name = tex(kind .. "_door"), backface_culling = true, }, },
		description = d.door,
		inventory_image = tex(kind .. "_door_item"),
		groups = { node = 1, choppy = 2, oddly_breakable_by_hand = 2, },
		recipe = { { planks, planks, }, { planks, planks, }, { planks, planks, }, },
	})
	cb_blocks.registered["cb_blocks:" .. kind .. "_door"] = true

	plant(kind .. "_fungus", d.fungus, 0.25)
	plant(kind .. "_roots", d.roots, 0)
end

plant("nether_sprouts", S("Nether Sprouts"), -0.25)
vine("weeping_vines", S("Weeping Vines"))
vine("twisting_vines", S("Twisting Vines"))

node("nether_wart_block", {
	description = S("Nether Wart Block"),
	tiles = { tex("nether_wart_block"), },
	groups = { snappy = 2, oddly_breakable_by_hand = 2, },
	sounds = leaves,
}, { natural = true, })

node("warped_wart_block", {
	description = S("Warped Wart Block"),
	tiles = { tex("warped_wart_block"), },
	groups = { snappy = 2, oddly_breakable_by_hand = 2, },
	sounds = leaves,
}, { natural = true, })

node("shroomlight", {
	description = S("Shroomlight"),
	tiles = { tex("shroomlight"), },
	paramtype = "light",
	light_source = core.LIGHT_MAX,
	groups = { snappy = 2, oddly_breakable_by_hand = 3, },
	sounds = leaves,
}, { natural = true, })
