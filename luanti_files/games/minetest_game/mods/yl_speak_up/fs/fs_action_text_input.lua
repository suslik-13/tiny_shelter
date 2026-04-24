yl_speak_up.input_fs_action_text_input = function(player, formname, fields)
	-- back from error_msg? then show the formspec again
	if(fields.back_from_error_msg) then
		-- the error message is only shown if the input was empty
		yl_speak_up.show_fs(player, "action_text_input", "")
		return
	end
	local pname = player:get_player_name()
	-- the player is no longer talking to the NPC
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return
	end
	local a_id = yl_speak_up.speak_to[pname].a_id
	local a = yl_speak_up.get_action_by_player(player)
	if(fields.back_to_talk) then
		-- the action was aborted
		yl_speak_up.execute_next_action(player, a_id, nil, formname)
		return
	end
	if(fields.finished_action and fields.quest_answer and fields.quest_answer ~= "") then
		local n_id = yl_speak_up.speak_to[pname].n_id
		-- is the answer correct?
		-- strip leading and tailing blanks
		local success = not(not(fields.quest_answer and a.a_value
			and fields.quest_answer:trim() == a.a_value:trim()))
		if(not(success)) then
			yl_speak_up.log_change(pname, n_id,
				"Action "..tostring(a_id)..
				" "..tostring(yl_speak_up.speak_to[pname].o_id)..
				" "..tostring(yl_speak_up.speak_to[pname].d_id)..
				": Player answered with \""..tostring(fields.quest_answer:trim())..
				"\", but we expected: \""..tostring(a.a_value:trim()).."\".")
		else
			yl_speak_up.log_change(pname, n_id,
				"Action "..tostring(a_id)..
				" "..tostring(yl_speak_up.speak_to[pname].o_id)..
				" "..tostring(yl_speak_up.speak_to[pname].d_id)..
				": Answer is correct.")
		end
		-- store what the player entered so that it can be examined by other functions
		yl_speak_up.last_text_input[pname] = fields.quest_answer:trim()
		-- the action was a either a success or failure
		yl_speak_up.execute_next_action(player, a_id, success, formname)
		return
	end
	-- no scrolling desired
	fields.button_up = nil
	fields.button_down = nil
--[[ this is too disruptive; it's better to just let the player select a button
	-- else show a message to the player
	yl_speak_up.show_fs(player, "msg", {
		input_to = "yl_speak_up:action_text_input",
		formspec = "size[7,1.5]"..
			"label[0.2,-0.2;"..
				"Please answer the question and click on \"Send answer\"!\n"..
				"If you don't know the answer, click on \"Back to talk\".]"..
				"button[2,1.0;1.5,0.9;back_from_error_msg;Back]"})
--]]
end


yl_speak_up.get_fs_action_text_input = function(player, param)
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	local a = yl_speak_up.get_action_by_player(player)
	if(not(a)) then
		return ""
	end

	local alternate_text =
		(a.a_question or "Your answer:").."\n\n"..
		(dialog.n_npc or "- ? -").." looks expectantly at you.]"
	local formspec = {}
	table.insert(formspec, "label[0.7,1.8;Answer:]")
	table.insert(formspec, "button[45,1.0;9,1.8;finished_action;Send this answer]")
	-- show the actual text for the option
	yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
		"field", "4.0,1.0;40,1.5",
		"quest_answer",
		";", --..minetest.formspec_escape("<your answer>"),
		"Enter your answer here.",
		true)

	local h = 2.0
	local pname_for_old_fs = nil
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"finished_action",
			"Please enter your answer in the input field above and click here to "..
				"send it.",
			minetest.formspec_escape("[Send this answer]"),
			true, nil, nil, pname_for_old_fs)
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"back_to_talk",
			"If you don't know the answer or don't want to answer right now, "..
				"choose this option to get back to the previous dialog.",
			"I give up. Let's talk about something diffrent.",
			true, nil, nil, pname_for_old_fs)

	-- do not offer edit_mode in the trade formspec because it makes no sense there;
	return yl_speak_up.show_fs_decorated(pname, nil, h, alternate_text, "",
		table.concat(formspec, "\n"), nil, h)

--[[ old version with extra formspec
	return --"size[12.0,4.5]"..
		yl_speak_up.show_fs_simple_deco(12.0, 4.5)..
		"button[0.2,0.0;2.0,0.9;back_to_talk;Back to talk]"..
		"button[2.0,3.7;3.0,0.9;finished_action;Send answer]"..

		"tooltip[back_to_talk;Click here if you don't know the answer.]"..
		"tooltip[finished_action;Click here once you've entered the answer.]"..
		"label[0.2,1.2;"..minetest.formspec_escape(a.a_question or "Your answer:").."]"..
		"label[0.2,1.9;Answer:]"..
		"field[1.6,2.2;10.0,0.6;quest_answer;;"..tostring(param or "").."]"..
		"label[0.2,2.8;"..minetest.formspec_escape(
			"["..(dialog.n_npc or "- ? -").." looks expectantly at you.]").."]"
--]]
end


yl_speak_up.register_fs("action_text_input",
	yl_speak_up.input_fs_action_text_input,
	yl_speak_up.get_fs_action_text_input,
	-- no special formspec version required:
	nil
)
