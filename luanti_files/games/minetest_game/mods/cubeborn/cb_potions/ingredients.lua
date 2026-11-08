-- Brewing ingredients the servers lack, their recipes and drops, the
-- brewing stand's Minecraft recipe and the water bottle.
local CP, S = cb_potions, cb_potions.S
local function tex(n)
	return "cb_potions_" .. n .. ".png"
end
local function hint(name, text)
	return name .. "\n" .. core.colorize("#a8a8a8", text)
end

core.register_craftitem("cb_potions:spider_eye", {
	description = hint(S("Spider Eye"), S("Dropped by spiders. Brews poison; fermented, it spoils potions.")),
	inventory_image = tex("spider_eye"),
	on_use = core.item_eat(2),
})
core.register_craftitem("cb_potions:fermented_spider_eye", {
	description = hint(S("Fermented Spider Eye"), S("Turns a potion into its opposite.")),
	inventory_image = tex("fermented_spider_eye"),
})
core.register_craftitem("cb_potions:glistering_melon", {
	description = hint(S("Glistering Melon Slice"), S("Brews healing.")),
	inventory_image = tex("glistering_melon"),
})
core.register_craftitem("cb_potions:rabbit_foot", {
	description = hint(S("Rabbit's Foot"), S("Rarely dropped by rabbits. Brews leaping.")),
	inventory_image = tex("rabbit_foot"),
})
core.register_craftitem("cb_potions:turtle_shell", {
	description = hint(S("Turtle Shell"), S("Rarely dropped by turtles. Brews the Turtle Master.")),
	inventory_image = tex("turtle_shell"),
})
core.register_craftitem("cb_potions:charge", {
	description = hint(S("Explosive Charge"), S("Gunpowder with a ghast tear: makes a harmful potion a splash one.")),
	inventory_image = "tnt_gunpowder_inventory.png^[colorize:#bfe8ff:110",
})

core.register_craft({ type = "shapeless", output = "cb_potions:fermented_spider_eye",
	recipe = { "cb_potions:spider_eye", "flowers:mushroom_brown", "farming:sugar", }, })
core.register_craft({ type = "shapeless", output = "cb_potions:glistering_melon",
	recipe = { "farming:melon_slice", "default:gold_ingot", }, })
core.register_craft({ type = "shapeless", output = "cb_potions:charge",
	recipe = { "tnt:gunpowder", "cb_mobs_nether:ghast_tear", }, })

-- The stand as in Minecraft: a blaze rod over three cobblestone.
core.clear_craft({ output = "cb_blocks:brewing_stand", })
core.register_craft({ output = "cb_blocks:brewing_stand", recipe = {
	{ "", "cb_items:blaze_rod", "", },
	{ "default:cobble", "default:cobble", "default:cobble", },
}, })

-- A glass bottle used on a water source fills (the bottle points at liquids).
local function fill(itemstack, nodename)
	local def = core.registered_nodes[nodename]
	if not (def and def.liquidtype == "source" and (def.groups.water or 0) > 0) then
		return nil
	end
	return ItemStack("cb_potions:water")
end

if core.registered_items["vessels:glass_bottle"] then
	local old_place = core.registered_items["vessels:glass_bottle"].on_place
	core.override_item("vessels:glass_bottle", {
		liquids_pointable = true,
		_cb_fill = fill,
		on_place = function(itemstack, placer, pointed)
			local under = pointed and pointed.type == "node" and core.get_node(pointed.under).name
			local water = under and fill(itemstack, under)
			if water and placer and placer:is_player() then
				local inv = placer:get_inventory()
				itemstack:take_item()
				if itemstack:is_empty() then
					return water
				end
				if inv:room_for_item("main", water) then
					inv:add_item("main", water)
				else
					core.add_item(placer:get_pos(), water)
				end
				return itemstack
			end
			return (old_place or core.item_place)(itemstack, placer, pointed)
		end,
	})
end

-- Drops on the servers' mobs: { mob, item, chance (1 in n) }.
CP.DROPS = {
	{ "mobs_monster:spider", "cb_potions:spider_eye", 2, },
	{ "cb_mobs_village:cave_spider", "cb_potions:spider_eye", 2, },
	{ "mobs_animal:bunny", "cb_potions:rabbit_foot", 10, },
	{ "mobs_turtles:turtle", "cb_potions:turtle_shell", 10, },
	{ "mobs_turtles:seaturtle", "cb_potions:turtle_shell", 10, },
}
core.register_on_mods_loaded(function()
	for _, d in ipairs(CP.DROPS) do
		local def = core.registered_entities[d[1]]
		if def then
			def.drops = def.drops or {}
			table.insert(def.drops, { name = d[2], chance = d[3], min = 1, max = 1, })
		end
	end
end)
