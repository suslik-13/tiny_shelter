-- This file contains what is necessary to execute/apply an effect.

-- for "deal_with_offered_item", used i.e. in yl_speak_up.get_fs_edit_option_effect_deal_with_offered_item
yl_speak_up.dropdown_list_deal_with_offered_item = {
	minetest.formspec_escape("- please select -"),
	"Take the expected part of the offered item(s) and put them in the NPC's inventory.",
	"Accept all of the offered item(s) and put them in the NPC's inventory.",
	"Refuse and give the item(s) back."
	}
-- the values that will be stored for yl_speak_up.dropdown_list_deal_with_offered_item above
yl_speak_up.dropdown_values_deal_with_offered_item = {
	"do_nothing", "take_as_wanted", "take_all", "refuse_all"}


-- check if a block of type node_name is blacklisted for a certain interaction
-- (this is needed if a block is not prepared for interaction with NPC and
-- expects to always be dealing with a player)
-- Parameters:
-- 	how		how to interact with the node
-- 	node_name	the node to place
-- 	node_there	the node that can currently be found at that position
-- 	tool_name	the name of the tool the NPC wants to use (punch or right-click with)
yl_speak_up.check_blacklisted = function(how, node_name, node_there, tool_name)
	if(tool_name) then
		return yl_speak_up.blacklist_effect_tool_use[ tool_name ]
	end
	return yl_speak_up.blacklist_effect_on_block_interact[ node_name ]
	  or yl_speak_up.blacklist_effect_on_block_interact[ node_there ]
	  or (how == "place"       and yl_speak_up.blacklist_effect_on_block_place[ node_name ])
	  or (how == "dig"         and yl_speak_up.blacklist_effect_on_block_dig[   node_there ])
	  or (how == "punch"       and yl_speak_up.blacklist_effect_on_block_punch[ node_there ])
	  or (how == "right-click" and yl_speak_up.blacklist_effect_on_block_right_click[ node_there])
	  or (how == "put"         and yl_speak_up.blacklist_effect_on_block_right_click[ node_there])
	  or (how == "take"        and yl_speak_up.blacklist_effect_on_block_right_click[ node_there])
end


-- create fake playerdata so that the NPC can interact with inventories, punch and right-click blocks
yl_speak_up.get_fake_player = function(owner_name, wielded_item)
	return {
		get_player_name = function()
			return owner_name
		end,
		is_player = function()
			return true
		end,
		is_fake_player = true,
		get_wielded_item = function(self, item)
			return ItemStack(wielded_item)
		end,
		get_player_control = function()
			-- NPC is not sneaking
			return {}
		end,
	}
end


-- shall the NPC wield and use a tool? if so that tools' on_use or on_place
-- function takes precedence over the block it's used on
yl_speak_up.use_tool_on_block = function(r, fun_name, player, n_id, o_id)
	if(not(r.r_wielded) or r.r_wielded == "") then
		return false
	end
	-- we need the owner_name for creating the fake player
	local owner_name = yl_speak_up.npc_owner[ n_id ]
	if(not(owner_name) or owner_name == "") then
		yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
			r.r_type..": NPC does not have an owner. Aborting.")
		return false
	end
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(n_id)})
	-- can the tool be used?
	local tool_err_msg = nil
	if(not(minetest.registered_items[r.r_wielded])) then
		tool_err_msg = "Tool not defined"
	elseif(not(minetest.registered_items[r.r_wielded][fun_name])) then
		tool_err_msg = "Tool does not support "..tostring(r.r_value).."ing"
	-- do not use forbidden tools
	elseif(yl_speak_up.check_blacklisted(nil, nil, nil, r.r_wielded)) then
		tool_err_msg = "NPC are not allowed to use this tool"
	-- does the NPC have the item he's supposed to wield?
	elseif(not(npc_inv:contains_item("npc_main", r.r_wielded, false))) then
		tool_err_msg = "NPC lacks tool"
	end
	if(tool_err_msg) then
		yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id)..
			" block: "..tostring(r.r_value).." - "..tool_err_msg..  ": \""..tostring(r.r_wielded).."\".")
		return false
	end
	-- act in the name of the owner when accessing inventories
	local fake_player = yl_speak_up.get_fake_player(owner_name, r.r_wielded)
	local itemstack = fake_player:get_wielded_item()
	local pointed_thing = {
			type = "node",
			under = r.r_pos,
			above = {x=r.r_pos.x, y=r.r_pos.y+1, z=r.r_pos.z}
		}
	local new_itemstack = minetest.registered_items[r.r_wielded][fun_name](
							itemstack, fake_player, pointed_thing)
	minetest.chat_send_player("singleplayer", "Did the rightclicking. Result: "..new_itemstack:get_name().." fun_name: "..tostring(fun_name))
	if(new_itemstack) then
		-- apply any itemstack changes
		npc_inv:remove_item("npc_main", itemstack)
		npc_inv:add_item("npc_main",    new_itemstack)
	end
	return true
