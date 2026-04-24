-- assign a quest step to a dialog option/answe
-- This is the formspec where this is handled.

-- small helper function
local show_error_fs = function(player, text)
        yl_speak_up.show_fs(player, "msg", {
                input_to = "yl_speak_up:assign_quest_step",
                formspec = yl_speak_up.build_fs_quest_edit_error(text, "back_from_error_msg")})
end


-- small helper function
yl_speak_up.get_choose_until_step_list = function(pname, q_id, quest_step)
	local choose_until_step = {
		" - the player restarts the quest -",
		" - this quest step -",
		" - the quest step immediately following this one -"
	}
	local cdata = yl_speak_up.quests[q_id].step_data[quest_step]
	for step_name, d in pairs(yl_speak_up.quests[q_id].step_data or {}) do
		if(step_name ~= quest_step
		  and cdata
		  -- exclude steps that quest_step depends on
		  and table.indexof(cdata.one_step_required  or {}, step_name) == -1
		  and table.indexof(cdata.all_steps_required or {}, step_name) == -1) then
			table.insert(choose_until_step, minetest.formspec_escape(step_name))
		end
	end
	return choose_until_step
end


yl_speak_up.input_fs_assign_quest_step = function(player, formname, fields)
	if(not(player)) then
		return ""
	end     
	local pname = player:get_player_name()
	-- what are we talking about?
	local n_id = yl_speak_up.speak_to[pname].n_id
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id

	if(not(n_id) or yl_speak_up.edit_mode[pname] ~= n_id) then
		return
	end
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o_id))) then
		return
        end

	-- go back to edit options field
	if((fields and fields.quit)
	  or (fields and fields.back and fields.back ~= "")) then
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_id})
		return
	elseif(fields and fields.back_from_error_msg) then
		yl_speak_up.show_fs(player, "assign_quest_step", nil)
		return
	-- show manage quests formspec
	elseif(fields and fields.manage_quests) then
		-- store information so that the back button can work
		yl_speak_up.speak_to[pname][ "working_at" ] = "assign_quest_step"
		yl_speak_up.show_fs(player, "manage_quests", nil)
		return
	elseif(fields and fields.show_quest) then
		local q_id = yl_speak_up.speak_to[pname].q_id
		local quest_var_name = nil
		if(q_id and yl_speak_up.quests[q_id]) then
			quest_var_name = yl_speak_up.strip_pname_from_var(yl_speak_up.quests[q_id].var_name, pname)
		end
		yl_speak_up.show_fs(player, "manage_quests", quest_var_name)
		return
	elseif(fields and fields.select_quest_id and fields.select_quest_id ~= "") then
		local parts = string.split(fields.select_quest_id, " ")
		if(parts and parts[1] and yl_speak_up.quests[parts[1]]) then
			-- TODO: check if the player has access rights to that quest
			-- TODO: check if the NPC has been added to that quest
			yl_speak_up.speak_to[pname].q_id = parts[1]
			yl_speak_up.show_fs(player, "add_quest_steps", "assign_quest_step")
			return
		end
	elseif(fields and fields.show_step) then
		yl_speak_up.show_fs(player, "manage_quest_steps", yl_speak_up.speak_to[pname].quest_step)
		return
	elseif(fields and fields.change_show_until) then
		yl_speak_up.show_fs(player, "assign_quest_step", "change_show_until")
		return
	elseif(fields and fields.store_show_until and fields.select_show_until) then
		local res = yl_speak_up.player_is_working_on_quest(player)
		if(res.error_msg) then
			return yl_speak_up.build_fs_quest_edit_error(res.error_msg, "back")
		end
		local choose_until_step = yl_speak_up.get_choose_until_step_list(
				res.pname, res.q_id, yl_speak_up.speak_to[pname].quest_step)
		local index = table.indexof(choose_until_step, fields.select_show_until or "")
		if(index ~= -1) then
			local dialog = yl_speak_up.speak_to[pname].dialog
			if(not(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o_id))) then
				return
			end
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				tostring(d_id).." "..tostring(o_id)..
				" quest step will be offered until player reached step \""..
				tostring(fields.select_show_until).."\".")
			if(fields.select_show_until == " - the player restarts the quest -") then
				fields.select_show_until = nil
			elseif(fields.select_show_until == " - this quest step -") then
				fields.select_show_until = yl_speak_up.speak_to[pname].quest_step
			elseif(fields.select_show_until == " - the quest step immediately following this one -") then
				fields.select_show_until = "  next_step"
			end
			dialog.n_dialogs[d_id].d_options[o_id].quest_show_until = fields.select_show_until
		end
		yl_speak_up.show_fs(player, "assign_quest_step")
		return
	elseif(fields.delete_assignment and fields.delete_assignment ~= "") then
		local n_id = yl_speak_up.speak_to[pname].n_id
		local d_id = yl_speak_up.speak_to[pname].d_id
		local o_id = yl_speak_up.speak_to[pname].o_id
		-- load the dialog (which may be diffrent from what the player is working on)
		local stored_dialog = yl_speak_up.load_dialog(n_id, false)
		-- check if the dialog exists
		if(not(yl_speak_up.check_if_dialog_has_option(stored_dialog, d_id, o_id))) then
			return show_error_fs(player, "Dialog or option not found.")
		end
		local quest_step_name = dialog.n_dialogs[d_id].d_options[o_id].quest_step
		local var_name        = dialog.n_dialogs[d_id].d_options[o_id].quest_id
		local q_id            = yl_speak_up.get_quest_id_by_var_name(var_name, pname)
		-- we will ignore the return value so that this connection can be deleted even if
		-- something went wrong (quest deleted, no write access to quest etc.)
		local msg = yl_speak_up.quest_step_del_where(pname, q_id, quest_step_name,
								{n_id = n_id, d_id = d_id, o_id = o_id})
		if(not(n_id)) then
			return show_error_fs(player, "NPC or location not found.")
		end
		-- log the change
		yl_speak_up.log_change(pname, n_id,
			"Dialog "..tostring(d_id)..": Option "..tostring(o_id)..
			" no longer sets quest step \""..
			tostring(dialog.n_dialogs[d_id].d_options[o_id].quest_step)..
			"\" of quest \""..
			tostring(dialog.n_dialogs[d_id].d_options[o_id].quest_id).."\".")
		-- we have updated the quest step data - we need to update the NPC as well
		local dialog = yl_speak_up.load_dialog(n_id, false)
		if(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o_id)) then
                        -- ok - the tables exist, so we can delete the connection
			-- (if it doesn't exist there's no need to change the stored NPC)
                        dialog.n_dialogs[d_id].d_options[o_id].quest_id   = nil
                        dialog.n_dialogs[d_id].d_options[o_id].quest_step = nil
                        -- write it back to disc
                        yl_speak_up.save_dialog(n_id, dialog)
		end
		-- the player is working on the NPC - thus, the NPC may be in a modified stage
		-- that hasn't been written to disc yet, and we need to adjust this stage as well
                dialog = yl_speak_up.speak_to[pname].dialog
		-- delete the connection
		dialog.n_dialogs[d_id].d_options[o_id].quest_id   = nil
		dialog.n_dialogs[d_id].d_options[o_id].quest_step = nil
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_id})
		return
	elseif(not(fields) or not(fields.save)) then
		return
	end
	-- actually store the data
	local error_msg = ""
	-- check if the quest exists
	local quest_list = yl_speak_up.get_sorted_quest_list(pname)
	local idx = table.indexof(quest_list, fields.quest_id or "")
	if(not(fields.quest_id) or fields.quest_id == "" or idx < 1) then
		error_msg = "Quest not found."
	elseif(not(fields.quest_step)
	  or string.len(fields.quest_step) < 1
	  or string.len(fields.quest_step) > 80) then
		error_msg = "The name of the quest step has to be between\n"..
				"1 and 80 characters long."
	end
	if(error_msg ~= "") then
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:assign_quest_step",
			formspec = "size[9,2]"..
				"label[0.2,0.5;Error: "..minetest.formspec_escape(error_msg).."]"..
				"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
		return
	end
	-- we identify quests by their var_name - not by their q_id
	-- (makes it easier to transfer quests from one server to another later)
	dialog.n_dialogs[d_id].d_options[o_id].quest_id = yl_speak_up.add_pname_to_var(fields.quest_id, pname)
	dialog.n_dialogs[d_id].d_options[o_id].quest_step = fields.quest_step
	if(not(yl_speak_up.npc_was_changed[ n_id ])) then
		yl_speak_up.npc_was_changed[ n_id ] = {}
	end
	table.insert(yl_speak_up.npc_was_changed[ n_id ],
                "Dialog "..d_id..": Option "..tostring(o_id)..
                " has been set as quest step \""..
		tostring(fields.quest_step).."\" for quest \""..tostring(fields.quest_id).."\".")
	yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_id})
