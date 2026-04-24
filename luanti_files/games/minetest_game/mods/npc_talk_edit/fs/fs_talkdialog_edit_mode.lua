
-- we have a better version of this in the editor - so not offer this particular entry:
yl_speak_up.get_fs_talkdialog_add_basic_edit = function(
				pname, formspec, h, pname_for_old_fs, is_a_start_dialog,
				active_dialog, luaentity, may_edit_npc, anz_options)
	return {h = h, formspec = formspec}
end


-- This is the main talkdialog the NPC shows when right-clicked. (now in edit_mode)
local old_input_talk = yl_speak_up.input_talk
yl_speak_up.input_talk = function(player, formname, fields)
	local pname = player:get_player_name()
	-- Is the player working on this particular npc?
	local edit_mode = yl_speak_up.in_edit_mode(pname)
	-- if not: do the normal things outside edit mode
	if(not(edit_mode) and not(fields.button_start_edit_mode)) then
		return old_input_talk(player, formname, fields)
	end
	-- selected option/answer
	local o = ""
	-- do all the processing and executing old_input_talk (in non-edit_mode)
	-- can do - but do not execute any actions; just return o
	fields.just_return_selected_option = true
	o = old_input_talk(player, formname, fields)
	-- old_input_talk handled it (including some error detection like
	-- wrong formname, not talking to npc, npc not configured)

	-- if in edit mode: detect if something was changed;
	local result = yl_speak_up.edit_mode_apply_changes(pname, fields)
	-- o is only nil if the old function returned nil; it does that
	-- when it found a fitting reaction to a button press
	if(not(o) and not(fields.button_start_edit_mode) and not(fields.player_offers_item)) then
		return
	end
	local n_id = yl_speak_up.speak_to[pname].n_id

	-- start edit mode (requires npc_talk_owner)
	if fields.button_start_edit_mode then
		-- check if this particular NPC is really owned by this player or if the player has global privs
		if(not(yl_speak_up.may_edit_npc(player, n_id))) then
			minetest.chat_send_player(pname, "Sorry. You do not have the npc_talk_owner or npc_talk_master priv.")
			return
		end
		-- the staff allows to create multiple target dialogs as result; this makes no sense
		-- and is too disambigous
		if(yl_speak_up.check_for_disambigous_results(n_id, pname)) then
			-- this needs to be fixed by someone with a staff; we don't know which dialog is the right
			-- result
			return
		end
		-- make sure the inventory of the NPC is loaded
		yl_speak_up.load_npc_inventory(n_id, true, nil)
		-- for older formspec versions: reset scroll counter
		yl_speak_up.speak_to[pname].counter = 1
		yl_speak_up.speak_to[pname].option_index = 1
		-- enter edit mode with that particular NPC
		yl_speak_up.edit_mode[pname] = yl_speak_up.speak_to[pname].n_id
		-- load the NPC dialog anew - but only what the NPC itself has to say, no generic dialogs
		yl_speak_up.speak_to[pname].dialog = yl_speak_up.load_dialog(n_id, false)
		-- start a new chat - but this time in edit mode
		yl_speak_up.speak_to[pname].d_id = nil
		yl_speak_up.show_fs(player, "talk", {n_id = yl_speak_up.speak_to[pname].n_id, d_id = nil})
		return
	-- end edit mode (does not require the priv; will only switch back to normal behaviour)
	elseif fields.button_end_edit_mode then
		-- if there are any changes done: ask first and don't end edit mode yet
		yl_speak_up.show_fs(player, "quit", nil)
		return
	end


	-- show which dialogs point to this one
	if(fields.show_what_points_to_this_dialog) then
		local dialog = yl_speak_up.speak_to[pname].dialog
		local d_id = yl_speak_up.speak_to[pname].d_id
		yl_speak_up.show_fs(player, "show_what_points_to_this_dialog",
			yl_speak_up.speak_to[pname].d_id)
		return
	end

	-- the player wants to change name and description; show the formspec
	if(fields.button_edit_name_and_description) then
		-- this is not the initial config - but the same formspec can be used
		yl_speak_up.show_fs(player, "initial_config",
			{n_id = n_id, d_id = yl_speak_up.speak_to[pname].d_id, false})
		return
	end

	-- change skin, cape and wielded items
	if(fields.edit_skin) then
		local dialog = yl_speak_up.speak_to[pname].dialog
		-- necessary so that the fashin formspec can be created
		yl_speak_up.speak_to[pname].n_npc = dialog.n_npc
		yl_speak_up.show_fs(player, "fashion")
		return
	end

	if(fields.button_save_dialog) then
		yl_speak_up.show_fs(player, "talk",
			{n_id = n_id, d_id = yl_speak_up.speak_to[pname].d_id, do_save = true})
		return
	end

	if(fields.button_export_dialog) then
		yl_speak_up.show_fs(player, "export")
		return
	end

	if(fields.button_edit_notes) then
		yl_speak_up.show_fs(player, "notes")
		return
	end

	-- the player wants to give something to the NPC
	-- (more complex in edit mode)
	if(fields.player_offers_item) then
		local dialog = yl_speak_up.speak_to[pname].dialog
		local future_d_id = "d_got_item"
		-- make sure this dialog exists; create if needed
		if(not(dialog.n_dialogs[ future_d_id ])) then
			dialog.n_dialogs[future_d_id] = {
				d_id = future_d_id,
				d_type = "text",
				d_text = "",
				d_sort = 9999 -- make this the last option
			}
		end
		-- in edit mode: allow to edit the options
		yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = future_d_id})
		return
	end


	-- button was clicked, now let's execute the results
	local d_id = yl_speak_up.speak_to[pname].d_id
	local dialog = yl_speak_up.speak_to[pname].dialog

	-- all three buttons (pre(C)onditions, (Ef)fects, edit option) lead to the same new formspec
	local n_dialog = dialog.n_dialogs[d_id]

	if(n_dialog and n_dialog.d_options) then
		for o_id,v in pairs(n_dialog.d_options) do
			if( fields["edit_option_"..o_id]
			 or fields["conditions_"..o_id]
			 or fields["actions_"..o_id]
			 or fields["quests_"..o_id]
			 or fields["effects_"..o_id]) then
				-- store which option we want to edit
				yl_speak_up.speak_to[pname].o_id = o_id
				-- if something was changed: ask for confirmation
				yl_speak_up.show_fs(player, "edit_option_dialog",
					{n_id = yl_speak_up.speak_to[pname].n_id,
					d_id = d_id, o_id = o_id, caller="button"})
				return
			end
		end
	end

	-- we may soon need actions and o_results from the selected_option
	local selected_option = {}
	if(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o)) then
		selected_option = dialog.n_dialogs[d_id].d_options[o]
	end

	-- translate a dialog name into a d_id
	fields.d_id = yl_speak_up.d_name_to_d_id(dialog, fields.d_id)
	-- in edit mode: has another dialog been selected?
	-- if nothing better can be found: keep the old dialog
	local show_dialog = d_id
	-- an option button was selected;
	-- since we do not execute actions and effects in edit mode, we need to find out the
	-- right target dialog manually (and assume all went correct)
	if( o ~= "" ) then
		-- find out the normal target dialog of this option
		if(selected_option and selected_option.o_results) then
			for k, v in pairs(selected_option.o_results) do
				if(v and v.r_type == "dialog") then
					show_dialog = v.r_value
				end
			end
		end
	-- dropdown menu was used; provided the dialog exists (and it's not the "New dialog" option)
	-- (if a new dialog was added using the "+" button, fields.d_id gets set accordingly)
	elseif(fields.d_id and fields.d_id ~= show_dialog and dialog.n_dialogs[fields.d_id]) then
		show_dialog = fields.d_id
	-- in edit mode: prev_dialog_../next_dialog_.. was selected
	else
		for k,v in pairs(dialog.n_dialogs) do
			if(fields["prev_dialog_"..k]) then
				show_dialog = k
			elseif(fields["next_dialog_"..k]) then
				show_dialog = k
			end
		end
	end

	yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = show_dialog})
	-- no option was selected - so we need to end this here
	return
