

yl_speak_up.input_notes = function(player, formname, fields)
	if(fields and fields.back) then
		return yl_speak_up.show_fs(player, "talk")
	elseif(fields and fields.store_notes and fields.notes_text) then
		local pname = player:get_player_name()
		local dialog = yl_speak_up.speak_to[pname].dialog
		local n_id   = yl_speak_up.speak_to[pname].n_id
		-- update the dialog data the player sees
		dialog.d_notes = fields.notes_text
		-- actually store/update it on disc as well
		local stored_dialog = yl_speak_up.load_dialog(n_id, false)
		stored_dialog.d_notes = dialog.d_notes
		yl_speak_up.save_dialog(n_id, stored_dialog)
		-- log the change
		yl_speak_up.log_change(pname, n_id, "Updated notes to: "..tostring(dialog.d_notes))
		return yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:notes",
				formspec = "size[10,3]"..
					"label[0.5,1.0;Notes successfully updated.]"..
					"button[3.5,2.0;2,0.9;back_from_error_msg;Back]"
				})
	else
		return yl_speak_up.show_fs(player, "notes")
	end
end


yl_speak_up.get_fs_notes = function(player, param)
	local pname = player:get_player_name()
	local n_id   = yl_speak_up.speak_to[pname].n_id
	-- generic dialogs are not part of the NPC
	local dialog = yl_speak_up.speak_to[pname].dialog
	return table.concat({"size[20,20]",
		"label[2,0.5;Internal notes on NPC ",
		minetest.formspec_escape(n_id or "- ? -"),
		", named ",
		minetest.formspec_escape(dialog.n_npc) or "- ? -",
		"]",
		"button[17.8,0.2;2.0,0.9;back;Back]",
		"button[15.0,0.2;2.0,0.9;store_notes;Save]",
		"textarea[0.2,2;19.6,13;notes_text;Notes (shown only to those who can edit this NPC):;",
			minetest.formspec_escape(dialog.d_notes or "Enter text here."),
			"]",
		"textarea[0.2,15.2;19.6,4.8;;;",
			"This can be used to make your NPC more intresting by storing information about..\n"..
			"* its character\n"..
			"* special characteristics of the NPC\n"..
			"* linguistic peculiarities and habits\n"..
			"* origin, relationships, lots of lore\n"..
			"* friendships / enmities\n"..
			"* personal goals / motivations / background\n"..
			"* planned quests\n"..
			"* trades\n"..
			"and whatever else you want to keep notes on for this NPC.]"
	})
end


yl_speak_up.register_fs("notes",
	yl_speak_up.input_notes,
	yl_speak_up.get_fs_notes,
	-- no special formspec required:
	nil
)