end


yl_speak_up.get_fs_assign_quest_step = function(player, param)
	if(not(player)) then
		return ""
	end     
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id
	-- this only works in edit mode
	if(not(n_id) or yl_speak_up.edit_mode[pname] ~= n_id) then
		return "size[1,1]label[0,0;You cannot edit this NPC.]"
	end
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o_id))) then
		return "size[4,1]label[0,0;Dialog option does not exist.]"
        end
	local d_option = dialog.n_dialogs[d_id].d_options[o_id]
	local quest_id   = d_option.quest_id or ""
	local quest_step = d_option.quest_step or ""
	local quest_show_until = d_option.quest_show_until or " - the player restarts the quest -"
	if(quest_show_until == quest_step) then
		quest_show_until = " - this quest step -"
	-- players cannot create quest steps with leading blanks
	elseif(quest_show_until == "  next_step") then
		quest_show_until = " - the quest step immediately following this one -"
	end

	-- has a quest been selected?
	local q_id = yl_speak_up.get_quest_id_by_var_name(quest_id, pname)
	if(not(q_id)) then
		local npc_id = tonumber(string.sub(n_id, 3))
		local quest_list = {}
		for id, d in pairs(yl_speak_up.quests) do
			if(table.indexof(d.npcs or {}, npc_id) ~= -1) then
				table.insert(quest_list, minetest.formspec_escape(
					tostring(id).." "..tostring(d.name)))
			end
		end
		if(#quest_list < 1) then
			return "size[14,4]"..
				"label[4.0,0.5;Using this option/answer shall be a quest step.]"..
				"label[0.2,1.4;"..
					"This NPC "..tostring(n_id).." has not been added to a quest yet.\n"..
					"Please add him to the NPC list of one of your quests first!\n"..
					"Search the \"Edit\" button for \"NPC that (may) participate:\" "..
					"while viewing the desired quest.]"..
				"button[0.2,3.0;3.6,0.8;manage_quests;Manage Quests]"..
				"button[9.5,3.0;4.0,0.8;back;Back to edit option "..tostring(o_id).."]"
		end
		local selected = 1

--		local quest_list = yl_speak_up.get_sorted_quest_list(pname)
--		for i, v in ipairs(quest_list) do
--			quest_list[i] = minetest.formspec_escape(v)
--			if(quest_id and v == quest_id) then
--				selected = i
--			end
--		end
		return "size[14,4]"..
			"label[4.0,0.5;Using this option/answer shall be a quest step.]"..
			"label[0.2,1.4;Select a quest:]"..
				"dropdown[4.0,1.0;9.5,0.8;select_quest_id;"..
					table.concat(quest_list, ',')..";"..
					tostring(selected)..",]"..
			"label[0.2,2.1;If you want to use a quest not mentionned here or a new one, "..
				"click on \"Manage Quests\"\n"..
				"and search the \"Edit\" button for \"NPC that (may) participate:\".]"..
			"button[0.2,3.0;3.6,0.8;manage_quests;Manage Quests]"..
			"button[9.5,3.0;4.0,0.8;back;Back to edit option "..tostring(o_id).."]"
	end

	-- this is the currently relevant quest
	yl_speak_up.speak_to[pname].q_id = q_id
	yl_speak_up.speak_to[pname].quest_step = quest_step
	local choose_until_step = {}
	local show_until = ""
	if(param and param == "change_show_until") then
		local choose_until_step = yl_speak_up.get_choose_until_step_list(pname, q_id, quest_step)
		local index = table.indexof(choose_until_step, quest_show_until or "")
		if(index == -1) then
			index = 1
		end
		show_until = "dropdown[3.0,5.1;10,0.5;select_show_until;"..
			table.concat(choose_until_step, ",")..";"..tostring(index)..";]"..
			"button[13.5,4.8;4.3,0.8;store_show_until;Store]"
	else
		show_until = "label[3.0,5.4;"..minetest.colorize("#AAFFAA",
					minetest.formspec_escape(quest_show_until)).."]"..
				"button[13.5,4.8;4.3,0.8;change_show_until;Edit]"
	end
	local formspec = {
		"size[18,7]"..
		"label[3.0,0.5;Using this option/answer shall be a quest step.]"..
		"label[0.2,1.4;Quest ID:]"..
		"label[0.2,1.9;Quest name:]"..
		"label[0.2,3.4;quest step:]"..
		"button[13.5,3.1;4.3,0.8;show_step;Show this quest step]"..
		"label[0.2,3.9;"..
			"This quest step will be set for the player after the effects of "..
			"the dialog option are executed.]"..

		"label[0.2,4.9;"..
			"This dialog option will be shown until the player has reached the "..
			"following quest step:]"..
		"button[0.2,0.2;2.0,0.8;delete_assignment;Delete]"..
		"tooltip[delete_assignment;"..
			"Delete the assignment of this quest step to this dialog option.\n"..
			"Neither the quest step nor the dialog option will be deleted.\n"..
			"Just their connection. Afterwards, you can assign a new or\n"..
			"diffrent quest step to the dialog option.]"..
		"button[13.5,6.0;4.3,0.8;manage_quests;Manage quests]"
		}
	table.insert(formspec, "label[3.0,1.4;")
	table.insert(formspec, minetest.formspec_escape(q_id))
	table.insert(formspec, "]")
	table.insert(formspec, "label[3.0,1.9;")
	table.insert(formspec, minetest.formspec_escape(yl_speak_up.quests[q_id].name or "- ? -"))
	table.insert(formspec, "]")
	table.insert(formspec, "button[13.5,1.0;4.3,0.8;show_quest;Show this quest ")
	table.insert(formspec, tostring(q_id))
	table.insert(formspec, "]")
	table.insert(formspec, "label[0.2,2.9;This option here (")
	table.insert(formspec, tostring(o_id))
	table.insert(formspec, ") will be available once the player has reached all required "..						"quest steps for the following]")
	table.insert(formspec, "label[3.0,3.4;")
	table.insert(formspec, minetest.colorize("#FFFF00", minetest.formspec_escape(quest_step)))
	table.insert(formspec, "]")
	table.insert(formspec, "button[6.0,6.0;6.0,0.8;back;Back to edit option ")
	table.insert(formspec, tostring(o_id))
	table.insert(formspec, "]")
	table.insert(formspec, show_until)
	return table.concat(formspec, " ")
end


yl_speak_up.register_fs("assign_quest_step",
	yl_speak_up.input_fs_assign_quest_step,
	yl_speak_up.get_fs_assign_quest_step,
	-- no special formspec required:
	nil
)