end


-- in edit mode, *all* options are displayed
local old_calculate_displayable_options = yl_speak_up.calculate_displayable_options
yl_speak_up.calculate_displayable_options = function(pname, d_options, allow_recursion)
	if(yl_speak_up.in_edit_mode(pname)) then
		-- no options - nothing to do
		if(not(d_options)) then
			return {}
		end
		-- in edit mode: show all options (but sort them first)
		local retval = {}
		local sorted_list = yl_speak_up.get_sorted_options(d_options, "o_sort")
		for i, o_k in ipairs(sorted_list) do
			retval[o_k] = true
		end
		return retval
	end
	-- outside edit mode: really calculate what can be displayed
	return old_calculate_displayable_options(pname, d_options, allow_recursion)
end


-- in edit mode, autoanswer, random dialogs and d_got_item play no role and are *not* applied
-- (we want to see and edit all options regardless of preconditions)
local old_apply_autoanswer_etc = yl_speak_up.apply_autoanswer_and_random_and_d_got_item
yl_speak_up.apply_autoanswer_and_random_and_d_got_item = function(player, pname, d_id, dialog, allowed, active_dialog, recursion_depth)
	-- no automatic switching in edit_mode
	if(yl_speak_up.in_edit_mode(pname)) then
		return
	end
	return old_apply_autoanswer_etc(player, pname, d_id, dialog, allowed, active_dialog, recursion_depth)
