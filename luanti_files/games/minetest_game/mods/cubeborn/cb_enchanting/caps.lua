-- Tool caps (spec 4.2, decision 5): the toolranks level bonus with
-- Efficiency, Unbreaking and Sharpness on top. toolranks rewrites the caps
-- from the definition on each level-up, so its after-use is wrapped to put
-- the enchantments back.
local E = cb_enchanting
local setting = function(k, d)
	return tonumber(core.settings:get(k)) or d
end
local MAX_LEVEL = setting("toolranks_levels", 10)
local MAX_SPEED = setting("toolranks_speed_multiplier", 2.0)
local MAX_USE = setting("toolranks_use_multiplier", 2.0)
E.SPEED_CAP, E.EFFICIENCY_STEP = 2.5, 0.1

-- The caps of an item of definition `def` at toolranks level `lastlevel` with enchantments `ench`.
function E.caps(def, lastlevel, ench)
	if not def.tool_capabilities then
		return nil
	end
	local caps = table.copy(def.tool_capabilities)
	local level_speed = 1 + lastlevel / MAX_LEVEL * (MAX_SPEED - 1)
	local use = (1 + lastlevel / MAX_LEVEL * (MAX_USE - 1)) * ((ench.unbreaking or 0) + 1)
	local speed = math.min(level_speed + E.EFFICIENCY_STEP * (ench.efficiency or 0), math.max(E.SPEED_CAP, level_speed))
	caps.full_punch_interval = caps.full_punch_interval and caps.full_punch_interval / level_speed
	caps.punch_attack_uses = caps.punch_attack_uses and caps.punch_attack_uses * use
	for _, c in pairs(caps.groupcaps or {}) do
		c.uses = c.uses and c.uses * use
		for i, t in ipairs(c.times or {}) do
			c.times[i] = t / speed
		end
	end
	if (ench.sharpness or 0) > 0 then
		caps.damage_groups = caps.damage_groups or {}
		caps.damage_groups.fleshy = (caps.damage_groups.fleshy or 0) + math.floor(1.25 * ench.sharpness + 0.5)
	end
	return caps
end

local CAPS = { efficiency = true, unbreaking = true, sharpness = true, }

function E.apply_caps(stack, ench)
	local meta = stack:get_meta()
	local def = stack:get_definition()
	local lastlevel = tonumber(meta:get_string("lastlevel")) or 0
	local any = false
	for n in pairs(ench) do
		any = any or CAPS[n] == true
	end
	if not def.tool_capabilities then
		return
	end
	if any or lastlevel > 0 then
		meta:set_tool_capabilities(E.caps(def, lastlevel, ench))
	else
		meta:set_tool_capabilities(nil)
	end
end

core.register_on_mods_loaded(function()
	local tr = rawget(_G, "toolranks")
	if not tr or not tr.new_afteruse then
		return
	end
	local orig = tr.new_afteruse
	E.toolranks_afteruse = function(stack, user, node, digparams)
		-- mobs_redo weapon hits come with node == nil and wear it worked out
		-- itself, without punch_attack_uses: Unbreaking applies here.
		local u = node == nil and digparams and (digparams.wear or 0) > 0 and E.level(stack, "unbreaking") or 0
		if u > 0 then
			digparams = table.copy(digparams)
			digparams.wear = math.max(1, math.floor(digparams.wear / (u + 1)))
		end
		local out = orig(stack, user, node, digparams)
		if out and next(E.get(out)) then
			E.refresh(out)
		end
		return out
	end
	tr.new_afteruse = E.toolranks_afteruse
	for name, def in pairs(core.registered_items) do
		if def.after_use == orig then
			core.override_item(name, { after_use = E.toolranks_afteruse, })
		end
	end
end)
