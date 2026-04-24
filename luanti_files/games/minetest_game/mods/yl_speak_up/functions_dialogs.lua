--
-- These functions here access and manipulate the "dialogs" data structure.
-- It is loaded for each player whenever the player talks to an NPC. Each
-- talking player gets *a copy* of that data structure.
--
-- As this mod is about this "dialogs" data structure and its editing, this
-- isn't the only place in this mod where the data structure is accessed
-- and/or manipulated. This here just contains some common functions.
--
--###
-- Helpers
--###

yl_speak_up.string_starts_with = function(str, starts_with)
	return (string.sub(str, 1, string.len(starts_with)) == starts_with)
end

yl_speak_up.get_number_from_id = function(any_id)
    if(not(any_id) or any_id == "d_got_item" or any_id == "d_end" or any_id == "d_dynamic") then
        return "0"
    end
    return string.split(any_id, "_")[2]
end


yl_speak_up.find_next_id = function(t)
    local start_id = 1

    if t == nil then
        return start_id
    end

    local keynum = 1
    for k, _ in pairs(t) do
        local keynum = tonumber(yl_speak_up.get_number_from_id(k))
        if keynum and keynum >= start_id then
            start_id = keynum + 1
        end
    end
    return start_id
end

yl_speak_up.sanitize_sort = function(options, value)
    local retval = value

    if value == "" or value == nil or tonumber(value) == nil then
        local temp = 0
        for k, v in pairs(options) do
            if v.o_sort ~= nil then
                if tonumber(v.o_sort) > temp then
                    temp = tonumber(v.o_sort)
                end
            end
        end
        retval = tostring(temp + 1)
    end
    return retval
end


-- helper function for
-- 	yl_speak_up.get_fs_talkdialog and
-- 	yl_speak_up.check_and_add_as_generic_dialog
-- find the dialog with d_sort == 0 or lowest number
yl_speak_up.get_start_dialog_id = function(dialog)
	if(not(dialog) or not(dialog.n_dialogs)) then
		return nil
	end
	-- Find the dialog with d_sort = 0 or alternatively with the lowest number
	local lowest_sort = nil
	local d_id = nil
	for k, v in pairs(dialog.n_dialogs) do
		local nr = tonumber(v.d_sort)
		if(not(lowest_sort) or (nr and nr >= 0 and nr < lowest_sort)) then
			lowest_sort = nr
			d_id = k
		end
	end
	return d_id
end


-- helper function that is also used by export_to_ink.lua
-- returns a sorted dialog list without special or generic dialogs
yl_speak_up.get_dialog_list_for_export = function(dialog)
	local liste = {}
	if(not(dialog) or not(dialog.n_dialogs)) then
		return liste
	end
	-- sort the list of dialogs by d_id
	local liste_sorted = yl_speak_up.sort_keys(dialog.n_dialogs or {}, true)
	for _, d_id in ipairs(liste_sorted) do
		-- only normal dialogs - no d_trade, d_got_item, d_dynamic etc;
		if(not(yl_speak_up.is_special_dialog(d_id))
		-- also no generic dialogs (they do not come from this NPC)
		   and not(dialog.n_dialogs[d_id].is_generic)) then
			table.insert(liste, d_id)
		end
	end
	-- now that the list contains only normal dialogs, we can sort by d_sort
	-- (thus allowing d_9 to be listed earlier than d_10 etc.)
	table.sort(liste, function(a, b)
		return  dialog and dialog.n_dialogs and dialog.n_dialogs[a] and dialog.n_dialogs[b]
			and ((tonumber(dialog.n_dialogs[a].d_sort or "") or 0)
			   < (tonumber(dialog.n_dialogs[b].d_sort or "") or 0)) end)
	return liste
end


--###
--Formspecs
--###


