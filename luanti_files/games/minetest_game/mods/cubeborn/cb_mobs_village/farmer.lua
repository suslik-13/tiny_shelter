-- Farmers (spec cycle 3, 3.4): every EVERY s by day, the nearest ripe crop
-- within R of the job site (of the bed without one); walk there (find_path), harvest into the food stock,
-- replant from the stock. Farming Redo: stage 1 starts its own growth timer.
local F = cb_mobs_village.food
local FA = { EVERY = 20, R = 16, GIVE_UP = 30, REACH = 1.5, SKIP = 300, }
cb_mobs_village.farmer = FA
FA.RIPE = { ["farming:wheat_8"] = "wheat", ["farming:carrot_8"] = "carrot", ["farming:potato_4"] = "potato",
	["farming:beetroot_5"] = "beetroot", }
FA.PLANT = { wheat = "farming:wheat_1", carrot = "farming:carrot_1", potato = "farming:potato_1",
	beetroot = "farming:beetroot_1", }
FA.SEED = { wheat = "seeds", carrot = "carrot", potato = "potato", beetroot = "beetroot", }

local ripe_names
local function ripe_list()
	if not ripe_names then
		ripe_names = {}
		for name, crop in pairs(FA.RIPE) do
			if core.registered_nodes[name] and core.registered_nodes[FA.PLANT[crop]] then
				ripe_names[#ripe_names + 1] = name
			end
		end
	end
	return ripe_names
end

function FA.harvest(self, pos)
	local crop = FA.RIPE[core.get_node(pos).name]
	if not crop then
		return
	end
	local drops = core.get_node_drops(core.get_node(pos).name, "")
	core.remove_node(pos)
	for _, d in ipairs(drops) do
		local st = ItemStack(d)
		local kind = F.ITEMS[st:get_name()]
		local put = kind and F.add(self, kind, st:get_count()) or 0
		if put < st:get_count() then
			st:set_count(st:get_count() - put)
			core.add_item(pos, st)
		end
	end
	if F.take(self, FA.SEED[crop], 1) then
		core.set_node(pos, { name = FA.PLANT[crop], })
	end
end

local function nearest(self)
	-- around the job site: a village's farms lie 20-30 nodes from the farmers' beds
	local r, c = FA.R, self._job or self._bed
	local list = core.find_nodes_in_area(vector.offset(c, -r, -4, -r), vector.offset(c, r, 4, r), ripe_list())
	local pos = self.object:get_pos()
	local bad = self._crop_bad and (self._crop_bad_t or 0) > core.get_gametime() and self._crop_bad
	if bad then
		for i = #list, 1, -1 do
			if vector.equals(list[i], bad) then
				table.remove(list, i)
			end
		end
	end
	table.sort(list, function(a, b) return vector.distance(a, pos) < vector.distance(b, pos) end)
	return list[1]
end

-- Daytime adult farmers with a bed (the caller checks day). true while
-- walking to a crop.
function FA.tick(self, dt)
	if self._prof ~= "farmer" or not self._bed or #ripe_list() == 0 or (self._goal and self._goal.seek) then
		return false
	end
	if not self._crop then
		self._farm_t = (self._farm_t or 0) + dt
		if self._farm_t < FA.EVERY then
			return false
		end
		self._farm_t = 0
		self._crop, self._crop_t, self._path = nearest(self), 0, nil
		if not self._crop then
			return false
		end
	end
	local crop = self._crop
	self._crop_t = self._crop_t + dt
	if not FA.RIPE[core.get_node(crop).name] or self._crop_t > FA.GIVE_UP then
		if self._crop_t > FA.GIVE_UP then
			-- unreachable: try the others for a while
			self._crop_bad, self._crop_bad_t = crop, core.get_gametime() + FA.SKIP
		end
		self._crop, self._path = nil, nil
		return false
	end
	local pos = self.object:get_pos()
	if math.abs(pos.x - crop.x) + math.abs(pos.z - crop.z) <= FA.REACH * 2 and math.abs(pos.y - crop.y) <= 2 then
		FA.harvest(self, crop)
		self._crop, self._path = nil, nil
		self._farm_t = FA.EVERY -- the next ripe crop right away
		return false
	end
	cb_mobs_village.walk_to(self, crop, dt, true)
	return true
end
