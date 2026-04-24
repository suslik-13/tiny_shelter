
-- returns a table with helpful information *if* the player is working on a quest;
-- else error_msg is set
yl_speak_up.player_is_working_on_quest = function(player)
	if(not(player)) then
		return
	end
	local t = {}
	t.pname = player:get_player_name()
	if(not(t.pname)) then
		return {error_msg = "Player not found."}
	end
	if(not(yl_speak_up.speak_to or not(yl_speak_up.speak_to[t.pname]))) then
		return {error_msg = "Player not working on a quest."}
	end
	t.q_id = yl_speak_up.speak_to[t.pname].q_id
	if(not(t.q_id) or not(yl_speak_up.quests) or not(yl_speak_up.quests[t.q_id])) then
		return {error_msg = "No quest selected or quest not found."}
	end
	t.quest = yl_speak_up.quests[t.q_id]
	if(not(t.quest.step_data) or type(t.quest.step_data) ~= "table") then
		yl_speak_up.quests[t.q_id].step_data = {}
	end
	-- TODO: check if the player has access to that data
	t.step_data = yl_speak_up.quests[t.q_id].step_data
	t.current_step = yl_speak_up.speak_to[t.pname].quest_step
	-- check here if the step exists
	if(t.current_step and not(t.step_data[t.current_step])) then
		yl_speak_up.speak_to[t.pname].quest_step = nil
		t.current_step = nil
	end
	-- t contains pname, q_id, quest, step_data and current_step - or error_msg
	return t
end


-- show the error message created above
yl_speak_up.build_fs_quest_edit_error = function(error_msg, back_button_name)
	return "size[10,3]"..
		"label[0.2,0.5;Error:]"..
		"label[0.5,1.0;"..minetest.colorize("#FFFF00",
					minetest.formspec_escape(
						minetest.wrap_text(tostring(error_msg), 80)))..
		"]button[3.5,2.0;2,0.9;"..tostring(back_button_name)..";Back]"
end


-- for which other quest steps is this_step needed for?
yl_speak_up.quest_step_required_for = function(step_data, this_step)
	-- find out the next quest step
	local required_for = {}
	for s, d in pairs(step_data) do
		if(s and d and d.one_step_required and type(d.one_step_required) == "table"
		  and table.indexof(d.one_step_required, this_step) ~= -1) then
			table.insert(required_for, s)
		end
		if(s and d and d.all_steps_required and type(d.all_steps_required) == "table"
		  and table.indexof(d.all_steps_required, this_step) ~= -1) then
			table.insert(required_for, s)
		end
	end
	table.sort(required_for)
	return required_for
end