end


-- helper function for yl_speak_up.get_fs_talkdialog:
--   shows the text the NPC "speaks" and adds edit and navigation buttons
--   (all only in *edit_mode*)
local old_talkdialog_main_text = yl_speak_up.get_fs_talkdialog_main_text
yl_speak_up.get_fs_talkdialog_main_text = function(pname, formspec, h, dialog, dialog_list, c_d_id, active_dialog, alternate_text)
	if(not(yl_speak_up.in_edit_mode(pname))) then
		return old_talkdialog_main_text(pname, formspec, h, dialog, dialog_list, c_d_id, active_dialog, alternate_text)
	end
	local d_id_to_dropdown_index = {}
	-- allow to change skin, wielded items etc.
	table.insert(formspec, "button[15.75,3.5;3.5,0.9;edit_skin;Edit Skin]")

	if(not(dialog) or not(dialog.n_dialogs)) then
		return {h = h, formspec = formspec, d_id_to_dropdown_index = {}, dialog_list = dialog_list}
	end

	-- display the window with the text the NPC is saying
	-- sort all dialogs by d_sort
	local sorted_list = yl_speak_up.get_sorted_options(dialog.n_dialogs, "d_sort")
	-- add buttons for previous/next dialog
	for i, d in ipairs(sorted_list) do
		local d_name = dialog.n_dialogs[d].d_name or d
		-- build the list of available dialogs for the dropdown list(s)
		dialog_list = dialog_list..","..minetest.formspec_escape(d_name)
		if(d == c_d_id) then
			local prev_dialog = tostring(minetest.formspec_escape(sorted_list[i-1]))
			yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
				"button", "15.4,5.0;2,0.9", "prev_dialog_"..prev_dialog,
				"<",
				"Go to previous dialog "..prev_dialog..".",
				(sorted_list[ i-1 ]))
			local next_dialog = tostring(minetest.formspec_escape(sorted_list[i+1]))
			yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
				"button", "17.6,5.0;2,0.9", "next_dialog_"..next_dialog,
				">",
				"Go to next dialog "..next_dialog..".",
				(sorted_list[ i+1 ]))
		end
		d_id_to_dropdown_index[d] = i + 1
	end
	dialog_list = dialog_list..",d_end"
	d_id_to_dropdown_index["d_end"] = #sorted_list + 2


	if(not(yl_speak_up.is_special_dialog(c_d_id))) then
		table.insert(formspec, "label[0.2,4.2;Dialog ")
		table.insert(formspec, minetest.formspec_escape(c_d_id))
		table.insert(formspec, ":]")
		table.insert(formspec, "field[5.0,3.6;9.8,1.2;d_name;;")
		table.insert(formspec, minetest.formspec_escape(dialog.n_dialogs[c_d_id].d_name or c_d_id))
		table.insert(formspec, "]")
		table.insert(formspec, "tooltip[d_name;Dialogs can have a *name* that is diffrent from\n"..
					"their ID (which is i.e. d_4). The name will be shown\n"..
					"in the dropdown list. Save a new name by clicking on\n"..
					"the dialog \"Save\" button.]")
	end

	table.insert(formspec, "label[0.2,5.5;Dialog:]") -- "..minetest.formspec_escape(c_d_id)..":]")
	table.insert(formspec, "dropdown[5.0,5.0;9.8,1;d_id;"..dialog_list..";"..
				(d_id_to_dropdown_index[c_d_id] or "1")..",]")
	table.insert(formspec, "tooltip[5.0,5.0;9.8,1;"..
		"Select the dialog you want to edit. Currently, dialog "..c_d_id..
			" is beeing displayed.;#FFFFFF;#000000]")

	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", "3.5,5.0;1,0.9", "show_new_dialog",
		"+",
		"Create a new dialog.",
		true)
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", "11.0,0.3;2,1.0", "button_edit_notes",
		"Notes",
		"Keep notes of what this NPC is for, how his character is etc.",
		true)
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", "13.2,0.3;2,0.9", "button_edit_name_and_description",
		"Edit",
		"Edit name and description of your NPC.",
		true)
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", "15.4,0.3;2,0.9", "button_save_dialog",
		"Save",
		"Save this dialog.",
		true)
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", "17.5,0.3;2.4,0.9", "button_export_dialog",
		"Export",
		"Export: Show the dialog in .json format which you can copy and store on your computer.",
		true)


	local tmp = "[0.2,6;19.6,16.8;d_text;"
	-- static help text instead of text input field for d_got_item
	if(c_d_id == "d_got_item") then
		table.insert(formspec, "hypertext"..tmp..
			"<normal>Note:\nThis is a special dialog. "..
				"It will be called when the player clicks on "..
				"<b>I want to give you something</b>."..
			"\nMost of the things listed below will be added automaticly when you add a "..
				"new option to this dialog. In most cases you may just have to edit the "..
				"<b>precondition</b> so that the <i>right item</i> is accepted, and then "..
				"set the <b>target dialog</b> <i>according to your needs</i>. Please also "..
				"edit the <b>alternate text</b> so that it fits your <i>item</i>!"..
			"\nThis is how it works in detail:"..
			"\n<b>Each option</b> you add here ought to deal with one item(stack) that "..
				"the NPC expects from the player, i.e. <i>farming:bread 2</i>. "..
				"Each option needs to be selected <b>automaticly</b> and ought to contain:"..
			"\n* a <b>precondition</b> regarding "..
				"<b>an item the player offered/gave to the NPC</b> "..
				"(shown as <b>player_offered_item</b> in overview) "..
				"where you define which item(stack) is relevant for this option"..
			"\n* an <b>effect</b> regarding <b>an item the player offered to the NPC</b> "..
				"(shown as <b>deal_with_offered_item</b> in overview) "..
				"where you define what shall happen to the offered item. Usually "..
				"the NPC will accept the item and put it into its inventory."..
			"\n* Don't forget to set a suitable target dialog for the <b>effect</b>! "..
				"Your NPC ought to comment on what he got, i.e. "..
				"<i>Thank you for those two breads! You saved me from starving.</i>"..
				"You can also work with an alternate text here (as is done in the "..
				"default setup when adding a new option here)."..
			"\n</normal>]")
	-- static help text instead of text input field for d_trade
	elseif(c_d_id == "d_trade") then
		table.insert(formspec, "hypertext"..tmp..
			"<normal>Note:\nThis is a special dialog. "..
				"It will be called when the player clicks on "..
				"<b>Let's trade!</b>."..
			"\nSome of the things listed below will be added automaticly when you add a "..
				"new option to this dialog. In most cases you may just have to edit the "..
				"<b>precondition</b> so that the <i>right item(stack)</i> is beeing "..
				"searched for, and you need to add suitable effects. The ones added "..
				"automaticly are just an example."..
			"\nNote that once the NPC found a matching precondition, it will execute the "..
			"relevant effects and present the player the trade list. Any further options "..
			"that might also fit will not be executed this time. Only <b>one</b> option "..
			"(or none) will be selected each time."..
			"\nThis is how it works in detail:"..
			"\n<b>Each option</b> you add here ought to deal with one item(stack) that "..
				"the NPC might or might not have in its inventory, "..
				"i.e. <i>default:stick 4</i>. "..
				"Each option needs to be selected <b>automaticly</b> and ought to contain:"..
			"\n* at least one <b>precondition</b> regarding "..
				"<b>the inventory of the NPC</b> "..
				"where you define which item(stack) is relevant for this option "..
				"(you can add multiple such preconditions for each option)"..
			"\n* at least one <b>effect</b> regarding what the NPC shall do if the "..
				"precondition matches. In most cases, <b>NPC crafts something</b>, "..
				"<b>put item from the NPC's inventory into a chest etc.</b> or "..
				"<b>take item from a chest etc. and put it into the NPC's inventory</b> "..
				"will be what you are looking for. More than one effect is possible."..
			"\n* In this particular case, no target dialog needs to be selected. After "..
				"executing the effect(s), the trade list view will be shown to the "..
				"player."..
			"\n</normal>]")
	elseif(c_d_id == "d_dynamic") then
		table.insert(formspec, "hypertext"..tmp..
			"<normal>Note:\nThis is a special dialog. "..
				"Each time right before this special dialog is displayed, a "..
				"function is called that can fill the <b>d_dynamic</b> dialog "..
				"with text and options."..
			"\nThat function has to decide <b>based on NPC, player and context</b> what "..
				"it wants to display this time."..
			"\nThe d_dynamic dialog is <b>never saved</b> as part of the dialog. "..
				"It has to be dynamicly created by your function each time it is needed."..
			"\nThe d_dynamic dialog will always be available as a <b>legitimate target "..
				"dialog</b> of a dialog option. Its options can do all that which "..
				"options of other dialogs can do. Its options can also lead back to "..
				"normal static parts of the dialog."..
			"\n</normal>]")
	elseif(active_dialog and active_dialog.d_text) then
		table.insert(formspec, "textarea"..tmp..";"..
			minetest.formspec_escape(active_dialog.d_text or "?")..
			"]")
	else
		table.insert(formspec, "textarea"..tmp..";"..
			minetest.formspec_escape("[no text]")..
			"]")
	end
	return {h = h, formspec = formspec, d_id_to_dropdown_index = d_id_to_dropdown_index,
		dialog_list = dialog_list}
