
-- when the player is editing the NPC and has changed it without having
-- saved the changes yet: ask what shall be done (save? discard? back?)
yl_speak_up.input_save_or_discard_changes = function(player, formname, fields)
	local pname = player:get_player_name()
	-- if the player is not even talking to this particular npc
	if(not(yl_speak_up.speak_to[pname])) then
		return
	end

	local target_dialog = yl_speak_up.speak_to[pname].target_dialog
	if(not(target_dialog)) then
		target_dialog = ""
	end

	local edit_mode = (yl_speak_up.edit_mode[pname] == yl_speak_up.speak_to[pname].n_id)
	local d_id = yl_speak_up.speak_to[pname].d_id
	local n_id = yl_speak_up.speak_to[pname].n_id
	local o_id = yl_speak_up.speak_to[pname].o_id

	-- the player decided to go back and continue editing the current dialog
	if(edit_mode and fields.back_to_dialog_changes) then
		-- do NOT clear the list of changes; just show the old dialog again
		yl_speak_up.show_fs(player, "show_last_fs", {})
		return

	-- save changes and continue on to the next dialog
	elseif(edit_mode and fields.save_dialog_changes) then
		-- actually save the dialog (the one the NPC currently has)
		yl_speak_up.save_dialog(n_id, yl_speak_up.speak_to[pname].dialog)
		-- log all the changes
		for i, c in ipairs(yl_speak_up.npc_was_changed[ n_id ]) do
			yl_speak_up.log_change(pname, n_id, c)
		end
		-- clear list of changes
		yl_speak_up.npc_was_changed[ n_id ] = {}
		-- save_dialog removed d_dynamic (because that is never to be saved!); we have
		-- to add d_dynamic back so that we can use it as a target dialog in further editing:
		yl_speak_up.speak_to[pname].dialog.n_dialogs["d_dynamic"] = {}
		yl_speak_up.speak_to[pname].dialog.n_dialogs["d_dynamic"].d_options = {}

	-- discard changes and continue on to the next dialog
	elseif(edit_mode and fields.discard_dialog_changes) then
		-- the current dialog and the one we want to show next may both be new dialogs;
		-- if we just reload the old state, they would both get lost
		local target_dialog_data = yl_speak_up.speak_to[pname].dialog.n_dialogs[ target_dialog ]
		-- actually restore the old state and discard the changes by loading the dialog anew
		yl_speak_up.speak_to[pname].dialog = yl_speak_up.load_dialog(n_id, false)
		-- clear list of changes
		yl_speak_up.npc_was_changed[ n_id ] = {}
		local dialog = yl_speak_up.speak_to[pname].dialog
		-- do we have to save again after restoring current and target dialog?
		local need_to_save = false
		-- if the current dialog was a new one, it will be gone now - restore it
		if(d_id and d_id ~= "" and not(dialog.n_dialogs[ d_id ])) then
			-- we can't just restore the current dialog - after all the player wanted
			-- to discard the changes; but we can recreate the current dialog so that it
			-- is in the "new dialog" state again
			local next_id = tonumber(string.sub( d_id, 3))
			yl_speak_up.add_new_dialog(dialog, pname, next_id)
			yl_speak_up.log_change(pname, n_id, "Saved new dialog "..tostring( d_id )..".")
			need_to_save = true
		end
		if(target_dialog and target_dialog ~= "" and not(dialog.n_dialogs[ target_dialog ])) then
			-- restore the new target dialog
			dialog.n_dialogs[ target_dialog ] = target_dialog_data
			yl_speak_up.log_change(pname, n_id, "Saved new dialog "..tostring( target_dialog )..".")
			need_to_save = true
		end
		if(need_to_save) then
			yl_speak_up.save_dialog(n_id, dialog)
		end
	end

	-- are there any changes which might be saved or discarded?
	if(edit_mode
	  and  yl_speak_up.npc_was_changed[ n_id ]
	  and #yl_speak_up.npc_was_changed[ n_id ] > 0) then

		yl_speak_up.show_fs(player, "save_or_discard_changes", {})
		return
	end

	yl_speak_up.show_fs(player, "proceed_after_save", {})
end


yl_speak_up.get_fs_save_or_discard_changes = function(player, param)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	-- TODO
	local target_name = "quit"
	local target_dialog = nil -- TODO
	if(target_dialog and target_dialog ~= "") then
		target_name = "go on to dialog "..minetest.formspec_escape(target_dialog)
		if(target_dialog == "edit_option_dialog") then
			target_name = "edit option \""..
					minetest.formspec_escape(tostring(o_id)).."\" of dialog \""..
					minetest.formspec_escape(tostring(d_id)).."\""
		end
	end

	yl_speak_up.speak_to[pname].target_dialog = target_dialog
	local d_id = yl_speak_up.speak_to[pname].d_id
	-- reverse the order of the changes in the log so that newest are topmost
	local text = ""
	for i,t in ipairs(yl_speak_up.npc_was_changed[ n_id ]) do
		text = minetest.formspec_escape(t).."\n"..text
	end
	-- build a formspec showing the changes to this dialog and ask for save
	return table.concat({"size[14,6.2]",
		"bgcolor[#00000000;false]",
		-- TODO: make this more flexible
		"label[0.2,0.2;You are about to leave dialog ",
			minetest.formspec_escape(d_id),
			" and ",
			target_name,
			".]",
		"label[0.2,0.65;These changes have been applied to dialog ",
			minetest.formspec_escape(d_id),
			":]",
		"hypertext[0.2,1;13.5,4;list_of_changes;<normal>",
			minetest.formspec_escape(text),
			"\n</normal>",
			"]",
		"button_exit[1.2,5.2;3,0.9;discard_dialog_changes;Discard changes]",
		"button[5.7,5.2;3,0.9;back_to_dialog_changes;Back]",
		"button_exit[10.2,5.2;3,0.9;save_dialog_changes;Save changes]",
		"tooltip[save_dialog_changes;Save all changes to this dialog and ",
			target_name,
			".]",
		"tooltip[discard_dialog_changes;Undo all changes and ",
			target_name,
			".]",
		"tooltip[back_to_dialog_changes;Go back to dialog ",
			minetest.formspec_escape(d_id),
			" and continue editing it.]"
		}, "")
end


yl_speak_up.register_fs("save_or_discard_changes",
	yl_speak_up.input_save_or_discard_changes,
	yl_speak_up.get_fs_save_or_discard_changes,
	-- no special formspec required:
	nil
)
