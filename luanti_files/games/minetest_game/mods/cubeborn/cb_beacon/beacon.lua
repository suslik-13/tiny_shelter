-- Beacon (spec cycle 10): a pyramid of 1-4 levels of mineral blocks under it,
-- the sky open above; paid once with an ingot or a gem, it gives the chosen
-- effects to players within 20/30/40/50 nodes every 4 s for 11 s (Bedrock
-- 9 + 2). A node timer only: no globalstep, players found by radius. The beam
-- is one unsaved entity, made again by the timer.
local S = cb_beacon.S
local B = cb_beacon
local E = cb_core.effects
B.NODE, B.BEAM = "cb_beacon:beacon", "cb_beacon:beam"
B.PERIOD, B.DURATION, B.SKY = 4, 11, 64

B.BASE = {}
for _, n in ipairs({ "default:steelblock", "default:goldblock", "default:diamondblock", "default:mese",
		B.EMERALD_BLOCK, B.NETHERITE_BLOCK, "moreores:silver_block", "moreores:mithril_block", }) do
	if core.registered_nodes[n] then
		B.BASE[n] = true
	end
end

B.PAYMENT = {}
for _, n in ipairs({ "default:steel_ingot", "default:gold_ingot", "default:diamond", "cb_items:emerald",
		"cb_blocks:netherite_ingot", }) do
	if core.registered_items[n] then
		B.PAYMENT[n] = true
	end
end

