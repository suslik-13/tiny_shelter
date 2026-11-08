-- Ocean blocks (spec cycle 4, 8c): prismarine, prismarine bricks, dark
-- prismarine (with stairs and slabs), sea lantern, prismarine shards and
-- crystals, sponges. A dry sponge placed into or next to water soaks up the
-- water around it (up to 65 nodes within 6, not in protected spots) and turns
-- wet; a wet sponge dries in a furnace.
local S = cb_blocks.S
local node, item, tex = cb_blocks.node, cb_blocks.item, cb_blocks.tex
local stone, glass = default.node_sound_stone_defaults(), default.node_sound_glass_defaults()
local SHARD, CRYSTALS = "cb_blocks:prismarine_shard", "cb_blocks:prismarine_crystals"
local SOAK_RANGE, SOAK_MAX = 6, 65

item("prismarine_shard", { description = S("Prismarine Shard"), inventory_image = tex("prismarine_shard"), })
item("prismarine_crystals", { description = S("Prismarine Crystals"), inventory_image = tex("prismarine_crystals"), })

node("prismarine", {
	description = S("Prismarine"),
	tiles = { { name = tex("prismarine_anim"), animation = { type = "vertical_frames", aspect_w = 32, aspect_h = 32,
		length = 45, }, }, },
	groups = { cracky = 2, },
	sounds = stone,
}, { stairs = { S("Prismarine Stairs"), S("Prismarine Slab"), }, wall = S("Prismarine Wall"), })
node("prismarine_bricks", {
	description = S("Prismarine Bricks"),
	tiles = { tex("prismarine_bricks"), },
	groups = { cracky = 2, },
	sounds = stone,
}, { stairs = { S("Prismarine Brick Stairs"), S("Prismarine Brick Slab"), }, })
node("dark_prismarine", {
	description = S("Dark Prismarine"),
	tiles = { tex("dark_prismarine"), },
	groups = { cracky = 2, },
	sounds = stone,
}, { stairs = { S("Dark Prismarine Stairs"), S("Dark Prismarine Slab"), }, })
node("sea_lantern", {
	description = S("Sea Lantern"),
	tiles = { { name = tex("sea_lantern"), animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16,
		length = 1.25, }, }, },
	paramtype = "light",
	light_source = core.LIGHT_MAX,
	groups = { cracky = 3, oddly_breakable_by_hand = 3, },
	sounds = glass,
	drop = { max_items = 1, items = { { items = { CRYSTALS .. " 3", }, rarity = 2, }, { items = { CRYSTALS .. " 2", }, }, }, },
})

core.register_craft({ output = "cb_blocks:prismarine", recipe = { { SHARD, SHARD, }, { SHARD, SHARD, }, }, })
core.register_craft({ output = "cb_blocks:prismarine_bricks",
	recipe = { { SHARD, SHARD, SHARD, }, { SHARD, SHARD, SHARD, }, { SHARD, SHARD, SHARD, }, }, })
core.register_craft({ output = "cb_blocks:dark_prismarine",
	recipe = { { SHARD, SHARD, SHARD, }, { SHARD, "dye:black", SHARD, }, { SHARD, SHARD, SHARD, }, }, })
core.register_craft({ output = "cb_blocks:sea_lantern",
	recipe = { { SHARD, CRYSTALS, SHARD, }, { CRYSTALS, CRYSTALS, CRYSTALS, }, { SHARD, CRYSTALS, SHARD, }, }, })

-- Soaks up the water around pos (breadth first through water); how much.
function cb_blocks.sponge_soak(pos, who)
	local seen, queue, n = {}, { pos, }, 0
	seen[core.hash_node_position(pos)] = true
	local i = 1
	while queue[i] and n < SOAK_MAX do
		local p = queue[i]
		i = i + 1
		for _, d in ipairs({ { 1, 0, 0, }, { -1, 0, 0, }, { 0, 1, 0, }, { 0, -1, 0, }, { 0, 0, 1, }, { 0, 0, -1, }, }) do
			local q = vector.offset(p, d[1], d[2], d[3])
			local h = core.hash_node_position(q)
			if not seen[h] and vector.distance(q, pos) <= SOAK_RANGE then
				seen[h] = true
				if core.get_item_group(core.get_node(q).name, "water") > 0 and not core.is_protected(q, who or "")
						and n < SOAK_MAX then
					core.remove_node(q)
					n = n + 1
					queue[#queue + 1] = q
				end
			end
		end
	end
	return n
end

node("sponge", {
	description = S("Sponge"),
	tiles = { tex("sponge"), },
	groups = { snappy = 3, oddly_breakable_by_hand = 3, flammable = 1, },
	sounds = default.node_sound_leaves_defaults(),
	after_place_node = function(pos, placer)
		if cb_blocks.sponge_soak(pos, placer and placer:get_player_name()) > 0 then
			core.swap_node(pos, { name = "cb_blocks:wet_sponge", })
		end
	end,
})
node("wet_sponge", {
	description = S("Wet Sponge"),
	tiles = { tex("wet_sponge"), },
	groups = { snappy = 3, oddly_breakable_by_hand = 3, },
	sounds = default.node_sound_leaves_defaults(),
})
core.register_craft({ type = "cooking", output = "cb_blocks:sponge", recipe = "cb_blocks:wet_sponge", })
