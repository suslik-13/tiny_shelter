
-- general helper functions
-- TODO: not yet used
yl_speak_up.count_table_elements = function(table)
	if(not(table) or type(table) ~= "table") then
		return -1
	end
	local c = 0
	for k, v in pairs(table) do
		c = c + 1
	end
	return c
end


-- just some handling of variables

-- TODO: mark some vars as "need to be saved" while others are less important (i.e. timestamps)

-- the keys are of the form:
-- 	$ <blank> <player name> <blank> <variable name> (makes it easier to grant read access)
-- the values are of the form:
-- 	<current player name as key> : <value of variable for that player as value>
yl_speak_up.player_vars = {}

-- store when player_vars was last saved to disc
yl_speak_up.player_vars_last_save_time = 0

-- save the data to disc; either if force_save is set or enough time has passed
yl_speak_up.save_quest_variables = function(force_save)
	if(not(force_save)
	  and (yl_speak_up.player_vars_last_save_time + yl_speak_up.player_vars_min_save_time >
	       math.floor(minetest.get_us_time()/1000000))) then
		return
	end
	local json = minetest.write_json( yl_speak_up.player_vars )
	-- actually store it on disk
	minetest.safe_file_write(yl_speak_up.worldpath..yl_speak_up.player_vars_save_file..".json", json)
end


yl_speak_up.handle_json_nil_values = function(data)
	if(data and type(data) == "table") then
		for k,v in pairs(data) do
			if(    type(v) == "string" and v == "$NIL_VALUE$") then
				data[ k ] = {}
			elseif(type(v) == "table") then
				data[ k ] = yl_speak_up.handle_json_nil_values(v)
			end
		end
	end
	return data
end


-- load the data from disc
yl_speak_up.load_quest_variables = function()
	-- load the data from the file
	local file, err = io.open(yl_speak_up.worldpath..yl_speak_up.player_vars_save_file..".json", "r")
	if err then
		return
	end
	io.input(file)
	local text = io.read()
	-- all values saved in the tables as such are strings
	local data = minetest.parse_json(text, "$NIL_VALUE$")
	io.close(file)

	if(type(data) ~= "table") then
		return
	end
	yl_speak_up.player_vars = yl_speak_up.handle_json_nil_values(data)
	if(not(yl_speak_up.player_vars.meta)) then
		yl_speak_up.player_vars["meta"] = {}
	end
end
-- do so when this file is parsed
yl_speak_up.load_quest_variables()


-- new variables have to be added somehow
yl_speak_up.add_quest_variable = function(owner_name, variable_name)
	local k = "$ "..tostring(owner_name).." "..tostring(variable_name)
	if(not(owner_name) or not(variable_name)) then
		return false
	end
	-- create a new empty table;
	-- keys will be the names of players for which values are set
	yl_speak_up.player_vars[ k ] = {}
	-- a new variable was created - that deserves a forced save
	yl_speak_up.save_quest_variables(true)
	return true
end


-- time based variables are used for "Limit guessing:" and "Limit repeating:"; they ensure that
-- options with actions cannot be repeated indefintely;
-- returns false if the variable could not be created; else it returns the variable metadata
yl_speak_up.add_time_based_variable = function(variable_name)
	if(not(yl_speak_up.player_vars[ variable_name ])) then
		yl_speak_up.player_vars[ variable_name ] = {}
		yl_speak_up.player_vars[ variable_name ][ "$META$" ] = {}
		yl_speak_up.player_vars[ variable_name ][ "$META$"][ "var_type" ] = "time_based"
		yl_speak_up.save_quest_variables(true)
		return yl_speak_up.player_vars[ variable_name ][ "$META$"]
	elseif(yl_speak_up.player_vars[ variable_name ]
	  and  yl_speak_up.player_vars[ variable_name ][ "$META$"]
	  and  type(yl_speak_up.player_vars[ variable_name ][ "$META$"]) == "table"
	  and  yl_speak_up.player_vars[ variable_name ][ "$META$"][ "var_type" ] == "time_based") then
		return yl_speak_up.player_vars[ variable_name ][ "$META$"]
	end
	return false
end


