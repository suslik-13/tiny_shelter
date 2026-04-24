
-- helper function; used by
-- 	* yl_speak_up.get_fs_edit_option_dialog and
-- 	* yl_speak_up.get_fs_edit_trade_limit
yl_speak_up.get_list_of_effects_and_target_dialog_and_effect = function(dialog, results, pname, target_dialog, target_effect)
	local list_of_effects = ""
	local count_effects = 0
	if(results) then
		local sorted_key_list = yl_speak_up.sort_keys(results)
		for i, k in ipairs(sorted_key_list) do
			local v = results[ k ]
			if v.r_type == "dialog" and (dialog.n_dialogs[v.r_value] ~= nil or v.r_value == "d_end" or v.r_value == "d_got_item") then
				list_of_effects = list_of_effects..
					minetest.formspec_escape(v.r_id)..",#999999,"..
					minetest.formspec_escape(v.r_type)..","..
					minetest.formspec_escape(
						yl_speak_up.show_effect(v, pname))..","
				-- there may be more than one in the data structure
				target_dialog = v.r_value
				target_effect = v
			elseif v.r_type ~= "dialog" then
				list_of_effects = list_of_effects..
					minetest.formspec_escape(v.r_id)..",#FFFF00,"..
					minetest.formspec_escape(v.r_type)..","..
					minetest.formspec_escape(
						yl_speak_up.show_effect(v, pname))..","
			end
			count_effects = count_effects + 1
		end
	end
	if(count_effects < yl_speak_up.max_result_effects) then
		list_of_effects = list_of_effects..",#00FF00,add,Add a new (Ef)fect"
	else
		list_of_effects = list_of_effects..",#AAAAAA,-,"..
			"Maximum amount of allowed (Ef)fects per option reached!"
	end
	return {list = list_of_effects, target_dialog = target_dialog, target_effect = target_effect}
end


