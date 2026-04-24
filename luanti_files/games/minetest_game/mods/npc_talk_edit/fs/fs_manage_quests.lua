-- helper functions for yl_speak_up.input_fs_manage_quests(..)
-- returns the index of the new quest
yl_speak_up.fun_input_fs_manage_quests_add_new_entry = function(pname, entry_name)
	local res = yl_speak_up.add_quest(pname, entry_name,
		"Name of your quest",
		"Enter a longer description here for describing the quest "..
			"to players who search for one.",
		"Enter a short description here describing what the quest is about.",
		"Room for comments/notes")
	-- might make sense to show the error message somewhere
	if(res ~= "OK") then
		return res
	end
	-- the new entry will be somewhere in it
	local quest_list = yl_speak_up.get_sorted_quest_list(pname)
	return table.indexof(quest_list, entry_name)
end

-- helper functions for yl_speak_up.input_fs_manage_quests(..)
-- returns a text describing if deleting the quest worked
yl_speak_up.fun_input_fs_manage_quests_del_old_entry = function(pname, entry_name)
	-- get q_id from entry_name
	local q_id = yl_speak_up.get_quest_id_by_var_name(entry_name, pname)
	return yl_speak_up.del_quest(q_id, pname)
end

-- helper functions for yl_speak_up.input_fs_manage_quests(..)
-- implements all the functions that are specific to managing quests and not part of
-- general item management
yl_speak_up.fun_input_fs_manage_quests_check_fields = function(player, formname, fields, quest_name, list_of_entries)
	local pname = player:get_player_name()
	if(not(quest_name)) then
		quest_name = ""
	end
	if(fields and fields.show_variable) then
		yl_speak_up.show_fs(player, "manage_variables", {var_name = quest_name})
		return
	end
	-- this function didn't have anything to do
	return "NOTHING FOUND"
end


-- makes use of yl_speak_up.handle_input_fs_manage_general and is thus pretty short
yl_speak_up.input_fs_manage_quests = function(player, formname, fields)
	local pname = player:get_player_name()
	if(fields and fields.manage_quest_steps and fields.manage_quest_steps ~= "") then
		-- the quest we're working at is stored in yl_speak_up.speak_to[pname].q_id
		yl_speak_up.show_fs(player, "manage_quest_steps")
		return
	end

	-- show and edit NPCs that may contribute
	if(    fields and fields.edit_npcs) then
		return yl_speak_up.show_fs(player, "add_quest_steps", "manage_quest_npcs")
	elseif(fields and fields.edit_locations) then
		return yl_speak_up.show_fs(player, "add_quest_steps", "manage_quest_locations")
	end

	-- show a particular quest step from the start/unconnected/end list?
	local res = yl_speak_up.player_is_working_on_quest(player)
	if(yl_speak_up.speak_to[pname]
	  and yl_speak_up.speak_to[pname].q_id
	  and yl_speak_up.handle_input_routing_show_a_quest_step(player, formname, fields, "back", res)) then
		return
	end

	local quest_list = yl_speak_up.get_sorted_quest_list(pname)
	local res = yl_speak_up.handle_input_fs_manage_general(player, formname, fields,
		-- what_is_the_list_about, min_length, max_length, function_add_new_entry,
		"quest", 2, 80,
		yl_speak_up.fun_input_fs_manage_quests_add_new_entry,
		quest_list,
		yl_speak_up.fun_input_fs_manage_quests_del_old_entry,
		yl_speak_up.fun_input_fs_manage_quests_check_fields)
	return true
end


yl_speak_up.get_fs_manage_quests = function(player, param)
	local pname = player:get_player_name()
	local quest_list = yl_speak_up.get_sorted_quest_list(pname)
	local formspec = {}
	if(param and param ~= "") then
		local index = table.indexof(quest_list, param)
		yl_speak_up.speak_to[pname].tmp_index_general = index + 1
	end
	table.insert(formspec,	"size[30,12]"..
				"container[6,0;18.5,12]"..
				"label[0.2,1.2;A quest is a linear sequence of quest steps. Quests can "..
						"depend on and influence other quests.\n"..
					"Progress for each player is stored in a variable. The name of "..
						"that variable cannot be changed after creation.]")
