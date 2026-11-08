-- Experience level each piece of gear needs (spec section 5). Every armour
-- piece, shield and tool of the three servers is covered: by exact name,
-- then by material (the last word of the name), then by name prefix, and
-- anything else by its strength, so gear from mods added later is ranked too.
local X = cb_xp

X.MATERIAL = {
	wood = 0, cactus = 0, stone = 0, admin = 0, adminh = 0, mushroom = 0,
	steel = 5, bronze = 5, gold = 5, meridium = 5, tessuto = 5, roots = 5,
	silver = 10,
	diamond = 15, mese = 15, mithril = 15, foglie = 15, juggernaut = 15,
	crystal = 20, fibra = 20,
	nether = 25, high = 25,
	netherite = 30, legendary = 30,
}

X.PREFIX = {
	["nether_mobs:dragon_"] = 30,
	["legendary_armor:"] = 30,
	["leather_armor:"] = 0,
	["zarmor:"] = 5,
	["cobble_compression:"] = 0,
	["x_obsidianmese:"] = 15,
}

X.EXACT = {
	-- utility tools, clothes and gadgets: no experience needed
	["anvil:hammer"] = 0, ["building_blocks:knife"] = 0, ["fireflies:bug_net"] = 0, ["wrench:wrench"] = 0,
	["x_farming:honeycomb_saw"] = 0, ["witches:witch_wand_btb"] = 0, ["witches:witch_wand_sp"] = 0,
	["technic:battery"] = 0, ["technic:blue_energy_crystal"] = 0, ["technic:green_energy_crystal"] = 0,
	["technic:red_energy_crystal"] = 0, ["ta4_jetpack:jetpack_material"] = 0, ["techage:hammer_stone"] = 0,
	["ebitems:glove_glove"] = 0, ["ethereal_bosses:glove_glove"] = 0,
	["shields:shield_enhanced_wood"] = 0, ["shields:shield_enhanced_cactus"] = 0,
	["zarmor:hat_head"] = 0, ["zarmor:Jacket_torso"] = 0, ["zarmor:Jacketpink_torso"] = 0,
	["zarmor:dressshirt_torso"] = 0, ["zarmor:jeanspants_legs"] = 0, ["zarmor:tennis_feet"] = 0,
	["zarmor:gas_mask"] = 0, ["zarmor:rabbit_mask"] = 0, ["zarmor:trashcanlid_shield"] = 0,
	["mask:mask"] = 5,
	["eamoretools:naturerod"] = 5, ["ethereal_bosses:naturerod"] = 5,
	["eamoretools:naturewhip"] = 0, ["ethereal_bosses:naturewhip"] = 0,
	["mobs:pick_lava"] = 15, ["mobs_others:sword_obsidian"] = 15,
	["x_obsidianmese:sword"] = 20,
	["ebitems:sword_obsidian"] = 25, ["ethereal_bosses:sword_obsidian"] = 25, ["mobs_balrog:balrog_whip"] = 25,
	["ebitems:flaming_sword"] = 30, ["ethereal_bosses:flaming_sword"] = 30, ["balrog_sword:balrog_sword"] = 30,
	["cb_items:elytra_wings"] = 30,
}

local ARMOR = { "armor_head", "armor_torso", "armor_legs", "armor_feet", "armor_shield", "armor_hand", "armor_feather", }

function X.is_armor(def)
	for _, g in ipairs(ARMOR) do
		if (def.groups or {})[g] then
			return true
		end
	end
	return false
end

function X.is_gear(def)
	if not def then
		return false
	end
	if X.is_armor(def) then
		return true
	end
	local tc = def.tool_capabilities
	return tc ~= nil and ((tc.groupcaps and next(tc.groupcaps) ~= nil) or tc.damage_groups ~= nil)
end

-- Level from the gear's strength, calibrated on the minetest_game materials.
local function by_strength(def)
	local tc = def.tool_capabilities
	if tc and not def.groups.armor_head and not def.groups.armor_torso then
		local dmg, lvl = tc.damage_groups and tc.damage_groups.fleshy or 0, 0
		for _, c in pairs(tc.groupcaps or {}) do
			lvl = math.max(lvl, c.maxlevel or 0)
		end
		if dmg >= 14 then return 30 elseif dmg >= 12 then return 25 elseif dmg >= 10 then return 20
		elseif dmg >= 7 or lvl >= 3 then return 15 elseif dmg >= 5 or lvl >= 2 then return 5 end
		return 0
	end
	local g = def.groups
	local legacy = 0
	for _, k in ipairs(ARMOR) do
		if (g[k] or 0) > 1 then
			legacy = math.max(legacy, g[k])
		end
	end
	local fleshy = def.armor_groups and def.armor_groups.fleshy or 0
	local rank = math.max(legacy, (g.armor_torso or g.armor_legs) and fleshy or fleshy + 5)
	if rank >= 20 then return 30 elseif rank >= 18 then return 15 elseif rank >= 15 then return 5 end
	return 0
end

function X.tier(item)
	local def = core.registered_items[item]
	if not X.is_gear(def) then
		return 0
	end
	if X.EXACT[item] then
		return X.EXACT[item]
	end
	local base = item:gsub("_durable$", ""):gsub("_fast$", ""):gsub("_sharp$", "")
	local material = base:match("_(%a+)$")
	material = material and material:lower()
	if material and X.MATERIAL[material] then
		return X.MATERIAL[material]
	end
	for prefix, lvl in pairs(X.PREFIX) do
		if item:sub(1, #prefix) == prefix then
			return lvl
		end
	end
	return by_strength(def)
end
