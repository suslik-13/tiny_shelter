-- helper function for yl_speak_up.handle_input_fs_edit_option_related
-- (handle editing of alternate texts that are shown instead of the normal dialog)
yl_speak_up.handle_edit_actions_alternate_text = function(
			player, pname, n_id, d_id, o_id, x_id, id_prefix,
			formspec_input_to, data, fields, tmp_data_cache)
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(dialog)
	  or not(dialog.n_dialogs)
	  or not(dialog.n_dialogs[ d_id ])
	  or not(dialog.n_dialogs[ d_id ].d_options)
	  or not(dialog.n_dialogs[ d_id ].d_options[ o_id ])) then
		return
	end
	-- edit_dialog_options: these first two buttons can only be pressed in this dialog
	-- action failed: want to edit the text that is shown when switching to the next dialog?
	if(fields.button_edit_action_failed_dialog) then
		-- the target effect is the (failed) action
		local target_action = {}
		local actions = dialog.n_dialogs[ d_id ].d_options[ o_id ].actions
		if(actions) then
			for a_id, a in pairs(actions) do
				if(a and a.a_id) then
					target_action = a
				end
			end
		end
		if(not(target_action)) then
			return
		end
		-- remember what we're working at
		yl_speak_up.speak_to[pname].edit_alternate_text_for = target_action
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = yl_speak_up.extend_fs_edit_dialog_modification(
				dialog, target_action.a_on_failure, target_action.alternate_text,
				"if the action \""..tostring(target_action.a_id)..
				"\" of option \""..tostring(o_id)..
				"\" of dialog \""..tostring(d_id)..
				"\" failed because the player did something wrong")
			})
		-- showing new formspec - the calling function shall return as well
		return true

	-- action was successful: want to edit the text that is shown when switching to the next dialog?
	elseif(fields.button_edit_action_success_dialog) then
		-- the target effect is the "dialog" effect
		local target_effect = {}
		local results = dialog.n_dialogs[ d_id ].d_options[ o_id ].o_results
		if(results) then
			for r_id, r in pairs(results) do
				if(r and r.r_type and r.r_type == "dialog") then
					target_effect = r
				end
			end
		end
		if(not(target_effect)) then
			return
		end
		-- remember what we're working at
		yl_speak_up.speak_to[pname].edit_alternate_text_for = target_effect
		-- this only happens in edit_options_dialog; log it directly
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = yl_speak_up.extend_fs_edit_dialog_modification(
					dialog, target_effect.r_value, target_effect.alternate_text,
					"if the action "..
					"of option \""..tostring(o_id)..
					"\" of dialog \""..tostring(d_id)..
					"\" was successful - or if there was no action")
			})
		-- showing new formspec - the calling function shall return as well
		return true

	-- in edit action dialog: edit alternate text for a failed action
	elseif(fields.button_edit_action_on_failure_text_change) then
		local sorted_dialog_list = yl_speak_up.sort_keys(dialog.n_dialogs)
		local failure_id = ""
		-- action is beeing edited; data.action_failure_dialog points to an index
		if(data and data.action_failure_dialog) then
			failure_id = sorted_dialog_list[ data.action_failure_dialog ]
		end
		-- remember what we edit
		data.x_id = x_id
		data.id_prefix = id_prefix
		yl_speak_up.speak_to[pname].edit_alternate_text_for = data
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = yl_speak_up.extend_fs_edit_dialog_modification(
				dialog, failure_id, data.alternate_text,
				"if the action \""..tostring(x_id)..
				"\" of option \""..tostring(o_id)..
				"\" of dialog \""..tostring(d_id)..
				"\" failed because the player did something wrong")
			})
		-- showing new formspec - the calling function shall return as well
		return true

	-- edit alternate text for an on_failure effect
	elseif(fields.button_edit_effect_on_failure_text_change) then
		-- remember what we edit
		data.x_id = x_id
		data.id_prefix = id_prefix
		yl_speak_up.speak_to[pname].edit_alternate_text_for = data
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = yl_speak_up.extend_fs_edit_dialog_modification(
				dialog, data.on_failure, data.alternate_text,
				"if the effect \""..tostring(x_id)..
				"\" of option \""..tostring(o_id)..
				"\" of dialog \""..tostring(d_id)..
				"\" failed to execute correctly")
		})
		-- showing new formspec - the calling function shall return as well
		return true

	-- edit alternate text for when the player has failed to do the action too many times
	elseif(fields.button_edit_limit_action_failed_repeat) then
		local timer_name = "timer_on_failure_"..tostring(d_id).."_"..tostring(o_id)
		local timer_data = yl_speak_up.get_variable_metadata( timer_name, "parameter", true)
		local alternate_text = yl_speak_up.standard_text_if_action_failed_too_often
		if(timer_data and timer_data["alternate_text"]) then
			alternate_text = timer_data["alternate_text"]
		end
		-- remember what we're working at
		yl_speak_up.speak_to[pname].edit_alternate_text_for = "timer_on_failure"
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = yl_speak_up.extend_fs_edit_dialog_modification(
				dialog, d_id, alternate_text,
				"if the player failed to complete the action "..
				"\" of option \""..tostring(o_id)..
				"\" of dialog \""..tostring(d_id)..
				"\" too many times",
				true) -- forbid_turn_into_new_dialog
			})
		-- showing new formspec - the calling function shall return as well
		return true
	-- edit alternate text whent he player has to wait a bit until he's allowed to repeat the
	-- action (to avoid i.e. unlimited quest item handout)
	elseif(fields.button_edit_limit_action_success_repeat) then
		local timer_name = "timer_on_success_"..tostring(d_id).."_"..tostring(o_id)
		local timer_data = yl_speak_up.get_variable_metadata( timer_name, "parameter", true)
		local alternate_text = yl_speak_up.standard_text_if_action_repeated_too_soon
		if(timer_data and timer_data["alternate_text"]) then
			alternate_text = timer_data["alternate_text"]
		end
		-- remember what we're working at
		yl_speak_up.speak_to[pname].edit_alternate_text_for = "timer_on_success"
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = yl_speak_up.extend_fs_edit_dialog_modification(
				dialog, d_id, alternate_text,
				"if the player has complete the action "..
				"\" of option \""..tostring(o_id)..
				"\" of dialog \""..tostring(d_id)..
				"\" just not long enough ago",
				true) -- forbid_turn_into_new_dialog
			})
		-- showing new formspec - the calling function shall return as well
		return true

	-- save the changes
	elseif(fields.save_dialog_modification) then
		local old_text = "-none-"
		local target_element = yl_speak_up.speak_to[pname].edit_alternate_text_for
		if(target_element
		  and (target_element == "timer_on_failure" or target_element == "timer_on_success")) then
			-- we're changing a timer (both can be handled the same way here)
			local timer_name = target_element.."_"..tostring(d_id).."_"..tostring(o_id)
			local timer_data = yl_speak_up.get_variable_metadata( timer_name, "parameter", true)
			local alternate_text = yl_speak_up.standard_text_if_action_failed_too_often
			if(target_element == "timer_on_success") then
				alternate_text = yl_speak_up.standard_text_if_action_repeated_too_soon
			end
			if(timer_data and timer_data["alternate_text"]) then
				alternate_text = timer_data["alternate_text"]
			end
			-- store the modified alternate text
			if(fields.d_text_new and fields.d_text_new ~= ""
			  and fields.d_text_new ~= alternate_text) then
				-- make sure the variable exists
				if(yl_speak_up.add_time_based_variable(timer_name)) then
					yl_speak_up.set_variable_metadata(timer_name, nil, "parameter",
						"alternate_text", fields.d_text_new)
					-- log the change
					yl_speak_up.log_change(pname, n_id,
						"Dialog "..d_id..", option "..tostring(o_id)..
						": The text displayed for "..tostring(target_element)..
						" was changed from "..
						"["..tostring(alternate_text).."] to ["..
						tostring(fields.d_text_new).."].")
				end
			end
		elseif(target_element) then
			data = target_element
			id_prefix = "a_"
			if(target_element.r_id) then
				id_prefix = "r_"
			end
			old_text = target_element.alternate_text
		else
			old_text = data.alternate_text
		end
		if(data and fields.d_text_new and fields.d_text_new ~= "$TEXT$"
		  and fields.d_text_new ~= data.alternate_text) then
			-- store modification
			-- not necessary for edit_option_dialog
			if(tmp_data_cache) then
				data.alternate_text = fields.d_text_new
				yl_speak_up.speak_to[pname][ tmp_data_cache ] = data
			else
				target_element.alternate_text = fields.d_text_new
			end
			if(id_prefix == "r_") then
				local failure_id = data.on_failure
				-- effect is beeing edited; data.on_failure contains the dialog name
				if(data and data.on_failure) then
					failure_id = data.on_failure
				-- edit_option_dialog: data.r_value contains the dialog name
				elseif(target_element and target_element.r_value) then
					failure_id = target_element.r_value
				end
				-- record the change
				table.insert(yl_speak_up.npc_was_changed[ n_id ],
					"Dialog "..d_id..": The text displayed for dialog "..
					tostring(failure_id).." when selecting option "..
					tostring(o_id).." in dialog "..tostring( d_id )..
					" and effect "..tostring(x_id).." failed "..
					" was changed from "..
					"["..tostring(old_text).."] to ["..tostring(fields.d_text_new).."].")
			elseif(id_prefix == "a_") then
				local sorted_dialog_list = yl_speak_up.sort_keys(dialog.n_dialogs)
				local failure_id = ""
				-- action is beeing edited; data.action_failure_dialog points to an index
				if(data and data.action_failure_dialog) then
					failure_id = sorted_dialog_list[ data.action_failure_dialog ]
				-- edit_option_dialog: data.a_on_failure contains the dialog name
				elseif(target_element and target_element.a_on_failure) then
					failure_id = target_element.a_on_failure
				end
				-- record the change
				table.insert(yl_speak_up.npc_was_changed[ n_id ],
					"Dialog "..d_id..": The text displayed for dialog "..
					tostring(failure_id).." when the action "..
					tostring(x_id).." of option "..
					tostring( o_id ).." in dialog "..tostring( d_id )..
					" failed, was changed from "..
					"["..tostring(old_text).."] to ["..tostring(fields.d_text_new).."].")
			end
			-- saved; finished editing
			yl_speak_up.speak_to[pname].edit_alternate_text_for = nil
		end
	-- turn this alternate answer into a new dialog
	elseif(fields.turn_alternate_text_into_new_dialog) then
		local target_element = yl_speak_up.speak_to[pname].edit_alternate_text_for
		if(target_element) then
			data = target_element
			if(data.id_prefix and data.x_id) then
				id_prefix = data.id_prefix
				x_id = data.x_id
			else
				id_prefix = "a_"
				x_id = target_element.a_id
				if(target_element.r_id) then
					id_prefix = "r_"
					x_id = target_element.r_id
				end
			end
		end
		-- create the new dialog
		local new_dialog_id = yl_speak_up.add_new_dialog(dialog, pname, nil)
		-- set the text (the previous alternate text)
		dialog.n_dialogs[ new_dialog_id ].d_text = data.alternate_text
		-- edit option: effect dialog - this is the normal progression from this dialog to the next
		if(    data.r_id and data.r_type and data.r_type == "dialog") then
			data.r_value = new_dialog_id
			data.alternate_text = nil
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": The alternate text for effect "..tostring(x_id)..
				" (dialog) of option "..tostring(o_id).." was turned into the new dialog "..
				tostring(new_dialog_id).." (edit option).")

		-- edit option: the action failed
		elseif(data.a_id and data.a_on_failure) then
			data.a_on_failure = new_dialog_id
			data.alternate_text = nil
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": The alternate text for action "..tostring(data.a_id)..
				" of option "..tostring(o_id).." was turned into the new dialog "..
				tostring(new_dialog_id).." (edit option).")

		-- edit action: the action failed
		elseif(data.what and data.what == 6 and data.action_failure_dialog) then
			local sorted_dialog_list = yl_speak_up.sort_keys(dialog.n_dialogs)
			data.action_failure_dialog = math.max(1,
					table.indexof(sorted_dialog_list, new_dialog_id))
			data.a_on_failure = new_dialog_id
			data.alternate_text = nil
			-- make sure its stored correctly
			dialog.n_dialogs[d_id].d_options[o_id].actions[x_id].a_on_failure = new_dialog_id
			dialog.n_dialogs[d_id].d_options[o_id].actions[x_id].alternate_text = nil
			yl_speak_up.speak_to[pname][ tmp_data_cache ] = data
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": The alternate text for action "..tostring(x_id)..
				" of option "..tostring(o_id).." was turned into the new dialog "..
				tostring(new_dialog_id).." (edit action).")

		-- edit effect: on_failure - the previous effect failed
		elseif(data.what and data.what == 5 and data.on_failure) then
			data.on_failure = new_dialog_id
			data.alternate_text = nil
			-- make sure its stored correctly
			dialog.n_dialogs[d_id].d_options[o_id].o_results[x_id].on_failure = new_dialog_id
			dialog.n_dialogs[d_id].d_options[o_id].o_results[x_id].alternate_text = nil
			yl_speak_up.speak_to[pname][ tmp_data_cache ] = data
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": The alternate text for effect "..tostring(x_id)..
				" of option "..tostring(o_id).." was turned into the new dialog "..
				tostring(new_dialog_id).." (edit effect).")
		end
	end
