-- Netherite gear (spec cycle 3, 4): made from diamond gear at the smithing
-- table only. Minecraft's proportions over the server's diamond values:
-- tools last 1.3x longer, dig 1.125x faster and hit 1 harder; armor gives 2
-- more protection per piece, lasts 1.12x longer and resists fire
-- (armor_fire 1/2/1/1: a full set stands lava in 3d_armor). Nothing here is
-- flammable, so netherite dropped in lava survives. Textures: Mineclonia.
local S = cb_items.S
local N = { UPGRADE = {}, TOOL_USES = 1.3, TOOL_SPEED = 1.125, ARMOR_USE = 1.12, }
cb_items.netherite = N
local function tex(n)
	return "cb_items_" .. n .. ".png"
end

local TOOLS = {
	sword = { "default:sword_diamond", S("Netherite Sword"), },
	pick = { "default:pick_diamond", S("Netherite Pickaxe"), },
	axe = { "default:axe_diamond", S("Netherite Axe"), },
	shovel = { "default:shovel_diamond", S("Netherite Shovel"), },
}
for kind, t in pairs(TOOLS) do
	local d = core.registered_tools[t[1]]
	if d and d.tool_capabilities then
		local caps = table.copy(d.tool_capabilities)
		for _, gc in pairs(caps.groupcaps or {}) do
			gc.uses = math.ceil((gc.uses or 20) * N.TOOL_USES)
			for level, time in pairs(gc.times or {}) do
				gc.times[level] = time / N.TOOL_SPEED
			end
		end
		for g, v in pairs(caps.damage_groups or {}) do
			caps.damage_groups[g] = v + 1
		end
		local name = "cb_items:" .. kind .. "_netherite"
		local groups = table.copy(d.groups or {})
		groups.flammable = nil
		core.register_tool(name, {
			description = t[2],
			inventory_image = tex(kind .. "_netherite"),
			wield_image = d.wield_image and d.wield_image:find("transformR90", 1, true) and tex(kind .. "_netherite")
				.. "^[transformR90" or nil,
			tool_capabilities = caps,
			sound = d.sound,
			groups = groups,
		})
		N.UPGRADE[t[1]] = name
	end
end

if rawget(_G, "farming") and farming.register_hoe and core.registered_tools["farming:hoe_diamond"] then
	farming.register_hoe(":cb_items:hoe_netherite", {
		description = S("Netherite Hoe"),
		inventory_image = tex("hoe_netherite"),
		max_uses = 650,
		damage_groups = { fleshy = 4, },
	})
	N.UPGRADE["farming:hoe_diamond"] = "cb_items:hoe_netherite"
end

local PIECES = {
	helmet = { "armor_head", 15, 1, S("Netherite Helmet"), },
	chestplate = { "armor_torso", 20, 2, S("Netherite Chestplate"), },
	leggings = { "armor_legs", 20, 1, S("Netherite Leggings"), },
	boots = { "armor_feet", 15, 1, S("Netherite Boots"), },
}
if rawget(_G, "armor") and armor.register_armor then
	for piece, p in pairs(PIECES) do
		local dname = "3d_armor:" .. piece .. "_diamond"
		local d = core.registered_tools[dname]
		if d then
			local name = "cb_items:" .. piece .. "_netherite"
			local dg = d.groups or {}
			armor:register_armor(name, {
				description = p[4],
				inventory_image = tex("inv_" .. piece .. "_netherite"),
				groups = { [p[1]] = 1, armor_heal = dg.armor_heal or 6,
					armor_use = math.floor((dg.armor_use or 200) / N.ARMOR_USE), armor_fire = p[3], },
				armor_groups = { fleshy = p[2], },
				damage_groups = d.damage_groups or { cracky = 2, snappy = 1, choppy = 1, level = 3, },
			})
			N.UPGRADE[dname] = name
		end
	end
end
