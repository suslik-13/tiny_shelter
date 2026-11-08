-- Composter (spec cycle 3, 4; after Mineclonia's mcl_composters by kabou,
-- GPLv3): an item adds a layer with its Bedrock chance; 7 layers turn ready
-- after 1 s and give bone meal. The level is the node (composter,
-- composter_1..7, composter_ready), shown by a node box. A hopper above puts
-- into the hidden src list, a hopper below takes the bone meal from dst.
local BASE = "cb_blocks:composter"
if not cb_blocks.registered[BASE] then
	return
end
local tex = cb_blocks.tex
local C = { BONEMEAL = "bonemeal:bonemeal", }
cb_blocks.composter = C
C.CHANCE = {
	["default:cactus"] = 50, ["default:papyrus"] = 50, ["farming:melon_slice"] = 50,
	["default:apple"] = 65, ["farming:carrot"] = 65, ["farming:potato"] = 65, ["farming:beetroot"] = 65,
	["farming:wheat"] = 65, ["farming:pumpkin"] = 65, ["farming:pumpkin_8"] = 65, ["farming:melon_8"] = 65,
	["flowers:waterlily"] = 65, ["flowers:mushroom_red"] = 65, ["flowers:mushroom_brown"] = 65,
	["cb_blocks:nether_wart"] = 65,
	["farming:bread"] = 85, ["farming:baked_potato"] = 85, ["farming:cookie"] = 85, ["farming:straw"] = 85,
	["farming:pumpkin_pie"] = 100, ["farming:cake"] = 100,
}
C.GROUPS = { { "seed", 30, }, { "leaves", 30, }, { "sapling", 30, }, { "grass", 30, }, { "dry_grass", 30, },
	{ "flower", 65, }, }
local LEVEL = {}

function C.chance(name)
	if C.CHANCE[name] then
		return C.CHANCE[name]
	end
	for _, g in ipairs(C.GROUPS) do
		if core.get_item_group(name, g[1]) > 0 then
			return g[2]
		end
	end
	return 0
end

local function name_of(level)
	return level == 0 and BASE or level == 8 and BASE .. "_ready" or BASE .. "_" .. level
end

function C.level(pos)
	return LEVEL[core.get_node(pos).name]
end

local function inv_of(pos)
	local inv = core.get_meta(pos):get_inventory()
	if inv:get_size("src") ~= 1 then
		inv:set_size("src", 1)
		inv:set_size("dst", 1)
	end
	return inv
end

local function set_level(pos, level)
	local node = core.get_node(pos)
	core.swap_node(pos, { name = name_of(level), param1 = node.param1, param2 = node.param2, })
end

-- A ready composter whose bone meal a hopper took is empty again.
local function settle(pos)
	if C.level(pos) == 8 and inv_of(pos):is_empty("dst") then
		set_level(pos, 0)
	end
end

function C.add(pos, stack)
	settle(pos)
	local level = C.level(pos)
	if not level or level >= 7 then
		return false
	end
	local chance = C.chance(stack:get_name())
	if chance <= 0 then
		return false
	end
	if math.random(1, 100) <= chance then
		level = level + 1
		set_level(pos, level)
		core.sound_play("default_grass_footstep", { pos = pos, gain = 0.4, max_hear_distance = 16, }, true)
		if level == 7 then
			core.get_node_timer(pos):start(1)
		end
	end
	return true
end

function C.take(pos)
	if C.level(pos) ~= 8 then
		return nil
	end
	local inv = inv_of(pos)
	local stack = inv:get_stack("dst", 1)
	inv:set_stack("dst", 1, "")
	set_level(pos, 0)
	return stack
end

local function allowed(pos, player)
	local name = player and player:get_player_name() or ""
	if name ~= "" and core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return false
	end
	return true
end