-- process input from formspec created in get_fs_edit_option_dialog(..)
yl_speak_up.input_edit_option_dialog = function(player, formname, fields)
	if formname ~= "yl_speak_up:edit_option_dialog" then
		return
	end
        local pname = player:get_player_name()

	-- Is the player working on this particular npc?
	local edit_mode = (yl_speak_up.edit_mode[pname] == yl_speak_up.speak_to[pname].n_id)
	if(not(edit_mode)) then
		return
	end
	local n_id = yl_speak_up.speak_to[pname].n_id
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id

	local dialog = yl_speak_up.speak_to[pname].dialog
	local n_dialog = dialog.n_dialogs[d_id]
	if(not(n_dialog) or not(n_dialog.d_options)) then
		return
	end
	local d_option = n_dialog.d_options[o_id]
	if(not(d_option)) then
		return
	end

	if(fields.assign_quest_step and fields.assign_quest_step ~= "") then
		yl_speak_up.show_fs(player, "assign_quest_step",
			{n_id = n_id, d_id = d_id, o_id = o_id})
		return
	end

	if(fields.switch_tab and fields.switch_tab == "2") then
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_id,
			 caller="show_if_action_failed"})
		return
	elseif(fields.switch_tab and fields.switch_tab == "1") then
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_id,
			 caller="show_if_action_succeeded"})
		return
	elseif(fields.switch_tab and fields.switch_tab == "3") then
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_id,
			 caller="show_tab_limit_guessing"})
		return
	elseif(fields.switch_tab and fields.switch_tab == "4") then
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_id,
			 caller="show_tab_limit_repeating"})
		return
	end

	-- this menu is specific to an option for a dialog; if no dialog is selected, we really
	-- can't know what to do
	if(not(o_id) and d_id) then
		yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = d_id})
	elseif(not(d_id)) then
		return
	end

	-- backwards compatibility to when this was a hidden field
	fields.o_id = o_id
	-- handles changes to o_text_when_prerequisites_met, target dialog, adding of a new dialog
	local result = yl_speak_up.edit_mode_apply_changes(pname, fields)
	-- if a new option was added or the target dialog of this one changed, display the right new option
	if(result and result["show_next_option"] and n_dialog.d_options[result["show_next_option"]]) then
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = result["show_next_option"],
			 caller="show_next_option"})
		return
	end

	if(fields.save_option) then
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_id, caller="save_option"})
		return
	end

	-- want to edit the text that is shown when switching to the next dialog?
	if(fields.button_edit_action_failed_dialog
	  or fields.button_edit_action_success_dialog
	  or fields.save_dialog_modification
	  or fields.button_edit_limit_action_failed_repeat
	  or fields.button_edit_limit_action_success_repeat
	  or fields.turn_alternate_text_into_new_dialog) then
		if( yl_speak_up.handle_edit_actions_alternate_text(
				-- x_id, id_prefix, target_element and tmp_data_cache are nil here
				player, pname, n_id, d_id, o_id, nil, nil,
				"edit_option_dialog", nil, fields, nil)) then
			-- the function above showed a formspec already
			return
		else
			yl_speak_up.show_fs(player, "edit_option_dialog",
				{n_id = n_id, d_id = d_id, o_id = o_id,
				caller="back_from_edit_dialog_modifications"})
			return
		end

	elseif(fields.back_from_edit_dialog_modification) then
		-- no longer working on an alternate text
		yl_speak_up.speak_to[pname].edit_alternate_text_for = nil
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_id, caller="back_from_edit_dialog_modifications"})
		return
	end

	-- back to the main dialog window?
	-- (this also happens when the last option was deleted)
	if(fields.show_current_dialog or fields.quit or fields.button_exit or not(d_option) or fields.del_option) then
		yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = d_id})
		return
	end

	-- the player wants to see the previous option/answer
	if(fields.edit_option_prev) then
		-- sort all options by o_sort
		local sorted_list = yl_speak_up.get_sorted_options(n_dialog.d_options, "o_sort")
		local o_found = o_id
		for i, o in ipairs(sorted_list) do
			if(o == o_id and sorted_list[ i-1]) then
				o_found = sorted_list[ i-1 ]
			end
		end
		-- show that dialog; fallback: show the same (o_id) again
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_found, caller="prev option"})
		return

	-- the player wants to see the next option/answer
	elseif(fields.edit_option_next) then
		-- sort all options by o_sort
		local sorted_list = yl_speak_up.get_sorted_options(n_dialog.d_options, "o_sort")
		local o_found = o_id
		for i, o in ipairs(sorted_list) do
			if(o == o_id and sorted_list[ i+1 ]) then
				o_found = sorted_list[ i+1 ]
			end
		end
		-- show that dialog; fallback: show the same (o_id) again
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = d_id, o_id = o_found, caller="next option"})
		return

	-- the player clicked on a precondition
	elseif(fields.table_of_preconditions) then
		yl_speak_up.show_fs(player, "edit_preconditions", fields.table_of_preconditions)
		return

	-- the player clicked on an action
	elseif(fields.table_of_actions) then
		yl_speak_up.show_fs(player, "edit_actions", fields.table_of_actions)
		return

	-- the player clicked on an effect
	elseif(fields.table_of_effects) then
		yl_speak_up.show_fs(player, "edit_effects", fields.table_of_effects)
		return
	end

	-- if ESC is pressed or anything else unpredicted happens: go back to the main dialog edit window
	-- reason: don't loose any unsaved changes to the dialog
	yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = d_id})
end