end


-- helper function for yl_speak_up.get_fs_talkdialog:
--   prints one entry (option/answer) in normal and *edit_mode*
local old_talkdialog_line = yl_speak_up.get_fs_talkdialog_line
yl_speak_up.get_fs_talkdialog_line = function(
				formspec, h, pname_for_old_fs, oid, sb_v,
				dialog, allowed, pname,
				-- these additional parameters are needed *here*, in edit_mode:
				active_dialog, dialog_list, d_id_to_dropdown_index,
				current_index, anz_options)

	if(not(yl_speak_up.in_edit_mode(pname))) then
		-- in normal mode:
		return old_talkdialog_line(formspec, h, pname_for_old_fs, oid, sb_v,
				dialog, allowed, pname,
				active_dialog, dialog_list, d_id_to_dropdown_index,
				current_index, anz_options)
	end

	-- in edit mode:
	local offset = 0.0
	local field_length = 43.8
	if(pname_for_old_fs) then
		offset = 0.7
		field_length = 41.8
	end
	h = h + 1
	-- add a button "o_<nr>:" that leads to an edit formspec for this option
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", tostring(2.9+offset).."," .. h .. ";2,0.9", "edit_option_" .. oid,
		oid,
		"Edit target dialog, pre(C)onditions and (Ef)fects for option "..oid..".",
		true)
	-- find the right target dialog for this option (if it exists):
	local target_dialog = nil
	local results = active_dialog.d_options[sb_v.o_id].o_results
	-- has this option more results/effects than just switching to another dialog?
	local has_other_results = false
	if(results ~= nil) then
		for k, v in pairs(results) do
			if v.r_type == "dialog"
			  and (dialog.n_dialogs[v.r_value] ~= nil
			  or yl_speak_up.is_special_dialog(v.r_value)) then
				-- there may be more than one in the data structure
				target_dialog = v.r_value
			elseif v.r_type ~= "dialog" then
				has_other_results = true
			end
		end
	end
	-- add a button "-> d_<nr>" that leads to the target dialog (if one is set)
	-- selecting an option this way MUST NOT execute the pre(C)onditions or (Ef)fects!
	local arrow = "->"
	local only_once = ""
	if(sb_v.o_visit_only_once and sb_v.o_visit_only_once == 1) then
		arrow = "*"
		only_once = "\nNote: This option can be selected only *once* per talk!"
	end
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", tostring(12.6+offset)..","..h..";1,0.9", "button_" .. oid,
		arrow,
		"Go to target dialog "..minetest.formspec_escape(target_dialog or "")..
			" that will be shown when this option ("..oid..") is selected."..
			only_once,
		(target_dialog))

	-- allow to set a new target dialog
	table.insert(formspec, "dropdown["..tostring(5.0+offset)..","..h..";7.7,1;d_id_"..
		oid..";"..
		dialog_list..";"..
		(d_id_to_dropdown_index[(target_dialog or "?")] or "0")..",]")
	-- add a tooltip "Change target dialog"
	table.insert(formspec, "tooltip[5.0,"..h..";4.7,1;"..
		"Change target dialog for option "..oid..".;#FFFFFF;#000000]")

	-- are there any prerequirements?
	local prereq = active_dialog.d_options[sb_v.o_id].o_prerequisites
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", tostring(0.5+offset)..","..h..";0.5,0.9", "conditions_"..oid,
		"C",
		"There are pre(C)onditions required for showing this option. Display them.",
		(prereq and next(prereq)))

	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", tostring(1.6+offset)..","..h..";0.6,0.9", "effects_"..oid,
		"Ef",
		"There are further (Ef)fects (apart from switching\n"..
			"to a new dialog) set for this option. Display them.",
		(has_other_results))

	local d_option = active_dialog.d_options[sb_v.o_id]
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", tostring(2.25+offset)..","..h..";0.6,0.9", "quests_"..oid,
		"Q",
		"This option sets a (Q)est step if possible.\n"..
			"A special precondition is evaluated automaticly\n"..
			"to check if the quest step can be set.",
		(d_option and d_option.quest_id and d_option.quest_step))

	-- are there any actions defined?
	local actions = active_dialog.d_options[sb_v.o_id].actions
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", tostring(1.05+offset)..","..h..";0.5,0.9", "actions_"..oid,
		"A",
		"There is an (A)ction (i.e. a trade) that will happen\n"..
			"when switching to a new dialog. Display actions and\n"..
			"trade of this option.",
		(actions and next(actions)))

	if(sb_v.o_autoanswer) then
		table.insert(formspec,
			"label["..tostring(13.5+offset+0.2)..","..tostring(h+0.5)..";"..
				minetest.formspec_escape("[Automaticly selected if preconditions are met] "..
					tostring(sb_v.o_text_when_prerequisites_met))..
				"]")
	elseif(active_dialog.o_random) then
		table.insert(formspec,
			"label["..tostring(13.5+offset+0.2)..","..tostring(h+0.5)..";"..
				minetest.formspec_escape("[One of these options is randomly selected] "..
					tostring(sb_v.o_text_when_prerequisites_met))..
				"]")
	else
		-- show the actual text for the option
		yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
			"field", tostring(13.5+offset)..","..h..";"..
				 tostring(field_length-5.3)..",0.9",
			"text_option_" .. oid,
			";"..minetest.formspec_escape(sb_v.o_text_when_prerequisites_met),
			"Edit the text that is displayed on button "..oid..".",
			true)
	end
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"button", tostring(10.5+offset+field_length-2.2)..","..h..";1.0,0.9", "delete_option_"..oid,
		"Del",
		"Delete this option/answer.",
		true)

	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
