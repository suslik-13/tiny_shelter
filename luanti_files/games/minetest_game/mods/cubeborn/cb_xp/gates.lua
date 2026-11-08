-- Gear unlocked by experience (spec section 5): armour and shields above the
-- player's level come off into the inventory; weapons and tools above it deal
-- no damage to players and creatures and dig nothing.
local X = cb_xp
local S = X.S

local function level(name)
	return (X.level_of(X.get(name)))
end

function X.allowed(name, item)
	local need = X.tier(item)
	return level(name) >= need, need
end

local function refuse(name, need)
	X.notify(name, S("Not enough experience: level @1 needed, you have @2", need, level(name)))
end

-- Machines (pipeworks/techage fake players) and diggers that hold nothing
-- are never gated; armour held in the hand digs and hits like the hand.
function X.blocked(player)
	if player.is_fake_player or not player.get_wielded_item then
		return false
	end
	local item = player:get_wielded_item():get_name()
	local def = core.registered_items[item]
	if not (def and def.tool_capabilities) or X.is_armor(def) then
		return false
	end
	local name = player:get_player_name()
	local ok, need = X.allowed(name, item)
	if not ok then
		refuse(name, need)
	end
	return not ok
end

function X.enforce_armor(player)
	if not (rawget(_G, "armor") and armor.get_valid_player) then
		return
	end
	local name, inv = armor:get_valid_player(player, "[cb_xp]")
	if not inv then
		return
	end
	for i = 1, inv:get_size("armor") do
		local item = inv:get_stack("armor", i):get_name()
		if item ~= "" then
			local ok, need = X.allowed(name, item)
			if not ok then
				armor:unequip(player, armor:get_element(item))
				refuse(name, need)
			end
		end
	end
end

function X.enforce_later(name, delay)
	core.after(delay, function()
		local player = core.get_player_by_name(name)
		if player then
			X.enforce_armor(player)
		end
	end)
end

core.register_on_joinplayer(function(player)
	X.enforce_later(player:get_player_name(), 1)
end)

core.register_on_respawnplayer(function(player)
	X.enforce_later(player:get_player_name(), 0)
end)

X.register_on_change(function(name, old, new)
	if new < old then
		X.enforce_later(name, 0)
	end
end)

core.register_on_punchplayer(function(_, hitter)
	if hitter and hitter.is_player and hitter:is_player() and X.blocked(hitter) then
		return true
	end
end)

local dig = core.node_dig
function core.node_dig(pos, node, digger)
	if digger and digger.is_player and digger:is_player() and X.blocked(digger) then
		return false
	end
	return dig(pos, node, digger)
end

-- Creatures: mobs_redo mobs and Cubeborn's own entities (e.g. the dragon).
local function creature(name, def)
	return def._cmi_is_mob or name:find("^cb_mobs_")
end

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_items) do
		local need = X.tier(name)
		if need > 0 then
			core.override_item(name, { description = (def.description or name) .. "\n"
				.. core.colorize("#ffaa00", S("Requires level @1", need)), })
		end
	end
	for name, def in pairs(core.registered_entities) do
		if creature(name, def) then
			local punch = def.on_punch
			def.on_punch = function(self, puncher, ...)
				if puncher and puncher.is_player and puncher:is_player() and X.blocked(puncher) then
					return true
				end
				if punch then
					return punch(self, puncher, ...)
				end
			end
		end
	end
	if rawget(_G, "armor") and armor.register_on_equip then
		armor:register_on_equip(function(player)
			X.enforce_later(player:get_player_name(), 0)
		end)
	end
end)
