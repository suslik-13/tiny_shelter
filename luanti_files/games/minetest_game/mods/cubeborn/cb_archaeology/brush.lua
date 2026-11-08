-- Brush (spec cycle 9, 4.1): punching a suspicious block brushes it.
local S = cb_archaeology.S
local A = cb_archaeology
A.BRUSH = "cb_archaeology:brush"

core.register_tool(A.BRUSH, {
	description = S("Brush") .. "\n" .. core.colorize("#aaaaaa", S("Brush suspicious sand and gravel to uncover finds")),
	inventory_image = "cb_archaeology_brush.png",
	groups = { tool = 1, },
	on_use = function(itemstack, user, pointed)
		if not user or pointed.type ~= "node" then
			return itemstack
		end
		if core.is_protected(pointed.under, user:get_player_name()) then
			core.record_protection_violation(pointed.under, user:get_player_name())
			return itemstack
		end
		local dir = vector.subtract(pointed.above, pointed.under)
		A.brush(pointed.under, user, dir)
		return user:get_wielded_item()
	end,
})

core.register_craft({
	output = A.BRUSH,
	recipe = { { "mobs:chicken_feather", }, { "default:copper_ingot", }, { "default:stick", }, },
})
