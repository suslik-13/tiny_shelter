
-- in addition: set who can edit this npc;
-- add buttons for fashion (skin editing) and properties;
local old_input_fs_initial_config = yl_speak_up.input_fs_initial_config
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

	if(fields.edit_skin and fields.edit_skin ~= "") then
		yl_speak_up.show_fs(player, "fashion")
		return
	end

	if(fields.edit_properties and fields.edit_properties ~= "") then
		yl_speak_up.show_fs(player, "properties")
		return
	end

	if((not(fields.save_initial_config)
	  and not(fields.show_nametag)
	  and not(fields.list_may_edit)
	  and not(fields.add_may_edit)
	  and not(fields.delete_may_edit)
	  ) or (fields and fields.exit)) then
		local dialog = yl_speak_up.speak_to[pname].dialog
		-- unconfigured NPC
		if(fields and fields.exit and not(dialog) or not(dialog.n_dialogs)) then
			minetest.chat_send_player(pname, "Aborting initial configuration.")
			return
		end
		-- is the player editing the npc? then leaving this config
		-- dialog has to lead back to the talk dialog
		if(yl_speak_up.edit_mode[pname] == n_id and n_id) then
			yl_speak_up.show_fs(player, "talk",
				{n_id = n_id, d_id = yl_speak_up.speak_to[pname].d_id})
		end
		-- else we can quit here
		return
	end


	local error_msg = nil
	local dialog = yl_speak_up.speak_to[pname].dialog
	local done = false
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		error_msg = "You are not allowed to edit this NPC."

	-- want to change who may edit this npc?
	-- delete a player from the list of those allowed to edit the NPC
	elseif(fields.delete_may_edit and fields.delete_may_edit ~= ""
	   and fields.list_may_edit and fields.list_may_edit ~= "") then
		if(pname ~= yl_speak_up.npc_owner[ n_id ]) then
			error_msg = "Only the owner of the NPC\ncan change this."
		elseif(not(dialog)) then
			error_msg = "Please set a name for your NPC first!"
		else
			-- actually delete the player from the list
			dialog.n_may_edit[ fields.list_may_edit ] = nil
			-- show the next entry
			yl_speak_up.speak_to[pname].tmp_index = math.max(1,
					yl_speak_up.speak_to[pname].tmp_index-1)
		end
		done = true
	-- add a player who may edit this NPC
	elseif(fields.add_may_edit_button and fields.add_may_edit and fields.add_may_edit ~= "") then
		if(pname ~= yl_speak_up.npc_owner[ n_id ]) then
			error_msg = "Only the owner of the NPC\ncan change this."
		-- Note: The owner can now add himself as well. This may be useful before transfering
		--       ownership of the NPC to an inexperienced new user who might need help.
