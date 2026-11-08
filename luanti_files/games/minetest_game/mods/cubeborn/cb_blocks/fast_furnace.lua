-- Smoker and blast furnace (spec cycle 3, 4): furnaces with the server's
-- cooking recipes, twice as fast (cooking and fuel), the smoker only for
-- food results, the blast furnace only for ingots and ores. The node timer
-- is minetest_game's furnace timer (LGPL 2.1) with the speed factor.
local S = cb_blocks.S
local F = { SPEED = 2, ANIM = { smoker = true, blast_furnace = true, }, timer = {}, }
cb_blocks.fast_furnace = F

function F.food(name)
	local def = core.registered_items[name]
	for g in pairs(def and def.groups or {}) do
		if g:sub(1, 4) == "food" or g == "eatable" then
			return true
		end
	end
	return false
end

local FILTER = {
	smoker = function(_, out)
		return F.food(out)
	end,
	blast_furnace = function(src, out)
		return out:find("ingot", 1, true) ~= nil or core.get_item_group(src, "ore") > 0
	end,
}

function F.accepts(kind, stack)
	local r = core.get_craft_result({ method = "cooking", width = 1, items = { stack, }, })
	return r.time > 0 and FILTER[kind](stack:get_name(), r.item:get_name())
end

local function inv_of(pos)
	local inv = core.get_meta(pos):get_inventory()
	if inv:get_size("src") ~= 1 then
		inv:set_size("src", 1)
		inv:set_size("fuel", 1)
		inv:set_size("dst", 4)
	end
	return inv
end

local function allowed(pos, player)
	local name = player and player:get_player_name() or ""
	if name ~= "" and core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return false
	end
	return true
end

local function swap(pos, name)
	local node = core.get_node(pos)
	if node.name ~= name then
		core.swap_node(pos, { name = name, param1 = node.param1, param2 = node.param2, })
	end
end

local function add_or_drop(inv, pos, item)
	local left = inv:add_item("dst", item)
	if not left:is_empty() then
		core.add_item(vector.offset(pos, 0, 1, 0), left)
	end
end

local function make_timer(kind)
	local idle, active = "cb_blocks:" .. kind, "cb_blocks:" .. kind .. "_active"
	return function(pos, elapsed)
		elapsed = elapsed * F.SPEED
		local meta = core.get_meta(pos)
		local fuel_time = meta:get_float("fuel_time")
		local src_time = meta:get_float("src_time")
		local fuel_totaltime = meta:get_float("fuel_totaltime")
		local inv = inv_of(pos)
		local srclist, fuellist, cookable, cooked, fuel
		local update, dst_full = true, false
		while elapsed > 0 and update do
			update = false
			srclist, fuellist = inv:get_list("src"), inv:get_list("fuel")
			local aftercooked
			cooked, aftercooked = core.get_craft_result({ method = "cooking", width = 1, items = srclist, })
			cookable = cooked.time ~= 0 and FILTER[kind](srclist[1]:get_name(), cooked.item:get_name())
			local el = math.min(elapsed, fuel_totaltime - fuel_time)
			if cookable then
				el = math.min(el, cooked.time - src_time)
			end
			if fuel_time < fuel_totaltime then
				fuel_time = fuel_time + el
				if cookable then
					src_time = src_time + el
					if src_time >= cooked.time then
						if inv:room_for_item("dst", cooked.item) then
							inv:add_item("dst", cooked.item)
							-- a replacement that cannot cook leaves src (it would clog it)
							local after = aftercooked.items[1]
							local again = core.get_craft_result({ method = "cooking", width = 1, items = { after:to_string(), }, })
							if after:is_empty() or again.time ~= 0 or not again.item:is_empty() then
								inv:set_stack("src", 1, after)
							else
								inv:set_stack("src", 1, "")
								add_or_drop(inv, pos, after)
							end
							src_time = src_time - cooked.time
							update = true
							if cooked.replacements[1] then
								add_or_drop(inv, pos, cooked.replacements[1])
							end
						else
							dst_full = true
						end
					else
						update = true
					end
				end
			else
				if cookable then
					local afterfuel
					fuel, afterfuel = core.get_craft_result({ method = "fuel", width = 1, items = fuellist, })
					if fuel.time == 0 then
						fuel_totaltime, src_time = 0, 0
					else
						-- a replacement that is no fuel (an empty bucket) leaves the fuel slot
						local is_fuel = core.get_craft_result({ method = "fuel", width = 1,
							items = { afterfuel.items[1]:to_string(), }, })
						if is_fuel.time == 0 then
							table.insert(fuel.replacements, afterfuel.items[1])
							inv:set_stack("fuel", 1, "")
						else
							inv:set_stack("fuel", 1, afterfuel.items[1])
						end
						if fuel.replacements[1] then
							add_or_drop(inv, pos, fuel.replacements[1])
						end
						update = true
						fuel_totaltime = fuel.time + (fuel_totaltime - fuel_time)
					end
				else
					fuel_totaltime, src_time = 0, 0
				end
				fuel_time = 0
			end
			elapsed = elapsed - el
		end
		if fuel and fuel_totaltime > fuel.time then
			fuel_totaltime = fuel.time
		end
		if srclist and srclist[1]:is_empty() then
			src_time = 0
		end
		local item_percent = cookable and math.floor(src_time / cooked.time * 100) or 0
		local running = fuel_totaltime ~= 0
		local formspec
		if running then
			formspec = default.get_furnace_active_formspec(100 - math.floor(fuel_time / fuel_totaltime * 100), item_percent)
			swap(pos, active)
		else
			formspec = default.get_furnace_inactive_formspec()
			swap(pos, idle)
			core.get_node_timer(pos):stop()
		end
		local desc = core.registered_nodes[idle].description
		meta:set_float("fuel_totaltime", fuel_totaltime)
		meta:set_float("fuel_time", fuel_time)
		meta:set_float("src_time", src_time)
		meta:set_string("cb_formspec", formspec)
		meta:set_string("infotext", running and S("@1 active", desc) or (dst_full and S("@1: output full", desc)
			or S("@1 inactive", desc)))
		return running
	end
