-- This file contains what is necessary to execute/evaluate a precondition.
--
-- You can add your own custom functions the file:
-- 	in custom_functions_you_can_override.lua

-- this is called directly in yl_speak_up.get_fs_talkdialog
-- it returns a list of options whose preconditions are fulfilled
-- allow_recursion may be false - we need to avoid infinite loops
yl_speak_up.calculate_displayable_options = function(pname, d_options, allow_recursion)
    -- Let's go through all the options and see if we need to display them to the user

    local retval = {}

    local player = minetest.get_player_by_name(pname)

    if d_options == nil then
        return {}
    end

    -- sort the entries by o_sort so that preconditions referencing options earlier in the
    -- list can work without causing loops or the like
    local sorted_list = yl_speak_up.get_sorted_options(d_options, "o_sort")
    for i, o_k in ipairs(sorted_list) do
		local o_v = d_options[ o_k ]
		-- Can we display this option?
		retval[o_k] = yl_speak_up.eval_all_preconditions(player, o_v.o_prerequisites, o_k, retval,o_v)
		-- do we need to take care of an automatic autoanswer?
		if(retval[o_k] and retval[o_k] == true and o_v.o_autoanswer and o_v.o_autoanswer == 1
		   and allow_recursion) then
			-- abort here - because we already know which option needs to be selected next
			retval["autoanswer"] = o_k
			return retval
		end
    end
    return retval
end


