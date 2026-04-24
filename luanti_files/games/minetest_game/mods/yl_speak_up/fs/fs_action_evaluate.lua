-- action of the type "evaluate"
yl_speak_up.input_fs_action_evaluate = function(player, formname, fields)
	local pname = player:get_player_name()
	local a_id = yl_speak_up.speak_to[pname].a_id
	-- the custom input_handler may have something to say here as well
	local a = yl_speak_up.get_action_by_player(player)
	if(player and a and a.a_value) then
		local custom_data = yl_speak_up.custom_functions_a_[a.a_value]
		if(custom_data and custom_data.code_input_handler) then
			local n_id = yl_speak_up.speak_to[pname].n_id
			local fun = custom_data.code_input_handler
			-- actually call the function (which may change the value of fields)
			fields = fun(player, n_id, a, formname, fields)
		end
	end
	-- back from error_msg? then show the formspec again
	if(fields.back_from_error_msg) then
		yl_speak_up.show_fs(player, "action_evaluate", nil)
		return
	end
	if(fields.back_to_talk) then
		-- the action was aborted
		yl_speak_up.execute_next_action(player, a_id, nil, formame)
		return
	end
	if(fields.failed_action) then
		-- the action failed
		yl_speak_up.execute_next_action(player, a_id, false, formame)
		return
	end
	if(fields.finished_action) then
		-- the action was a success
		yl_speak_up.execute_next_action(player, a_id, true, formame)
		return
	end
	if(fields.quit) then
		return
	end
	-- else show a message to the player that he ought to decide
	yl_speak_up.show_fs(player, "msg", {
		input_to = "yl_speak_up:action_evaluate",
		formspec = "size[7,1.5]"..
			"label[0.2,-0.2;"..
				"Please click on one of the offered options\nor select \"Back to talk\"!]"..
				"button[2,1.0;1.5,0.9;back_from_error_msg;Back]"})
end


yl_speak_up.get_fs_action_evaluate = function(player, param)
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	local n_id = yl_speak_up.speak_to[pname].n_id
	local a = yl_speak_up.get_action_by_player(player)
	if(not(a)) then
		return ""
	end

	if(not(player) or not(a.a_value)) then
		return "label[0.2,0.5;Ups! An internal error occoured. Please tell your "..
				"local admin to check the brain of this lifeform here.]"..
			"button[1.5,1.5;2,0.9;back_to_talk;Back]"
	end
	local custom_data = yl_speak_up.custom_functions_a_[a.a_value]
	if(not(custom_data) or not(custom_data.code)) then
		return "label[0.2,0.5;Ups! An internal error occoured. Please tell your "..
				"local admin that the internal function "..
					minetest.formspec_escape(tostring(a.a_value))..
				"somehow got lost/broken.]"..
			"button[1.5,1.5;2,0.9;back_to_talk;Back]"
	end
	local fun = custom_data.code
	-- actually call the function
	return fun(player, n_id, a)
end


yl_speak_up.register_fs("action_evaluate",
	yl_speak_up.input_fs_action_evaluate,
	yl_speak_up.get_fs_action_evaluate,
	-- no special formspec version required:
	nil
)