end


-- called by yl_speak_up.input_talk(..)
-- and also by yl_speak_up.get_fs_trade_list(..)
--
-- This function is called *after* the player has clicked on an option
-- and *after* any actions (i.e. trade) have been completed either
-- successfully (=action_was_succesful is true) or not.
-- Unlike the preconditions, the effects are executed in ordered form,
-- ordered by their r_id.
-- Returns the new target dialog that is to be displayed next. This will
-- usually be the one with the r_type "dialog" - unless r_type "on_failure"
-- was encountered after an unsuccessful action *or* right after an
-- effect that returned false.
-- Note: In edit mode, effects will *not* be executed.
yl_speak_up.execute_all_relevant_effects = function(player, effects, o_id, action_was_successful, d_option,
						dry_run_no_exec) -- dry_run_no_exec for edit_mode
	local target_dialog = ""
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	if(not(effects)) then
		-- it may still be necessary to set the quest step
		if(d_option and d_option.quest_id and d_option.quest_step) then
			local d_id = yl_speak_up.speak_to[pname].d_id
			yl_speak_up.debug_msg(player, n_id, o_id, "Setting quest step \""..
					tostring(d_option.quest_step).."\" in quest \""..
					tostring(d_option.quest_id).."\".")
			yl_speak_up.quest_step_reached(player, d_option.quest_step, d_option.quest_id,
				n_id, d_id, o_id)
		end
		yl_speak_up.debug_msg(player, n_id, o_id, "No effects given.")
		-- the player has visited this option successfully
		yl_speak_up.count_visits_to_option(pname, o_id)
		-- no effects? Then...return to the start dialog
		return {next_dialog = "", alternate_text = nil}
	end
	-- Important: the list of effects is *sorted* here. The order remains constant!
	local sorted_key_list = yl_speak_up.sort_keys(effects)
	if(not(sorted_key_list) or #sorted_key_list < 1) then
		yl_speak_up.debug_msg(player, n_id, o_id, "Error: No effects found. At least one of "..
			"type \"dialog\" is necessary.")
	elseif(not(dry_run_no_exec)) then
		yl_speak_up.debug_msg(player, n_id, o_id, "Executing effects: "..
			table.concat(sorted_key_list, ", ")..".")
	else
		yl_speak_up.debug_msg(player, n_id, o_id, "Not executing effects because in edit mode.")
	end
	-- failed actions may set an alternate text
	local alternate_text = nil
	local last_result = action_was_successful
	local res = true
	local refuse_items = true
	local properties = yl_speak_up.get_npc_properties(pname)
	local no_log = properties["server_nolog_effects"]
	for i, k in ipairs(sorted_key_list) do
		local r = effects[ k ]
		yl_speak_up.debug_msg(player, n_id, o_id, "..executing "..
			tostring(r.r_id)..": "..yl_speak_up.show_effect(r, pname))
		-- do not execute effects in edit mode
		if(not(dry_run_no_exec)) then
			if(not(no_log)) then
				yl_speak_up.debug_msg(player, n_id, o_id,
					"Executing effect "..tostring(r.r_id)..".")
			end
			res = yl_speak_up.execute_effect(player, n_id, o_id, r)
			if(no_log) then
				if(not(res)) then
					alternate_text = r.alternate_text
				end
			elseif(not(res)) then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id)..
					" -> Effect failed to execute.")
				if(r.r_type ~= "dialog") then
					local d_id = yl_speak_up.speak_to[pname].d_id
					yl_speak_up.log_change(pname, n_id,
						"Failed to execute effect "..tostring(r.r_id)..
						" "..tostring(o_id).." "..tostring(d_id)..": "..
						yl_speak_up.show_effect(r, pname))
				end
				alternate_text = r.alternate_text
			else
				if(r.r_type ~= "dialog") then
					local d_id = yl_speak_up.speak_to[pname].d_id
					yl_speak_up.log_change(pname, n_id,
						"Executed effect "..tostring(r.r_id)..
						" "..tostring(o_id).." "..tostring(d_id)..": "..
						yl_speak_up.show_effect(r, pname))
				end
			end
			if(r and r.r_type and r.r_type == "deal_with_offered_item") then
				refuse_items = true
				if(not(r.r_value) or r.r_value == "do_nothing") then
					refuse_items = false
				end
			end
		else
			-- in edit mode: assume that the effect was successful
			res = true
		end
		-- "dialog" gives us the normal target_dialog
		if(r.r_type and r.r_type == "dialog") then
			target_dialog = r.r_value
			alternate_text = r.alternate_text
		-- "on_failure" gives an alternate target dialog if the action
		-- or last effect failed
		elseif(r.r_type and r.r_type == "on_failure" and r.r_value and not(last_result)) then
			yl_speak_up.debug_msg(player, n_id, o_id, "Aborted executing effects at "..
				tostring(r.r_id)..". New target dialog: "..tostring(r.r_value)..".")
			-- we also stop execution here
			-- any quest step is NOT set (because effects and/or action weren't successful)
			-- the visit counter for this option is not incresed - after all the visit failed
			return {next_dialog = r.r_value, alternate_text = r.alternate_text}
		end
		last_result = res
	end
	-- all preconditions are true
	yl_speak_up.debug_msg(player, n_id, o_id, "Finished executing effects.")
	-- make sure to give unwanted items back if needed
	if(refuse_items) then
		-- check if there is actually something that needs to be given back
		local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
		if(not(trade_inv:is_empty("npc_wants"))) then
			target_dialog = "d_got_item"
		end
	end

	-- it may still be necessary to set the quest step
	if(d_option and d_option.quest_id and d_option.quest_step) then
		local d_id = yl_speak_up.speak_to[pname].d_id
		yl_speak_up.debug_msg(player, n_id, o_id, "Setting quest step \""..
				tostring(d_option.quest_step).."\" in quest \""..
				tostring(d_option.quest_id).."\".")
		yl_speak_up.quest_step_reached(player, d_option.quest_step, d_option.quest_id,
				n_id, d_id, o_id)
	end
	-- the player has visited this option successfully
	yl_speak_up.count_visits_to_option(pname, o_id)
	return {next_dialog = target_dialog, alternate_text = alternate_text}
end


-- helper function for yl_speak_up.execute_effect
-- used by "state" (pname is nil) and "property" (pname is nil)
yl_speak_up.execute_effect_get_new_value = function(r, var_val, pname)
	-- for "state" - but not for "property"
	if(pname
	  and (r.r_operator == "quest_step"
	    or r.r_operator == "maximum" or r.r_operator == "minimum"
	    or r.r_operator == "increment" or r.r_operator == "decrement")) then
		var_val = yl_speak_up.get_quest_variable_value(pname, r.r_variable)
	end
	-- set the value of the variable
	local new_value = nil
	if(    r.r_operator and r.r_operator == "set_to") then
		new_value = r.r_var_cmp_value
	elseif(r.r_operator and r.r_operator == "unset") then
		new_value = nil
	elseif(r.r_operator and r.r_operator == "set_to_current_time") then
		-- we store the time in seconds - because microseconds would just
		-- confuse the users and be too fine grained anyway
		new_value = math.floor(minetest.get_us_time()/1000000)
	elseif(r.r_operator and r.r_operator == "quest_step") then
		-- quest_step and maximum are effectively the same
		-- TODO: later on, quest steps may be strings
		if(var_val and tonumber(var_val) and tonumber(r.r_var_cmp_value)) then
			new_value = math.max(tonumber(var_val), tonumber(r.r_var_cmp_value))
		else
			new_value = r.r_var_cmp_value
		end
	elseif(r.r_operator and r.r_operator == "maximum") then
		if(var_val and tonumber(var_val) and tonumber(r.r_var_cmp_value)) then
			new_value = math.max(tonumber(var_val), tonumber(r.r_var_cmp_value))
		else
			new_value = r.r_var_cmp_value
		end
	elseif(r.r_operator and r.r_operator == "minimum") then
		if(var_val and tonumber(var_val) and tonumber(r.r_var_cmp_value)) then
			new_value = math.min(tonumber(var_val), tonumber(r.r_var_cmp_value))
		else
			new_value = r.r_var_cmp_value
		end
	elseif(r.r_operator and r.r_operator == "increment") then
		if(var_val and tonumber(var_val) and tonumber(r.r_var_cmp_value)) then
			new_value = tonumber(var_val) + tonumber(r.r_var_cmp_value)
		else
			new_value = r.r_var_cmp_value
		end
	elseif(r.r_operator and r.r_operator == "decrement") then
		if(var_val and tonumber(var_val) and tonumber(r.r_var_cmp_value)) then
			new_value = tonumber(var_val) - tonumber(r.r_var_cmp_value)
		else
			new_value = -1 * r.r_var_cmp_value
		end
	else
		yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
			"state: Unsupported type: "..tostring(r.r_value)..".")
		-- keep the old value
		new_value = var_val
	end
	return new_value
