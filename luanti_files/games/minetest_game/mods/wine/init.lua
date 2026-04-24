wine = {}

local path = core.get_modpath("wine")
local def = core.get_modpath("default")
local pipe = core.get_modpath("pipeworks")
local snd_d = def and default.node_sound_defaults()
local snd_g = def and default.node_sound_glass_defaults()
local glass_item = def and "default:glass"
local txt
local pipes_list = pipe and pipeworks.pipes_full_nodenames or {"default:river_water_source"}


-- check for MineClone2
local mcl = core.get_modpath("mcl_core")

if mcl then
	snd_d = mcl_sounds.node_sound_glass_defaults()
	snd_g = mcl_sounds.node_sound_defaults()
	glass_item = "mcl_core:glass"
end

-- check for Unified Inventory
local is_uninv = core.global_exists("unified_inventory") or false

-- is thirsty mod active
local thirsty_mod = core.get_modpath("thirsty")

-- translation support
local S = core.get_translator("wine") ; wine.S = S

-- Unified Inventory hints
if is_uninv then

	unified_inventory.register_craft_type("barrel", {
		description = "Barrel",
		icon = "wine_barrel.png",
		width = 2,
		height = 2
	})
end

-- fermentation list (drinks added in drinks.lua)
local ferment = {}


-- add item and resulting beverage to list
function wine:add_item(list)

	for n = 1, #list do

		local item = list[n]

		-- change old string recipe item into table
		if type(item[1]) == "string" then
			item = { {item[1], "vessels:drinking_glass"}, item[2] }
		end

		table.insert(ferment, item)

		-- if ui mod found add recipe
		if is_uninv then

			unified_inventory.register_craft({
				type = "barrel",
				items = item[1],
				output = item[2]
			})
		end
	end
end

-- helper function
function wine.add_eatable(item, hp)

	local def = core.registered_items[item]

	if def then

		local groups = table.copy(def.groups) or {}

		groups.eatable = hp ; groups.flammable = 2

		core.override_item(item, {groups = groups})
	end
end

-- add drink with bottle
function wine:add_drink(name, desc, has_bottle, num_hunger, num_thirst, alcoholic)

	-- glass
	core.register_node("wine:glass_" .. name, {
		description = S("Glass of " .. desc),
		drawtype = "plantlike",
		visual_scale = 0.5,
		tiles = {"wine_" .. name .. "_glass.png"},
		inventory_image = "wine_" .. name .. "_glass.png",
		wield_image = "wine_" .. name .. "_glass.png",
		paramtype = "light",
		is_ground_content = false,
		sunlight_propagates = true,
		walkable = false,
		selection_box = {
			type = "fixed", fixed = {-0.15, -0.5, -0.15, 0.15, 0, 0.15}
		},
		groups = {
			vessel = 1, dig_immediate = 3,
			attached_node = 1, drink = 1, alcohol = alcoholic
		},
		sounds = snd_g,

		on_use = function(itemstack, user, pointed_thing)

			if user then

				if thirsty_mod then
					thirsty.drink(user, num_thirst)
				end

				return core.do_item_eat(num_hunger, "vessels:drinking_glass",
						itemstack, user, pointed_thing)
			end
		end
	})

	wine.add_eatable("wine:glass_" .. name, num_hunger)

	-- bottle
	if has_bottle then

		core.register_node("wine:bottle_" .. name, {
			description = S("Bottle of " .. desc),
			drawtype = "plantlike",
			visual_scale = 0.7,
			tiles = {"wine_" .. name .. "_bottle.png"},
			inventory_image = "wine_" .. name .. "_bottle.png",
			paramtype = "light",
			is_ground_content = false,
			sunlight_propagates = true,
			walkable = false,
			selection_box = {
				type = "fixed", fixed = {-0.15, -0.5, -0.15, 0.15, 0.25, 0.15}
			},
			groups = {dig_immediate = 3, attached_node = 1, vessel = 1},
			sounds = snd_d,
		})

		local glass = "wine:glass_" .. name

		core.register_craft({
			output = "wine:bottle_" .. name,
			recipe = {
				{glass, glass, glass},
				{glass, glass, glass},
				{glass, glass, glass}
			}
		})

		core.register_craft({
			output = glass .. " 9",
			recipe = {{"wine:bottle_" .. name}}
		})
	end
