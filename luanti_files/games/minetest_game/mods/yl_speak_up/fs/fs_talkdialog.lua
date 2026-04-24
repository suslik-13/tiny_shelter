-- This is the main talkdialog the NPC shows when right-clicked.
-- Returns o (selected dialog option) if fields.just_return_selected_option
--  is set (useful for edit_mode).
yl_speak_up.input_talk = function(player, formname, fields)
	if formname ~= "yl_speak_up:talk" then
		return
	end

	local pname = player:get_player_name()

	-- error: not talking?
	if(not(yl_speak_up.speak_to[pname])) then
		return
	end
	local n_id = yl_speak_up.speak_to[pname].n_id
	local d_id = yl_speak_up.speak_to[pname].d_id
	local dialog = yl_speak_up.speak_to[pname].dialog

	-- the NPC needs to be configured first; route input to the configuration dialog
	if(not(dialog)
	  or not(dialog.n_npc)
	  or not(d_id)) then
		yl_speak_up.input_fs_initial_config(player, formname, fields)
		return
	end

	if(fields.show_log) then
		-- show a log
		yl_speak_up.show_fs(player, "show_log", {log_type = "full"})
		return
	end

	-- mobs_redo based NPC may follow their owner, stand or wander around
	local new_move_order = ""
	if(fields.order_stand) then
		new_move_order = "stand"
	elseif(fields.order_follow) then
		new_move_order = "follow"
	elseif(fields.order_wander) then
		new_move_order = "wander"
	end
	if(new_move_order ~= "") then
		local dialog = yl_speak_up.speak_to[pname].dialog
		yl_speak_up.set_npc_property(pname, "self.order", new_move_order, "move_order")
		minetest.chat_send_player(pname,
			tostring(dialog.n_npc or "NPC").." tells you: "..
				"Ok. I will "..tostring(new_move_order)..".")
		yl_speak_up.stop_talking(pname)
		return
	end

	-- useful for i.e. picking up the mob
	if(fields.order_custom) then
		local obj = yl_speak_up.speak_to[pname].obj
		-- some precautions - someone else might have eliminated the NPC in the meantime
		local luaentity = nil
		if(obj) then
			luaentity = obj:get_luaentity()
		end
		if(luaentity and luaentity.name and yl_speak_up.add_on_rightclick_entry[luaentity.name]) then
			local m = yl_speak_up.add_on_rightclick_entry[luaentity.name]
			local ret = m.execute_function(luaentity, player)
		end
		yl_speak_up.stop_talking(pname)
		return
	end

	-- normal mode + edit_mode (not exclusive to edit_mode):
	if fields.quit or fields.button_exit then
		-- if there are any changes done: ask first and don't quit yet
		yl_speak_up.show_fs(player, "quit", nil)
		return
	end

	-- allow the player to take the item back
	if(fields.show_player_offers_item and fields.show_player_offers_item ~= "") then
		yl_speak_up.show_fs(player, "player_offers_item", nil)
		return
	end

	-- the player wants to give something to the NPC
	-- (less complex outside edit mode)
	if(fields.player_offers_item) then
		-- normal mode: take the item the player wants to offer
		yl_speak_up.show_fs(player, "player_offers_item", nil)
		return
	end

	-- the player wants to access the inventory of the NPC
	if(fields.show_inventory and yl_speak_up.may_edit_npc(player, n_id)) then
		-- the inventory is just an inventory with a back button; come back to this dialog here
		yl_speak_up.show_fs(player, "inventory")
		return
	end

	-- the player wants to see the trade list
	if(fields.show_trade_list) then
		yl_speak_up.show_fs(player, "trade_list", nil)
		return
	end

	-- allow some basic editing (name, description, owner) even without editor mod installed:
	if(fields.button_edit_basics) then
		yl_speak_up.show_fs(player, "initial_config",
			{n_id = n_id, d_id = d_id, false})
		return
	end


	if fields.button_up then
		yl_speak_up.speak_to[pname].option_index =
			yl_speak_up.speak_to[pname].option_index + yl_speak_up.max_number_of_buttons
		yl_speak_up.show_fs(player, "talk", {n_id = yl_speak_up.speak_to[pname].n_id,
						     d_id = yl_speak_up.speak_to[pname].d_id})
		return
	elseif fields.button_down then --and yl_speak_up.speak_to[pname].option_index > yl_speak_up.max_number_of_buttons then
		yl_speak_up.speak_to[pname].option_index =
			yl_speak_up.speak_to[pname].option_index - yl_speak_up.max_number_of_buttons
		if yl_speak_up.speak_to[pname].option_index < 0 then
			yl_speak_up.speak_to[pname].option_index = 1
		end
		yl_speak_up.show_fs(player, "talk", {n_id = yl_speak_up.speak_to[pname].n_id,
						    d_id = yl_speak_up.speak_to[pname].d_id})
		return
	else
		yl_speak_up.speak_to[pname].option_index = 1
	end


	-- has an option/answer been selected?
	local o = ""
	for k, v in pairs(fields) do
		-- only split into 2 parts at max
		local s = string.split(k, "_", false, 2)

		if(s[1] == "button"
		  and s[2] ~= nil and s[2] ~= "" and s[2] ~= "exit" and s[2] ~= "back" and s[3] ~= nil
		  and s[2] ~= "up" and s[2] ~= "down") then
			o = s[2] .. "_" .. s[3]
		end
	end
	-- this is for edit mode - we need a diffrent reaction there, not executing actions
	if(fields.just_return_selected_option) then
		return o
	end
	-- nothing selected
	if(o == "") then
		return
	end

	-- Let's check if the button was among the "allowed buttons". Only those may be executed
	if(not(yl_speak_up.speak_to[pname].allowed) or not(yl_speak_up.speak_to[pname].allowed[o])) then
		return
	end

	-- we may soon need actions and o_results from the selected_option
	local selected_option = {}
	if(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o)) then
		selected_option = dialog.n_dialogs[d_id].d_options[o]
	end

	-- abort if the option does not exist
	if(not(selected_option)) then
		return
	end
	yl_speak_up.speak_to[pname].o_id = o
	-- store this a bit longer than o_id above (for yl_speak_up.generate_next_dynamic_dialog):
	yl_speak_up.speak_to[pname].selected_o_id = o
	-- start with executing the first action
	yl_speak_up.execute_next_action(player, nil, true, formname)
	return