end


-- executes an effect/result r for the player and npc n_id;
-- returns true on success (relevant for on_failure)
-- Note: In edit mode, this function does not get called.
yl_speak_up.execute_effect = function(player, n_id, o_id, r)
	if(not(r.r_type) or r.r_type == "") then
                -- nothing to do
                return true
	elseif(r.r_type == "auto" or r.r_type == "trade") then
		-- these effects don't do anything
		return true
	elseif(r.r_type == "put_into_block_inv"
	    or r.r_type == "take_from_block_inv") then
		-- get the inventory of the block
		if(not(r.r_pos) or type(r.r_pos) ~= "table"
		  or not(r.r_pos.x) or not(r.r_pos.y) or not(r.r_pos.z)) then
			-- position not found?
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": No or incorrect position given: "..
				minetest.serialize(r.rp_pos)..".")
			return false
		end
		local meta = minetest.get_meta(r.r_pos)
		if(not(meta)) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": Failed to get metadata at "..
				minetest.serialize(r.rp_pos)..".")
			return false
		end
		local inv = meta:get_inventory()
		if(not(inv)) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": Failed to get inventory at "..
				minetest.serialize(r.rp_pos)..".")
			return false
		end
		local inv_name = r.r_inv_list_name
		-- get the inventory of the npc
		local npc_inv = minetest.get_inventory({type="detached",
					name="yl_speak_up_npc_"..tostring(n_id)})
		local npc_inv_name = "npc_main"
		-- for easier checking
		local how_to_interact = "take"
		if(r.r_type and r.r_type == "put_into_block_inv") then
			how_to_interact = "put"
		end
		local stack = ItemStack(r.r_itemstack)
		-- is there enough room for the item?
		if(how_to_interact == "put"
		  and not(inv:room_for_item(inv_name, stack))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": No room for \""..
				minetest.serialize(r.r_itemstack).."\""..
				" in node at "..
				minetest.serialize(r.r_pos)..", inv list \""..
				minetest.serialize(inv_name).."\".")
			return false
		elseif(how_to_interact == "take"
		  and not(npc_inv:room_for_item("npc_main", stack))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": NPC has no room for \""..
				minetest.serialize(r.r_itemstack).."\".")
			return false
		end
		-- does the item exist?
		if(how_to_interact == "put"
		  and not(npc_inv:contains_item(npc_inv_name, stack, false))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": NPC does not have \""..
				minetest.serialize(r.r_itemstack).."\".")
			return false
		elseif(how_to_interact == "take"
		  and not(inv:contains_item(inv_name, stack, false))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": Block at "..minetest.serialize(r.r_pos)..
				" does not contain \""..tostring(r.r_itemstack).."\" in list \""..
				tostring(r.r_inv_list).."\".")
			return false
		end
		-- check the blacklist
		local node = minetest.get_node(r.r_pos)
		if(not(node) or not(node.name)) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": No node found at "..minetest.serialize(r.r_pos)..".")
			return false
		end
		-- do not interact with nodes on the blacklist
		-- (this here is inventory interaction, so no need to check for tools)
		if(yl_speak_up.check_blacklisted(how_to_interact, node.name, node.name, nil)) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": Blocks of type \""..tostring(node.name).."\" do not allow "..
				"interaction of type \""..tostring(r.r_value).."\" for NPC.")
			return false
		end
		-- construct a fake player
		local owner_name = yl_speak_up.npc_owner[ n_id ]
		if(not(owner_name) or owner_name == "") then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": NPC does not have an owner. Aborting.")
			return false
		end
		-- act in the name of the owner when accessing inventories
		local fake_player = yl_speak_up.get_fake_player(owner_name, "")
		local def = minetest.registered_nodes[ node.name ]
		if(def and def[ "allow_metadata_inventory_"..how_to_interact ]) then
			local res = def[ "allow_metadata_inventory_"..how_to_interact ](
						r.r_pos, inv_name, 1,
						ItemStack(r.r_itemstack),
						fake_player)
			if(not(res) or res < ItemStack(r.r_itemstack):get_count()) then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					r.r_type..": allow_metadata_inventory_"..tostring(how_to_interact)..
					" forbits interaction at "..minetest.serialize(r.r_pos)..".")
				return false
			end
		end
		-- all ok so far; we can proceed
		if(how_to_interact == "put") then
			local r1 = npc_inv:remove_item(npc_inv_name, stack)
			local r2 = inv:add_item(inv_name, r1)
			return true
		elseif(how_to_interact == "take") then
			local r1 = inv:remove_item(inv_name, stack)
			local r2 = npc_inv:add_item(npc_inv_name, r1)
			return true
		end
		return false
	elseif(r.r_type == "deal_with_offered_item") then
		-- possible r_value: "do_nothing", "take_as_wanted", "take_all", "refuse_all"}
		if(not(r.r_value) or r.r_value == "do_nothing") then
			return true -- we're good at doing nothing
		end
		local pname = player:get_player_name()
		local inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
		local stack_got = inv:get_stack("npc_wants",1)
		if(stack_got:is_empty()) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					r.r_type..": The offered stack is empty.")
			return false -- the player gave nothing
		end
		-- get the inventory of the npc
		local npc_inv = minetest.get_inventory({type="detached",
					name="yl_speak_up_npc_"..tostring(n_id)})
		-- shall we take all or just as much as the NPC wants?
		local stack_wanted = ItemStack(r.r_value)
		local amount = 0
		if(r.r_value == "take_all") then
			amount = stack_got:get_count()
		elseif(r.r_value == "takeas_wanted") then
			amount = stack_wanted:get_count()
			-- the NPC didn't get enough
			if(amount > stack_got:get_count()) then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					r.r_type..": The offered stack \""..tostring(stack_got)..
					"is smaller than what the NPC wanted: \""..
					tostring(stack_wanted).."\".")
				return false
			end
		end
		local take_stack = stack_got:get_name().." "..tostring(amount)
		if(not(npc_inv:room_for_item("npc_main", take_stack))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": The NPC has not enough room for \""..tostring(take_stack).."\".")
			return false
		end
		-- actually transfer the item from the player to the NPC's inventory
		npc_inv:add_item("npc_main", take_stack)
		inv:remove_item("npc_wants", take_stack)
		-- returning of any leftover items needs to happen after *all* effects
		-- are executed; we don't need to take any special preparations here

		-- this action was a success
		return true

	elseif(r.r_type == "dialog"
	    or r.r_type == "on_failure") then
		-- this needs to be handled in the calling function
		return true
	elseif(r.r_type == "function") then
	-- this can only be set and edited with the staff
		if(not(yl_speak_up.npc_has_priv(n_id, "effect_exec_lua", r.r_is_generic))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": The NPC does not have the \"effect_exec_lua\" priv.")
			return false
		end
		return yl_speak_up.eval_and_execute_function(player, r, "r_")
	-- this can only be set and edited with the staff
	elseif(r.r_type == "give_item") then
		if(not(r.r_value)) then
			return false
		end
		if(not(yl_speak_up.npc_has_priv(n_id, "effect_give_item", r.r_is_generic))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": The NPC does not have the \"effect_give_item\" priv.")
			return false
		end
		local item = ItemStack(r.r_value)
		if(not(minetest.registered_items[item:get_name()])) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"give_item: "..tostring(item:get_name()).." unknown.")
			return false
		end
		local r = player:get_inventory():add_item("main", item)
		if(not(r) or not(r:is_empty())) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"give_item: "..tostring(item:get_name()).." failed.")
			local pname = player:get_player_name()
			yl_speak_up.log_change(pname, n_id, "No room for item: "..r:to_string())
			return false
		end
		return true
	-- this can only be set and edited with the staff
	elseif(r.r_type == "take_item") then
		if(not(yl_speak_up.npc_has_priv(n_id, "effect_take_item", r.r_is_generic))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": The NPC does not have the \"effect_take_item\" priv.")
			return false
		end
		if(not(r.r_value)) then
			return false
		end
		local item = ItemStack(r.r_value)
		if(not(minetest.registered_items[item:get_name()])) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"take_item: "..tostring(item:get_name()).." unknown.")
			return false
		end
		local r = player:get_inventory():remove_item("main", item)
		if(not(r)) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"take_item: "..tostring(item:get_name()).." failed.")
			return false
		end
		return true
	-- this can only be set and edited with the staff
	elseif(r.r_type == "move") then
		if(not(yl_speak_up.npc_has_priv(n_id, "effect_move_player", r.r_is_generic))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": The NPC does not have the \"effect_move_player\" priv.")
			return false
		end
		-- copeid/moved here from AliasAlreadyTakens code in functions.lua
		local target_pos = nil
		local target_pos_valid = false

		--pos like (100,20,400)
		if minetest.string_to_pos(r.r_value) then
		    target_pos = minetest.string_to_pos(r.r_value)
		    target_pos_valid = true
		end

		--pos like 100,20,400
		local maybe = string.split(r.r_value, ",")
		if not target_pos_valid and maybe and tonumber(maybe[1])
		  and tonumber(maybe[2]) and tonumber(maybe[3]) and maybe[4] == nil and
		    tonumber(maybe[1]) <= 32000 and tonumber(maybe[1]) >= -32000 and
		    tonumber(maybe[2]) <= 32000 and tonumber(maybe[2]) >= -32000 and
		    tonumber(maybe[3]) <= 32000 and tonumber(maybe[3]) >= -32000 then
		        target_pos = {x=maybe[1],y=maybe[2],z=maybe[3]}
		        target_pos_valid = true
		end

		--pos like {x=100,y=20,z=400}
		if not target_pos_valid and string.sub(r.r_value,1,1) == "{"
		  and string.sub(r.r_value,-1,-1) == "}" then
		    local might_be_pos = minetest.deserialize("return " .. r.r_value)
		    if tonumber(might_be_pos.x)
		     and tonumber(might_be_pos.x) <= 32000
		     and tonumber(might_be_pos.x) >= -32000
		     and tonumber(might_be_pos.y)
		     and tonumber(might_be_pos.y) <= 32000
		     and tonumber(might_be_pos.y) >= -32000
		     and tonumber(might_be_pos.z)
		     and tonumber(might_be_pos.z) <= 32000
		     and tonumber(might_be_pos.z) >= -32000 then
		        target_pos = might_be_pos
		        target_pos_valid = true
		    end
		end

		if target_pos_valid == true then
		    player:set_pos(target_pos)
		    if vector.distance(player:get_pos(),target_pos) >= 2 then
			yl_speak_up.log_change(pname, n_id, tostring(r.r_id)..": "..
				"Something went wrong! Player wasn't moved properly.")
		    end
		end

		-- Debug
		if target_pos_valid == false then
		    local obj = yl_speak_up.speak_to[pname].obj
		    local n_id = yl_speak_up.speak_to[pname].n_id
		    local npc = yl_speak_up.get_number_from_id(n_id)
		    if obj:get_luaentity() and tonumber(npc) then
			yl_speak_up.log_change(pname, n_id, tostring(r.r_id)..": "..
				"NPC at "..minetest.pos_to_string(obj:get_pos(),0)..
				" could not move player "..pname.." because the content of "..
				tostring(r.r_id).." is wrong:"..dump(r.r_value))
		    else
			yl_speak_up.log_change(pname, n_id, tostring(r.r_id)..": "..
				"NPC with unknown ID or without proper object "..
				" could not move player "..pname.." because the content of "..
				tostring(r.r_id).." is wrong:"..dump(r.r_value))
		    end
		    return false
		end
		return true

	-- "an internal state (i.e. of a quest)", -- 2
	elseif(r.r_type == "state") then
		if(not(r.r_variable) or r.r_variable == "") then
			return false
		end
		local pname = player:get_player_name()
		-- set the value of the variable
		local new_value = yl_speak_up.execute_effect_get_new_value(r, nil, pname)
		-- the owner is already encoded in the variable name
		local ret = yl_speak_up.set_quest_variable_value(pname, r.r_variable, new_value)
		yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
			"state: Success: "..tostring(ret).." for setting "..tostring(r.r_variable).." to "..
			tostring(new_value)..".")
                return ret
	-- "the value of a property of the NPC (for generic NPC)", -- property
	elseif(r.r_type == "property") then
		local pname = player:get_player_name()
		-- get the properties of the NPC
		local properties = yl_speak_up.get_npc_properties(pname)
		if(not(properties)) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"property: Failed to access properties of NPC "..tostring(n_id))
			return false
		end
		if(not(r.r_value) or r.r_value == "") then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"property: No name of property given")
			return false
		end
		local var_val = properties[r.r_value]
		-- set the value of the variable
		local new_value = yl_speak_up.execute_effect_get_new_value(r, var_val, nil)
		local res = yl_speak_up.set_npc_property(pname, r.r_value, new_value, "effect")
		if(res ~= "OK") then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"property: "..tostring(res))
			return false
		end
		yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
			"state: Success: Set property "..tostring(r.r_value).." to "..
			tostring(new_value)..".")
		return true
	-- "something that has to be calculated or evaluated (=call a function)", -- evaluate
	elseif(r.r_type == "evaluate") then
		if(not(player) or not(r.r_value)) then
			return false
		end
		local custom_data = yl_speak_up.custom_functions_r_[r.r_value]
		if(not(custom_data) or not(custom_data.code)) then
			return false
		end
		local fun = custom_data.code
		-- actually call the function
		return fun(player, n_id, r)
	-- "a block somewhere" -- 3
	elseif(r.r_type == "block") then
		-- is the position given correctly?
		if(not(r.r_pos) or type(r.r_pos) ~= "table"
		 or not(r.r_pos.x) or not(r.r_pos.y) or not(r.r_pos.z)) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"block: Missing or wrong position given: "..
				minetest.serialize(r.r_pos)..".")
			return false
		end
		-- check protection (relevant for some actions): the *owner*
		-- of the NPC needs to be able to build there
		local is_protected = minetest.is_protected(r.r_pos, yl_speak_up.npc_owner[ n_id ] or "?")
		-- human readable position; mostly for debug messages
		local pos_str = tostring(minetest.pos_to_string(r.r_pos))
		-- the area has to be loaded
		local node = minetest.get_node_or_nil(r.r_pos)
		if(not(node)) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"block: Not loaded (nil) at pos "..pos_str..".")
			return false
		end
		-- do not interact with nodes on the blacklist
		if(yl_speak_up.check_blacklisted(r.r_value, r.r_node, node.name, nil)) then
			-- construct the right text for the error message
			local nname = node.name
			if(r.r_value == "place") then
				nname = r.r_node
			end
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"block: Blocks of type \""..tostring(nname).."\" do not allow "..
				"interaction of type \""..tostring(r.r_value).."\" for NPC.")
			return false
		end
		-- if node has owner set: check if owner == npc owner
		local meta = minetest.get_meta(r.r_pos)
		if(meta
		  and meta:get_string("owner") and meta:get_string("owner") ~= ""
		  and meta:get_string("owner") ~= yl_speak_up.npc_owner[ n_id ]) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"block: Blocks at "..pos_str.." is owned by "..meta:get_string("owner")..
				". NPC is owned by "..tostring(yl_speak_up.npc_owner[ n_id ])..
				" and thus cannot interact with it.")
			return false
		end
		-- create a fake player and a suitable itemstack
		local owner_name = yl_speak_up.npc_owner[ n_id ]
		if(not(owner_name) or owner_name == "") then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				r.r_type..": NPC does not have an owner. Aborting.")
			return false
		end

		-- "If there is air: Place a block so that it looks like now.", -- 2
		if(r.r_value and r.r_value == "place") then
			if(is_protected) then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: place - "..pos_str.." is protected. Can't place.")
				return false
			end
			if(not(node) or not(node.name) or node.name ~= "air") then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: place - there is already a block at pos "..pos_str..
					". Can't place.")
				return false
			end
			-- does the NPC have this block in his inventory? else he can't place it
			local npc_inv = minetest.get_inventory({type="detached",
					name="yl_speak_up_npc_"..tostring(n_id)})
			if(not(npc_inv:contains_item("npc_main", tostring(r.r_node)))) then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: place - NPC does not have "..tostring(r.r_node)..
					" in his inventory for placing at "..pos_str..".")
				return false
			end
			-- TODO: switch to minetest.place_node in the future once the bug with placing
			--       on an air node is fixed
			-- actually place the node
			minetest.set_node(r.r_pos, {name=r.r_node, param2=r.r_param2})
			-- consume the item
			npc_inv:remove_item("npc_main", tostring(r.r_node))
			return true
		-- "If there is a block: Dig it.", -- 3
		elseif(r.r_value and r.r_value == "dig") then
			if(is_protected) then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: place - "..pos_str.." is protected. Can't place.")
				return false
			end
			if(not(node) or not(node.name) or node.name == "air"
			   or not(minetest.registered_items[ node.name ])) then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: dig - there is no block at pos "..pos_str..".")
				return false
			end
			-- TODO: use dig_node once that can put the items in the inventory
			-- local dig_res = minetest.dig_node(r.r_pos)
			if(minetest.registered_items[ node.name ].can_dig
			   and not(minetest.registered_items[ node.name ].can_dig(r.r_pos))) then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: dig - Can't dig block at pos "..pos_str..".")
				return false
			end
			-- actually remove the node
			minetest.remove_node(r.r_pos)
			-- get node drops when digging without a tool
			local drop_list = minetest.get_node_drops(node, nil)
			local npc_inv = minetest.get_inventory({type="detached",
				name="yl_speak_up_npc_"..tostring(n_id)})
			-- put the drops into the inventory of the NPC
			for i, d in ipairs(drop_list or {}) do
				local rest = npc_inv:add_item("npc_main", ItemStack(d))
				if(rest and not(rest:is_empty()) and rest:get_count()>0) then
					yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id)..
					" block: dig (info) - NPC had no room for item drop "..
					rest:to_string().." from digging at "..pos_str..".")
				end
			end
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: dig - success: "..tostring(node.name).." at pos "..pos_str..".")
			return true
		-- "Punch the block.", -- 4
		elseif(r.r_value and r.r_value == "punch") then
			-- shall the NPC wield and use an item? if so that items' on_use function takes
			-- precedence
			if(r.r_wielded and r.r_wielded ~= "") then
				return yl_speak_up.use_tool_on_block(r, "on_use", player, n_id, o_id)
			end
			-- even air can be punched - even if that is pretty pointless
			-- TODO: some blocks may define their own functions and care for what the player wields (i.e. cheese mod)
			minetest.punch_node(r.r_pos, nil)
			return true
		-- "Right-click the block.", -- 5
		elseif(r.r_value and r.r_value == "right-click") then
			-- shall the NPC wield and use an item? if so that items' on_use function takes
			-- precedence
			if(r.r_wielded and r.r_wielded ~= "") then
				return yl_speak_up.use_tool_on_block(r, "on_place", player, n_id, o_id)
			end
			-- with a tool, clicking on air might make sense; without a tool it doesn't
			if(not(node) or not(node.name) or not(minetest.registered_nodes[node.name])) then
				return false
			end
			-- do not right-click nodes that have a metadata formspec string
			local meta = minetest.get_meta(r.r_pos)
			if(meta and meta:get_string("formspec") and meta:get_string("formspec") ~= "") then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: right-click - The block at "..pos_str.." has a "..
					"formspec set. NPC can't read these. Interaction not possible.")
				return false
			end
			-- do not right-click nodes that have an inventory (they most likely show a
			-- formspec - which the NPC can't use anyway)
			local inv = meta:get_inventory()
			for k, l in pairs(inv:get_lists()) do
				-- if the inventory contains any lists: abort
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: right-click - The block at "..pos_str.." has an "..
					"inventory. Most likely it will show a formspec on right-click. "..
					"NPC can't read these. Interaction not possible.")
				return false
			end
			-- is it a door?
			if(doors.registered_doors[node.name]) then
				doors.door_toggle(    r.r_pos, node, nil) --, clicker)
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: Opened/closed door at "..pos_str..".")
			-- is it a normal trapdoor?
			elseif(doors.registered_trapdoors[node.name]) then
				doors.trapdoor_toggle(r.r_pos, node, nil) --, clicker)
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"block: Opened/closed trapdoor at "..pos_str..".")
			elseif(minetest.registered_nodes[node.name]
			  and minetest.registered_nodes[node.name].on_rightclick) then
				local fake_player = yl_speak_up.get_fake_player(owner_name, "")
				local itemstack = ItemStack("")
				local pointed_thing = nil -- TODO
				if(minetest.registered_nodes[node.name].on_rightclick(
					r.r_pos, node, fake_player, itemstack, pointed_thing)) then
					yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
						"block: right-clicked at at pos "..pos_str..".")
				else
					yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
						"block: right-click at at pos "..pos_str.." had no effect.")
				end
			end
		end
		return false
	-- ""NPC crafts something", -- 4
	elseif(r.r_type == "craft") then
		if(not(r.r_craft_grid) or not(r.r_value)) then
			return false
		end
		local input = {}
		input.items = {}
		-- multiple slots in the craft grid may contain the same item
		local sum_up = {}
		for i, v in ipairs(r.r_craft_grid or {}) do
			if(v and v ~= "") then
				local stack = ItemStack(v)
				-- store this for later crafting
				input.items[ i ] = stack
				local name = stack:get_name()
				if(sum_up[ name ]) then
					sum_up[ name ] = sum_up[ name ] + stack:get_count()
				else
					sum_up[ name ] = stack:get_count()
				end
			else
				-- empty itemstack in this slot
				input.items[ i ] = ItemStack("")
			end
		end
		-- does the NPC have all these items in his inventory?
		local npc_inv = minetest.get_inventory({type="detached",
					name="yl_speak_up_npc_"..tostring(n_id)})
		for k, v in pairs(sum_up) do
                        if(not(npc_inv:contains_item("npc_main", k.." "..v))) then
				yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
					"Crafting failed: NPC does not have "..tostring(k.." "..v))
				return false
			end
		end
		-- do these input items form a valid craft recipe?
		input.method = "normal" -- normal crafting; no cooking or fuel or the like
		input.width = 3
		local output, decremented_input = minetest.get_craft_result(input)
		if(output.item:is_empty()) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"Crafting failed: No output for that recipe.")
			return false
		end
		-- the craft receipe may have changed in the meantime and yield a diffrent result
		local expected_stack = ItemStack(r.r_value)
		if(output.item:get_name() ~= expected_stack:get_name()
		  or output.item:get_count() ~= expected_stack:get_count()) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"Crafting failed: Diffrent output: "..tostring(output.item:to_string()))
			return false
		end
		yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"Great: Crafting is possible!")
		-- actually consume the items required, return the ones in decremented_input
		for i, v in ipairs(r.r_craft_grid or {}) do
			if(v and v ~= "") then
				npc_inv:remove_item("npc_main", ItemStack(v))
			end
		end
		-- add the craft result
		if(not(npc_inv:room_for_item("npc_main", output.item))) then
			yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
				"No room for craft result "..output.item:to_string())
		end
		npc_inv:add_item("npc_main", output.item)
		-- add the decremented_inputs
		for k,v in pairs(decremented_input.items or {}) do
			if(k and not(v:is_empty())) then
				if(not(npc_inv:room_for_item("npc_main", v))) then
					yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
						"No room for craft decr. input "..v:to_string())
				end
				-- actually give the decremented input to the NPC
				npc_inv:add_item("npc_main", v)
			end
		end
		return true
	-- "send a chat message to all players", -- 6
	elseif(r.r_type == "chat_all") then
		local pname = player:get_player_name()
		local dialog = yl_speak_up.speak_to[pname].dialog
		local text = r.r_value
		-- replace $NPC_NAME$, $OWNER_NAME$, $PLAYER_NAME$ etc.
		text = yl_speak_up.replace_vars_in_text(text, dialog, pname)
		minetest.chat_send_all(
			yl_speak_up.chat_all_prefix..
			minetest.colorize(yl_speak_up.chat_all_color, text))
		-- sending a chat message always counts as successful
		return true
	end
	-- fallback: unkown type
	return false
end
