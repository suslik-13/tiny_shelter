-- Enchantment data (plan 13a): ported from Mineclonia mcl_enchanting/enchantments.lua and
-- mcl_armor/register.lua (GPLv3); bow, crossbow and trident enchantments and Aqua Affinity left out.
-- primary: classes the table offers it for; secondary: books, the anvil and loot only.
local E = cb_enchanting
E.DEFS = {
	efficiency = { max = 5, weight = 10, primary = { axe = true, hoe = true, pick = true, shovel = true, }, secondary = { shears = true, },
		incompatible = { }, treasure = false, curse = false,
		power = { { 1, 61, }, { 11, 71, }, { 21, 81, }, { 31, 91, }, { 41, 101, }, }, anvil_item = 1, anvil_book = 1, },
	unbreaking = { max = 3, weight = 5, primary = { armor_feet = true, armor_head = true, armor_legs = true, armor_torso = true, axe = true, fishing_rod = true, hoe = true, mace = true, pick = true, shovel = true, sword = true, }, secondary = { flint = true, shears = true, shield = true, },
		incompatible = { }, treasure = false, curse = false,
		power = { { 5, 61, }, { 13, 71, }, { 21, 81, }, }, anvil_item = 2, anvil_book = 1, },
	fortune = { max = 3, weight = 2, primary = { axe = true, hoe = true, pick = true, shovel = true, }, secondary = { },
		incompatible = { silk_touch = true, }, treasure = false, curse = false,
		power = { { 15, 61, }, { 24, 71, }, { 33, 81, }, }, anvil_item = 4, anvil_book = 2, },
	silk_touch = { max = 1, weight = 1, primary = { axe = true, hoe = true, pick = true, shovel = true, }, secondary = { shears = true, },
		incompatible = { fortune = true, }, treasure = false, curse = false,
		power = { { 15, 61, }, }, anvil_item = 8, anvil_book = 4, },
	sharpness = { max = 5, weight = 5, primary = { sword = true, }, secondary = { axe = true, },
		incompatible = { bane_of_arthropods = true, smite = true, }, treasure = false, curse = false,
		power = { { 1, 21, }, { 12, 32, }, { 23, 43, }, { 34, 54, }, { 45, 65, }, }, anvil_item = 1, anvil_book = 1, },
	smite = { max = 5, weight = 5, primary = { mace = true, sword = true, }, secondary = { axe = true, },
		incompatible = { bane_of_arthropods = true, breach = true, density = true, sharpness = true, }, treasure = false, curse = false,
		power = { { 5, 25, }, { 13, 33, }, { 21, 41, }, { 29, 49, }, { 37, 57, }, }, anvil_item = 2, anvil_book = 1, },
	bane_of_arthropods = { max = 5, weight = 5, primary = { mace = true, sword = true, }, secondary = { axe = true, },
		incompatible = { breach = true, density = true, sharpness = true, smite = true, }, treasure = false, curse = false,
		power = { { 5, 25, }, { 13, 33, }, { 21, 41, }, { 29, 49, }, { 37, 57, }, }, anvil_item = 2, anvil_book = 1, },
	knockback = { max = 2, weight = 5, primary = { sword = true, }, secondary = { },
		incompatible = { }, treasure = false, curse = false,
		power = { { 5, 61, }, { 25, 71, }, }, anvil_item = 2, anvil_book = 1, },
	fire_aspect = { max = 2, weight = 2, primary = { mace = true, sword = true, }, secondary = { },
		incompatible = { }, treasure = false, curse = false,
		power = { { 10, 61, }, { 30, 71, }, }, anvil_item = 4, anvil_book = 2, },
	looting = { max = 3, weight = 2, primary = { sword = true, }, secondary = { },
		incompatible = { }, treasure = false, curse = false,
		power = { { 15, 61, }, { 24, 71, }, { 33, 81, }, }, anvil_item = 4, anvil_book = 2, },
	protection = { max = 4, weight = 10, primary = { armor_feet = true, armor_head = true, armor_legs = true, armor_torso = true, }, secondary = { },
		incompatible = { blast_protection = true, fire_protection = true, projectile_protection = true, }, treasure = false, curse = false,
		power = { { 1, 12, }, { 12, 23, }, { 23, 34, }, { 34, 45, }, }, anvil_item = 1, anvil_book = 1, },
	fire_protection = { max = 4, weight = 5, primary = { armor_feet = true, armor_head = true, armor_legs = true, armor_torso = true, }, secondary = { },
		incompatible = { blast_protection = true, projectile_protection = true, protection = true, }, treasure = false, curse = false,
		power = { { 5, 13, }, { 13, 21, }, { 21, 29, }, { 29, 37, }, }, anvil_item = 2, anvil_book = 1, },
	blast_protection = { max = 4, weight = 2, primary = { armor_feet = true, armor_head = true, armor_legs = true, armor_torso = true, }, secondary = { },
		incompatible = { fire_protection = true, projectile_protection = true, protection = true, }, treasure = false, curse = false,
		power = { { 5, 13, }, { 13, 21, }, { 21, 29, }, { 29, 37, }, }, anvil_item = 4, anvil_book = 2, },
	projectile_protection = { max = 4, weight = 5, primary = { armor_feet = true, armor_head = true, armor_legs = true, armor_torso = true, }, secondary = { },
		incompatible = { blast_protection = true, fire_protection = true, protection = true, }, treasure = false, curse = false,
		power = { { 1, 16, }, { 11, 26, }, { 21, 36, }, { 31, 46, }, }, anvil_item = 2, anvil_book = 1, },
	thorns = { max = 3, weight = 1, primary = { armor_torso = true, }, secondary = { armor_feet = true, armor_head = true, armor_legs = true, },
		incompatible = { }, treasure = false, curse = false,
		power = { { 10, 61, }, { 30, 71, }, { 50, 81, }, }, anvil_item = 8, anvil_book = 4, },
	respiration = { max = 3, weight = 2, primary = { armor_head = true, }, secondary = { },
		incompatible = { }, treasure = false, curse = false,
		power = { { 10, 40, }, { 20, 50, }, { 30, 60, }, }, anvil_item = 4, anvil_book = 2, },
	feather_falling = { max = 4, weight = 5, primary = { armor_feet = true, }, secondary = { },
		incompatible = { }, treasure = false, curse = false,
		power = { { 5, 11, }, { 11, 17, }, { 17, 23, }, { 23, 29, }, }, anvil_item = 2, anvil_book = 1, },
	depth_strider = { max = 3, weight = 2, primary = { }, secondary = { armor_feet = true, },
		incompatible = { frost_walker = true, }, treasure = false, curse = false,
		power = { { 10, 25, }, { 20, 35, }, { 30, 45, }, }, anvil_item = 4, anvil_book = 2, },
	frost_walker = { max = 2, weight = 2, primary = { }, secondary = { armor_feet = true, },
		incompatible = { depth_strider = true, }, treasure = true, curse = false,
		power = { { 10, 25, }, { 20, 35, }, }, anvil_item = 4, anvil_book = 2, },
	luck_of_the_sea = { max = 3, weight = 2, primary = { fishing_rod = true, }, secondary = { },
		incompatible = { }, treasure = false, curse = false,
		power = { { 15, 61, }, { 24, 71, }, { 33, 81, }, }, anvil_item = 4, anvil_book = 2, },
	lure = { max = 3, weight = 2, primary = { fishing_rod = true, }, secondary = { },
		incompatible = { }, treasure = false, curse = false,
		power = { { 15, 61, }, { 24, 71, }, { 33, 81, }, }, anvil_item = 4, anvil_book = 2, },
	mending = { max = 1, weight = 2, primary = { }, secondary = { armor_feet = true, armor_head = true, armor_legs = true, armor_torso = true, axe = true, fishing_rod = true, flint = true, hoe = true, mace = true, pick = true, shears = true, shield = true, shovel = true, sword = true, },
		incompatible = { }, treasure = true, curse = false,
		power = { { 25, 75, }, }, anvil_item = 4, anvil_book = 2, },
	curse_of_vanishing = { max = 1, weight = 1, primary = { }, secondary = { armor_feet = true, armor_head = true, armor_legs = true, armor_torso = true, axe = true, fishing_rod = true, flint = true, hoe = true, mace = true, pick = true, shears = true, shield = true, shovel = true, sword = true, },
		incompatible = { }, treasure = true, curse = true,
		power = { { 25, 50, }, }, anvil_item = 8, anvil_book = 4, },
	curse_of_binding = { max = 1, weight = 1, primary = { }, secondary = { armor_feet = true, armor_head = true, armor_legs = true, armor_torso = true, },
		incompatible = { }, treasure = true, curse = true,
		power = { { 25, 50, }, }, anvil_item = 8, anvil_book = 4, },
	density = { max = 5, weight = 2, primary = { mace = true, }, secondary = { },
		incompatible = { bane_of_arthropods = true, breach = true, smite = true, }, treasure = true, curse = false,
		power = { { 10, 25, }, { 20, 35, }, { 30, 45, }, { 40, 55, }, { 50, 65, }, }, anvil_item = 8, anvil_book = 4, },
	breach = { max = 4, weight = 2, primary = { mace = true, }, secondary = { },
		incompatible = { bane_of_arthropods = true, density = true, smite = true, }, treasure = true, curse = false,
		power = { { 10, 25, }, { 20, 35, }, { 30, 45, }, { 40, 55, }, }, anvil_item = 8, anvil_book = 4, },
	wind_burst = { max = 3, weight = 2, primary = { mace = true, }, secondary = { },
		incompatible = { }, treasure = true, curse = false,
		power = { { 10, 25, }, { 20, 35, }, { 30, 45, }, }, anvil_item = 8, anvil_book = 4, },
}

