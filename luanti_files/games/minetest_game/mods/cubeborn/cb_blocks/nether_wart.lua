-- Nether wart: planted on soul sand, grows through four stages on a node timer.
local S = cb_blocks.S
local node, item, tex = cb_blocks.node, cb_blocks.item, cb_blocks.tex

cb_blocks.WART_GROW = { 40, 80, }
local STAGE_TEX = { "nether_wart_0", "nether_wart_1", "nether_wart_1", "nether_wart_2", }
local SOIL = "cb_blocks:soul_sand"

local function start_timer(pos)
	core.get_node_timer(pos):start(math.random(cb_blocks.WART_GROW[1], cb_blocks.WART_GROW[2]))
end

for stage = 0, 3 do
	local mature = stage == 3
	node("nether_wart_" .. stage, {
		description = S("Nether Wart"),
		drawtype = "plantlike",
		tiles = { tex(STAGE_TEX[stage + 1]), },
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		groups = { snappy = 3, attached_node = 1, not_in_creative_inventory = 1, },
		sounds = default.node_sound_leaves_defaults(),
		selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.5 + (stage + 2) / 8, 0.5, }, },
		drop = mature and {
			max_items = 1,
			items = {
				{ items = { "cb_blocks:nether_wart 4", }, rarity = 3, },
				{ items = { "cb_blocks:nether_wart 3", }, rarity = 2, },
				{ items = { "cb_blocks:nether_wart 2", }, },
			},
		} or "cb_blocks:nether_wart",
		on_construct = not mature and start_timer or nil,
		on_timer = not mature and function(pos)
			if core.get_node(vector.offset(pos, 0, -1, 0)).name ~= SOIL then
				return false
			end
			core.swap_node(pos, { name = "cb_blocks:nether_wart_" .. (stage + 1), })
			if stage + 1 < 3 then
				start_timer(pos)
			end
			return false
		end or nil,
	})
end

item("nether_wart", {
	description = S("Nether Wart"),
	inventory_image = tex("nether_wart_item"),
	on_place = function(itemstack, placer, pointed)
		if pointed.type ~= "node" then
			return itemstack
		end
		local under = core.get_node(pointed.under)
		local udef = core.registered_nodes[under.name]
		if udef and udef.on_rightclick and placer and not placer:get_player_control().sneak then
			return udef.on_rightclick(pointed.under, under, placer, itemstack, pointed)
		end
		if under.name ~= SOIL or pointed.above.y ~= pointed.under.y + 1
				or core.get_node(pointed.above).name ~= "air" then
			return itemstack
		end
		local name = placer and placer:get_player_name() or ""
		if core.is_protected(pointed.above, name) then
			core.record_protection_violation(pointed.above, name)
			return itemstack
		end
		core.set_node(pointed.above, { name = "cb_blocks:nether_wart_0", })
		if not core.is_creative_enabled(name) then
			itemstack:take_item()
		end
		return itemstack
	end,
})

local w, nb = "cb_blocks:nether_wart", "cb_blocks:nether_brick"
core.register_craft({ output = "cb_blocks:nether_wart_block", recipe = { { w, w, w, }, { w, w, w, }, { w, w, w, }, }, })
core.register_craft({ output = "cb_blocks:red_nether_bricks", recipe = { { w, nb, }, { nb, w, }, }, })
