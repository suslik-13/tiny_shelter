-- the command to add new generic dialogs is implemented in yl_speak_up.command_npc_talk_generic

-- this table holds all generic dialogs with indices
--   generic_dialog[n_id][d_id_n_id]
yl_speak_up.generic_dialogs = {}
-- this table holds the preconditions for all generic dialogs
-- so that we know which ones are relevant for a particular NPC
yl_speak_up.generic_dialog_conditions = {}
-- the start dialog of a generic dialog needs to have just one option,
-- and that option has to be an autoanswer; all those options of the
-- dialogs that follow this start dialog are stored in dialog
--   "d_generic_start_dialog"


-- a chat command to grant or deny or disallow npc these privs;
-- it is not checked if the NPC exists
-- used by register_once.lua
yl_speak_up.command_npc_talk_generic = function(pname, param)
	if(not(param) or param == "") then
		minetest.chat_send_player(pname, "Usage: [list|add|remove|reload] <n_id>")
		return
	end
	local parts = string.split(param, " ")
	local s = yl_speak_up.modstorage:get_string("generic_npc_list") or ""
	local generic_npc_list = string.split(s, " ")
	if((parts[1] == "add" or parts[1] == "remove") and #parts == 2) then
		local do_reload = false
		local i = table.indexof(generic_npc_list, parts[2])
		if(parts[1] == "add" and i == -1) then
			local n_id = parts[2]
			table.insert(generic_npc_list, n_id)
			local dialog = yl_speak_up.load_dialog(n_id, false)
			local res = yl_speak_up.check_and_add_as_generic_dialog(dialog, n_id)
			minetest.chat_send_player(pname, "Adding NPC "..tostring(n_id).."..: "..tostring(res))
			do_reload = true
		elseif(parts[1] == "add" and i ~= -1) then
			minetest.chat_send_player(pname, "NPC "..tostring(parts[2])..
				" is already registered as a generic NPC. You may try to "..
				"remove and add it again if something went wrong.")
		elseif(parts[1] == "remove" and i ~= -1) then
			table.remove(generic_npc_list, i)
			minetest.chat_send_player(pname, "Removing NPC "..tostring(parts[2]).." ..")
			do_reload = true
			yl_speak_up.generic_dialogs[parts[2]] = nil
			yl_speak_up.generic_dialog_conditions[parts[2]] = nil
		elseif(parts[1] == "reload") then
			do_reload = true
		end
		-- actually reload the NPC list
		if(do_reload) then
			-- store the updated version
			yl_speak_up.modstorage:set_string("generic_npc_list",
				table.concat(generic_npc_list, " "))
			yl_speak_up.load_generic_dialogs()
		end
	elseif(parts[1] ~= "list" and parts[1] ~= "reload") then
		minetest.chat_send_player(pname, "Usage: [list|add|remove|reload] <n_id>")
		return
	end
	local liste = {}
	for n_id, v in pairs(yl_speak_up.generic_dialogs) do
		table.insert(liste, n_id)
	end
	if(#liste < 1) then
		minetest.chat_send_player(pname, "No NPC provides generic dialogs.")
	else
		minetest.chat_send_player(pname, "These NPC provide generic dialogs: "..
			table.concat(liste, ", ")..".")
	end
end


-- this is similar to the function
-- 	yl_speak_up.calculate_displayable_options
-- in exec_eval_preconditions.lua
-- - except that some things like sorting or extensive debug output can be skipped
yl_speak_up.calculate_available_generic_dialogs = function(current_n_id, player)
	-- if this is a generic npc: don't inject anything
	if(yl_speak_up.generic_dialogs[current_n_id]) then
		return {}
	end
	local pname = player:get_player_name()
	-- the IDs of all those NPCs whose dialogs can be added
	local n_id_list = {}

	-- cache the properties of the NPC
	local properties = yl_speak_up.get_npc_properties(pname)

	-- Let's go through all the options and see if we need to display them to the user
	-- check all options: option key (n_id), option value/data (list of preconditions)
	for n_id, prereq in pairs(yl_speak_up.generic_dialog_conditions) do
		-- if true: this generic dialog fits and will be added
		local include_this = true
		-- check all preconditions: precondition key, precondition data/data
		for p_id, p in pairs(prereq) do
			-- as soon as we locate one precondition that is false, this option (and thus the
			-- generic dialog it stands for) cannot be included
			if(not(include_this)
			  -- only certain types of preconditions are allowed because the other ones would
			  -- be too expensive or make no sense here
			  or not(yl_speak_up.eval_precondition(player, current_n_id, p, nil, properties))) then
				include_this = false
				break
			end
		end
		if(include_this) then
			table.insert(n_id_list, n_id)
		end
	end
	return n_id_list
end


-- helper function for yl_speak_up.check_and_add_as_generic_dialog;
-- appends append-str to data[field_name] if the name of the
-- target dialog stored there needs to be rewritten
yl_speak_up.rewrite_dialog_id = function(data, field_name, start_dialog, append_str)
	if(not(data) or not(data[field_name])) then
		return nil
	end
	-- we need this to point to a *common* start dialog
	if(data[field_name] == start_dialog
	  or data[field_name]..append_str == start_dialog) then
		return "d_generic_start_dialog"
	elseif(data[field_name] ~= "d_got_item" and data[field_name] ~= "d_end") then
		return data[field_name]..append_str
	end
	return data[field_name]
end


-- helper function for yl_speak_up.check_and_add_as_generic_dialog(..);
-- has to be called for all those dialogs where options from the generic
-- NPC need to be injected in a dialog from the special NPC (and not in
-- dialogs that are specific to the generic NPC)
yl_speak_up.generic_dialog_rewrite_options = function(n_id, dialog_name, append_str, anz_generic)
	if(not(yl_speak_up.generic_dialogs[n_id])
	  or not(yl_speak_up.generic_dialogs[n_id][dialog_name])) then
		return
	end
	local options = yl_speak_up.generic_dialogs[n_id][dialog_name].d_options
	if(not(options)) then
		return
	end
	local new_options = {}
	local anz_options = 0
	for o_id, o in pairs(options) do
		-- o_sort needs to be set accordingly
		local o_sort = tonumber(o.o_sort or "0")
		if(not(o_sort) or o_sort < 0) then
			o_sort = anz_options
		end
		-- make sure there is enough room for internal sorting
		o.o_sort = o_sort + (anz_generic * 100000)
		anz_options = anz_options + 1

		-- adjust o_id
		o.o_id = o_id..append_str
		-- mark this option as generic
		o.is_generic = append_str
		-- the options of the first dialog need to be renamed to r.r_id_n_id to avoid duplicates
		new_options[o_id..append_str] = o
		-- TODO: there may be preconditions refering this option which also might need changing
	end
	-- store the new options
	yl_speak_up.generic_dialogs[n_id][dialog_name].d_options = new_options
end


-- returns "OK" if the dialog can be used as a generic dialog, that is:
-- * has at least one dialog
yl_speak_up.check_and_add_as_generic_dialog = function(dialog, n_id)
	yl_speak_up.generic_dialogs[n_id] = nil
	yl_speak_up.generic_dialog_conditions[n_id] = nil
	-- we do *not* want d_dynamic in generic dialogs (each NPC will get its own anyway):
	dialog.n_dialogs["d_dynamic"] = nil
	-- get the start dialog
	local d_id = yl_speak_up.get_start_dialog_id(dialog)
	if(not(d_id)
	  or not(dialog.n_dialogs[d_id])
	  or not(dialog.n_dialogs[d_id].d_options)) then
		return "No start dialog found."
	end
	-- the start dialog shall have exactly one option/answer
	local one_option = nil
	local anz_options = 0
	for o_id, o in pairs(dialog.n_dialogs[d_id].d_options) do
		anz_options = anz_options + 1
		one_option = o_id
	end
	if(anz_options ~= 1) then
		return "The start dialog has more than one option/answer."
	end
	local option = dialog.n_dialogs[d_id].d_options[one_option]
	-- and this one option/answer shall be of the type autoanswer
	if(not(option) or not(option.o_autoanswer) or not(option.o_autoanswer ~= "1")) then
		return "The option of the start dialog is set to \"by clicking manually\" instead "..
			"of \"automatcily\"."
	end
	-- only some few types are allowed for preconditions
	-- (these checks have to be cheap and quick, and any npc inventory is not available
	-- at the time of these checks; let alone any block inventories or the like)
	local prereq = option.o_prerequisites
	if(prereq) then
		for p_id, p in pairs(prereq) do
			if(p.p_type ~= "state" and p.p_type ~= "player_inv" and p.p_type ~= "evaluate"
			   and p.p_type ~= "property" and p.p_type ~= "function"
			   and p.p_type ~= "true" and p.p_type ~= "false") then
				return "Precondition "..tostring(p_id)..
					" of option "..tostring(one_option)..
					" of dialog "..tostring(d_id)..
					" has unsupported type: "..tostring(p.p_type)..
					". Supported types: state, property, evaluate, function and player_inv."
			end
		end
	end
	-- the original start dialog of the generic dialog, containing only the
	-- one automatic option
	local orig_start_dialog = d_id

	-- not everything is suitable for generic dialogs
	-- for all dialogs (doesn't hurt here to check the start dialog again):
	for d_id, d in pairs(dialog.n_dialogs) do
		-- if there are any options
		if(d.d_options) then
			-- for all options:
			for o_id, o in pairs(d.d_options) do
				-- if there are any preconditions:
				if(o.o_prerequisites) then
					-- for all preconditions:
					for p_id, p in pairs(o.o_prerequisites) do
						-- makes no sense: block, trade, npc_inv, npc_inv, block_inv
						if(   p.p_type ~= "state"
						  and p.p_type ~= "player_inv"
						  and p.p_type ~= "player_offered_item"
						  and p.p_type ~= "function"
						  and p.p_type ~= "evaluate"
						  and p.p_type ~= "property"
						  -- depends on the preconditions of another option
						  and p.p_type ~= "other"
						  and p.p_type ~= "true"
						  and p.p_type ~= "false") then
							return "Precondition "..tostring(p_id)..
								" of option "..tostring(o_id)..
								" of dialog "..tostring(d_id)..
								" has (for generic dialogs) unsupported "..
								"type: "..tostring(p.p_type).."."
						end
					end
				end
				-- actions ought to be fully supported but MUST NOT access the NPCs inventory;
				-- if there are any effects/results:
				if(o.o_results) then
					-- for all actions (there ought to be only one)
					for r_id, r in pairs(o.o_results) do
						-- makes no sense:
						--   block, put_into_block_inv, take_from_block_inv,
						--   craft
						if(   r.r_type ~= "state"
						  -- only accepting or refusing makes sense here
						  and r.r_type ~= "deal_with_offered_item"
						  and r.r_type ~= "on_failure"
						  and r.r_type ~= "chat_all"
						  and r.r_type ~= "give_item"
						  and r.r_type ~= "take_item"
						  and r.r_type ~= "move"
						  and r.r_type ~= "function"
						  and r.r_type ~= "evaluate"
						  and r.r_type ~= "dialog"
						) then
							return "Effect "..tostring(r_id)..
								" of option "..tostring(o_id)..
								" of dialog "..tostring(d_id)..
								" has (for generic dialogs) unsupported "..
								"type: "..tostring(r.r_type).."."
						end
					end
				end
			end
		end
	end

	-- this looks good; we may actually add these dialogs;
	-- if data for this generic dialog (from this NPC) was stored before: reset it
	yl_speak_up.generic_dialogs[n_id] = {}

	-- store the prerequirements for this generic dialog
	yl_speak_up.generic_dialog_conditions[n_id] = option.o_prerequisites

	-- some modifications are necessary because dialog IDs are only uniq regarding
	-- *one* NPC; for example, the dialog d_1 will be present in almost all NPC
	-- we need to append a uniq postfix to all IDs
	--    - except for d_got_item; that needs diffrent treatment
	--    - and except for the start_dialog
	local append_str = "_"..tostring(n_id)

	-- this is the actual dialog where all those options of intrest are that
	-- later on need to be injected into the receiving NPC
	local start_dialog = nil
	local effects = option.o_results
	if(effects) then
		for r_id, r in pairs(option.o_results) do
			if(r.r_type == "dialog") then
				-- the start_dialog will soon be renamed for uniqueness; so store that name
				start_dialog = r.r_value..append_str
			end
		end
	end

	-- if no first dialog has been found or if the option loops back to
	-- the first one: give up
	if(not(start_dialog)
	  or start_dialog == orig_start_dialog
	  or start_dialog == "d_got_item"..append_str) then
		yl_speak_up.generic_dialog_conditions[n_id] = {}
		return "Option of first dialog loops back to first dialog. Giving up."
	end

	-- we need to make sure that o_sort and d_sort make some sense;
	-- anz_generic is multipiled with a factor later on, so we want at least 1 here
	-- so that the values of the inserted dialogs are sufficiently high compared to
	-- the "normal" ones of the npc
	local anz_generic = 1
	for n_id, d in pairs(yl_speak_up.generic_dialogs) do
		anz_generic = anz_generic + 1
	end

	-- for setting d_sort to a useful, non-conflicting value
	local anz_dialogs = 0
	-- we rename the dialogs where necessary;
	-- we also mark each dialog, precondition, action and effect with a
	--    ?_is_generic = append_str entry so that it can later be easily recognized
	-- and any interactions with the inventory of the NPC be avoided
	for d_id, d in pairs(dialog.n_dialogs) do
		-- if there are any options
		if(d.d_options) then
			-- for all options:
			for o_id, o in pairs(d.d_options) do
				-- if there are any preconditions:
				if(o.o_prerequisites) then
					-- for all preconditions:
					for p_id, p in pairs(o.o_prerequisites) do
						-- this comes from a generic dialog
						p.p_is_generic = append_str
						if(p.p_type == "other") then
							-- ID of the other dialog that is checked
							p.p_value = yl_speak_up.rewrite_dialog_id(p,
									"p_value", start_dialog, append_str)
						end
					end
				end
				-- if there are any actions:
				if(o.actions) then
					-- for all actions (usually just one):
					for a_id, a in pairs(o.actions) do
						-- this comes from a generic dialog
						a.a_is_generic = append_str
						-- ID of the target dialog when the action failed
						a.a_on_failure = yl_speak_up.rewrite_dialog_id(a,
									"a_on_failure", start_dialog, append_str)
					end
				end
				-- if there are any effects/results:
				if(o.o_results) then
					-- for all actions (there ought to be only one)
					for r_id, r in pairs(o.o_results) do
						-- this comes from a generic dialog
						r.r_is_generic = append_str
						if(r.r_type == "on_failure") then
							r.r_on_failure = yl_speak_up.rewrite_dialog_id(r,
									"r_on_failure", start_dialog, append_str)
						elseif(r.r_type=="dialog") then
							-- ID of the normal target dialog
							r.r_value = yl_speak_up.rewrite_dialog_id(r,
									"r_value", start_dialog, append_str)
						end
					end
				end
			end
		end
		-- d_sort needs to be set accordingly
		local d_sort = tonumber(d.d_sort or "0")
		if(not(d_sort) or d_sort < 0) then
			d_sort = anz_dialogs
		end
		-- make sure there is enough room for internal sorting
		d.d_sort = d_sort + (anz_generic * 100000)
		anz_dialogs = anz_dialogs + 1

		-- remember where this generic dialog comes from and that it is a generic one
		d.is_generic = append_str
		-- store this new dialog with its new ID
		-- Note: This may also create d_got_item_n_<id>
		d.d_id = yl_speak_up.rewrite_dialog_id(d, "d_id", start_dialog, append_str)
		-- the dialog ID will only be equal to start_dialog after adding append_str,
		-- so...check again here
		if(d.d_id == start_dialog) then
			d.d_id = "d_generic_start_dialog"
		end
		yl_speak_up.generic_dialogs[n_id][d.d_id] = d
	end

	start_dialog = "d_generic_start_dialog"
	-- make the necessary adjustments for the options of the start_dialog
	local options = yl_speak_up.generic_dialogs[n_id][start_dialog].d_options
	if(not(options)) then
		return "There are no options/answers that might be injected/made generic."
	end
	yl_speak_up.generic_dialog_rewrite_options(n_id, start_dialog, append_str, anz_generic)

	-- rename the options of d_got_item so that it can be used in combination with d_got_item
	-- from other generic npc or the specific npc
	yl_speak_up.generic_dialog_rewrite_options(n_id, "d_got_item", append_str, anz_generic)

	-- all fine - no error occoured, no error message to display;
	-- the NPC's dialog has been added
	return "OK"
end


-- if a dialog has just been loaded (or is about to be saved),
-- generic dialogs must not be contained in it;
-- returns the cleaned up dialog;
-- used by yl_speak_up.add_generic_dialogs (see function below)
-- 	and in yl_speak_up.save_dialog in functions.lua
yl_speak_up.strip_generic_dialogs = function(dialog)
	if(not(dialog) or not(dialog.n_dialogs)) then
		return dialog
	end
	for d_id, d_data in pairs(dialog.n_dialogs) do
		if(d_data and d_data.is_generic) then
			-- delete those dialogs that were mistakingly included by previous bugs
			dialog.n_dialogs[d_id] = nil
		elseif(d_data and dialog.n_dialogs[d_id].d_options) then
			for o_id, o_data in pairs(dialog.n_dialogs[d_id].d_options) do
				if(o_data and o_data.is_generic) then
					dialog.n_dialogs[d_id].d_options[o_id] = nil
				end
			end
		end
	end
	return dialog
end


yl_speak_up.add_generic_dialogs = function(dialog, current_n_id, player)
	dialog = yl_speak_up.strip_generic_dialogs(dialog)
	-- make sure we can add d_dynamic dialog:
	if(not(dialog)) then
		dialog = {}
	end
	if(not(dialog.n_dialogs)) then
		dialog.n_dialogs = {}
	end
	-- make sure the dynamic dialog exists (as an empty dialog):
	-- (initial_dialog looks for dialog.n_npc in order to determine if it's a new npc;
	-- so we are safe here with an initialized dialog)
	dialog.n_dialogs["d_dynamic"] = {}
	dialog.n_dialogs["d_dynamic"].d_options = {}

	if(not(player) or not(current_n_id)) then
		return dialog
	end

	-- which is the start dialog of the current NPC? where do we want to insert the options?
	local start_dialog_current = yl_speak_up.get_start_dialog_id(dialog)
	if(not(start_dialog_current)) then
		start_dialog_current = "d_1"
	end
	-- unconfigured NPC are in special need of generic dialogs
	if(not(dialog.n_dialogs[start_dialog_current])) then
		dialog.n_dialogs[start_dialog_current] = {}
	end
	if(not(dialog.n_dialogs[start_dialog_current].d_options)) then
		dialog.n_dialogs[start_dialog_current].d_options = {}
	end
	if(not(dialog.n_dialogs[start_dialog_current].d_text)) then
		dialog.n_dialogs[start_dialog_current].d_text = ""
	end

	-- TODO: supply npc.self directly as parameter?

	-- which generic dialogs shall be included?
	local n_id_list = yl_speak_up.calculate_available_generic_dialogs(current_n_id, player)
	-- actually integrate those generic parts
	for i, n_id in ipairs(n_id_list) do
		-- add the dialogs as such first
		for d_id, d in pairs(yl_speak_up.generic_dialogs[n_id]) do
			-- d_got_item needs to be combined
			if(d_id ~= "d_got_item" and d_id ~= "d_got_item".."_"..tostring(n_id)) then
				-- no need to deep copy here - this is not added in edit mode
				dialog.n_dialogs[d_id] = d
			end
		end
		-- add the options so that these new dialogs can be accessed
		local d = yl_speak_up.generic_dialogs[n_id]["d_generic_start_dialog"]
		if(d and d.d_options) then
			for o_id, o in pairs(d.d_options) do
				-- actually insert the new option
				dialog.n_dialogs[start_dialog_current].d_options[o.o_id] = o
			end
		end
		-- add text from those new dialogs so that the player can know what the
		-- new options are actually about
		if(d and d.d_text and d.d_text ~= "") then
			dialog.n_dialogs[start_dialog_current].d_text =
				dialog.n_dialogs[start_dialog_current].d_text.."\n"..d.d_text
		end

		d = yl_speak_up.generic_dialogs[n_id]["d_got_item"]
		-- add the options from d_got_item
		if(not(dialog.n_dialogs["d_got_item"])
		  or not(dialog.n_dialogs["d_got_item"].d_options)) then
			-- if the current NPC doesn't accept any items: just copy them from the generic npc
			dialog.n_dialogs["d_got_item"] = d
		elseif(d and d.d_options) then
			for o_id, o in pairs(d.d_options) do
				-- actually insert the new options
				-- note: the o_id needs to have been rewritten before this can be done!
				dialog.n_dialogs["d_got_item"].d_options[o.o_id] = o
			end
		end


	end
	return dialog
end


yl_speak_up.load_generic_dialogs = function()
	yl_speak_up.generic_dialogs = {}
	yl_speak_up.generic_dialog_conditions = {}
	-- read list of generic NPC from mod storage
	local s = yl_speak_up.modstorage:get_string("generic_npc_list") or ""
	for i, n_id in ipairs(string.split(s, " ")) do
		local dialog = yl_speak_up.load_dialog(n_id, false)
		local res = yl_speak_up.check_and_add_as_generic_dialog(dialog, n_id)
		if(res == "OK") then
			yl_speak_up.log_change("-", n_id,
				"Generic dialog from NPC "..tostring(n_id).." loaded successfully.",
				"action")
		else
			yl_speak_up.log_change("-", n_id,
				"Generic dialog from NPC "..tostring(n_id).." failed to load: "..
				tostring(res)..".",
				"action")
		end
	end
end
