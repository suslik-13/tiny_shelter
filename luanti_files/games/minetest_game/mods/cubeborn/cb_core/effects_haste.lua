-- Haste and Conduit Power (plan 16a: beacon and conduit). Luanti takes dig
-- times from the wielded stack's caps, so a hasted player's wielded tool gets
-- scaled meta caps; its own meta caps (toolranks level, enchantments) wait in
-- "cb_haste_orig" and come back when it is no longer wielded or the effect
-- ends. If someone rewrote the caps meanwhile (a toolranks level-up), the
-- new caps stay. Checked every effects tick (0.5 s), players with the effect only.
local S = cb_core.S
local E = cb_core.effects
local MARK, ORIG, SET = "cb_haste", "cb_haste_orig", "cb_haste_set"

local function head_in_water(player)
	local pos = player:get_pos()
	if not pos then
		return false
	end
	local node = core.get_node_or_nil(vector.round(vector.offset(pos, 0, 1.5, 0)))
	return node ~= nil and core.get_item_group(node.name, "water") > 0
end

-- Dig speed factor of the player now (1 = none): Haste +20 % a level;
-- Conduit Power under water counts as Haste I.
function E.dig_factor(player)
	local level = E.get(player, "haste") or 0
	if level < 1 and E.get(player, "conduit_power") and head_in_water(player) then
		level = 1
	end
	return 1 + 0.2 * level, level
end

local function restore(stack)
	local meta = stack:get_meta()
	if meta:get_string(MARK) == "" then
		return false
	end
	if meta:get_string("tool_capabilities") == meta:get_string(SET) then
		meta:set_string("tool_capabilities", meta:get_string(ORIG))
	end
	meta:set_string(MARK, "")
	meta:set_string(ORIG, "")
	meta:set_string(SET, "")
	return true
end

local function haste(stack, factor, level)
	if not stack:get_definition().tool_capabilities then
		return false
	end
	local meta = stack:get_meta()
	local orig = meta:get_string("tool_capabilities")
	local caps = stack:get_tool_capabilities()
	caps.full_punch_interval = caps.full_punch_interval and caps.full_punch_interval * (1 - 0.1 * level)
	for _, c in pairs(caps.groupcaps or {}) do
		for i, t in ipairs(c.times or {}) do
			c.times[i] = t / factor
		end
	end
	meta:set_tool_capabilities(caps)
	meta:set_string(MARK, tostring(factor))
	meta:set_string(ORIG, orig)
	meta:set_string(SET, meta:get_string("tool_capabilities"))
	return true
end

-- Puts the haste on the wielded tool only, at the current factor.
function E.haste_refresh(player)
	local inv = player.get_inventory and player:get_inventory()
	if not inv then
		return
	end
	local factor, level = E.dig_factor(player)
	local wi = player:get_wield_index()
	for i = 1, inv:get_size("main") do
		local st = inv:get_stack("main", i)
		local m = st:get_meta():get_string(MARK)
		local want = factor > 1 and i == wi
		if m ~= "" and (not want or m ~= tostring(factor)) then
			restore(st)
			inv:set_stack("main", i, st)
		end
		if want and st:get_meta():get_string(MARK) == "" and not st:is_empty() and haste(st, factor, level) then
			inv:set_stack("main", i, st)
		end
	end
end

local function tick(player)
	E.haste_refresh(player)
end

E.register("haste", {
	description = S("Haste"),
	icon = "cb_core_effect_haste.png",
	on_start = tick,
	on_tick = tick,
	on_end = tick,
})

E.register("conduit_power", {
	description = S("Conduit Power"),
	icon = "cb_core_effect_conduit_power.png",
	on_tick = function(player)
		local wet = head_in_water(player)
		if wet then
			local max = player:get_properties().breath_max or 10
			if player:get_breath() < max then
				player:set_breath(max)
			end
			player:override_day_night_ratio(1)
		elseif not E.get(player, "night_vision") then
			player:override_day_night_ratio(nil)
		end
		E.haste_refresh(player)
	end,
	on_end = function(player)
		if not E.get(player, "night_vision") then
			player:override_day_night_ratio(nil)
		end
		E.haste_refresh(player)
	end,
})

-- A marker left by a crash or a restart while hasted goes on join; on leave
-- the tool gets its caps back before the inventory is saved.
local function strip(player)
	local inv = player:get_inventory()
	if not inv then
		return
	end
	for i = 1, inv:get_size("main") do
		local st = inv:get_stack("main", i)
		if restore(st) then
			inv:set_stack("main", i, st)
		end
	end
end
core.register_on_joinplayer(function(player)
	strip(player)
	E.haste_refresh(player)
end)
core.register_on_leaveplayer(strip)

-- A hasted tool thrown away keeps nothing.
local item_drop = core.item_drop
function core.item_drop(itemstack, dropper, pos)
	if itemstack:get_meta():get_string(MARK) ~= "" then
		restore(itemstack)
	end
	return item_drop(itemstack, dropper, pos)
end
