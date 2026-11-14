-- Statue entity and the registry of loaded pedestals.
--
-- Statues are not saved with the map (static_save = false): they vanish when
-- their mapblock unloads and an LBM re-creates them when it loads again.
-- Statues have no on_step, so a loaded statue costs nothing per server step.

local S = player_pedestal.S
local A = player_pedestal.appearance
local R = player_pedestal.ranking

local ENTITY = "player_pedestal:statue"
local TAG = "player_pedestal:nametag"
-- pos hash -> {pos, kind, stat, objs = {slot = statue}, tags = {slot = nametag object},
--              shown = {slot = {name, value}}, version}
local active = {}
player_pedestal.active = active

local show_values = minetest.settings:get_bool("player_pedestal.show_values", true)
local interval = tonumber(minetest.settings:get("player_pedestal.update_interval")) or 30
interval = math.max(5, interval)
local tag_dist = tonumber(minetest.settings:get("player_pedestal.nametag_distance")) or 8

minetest.register_entity(ENTITY, {
	initial_properties = {
		visual = "mesh",
		mesh = "character.b3d",
		textures = { "character.png" },
		visual_size = { x = 1, y = 1, z = 1 },
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		backface_culling = false,
		makes_footstep_sound = false,
		collisionbox = { -0.3, 0, -0.3, 0.3, 1.7, 0.3 },
		selectionbox = { -0.3, 0, -0.3, 0.3, 1.7, 0.3, rotate = false },
		show_on_minimap = false,
		shaded = true,
	},
	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,
	on_deactivate = function(self)
		local e = self._pp_hash and active[self._pp_hash]
		if e and e.objs[self._pp_slot] == self.object then
			e.objs[self._pp_slot] = nil
		end
	end,
	on_punch = function()
		return true
	end,
})

-- Name above a statue. Engine nametags have no distance limit, so the name
-- lives on its own invisible entity whose observers (the players allowed to
-- see it) are refreshed once a second to "players within nametag_distance".
-- The statue itself stays visible to everyone.
minetest.register_entity(TAG, {
	initial_properties = {
		visual = "sprite",
		textures = { "blank.png" },
		visual_size = { x = 0.01, y = 0.01 },
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		collisionbox = { -0.05, 0, -0.05, 0.05, 0.05, 0.05 },
		selectionbox = { -0.05, 0, -0.05, 0.05, 0.05, 0.05 },
		nametag_color = "#ffffff",
		nametag_bgcolor = "#00000080",
		show_on_minimap = false,
	},
	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,
	on_deactivate = function(self)
		local e = self._pp_hash and active[self._pp_hash]
		if e and e.tags[self._pp_slot] == self.object then
			e.tags[self._pp_slot] = nil
		end
	end,
	on_punch = function()
		return true
	end,
})

