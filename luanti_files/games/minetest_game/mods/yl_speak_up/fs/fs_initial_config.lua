-- set name, description and owner of the NPC
-- (owner can only be set if the player has the npc_talk_master
--  priv - not with npc_talk_owner priv alone)
yl_speak_up.input_fs_initial_config = function(player, formname, fields)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id

	if(fields.back_from_error_msg) then
		-- no point in showing the formspec or error message again if we did so already
		if(not(yl_speak_up.may_edit_npc(player, n_id))) then
			return
		end
		-- show this formspec again
		yl_speak_up.show_fs(player, "initial_config",
			{n_id = n_id, d_id = yl_speak_up.speak_to[pname].d_id, false})
		return
	end

	if(fields.button_export_dialog) then
		yl_speak_up.show_fs(player, "export")
		return
	end

	if((not(fields.save_initial_config)
	  and not(fields.show_nametag)
	  ) or (fields and fields.exit)) then
		local dialog = yl_speak_up.speak_to[pname].dialog
		-- unconfigured NPC
		if(fields and fields.exit and not(dialog) or not(dialog.n_dialogs)) then
			minetest.chat_send_player(pname, "Aborting initial configuration.")
			return
		end
		-- else we can quit here
		return
	end

	local error_msg = nil
	-- remove leading and tailing spaces from the potential new NPC name in order to avoid
	-- confusing names where a player's name (or that of another NPC) is beginning/ending
	-- with blanks
	if(fields.n_npc) then
		fields.n_npc = fields.n_npc:match("^%s*(.-)%s*$")
	end
	local dialog = yl_speak_up.speak_to[pname].dialog
	-- the player is trying to save the initial configuration
	-- is the player allowed to initialize this npc?
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		error_msg = "You are not allowed to edit this NPC."
	elseif(not(fields.n_npc) or string.len(fields.n_npc) < 2) then
		error_msg = "The name of your NPC needs to be\nat least two characters long."
	elseif(minetest.check_player_privs(fields.n_npc, {interact=true})
	  and not(minetest.check_player_privs(player, {npc_talk_master=true}))
	  and not(minetest.check_player_privs(player, {npc_talk_admin=true}))) then
		error_msg = "You cannot name your NPC after an existing player.\n"..
			"Only those with the npc_talk_admin priv can do so."
	elseif(not(fields.n_description) or string.len(fields.n_description) < 2) then
		error_msg = "Please provide a description of your NPC!"
	-- sensible length limit
	elseif(string.len(fields.n_npc)>40 or string.len(fields.n_description)>40) then
		error_msg = "The name and description of your NPC\ncannot be longer than 40 characters."
	-- want to change the owner?
	elseif(fields.n_owner and fields.n_owner ~= yl_speak_up.npc_owner[ n_id ]) then
		if(    not(minetest.check_player_privs(player, {npc_talk_master=true}))) then
			error_msg = "You need the \"npc_talk_master\" priv\nin order to change the owner."
		elseif(not(minetest.check_player_privs(fields.n_owner, {npc_talk_owner=true}))) then
			error_msg = "The NPC can only be owned by players that\n"..
				    "have the \"npc_talk_owner\" priv. Else the\n"..
				    "new owner could not edit his own NPC."
		end
	end
	if(error_msg) then
		yl_speak_up.show_fs(player, "msg", { input_to = "yl_speak_up:initial_config",
			formspec = "size[6,2]"..
				"label[0.2,0.0;"..tostring(error_msg).."]"..
				"button[2,1.5;1,0.9;back_from_error_msg;Back]"})
		return
	end
	-- warn players with npc_talk_master priv if the name of an npc is used by a player already
	if(minetest.check_player_privs(fields.n_npc, {interact=true})) then
		minetest.chat_send_player(pname, "WARNING: A player named \'"..tostring(fields.n_npc)..
			"\' exists. This NPC got assigned the same name!")
	end

	-- we checked earlier if the player doing this change and the
	-- player getting the NPC have appropriate privs
	if(fields.n_owner ~= yl_speak_up.npc_owner[ n_id ]) then
		yl_speak_up.log_change(pname, n_id,
			"Owner changed from "..tostring(yl_speak_up.npc_owner[ n_id ])..
			" to "..tostring(fields.n_owner).." for "..
			"NPC name: \""..tostring(fields.n_npc))
		-- the owner will actually be changed further down, at the end of this function
		yl_speak_up.npc_owner[ n_id ] = fields.n_owner
	end

	-- give the NPC its first dialog
	if(not(dialog)
	  or not(dialog.created_at)
	  or not(dialog.n_npc)
	  or not(dialog.npc_owner)) then
		-- TODO: pname == yl_speak_up.npc_owner[ n_id ]  required
		-- initialize the NPC with first dialog, name, description and owner:
		yl_speak_up.initialize_npc_dialog_once(pname, dialog, n_id, fields.n_npc, fields.n_description)
	end

	-- initializing the dialog in the code above may have changed it
	dialog = yl_speak_up.speak_to[pname].dialog
	-- just change name and description
	if((fields.n_npc and fields.n_npc ~= "")
	   and (fields.n_description and fields.n_description ~= "")) then
		-- we checked that these fields contain values; are they diffrent from the existing ones?
		if(dialog.n_npc ~= fields.n_npc
		  or dialog.n_description ~= fields.n_description) then
			dialog.n_npc = fields.n_npc
			dialog.n_description = fields.n_description
			yl_speak_up.save_dialog(n_id, dialog)

			yl_speak_up.log_change(pname, n_id,
				"Name and/or description changed. "..
				"NPC name: \""..tostring(fields.n_npc)..
				"\" Description: \""..tostring(fields.n_description)..
				"\" May be edited by: \""..
				table.concat(yl_speak_up.sort_keys(dialog.n_may_edit or {}, true), " ").."\".")
		end
	end

	-- show nametag etc.
	if yl_speak_up.speak_to[pname].obj then
		local obj = yl_speak_up.speak_to[pname].obj
		local ent = obj:get_luaentity()
		if ent ~= nil then
			if(fields.show_nametag) then
				local new_nametag_state = "- UNDEFINED -"
				if(fields.show_nametag == "false") then
					ent.yl_speak_up.hide_nametag = true
					dialog.hide_nametag = true
					new_nametag_state = "HIDE"
					-- update_nametag else will only work on reload
					obj:set_nametag_attributes({text=""})
				elseif(fields.show_nametag == "true") then
					ent.yl_speak_up.hide_nametag = nil
					dialog.hide_nametag = nil
					new_nametag_state = "SHOW"
				end
				yl_speak_up.save_dialog(n_id, dialog)
				yl_speak_up.log_change(pname, n_id,
					tostring(new_nametag_state).." nametag.")
				minetest.chat_send_player(pname,
					tostring(dialog.n_npc)..": I will "..
					tostring(new_nametag_state).." my nametag.")
			end
			ent.yl_speak_up.npc_name = dialog.n_npc
			ent.yl_speak_up.npc_description = dialog.n_description
			ent.owner = yl_speak_up.npc_owner[ n_id ] or dialog.npc_owner
			local i_text = dialog.n_npc .. "\n" .. 
					dialog.n_description .. "\n" ..
					yl_speak_up.infotext
			obj:set_properties({infotext = i_text})
                        yl_speak_up.update_nametag(ent)
		end
	end

	-- the dialog id may be new due to the dialog having been initialized
	local d_id = yl_speak_up.speak_to[pname].d_id
	if(not(fields.save_initial_config)) then
		yl_speak_up.show_fs(player, "initial_config",
			{n_id = n_id, d_id = d_id, false})
		return
	end
	if((fields.add_may_edit and fields.add_may_edit ~= "")
	  or (fields.delete_may_edit and fields.delete_may_edit ~= "")) then
		-- show this formspec again
		yl_speak_up.show_fs(player, "initial_config",
			{n_id = n_id, d_id = d_id, false})
	else
		-- actually start a chat with our new npc
		yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = d_id})
	end