end

local function register(kind)
	local idle, active = "cb_blocks:" .. kind, "cb_blocks:" .. kind .. "_active"
	if not cb_blocks.registered[idle] then
		return
	end
	local timer = make_timer(kind)
	F.timer[kind] = timer
	local function show(pos, name)
		inv_of(pos)
		local meta = core.get_meta(pos)
		local fs = meta:get_string("cb_formspec")
		if fs == "" then
			fs = default.get_furnace_inactive_formspec()
		end
		-- the furnace formspecs use context lists: point them at this node
		fs = fs:gsub("context;", "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";")
		core.show_formspec(name, "cb_blocks:" .. kind .. "_" .. core.pos_to_string(pos), fs)
	end
	local common = {
		on_construct = function(pos)
			inv_of(pos)
		end,
		on_timer = timer,
		on_rightclick = function(pos, _, clicker, itemstack)
			if clicker and allowed(pos, clicker) then
				show(pos, clicker:get_player_name())
			end
			return itemstack
		end,
		can_dig = function(pos)
			local inv = inv_of(pos)
			return inv:is_empty("src") and inv:is_empty("fuel") and inv:is_empty("dst")
		end,
		allow_metadata_inventory_put = function(pos, list, _, stack, player)
			if not allowed(pos, player) then
				return 0
			end
			if list == "fuel" then
				return core.get_craft_result({ method = "fuel", width = 1, items = { stack, }, }).time ~= 0
					and stack:get_count() or 0
			elseif list == "src" then
				return F.accepts(kind, stack) and stack:get_count() or 0
			end
			return 0
		end,
		allow_metadata_inventory_move = function()
			return 0
		end,
		allow_metadata_inventory_take = function(pos, _, _, stack, player)
			return allowed(pos, player) and stack:get_count() or 0
		end,
		on_metadata_inventory_put = function(pos)
			core.get_node_timer(pos):start(1.0)
		end,
		on_metadata_inventory_take = function(pos)
			core.get_node_timer(pos):start(1.0)
		end,
		on_blast = function(pos)
			local drops = {}
			for _, list in ipairs({ "src", "fuel", "dst", }) do
				for _, st in ipairs(inv_of(pos):get_list(list)) do
					if not st:is_empty() then
						drops[#drops + 1] = st:to_string()
					end
				end
			end
			drops[#drops + 1] = idle
			core.remove_node(pos)
			return drops
		end,
	}
	core.override_item(idle, common)
	local base = core.registered_nodes[idle]
	local def = table.copy(common)
	local tiles = table.copy(base.tiles)
	local front = cb_blocks.tex(kind .. "_front_active")
	tiles[6] = F.ANIM[kind] and { name = front, animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16,
		length = 1.5, }, } or front
	local groups = table.copy(base.groups)
	groups.not_in_creative_inventory = 1
	def.description, def.sounds, def.paramtype2, def.tiles, def.groups = base.description, base.sounds, base.paramtype2,
		tiles, groups
	def.light_source, def.drop, def._cb_jobsite_of, def.is_ground_content = 8, idle, idle, false
	core.register_node(":" .. active, def)
	if rawget(_G, "hopper") and hopper.add_container then
		for _, n in ipairs({ idle, active, }) do
			hopper:add_container({ { "top", n, "dst", }, { "bottom", n, "src", }, { "side", n, "fuel", }, })
		end
	end
end

register("smoker")
register("blast_furnace")
