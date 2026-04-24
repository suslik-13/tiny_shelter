
-- Implementation of chat commands that were registered in register_once
-- (here: only add those additional things needed for edit mode)

local old_command_npc_talk = yl_speak_up.command_npc_talk
yl_speak_up.command_npc_talk = function(pname, param)
	if(not(pname)) then
		return
	end
	-- activates edit mode when talking to an NPC; but only if the player can edit that NPC
	if(param and param == "force_edit") then
		-- implemented in functions.lua:
		return yl_speak_up.command_npc_talk_force_edit(pname, rest)
	end
	-- not perfect - but at least some help
	if(param
	  and (param == "help force_edit"
	    or param == "? force_edit"
	    or param == "force_edit help")) then
		minetest.chat_send_player(pname,
			"Toggles force edit mode. This is helpful if you cut yourself out "..
			"of editing an NPC by breaking it. From now on all NPC you will talk to "..
			"will already be in edit mode (provided you are allowed to edit them)."..
			"\nIssuing the command again ends force edit mode.")
		return
	end
	return old_command_npc_talk(pname, param)
end
