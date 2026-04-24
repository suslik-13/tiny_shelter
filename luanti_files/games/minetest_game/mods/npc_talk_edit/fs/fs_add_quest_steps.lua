-- helper function to make unintresting zeros in tables less visible
local grey_if_zero = function(fs, n)
	if(n and n == 0) then
		table.insert(fs, "#444444")
	else
		table.insert(fs, "#FFFFFF")
	end
	table.insert(fs, minetest.formspec_escape(n))
end


-- small helper function
local show_error_fs = function(player, text)
	yl_speak_up.show_fs(player, "msg", {
		input_to = "yl_speak_up:add_quest_steps",
		formspec = yl_speak_up.build_fs_quest_edit_error(text, "back_from_error_msg")})
end


-- find out in how many quest steps this NPC or location is used;
-- ID can either be n_<ID> or a location p_(x,y,z)
yl_speak_up.count_used_in_quest_steps = function(id, step_data)
	local used = 0
	for s, d in pairs(step_data or {}) do
		for loc_id, loc in pairs(d.where or {}) do
			if(loc and loc.n_id and loc.n_id == id) then
				used = used + 1
			end
		end
	end
	return used
end


-- This order imposed here on the quest steps is the one in which the
-- quest steps have to be solved - as far as we can tell (the quest
-- may be in the process of beeing created and not logicly complete yet).
yl_speak_up.get_sorted_quest_step_list_by_prev_step = function(pname, q_id)
	if(not(q_id) or not(yl_speak_up.quests[q_id]) or not(yl_speak_up.quests[q_id].step_data)) then
		return {}
	end

	-- for now: sort alphabeticly
	local step_data = yl_speak_up.quests[q_id].step_data
	local liste = {}
	for k, v in pairs(step_data) do
		table.insert(liste, k)
	end
	table.sort(liste)
	return liste
end