--		elseif(fields.add_may_edit == pname) then
--			error_msg = "You are already the owner of this NPC!\nNo need to add you extra here."
		elseif(not(minetest.check_player_privs(fields.add_may_edit, {interact=true}))) then
			error_msg = "Player \""..minetest.formspec_escape(fields.add_may_edit)..
				"\" not found."
		elseif(not(dialog)) then
			error_msg = "Please set a name for the NPC first!"
		else
			if(not(dialog.n_may_edit)) then
				dialog.n_may_edit = {}
			end
			dialog.n_may_edit[ fields.add_may_edit ] = true
			-- jump to the index with this player so that the player sees that he has been added
			local tmp_list = yl_speak_up.sort_keys(dialog.n_may_edit, true)
			local index = table.indexof(tmp_list, fields.add_may_edit)
			if(index and index > 0) then
				-- "Add player:" is added before all other names, so +1
				yl_speak_up.speak_to[pname].tmp_index = index + 1
			end
		end
		done = true
	-- selected a player name in the woy may edit this NPC dropdown?
	elseif(fields.list_may_edit and fields.list_may_edit ~= "") then
		local tmp_list = yl_speak_up.sort_keys(dialog.n_may_edit, true)
		local index = table.indexof(tmp_list, fields.list_may_edit)
		if(fields.list_may_edit == "Add player:") then
			index = 0
		end
		if(index and index > -1) then
			yl_speak_up.speak_to[pname].tmp_index = index + 1
		end
		done = true
	end
	if(error_msg) then
		yl_speak_up.show_fs(player, "msg", { input_to = "yl_speak_up:initial_config",
			formspec = "size[6,2]"..
				"label[0.2,0.0;"..tostring(error_msg).."]"..
				"button[2,1.5;1,0.9;back_from_error_msg;Back]"})
		return
	end

	if(    fields.add_may_edit and fields.add_may_edit ~= "") then
		yl_speak_up.save_dialog(n_id, dialog)
		yl_speak_up.log_change(pname, n_id,
			"Added to \"may be edited by\": "..tostring(fields.add_may_edit))
	elseif(fields.delete_may_edit and fields.delete_may_edit ~= ""
           and fields.list_may_edit and fields.list_may_edit ~= "") then
		yl_speak_up.save_dialog(n_id, dialog)
		yl_speak_up.log_change(pname, n_id,
			"Removed from \"may be edited by\": "..tostring(fields.list_may_edit))
	elseif(not(done) or fields.save_initial_config or fields.show_nametag ~= nil) then
		return old_input_fs_initial_config(player, formname, fields)
	end
	-- update display after editing may_edit_npc:
	yl_speak_up.show_fs(player, "initial_config",
			{n_id = n_id, d_id = yl_speak_up.speak_to[pname].d_id, false})
end


-- initialize the npc without having to use a staff;

-- add option to show, add and delete other players who may edit this npc;
-- add buttons for skin change and editing properties
local old_get_fs_initial_config = yl_speak_up.get_fs_initial_config
yl_speak_up.get_fs_initial_config = function(player, n_id, d_id, is_initial_config, add_formspec)
	-- nothing to add if this is the initial configuration
	if(is_initial_config) then
		return old_get_fs_initial_config(player, n_id, d_id, is_initial_config, nil)
	end

	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	-- dialog.n_may_edit was a string for a short time in development
	if(not(dialog.n_may_edit) or type(dialog.n_may_edit) ~= "table") then
		dialog.n_may_edit = {}
	end
	local table_of_names = dialog.n_may_edit
	local may_be_edited_by = {
		-- these buttons and formspecs are provided by the editor:
		"button[1.0,5.5;4,0.9;edit_skin;Edit Skin]",
		"button[6.0,5.5;4,0.9;edit_properties;Edit Properties]",
		-- who can edit this NPC?
		"label[0.2,4.45;May be\nedited by:]",
		-- offer a dropdown list and a text input field for player names for adding
		yl_speak_up.create_dropdown_playerlist(player, pname,
			table_of_names, yl_speak_up.speak_to[pname].tmp_index,
			2.2, 4.3, 0.0, 1.0, "list_may_edit", "player",
				"Remove selected\nplayer from list",
			"add_may_edit",
				"Enter the name of the player whom you\n"..
				"want to grant the right to edit your NPC.\n"..
				"The player needs at least the npc_talk_owner priv\n"..
				"in order to actually edit the NPC.\n"..
				"Click on \"Add\" to add the new player.",
			"delete_may_edit",
				"If you click here, the player will no\n"..
				"longer be able to edit your NPC."
		)}
	if(not(yl_speak_up.speak_to[pname].tmp_index) or yl_speak_up.speak_to[pname].tmp_index < 2) then
		table.insert(may_be_edited_by, "button[9.8,4.3;1.0,1.0;add_may_edit_button;Add]")
		table.insert(may_be_edited_by, "tooltip[add_may_edit_button;Click here to add the player "..
					"listed to the left\nto those who can edit this NPC.]")
	end
	-- show the formspec to the player
	return old_get_fs_initial_config(player, n_id, d_id, is_initial_config, may_be_edited_by)
end


yl_speak_up.register_fs("initial_config",
	-- this function has been changed here:
        yl_speak_up.input_fs_initial_config,
	-- still handled by the wrapper:
        yl_speak_up.get_fs_initial_config_wrapper,
        -- no special formspec required:
        nil
)