--	if(true) then return formspec[1] end -- TODO: temporally disabled for YL
	local selected = yl_speak_up.build_fs_manage_general(player, param,
				formspec, quest_list,
				"Create quest",
					"Create a new varialbe with the name\n"..
					"you entered in the field to the left.",
				"quest",
				"Enter the name of the new quest you want to create.\n"..
					"You can't change this name afterwards. But you *can*\n"..
					"add and change a human readable description later on.",
				"If you click here, the selected quest will be deleted.\n"..
					"This will only be possible if it's not used anywhere.")
	if(not(selected) or selected == "") then
		table.insert(formspec, "container_end[]")
		return table.concat(formspec, "")
	end
	local var_name = yl_speak_up.restore_complete_var_name(selected, pname)
	local quest = {}
        for q_id, data in pairs(yl_speak_up.quests) do
		if(data and data.var_name and data.var_name == var_name) then
			quest = data
		end
	end

	-- which quest is the player working on? that's important for showing quest steps
	if(not(yl_speak_up.speak_to[pname])) then
		yl_speak_up.speak_to[pname] = {}
	end
	yl_speak_up.speak_to[pname].q_id = quest.id

	local quest_state_selected = table.indexof({"created","testing","open","official"}, quest.state)
	if(quest_state_selected == -1) then
		quest_state_selected = 1
	end
	-- index 1 is "Add variable:"

	table.insert(formspec, "button[12,2.15;4.5,0.6;show_variable;Show and edit this variable]")

	table.insert(formspec, "scroll_container[0,3;18,8;scr0;vertical;1]")
	table.insert(formspec, "button[12,0.15;4.5,0.6;manage_quest_steps;Manage quest steps]")

	table.insert(formspec, "label[0.5,0.5;Quest ID:]")
	table.insert(formspec, "label[3.5,0.5;"..minetest.formspec_escape(quest.id or "- ? -").."]")
	table.insert(formspec, "label[0.5,1.1;State:]")
	table.insert(formspec, "dropdown[3.5,0.8;4.0,0.5;quest_state;created,testing,open,official;"..tostring(quest_state_selected).."]")
	table.insert(formspec, "label[0.5,1.7;Creator/Owner:]")
	table.insert(formspec, "field[3.5,1.4;4.0,0.5;quest_owner;;"..minetest.formspec_escape(quest.owner or "- ? -").."]")
	table.insert(formspec, "label[0.5,2.3;Name:]")
	table.insert(formspec, "field[3.5,2.0;13.0,0.5;quest_name;;"..minetest.formspec_escape(quest.name or "- ? -").."]")
	table.insert(formspec, "label[0.5,2.9;Short Description:]")
	table.insert(formspec, "field[3.5,2.6;13.0,0.5;quest_short_desc;;"..minetest.formspec_escape(quest.short_desc or "- ? -").."]")
	table.insert(formspec, "label[0.5,3.5;Full Description:]")
	table.insert(formspec, "textarea[3.5,3.2;13.0,1.5;quest_desc;;"..minetest.formspec_escape(quest.description or "- ? -").."]")
	table.insert(formspec, "label[0.5,5.1;Internal comment:]")
	table.insert(formspec, "textarea[3.5,4.8;13.0,1.5;quest_comment;;"..minetest.formspec_escape(quest.comment or "- ? -").."]")

	table.insert(formspec, "button[3.5,6.5;4.0,0.8;save_changes;TODO Save changes]")
	table.insert(formspec, "scroll_container_end[]")
	table.insert(formspec, "container_end[]")

	-- TODO: make the content of the fields and textareas more readable (more contrast)
	-- TODO: actually process and store changed entries