--[[ still belongs to the above function
	-- add back links (or rather: forward links to quest steps that get enabled)
	local connected = table.copy(step_data)
	for k, v in pairs(connected) do
		-- will store the inverse data
		connected[k].inv_one_step_required = {}
		connected[k].inv_all_steps_require = {}
	end
	for k, v in pairs(connected) do
		if(k and v and v.one_step_required) then
			for i, s in ipairs(v.one_step_required) do
				table.insert(connected[s].inv_one_step_required, k)
			end
		end
		if(k and v and v.all_steps_required) then
			for i, s in ipairs(v.all_steps_required) do
				table.insert(connected[s].inv_all_steps_required, k)
			end
		end
	end
	-- get those quest steps that are not connected and not used yet
	local liste = {}
	for k, v in pairs(connected) do
		if(k and v
		  and #v.one_step_required == 0 and #v.all_steps_required == 0
		  and #v.inv_one_step_required == 0 and #v.inv_all_steps_required == 0) then
			table.insert(liste, k)
		end
	end
	-- sort alphabeticly
	table.sort(liste)
	-- remove those entries from our connection table (they're not connected anyway);
	-- we have already added them to the beginning of the list
	for i, v in ipairs(liste) do
		connected[v] = nil
	end


        return liste
end             
--]]


-- helper function: find out if a quest step is required by other quest steps
yl_speak_up.quest_step_get_required_for_steps = function(step_data)
	local required_for_steps = {}
	for s, d in pairs(step_data) do
		required_for_steps[s] = {}
	end
	for s, d in pairs(step_data) do
		if(s and d and d.one_step_required and type(d.one_step_required) == "table") then
			for i, s2 in ipairs(d.one_step_required) do
				table.insert(required_for_steps[s2], s)
			end
		end
                if(s and d and d.all_steps_required and type(d.all_steps_required) == "table") then
			for i, s2 in ipairs(d.all_steps_required) do
				table.insert(required_for_steps[s2], s)
			end
		end
	end
	return required_for_steps
end


yl_speak_up.input_fs_add_quest_steps = function(player, formname, fields)
	if(not(fields) or not(player)) then
		return
	end
	local res = yl_speak_up.player_is_working_on_quest(player)
	if(res.error_msg) then
		return show_error_fs(player, res.error_msg)
	end
	local pname = res.pname
	local q_id  = res.q_id
	local current_step = res.current_step
	local step_data    = res.step_data
	local quest        = res.quest

	if(fields.back_from_error_msg) then
		yl_speak_up.show_fs(player, "add_quest_steps")
		return
	end
	local mode = yl_speak_up.speak_to[pname].quest_step_mode
	if(fields.back) then
		-- go back to quest overview
		if(mode and (mode == "manage_quest_npcs" or mode == "manage_quest_locations")) then
			return yl_speak_up.show_fs(player, "manage_quests")
		end
		return yl_speak_up.show_fs(player, "manage_quest_steps", current_step)
	end

	-- has a quest step be selected?
	local work_step = nil
	if(fields.add_element and fields.add_element_name) then
		if(    mode and mode == "manage_quest_npcs") then
			-- manually entered an NPC ID
			local npc_id = fields.add_element_name or ""
			-- just check if it is *potentially* an NPC ID; that way NPC the quest
			-- creator has no write access to can be added
			if(string.sub(npc_id, 1, 2) ~= "n_"
			  or not(tonumber(string.sub(npc_id, 3)))) then
				return show_error_fs(player, "This is not an NPC ID. They have the form n_<id>.")
			end
			-- only npcs that are not yet added (and we store IDs without n_ prefix)
			local id = tonumber(string.sub(npc_id, 3))
			if(id and table.indexof(res.quest.npcs or {}, id) == -1) then
				table.insert(yl_speak_up.quests[q_id].npcs, id)
				yl_speak_up.save_quest(q_id)
			end
			return yl_speak_up.show_fs(player, "add_quest_steps")
		elseif(mode and mode == "manage_quest_locations") then
			-- manually entered a quest location
			local location_id = fields.add_element_name or ""
			local d = yl_speak_up.player_vars["$NPC_META_DATA$"][location_id]
			local error_msg = ""
			-- the owner is not checked; that way, locations can be added where the
			-- quest onwer does not (yet) have write access
			if(string.sub(location_id, 1, 1) ~= "p") then
				error_msg = "This is not a location ID."
			elseif(not(d)) then
				error_msg = "Location not found."
			end
			if(error_msg ~= "") then
				return show_error_fs(player, error_msg)
			end
			-- only locations that are not yet added
			if(table.indexof(res.quest.locations or {}, location_id) == -1) then
				table.insert(yl_speak_up.quests[q_id].locations, location_id)
				yl_speak_up.save_quest(q_id)
			end
			return yl_speak_up.show_fs(player, "add_quest_steps")
		end

		-- create a new quest step
		local new_step = fields.add_element_name:trim()
		-- a new one shall be created
		local msg = yl_speak_up.quest_step_add_quest_step(pname, q_id, new_step)
		if(msg ~= "OK") then
			return show_error_fs(player, msg)
		end
		-- this will also be set if the quest step exists already; this is fine so far
		work_step = new_step

	elseif(fields.add_from_available
	  and yl_speak_up.speak_to[pname].list_available) then
		-- selected a quest step from the list of available steps offered
		local liste = yl_speak_up.speak_to[pname].list_available
		local selected = minetest.explode_table_event(fields.add_from_available)
		if(selected and selected.row and selected.row > 1 and selected.row <= #liste + 1) then
			work_step = liste[selected.row - 1]
		end

	elseif(fields.add_to_npc_list
	  and yl_speak_up.speak_to[pname].list_available) then
		-- selected an NPC from the list of available NPC offered
		local liste = yl_speak_up.speak_to[pname].list_available
		local selected = minetest.explode_table_event(fields.add_to_npc_list)
		if(selected and selected.row and selected.row > 1 and selected.row <= #liste + 1) then
			local npc_id = liste[selected.row - 1]
			if(table.indexof(res.quest.npcs or {}, npc_id) == -1) then
				table.insert(yl_speak_up.quests[q_id].npcs, npc_id)
				yl_speak_up.save_quest(q_id)
			end
		end
		return yl_speak_up.show_fs(player, "add_quest_steps")

	elseif(fields.add_to_location_list
	  and yl_speak_up.speak_to[pname].list_available) then
		-- selected a location from the list of available locations offered
		local liste = yl_speak_up.speak_to[pname].list_available
		local selected = minetest.explode_table_event(fields.add_to_location_list)
		if(selected and selected.row and selected.row > 1 and selected.row <= #liste + 1) then
			local location_id = liste[selected.row - 1]
			if(table.indexof(res.quest.locations or {}, location_id) == -1) then
				table.insert(yl_speak_up.quests[q_id].locations, location_id)
				yl_speak_up.save_quest(q_id)
			end
		end
		return yl_speak_up.show_fs(player, "add_quest_steps")

	elseif(fields.delete_from_one_step_required and current_step and step_data[current_step]) then
		-- remove a quest step from the list (from one step required)
		local selected = minetest.explode_table_event(fields.delete_from_one_step_required)
		local liste = (step_data[current_step].one_step_required or {})
		if(selected and selected.row and selected.row > 1 and selected.row <= #liste + 1) then
			table.remove(yl_speak_up.quests[q_id].step_data[current_step].one_step_required, selected.row-1)
		end
		yl_speak_up.save_quest(q_id)
		return yl_speak_up.show_fs(player, "add_quest_steps")

	elseif(fields.delete_from_all_steps_required and current_step and step_data[current_step]) then
		-- remove a quest step from the lists (from all steps required)
		local selected = minetest.explode_table_event(fields.delete_from_all_steps_required)
		local liste = (step_data[current_step].all_steps_required or {})
		if(selected and selected.row and selected.row > 1 and selected.row <= #liste + 1) then
			table.remove(yl_speak_up.quests[q_id].step_data[current_step].all_steps_required, selected.row-1)
		end
		yl_speak_up.save_quest(q_id)
		return yl_speak_up.show_fs(player, "add_quest_steps")

	elseif(fields.delete_from_npc_list) then
		-- remove an NPC from the list of contributors
		local selected = minetest.explode_table_event(fields.delete_from_npc_list)
		local liste = (res.quest.npcs or {})
		if(selected and selected.row and selected.row > 1 and selected.row <= #liste + 1) then
			-- *can* it be removed, or is it needed somewhere?
			local full_id = "n_"..tostring(liste[selected.row - 1])
			if(yl_speak_up.count_used_in_quest_steps(full_id, step_data) > 0) then
				return show_error_fs(player, "This NPC is needed for setting a quest step.")
			end
			table.remove(yl_speak_up.quests[q_id].npcs, selected.row - 1)
		end
		yl_speak_up.save_quest(q_id)
		return yl_speak_up.show_fs(player, "add_quest_steps")

	elseif(fields.delete_from_location_list) then
		-- remove a location from the list of contributors
		local selected = minetest.explode_table_event(fields.delete_from_location_list)
		local liste = (res.quest.locations or {})
		if(selected and selected.row and selected.row > 1 and selected.row <= #liste + 1) then
			-- *can* it be removed, or is it needed somewhere?
			local full_id = liste[selected.row - 1]
			if(yl_speak_up.count_used_in_quest_steps(full_id, step_data) > 0) then
				return show_error_fs(player, "This location is needed for setting a quest step.")
			end
			table.remove(yl_speak_up.quests[q_id].locations, selected.row - 1)
		end
		yl_speak_up.save_quest(q_id)
		return yl_speak_up.show_fs(player, "add_quest_steps")
	end

	if(not(work_step)) then
		return -- TODO
	elseif(mode == "embedded_select") then
		yl_speak_up.speak_to[pname].quest_step = work_step
		return yl_speak_up.show_fs(player, "manage_quest_steps", work_step)
	elseif(mode == "assign_quest_step") then
		-- TODO: what if there's already a step assigned?
		-- actually add the step
		local n_id = yl_speak_up.speak_to[pname].n_id
		local d_id = yl_speak_up.speak_to[pname].d_id
		local o_id = yl_speak_up.speak_to[pname].o_id
		-- this saves the quest data as well if needed
		local msg = yl_speak_up.quest_step_add_where(pname, q_id, work_step,
						{n_id = n_id, d_id = d_id, o_id = o_id})
		if(msg ~= "OK") then
			return show_error_fs(player, msg)
		end
		if(not(n_id)) then
			return show_error_fs(player, "NPC or location not found.")
		end
		-- store the new connection in the NPC file itself (do not load generic dialogs)
		local dialog = yl_speak_up.load_dialog(n_id, false)
		if(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o_id)) then
			-- ok - the tables exist, so we can store the connection
			dialog.n_dialogs[d_id].d_options[o_id].quest_id   = quest.var_name
			dialog.n_dialogs[d_id].d_options[o_id].quest_step = work_step
			-- write it back to disc
			yl_speak_up.save_dialog(n_id, dialog)
		else
			return show_error_fs(player, "Failed to save this quest step for this NPC.")
		end
		-- the player is working on the NPC - thus, the NPC may be in a modified stage
		-- that hasn't been written to disc yet, and we need to adjust this stage as well
		dialog = yl_speak_up.speak_to[pname].dialog
		if(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o_id)) then
			-- ok - the tables exist, so we can store the connection
			dialog.n_dialogs[d_id].d_options[o_id].quest_id   = quest.var_name
			dialog.n_dialogs[d_id].d_options[o_id].quest_step = work_step
			yl_speak_up.speak_to[pname].dialog = dialog
		else
			return show_error_fs(player, "Failed to update NPC.")
		end
		-- show the newly created or selected step
		yl_speak_up.speak_to[pname].quest_step = work_step
		-- log the change
		yl_speak_up.log_change(pname, n_id,
			"Dialog "..tostring(d_id)..": Option "..tostring(o_id)..
			" will now set quest step \""..
			tostring(dialog.n_dialogs[d_id].d_options[o_id].quest_step)..
			"\" of quest \""..
			tostring(dialog.n_dialogs[d_id].d_options[o_id].quest_id).."\".")
		return yl_speak_up.show_fs(player, "manage_quest_steps", work_step)
	elseif(not(current_step) or not(step_data[current_step])) then
		return yl_speak_up.show_fs(player, "manage_quests")
	end

	local required_for_steps = yl_speak_up.quest_step_get_required_for_steps(step_data)

	-- make sure we have a sane data structure
	for i, s in ipairs({current_step, work_step}) do
		if(s and yl_speak_up.quests[q_id].step_data[s]) then
			if(not(yl_speak_up.quests[q_id].step_data[s].one_step_required)) then
				yl_speak_up.quests[q_id].step_data[s].one_step_required = {}
			end
			if(not(yl_speak_up.quests[q_id].step_data[s].all_steps_required)) then
				yl_speak_up.quests[q_id].step_data[s].all_steps_required = {}
			end
		end
	end
	-- actually do the work
	if(mode == "add_to_one_needed") then
		table.insert(yl_speak_up.quests[q_id].step_data[current_step].one_step_required, work_step)
	elseif(mode == "add_to_all_needed") then
		table.insert(yl_speak_up.quests[q_id].step_data[current_step].all_steps_required, work_step)
	elseif(mode == "insert_after_prev_step") then
		-- the work_step requires what the current step used to require
		if(#step_data[current_step].one_step_required == 1) then
			-- a clear insert is possible
			yl_speak_up.quests[q_id].step_data[work_step].one_step_required = {
				step_data[current_step].one_step_required[1]}
			yl_speak_up.quests[q_id].step_data[current_step].one_step_required[1] = work_step
		else
			-- no useful information on what the new work_step ought to depend on;
			-- we just insert the new step at the first place
			table.insert(yl_speak_up.quests[q_id].step_data[current_step].one_step_required,
					1, work_step)
		end
		return yl_speak_up.show_fs(player, "manage_quest_steps", work_step)
	elseif(mode == "insert_before_next_step") then
		-- the work_step requires the current_step
		table.insert(yl_speak_up.quests[q_id].step_data[work_step].one_step_required, 1, current_step)
		-- the current step has exactly one successor? then we adjust that one
		if(#required_for_steps[current_step] == 1) then
			local next_step = required_for_steps[current_step][1]
			local i = table.indexof(step_data[next_step].one_step_required,  current_step)
			local a = table.indexof(step_data[next_step].all_steps_required, current_step)
			if(i > -1) then
				-- is it in one_step_required? -> replace current_step with work_step
				yl_speak_up.quests[q_id].step_data[next_step].one_step_required[i] = work_step
			elseif(a > -1) then
				-- or in all_steps_required? -> replace current_step with work_step
				yl_speak_up.quests[q_id].step_data[next_step].all_steps_required[i] =work_step
			end
		end
		return yl_speak_up.show_fs(player, "manage_quest_steps", work_step)
	end
	yl_speak_up.save_quest(q_id)
	return yl_speak_up.show_fs(player, "add_quest_steps")
end


-- small helper function for yl_speak_up.get_fs_add_quest_steps;
-- lists all the quest steps found in liste in the order they occour there
yl_speak_up.quest_step_list_show_table = function(formspec, table_specs, liste, data, required_for_steps)
	table.insert(formspec, "tablecolumns["..
		"color;text,align=right;".. -- #d.one_step_required
		"color;text,align=right;".. -- #d.all_steps_required
		"color;text,align=right;".. -- #required_for_steps (quest steps that need this one)
		"color;text,align=right;".. -- #where (locations/NPC that *set* this quest step)
		"color;text,align=left"..  -- name of quest step
		"]table[")
	table.insert(formspec, table_specs)
	table.insert(formspec,"#FFFFFF,(O),#FFFFFF,(A),#FFFFFF,(U),#FFFFFF,(L),#FFFFFF,Name of step:,")
	local tmp = {}
	for i, s in ipairs(liste or {}) do
		local d = data[s]
		if(not(d.one_step_required) or type(d.one_step_required) ~= "table") then
			d.one_step_required = {}
		end
		grey_if_zero(tmp, #d.one_step_required)
		if(not(d.all_steps_required) or type(d.all_steps_required) ~= "table") then
			d.all_steps_required = {}
		end
		grey_if_zero(tmp, #d.all_steps_required)
		if(not(required_for_steps[s])) then
			required_for_steps[s] = {}
		end
		grey_if_zero(tmp, #required_for_steps[s])

		if(not(d.where) or type(d.where) ~= "table") then
			d.where = {}
		end
		local anz_where = 0
		for k, v in pairs(d.where) do
			anz_where = anz_where + 1
		end
		grey_if_zero(tmp, anz_where)

		table.insert(tmp, "#AAFFAA")
		table.insert(tmp, minetest.formspec_escape(s))
	end
	table.insert(formspec, table.concat(tmp, ","))
	table.insert(formspec, ";]")
end


-- returns list of NPCs that pname can edit and that are not yet part of quest_npc_list
yl_speak_up.quest_get_npc_candidate_list = function(pname, quest_npc_liste)
	-- build a list of candidates
	local npc_list = {}
	for k, v in pairs(yl_speak_up.npc_list) do
		-- only NPC that are not already added
		if(table.indexof(quest_npc_liste or {}, k) == -1
		  -- and only those that the player can edit
		  and (v.owner == pname or (v.may_edit and v.may_edit[pname]))) then
			table.insert(npc_list, k)
		end
	end
	table.sort(npc_list)
	return npc_list
end


-- lists npc that are either already added or could be added
-- can also handle locations
yl_speak_up.quest_npc_show_table = function(formspec, table_specs, liste, step_data, is_location_list)
	table.insert(formspec, "tablecolumns["..
		"color;text,align=right;".. -- used in this many quest steps
		"color;text,align=left;".. -- n_id (number, for NPC) or p_(-185,3,-146) (for locations)
		"color;text,align=left;".. -- owner
		"color;text,align=left"..  -- name of NPC
		"]table[")
	table.insert(formspec, table_specs)
	if(is_location_list) then
		table.insert(formspec,"#FFFFFF,Used:,#FFFFFF,PositionID:,#FFFFFF,Name")
	else
		table.insert(formspec,"#FFFFFF,Used:,#FFFFFF,n_id:,#FFFFFF,Name")
	end
	table.insert(formspec, minetest.formspec_escape(","))
	table.insert(formspec, " description:,#FFFFFF,Owner:,")
	local tmp = {}
	for i, n_id in ipairs(liste or {}) do
		local full_id = n_id
		if(not(is_location_list)) then
			full_id = "n_"..tostring(n_id)
		end
		grey_if_zero(tmp, yl_speak_up.count_used_in_quest_steps(full_id, step_data))
		-- the n_id of the NPC
		table.insert(tmp, "#AAFFAA")
		if(is_location_list) then
			-- this already encodes the position but contains , and ()
			table.insert(tmp, minetest.formspec_escape(n_id))
		else
			table.insert(tmp, "n_"..minetest.formspec_escape(n_id))
		end
		-- get information from the NPC list (see fs_npc_list.lua)
		local owner = "- ? -"
		local name  = "- ? -"
		if(yl_speak_up.npc_list[n_id]) then
			local npc = yl_speak_up.npc_list[n_id]
			owner = npc.owner
			name = (npc.name or name)
			if(npc.desc and npc.desc ~= "") then
				name = name..', '..(npc.desc or "")
			end
                end
		-- name and description of the NPC
		table.insert(tmp, "#AAFFAA")
		table.insert(tmp, minetest.formspec_escape(name))
		-- owner of the NPC
		table.insert(tmp, "#AAFFAA")
		table.insert(tmp, minetest.formspec_escape(owner))
	end
	table.insert(formspec, table.concat(tmp, ","))
	table.insert(formspec, ";]")
end


-- returns list of locations that pname can edit and that are not yet part of quest_location_list
yl_speak_up.quest_get_location_candidate_list = function(pname, quest_location_liste)
	-- build a list of candidates of locations
	local location_list = {}
	for n_id, v in pairs(yl_speak_up.player_vars["$NPC_META_DATA$"] or {}) do
		-- TODO: better detection would be helpful
		if(string.sub(n_id, 1, 1) == "p"
		  -- only locations that are not yet added
		  and table.indexof(quest_location_liste or {}, n_id) == -1
		  -- and only those that the player can edit
		  and (v.owner == pname or (v.may_edit and v.may_edit[pname]))) then
			table.insert(location_list, n_id)
		end
	end
	table.sort(location_list)
	return location_list
end


-- param is unused
yl_speak_up.get_fs_add_quest_steps = function(player, param)
	local res = yl_speak_up.player_is_working_on_quest(player)
	if(res.error_msg) then
		return yl_speak_up.build_fs_quest_edit_error(res.error_msg, "back")
        end
	local pname = res.pname
	local step_data = res.step_data or {}


	-- find out if a quest step is required by other quest steps
	local required_for_steps = yl_speak_up.quest_step_get_required_for_steps(step_data)

	local current_step = nil
	local this_step_data = nil
	if(pname and yl_speak_up.speak_to[pname] and yl_speak_up.speak_to[pname].quest_step) then
		current_step = yl_speak_up.speak_to[pname].quest_step
		this_step_data = step_data[current_step]
	end
	local mode = ""
	if(param) then
		mode = param
		yl_speak_up.speak_to[pname].quest_step_mode = param
	elseif(pname and yl_speak_up.speak_to[pname] and yl_speak_up.speak_to[pname].quest_step_mode) then
		mode = yl_speak_up.speak_to[pname].quest_step_mode
	end

	local add_what = "Add a new quest step named:"
	if(mode == "manage_quest_npcs") then
		add_what = "Add the NPC with n_<id>:"
	elseif(mode == "manage_quest_locations") then
		add_what = "Add a location by entering its ID directly:"
	end

	local formspec = {}
	if(mode and mode == "embedded_select") then
		table.insert(formspec, "size[30,12]container[6,0;18.5,12]")
		current_step = nil
	else
		table.insert(formspec, "size[18.5,17.3]")
	end

	-- add back button
	table.insert(formspec, "button[8,0;2,0.7;back;Back]")
	-- show which quest we're working at
	table.insert(formspec, "label[0.2,1.0;Quest ID:]")
	table.insert(formspec, "label[3.0,1.0;")
	table.insert(formspec, minetest.formspec_escape(res.q_id))
	table.insert(formspec, "]")
	table.insert(formspec, "label[0.2,1.5;Quest name:]")
	table.insert(formspec, "label[3.0,1.5;")
	table.insert(formspec, minetest.formspec_escape(res.quest.name or "- unknown -"))
	table.insert(formspec, "]")

	-- add new quest step
	table.insert(formspec, "label[0.2,2.2;")
	table.insert(formspec, add_what)
	table.insert(formspec, "]")
	table.insert(formspec, "button[16.1,2.4;1.2,0.7;add_element;Add]")
	table.insert(formspec, "field[1.0,2.4;15,0.7;add_element_name;;]")

	local y_pos = 3.3
	if(current_step and mode == "insert_after_prev_step") then
		local prev_step = "-"
		if(this_step_data and this_step_data.one_step_required and #this_step_data.one_step_required > 0) then
			prev_step = this_step_data.one_step_required[1]
		end
		table.insert(formspec, "label[0.2,3.3;between the previous step:]")
		table.insert(formspec, "label[1.0,3.7;")
		table.insert(formspec, minetest.colorize("#AAFFAA", minetest.formspec_escape(prev_step)))
		table.insert(formspec, "]")
		table.insert(formspec, "label[0.2,4.1;and the currently selected step:]")
		table.insert(formspec, "label[1.0,4.5;")
		table.insert(formspec, minetest.colorize("#FFFF00", minetest.formspec_escape(current_step)))
		table.insert(formspec, "]")
		y_pos = 5.3
	elseif(current_step and mode == "insert_before_next_step") then
		local next_step = "-"
		if(current_step and required_for_steps[current_step] and #required_for_steps[current_step] > 0) then
			next_step = required_for_steps[current_step][1]
		end
		table.insert(formspec, "label[0.2,3.3;between the currently selected step:]")
		table.insert(formspec, "label[1.0,3.7;")
		table.insert(formspec, minetest.colorize("#FFFF00", minetest.formspec_escape(current_step)))
		table.insert(formspec, "]")
		table.insert(formspec, "label[0.2,4.1;and the next step:]")
		table.insert(formspec, "label[1.0,4.5;")
		table.insert(formspec, minetest.colorize("#AAFFAA", minetest.formspec_escape(next_step)))
		table.insert(formspec, "]")
		y_pos = 5.3
	elseif(current_step and mode == "add_to_one_needed") then
		table.insert(formspec, "label[0.2,3.3;as a requirement to the currently selected step:]")
		table.insert(formspec, "label[1.0,3.7;")
		table.insert(formspec, minetest.colorize("#FFFF00", minetest.formspec_escape(current_step)))
		table.insert(formspec, "]")
		table.insert(formspec, "label[0.2,4.1;so that "..
					minetest.colorize("#9999FF", "at least one")..
					" of these requirements is fulfilled:]")
		yl_speak_up.quest_step_list_show_table(formspec,
					"0.2,4.3;17.0,3.0;delete_from_one_step_required;",
					step_data[current_step].one_step_required,
					step_data, required_for_steps)
		table.insert(formspec, "label[0.2,7.5;(Click on an entry to delete it from the list above.)]")
		y_pos = 8.3
	elseif(current_step and mode == "add_to_all_needed") then
		table.insert(formspec, "label[0.2,3.3;as a requirement to the currently selected step:]")
		table.insert(formspec, "label[1.0,3.7;")
		table.insert(formspec, minetest.colorize("#FFFF00", minetest.formspec_escape(current_step)))
		table.insert(formspec, "]")
		table.insert(formspec, "label[0.2,4.1;so that "..
					minetest.colorize("#9999FF", "all")..
					" of these requirements are fulfilled:]")
		yl_speak_up.quest_step_list_show_table(formspec,
					"0.2,4.3;17.0,3.0;delete_from_all_steps_required;",
					step_data[current_step].all_steps_required,
					step_data, required_for_steps)
		table.insert(formspec, "label[0.2,7.5;(Click on an entry to delete it from the list above.)]")
		y_pos = 8.3
	-- add a quest step to an NPC or location
	elseif(mode == "assign_quest_step") then
		table.insert(formspec, "container[0,3.3;17,4]")
		-- what are we talking about?
		local n_id = yl_speak_up.speak_to[pname].n_id
		local d_id = yl_speak_up.speak_to[pname].d_id
		local o_id = yl_speak_up.speak_to[pname].o_id
		-- describe where in the dialog of the NPC or location this quest step shall be set
		yl_speak_up.quest_step_show_where_set(pname, formspec, "which will be set by ", n_id, d_id, o_id, nil, nil)
		table.insert(formspec, "container_end[]")
		y_pos = 7.8

	-- which NPC may contribute to the quest?
	elseif(mode == "manage_quest_npcs") then
		table.insert(formspec, "container[0,3.3;18,6]")
		table.insert(formspec, "label[0.2,0;so that the NPC "..
					minetest.colorize("#9999FF", "may contribute")..
					" to the quest like these NPC:]")
		yl_speak_up.quest_npc_show_table(formspec,
					"0.2,0.2;17.0,3.0;delete_from_npc_list;",
					res.quest.npcs or {},
					step_data, false)
		table.insert(formspec, "label[0.2,3.4;(Click on an entry to delete it from the list above.)]")
		local available_npcs = yl_speak_up.quest_get_npc_candidate_list(pname, res.quest.npcs or {})
		yl_speak_up.speak_to[pname].list_available = available_npcs
		table.insert(formspec, "label[0.2,4.4;or select an NPC from the list below:]")
		yl_speak_up.quest_npc_show_table(formspec,
					"0.2,4.6;17.0,6.0;add_to_npc_list;",
					available_npcs or {}, step_data, false)
		table.insert(formspec, "label[0.2,10.8;Used: Shows in how many quest steps this NPC is used.]")
		table.insert(formspec, "container_end[]")
		return table.concat(formspec, "")
	-- which locations may contribute to the quest?
	elseif(mode == "manage_quest_locations") then
		table.insert(formspec, "container[0,3.3;18,6]")
		table.insert(formspec, "label[0.2,0;so that the location "..
					minetest.colorize("#9999FF", "may contribute")..
					" to the quest like these locations:]")
		yl_speak_up.quest_npc_show_table(formspec,
					"0.2,0.2;17.0,3.0;delete_from_location_list;",
					res.quest.locations or {},
					step_data, true)
		table.insert(formspec, "label[0.2,3.4;(Click on an entry to delete it from the list above.)]")
		local available_locations = yl_speak_up.quest_get_location_candidate_list(pname, res.quest.locations or {})
		yl_speak_up.speak_to[pname].list_available = available_locations
		table.insert(formspec, "label[0.2,4.4;or select a location from the list below:]")
		yl_speak_up.quest_npc_show_table(formspec,
					"0.2,4.6;17.0,6.0;add_to_location_list;",
					available_locations or {}, step_data, true)
		table.insert(formspec, "label[0.2,10.8;Used: Shows in how many quest steps this location is used.]")
		table.insert(formspec, "container_end[]")
		return table.concat(formspec, "")
	end

	-- some quest steps may not be available/may not make sense
	local not_available = {}
	if(current_step and step_data[current_step] and (not(mode) or mode ~= "assign_quest_step")) then
		-- steps that are already required
		for i, s in ipairs(step_data[current_step].one_step_required or {}) do
			not_available[s] = true
		end
		for i, s in ipairs(step_data[current_step].all_steps_required or {}) do
			not_available[s] = true
		end
		-- steps that directly require this quest step here
		for i, s in ipairs(required_for_steps[current_step] or {}) do
			not_available[s] = true
		end
	end
	if(current_step and (not(mode) or mode ~= "assign_quest_step")) then
		not_available[current_step] = true
	end
	-- build a list of candidates
	local available_steps = {}
	for k, v in pairs(step_data) do
		if(not(not_available[k])) then
			table.insert(available_steps, k)
		end
	end
	table.sort(available_steps)
	yl_speak_up.speak_to[pname].list_available = available_steps

	table.insert(formspec, "container[0,")
	table.insert(formspec, tostring(y_pos))
	table.insert(formspec, ";30,20]")

	table.insert(formspec, "label[0.2,0;or select an existing quest step from the list below")
	if(mode and mode == "embedded_select") then
		table.insert(formspec, minetest.colorize("#9999FF", " to display the step")..":]")
	else
		table.insert(formspec, ":]")
	end
	yl_speak_up.quest_step_list_show_table(formspec,
		"0.2,0.2;17,6.0;add_from_available;",
		available_steps,
		step_data, required_for_steps)
	table.insert(formspec, "label[0.2,6.5;Legend: The numbers show the amount of quest steps...\n"..
			"\t(O) from which (o)ne needs to be achieved for this quest step\n"..
			"\t(A) that (a)ll need to be achieved for this quest step\n"..
			"\t(U) that require/(u)se this quest step in some form\n"..
			"\t(L) Number of locations (npc/places) that "..
				minetest.colorize("#9999FF", "set").." this quest step]")
	table.insert(formspec, "container_end[]")

	return table.concat(formspec, "")
end

yl_speak_up.register_fs("add_quest_steps",
	yl_speak_up.input_fs_add_quest_steps,
	-- param is unused here
	yl_speak_up.get_fs_add_quest_steps,
	-- no special formspec version required
	nil
)
