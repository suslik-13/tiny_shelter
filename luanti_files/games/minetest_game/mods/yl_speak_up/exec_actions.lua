-- This file contains what is necessary to execute an action.

-- monitor changes to the npc_gives and npc_wants slots (in particular when editing actions)
-- how: can be "put" or "take"
yl_speak_up.action_inv_changed = function(inv, listname, index, stack, player, how)
	if(not(player)) then
		return
	end
	local pname = player:get_player_name()
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return
	end
	local n_id = yl_speak_up.speak_to[pname].n_id
	-- if not in edit mode: the player may just be normally interacting with the NPC;
	-- nothing to do for us here (wait for the player to click on "save")
	if(listname and listname == "npc_gives") then
		yl_speak_up.input_fs_action_npc_gives(player, "action_npc_gives", {})
		return
	end
end


-- actions - in contrast to preconditions and effects - may take time
-- because the player usually gets presented a formspec and needs to
-- react to that; thus, we can't just execute all actions simultaneously
yl_speak_up.execute_next_action = function(player, a_id, result_of_a_id, formname)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	yl_speak_up.debug_msg(player, n_id, o_id, "Last action: "..tostring(a_id).." returned "..
				tostring(result_of_a_id)..".")
	local actions = {}
	local effects = {}
	local sorted_key_list = {}
	local d_option = {}
	if(dialog
	  and dialog.n_dialogs
	  and dialog.n_dialogs[d_id]
	  and dialog.n_dialogs[d_id].d_options
	  and dialog.n_dialogs[d_id].d_options[o_id]) then
		-- get the actual actions
		actions = dialog.n_dialogs[d_id].d_options[o_id].actions
		-- needed later on when all actions are executed
		effects = dialog.n_dialogs[d_id].d_options[o_id].o_results
		-- needed later for setting quest_step (optional)
		d_option = dialog.n_dialogs[d_id].d_options[o_id]
	end
	if(actions) then
		-- sort the actions so that we can execute them always in the
		-- same order
		sorted_key_list = yl_speak_up.sort_keys(actions)
		local nr = 0
		if(not(a_id)) then
			-- check if the action(s) can be executed
			local time_now = yl_speak_up.get_time_in_seconds()
			-- is there a limiton how many failed attempts there can be per time?
			local timer_name = "timer_on_failure_"..tostring(d_id).."_"..tostring(o_id)
			local timer_data = yl_speak_up.get_variable_metadata( timer_name, "parameter", true)
						or {}
			local max_attempts = tonumber(timer_data["max_attempts"] or 0)
			local duration     = tonumber(timer_data["duration"]     or 0)
			if(max_attempts > 0 and duration > 0) then
				local new_times = ""
				local times = yl_speak_up.get_quest_variable_value(pname, timer_name)
				local parts = string.split(times or "", " ")
				local count = 0
				for i, p in ipairs(parts) do
					p = tonumber(p)
					-- eliminate entries that are in the future
					if(p and p < time_now and (p + duration > time_now)) then
						new_times = new_times.." "..tostring(p)
						count = count + 1
					end
				end
				-- all timers are expired
				if(count == 0) then
					yl_speak_up.set_quest_variable_value(pname, timer_name, nil)
				-- some timers are expired
				elseif(new_times ~= times) then
					yl_speak_up.set_quest_variable_value(pname, timer_name, new_times)
				end
				if(count >= max_attempts) then
					yl_speak_up.debug_msg(player, n_id, o_id, "Action for option "..
						tostring(d_id).."_"..tostring(o_id)..
						" was attempted "..tostring(count)..
						" times withhin the last "..tostring(duration)..
						" seconds. Maximum allowed attempts are: "..
						tostring(max_attempts)..".")
					-- show the same dialog again, but with the failure message
					yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = d_id,
						alternate_text = timer_data[ "alternate_text" ]
						or yl_speak_up.standard_text_if_action_failed_too_often})
					return
				end
			end
			-- is there a limiton how fast the action may be repeated again?
			timer_name = "timer_on_success_"..tostring(d_id).."_"..tostring(o_id)
			timer_data = yl_speak_up.get_variable_metadata(timer_name, "parameter", true)
						or {}
			duration = tonumber(timer_data["duration"] or 0)
			if(duration > 0) then
				local last_time = yl_speak_up.get_quest_variable_value(pname, timer_name)
				last_time = tonumber(last_time or 0)
				-- timers in the future are ignored
				if(last_time > 0 and last_time < time_now
				  and last_time + duration > time_now) then
					-- show the same dialog again, but with the failure message
					yl_speak_up.debug_msg(player, n_id, o_id, "Action for option "..
						tostring(d_id).."_"..tostring(o_id)..
						" has last been completed "..
						tostring(time_now - last_time)..
						" seconds ago. It can only be repeated after "..
						tostring(duration)..
						" seconds have passed.")
					yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = d_id,
						alternate_text = timer_data[ "alternate_text" ]
						or yl_speak_up.standard_text_if_action_repeated_too_soon})
					return
				else
					-- the timer has expired
					yl_speak_up.set_quest_variable_value(pname, timer_name, nil)
				end
			end

		else -- if(a_id) then
			nr = table.indexof(sorted_key_list, a_id)
			-- did the player go back?
			if(nr > -1 and result_of_a_id == nil) then
				-- set the current action to nil
				yl_speak_up.speak_to[pname].a_id = nil
				-- no option of the new dialog has been selected yet
				yl_speak_up.speak_to[pname].o_id = nil
				-- show the new dialog
				yl_speak_up.debug_msg(player, n_id, o_id, "Action "..
					tostring(a_id).." aborted. Switching back to dialog "..
					tostring(d_id)..".")
				yl_speak_up.speak_to[pname].o_id = nil
				yl_speak_up.speak_to[pname].a_id = nil
				yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = d_id})
				return
			-- did the action fail?
			elseif(nr > -1 and not(result_of_a_id)) then
				-- is there a limiton how many failed attempts there can be per time?
				local timer_name = "timer_on_failure_"..tostring(d_id).."_"..tostring(o_id)
				local timer_data = yl_speak_up.get_variable_metadata(
								timer_name, "parameter", true)
				-- store that (another?) attempt to do the action failed
				if(timer_data
				  and timer_data["max_attempts"] and tonumber(timer_data["max_attempts"])> 0
				  and timer_data["duration"]     and tonumber(timer_data["duration"])> 0) then
					local times = yl_speak_up.get_quest_variable_value(pname, timer_name)
					if(not(times)) then
						times = ""
					end
					-- variables are stored as strings, not as lists
					yl_speak_up.set_quest_variable_value(pname, timer_name,
							times.." "..yl_speak_up.get_time_in_seconds())
				end

				local this_action = actions[ sorted_key_list[ nr ]]
				-- if there is an on_failure target dialog: go there

				-- set the current action to nil
				yl_speak_up.speak_to[pname].a_id = nil
				-- no option of the new dialog has been selected yet
				yl_speak_up.speak_to[pname].o_id = nil
				-- show the new dialog
				yl_speak_up.debug_msg(player, n_id, o_id, "Action "..
					tostring(a_id).." failed. Switching to dialog "..
					tostring(this_action.a_on_failure)..".")
				yl_speak_up.log_change(pname, n_id,
					"Player failed to complete action "..tostring(a_id)..
					" "..tostring(o_id).." "..tostring(d_id)..": "..
					yl_speak_up.show_action(this_action))
				yl_speak_up.speak_to[pname].d_id = this_action.a_on_failure
				yl_speak_up.speak_to[pname].o_id = nil
				yl_speak_up.speak_to[pname].a_id = nil
				-- allow d_end, d_trade, d_got_item etc. to work as a_on_failure
				yl_speak_up.show_next_talk_fs_after_action(player, pname,
					this_action.a_on_failure, formname,
					dialog, d_id, n_id, this_action.alternate_text)
				return
			else
				local this_action = actions[ sorted_key_list[ nr ]]
				yl_speak_up.log_change(pname, n_id,
					"Player completed action "..tostring(a_id)..
					" "..tostring(o_id).." "..tostring(d_id)..": "..
					yl_speak_up.show_action(this_action))
			end
		end
		-- get the next entry
		if(nr > -1 and nr < #sorted_key_list and sorted_key_list[nr + 1]) then
			local next_action = actions[ sorted_key_list[ nr + 1 ]]
			-- store which action we are currently executing
			yl_speak_up.speak_to[pname].a_id = next_action.a_id
			-- execute the next action
			yl_speak_up.debug_msg(player, n_id, o_id, "Executing next action "..
				tostring(next_action.a_id)..".")
			yl_speak_up.execute_action(player, n_id, o_id, next_action)
			-- the player needs time to react
			return
		end
	end
	-- when all actions are executed:
	-- is there a limiton how fast the action may be repeated again?
	local timer_name = "timer_on_success_"..tostring(d_id).."_"..tostring(o_id)
	local timer_data = yl_speak_up.get_variable_metadata(timer_name, "parameter", true)
	-- store that the action was executed successfully
	if(timer_data
	  and timer_data["duration"]     and tonumber(timer_data["duration"]) > 0) then
		yl_speak_up.set_quest_variable_value(pname, timer_name, yl_speak_up.get_time_in_seconds())
	end
	-- set the current action to nil
	yl_speak_up.speak_to[pname].a_id = nil
	yl_speak_up.debug_msg(player, n_id, o_id, "All actions have been executed successfully. "..
		"Doing effects/results now.")
	-- execute all effects/results
	local res = yl_speak_up.execute_all_relevant_effects(player, effects, o_id, true, d_option)
	local target_dialog = res.next_dialog
	yl_speak_up.speak_to[pname].o_id = nil
	yl_speak_up.speak_to[pname].a_id = nil

	-- the function above returns a target dialog; show that to the player
	yl_speak_up.show_next_talk_fs_after_action(player, pname, target_dialog, formname,
					dialog, target_dialog, n_id, res.alternate_text)
end


-- after completing the action - either successfully or if it failed:
yl_speak_up.show_next_talk_fs_after_action = function(player, pname, target_dialog, formname,
							dialog, d_id, n_id, alternate_text)
	-- allow to switch to d_trade from any dialog
	if(target_dialog and target_dialog == "d_trade") then
		yl_speak_up.show_fs(player, "trade_list")
		return
	end
	-- allow to switch to d_got_item from any dialog
	if(target_dialog and target_dialog == "d_got_item") then
		yl_speak_up.show_fs(player, "player_offers_item")
		return
	end
	-- end conversation
	if(target_dialog and target_dialog == "d_end") then
		yl_speak_up.stop_talking(pname)
		-- we are done with this; close any open forms
		if(formname) then
			minetest.close_formspec(pname, formname)
		end
		return
	end
	-- the special dialogs d_trade and d_got_item have no actions or effects - thus
	-- d_id cannot become d_trade or d_got_item
	if(not(target_dialog)
	  or target_dialog == ""
	  or not(dialog.n_dialogs[target_dialog])) then
		target_dialog = d_id
	end
	-- actually show the next dialog to the player
	yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = target_dialog,
				alternate_text = alternate_text})