--[[
	-- TODO: entries that are not yet shown:
        quest.var_name = var_name -- name of the variable where progress is stored for each player
        quest.subquests = {}      -- list of other quest_ids that contribute to this quest
                                  -- -> determined from quests.npcs and quests.locations
        quest.is_subquest_of = {} -- list of quest_ids this quest contributes to
                                  -- -> determined from quests.npcs and quests.locations
	     quest.rewards = {}        -- list of rewards (item stacks) for this ques
        quest.testers = {}        -- list of player names that can test the quest
                                  -- -> during the created/testing phase: any player for which
                                  --    quest.var_name is set to a value
        quest.solved_by = {}      -- list of names of players that solved the quest at least once
--]]

	-- left side: quest steps
	-- quest.step_data = {}
	--     table containing information about a quest step (=key)
	--     this may also be information about WHERE a quest step shall take place
	table.insert(formspec, "button[0.1,0.1;5.6,0.8;show_step_list;Show all quest steps]")
	local lists = yl_speak_up.quest_step_get_start_end_unconnected_lists(quest.step_data or {})
	yl_speak_up.get_sub_fs_show_list_in_box(formspec,
			"Start steps:", "select_from_start_steps", lists.start_steps,
			"0.1", "1.0", "5.6", "3.5", 0, nil, "#AAFFAA",
			"The quest begins with this (or one of these) steps.\n"..
				"You need at least one start step.",
			nil)
	yl_speak_up.get_sub_fs_show_list_in_box(formspec,
			"Unconnected steps:", "select_from_unconnected_steps", lists.unconnected_steps,
			"0.1", "4.5", "5.6", "3.5", 0, nil, "#FFAAAA",
			"These steps are not used yet. They are not required\n"..
				"by any other step and do not require steps either.\n"..
				"Please decide what to do with them!",
			nil)
	yl_speak_up.get_sub_fs_show_list_in_box(formspec,
			"Quest ends with steps:", "select_from_end_steps", lists.end_steps,
			"0.1", "8.0", "5.6", "3.5", 0, nil, "#AAFFAA",
			"This quest ends with these steps. They are not required\n"..
				"by any other steps and have no successor.\n"..
				"Your quest needs at least one end step.",
			nil)

	-- right side:
	--     All these values could in theory either be derived from quest.var_name
	--     and/or from quest.step_data.where.
	--     These lists here are needed regardless of that because they may be used
	--     to add NPC/locations/quest items that are *not yet* used but are planned
	--     to be used for this quest eventually.
	table.insert(formspec, "style[edit_npcs,edit_locations,edit_items;bgcolor=blue;textcolor=yellow]")
	-- quest.npcs = {}
	--     list of NPC that *may* contribute to this quest (only IDs without leading n_)
	-- turn that list into a more readable list of names
	local npc_names = {}
	for i, id in ipairs(quest.npcs or {}) do
		local d = yl_speak_up.npc_list[id] or {}
		table.insert(npc_names, "n_"..tostring(id).." "..(d.name or "- unknown -"))
	end
	yl_speak_up.get_sub_fs_show_list_in_box(formspec,
			"NPC that (may) participate:", "select_from_npcs", npc_names,
			"24", "1.0", "5.6", "3.5", 0, nil, "#AAAAFF",
			"This is a list of NPC that may be relevant for this quest.\n"..
				"Add an NPC to this list and then edit the NPC.\n"..
				"Now you can set quest steps from this quest in the NPC's options.",
			"button[4.6,0.0;0.94,0.7;edit_npcs;Edit]")
	-- quest.locations = {}
	--     list of locations that *may* contribute to this quest
	yl_speak_up.get_sub_fs_show_list_in_box(formspec,
			"Locations:", "select_from_locations", quest.locations or {},
			"24", "4.5", "5.6", "3.5", 0, nil, "#AAAAFF",
			"This is a list of locations that may be relevant for this quest.\n"..
				"It works the same way as for the NPC above.",
			"button[4.6,0.0;0.94,0.7;edit_locations;Edit]")
	-- quest.items = {}
	--     data of quest items that *may* be created and/or accepted in this quest
	yl_speak_up.get_sub_fs_show_list_in_box(formspec,
			"Quest items:", "select_from_quest_items", quest.items or {},
			"24", "8.0", "5.6", "3.5", 0, nil, "#FFFFFF",
			"This is a list of quest items.\n"..
				"Add quest items here in order to use them more easily in your NPC.",
			"button[4.6,0.0;0.94,0.7;edit_items;Edit]")


	-- store the quest ID so that we know what we're working at
	yl_speak_up.speak_to[pname].q_id = quest.id
	return table.concat(formspec, "")
end


yl_speak_up.register_fs("manage_quests",
	yl_speak_up.input_fs_manage_quests,
	yl_speak_up.get_fs_manage_quests,
	-- no special formspec required:
	nil
)
