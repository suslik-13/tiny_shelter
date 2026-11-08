-- Mending (spec 5): collected experience repairs a random held or worn
-- Mending item, 2 durability a point; what is left goes to the player.
local E = cb_enchanting
E.MEND_PER_POINT = 2

-- Wear of one durability point of `stack`.
function E.durability(stack)
	local use = core.get_item_group(stack:get_name(), "armor_use")
	if use > 0 then
		return use
	end
	-- the definition's uses: Unbreaking and toolranks levels do not slow Mending
	local caps = (stack:get_definition() or {}).tool_capabilities
	local u = 0
	for _, c in pairs(caps and caps.groupcaps or {}) do
		u = math.max(u, c.uses or 0)
	end
	if u == 0 then
		u = caps and caps.punch_attack_uses or 0
	end
	return 65535 / (u > 0 and u or 250)
end

-- Repairs with `points` of experience; returns the points left over.
-- `slots` lists { get = fn() -> stack, set = fn(stack) } (hand and armor).
function E.mend_slots(slots, points)
	local open = {}
	for _, sl in ipairs(slots) do
		local s = sl.get()
		if s:get_wear() > 0 and E.level(s, "mending") > 0 then
			open[#open + 1] = sl
		end
	end
	while points > 0 and #open > 0 do
		local i = math.random(#open)
		local sl = open[i]
		local s = sl.get()
		local per = E.MEND_PER_POINT * E.durability(s)
		local need = math.ceil(s:get_wear() / per)
		local used = math.min(need, points)
		s:set_wear(math.max(0, s:get_wear() - math.floor(used * per + 0.5)))
		sl.set(s)
		points = points - used
		if s:get_wear() == 0 then
			table.remove(open, i)
		end
	end
	return points
end

function E.mend(player, points)
	local slots = {
		{ get = function() return player:get_wielded_item() end, set = function(s) player:set_wielded_item(s) end, },
	}
	local armor = rawget(_G, "armor")
	local _, ainv = armor and armor.get_valid_player and armor:get_valid_player(player, "[cb_enchanting]")
	for i = 1, ainv and ainv:get_size("armor") or 0 do
		slots[#slots + 1] = { get = function() return ainv:get_stack("armor", i) end,
			set = function(s) armor:set_inventory_stack(player, i, s) end, }
	end
	return E.mend_slots(slots, points)
end

local X = rawget(_G, "cb_xp")
if X and X.register_on_collect then
	X.register_on_collect(function(name, points)
		local player = core.get_player_by_name(name)
		return player and E.mend(player, points) or points
	end)
end