end


yl_speak_up.execute_action = function(player, n_id, o_id, a)
	if(not(a.a_type) or a.a_type == "" or a.a_type == "none") then
		-- no action - nothing to do
		return true
	elseif(a.a_type == "trade") then
		yl_speak_up.show_fs(player, "trade_simple", a.a_value)
		return
	elseif(a.a_type == "npc_gives") then
		yl_speak_up.show_fs(player, "action_npc_gives", a.a_value)
		return
	elseif(a.a_type == "npc_wants") then
		yl_speak_up.show_fs(player, "action_npc_wants", a.a_value)
		return
	elseif(a.a_type == "text_input") then
		-- start with an empty answer
		yl_speak_up.show_fs(player, "action_text_input", "")
		return
	-- "Show something custom (has to be provided by the server)", -- evaluate
	elseif(a.a_type == "evaluate") then
		yl_speak_up.show_fs(player, "action_evaluate", a.a_value)
		return
	end
	-- fallback: unkown type
	return false
end


-- helper function;
-- returns the action the player is currently faced with (or nil if none)
yl_speak_up.get_action_by_player = function(player)
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	local n_id = yl_speak_up.speak_to[pname].n_id
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id
	local a_id = yl_speak_up.speak_to[pname].a_id
	if(not(dialog) or not(d_id) or not(o_id) or not(a_id)
	  or not(dialog.n_dialogs)
	  or not(dialog.n_dialogs[d_id])
	  or not(dialog.n_dialogs[d_id].d_options)
	  or not(dialog.n_dialogs[d_id].d_options[o_id])
	  or not(dialog.n_dialogs[d_id].d_options[o_id].actions)
	  or not(dialog.n_dialogs[d_id].d_options[o_id].actions[a_id])) then
		return nil
	end
	return dialog.n_dialogs[d_id].d_options[o_id].actions[a_id]