-- helper function
-- the option to override next_id and provide a value is needed when a new dialog was
-- added, then edited, and then discarded; it's still needed after that, but has to
-- be reset to empty state (wasn't stored before)
-- Note: pname is only passed to yl_speak_up.add_new_option - which is only used if
--       dialog_text is empty (and only for logging)
yl_speak_up.add_new_dialog = function(dialog, pname, next_id, dialog_text)
	if(not(next_id)) then
		next_id = yl_speak_up.find_next_id(dialog.n_dialogs)
	end
	local future_d_id = "d_" .. next_id
	-- Initialize empty dialog
	dialog.n_dialogs[future_d_id] = {
		d_id = future_d_id,
		d_type = "text",
		d_text = (dialog_text or ""),
		d_sort = next_id
		}
	-- store that there have been changes to this npc
	-- (better ask only when the new dialog is changed)
--	table.insert(yl_speak_up.npc_was_changed[ yl_speak_up.edit_mode[pname] ],
--		"Dialog "..future_d_id..": New dialog added.")

	-- add an option for going back to the start of the dialog;
	-- this is an option which the player can delete and change according to needs,
	-- not a fixed button which may not always fit
	if(not(dialog_text)) then
		-- we want to go back to the start from here
		local target_dialog = yl_speak_up.get_start_dialog_id(dialog)
		-- this text will be used for the button
		local option_text = "Let's go back to the start of our talk."
		-- we just created this dialog - this will be the first option
		yl_speak_up.add_new_option(dialog, pname, "1", future_d_id, option_text, target_dialog)
	end
	return future_d_id
end


-- update existing or create a new dialog named d_name with d_text
-- (useful for import from ink and likewise functionality)
-- this also prepares the dialog for options update
yl_speak_up.update_dialog = function(log, dialog, dialog_name, dialog_text)
	if(dialog_name and yl_speak_up.is_special_dialog(dialog_name)) then
		-- d_trade, d_got_item, d_dynamic and d_end are not imported because they need to be handled diffrently
		table.insert(log, "Note: Not importing dialog text for \""..tostring(dialog_name).."\" because it is a special dialog.")
		-- the options of thes special dialogs are still relevant
		return dialog_name
	end
	-- does a dialog with name d_name already exist?
	local d_id = yl_speak_up.d_name_to_d_id(dialog, dialog_name)
	-- name the thing for logging purposes
	local log_str = "Dialog "..tostring(d_id)
	if(dialog_name and dialog_name ~= d_id) then
		log_str = log_str.." ["..tostring(dialog_name).."]:"
	else
		log_str = log_str..": "
	end
	local is_new = false
	if(not(d_id)) then
		local next_id = nil
		-- if dialog_name matches the d_<nr> pattern but d_<nr> does not exist,
		-- then try to create *that* dialog
		if(dialog_name and string.sub(dialog_name, 1, 2) == "d_") then
			next_id = tonumber(string.sub(dialog_name, 3))
		end
		-- pname is nil - thus no logging and no adding of a back to start option
		-- next_id is also usually nil - so just add a new dialog
		d_id = yl_speak_up.add_new_dialog(dialog, nil, next_id, dialog_text)
		if(not(d_id)) then
			-- the creation may have failed (i.e. dialog not beeing a dialog,
			-- or too many dialogs in dialog already)
			table.insert(log, log_str.."FAILED to create new dialog.")
			return nil
		end
		-- we got a new name for the log
		log_str = "New dialog "..tostring(d_id).." ["..tostring(dialog_name).."]: "
		is_new = true
		table.insert(log, log_str.." Created successfully.")

	elseif(dialog.n_dialogs[d_id].d_text ~= dialog_text) then
		-- else update the text
		table.insert(log, log_str.." Changed dialog text from \""..
			tostring(dialog.n_dialogs[d_id].d_text).."\" to \""..tostring(dialog_text).."\".")
		-- actually change the dialog text
		dialog.n_dialogs[d_id].d_text = dialog_text
	end

	local d_data = dialog.n_dialogs[d_id]
	-- set d_name if it differs from d_id
	if(d_id ~= dialog_name
	  and (not(d_data.d_name)
	        or(d_data.d_name ~= dialog_name))) then
		if(not(is_new)) then
			-- log only if it's not a new dialog
			table.insert(log, log_str.."Changed dialog name from \""..
				tostring(d_data.d_name).."\" to \""..tostring(dialog_name).."\".")
		end
		-- actually change the dialog name
		d_data.d_name = dialog_name
	end

	-- the random option is set for the dialog entire; we will have to process the individual
	-- options in order to find out if this dialog is o_random; the first option that is sets
	-- it for the dialog -> keep the old value
	--d_data.o_random = nil

	-- there may be existing options that won't get updated; deal with them:
	-- remember which options the dialog has and which sort order they had
	d_data.d_tmp_sorted_option_list = yl_speak_up.get_sorted_options(d_data.d_options or {}, "o_sort") or {}
	-- this value is increased whenever an option gets updated - so that we can have options
	-- that don't get an update sorted in after those options that did
	d_data.d_tmp_sort_value = 1
	-- mark all existing options as requirilng an update
	for i, o_id in ipairs(d_data.d_tmp_sorted_option_list or {}) do
		d_data.d_options[o_id].o_tmp_needs_update = true
	end
	-- mark this dialog as having received an update (meaning we won't have to update d_sort after
	-- all dialogs have been updated)
	d_data.d_tmp_has_been_updated = true
	return d_id
end


-- helper function for update_dialog_options_completed;
-- adds a precondition of p_type "false" to the option so that the option is no longer displayed
-- if disable_option is false, then all preconditions of p_type "false" will be changed to p_type "true"
-- and thus the option will be shown to the player again
yl_speak_up.update_disable_dialog_option = function(o_data, disable_option)
	-- is this otpion already deactivated?
	local is_deactivated = false
	for p_id, p in pairs(o_data.o_prerequisites or {}) do
		if(p and p_id and p.p_type == "false") then
			is_deactivated = true
			-- if we want to re-enable the option, then this here is the place
			if(not(disable_option)) then
				-- change the type from false to true - this particular precondition
				-- will now always be true
				p.p_type = "true"
				-- we continue work here because the player may have created multiple
				-- options of this type
			end
		end
	end
	-- if not: add a precondition of type "false"
	if(not(is_deactivated) and disable_option) then
		-- we need to add a new precondition of type "false"
		-- make sure we can add the prereq:
		if(not(o_data.o_prerequisites)) then
			o_data.o_prerequisites = {}
		end
		local future_p_id = "p_"..tostring(yl_speak_up.find_next_id(o_data.o_prerequisites))
		-- we just added this option; this is the first and for now only precondition for it;
		-- the player still has to adjust it, but at least it is a reasonable default
		o_data.o_prerequisites[future_p_id] = { p_id = future_p_id, p_type = "false"}
	end
end


-- call this *after* all dialog options have been updated for dialog_name
yl_speak_up.update_dialog_options_completed = function(log, dialog, d_id)
	local d_data = dialog.n_dialogs[d_id]
	if(not(d_data)) then
		return
	end
	for i, o_id in ipairs(d_data.d_tmp_sorted_option_list or {}) do
		local o_data = d_data.d_options[o_id]
		if(o_data.o_tmp_needs_update) then
			-- update the sort value so that this option will be listed *after* those
			-- options that actually did get updated
			o_data.o_sort = d_data.d_tmp_sort_value
			d_data.d_tmp_sort_value = d_data.d_tmp_sort_value + 1
			-- this option has now been processed
			o_data.o_tmp_needs_update = nil

			-- name the thing for logging purposes
			local log_str = "Dialog "..tostring(d_id)
			if(dialog_name and dialog_name ~= d_id) then
				log_str = log_str.." ["..tostring(d_id).."]"
			end
			table.insert(log, log_str..", option <"..tostring(o_id)..">: "..
				"Option exists in old dialog but not in import. Keeping option.")
			-- add a precondition of p_type "false" to the option so that the option
			-- is no longer displayed
			yl_speak_up.update_disable_dialog_option(o_data, true)
		end
	end
	-- clean up the dialog
	d_data.d_tmp_sorted_option_list = nil
	d_data.d_tmp_sort_value = nil
end


-- make sure only one dialog has d_sort set to 0 (and is thus the start dialog)
yl_speak_up.update_start_dialog = function(log, dialog, start_dialog_name, start_with_d_sort)
	local start_d_id = yl_speak_up.d_name_to_d_id(dialog, start_dialog_name)
	if(not(start_d_id)) then
		return
	end
	for d_id, d in pairs(dialog.n_dialogs) do
		if(d_id == start_d_id) then
			if(not(d.d_sort) or d.d_sort ~= 0) then
				table.insert(log, "Setting start dialog to "..tostring(start_dialog_name)..".")
			end
			d.d_sort = 0
			-- the start dialog certainly is *a* start dialog (with the buttons)
			d.is_a_start_dialog = true
		elseif(not(d.d_tmp_has_been_updated)) then
			-- sort this dialog behind the others
			d.d_sort = start_with_d_sort
			start_with_d_sort = start_with_d_sort + 1
		end
		d.d_tmp_has_been_updated = nil
        end
end


-- add a new option/answer to dialog d_id with option_text (or default "")
-- 	option_text	(optional) the text that shall be shown as option/answer
-- 	target_dialog	(optional) the target dialog where the player will end up when choosing
-- 			this option/answer
-- Note: pname is only used for logging (and for changing o_sort)
yl_speak_up.add_new_option = function(dialog, pname, next_id, d_id, option_text, target_dialog)
	if(not(dialog) or not(dialog.n_dialogs) or not(dialog.n_dialogs[d_id])) then
		return nil
	end
	if dialog.n_dialogs[d_id].d_options == nil then
		-- make sure d_options exists
		dialog.n_dialogs[d_id].d_options = {}
	else
		-- we don't want an infinite amount of answers per dialog
		local sorted_list = yl_speak_up.get_sorted_options(dialog.n_dialogs[d_id].d_options, "o_sort")
		local anz_options = #sorted_list
		if(anz_options >= yl_speak_up.max_number_of_options_per_dialog) then
			-- nothing added
			return nil
		end
	end
	if(not(next_id)) then
		next_id = yl_speak_up.find_next_id(dialog.n_dialogs[d_id].d_options)
	end
	local future_o_id = "o_" .. next_id
	dialog.n_dialogs[d_id].d_options[future_o_id] = {
		o_id = future_o_id,
		o_hide_when_prerequisites_not_met = "false",
		o_grey_when_prerequisites_not_met = "false",
		o_sort = -1,
		o_text_when_prerequisites_not_met = "",
		o_text_when_prerequisites_met = (option_text or ""),
		}

	local start_with_o_sort = nil
	if(pname and pname ~= "") then
		-- log only in edit mode
		local n_id = yl_speak_up.speak_to[pname].n_id
		-- would be too difficult to add an exception for edit_mode here; thus, we do it directly here:
		if(yl_speak_up.npc_was_changed
		  and yl_speak_up.npc_was_changed[n_id]) then
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": Added new option/answer "..future_o_id..".")
		end

		start_with_o_sort = yl_speak_up.speak_to[pname].o_sort
	end

	-- necessary in order for it to work
	local new_o_sort = yl_speak_up.sanitize_sort(dialog.n_dialogs[d_id].d_options, start_with_o_sort)
	dialog.n_dialogs[d_id].d_options[future_o_id].o_sort = new_o_sort

	-- letting d_got_item point back to itself is not a good idea because the
	-- NPC will then end up in a loop; plus the d_got_item dialog is intended for
	-- automatic processing, not for showing to the player
	if(d_id == "d_got_item") then
		-- unless the player specifies something better, we go back to the start dialog
		-- (that is where d_got_item got called from anyway)
		target_dialog = yl_speak_up.get_start_dialog_id(dialog)
		-- ...and this option needs to be selected automaticly
		dialog.n_dialogs[d_id].d_options[future_o_id].o_autoanswer = 1
	elseif(d_id == "d_trade") then
		-- we really don't want to go to another dialog from here
		target_dialog = "d_trade"
		-- ...and this option needs to be selected automaticly
		dialog.n_dialogs[d_id].d_options[future_o_id].o_autoanswer = 1
	end
	local future_r_id = nil
	-- create a fitting dialog result automaticly if possible:
	-- give this new dialog a dialog result that leads back to this dialog
	-- (which is more helpful than creating tons of empty dialogs)
	if(target_dialog and (dialog.n_dialogs[target_dialog] or target_dialog == "d_end")) then
		future_r_id = yl_speak_up.add_new_result(dialog, d_id, future_o_id)
		-- actually store the new result
		dialog.n_dialogs[d_id].d_options[future_o_id].o_results = {}
		dialog.n_dialogs[d_id].d_options[future_o_id].o_results[future_r_id] = {
			r_id = future_r_id,
			r_type = "dialog",
			r_value = target_dialog}
	end

	-- the d_got_item dialog is special; players can easily forget to add the
	-- necessary preconditions and effects, so we do that manually here
	if(d_id == "d_got_item") then
		-- we also need a precondition so that the o_autoanswer can actually get called
		dialog.n_dialogs[d_id].d_options[future_o_id].o_prerequisites = {}
		-- we just added this option; this is the first and for now only precondition for it;
		-- the player still has to adjust it, but at least it is a reasonable default
		dialog.n_dialogs[d_id].d_options[future_o_id].o_prerequisites["p_1"] = {
			p_id = "p_1",
			p_type = "player_offered_item",
			p_item_stack_size = tostring(next_id),
			p_match_stack_size = "exactly",
			-- this is just a simple example item and ought to be changed after adding
			p_value = "default:stick "..tostring(next_id)}
		-- we need to show the player that his action was successful
		dialog.n_dialogs[d_id].d_options[future_o_id].o_results[future_r_id].alternate_text =
			"Thank you for the "..tostring(next_id).." stick(s)! "..
			"Never can't have enough sticks.\n$TEXT$"
		-- we need an effect for accepting the item;
		-- taking all that was offered and putting it into the NPC's inventory is a good default
		future_r_id = yl_speak_up.add_new_result(dialog, d_id, future_o_id)
		dialog.n_dialogs[d_id].d_options[future_o_id].o_results[future_r_id] = {
			r_id = future_r_id,
			r_type = "deal_with_offered_item",
			r_value	= "take_all"}

	-- the trade dialog is equally special
	elseif(d_id == "d_trade") then
		dialog.n_dialogs[d_id].d_options[future_o_id].o_prerequisites = {}
		-- this is just an example
		dialog.n_dialogs[d_id].d_options[future_o_id].o_prerequisites["p_1"] = {
			p_id = "p_1",
			p_type = "npc_inv",
			p_value	= "inv_does_not_contain",
			p_inv_list_name	= "npc_main",
			p_itemstack = "default:stick "..tostring(100-next_id)}
		future_r_id = yl_speak_up.add_new_result(dialog, d_id, future_o_id)
		-- example craft
		dialog.n_dialogs[d_id].d_options[future_o_id].o_results[future_r_id] = {
			r_id = future_r_id,
			r_type = "craft",
			r_value = "default:stick 4",
			o_sort = "1",
			r_craft_grid = {"default:wood", "", "", "", "", "", "", "", ""}}
	end
	return future_o_id
