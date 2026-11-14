-- Cyber machines: players craft the unique spawn blocks from valuable resources.
--
--   Cyber Fabricator  - structural blocks: plates, asphalt, panels, lamps, solar tech
--   Holo Synthesizer  - neon, holograms, crystals, neon plants
--
-- How it works: put resources into the input slots, pick a recipe on the
-- screen; the machine crafts one batch every few seconds while the
-- ingredients last and there is room in the output.
local MN = "the_tiny_spawn"
local S = minetest.get_translator(MN)
local P = MN .. ":"

local function t(n) return MN .. "_" .. n .. ".png" end

------------------------------------------------------------------------------
-- recipes: {output, {inputs...}, seconds}
------------------------------------------------------------------------------
local RECIPES = {
	fabricator = {
		{P .. "plate 8",          {"default:stone 8", "default:steel_ingot"}, 3},
		{P .. "plate_light 8",    {"default:stone 8", "default:tin_ingot"}, 3},
		{P .. "road 8",           {"default:gravel 6", "default:coal_lump 2"}, 3},
		{P .. "road_line 8",      {"default:gravel 6", "default:coal_lump 2", "default:mese_crystal_fragment 2"}, 4},
		{P .. "panel 8",          {"default:stone 6", "default:steel_ingot 2", "default:mese_crystal_fragment"}, 4},
		{P .. "lamp_pole 6",      {"default:steel_ingot 3"}, 3},
		{P .. "lamp_head 2",      {"default:glass 2", "default:mese_crystal"}, 5},
		{P .. "solar_lantern 2",  {"default:glass 2", "default:gold_ingot", "default:mese_crystal_fragment 3"}, 5},
		{P .. "light_pillar 4",   {"default:glass 2", "default:mese_crystal", "dye:cyan"}, 5},
		{P .. "solar_panel 4",    {"default:glass 2", "default:tin_ingot 2", "default:copper_ingot", "default:mese_crystal"}, 6},
		{P .. "emitter",          {"default:diamond 2", "default:gold_ingot 2", "default:mese"}, 10},
	},
	synthesizer = {
		{P .. "neon_cyan 8",      {"default:glass 8", "default:mese_crystal", "dye:cyan 2"}, 5},
		{P .. "neon_magenta 8",   {"default:glass 8", "default:mese_crystal", "dye:magenta 2"}, 5},
		{P .. "neon_purple 8",    {"default:glass 8", "default:mese_crystal", "dye:violet 2"}, 5},
		{P .. "neon_yellow 8",    {"default:glass 8", "default:mese_crystal", "dye:yellow 2"}, 5},
		{P .. "glass_cyan 8",     {"default:glass 8", "default:mese_crystal_fragment 2", "dye:cyan"}, 4},
		{P .. "holo_pool 4",      {"default:glass 4", "default:mese_crystal", "dye:blue"}, 5},
		{P .. "holo_column 4",    {"default:obsidian_glass 2", "default:mese_crystal", "dye:cyan"}, 6},
		{P .. "holo_screen 4",    {"default:obsidian_glass 2", "default:mese_crystal 2", "default:copper_ingot"}, 6},
		{P .. "beacon_red 2",     {"default:glass", "default:mese_crystal", "dye:red 2"}, 5},
		{P .. "crystal_cyan 2",   {"default:diamond", "default:mese_crystal_fragment 4", "dye:cyan"}, 8},
		{P .. "crystal_magenta 2", {"default:diamond", "default:mese_crystal_fragment 4", "dye:magenta"}, 8},
		{P .. "neon_trunk 4",     {"default:tree 4", "default:mese_crystal_fragment 2", "dye:magenta"}, 4},
		{P .. "neon_leaves 8",    {"default:leaves 8", "default:mese_crystal_fragment 2", "dye:pink"}, 4},
		{P .. "glow_vine 4",      {"default:leaves 4", "default:mese_crystal_fragment 2", "dye:green"}, 4},
		{P .. "petals 16",        {"default:paper", "dye:pink 2"}, 3},
	},
}