end


-- did the NPC try to give something to the player already - and the player didn't take it?
-- then give that old item back to the NPC
yl_speak_up.action_take_back_failed_npc_gives = function(trade_inv, npc_inv)
	if(not(trade_inv) or not(npc_inv)) then
		return
	end
	local last_stack = trade_inv:get_stack("npc_gives", 1)
	if(not(last_stack:is_empty())) then
		-- strip any metadata to avoid stacking problems
		npc_inv:add_item("npc_main", last_stack:get_name().." "..last_stack:get_count())
	-- clear the stack
		trade_inv:set_stack("npc_gives", 1, "")
	end
end


-- Create the quest item by taking a raw item (i.e. a general piece of paper) out
-- of the NPC's inventory, applying a description (if given) and quest id (if
-- given); place the quest item in the trade inv of the player in the npc_gives slot.
-- The npc_gives inv is managed mostly by the NPC, except when in edit mode. We can
-- just overwrite anything old in there.
-- Returns false if the creation of the quest item wasn't possible (i.e. the
-- NPC had no paper left).
yl_speak_up.action_quest_item_prepare = function(player)
	-- which action are we talking about?
	local a = yl_speak_up.get_action_by_player(player)
	if(not(a) or not(a.a_id) or not(a.a_value)) then
		return false
	end
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	-- what shall the NPC give?
	local stack = ItemStack(a.a_value)
	-- get the inventory of the NPC
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(n_id)})

	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	yl_speak_up.action_take_back_failed_npc_gives(trade_inv, npc_inv)

	-- does the NPC have the item we are looking for?
	if(not(npc_inv:contains_item("npc_main", stack))) then
		local o_id = yl_speak_up.speak_to[pname].o_id
		yl_speak_up.debug_msg(player, n_id, o_id, "Action "..tostring(a.a_id)..": NPC ran out of "..
			tostring(a.a_value)..".")
		-- just go back; the player didn't do anything wrong
		return nil
	end
	-- get the items from the NPCs inventory
	local new_stack = npc_inv:remove_item("npc_main", stack)
	local meta = new_stack:get_meta()
	-- if given: set the item stack description
	if(a.a_item_desc and a.a_item_desc ~= "") then
		local dialog = yl_speak_up.speak_to[pname].dialog
		-- replace $PLAYER_NAME$ etc. in quest item description
		meta:set_string("description", yl_speak_up.replace_vars_in_text(a.a_item_desc, dialog, pname))
	end
	if(a.a_item_quest_id and a.a_item_quest_id ~= "") then
		-- which player got this quest item?
		meta:set_string("yl_speak_up:quest_item_for", pname)
		-- include the NPC id so that we know which NPC gave it
		meta:set_string("yl_speak_up:quest_item_from", tostring(n_id))
		-- extend quest_id by NPC id so that it becomes more uniq
		meta:set_string("yl_speak_up:quest_id",
			tostring(n_id).." "..tostring(a.a_item_quest_id))
	end
	-- put the stack in the npc_gives-slot of the trade inventory of the player
	-- (as that slot is managed by the NPC alone we don't have to worry about
	-- anything else in the slot)
	-- actually put the stack in there
	trade_inv:set_stack("npc_gives", 1, new_stack)
	return true
