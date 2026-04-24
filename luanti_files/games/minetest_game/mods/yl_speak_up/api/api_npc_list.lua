-- keeps a list of NPC with some data; Index: n_id
-- is saved to disk
yl_speak_up.npc_list = {}

-- list of objects of the NPC; Index: n_id
-- no point in saving this to disk
yl_speak_up.npc_list_objects = {}

-- file to store the list of NPC for the "/npc_talk list" command
yl_speak_up.npc_list_path = minetest.get_worldpath().."/yl_speak_up_npc_list.data"

-- pre-calculated lines for the NPC list (only which ones are shown and how some columns
-- are colored varies per player)
yl_speak_up.cache_general_npc_list_lines = {}

-- we need to remember which NPC was shown to the player in which order; index: player name
yl_speak_up.cache_npc_list_per_player = {}

-- which table column is the player using for sorting?
yl_speak_up.sort_npc_list_per_player = {}

-- add/update data about NPC self with dialog dialog (optional)
-- force_store ought to be true if something important has been changed
yl_speak_up.update_npc_data = function(self, dialog, force_store)
	-- is this a properly indexed npc?
	if(not(self) or not(self.yl_speak_up) or not(self.yl_speak_up.id)) then
		return
	end
	local is_known = not(not(yl_speak_up.npc_list[self.yl_speak_up.id]))
	-- who else may edit this NPC - that is stored in the dialog
	local may_edit = {}
	local desc = ""
	local trades = {}
	if(dialog) then
		may_edit = dialog.n_may_edit
		desc     = dialog.n_description
		-- maybe update this only when the trades are updated?
		if(dialog.trades) then
			for k, v in pairs(dialog.trades) do
				if(v.buy and v.pay and v.buy[1] and v.pay[1]) then
					table.insert(trades, {v.buy[1], v.pay[1]})
				end
			end
		end
	elseif(is_known) then
		local old = yl_speak_up.npc_list[self.yl_speak_up.id]
		may_edit   = old.may_edit
		desc       = old.desc
		trades     = old.trades
	end
	local created_at = 0
	if(is_known and yl_speak_up.npc_list[self.yl_speak_up.id].created_at) then
		created_at = yl_speak_up.npc_list[self.yl_speak_up.id].created_at
	else
		created_at = os.time()
	end
	local pos = {}
	if(self.object) then
		pos = self.object:get_pos()
		if(pos) then
			pos = { x = math.floor(pos.x or 0),
				y = math.floor(pos.y or 0),
				z = math.floor(pos.z or 0)}
		else
			pos = { x=0, y=0, z=0}
		end
	end
	-- only store real, important properties
	local properties = {}
	for k, v in pairs(self.yl_speak_up.properties or {}) do
		if(string.sub(k, 1, 5) ~= "self.") then
			properties[k] = v
		end
	end
	-- update the information we have on the NPC
	yl_speak_up.npc_list[self.yl_speak_up.id] = {
		typ        = self.name,
		name       = self.yl_speak_up.npc_name,
		desc       = desc,
		owner      = self.owner,
		may_edit   = may_edit,
		trades     = trades,
		pos        = pos,
		properties = properties,
		created_at = created_at,
		muted      = self.yl_speak_up.talk,
		animation  = self.yl_speak_up.animation,
		skin       = self.yl_speak_up.skin,
		textures   = self.textures,
	}
	-- the current object will change after deactivate; there is no point in storing
	-- it over server restart
	yl_speak_up.npc_list_objects[self.yl_speak_up.id] = self.object
	-- if we didn't know about this NPC before then by all means store the data
	if(not(is_known) or force_store) then
		yl_speak_up.npc_list_store()
	end
end


yl_speak_up.npc_list_load = function()
	local file,err = io.open( yl_speak_up.npc_list_path, "rb")
	if (file == nil) then
		yl_speak_up.npc_list = {}
		return
	end
	local data = file:read("*all")
	file:close()
	yl_speak_up.npc_list = minetest.deserialize(data)
end


yl_speak_up.npc_list_store = function()
	local file,err = io.open( yl_speak_up.npc_list_path, "wb")
	if (file == nil) then
		return
	end
	file:write(minetest.serialize(yl_speak_up.npc_list))
	file:close()
end


