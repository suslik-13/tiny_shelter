-- Nodes: the player pedestal and the ranking podiums (+ invisible side fillers).
local S = player_pedestal.S
local FS = function(...) return minetest.formspec_escape(S(...)) end
local R = player_pedestal.ranking
local is_admin = player_pedestal.is_admin

local sounds = minetest.global_exists("default") and default.node_sound_stone_defaults
	and default.node_sound_stone_defaults() or nil

local function deny(player)
	if player and player.is_player and player:is_player() then
		minetest.chat_send_player(player:get_player_name(),
			minetest.colorize("#ff8080", S("Only administrators can do this.")))
	end
end

-- Admin-only placement.
local function admin_place(itemstack, placer, pointed_thing)
	if not is_admin(placer) then
		deny(placer)
		return itemstack
	end
	return minetest.item_place(itemstack, placer, pointed_thing)
end

local function admin_can_dig(_, player)
	if is_admin(player) then
		return true
	end
	deny(player)
	return false
end

local common = {
	paramtype = "light",
	paramtype2 = "4dir",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = { cracky = 1, level = 2, pedestal = 1 },
	sounds = sounds,
	on_place = admin_place,
	can_dig = admin_can_dig,
	on_blast = function() end,       -- TNT-proof
}

local function merge(a, b)
	local t = table.copy(a)
	for k, v in pairs(b) do
		t[k] = v
	end
	return t
end

---------------------------------------------------------------------------
-- Single pedestal with a nameplate

local context = {}  -- player name -> pos of the pedestal being edited
minetest.register_on_leaveplayer(function(p) context[p:get_player_name()] = nil end)

local function pose_list()
	local t = {}
	for i, p in ipairs(player_pedestal.poses) do
		t[i] = minetest.formspec_escape(i .. ". " .. p.name)
	end
	return table.concat(t, ",")
end

local function show_edit(pname, pos)
	local meta = minetest.get_meta(pos)
	local pose = math.max(1, meta:get_int("pose"))
	local fs = "formspec_version[4]size[8,6.6]" ..
		"label[0.4,0.6;" .. FS("Player pedestal") .. "]" ..
		"field[0.4,1.5;7.2,0.8;player;" .. FS("Player name (nameplate)") .. ";" ..
			minetest.formspec_escape(meta:get_string("player")) .. "]" ..
		"label[0.4,2.75;" .. FS("Pose") .. "]" ..
		"dropdown[0.4,3;7.2,0.8;pose;" .. pose_list() .. ";" .. pose .. ";true]" ..
		"checkbox[0.4,4.25;hide_tag;" .. FS("Hide name above the statue") .. ";" ..
			(meta:get_int("hide_tag") == 1 and "true" or "false") .. "]" ..
		"button[0.4,5.3;2.3,0.9;rotate;" .. FS("Rotate") .. "]" ..
		"button[2.85,5.3;2.3,0.9;clear;" .. FS("Clear") .. "]" ..
		"button_exit[5.3,5.3;2.3,0.9;save;" .. FS("Save") .. "]"
	context[pname] = vector.copy(pos)
	minetest.show_formspec(pname, "player_pedestal:edit", fs)
end