-- drop recipes whose items do not exist (e.g. a mod is missing)
for kind, list in pairs(RECIPES) do
	local ok = {}
	for _, r in ipairs(list) do
		local good = minetest.registered_items[ItemStack(r[1]):get_name()] ~= nil
		for _, i in ipairs(r[2]) do
			if not minetest.registered_items[ItemStack(i):get_name()] then good = false end
		end
		if good then ok[#ok + 1] = r else
			minetest.log("warning", "[" .. MN .. "] recipe for " .. r[1] .. " disabled (missing item)")
		end
	end
	RECIPES[kind] = ok
end
the_tiny_spawn.recipes = RECIPES

local TITLES = {fabricator = S("Cyber Fabricator"), synthesizer = S("Holo Synthesizer")}
local ACCENT = {fabricator = "#00e5ff", synthesizer = "#ff3cdc"}

------------------------------------------------------------------------------
-- formspec
------------------------------------------------------------------------------
local function formspec(pos, kind)
	local meta = minetest.get_meta(pos)
	local sel = meta:get_int("recipe")
	local progress = meta:get_float("progress")
	local list = RECIPES[kind]
	local acc = ACCENT[kind]
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local fs = {
		"formspec_version[4]",
		"size[12.6,13.7]",
		"bgcolor[#0b0b16f0;true]",
		"background9[0,0;12.6,13.7;" .. t("machine_side") .. "^[colorize:#0b0b16:200;true;4]",
		"style_type[label;textcolor=" .. acc .. "]",
		"label[0.4,0.5;" .. minetest.formspec_escape(TITLES[kind]) .. "]",
		"style_type[label;textcolor=#c8c8e0]",
		"label[0.4,0.95;" .. minetest.formspec_escape(S("Choose a recipe, load resources:")) .. "]",
	}
	-- recipe grid
	for i, r in ipairs(list) do
		local col, row = (i - 1) % 8, math.floor((i - 1) / 8)
		local x, y = 0.4 + col * 1.15, 1.3 + row * 1.15
		if i == sel then
			fs[#fs + 1] = ("box[%.2f,%.2f;1.1,1.1;%s]"):format(x - 0.05, y - 0.05, acc)
		end
		fs[#fs + 1] = ("item_image_button[%.2f,%.2f;1,1;%s;rcp_%d;]"):format(x, y, r[1], i)
	end
	-- selected recipe: ingredients -> result
	local r = list[sel]
	local y0 = 4.0
	if r then
		fs[#fs + 1] = "label[0.4," .. (y0 - 0.15) .. ";" .. minetest.formspec_escape(S("Needs:")) .. "]"
		for k, ing in ipairs(r[2]) do
			fs[#fs + 1] = ("item_image_button[%.2f,%.2f;0.9,0.9;%s;ing_%d;]"):format(0.4 + (k - 1) * 1.0, y0 + 0.1, ing, k)
		end
		fs[#fs + 1] = ("image[4.6,%.2f;0.9,0.9;gui_furnace_arrow_bg.png^[transformR270]"):format(y0 + 0.1)
		fs[#fs + 1] = ("item_image_button[5.7,%.2f;0.9,0.9;%s;out;]"):format(y0 + 0.1, r[1])
		fs[#fs + 1] = ("label[6.8,%.2f;%s]"):format(y0 + 0.55, minetest.formspec_escape(
			S("@1 s / batch", r[3])))
	else
		fs[#fs + 1] = "label[0.4," .. (y0 + 0.5) .. ";" .. minetest.formspec_escape(S("No recipe selected")) .. "]"
	end
	-- inventories + progress bar
	local yi = 5.5
	fs[#fs + 1] = "list[nodemeta:" .. spos .. ";src;0.4," .. yi .. ";4,2;]"
	fs[#fs + 1] = ("box[5.65,%.2f;1.3,0.3;#20203a]"):format(yi + 0.95)
	fs[#fs + 1] = ("box[5.65,%.2f;%.2f,0.3;%s]"):format(yi + 0.95, 1.3 * math.min(1, progress), acc)
	fs[#fs + 1] = "list[nodemeta:" .. spos .. ";dst;7.2," .. yi .. ";4,2;]"
	fs[#fs + 1] = "list[current_player;main;1.3,8.4;8,4;]"
	fs[#fs + 1] = "listring[nodemeta:" .. spos .. ";dst]listring[current_player;main]"
	fs[#fs + 1] = "listring[nodemeta:" .. spos .. ";src]listring[current_player;main]"
	return table.concat(fs)
end

------------------------------------------------------------------------------
-- processing
------------------------------------------------------------------------------
local function can_craft(inv, r)
	if not r then return false, S("no recipe") end
	for _, ing in ipairs(r[2]) do
		if not inv:contains_item("src", ing) then return false, S("missing resources") end
	end
	if not inv:room_for_item("dst", r[1]) then return false, S("output full") end
	return true
end

local function set_active(pos, kind, active)
	local node = minetest.get_node(pos)
	local want = P .. kind .. (active and "_active" or "")
	if node.name ~= want then
		minetest.swap_node(pos, {name = want, param2 = node.param2})
	end
end

local function update(pos, kind)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local r = RECIPES[kind][meta:get_int("recipe")]
	local ok, why = can_craft(inv, r)
	if ok then
		local timer = minetest.get_node_timer(pos)
		if not timer:is_started() then timer:start(1) end
		set_active(pos, kind, true)
		meta:set_string("infotext", ("%s: %s %d%%"):format(TITLES[kind], S("working"),
			math.floor(meta:get_float("progress") * 100)))
	else
		minetest.get_node_timer(pos):stop()
		set_active(pos, kind, false)
		meta:set_float("progress", 0)
		meta:set_string("infotext", ("%s: %s"):format(TITLES[kind], why))
	end
	meta:set_string("formspec", formspec(pos, kind))
	return ok
end

local function on_timer(pos, elapsed, kind)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local r = RECIPES[kind][meta:get_int("recipe")]
	if not can_craft(inv, r) then
		update(pos, kind)
		return false
	end
	local p = meta:get_float("progress") + elapsed / r[3]
	if p >= 1 then
		for _, ing in ipairs(r[2]) do inv:remove_item("src", ing) end
		inv:add_item("dst", r[1])
		p = 0
	end
	meta:set_float("progress", p)
	return update(pos, kind)
end

------------------------------------------------------------------------------
-- node registration
------------------------------------------------------------------------------
local function protected(pos, player)
	local name = player and player:get_player_name() or ""
	if minetest.is_protected(pos, name) then
		minetest.record_protection_violation(pos, name)
		return true
	end
	return false
end

local function register_machine(kind, front, desc_extra)
	local common = {
		description = TITLES[kind] .. "\n" .. desc_extra,
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = {cracky = 2},
		sounds = default.node_sound_metal_defaults and default.node_sound_metal_defaults()
			or default.node_sound_stone_defaults(),
		drop = P .. kind,
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("src", 8)
			inv:set_size("dst", 8)
			meta:set_int("recipe", 0)
			update(pos, kind)
		end,
		can_dig = function(pos)
			local inv = minetest.get_meta(pos):get_inventory()
			return inv:is_empty("src") and inv:is_empty("dst")
		end,
		on_receive_fields = function(pos, _, fields, sender)
			if protected(pos, sender) then return end
			for k in pairs(fields) do
				local i = tonumber(k:match("^rcp_(%d+)$"))
				if i and RECIPES[kind][i] then
					local meta = minetest.get_meta(pos)
					if meta:get_int("recipe") ~= i then
						meta:set_int("recipe", i)
						meta:set_float("progress", 0)
					end
					update(pos, kind)
				end
			end
		end,
		allow_metadata_inventory_put = function(pos, listname, _, stack, player)
			if protected(pos, player) or listname == "dst" then return 0 end
			return stack:get_count()
		end,
		allow_metadata_inventory_move = function(pos, from_list, _, to_list, _, count, player)
			if protected(pos, player) or to_list == "dst" then return 0 end
			return count
		end,
		allow_metadata_inventory_take = function(pos, _, _, stack, player)
			if protected(pos, player) then return 0 end
			return stack:get_count()
		end,
		on_metadata_inventory_put = function(pos) update(pos, kind) end,
		on_metadata_inventory_take = function(pos) update(pos, kind) end,
		on_metadata_inventory_move = function(pos) update(pos, kind) end,
		on_timer = function(pos, elapsed) return on_timer(pos, elapsed, kind) end,
		on_blast = function() end,
	}
	local idle = table.copy(common)
	idle.tiles = {t("machine_top"), t("machine_top"), t("machine_side"), t("machine_side"),
		t("machine_side"), t(front)}
	minetest.register_node(P .. kind, idle)

	local active = table.copy(common)
	active.tiles = {t("machine_top"), t("machine_top"), t("machine_side"), t("machine_side"),
		t("machine_side"), {name = t(front .. "_active"), animation = {type = "vertical_frames",
		aspect_w = 16, aspect_h = 16, length = 1.2}}}
	active.light_source = 8
	active.groups = {cracky = 2, not_in_creative_inventory = 1}
	minetest.register_node(P .. kind .. "_active", active)
end

register_machine("fabricator", "fabricator_front", S("Turns metals, stone and mese into cyber building blocks"))
register_machine("synthesizer", "synthesizer_front", S("Turns glass, mese, diamonds and dyes into neon and holograms"))

------------------------------------------------------------------------------
-- machine crafting (expensive on purpose)
------------------------------------------------------------------------------
minetest.register_craft({
	output = P .. "fabricator",
	recipe = {
		{"default:steelblock", "default:mese", "default:steelblock"},
		{"default:diamond", "default:furnace", "default:diamond"},
		{"default:copperblock", "default:obsidian_glass", "default:copperblock"},
	},
})
minetest.register_craft({
	output = P .. "synthesizer",
	recipe = {
		{"default:goldblock", "default:obsidian_glass", "default:goldblock"},
		{"default:mese", "default:diamondblock", "default:mese"},
		{"default:tinblock", "default:steelblock", "default:tinblock"},
	},
})

------------------------------------------------------------------------------
-- show the machine recipes in unified_inventory's craft guide (if present)
------------------------------------------------------------------------------
if minetest.get_modpath("unified_inventory") and unified_inventory and unified_inventory.register_craft_type then
	for kind, list in pairs(RECIPES) do
		unified_inventory.register_craft_type(MN .. "_" .. kind, {
			description = TITLES[kind],
			icon = t(kind .. "_front"),
			width = 4, height = 1,
			uses_crafting_grid = false,
		})
		for _, r in ipairs(list) do
			unified_inventory.register_craft({type = MN .. "_" .. kind, output = r[1], items = r[2], width = 4})
		end
	end
end