end


-- initialize the npc without having to use a staff;
-- returns true when initialization possible
-- the entries from add_formspec are added to the output
yl_speak_up.get_fs_initial_config = function(player, n_id, d_id, is_initial_config, add_formspec)
	local pname = player:get_player_name()

	-- is the player allowed to edit this npc?
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		return "size[6,2]"..
			"label[0.2,0.0;Sorry. You are not authorized\nto edit this NPC.]"..
			"button_exit[2,1.5;1,0.9;back_from_error_msg;Exit]"
	end

	local tmp_show_nametag = "true"
	local tmp_name = n_id
	local tmp_descr = "A new NPC without description"
	local tmp_text = "Please provide your new NPC with a name and description!"
	local tmp_owner = (yl_speak_up.npc_owner[ n_id ] or "- none -")
	-- use existing name and description as presets when just editing
	if(not(is_initial_config)) then
		local dialog = yl_speak_up.speak_to[pname].dialog
		tmp_show_nametag = not(dialog.hide_nametag)
		tmp_name = (dialog.n_npc or tmp_name)
		tmp_descr = (dialog.n_description or tmp_descr)
		tmp_text = "You can change the name and description of your NPC."
	end
	local formspec = {"size[11,8.0]",
		"label[0.2,0.5;",
		tmp_text,
		"]",
		"button[9.0,0.2;1.8,0.9;button_export_dialog;Export]",
		"tooltip[button_export_dialog;"..
			"Export: Show the dialog in .json format which you can"..
			"\n\tcopy and store on your computer.]",
		-- name of the npc
		"checkbox[2.2,0.9;show_nametag;Show nametag;",
		tostring(tmp_show_nametag),
		"]",
		"label[0.2,1.65;Name:]",
		"field[2.2,1.2;4,0.9;n_npc;;",
		minetest.formspec_escape(tmp_name),
		"]",
		"label[7.0,1.65;NPC ID: ",
		minetest.colorize("#FFFF00",tostring(n_id)),
		"]",
		"tooltip[n_npc;n_npc: The name of the NPC;#FFFFFF;#000000]",
		-- description of the npc
		"label[0.2,2.65;Description:]",
		"field[2.2,2.2;8,0.9;n_description;;",
		minetest.formspec_escape(tmp_descr),
		"]",
		"tooltip[n_description;n_description: A description for the NPC;#FFFFFF;#000000]",
		-- the owner of the NPC
		"label[0.2,3.65;Owner:]",
		"field[2.2,3.2;8,0.9;n_owner;;",
		minetest.formspec_escape(tmp_owner),
		"]",
		"tooltip[n_owner;The owner of the NPC. This can only be changed\n"..
			"if you have the npc_talk_master priv.;#FFFFFF;#000000]",
		-- save and exit buttons
		"button[3.2,7.0;2,0.9;save_initial_config;Save]",
		"button_exit[5.4,7.0;2,0.9;exit;Exit]"
	}
	-- add some entries in edit mode
	if(add_formspec) then
		for _, v in ipairs(add_formspec) do
			table.insert(formspec, v)
		end
	elseif(not(is_initial_config)) then
		-- TODO: add import/export/show texture?
	end
	-- show the formspec to the player
	return table.concat(formspec, "")
end


yl_speak_up.get_fs_initial_config_wrapper = function(player, param)
	if(not(param)) then
		param = {}
	end
	return yl_speak_up.get_fs_initial_config(player, param.n_id, param.d_id, param.is_initial_config, nil)
end

yl_speak_up.register_fs("initial_config",
	yl_speak_up.input_fs_initial_config,
	yl_speak_up.get_fs_initial_config_wrapper,
	-- no special formspec required:
	nil
)