minetest.register_node("player_pedestal:pedestal", merge(common, {
	description = S("Player Pedestal") .. "\n" .. minetest.colorize("#aaaaaa", S("Admin only")),
	drawtype = "nodebox",
	tiles = {
		"player_pedestal_marble_top.png", "player_pedestal_marble_top.png",
		"player_pedestal_marble.png", "player_pedestal_marble.png",
		"player_pedestal_marble.png", "player_pedestal_front.png",
	},
	node_box = { type = "fixed", fixed = {
		{ -0.5, -0.5, -0.5, 0.5, -0.3125, 0.5 },        -- base
		{ -0.375, -0.3125, -0.375, 0.375, 0.3125, 0.375 }, -- column
		{ -0.5, 0.3125, -0.5, 0.5, 0.5, 0.5 },          -- top
	} },
	selection_box = { type = "regular" },
	collision_box = { type = "regular" },
	on_construct = function(pos)
		minetest.get_meta(pos):set_string("infotext", S("Player pedestal (empty)"))
		player_pedestal.spawn_single(pos)
	end,
	on_destruct = function(pos)
		player_pedestal.remove_statues(pos)
	end,
	on_rightclick = function(pos, _, clicker)
		if is_admin(clicker) then
			show_edit(clicker:get_player_name(), pos)
		end
	end,
	on_rotate = function(pos, node, user, mode, new_param2)
		if not is_admin(user) then
			return false
		end
		node.param2 = new_param2 % 4
		minetest.swap_node(pos, node)
		player_pedestal.spawn_single(pos, node)
		return true
	end,
	_pp_spawn = function(pos, node)
		player_pedestal.spawn_single(pos, node)
	end,
}))

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "player_pedestal:edit" then
		return
	end
	local pname = player:get_player_name()
	local pos = context[pname]
	if not pos or not is_admin(player) then
		return true
	end
	local node = minetest.get_node(pos)
	if node.name ~= "player_pedestal:pedestal" then
		context[pname] = nil
		return true
	end
	local meta = minetest.get_meta(pos)
	if fields.quit and not fields.save then
		context[pname] = nil
		return true
	end
	if fields.hide_tag then
		meta:set_int("hide_tag", fields.hide_tag == "true" and 1 or 0)
	end
	if fields.rotate then
		node.param2 = (node.param2 + 1) % 4
		minetest.swap_node(pos, node)
		player_pedestal.spawn_single(pos, node)
		show_edit(pname, pos)
		return true
	end
	if fields.clear then
		meta:set_string("player", "")
		meta:set_string("infotext", S("Player pedestal (empty)"))
		player_pedestal.spawn_single(pos, node)
		show_edit(pname, pos)
		return true
	end
	if fields.save or fields.key_enter_field then
		local target = (fields.player or ""):gsub("^%s+", ""):gsub("%s+$", "")
		local pose = tonumber(fields.pose) or 1
		pose = math.max(1, math.min(#player_pedestal.poses, math.floor(pose)))
		meta:set_int("pose", pose)
		if target == "" then
			meta:set_string("player", "")
			meta:set_string("infotext", S("Player pedestal (empty)"))
		elseif not target:match("^[%w_%-]+$") or #target > 20 or not minetest.player_exists(target) then
			-- unknown nickname: the pedestal stays empty
			meta:set_string("player", "")
			meta:set_string("infotext", S("Player pedestal (empty)"))
			minetest.chat_send_player(pname, minetest.colorize("#ff8080",
				S("Unknown player: @1", target) .. " — " .. S("the pedestal stays empty.")))
		else
			meta:set_string("player", target)
			meta:set_string("infotext", S("Statue of @1", target))
			if not player_pedestal.appearance.has(target) and not minetest.get_player_by_name(target) then
				minetest.chat_send_player(pname, S("@1 has not joined since the mod was installed: the default skin is shown until their next login.", target))
			end
		end
		player_pedestal.spawn_single(pos, node)
		minetest.log("action", ("[player_pedestal] %s set pedestal at %s to '%s', pose %d")
			:format(pname, minetest.pos_to_string(pos), target, pose))
		if fields.key_enter_field then
			show_edit(pname, pos)
		end
	end
	return true
end)

---------------------------------------------------------------------------
-- Ranking podiums. Registered only for statistics that exist on this server.

-- Invisible, indestructible side parts that give the wings their collision
-- and keep other blocks (and liquids) out of the podium's space.
local function register_filler(slot)
	local top = player_pedestal.PODIUM_TOP[slot]
	minetest.register_node("player_pedestal:podium_filler_" .. slot, {
		description = "Podium filler",
		drawtype = "airlike",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = true,
		pointable = false,
		diggable = false,
		buildable_to = false,
		floodable = false,
		is_ground_content = false,
		drop = "",
		collision_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, top, 0.5 } },
		groups = { not_in_creative_inventory = 1 },
		on_blast = function() end,
		can_dig = function() return false end,
	})