--		"image_button", tostring(9.9+offset+field_length-0.5)..","..h..";0.5,0.9"..
--			";gui_furnace_arrow_bg.png^[transformR180",
		"button", tostring(10.5+offset+field_length-1.1)..","..h..";0.5,0.9",
		"option_move_down_"..oid,
		"v",
		"Move this option/answer one down.",
		(current_index < anz_options))
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
--		"image_button", tostring(9.9+offset+field_length-1.0)..","..h..";0.5,0.9"..
--			";gui_furnace_arrow_bg.png",
		"button", tostring(10.5+offset+field_length-0.5)..","..h..";0.5,0.9",
		"option_move_up_"..oid,
		"^",
		"Move this option/answer one up.",
		(current_index > 1))
	return {h = h, formspec = formspec}
end


-- add a prefix to "I want to give you something." dialog option in edit_mode:
local old_talkdialog_offers_item = yl_speak_up.get_fs_talkdialog_add_player_offers_item
yl_speak_up.get_fs_talkdialog_add_player_offers_item = function(pname, formspec, h, dialog, add_text, pname_for_old_fs)
	local offer_item_add_text = nil
	if(yl_speak_up.in_edit_mode(pname)) then
		-- force showing the "I want to give you something"-text
		offer_item_add_text = minetest.formspec_escape("[dialog d_got_item] -> ")
	end
	return old_talkdialog_offers_item(pname, formspec, h, dialog, offer_item_add_text, pname_for_old_fs)
