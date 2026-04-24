-- add all drinks even if mods to brew them aren't active
-- (name, desc, has bottle, hunger, thirst, alcoholic)
wine:add_drink("wine", "Wine", true, 2, 5, 1)
wine:add_drink("beer", "Beer", true, 2, 8, 1)
wine:add_drink("rum", "Rum", true, 2, 5, 1)
wine:add_drink("tequila", "Tequila", true, 2, 3, 1)
wine:add_drink("wheat_beer", "Wheat Beer", true, 2, 8, 1)
wine:add_drink("sake", "Sake", true, 2, 3, 1)
wine:add_drink("bourbon", "Bourbon", true, 2, 3, 1)
wine:add_drink("vodka", "Vodka", true, 2, 3, 1)
wine:add_drink("cider", "Cider", true, 2, 6, 1)
wine:add_drink("mead", "Honey-Mead", true, 4, 5, 1)
wine:add_drink("mint", "Mint Julep", true, 4, 3, 1)
wine:add_drink("brandy", "Brandy", true, 3, 4, 1)
wine:add_drink("coffee_liquor", "Coffee Liquor", true, 3, 4, 1)
wine:add_drink("champagne", "Champagne", true, 4, 5, 1)
wine:add_drink("cointreau", "Cointreau", true, 2, 3, 1)
wine:add_drink("margarita", "Margarita", false, 4, 5, 1)
wine:add_drink("kefir", "Kefir", true, 4, 4, 0)
wine:add_drink("sparkling_agave_juice", "Sparkling Agave Juice", true, 2, 4, 0)
wine:add_drink("sparkling_apple_juice", "Sparkling Apple Juice", true, 2, 5, 0)
wine:add_drink("sparkling_carrot_juice", "Sparkling Carrot Juice", true, 3, 4, 0)
wine:add_drink("sparkling_blackberry_juice", "Sparkling Blackberry Juice", true, 2, 4, 0)

-- brandy recipe
core.register_craft({
	type = "cooking",
	cooktime = 15,
	output = "wine:glass_brandy",
	recipe = "wine:glass_wine"
})

-- Raw champagne alias
core.register_alias("wine:glass_champagne_raw", "wine:glass_champagne")

-- quick override to add wine to food group
local def = core.registered_items["wine:glass_wine"]
local grp = table.copy(def.groups) ; grp.food_wine = 1
core.override_item("wine:glass_wine", {groups = grp})

-- quick override to add brandy to food group
def = core.registered_items["wine:glass_brandy"]
grp = table.copy(def.groups) ; grp.food_brandy = 1
core.override_item("wine:glass_brandy", {groups = grp})

-- wine mod adds tequila by default
wine:add_item({
	{
		{"wine:agave_syrup", "wine:blue_agave", "vessels:drinking_glass"},
		"wine:glass_sparkling_agave_juice"
	},
	{"wine:blue_agave", "wine:glass_tequila"}
})

-- default game
if core.get_modpath("default") then

	wine:add_item({
		{"default:apple", "wine:glass_cider"},
		{"default:papyrus", "wine:glass_rum"}
	})
end

-- xdecor
if core.get_modpath("xdecor") then

	wine:add_item({ {"xdecor:honey", "wine:glass_mead"} })
end

-- mobs_animal
if core.get_modpath("mobs_animal")
or core.get_modpath("xanadu") then

	wine:add_item({
		{"mobs:honey", "wine:glass_mead"},
		{{"mobs:glass_milk", "farming:wheat"}, "wine:glass_kefir"}
	})
end

-- farming
if core.get_modpath("farming") then

	wine:add_item({ {"farming:wheat", "wine:glass_wheat_beer"} })

	if farming.mod and (farming.mod == "redo" or farming.mod == "undo") then

		-- mint julep recipe
		core.register_craft({
			output = "wine:glass_mint",
			recipe = {
				{"farming:mint_leaf", "farming:mint_leaf", "farming:mint_leaf"},
				{"wine:glass_bourbon", "farming:sugar", ""}
			}
		})

		wine:add_item({
			{"farming:grapes", "wine:glass_wine"},
			{"farming:barley", "wine:glass_beer"},
			{"farming:rice", "wine:glass_sake"},
			{"farming:corn", "wine:glass_bourbon"},
			{"farming:baked_potato", "wine:glass_vodka"},
			{{"wine:glass_rum", "farming:coffee_beans"}, "wine:glass_coffee_liquor"},
			{{"wine:glass_wine", "farming:sugar"}, "wine:glass_champagne"},
			{
				{"default:apple", "farming:sugar", "vessels:drinking_glass"},
				"wine:glass_sparkling_apple_juice"
			},
			{
				{"farming:carrot", "farming:sugar", "vessels:drinking_glass"},
				"wine:glass_sparkling_carrot_juice"
			},
			{
				{"farming:blackberry 2", "farming:sugar", "vessels:drinking_glass"},
				"wine:glass_sparkling_blackberry_juice"
			}
		})
	end
end

-- x_farming
if core.get_modpath("x_farming") then

	wine:add_item({
		{"x_farming:barley", "wine:glass_beer"},
		{"x_farming:bakedpotato", "wine:glass_vodka"},
		{"x_farming:rice_grains", "wine:glass_sake"},
		{"x_farming:corn", "wine:glass_bourbon"},
		{{"x_farming:bottle_honey"}, "wine:glass_mead"},
		{{"wine:glass_rum", "x_farming:coffee"}, "wine:glass_coffee_liquor"},
		{
			{"x_farming:carrot", "x_farming:sugar", "vessels:drinking_glass"},
			"wine:glass_sparkling_carrot_juice"
		},
	})
end

-- ethereal
if core.get_modpath("ethereal") then

	wine:add_item({ {"ethereal:orange", "wine:glass_cointreau"} })

	-- margarita recipe
	core.register_craft({
		output = "wine:glass_margarita 2",
		recipe = {
			{"wine:glass_cointreau", "wine:glass_tequila", "ethereal:lemon"}
		}
	})
end

-- mineclone2
if core.get_modpath("mcl_core") then

	wine:add_item({
		{"mcl_core:apple", "wine:glass_cider"},
		{"mcl_core:reeds", "wine:glass_rum"},
		{"mcl_farming:wheat_item", "wine:glass_wheat_beer"},
		{"mcl_farming:potato_item_baked", "wine:glass_vodka"},
		{
			{"mcl_core:apple", "mcl_core:sugar", "vessels:drinking_glass"},
			"wine:glass_sparkling_apple_juice"
		},
		{
			{"mcl_farming:carrot_item", "mcl_core:sugar", "vessels:drinking_glass"},
			"wine:glass_sparkling_carrot_juice"
		}
	})
end
