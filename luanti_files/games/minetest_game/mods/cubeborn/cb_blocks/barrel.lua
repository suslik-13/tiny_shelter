-- Barrel (spec cycle 3, 4): 27 slots like a chest; the lid shows open while
-- someone looks inside. Area protection guards the contents.
local BASE, OPEN = "cb_blocks:barrel", "cb_blocks:barrel_open"
if not cb_blocks.registered[BASE] then
	return
end
local S, tex = cb_blocks.S, cb_blocks.tex
local B = { SIZE = 27, }
cb_blocks.barrel = B
local viewers = {} -- node hash -> { player name = true }
local FORM = "cb_blocks:barrel_"

local function inv_of(pos)
	local inv = core.get_meta(pos):get_inventory()
	if inv:get_size("main") ~= B.SIZE then
		inv:set_size("main", B.SIZE)
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

function B.open(pos, name)
	inv_of(pos)
	local h = core.hash_node_position(pos)
	viewers[h] = viewers[h] or {}
	viewers[h][name] = true
	if core.get_node(pos).name ~= OPEN then
		core.sound_play("default_chest_open", { pos = pos, gain = 0.3, max_hear_distance = 10, }, true)
	end
	swap(pos, OPEN)
	local loc = "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z
	core.show_formspec(name, FORM .. core.pos_to_string(pos),
		"size[9,8.6]label[0,0;" .. core.formspec_escape(S("Barrel")) .. "]list[" .. loc .. ";main;0,0.5;9,3;]"
		.. "list[current_player;main;0.5,4.4;8,4;]listring[" .. loc .. ";main]listring[current_player;main]")
end

function B.close(pos, name)
	local h = core.hash_node_position(pos)
	local v = viewers[h]
	if v then
		v[name] = nil
		if next(v) then
			return
		end
		viewers[h] = nil
	end
	if core.get_node(pos).name == OPEN then
		core.sound_play("default_chest_close", { pos = pos, gain = 0.3, max_hear_distance = 10, }, true)
		swap(pos, BASE)
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, #FORM) ~= FORM then
		return
	end
	local pos = core.string_to_pos(formname:sub(#FORM + 1))
	if pos and fields.quit then
		B.close(pos, player:get_player_name())
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	for h, v in pairs(viewers) do
		if v[name] then
			B.close(core.get_position_from_hash(h), name)
		end
	end
end)

local common = {
	on_construct = inv_of,
	on_rightclick = function(pos, _, clicker, itemstack)
		if clicker and allowed(pos, clicker) then
			B.open(pos, clicker:get_player_name())
		end
		return itemstack
	end,
	can_dig = function(pos)
		return inv_of(pos):is_empty("main")
	end,
	allow_metadata_inventory_put = function(pos, _, _, stack, player)
		return allowed(pos, player) and stack:get_count() or 0
	end,
	allow_metadata_inventory_take = function(pos, _, _, stack, player)
		return allowed(pos, player) and stack:get_count() or 0
	end,
	allow_metadata_inventory_move = function(pos, _, _, _, _, count, player)
		return allowed(pos, player) and count or 0
	end,
	on_blast = function(pos)
		local drops = {}
		for _, st in ipairs(inv_of(pos):get_list("main")) do
			if not st:is_empty() then
				drops[#drops + 1] = st:to_string()
			end
		end
		drops[#drops + 1] = BASE
		core.remove_node(pos)
		return drops
	end,
	on_destruct = function(pos)
		viewers[core.hash_node_position(pos)] = nil
	end,
}

local base = core.registered_nodes[BASE]
local groups = table.copy(base.groups)
groups.cb_barrel = 1
local over = table.copy(common)
over.groups = groups
core.override_item(BASE, over)

local open = table.copy(common)
local ogroups = table.copy(groups)
ogroups.not_in_creative_inventory = 1
open.description, open.sounds, open.paramtype2, open.groups = base.description, base.sounds, base.paramtype2, ogroups
open.tiles = { tex("barrel_top_open"), tex("barrel_bottom"), tex("barrel_side"), }
open.drop, open._cb_jobsite_of = BASE, BASE
open.is_ground_content = false
core.register_node(":" .. OPEN, open)

if rawget(_G, "hopper") and hopper.add_container then
	hopper:add_container({
		{ "top", "group:cb_barrel", "main", },
		{ "bottom", "group:cb_barrel", "main", },
		{ "side", "group:cb_barrel", "main", },
	})
end
