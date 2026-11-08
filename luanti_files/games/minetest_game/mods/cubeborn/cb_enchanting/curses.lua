-- Curses (spec 5): Vanishing — gone on death, never in bones; Binding — an
-- armor piece that cannot leave the armor slots (death and creative aside).
local E = cb_enchanting

function E.bound(stack)
	return E.level(stack, "curse_of_binding") > 0
end

local function creative(player)
	return core.is_creative_enabled(player:get_player_name())
end

local function armor_inv(player)
	local armor = rawget(_G, "armor")
	if not (armor and armor.get_valid_player) then
		return nil
	end
	local _, inv = armor:get_valid_player(player, "[cb_enchanting]")
	return inv
end

-- Removes the Vanishing items of a dying player; returns how many went.
function E.vanish(player, ainv)
	local n = 0
	local function clear(inv, list)
		for i, s in ipairs(inv and inv:get_list(list) or {}) do
			if not s:is_empty() and E.level(s, "curse_of_vanishing") > 0 then
				inv:set_stack(list, i, ItemStack(""))
				n = n + 1
			end
		end
	end
	local inv = player:get_inventory()
	clear(inv, "main")
	clear(inv, "craft")
	ainv = ainv or armor_inv(player)
	local before = n
	clear(ainv, "armor")
	local armor = rawget(_G, "armor")
	if n > before and armor and type(player) == "userdata" then
		armor:save_armor_inventory(player)
		armor:set_player_armor(player)
	end
	return n
end

-- before bones and 3d_armor take the inventory (registered normally so the
-- builtin runner knows its origin, then moved to the front)
core.register_on_dieplayer(function(player)
	E.vanish(player)
end)
table.insert(core.registered_on_dieplayers, 1, table.remove(core.registered_on_dieplayers))

-- Whether putting on `item` would take a bound piece off `player`.
function E.equip_blocked(player, item)
	local armor = rawget(_G, "armor")
	if not (armor and armor.get_element) or creative(player) then
		return false
	end
	local element = armor:get_element(item)
	for _, s in ipairs(E.worn(player)) do
		if not s:is_empty() and E.bound(s) and armor:get_element(s:get_name()) == element then
			return true
		end
	end
	return false
end

-- Wraps the allow_take of the player's 3d_armor inventory once.
function E.bind_inventory(name)
	local cb = core.detached_inventories[name .. "_armor"]
	if not cb or cb._cb_bound then
		return
	end
	local allow_take = cb.allow_take
	cb.allow_take = function(inv, listname, index, stack, player)
		if E.bound(stack) and not creative(player) then
			return 0
		end
		return allow_take and allow_take(inv, listname, index, stack, player) or stack:get_count()
	end
	cb._cb_bound = true
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	E.bind_inventory(name)
	core.after(0, E.bind_inventory, name)
end)

core.register_on_mods_loaded(function()
	local armor = rawget(_G, "armor")
	if not (armor and armor.equip and armor.unequip) then
		return
	end
	local equip, unequip = armor.equip, armor.unequip
	armor.equip = function(self, player, itemstack, ...)
		if player and itemstack and E.equip_blocked(player, itemstack:get_name()) then
			return itemstack
		end
		return equip(self, player, itemstack, ...)
	end
	armor.unequip = function(self, player, element, ...)
		if player and not creative(player) then
			for _, s in ipairs(E.worn(player)) do
				if not s:is_empty() and E.bound(s) and self:get_element(s:get_name()) == element then
					return
				end
			end
		end
		return unequip(self, player, element, ...)
	end
end)