local function on_rightclick(pos, _, clicker, itemstack)
	if not clicker or not allowed(pos, clicker) then
		return itemstack
	end
	local ctrl = clicker.get_player_control and clicker:get_player_control() or {}
	if ctrl.sneak then
		return itemstack
	end
	if C.level(pos) == 8 then
		local meal = C.take(pos)
		if meal and not meal:is_empty() then
			core.add_item(vector.offset(pos, 0, 0.7, 0), meal)
		end
		return itemstack
	end
	if not itemstack:is_empty() and C.add(pos, itemstack) and not core.is_creative_enabled(clicker:get_player_name()) then
		itemstack:take_item()
	end
	return itemstack
end

local function on_timer(pos)
	if C.level(pos) == 7 then
		set_level(pos, 8)
		if core.registered_items[C.BONEMEAL] then
			inv_of(pos):set_stack("dst", 1, C.BONEMEAL)
		end
		core.sound_play("default_dig_snappy", { pos = pos, gain = 1, max_hear_distance = 16, }, true)
	end
	return false
end

local function box(level)
	local top = ({ [0] = -7, -5, -3, -1, 1, 3, 5, 7, 7, })[level] / 16
	return { type = "fixed", fixed = {
		{ -0.5, -0.5, -0.5, -0.375, 0.5, 0.5, }, { 0.375, -0.5, -0.5, 0.5, 0.5, 0.5, },
		{ -0.375, -0.5, 0.375, 0.375, 0.5, 0.5, }, { -0.375, -0.5, -0.5, 0.375, 0.5, -0.375, },
		{ -0.5, -0.5, -0.5, 0.5, top, 0.5, },
	}, }
end

local function def_for(level)
	local fill = level == 0 and tex("composter_bottom") or level == 8 and tex("composter_ready") or tex("composter_compost")
	local groups = { choppy = 2, oddly_breakable_by_hand = 1, cb_jobsite = 1, cb_composter = 1, }
	if level > 0 then
		groups.not_in_creative_inventory = 1
	end
	return {
		drawtype = "nodebox",
		paramtype = "light",
		node_box = box(level),
		selection_box = { type = "regular", },
		tiles = { fill .. "^" .. tex("composter_top"), tex("composter_bottom"), tex("composter_side"), },
		groups = groups,
		drop = BASE,
		on_construct = inv_of,
		on_rightclick = on_rightclick,
		on_timer = on_timer,
		allow_metadata_inventory_put = function(pos, list, _, stack, player)
			settle(pos)
			if list ~= "src" or not allowed(pos, player) or (C.level(pos) or 8) >= 7 or C.chance(stack:get_name()) <= 0 then
				return 0
			end
			return 1
		end,
		allow_metadata_inventory_take = function(pos, list, _, stack, player)
			return list == "dst" and allowed(pos, player) and stack:get_count() or 0
		end,
		allow_metadata_inventory_move = function()
			return 0
		end,
		on_metadata_inventory_put = function(pos, list)
			local inv = inv_of(pos)
			if list == "src" then
				local stack = inv:get_stack("src", 1)
				inv:set_stack("src", 1, "")
				for _ = 1, stack:get_count() do
					C.add(pos, ItemStack(stack:get_name()))
				end
			end
		end,
		on_metadata_inventory_take = function(pos, list)
			if list == "dst" then
				settle(pos)
			end
		end,
	}
end

local base = core.registered_nodes[BASE]
for level = 0, 8 do
	LEVEL[name_of(level)] = level
	local def = def_for(level)
	if level == 0 then
		def.drop = nil
		core.override_item(BASE, def)
	else
		def.description = base.description
		def.sounds = base.sounds
		def._cb_jobsite_of = BASE
		core.register_node(":" .. name_of(level), def)
	end
end

if core.get_modpath("hopper") and rawget(_G, "hopper") and hopper.add_container then
	hopper:add_container({
		{ "top", "group:cb_composter", "dst", },
		{ "bottom", "group:cb_composter", "src", },
	})
end
