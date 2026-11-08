-- Cobweb for mineshafts, when the server has none (xdecor has one).
local S = cb_blocks.S

cb_core.register_equiv("cobweb", { "xdecor:cobweb", "cb_blocks:cobweb", })
cb_blocks.node("cobweb", {
	description = S("Cobweb"),
	drawtype = "plantlike",
	tiles = { cb_blocks.tex("cobweb"), },
	inventory_image = cb_blocks.tex("cobweb"),
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	liquid_viscosity = 8,
	liquidtype = "source",
	liquid_alternative_flowing = "cb_blocks:cobweb",
	liquid_alternative_source = "cb_blocks:cobweb",
	liquid_renewable = false,
	liquid_range = 0,
	groups = { snappy = 2, flammable = 3, },
	drop = "farming:string",
}, { equiv = "cobweb", })