end


-- helper function for yl_speak_up.get_fs_talkdialog:
--   shows the text the NPC "speaks"
--   (this is pretty boring; the more intresting stuff happens in edit_mode)
yl_speak_up.get_fs_talkdialog_main_text = function(pname, formspec, h, dialog, dialog_list, c_d_id, active_dialog, alternate_text)
	local fs_version = yl_speak_up.fs_version[pname]
	formspec = yl_speak_up.show_fs_npc_text(pname, formspec, dialog, alternate_text, active_dialog, fs_version)
	return {h = h, formspec = formspec, d_id_to_dropdown_index = {}, dialog_list = dialog_list}
end


-- helper function for yl_speak_up.get_fs_talkdialog:
--   prints one entry (option/answer) in normal mode - not in edit_mode
yl_speak_up.get_fs_talkdialog_line = function(
				formspec, h, pname_for_old_fs, oid, sb_v,
				dialog, allowed, pname,
				-- these additional parameters are needed in edit_mode and not used here
				active_dialog, dialog_list, d_id_to_dropdown_index,
				current_index, anz_options)

	local t = "- no text given -"
	local t_alt = nil
	-- the preconditions are fulfilled; showe the option
	if(allowed[sb_v.o_id] == true) then
		-- replace $NPC_NAME$ etc.
		t = minetest.formspec_escape(yl_speak_up.replace_vars_in_text(
			sb_v.o_text_when_prerequisites_met, dialog, pname))
	-- precondition not fulfilled? the option shall be hidden
	elseif(sb_v.o_hide_when_prerequisites_not_met == "true") then
		-- show nothing; t_alt remains nil
		t = nil
	-- precondition not fulfilled, and autoanswer active? Then hide this option.
	elseif(sb_v.o_autoanswer) then
		-- show nothing; t_alt remains nil
		t = nil
	-- precondition not fulfilled? the option shall be greyed out
	-- default to greyed out (this option cannot be selected)
	elseif(sb_v.o_grey_when_prerequisites_not_met == "true") then
		local text = sb_v.o_text_when_prerequisites_not_met
		if(not(text) or text == "") then
			text = t or yl_speak_up.message_button_option_prerequisites_not_met_default
		end
		t = nil
		-- replace $NPC_NAME$ etc.
		t_alt = minetest.formspec_escape(yl_speak_up.replace_vars_in_text(
			text, dialog, pname))
	elseif(sb_v.o_grey_when_prerequisites_not_met == "false"
	   and sb_v.o_text_when_prerequisites_not_met ~= "") then
		-- show in normal coor
		t = minetest.formspec_escape(yl_speak_up.replace_vars_in_text(
			sb_v.o_text_when_prerequisites_not_met, dialog, pname))
	end
	if(t or t_alt) then
		-- some options can be visited only once; talking to the NPC anew resets that
		-- (not stored persistently)
		if(t and sb_v.visits and sb_v.visits > 0
		    and sb_v.o_visit_only_once and sb_v.o_visit_only_once == 1) then
			t_alt = minetest.formspec_escape("[Done] ")..t
			t = nil
		end
		-- actually show the button
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"button_" .. oid,
			t,
			t,
			(t and not(t_alt)),
			t_alt,
			nil, pname_for_old_fs)
	end
	return {h = h, formspec = formspec}
