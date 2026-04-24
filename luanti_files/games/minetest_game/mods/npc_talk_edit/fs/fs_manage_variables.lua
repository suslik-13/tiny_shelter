
-- helper functions for yl_speak_up.input_fs_manage_variables(..)
-- returns the index of the new variable
yl_speak_up.fun_input_fs_manage_variables_add_new_entry = function(pname, entry_name)
	local res = yl_speak_up.add_quest_variable(pname, entry_name)
	if(not(res)) then
		return -1
	end
	local var_list = yl_speak_up.get_quest_variables(pname, true)
	-- make names of own variables shorter
	yl_speak_up.strip_pname_from_varlist(var_list, pname)
	table.sort(var_list)
	return table.indexof(var_list, entry_name)
end

-- helper functions for yl_speak_up.input_fs_manage_variables(..)
-- returns a text describing if deleting the variable worked
yl_speak_up.fun_input_fs_manage_variables_del_old_entry = function(pname, entry_name)
	-- delete (empty) variable
	return yl_speak_up.del_quest_variable(pname, entry_name, nil)
end

-- helper functions for yl_speak_up.input_fs_manage_variables(..)
-- implements all the functions that are specific to managing variables and not part of
-- general item management
yl_speak_up.fun_input_fs_manage_variables_check_fields = function(player, formname, fields, var_name, list_of_entries)
	local pname = player:get_player_name()
	if(not(var_name)) then
		var_name = ""
	end
	local var_name_with_prefix = yl_speak_up.restore_complete_var_name(var_name, pname)

	-- show all stored values for a variable in a table
	if(fields and fields.show_stored_values_for_var and var_name) then
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
			formspec = yl_speak_up.fs_show_all_var_values(player, pname, var_name)
		})
		return
	-- show details about a quest (if it is a quest variable)
	elseif(fields and fields.show_quest) then
		yl_speak_up.show_fs(player, "manage_quests", var_name)
		return
	-- show where this variable is used
	elseif(fields and fields.show_var_usage and fields.show_var_usage ~= "") then
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
			formspec = yl_speak_up.fs_get_list_of_usage_of_variable(
					fields.list_of_entries, pname, true,
					"back_from_msg",
					"Back to manage variables",
					-- not an internal variable
					false)
		})
		return
	-- set default value
	elseif(fields and fields.set_default_value and fields.default_value) then
		-- store the new default value
		if(fields.default_value == "") then
			fields.default_value = nil
		end
		local k_long = var_name_with_prefix
		local old_val = yl_speak_up.get_variable_metadata(k_long, "default_value", true)
		yl_speak_up.set_variable_metadata(k_long, nil, "default_value", nil, fields.default_value)
		local new_val = yl_speak_up.get_variable_metadata(k_long, "default_value", true)
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
                        formspec = "size[10,3.5]"..
                                "label[0.2,0.0;The "..minetest.colorize("#FFFF00", "default value")..
					" for variable\n\t"..
                                        minetest.colorize("#FFFF00",
						minetest.formspec_escape(tostring(var_name)))..
                                        "\nhas been changed from\n\t"..
					minetest.colorize("#FFFF00",
						minetest.formspec_escape(old_val or ""))..
                                        "\nto the NEW value\n\t"..
					minetest.colorize("#FFFF00",
						minetest.formspec_escape(new_val or "")).."]"..
                                "button[1.5,3.0;2,0.9;back_from_msg;Back]"
			})
		return

	-- enable, disable and list variables in debug mode
	elseif(fields and fields.enable_debug_mode and var_name) then
		yl_speak_up.set_variable_metadata(var_name, pname, "debug", pname, true)
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
                        formspec = "size[10,2]"..
                                "label[0.2,0.0;Activating debug mode for variable \""..
                                        minetest.colorize("#FFFF00",
						minetest.formspec_escape(tostring(var_name)))..
                                        "\".\nYou will now receive a chat message whenever the "..
					"variable changes.]"..
                                "button[1.5,1.5;2,0.9;back_from_msg;Back]"})
		return
	elseif(fields and fields.disable_debug_mode and var_name) then
		yl_speak_up.set_variable_metadata(var_name, pname, "debug", pname, nil)
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
                        formspec = "size[10,2]"..
                                "label[0.2,0.0;Deactivating debug mode for variable \""..
                                        minetest.colorize("#FFFF00",
						minetest.formspec_escape(tostring(var_name)))..
                                        "\".\nYou will no longer receive a chat message whenever the "..
					"variable changes.]"..
                                "button[1.5,1.5;2,0.9;back_from_msg;Back]"})
		return
	elseif(fields and fields.list_debug_mode) then
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
                        formspec = "size[10,6]"..
                                "label[0.2,0.0;You are currently receiving debug information for the "..
					"following variables:]"..
				"tablecolumns[text]"..
				"table[0.8,0.8;8.8,4.0;list_of_variables_in_debug_mode;"..
				-- the table entries will already be formspec_escaped
				table.concat(yl_speak_up.get_list_of_debugged_variables(pname), ",").."]"..
                                "button[1.5,5.5;2,0.9;back_from_msg;Back]"})
		return

	-- a player name was given; the value for that player shall be shown
	elseif(fields and fields.show_stored_value_for_player and var_name
	  and fields.stored_value_for_player and fields.stored_value_for_player ~= "") then
		yl_speak_up.show_fs(player, "manage_variables", {var_name = var_name,
				for_player = fields.stored_value_for_player})
		return
	-- change the value for a player (possibly to nil)
	elseif(fields and fields.store_new_value_for_player and var_name
	  and fields.stored_value_for_player and fields.stored_value_for_player ~= "") then
		local old_value = yl_speak_up.get_quest_variable_value(
					fields.stored_value_for_player, var_name_with_prefix)
		yl_speak_up.set_quest_variable_value(fields.stored_value_for_player, var_name_with_prefix,
							fields.current_value_for_player)
		local new_value = yl_speak_up.get_quest_variable_value(
					fields.stored_value_for_player, var_name_with_prefix)
		local success_msg = minetest.colorize("#00FF00", "Successfully set variable")
		if(new_value ~= fields.current_value_for_player) then
			success_msg = minetest.colorize("#FF0000", "FAILED TO set variable")
		end
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
                        formspec = "size[10,2.5]"..
                                "label[0.2,0.0;"..success_msg.." \""..
                                        minetest.colorize("#FFFF00",
						minetest.formspec_escape(tostring(var_name)))..
                                        "\"\nfor player "..
						minetest.formspec_escape(fields.stored_value_for_player)..
					"\n(old value: "..
					minetest.colorize("#AAAAAA", old_value)..
					")\nto new value "..
					minetest.colorize("#FFFF00", fields.current_value_for_player)..".]"..
                                "button[1.5,2.0;2,0.9;back_from_msg;Back]"})
		return
	-- remove the value for a player (set to nil)
	elseif(fields and fields.unset_value_for_player and var_name
	  and fields.stored_value_for_player and fields.stored_value_for_player ~= "") then
		local old_value = yl_speak_up.get_quest_variable_value(
					fields.stored_value_for_player, var_name_with_prefix)
		yl_speak_up.set_quest_variable_value(fields.stored_value_for_player, var_name_with_prefix, nil)
		local new_value = yl_speak_up.get_quest_variable_value(
					fields.stored_value_for_player, var_name_with_prefix)
		local success_msg = minetest.colorize("#00FF00", "Unset variable")
		if(new_value) then
			success_msg = minetest.colorize("#FF0000", "FAILED TO unset variable")
		end
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
                        formspec = "size[10,2]"..
                                "label[0.2,0.0;"..success_msg.." \""..
                                        minetest.colorize("#FFFF00",
						minetest.formspec_escape(tostring(var_name)))..
                                        "\"\nfor player "..
						minetest.formspec_escape(fields.stored_value_for_player)..
					"\n(old value: "..
					minetest.colorize("#AAAAAA", old_value)..
					").]"..
                                "button[1.5,1.5;2,0.9;back_from_msg;Back]"})
		return
	-- revoke read or write access to a variable
	elseif(fields
	  and ((fields.revoke_player_var_read_access  and fields.revoke_player_var_read_access ~= "")
	    or (fields.revoke_player_var_write_access and fields.revoke_player_var_write_access ~= ""))
	  and var_name) then
		local right = "read"
		if(fields.revoke_player_var_write_access and fields.revoke_player_var_write_access ~= "") then
			right = "write"
		end
		-- which player are we talking about?
		local selected = yl_speak_up.speak_to[pname]["tmp_index_var_"..right.."_access"]
		local pl_with_access = yl_speak_up.get_access_list_for_var(var_name, pname, right.."_access")
		local tmp_list = {}
		for k, v in pairs(pl_with_access) do
			table.insert(tmp_list, k)
		end
		table.sort(tmp_list)
		local grant_to = ""
		if(selected > 1) then
			grant_to = tmp_list[ selected-1 ]
		end
		local error_msg = ""
		local pl_with_access = yl_speak_up.get_access_list_for_var(var_name, pname, right.."_access")
		if(not(grant_to) or grant_to == "") then
			error_msg = "For which player do you want to revoke "..right.." access?"
		elseif(pname ~= yl_speak_up.npc_owner[ n_id ]
		  and not(minetest.check_player_privs(pname, {npc_talk_master=true}))) then
			error_msg = "Only the owner of the NPC or players with\n"..
				    "the npc_talk_master priv can change this."
		elseif(not(pl_with_access[ grant_to ])) then
			error_msg = minetest.formspec_escape(grant_to).." doesn't have "..right..
				    " access\nto this variable. Nothing changed."
		-- try to revoke access
		elseif(not(yl_speak_up.manage_access_to_quest_variable(var_name, pname, grant_to,
									right.."_access", nil))) then
			error_msg = "An internal error occoured."
		else
			-- not really an error message here...rather a success message
			error_msg = "Revoked "..right.." access to variable\n\""..
				minetest.formspec_escape(var_name)..
				"\"\nfor player "..minetest.formspec_escape(grant_to)..".\n"..
				"Note: This will *not* affect existing preconditions/effects!"
		end
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
			formspec = "size[6,2]"..
				"label[0.2,0.0;"..error_msg.."]"..
				"button[1.5,1.5;2,0.9;back_from_msg;Back]"})
		return

	-- grant read or write access to a variable
	elseif(fields
	  and ((fields.grant_player_var_read_access  and fields.grant_player_var_read_access ~= "")
	    or (fields.grant_player_var_write_access and fields.grant_player_var_write_access ~= ""))
	  and var_name) then
		local right = "read"
		if(fields.grant_player_var_write_access and fields.grant_player_var_write_access ~= "") then
			right = "write"
		end
		local grant_to = fields[ "grant_player_var_"..right.."_access"]
		local error_msg = ""
		local pl_with_access = yl_speak_up.get_access_list_for_var(var_name, pname, right.."_access")
		if(pname ~= yl_speak_up.npc_owner[ n_id ]
		  and not(minetest.check_player_privs(pname, {npc_talk_master=true}))) then
			error_msg = "Only the owner of the NPC or players with\n"..
				    "the npc_talk_master priv can change this."
		elseif(grant_to == pname) then
                        error_msg = "You already have "..right.." access to this variable."
		elseif(pl_with_access[ grant_to ]) then
			error_msg = minetest.formspec_escape(grant_to).." already has "..right..
				    " access\nto this variable."
		elseif(not(minetest.check_player_privs(grant_to, {interact=true}))) then
			error_msg = "Player \""..minetest.formspec_escape(grant_to).."\" not found."
		-- try to grant access
		elseif(not(yl_speak_up.manage_access_to_quest_variable(var_name, pname, grant_to,
									right.."_access", true))) then
			error_msg = "An internal error occoured."
		else
			-- not really an error message here...rather a success message
			error_msg = "Granted "..right.." access to variable\n\""..
				minetest.formspec_escape(var_name)..
				"\"\nto player "..minetest.formspec_escape(grant_to).."."
		end
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:manage_variables",
			formspec = "size[6,2]"..
				"label[0.2,0.0;"..error_msg.."]"..
				"button[1.5,1.5;2,0.9;back_from_msg;Back]"})
		return

	-- the player clicked on a name in the list of players with read or write access
	elseif(fields
	  and ((fields.list_var_read_access  and fields.list_var_read_access ~= "")
	    or (fields.list_var_write_access and fields.list_var_write_access ~= ""))
	  and var_name) then
		local right = "read"
		if(fields.list_var_write_access and fields.list_var_write_access ~= "") then
			right = "write"
		end
		local selected = fields[ "list_var_"..right.."_access"]
		local pl_with_access = yl_speak_up.get_access_list_for_var(var_name, pname, right.."_access")
		local tmp_list = {}
		for k, v in pairs(pl_with_access) do
			table.insert(tmp_list, k)
		end
		table.sort(tmp_list)
		local index = table.indexof(tmp_list, selected)
		if(selected == "Add player:") then
			index = 0
		end
		if(index and index > -1) then
			yl_speak_up.speak_to[pname]["tmp_index_var_"..right.."_access"] = index + 1
		end
		yl_speak_up.show_fs(player, "manage_variables")
		return
	end
	-- this function didn't have anything to do
	return "NOTHING FOUND"
