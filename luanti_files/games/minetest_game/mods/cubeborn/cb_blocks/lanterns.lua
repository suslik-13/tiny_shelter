-- Lanterns, soul lanterns (ancient cities) and chains (bastions; Mineclonia's
-- models). A lantern stands on a block, or hangs when placed against the
-- underside of one.
local S = cb_blocks.S
local node, tex = cb_blocks.node, cb_blocks.tex
local metal = default.node_sound_metal_defaults()
local STEEL = "default:steel_ingot"

local FLOOR_BOX = { type = "fixed", fixed = {
	{ -0.1875, -0.5, -0.1875, 0.1875, -0.0625, 0.1875, }, { -0.125, -0.0625, -0.125, 0.125, 0.0625, 0.125, },
	{ -0.0625, -0.5, -0.0625, 0.0625, 0.1875, 0.0625, },
}, }
local HANGING_BOX = { type = "fixed", fixed = {
	{ -0.1875, 0, -0.1875, 0.1875, 0.4375, 0.1875, }, { -0.125, -0.125, -0.125, 0.125, 0, 0.125, },
	{ -0.0625, -0.5, -0.0625, 0.0625, -0.125, 0.0625, },
}, }

local function lantern(name, desc, kind, light, mesh, box, extra)
	local def = {
		description = desc,
		drawtype = "mesh",
		mesh = mesh,
		tiles = { { name = tex(kind), animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16,
			length = 3.3, }, }, },
		inventory_image = tex(kind .. "_inv"),
		wield_image = tex(kind .. "_inv"),
		use_texture_alpha = "clip",
		paramtype = "light",
		paramtype2 = "wallmounted",
		sunlight_propagates = true,
		light_source = light,
		selection_box = box,
		collision_box = box,
		groups = { cracky = 3, oddly_breakable_by_hand = 2, attached_node = 1, },
		sounds = metal,
		on_rotate = false,
	}
	for k, v in pairs(extra) do
		def[k] = v
	end
	node(name, def)
end

local function lanterns(kind, desc, light)
	local floor, hanging = "cb_blocks:" .. kind, "cb_blocks:" .. kind .. "_hanging"
	lantern(kind, desc, kind, light, "cb_blocks_lantern_floor.obj", FLOOR_BOX, {
		on_place = function(itemstack, placer, pointed)
			if pointed.type ~= "node" then
				return itemstack
			end
			local under = core.get_node(pointed.under)
			local udef = core.registered_nodes[under.name]
			local sneak = placer and placer:is_player() and placer:get_player_control().sneak
			if udef and udef.on_rightclick and not sneak then
				return udef.on_rightclick(pointed.under, under, placer, itemstack, pointed)
			end
			local hang = pointed.under.y > pointed.above.y
			local left = core.item_place_node(ItemStack(hang and hanging or floor), placer, pointed, hang and 0 or 1)
			if left:is_empty() and not core.is_creative_enabled(placer and placer:get_player_name() or "") then
				itemstack:take_item()
			end
			return itemstack
		end,
	})
	lantern(kind .. "_hanging", desc, kind, light, "cb_blocks_lantern_ceiling.obj", HANGING_BOX, {
		drop = floor,
		groups = { cracky = 3, oddly_breakable_by_hand = 2, attached_node = 1, not_in_creative_inventory = 1, },
	})
end
lanterns("lantern", S("Lantern"), core.LIGHT_MAX)
lanterns("soul_lantern", S("Soul Lantern"), 10)

local CHAIN_BOX = { type = "fixed", fixed = { { -0.0625, -0.5, -0.0625, 0.0625, 0.5, 0.0625, }, }, }
node("chain", {
	description = S("Chain"),
	drawtype = "mesh",
	mesh = "cb_blocks_chain.obj",
	tiles = { tex("chain"), },
	inventory_image = tex("chain_inv"),
	wield_image = tex("chain_inv"),
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	selection_box = CHAIN_BOX,
	collision_box = CHAIN_BOX,
	groups = { cracky = 3, },
	sounds = metal,
	on_place = core.rotate_node,
})

core.register_craft({ output = "cb_blocks:chain 3", recipe = { { STEEL, }, { STEEL, }, }, })
core.register_craft({ output = "cb_blocks:lantern", recipe = { { STEEL, }, { "default:torch", }, { STEEL, }, }, })
-- Bedrock's soul torch is a torch over soul soil; here the soil goes under the lantern.
for _, soul in ipairs({ "cb_blocks:soul_soil", "cb_blocks:soul_sand", }) do
	core.register_craft({ output = "cb_blocks:soul_lantern",
		recipe = { { STEEL, }, { "default:torch", }, { soul, }, }, })
end