end


-- Wine barrel formspec
local function winebarrel_formspec(item_percent, brewing, water_percent)

	local mcl_bg = mcl and "listcolors[#9d9d9d;#FFF7;#474747]" or ""

	return "size[8,9]" .. mcl_bg

	-- images
	.. "image[0,0;7,5;wine_barrel_fs_bg.png]"
	.. "image[5.88,1.8;1,1;wine_barrel_icon_bg.png^[lowpart:"
	.. item_percent .. ":wine_barrel_icon.png]"
	.. "image[1.04,2.7;4.45,1.65;wine_barrel_water.png"
	.. "^[colorize:#261c0e:175^[opacity:125"
	.. "^[lowpart:" .. water_percent .. ":wine_barrel_water.png]"

	-- inside barrel tinv
	.. "list[current_name;src;1.9,0.7;2,2;]"
	.. "list[current_name;src_b;2.4,2.95;1,1;0]"

	-- outside barrel inv
	.. "list[current_name;dst;7,1.8;1,1;]"
	.. "list[current_player;main;0,5;8,4;]"

	-- tooltips
	.. "tooltip[5.88,1.8;1,1;" .. brewing .. "]"
	.. "tooltip[1.05,2.7;3.495,1.45;" .. S("Water @1% Full", water_percent) .. "]"

	-- shift-click
	.. "listring[current_name;dst]"
	.. "listring[current_player;main]"
	.. "listring[current_name;src]"
	.. "listring[current_player;main]"
end


-- list of buckets used to fill barrel
local bucket_list = {
	{"bucket:bucket_water", "bucket:bucket_empty", 20},
	{"bucket:bucket_river_water", "bucket:bucket_empty", 20},
	{"wooden_bucket:bucket_wood_water", "wooden_bucket:bucket_wood_empty", 20},
	{"wooden_bucket:bucket_wood_river_water", "wooden_bucket:bucket_wood_empty", 20},
	{"bucket_wooden:bucket_water", "bucket_wooden:bucket_empty", 20},
	{"bucket_wooden:bucket_river_water", "bucket_wooden:bucket_empty", 20},
	{"mcl_buckets:bucket_water", "mcl_buckets:bucket_empty", 20},
	{"farming:glass_water", "vessels:drinking_glass", 5},
	{"default:water_source", "", 20},
	{"default:river_water_source", "", 20},
	{"mcl_core:water_source", "", 20},
	{"bucket:bucket_water_uni_gold", "bucket:bucket_empty_gold", 20},
	{"bucket:bucket_water_uni_mese", "bucket:bucket_empty_mese", 20},
	{"bucket:bucket_water_uni_wood", "bucket:bucket_empty_wood", 20},
	{"bucket:bucket_water_uni_steel", "bucket:bucket_empty_steel", 20},
	{"bucket:bucket_water_uni_stone", "bucket:bucket_empty_stone", 20},
	{"bucket:bucket_water_uni_bronze", "bucket:bucket_empty_bronze", 20},
	{"bucket:bucket_water_uni_diamond", "bucket:bucket_empty_diamond", 20},
	{"bucket:bucket_water_river_gold", "bucket:bucket_empty_gold", 20},
	{"bucket:bucket_water_river_mese", "bucket:bucket_empty_mese", 20},
	{"bucket:bucket_water_river_wood", "bucket:bucket_empty_wood", 20},
	{"bucket:bucket_water_river_steel", "bucket:bucket_empty_steel", 20},
	{"bucket:bucket_water_river_stone", "bucket:bucket_empty_stone", 20},
	{"bucket:bucket_water_river_bronze", "bucket:bucket_empty_bronze", 20},
	{"bucket:bucket_water_river_diamond", "bucket:bucket_empty_diamond", 20},
	{"mesecraft_bucket:bucket_water", "mesecraft_bucket:bucket_empty", 20},
	{"mesecraft_bucket:bucket_river_water", "mesecraft_bucket:bucket_empty", 20}
}