end


-- makes use of yl_speak_up.handle_input_fs_manage_general and is thus pretty short
yl_speak_up.input_fs_manage_variables = function(player, formname, fields)
	local pname = player:get_player_name()
	local list_of_entries = yl_speak_up.get_quest_variables(pname, true)
	-- make names of own variables shorter
	yl_speak_up.strip_pname_from_varlist(list_of_entries, pname)
	table.sort(list_of_entries)

	local res = yl_speak_up.handle_input_fs_manage_general(player, formname, fields,
		-- what_is_the_list_about, min_length, max_length, function_add_new_entry,
		"variable", 2, 30,
		yl_speak_up.fun_input_fs_manage_variables_add_new_entry,
		list_of_entries,
		yl_speak_up.fun_input_fs_manage_variables_del_old_entry,
		yl_speak_up.fun_input_fs_manage_variables_check_fields)
end


yl_speak_up.get_fs_manage_variables = function(player, param)
	local pname = player:get_player_name()
	-- variables owned by the player - including those with write access
	local var_list = yl_speak_up.get_quest_variables(pname, true)
	-- make names of own variables shorter
	yl_speak_up.strip_pname_from_varlist(var_list, pname)

	local formspec = {}
	if(not(param) or type(param) ~= "table") then
		param = {}
	end
	if(param and type(param) == "table" and param.var_name and param.var_name ~= "") then
		local index = table.indexof(var_list, param.var_name)
		yl_speak_up.speak_to[pname].tmp_index_general = index + 1
	end
	table.insert(formspec,	"size[18,12]"..
				"label[0.2,1.2;Note: Each variable will store a diffrent value for each "..
					"player who interacts with the NPC.\n"..
				"You can grant read and write access to other players for your "..
					"variables so that they can also use them as well.]")
	local selected = yl_speak_up.build_fs_manage_general(player, param.var_name,
				formspec, var_list,
				"Create variable",
					"Create a new varialbe with the name\n"..
					"you entered in the field to the left.",
				"variable",
				"Enter the name of the new variable you\n"..
					"want to create.",
				"If you click here, the selected variable\n"..
					"will be deleted.")
	if(selected and selected ~= "") then
		local k = selected
		-- index 1 is "Add variable:"
		local pl_with_read_access = yl_speak_up.get_access_list_for_var(k, pname, "read_access")
		local pl_with_write_access = yl_speak_up.get_access_list_for_var(k, pname, "write_access")
		if(not(yl_speak_up.speak_to[pname].tmp_index_var_read_access)
		   or yl_speak_up.speak_to[pname].tmp_index_var_read_access == 1) then
			yl_speak_up.speak_to[pname].tmp_index_var_read_access = 1
			table.insert(formspec, "button[14.6,2.95;1.0,0.6;add_read_access;Add]"..
					"tooltip[add_read_access;Grant the player whose name you entered\n"..
					"you entered in the field to the left read access\n"..
					"to your variable.]")
		end
		if(not(yl_speak_up.speak_to[pname].tmp_index_var_write_access)
		   or yl_speak_up.speak_to[pname].tmp_index_var_write_access == 1) then
			yl_speak_up.speak_to[pname].tmp_index_var_write_access = 1
			table.insert(formspec, "button[14.6,3.95;1.0,0.6;add_write_access;Add]"..
				"tooltip[add_write_access;Grant the player whose name you entered\n"..
					"you entered in the field to the left *write* access\n"..
					"to your variable.]")
		end
		local list_of_npc_users = "- none -"
		local list_of_node_pos_users = "- none -"
		-- expand name of variable k again
		local k_long = yl_speak_up.add_pname_to_var(k, pname)
		-- which npc and which node_pos use this variable? create a list for display
		local c1 = 0
		local c2 = 0
		if(k_long
		  and yl_speak_up.player_vars[ k_long ]
		  and yl_speak_up.player_vars[ k_long ][ "$META$"]) then
			local npc_users = yl_speak_up.get_variable_metadata(k_long, "used_by_npc")
			c1 = #npc_users
			if(npc_users and c1 > 0) then
				list_of_npc_users = minetest.formspec_escape(table.concat(npc_users, ", "))
			end
			local node_pos_users = yl_speak_up.get_variable_metadata(k_long, "used_by_node_pos")
			c2 = #node_pos_users
			if(node_pos_users and c2 > 0) then
				list_of_node_pos_users = minetest.formspec_escape(table.concat(
								node_pos_users, ", "))
			end
		end
		table.insert(formspec, "button[10.0,10.05;4.0,0.6;list_debug_mode;What am I debugging?]"..
					"tooltip[list_debug_mode;"..
						"Show for which variables you currently have "..
						"\nactivated the debug mode.]")
		local debuggers =  yl_speak_up.get_variable_metadata(k_long, "debug")
		local i = table.indexof(debuggers, pname)
		if(i and i > 0) then
			table.insert(formspec,
					"button[5.0,10.05;4.0,0.6;disable_debug_mode;Deactivate debug mode]"..
					"tooltip[disable_debug_mode;"..
						"You will no longer receive a chat message "..
						"\nwhen this value changes for a player.]")
		else
			table.insert(formspec,
					"button[5.0,10.05;4.0,0.6;enable_debug_mode;Activate debug mode]"..
					"tooltip[enable_debug_mode;"..
						"You will receive a chat message whenever the value "..
						"\nof this variable changes for one player. The debug\n"..
						"messages will be sent even after relogin.]")
		end
		-- checking/changing debug value for one specific player
		if(not(param.for_player)) then
			param.for_player = ""
		end
		table.insert(formspec,
			"label[0.2,8.05;Show stored value for player:]"..
			"field[4.9,7.75;4.0,0.6;stored_value_for_player;;")
		table.insert(formspec, minetest.formspec_escape(param.for_player))
		table.insert(formspec, "]")
		table.insert(formspec,
			"button[9.0,7.75;4.5,0.6;show_stored_value_for_player;Show value for this player]"..
			"tooltip[stored_value_for_player;Enter the name of the player for which you\n"..
				"want to check (or change) the stored value.]"..
			"tooltip[show_stored_value_for_player;Click here to read and the current value"..
				"\nstored for this player.]")
		if(param.for_player and param.for_player ~= "") then
			local v = yl_speak_up.get_quest_variable_value(param.for_player, k_long) or ""
			table.insert(formspec,
				"label[0.2,9.05;Found stored value:]"..
				"field[4.9,8.75;4.0,0.6;current_value_for_player;;")
			table.insert(formspec, minetest.formspec_escape(v))
			table.insert(formspec, "]"..
				"tooltip[current_value_for_player;You can see and change the current "..
					"value here.]"..
				"button[9.0,8.75;4.5,0.6;store_new_value_for_player;"..
					"Store this as new value]"..
				"tooltip[store_new_value_for_player;"..
					"Click here to update the stored value for this player."..
					"\nWARNING: Be very careful here and never do this without"..
					"\n         informing the player about this change!]"..
				"button[13.9,8.75;3.0,0.6;unset_value_for_player;"..
					"Remove this entry]"..
				"tooltip[unset_value_for_player;Click here to delete the entry for this "..
					"player.\nSetting the entry to an empty string would not be "..
					"the same!]")
		end
		table.insert(formspec, "button[12.2,2.15;3.0,0.6;show_var_usage;Where is it used?]"..
			"tooltip[show_var_usage;Show which NPC use this variable in which context.]"..
			-- offer a dropdown list and a text input field for new varialbe names for adding
			"label[0.2,3.25;Players with read access to this variable:]")
		table.insert(formspec, yl_speak_up.create_dropdown_playerlist(player, pname,
				pl_with_read_access,
				yl_speak_up.speak_to[pname].tmp_index_var_read_access,
				6.9, 2.95, 0.0, 0.6, "list_var_read_access", "player",
					"Remove player from list",
				"grant_player_var_read_access",
					"Enter the name of the player that shall\n"..
					"have read access to this variable.",
				"revoke_player_var_read_access",
					"If you click here, the selected player\n"..
					"will no longer be able to add new\n"..
					"pre(C)onditions which read your variable."))
		table.insert(formspec, "label[0.2,4.25;Players with *write* access to this variable:]")
		table.insert(formspec, yl_speak_up.create_dropdown_playerlist(player, pname,
				pl_with_write_access,
				yl_speak_up.speak_to[pname].tmp_index_var_write_access,
				6.9, 3.95, 0.0, 0.6,
					"list_var_write_access", "player", "Remove player from list",
				"grant_player_var_write_access",
					"Enter the name of the player that shall\n"..
					"have *write* access to this variable.",
				"revoke_player_var_write_access",
					"If you click here, the selected player\n"..
					"will no longer be able to *write* new\n"..
					"values into this variable."))
		local var_type = (yl_speak_up.get_variable_metadata(k_long, "var_type")
					 or "String/text or numerical value, depending on how you use it")
		-- get the default value as-is (will usually be nil)
		local var_default_val = (yl_speak_up.get_variable_metadata(k_long, "default_value", true)
					 or "")
		table.insert(formspec, "label[0.2,4.95;Type of variable: ")
		table.insert(formspec, minetest.colorize("#FFFF00", var_type)) -- show variable type
		table.insert(formspec, ".]")
		table.insert(formspec,
			"label[0.2,5.55;Default value (when not set):]"..
			"field[4.9,5.25;4.0,0.6;default_value;;"..
				minetest.formspec_escape(var_default_val).."]"..
			"button[9.0,5.25;4.5,0.6;set_default_value;Set default value]"..
			"tooltip[default_value;By default, variables start unset with value \'nil\'. "..
				"\nIf you set this to a diffrent value, the variable will have this "..
				"\nvalue instead whenever it is unset."..
				"\nNote: Internally it is still stored as \'nil\'.]"..
			"tooltip[set_default_value;Store a new default value. Use empty input to set "..
				"back to the default \'nil\'.]")
		if(var_type == "quest") then
			table.insert(formspec, "button[4.2,4.75;4.5,0.6;show_quest;Show and edit this quest]")
		end
		table.insert(formspec, "label[0.2,6.05;This variable is used by the following ")
		table.insert(formspec,
				minetest.colorize("#FFFF00", tostring(c1)).." NPC:\n\t"..
				-- those are only n_id - no need to formspec_escape that
				minetest.colorize("#FFFF00", list_of_npc_users))
		table.insert(formspec, ".]")
		table.insert(formspec, "label[0.2,7.05;This variable is used by the following ")
		table.insert(formspec,
				minetest.colorize("#FFFF00", tostring(c2)).." node positions:\n\t"..
				-- those are only pos_to_string(..) - no need to formspec_escape that
				minetest.colorize("#FFFF00", list_of_node_pos_users))
		table.insert(formspec, ".]")
		table.insert(formspec,
			"button[0.2,10.05;4.0,0.6;show_stored_values_for_var;Show all stored values]"..
			"tooltip[show_stored_values_for_var;A diffrent value can be stored for each "..
				"player.\nShow these values in a table.]")
	end
	return table.concat(formspec, "")
end


yl_speak_up.register_fs("manage_variables",
	yl_speak_up.input_fs_manage_variables,
	yl_speak_up.get_fs_manage_variables,
	-- no special formspec required:
	nil
)
