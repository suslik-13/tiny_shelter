
-- add example answers and dialogs; they may be irritating for experienced
-- users, but help new users a lot in figuring out how the system works
--
-- first, we create three example dialogs as such:
-- (the first one has already been created in the creation of the dialog;
-- yl_speak_up.fields_to_dialog stores d_id in yl_speak_up.speak_to[pname].d_id)
--
-- Important: Overwrite this function if you want something diffrent here
--            (i.e. texts in a language your players speak).
yl_speak_up.setup_initial_dialog = function(dialog, pname)
	local new_d_1 = "d_1"
	local new_d_2 = yl_speak_up.add_new_dialog(dialog, pname, "2",
				"I'm glad that you wish me to talk to you.\n\n"..
				"I hope we can talk more soon!")
	local new_d_3 = yl_speak_up.add_new_dialog(dialog, pname, "3",
				"Oh! Do you really think so?\n\n"..
				"To me, talking is important.")
	-- we are dealing with a new NPC, so there are no options yet
	-- options added to dialog f.d_id:
	local new_d_1_o_1 = yl_speak_up.add_new_option(dialog, pname, nil,
				"d_1", "I hope so as well!", new_d_2)
	local new_d_1_o_2 = yl_speak_up.add_new_option(dialog, pname, nil,
				"d_1", "No. Talking is overrated.", new_d_3)
	-- options added to dialog new_d_2:
	local new_d_2_o_1 = yl_speak_up.add_new_option(dialog, pname, nil,
				"d_2", "Glad that we agree.", new_d_1)
	-- options added to dialog new_d_3:
	local new_d_3_o_1 = yl_speak_up.add_new_option(dialog, pname, nil,
				"d_3", "No. I was just joking. I want to talk to you!", new_d_2)
	local new_d_3_o_2 = yl_speak_up.add_new_option(dialog, pname, nil,
				"d_3", "Yes. Why am I talking to you anyway?", "d_end")
end


-- supply the NPC with its first (initial) dialog;
-- pname will become the owner of the NPC;
-- example call:
-- 	yl_speak_up.initialize_npc_dialog_once(pname, nil, n_id, fields.n_npc, fields.n_description)
yl_speak_up.initialize_npc_dialog_once = function(pname, dialog, n_id, npc_name, npc_description)
	-- the NPC already has a dialog - do not overwrite it!
	if(dialog.created_at) then
		return dialog
	end
	if(yl_speak_up.count_dialogs(dialog) > 0) then
		-- add the created_at flag if the dialog is already set up
		-- (this affects only NPC created before this time)
		dialog.created_at = os.time()
		return dialog
	end

	-- give the NPC its first dialog
	local f = {}
	-- create a new dialog
	f.d_id = yl_speak_up.text_new_dialog_id
	-- ...with this text
	f.d_text = "$GOOD_DAY$ $PLAYER_NAME$,\n"..
		"I am $NPC_NAME$. I don't know much yet.\n"..
		"Hopefully $OWNER_NAME$ will teach me to talk soon."
	-- it is the first, initial dialog
	f.d_sort = "0"
	f.n_npc = npc_name -- old: fields.n_npc
	f.n_description = npc_description -- old: fields.n_description
	f.npc_owner = pname -- old: yl_speak_up.npc_owner[ n_id ] (make sure to call it with right pname!)
	-- create and save the first dialog for this npc
	local dialog = yl_speak_up.fields_to_dialog(pname, f)
	-- overwrite this function if you want something diffrent added:
	yl_speak_up.setup_initial_dialog(dialog, pname)
	dialog.created_at = os.time()
	-- save our new dialog
	yl_speak_up.save_dialog(n_id, dialog)
	dialog.n_may_edit = {}
	-- update the dialog for the player
	yl_speak_up.speak_to[pname].dialog = dialog
	yl_speak_up.speak_to[pname].d_id = yl_speak_up.get_start_dialog_id(dialog)
	-- now connect the dialogs via results
	yl_speak_up.log_change(pname, n_id,
		"Initial config saved. "..
		"NPC name: \""..tostring(dialog.n_npc)..
		"\" Description: \""..tostring(dialog.n_description).."\".")
	return dialog
end
