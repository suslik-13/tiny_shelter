

-- allow to enter force edit mode (useful when an NPC was broken)
yl_speak_up.force_edit_mode = {}
-- command to enter force edit mode
yl_speak_up.command_npc_talk_force_edit = function(pname, param)
	if(not(pname)) then
		return
	end
	if(yl_speak_up.force_edit_mode[pname]) then
		yl_speak_up.force_edit_mode[pname] = nil
		minetest.chat_send_player(pname,
			"Ending force edit mode for NPC. From now on talks "..
			"will no longer start in edit mode.")
	else
		yl_speak_up.force_edit_mode[pname] = true
		minetest.chat_send_player(pname,
			"STARTING force edit mode for NPC. From now on talks "..
			"with NPC will always start in edit mode provided "..
			"you are allowed to edit this NPC.\n"..
			"In order to end force edit mode, give the command "..
			"/npc_talk_force_edit a second time.")
	end
end