-- Primary effects and the pyramid level they need (Minecraft's table).
B.PRIMARY = { { "speed", 1, }, { "haste", 1, }, { "resistance", 2, }, { "jump_boost", 2, }, { "strength", 3, }, }
local NEED = {}
for _, p in ipairs(B.PRIMARY) do
	NEED[p[1]] = p[2]
end

-- Pyramid levels under pos: each full square ring of base blocks counts.
function B.level(pos)
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map(vector.offset(pos, -4, -4, -4), vector.offset(pos, 4, -1, 4))
	local va, data = VoxelArea(e1, e2), vm:get_data()
	local base = {}
	for n in pairs(B.BASE) do
		base[core.get_content_id(n)] = true
	end
	for l = 1, 4 do
		local y = pos.y - l
		for x = pos.x - l, pos.x + l do
			for z = pos.z - l, pos.z + l do
				if not base[data[va:index(x, y, z)]] then
					return l - 1
				end
			end
		end
	end
	return 4
end

-- Height of the open column above (0 = blocked right above); light-passing
-- nodes (air, glass, panes) let the beam through, an unloaded block ends it.
function B.sky(pos)
	local vm = VoxelManip()
	local top = vector.offset(pos, 0, B.SKY, 0)
	local e1, e2 = vm:read_from_map(vector.offset(pos, 0, 1, 0), top)
	local va, data = VoxelArea(e1, e2), vm:get_data()
	local ignore = core.CONTENT_IGNORE
	for y = pos.y + 1, top.y do
		local cid = data[va:index(pos.x, y, pos.z)]
		if cid == ignore then
			return y - pos.y - 1
		end
		local def = core.registered_nodes[core.get_name_from_content_id(cid)]
		if not (def and def.sunlight_propagates) then
			return y - pos.y - 1
		end
	end
	return B.SKY
end

function B.sky_clear(pos)
	return B.sky(pos) > 0
end

core.register_entity(B.BEAM, {
	initial_properties = {
		physical = false, collide_with_objects = false, pointable = false, static_save = false,
		visual = "cube", visual_size = { x = 0.3, y = 1, z = 0.3, }, glow = 14, use_texture_alpha = true,
		textures = { "blank.png", "blank.png", "[fill:1x1:#d6f7ffb0", "[fill:1x1:#d6f7ffb0", "[fill:1x1:#d6f7ffb0",
			"[fill:1x1:#d6f7ffb0", },
	},
})

local beam_of

-- The beam is drawn from the beacon upwards: a cube entity scales around its
-- centre, so the centre goes half its height up.
local function place_beam(pos, height)
	local obj = beam_of(pos)
	if height <= 0 then
		if obj then
			obj:remove()
		end
		return
	end
	if not obj then
		obj = core.add_entity(vector.offset(pos, 0, 1, 0), B.BEAM)
		if not obj then
			return
		end
	end
	obj:set_properties({ visual_size = { x = 0.3, y = height, z = 0.3, }, })
	obj:set_pos(vector.offset(pos, 0, 0.5 + height / 2, 0))
end
B.place_beam = place_beam

-- The beam of the beacon at pos: its centre is up the column.
function beam_of(pos)
	for _, obj in ipairs(core.get_objects_inside_radius(vector.offset(pos, 0, B.SKY / 2 + 1, 0), B.SKY / 2 + 2)) do
		local e = obj:get_luaentity()
		local p = obj:get_pos()
		if e and e.name == B.BEAM and p and math.abs(p.x - pos.x) < 0.1 and math.abs(p.z - pos.z) < 0.1 then
			return obj
		end
	end
end
B.beam_of = beam_of

-- Minecraft's beacon box: range sideways, from range below up to the sky.
function B.in_range(pos, range, p)
	return math.abs(p.x - pos.x) <= range and math.abs(p.z - pos.z) <= range and p.y >= pos.y - range
end

function B.players_in(pos, range)
	local list = {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, range * 1.75)) do
		if obj:is_player() and B.in_range(pos, range, obj:get_pos()) then
			list[#list + 1] = obj
		end
	end
	return list
end

-- One beacon step: true keeps the timer running.
function B.tick(pos)
	local meta = core.get_meta(pos)
	local level = B.level(pos)
	local height = level > 0 and B.sky(pos) or 0
	meta:set_int("level", level)
	place_beam(pos, height)
	local primary, secondary = meta:get_string("primary"), meta:get_string("secondary")
	if level == 0 or height <= 0 or primary == "" or (NEED[primary] or 9) > level then
		return true
	end
	local range = 10 + 10 * level
	for _, player in ipairs(B.players_in(pos, range)) do
		if level >= 4 and secondary == primary then
			E.apply(player, primary, 2, B.DURATION)
		else
			E.apply(player, primary, 1, B.DURATION)
			if level >= 4 and secondary == "regeneration" then
				E.apply(player, "regeneration", 1, B.DURATION)
			end
		end
	end
	return true
end

-- Formspec: the payment slot, the primary effects open at this level and,
-- at level 4, the secondary (regeneration or the primary at level II).
local function fs_pos(pos)
	return pos.x .. "," .. pos.y .. "," .. pos.z
end

function B.formspec(pos)
	local meta = core.get_meta(pos)
	local level = B.level(pos)
	local primary, secondary = meta:get_string("primary"), meta:get_string("secondary")
	local loc = "nodemeta:" .. fs_pos(pos)
	local f = { "formspec_version[4]size[10.5,10.6]",
		"label[0.4,0.5;" .. core.formspec_escape(S("Beacon, pyramid level @1 of 4", level)) .. "]",
		"label[0.4,1.1;" .. core.formspec_escape(S("Primary power")) .. "]", }
	local y = 1.5
	for _, p in ipairs(B.PRIMARY) do
		local name, need = p[1], p[2]
		local label = E.defs[name].description .. (primary == name and " *" or "")
		if level >= need then
			f[#f + 1] = ("button[0.4,%.1f;4,0.6;primary_%s;%s]"):format(y, name, core.formspec_escape(label))
		else
			f[#f + 1] = ("label[0.5,%.1f;%s]"):format(y + 0.3,
				core.formspec_escape(S("@1 (level @2)", E.defs[name].description, need)))
		end
		y = y + 0.7
	end
	f[#f + 1] = "label[5.4,1.1;" .. core.formspec_escape(S("Secondary power (level 4)")) .. "]"
	if level >= 4 then
		f[#f + 1] = "button[5.4,1.5;4.6,0.6;secondary_regeneration;" ..
			core.formspec_escape(E.defs.regeneration.description .. (secondary == "regeneration" and " *" or "")) .. "]"
		if primary ~= "" then
			f[#f + 1] = "button[5.4,2.2;4.6,0.6;secondary_primary;" ..
				core.formspec_escape(S("@1 II", E.defs[primary].description) .. (secondary == primary and " *" or "")) .. "]"
		end
	end
	f[#f + 1] = "label[5.4,3.3;" .. core.formspec_escape(S("Pay with an iron or gold ingot, a diamond, an emerald or a netherite ingot")) .. "]"
	f[#f + 1] = "list[" .. loc .. ";payment;5.4,3.7;1,1;]"
	f[#f + 1] = "button[6.7,3.8;3.3,0.8;confirm;" .. core.formspec_escape(S("Confirm")) .. "]"
	f[#f + 1] = "list[current_player;main;0.4,5.4;8,4;]listring[]"
	return table.concat(f)
end

local pending = {} -- player -> { pos, primary, secondary } chosen, not yet paid

-- Pays and applies the choice; returns ok, message.
function B.confirm(pos, choice)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack("payment", 1)
	if stack:is_empty() or not B.PAYMENT[stack:get_name()] then
		return false, S("Put an iron or gold ingot, a diamond, an emerald or a netherite ingot in the slot.")
	end
	local level = B.level(pos)
	if not choice.primary or (NEED[choice.primary] or 9) > level then
		return false, S("Choose a primary power first.")
	end
	stack:take_item(1)
	inv:set_stack("payment", 1, stack)
	meta:set_string("primary", choice.primary)
	meta:set_string("secondary", level >= 4 and (choice.secondary or "") or "")
	B.tick(pos)
	return true, S("The beacon is set.")
end

local function show(name, pos)
	core.show_formspec(name, "cb_beacon:" .. fs_pos(pos), B.formspec(pos))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	local p = formname:match("^cb_beacon:(.+)$")
	if not p then
		return false
	end
	local pos = core.string_to_pos("(" .. p .. ")")
	local name = player:get_player_name()
	if not pos or core.get_node(pos).name ~= B.NODE or core.is_protected(pos, name) then
		pending[name] = nil
		return true
	end
	local meta = core.get_meta(pos)
	local c = pending[name] or { primary = meta:get_string("primary"), secondary = meta:get_string("secondary"), }
	if c.primary == "" then
		c.primary = nil
	end
	for k in pairs(fields) do
		local prim = k:match("^primary_(.+)$")
		if prim and NEED[prim] then
			c.primary = prim
		elseif k == "secondary_regeneration" then
			c.secondary = "regeneration"
		elseif k == "secondary_primary" then
			c.secondary = c.primary
		end
	end
	pending[name] = c
	if fields.confirm then
		local _, msg = B.confirm(pos, c)
		core.chat_send_player(name, msg)
		pending[name] = nil
	end
	if fields.quit then
		pending[name] = nil
		return true
	end
	show(name, pos)
	return true
end)

core.register_node(B.NODE, {
	description = S("Beacon") .. "\n" .. S("On a pyramid of mineral blocks under the open sky it gives effects"),
	drawtype = "mesh", mesh = "cb_beacon_beacon.b3d", tiles = { "cb_beacon_beacon.png", },
	use_texture_alpha = "clip", paramtype = "light", sunlight_propagates = true,
	collision_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5, }, },
	selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5, }, },
	light_source = 14, is_ground_content = false,
	groups = { cracky = 3, oddly_breakable_by_hand = 2, },
	sounds = default.node_sound_glass_defaults(),
	on_construct = function(pos)
		core.get_meta(pos):get_inventory():set_size("payment", 1)
		core.get_node_timer(pos):start(B.PERIOD)
	end,
	on_rightclick = function(pos, _, clicker)
		if clicker and clicker:is_player() and not core.is_protected(pos, clicker:get_player_name()) then
			show(clicker:get_player_name(), pos)
		end
	end,
	on_timer = function(pos)
		return B.tick(pos)
	end,
	on_destruct = function(pos)
		place_beam(pos, 0)
	end,
	can_dig = function(pos)
		return core.get_meta(pos):get_inventory():is_empty("payment")
	end,
	allow_metadata_inventory_put = function(pos, _, _, stack, player)
		if core.is_protected(pos, player:get_player_name()) or not B.PAYMENT[stack:get_name()] then
			return 0
		end
		return 1
	end,
	allow_metadata_inventory_take = function(pos, _, _, stack, player)
		return core.is_protected(pos, player:get_player_name()) and 0 or stack:get_count()
	end,
})

core.register_lbm({
	label = "Cubeborn beacon timers",
	name = "cb_beacon:restart",
	nodenames = { B.NODE, },
	run_at_every_load = true,
	action = function(pos)
		local t = core.get_node_timer(pos)
		if not t:is_started() then
			t:start(B.PERIOD)
		end
	end,
})

core.register_craft({
	output = B.NODE,
	recipe = {
		{ "default:glass", "default:glass", "default:glass", },
		{ "default:glass", "cb_mobs_nether:nether_star", "default:glass", },
		{ "default:obsidian", "default:obsidian", "default:obsidian", },
	},
})
