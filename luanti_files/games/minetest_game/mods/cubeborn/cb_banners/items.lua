-- Banner items: one per wool colour of the server, 16 at most; six wool of a
-- colour and a stick make one.
local S, B = cb_banners.S, cb_banners

for colour, c in pairs(B.COLOURS) do
	local wool = "wool:" .. colour
	if core.registered_items[wool] then
		local name = B.item(colour)
		local img = B.item_texture(colour, nil)
		core.register_craftitem(name, {
			description = S("@1 Banner", c[1]),
			inventory_image = img,
			wield_image = img,
			groups = { cb_banner_item = 1, flammable = 2, },
			stack_max = 16,
			_cb_colour = colour,
		})
		core.register_craft({ output = name, recipe = {
			{ wool, wool, wool, },
			{ wool, wool, wool, },
			{ "", "default:stick", "", },
		}, })
	end
end
