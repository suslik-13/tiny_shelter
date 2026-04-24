

-- helper function for yl_speak_up.edit_mode_apply_changes;
-- makes sure the new dialog (and a result/effect "dialog" for each option) exist
yl_speak_up.prepare_new_dialog_for_option = function(dialog, pname, n_id, d_id, o_id,target_dialog,o_results)
	-- this may also point to a new dialog
	if(target_dialog == yl_speak_up.text_new_dialog_id) then
		-- create a new dialog and show it as new target dialog - but do not display
		-- this dialog directly (the player may follow the -> button)
		target_dialog = yl_speak_up.add_new_dialog(dialog, pname, nil)
	end
	-- translate name into dialog id (d_end is also legitimate)
	if(target_dialog ~= "d_end") then
		target_dialog = yl_speak_up.d_name_to_d_id(dialog, target_dialog)
	end
	-- is there a result/effect of the type "dialog" already? else use a fallback
	local result = {} --{r_value = "-default-"}
	if(o_results) then
		for kr, vr in pairs(o_results) do
			if( vr.r_type == "dialog" ) then
				result = vr
				-- no problem - the right dialog is set already
				if(result.r_value and result.r_value == target_dialog) then
					return target_dialog
				else
					-- no need to search any further
					break
				end
			end
		end
	end
	local old_d = tostring(result.r_value or "-default-")
	if(result.r_value and dialog.n_dialogs[result.r_value] and dialog.n_dialogs[result.r_value].d_name) then
		old_d = old_d..":"..tostring(dialog.n_dialogs[result.r_value].d_name)
	end
	local new_d = tostring(target_dialog)
	if(target_dialog and dialog.n_dialogs[target_dialog] and dialog.n_dialogs[target_dialog].d_name) then
		new_d = new_d..":"..tostring(dialog.n_dialogs[target_dialog].d_name)
	end
	-- store that a new option has been added to this dialog
	table.insert(yl_speak_up.npc_was_changed[ n_id ],
		"Dialog "..d_id..": The target dialog for option "..
		tostring(o_id).." was changed from "..
		old_d.." to "..new_d..".")
	-- does the result/effect of type "dialog" exist already? then we're done
	if(result.r_type and result.r_type == "dialog") then
		-- actually change the target dialog
		result.r_value = target_dialog
		return target_dialog
	end
	-- create a new result (first the id, then the actual result)
	local future_r_id = yl_speak_up.add_new_result(dialog, d_id, o_id)
	-- actually store the new result
	dialog.n_dialogs[d_id].d_options[o_id].o_results[future_r_id] = {
		r_id = future_r_id,
		r_type = "dialog",
		r_value = target_dialog}
	return target_dialog
end


