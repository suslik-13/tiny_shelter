
-- Imposing an order on the quest steps is...tricky as best as what will
-- be more important to the players will be the order in which the
-- quest steps have to be solved/done - and not an alphabetical order.
-- But we need an order here for a dropdown menu to select each
-- quest step even if it hasn't been assigned any place in the chain
-- of quest steps yet. So - alphabetical order.
yl_speak_up.get_sorted_quest_step_list = function(pname, q_id)
	local quest_step_list = {}
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return {}
	end
	local q_id = yl_speak_up.speak_to[pname].q_id

	if(q_id and yl_speak_up.quests[q_id] and yl_speak_up.quests[q_id].step_data) then
		for step_id, v in pairs(yl_speak_up.quests[q_id].step_data) do
			table.insert(quest_step_list, step_id)
		end
	end
        table.sort(quest_step_list)
        return quest_step_list
end             


-- helper functions for yl_speak_up.input_fs_manage_quest_steps(..)
-- returns the index of the new quest step
yl_speak_up.input_fs_manage_quest_steps_add_new_entry = function(pname, entry_name)
	local q_id = yl_speak_up.speak_to[pname].q_id
	local res = yl_speak_up.quest_step_add_quest_step(pname, q_id, entry_name)
	-- might make sense to show the error message somewhere
	if(res ~= "OK") then
		return res
	end
	-- the new entry will be somewhere in it
	local quest_step_list = yl_speak_up.get_sorted_quest_step_list(pname)
	return table.indexof(quest_step_list, entry_name)
end


-- helper functions for yl_speak_up.input_fs_manage_quest_steps(..)
-- returns a text describing if deleting the quest worked
yl_speak_up.input_fs_manage_quest_steps_del_old_entry = function(pname, entry_name)
	local q_id = yl_speak_up.speak_to[pname].q_id
	return yl_speak_up.quest_step_del_quest_step(pname, q_id, entry_name)
end


-- helper functions for yl_speak_up.input_fs_manage_quest_steps(..)
-- implements all the functions that are specific to managing quest steps and not part of
-- general item management
yl_speak_up.input_fs_manage_quest_steps_check_fields = function(player, formname, fields, quest_step_name, list_of_entries)
	local pname = player:get_player_name()
	if(not(quest_step_name)) then
		quest_step_name = ""
	end
--[[ TODO: implement some back button functionality?
	if(fields and fields.show_variable) then
		yl_speak_up.show_fs(player, "manage_variables", {var_name = quest_name})
		return
	end
--]]
	-- this function didn't have anything to do
	return "NOTHING FOUND"
end



-- makes use of yl_speak_up.handle_input_fs_manage_general and is thus pretty short
yl_speak_up.input_fs_manage_quest_steps = function(player, formname, fields)
	local pname = player:get_player_name()

	-- route diffrently when the task was adding a quest step
	if(fields and fields.back
	  and pname
	  and yl_speak_up.speak_to[pname].d_id
	  and yl_speak_up.speak_to[pname].o_id) then
		return yl_speak_up.show_fs(player, "edit_option_dialog", {
						d_id = yl_speak_up.speak_to[pname].d_id,
						o_id = yl_speak_up.speak_to[pname].o_id,
					})
	end
	if(not(fields) or fields.manage_quests or fields.back) then
		return yl_speak_up.show_fs(player, "manage_quests")
	end
	local res = yl_speak_up.player_is_working_on_quest(player)

	-- show a particular quest step?
	if(yl_speak_up.handle_input_routing_show_a_quest_step(player, formname, fields, "back_from_error_msg", res)) then
		return
	end

	if(res.current_step) then
		-- forward input from that formspec...
		if((yl_speak_up.speak_to[res.pname].quest_step_mode == "embedded_select")
		  and (fields.add_from_available
		       or (fields.add_step and fields.add_quest_step))) then
			return yl_speak_up.input_fs_add_quest_steps(player, "yl_speak_up:add_quest_steps", fields)
		end
	end

	local modes = {"add_to_one_needed", "add_to_all_needed",
			"insert_after_prev_step", "insert_before_next_step"}
	for i, mode in ipairs(modes) do
		if(fields[mode] and fields[mode] ~= "") then
			-- let that function sort out what to do;
			-- yl_speak_up.speak_to[pname].q_id and yl_speak_up.speak_to[pname].quest_step
			-- ought to be set to the current quest and step by now
			yl_speak_up.speak_to[pname].quest_step_mode = mode
			yl_speak_up.show_fs(player, "add_quest_steps")
			return
		end
	end

	local quest_step_list = yl_speak_up.get_sorted_quest_step_list(pname)
	local res = yl_speak_up.handle_input_fs_manage_general(player, formname, fields,
		-- what_is_the_list_about, min_length, max_length, function_add_new_entry,
		"quest step", 2, 70,
		yl_speak_up.input_fs_manage_quest_steps_add_new_entry,
		quest_step_list,
		yl_speak_up.input_fs_manage_quest_steps_del_old_entry,
                yl_speak_up.input_fs_manage_quest_steps_check_fields)
	return true