local S = E.S
E.LABELS = {
	efficiency = S("Efficiency"), unbreaking = S("Unbreaking"), fortune = S("Fortune"), silk_touch = S("Silk Touch"),
	sharpness = S("Sharpness"), smite = S("Smite"), bane_of_arthropods = S("Bane of Arthropods"),
	knockback = S("Knockback"), fire_aspect = S("Fire Aspect"), looting = S("Looting"), protection = S("Protection"),
	fire_protection = S("Fire Protection"), blast_protection = S("Blast Protection"),
	projectile_protection = S("Projectile Protection"), thorns = S("Thorns"), respiration = S("Respiration"),
	feather_falling = S("Feather Falling"), depth_strider = S("Depth Strider"), frost_walker = S("Frost Walker"),
	luck_of_the_sea = S("Luck of the Sea"), lure = S("Lure"), mending = S("Mending"),
	curse_of_vanishing = S("Curse of Vanishing"), curse_of_binding = S("Curse of Binding"), density = S("Density"),
	breach = S("Breach"), wind_burst = S("Wind Burst"),
}

-- Minecraft's enchantability by material (the last word of the item name);
-- materials Minecraft has not got are the plan's call.
E.ENCHANTABILITY = {
	wood = 15, stone = 5, steel = 14, bronze = 12, gold = 22, mese = 18, diamond = 10, mithril = 12, crystal = 14,
	netherite = 15, leather = 15, cactus = 5,
}
E.ENCHANTABILITY_DEFAULT = 10

-- Item class by name: exact names first, then the tool word in the name.
E.EXACT_CLASS = {
	["ethereal:fishing_rod"] = "fishing_rod", ["cb_mobs_trial:mace"] = "mace", ["fire:flint_and_steel"] = "flint",
}
E.NAME_CLASS = {
	{ ":pick_", "pick", }, { ":axe_", "axe", }, { ":shovel_", "shovel", }, { ":hoe_", "hoe", }, { ":sword_", "sword", },
	{ "shears", "shears", },
}
E.ARMOR_GROUPS = { "armor_head", "armor_torso", "armor_legs", "armor_feet", }
E.NOT_ENCHANTABLE_PREFIX = { "technic:", "techage:", "ta4_", }
