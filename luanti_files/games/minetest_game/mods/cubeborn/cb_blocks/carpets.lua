-- Carpets for woodland mansions: a 1/16 layer of each wool colour with the
-- wool texture; two wool make three carpets, as in Minecraft.
local S = cb_blocks.S

local CARPETS = {
	white = S("White Carpet"), grey = S("Grey Carpet"), dark_grey = S("Dark Grey Carpet"), black = S("Black Carpet"),
	violet = S("Violet Carpet"), blue = S("Blue Carpet"), cyan = S("Cyan Carpet"),
	dark_green = S("Dark Green Carpet"), green = S("Green Carpet"), yellow = S("Yellow Carpet"),
	brown = S("Brown Carpet"), orange = S("Orange Carpet"), red = S("Red Carpet"), magenta = S("Magenta Carpet"),
	pink = S("Pink Carpet"),
}
local sounds = default.node_sound_wool_defaults and default.node_sound_wool_defaults() or default.node_sound_defaults()

for colour, desc in pairs(CARPETS) do
	cb_blocks.node("carpet_" .. colour, {
		description = desc,
		tiles = { "wool_" .. colour .. ".png", },
		drawtype = "nodebox",
		paramtype = "light",
		sunlight_propagates = true,
		node_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.4375, 0.5, }, },
		groups = { snappy = 2, choppy = 2, oddly_breakable_by_hand = 3, flammable = 3, carpet = 1, attached_node = 1, },
		sounds = sounds,
	})
	if core.registered_items["wool:" .. colour] then
		core.register_craft({ output = "cb_blocks:carpet_" .. colour .. " 3",
			recipe = { { "wool:" .. colour, "wool:" .. colour, }, }, })
	end
end
