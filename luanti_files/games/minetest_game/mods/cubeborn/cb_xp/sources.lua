-- Where experience comes from (Minecraft values where MTG has an analogue):
-- mobs killed by a player, ores, ripe crops, smelting, breeding, fishing.
-- Trading and the ender dragon call cb_xp.drop themselves.
local X = cb_xp

X.MOB_XP = { ["cb_mobs_dim:blaze"] = 10, }

function X.mob_xp(ent)
	if ent.child or ent.type == "npc" then
		return 0
	end
	if X.MOB_XP[ent.name] then
		return X.MOB_XP[ent.name]
	end
	if ent.type == "monster" then
		return 5
	elseif ent.type == "animal" then
		return math.random(1, 3)
	end
	return 0
end

X.ORE_XP = {
	["default:stone_with_coal"] = { 0, 2, },
	["default:stone_with_diamond"] = { 3, 7, },
	["default:stone_with_mese"] = { 3, 7, },
	["cb_blocks:quartz_ore"] = { 2, 5, },
}

-- Ripe (last stage) crops of farming redo; harvesting one gives 1.
local ripe

function X.ripe_crop(nodename)
	if not ripe then
		ripe = {}
		local plants = rawget(_G, "farming") and farming.registered_plants or {}
		for _, p in pairs(plants) do
			if p.crop and p.steps then
				ripe[p.crop .. "_" .. p.steps] = true
			end
		end
	end
	return ripe[nodename] == true
end

function X.on_dig(pos, nodename, digger)
	local r = X.ORE_XP[nodename] or X.ripe_crop(nodename) and { 1, 1, }
	if not (r and digger and digger.is_player and digger:is_player()) or digger.is_fake_player
			or core.is_creative_enabled(digger:get_player_name()) then
		return
	end
	X.drop(pos, math.random(r[1], r[2]))
end

core.register_on_dignode(function(pos, oldnode, digger)
	X.on_dig(pos, oldnode.name, digger)
end)

-- A villager trade gives 3-6; money changed at the banker gives nothing (it
-- has no daily limit, so it would sell experience).
function X.trade_xp(offer)
	return offer.bank and 0 or math.random(3, 6)
end

-- Experience per smelted item; fractions are kept per player.
function X.cook_value(item)
	if item == "default:gold_ingot" then
		return 1
	elseif item:find("_ingot$") then
		return 0.7
	elseif core.get_item_group(item, "food") > 0 or core.get_item_group(item, "eatable") > 0 then
		return 0.35
	end
	return 0.1
end

function X.smelt(name, item, count)
	local key = "f:" .. name
	local sum = X.storage:get_float(key) + X.cook_value(item) * count
	local whole = math.floor(sum + 1e-6)
	X.storage:set_float(key, sum - whole)
	return whole
end

local FURNACES = { "default:furnace", "default:furnace_active", "cb_blocks:smoker", "cb_blocks:smoker_active",
	"cb_blocks:blast_furnace", "cb_blocks:blast_furnace_active", }

core.register_on_mods_loaded(function()
	for _, n in ipairs(FURNACES) do
		local def = core.registered_nodes[n]
		if def then
			local take = def.on_metadata_inventory_take
			core.override_item(n, {
				on_metadata_inventory_take = function(pos, listname, index, stack, player)
					if listname == "dst" and player and player:is_player() then
						local n_xp = X.smelt(player:get_player_name(), stack:get_name(), stack:get_count())
						if n_xp > 0 then
							X.drop(vector.offset(pos, 0, 1, 0), n_xp)
						end
					end
					if take then
						return take(pos, listname, index, stack, player)
					end
				end,
			})
		end
	end
	-- Fishing: a catch (the bob has a bite when the rod is used) gives 1-6.
	local rod = core.registered_items["ethereal:fishing_rod"]
	if rod and rod.on_use then
		local use = rod.on_use
		core.override_item("ethereal:fishing_rod", {
			on_use = function(itemstack, player, ...)
				local bite = false
				if player and player.is_player and player:is_player() and not player.is_fake_player then
					local name = player:get_player_name()
					for _, obj in ipairs(core.get_objects_inside_radius(player:get_pos(), 15)) do
						local e = obj:get_luaentity()
						bite = bite or (e and e.name == "ethereal:bob_entity" and e.fisher == name and e.bob == true)
					end
				end
				local r = use(itemstack, player, ...)
				if bite then
					X.drop(player:get_pos(), math.random(1, 6))
				end
				return r
			end,
		})
	end
	if not (rawget(_G, "mobs") and mobs.mob_class) then
		return
	end
	local item_drop = mobs.mob_class.item_drop
	mobs.mob_class.item_drop = function(self, ...)
		local c = self.cause_of_death
		local killer = c and c.puncher
		if killer and killer.is_player and killer:is_player() then
			local n = X.mob_xp(self)
			if n > 0 then
				X.drop(self.object:get_pos(), n)
			end
		end
		return item_drop(self, ...)
	end
	for _, def in pairs(core.registered_entities) do
		if def._cmi_is_mob then
			local breed = def.on_breed
			def.on_breed = function(self, other)
				local r = breed and breed(self, other)
				if r ~= false then
					X.drop(self.object:get_pos(), math.random(1, 7))
				end
				return r
			end
		end
	end
end)