local function update_observers(tag, players)
	local pos = tag:get_pos()
	if not pos then
		return
	end
	local names = {}
	for _, p in ipairs(players) do
		if vector.distance(p.pos, pos) <= tag_dist then
			names[#names + 1] = p.name
		end
	end
	table.sort(names)
	local key = table.concat(names, ",")
	local le = tag:get_luaentity()
	if le and le._obs ~= key then
		le._obs = key
		local set = {}
		for _, n in ipairs(names) do
			set[n] = true
		end
		tag:set_observers(set)
	end
end

local function player_list()
	local list = {}
	for _, p in ipairs(minetest.get_connected_players()) do
		list[#list + 1] = { name = p:get_player_name(), pos = p:get_pos() }
	end
	return list
end

-- Facing helpers. Pedestals use paramtype2 "4dir": the front faces the player
-- who placed it, statues look the same way.
local function front_dir(param2)
	return vector.multiply(minetest.fourdir_to_dir(param2 % 4), -1)
end

local function apply_look(obj, name, pose)
	local a = A.get(name)
	obj:set_properties({
		mesh = a.mesh,
		textures = a.textures,
		visual_size = a.visual_size or { x = 1, y = 1, z = 1 },
	})
	player_pedestal.apply_pose(obj, pose)
end

local SIT_POSE = 8

-- Create / move / update / remove the name above slot `slot`.
local function set_tag(e, slot, feet, pose, text)
	local tag = e.tags[slot]
	if tag and not tag:is_valid() then
		tag, e.tags[slot] = nil, nil
	end
	if not text or text == "" then
		if tag then
			tag:remove()
			e.tags[slot] = nil
		end
		return
	end
	local pos = vector.offset(feet, 0, pose == SIT_POSE and 1.4 or 2.0, 0)
	if not tag then
		tag = minetest.add_entity(pos, TAG)
		if not tag then
			return
		end
		local le = tag:get_luaentity()
		le._pp_hash = minetest.hash_node_position(e.pos)
		le._pp_slot = slot
		e.tags[slot] = tag
	else
		tag:set_pos(pos)
	end
	tag:set_properties({ nametag = text })
	update_observers(tag, player_list())
end

local function spawn_obj(e, slot, pos, yaw, name, pose, nametag)
	local obj = minetest.add_entity(pos, ENTITY)
	if not obj then
		return
	end
	local le = obj:get_luaentity()
	le._pp_hash = minetest.hash_node_position(e.pos)
	le._pp_slot = slot
	le._pp_name = name
	obj:set_yaw(yaw)
	apply_look(obj, name, pose)
	e.objs[slot] = obj
	set_tag(e, slot, pos, pose, nametag)
	return obj
end

local function clear(e)
	for _, list in ipairs({ e.objs, e.tags }) do
		for slot, obj in pairs(list) do
			if obj:is_valid() then
				obj:remove()
			end
			list[slot] = nil
		end
	end
	e.shown = {}
end

function player_pedestal.remove_statues(pos)
	local h = minetest.hash_node_position(pos)
	local e = active[h]
	if e then
		clear(e)
		active[h] = nil
	end
	-- leftovers (e.g. after a crash of the registry): statues bound to this pos
	for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 2.5)) do
		local le = obj:get_luaentity()
		if le and (le.name == ENTITY or le.name == TAG) and le._pp_hash == h then
			obj:remove()
		end
	end
end

---------------------------------------------------------------------------
-- Single pedestal

function player_pedestal.spawn_single(pos, node)
	node = node or minetest.get_node(pos)
	player_pedestal.remove_statues(pos)
	local meta = minetest.get_meta(pos)
	local name = meta:get_string("player")
	local h = minetest.hash_node_position(pos)
	local e = { pos = vector.copy(pos), kind = "single", objs = {}, tags = {}, shown = {} }
	active[h] = e
	-- no such player in the auth database -> empty pedestal
	if name == "" or not minetest.player_exists(name) then
		return
	end
	local pose = meta:get_int("pose")
	if pose < 1 then
		pose = 1
	end
	local nametag = meta:get_int("hide_tag") == 1 and "" or name
	local yaw = minetest.dir_to_yaw(front_dir(node.param2))
	spawn_obj(e, 1, vector.offset(pos, 0, 0.5, 0), yaw, name, pose, nametag)
	e.shown[1] = { name = name }
end

---------------------------------------------------------------------------
-- Ranking podium: slot 1 in the middle (highest), 2 on the viewer's left,
-- 3 on the viewer's right. Heights match the node box in nodes.lua.

player_pedestal.PODIUM_TOP = { [1] = 0.5, [2] = 0.125, [3] = -0.125 }

local function slot_pos(pos, param2, slot)
	local d = minetest.fourdir_to_dir(param2 % 4)       -- from viewer into the podium
	local right = vector.new(d.z, 0, -d.x)                -- viewer's right
	local side = slot == 2 and -1 or slot == 3 and 1 or 0
	return vector.offset(vector.add(pos, vector.multiply(right, side)), 0, player_pedestal.PODIUM_TOP[slot], 0)
end
player_pedestal.podium_slot_pos = slot_pos

local function fmt_tag(slot, entry, def)
	local tag = slot .. ". " .. entry.name
	if show_values then
		tag = tag .. "\n" .. entry.value .. " " .. def.unit
	end
	return tag
end