end

local function wing_positions(pos, param2)
	local d = minetest.fourdir_to_dir(param2 % 4)
	local right = vector.new(d.z, 0, -d.x)
	return vector.subtract(pos, right), vector.add(pos, right)   -- slot 2 (left), slot 3 (right)
end

local podium_box = {
	{ -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },      -- 1st place
	{ -1.5, -0.5, -0.5, -0.5, 0.125, 0.5 },   -- 2nd place (viewer's left)
	{ 0.5, -0.5, -0.5, 1.5, -0.125, 0.5 },    -- 3rd place (viewer's right)
}

local function register_podium(stat)
	local def = R.sources[stat]
	local name = "player_pedestal:podium_" .. stat
	minetest.register_node(name, merge(common, {
		description = S("Ranking podium: @1", def.label) .. "\n" .. minetest.colorize("#aaaaaa", S("Admin only")),
		drawtype = "nodebox",
		tiles = {
			"player_pedestal_podium_top.png", "player_pedestal_marble_top.png",
			"player_pedestal_podium_" .. stat .. ".png", "player_pedestal_podium_" .. stat .. ".png",
			"player_pedestal_podium_" .. stat .. ".png", "player_pedestal_podium_" .. stat .. ".png",
		},
		node_box = { type = "fixed", fixed = podium_box },
		selection_box = { type = "fixed", fixed = podium_box },
		collision_box = { type = "regular" },
		on_rotate = false,
		after_place_node = function(pos, placer)
			local pname = placer and placer:get_player_name() or ""
			local node = minetest.get_node(pos)
			local l, r = wing_positions(pos, node.param2)
			for _, p in ipairs({ l, r }) do
				local n = minetest.get_node(p)
				local nd = minetest.registered_nodes[n.name]
				if not nd or not nd.buildable_to or (pname ~= "" and minetest.is_protected(p, pname)) then
					minetest.remove_node(pos)
					minetest.chat_send_player(pname, minetest.colorize("#ff8080",
						S("The podium needs free space one block to the left and right.")))
					return true   -- keep the item
				end
			end
			minetest.set_node(l, { name = "player_pedestal:podium_filler_2" })
			minetest.set_node(r, { name = "player_pedestal:podium_filler_3" })
			player_pedestal.spawn_podium(pos, stat)
		end,
		on_destruct = function(pos)
			player_pedestal.remove_statues(pos)
			local l, r = wing_positions(pos, minetest.get_node(pos).param2)
			if minetest.get_node(l).name == "player_pedestal:podium_filler_2" then
				minetest.remove_node(l)
			end
			if minetest.get_node(r).name == "player_pedestal:podium_filler_3" then
				minetest.remove_node(r)
			end
		end,
		on_rightclick = function(pos, _, clicker)
			if not is_admin(clicker) then
				return
			end
			local top = R.get_top3(stat)
			local fs = "formspec_version[4]size[7,5.2]" ..
				"label[0.4,0.6;" .. FS("Top 3: @1", def.label) .. "]"
			for i = 1, 3 do
				local t = top[i]
				fs = fs .. "label[0.6," .. (0.9 + i * 0.7) .. ";" .. minetest.formspec_escape(
					i .. ". " .. (t and (t.name .. " — " .. t.value .. " " .. def.unit) or "—")) .. "]"
			end
			fs = fs .. "label[0.4,3.6;" .. FS("Poses are random and change with the ranking.") .. "]" ..
				"button_exit[0.4,4.1;6.2,0.8;refresh;" .. FS("Refresh now (new poses)") .. "]"
			context[clicker:get_player_name()] = vector.copy(pos)
			minetest.show_formspec(clicker:get_player_name(), "player_pedestal:podium", fs)
		end,
		_pp_spawn = function(pos)
			player_pedestal.spawn_podium(pos, stat)
		end,
	}))
	return name
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "player_pedestal:podium" then
		return
	end
	local pname = player:get_player_name()
	local pos = context[pname]
	context[pname] = nil
	if fields.refresh and pos and is_admin(player) then
		local def = minetest.registered_nodes[minetest.get_node(pos).name]
		local stat = def and def._pp_stat
		if stat then
			R.rescan(stat)
			player_pedestal.spawn_podium(pos, stat)
		end
	end
	return true
end)

-- A podium whose statistic is switched off on this server (e.g. experience
-- disabled with cubeborn.xp = false, or the statistics mod removed): podiums
-- already in the world stay as plain decoration without statues instead of
-- turning into unknown nodes, new ones cannot be placed. Turning the
-- statistic back on re-activates them.
local KNOWN = { xp = S("Experience"), kills = S("Kills"), placed = S("Placed blocks") }

local function register_disabled_podium(stat)
	local name = "player_pedestal:podium_" .. stat
	local tile = "player_pedestal_podium_" .. stat .. ".png^[colorize:#000000:90"
	minetest.register_node(name, merge(common, {
		description = S("Ranking podium: @1", KNOWN[stat]) .. "\n" ..
			minetest.colorize("#ff8080", S("This ranking is turned off on the server")),
		drawtype = "nodebox",
		tiles = { "player_pedestal_podium_top.png", "player_pedestal_marble_top.png", tile, tile, tile, tile },
		node_box = { type = "fixed", fixed = podium_box },
		selection_box = { type = "fixed", fixed = podium_box },
		collision_box = { type = "regular" },
		groups = merge(common.groups, { not_in_creative_inventory = 1 }),
		on_rotate = false,
		on_place = function(itemstack, placer)
			if placer and placer:is_player() then
				minetest.chat_send_player(placer:get_player_name(), minetest.colorize("#ff8080",
					S("This ranking is turned off on the server")))
			end
			return itemstack
		end,
		on_destruct = function(pos)
			player_pedestal.remove_statues(pos)
			local l, r = wing_positions(pos, minetest.get_node(pos).param2)
			if minetest.get_node(l).name == "player_pedestal:podium_filler_2" then
				minetest.remove_node(l)
			end
			if minetest.get_node(r).name == "player_pedestal:podium_filler_3" then
				minetest.remove_node(r)
			end
		end,
		_pp_spawn = function(pos)
			minetest.get_meta(pos):set_string("infotext",
				S("Ranking podium: @1", KNOWN[stat]) .. "\n" .. S("This ranking is turned off on the server"))
		end,
	}))
	return name
end

local spawnable = { "player_pedestal:pedestal" }
register_filler(2)
register_filler(3)
for _, stat in ipairs(R.order) do
	local n = register_podium(stat)
	minetest.override_item(n, { _pp_stat = stat })
	spawnable[#spawnable + 1] = n
end
for stat in pairs(KNOWN) do
	if not R.sources[stat] then
		spawnable[#spawnable + 1] = register_disabled_podium(stat)
		minetest.log("action", "[player_pedestal] ranking '" .. stat .. "' is off: podium disabled")
	end
end

-- Re-create statues whenever a mapblock with pedestals is loaded.
minetest.register_lbm({
	label = "Spawn player pedestal statues",
	name = "player_pedestal:spawn_statues",
	nodenames = spawnable,
	run_at_every_load = true,
	action = function(pos, node)
		local def = minetest.registered_nodes[node.name]
		if def and def._pp_spawn then
			def._pp_spawn(pos, node)
		end
	end,
})

-- Pistons / movestones must not move pedestals.
if minetest.global_exists("mesecon") and mesecon.register_mvps_stopper then
	for _, n in ipairs(spawnable) do
		mesecon.register_mvps_stopper(n)
	end
	mesecon.register_mvps_stopper("player_pedestal:podium_filler_2")
	mesecon.register_mvps_stopper("player_pedestal:podium_filler_3")
end
