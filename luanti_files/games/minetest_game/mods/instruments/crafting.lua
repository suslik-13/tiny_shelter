minetest.register_craft({
	output = "instruments:fretboard",
	recipe = {
		{"default:tree", "default:tin_ingot"},
		{"default:tree", "default:tin_ingot"},
		{"default:tree", "default:tin_ingot"}
	}
})

minetest.register_craft({
	output = "instruments:tuning_peg 2",
	recipe = {
		{"default:tin_ingot", "default:stick", "default:steel_ingot"}
	}
})

minetest.register_craft({
	output = "instruments:headsheet",
	recipe = {
		{"default:paper", "default:paper", "default:paper"},
		{"farming:string", "farming:string", "farming:string"},
	}
})



minetest.register_craft({
	output = "instruments:banjo_body",
	recipe = {
		{"default:pine_tree", "instruments:headsheet", "default:pine_tree"},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
	}
})

minetest.register_craft({
	output = "instruments:banjo_stock",
	recipe = {
		{"instruments:tuning_peg", "default:steel_ingot", "instruments:tuning_peg"},
		{"instruments:tuning_peg", "default:steel_ingot", "instruments:tuning_peg"},
		{"", "instruments:fretboard", ""}
	}
})

minetest.register_craft({
	output = "instruments:banjo",
	recipe = {
		{"instruments:banjo_stock"},
		{"farming:string"},
		{"instruments:banjo_body"}
	}
})



minetest.register_craft({
	output = "instruments:harmonica_body",
	recipe = {
		{"default:tin_ingot", "default:tin_ingot", "default:tin_ingot"},
		{"default:mese_crystal_fragment", "default:mese_crystal_fragment", "default:mese_crystal_fragment"},
		{"default:tin_ingot", "default:tin_ingot", "default:tin_ingot"},
	}
})

minetest.register_craft({
	output = "instruments:harmonica_casing",
	recipe = {
		{"default:gold_ingot", "default:steel_ingot", "default:gold_ingot"},
		{"", "", ""},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
	}
})

minetest.register_craft({
	output = "instruments:harmonica",
	type = "shapeless",
	recipe = {"instruments:harmonica_body", "instruments:harmonica_casing"}
})



minetest.register_craft({
	output = "instruments:drum",
	recipe = {
		{"default:acacia_tree", "instruments:headsheet", "default:acacia_tree"},
		{"default:acacia_tree", "", "default:acacia_tree"},
		{"default:acacia_tree", "", "default:acacia_tree"},
	}
})

minetest.register_craft({
	output = "instruments:apple_drum",
	recipe = {
		{"default:tree", "instruments:headsheet", "default:tree"},
		{"default:tree", "", "default:tree"},
		{"default:tree", "", "default:tree"},
	}
})

minetest.register_craft({
	output = "instruments:drum_stick",
	recipe = {
		{"default:dry_shrub"},
		{"default:stick"}
	}
})



if minetest.get_modpath("moreores") ~= nil then
	minetest.register_craft({
		output = "instruments:silver_pipe",
		recipe = {
			{"moreores:silver_ingot", "moreores:silver_ingot", "moreores:silver_ingot"},
			{"", "", ""},
			{"moreores:silver_ingot", "moreores:silver_ingot", "moreores:silver_ingot"}
		}
	})
	minetest.register_craft({
		output = "instruments:flute_keys 2",
		recipe = {
			{"", "moreores:silver_ingot", "moreores:silver_ingot"},
			{"default:tin_ingot", "", ""}
		}
	})
	minetest.register_craft({
		output = "instruments:embouchure",
		recipe = {
			{"moreores:silver_ingot", "", "moreores:silver_ingot"},
			{"default:steel_ingot", "", "default:steel_ingot"}
		}
	})
else
	minetest.register_craft({
		output = "instruments:silver_pipe",
		recipe = {
			{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
			{"", "", ""},
			{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
		}
	})
	minetest.register_craft({
		output = "instruments:flute_keys 2",
		recipe = {
			{"", "default:steel_ingot", "default:steel_ingot"},
			{"default:tin_ingot", "", ""}
		}
	})
	minetest.register_craft({
		output = "instruments:embouchure",
		recipe = {
			{"default:tin_ingot", "", "default:tin_ingot"},
			{"default:steel_ingot", "", "default:steel_ingot"}
		}
	})
end

minetest.register_craft({
	output = "instruments:flute",
	recipe = {
		{"instruments:embouchure", "instruments:flute_keys", "instruments:flute_keys"},
		{"instruments:silver_pipe", "instruments:silver_pipe", "instruments:silver_pipe"},
		{"", "instruments:flute_keys", "instruments:flute_keys"}
	}
})



minetest.register_craft({
	output = "instruments:untuned_resonator",
	recipe = {
		{"instruments:tuning_peg", "instruments:tuning_peg", "instruments:tuning_peg"},
		{"farming:string", "farming:string", "farming:string"},
		{"default:stick", "default:paper", "default:stick"}
	}
})