end


-- check if the item in the npc_gives slot is the one the NPC wants
yl_speak_up.action_quest_item_check = function(player)
	-- which action are we talking about?
	local a = yl_speak_up.get_action_by_player(player)
	if(not(a) or not(a.a_id) or not(a.a_value)) then
		return false
	end
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	local o_id = yl_speak_up.speak_to[pname].o_id
	-- get the item that needs to be checked
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	local stack = trade_inv:get_stack("npc_wants", 1)
	-- nothing there?
	if(stack:is_empty()) then
		yl_speak_up.debug_msg(player, n_id, o_id, "Action "..tostring(a.a_id)..": No item found.")
		return false
	end
	local cmp = tostring(stack:get_name()).." "..(stack:get_count())
	-- wrong item or wrong amount?
	if(cmp ~= a.a_value) then
		yl_speak_up.debug_msg(player, n_id, o_id, "Action "..tostring(a.a_id)..
			": Wrong item given. Got: "..stack:to_string()..
			" Expected: "..tostring(a.a_value)..".")
		yl_speak_up.log_change(pname, n_id,
			"Action "..tostring(a_id)..
			" "..tostring(yl_speak_up.speak_to[pname].o_id)..
			" "..tostring(yl_speak_up.speak_to[pname].d_id)..
			" failed: Player gave item \""..tostring(cmp).."\", but we wanted: \""..
				tostring(a.a_value).."\".")
		return false
	end
	local meta = stack:get_meta()
	-- the description is not checked; just the quest id (if given)
	if(a.a_item_quest_id and a.a_item_quest_id ~= "") then
		-- we don't check here if the item was given by the right NPC;
		-- only the quest id has to fit
		if(meta:get_string("yl_speak_up:quest_id") ~= a.a_item_quest_id) then
			yl_speak_up.debug_msg(player, n_id, o_id, "Action "..tostring(a.a_id)..
				": Wrong quest item (wrong ID).")
			yl_speak_up.log_change(pname, n_id,
				"Action "..tostring(a_id)..
				" "..tostring(yl_speak_up.speak_to[pname].o_id)..
				" "..tostring(yl_speak_up.speak_to[pname].d_id)..
				" failed: Player gave item with wrong quest ID.")
			return false
		end
		-- was this quest item given to another player?
		if(meta:get_string("yl_speak_up:quest_item_for") ~= pname) then
			yl_speak_up.debug_msg(player, n_id, o_id, "Action "..tostring(a.a_id)..
				": Quest item was given to "..
				tostring(meta:get_string("yl_speak_up:quest_item_for"))..
				", but "..tostring(pname).." gave it.")
			yl_speak_up.log_change(pname, n_id,
				"Action "..tostring(a_id)..
				" "..tostring(yl_speak_up.speak_to[pname].o_id)..
				" "..tostring(yl_speak_up.speak_to[pname].d_id)..
				" failed: Player gave quest item that belonged to player "..
				tostring(meta:get_string("yl_speak_up:quest_item_for"))..".")
			return false
		end
	end
	yl_speak_up.debug_msg(player, n_id, o_id, "Action "..tostring(a.a_id)..
		": Quest item checked ok.")
	return true