end


yl_speak_up.get_fs_manage_quest_steps = function(player, param)
	-- small helper function
	local em = function(text)
			return minetest.colorize("#9999FF", text)
		   end

	local res = yl_speak_up.player_is_working_on_quest(player)
	if(res.error_msg) then
		return yl_speak_up.build_fs_quest_edit_error(res.error_msg, "back")
	end
	local step_data = res.step_data
	local quest_step_list = yl_speak_up.get_sorted_quest_step_list(res.pname)
	if(param and param ~= "") then
		local index = table.indexof(quest_step_list, param)
		yl_speak_up.speak_to[res.pname].tmp_index_general = index + 1
	end
	local idx = yl_speak_up.speak_to[res.pname].tmp_index_general
	if(idx and idx > 1) then
		yl_speak_up.speak_to[res.pname].quest_step = quest_step_list[idx - 1]
	end

	local formspec = {}
	table.insert(formspec,	"size[30,12]"..
				"container[6,0;18.5,12]"..
				"label[0.2,1.2;A quest step is a single thing a player may do in a quest - "..
						"like talking to an NPC.\n"..
					"Usually not all quest steps can be done/solved at all times.]")
	local selected = yl_speak_up.build_fs_manage_general(player, param,
				formspec, quest_step_list,
				"Create quest step",
					"Create a new quest step for this quest.",
				"quest step",
				"Enter the name of the new quest step you want to create.\n"..
					"This is an internal text shown only to yourself.\n"..
					"Players cannot see the names of quest steps.",
				"If you click here, the selected quest step will be deleted.\n"..
					"This will only be possible if it's not used anywhere.",
				"1.0")
	table.insert(formspec, "container_end[]")

	if(not(selected) or selected == "" or not(step_data) or not(step_data[selected])) then
		formspec = {} -- we start a new one
		-- insert a nicely formated list of quest steps
		yl_speak_up.speak_to[res.pname].quest_step_mode = "embedded_select"
		table.insert(formspec, yl_speak_up.get_fs_add_quest_steps(player, nil))
		table.insert(formspec, "container_end[]")
		local lists = yl_speak_up.quest_step_get_start_end_unconnected_lists(step_data)
		yl_speak_up.get_sub_fs_show_list_in_box(formspec,
			"Start steps:", "select_from_start_steps", lists.start_steps,
			"0.1", "2.7", "5.6", "4.3", 0, nil, "#AAFFAA",
			"The quest begins with this (or one of these) steps.\n"..
				"You need at least one start step.",
			nil)
		yl_speak_up.get_sub_fs_show_list_in_box(formspec,
			"Unconnected steps:", "select_from_unconnected_steps", lists.unconnected_steps,
			"0.1", "7.0", "5.6", "4.3", 0, nil, "#FFAAAA",
			"These steps are not used yet. They are not required\n"..
				"by any other step and do not require steps either.\n"..
				"Please decide what to do with them!",
			nil)
		yl_speak_up.get_sub_fs_show_list_in_box(formspec,
			"Quest ends with steps:", "select_from_end_steps", lists.end_steps,
			"24", "2.7", "5.6", "8.5", "0.1", nil, "#AAFFAA",
			"This quest ends with these steps. They are not required\n"..
				"by any other steps and have no successor.\n"..
				"Your quest needs at least one end step.",
			nil)
		return table.concat(formspec, "")
	end
	-- find out the next quest step
	local required_for = yl_speak_up.quest_step_required_for(step_data, selected)

	-- middle (this quest step)
	table.insert(formspec, "container[6,2.7;12,10.8]"..
				"label[0.2,0.5;This quest step is named:]"..
				"box[0.7,0.7;17,0.7;#000000]"..
				"label[0.8,1.1;")
	table.insert(formspec, minetest.colorize("#AAFFAA", minetest.formspec_escape(selected)))
	table.insert(formspec, "]")
	table.insert(formspec, "container_end[]")
	-- show the locations where this quest step is set
	local c = 0
	for where_id, d in pairs(step_data[selected].where or {}) do
		c = c + 1
	end
	if(c > 1) then
		table.insert(formspec, "label[6.2,4.5;This quest step can be set in diffrent ways (")
		table.insert(formspec, tostring(c))
		table.insert(formspec, " ways) by:]")
		table.insert(formspec, "scrollbaroptions[max=")
		table.insert(formspec, tostring((c-1.5) * 30)) -- 10 units for default 0.1 scroll factor
		table.insert(formspec, ";thumbsize=15")
		table.insert(formspec, "]")
		table.insert(formspec, "scrollbar[23.2,4.7;0.3,5;vertical;scrollbar_where;0.1]")
	elseif(c == 1) then
		table.insert(formspec, "label[6.2,4.5;This quest step can be set by:]")
	else
		table.insert(formspec, "label[6.2,4.5;This quest step cannot be set yet.]")
	end
	table.insert(formspec, "scroll_container[6.2,4.7;17,5;scrollbar_where;vertical;]")
	c = 0
	for where_id, d in pairs(step_data[selected].where or {}) do
		table.insert(formspec, "container[0,")
		table.insert(formspec, tostring(0.2 + c * 3.0))
		table.insert(formspec, ";17,4]")
		table.insert(formspec, "box[0,0;17,2.7;")
		if(c%2 == 0) then
			table.insert(formspec, "#000000]")
		else
			table.insert(formspec, "#222222]")
		end
		-- describe where in the dialog of the NPC or location this quest step shall be set
		local s = "This quest step can be set by "
		if(c > 0) then
			s = "..alternatively, this quest step can be set by "
		end
		yl_speak_up.quest_step_show_where_set(res.pname, formspec, s, d.n_id, d.d_id, d.o_id,
				"#444488", c + 1) --"#513F23", c + 1) --"#a37e45", c + 1)
		table.insert(formspec, "container_end[]")
		c = c + 1
	end
	table.insert(formspec, "scroll_container_end[]")

	-- left side (previous quest step)
	table.insert(formspec,	"container[0,0;5.8,13.5]"..
			"label[0.2,2.0;"..em("Required previous").."]"..
			"label[0.2,2.4;quest step(s):]"..
			"style[insert_before_next_step,insert_after_prev_step,"..
				"add_to_one_needed,add_to_all_needed;bgcolor=blue;textcolor=yellow]"..
			"button[0.1,0.1;5.6,0.8;show_step_list;Show all quest steps]")
	yl_speak_up.get_sub_fs_show_list_in_box(formspec,
		em("One of").." these quest steps:", "one_step_required",
		step_data[selected].one_step_required,
		"0.1", "2.7", "5.6", "4.3", 0, nil, "#AAFFAA",
		"At least "..em("one of").." these previous quest steps listed here has to be\n"..
			"achieved by the player who is trying to solve this quest.\n"..
			"Only then can the player try to achieve this current quest\n"..
			"step that you are editing here.\n"..
			"If this is empty, then it's usually the/a first step of the quest.\n"..
			"If there is one entry, then that entry is the previous quest step.\n"..
			"If there are multiple entries, then players have alternate ways\n"..
			"to achieve this current quest step here.",
		"button[4.6,0.0;0.94,0.7;add_to_one_needed;Edit]"..
			"tooltip[add_to_one_needed;Add or remove a quest step to this list.]")
	yl_speak_up.get_sub_fs_show_list_in_box(formspec,
		em("All of").." these quest steps:", "all_steps_required",
		step_data[selected].all_steps_required,
		"0.1", "7.0", "5.6", "4.3", 0, nil, "#AAFFAA",
		"Sometimes there may not be a particular order in which\n"..
			"quest steps ought to be solved. Imagine for example getting\n"..
			"indigrents for a cake and delivering them to an NPC.\n"..
			"The quest steps listed here can be done in "..em("any order")..".\n"..
			"They have "..em("all").." to be achieved first in order for this current\n"..
			"quest step to become available.\n"..
			"Usually this list is empty.",
		"button[4.6,0.0;0.94,0.7;add_to_all_needed;Edit]"..
			"tooltip[add_to_all_needed;Add or remove a quest step to this list.]")
	if(  #step_data[selected].one_step_required  > 0
	  or #step_data[selected].all_steps_required > 0) then
		if( #step_data[selected].one_step_required
		  + #step_data[selected].all_steps_required > 1) then
			table.insert(formspec, "style[show_prev_step;bgcolor=red]")
		end
		table.insert(formspec, "button[5.6,1.7;0.6,7.0;show_prev_step;<]"..
				"tooltip[show_prev_step;Show the previous step according to "..
					em("your quest logic")..".\n"..
					"The button turns "..minetest.colorize("#FF0000", "red")..
						" if there is more than one option. In such\na case "..
						"the alphabeticly first previous quest step is choosen.\n"..
					"The other "..em("< Prev").." button shows the previous step "..
					"in\n"..em("alphabetical order")..".]")
	end
	-- add buttons for inserting steps between this and the prev/next one
	if(#step_data[selected].one_step_required <= 1) then
		table.insert(formspec,
				"button[5.6,8.7;0.6,2.6;insert_after_prev_step;+]"..
				"tooltip[insert_after_prev_step;"..
					"Insert a new quest step between the "..em("previous step")..
					" (shown\n"..
					"to the left) and the "..em("current step")..
					" (shown in the middle).\n"..
					"Note: This only makes sense if there's just one or no\n"..
					"      previous step.]")
	end
	table.insert(formspec, "container_end[]")


	-- right side (next quest step)
	table.insert(formspec,	"container[23.8,0;5.8,13.5]"..
				"label[0.6,2.0;Achieving this quest step]"..
				"label[0.6,2.4;"..em("helps").." the quester to:]"..
				"button[0.4,0.1;5.6,0.8;manage_quests;Manage quests]")
	yl_speak_up.get_sub_fs_show_list_in_box(formspec,
		"get these quest step(s) "..em("next")..":", "next_steps_show",
		required_for,
		-- the label needs to be moved slightly to the right to make room for the > button
		"0.4", "2.7", "5.6", "8.5", "0.1", nil, "#AAFFAA",
		"Once the current quest step has been achieved by the\n"..
			"player, the player can strive to achieve these next\n"..
			"quest step(s).\n"..
			"If this is empty, then it's either the/a last step (quest\n"..
			"solved!) - or the quest is not properly set up.",
		nil)

	if(required_for and #required_for > 0) then
		if(#required_for > 1) then
			table.insert(formspec, "style[show_next_step;bgcolor=red]")
		end
		table.insert(formspec, "button[0,1.7;0.6,7.0;show_next_step;>]"..
				"tooltip[show_next_step;Show the next step according to "..
					em("your quest logic")..".\n"..
					"The button turns "..minetest.colorize("#FF0000", "red")..
						" if there is more than one option. In such\na case "..
						"the alphabeticly first next quest step is choosen.\n"..
					"The other "..em("Next >").." button shows the next step "..
					"in\n"..em("alphabetical order")..".]")
	end
	if(#required_for <= 1) then
		table.insert(formspec,
				"button[0,8.7;0.6,2.6;insert_before_next_step;+]"..
				"tooltip[insert_before_next_step;"..
					"Insert a new quest step between "..em("current step")..
					" (shown\nin the middle) "..
					"and the "..em("next step").." (shown to the right).\n"..
					"Note: This only makes sense if there's just one or no\n"..
					"      next step.]")
	end
	table.insert(formspec, "container_end[]")

	return table.concat(formspec, "")
end


yl_speak_up.register_fs("manage_quest_steps",
	yl_speak_up.input_fs_manage_quest_steps,
	yl_speak_up.get_fs_manage_quest_steps,
	-- no special formspec required:
	nil
)