end


yl_speak_up.show_colored_dialog_text = function(dialog, data, d_id, hypertext_pos,
		alternate_label_text, postfix, button_name)
	if(not(data)) then
		return ""
	end
	-- if(math.random(1,2)==1) then data.alternate_text = "This is an alternate text.\n$TEXT$" end
	-- slightly red in order to indicate that this is an on_failure dialog
	local color = "776666"
	-- ..except for normal redirecting to the next dialog with the dialog effect
	-- (slightly yellow there)
	if(data.r_id and data.r_type and data.r_type == "dialog") then
		color = "777766"
	end
	local add_info_alternate_text = ""
	local text = ""
	if(dialog and dialog.n_dialogs and dialog.n_dialogs[ d_id ]) then
		text = dialog.n_dialogs[ d_id ].d_text
	end
	if(d_id == "d_got_item") then
		color = "777777"
		text = "[This dialog shall only have automatic options. The text is therefore irrelevant.]"
	end
	if(d_id == "d_end") then
		color = "777777"
		text = "[The NPC will end this conversation.]"
	end
	if(not(text)) then
		text = "[ERROR: No text!]"
	end
	if(data and data.alternate_text and data.alternate_text ~= "") then
		add_info_alternate_text = alternate_label_text
		-- replace $TEXT$ with the normal dialog text and make the new text yellow
		text = "<style color=#FFFF00>"..
				string.gsub(
					data.alternate_text,
					"%$TEXT%$",
					"<style color=#FFFFFF>"..text.."</style>")..
			"</style>"
		-- slightly blue in order to indicate that this is a modified text
		color = "333366"
	end
	-- fallback
	if(not(text)) then
		text = "ERROR: No dialog text found for dialog \""..tostring(d_id).."\"!"
	end
	-- display the variables in orange
	text = yl_speak_up.replace_vars_in_text(text,
		-- fake dialog; just adds the colors
		-- also MY_NAME..but we can easily replace just one
		{ n_npc     = "<style color=#FF8800>$NPC_NAME$</style>",
		  npc_owner = "<style color=#FF8800>$OWNER_NAME$</style>"},
		-- pname
		"<style color=#FF8800>$PLAYER_NAME$</style>")

	local edit_button = ""
	-- if there is the possibility that an alternate text may be displayed: allow to edit it
	-- and calculate the position of the button from the hypertext_pos position and size
	if(button_name and button_name ~= "") then
		local parts = string.split(hypertext_pos, ";")
		local start = string.split(parts[1], ",")
		local size  = string.split(parts[2], ",")
		edit_button = "button_exit["..
			tostring(tonumber(start[1]) + tonumber(size[1]) - 3.5)..","..
			tostring(tonumber(start[2]) + tonumber(size[2]) - 0.9)..";"..
			"3.0,0.7;"..button_name..";Edit this text]"
	end
	return add_info_alternate_text..
		postfix..
		"hypertext["..hypertext_pos..";<global background=#"..color.."><normal>"..
			minetest.formspec_escape(text or "?")..
			"\n</normal>]"..
		-- display the edit button *inside*/on top of the hypertext field
		edit_button