end


-- update existing or create a new option named option_name for dialog dialog_name
-- If option_name starts with..
-- 	new_          create a new option (discard the rest of option_name)
-- 	automaticly_  set o_autoanswer
-- 	randomly_     set o_random *for the dialog*
-- 	grey_out_     set o_text_when_prerequisites_not_met
-- ..and take what remains as option_name.
-- (useful for import from ink and likewise functionality)
--
-- TODO: these notes need to be taken care of in the calling function
-- Note: The calling function may need to adjust o_sort according to its needs.
-- Note: Preconditions, actions and effects are not handled here (apart from the "dialog"
--       effect/result for the redirection to the target dialog)
yl_speak_up.update_dialog_option = function(log, dialog, dialog_name, option_name,
						option_text, option_text_if_preconditions_false,
						target_dialog, alternate_text, visit_only_once, sort_order)
	-- does the dialog we want to add to exist?
	local d_id = yl_speak_up.d_name_to_d_id(dialog, dialog_name)
	if(not(d_id)) then
		if(not(yl_speak_up.is_special_dialog(dialog_name))) then
			-- the dialog does not exist - we cannot add an option to a nonexistant dialog
			return nil
		end
		-- options for special dialogs have to start with "automaticly_"
		local parts = string.split(option_name or "", "_")
		if(not(parts) or not(parts[1]) or parts[1] ~= "automaticly") then
			option_name = "automaticly_"..table.concat(parts[2], "_")
		end
		-- for d_trade and d_got_item effects and preconditions are created WITH DEFAULT VALUES TODO
		d_id = dialog_name
		-- make sure the relevant dialog and fields exist
		dialog.n_dialogs[d_id] = dialog.n_dialogs[d_id] or {}
		dialog.n_dialogs[d_id].d_options = dialog.n_dialogs[d_id].d_options or {}
	end
	-- name the thing for logging purposes
	local log_str = "Dialog "..tostring(d_id)
	if(dialog_name and dialog_name ~= d_id) then
		log_str = log_str.." ["..tostring(dialog_name).."]"
	end
	log_str = log_str..", option <"..tostring(option_name)..">: "
	local is_new = false

	-- translate the name of the target_dialog if needed
	if(target_dialog and not(yl_speak_up.is_special_dialog(target_dialog))) then
		target_dialog = yl_speak_up.d_name_to_d_id(dialog, target_dialog)
	end
	-- TODO: dialogs d_got_item and d_trade are special

	local o_id = option_name
	local mode = 0
	local text_when_prerequisites_not_met = ""
	local parts = string.split(o_id, "_")
	if(not(parts) or not(parts[1]) or not(parts[2])) then
		table.insert(log, log_str.."FAILED to create unknown option \""..tostring(o_id).."\".")
		return nil
	elseif(o_id and parts[1] == "new") then
		-- we are asked to create a *new* option
		o_id = nil
	elseif(o_id and parts[1] == "automaticly") then
		-- this option will be automaticly selected if its preconditions are true
		mode = 1
		option_name = parts[2]
		o_id = option_name
	elseif(o_id and parts[1] == "randomly") then
		-- this option will be randomly selected if its preconditions are true;
		-- (that means all other options of this dialog will have to be randomly as well;
		-- something which cannot be done here as there is no guarantee that all options
		-- *exist* at this point)
		mode = 2
		option_name = parts[2]
		o_id = option_name
	elseif(o_id and parts[1] ~= "o") then
		table.insert(log, log_str.."FAILED to create unknown option \""..tostring(o_id).."\".")
		return nil
	end


	-- if the option does not exist: create it
	if(  not(dialog.n_dialogs[d_id].d_options)
          or not(o_id) or o_id == ""
	  or not(dialog.n_dialogs[d_id].d_options[o_id])) then
		local next_id = nil
		-- get the id part (number) from o_id - because we may be creating a new option here -
		-- but said option may have a diffrent *name* than what a new option would get by
		-- default
		if(o_id) then
			next_id = string.sub(o_id, 3)
			if(next_id == "" or not(tonumber(next_id))) then
				next_id = nil
				table.insert(log, log_str.."FAILED to create new option \""..tostring(o_id).."\".")
				return
			end
		end
		-- pname is nil - thus no logging here
		o_id = yl_speak_up.add_new_option(dialog, nil, next_id, d_id, option_text, target_dialog)
		if(not(o_id)) then
			return nil
		end
		is_new = true
	end

	-- abbreviate that
	local o_data = dialog.n_dialogs[d_id].d_options[o_id]

	-- cchnage option_text if needed
	if(o_data.o_text_when_prerequisites_met ~= option_text) then
		table.insert(log, log_str.."Changed option text from \""..
			tostring(o_data.o_text_when_prerequisites_met)..
			"\" to \""..tostring(option_text).."\" for option \""..tostring(o_id).."\".")
	end
	-- actually update the text
	o_data.o_text_when_prerequisites_met = option_text

	-- chnage greyed out text if needed
	if(o_data.o_text_when_prerequisites_not_met ~= option_text_if_preconditions_false
	   and option_text_if_preconditions_false) then
		table.insert(log, log_str.."Changed greyed out text when prerequisites not met from \""..
			tostring(o_data.o_text_when_prerequisites_not_met)..
			"\" to \""..tostring(option_text_if_preconditions_false or "")..
			"\" for option \""..tostring(o_id).."\".")
		-- make sure the greyed out text gets shown (or not shown)
		o_data.o_text_when_prerequisites_not_met = option_text_if_preconditions_false or ""
	end
	-- make grey_out_ text visible if necessary
	if(o_data.o_text_when_prerequisites_not_met and o_data.o_text_when_prerequisites_not_met ~= ""
	  and option_text_if_preconditions_false and option_text_if_preconditions_false ~= "") then
		-- make sure this text is really shown - and greyed out
		-- (resetting this can only happen through editing the NPC directly; not through import)
		o_data.o_hide_when_prerequisites_not_met = "false"
		o_data.o_grey_when_prerequisites_not_met = "true"
	else
		-- if this were not set to true, then the player would see a clickable button for
		-- the option - but that button would do nothing
		o_data.o_hide_when_prerequisites_not_met = "true"
		o_data.o_grey_when_prerequisites_not_met = "false"
	end

	local r_found = false
	-- the target_dialog may have been changed
	for r_id, r in pairs(o_data.o_results or {}) do
		-- we found the right result/effect that holds the (current) target_dialog
		if(r and r.r_type and r.r_type == "dialog") then
			r_found = true
			if(not(r.r_value) or r.r_value ~= target_dialog) then
				if(is_new) then
					table.insert(log, log_str.."Successfully created new option \""..
						tostring(o_id).."\" with target dialog \""..
						tostring(target_dialog).."\".")
				else
					table.insert(log, log_str.."Changed target dialog from \""..
						tostring(r.r_value).."\" to \""..tostring(target_dialog)..
						"\" for option \""..tostring(o_id).."\".")
				end
				-- actually change the target dialog
				r.r_value = target_dialog
			end
			-- the alternate_text may have been changed
			if(r.alternate_text ~= alternate_text) then
				table.insert(log, log_str.."Changed alternate text from \""..
					tostring(r.r_alternate_text).."\" to \""..tostring(alternate_text)..
					"\" for option \""..tostring(o_id).."\".")
				r.alternate_text = alternate_text
			end
		end
	end
	-- for some reason the effect pointing to the target dialog got lost!
	if(r_found and is_new) then
		table.insert(log, log_str.."Set target dialog to "..tostring(target_dialog)..
					" for new option \""..tostring(o_id).."\".")
	end
	if(not(r_found)) then
		-- create the result/effect that points to the target_dialog
		local r_id = yl_speak_up.add_new_result(dialog, d_id, o_id)
		if(r_id) then
			o_data.o_results[r_id].r_type = "dialog"
			o_data.o_results[r_id].r_value = target_dialog
			o_data.o_results[r_id].alternate_text = alternate_text
			table.insert(log, log_str.."Set target dialog to "..tostring(target_dialog)..
					" for option \""..tostring(o_id).."\".")
		end
	end

	-- "randomly selected" applies to the *dialog* - it is set there and not in the individual option
	local d_data = dialog.n_dialogs[d_id]
	-- is this option selected randomly?
	if(    mode == 2 and not(d_data.o_random)) then
		table.insert(log, log_str.."Changed DIALOG \""..tostring(d_id).."\" to RANDOMLY SELECTED.")
		d_data.o_random = 1
	end

	-- is this option selected automaticly if all preconditions are met?
	if(mode == 1 and not(o_data.o_autoanswer)) then
		o_data.o_autoanswer = 1
		table.insert(log, log_str.."Changed option \""..tostring(o_id).."\" to AUTOMATICLY SELECTED.")
		-- mode is 0 - that means everything is normal for this option
	elseif(mode ~= 1 and o_data.o_autoanswer) then
		o_data.o_autoanswer = nil
		table.insert(log, log_str.."Removed AUTOMATICLY SELECTED from option \""..tostring(o_id).."\".")
	end

	-- the visit_only_once option is handled without logging as it might create too many
	-- entries in the log without adding any helpful information
	if(visit_only_once
	  and (not(o_data.o_visit_only_once)
	     or o_data.o_visit_only_once ~= 1)) then
		o_data.o_visit_only_once = 1
	elseif(not(visit_only_once)
	  and   o_data.o_visit_only_once and o_data.o_visit_only_once == 1) then
		o_data.o_visit_only_once = nil
	end
	-- set sort order of options (no logging because that might get too spammy)
	if(sort_order) then
		o_data.o_sort = sort_order
	end
	-- this option has been updated
	o_data.o_tmp_needs_update = false
	if(o_data.o_sort and d_data.d_tmp_sort_value and o_data.o_sort >= d_data.d_tmp_sort_value) then
		-- make sure this stores the highest o_sort value we found
		d_data.d_tmp_sort_value = o_data.o_sort + 1
	end
	return o_id
