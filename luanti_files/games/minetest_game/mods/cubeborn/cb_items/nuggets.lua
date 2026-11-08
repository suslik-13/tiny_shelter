-- Gold and iron nuggets (Minecraft): 9 make an ingot. An iron ingot also
-- gives 9 back; a gold ingot does not, since minetest_game's skeleton key
-- already is one gold ingot. As in Minecraft, smelting gold and iron tools,
-- weapons and armour gives a nugget. Loot tables and firework stars use them.
local S = cb_items.S
for _, n in ipairs({ { "gold", S("Gold Nugget"), "default:gold_ingot", false, }, { "iron", S("Iron Nugget"), "default:steel_ingot", true, }, }) do
	local item = "cb_items:" .. n[1] .. "_nugget"
	core.register_craftitem(item, { description = n[2], inventory_image = "cb_items_" .. n[1] .. "_nugget.png", })
	core.register_craft({ output = n[3], recipe = { { item, item, item, }, { item, item, item, }, { item, item, item, }, }, })
	if n[4] then
		core.register_craft({ type = "shapeless", output = item .. " 9", recipe = { n[3], }, })
	end
end

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_items) do
		local metal = name:match("_gold$") and "gold" or (name:match("_steel$") or name:match("_iron$")) and "iron"
		if metal and (def.type == "tool" or (def.groups and (def.groups.armor_head or def.groups.armor_torso
				or def.groups.armor_legs or def.groups.armor_feet))) then
			local out = core.get_craft_result({ method = "cooking", width = 1, items = { name, }, })
			if out.item:is_empty() then
				core.register_craft({ type = "cooking", output = "cb_items:" .. metal .. "_nugget", recipe = name, cooktime = 10, })
			end
		end
	end
end)