-- water item helper
local function water_check(item)

	for n = 1, #bucket_list do

		if bucket_list[n][1] == item then
			return bucket_list[n]
		end
	end
end


-- Wine barrel node
core.register_node("wine:wine_barrel", {
	description = S("Fermenting Barrel"),
	tiles = {"wine_barrel.png" },
	drawtype = "mesh",
	mesh = "wine_barrel.obj",
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {
		choppy = 2, oddly_breakable_by_hand = 1, flammable = 2,
		tubedevice = 1, tubedevice_receiver = 1, axey = 1
	},
	legacy_facedir_simple = true,

	--on_place = core.rotate_node,

	on_construct = function(pos)

		local meta = core.get_meta(pos)

		meta:set_string("formspec", winebarrel_formspec(0, "", 0))
		meta:set_string("infotext", S("Fermenting Barrel"))
		meta:set_float("status", 0)

		local inv = meta:get_inventory()

		inv:set_size("src", 4) -- ingredients
		inv:set_size("src_b", 1) -- water bucket
		inv:set_size("dst", 1) -- brewed item
	end,

	-- punch old barrel to change to new 4x slot variant and add a little water
	on_punch = function(pos, node, puncher, pointed_thing)

		local meta = core.get_meta(pos)
		local inv = meta and meta:get_inventory()
		local size = inv and inv:get_size("src")

		if size and size < 4 then

			inv:set_size("src", 4)
			inv:set_size("src_b", 1)

			meta:set_int("water", 50)
			meta:set_string("formspec", winebarrel_formspec(0, "", 50))
		end
	end,

	can_dig = function(pos,player)

		local meta = core.get_meta(pos)
		local inv = meta:get_inventory()

		if not inv:is_empty("dst")
		or not inv:is_empty("src")
		or not inv:is_empty("src_b") then
			return false
		end

		return true
	end,

	allow_metadata_inventory_take = function(pos, listname, index, stack, player)

		if core.is_protected(pos, player:get_player_name()) then
			return 0
		end

		return stack:get_count()
	end,

	allow_metadata_inventory_put = function(pos, listname, index, stack, player)

		if core.is_protected(pos, player:get_player_name()) then
			return 0
		end

		local meta = core.get_meta(pos)
		local inv = meta:get_inventory()

		if listname == "src" then

			return stack:get_count()

		elseif listname == "src_b" then

			local water = meta:get_int("water")

			-- water full, return item
			if water == 100 then
				return 0
			end

			local is_bucket = stack:get_name()
			local is_water = water_check(is_bucket)

			if is_water then
				return stack:get_count()
			else
				return 0
			end

		elseif listname == "dst" then

			return 0
		end
	end,

	allow_metadata_inventory_move = function(
			pos, from_list, from_index, to_list, to_index, count, player)

		if core.is_protected(pos, player:get_player_name()) then
			return 0
		end

		local meta = core.get_meta(pos)
		local inv = meta:get_inventory()
		local stack = inv:get_stack(from_list, from_index)

		if to_list == "src" then
			return count

		elseif to_list == "dst" then
			return 0

		elseif to_list == "src_b" then
			return 0
		end
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)

		if listname == "src_b" then

			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			local is_bucket = inv:get_stack("src_b", 1):get_name()
			local is_water = water_check(is_bucket)

			if is_water then

				local water = meta:get_int("water")
				local amount = tonumber(is_water[3]) or 0

				water = water + amount

				if water > 100 then water = 100 end

				inv:remove_item("src_b", is_water[1])

				-- if replacement found then add to inventory
				if is_water[2] ~= "" then
					inv:add_item("src_b", is_water[2])
				end

				local status = meta:get_float("status")

				meta:set_int("water", water)
				meta:set_string("formspec",
						winebarrel_formspec(status, S("Water Added"), water))
			end
		end

		local timer = core.get_node_timer(pos)

		if not timer:is_started() then
			core.get_node_timer(pos):start(5)
		end
	end,

	on_metadata_inventory_move = function(pos)

		local timer = core.get_node_timer(pos)

		if not timer:is_started() then
			core.get_node_timer(pos):start(5)
		end
	end,

	on_metadata_inventory_take = function(pos)

		local timer = core.get_node_timer(pos)

		if not timer:is_started() then
			core.get_node_timer(pos):start(5)
		end
	end,

	pipe_connections = {
		left = 1, right = 1, front = 1, back = 1,
		left_param2 = 3, right_param2 = 1, front_param2 = 2, back_param2 = 0
	},

	after_dig_node = function(pos)

		if pipe then
			pipeworks.scan_for_pipe_objects(pos)
		end
	end,

	tube = (function() if pipe then return {

		-- using a different stack from defaut when inserting
		insert_object = function(pos, node, stack, direction)

			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			local timer = core.get_node_timer(pos)

			if not timer:is_started() then
				timer:start(5)
			end

			return inv:add_item("src", stack)
		end,

		can_insert = function(pos, node, stack, direction)

			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()

			return inv:room_for_item("src", stack)
		end,

		-- the default stack, from which objects will be taken
		input_inventory = "dst",

		connect_sides = {left = 1, right = 1, back = 1, front = 1, bottom = 1, top = 1}

	} end end)(),

	on_timer = function(pos)

		local meta = core.get_meta(pos) ; if not meta then return end
		local inv = meta:get_inventory()
		local water = meta:get_int("water") or 0

		-- check for pipeworks water inlet or well block
		if water < 100 then

			if core.find_node_near(pos, 1, pipes_list) then

				water = water + 20

				if water > 100 then water = 100 end

				meta:set_int("water", water)
			end
		end

		-- is barrel empty?
		if not inv or inv:is_empty("src") then

			meta:set_float("status", 0)
			meta:set_string("infotext", S("Fermenting Barrel"))
			meta:set_string("formspec", winebarrel_formspec(0, "", water))

			return false
		end

		-- check water level
		if water < 5 then

			txt = S("Fermenting Barrel") .. " " .. S("(Water Level Low)")

			meta:set_string("infotext", txt)
			meta:set_float("status", 0)
			meta:set_string("formspec", winebarrel_formspec(0,
					S("(Water Level Low)"), water))

			return false
		end

		-- does it contain any of the source items on the list?
		local has_items, recipe, item1, item2, item3, item4

		for n = 1, #ferment do

			recipe = ferment[n]

			item1 = recipe[1][1] and ItemStack(recipe[1][1])
			item2 = recipe[1][2] and ItemStack(recipe[1][2])
			item3 = recipe[1][3] and ItemStack(recipe[1][3])
			item4 = recipe[1][4] and ItemStack(recipe[1][4])

			-- check for recipe items
			if item1 then

				has_items = inv:contains_item("src", item1)

				if has_items and item2 then

					has_items = inv:contains_item("src", item2)

					if has_items and item3 then

						has_items = inv:contains_item("src", item3)

						if has_items and item4 then
							has_items =  inv:contains_item("src", item4)
						end
					end
				end
			end

			-- if we have all items in recipe break and continue
			if has_items then
				break
			end
		end

		-- if we have a wrong recipe change status
		if not has_items then

			txt = S("Fermenting Barrel") .. " " .. S("(No Valid Recipe)")

			meta:set_string("infotext", txt)
			meta:set_float("status", 0)
			meta:set_string("formspec",
					winebarrel_formspec(0, S("(No Valid Recipe)"), water))

			return false
		end

		-- is there room for additional fermentation?
		if not inv:room_for_item("dst", recipe[2]) then

			txt = S("Fermenting Barrel") .. " " .. S("(Output Full)")

			meta:set_string("infotext", txt)
			meta:set_string("formspec",
					winebarrel_formspec(0, S("(Output Full)"), water))

			return false
		end

		local status = meta:get_float("status")

		-- fermenting (change status)
		if status < 100 then

			txt = S("Fermenting Barrel") .. " " .. S("(@1% Done)", status)

			meta:set_string("infotext", txt)
			meta:set_float("status", status + 5)

			local d1 = recipe[2]:split(" ")[1]
			local desc = core.registered_items[d1].description or ""

			txt = S("Brewing: @1", desc) .. " " .. S("(@1% Done)", status)

			meta:set_string("formspec", winebarrel_formspec(status, txt, water))

		else -- when we hit 100% remove items needed and add beverage

			if item1 then inv:remove_item("src", item1) end
			if item2 then inv:remove_item("src", item2) end
			if item3 then inv:remove_item("src", item3) end
			if item4 then inv:remove_item("src", item4) end

			inv:add_item("dst", recipe[2])

			water = water - 5

			meta:set_float("status", 0)
			meta:set_int("water", water)
			meta:set_string("formspec", winebarrel_formspec(0, "", water))
		end

		if inv:is_empty("src") then
			meta:set_float("status", 0.0)
			meta:set_string("infotext", S("Fermenting Barrel"))
		end

		return true
	end
})


