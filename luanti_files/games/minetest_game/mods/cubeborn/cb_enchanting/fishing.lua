-- The ethereal fishing rod (spec 5): Lure shortens the wait for a bite,
-- Luck of the Sea adds a treasure to some catches (ethereal's catch roll is
-- local to its mod, so junk stays as it is), Unbreaking spares the rod.
local E = cb_enchanting
local ROD, BOB = "ethereal:fishing_rod", "ethereal:bob_entity"
E.LURE_STEP, E.LUCK_CHANCE = 5, 0.05

function E.lure_wait(patience, level)
	return math.max(1, patience - E.LURE_STEP * level)
end

function E.lucky(level)
	return level > 0 and math.random() < E.LUCK_CHANCE * level
end

local TREASURE = { "cb_enchanting:book", ROD, "mobs:nametag", "mobs:saddle", "cb_mobs_water:nautilus_shell", }

-- One treasure: a registered item of the list, books and rods enchanted.
function E.fish_treasure()
	local list = {}
	for _, n in ipairs(TREASURE) do
		if core.registered_items[n] then
			list[#list + 1] = n
		end
	end
	local s = ItemStack(list[math.random(#list)])
	if s:get_name() == "cb_enchanting:book" or s:get_name() == ROD then
		E.enchant_randomly(s, 30, s:get_name() == "cb_enchanting:book")
	end
	return s
end

local function rod_level(fisher, ench)
	local player = fisher and core.get_player_by_name(fisher)
	return player and E.level(player:get_wielded_item(), ench) or 0
end

local function biting(player)
	for _, obj in ipairs(core.get_objects_inside_radius(player:get_pos(), 15)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == BOB and ent.fisher == player:get_player_name() and ent.bob == true then
			return true
		end
	end
	return false
end

core.register_on_mods_loaded(function()
	local bob = core.registered_entities[BOB]
	if bob and bob.on_step then
		local on_step = bob.on_step
		bob.on_step = function(self, ...)
			local old = self.patience
			local r = on_step(self, ...)
			if self.cast and not self.bob and (old == nil or old <= 0) and (self.patience or 0) > 0 then
				local l = rod_level(self.fisher, "lure")
				if l > 0 then
					self.patience = E.lure_wait(self.patience, l)
				end
			end
			return r
		end
	end
	local def = core.registered_tools[ROD]
	if not (def and def.on_use) then
		return
	end
	local on_use = def.on_use
	core.override_item(ROD, { on_use = function(itemstack, player, pointed)
		local ench = E.get(itemstack)
		if not (next(ench) and player and player.get_pos) then
			return on_use(itemstack, player, pointed)
		end
		local catch = E.lucky(ench.luck_of_the_sea or 0) and biting(player)
		local wear = itemstack:get_wear()
		local r = on_use(itemstack, player, pointed)
		local u = ench.unbreaking or 0
		if r and u > 0 and r:get_wear() > wear and math.random() < u / (u + 1) then
			r:set_wear(wear)
		end
		if catch then
			local t = E.fish_treasure()
			local left = player:get_inventory():add_item("main", t)
			if not left:is_empty() then
				core.add_item(player:get_pos(), left)
			end
		end
		return r
	end, })
end)