end


-- at least allow editing name, description and owner - even without the editor mod installed
yl_speak_up.get_fs_talkdialog_add_basic_edit = function(
				pname, formspec, h, pname_for_old_fs, is_a_start_dialog,
				active_dialog, luaentity, may_edit_npc, anz_options)
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"button_edit_basics",
		"Edit name, description and owner of your NPC.\n"..
			"For more editing, install npc_talk_edit!",
		-- chat option: "[Edit name, description and owner.]"
		minetest.formspec_escape("[Edit name, description and owner.]"),
			true, nil, false, pname_for_old_fs) -- *not* an exit button
		return {h = h, formspec = formspec}
end


-- helper function for yl_speak_up.get_fs_talkdialog:
--   if the player can edit the NPC,
--   either add a button for entering edit mode
--   or add the buttons needed to edit the dialog when in *edit mode*
yl_speak_up.get_fs_talkdialog_add_edit_and_command_buttons = function(
				pname, formspec, h, pname_for_old_fs, is_a_start_dialog,
				active_dialog, luaentity, may_edit_npc, anz_options)
	-- outside edit mode: nothing to add here
	if(not(may_edit_npc)) then
		return {h = h, formspec = formspec}
	end

	if(is_a_start_dialog) then
		-- show the "show your inventory"-button even when not in edit mode
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"show_inventory",
			"Access and manage the inventory of the NPC. This is used for adding trade "..
				"items, getting collected payments and managing quest items.",
			"Show your inventory (only accessible to owner)!",
			true, nil, nil, pname_for_old_fs)
	end

	-- mobs_redo based NPC can follow, stand or wander around
	if(luaentity and luaentity.order and may_edit_npc
	  -- not all mobs need or support this feature
	  and table.indexof(yl_speak_up.emulate_orders_on_rightclick, luaentity.name) > -1) then
		if(luaentity.order ~= "follow") then
			h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
				"order_follow",
				"The NPC will follow you.",
				"New order: Follow me!",
				((luaentity.owner == pname) and (luaentity.order ~= "follow")),
				"New order: Follow me. (Only available for owner).",
				nil, pname_for_old_fs)
			end
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"order_stand",
			"The NPC will wait here.",
			"New order: Stand here.",
			(luaentity.order ~= "stand"), nil, nil, pname_for_old_fs)
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"order_wander",
			"The NPC will wander around randomly.",
			"New order: Wander around a bit on your own.",
			(luaentity.order ~= "walking"), nil, nil, pname_for_old_fs)
	end

	-- some mobs may need additional things in on_rightclick (i.e. beeing picked up)
	if(luaentity and may_edit_npc
	  and yl_speak_up.add_on_rightclick_entry[luaentity.name]) then
		local m = yl_speak_up.add_on_rightclick_entry[luaentity.name]
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"order_custom",
			minetest.formspec_escape(m.text_if_false),
			minetest.formspec_escape(m.text_if_true),
			(m.condition), nil, nil, pname_for_old_fs)
	end
	local res = yl_speak_up.get_fs_talkdialog_add_basic_edit(
				pname, formspec, h, pname_for_old_fs, is_a_start_dialog,
				active_dialog, luaentity, may_edit_npc, anz_options)
	h = res.h
	return {h = h, formspec = formspec}
