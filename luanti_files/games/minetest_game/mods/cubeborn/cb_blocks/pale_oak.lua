-- Pale oak and pale gardens (plan 8f-2): logs, planks with stairs, slabs, a
-- fence and a door, leaves, saplings (they grow into pale oaks), pale moss
-- and its carpet, hanging moss, and resin (from creaking hearts): clumps,
-- blocks, bricks with stairs, slabs and a wall, chiseled resin bricks.
-- Textures from Mineclonia's mcl_pale_oak.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex
local wood, leaves = default.node_sound_wood_defaults(), default.node_sound_leaves_defaults()
local LOG, PLANKS, LEAVES = "cb_blocks:pale_oak_log", "cb_blocks:pale_oak_planks", "cb_blocks:pale_oak_leaves"
local SAPLING, MOSS, HANGING = "cb_blocks:pale_oak_sapling", "cb_blocks:pale_moss", "cb_blocks:pale_hanging_moss"
local CLUMP, RESIN_BRICK = "cb_blocks:resin_clump", "cb_blocks:resin_brick"

node("pale_oak_log", {
	description = S("Pale Oak Log"),
	tiles = { tex("pale_oak_log_top"), tex("pale_oak_log_top"), tex("pale_oak_log"), },
	paramtype2 = "facedir",
	on_place = core.rotate_node,
	groups = { tree = 1, choppy = 2, oddly_breakable_by_hand = 1, flammable = 2, },
	sounds = wood,
})
node("pale_oak_planks", {
	description = S("Pale Oak Planks"),
	tiles = { tex("pale_oak_planks"), },
	groups = { choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1, },
	sounds = wood,
}, { stairs = { S("Pale Oak Stairs"), S("Pale Oak Slab"), }, })
core.register_craft({ output = PLANKS .. " 4", recipe = { { LOG, }, }, })
default.register_fence("cb_blocks:pale_oak_fence", {
	description = S("Pale Oak Fence"),
	texture = tex("pale_oak_planks"),
	material = PLANKS,
	groups = { choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, },
	sounds = wood,
})
cb_blocks.registered["cb_blocks:pale_oak_fence"] = true
if rawget(_G, "doors") then
	doors.register("cb_blocks:pale_oak_door", {
		tiles = { { name = tex("pale_oak_door"), backface_culling = true, }, },
		description = S("Pale Oak Door"),
		inventory_image = tex("pale_oak_door_item"),
		groups = { node = 1, choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, },
		recipe = { { PLANKS, PLANKS, }, { PLANKS, PLANKS, }, { PLANKS, PLANKS, }, },
	})
	cb_blocks.registered["cb_blocks:pale_oak_door"] = true
end

node("pale_oak_leaves", {
	description = S("Pale Oak Leaves"),
	drawtype = "allfaces_optional",
	waving = 1,
	tiles = { tex("pale_oak_leaves"), },
	paramtype = "light",
	groups = { snappy = 3, leafdecay = 3, flammable = 2, leaves = 1, },
	drop = { max_items = 1, items = { { items = { SAPLING, }, rarity = 40, }, { items = { LEAVES, }, }, }, },
	sounds = leaves,
	after_place_node = default.after_place_leaves,
})
default.register_leafdecay({ trunks = { LOG, }, leaves = { LEAVES, }, radius = 4, })

node("pale_hanging_moss", {
	description = S("Pale Hanging Moss"),
	drawtype = "plantlike",
	tiles = { tex("pale_hanging_moss"), },
	inventory_image = tex("pale_hanging_moss"),
	wield_image = tex("pale_hanging_moss"),
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	floodable = true,
	groups = { snappy = 3, flammable = 3, },
	sounds = leaves,
	selection_box = { type = "fixed", fixed = { -0.3, -0.5, -0.3, 0.3, 0.5, 0.3, }, },
})
node("pale_moss", {
	description = S("Pale Moss"),
	tiles = { tex("pale_moss"), },
	groups = { crumbly = 3, soil = 1, flammable = 3, },
	sounds = default.node_sound_dirt_defaults(),
})
local CARPET = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -7 / 16, 0.5, }, }
node("pale_moss_carpet", {
	description = S("Pale Moss Carpet"),
	drawtype = "nodebox",
	node_box = CARPET,
	selection_box = CARPET,
	tiles = { tex("pale_moss"), },
	paramtype = "light",
	sunlight_propagates = true,
	buildable_to = true,
	groups = { snappy = 3, attached_node = 1, flammable = 3, },
	sounds = leaves,
})
core.register_craft({ output = "cb_blocks:pale_moss_carpet 3", recipe = { { MOSS, MOSS, }, }, })