-- the entries for the "/npc_talk list" NPC list are generally the same for all
-- - except that not all lines are shown to each player and that some
-- lines might be colored diffrently
yl_speak_up.build_cache_general_npc_list_lines = function()

	-- small helper function to suppress the display of zeros
	local show_if_bigger_null = function(value, do_count)
		if(do_count and value) then
			local anz = 0
			for k, v in pairs(value) do
				anz = anz + 1
			end
			value = anz
		end
		if(value and value > 0) then
			return tostring(value)
		else
			return ""
		end
	end

	-- the real priv names would be far too long
	local short_priv_name = {
	        precon_exec_lua    = 'pX',
		effect_exec_lua    = 'eX',
		effect_give_item   = 'eG',
		effect_take_item   = 'eT',
		effect_move_player = 'eM',
	}

	yl_speak_up.cache_general_npc_list_lines = {}

	for k, data in pairs(yl_speak_up.npc_list) do
		local data = yl_speak_up.npc_list[k]
		local n = (data.name or "- ? -")
		if(data.desc and data.desc ~= "") then
			n = n..', '..(data.desc or "")
		end
		-- is the NPC muted?
		local npc_color = (yl_speak_up.nametag_color_when_not_muted or '#FFFFFF')
		if(data.muted ~= nil and data.muted == false) then
			npc_color = (yl_speak_up.nametag_color_when_muted or '#FFFFFF')
		end
		-- is the NPC loaded?
		local is_loaded_color = '#777777'
		if(yl_speak_up.npc_list_objects[k]) then
			is_loaded_color = '#FFFFFF'
		end
		-- is it a generic NPC?
		local n_id = 'n_'..tostring(k)
		local is_generic = ''
		if(yl_speak_up.generic_dialogs[n_id]) then
			is_generic = 'G'
		end
		-- does the NPC have extra privs?
		local priv_list = ''
		if(yl_speak_up.npc_priv_table[n_id]) then
			for priv, has_it in pairs(yl_speak_up.npc_priv_table[n_id]) do
				priv_list = priv_list..tostring(short_priv_name[priv])..' '
			end
		end
		-- fallback if something went wrong with the position (or it's unknown)
		local pos_str = '- unknown -'
		if(not(data.pos) or not(data.pos.x) or not(data.pos.y) or not(data.pos.z)) then
			data.pos = {x=0, y=0, z=0}
		end
		pos_str = minetest.formspec_escape(minetest.pos_to_string(data.pos))

		yl_speak_up.cache_general_npc_list_lines[k] = {
			id              = k, -- keep for sorting
			is_loaded_color = is_loaded_color,
			n_id            = n_id,
			is_generic      = is_generic,
			npc_color       = npc_color, -- muted or not
			-- npc_color is diffrent for each player
			n_name          = minetest.formspec_escape(n),
			owner           = minetest.formspec_escape(data.owner or '- ? -'),
			is_loaded_color = is_loaded_color,
			anz_trades      = show_if_bigger_null(#data.trades),
			anz_properties  = show_if_bigger_null(data.properties, true),
			anz_editors     = show_if_bigger_null(data.may_edit, true),
			pos             = pos_str,
			priv_list       = priv_list,
		}
	end
end

-- emergency restore NPC that got lost (egg deleted, killed, ...)
yl_speak_up.command_npc_force_restore_npc = function(pname, rest)
	if(not(pname)) then
		return
	end
	if(not(minetest.check_player_privs(pname, {npc_talk_admin = true}))) then
		minetest.chat_send_player(pname, "This command is used for restoring "..
			"NPC that somehow got lost (egg destroyed, killed, ..). You "..
			"lack the \"npc_talk_admin\" priv required to run this command.")
			return
	end
	if(not(rest) or rest == "" or rest == "help" or rest == "?") then
		minetest.chat_send_player(pname, "This command is used for restoring "..
			"NPC that somehow got lost (egg destroyed, killed, ..).\n"..
			"WARNING: If the egg is found again later on, make sure that "..
				"this restored NPC and the NPC from the egg are not both placed!\n"..
			"         There can only be one NPC per ID.\n"..
			"Syntax: /npc_talk force_restore_npc <id> [<copy_from_id>]\n"..
			"        <id> is the ID (number! Without \"n_\") of the NPC to be restored.\n"..
			"        <copy_from_id> is only needed if the NPC is not listed in "..
			"\"/npc_talk list\" (=extremly old NPC).")
		return
	end
	local parts = string.split(rest or "", " ", false, 1)
	local id = tonumber(parts[1] or "")
	if(not(id)) then
		minetest.chat_send_player(pname, "Please provide the ID (number!) of the NPC "..
				"you wish to restore.")
		return
	elseif(not(yl_speak_up.number_of_npcs) or yl_speak_up.number_of_npcs < 1
	  or id > yl_speak_up.number_of_npcs) then
		minetest.chat_send_player(pname, "That ID is larger than the amount of existing NPC. "..
				"Restoring is for old NPC that got lost.")
		return
	elseif(id < 1) then
		minetest.chat_send_player(pname, "That ID is smaller than 1. Can't restore negative NPC.")
		return
	end
	local player = minetest.get_player_by_name(pname)
	if(not(player)) then
		return
	end
	-- if we've seen the NPC before: make sure he's not just unloaded because nobody is where he is
	if(yl_speak_up.npc_list[id] and yl_speak_up.npc_list[id].pos
	  and yl_speak_up.npc_list[id].pos.x
	  and yl_speak_up.npc_list[id].pos.y
	  and yl_speak_up.npc_list[id].pos.z) then
		local v_npc = vector.new(yl_speak_up.npc_list[id].pos)
		local v_pl  = vector.new(player:get_pos())
		if(vector.distance(v_npc, v_pl) > 6) then
			minetest.chat_send_player(pname, "You are more than 6 m away from the last "..
				"known position of this NPC at "..
				minetest.pos_to_string(yl_speak_up.npc_list[id].pos)..
				". Please move closer to make sure the NPC isn't just not loaded "..
				"due to nobody beeing near!")
			return
		end
	end
	-- check the currently loaded mobs to make sure he wasn't loaded since last update of our list
	for k,v in pairs(minetest.luaentities) do
		if(v and v.yl_speak_up and v.yl_speak_up.id and v.yl_speak_up.id == id) then
			minetest.chat_send_player(pname, "An NPC with the ID "..tostring(id)..
				" is currently loaded. No restoring required!")
			return
		end
	end
	local data = nil
	-- do we need a donator NPC because we have never seen this NPC and have no data?
	local copy_from_id = tonumber(parts[2] or "")
	if(not(yl_speak_up.npc_list[id])) then
		if(not(copy_from_id) or not(yl_speak_up.npc_list[copy_from_id])) then
			minetest.chat_send_player(pname, "We have no data on NPC "..tostring(id)..
				". Please provide the ID of an EXISTING NPC from which necessary "..
				"data can be copied!")
			return
		end
		minetest.chat_send_player(pname, "Will use the data of the NPC with ID "..
				tostring(copy_from_id).." to set up the new/restored NPC.")
		data = yl_speak_up.npc_list[copy_from_id]
	else
		data = yl_speak_up.npc_list[id]
	end
	-- ok..the NPC is not loaded. Perhaps he really got lost.
	minetest.chat_send_player(pname, "Will try to restore the NPC with the ID "..tostring(id)..".")

	if(not(data.typ) or not(minetest.registered_entities[data.typ or "?"])) then
		minetest.chat_send_player(pname, "Error: No NPC entity prototype found for \""..
				tostring(data.name).."\". Aborting.")
		return
	end

	-- this is an emergency fallback restore - so it's ok to drop the NPC where the admin is standing
	local mob = minetest.add_entity(player:get_pos(), data.typ)
	local ent = mob and mob:get_luaentity()
	if(not(ent)) then
		minetest.chat_send_player(pname, "Failed to create a new NPC entity of type \""..
				tostring(data.name).."\". Aborting.")
		return
	end
	-- set up the new NPC
	local npc_name  = data.name
	local npc_desc  = data.npc_description
	local npc_owner = data.owner
	-- the dialog includes the trades, n_may_edit and other data
	local dialog = yl_speak_up.load_dialog(id, nil)
	-- restore name and description from dialog if possible
	if(dialog and dialog.n_npc) then
		npc_name  = dialog.n_npc
		npc_desc  = dialog.n_description
		npc_owner = dialog.npc_owner or data.owner
	end
	ent.yl_speak_up = {
		id              = id,
		talk            = data.muted,
		properties      = data.properties,
		npc_name        = npc_name,
		npc_description = npc_desc,
		infotext        = yl_speak_up.infotext, -- will be set automaticly later
		animation       = data.animation,
		textures        = data.textures,
	}
	-- This is at least useful for mobs_redo. Other mob mods may require adjustments.
	ent.owner = npc_owner
	ent.tamed = true
	-- update nametag, infotext etc.
	yl_speak_up.update_nametag(ent)
	if(data.animation and ent.object) then
		ent.object:set_animation(data.animation)
	end
	if(data.skin and ent.object) then
		ent.object:set_properties({textures = table.copy(data.skin)})
		ent.yl_speak_up.textures = table.copy(data.skin)
	end
	-- update the NPC list
	yl_speak_up.update_npc_data(ent, dialog, true)
	minetest.chat_send_player(pname, "Placed the restored NPC ID "..tostring(id)..
		", named "..tostring(data.name)..", right where you stand.")
end


-- provides a list of NPC the player can edit
yl_speak_up.command_npc_talk_list = function(pname, rest)
	if(not(pname)) then
		return
	end

	-- check if there are any loaded entities handled by yl_speak_up that
	-- are *not* in the list yet
	local liste = {}
	for k,v in pairs(minetest.luaentities) do
		if(v and v.yl_speak_up and v.yl_speak_up.id) then
			if(not(yl_speak_up.npc_list[v.yl_speak_up.id])) then
				local dialog = yl_speak_up.load_dialog(v.yl_speak_up.id, nil)
				yl_speak_up.update_npc_data(v, dialog, false)
			else
				yl_speak_up.update_npc_data(v, nil, false)
			end
		end
	end
	-- store the updated list
	yl_speak_up.npc_list_store()
	-- update the information for display
	yl_speak_up.build_cache_general_npc_list_lines()
	-- clear the stored NPC list and calculate it anew
	yl_speak_up.cache_npc_list_per_player[pname] = {}
	-- Note: show_fs cannot be used here as that expects the player to be talking to an actual npc
	yl_speak_up.show_fs_ver(pname, "yl_speak_up:show_npc_list",
                        yl_speak_up.get_fs_show_npc_list(pname, nil))
end


