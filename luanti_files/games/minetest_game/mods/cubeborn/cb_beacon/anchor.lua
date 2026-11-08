-- Respawn anchor (spec cycle 10): charged with glowstone (0-4 charges, the
-- light grows); in the Nether (the own pocket or the nether mod's) a
-- right-click makes it the player's respawn point, every respawn there costs
-- a charge. Anywhere else a charged anchor blows up when used. Its respawn
-- handler is added after all mods have loaded, so it comes last and wins
-- over beds and the spawn mod while it holds a charge.
local S = cb_beacon.S
local B = cb_beacon
local KEY = "cb_anchor"
B.ANCHOR = "cb_beacon:respawn_anchor"
local LIGHT = { [0] = 0, 3, 7, 11, 15, }

local function anchor_name(n)
	return n == 0 and B.ANCHOR or (B.ANCHOR .. "_" .. n)
end

function B.anchor_charges(pos)
	local name = core.get_node(pos).name
	if name == B.ANCHOR then
		return 0
	end
	return tonumber(name:match("^" .. B.ANCHOR:gsub("%p", "%%%0") .. "_(%d)$"))
end

local function set_charges(pos, n)
	core.swap_node(pos, { name = anchor_name(n), })
end
B.anchor_set_charges = set_charges

local function in_nether(pos)
	local st = rawget(_G, "cb_structures")
	return st and st.dim_at and st.dim_at(pos) == "nether"
end

local function glowstone(stack)
	return stack:get_name() == cb_core.equiv("glowstone")
		or (core.registered_items["nether:glowstone"] and stack:get_name() == "nether:glowstone")
		or stack:get_name() == "cb_blocks:glowstone"
end

-- Minecraft's anchor explosion (power 5): TNT's blast where it may destroy,
-- else the people around only get hurt.
function B.anchor_explode(pos)
	core.remove_node(pos)
	local tnt_ok = rawget(_G, "tnt") and tnt.boom and not core.is_protected(pos, "")
	if tnt_ok then
		tnt.boom(pos, { radius = 3, damage_radius = 5, explode_center = true, })
		return
	end
	core.set_node(pos, { name = B.ANCHOR, })
	set_charges(pos, 0)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 5)) do
		if obj:is_player() then
			local d = vector.distance(pos, obj:get_pos())
			obj:set_hp(math.max(0, obj:get_hp() - math.ceil(10 * (1 - d / 6))), { type = "set_hp", cause = "cb_beacon:anchor", })
		end
	end
end

function B.anchor_use(pos, player, itemstack)
	local n = B.anchor_charges(pos) or 0
	local name = player:get_player_name()
	if itemstack and glowstone(itemstack) and n < 4 then
		set_charges(pos, n + 1)
		if not core.is_creative_enabled(name) then
			itemstack:take_item(1)
		end
		return itemstack
	end
	if n == 0 then
		return itemstack
	end
	if not in_nether(pos) then
		B.anchor_explode(pos)
		return itemstack
	end
	player:get_meta():set_string(KEY, core.pos_to_string(pos))
	core.chat_send_player(name, S("Respawn point set."))
	return itemstack
end

-- Respawns the player at their anchor if it still holds a charge.
function B.anchor_respawn(player)
	local meta = player:get_meta()
	local pos = core.string_to_pos(meta:get_string(KEY))
	if not pos then
		return false
	end
	core.load_area(pos)
	local n = B.anchor_charges(pos)
	if not n or n == 0 then
		meta:set_string(KEY, "")
		core.chat_send_player(player:get_player_name(), S("Your respawn anchor is gone or empty."))
		return false
	end
	set_charges(pos, n - 1)
	local spot = vector.offset(pos, 0, 1, 0)
	for _, o in ipairs({ { 1, 0, }, { -1, 0, }, { 0, 1, }, { 0, -1, }, { 1, 1, }, { -1, -1, }, }) do
		local p = vector.offset(pos, o[1], 0, o[2])
		local a, b = core.get_node(p), core.get_node(vector.offset(p, 0, 1, 0))
		local da, db = core.registered_nodes[a.name], core.registered_nodes[b.name]
		if da and db and not da.walkable and not db.walkable then
			spot = p
			break
		end
	end
	player:set_pos(spot)
	return true
end

for n = 0, 4 do
	local top = n == 0 and "cb_beacon_anchor_top_off.png" or "cb_beacon_anchor_top_on.png"
	core.register_node(anchor_name(n), {
		description = n == 0 and (S("Respawn Anchor") .. "\n" .. S("Charge with glowstone; sets your respawn point in the Nether, explodes elsewhere"))
			or S("Respawn Anchor"),
		tiles = { top, "cb_beacon_anchor_bottom.png", "cb_beacon_anchor_side" .. n .. ".png", },
		paramtype = "light", light_source = LIGHT[n], is_ground_content = false,
		groups = { cracky = 1, level = 2, not_in_creative_inventory = n > 0 and 1 or nil, },
		drop = B.ANCHOR,
		sounds = default.node_sound_stone_defaults(),
		on_rightclick = function(pos, _, clicker, itemstack)
			if not (clicker and clicker:is_player()) or core.is_protected(pos, clicker:get_player_name()) then
				return itemstack
			end
			return B.anchor_use(pos, clicker, itemstack)
		end,
	})
end

core.register_craft({
	output = B.ANCHOR,
	recipe = {
		{ "cb_blocks:crying_obsidian", "cb_blocks:crying_obsidian", "cb_blocks:crying_obsidian", },
		{ "group:cb_glowstone", "group:cb_glowstone", "group:cb_glowstone", },
		{ "cb_blocks:crying_obsidian", "cb_blocks:crying_obsidian", "cb_blocks:crying_obsidian", },
	},
})
for _, g in ipairs({ "cb_blocks:glowstone", "nether:glowstone", }) do
	local def = core.registered_items[g]
	if def then
		local groups = table.copy(def.groups or {})
		groups.cb_glowstone = 1
		core.override_item(g, { groups = groups, })
	end
end

core.register_on_mods_loaded(function()
	core.register_on_respawnplayer(function(player)
		return B.anchor_respawn(player)
	end)
end)