cb_blocks.item("resin_clump", { description = S("Resin Clump"), inventory_image = tex("resin_clump"), })
cb_blocks.item("resin_brick", { description = S("Resin Brick"), inventory_image = tex("resin_brick"), })
core.register_craft({ type = "cooking", output = RESIN_BRICK, recipe = CLUMP, })
node("resin_block", {
	description = S("Block of Resin"),
	tiles = { tex("resin_block"), },
	groups = { oddly_breakable_by_hand = 3, snappy = 3, },
	sounds = default.node_sound_dirt_defaults(),
})
core.register_craft({ output = "cb_blocks:resin_block", recipe = { { CLUMP, CLUMP, CLUMP, }, { CLUMP, CLUMP, CLUMP, },
	{ CLUMP, CLUMP, CLUMP, }, }, })
core.register_craft({ output = CLUMP .. " 9", recipe = { { "cb_blocks:resin_block", }, }, })
node("resin_bricks", {
	description = S("Resin Bricks"),
	tiles = { tex("resin_bricks"), },
	groups = { cracky = 2, },
	sounds = default.node_sound_stone_defaults(),
}, { stairs = { S("Resin Brick Stairs"), S("Resin Brick Slab"), }, wall = S("Resin Brick Wall"), })
core.register_craft({ output = "cb_blocks:resin_bricks", recipe = { { RESIN_BRICK, RESIN_BRICK, }, { RESIN_BRICK, RESIN_BRICK, }, }, })
node("chiseled_resin_bricks", {
	description = S("Chiseled Resin Bricks"),
	tiles = { tex("chiseled_resin_bricks"), },
	groups = { cracky = 2, },
	sounds = default.node_sound_stone_defaults(),
})
core.register_craft({ output = "cb_blocks:chiseled_resin_bricks", recipe = { { "stairs:slab_cb_resin_bricks", },
	{ "stairs:slab_cb_resin_bricks", }, }, })

-- A pale oak at pos (the -x -z corner of its 2x2 trunk): set(p, name) writes,
-- get(p) reads. Leaves and moss go only into air. Returns the trunk height.
function cb_blocks.pale_oak_tree(pos, rand, set, get)
	local h = 6 + rand(0, 3)
	for y = 0, h - 1 do
		for dx = 0, 1 do
			for dz = 0, 1 do
				set(vector.offset(pos, dx, y, dz), LOG)
			end
		end
	end
	local function leaf(p)
		if get(p) == "air" then
			set(p, LEAVES)
			return true
		end
	end
	for dy = -2, 1 do
		local r = dy <= -1 and 3 or 2
		for dx = -r, r + 1 do
			for dz = -r, r + 1 do
				local cx, cz = math.min(math.abs(dx), math.abs(dx - 1)), math.min(math.abs(dz), math.abs(dz - 1))
				if not (cx == r and cz == r) or rand(0, 2) == 0 then
					local p = vector.offset(pos, dx, h + dy, dz)
					if leaf(p) and dy == -2 and rand(1, 6) == 1 then
						for d = 1, rand(1, 3) do
							local m = vector.offset(p, 0, -d, 0)
							if get(m) ~= "air" then
								break
							end
							set(m, HANGING)
						end
					end
				end
			end
		end
	end
	return h
end

-- Saplings grow in 5-10 minutes where there is light and room.
node("pale_oak_sapling", {
	description = S("Pale Oak Sapling"),
	drawtype = "plantlike",
	tiles = { tex("pale_oak_sapling"), },
	inventory_image = tex("pale_oak_sapling"),
	wield_image = tex("pale_oak_sapling"),
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	groups = { snappy = 2, dig_immediate = 3, flammable = 2, attached_node = 1, sapling = 1, },
	sounds = leaves,
	selection_box = { type = "fixed", fixed = { -0.3, -0.5, -0.3, 0.3, 0.35, 0.3, }, },
	on_construct = function(pos)
		core.get_node_timer(pos):start(math.random(300, 600))
	end,
	on_timer = function(pos)
		return not cb_blocks.grow_pale_oak(pos)
	end,
})

-- The sapling at pos becomes a pale oak; false (try later) without light
-- or room.
function cb_blocks.grow_pale_oak(pos)
	if (core.get_node_light(pos) or 0) < 9 then
		return false
	end
	for y = 0, 9 do
		for dx = 0, 1 do
			for dz = 0, 1 do
				local p = vector.offset(pos, dx, y, dz)
				local n = core.get_node(p).name
				if not (n == "air" or (p.x == pos.x and p.y == pos.y and p.z == pos.z)) then
					return false
				end
			end
		end
	end
	cb_blocks.pale_oak_tree(pos, math.random, function(p, name)
		core.set_node(p, { name = name, })
	end, function(p)
		return core.get_node(p).name
	end)
	return true
end