-- wine barrel craft recipe (with mineclone2 check)
local ingot = mcl and "mcl_core:iron_ingot" or "default:steel_ingot"

core.register_craft({
	output = "wine:wine_barrel",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{ingot, "", ingot},
		{"group:wood", "group:wood", "group:wood"}
	}
})


-- LBMs to start timers on existing, ABM-driven nodes
core.register_lbm({
	name = "wine:barrel_timer_upgrade_init",
	label = "upgrade old barrels and start timers",
	nodenames = {"wine:wine_barrel"},
	run_at_every_load = false,

	action = function(pos)

		-- convert any old 2x slot barrels into new 4x slot ones and add a little water
		local meta = core.get_meta(pos)
		local inv = meta and meta:get_inventory()
		local size = inv and inv:get_size("src")

		if size and size < 4 then

			inv:set_size("src", 4)
			inv:set_size("src_b", 1)

			meta:set_int("water", 50)
			meta:set_string("formspec", winebarrel_formspec(0, "", 50))
		end

		-- Start barrel timer
		core.get_node_timer(pos):start(5)
	end
})


-- add agave plant and functions
dofile(path .. "/agave.lua")

-- add drink nodes and recipes
dofile(path .. "/drinks.lua")

-- add lucky blocks
if core.get_modpath("lucky_block") then
	dofile(path .. "/lucky_block.lua")
