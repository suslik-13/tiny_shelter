-- End portal: twelve frames with eyes of ender around a 3x3 hole open it, and
-- stepping in leads to the End's entry platform. The exit portal in the middle
-- of the main island opens after the dragon dies (plan 4) and leads home.
local S = cb_portals.S
local the_end = cb_dimensions.the_end
local NODE = "cb_portals:end_portal"
local FRAME, FRAME_EYE = "cb_blocks:end_portal_frame", "cb_blocks:end_portal_frame_eye"
local TICK, COOLDOWN, MESSAGE_EVERY = 0.5, 3, 5
local storage = core.get_mod_storage()
cb_portals.END_NODE = NODE

core.register_node(NODE, {
	description = S("End Portal"),
	drawtype = "nodebox",
	node_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 4 / 16, 0.5, }, },
	tiles = { "cb_portals_end_portal.png", },
	paramtype = "light",
	sunlight_propagates = true,
	light_source = core.LIGHT_MAX,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = false,
	is_ground_content = false,
	drop = "",
	groups = { not_in_creative_inventory = 1, },
	on_blast = function()
	end,
})

local function ring(c)
	local list = {}
	for k = -1, 1 do
		list[#list + 1] = vector.offset(c, 2, 0, k)
		list[#list + 1] = vector.offset(c, -2, 0, k)
		list[#list + 1] = vector.offset(c, k, 0, 2)
		list[#list + 1] = vector.offset(c, k, 0, -2)
	end
	return list
end

-- Opens the portal of a complete ring of frames with eyes that holds pos.
function cb_portals.end_try_open(pos)
	for k = -1, 1 do
		for _, c in ipairs({ vector.offset(pos, -2, 0, k), vector.offset(pos, 2, 0, k),
			vector.offset(pos, k, 0, -2), vector.offset(pos, k, 0, 2), }) do
			local complete = true
			for _, p in ipairs(ring(c)) do
				if core.get_node(p).name ~= FRAME_EYE then
					complete = false
					break
				end
			end
			if complete then
				core.sound_play("cb_portals_end_portal_open", { pos = c, gain = 1.2, max_hear_distance = 64, }, true)
				for dx = -1, 1 do
					for dz = -1, 1 do
						local q = vector.offset(c, dx, 0, dz)
						if core.get_node(q).name == "air" then
							core.set_node(q, { name = NODE, })
						end
					end
				end
				return c
			end
		end
	end
end

core.override_item(FRAME, {
	on_rightclick = function(pos, node, clicker, itemstack)
		if itemstack:get_name() ~= "cb_items:ender_eye" then
			return itemstack
		end
		local name = clicker and clicker:get_player_name() or ""
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return itemstack
		end
		core.swap_node(pos, { name = FRAME_EYE, param2 = node.param2, })
		core.sound_play("cb_portals_eye_place", { pos = pos, max_hear_distance = 16, }, true)
		if not core.is_creative_enabled(name) then
			itemstack:take_item()
		end
		cb_portals.end_try_open(pos)
		return itemstack
	end,
})

function cb_portals.end_entry(pocket)
	return vector.offset(the_end.geometry(pocket).platform, 0, 1, 0)
end

function cb_portals.end_exit_is_open()
	return storage:get_int("end_exit_open") == 1
end

function cb_portals.end_open_exit()
	local pocket = cb_dimensions.get("end")
	if not pocket or pocket.state ~= "ready" then
		return false
	end
	local g = the_end.geometry(pocket)
	core.load_area(vector.offset(g.centre, -4, 0, -4), vector.offset(g.centre, 4, 8, 4))
	for _, p in ipairs(the_end.exit_portal_nodes(g)) do
		core.set_node(p, { name = NODE, })
	end
	storage:set_int("end_exit_open", 1)
	return true
end

function cb_portals.end_close_exit()
	storage:set_int("end_exit_open", 0)
	local pocket = cb_dimensions.get("end")
	if not pocket or pocket.state ~= "ready" then
		return false
	end
	local g = the_end.geometry(pocket)
	core.load_area(vector.offset(g.centre, -4, 0, -4), vector.offset(g.centre, 4, 8, 4))
	for _, p in ipairs(the_end.exit_portal_nodes(g)) do
		if core.get_node(p).name == NODE then
			core.set_node(p, { name = "air", })
		end
	end
	return true
end

local players = {}

function cb_portals.end_tick(player, dtime)
	local name = player:get_player_name()
	local st = players[name]
	if not st then
		st = { cooldown = 0, quiet = 0, }
		players[name] = st
	end
	st.cooldown = st.cooldown - dtime
	st.quiet = st.quiet - dtime
	if st.cooldown > 0 then
		return false
	end
	local pos = player:get_pos()
	if not pos or player:get_hp() <= 0 then
		return false
	end
	local feet = cb_blocks.node_at(pos)
	if core.get_node(feet).name ~= NODE then
		return false
	end
	local pocket = cb_dimensions.get("end")
	if pocket and cb_core.inside(feet, pocket.minp, pocket.maxp) then
		cb_portals.teleport(player, cb_portals.respawn_pos(name))
	elseif pocket and pocket.state == "ready" then
		local entry = cb_portals.end_entry(pocket)
		core.load_area(vector.offset(entry, -3, -2, -3), vector.offset(entry, 3, 3, 3))
		cb_portals.teleport(player, vector.offset(entry, 0, -0.5, 0))
	else
		if st.quiet <= 0 then
			core.chat_send_player(name, S("The End is not open yet."))
			st.quiet = MESSAGE_EVERY
		end
		return false
	end
	st.cooldown = COOLDOWN
	return true
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < TICK then
		return
	end
	local dt = timer
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		cb_portals.end_tick(player, dt)
	end
end)

core.register_on_leaveplayer(function(player)
	players[player:get_player_name()] = nil
end)