end


-- strip the quest information from the item and give it back to the NPC;
-- returns the modified stack (but also places it in the NPC's inventory)
yl_speak_up.action_quest_item_take_back = function(player)
	-- which action are we talking about?
	local a = yl_speak_up.get_action_by_player(player)
	if(not(a) or not(a.a_id) or not(a.a_value)) then
		return false
	end
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	-- get the item that the NPC shall take back (or accept in npc_wants)
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	local stack = trade_inv:get_stack("npc_wants", 1)
	-- if it was the wrong item:
	if(not(yl_speak_up.action_quest_item_check(player))) then
		local player_inv = player:get_inventory()
		-- give the item back to the player
		local remaining = player_inv:add_item("main", stack)
		-- very unlikely - but in case the item did not fit back into the player's inv:
		if(remaining and not(remaining:is_empty())) then
			local p = player:get_pos()
			-- throw it at the player
			minetest.add_item({x=p.x, y=p.y+1, z=p.z},  stack)
		end
		-- remove it from the trade inv slot
		trade_inv:set_stack("npc_wants", 1, ItemStack())
		return false
	end
	-- we already checked that it is the correct item
	local meta = stack:get_meta()
	-- if given: set the item stack description
	if(a.a_item_desc and a.a_item_desc ~= "") then
		meta:set_string("description", "")
	end
	-- delete all the special IDs that where added before
	if(a.a_item_quest_id and a.a_item_quest_id ~= "") then
		meta:set_string("yl_speak_up:quest_item_for", "")
		meta:set_string("yl_speak_up:quest_item_from", "")
		meta:set_string("yl_speak_up:quest_id", "")
	end
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(n_id)})
	-- Has the NPC room enough for the item?
	-- If the NPC doesn't have room, the item will be destroyed in the next step by setting
	-- npc_wants to an empty stack. While this may lead to some item loss, it is more important
	-- that the quest item was properly accepted (and discarded of) rather than worrying about
	-- where to put it or even giving it back and letting the quest fail.
	if(npc_inv:room_for_item("npc_main", stack)) then
		npc_inv:add_item("npc_main", stack)
		-- save the inventory of the NPC
		yl_speak_up.save_npc_inventory(n_id)
	end
	-- the NPC has accepted the item
	trade_inv:set_stack("npc_wants", 1, ItemStack())
	return true
end


-- show the diffrent action-related formspecs and handle input to them
-- (Note: trade is handled in trade_simple.lua)
-- -> now moved to fs/fs_action_*.lua