end


-- add a new result to option o_id of dialog d_id
yl_speak_up.add_new_result = function(dialog, d_id, o_id)
	if(not(dialog) or not(dialog.n_dialogs) or not(dialog.n_dialogs[d_id])
	  or not(dialog.n_dialogs[d_id].d_options) or not(dialog.n_dialogs[d_id].d_options[o_id])) then
		return
	end
	-- create a new result (first the id, then the actual result)
	local future_r_id = "r_" .. yl_speak_up.find_next_id(dialog.n_dialogs[d_id].d_options[o_id].o_results)
	if future_r_id == "r_1" then
		dialog.n_dialogs[d_id].d_options[o_id].o_results = {}
	end
	dialog.n_dialogs[d_id].d_options[o_id].o_results[future_r_id] = {}
	dialog.n_dialogs[d_id].d_options[o_id].o_results[future_r_id].r_id = future_r_id
	return future_r_id
end
-- TODO: we need yl_speak_up.update_dialog_option_result as well


-- this is useful for result types that can exist only once per option
-- (apart from editing with the staff);
-- examples: "dialog" and "trade";
-- returns tue r_id or nil if no result of that type has been found
yl_speak_up.get_result_id_by_type = function(dialog, d_id, o_id, result_type)
	if(not(dialog) or not(dialog.n_dialogs) or not(dialog.n_dialogs[d_id])
	  or not(dialog.n_dialogs[d_id].d_options) or not(dialog.n_dialogs[d_id].d_options[o_id])) then
		return
	end
	local results = dialog.n_dialogs[d_id].d_options[o_id].o_results
	if(not(results)) then
		return
	end
	for k, v in pairs(results) do
		if(v.r_type == result_type) then
			return k
		end
	end