-- edit options (not via staff but via the "I am your owner" dialog)
yl_speak_up.get_fs_edit_option_dialog = function(player, n_id, d_id, o_id, caller)
	-- n_id, d_id and o_id have already been checked when this function is called
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	local n_dialog = dialog.n_dialogs[d_id]

	-- currently no trade running (we're editing options)
	yl_speak_up.trade[pname] = nil
	yl_speak_up.speak_to[pname].trade_id = nil

	if(not(n_dialog) or not(n_dialog.d_options) or not(n_dialog.d_options[o_id])) then
		return "size[6,2]"..
			"label[0.2,0.5;Ups! Option "..minetest.formspec_escape(tostring(o_id))..
				" does not exist.]"..
			"button_exit[2,1.5;1,0.9;exit;Exit]"
	end
	local d_option = n_dialog.d_options[o_id]

	-- if it is a quest step, then show that; else allow creating a quest step
	local quest_step_text = "button[15.4,0.1;6.0,0.9;assign_quest_step;Turn this into a quest step]"
	if(   d_option.quest_id   and d_option.quest_id   ~= ""
	  and d_option.quest_step and d_option.quest_step ~= "") then
		local q_id = ""
		local quest_name = "["..tostring(d_option.quest_id).."] - unknown quest -"
		for q_id, data in pairs(yl_speak_up.quests) do
			if(data and data.var_name == d_option.quest_id) then
				quest_name = "["..tostring(q_id)..": "..
					tostring(yl_speak_up.strip_pname_from_var(data.var_name, pname))..
					"] "..
					tostring(data.name)
			end
		end
		quest_step_text = table.concat({"box[4.9,0.0;14.0,1.1;#BB77BB]",
			"label[0.2,0.3;This is quest step:]",
			"label[5.0,0.3;",
				minetest.colorize("#00FFFF",
					minetest.formspec_escape(d_option.quest_step)),
					"]",
			"label[0.2,0.8;of the quest:]",
			"label[5.0,0.8;",
				minetest.colorize("#CCCCFF",
					minetest.formspec_escape(quest_name)),
					"]",
			"button[19.4,0.1;2.0,0.9;assign_quest_step;Change]"
			}, "")
	end


	-- offer the correct preselection for hidden/grey/show text
	local alternate_answer_option = "3"
	if(d_option.o_hide_when_prerequisites_not_met == "true") then
		alternate_answer_option = "1"
	elseif(d_option.o_grey_when_prerequisites_not_met == "true") then
		alternate_answer_option = "2"
	end

	local answer_mode = 0
	-- shall this option be choosen automaticly?
	if(d_option.o_autoanswer and d_option.o_autoanswer == 1) then
		answer_mode = 1
	-- or randomly?
	elseif(n_dialog.o_random) then
		answer_mode = 2
	end

	-- show an option only once
	local visit_only_once = 0
	if(d_option.o_visit_only_once and d_option.o_visit_only_once == 1) then
		visit_only_once = 1
	end

	local answer_text =
		-- answer of the player (the actual option)
		"container[0.0,8.3]"..
		"label[0.2,0.0;..the player may answer with this text"..
			minetest.formspec_escape(" [dialog option \""..tostring(o_id).."\"]:").."]"..
		"dropdown[13.3,-0.4;2.5,0.7;option_visits;"..
			"often,*once*;"..tostring(visit_only_once + 1)..";]"..
		"tooltip[option_visits;\"often\" allows to select this option whenever the\n"..
				"\tpreconditions are fulfilled.\n"..
				"\"*once*\" greys out the option after it has been selected\n"..
				"\tone time successfully.\n"..
				"Useful for visually marking options as read for the player.\n"..
				"Talking to the NPC anew resets this option and it can be selected again.]"..
		"dropdown[16.0,-0.4;5.3,0.7;option_autoanswer;"..
			"by clicking on it,automaticly,randomly;"..tostring(answer_mode+1)..";]"
			-- (automaticly *by fulfilling the prerequirements*)
	if(d_id == "d_got_item" or d_id == "d_trade") then
		answer_mode = 1
		d_option.o_autoanswer = 1
		answer_text =
			"container[0.0,8.3]"..
			"label[0.2,0.0;..this option will be selected automaticly.]"
	end
	if(answer_mode == 0 and (d_id ~= "d_got_item" and d_id ~= "d_trade")) then
		answer_text = table.concat({answer_text,
		"label[1.2,0.8;A:]",
		"field[1.7,0.3;19.6,0.9;text_option_",
			minetest.formspec_escape(o_id),
			";;",
			minetest.formspec_escape(d_option.o_text_when_prerequisites_met),
			"]",
		"tooltip[option_text_met;This is the answer the player may choose if the "..
			"preconditions are all fulfilled.]",
		-- dropdown for selecting weather to show the alternate answer or not
		"label[0.2,1.7;..but if at least one pre(C)ondition is not fulfilled, then...]",
		"dropdown[12.0,1.3;9.3,0.7;hide_or_grey_or_alternate_answer;",
			"..hide this answer.,",
			"..grey out the following answer:,",
			"..display the following alternate answer:;",
			alternate_answer_option,
			";]",
		-- alternate answer
		"label[1.2,2.5;A:]",
		"field[1.7,2.0;19.6,0.9;option_text_not_met;;",
			minetest.formspec_escape(d_option.o_text_when_prerequisites_not_met),
			"]",
		"tooltip[option_text_not_met;This is the answer the player may choose if the "..
			"preconditions are NOT all fulfilled.]",
		"container_end[]"
		}, "")
	elseif(answer_mode == 1) then
		answer_text = answer_text..
		"label[1.2,0.8;This option will not be shown but will be selected automaticly if all "..
			"prerequirements are fullfilled.]"..
		"label[1.2,1.4;The remaining options of this dialog will in this case not be evaluated.]"..
		"label[1.2,2.0;The NPC will proceed as if this option was choosen manually.]"..
		"label[1.2,2.6;"
		if(d_id == "d_got_item") then
			answer_text = answer_text..
				"Note: This is used here to process items that the player gave to the NPC."
		elseif(d_id == "d_trade") then
			answer_text = answer_text..
				"Note: This is useful for refilling stock by crafting new things when "..
				"necessary, or for getting\nsupplies from a storage, or for storing "..
				"traded goods in external storage chests."
		else
			answer_text = answer_text..
				"This is i.e. useful for offering a diffrent start dialog depending on the "..
				"player's progress in a quest."
		end
		answer_text = answer_text .. "]container_end[]"
	elseif(answer_mode == 2) then
		answer_text = answer_text..
		"label[1.2,0.8;One option of the dialog - for example this one - will be selected randomly.]"..
		"label[1.2,1.4;The other options of this dialog will be set to random as well.]"..
		"label[1.2,2.0;The NPC will proceed as if this dialog was choosen manually.]"..
		"label[1.2,2.6;Useful for small talk for generic NPC but usually not for quests.]"..
		"container_end[]"
	end

	-- remember which option we are working at (better than a hidden field)
	yl_speak_up.speak_to[pname].o_id = o_id
	-- are there any preconditions?
	local list_of_preconditions = ""
	local prereq = d_option.o_prerequisites
	local count_prereq = 0
	if(prereq) then
		local sorted_key_list = yl_speak_up.sort_keys(prereq)
		for i, k in ipairs(sorted_key_list) do
			local v = prereq[ k ]
			list_of_preconditions = list_of_preconditions..
				minetest.formspec_escape(v.p_id)..",#FFFF00,"..
				minetest.formspec_escape(v.p_type)..","..
				minetest.formspec_escape(
					yl_speak_up.show_precondition(v, pname))..","
			count_prereq = count_prereq + 1
		end
	end
	if(count_prereq < yl_speak_up.max_prerequirements) then
		list_of_preconditions = list_of_preconditions..",#00FF00,add,Add a new pre(C)ondition"
	else
		list_of_preconditions = list_of_preconditions..",#AAAAAA,-,"..
			"Maximum amount of pre(C)onditions per option reached!"
	end

	-- build action list the same way as list of preconditions and effects
	local list_of_actions = ""
	local actions = d_option.actions
	local count_actions = 0
	local action_data = nil
	-- if autoanswer or random is choosen, then there can be no action
	if(answer_mode == 1 or answer_mode == 2) then
		actions = nil
		count_actions = 0
		caller = ""
	end
	if(actions) then
		local sorted_key_list = yl_speak_up.sort_keys(actions)
		for i, k in ipairs(sorted_key_list) do
			local v = actions[ k ]
			list_of_actions = list_of_actions..
				minetest.formspec_escape(v.a_id)..",#FFFF00,"..
				minetest.formspec_escape(v.a_type)..","..
				minetest.formspec_escape(
					yl_speak_up.show_action(v))..","
			count_actions = count_actions + 1
			action_data = v
		end
	end
	if(count_actions < yl_speak_up.max_actions) then
		list_of_actions = list_of_actions..",#00FF00,add,Add a new (A)ction"
	else
		list_of_actions = list_of_actions..",#AAAAAA,-,"..
			"Maximum amount of (A)ctions per option reached!"
	end

	-- list of (A)ctions (there can only be one per option; i.e. a trade)
	local action_list_text =
		"container[0.0,12.0]"..
		"label[0.2,0.0;When this answer has been selected, start the following (A)ction:]"..
		"tablecolumns[text;color,span=1;text;text]"
	if(answer_mode == 1) then
		action_list_text = action_list_text..
		"label[1.2,0.6;No actions are executed because this option here is automaticly selected.]"..
		"container_end[]"
	elseif(answer_mode == 2) then
		action_list_text = action_list_text..
		"label[1.2,0.6;No actions are executed because this option here is selected randomly.]"..
		"container_end[]"
	else
		action_list_text = action_list_text..
		"table[1.2,0.3;20.2,0.7;table_of_actions;"..
			list_of_actions..";0]"..
		"container_end[]"
	end

	-- find the right target dialog for this option (if it exists)
	local target_dialog = nil
	-- which effect holds the information about the target dialog?
	-- set this to a fallback for yl_speak_up.show_colored_dialog_text
	local target_effect = {r_id = "-?-", r_type = "dialog"}
	-- and build the list of effects
	local results = d_option.o_results
	-- create a new dialog type option if needed
	if(not(results) or not(next(results))) then
		target_dialog = yl_speak_up.prepare_new_dialog_for_option(
			dialog, pname, n_id, d_id, o_id,
			yl_speak_up.text_new_dialog_id,
			results)
		-- make sure we are up to date (a new option was inserted)
		results = d_option.o_results
	end
	-- constructs the list_of_effects; may also update target_dialog and target_effect
	local res = yl_speak_up.get_list_of_effects_and_target_dialog_and_effect(dialog, results, pname,
										target_dialog, target_effect)
	local list_of_effects = res.list
	target_dialog = res.target_dialog
	target_effect = res.target_effect

	-- if no target dialog has been selected: default is to go to the dialog with d_sort 0
	if(not(target_dialog) or target_dialog == "" or
	  (not(dialog.n_dialogs[target_dialog])
	    and target_dialog ~= "d_end"
	    and target_dialog ~= "d_got_item")) then
		for d, v in pairs(dialog.n_dialogs) do
			if(v.d_sort and tonumber(v.d_sort) == 0) then
				target_dialog = d
			end
		end
	end
	-- build the list of available dialogs for the dropdown list(s)
	local dialog_list = yl_speak_up.text_new_dialog_id
	local dialog_selected = "1"
	-- if there are dialogs defined
	if(dialog and dialog.n_dialogs) then
		-- the first entry will be "New dialog"
		local n = 1
		for k, v in pairs(dialog.n_dialogs) do
			local d_name = (v.d_name or v.d_id or "?")
			-- build the list of available dialogs for the dropdown list(s)
			dialog_list = dialog_list..","..minetest.formspec_escape(d_name)
			-- which one is the current dialog?
			n = n + 1
			if(v.d_id == target_dialog) then
				dialog_selected = tostring(n)
			end
		end
		if(target_dialog == "d_end") then
			dialog_selected = tostring(n + 1)
		end
	end
	dialog_list = dialog_list..",d_end"
	if(not(target_dialog)) then
		target_dialog = "- none -"
	end


	-- can the button "prev(ious)" be shown?
	local button_prev = ""
	-- can the button "next" be shown?
	local button_next = ""
	-- sort all options by o_sort
	local sorted_list = yl_speak_up.get_sorted_options(n_dialog.d_options, "o_sort")
	local o_found = o_id
	local anz_options = 0
	for i, o in ipairs(sorted_list) do
		-- the buttons are inside a container; thus, Y is 0.0
		if(o == o_id and sorted_list[ i-1 ]) then
			button_prev = ""..
				"button[7.9,0.0;2.0,0.9;edit_option_prev;Prev]"..
				"tooltip[edit_option_prev;Go to previous option/answer "..
				"(according to o_sort).]"
		end
		if(o == o_id and  sorted_list[ i+1 ]) then
			button_next = ""..
				"button[12.5,0.0;2.0,0.9;edit_option_next;Next]"..
				"tooltip[edit_option_next;Go to next option/answer "..
				"(according to o_sort).]"
		end
		anz_options = anz_options + 1
	end

	-- less than yl_speak_up.max_number_of_options_per_dialog options?
	local button_add = ""..
		-- the buttons are inside a container; thus, Y is 0.0
		"button[2.4,0.0;2.0,0.9;add_option;Add]"..
		"tooltip[add_option;Add a new option/answer to this dialog.]"
	if(anz_options >= yl_speak_up.max_number_of_options_per_dialog
	  or target_dialog == "d_end") then
		button_add = ""
	end

	-- make all following coordinates relative
	local action_text = "container[0.2,14.0]"..
		"box[0.25,0.0;21.0,6.7;#555555]"
	local tab_list = "tabheader[0.2,0.0;switch_tab;"..
				"If the action was successful:,"..
				"If the action failed:,"..
				"Limit guessing:,"..
				"Limit repeating:"
	-- show what happens if the action fails
	if(caller == "show_if_action_failed") then
		-- allow to switch between successful and failed actions
		action_text = action_text..tab_list..";2;true;true]"..
			"label[0.4,0.6;"..
			"If the player *failed* to complete the above action correctly,]"
		if(action_data and action_data.a_on_failure
		  and dialog.n_dialogs and dialog.n_dialogs[ action_data.a_on_failure]) then
			action_text = action_text..
			-- ..and what the NPC will reply to that answer
				"tooltip[1.2,3.9;19.6,2.5;This is what the NPC will say next when "..
					"the player has failed to complete the action.]"..

				"container[0.0,3.2]"..
				"label[0.4,0.4;..the NPC will react to this failed action with the "..
					"following dialog \""..tostring(action_data.a_on_failure)..
					"\""..
				yl_speak_up.show_colored_dialog_text(
					dialog,
					action_data,
					action_data.a_on_failure,
					"1.2,0.7;19.6,2.5;d_text_next",
					"with the *modified* text",
					":]",
					"button_edit_action_failed_dialog")..
				"container_end[]"
		else
			action_text = action_text..
				"label[0.4,3.6;..go back to the initial dialog.]"
		end
	-- show time-based restrictions (max guesses per time);
	-- the values will be saved in function yl_speak_up.edit_mode_apply_changes
	elseif( caller == "show_tab_limit_guessing") then
		local timer_name = "timer_on_failure_"..tostring(d_id).."_"..tostring(o_id)
		local timer_data = yl_speak_up.get_variable_metadata(timer_name, "parameter", true)
		if(not(timer_data)) then
			timer_data = {}
		end
		action_text = table.concat({action_text,
				tab_list,
				";3;true;true]",
			-- allow to switch between successful and failed actions
			"label[0.4,0.6;",
				"Apply the following time-based restrictions to limit wild guessing:]",
			-- timer for failed actions
			"label[0.4,1.6;The player can make]",
			"field[4.9,1.0;1.5,0.9;timer_max_attempts_on_failure;;",
				tostring(timer_data[ "max_attempts" ] or 0),
				"]",
			"label[6.7,1.6;attempts to complete this action successfully each]",
			"field[17.5,1.0;1.5,0.9;timer_max_seconds_on_failure;;",
				tostring(timer_data[ "duration" ] or 0),
				"]",
			"label[19.2,1.6;seconds.]",
			"label[0.4,2.2;Hint: 3 attempts per 1200 seconds (=20 minutes or one MineTest day)"..
				" may be good values to\navoid wild guessing while not making the player "..
				"having to wait too long to try again.]"..
			"tooltip[timer_max_attempts_on_failure;How many tries shall the player have?"..
				"\nA value of 0 disables this restriction.]"..
			"tooltip[timer_max_seconds_on_failure;After which time can the player try again?"..
				"\nA value of 0 disables this restriction.]"..
			-- ..and what the NPC will explain in such a case
			"tooltip[1.2,3.9;19.6,2.5;This is what the NPC will say next when "..
				"\nthe player has failed to complete the action too"..
				"\nmany times for the NPC's patience and the player"..
				"\nhas to wait some time before guessing again.]"..
			"container[0.0,3.2]"..
			"label[0.4,0.4;The NPC will explain his unwillingness to accept more "..
				"guesses ",
			yl_speak_up.show_colored_dialog_text(
				dialog,
				{alternate_text = (timer_data[ "alternate_text" ]
					          or yl_speak_up.standard_text_if_action_failed_too_often)},
				d_id, -- show the same dialog again
				"1.2,0.7;19.6,2.5;d_text_next",
				"with the following text",
				":]",
				"button_edit_limit_action_failed_repeat"),
			"container_end[]"
			}, "")
	-- show time-based restrictions (time between repeating this action successfully)
	elseif( caller == "show_tab_limit_repeating") then
		local timer_name = "timer_on_success_"..tostring(d_id).."_"..tostring(o_id)
		local timer_data = yl_speak_up.get_variable_metadata(timer_name, "parameter", true)
		if(not(timer_data)) then
			timer_data = {}
		end
		action_text = table.concat({action_text,
				tab_list,
				";4;true;true]",
			"label[0.4,0.6;",
				"Apply the following time-based restrictions to limit too quick repeating:]",
			-- timer for successful actions
			"label[0.4,1.6;If the player completed the action successfully, he shall have to"..
				" wait]",
			"field[15.0,1.0;1.5,0.9;timer_max_seconds_on_success;;",
				tostring(timer_data[ "duration" ] or 0),
				"]",
			"label[16.7,1.6;seconds until he]",
			"label[0.4,2.1;can repeat the action. Hint: 1200 seconds (=20 minutes or one ",
				"MineTest day) may be a good value.]",
			"tooltip[timer_max_seconds_on_success;",
				minetest.formspec_escape(
				"If you hand out a quest item, you may not want the player"..
				"\nto immediately repeat the action countless times, thus"..
				"\nemptying the NPC's storage and using the quest item for"..
				"\nother purposes. On the other hand, quest items may get "..
				"\nlost, so the player needs a way to repeat each step."..
				"\n1200 seconds may be a good value here as well."),
				"]",
			-- ..and what the NPC will explain in such a case
			"tooltip[1.2,3.9;19.6,2.5;",
				minetest.formspec_escape(
				"This is what the NPC will say next when the player"..
				"\nwants to repeat the action too soon for the NPC's"..
				"\ntaste - after all the NPC does not have infinite "..
				"\ninventory ressources, and the player may abuse the "..
				"\nquest item for entirely diffrent purposes.."),
				"]",
			"container[0.0,3.2]",
			-- this will lead back to the same dialog
			"label[0.4,0.4;The NPC will explain his unwillingness to repeat the "..
				"action so soon ",
			yl_speak_up.show_colored_dialog_text(
				dialog,
				{alternate_text = (timer_data[ "alternate_text" ]
						   or yl_speak_up.standard_text_if_action_repeated_too_soon)},
				d_id, -- show the same dialog again
				"1.2,0.7;19.6,2.5;d_text_next",
				"with the following text",
				":]",
				"button_edit_limit_action_success_repeat"),
			"container_end[]"
			}, "")
	-- show what happens if the action was successful
	else
		-- no action defined
		if(count_actions == 0) then
			-- do not show tabheader
			action_text = action_text..
				"label[0.4,0.6;"..
				"There is no (A)ction defined. Directly apply the following (Ef)fects:]"
		else
			-- allow to switch between successful and failed actions
			action_text = table.concat({action_text,
					tab_list,
					";1;true;true]",
				"label[0.4,0.6;",
					"If the player completed the above action successfully, "..
					"apply the following (Ef)fects:]"
				}, "")
		end
		action_text = table.concat({action_text,
			-- list of effects
			"tablecolumns[text;color,span=1;text;text]",
			"table[1.2,0.9;19.6,2.0;table_of_effects;",
				list_of_effects,
				";0]",
			"tooltip[1.2,0.9;19.6,2.0;"..
				"*All* (Ef)fects are executed after the action (if there is\n"..
				"one defined in this option) has been completed successfully\n"..
				"by the player. If there is no action defined, then the\n"..
				"(Ef)fects will always be executed when this option here is\n"..
				"selected.\n"..
				"Please click on an (Ef)fect in order to edit or delete it!]",
			"container[0.0,3.2]",
			"label[0.4,0.4;The NPC will react to this answer with dialog:]"
			}, "")
		if(d_id == "d_trade") then
			action_text = action_text..
				"label[13.5,0.4;..by showing his trade list.]"..
				"container_end[]"
		else
			action_text = table.concat({action_text,
			-- allow to change the target dialog via a dropdown menu
			"dropdown[11,0.0;9.8,0.7;d_id_",
				minetest.formspec_escape(o_id),
				";",
				dialog_list,
				";",
				dialog_selected,
				",]",
			"tooltip[10.2,0.0;3.0,0.7;Select the target dialog with which the NPC shall react "..
				"to this answer.\nCurrently, dialog \"",
				minetest.formspec_escape(target_dialog),
				"\" is beeing displayed.;#FFFFFF;#000000]",
			-- ..and what the NPC will reply to that answer
			"tooltip[1.2,0.7;19.6,2.5;This is what the NPC will say next when the player has "..
				"selected this answer here.]",
			yl_speak_up.show_colored_dialog_text(
				dialog,
				-- this is either the "dialog" effect or an empty fallback
				target_effect,
				-- this is the text the NPC will say in reaction to this answer
				target_dialog,
				"1.2,0.7;19.6,2.5;d_text",
				"label[13.5,0.4;with the following *modified* text:]",
				"",
				"button_edit_action_success_dialog"),
				"container_end[]"
			}, "")
		end
	end
	action_text = action_text.."container_end[]"

	-- build up the formspec
	local formspec = table.concat({
		"size[22,22]",
		"bgcolor[#00000000;false]",
		-- button back to the current dialog (of which this is an option)
		"button[16.4,0.2;5.0,0.9;show_current_dialog;Back to dialog ",
			minetest.formspec_escape(d_id),
			"]",
		"tooltip[show_current_dialog;Go back to dialog ",
			minetest.formspec_escape(d_id),
			" and continue editing that dialog.]",
		-- tell the player what this formspec is about
		"label[6.5,0.4;You are editing dialog option \"",
			tostring(o_id),
			"\":]",

		-- the text the NPC says
		"container[0.0,0.9]",
		"label[0.2,0.0;NPC says ",
			minetest.formspec_escape("[dialog \""..tostring(d_id).."\"]:"),
			"]",
		yl_speak_up.show_colored_dialog_text(
			dialog,
			{r_id = "", r_type = "dialog"},
			d_id,
			"1.2,0.3;20.2,2.5;d_text",
			"", -- no modifications possible at this step
			"",
			""), -- no edit button here as this text cannot be changed here
		"tooltip[1.2,0.3;20.2,3.0;This is what the NPC says to the player.]",
		"container_end[]",

		"container[0.0,3.9]",
			quest_step_text,
		"container_end[]",

		-- list the preconditions
		"container[0.0,5.4]",
		"label[0.2,0.0;If all of the following pre(C)onditions are fulfilled:]",
		"tablecolumns[text;color,span=1;text;text]",
		"table[1.2,0.3;20.2,2.0;table_of_preconditions;",
			list_of_preconditions,
			";0]",
		"tooltip[1.2,0.3;20.2,2.0;",
			"*All* pre(C)onditions need to be true in order\n"..
			"for the option to be offered to the player.\n"..
			"Please click on a pre(C)ondition in order\n"..
			"to edit or delete it!]",
		"container_end[]",

		-- answer of the player (the actual option)
		answer_text,

		-- list of (A)ctions (there can only be one per option; i.e. a trade)
		action_list_text,

		-- list effects and target dialog for successful - and target dialog for unsuccessful
		-- actions (including a toggle button)
		action_text,

		-- container for the buttons/footer
		"container[0.0,20.9]",
		-- button: delete
		"button[0.2,0.0;2.0,0.9;del_option;Delete]",
		"tooltip[del_option;Delete this option/answer.]",
		-- button: add new
		button_add,
		-- button: save
		"button[4.6,0.0;2.0,0.9;save_option;Save]",
		"tooltip[save_option;Save what you canged (or discard it).]",
		-- button: prev/next
		button_prev,
		button_next,
		-- button: go back to dialog (repeated from top of the page)
		"button[15.8,0.0;5.0,0.9;show_current_dialog;Back to dialog ",
			minetest.formspec_escape(d_id),
			"]",
		"tooltip[show_current_dialog;Go back to dialog ",
			minetest.formspec_escape(d_id),
			" and continue editing that dialog.]",
		-- allow to enter o_sort
		"label[10.1,0.5;Sort:]",
		"field[11.1,0.0;1.0,0.9;edit_option_o_sort;;",
			minetest.formspec_escape(d_option.o_sort),
			"]",
		"tooltip[edit_option_o_sort;o_sort: The lower the number, the higher up in the "..
			"list this option goes\nNegative values are ignored;#FFFFFF;#000000]",
		"container_end[]"
		}, "")
	return formspec
end


yl_speak_up.get_fs_edit_option_dialog_wrapper = function(player, param)
	if(not(param)) then
		param = {}
	end
	local pname = player:get_player_name()
	yl_speak_up.speak_to[pname].o_id = param.o_id
	return yl_speak_up.get_fs_edit_option_dialog(player, param.n_id, param.d_id, param.o_id, param.caller)
end


yl_speak_up.register_fs("edit_option_dialog",
	yl_speak_up.input_edit_option_dialog,
	yl_speak_up.get_fs_edit_option_dialog_wrapper,
	-- no special formspec required:
	nil
)