end

-- this allows to edit modifications of a dialog that are applied when a given option
-- is choosen - i.e. when the NPC wants to answer some questions - but those answers
-- do not warrant their own dialog
yl_speak_up.extend_fs_edit_dialog_modification = function(dialog, d_id, alternate_dialog_text, explanation,
		forbid_turn_into_new_dialog)

	local nd = "button[9.0,12.3;6,0.7;turn_alternate_text_into_new_dialog;Turn this into a new dialog]"
	if(forbid_turn_into_new_dialog) then
		nd = ""
	end
	return table.concat({"size[20,13.5]",
		"label[6.0,0.5;Edit alternate text]",
		"label[0.2,1.0;The alternate text which you can edit here will be shown instead of "..
			"the normal text of the dialog \"", tostring(d_id), "\" - but *only*\n",
			tostring(explanation or "- missing explanation -"), ".]",
		"label[0.2,2.3;This is the normal text of dialog \"",
			minetest.formspec_escape(tostring(d_id)), "\", shown for reference:]",
		yl_speak_up.show_colored_dialog_text(
			dialog,
			{r_id = "", r_type = "dialog"},
			d_id,
			"1.2,2.6;18.0,4.0;d_text_orig",
			"", -- no modifications possible at this step
			"",
			""), -- no edit button here as this text cannot be changed here
		"label[0.2,7.3;Enter the alternate text here. $TEXT$ will be replaced with the normal "..
			"dialog text above:]",
		"textarea[1.2,7.6;18.0,4.5;d_text_new;;",
			minetest.formspec_escape(alternate_dialog_text or "$TEXT$"), "]",
		"button[3.0,12.3;1,0.7;back_from_edit_dialog_modification;Abort]",
		"button[6.0,12.3;1,0.7;save_dialog_modification;Save]",
		nd
		}, "")
end