end


-- helper function for sorting options/answers using options[o_id].o_sort
-- (or dialogs by d_sort)
yl_speak_up.get_sorted_options = function(options, sort_by)
	local sorted_list = {}
	for k,v in pairs(options) do
		table.insert(sorted_list, k)
	end
	table.sort(sorted_list,
		function(a,b)
			if(not(options[a][sort_by])) then
				return false
			elseif(not(options[b][sort_by])) then
				return true
			-- sadly not all entries are numeric
			elseif(tonumber(options[a][sort_by]) and tonumber(options[b][sort_by])) then
				return (tonumber(options[a][sort_by]) < tonumber(options[b][sort_by]))
			-- numbers have a higher priority
			elseif(tonumber(options[a][sort_by])) then
				return true
			elseif(tonumber(options[b][sort_by])) then
				return false
			-- if the value is the same: sort by index
			elseif(options[a][sort_by] == options[b][sort_by]) then
				return (a < b)
			else
				return (options[a][sort_by] < options[b][sort_by])
			end
		end
	)
	return sorted_list
end


-- simple sort of keys of a table numericly;
-- this is not efficient - but that doesn't matter: the lists are small and
-- it is only executed when configuring an NPC
-- simple: if the parameter is true, the keys will just be sorted (i.e. player names) - which is
-- 	not enough for d_<nr>, o_<nr> etc. (which need more care when sorting)
yl_speak_up.sort_keys = function(t, simple)
	local keys = {}
	for k, v in pairs(t) do
		-- add a prefix so that p_2 ends up before p_10
		if(not(simple) and string.len(k) == 3) then
			k = "a"..k
		end
		table.insert(keys, k)
	end
	table.sort(keys)
	if(simple) then
		return keys
	end
	for i,k in ipairs(keys) do
		-- avoid cutting the single a from a_1 (action 1)
		if(k and string.sub(k, 1, 1) == "a" and string.sub(k, 2, 2) ~= "_") then
			-- remove the leading blank
			keys[i] = string.sub(k, 2)
		end
	end
	return keys