end


-- helper function for yl_speak_up.get_fs_talkdialog:
--   if the player can edit the NPC,
--   either add a button for entering edit mode
--   or add the buttons needed to edit the dialog when in *edit mode*
local old_talkdialog_add_edit_and_command_buttons = yl_speak_up.get_fs_talkdialog_add_edit_and_command_buttons
yl_speak_up.get_fs_talkdialog_add_edit_and_command_buttons = function(
				pname, formspec, h, pname_for_old_fs, is_a_start_dialog,
				active_dialog, luaentity, may_edit_npc, anz_options)
	-- add the buttons that are added to all editable NPC *first*:
	-- inventory access, commands for mobs_npc, custom commands
	local res = old_talkdialog_add_edit_and_command_buttons(
				pname, formspec, h, pname_for_old_fs, is_a_start_dialog,
				active_dialog, luaentity, may_edit_npc, anz_options)
	formspec = res.formspec
	h = res.h
	-- if the player cannot *enter* edit_mode:
	if(not(may_edit_npc)) then
		return res
	end
	local edit_mode = yl_speak_up.in_edit_mode(pname)
	-- button "show log" for those who can edit the NPC (entering edit mode is not required)
	local text = minetest.formspec_escape(
		"[Log] Show me your log.")
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"show_log",
		text, text,
		true, nil, nil, pname_for_old_fs)
	-- Offer to enter edit mode if the player has the npc_talk_owner priv OR is allowed to edit the NPC.
	-- The npc_talk_master priv allows to edit all NPC.
	if(not(edit_mode)) then
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"button_start_edit_mode",
			"Enters edit mode. In this mode, you can edit the texts the NPC says and the "..
				"answers that can be given.",
			-- chat option: "I am your owner. I have new orders for you.
			"I am your owner. I have new orders for you.",
			true, nil, true, pname_for_old_fs) -- is button_exit
		return {h = h, formspec = formspec}
	end

	local offset = 0.0
	-- If in edit mode, add new menu entries: "add new options", "end edit mode" and what else is needed.
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"add_option",
		-- chat option: "Add a new answer/option to this dialog."
		"Adds a new option to this dialog. You can delete options via the option edit menu.",
		"Add a new option/answer to this dialog. You can delete options via the option "..
			"edit menu.",
		-- the amount of allowed options/answers has been reached
		(anz_options < yl_speak_up.max_number_of_options_per_dialog),
			"Maximum number of allowed answers/options reached. No further options/answers "..
				"can be added.", nil, pname_for_old_fs)

	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"delete_this_empty_dialog",
		-- chat option: "Delete this dialog."
		"Dialogs can only be deleted when they are empty and have no more "..
			"options/answers. This is the case here, so the dialog can be deleted.",
		"Delete this empty dialog.",
		(active_dialog and active_dialog.d_text == "" and anz_options == 0),
		-- (but only show this option if the dialog is empty)
		"If you want to delete this dialog, you need to delete all options and its "..
			"text first.", nil, pname_for_old_fs)

	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"show_what_points_to_this_dialog",
		-- chat option: "Show what points to this dialog."
		"Show which other dialog options or failed actions\n"..
			"or effects lead the player to this dialog here.",
		"Show what points to this dialog.",
		-- there is no alternate text to show
		true, nil, nil, pname_for_old_fs)

	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"make_first_option",
		-- chat option: "Make this dialog the first one shown when starting to talk."
		"The NPC has to start with one dialog when he is right-clicked. "..
			"Make this dialog the one shown.",
		"Make this dialog the first one shown when starting a conversation.",
		(active_dialog and active_dialog.d_sort and tonumber(active_dialog.d_sort) ~= 0),
		-- (but only show this option if it's not already the first one)
		"This dialog will be shown whenever a conversation is started.", nil,pname_for_old_fs)

	local b_text = "Turn this into"
	if(is_a_start_dialog) then
		b_text = "This shall no longer be"
	end
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"turn_into_a_start_dialog",
		"With automatic selection of options, it is possible that the real\n"..
			"start dialog will never be shown to the player. However, we need\n"..
			"to add some buttons to that start dialog for i.e. giving items\n"..
			"to the NPC and for trading. Therefore, dialogs can be marked as\n"..
			"*a* start dialog so that these buttons will be added to those dialogs.",
		b_text.." *a* start dialog where buttons for trade etc. are shown.",
		not(active_dialog and active_dialog.d_sort and tonumber(active_dialog.d_sort) == 0),
		"The start dialog automaticly counts as *a* start dialog where buttons for "..
			"trade etc. are shown.", nil, pname_for_old_fs)

	-- chat option: Mute/Unmute NPC
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"mute_npc",
		-- chat option: mute the NPC
		"The NPC will no longer show his dialogs when he is right-clicked. This is "..
			"useful while you edit the NPC and don't want players to see "..
			"unfinished entries and/or quests.",
		"State: Not muted. Stop talking to other players while I give you new orders.",
		(luaentity and luaentity.yl_speak_up.talk), nil, nil, pname_for_old_fs)
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"un_mute_npc",
		-- unmute the NPC
		"The NPC will show his dialogs to other players when he is right-clicked. "..
			"This is the normal mode of operation. Choose this when you are "..
			"finished editing.",
		"State: You are currently muted. Talk to anyone again who wants to talk to you.",
		-- the NPC has to be there
		(luaentity and not(luaentity.yl_speak_up.talk)), nil, nil, pname_for_old_fs)


	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"button_end_edit_mode",
		"Ends edit mode. From now on, your NPC will talk to you like he talks to other "..
			"players. You can always give him new orders by entering edit mode again.",
		-- chat option:"That was all. I'm finished with giving you new orders. Remember them!"
		"That was all. I'm finished with giving you new orders. Remember them!",
		true, nil, true, pname_for_old_fs) -- is button_exit
	return {h = h, formspec = formspec}