-- helper function for formspec "yl_speak_up:talk" *and* formspec "yl_speak_up:edit_option_dialog"
-- when a parameter was changed in edit mode;
-- this is called when the player is in edit_mode (editing the NPC);
-- the function checks if the player has changed any parameters
-- Parameters:
--    pname    player name
--    fields   the fields returned from the formspec
-- Returns:
--    result   table with information about what was added
--             (for now, only result.show_next_option is of intrest in the option edit menu)
yl_speak_up.edit_mode_apply_changes = function(pname, fields)
	local n_id = yl_speak_up.edit_mode[pname]
	if(not(n_id) or not(yl_speak_up.speak_to[pname])) then
		return
	end
	local d_id = yl_speak_up.speak_to[pname].d_id
	local dialog = yl_speak_up.speak_to[pname].dialog

	-- check if the player is allowed to edit this NPC
	if(not(yl_speak_up.may_edit_npc(minetest.get_player_by_name(pname), n_id))) then
		return
	end

	-- this way we can store the actual changes and present them to the player for saving
	if(not(yl_speak_up.npc_was_changed[ n_id ])) then
		yl_speak_up.npc_was_changed[ n_id ] = {}
	end


	-- nothing to do if that dialog does not exist
	if(not(d_id) or not(dialog.n_dialogs) or not(dialog.n_dialogs[ d_id ])) then
		return
	end

	-- allow owner to mute/unmute npc (would be bad if players can already see what is going
	-- to happen while the owner creates a long quest)
	-- mute/unmute gets logged in the function and does not need extra log entries
	local obj = yl_speak_up.speak_to[pname].obj
	if(fields.mute_npc and obj) then
		yl_speak_up.set_muted(pname, obj, true)
	elseif(fields.un_mute_npc and obj) then
		yl_speak_up.set_muted(pname, obj, false)
	end

	-- changes to d_dynamic are *not* changed (the content of that dialog has to be provided
	-- dynamicly by a function):
	if(d_id == "d_dynamic") then
		return
	end

	-- new options etc. may be added; store these IDs so that we can switch to the right target
	local result = {}

	-- make this the first dialog shown when starting a conversation
	if(fields.make_first_option) then
		-- check which dialog(s) previously had the highest priority and change thsoe
		for k, v in pairs(dialog.n_dialogs) do
			if(v and v.d_sort and (v.d_sort=="0" or v.d_sort==0)) then
				-- try to derive a sensible future sort priority from the key:
				-- here we make use of the d_<nr> pattern; but even if that fails to yield
				-- a number, the sort function will later be able to deal with it anyway
				local new_priority = string.sub(k, 3)
				dialog.n_dialogs[ k ].d_sort = new_priority
			end
		end
		-- actually make this the chat with the highest priority
		dialog.n_dialogs[ d_id ].d_sort = "0"
		-- this is not immediately saved, even though the changes to the previous dialog with
		-- the highest priority cannot be automaticly undone (but as long as it is not saved,
		-- it really does not matter; and when saving, the player has to take some care)
		table.insert(yl_speak_up.npc_was_changed[ n_id ],
			"Dialog "..d_id..": Turned into new start dialog.")
	end

	-- if it is *a* start dialog: buttons like give item to npc/trade/etc. will be shown
	if(fields.turn_into_a_start_dialog) then
		if(dialog.n_dialogs[ d_id ].is_a_start_dialog) then
			-- no need to waste space...
			dialog.n_dialogs[ d_id ].is_a_start_dialog = nil
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": Is no longer *a* start dialog (regarding buttons).")
		else
			dialog.n_dialogs[ d_id ].is_a_start_dialog = true
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": Turned into *a* start dialog (regarding buttons).")
		end
	end

	-- detect changes to d_text: text of the dialog (what the npc is saying)
	-- (only happens in dialog edit menu)
	if(fields.d_text and dialog.n_dialogs[ d_id ].d_text ~= fields.d_text) then
		-- store that there have been changes to this npc
		table.insert(yl_speak_up.npc_was_changed[ n_id ],
			"Dialog "..d_id..": d_text (what the NPC says) was changed from \""..
			tostring( dialog.n_dialogs[ d_id ].d_text)..
			"\" to \""..tostring(fields.d_text).."\".")
		-- actually change the text - but do not save to disk yet
		dialog.n_dialogs[ d_id ].d_text = fields.d_text
	end

	if(fields.d_name and fields.d_name ~= "" and dialog.n_dialogs[ d_id ].d_name ~= fields.d_name) then
		if(fields.d_name ~= d_id
		  and not(yl_speak_up.is_special_dialog(d_id))) then
			local err_msg = nil
			-- check if there are no duplicate names
			for k, v in pairs(dialog.n_dialogs) do
				if(v and v.d_name and v.d_name == fields.d_name and k ~= d_id) then
					err_msg = "Sorry. That name has already been used for dialog "..
							tostring(k).."."
				end
			end
			if(dialog.n_dialogs[fields.d_name]) then
				err_msg = "Sorry. There is already a dialog with a dialog id of "..
						tostring(fields.d_name).."."
			elseif(yl_speak_up.is_special_dialog(fields.d_name)) then
				err_msg = "Sorry. That is a special dialog ID. You cannot use it as "..
						"a manually set name."
			elseif(string.sub(fields.d_name, 1, 2) == "d_") then
				err_msg = "Sorry. Names starting with \"d_\" are not allowed. They "..
						"may later be needed for new dialogs."
			end
			-- TODO: check if the name is allowed (only normal chars, numbers and underscore)
			if(err_msg) then
				minetest.chat_send_player(pname, err_msg)
			else
				table.insert(yl_speak_up.npc_was_changed[ n_id ],
					"Dialog "..d_id..": renamed from \""..
						tostring(dialog.n_dialogs[ d_id ].d_name)..
						"\" to \""..tostring(fields.d_name).."\".")
				dialog.n_dialogs[ d_id ].d_name = fields.d_name
			end
		end
	end

	-- add a new option/answer
	if(fields[ "add_option"]) then
		local future_o_id = yl_speak_up.add_new_option(dialog, pname, nil, d_id, "", d_id)
		if(not(future_o_id)) then
			-- this is already checked earlier on and the button only shown if
			-- options can be added; so this can reamin a chat message
			minetest.chat_send_player(pname, "Sorry. Only "..
				tostring(yl_speak_up.max_number_of_options_per_dialog)..
				" options/answers are allowed per dialog.")
			fields.add_option = nil
		else
			-- add_new_option has added a dialog result for us already - no need to do that again

			-- if this is selected in the options edit menu, we want to move straight on to the new option
			result["show_next_option"] = future_o_id
		end
	end

	-- delete an option directly from the main fs_talkdialog
	if(dialog.n_dialogs[d_id].d_options) then
		for o_id, o_v in pairs(dialog.n_dialogs[d_id].d_options) do
			if(o_id and fields["delete_option_"..o_id]) then
				fields["del_option"] = true
				fields.o_id = o_id
			-- ..or move an option up by one in the list
			elseif(o_id and fields["option_move_up_"..o_id]) then
				fields["option_move_up"] = true
				fields.o_id = o_id
			-- ..or move an option down by one in the list
			elseif(o_id and fields["option_move_down_"..o_id]) then
				fields["option_move_down"] = true
				fields.o_id = o_id
			end
		end
	end

	if(fields[ "del_option"] and fields.o_id and dialog.n_dialogs[d_id].d_options[fields.o_id]) then
		local o_id = fields.o_id
		-- which dialog to show instead of the deleted one?
		local next_o_id = o_id
		local sorted_list = yl_speak_up.get_sorted_options(dialog.n_dialogs[d_id].d_options, "o_sort")
		for i, o in ipairs(sorted_list) do
			if(o == o_id and sorted_list[ i+1 ]) then
				next_o_id = sorted_list[ i+1 ]
			elseif(o == o_id and sorted_list[ i-1 ]) then
				next_o_id = sorted_list[ i-1 ]
			end
		end
		table.insert(yl_speak_up.npc_was_changed[ n_id ],
			"Dialog "..d_id..": Option "..tostring(o_id).." deleted.")
		-- actually delete the dialog
		dialog.n_dialogs[d_id].d_options[o_id] = nil
		-- the current dialog is deleted; we need to show another one
		result["show_next_option"] = next_o_id
		-- after deleting the entry, all previous/further changes to it are kind of unintresting
		return result
	end

	-- move an option up by one
	local d_options = dialog.n_dialogs[d_id].d_options
	if(fields[ "option_move_up"] and fields.o_id and d_options[fields.o_id]) then
		local sorted_o_list = yl_speak_up.get_sorted_options(d_options, "o_sort")
		local idx = table.indexof(sorted_o_list, fields.o_id)
		if(idx > 1) then
			-- swap the two positions
			local tmp = dialog.n_dialogs[d_id].d_options[fields.o_id].o_sort
			dialog.n_dialogs[d_id].d_options[fields.o_id].o_sort =
				dialog.n_dialogs[d_id].d_options[sorted_o_list[idx - 1]].o_sort
			dialog.n_dialogs[d_id].d_options[sorted_o_list[idx - 1]].o_sort = tmp
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": Option "..tostring(fields.o_id).." was moved up by one.")
		end
	-- ..or move the option down by one
	elseif(fields[ "option_move_down"] and fields.o_id and d_options[fields.o_id]) then
		local sorted_o_list = yl_speak_up.get_sorted_options(d_options, "o_sort")
		local idx = table.indexof(sorted_o_list, fields.o_id)
		if(idx > 0 and idx < #sorted_o_list) then
			local tmp = dialog.n_dialogs[d_id].d_options[fields.o_id].o_sort
			dialog.n_dialogs[d_id].d_options[fields.o_id].o_sort =
				dialog.n_dialogs[d_id].d_options[sorted_o_list[idx + 1]].o_sort
			dialog.n_dialogs[d_id].d_options[sorted_o_list[idx + 1]].o_sort = tmp
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": Option "..tostring(fields.o_id).." was moved down by one.")
		end
	end

	-- ignore entries to o_sort if they are not a number
	if(fields[ "edit_option_o_sort"]
	  and tonumber(fields[ "edit_option_o_sort"])
	  and fields.o_id and dialog.n_dialogs[d_id].d_options[fields.o_id]) then
		local o_id = fields.o_id
		local new_nr = tonumber(fields[ "edit_option_o_sort"])
		local old_nr = tonumber(dialog.n_dialogs[d_id].d_options[o_id].o_sort)
		-- if the nr is -1 (do not show) then we are done already: nothing to do
		if(old_nr == new_nr) then
		-- -1: do not list as option/answer (but still store and keep it)
		elseif(new_nr == -1 and old_nr ~= -1) then
			dialog.n_dialogs[d_id].d_options[o_id].o_sort = "-1"
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": Option "..tostring(o_id).." was set to -1 (do not list).")
		else
			-- get the old sorted list
			local sorted_list = yl_speak_up.get_sorted_options(dialog.n_dialogs[d_id].d_options, "o_sort")
			-- negative numbers are not shown
			local entries_shown_list = {}
			for i, o in ipairs(sorted_list) do
				local n = tonumber(dialog.n_dialogs[d_id].d_options[o].o_sort)
				if(n and n > 0 and o ~= o_id) then
					table.insert(entries_shown_list, o)
				end
			end
			-- insert the entry at the new position and let lua do the job
			table.insert(entries_shown_list, new_nr, o_id)
			-- take the indices from that new list as new sort values and store them;
			-- this has the side effect that duplicate entries get sorted out as well
			for i, o in ipairs(entries_shown_list) do
				dialog.n_dialogs[d_id].d_options[o].o_sort = tostring(i)
			end
			-- store that there was a cahnge
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": Option "..tostring(o_id).." was moved to position "..
				tostring(new_nr)..".")
		end
	end

	-- changes to options are not possible if there are none
	if(dialog.n_dialogs[ d_id ].d_options) then

		-- detect changes to text_option_<o_id>: text for option <o_id>
		for k, v in pairs(dialog.n_dialogs[ d_id ].d_options) do
			if(   fields[ "text_option_"..k ]
			  and fields[ "text_option_"..k ] ~= v.o_text_when_prerequisites_met ) then
				-- store that there have been changes to this npc
				table.insert(yl_speak_up.npc_was_changed[ n_id ],
					"Dialog "..d_id..": The text for option "..tostring(k)..
					" was changed from \""..tostring(v.o_text_when_prerequisites_met)..
					"\" to \""..tostring(fields[ "text_option_"..k]).."\".")
				-- actually change the text of the option
				dialog.n_dialogs[ d_id ].d_options[ k ].o_text_when_prerequisites_met = fields[ "text_option_"..k ]
			end
		end

		-- detect changes to d_id_<o_id>: target dialog for option <o_id>
		for k, v in pairs(dialog.n_dialogs[ d_id ].d_options) do
			if(fields[ "d_id_"..k ]) then
				local new_target_dialog = yl_speak_up.prepare_new_dialog_for_option(
					dialog, pname, n_id, d_id, k, fields[ "d_id_"..k ], v.o_results)
				if(new_target_dialog ~= fields[ "d_id_"..k ]
				  and not(  dialog.n_dialogs[new_target_dialog]
				        and dialog.n_dialogs[new_target_dialog].d_name
				        and dialog.n_dialogs[new_target_dialog].d_name == fields["d_id_"..k])
				) then
					fields[ "d_id_"..k ] = new_target_dialog
					-- in options edit menu: show this update
					result["show_next_option"] = k
				end
			end
		end
	end

	-- add a new dialog; either via "+" button or "New dialog" in dialog dropdown menu
	-- this has to be done after all the other changes because those (text changes etc.) still
	-- apply to the *old* dialog
	if(fields.show_new_dialog
	  or(fields["d_id"] and fields["d_id"] == yl_speak_up.text_new_dialog_id)) then
		-- create the new dialog and make sure it gets shown
		local d_id = yl_speak_up.add_new_dialog(dialog, pname, nil)
		-- actually show the new dialog
		fields["d_id"] = d_id
		fields["show_new_dialog"] = nil
	end

	-- delete one empty dialog
	if(fields.delete_this_empty_dialog) then
		local anz_options = 0
		-- we need to show a new dialog after this one was deleted
		local new_dialog = d_id
		local sorted_list = yl_speak_up.get_sorted_options(dialog.n_dialogs, "d_sort")
		for i, k in ipairs(sorted_list) do
			-- count the options of this dialog
			if(k == d_id) then
				if(dialog.n_dialogs[d_id].d_options) then
					for o, w in pairs(dialog.n_dialogs[d_id].d_options) do
						anz_options = anz_options + 1
					end
				end
				if(sorted_list[i+1]) then
					new_dialog = sorted_list[i+1]
				elseif(sorted_list[i-1]) then
					new_dialog = sorted_list[i-1]
				end
			end
		end
		-- there needs to be one dialog left after deleting this one,
		-- (as there is always d_dynamic we need to leave *two* dialogs)
		if(#sorted_list > 2
		-- this dialog isn't allowed to hold any more options/answers
		  and anz_options == 0
		-- we really found a new dialog to show
		  and new_dialog ~= d_id
		-- and the text needs to be empty
		  and dialog.n_dialogs[ d_id ].d_text == "") then
			-- actually delete this dialog
			dialog.n_dialogs[ d_id ] = nil
			-- ..and store it to disk
			yl_speak_up.delete_dialog(n_id, d_id)
                        yl_speak_up.log_change(pname, n_id,
				"Deleted dialog "..tostring(d_id)..".")
			-- switch to another dialog (this one was deleted after all)
			fields["d_id"] = new_dialog
			fields["show_new_dialog"] = nil
		else
			-- deleting is only possible from the talk menu, and there the delete
			-- button is only shown if the dialog can be deleted; so this can remain
			-- a chat message
			minetest.chat_send_player(pname, "Sorry. This dialog cannot be deleted (yet). "..
				"It is either the only dialog left or has a non-empty text or has at "..
				"least on remaining option/answer.")
		end
	end

	-- not in options edit menu?
	local o_id = fields.o_id
	if(not(o_id)) then
		return result
	end

	local d_option = dialog.n_dialogs[ d_id ].d_options[ o_id ]
	-- change alternate text when preconditions are not met
	-- (only happens in options edit menu)
	if(fields.option_text_not_met and d_option
	  and d_option.o_text_when_prerequisites_not_met ~= fields.option_text_not_met) then
		-- add change to changelog
		table.insert(yl_speak_up.npc_was_changed[ n_id ],
			"Dialog "..d_id..": The alternate text for option "..tostring(o_id)..
			" was changed from \""..
			tostring(d_option.o_text_when_prerequisites_not_met).."\" to \""..
			tostring(fields.option_text_not_met).."\".")
		-- actually change the text of the option
		d_option.o_text_when_prerequisites_not_met = fields.option_text_not_met
	end

	-- toggle visit often/only *once*
	if(d_option and fields.option_visits and fields.option_visits ~= "") then
		local old_visit_mode = "often"
		if(d_option.o_visit_only_once and d_option.o_visit_only_once == 1) then
			old_visit_mode = "*once*"
		end
		if(fields.option_visits ~= old_visit_mode) then
			if(fields.option_visits == "often") then
				d_option.o_visit_only_once = 0
				table.insert(yl_speak_up.npc_was_changed[ n_id ],
					"Dialog "..d_id..": Option "..tostring(o_id)..
					" can now be visited often/unlimited (default).")
			elseif(fields.option_visits == "*once*") then
				d_option.o_visit_only_once = 1
				table.insert(yl_speak_up.npc_was_changed[ n_id ],
					"Dialog "..d_id..": Option "..tostring(o_id)..
					" can now be visited only *once* per talk.")
			end
		end
	end

	-- toggle autoselection/autoclick of an option
	if(d_option and fields.option_autoanswer and fields.option_autoanswer ~= "") then
		local old_answer_mode = "by clicking on it"
		if(dialog.n_dialogs[ d_id ].o_random) then
			old_answer_mode = "randomly"
		elseif(d_option.o_autoanswer and d_option.o_autoanswer == 1) then
			old_answer_mode = "automaticly"
		end
		if(fields.option_autoanswer ~= old_answer_mode) then
			local new_answer_mode = ""
			if(fields.option_autoanswer == "by clicking on it") then
				d_option.o_autoanswer = nil
				-- the dialog is no longer random
				dialog.n_dialogs[ d_id ].o_random = nil
				new_answer_mode = fields.option_autoanswer
			elseif(fields.option_autoanswer == "automaticly") then
				d_option.o_autoanswer = 1
				-- the dialog is no longer random
				dialog.n_dialogs[ d_id ].o_random = nil
				new_answer_mode = fields.option_autoanswer
			elseif(fields.option_autoanswer == "randomly") then
				d_option.o_autoanswer = nil
				-- the entire dialog needs to be set to randomly - not just this option
				dialog.n_dialogs[ d_id ].o_random = 1
				new_answer_mode = fields.option_autoanswer
			end
			if(new_answer_mode ~= "" and new_answer_mode ~= old_answer_mode) then
				local random_was_changed = ""
				if(new_answer_mode == "randomly" or old_answer_mode == "randomly") then
					random_was_changed = " Note that changes to/from \"randomly\" "..
						"affect the entire dialog!"
				end
				table.insert(yl_speak_up.npc_was_changed[ n_id ],
					"Dialog "..d_id..": The modus for option "..tostring(o_id)..
					" was changed from \""..old_answer_mode.."\" to \""..
					new_answer_mode.."\"."..random_was_changed)
			end
		end
	end

	-- handle hide/grey out/show alternate answer
	-- (only happens in options edit menu)
	if(fields.hide_or_grey_or_alternate_answer and d_option) then
		if(fields.hide_or_grey_or_alternate_answer == "..hide this answer."
		  and d_option.o_hide_when_prerequisites_not_met ~= "true") then
			d_option.o_hide_when_prerequisites_not_met = "true"
			d_option.o_grey_when_prerequisites_not_met = "false"
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": If precondition for option "..tostring(o_id)..
				" is not met, hide option/answer.")
			-- make sure we show this options update next
			result["show_next_option"] = o_id
		elseif(fields.hide_or_grey_or_alternate_answer == "..grey out the following answer:"
		  and d_option.o_grey_when_prerequisites_not_met ~= "true") then
			d_option.o_hide_when_prerequisites_not_met = "false"
			d_option.o_grey_when_prerequisites_not_met = "true"
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": If precondition for option "..tostring(o_id)..
				" is not met, grey out option/answer.")
			result["show_next_option"] = o_id
		elseif(fields.hide_or_grey_or_alternate_answer == "..display the following alternate answer:"
		  and (d_option.o_hide_when_prerequisites_not_met ~= "false"
		    or d_option.o_grey_when_prerequisites_not_met) ~= "false") then
			d_option.o_hide_when_prerequisites_not_met = "false"
			d_option.o_grey_when_prerequisites_not_met = "false"
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": If precondition for option "..tostring(o_id)..
				" is not met, show alternate option/answer.")
			result["show_next_option"] = o_id
		end
	end

	-- how many times can the player fail to execute the action successfully?
	if(fields[ "timer_max_attempts_on_failure"]) then
		local field_name = "timer_max_attempts_on_failure"
		local timer_name = "timer_on_failure_"..tostring(d_id).."_"..tostring(o_id)
		if(not(tonumber(fields[ field_name ]))) then
			fields[ field_name ] = 0
		end
		-- make sure the variable exists
		if(yl_speak_up.add_time_based_variable(timer_name)) then
			yl_speak_up.set_variable_metadata(timer_name, nil, "parameter", "max_attempts",
							  fields[ field_name ])
		end
	end
	-- ..and how long has the player to wait in order to try again?
	if(fields[ "timer_max_seconds_on_failure"]) then
		local field_name = "timer_max_seconds_on_failure"
		local timer_name = "timer_on_failure_"..tostring(d_id).."_"..tostring(o_id)
		if(not(tonumber(fields[ field_name ]))) then
			fields[ field_name ] = 0
		end
		-- make sure the variable exists
		if(yl_speak_up.add_time_based_variable(timer_name)) then
			yl_speak_up.set_variable_metadata(timer_name, nil, "parameter", "duration",
							  fields[ field_name ])
		end
	end
	if(fields[ "timer_max_seconds_on_success"]) then
		local field_name = "timer_max_seconds_on_success"
		local timer_name = "timer_on_success_"..tostring(d_id).."_"..tostring(o_id)
		if(not(tonumber(fields[ field_name ]))) then
			fields[ field_name ] = 0
		end
		-- make sure the variable exists
		if(yl_speak_up.add_time_based_variable(timer_name)) then
			yl_speak_up.set_variable_metadata(timer_name, nil, "parameter", "duration",
							  fields[ field_name ])
		end
	end
	-- currently only contains result["show_new_option"] (which is needed for options edit menu)
	return result
end
-- end of yl_speak_up.edit_mode_apply_changes