end


-- checks if dialog contains d_id and o_id
yl_speak_up.check_if_dialog_has_option = function(dialog, d_id, o_id)
	return (dialog and d_id and o_id
	  and dialog.n_dialogs
	  and dialog.n_dialogs[d_id]
	  and dialog.n_dialogs[d_id].d_options
	  and dialog.n_dialogs[d_id].d_options[o_id])
end

-- checks if dialog exists
yl_speak_up.check_if_dialog_exists = function(dialog, d_id)
	return (dialog and d_id
	  and dialog.n_dialogs
	  and dialog.n_dialogs[d_id])
end



yl_speak_up.is_special_dialog = function(d_id)
	if(not(d_id)) then
		return false
	end
	return (d_id == "d_trade" or d_id == "d_got_item" or d_id == "d_dynamic" or d_id == "d_end")
end


yl_speak_up.d_name_to_d_id = function(dialog, d_name)
	if(not(dialog) or not(dialog.n_dialogs) or not(d_name) or d_name == "") then
		return nil
	end
	-- it is already the ID of an existing dialog
	if(dialog.n_dialogs[d_name]) then
		return d_name
	end
	-- search all dialogs for one with a fitting d_name
	for k,v in pairs(dialog.n_dialogs) do
		if(v and v.d_name and v.d_name == d_name) then
			return k
		end
	end
	return nil
end


-- get the name of a dialog (reverse of above)
yl_speak_up.d_id_to_d_name = function(dialog, d_id)
	if(not(dialog) or not(dialog.n_dialogs) or not(d_id) or d_id == ""
	  or not(dialog.n_dialogs[d_id])
	  or not(dialog.n_dialogs[d_id].d_name)
	  or dialog.n_dialogs[d_id].d_name == "") then
		return d_id
	end
	return dialog.n_dialogs[d_id].d_name
end




-- how many own (not special, not generic) dialogs does the NPC have?
yl_speak_up.count_dialogs = function(dialog)
	local count = 0
	if(not(dialog) or not(dialog.n_dialogs)) then
		return 0
	end
	for d_id, v in pairs(dialog.n_dialogs) do
		if(d_id
		  and not(yl_speak_up.is_special_dialog(d_id))
		  and not(dialog.n_dialogs[d_id].is_generic)) then
			count = count + 1
		end
	end
	return count
end