-- accidentally created or no longer needed variables need to be deleted somehow
-- force_delete if set, the variable will be deleted no matter what; this is for
--              manual maintenance and not used in this mod
yl_speak_up.del_quest_variable = function(owner_name, variable_name, force_delete)
	if(not(owner_name) or not(variable_name)) then
		return " could not be deleted. Parameters mismatch."
	end
	local var_name = yl_speak_up.restore_complete_var_name(variable_name, owner_name)
	if(not(var_name) or not(yl_speak_up.player_vars[ var_name ])) then
		return text.." does not exist."
	end
	local text = "Variable \""..minetest.formspec_escape(var_name).."\""
	-- forcefully delete - even if the variable is still beeing used
	if(force_delete) then
		yl_speak_up.player_vars[ k ] = nil
		yl_speak_up.save_quest_variables(true)
		return text.." deleted by force."
	end
	-- check if the player really owns the variable: not that important because only unused
	-- variables can be deleted;
	-- check if the variable is used by an NPC
	local var_data = yl_speak_up.player_vars[ var_name ]
	local npc_users = yl_speak_up.get_variable_metadata(var_name, "used_by_npc")
	if(npc_users and #npc_users > 0) then
		return text.." could not be deleted.\nIt is used by "..tostring(#npc_users).." NPC."
	end
	-- check if the variable is used by a node position (for quests)
	local node_pos_users = yl_speak_up.get_variable_metadata(var_name, "used_by_node_pos")
	if(node_pos_users and #node_pos_users > 0) then
		return text.." could not be deleted.\nIt is used by "..tostring(#node_pos_users)..
				" node positions (quest)."
	end
	-- check if the variable has any values stored
	for k, v in pairs(var_data) do
		if(k and k ~= "$META$") then
			return text.." could not be deleted.\nIt contains at least one stored value."
		end
	end
	-- actually delete the variable
	yl_speak_up.player_vars[ var_name ] = nil
	-- a variable was deleted - that deserves a forced save
	yl_speak_up.save_quest_variables(true)
	return text.." deleted successfully."
end


-- set the value of a variable used by a player in an NPC;
-- returns false if the variable cannot be set (i.e. does not exist)
yl_speak_up.set_quest_variable_value = function(player_name, variable_name, new_value)
	-- the owner name is alrady encoded in the variable name
	local k = tostring(variable_name)
	if(not(variable_name) or not(player_name) or not(yl_speak_up.player_vars[ k ])) then
		return false
	end
	if(yl_speak_up.player_vars[ k ]["$META$"]
	  and yl_speak_up.player_vars[ k ]["$META$"][ "debug" ]
	  and type(yl_speak_up.player_vars[ k ]["$META$"][ "debug" ]) == "table") then
		for p, _ in pairs(yl_speak_up.player_vars[ k ]["$META$"][ "debug" ]) do
			minetest.chat_send_player(p, "[Variable "..
				minetest.colorize("#FFFF00", tostring(k))..
				", player "..
				minetest.colorize("#FFFF00", tostring(player_name))..
				"] old value: \""..
				minetest.colorize("#FFFF00",
					tostring(yl_speak_up.player_vars[ k ][ player_name ]))..
				"\" new value: \""..
				minetest.colorize("#FFFF00", tostring(new_value)).."\".")
		end
	end
	if(new_value ~= nil) then
		new_value = tostring(new_value)
	end
	yl_speak_up.player_vars[ k ][ player_name ] = new_value
	-- a quest variable was changed - save that to disc (but no need to force it)
	yl_speak_up.save_quest_variables(false)
	return true
end


-- get the value of a variable used by a player in an NPC;
-- returns nil if the variable does not exist
yl_speak_up.get_quest_variable_value = function(player_name, variable_name)
	-- the owner name is alrady encoded in the variable name
	local k = tostring(variable_name)
	if(not(variable_name) or not(player_name) or not(yl_speak_up.player_vars[ k ])) then
		yl_speak_up.get_variable_metadata(k_long, "default_value", true)
		return nil
	end
	-- return stored value OR the default value
	return yl_speak_up.player_vars[ k ][ player_name ]
	    or yl_speak_up.player_vars[ k ][ "$META$"][ "default_value" ]
end


yl_speak_up.get_quest_variables = function(pname, has_write_access)
	if(not(pname)) then
		return {}
	end
	local liste = {}
	-- first: list the variables owned by the player
	for k, v in pairs(yl_speak_up.player_vars) do
		local parts = string.split(k, " ")
		if(parts and parts[1] and parts[1] == "$" and parts[2] and parts[2] == pname) then
			table.insert(liste, k)
		end
	end
	-- if the player has the right privs: allow to access all other variables as well
	if( minetest.check_player_privs(pname, {npc_master=true})
	 or minetest.check_player_privs(pname, {npc_talk_master=true})
	 or minetest.check_player_privs(pname, {npc_talk_admin=true})) then
		for k, v in pairs(yl_speak_up.player_vars) do
			local parts = string.split(k, " ")
			-- variables owned by *other* players
			if(parts and parts[1] and parts[1] == "$" and parts[2] and parts[2] ~= pname) then
				table.insert(liste, k)
			end
		end
	else
		local right = "read_access"
		if(has_write_access) then
			right = "write_access"
		end
		-- insert those vars owned by other players where this one has access
		for k, v in pairs(yl_speak_up.player_vars) do
			if(   k[ "$META$"]
			  and k[ "$META$"][ right ]
			  and k[ "$META$"][ right ][ pname ]) then
				table.insert(liste, k)
			end
		end
	end
	table.sort(liste)
	return liste
end


-- which variables can player pname read and use in preconditions?
-- returns a sorted list
yl_speak_up.get_quest_variables_with_read_access = function(pname)
	return yl_speak_up.get_quest_variables(pname, false)
end


-- which variables can player pname write and use in effects/results?
yl_speak_up.get_quest_variables_with_write_access = function(pname)
	return yl_speak_up.get_quest_variables(pname, true)
end


-- variables are personalized; they are prefixed by "$ <PLAYER_NAME> <VAR_NAME>"

-- helper function;
-- strip "$ PNAME " from variable names (but only for those owned by player with name pname)
yl_speak_up.strip_pname_from_var = function(var_name, pname)
	local parts = string.split(var_name, " ")
	if(parts and parts[1] and parts[1] == "$" and parts[2] and parts[2] == pname) then
		table.remove(parts, 1) -- remove "$"
		table.remove(parts, 1) -- remove pname
		return table.concat(parts, " ")
	end
	return var_name
end


-- does the opposite of the function above; adds "$ PNAME " if needed
yl_speak_up.add_pname_to_var = function(var_name, pname)
	if(not(var_name)) then
		return ""
	end
	local parts = string.split(var_name, " ")
	if(parts and parts[1] and parts[1] ~= "$") then
		return "$ "..tostring(pname).." "..tostring(var_name)
	end
	return var_name
end


-- helper function for yl_speak_up.handle_input_fs_edit_option_related
-- and yl_speak_up.get_fs_edit_option_p_and_e_state
yl_speak_up.strip_pname_from_varlist = function(var_list, pname)
	local var_list_text = ""
	-- strip pname from the variable names
	for i, v in ipairs(var_list) do
		var_list[i] = yl_speak_up.strip_pname_from_var(v, pname)
		-- useful for presenting a list
		var_list_text = var_list_text..","..minetest.formspec_escape(tostring(var_list[i]))
	end
	return var_list_text
end


-- (partly) the opposite of the function above - add the name of the player to a variable
-- name again if needed
yl_speak_up.restore_complete_var_name = function(var_name, pname)
	local vparts = string.split(var_name or "", " ")
	-- has the player name been stripped from the variable name for better readability?
	if(vparts and #vparts > 0 and vparts[1] ~= "$") then
		return "$ "..tostring(pname).." "..table.concat(vparts, " ")
	end
	return var_name
end


-- helper function for saving NPC data;
-- this only works if *someone* is currently talking to that NPC
yl_speak_up.get_pname_for_n_id = function(n_id)
	for k, v in pairs(yl_speak_up.speak_to) do
		if(v and v.n_id and v.n_id == n_id) then
			return k
		end
	end
end


-- add or revoke read or write access to a variable
--
-- k:              name of the variable
-- pname:          the name of the player trying to grant or revoke the right
-- grant_to_pname: the name of the player who shall have that access right
-- grant_write_access:
-- 	if false: grant read access
-- 	if true:  grant write access
-- do_grant:
-- 	if false: revoke acces
-- 	if true:  grant access
-- returns true if the variable was found
yl_speak_up.manage_access_to_quest_variable = function(k, pname, grant_to_pname, what_to_grant, do_grant)
	-- only read and write access can be granted
	if(not(what_to_grant) or (what_to_grant ~= "read_access" and what_to_grant ~= "write_access")) then
		return false
	end
	return yl_speak_up.set_variable_metadata(k, pname, what_to_grant, grant_to_pname, do_grant)
end


-- a more general way of setting metadata for variables
-- in general, meta_name is a table containing entries entry_name (usually players or npc_ids)
-- with assigned values (usually true) for quick lookup
yl_speak_up.set_variable_metadata = function(k, pname, meta_name, entry_name, new_value)
	if(pname) then
		k = yl_speak_up.add_pname_to_var(k, pname)
	end
	-- delete/unset
	if(not(new_value)) then
		new_value = nil
	end
	-- the variable needs to exist
	if(not(yl_speak_up.player_vars[ k ])) then
		return false
	end
	-- make sure all the necessary tables exist
	if( not(yl_speak_up.player_vars[ k ][ "$META$" ])) then
		yl_speak_up.player_vars[ k ][ "$META$" ] = { meta_name = {} }
	end

	-- var_type (the type of the variable) is a single string
	if(meta_name == "var_type") then
		yl_speak_up.player_vars[ k ][ "$META$"][ meta_name ] = new_value
	elseif(meta_name == "default_value") then
		-- reset default value to nil with empty string:
		if(new_value == "") then
			new_value = nil
		end
		yl_speak_up.player_vars[ k ][ "$META$"][ meta_name ] = new_value
	else
		if( not(yl_speak_up.player_vars[ k ][ "$META$" ][ meta_name ])
		or type(yl_speak_up.player_vars[ k ][ "$META$" ][ meta_name ]) ~= "table") then
			yl_speak_up.player_vars[ k ][ "$META$" ][ meta_name ] = {}
		end
		yl_speak_up.player_vars[ k ][ "$META$"][ meta_name ][ entry_name ] = new_value
	end
	yl_speak_up.save_quest_variables(true)
	return true
end


-- get a list of all players who have read or write access to variable k (belonging to pname)
-- (technically a table and not a list)
yl_speak_up.get_access_list_for_var = function(k, pname, access_what)
	k = yl_speak_up.add_pname_to_var(k, pname)
	if(not(k)
	  or not(yl_speak_up.player_vars[ k ])
	  or not(yl_speak_up.player_vars[ k ][ "$META$"])
	  or not(yl_speak_up.player_vars[ k ][ "$META$"][ access_what ])) then
		return {}
	end
	return yl_speak_up.player_vars[ k ][ "$META$"][ access_what ]
end


-- helper function that searces for variables that will be replaced with their
-- values in text when displayed; helper function for yl_speak_up.update_stored_npc_data
-- (for keeping track of which NPC uses which variables)
-- changes table vars_used
yl_speak_up.find_player_vars_in_text = function(vars_used, text)
	if(not(text) or text == "") then
		return vars_used
	end
	for v in string.gmatch(text, "%$VAR ([%w%s_%-%.]+)%$") do
		-- add the $ prefix again
		vars_used["$ "..tostring(v)] = true
	end
	return vars_used
end


-- the dialog data of an NPC is saved - use this to save some statistical data
-- plus store which variables are used by this NPC
-- TODO: show this data in a formspec to admins for maintenance
yl_speak_up.update_stored_npc_data = function(n_id, dialog)
	-- in order to determine the position of the NPC, we need its object
	local pname = yl_speak_up.get_pname_for_n_id(n_id)
	local npc_pos = ""
	if(pname) then
		local obj = yl_speak_up.speak_to[pname].obj
		if(obj and obj:get_pos()) then
			npc_pos = minetest.pos_to_string(obj:get_pos())
		end
	end
	-- gather statistical data about the NPC and find out which variables it uses
	local anz_dialogs = 0
	local anz_options = 0
	local anz_preconditions = 0
	local anz_actions = 0
	local anz_effects = 0
	local anz_trades  = 0
	-- used in d.d_text dialog texts,
	-- o.o_text_when_prerequisites_met, o.o_text_when_prerequisites_not_met,
	-- preconditions and effects
	local variables_used = {}
	if(dialog and dialog.n_dialogs) then
		for d_id, d in pairs(dialog.n_dialogs) do
			anz_dialogs = anz_dialogs + 1
			if(d) then
				-- find all variables used in the text
				variables_used = yl_speak_up.find_player_vars_in_text(variables_used, d.d_text)
			end
			if(d and d.d_options) then
				for o_id, o in pairs(d.d_options) do
					anz_options = anz_options + 1
					variables_used = yl_speak_up.find_player_vars_in_text(variables_used, o.o_text_when_prerequisites_met)
					variables_used = yl_speak_up.find_player_vars_in_text(variables_used, o.o_text_when_prerequisites_not_met)
					if(o and o.o_prerequisites) then
						for p_id, p in pairs(o.o_prerequisites) do
							anz_preconditions = anz_preconditions + 1
							if(p and p.p_type and p.p_type == "state"
							  and p.p_variable and p.p_variable ~= "") then
								variables_used[ p.p_variable ] = true
							end
						end
					end
					if(o and o.actions) then
						for a_id, a_data in pairs(o.actions) do
							anz_actions = anz_actions + 1
							-- actions can have alternate_text
							variables_used = yl_speak_up.find_player_vars_in_text(variables_used, a_data.alternate_text)
						end
					end
					if(o and o.o_results) then
						for r_id, r in pairs(o.o_results) do
							anz_effects = anz_effects + 1
							if(r and r.r_type and r.r_type == "state"
							  and r.r_variable and r.r_variable ~= "") then
								variables_used[ r.r_variable ] = true
							end
							-- effects can have alternate_text
							variables_used = yl_speak_up.find_player_vars_in_text(variables_used, r.alternate_text)
						end
					end
				end
			end
		end
	end
	if(dialog and dialog.trades) then
		for trade_id, t_data in pairs(dialog.trades) do
			-- not a trade that is the action of a dialog option; only trade list trades count
			if(not(t_data.d_id)) then
				anz_trades = anz_trades + 1
			end
		end
	end
	-- add a special variable (if needed) for saving the NPC meta data
	if(not(yl_speak_up.player_vars[ "$NPC_META_DATA$" ])) then
		yl_speak_up.player_vars[ "$NPC_META_DATA$" ] = {}
	end
	yl_speak_up.player_vars[ "$NPC_META_DATA$" ][ n_id ] = {
		n_id = n_id,
		name = tostring(dialog.n_npc),
		owner = tostring(yl_speak_up.npc_owner[ n_id ]),
		may_edit = dialog.n_may_edit or {},
		pos = tostring(npc_pos),
		anz_dialogs = anz_dialogs,
		anz_options = anz_options,
		anz_preconditions = anz_preconditions,
		anz_actions = anz_actions,
		anz_effects = anz_effects,
		anz_trades = anz_trades,
		last_modified = os.date(),
	}

	-- delete all old entries that are not longer needed
	for k, v in pairs(yl_speak_up.player_vars) do
		if(not(variables_used[ k ])) then
			yl_speak_up.set_variable_metadata(k, pname, "used_by_npc", n_id, false)
		end
	end

	-- save in the variables' metadata which NPC uses it
	-- (this is what we're mostly after - know which variable is used in which NPC)
	for k, v in pairs(variables_used) do
		yl_speak_up.set_variable_metadata(k, pname, "used_by_npc", n_id, true)
	end
	-- force writing the data
	yl_speak_up.save_quest_variables(true)
end


-- which NPC do use this variable?
yl_speak_up.get_variable_metadata = function(var_name, meta_name, get_as_is)
	-- var_type (the type of the variable) is a single string
	if(meta_name and var_name and (meta_name == "var_type" or meta_name == "default_value")) then
		if(  not(yl_speak_up.player_vars[ var_name ])
		  or not(yl_speak_up.player_vars[ var_name ][ "$META$"])) then
			return nil
		end
		return yl_speak_up.player_vars[ var_name ][ "$META$"][ meta_name ]
	end
	-- no variable, or nothing stored? then it's not used by any NPC either
	if(not(var_name)
	  or  not(meta_name)
	  or  not(yl_speak_up.player_vars[ var_name ])
	  or  not(yl_speak_up.player_vars[ var_name ][ "$META$"])
	  or  not(yl_speak_up.player_vars[ var_name ][ "$META$"][ meta_name ])
	  or type(yl_speak_up.player_vars[ var_name ][ "$META$"][ meta_name ]) ~= "table") then
		return {}
	end
	-- do not transform into a list; get the table
	if(get_as_is) then
		return yl_speak_up.player_vars[ var_name ][ "$META$"][ meta_name ]
	end
	local meta_list = {}
	for k, v in pairs(yl_speak_up.player_vars[ var_name ][ "$META$"][ meta_name ]) do
		table.insert(meta_list, k)
	end
	table.sort(meta_list)
	return meta_list
end


-- show which variables the player is currently debugging
yl_speak_up.get_list_of_debugged_variables = function(pname)
	if(not(pname) or pname == "") then
		return
	end
	local res = {}
	for k, v in pairs(yl_speak_up.player_vars) do
		if(k and v and v[ "$META$" ] and v[ "$META$" ][ "debug" ]) then
			-- this will be used in a table presented to the player
			table.insert(res, minetest.formspec_escape(k))
		end
	end
	return res
end


-- helper function; time is sometimes needed
yl_speak_up.get_time_in_seconds = function()
	return math.floor(minetest.get_us_time()/1000000)
end


-----------------------------------------------------------------------------
-- Quests as such (up until here we mostly dealt with variables)
-----------------------------------------------------------------------------

-- uses yl_speak_up.quest_path
-- uses yl_speak_up.number_of_quests = yl_speak_up.modstorage:get_int("max_quest_id") or 0

-- table containing the quest data with q_id as index
yl_speak_up.quests = {}


-- store quest q_id to disc
yl_speak_up.save_quest = function(q_id)
	local json = minetest.write_json(yl_speak_up.quests[q_id])
	-- actually store it on disk
	local file_name = yl_speak_up.worldpath..yl_speak_up.quest_path..DIR_DELIM..q_id..".json"
	minetest.safe_file_write(file_name, json)
end



-- read quest q_id from disc
yl_speak_up.load_quest = function(q_id)
	-- load the data from the file
	local file_name = yl_speak_up.worldpath..yl_speak_up.quest_path..DIR_DELIM..q_id..".json"
	local file, err = io.open(file_name, "r")
	if err then
		return
	end
	io.input(file)
	local text = io.read()
	-- all values saved in the tables as such are strings
	local data = minetest.parse_json(text, "$NIL_VALUE$")
	io.close(file)

	if(type(data) ~= "table") then
		return
	end
	yl_speak_up.quests[q_id] = yl_speak_up.handle_json_nil_values(data)
	-- make sure all required fields exist
	local quest = yl_speak_up.quests[q_id]
	if(quest and not(quest.step_data)) then
		quest.step_data = {}
	end
	if(quest and not(quest.npcs)) then
		quest.npcs = {}
	end
	if(quest and not(quest.locations)) then
		quest.locations = {}
	end
	if(quest) then
		for s, d in pairs(quest.step_data) do
			if(not(d.where)) then
				quest.step_data[s].where = {}
			end
			if(not(d.one_step_required)) then
				quest.step_data[s].one_step_required = {}
			end
			if(not(d.all_steps_required)) then
				quest.step_data[s].all_steps_required = {}
			end
		end
	end
	yl_speak_up.quests[q_id] = quest
	return yl_speak_up.quests[q_id]
end


-- get data of quest q_id
yl_speak_up.get_quest = function(q_id)
	if(not(yl_speak_up.quests[q_id])) then
		yl_speak_up.load_quest(q_id)
	end
	return yl_speak_up.quests[q_id]
end


-- add/create a new quest
-- a quest is based on a variable; the variable is needed to store quest progress;
-- as this variable is of type integer, quests can only be linear;
-- in order to offer alternatives, players can add as many quests as they want and
-- make them depend on each other
yl_speak_up.add_quest = function(owner_name, variable_name, quest_name, descr_long, descr_short, comment)
	-- add a special variable (if needed) for saving quest meta data
	if(not(yl_speak_up.player_vars[ "$QUEST_META_DATA$" ])) then
		yl_speak_up.player_vars[ "$QUEST_META_DATA$" ] = {}
		yl_speak_up.save_quest_variables(true)
	end

	if(not(variable_name) or variable_name == "") then
		return "Missing name of variable."
	end
	-- determine the full name of the variable used to store quest progress
	local var_name = yl_speak_up.add_pname_to_var(variable_name, owner_name)
	-- if it is a new variable: make sure it gets created
	if(not(yl_speak_up.player_vars[var_name])) then
		-- create the new varialbe
		yl_speak_up.add_quest_variable(owner_name, variable_name)
	else
		-- if it exists already: make sure it is of a type that can be used
		local var_type = yl_speak_up.get_variable_metadata(var_name, "var_type")
		if("var_type" == "time_based") then
			return "Variable already used as a timer."
		elseif("var_type" == "quest") then
			return "Variable already used by another quest."
		end
	end
	-- set the variable for the quest creator to 0 - so that it's possible to check for
	-- var_name is set (to a value) in a precondition and thus only allow the quest creator
	-- to test the quest in the beginning
	yl_speak_up.set_quest_variable_value(owner_name, var_name, 0)
	-- set the variable type to quest
	yl_speak_up.set_variable_metadata(var_name, owner_name, "var_type", nil, "quest")
	-- get a uniq ID for storing this quest (mostly needed for creating a safe file name)
	local quest_nr = yl_speak_up.number_of_quests + 1
	yl_speak_up.number_of_quests = quest_nr
	yl_speak_up.modstorage:set_int("max_quest_nr", yl_speak_up.number_of_quests)
	-- store this number in the variable $META$ data
	yl_speak_up.set_variable_metadata(var_name, owner_name, "quest_data", "quest_nr", quest_nr)
	-- the list of quest steps is stored in the variables' metadata for quicker access
	-- (this way we won't have to load the quest file if we want to check a precondition
	--  or update the variable value to the next quest step)
	--  TODO: store those in the quest file
	yl_speak_up.set_variable_metadata(var_name, owner_name, "quest_data", "steps", {"start","finish"})

	-- create the quest data structure
	local quest = {}
	quest.nr = quest_nr
	quest.id = "q_"..quest_nr -- quest ID
	quest.name = quest_name   -- human-readable name of the quest
	quest.description = (descr_long or "")
				  -- long description of what the quest is about
	quest.short_desc = (descr_short or  "")
				  -- a short description of this quest which may later be used to
				  -- advertise for the quest in a quest log
	quest.comment = (comment or "")
				  -- comment to other programmers who might want to maintain the
				  -- quest later on
	quest.owner = owner_name  -- creator of the quest
	quest.var_name = var_name -- name of the variable where progress is stored for each player
--	quest.steps = {           -- list of names (strings) of the quest steps
--		"start",	  -- the quest needs to start somehow
--		"finish"}	  -- and it needs to finish somehow
--	the following things can be determined automaticly, BUT: in order to PLAN a future
--	quest, it is easier to gather information here first
	quest.step_data = {}      -- table containing information about a quest step (=key)
				  -- this may also be information about WHERE a quest step shall
				  -- take place
	quest.subquests = {}      -- list of other quest_ids that contribute to this quest
				  -- -> determined from quests.npcs and quests.locations
	quest.is_subquest_of = {} -- list of quest_ids this quest contributes to
				  -- -> determined from quests.npcs and quests.locations
	quest.npcs = {}           -- list of NPC that contribute to this quest
				  -- -> derived from quest.var_name
				  -- --> or derived from quest.step_data.where
	quest.locations = {}      -- list of locations that contribute to this quest
				  -- -> derived from quest.var_name
				  -- --> or derived from quest.step_data.where
	quest.items = {}          -- data of quest items created and accepted
				  -- -> derived from the quest steps
	quest.rewards = {}        -- list of rewards (item stacks) for this ques
	quest.testers = {}        -- list of player names that can test the quest
				  -- -> during the created/testing phase: any player for which
				  --    quest.var_name is set to a value
	quest.solved_by = {}      -- list of names of players that solved the quest at least once
	quest.state = "created"   -- state of the quest:
				  --   created: only the creator can do it
				  --   testing: players listed in quest.testers can do the quest
				  --   open:    *all* players with interact can try to solve the quest
				  --            *AND* changes to the quest are now impossible (apart from
				  --            changing texts in the NPC)
				  --   official: official server quest; NPC can create items out of thin air
	-- store the new quest in the quest table
	yl_speak_up.quests[quest.id] = quest
	-- and store it on disc
	yl_speak_up.save_quest(quest.id)
	return "OK"
end


-- delete a quest if possible
yl_speak_up.del_quest = function(q_id, pname)
	if(not(q_id)) then
		return "No quest ID given. Quest not found."
	end
	local quest = yl_speak_up.load_quest(q_id)
	if(not(quest)) then
		return "Quest "..tostring(q_id).." does not exist."
	end
	if(quest.owner ~= pname
	  and not(minetest.check_player_privs(pname, {npc_master=true}))
	  and not(minetest.check_player_privs(pname, {npc_talk_master=true}))
	  and not(minetest.check_player_privs(pname, {npc_talk_admin=true}))) then
		return "Quest "..tostring(q_id).." is owned by "..tostring(quest.owner)..
			".\n You can't delete it."
	end
	if(quest.state ~= "created" and quest.state ~= "testing") then
		return "Quest "..tostring(q_id).." is in stage \""..tostring(quest.state)..
			"\".\n Only quests in state \"created\" or \"testing\" can be deleted."
	end
	if(#quest.is_subquest_of > 0) then
		return "Quest "..tostring(q_id).." is used by the following subquests:\n"..
			table.concat(quest.subquests, ", ")..
			".\nPlease remove the subquests first!"
	end

	for k, v in pairs(quest.step_data) do
		if(v) then
			return "Quest "..tostring(q_id).." contains at least one remaining quest step.\n"..
			"Please remove all steps first!"
		end
	end

	-- TODO: actually delete the file?
	-- TODO: set the quest variable back to no type
	-- TODO: delete (empty?) quest variable?  yl_speak_up.del_quest_variable(pname, entry_name, nil)
	return "OK"
end


-- returns a list of all quest IDs to which the player has write access
-- TODO: function is unused
yl_speak_up.get_quest_owner_list = function(pname)
	local var_list = yl_speak_up.get_quest_variables_with_write_access(pname)
	local quest_id_list = {}
	for i, var_name in ipairs(var_list) do
		local t = yl_speak_up.get_variable_metadata(var_name, "var_type")
		if(t and t == "quest") then
			local data = yl_speak_up.get_variable_metadata(var_name, "quest_data", true)
			if(data and data["quest_nr"]) then
				local q_id = "q_"..tostring(data["quest_nr"])
				yl_speak_up.load_quest(q_id)
				-- offer the quest only if it was loaded successfully
				if(yl_speak_up.quests[q_id]) then
					table.insert(quest_id_list, q_id)
				end
			end
		end
	end
	return quest_id_list
end


yl_speak_up.get_sorted_quest_list = function(pname)
	local quest_list = {}
	local has_privs = (minetest.check_player_privs(pname, {npc_master=true})
			or minetest.check_player_privs(pname, {npc_talk_master=true})
			or minetest.check_player_privs(pname, {npc_talk_admin=true}))
	for q_id, data in pairs(yl_speak_up.quests) do
		if(data and data.var_name) then
			if(has_privs
			  or(data.owner and data.owner == pname)
			  or(table.indexof(
					yl_speak_up.get_access_list_for_var(
						data.var_name, pname, "write_access") or {}) ~= -1)) then
				table.insert(quest_list, data.var_name)
			end
		end
	end
	yl_speak_up.strip_pname_from_varlist(quest_list, pname)
	table.sort(quest_list)
	return quest_list
end



-- quests have a name and a variable which stores their data
-- this returns the q_id (index in the quest table) based on the variable name
yl_speak_up.get_quest_id_by_var_name = function(var_name, owner_name)
	local var_name = yl_speak_up.add_pname_to_var(var_name, owner_name)
	-- find out which quest we're talking about
	for q_id, quest in pairs(yl_speak_up.quests) do
		if(quest.var_name == var_name) then
			return q_id
		end
	end
	-- TODO or we may have a leftover variable with no quest information stored
--	local var_type = yl_speak_up.get_variable_metadata(var_name, "var_type")
--	if("var_type" == "quest") then
--		-- this is no longer a quest variable - the quest is long gone
--		yl_speak_up.set_variable_metadata(var_name, owner_name, "var_type", nil, "string")
--		yl_speak_up.set_variable_metadata(var_name, owner_name, "quest_data", "quest_nr", nil)
--		yl_speak_up.set_variable_metadata(var_name, owner_name, "quest_data", "steps", nil)
--	end
	return nil
end


-- quests can also be identified by their name
-- this returns the q_id (index in the quest table) based on the quest name
yl_speak_up.get_quest_id_by_quest_name = function(quest_name)
	-- find out which quest we're talking about
	for q_id, quest in pairs(yl_speak_up.quests) do
		if(quest.name == quest_name) then
			return q_id
		end
	end
	return nil
end


-- finds out if player pname is allowed to view (read_only is true)
-- or edit (read_only is false) the quest q_id
yl_speak_up.quest_allow_access = function(q_id, pname, read_only)
	-- no quest with that variable as base found
	if(not(q_id) or not(yl_speak_up.quests[q_id])) then
		return "Quest not found (id: "..tostring(q_id)..")."
	end
	local quest = yl_speak_up.quests[q_id]
	-- check if the player has access rights to that quest
	if(quest.owner ~= pname
	  and not(minetest.check_player_privs(pname, {npc_master=true}))
	  and not(minetest.check_player_privs(pname, {npc_talk_master=true}))
	  and not(minetest.check_player_privs(pname, {npc_talk_admin=true}))) then
		-- the player may have suitable privs (check access to the variable)
		local access_what = "write_access"
		if(read_only) then
			access_what = "read_access"
		end
		local allowed = yl_speak_up.get_access_list_for_var(quest.var_name, "", access_what)
		if(table.indexof(allowed, pname) == -1) then
			return "Sorry. You have no write access to quest \""..tostring(quest.name).."\" "..
				"["..tostring(k).."]."
		end
	end
	-- quests that are already open to the public cannot be changed anymore
	-- as that would cause chaos; only in "created" and "testing" stage it's
	-- possible to change quest steps
	if(not(read_only) and (quest.state == "open" or quest.state == "official")) then
		return "The quest is in state \""..tostring(quest.state).."\". Quests in such "..
			"a state cannot be changed/extended as that would confuse players. "..
			"Reset quest state first if changes are unavoidable."
	end
	return "OK"
end


-- add a quest step to a quest
yl_speak_up.quest_step_add_quest_step = function(pname, q_id, quest_step_name)
	local error_msg = yl_speak_up.quest_allow_access(q_id, pname, false)
	if(error_msg ~= "OK") then
		return error_msg
	end
	if(not(quest_step_name) or quest_step_name == ""
	  or string.len(quest_step_name) < 2 or string.len(quest_step_name) > 70) then
		return "No name for this quest step given or too long (>70) or too short (<2 characters)."
	end
	if(not(yl_speak_up.quests[q_id].step_data)) then
		yl_speak_up.quests[q_id].step_data = {}
	end
	-- create an entry for the quest step if needed
	if(not(yl_speak_up.quests[q_id].step_data[quest_step_name])) then
		yl_speak_up.quests[q_id].step_data[quest_step_name] = {
			-- where (NPCs, locations) can this quest step be set?
			where = {},
			-- at least one of this quest steps has to be achieved before this one is possible
			one_step_required = {},
			-- all of these quest steps have to be achieved before this one is possible
			all_steps_required = {}
			}
			yl_speak_up.save_quest(q_id)
	end
	-- return OK even if the quest step existed already
	return "OK"
end


-- delete a quest step - but only if it's not used
yl_speak_up.quest_step_del_quest_step = function(pname, q_id, quest_step_name)
	local error_msg = yl_speak_up.quest_allow_access(q_id, pname, false)
	if(error_msg ~= "OK") then
		return error_msg
	end
	if(not(quest_step_name)
	  or not(yl_speak_up.quests[q_id].step_data)
	  or not(yl_speak_up.quests[q_id].step_data[quest_step_name])) then
		return "OK"
	end
	-- the quest step exists; can we delete it?
	local quest_step = yl_speak_up.quests[q_id].step_data[quest_step_name]
	local anz_where = 0
	for k, _ in pairs(quest_step.where or {}) do
		anz_where = anz_where + 1
	end
	if(anz_where > 0) then
		return "This quest step is used/set by "..tostring(anz_where)..
			" NPCs and/or locations.\nRemove them from this quest step first!"
	end
	-- is this the previous quest step of another step?
	for sn, step_data in pairs(yl_speak_up.quests[q_id].step_data) do
		if(step_data and step_data.previous_step and step_data.previous_step == quest_step_name) then
			return "Quest step \""..tostring(sn).."\" names this quest step that you want "..
				"to delete as its previous step. Please remove that requirement first "..
				"for quest step \""..tostring(sn).."\" before deleting this step here."
		end
		if(step_data and step_data.further_required_steps
		  and table.indexof(step_data.further_required_steps, quest_step_name) ~= -1) then
			return "Quest step \""..tostring(sn).."\" gives this quest step that you want "..
				"to delete as one of the further steps required to reach it. Please "..
				"remove that requirement first "..
				"for quest step \""..tostring(sn).."\" before deleting this step here."
		end
		-- offered_until_quest_step_reached would be no problem/hinderance and doesn't need checking
	end
	yl_speak_up.quests[q_id].step_data[quest_step_name] = nil
	yl_speak_up.save_quest(q_id)
	return "OK"
end


-- turn a location {n_id=.., d_id=.., c_id=..} or position into a uniq string
yl_speak_up.get_location_id = function(loc)
	if(not(loc) or type(loc) ~= "table") then
		return nil
	end
	if(loc.is_block and loc.n_id and loc.d_id and loc.o_id) then
		return "POS "..tostring(loc.n_id).." "..tostring(loc.d_id).." "..tostring(loc.o_id)
	-- if it's an NPC:
	elseif(loc.n_id and string.sub(loc.n_id, 1, 2) == "n_" and loc.d_id and loc.o_id) then
		return "NPC "..tostring(loc.n_id).." "..tostring(loc.d_id).." "..tostring(loc.o_id)
	else
		return nil
	end
end


-- add an NPC or location to a quest step (quest_step.where = list of such locations)
-- Note: This is for NPC and locations that SET this very quest step. They ought to be listed here.
-- new_location has to be a table, and new_loc_id an ID to avoid duplicates
-- for NPC, new_loc_id ought to look like this:  "NPC <n_id> <d_id> <o_id>"
yl_speak_up.quest_step_add_where = function(pname, q_id, quest_step_name, new_location)
	local error_msg = yl_speak_up.quest_allow_access(q_id, pname, false)
	if(error_msg ~= "OK") then
		return error_msg
	end
	local step_data = yl_speak_up.quests[q_id].step_data[quest_step_name]
	if(not(step_data)) then
		return "Quest step \""..tostring(quest_step_name).."\" does not exist."
	end
	if(not(step_data.where)) then
		step_data.where = {}
	end
	local new_loc_id = yl_speak_up.get_location_id(new_location)
	if(not(new_loc_id)) then
		return "Failed to create location ID for this location/NPC."
	end
	-- overwrite existing/old entries
	yl_speak_up.quests[q_id].step_data[quest_step_name].where[new_loc_id] = new_location
	-- make sure quest.npcs or quest.locations contains this entry
	local n_id = new_location.n_id or "?"
	if(string.sub(n_id, 1, 2) == "n_") then
		-- only npcs that are not yet added (and we store IDs without n_ prefix)
		local id = tonumber(string.sub(n_id, 3))
		if(id and table.indexof(yl_speak_up.quests[q_id].npcs or {}, id) == -1) then
			table.insert(yl_speak_up.quests[q_id].npcs, id)
		end
	elseif(string.sub(n_id, 1, 1) == "p"
	       and table.indexof(yl_speak_up.quests[q_id].locations or {}, n_id) == -1) then
		table.insert(yl_speak_up.quests[q_id].locations, n_id)
	end
	yl_speak_up.save_quest(q_id)
	-- return OK even if the quest step existed already
	return "OK"
end


-- delete a quest step location with the id location_id
yl_speak_up.quest_step_del_where = function(pname, q_id, quest_step_name, old_location)
	local error_msg = yl_speak_up.quest_allow_access(q_id, pname, false)
	if(error_msg ~= "OK") then
		return error_msg
	end
	local quest_step = yl_speak_up.quests[q_id].step_data[quest_step_name]
	if(not(quest_step)) then
		return "Quest step \""..tostring(quest_step_name).."\" does not exist."
	end
	local loc_id = yl_speak_up.get_location_id(old_location)
	if(not(loc_id)) then
		return "Failed to create location ID for this location/NPC."
	end
	if(not(yl_speak_up.quests[q_id].step_data[quest_step_name])) then
		yl_speak_up.quests[q_id].step_data[quest_step_name].where = {}
	end
	-- delete the quest step location
	yl_speak_up.quests[q_id].step_data[quest_step_name].where[loc_id] = nil
	yl_speak_up.save_quest(q_id)
	return "OK"
end


-- TODO: quest_step: previous_step -> one_step_required
-- TODO: quest_step: further_required_steps -> all_steps_required
-- TODO: quest_step: offered_until_quest_step_reached


-- called for example by yl_speak_up.eval_all_preconditions to see if the player
-- can reach quest_step in quest quest_id
yl_speak_up.quest_step_possible = function(player, quest_step, quest_id, n_id, d_id, o_id)
	-- TODO: evaluate that
	-- TODO: the *previous* quest step needs to have been reached
	-- TODO: the quest step *after* this quest step hasn't been reached (does that work?)
	-- TODO: the quest needs to be owned by the player, the player be an authorized tester,
	--       or the quest be in the official released stage
--	minetest.chat_send_player("singleplayer", "TESTING quest step "..tostring(quest_step).." for quest "..tostring(quest_id))
	return true
end


-- sets quest_step in quest_id for player as achieved
-- called for example by yl_speak_up.execute_all_relevant_effects if the action was
yl_speak_up.quest_step_reached = function(player, quest_step, quest_id, n_id, d_id, o_id)
	-- TODO: check again if it's possible? we don't want to step back in the quest_step chain
	-- TODO: actually store the quest progress
--	minetest.chat_send_player("singleplayer", "SETTING quest step "..tostring(quest_step).." for quest "..tostring(quest_id))
end



-- load all known quests
yl_speak_up.load_all_quests = function()
	for var_name, var_data in pairs(yl_speak_up.player_vars) do
		local var_type = yl_speak_up.get_variable_metadata(var_name, "var_type")
		if(var_type == "quest") then
			local data = yl_speak_up.get_variable_metadata(var_name, "quest_data", true)
			if(data and data["quest_nr"]) then
				yl_speak_up.load_quest("q_"..tostring(data["quest_nr"]))
			end
		end
	end
end

-- do so on startup and reload
yl_speak_up.load_all_quests()