-- called by calculate_displayable_options(..);
-- returns false if a single precondition is false
-- Important: If something cannot be determined (i.e. the node is nil),
--            *both* the condition and its inverse condition may be
--            true (or false).
yl_speak_up.eval_all_preconditions = function(player, prereq, o_id, other_options_true_or_false, d_option)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id

	-- if this is a quest step: check if its preconditions are fulfilled
	-- (that way there doesn't have to be a manual precondition set for quests)
	if(d_option and d_option.quest_id and d_option.quest_step) then
		local d_id = yl_speak_up.speak_to[pname].d_id
		yl_speak_up.debug_msg(player, n_id, o_id, "..checking quest step \""..
			tostring(d_option.quest_step).."\" of quest \""..
			tostring(d_option.quest_id).."\".")
		if(not(yl_speak_up.quest_step_possible(player, d_option.quest_step, d_option.quest_id,
				n_id, d_id, o_id))) then
			yl_speak_up.debug_msg(player, n_id, o_id, "Quest step not available. Aborting.")
			-- no need to look any further - once we hit a false, it'll stay false
			return false
		else
			yl_speak_up.debug_msg(player, n_id, o_id, "OK. Quest step available.")
		end
	end


	if(not(prereq)) then
		yl_speak_up.debug_msg(player, n_id, o_id, "No preconditions given.")
		-- no prerequirements? then they are automaticly fulfilled
		return true
	end
	yl_speak_up.debug_msg(player, n_id, o_id, "Checking preconditions..")

	-- we need to be fast and efficient here - and the properties stay fixed for the NPC
	-- during this call, so we can cache them
	local properties = yl_speak_up.get_npc_properties(pname)

	for k, p in pairs(prereq or {}) do
		yl_speak_up.debug_msg(player, n_id, o_id, "..checking "..
			tostring(p.p_id)..": "..yl_speak_up.show_precondition(p, pname))
		if(not(yl_speak_up.eval_precondition(player, n_id, p, other_options_true_or_false, properties))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(p.p_id)..
				" -> is false. Aborting.")
			-- no need to look any further - once we hit a false, it'll stay false
			return false
		end
	end
	-- all preconditions are true
	yl_speak_up.debug_msg(player, n_id, o_id, "OK. All preconditions true.")
	return true
end


-- helper function for yl_speak_up.eval_precondition
-- (needed by "state", "property" and "evaluate")
-- Parameters:
-- 	p.p_operator        the operator (>, <, ==, is_set, ...) from values_operator
-- 	p.p_var_cmp_value   the value against which we compare
-- 	var_val      	    the current value - that one which we want to check
yl_speak_up.eval_precondition_with_operator = function(p, var_val)
	if(p.p_operator == "not") then
		return not(var_val)
	elseif(p.p_operator == "is_set") then
		return var_val ~= nil
	elseif(p.p_operator == "is_unset") then
		return var_val == nil
	-- for security reasons: do this manually instead of just evaluating a term
	elseif(p.p_operator == "==") then
		if(p.p_var_cmp_value == nil or var_val == nil) then
			return false
		end
		-- best do these comparisons in string form to make sure both are of same type
		return tostring(var_val) == tostring(p.p_var_cmp_value)
	elseif(p.p_operator == "~=") then
		return tostring(var_val) ~= tostring(p.p_var_cmp_value)
	elseif(p.p_operator == ">=") then
		if(p.p_var_cmp_value == nil or var_val == nil) then
			return false
		end
		-- compare numeric if possible
		if(tonumber(var_val) and tonumber(p.p_var_cmp_value)) then
			return tonumber(var_val) >= tonumber(p.p_var_cmp_value)
		-- fallback: compare as strings
		else
			return tostring(var_val) >= tostring(p.p_var_cmp_value)
		end
	elseif(p.p_operator == ">") then
		if(p.p_var_cmp_value == nil or var_val == nil) then
			return false
		end
		if(tonumber(var_val) and tonumber(p.p_var_cmp_value)) then
			return tonumber(var_val) >  tonumber(p.p_var_cmp_value)
		else
			return tostring(var_val) >  tostring(p.p_var_cmp_value)
		end
	elseif(p.p_operator == "<=") then
		if(p.p_var_cmp_value == nil or var_val == nil) then
			return false
		end
		if(tonumber(var_val) and tonumber(p.p_var_cmp_value)) then
			return tonumber(var_val) <= tonumber(p.p_var_cmp_value)
		else
			return tostring(var_val) <= tostring(p.p_var_cmp_value)
		end
	elseif(p.p_operator == "<") then
		if(p.p_var_cmp_value == nil or var_val == nil) then
			return false
		end
		if(tonumber(var_val) and tonumber(p.p_var_cmp_value)) then
			return tonumber(var_val) <  tonumber(p.p_var_cmp_value)
		else
			return tostring(var_val) <  tostring(p.p_var_cmp_value)
		end
	elseif(p.p_operator == "more_than_x_seconds_ago") then
		if(p.p_var_cmp_value == nil or var_val == nil) then
			return false
		end
		if(not(tonumber(var_val)) or not(tonumber(p.p_var_cmp_value))) then
			return true
		end
		return (tonumber(var_val) + tonumber(p.p_var_cmp_value)) <
			math.floor(minetest.get_us_time()/1000000)
	elseif(p.p_operator == "less_than_x_seconds_ago") then
		if(p.p_var_cmp_value == nil or var_val == nil) then
			return false
		end
		if(not(tonumber(var_val)) or not(tonumber(p.p_var_cmp_value))) then
			return false
		end
		return (tonumber(var_val) + tonumber(p.p_var_cmp_value)) >
			minetest.get_us_time()/1000000
	-- this is currently equivalent to >= but may change in the future
	-- TODO: quest steps may be strings in the future
	elseif(p.p_operator == "quest_step_done") then
		-- if the variable is not set at all, then the quest step definitely
		-- has not been reached yet
		if((p.p_var_cmp_value == nil) or (var_val == nil)) then
			return false
		end
		-- compare numeric if possible
		if(tonumber(var_val) and tonumber(p.p_var_cmp_value)) then
			return tonumber(var_val) >= tonumber(p.p_var_cmp_value)
		-- fallback: compare as strings
		else
			return tostring(var_val) >= tostring(p.p_var_cmp_value)
		end
	-- this is currently equivalent to < but may change in the future
	-- TODO: quest steps may be strings in the future
	elseif(p.p_operator == "quest_step_not_done") then
		-- if the variable is not set at all, then the quest step definitely
		-- has not been reached yet
		if((p.p_var_cmp_value == nil) or (var_val == nil)) then
			return true
		end
		if(tonumber(var_val) and tonumber(p.p_var_cmp_value)) then
			return tonumber(var_val) <  tonumber(p.p_var_cmp_value)
		else
			return tostring(var_val) <  tostring(p.p_var_cmp_value)
		end
	end
	-- unsupported operator
	return false
end


-- checks if precondition p is true for the player and npc n_id
yl_speak_up.eval_precondition = function(player, n_id, p, other_options_true_or_false, properties)
	if(not(p.p_type) or p.p_type == "") then
		-- empty prerequirement: automaticly true (fallback)
		return true
	elseif(p.p_type == "item") then
		-- a precondition set by using the staff;
		-- aequivalent to p.p_type == "player_inv" and p.p_itemstack == "inv_contains"
		return player:get_inventory():contains_item("main", p.p_value)
	elseif(p.p_type == "quest") then
		-- a precondition set by using the staff; intended as future quest interface?
		return false
	elseif(p.p_type == "auto") then
		-- a precondition set by using the staff; kept for compatibility
		return true
	elseif(p.p_type == "true") then
		-- mostly useful for generic dialogs
		return true
	elseif(p.p_type == "false") then
		-- mostly useful for temporally disabling options
		return false
	elseif(p.p_type == "function") then
		if(not(yl_speak_up.npc_has_priv(n_id, "precon_exec_lua", p.p_is_generic))) then
			return false
		end
		-- a precondition set by using the staff;
		-- extremly powerful (executes any lua code)
		return yl_speak_up.eval_and_execute_function(player, p, "p_")
	elseif(p.p_type == "state") then
		local var_val = false
		if(not(p.p_variable) or p.p_variable == "") then
			-- broken precondition
			return false
		-- internal custom server functions for preconditions
		elseif(table.indexof(yl_speak_up.custom_server_functions.precondition_descriptions,
		                     p.p_variable) > -1) then
			-- evaluate it
			var_val = yl_speak_up.custom_server_functions.precondition_eval(
					player, p.p_variable, p)
			if(p.p_operator == "true_for_param") then
				return var_val
			elseif(p.p_operator == "false_for_param") then
				return not(var_val)
			end
		else
			local pname = player:get_player_name()
			local owner = yl_speak_up.npc_owner[ n_id ]
			-- get the value of the variable
			-- the owner is alrady encoded in the variable name
			var_val = yl_speak_up.get_quest_variable_value(pname, p.p_variable)
		end
		-- actually evaulate it
		return yl_speak_up.eval_precondition_with_operator(p, var_val)

	elseif(p.p_type == "property") then
		-- fallback in case this function is called alone, without properties
		if(not(properties)) then
			local pname = player:get_player_name()
			properties = yl_speak_up.get_npc_properties(pname)
		end
		return yl_speak_up.eval_precondition_with_operator(p, properties[p.p_value])

	elseif(p.p_type == "evaluate") then
		if(not(player) or not(p.p_value)) then
			return false
		end
		local custom_data = yl_speak_up.custom_functions_p_[p.p_value]
		if(not(custom_data) or not(custom_data.code)) then
			return false
		end
		local fun = custom_data.code
		-- actually call the function
		local ret = fun(player, n_id, p)
		-- compare the result with wat is expected
		return yl_speak_up.eval_precondition_with_operator(p, ret)
	elseif(p.p_type == "block") then
		if(not(p.p_pos) or type(p.p_pos) ~= "table"
		  or not(p.p_pos.x) or not(p.p_pos.y) or not(p.p_pos.z)) then
			return false
		elseif(p.p_value == "node_is_like") then
			local node = minetest.get_node_or_nil(p.p_pos)
			return (node and node.name and node.name == p.p_node and node.param2 == p.p_param2)
		elseif(p.p_value == "node_is_air") then
			local node = minetest.get_node_or_nil(p.p_pos)
			return (node and node.name and node.name == "air")
		elseif(p.p_value == "node_is_diffrent_from") then
			local node = minetest.get_node_or_nil(p.p_pos)
			return (node and node.name and (node.name ~= p.p_node or node.param2 ~= p.p_param2))
		end
		-- fallback - unsupported option
		return false
	elseif(p.p_type == "trade") then
		local pname = player:get_player_name()
		local dialog = yl_speak_up.speak_to[pname].dialog
		local n_id = yl_speak_up.speak_to[pname].n_id
		local d_id = yl_speak_up.speak_to[pname].d_id
		local o_id = yl_speak_up.speak_to[pname].o_id
		-- if there is no trade, then this condition is true
		if(not(dialog) or not(dialog.trades) or not(d_id) or not(o_id)) then
			return true
		end
		local trade = dialog.trades[ tostring(d_id).." "..tostring(o_id) ]
		-- something is wrong with the trade
		if(not(trade)
		  or not(trade.pay) or not(trade.pay[1]) or not(trade.buy) or not(trade.buy[1])) then
			return false
		end
		if(    p.p_value == "npc_can_sell") then
			local npc_inv = minetest.get_inventory({type="detached",
				name="yl_speak_up_npc_"..tostring(n_id)})
			return npc_inv:contains_item("npc_main", trade.buy[1])
		elseif(p.p_value == "npc_is_out_of_stock") then
			local npc_inv = minetest.get_inventory({type="detached",
				name="yl_speak_up_npc_"..tostring(n_id)})
			return not(npc_inv:contains_item("npc_main", trade.buy[1]))
		elseif(p.p_value == "player_can_buy") then
			local player_inv = player:get_inventory()
			return player_inv:contains_item("main", trade.pay[1])
		elseif(p.p_value == "player_has_not_enough") then
			local player_inv = player:get_inventory()
			return not(player_inv:contains_item("main", trade.pay[1]))
		end
		return false
	elseif(p.p_type == "player_inv" or p.p_type == "npc_inv" or p.p_type == "block_inv") then
		local inv = nil
		local inv_name = "main"
		-- determine the right inventory
		if(p.p_type == "player_inv") then
			inv = player:get_inventory()
		elseif(p.p_type == "npc_inv") then
			inv = minetest.get_inventory({type="detached",
                                name="yl_speak_up_npc_"..tostring(n_id)})
			inv_name = "npc_main"
		elseif(p.p_type == "block_inv") then
			if(not(p.p_pos) or type(p.p_pos) ~= "table"
			  or not(p.p_pos.x) or not(p.p_pos.y) or not(p.p_pos.z)) then
				return false
			end
			local meta = minetest.get_meta(p.p_pos)
			if(not(meta)) then
				return false
			end
			inv = meta:get_inventory()
			if(not(inv)) then
				return false
			end
			inv_name = p.p_inv_list_name
		end
		if(    p.p_itemstack and p.p_value == "inv_contains") then
			return inv:contains_item(inv_name, p.p_itemstack)
		elseif(p.p_itemstack and p.p_value == "inv_does_not_contain") then
			return not(inv:contains_item(inv_name, p.p_itemstack))
		elseif(p.p_itemstack and p.p_value == "has_room_for") then
			return inv:room_for_item(inv_name, p.p_itemstack)
		elseif(p.p_value == "inv_is_empty") then
			return inv:is_empty(inv_name)
		end
		return false
	elseif(p.p_type == "player_offered_item") then
		local pname = player:get_player_name()
		local inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
		local stack_got = inv:get_stack("npc_wants",1)
		if(stack_got:is_empty()) then
			return false -- empty stack
		end
		local stack_wanted = ItemStack(p.p_value)
		-- check group
		if(p.p_item_group and p.p_item_group ~= "") then
			local g = minetest.get_item_group(stack_got:get_name(), p.p_item_group)
			if(not(g) or g == 0) then
				return false -- wrong group
			end
		-- or: check item name
		elseif(stack_got:get_name() ~= stack_wanted:get_name()) then
			return false -- wrong item
		end
		-- independent of that: check stack size
		if(p.p_match_stack_size and p.p_match_stack_size ~= "") then
			local c_got = stack_got:get_count()
			local c_wanted = stack_wanted:get_count()
			if(    p.p_match_stack_size == "exactly" and c_got ~= c_wanted) then
				return false -- not exactly the same amount as the wanted one
			elseif(p.p_match_stack_size == "less"    and c_got >= c_wanted) then
				return false -- didn't get less than the given number
			elseif(p.p_match_stack_size == "more"    and c_got <= c_wanted) then
				return false -- didn't get more than the given number
			elseif(p.p_match_stack_size == "another" and c_got == c_wanted) then
				return false -- got the same than the given number
			end
		end
		-- check quest_id
		if(p.p_item_quest_id and p.p_item_quest_id ~= "") then
			local meta = stack_got:get_meta()
			-- we don't check here if the item was given by the right NPC;
			-- only the quest id has to fit
			if(meta:get_string("yl_speak_up:quest_id") ~= p.p_item_quest_id) then
				return false -- wrong quest_id
			end
			-- was this quest item given to another player?
			if(meta:get_string("yl_speak_up:quest_item_for") ~= pname) then
				return false -- wrong player
			end
		end
		-- all ok
		return true
	elseif(p.p_type == "other") then
		-- are the preconditions of another option fulfilled?
		return (p.p_value
		    and other_options_true_or_false
		    and other_options_true_or_false[ p.p_value ] ~= nil
		    and tostring(other_options_true_or_false[ p.p_value ]) == tostring(p.p_fulfilled))
	elseif(p.p_type == "entity_type") then
		local pname = player:get_player_name()
		-- is the NPC type the same as the requested entity_type?
		return (p.p_value
			and yl_speak_up.speak_to[pname]._self
			and yl_speak_up.speak_to[pname]._self.name
			and yl_speak_up.speak_to[pname]._self.name == p.p_value)
	end
	-- fallback - unknown type
	return false
end


-- helper function for yl_speak_up.eval_trade_list_preconditions
yl_speak_up.eval_precondition_npc_inv = function(p, inv, inv_name)
	if(p.p_type ~= "npc_inv") then
		return false
	end
	-- determine the right inventory
	if(    p.p_itemstack and p.p_value == "inv_contains") then
		return inv:contains_item(inv_name, p.p_itemstack)
	elseif(p.p_itemstack and p.p_value == "inv_does_not_contain") then
		return not(inv:contains_item(inv_name, p.p_itemstack))
	elseif(p.p_itemstack and p.p_value == "has_room_for") then
		return inv:room_for_item(inv_name, p.p_itemstack)
	elseif(p.p_value == "inv_is_empty") then
		return inv:is_empty(inv_name)
	end
	return false
end


-- cheaper version of eval_all_preconditions for the trade_list (d_trade);
-- returns the ID of the first option where the precondition match or nil;
-- *only* preconditions of the type "npc_inv" are evaluated!
yl_speak_up.eval_trade_list_preconditions = function(player)
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	local n_id = yl_speak_up.speak_to[pname].n_id
	if(not(dialog) or not(dialog.n_dialogs) or not(dialog.n_dialogs["d_trade"])
	   or not(dialog.n_dialogs["d_trade"].d_options)) then
		return
	end
	local options = dialog.n_dialogs["d_trade"].d_options
	local sorted_o_list = yl_speak_up.get_sorted_options(options, "o_sort")

	local inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(n_id)})
	local inv_name = "npc_main"
	-- search through all options
	for i, s_o_id in ipairs(sorted_o_list) do
		local prereq = options[s_o_id].o_prerequisites
		local all_ok = true
		for k, p in pairs(prereq or {}) do
			if(not(yl_speak_up.eval_precondition_npc_inv(p, inv, inv_name))) then
				all_ok = false
				break
			end
		end
		if(all_ok) then
			return s_o_id
		end
	end
end
