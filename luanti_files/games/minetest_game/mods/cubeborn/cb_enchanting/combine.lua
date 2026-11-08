-- Combining (spec 4.5), ported from Mineclonia mcl_enchanting.combine and
-- mcl_anvils (GPLv3): an item takes the enchantments of a book or of the same
-- item; the cost in levels grows with the prior work penalty.
local E = cb_enchanting
local BOOK = "cb_enchanting:book"
local PWP = "cb_enchanting:pwp"
local FULL = 65535
E.ANVIL_MAX = 40
E.SAME_TOOL_BONUS = 0.12

function E.pwp(stack)
	return stack:get_meta():get_int(PWP)
end

local function repaired_wear(a, b)
	local health = (FULL - a:get_wear()) + (FULL - b:get_wear()) + math.floor(FULL * E.SAME_TOOL_BONUS)
	return math.max(0, FULL - health)
end

-- The combined stack and its cost in levels, or nil, 0 and why
-- ("mismatch": these two do not go together, "nothing": nothing would change).
-- The inputs are not changed.
function E.combine(target, sacrifice)
	local tname, sname = target:get_name(), sacrifice:get_name()
	local from = E.get(sacrifice)
	if target:is_empty() or sacrifice:is_empty() or not E.class(tname)
			or (sname ~= tname and not (sname == BOOK and next(from))) then
		return nil, 0, "mismatch"
	end
	local ench = E.get(target)
	local book = sname == BOOK
	local changed, cost = {}, 0
	for name, l in pairs(from) do
		local def = E.DEFS[name]
		if def then
			local have = ench[name]
			if have then
				local new = have == l and math.min(l + 1, def.max) or math.max(have, l)
				if new ~= have then
					ench[name], changed[name] = new, true
				end
			elseif E.supports(tname, name) then
				local ok = true
				for other in pairs(ench) do
					if def.incompatible[other] or (E.DEFS[other] and E.DEFS[other].incompatible[name]) then
						ok = false
					end
				end
				if ok then
					ench[name], changed[name] = l, true
				else
					cost = cost + 1
				end
			end
		end
	end
	local out = ItemStack(target)
	local repaired = false
	if sname == tname and core.registered_tools[tname] and target:get_wear() > 0 then
		local w = repaired_wear(target, sacrifice)
		if w < target:get_wear() then
			out:set_wear(w)
			repaired = true
			cost = cost + 2
		end
	end
	if not next(changed) and not repaired then
		return nil, 0, "nothing"
	end
	for name in pairs(changed) do
		local def = E.DEFS[name]
		cost = cost + ench[name] * (book and def.anvil_book or def.anvil_item)
	end
	local p1, p2 = E.pwp(target), E.pwp(sacrifice)
	cost = cost + (2 ^ p1 - 1) + (2 ^ p2 - 1)
	out:get_meta():set_int(PWP, math.max(p1, p2) + 1)
	E.set(out, ench)
	return out, math.floor(cost)
end

-- The anvil (`anvil:anvil`, one slot): punching the item on it with an
-- enchanted book or the same item combines them for experience. Hammer
-- repairs stay the anvil's.
local S = E.S
local ANVIL = "anvil:anvil"

local function X()
	return rawget(_G, "cb_xp")
end

local function has_access(pos, name)
	local meta = core.get_meta(pos)
	return meta:get_int("shared") == 1 or meta:get_string("owner") == name
end

-- true when the punch was a combine (done or refused with a message);
-- false: not ours, the anvil handles it.
function E.anvil_punch(pos, puncher)
	local name = puncher:get_player_name()
	local inv = core.get_meta(pos):get_inventory()
	local target, hand = inv:get_stack("input", 1), puncher:get_wielded_item()
	if target:is_empty() or hand:is_empty() or hand:get_name() == "anvil:hammer" then
		return false
	end
	if not has_access(pos, name) then
		return false
	end
	local out, levels, why = E.combine(target, hand)
	if why == "mismatch" then
		return false
	end
	if not out then
		return true, S("Nothing to combine")
	end
	if levels >= E.ANVIL_MAX then
		return true, S("Too expensive")
	end
	local x = X()
	if x and not x.is_admin(name) then
		if x.level_of(x.get(name)) < levels then
			return true, S("Needs level @1", levels)
		end
		x.spend(name, E.xp_cost(name, levels))
	end
	inv:set_stack("input", 1, out)
	hand:take_item()
	puncher:set_wielded_item(hand)
	core.sound_play("anvil_clang", { pos = pos, max_hear_distance = 16, }, true)
	return true
end

core.register_on_mods_loaded(function()
	local def = core.registered_nodes[ANVIL]
	if not def then
		return
	end
	local punch, allow_put = def.on_punch, def.allow_metadata_inventory_put
	core.override_item(ANVIL, {
		on_punch = function(pos, node, puncher, ...)
			if puncher and puncher.is_player and puncher:is_player() then
				local done, msg = E.anvil_punch(pos, puncher)
				if done then
					if msg then
						core.chat_send_player(puncher:get_player_name(), msg)
					end
					return
				end
			end
			return punch(pos, node, puncher, ...)
		end,
		-- unworn enchantable items and books may lie on the anvil too
		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if listname == "input" and stack:get_wear() == 0 and E.class(stack:get_name()) and player then
				local inv = core.get_meta(pos):get_inventory()
				return has_access(pos, player:get_player_name()) and inv:is_empty("input") and 1 or 0
			end
			return allow_put(pos, listname, index, stack, player)
		end,
	})
end)