local function podium_infotext(stat, top)
	local def = R.sources[stat]
	local lines = { S("Top 3: @1", def.label) }
	for i = 1, 3 do
		local t = top[i]
		lines[#lines + 1] = i .. ". " .. (t and (t.name .. " — " .. t.value .. " " .. def.unit) or "—")
	end
	return table.concat(lines, "\n")
end

-- Bring a podium in line with the current top-3. `force` re-rolls every pose.
local function sync_podium(e, force)
	local node = minetest.get_node(e.pos)
	local def = R.sources[e.stat]
	if not def then
		return
	end
	local top = R.get_top3(e.stat)
	local yaw = minetest.dir_to_yaw(front_dir(node.param2))
	local changed = force
	for slot = 1, 3 do
		local want, shown, obj = top[slot], e.shown[slot], e.objs[slot]
		if obj and not obj:is_valid() then
			obj, e.objs[slot] = nil, nil
		end
		if not want then
			if obj then
				obj:remove()
				e.objs[slot] = nil
			end
			set_tag(e, slot, nil, nil, nil)
			e.shown[slot] = nil
		elseif force or not obj or not shown or shown.name ~= want.name then
			-- new player on this place: fresh random pose
			local pose = player_pedestal.random_pose()
			if obj then
				apply_look(obj, want.name, pose)
				obj:set_yaw(yaw)
				set_tag(e, slot, slot_pos(e.pos, node.param2, slot), pose, fmt_tag(slot, want, def))
			else
				spawn_obj(e, slot, slot_pos(e.pos, node.param2, slot), yaw, want.name, pose, fmt_tag(slot, want, def))
			end
			e.shown[slot] = { name = want.name, value = want.value }
			changed = true
		elseif shown.value ~= want.value then
			local tag = e.tags[slot]
			if show_values and tag and tag:is_valid() then
				tag:set_properties({ nametag = fmt_tag(slot, want, def) })
			end
			shown.value = want.value
			changed = true
		end
	end
	if changed then
		minetest.get_meta(e.pos):set_string("infotext", podium_infotext(e.stat, top))
	end
	e.version = R.version[e.stat]
end

function player_pedestal.spawn_podium(pos, stat)
	player_pedestal.remove_statues(pos)
	local h = minetest.hash_node_position(pos)
	local e = { pos = vector.copy(pos), kind = "podium", stat = stat, objs = {}, tags = {}, shown = {} }
	active[h] = e
	sync_podium(e, true)
end

function player_pedestal.refresh_podium(pos)
	local e = active[minetest.hash_node_position(pos)]
	if e and e.kind == "podium" then
		sync_podium(e, true)
	end
end

---------------------------------------------------------------------------
-- Periodic check (only does work while podiums are loaded and changed).

local function tick()
	for h, e in pairs(active) do
		if minetest.compare_block_status(e.pos, "active") == false then
			-- mapblock went away; its statues are gone with it
			active[h] = nil
		elseif e.kind == "podium" and e.version ~= R.version[e.stat] then
			sync_podium(e, false)
		end
	end
	minetest.after(interval, tick)
end
minetest.after(interval, tick)

-- Once a second: who may see which name (only while names are loaded).
local function tag_tick()
	local players
	for _, e in pairs(active) do
		for _, tag in pairs(e.tags) do
			if tag:is_valid() then
				players = players or player_list()
				update_observers(tag, players)
			end
		end
	end
	minetest.after(1, tag_tick)
end
minetest.after(1, tag_tick)

-- A player's look changed: update their loaded statues right away.
A.register_on_change(function(name)
	for _, e in pairs(active) do
		for slot, obj in pairs(e.objs) do
			local shown = e.shown[slot]
			if shown and shown.name == name and obj:is_valid() then
				local a = A.get(name)
				obj:set_properties({ mesh = a.mesh, textures = a.textures, visual_size = a.visual_size })
			end
		end
	end
end)

function player_pedestal.respawn_all()
	local list = {}
	for _, e in pairs(active) do
		list[#list + 1] = e
	end
	for _, e in ipairs(list) do
		local node = minetest.get_node(e.pos)
		local def = minetest.registered_nodes[node.name]
		if def and def._pp_spawn then
			def._pp_spawn(e.pos, node)
		end
	end
	return #list
end