end


-- mineclone2 doesn't have a drinking glass, so if none found add one
if not core.registered_items["vessels:drinking_glass"] then

	core.register_node(":vessels:drinking_glass", {
		description = S("Empty Drinking Glass"),
		drawtype = "plantlike",
		tiles = {"wine_drinking_glass.png"},
		inventory_image = "wine_drinking_glass.png",
		wield_image = "wine_drinking_glass.png",
		paramtype = "light",
		is_ground_content = false,
		walkable = false,
		selection_box = {
			type = "fixed",
			fixed = {-0.25, -0.5, -0.25, 0.25, 0.3, 0.25}
		},
		groups = {vessel = 1, dig_immediate = 3, attached_node = 1},
		sounds = snd_g,
	})

	core.register_craft( {
		output = "vessels:drinking_glass 14",
		recipe = {
			{glass_item, "" , glass_item},
			{glass_item, "" , glass_item},
			{glass_item, glass_item, glass_item}
		}
	})
end


-- sort ferment table to fix recipe overlap (large to small)
core.after(0.2, function()

	local tmp = {}

	for l = 4, 1, -1 do
		for n = 1, #ferment do

			if #ferment[n][1] == l then
				table.insert(tmp, ferment[n])
			end
		end
	end

	ferment = tmp
end)


print ("[MOD] Wine loaded")
