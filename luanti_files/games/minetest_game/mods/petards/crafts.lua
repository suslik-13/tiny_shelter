minetest.register_craft({
	type = "fuel",
	recipe = "petards:confetti_petard_used",
	burntime = 10
})
minetest.register_craft({
	output = "petards:confetti_petard",
	recipe = {
		{"default:paper","default:paper",""},
		{"default:paper","tnt:gunpowder","default:paper"},
		{"","default:paper",(minetest.get_modpath("farming") and "farming:string" or "")}
	}
})
minetest.register_craft({
	output = "petards:petard 4",
	recipe = {{"tnt:tnt_stick"}}
})
minetest.register_craft({
	output = "petards:bengal",
	recipe = {
		{(minetest.get_modpath("basic_materials") and "basic_materials:steel_bar" or "default:steel_ingot")},
		{"tnt:gunpowder"},
	}
})