end


-- apply autoanswer, random dialog switching and d_got_item if needed;
-- returns the new formspec if any automatic switching happened
-- (this will not be done if in edit_mode)
yl_speak_up.apply_autoanswer_and_random_and_d_got_item = function(player, pname, d_id, dialog, allowed, active_dialog, recursion_depth)
	-- autoanswer or o_random may force to select a particular dialog
	local go_to_next_dialog = nil
	-- abort here if needed - the autoanswer/autoselection did choose an option for us alread
	if(allowed and allowed["autoanswer"] and allowed["autoanswer"] ~= "") then
		go_to_next_dialog = allowed["autoanswer"]
	-- randomly select an answer
	elseif(allowed and active_dialog.o_random
	  and (recursion_depth < yl_speak_up.max_allowed_recursion_depth)) then
		local liste = {}
		-- only allowed options can be randomly selected from
		for o_id, v in pairs(allowed) do
			if(v) then
				table.insert(liste, o_id)
			end
		end
		-- randomly select one of the possible dialogs
		if(#liste > 0) then
			go_to_next_dialog = liste[math.random(1, #liste)]
		end
	end

	if(go_to_next_dialog and go_to_next_dialog ~= "") then
		-- no actions shall be executed
		local o_id = go_to_next_dialog
		local effects = active_dialog.d_options[o_id].o_results
		local d_option = active_dialog.d_options[o_id]
		-- execute all effects/results
		local res = yl_speak_up.execute_all_relevant_effects(player, effects, o_id, true, d_option)
		local target_dialog = res.next_dialog
		yl_speak_up.speak_to[pname].o_id = nil
		yl_speak_up.speak_to[pname].a_id = nil
		-- end the conversation?
		if(target_dialog and target_dialog == "d_end") then
			yl_speak_up.stop_talking(pname)
			-- a formspec is expected here; provide one that has an exit button only
			return "size[2,1]"..
				"button_exit[0,0;1,1;Exit;exit]"
		end
		if(not(target_dialog)
		  or target_dialog == ""
		  or not(dialog.n_dialogs[target_dialog])) then
			target_dialog = yl_speak_up.speak_to[pname].d_id
		end
		-- show the new target dialog and exit
		-- the recursion_depth will be increased by one (we did autoselect here and need to
		-- avoid infinite loops)
		return yl_speak_up.get_fs_talkdialog(player, n_id, target_dialog, res.alternate_text,
			recursion_depth + 1)
	end

	-- is the player comming back from trying to offer something to the NPC?
	-- And is the NPC trying to return the item?
	if(d_id == "d_got_item") then
		local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
		if(not(trade_inv:is_empty("npc_wants"))) then
			return table.concat({"formspec_version[1]",
				yl_speak_up.show_fs_simple_deco(8, 2.5),
				"label[0.5,0.5;",
				minetest.formspec_escape(dialog.n_npc or "- ? -"),
				" does not seem to be intrested in that.\n"..
				"Please take your item back and try something else.]"..
				"button[3.5,1.5;1.5,1.0;show_player_offers_item;Ok]"
				}, "")
		end
	end
	-- no automatic switching happened
	return nil
end


yl_speak_up.get_fs_talkdialog_add_player_offers_item = function(pname, formspec, h, dialog, add_text, pname_for_old_fs)
	return yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"player_offers_item",
			"If you want to give something (items) to this NPC\n"..
				"- either because he requested it or as a present -\n"..
				"click here. The NPC will return items he doesn't want.",
			(add_text or "").."I want to give you something.",
			-- show this in edit mode and when the NPC actually accepts items
			(add_text or dialog.n_dialogs["d_got_item"]), nil, nil, pname_for_old_fs)
end


-- recursion_depth is increased each time autoanswer is automaticly selected
yl_speak_up.get_fs_talkdialog = function(player, n_id, d_id, alternate_text, recursion_depth)
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	local context_d_id = yl_speak_up.speak_to[pname].d_id
	local active_dialog

	if(not(dialog)) then
		yl_speak_up.log_change(pname, n_id,
			"unconfigured NPC beeing talked to at "..
			minetest.pos_to_string(player:get_pos()), "action")
		return yl_speak_up.get_error_message()
	end

	-- currently no trade running (we're editing options)
	yl_speak_up.trade[pname] = nil
	yl_speak_up.speak_to[pname].trade_id = nil

	-- add a d_trade dialog if necessary
	if(dialog and dialog.trades and dialog.n_dialogs and not(dialog.n_dialogs["d_trade"])) then
		yl_speak_up.add_new_dialog(dialog, pname, "trade", "[no text]")
	end

	--[[ If we have an explicit call for a certain d_id, we grab it from parameters.
	If not, we grab in from context.
	When neither are present, we grab it from d_sort
	]]--

	local c_d_id
	-- the generic start dialog contains only those options that are generic;
	-- choose the right start dialog of the NPC
	if(d_id ~= nil and d_id ~= "d_generic_start_dialog") then
		active_dialog = dialog.n_dialogs[d_id]
		c_d_id = d_id
	elseif(d_id and d_id ~= "d_generic_start_dialog" and yl_speak_up.speak_to[pname].d_id ~= nil) then
		c_d_id = yl_speak_up.speak_to[pname].d_id
		active_dialog = dialog.n_dialogs[c_d_id]
	-- do this only if the dialog is already configured/created_at:
	elseif dialog.n_dialogs ~= nil and dialog.created_at then
		-- Find the dialog with d_sort = 0
		c_d_id = yl_speak_up.get_start_dialog_id(dialog)
		if(c_d_id) then
			active_dialog = dialog.n_dialogs[c_d_id]
		end
	else
	-- it may be possible that this player can initialize this npc
		yl_speak_up.log_change(pname, n_id,
			"unconfigured NPC beeing talked to at "..
			minetest.pos_to_string(player:get_pos()), "action")
		-- this is the initial config
		-- (input ends up at yl_speak_up.input_talk and needs to be rerouted)
		return yl_speak_up.get_fs_initial_config(player, n_id, d_id, true)
	end

	if c_d_id == nil then return yl_speak_up.get_error_message() end

	-- show the player a dynamic dialog text:
	if(c_d_id == "d_dynamic") then
		-- the dialog will be modified for this player only:
		-- (pass on all the known parameters in case they're relevant):
		yl_speak_up.generate_next_dynamic_dialog(player, n_id, d_id, alternate_text, recursion_depth)
		-- just to make sure that the right dialog is loaded:
		active_dialog = dialog.n_dialogs[c_d_id]
	end

	yl_speak_up.speak_to[pname].d_id = c_d_id

	-- Now we have a dialog to display to the user

	-- do not crash in case of error
	if(not(active_dialog)) then
		return "size[10,3]"..
			"label[0.2,0.5;Ups! Something went wrong. No dialog found.\n"..
				"Please talk to the NPC by right-clicking again.]"..
			"button_exit[4.5,1.6;1,0.9;exit;Exit]"
	end

	-- how often has the player visted this dialog?
	yl_speak_up.count_visits_to_dialog(pname)

	-- evaluate the preconditions of each option and check if the option can be offered
	local allowed = yl_speak_up.calculate_displayable_options(pname, active_dialog.d_options,
			-- avoid loops by limiting max recoursion depths for autoanswers
			(recursion_depth < yl_speak_up.max_allowed_recursion_depth))


	-- apply autoanswer, random dialog switching and d_got_item if needed
	local show_other_dialog_fs = yl_speak_up.apply_autoanswer_and_random_and_d_got_item(
					player, pname, d_id, dialog, allowed, active_dialog, recursion_depth)
	if(show_other_dialog_fs) then
		return show_other_dialog_fs
	end


	yl_speak_up.speak_to[pname].allowed = allowed


	local pname_for_old_fs = yl_speak_up.get_pname_for_old_fs(pname)
	local fs_version = yl_speak_up.fs_version[pname]
	local formspec = {}
	local h

	-- this is used to build a list of all available dialogs for a dropdown menu in edit mode
	-- (only relevant in edit mode)
	local dialog_list = yl_speak_up.text_new_dialog_id
	-- allow to change skin, wielded items etc.
	-- display the window with the text the NPC is saying (diffrent in *edit_mode*)
	local res_edit_top = yl_speak_up.get_fs_talkdialog_main_text(
				pname, formspec, h, dialog, dialog_list, c_d_id, active_dialog,
				alternate_text)
	-- we are finished with adding buttons and text etc. to the left side of the formspec
	local left_window_fs = table.concat(res_edit_top.formspec, "")
	dialog_list = res_edit_top.dialog_list
	-- find the right index for the dialog_list dropdown above
	local d_id_to_dropdown_index = res_edit_top.d_id_to_dropdown_index

	-- empty formspec for the bottom part
	formspec = {}

	h = -0.8

	-- allow to delete entries that have no options later on
	local anz_options = 0
	-- Let's sort the options by o_sort
	if active_dialog ~= nil and active_dialog.d_options ~= nil then
		local sorted_o_list = yl_speak_up.get_sorted_options(active_dialog.d_options, "o_sort")
		for _, sb_v in ipairs(sorted_o_list) do
			anz_options = anz_options + 1
		end

		for i, s_o_id in ipairs(sorted_o_list) do
			local sb_v = active_dialog.d_options[s_o_id]
			local oid = minetest.formspec_escape(sb_v.o_id)
			local res = {}
			-- normal mode: show an option if the prerequirements (if any are defined) are met
			res = yl_speak_up.get_fs_talkdialog_line(
					formspec, h, pname_for_old_fs, oid, sb_v,
					dialog, allowed, pname,
					-- these additional parameters are needed in edit_mode
					active_dialog, dialog_list, d_id_to_dropdown_index, i, #sorted_o_list)
			formspec = res.formspec
			h = res.h
		end
	end

	-- with automatic selection from the start dialog, it is possible that the
	-- real start dialog is never shown; thus, add those buttons which need to
	-- be shown just once to all dialogs with is_a_start_dialog set
	local is_a_start_dialog = (active_dialog and active_dialog.d_sort
				   and (tonumber(active_dialog.d_sort) == 0
				     or active_dialog.is_a_start_dialog))
	-- add a "I want to give you something" button to the first dialog if the NPC accepts items
	if(is_a_start_dialog) then
		h = yl_speak_up.get_fs_talkdialog_add_player_offers_item(pname, formspec, h,
							dialog, nil, pname_for_old_fs)
	end


	-- add a Let's trade button to the first dialog if the NPC has trades
	local has_trades = nil
	if(is_a_start_dialog and dialog.trades) then
		for k, v in pairs(dialog.trades) do
			-- has the NPC any *public* trades that are not effects/results?
			if(not(v.hide) and not(v.d_id)) then
				has_trades = true
				break
			end
		end
	end
	if(has_trades) then
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"show_trade_list",
			"Show a list of trades the NPC has to offer.",
			"Let's trade!",
			(has_trades), nil, nil, pname_for_old_fs)
	end


	-- can the player edit this NPC?
	local may_edit_npc = yl_speak_up.may_edit_npc(player, n_id)
	-- for muting and for checking the owner/order, the luaentity is needed
	local obj = yl_speak_up.speak_to[pname].obj
	-- some precautions - someone else might have eliminated the NPC in the meantime
	local luaentity = nil
	if(obj) then
		luaentity = obj:get_luaentity()
	end


	-- If in edit mode, add new menu entries: "add new options", "end edit mode" and what else is needed.
	-- Else allow to enter edit mode
	-- also covers commands for mobs_npc (walk, stand, follow), custom commands and inventory access
	local res = yl_speak_up.get_fs_talkdialog_add_edit_and_command_buttons(
				pname, formspec, h, pname_for_old_fs, is_a_start_dialog,
				active_dialog, luaentity, may_edit_npc, anz_options)
	formspec = res.formspec
	h = res.h


	-- we are finished with adding buttons to the bottom of the formspec
	local bottom_window_fs = table.concat(formspec, "\n")

	return yl_speak_up.show_fs_decorated(pname, true, h, alternate_text,
						left_window_fs, bottom_window_fs,
						active_dialog, h)
end


yl_speak_up.get_fs_talk_wrapper = function(player, param)
	if(not(param)) then
		param = {}
	end
	-- recursion depth from autoanswer: 0 (the player selected manually)
	return yl_speak_up.get_fs_talkdialog(player, param.n_id, param.d_id, param.alternate_text,0)
end

yl_speak_up.register_fs("talk",
	yl_speak_up.input_talk,
	yl_speak_up.get_fs_talk_wrapper,
	-- no special formspec required:
	nil
)