end


-- apply force_edit_mode if necessary
local old_get_fs_talkdialog = yl_speak_up.get_fs_talkdialog
yl_speak_up.get_fs_talkdialog = function(player, n_id, d_id, alternate_text, recursion_depth)
	if(not(player)) then
		return
	end
	local pname = player:get_player_name()
	-- are we in force edit mode, and can the player edit this NPC?
	if(yl_speak_up.force_edit_mode[pname]
	  -- not already in edit mode?
	  and (not(yl_speak_up.edit_mode[pname]) or yl_speak_up.edit_mode[pname] ~= n_id)
	  and yl_speak_up.may_edit_npc(player, n_id)) then
		yl_speak_up.edit_mode[pname] = n_id
	end
	return old_get_fs_talkdialog(player, n_id, d_id, alternate_text, recursion_depth)
end

--[[
yl_speak_up.get_fs_talk_wrapper = function(player, param)
	if(not(param)) then
		param = {}
	end
	-- recursion depth from autoanswer: 0 (the player selected manually)
	return yl_speak_up.get_fs_talkdialog(player, param.n_id, param.d_id, param.alternate_text,0)
end
--]]

yl_speak_up.register_fs("talk",
	-- this function is changed here:
	yl_speak_up.input_talk,
	-- the underlying function is changed as well - but the wrapper calls that already; so ok:
	yl_speak_up.get_fs_talk_wrapper,
	-- no special formspec required:
	nil
)

