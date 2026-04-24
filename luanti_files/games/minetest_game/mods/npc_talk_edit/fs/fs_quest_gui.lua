yl_speak_up.input_quest_gui = function(player, formname, fields)
	-- this return value is necessary for custom actions
	local ret = {quit = true}

	local pname = player:get_player_name()
	if(fields and fields.back_from_msg) then
		yl_speak_up.show_fs(player, "quest_gui")
		return ret
	end

	-- new variables have to be added (and deleted) somewhere after all
	if(fields.manage_variables) then
		-- remember which formspec we are comming from
		yl_speak_up.speak_to[pname][ "working_at" ] = "quest_gui"
		yl_speak_up.show_fs(player, "manage_variables")
		return ret
	elseif(fields.manage_quests) then
		yl_speak_up.speak_to[pname][ "working_at" ] = "quest_gui"
		yl_speak_up.show_fs(player, "manage_quests")
		return ret
	end
	-- the calling NPC shall no longer do anything
	return ret
end


yl_speak_up.get_fs_quest_gui = function(player, param)
	local pname = player:get_player_name()
	return "size[24,20]"..
		"label[0,0.5;Hi. This is a quest admin gui.]"..
		"button[0.2,1.0;4.0,0.6;manage_variables;Manage variables]"..
		"button[6.2,1.0;4.0,0.6;manage_quests;Manage quests]"
end


yl_speak_up.register_fs("quest_gui",
	yl_speak_up.input_quest_gui,
	yl_speak_up.get_fs_quest_gui,
	-- no special formspec required:
	nil
)