-- sorts quest steps into lists: start, middle, end, unconnected
yl_speak_up.quest_step_get_start_end_unconnected_lists = function(step_data)
	local start_steps = {}
	local end_steps = {}
	local unconnected_steps = {}
	-- construct tables of *candidates* for start/end steps first
	for s, d in pairs(step_data) do
		if(#d.one_step_required == 0 and #d.all_steps_required == 0) then
			start_steps[s] = true
		end
		end_steps[s] = true
	end
	for s, d in pairs(step_data) do
		-- anything that is required somewhere cannot be an end step
		for i, s2 in ipairs(d.one_step_required or {}) do
			end_steps[s2] = nil
		end
		for i, s2 in ipairs(d.all_steps_required or {}) do
			end_steps[s2] = nil
		end
	end
	local lists = {}
	lists.start_steps = {}
	lists.end_steps = {}
	lists.unconnected_steps = {}
	lists.middle_steps = {}
	for s, d in pairs(step_data) do
		-- if it's both a start and end step, then it's an unconnected step
		if(start_steps[s] and end_steps[s]) then
			table.insert(lists.unconnected_steps, s)
		elseif(start_steps[s]) then
			table.insert(lists.start_steps, s)
		elseif(end_steps[s]) then
			table.insert(lists.end_steps, s)
		else
			table.insert(lists.middle_steps, s)
		end
	end
	return lists
end


-- some lists are offered in diffrent formspecs for selection;
-- this function will display the right quest step if possible
-- res needs to be yl_speak_up.player_is_working_on_quest(player)
yl_speak_up.handle_input_routing_show_a_quest_step = function(player, formname, fields, back_field_name, res)
	if(not(player) or not(fields) or (fields and fields.back) or not(res)) then
		return false
	end

	if(res.error_msg) then
		yl_speak_up.show_fs(player, "msg", {
			input_to = formname,
			formspec = yl_speak_up.build_fs_quest_edit_error(error_msg, back_field_name)
		})
		return true
	end
	local step_data = res.step_data or {}

	-- which quest step to show next? (if any)
	local show_step = ""
	-- was a quest step selected from the start/end/unconnected lists?
	local list = {}
	local field_name = ""
	local row_offset = 0
	if(    fields.select_from_start_steps and fields.select_from_start_steps ~= "") then
		-- selected a start quest step
		list = yl_speak_up.quest_step_get_start_end_unconnected_lists(step_data).start_steps
		field_name = "select_from_start_steps"
	elseif(fields.select_from_end_steps and fields.select_from_end_steps ~= "") then
		-- selected an end quest step
		list = yl_speak_up.quest_step_get_start_end_unconnected_lists(step_data).end_steps
		field_name = "select_from_end_steps"
	elseif(fields.select_from_unconnected_steps and fields.select_from_unconnected_steps ~= "") then
		-- selected an unconnected/unused quest step
		list = yl_speak_up.quest_step_get_start_end_unconnected_lists(step_data).unconnected_steps
		field_name = "select_from_unconnected_steps"
	elseif(res.current_step and step_data[res.current_step] and fields.one_step_required) then
		list = step_data[res.current_step].one_step_required
		field_name = "one_step_required"
	elseif(res.current_step and step_data[res.current_step] and fields.all_steps_required) then
		list = step_data[res.current_step].all_steps_required
		field_name = "all_steps_required"
	elseif(res.current_step and step_data[res.current_step] and fields.next_steps_show) then
		list = yl_speak_up.quest_step_required_for(step_data, res.current_step)
		field_name = "next_steps_show"
	elseif(fields.add_from_available) then
		-- selected a quest step from the list of available steps offered
		list = yl_speak_up.speak_to[res.pname].available_quest_steps or {}
		field_name = "add_from_available"
		-- this table has a header
		row_offset = 1

	-- show prev logical step
	elseif(fields.show_prev_step and res.current_step and step_data[res.current_step]) then
		if(    #step_data[res.current_step].one_step_required > 0) then
			show_step = step_data[res.current_step].one_step_required[1]
		elseif(#step_data[res.current_step].all_steps_required > 0) then
			show_step = step_data[res.current_step].all_steps_required[1]
		end
	-- show next logical step
	elseif(fields.show_next_step) then
		local list = yl_speak_up.quest_step_required_for(res.step_data, res.current_step)
		if(list and #list > 0) then
			show_step = list[1]
		end
	end

	if(list and field_name) then
		local selected = minetest.explode_table_event(fields[field_name])
		-- if a table uses a header, row_offset will be 1; else 0
		if(selected and selected.row and selected.row > row_offset and selected.row <= #list + row_offset) then
			show_step = list[selected.row - row_offset]
		end
	end
	-- actually show the selected quest step
	if(show_step and show_step ~= "") then
		yl_speak_up.speak_to[res.pname].quest_step = show_step
		yl_speak_up.show_fs(player, "manage_quest_steps", show_step)
		return true
	-- show the entire list
	elseif(fields.show_step_list) then
		yl_speak_up.speak_to[res.pname].tmp_index_general = -1
		yl_speak_up.speak_to[res.pname].quest_step = nil
		yl_speak_up.show_fs(player, "manage_quest_steps", nil)
		return true
	end
	return false
end


-- describe a location where a quest step can be set; also used by yl_speak_up.fs_manage_quest_steps
yl_speak_up.quest_step_show_where_set = function(pname, formspec, label, n_id, d_id, o_id, box_color, nr)
	if(not(pname)) then
		return
	end
	-- what are we talking about?
	local dialog = nil
	if(yl_speak_up.speak_to[pname] and yl_speak_up.speak_to[pname].n_id == n_id) then
		dialog = yl_speak_up.speak_to[pname].dialog
	else
		dialog = yl_speak_up.load_dialog(n_id, false)
	end
	local name_txt   = "- ? -"
	local dialog_txt = "- ? -"
	local option_txt = "- ? -"
	if(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o_id)) then
		dialog_txt = dialog.n_dialogs[d_id].d_text or "- ? -"
		option_txt = dialog.n_dialogs[d_id].d_options[o_id].o_text_when_prerequisites_met or "- ? -"
		name_txt   = (dialog.n_npc or "- ? -")
		if(dialog.n_description and dialog.n_description ~= "") then
			name_txt = name_txt..", "..tostring(dialog.n_description)
		end
	end
	-- are we dealing with an NPC?
	local id_label = "the block at position "
	if(n_id and string.sub(n_id, 1, 2) == "n_") then
		id_label = "NPC "
	end

	if(box_color) then
		name_txt = name_txt.." ["..tostring(n_id).."]"
		table.insert(formspec, "label[0.2,0.2;")
		if(nr) then
			table.insert(formspec, tostring(nr)..". ")
		end
		table.insert(formspec, id_label)
		table.insert(formspec, minetest.colorize("#AAAAFF", minetest.formspec_escape(name_txt)))
		table.insert(formspec, " says in dialog ")
		table.insert(formspec, minetest.colorize("#AAAAFF", minetest.formspec_escape(d_id)..":]"))
		table.insert(formspec, "]")
		table.insert(formspec, "box[1.0,0.4;16,1.8;")
		table.insert(formspec, box_color)
		table.insert(formspec, "]")
		table.insert(formspec, "textarea[1.0,0.4;16,1.8;;;")
		table.insert(formspec, minetest.formspec_escape(dialog_txt))
		table.insert(formspec, "]")
		table.insert(formspec, "label[1.0,2.4;Answer ")
		table.insert(formspec, minetest.colorize("#AAAAFF", minetest.formspec_escape(o_id..": ")))
		table.insert(formspec, minetest.colorize("#AAAAFF", minetest.formspec_escape(option_txt)))
		table.insert(formspec, "]")
		return
	end
	table.insert(formspec, "label[0.2,0;")
	table.insert(formspec, label or "which will be set by ")
	table.insert(formspec, id_label)
	table.insert(formspec, minetest.colorize("#AAAAFF", minetest.formspec_escape(n_id)))
	table.insert(formspec, ":]")
	table.insert(formspec, "label[1.0,0.4;")
	table.insert(formspec, minetest.colorize("#AAAAFF", minetest.formspec_escape(name_txt)))
	table.insert(formspec, "]")
	table.insert(formspec, "label[0.2,0.9;when answering to dialog ")
	table.insert(formspec, minetest.colorize("#AAAAFF", minetest.formspec_escape(d_id)))
	table.insert(formspec, ":]")
	table.insert(formspec, "textarea[1.0,1.1;16,1.8;;;")
	table.insert(formspec, minetest.formspec_escape(dialog_txt))
	table.insert(formspec, "]")
	table.insert(formspec, "label[0.2,3.2;with the following answer/option ")
	table.insert(formspec, minetest.colorize("#AAAAFF", minetest.formspec_escape(o_id)))
	table.insert(formspec, ":]")
	table.insert(formspec, "label[1.0,3.6;")
	table.insert(formspec, minetest.colorize("#AAAAFF", minetest.formspec_escape(option_txt)))
	table.insert(formspec, "]")
end
