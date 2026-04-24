
-- helper function; get a formspec with the inventory of the player (for selecting items)
yl_speak_up.fs_your_inventory_select_item = function(pname, data)
	return "label[0.2,4.2;Name of the item(stack):]"..
		"field[4.0,4.0;16.0,0.6;inv_stack_name;;"..(data.inv_stack_name or "").."]"..
		"tooltip[inv_stack_name;Enter name of the block and amount.\n"..
			"Example: \"default:apple 3\" for three apples,\n"..
			"         \"farming:bread\" for a bread.]"..
		"label[0.2,5.7;Or put the item in here\nand click on \"Update\":]"..
		"button[5.5,5.5;1.5,0.9;store_item_name;Update]"..
		"list[detached:yl_speak_up_player_"..pname..";npc_wants;4.0,5.5;1,1;]"..
		"label[8,4.9;Your inventory:]"..
		"list[current_player;main;8,5.3;8,4;]"
end


-- helper function: get the names of the inventory lists of the node at position
-- pos on the map and return the index of search_for_list_name in that index
yl_speak_up.get_node_inv_lists = function(pos, search_for_list_name)
	if(not(pos)) then
		return {inv_lists = {"- no inventory -"}, index = "1"}
	end
	local meta = minetest.get_meta(pos)
	if(not(meta)) then
		return {inv_lists = {"- no inventory -"}, index = "1"}
	end
	local inv_lists = {}
	local index = -1
	local inv = meta:get_inventory()

	table.insert(inv_lists, minetest.formspec_escape("- please select -"))
	for k,v in pairs(inv:get_lists()) do
		table.insert(inv_lists, k)
		if(search_for_list_name == k) then
			index = #inv_lists
		end
	end
	return {inv_lists = inv_lists, index = tostring(index)}
end


-- helper function for yl_speak_up.handle_input_fs_edit_option_related
yl_speak_up.delete_element_p_or_a_or_e = function(
			player, pname, n_id, d_id, o_id, x_id, id_prefix,
			element_list_name, element_desc, formspec_input_to)
	-- does the dialog we want to modify exist?
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(dialog and dialog.n_dialogs
	  and x_id
	  and dialog.n_dialogs[d_id]
	  and dialog.n_dialogs[d_id].d_options
	  and dialog.n_dialogs[d_id].d_options[o_id])) then
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = "size[9,2]"..
				"label[0.2,0.5;The dialog that is supposed to contain the\n"..
				"element that you want to delete does not exist.]"..
				"button[1.5,1.5;2,0.9;back_from_cannot_be_edited;Back]"})
		return
	end
	local old_elem = dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ][ x_id ]
	if(id_prefix == "r_" and old_elem and old_elem.r_type == "dialog") then
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = "size[9,2]"..
				"label[0.2,0.5;Effects of the type \"dialog\" cannot be deleted.\n"..
				"Use the edit options or dialog menu to change the target dialog.]"..
				"button[1.5,1.5;2,0.9;back_from_cannot_be_edited;Back]"})
		return
	end
	-- actually delete the element
	dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ][ x_id ] = nil
	-- record this as a change, but do not save do disk yet
	table.insert(yl_speak_up.npc_was_changed[ n_id ],
		"Dialog "..tostring(d_id)..": "..element_desc.." "..tostring( x_id )..
		" deleted for option "..tostring(o_id)..".")
	-- TODO: when trying to save: save to disk as well?
	-- show the new/changed element
	-- go back to the edit option dialog (after all we just deleted the prerequirement)
	yl_speak_up.show_fs(player, "msg", {
		input_to = "yl_speak_up:"..formspec_input_to,
		formspec = "size[6,2]"..
			"label[0.2,0.5;"..element_desc.." \""..
			minetest.formspec_escape(tostring( x_id ))..
			"\" has been deleted.]"..
			"button[1.5,1.5;2,0.9;back_from_delete_element;Back]"})
	return
end


-- helper function for yl_speak_up.save_element_p_or_a_or_e
yl_speak_up.save_element_check_priv = function(player, priv_name, formspec_input_to, explanation)
	local priv_list = {}
	priv_list[priv_name] = true
	if(not(minetest.check_player_privs(player, priv_list))) then
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = "size[9,2]"..
				"label[0.2,0.5;Error: You need the \""..
					tostring(priv_name).."\" priv"..
					tostring(explanation)..".]"..
				"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
		return false
	end
	return true
end

-- helper function for yl_speak_up.handle_input_fs_edit_option_related
yl_speak_up.save_element_p_or_a_or_e = function(
			player, pname, n_id, d_id, o_id, x_id, id_prefix, tmp_data_cache,
			element_list_name, element_desc, max_entries_allowed,
			values_what, values_operator, values_block, values_trade, values_inv,
			formspec_input_to, data, fields)

	-- for creating the new prerequirement; normal elements: p_type, p_value, p_id
	local v = {}
	-- determine p_type
	v[ id_prefix.."type" ] = values_what[ data.what ]
	-- so that we don't have to compare number values of data.what
	local what_type = values_what[ data.what ]

	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(dialog) or not(dialog.n_dialogs)
	  or not(dialog.n_dialogs[d_id])
	  or not(dialog.n_dialogs[d_id].d_options)
	  or not(dialog.n_dialogs[d_id].d_options[o_id])) then
		-- this really should not happen during the normal course of operation
		-- (only if the player sends forged formspec data or a bug occoured)
		minetest.chat_send_player(pname, "Dialog or option does not exist.")
		return
	end
	local elements = dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ]
	if(not(elements)) then
		dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ] = {}
		elements = dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ]
		x_id = "new"
	end
	-- set x_id appropriately
	if(not(x_id) or x_id == "new") then
		x_id = id_prefix..yl_speak_up.find_next_id(elements)
	end
	v[ id_prefix.."id" ] = x_id

	-- if needed: show a message after successful save so that the player can take
	-- his items back from the trade_inv slots
	local show_save_msg = nil
	local sorted_key_list = yl_speak_up.sort_keys(elements)
	if( x_id == "new" and #sorted_key_list >= max_entries_allowed) then
		-- this really should not happen during the normal course of operation
		-- (only if the player sends forged formspec data or a bug occoured)
		minetest.chat_send_player(pname, "Maximum number of allowed entries exceeded.")
		return
	end
	-- "an internal state (i.e. of a quest)", -- 2
	if(what_type == "state" and id_prefix ~= "a_") then
		v[ id_prefix.."value" ] = "expression"
		v[ id_prefix.."operator" ] = values_operator[ data.operator ]
		v[ id_prefix.."var_cmp_value" ] = (data.var_cmp_value or "")
		-- if it is a custom server function,then do not preifx it with $ playername
		if(id_prefix == "p_") then
			local idx = table.indexof(yl_speak_up.custom_server_functions.precondition_descriptions,
			                          data.variable_name)
			if(idx > -1) then
				v[ id_prefix.."variable" ] = data.variable_name
			else
				v[ id_prefix.."variable" ] = yl_speak_up.add_pname_to_var(data.variable_name, pname)
			end
		else
			v[ id_prefix.."variable" ] = yl_speak_up.add_pname_to_var(data.variable_name, pname)
		end

	-- "the value of a property of the NPC (for generic NPC)"
	elseif(what_type == "property" and id_prefix ~= "a_") then
		v[ id_prefix.."value" ] = (data.property or "")
		v[ id_prefix.."operator" ] = values_operator[ data.operator ]
		v[ id_prefix.."var_cmp_value" ] = (data.var_cmp_value or "")

	-- "something that has to be calculated or evaluated (=call a function)"
	elseif(what_type == "evaluate") then
		v[ id_prefix.."value" ] = (data.function_name or "")
		v[ id_prefix.."operator" ] = values_operator[ data.operator ]
		v[ id_prefix.."var_cmp_value" ] = (data.var_cmp_value or "")
		-- transfer the parameters
		for i = 1, 9 do
			local s = "param"..tostring(i)
			v[ id_prefix..s ] = (data[s] or "")
		end

	-- "a block somewhere", -- 3
	elseif(what_type == "block" and id_prefix ~= "a_") then
		v[ id_prefix.."value" ] = values_block[ data.block ]
		if(not(data.block_pos) or not(data.node_data) or not(data.node_data.name)) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[8,2]"..
					"label[0.2,0.5;Error: Please select a block first!]"..
					"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
			return
		end
		-- for "node_is_air", there is no need to store node name and parameter
		if(v[ id_prefix.."value" ]
		  and (v[ id_prefix.."value" ] == "node_is_like"
		    or v[ id_prefix.."value" ] == "node_is_diffrent_from")
		    or v[ id_prefix.."value" ] == "place"
		    or v[ id_prefix.."value" ] == "dig"
		    or v[ id_prefix.."value" ] == "punch"
		    or v[ id_prefix.."value" ] == "right-click") then
			v[ id_prefix.."node" ]   = data.node_data.name
			v[ id_prefix.."param2" ] = data.node_data.param2
		end
		-- preconditions can be applied to all blocks; effects may be more limited
		if(id_prefix == "r_"
		  and yl_speak_up.check_blacklisted(v[id_prefix.."value"],
				-- we don't know yet which node will be there later on
				data.node_data.name, data.node_data.name)) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[8,2]"..
					"label[0.2,0.5;Error: Blocks of type \""..
					tostring(data.node_data.name).."\" do not allow\n"..
					"interaction of type \""..tostring(v[id_prefix.."value"])..
					"\" for NPC.]"..
					"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
			return
		end
		-- we also need to store the position of the node
		v[ id_prefix.."pos" ] = {x = data.block_pos.x, y = data.block_pos.y, z = data.block_pos.z }
		-- "I can't punch it. The block is as the block *above* the one I punched.",
		if(id_prefix == "p_" and data.block == 5) then
			v.p_pos.y = v.p_pos.y + 1
		end

	-- "a trade", -- 4
	-- (only for preconditions; not for effects)
	elseif(what_type == "trade" and id_prefix == "p_") then
		-- this depends on the trade associated with that option; therefore,
		-- it does not need any more parameters (they come dynamicly from the
		-- trade)
		v.p_value = values_trade[ data.trade ]

	-- "the inventory of the player", -- 5
	-- "the inventory of the NPC", -- 6
	-- "the inventory of a block somewhere", -- 7
	-- (only for preconditions; not for effects)
	elseif((id_prefix == "p_"
	       and (what_type == "player_inv" or what_type == "npc_inv" or what_type == "block_inv"))
	     or(id_prefix == "r_"
	       and (what_type == "put_into_block_inv" or what_type == "take_from_block_inv"))) then
		-- changing the inventory of a block? we need to set p_value to something
		if(id_prefix == "r_") then
			-- just to be sure something is stored there...
			v.r_value = data.inv_stack_name
			-- for easier access in the formspec
			v.r_itemstack = data.inv_stack_name
		-- store in p_value what we want to check regarding the inv (contains/contains not/empty/..)
		else
			v.p_value = values_inv[ data.inv ]
		end
		if(v.p_value and v.p_value ~= "inv_is_empty") then
			if(not(data.inv_stack_name) or data.inv_stack_name == "") then
				yl_speak_up.show_fs(player, "msg", {
					input_to = "yl_speak_up:"..formspec_input_to,
					formspec = "size[8,2]"..
						"label[0.2,0.5;Error: Please provide the name of the "..
							"\nitem you want to check for!]"..
						"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
				return
			end
			-- we have checked this value earlier on
			v[ id_prefix.."itemstack" ] = data.inv_stack_name
		end

		if(data and data.what_type == "player_inv") then
			data.inv_list_name = "main"
		elseif(data and data.what_type == "npc_inv") then
			data.inv_list_name = "npc_main"
		elseif(data and data.what_type == "block_inv") then
			data.inv_list_name = "main"
		end
		if(not(data.inv_list_name) or data.inv_list_name == "") then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[8,2]"..
					"label[0.2,0.5;Error: Please provide the name of the "..
						"\ninventory you want to access!]"..
					"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
			return
		end
		-- the name of the inventory list we want to access
		v[ id_prefix.."inv_list_name" ] = data.inv_list_name

		-- the inventory of a block
		if(what_type == "block_inv"
		  or what_type == "put_into_block_inv"
		  or what_type == "take_from_block_inv") then
			if(not(data.block_pos) or not(data.node_data) or not(data.node_data.name)) then
				yl_speak_up.show_fs(player, "msg", {
					input_to = "yl_speak_up:"..formspec_input_to,
					formspec = "size[8,2]"..
						"label[0.2,0.5;Error: Please select a block first!]"..
						"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
				return
			end
			-- we also need to store the position of the node
			v[ id_prefix.."pos" ] = {x = data.block_pos.x, y = data.block_pos.y, z = data.block_pos.z }
		end

	-- "give item (created out of thin air) to player (requires yl_speak_up.npc_privs_priv priv)", -- 9
	-- "take item from player and destroy it (requires yl_speak_up.npc_privs_priv priv)", -- 10
	elseif(id_prefix == "r_" and (what_type == "give_item" or what_type == "take_item")) then
		if(not(data.inv_stack_name) or data.inv_stack_name == "") then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[8,2]"..
					"label[0.2,0.5;Error: Please provide the name of the "..
						"\nitem you want to give or take!]"..
					"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
			return
		end
		local priv_list = {}
		if(not(yl_speak_up.save_element_check_priv(player,
				yl_speak_up.npc_priv_needs_player_priv["effect_"..what_type] or "privs",
				formspec_input_to, " in order to set this effect"))) then
			return
		end
		v[ "r_value" ] = data.inv_stack_name


	-- "move the player to a given position (requires yl_speak_up.npc_privs_priv priv)", -- 11
	elseif(what_type == "move" and id_prefix == "r_") then
		if(not(data.move_to_x) or not(data.move_to_y) or not(data.move_to_z)) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2]"..
					"label[0.2,0.5;Error: Please provide valid coordinates "..
						" x, y and z!]"..
					"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
			return
		end
		if(not(yl_speak_up.save_element_check_priv(player,
				yl_speak_up.npc_priv_needs_player_priv["effect_move_player"] or "privs",
				formspec_input_to, " in order to set this effect"))) then
			return
		end
		v[ "r_value" ] = minetest.pos_to_string(
			{x = data.move_to_x, y = data.move_to_y, z = data.move_to_z})

	-- effect "execute Lua code (requires npc_master priv)", -- precondition: 8; effect: 12
	elseif((what_type == "function" and id_prefix == "p_")
	    or (what_type == "function" and id_prefix == "r_")) then
		if(not(data.lua_code) or data.lua_code == "") then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2]"..
					"label[0.2,0.5;Error: Please enter the Lua code you want "..
						"to execute!]"..
					"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
			return
		end
		if(not(yl_speak_up.save_element_check_priv(player, "npc_master",
				formspec_input_to, " in order to set this"))) then
			return
		end
		v[ id_prefix.."value" ] = data.lua_code

	-- "NPC crafts something", -- 6
	-- (only for effects; not for preconditions)
	elseif(what_type == "craft" and id_prefix == "r_") then
		local player_inv = player:get_inventory()
		if(player_inv:get_stack("craftpreview", 1):is_empty()) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[8,2]"..
					"label[0.2,0.5;Error: Please prepare your craft grid first!"..
						"\nYour NPC needs to know what to craft.]"..
					"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
			return
		end
		-- store the craft result (Note: the craft result may change in the future
		-- if the server changes its craft result, making this craft invalid)
		v[ "r_value" ] = player_inv:get_stack("craftpreview", 1):to_string()
		v[ "r_craft_grid"] = {}
		for i = 1, 9 do
			-- store all the indigrents of the craft grid
			table.insert( v[ "r_craft_grid" ],
				player_inv:get_stack("craft", i):to_string())
		end

	-- "go to other dialog if the *previous* effect failed", -- 7
	-- (only for effects; not for preconditions)
	elseif(what_type == "on_failure" and id_prefix == "r_") then
		v[ "r_value" ] = data.on_failure

	-- "send a chat message to all players", -- 8
	-- (only for effects; not for preconditions)
	elseif(what_type == "chat_all" and id_prefix == "r_") then
		data.chat_msg_text = fields.chat_msg_text
		-- allow saving only if the placeholders are all present
		-- (reason for requiring them: players and server owners ought to
		-- be able to see who is responsible for a message)
		if(not(string.find(data.chat_msg_text, "%$NPC_NAME%$"))
		  or not(string.find(data.chat_msg_text, "%$PLAYER_NAME%$"))
		  or not(string.find(data.chat_msg_text, "%$OWNER_NAME%$"))) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;Error: Your chat message needs to contain "..
						"the following\nplaceholders: $NPC_NAME$, "..
						"$PLAYER_NAME$ and $OWNER_NAME$.\nThat way, other "..
						"players will know who sent the message.]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		v[ "r_value" ] = data.chat_msg_text

	-- "Normal trade - one item(stack) for another item(stack).", -- 3
	-- (only for actions)
	elseif(what_type == "trade" and id_prefix == "a_") then
		-- remember which option was selected
		yl_speak_up.speak_to[pname].o_id = o_id
		-- do not switch target dialog (we are in edit mode)
		yl_speak_up.speak_to[pname].target_d_id = nil
		-- just to make sure that the trade_id is properly set...
		if(not(data.trade_id)) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;Error: Missing trade ID.]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		-- the button is called store_trade_simple instead of save_element in
		-- the trade simple function(s); we want to store a trade
		fields.store_trade_simple = true
		local res = yl_speak_up.input_add_trade_simple(player, "", fields, nil)
		-- the above function sets:
		--    dialog.trades[ trade_id ] = {pay={ps},buy={bs}, d_id = d_id, o_id = o_id}
		-- store the trade as an action:
		local dialog = yl_speak_up.speak_to[pname].dialog
		if(res and dialog.trades and dialog.trades[ data.trade_id ]) then
			v[ "a_value" ] = data.trade_id
			v[ "a_pay"   ] = dialog.trades[ data.trade_id ].pay
			v[ "a_buy"   ] = dialog.trades[ data.trade_id ].buy
			yl_speak_up.edit_mode_set_a_on_failure(data, pname, v)
		end

	-- "The NPC gives something to the player (i.e. a quest item).", -- 4
	-- "The player is expected to give something to the NPC (i.e. a quest item).", -- 5
	-- (only for actions)
	elseif(((what_type == "npc_gives" or what_type == "npc_wants") and  id_prefix == "a_")
	     or (what_type == "player_offered_item" and id_prefix == "p_")) then
		local trade_inv_list = what_type
		if(id_prefix == "p_") then
			trade_inv_list = "npc_wants"
		end
		local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
		if(not(trade_inv) or trade_inv:is_empty( trade_inv_list )) then
			local what = "give to"
			if(id_prefix == "p_") then
				what = "accept from"
			end
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;Please insert an item first! Your NPC "..
						"needs\nto know what it shall "..what.." the player.]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		yl_speak_up.edit_mode_set_a_on_failure(data, pname, v)
		-- change the node in the slot
		local stack = trade_inv:get_stack( trade_inv_list, 1)
		if(not(stack) or not(minetest.registered_items[ stack:get_name() ])) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;This item is unkown. Please use only known"..
						"items.]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		-- is this particular item blacklisted on this server?
		-- this is only relevant for actions, not for preconditions
		if(id_prefix ~= "p_" and yl_speak_up.blacklist_action_quest_item[ stack:get_name() ]) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;Sorry. This item is blacklisted on this "..
						"server.\nYou can't use it as a quest item.]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		local meta = stack:get_meta()
		-- what does the NPC want to give?
		v[ id_prefix.."value" ] = stack:get_name().." "..stack:get_count()
		-- for displaying as a background image
		data.item_string = v[ id_prefix.."value" ]
		if(what_type == "npc_wants" or what_type == "player_offered_item") then
			-- try to reconstruct $PLAYER_NAME$ (may not always work)
			local item_was_for = meta:get_string("yl_speak_up:quest_item_for")
			local new_desc = meta:get_string("description")
			if(item_was_for and item_was_for ~= "") then
				new_desc = string.gsub(new_desc, item_was_for, "$PLAYER_NAME$")
			end
			data.item_desc = new_desc
		end
		-- set new description if there is one set (optional)
		if(data.item_desc
		  and data.item_desc ~= ""
		  and data.item_desc ~= "- none set -") then
			if(what_type == "npc_gives") then
				meta:set_string("description", data.item_desc)
			end
			v[ id_prefix.."item_desc" ] = data.item_desc
		end
		if(what_type == "npc_wants" or what_type == "player_offers_item") then
			data.item_quest_id = meta:get_string("yl_speak_up:quest_id")
		end
		-- set special ID (optional)
		if(data.item_quest_id
		  and data.item_quest_id ~= ""
		  and data.item_quest_id ~= "- no item set -") then
			if(what_type == "npc_gives") then
				-- which player got this quest item?
				meta:set_string("yl_speak_up:quest_item_for", pname)
				-- include the NPC id so that we know which NPC gave it
				meta:set_string("yl_speak_up:quest_item_from", tostring(n_id))
				-- extend quest_id by NPC id so that it becomes more uniq
				meta:set_string("yl_speak_up:quest_id",
					tostring(n_id).." "..tostring(data.item_quest_id))
			end
			v[ id_prefix.."item_quest_id" ] = data.item_quest_id
		end
		if( v["a_item_quest_id"] and not(v[ "a_item_desc"]) and what_type == "npc_gives") then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;You can't set a special quest ID without "..
					"also changing\nthe description. The player would be "..
					"unable to tell\nthe quest item and normal items "..
					"apartapart.]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		if(data.item_group and data.item_group ~= ""
		   and data.item_group ~= "- no, just this one item -") then
			v["p_item_group"] = data.item_group
		end
		v["p_item_stack_size"] = data.item_stack_size
		v["p_match_stack_size"] = data.match_stack_size
		local player_inv = player:get_inventory()
		if(not(player_inv:room_for_item("main", stack))) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;You have no room in your inventory for "..
					"the example\nitem. Please make room so that it can be"..
					"given back to you!]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		player_inv:add_item("main", stack)
		trade_inv:remove_item(trade_inv_list, stack)
		-- just send a message that the save was successful and give the player time to
		-- take his items back
		show_save_msg = "size[9,2.5]"..
			"label[0.2,0.5;The information was saved successfully.\n"..
				"The item has been returned to your inventory.]"..
			"button[1.5,2.0;2,0.9;back_from_saving;Back]"

	-- "The player has to manually enter a password or passphrase or some other text.", -- 6
	elseif(what_type == "text_input" and id_prefix == "a_") then
		if(not(data.quest_question)) then
			data.quest_question = "Your answer:"
		end
		v[ "a_question" ] = data.quest_question
		-- the player setting this up needs to provide the correct answer
		if(not(data.quest_answer)) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;Error: Please provide the correct answer!\n"..
					"The answer the player gives is checked against this.]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		v[ "a_value" ] = data.quest_answer
		if(not(data.action_failure_dialog)) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;Error: Please provide a target dialog if "..
					"the player gives the wrong answer.]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		yl_speak_up.edit_mode_set_a_on_failure(data, pname, v)

	elseif(what_type == "deal_with_offered_item" and id_prefix == "r_") then
		if(not(data.select_deal_with_offered_item) or data.select_deal_with_offered_item < 2) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[9,2.5]"..
					"label[0.2,0.5;Error: Please select what the NPC shall do!]"..
					"button[1.5,2.0;2,0.9;back_from_error_msg;Back]"})
			return
		end
		v[ "r_value" ] = yl_speak_up.dropdown_values_deal_with_offered_item[data.select_deal_with_offered_item]

	-- "Call custom functions that are supposed to be overridden by the server.", --
	-- precondition: 9; action: 7; effect: 13
	elseif((id_prefix == "a_" and what_type == "custom")
	    or (id_prefix == "p_" and what_type == "custom")
	    or (id_prefix == "r_" and what_type == "custom")) then
		v[ id_prefix.."value" ] = data.custom_param
		if(id_prefix == "a_") then
			v[ "a_on_failure" ] = data.action_failure_dialog
		end

	-- "the type of the entity of the NPC",
	-- precondition: (last entry)
	elseif(what_type == "entity_type" and id_prefix == "p_") then
		-- Note: We might check for minetest.registered_entities[data.entity_type] - but
		--       that doesn't really help much - so we skip that.
		v[ "p_value" ] = data.entity_type

	-- "The preconditions of another dialog option are fulfilled/not fulfilled.", -- 10
	-- precondition: 10
	elseif(what_type == "other" and id_prefix == "p_") then
		if(data.other_o_id and data.other_o_id ~= "-select-") then
			v[ "p_value" ] = data.other_o_id
		end
		if(data.fulfilled  and data.fulfilled  ~= "-select-") then
			v[ "p_fulfilled" ] = data.fulfilled
		end

	elseif(what_type == "true") then
		v[ "p_value" ] = true -- doesn't matter here - just *some* value
	elseif(what_type == "false") then
		v[ "p_value" ] = true -- doesn't matter here - just *some* value
	end

	v[ "alternate_text" ] = data.alternate_text

	-- only save if something was actually selected
	if(v[ id_prefix.."value"]) then
		if(not(dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ])) then
			dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ] = {}
		end
		-- store the change in the dialog
		dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ][ x_id ] = v
		-- clear up data
		yl_speak_up.speak_to[pname][ id_prefix.."id" ] = nil
		yl_speak_up.speak_to[pname][ tmp_data_cache ] = nil
		-- record this as a change, but do not save do disk yet
		table.insert(yl_speak_up.npc_was_changed[ n_id ],
			"Dialog "..tostring(d_id)..": "..element_desc.." "..tostring(x_id)..
			" added/changed for option "..tostring(o_id)..".")
		if(show_save_msg) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = show_save_msg})
			return
		end
		-- TODO: when trying to save: save to disk as well?
		-- show the new/changed precondition
		yl_speak_up.show_fs(player, formspec_input_to, x_id)
		return
	else
		-- make sure the player is informed that saving failed
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = "size[8,2]"..
				"label[0.2,0.5;Error: There is no \""..tostring(id_prefix)..
					"value\" set.\n"..
					"\nCould not save.]"..
				"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
		return
	end
end


-- These two functions
--   * yl_speak_up.handle_input_fs_edit_option_related and
--   * yl_speak_up.build_fs_edit_option_related
-- are very similar for preconditions and effects. Therefore they're called here
-- with a lot of parameters. fs_edit_preconditions.lua and fs_edit_effects.lua
-- contain only wrappers.

yl_speak_up.handle_input_fs_edit_option_related = function(player, formname, fields,
		id_prefix, element_list_name, max_entries_allowed,
		element_desc, tmp_data_cache,
		text_ask_for_punching,
		values_what, values_operator, values_block, values_trade, values_inv,
		check_what, check_operator, check_block, check_trade, check_inv,
		get_sorted_player_var_list_function,
		formspec_input_to
		)
	if(not(player)) then
		return
	end
	local pname = player:get_player_name()
	-- what are we talking about?
	local n_id = yl_speak_up.speak_to[pname].n_id
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id
	local x_id = yl_speak_up.speak_to[pname][ id_prefix.."id"]

	-- this only works in edit mode
	if(not(n_id) or yl_speak_up.edit_mode[pname] ~= n_id) then
		return
	end

	if(fields.back_from_cannot_be_edited
	 or fields.back_from_show_var_usage) then
		yl_speak_up.show_fs(player, formspec_input_to, x_id)
		return
	end

	-- clear editing cache tmp_data_cache for all other types
	if(id_prefix ~= "p_") then
		yl_speak_up.speak_to[pname][ "tmp_prereq" ] = nil
	end
	if(id_prefix ~= "a_") then
		yl_speak_up.speak_to[pname][ "tmp_action" ] = nil
	end
	if(id_prefix ~= "r_") then
		yl_speak_up.speak_to[pname][ "tmp_effect" ] = nil
	end

	-- delete precondition, action or effect
	if(fields.delete_element) then
		yl_speak_up.delete_element_p_or_a_or_e( player, pname, n_id, d_id, o_id, x_id, id_prefix,
				element_list_name, element_desc, formspec_input_to)
		return
	end

	if(fields.select_block_pos) then
		minetest.chat_send_player(pname, text_ask_for_punching)
		-- this formspec expects the block punch:
		yl_speak_up.speak_to[pname].expect_block_punch = formspec_input_to
		return
	end

	-- field inputs: those do not trigger a sending of the formspec on their own

	local was_changed = false
	-- are we talking about an inventory?
	-- (inventory only applies to preconditions; not effects)
	local data = yl_speak_up.speak_to[pname][ tmp_data_cache ]
	local what_type = ""
	if(data and data.what and values_what[ data.what ]) then
		what_type = values_what[ data.what ]
	end

	if(((fields.inv_stack_name and fields.inv_stack_name ~= "")
	  or (fields.store_item_name and fields.store_item_name ~= ""))
	  and data and data.what
	  and ((id_prefix == "p_"
	        and (what_type == "player_inv" or what_type == "npc_inv" or what_type == "block_inv"))
	    -- "give item (created out of thin air) to player (requires yl_speak_up.npc_privs_priv priv)", -- 9
	    -- "take item from player and destroy it (requires yl_speak_up.npc_privs_priv priv)", -- 10
	    or (id_prefix == "r_"
	        and (what_type == "give_item" or what_type == "take_item"
		  or what_type == "put_into_block_inv" or what_type == "take_from_block_inv")))) then
		local wanted = ""
		local wanted_name = ""
		if(not(fields.store_item_name)) then
			local parts = fields.inv_stack_name:split(" ")
			local size = 1
			if(parts and #parts > 1) then
				size = tonumber(parts[2])
				if(not(size) or size < 1) then
					size = 1
				end
			end
			wanted = parts[1].." "..tostring(size)
			wanted_name = parts[1]
		else
			local trade_inv = minetest.get_inventory({type="detached",
						name="yl_speak_up_player_"..pname})
			if(not(trade_inv) or trade_inv:is_empty("npc_wants", 1)) then
				-- show error message
				yl_speak_up.show_fs(player, "msg", {
					input_to = "yl_speak_up:"..formspec_input_to,
					formspec = "size[8,2]"..
						"label[0.2,0.0;Please put an item(stack) into the slot "..
							"next to the\n\"Store\" button first!]"..
						"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
				return
			end
			local stack = trade_inv:get_stack("npc_wants", 1)
			wanted = stack:get_name().." "..stack:get_count()
			wanted_name = stack:get_name()
		end
		-- does the item exist?
		if(minetest.registered_items[ wanted_name ]) then
			data.inv_stack_name = wanted
			fields.inv_stack_name = wanted
		else
			-- show error message
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = "size[8,2]"..
					"label[0.2,0.5;Error: \""..
					minetest.formspec_escape(wanted)..
					"\" is not a valid item(stack).]"..
					"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
			return
		end

	elseif(fields.select_deal_with_offered_item and fields.select_deal_with_offered_item ~= "") then
		data.select_deal_with_offered_item = table.indexof(
				yl_speak_up.dropdown_list_deal_with_offered_item,
				fields.select_deal_with_offered_item)

	elseif(fields.select_accept_group and fields.select_accept_group ~= ""
	  and data and data.what and what_type == "player_offered_item" and id_prefix == "p_") then
		data.item_group = fields.select_accept_group

	elseif(fields.select_match_stack_size and fields.select_match_stack_size ~= ""
	  and data and data.what and what_type == "player_offered_item" and id_prefix == "p_") then
		data.match_stack_size = fields.select_match_stack_size:split(" ")[1]

	-- comparison value for a variable (same for both preconditions and effects)
	-- (also used for checking return values of functions and property values)
	elseif(fields.var_cmp_value
	  and data and data.what
	  and (what_type == "state" or what_type == "property" or what_type == "evaluate")) then
		data.var_cmp_value = fields.var_cmp_value
		was_changed = true

	-- text for a chat message
	elseif(fields.chat_msg_text
	  and data and data.what and what_type == "chat_all" and id_prefix == "r_") then
		data.chat_msg_text = fields.chat_msg_text
		was_changed = true

	elseif(fields.custom_param
	  and fields.custom_param ~= "- Insert a text that is passed on to your function here -"
	  and fields.custom_param ~= ""
	  and data and data.what
	  and ((id_prefix == "a_" and what_type == "custom")
	    or (id_prefix == "p_" and what_type == "custom")
	    or (id_prefix == "r_" and what_type == "custom"))) then
		data.custom_param = fields.custom_param
		was_changed = true

	elseif(fields.action_item_quest_id
	  and fields.action_item_quest_id ~= ""
	  and fields.action_item_quest_id ~= "- none set -"
	  and data and data.what and what_type == "npc_gives" and id_prefix == "a_") then
		data.item_quest_id = fields.action_item_quest_id
		was_changed = true
	end
	-- action_item_quest_id and action_item_desc can be set at the same time
	if(fields.action_item_desc
	  and fields.action_item_desc ~= ""
	  and fields.action_item_desc ~= "- no item set -"
	  and data and data.what and what_type == "npc_gives" and id_prefix == "a_") then
		-- TODO: check if it diffrent from the default one of the stack
		data.item_desc = fields.action_item_desc
		was_changed = true
	end
	if(fields.quest_question
	  and fields.quest_question ~= ""
	  and data and data.what and what_type == "text_input" and id_prefix == "a_") then
		data.quest_question = fields.quest_question
		was_changed = true
	end
	-- quest question and answer can be given with the same press of the save button
	if(fields.quest_answer
	  and fields.quest_answer ~= "- Insert the correct answer here -"
	  and fields.quest_answer ~= ""
	  and data and data.what and what_type == "text_input" and id_prefix == "a_") then
		data.quest_answer = fields.quest_answer
		was_changed = true
	end

	-- "move the player to a given position (requires yl_speak_up.npc_privs_priv priv)", -- 11
	if(fields.move_to_x or fields.move_to_y or fields.move_to_z) then
		local dimension = {"x","y","z"}
		for i, dim in ipairs(dimension) do
			local text = fields["move_to_"..dim]
			if(text and text ~= "") then
				local val = tonumber(text)
				if(not(val) or val < -32000 or val > 32000) then
					yl_speak_up.show_fs(player, "msg", {
						input_to = "yl_speak_up:"..formspec_input_to,
						formspec = "size[9,2]"..
							"label[0.2,0.5;Error: The coordinate values have "..
								"be in the range of -32000..32000.]"..
							"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
					return
				else
					data[ "move_to_"..dim ] = val
				end
			end
		end
	end
	-- lua code
	if(fields.lua_code) then
		data.lua_code = fields.lua_code
	end
	-- select the type of the entity for "the type of the entity of the NPC"
	if(fields.entity_type) then
		data.entity_type = fields.entity_type
	end
	-- if the type of operator is changed: store any new values that may need storing
	if(what_type == "evaluate"
	   and (fields.set_param0 or fields.set_param1 or fields.set_param2 or fields.set_param3
	     or fields.set_param4 or fields.set_param5 or fields.set_param6 or fields.set_param7
	     or fields.set_param8 or fields.set_param9)) then
		for i = 1, 9 do
			local pn = "param"..tostring(i)
			if(fields["set_"..pn]) then
				if(data[pn] ~= fields["set_"..pn]) then
					data[pn] = fields["set_"..pn]
					was_changed = true
				end
			end
		end
	end


	-- the save button was pressed
	if(fields.save_element and data and data.what and values_what[ data.what ]) then
		local v = yl_speak_up.save_element_p_or_a_or_e(
			player, pname, n_id, d_id, o_id, x_id, id_prefix, tmp_data_cache,
			element_list_name, element_desc, max_entries_allowed,
			values_what, values_operator, values_block, values_trade, values_inv,
			formspec_input_to, data, fields)
		return
	end


	-- selections in a dropdown menu (they trigger sending the formspec)

	-- select a general direction/type first
	-- but *not* when enter was pressed (enter sends them all)
	if(fields.select_what and not(fields.key_enter) and not(fields.store_item_name)) then
		local nr = table.indexof(check_what, fields.select_what)
		yl_speak_up.speak_to[pname][ tmp_data_cache ] = { what = nr }
	end
	-- select a subtype for the "a trade" selection
	if(fields.select_trade) then
		local nr = table.indexof(check_trade, fields.select_trade)
		yl_speak_up.speak_to[pname][ tmp_data_cache ].trade = nr
	end
	-- select a subtype for the inventory selection (player or NPC)
	if(fields.select_inv) then
		local nr = table.indexof(check_inv, fields.select_inv)
		yl_speak_up.speak_to[pname][ tmp_data_cache ].inv = nr
	end
	-- select data regarding a block
	if(fields.select_block) then
		local nr = table.indexof(check_block, fields.select_block)
		yl_speak_up.speak_to[pname][ tmp_data_cache ].block = nr
	end
	-- select data regarding the inventory list of a block
	if(fields.inv_list_name and fields.inv_list_name ~= "") then
		local tmp = yl_speak_up.get_node_inv_lists(
					yl_speak_up.speak_to[pname][ tmp_data_cache ].block_pos,
					fields.inv_list_name)
		-- if that inventory list really exists in that block: all ok
		if(tmp and tmp.index ~= "" and tmp.index ~= "1") then
			yl_speak_up.speak_to[pname][ tmp_data_cache ].inv_list_name = fields.inv_list_name
		end
	end
	-- select data regarding a variable
	if(fields.select_variable) then
		-- get the list of available variables (with the same elements
		-- and the same sort order as when the dropdown was displayed)
		local var_list = get_sorted_player_var_list_function(pname)
		yl_speak_up.strip_pname_from_varlist(var_list, pname)
		local nr = table.indexof(var_list, fields.select_variable)
		if(nr) then
			yl_speak_up.speak_to[pname][ tmp_data_cache ].variable = nr
			yl_speak_up.speak_to[pname][ tmp_data_cache ].variable_name = var_list[ nr ]
		end
	end
	-- select data regarding an operator
	if(fields.select_operator) then
		local nr = table.indexof(check_operator, fields.select_operator)
		yl_speak_up.speak_to[pname][ tmp_data_cache ].operator = nr
	end
	-- "the value of a property of the NPC (for generic NPC)"
	if(fields.property and fields.property ~= "") then
		yl_speak_up.speak_to[pname][ tmp_data_cache ].property = fields.property
	end
	-- "something that has to be calculated or evaluated (=call a function)"
	if(fields.select_function_name and fields.select_function_name ~= "") then
		for k, v in pairs(yl_speak_up["custom_functions_"..id_prefix]) do
			if(v["description"] == fields.select_function_name) then
				yl_speak_up.speak_to[pname][ tmp_data_cache ].function_name = k
			end
		end
	end
	-- "something that has to be calculated or evaluated (=call a function)"
	if(fields.evaluate and fields.evaluate ~= "") then
		yl_speak_up.speak_to[pname][ tmp_data_cache ].evaluate = fields.evaluate
	end
	for i = 1,9 do
		local s = "param"..tostring(i)
		if(fields[s] and fields[s] ~= "") then
			yl_speak_up.speak_to[pname][ tmp_data_cache ][s] = fields[s]
		end
	end
	-- another dialog option is true or false
	-- Note: "-select-" can be choosen here as well
	if(fields.select_other_o_id and fields.select_other_o_id ~= "") then
		yl_speak_up.speak_to[pname][ tmp_data_cache ].other_o_id = fields.select_other_o_id
	end
	-- Note: "-select-" can be choosen here as well
	if(fields.select_fulfilled and fields.select_fulfilled ~= "") then
		yl_speak_up.speak_to[pname][ tmp_data_cache ].fulfilled = fields.select_fulfilled
	end
	if(fields.select_on_failure) then
		-- in this case we really want the name of the target dialog
		local dialog = yl_speak_up.speak_to[pname].dialog
		yl_speak_up.speak_to[pname][ tmp_data_cache ].on_failure =
				yl_speak_up.d_name_to_d_id(dialog, fields.select_on_failure)
	end
	if(fields.select_on_action_failure
	  and data and data.what and id_prefix == "a_") then
		local dialog = yl_speak_up.speak_to[pname].dialog
		yl_speak_up.speak_to[pname][ tmp_data_cache ].action_failure_dialog =
				yl_speak_up.d_name_to_d_id(dialog, fields.select_on_action_failure)
	end

	-- new variables have to be added (and deleted) somewhere after all
	if(fields.manage_variables) then
		-- remember which formspec we are comming from
		yl_speak_up.speak_to[pname][ "working_at" ] = formspec_input_to
		if(data.variable) then
			yl_speak_up.speak_to[pname].tmp_index_variable = data.variable - 1
		end
		yl_speak_up.show_fs(player, "manage_variables")
		return
	end

	-- handle editing and changing of alternate texts for actions
	if(  fields.button_edit_action_on_failure_text_change
	  or fields.button_edit_effect_on_failure_text_change
	  or fields.turn_alternate_text_into_new_dialog
	  or fields.save_dialog_modification) then
		yl_speak_up.handle_edit_actions_alternate_text(
			player, pname, n_id, d_id, o_id, x_id, id_prefix,
			formspec_input_to, data, fields, tmp_data_cache)
		if(not(fields.save_dialog_modification)
		  and not(fields.turn_alternate_text_into_new_dialog)) then
			return
		end
		was_changed = true
	-- we are back from that submenu
	elseif(fields.back_from_edit_dialog_modification) then
		was_changed = true
	end

	-- show var usage - starting from clicking on a precondition or effect in the
	-- edit options menu and viewing the list containing that selected element
	if( fields.show_var_usage and x_id) then
		local dialog = yl_speak_up.speak_to[pname].dialog
		local element = dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ][ x_id ]
		if(element and element[ id_prefix.."variable"]) then
			local effect_name = "(Ef)fect"
			if(id_prefix == "p_") then
				effect_name = "pre(C)ondition"
			end
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = yl_speak_up.fs_get_list_of_usage_of_variable(
					element[ id_prefix.."variable"], pname, true,
					"back_from_show_var_usage",
					"Back to select "..effect_name.." "..tostring(x_id)..
						" of option "..tostring(o_id)..
						" of dialog "..tostring(d_id),
					-- internal variable?
					(data and data.variable and data.variable < 3))
				})
			return
		end
	-- show var usuage - but this time from the edit dialog for that precondition or effect
	elseif(fields.show_var_usage_edit_element and x_id) then
		local dialog = yl_speak_up.speak_to[pname].dialog
		local element = nil
		-- x_id may be "new" and this may be the first element in element_list_name
		if(dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ]) then
			element = dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ][ x_id ]
		end
		if(not(element) or data.variable_name) then
			element = {}
			element[ id_prefix.."variable"] = data.variable_name
		end
		if(element and element[ id_prefix.."variable"]) then
			local effect_name = "(Ef)fect"
			if(id_prefix == "p_") then
				effect_name = "pre(C)ondition"
			end
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..formspec_input_to,
				formspec = yl_speak_up.fs_get_list_of_usage_of_variable(
					element[ id_prefix.."variable"], pname, true,
					"back_from_error_msg",
					"Back to select "..effect_name.." "..tostring(x_id)..
						" of option "..tostring(o_id)..
						" of dialog "..tostring(d_id),
					-- internal variable?
					(data and data.variable and data.variable < 3))
				})
			return
		end
	-- allow to delete unused variables
	elseif(fields.delete_unused_variable) then
		-- try to delete the variable (button comes from the show usage of variable formspec)
		local text = yl_speak_up.del_quest_variable(pname, data.variable_name, nil)
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formspec_input_to,
			formspec = "size[10,2]"..
				"label[0.2,0.0;Trying to delete variable \""..
					minetest.formspec_escape(tostring(data.variable_name))..
					"\":\n"..text.."]"..
				"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
		return
	end

	-- the player wants to change/edit a precondition or effect
	if(not(fields.back)
	  and (fields.change_element or fields.select_what or fields.select_trade
	  or fields.select_inv or fields.select_block
	  or fields.inv_list_name
	  or fields.select_deal_with_offered_item
	  or fields.select_accept_group
	  or fields.select_match_stack_size
	  or fields.select_variable or fields.select_operator
	  or fields.select_on_failure
	  or fields.select_on_action_failure
	  or fields.back_from_error_msg
	  or fields.store_item_name
	  or fields.select_other_o_id
	  or fields.select_fulfilled
	  or fields.select_function_name
	  or fields.entity_type
	  or was_changed
	  or fields.key_enter
	  or fields.quit
	  -- return was pressed
	  or fields.key_enter_field)) then
		yl_speak_up.show_fs(player, formspec_input_to)
		return
	end

	-- go back to the edit option dialog
	yl_speak_up.show_fs(player, "edit_option_dialog",
		{n_id = n_id, d_id = d_id, o_id = o_id, caller= formspec_input_to})
end


yl_speak_up.build_fs_edit_option_related = function(player, table_click_result,
		id_prefix, element_list_name, max_entries_allowed,
		element_desc, tmp_data_cache,
		what_do_you_want_txt,
		values_what, values_operator, values_block, values_trade, values_inv,
		check_what, check_operator, check_block, check_trade, check_inv,
		get_sorted_player_var_list_function,
		show_element_function,
		table_of_name,
		text_variable, text_select_operator, text_select_value,
		text_block_position)
	if(not(player)) then
		return ""
	end
	local pname = player:get_player_name()
	-- what are we talking about?
	local n_id = yl_speak_up.speak_to[pname].n_id
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id
	local x_id = yl_speak_up.speak_to[pname][ id_prefix.."id" ]

	-- this only works in edit mode
	if(not(n_id) or yl_speak_up.edit_mode[pname] ~= n_id) then
		return "size[1,1]label[0,0;You cannot edit this NPC.]"
	end

	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(dialog) or not(dialog.n_dialogs)
	  or not(dialog.n_dialogs[d_id])
	  or not(dialog.n_dialogs[d_id].d_options)
	  or not(dialog.n_dialogs[d_id].d_options[o_id])) then
		return "size[4,1]label[0,0;Dialog option does not exist.]"
	end

	local elements = dialog.n_dialogs[d_id].d_options[o_id][ element_list_name ]
	if(not(elements)) then
		elements = {}
	end

	-- did we arrive here through clicking on an element in the dialog edit options menu?
	if(table_click_result or elements[ table_click_result ]) then
		if(not(elements[ table_click_result ])) then
			-- which element has the player selected?
			local sorted_key_list = yl_speak_up.sort_keys(elements)
			local selected = minetest.explode_table_event(table_click_result)
			-- use "new" if nothing fits
			x_id = "new"
			if((selected.type == "CHG" or selected.type == "DLC")
			  and selected.row <= #sorted_key_list) then
				x_id = sorted_key_list[ selected.row ]
			end

			if( x_id == "new" and #sorted_key_list >= max_entries_allowed) then
				return "size[9,1.5]"..
					"label[0.2,0.0;There are only up to "..
						minetest.formspec_escape(yl_speak_up.max_result_effects)..
						" "..element_desc.."s allowed per dialog option.]"..
						"button[2.0,0.8;1.0,0.9;back;Back]"
			end
		else
			-- allow to directly specify a x_id to show
			x_id = table_click_result
		end

		local show_var_usage = ""
		if(x_id

		  and elements[ x_id ]
		  and elements[ x_id ][ id_prefix.."type"]
		  and elements[ x_id ][ id_prefix.."type"] == "state"
		  and elements[ x_id ][ id_prefix.."variable"]) then
			show_var_usage = "button[12.0,1.8;6.5,0.9;show_var_usage;"..
					"Show where this variable is used]"
		end
		-- store which element we are talking about
		yl_speak_up.speak_to[pname][ id_prefix.."id" ] = x_id
		-- nothing selected yet
		yl_speak_up.speak_to[pname][ tmp_data_cache ] = nil
		-- display the selected element
		if(x_id ~= "new") then
			return "size[20,3]"..
				"bgcolor[#00000000;false]"..
				"label[0.2,0.5;Selected "..element_desc..":]"..
				"tablecolumns[text;color,span=1;text;text]"..
				"table[0.2,0.8;19.6,0.7;"..table_of_name..";"..
					minetest.formspec_escape(elements[ x_id ][ id_prefix.."id"])..
						",#FFFF00,"..
					minetest.formspec_escape(elements[ x_id ][ id_prefix.."type"])..
						","..
					minetest.formspec_escape(
						show_element_function(elements[ x_id ], pname))..";0]"..
				"button[2.0,1.8;1.5,0.9;delete_element;Delete]"..
				"button[4.0,1.8;1.5,0.9;change_element;Change]"..
				"button[6.0,1.8;5.5,0.9;back;Back to edit dialog option \""..
					tostring(o_id).."\"]"..
				show_var_usage
		end
	end

	local data = yl_speak_up.speak_to[pname][ tmp_data_cache ]

	if(not(data) or not(data.what)) then
		data = { what = 1}
	end
	-- fallback
	if(not(x_id)) then
		x_id = "new"
	end

	local e = nil
	-- does the element exist already? if so: use the existing values as presets for data
	-- (so that the element can be edited)
	-- does kind of the opposite than the saving of values starting in line 323 of this file
	if(x_id ~= "new" and data.what == 1 and elements[ x_id ]) then
		e = elements[ x_id ]
		if( id_prefix == "r_" and e[ "r_type" ] == "dialog") then
			-- dialog effects cannot be edited this way
			return "size[9,2]"..
				"label[0.2,0.5;Effects of the type \"dialog\" cannot be edited this way.\n"..
				"Use the edit options or dialog menu to change the target dialog.]"..
				"button[1.5,1.5;2,0.9;back_from_cannot_be_edited;Back]"
		end
		if( id_prefix == "p_" and e[ "p_type" ] == "item") then
			-- the staff-based item precondition can be translated to an editable
			-- inventory precondition which is equal
			e[ "p_type" ] = "player_inv"
			e[ "p_itemstack" ] = e[ "p_value"]
			e[ "p_value" ] = "inv_contains"
		end

		data.what = table.indexof(values_what, e[ id_prefix.."type" ])
		if(data.what == -1) then
			data.what = 1

		-- npc_gives/npc_wants (action)
		-- (two seperate functions, but can be handled here together)
		elseif(data.what and id_prefix == "a_" and (data.what == 4 or data.what == 5)) then
			data.action_failure_dialog = e[ "a_on_failure" ]
			-- data.item_string is used to show a background image
			data.item_string = e[ "a_value"] -- stack name and count (as string)
			data.item_desc = e[ "a_item_desc" ]
			data.item_quest_id = e[ "a_item_quest_id" ]

		-- player_offered_item precondition
		elseif(data.what and id_prefix == "p_" and (data.what == 8)) then
			-- data.item_string is used to show a background image
			data.item_string = e[ "p_value"] -- stack name and count (as string)
			data.item_desc = e[ "p_item_desc" ]
			data.item_quest_id = e[ "p_item_quest_id" ]
			data.item_group    = e[ "p_item_group" ]
			data.item_stack_size = e["p_item_stack_size"]
			data.match_stack_size = e["p_match_stack_size"]
		end

		if(e[ "alternate_text"]) then
			data.alternate_text = e[ "alternate_text" ]
		end
		-- write that data back
		yl_speak_up.speak_to[pname][ tmp_data_cache ] = data
	end

	local save_button = "button[5.0,12.2;1,0.7;save_element;Save]"
	local formspec =
		"size[20,13]"..
		"label[5,0.5;Edit "..element_desc.." \""..minetest.formspec_escape(x_id)..
			"\" of option \""..minetest.formspec_escape(tostring(o_id))..
			"\" of dialog \""..minetest.formspec_escape(tostring(d_id)).."\"]"..
		"label[0.2,1.5;"..what_do_you_want_txt.."]"..
		"label[0.2,2.0;Something regarding...]"..
		"dropdown[4.0,1.8;14.0,0.6;select_what;"..
			table.concat(check_what, ",")..";"..
			tostring(data.what)..";]"..
		"button[3.0,12.2;1,0.7;back;Abort]"

	if(id_prefix ~= "a_") then
		formspec = formspec..
			"label[1,10.5;If you are unsure if your setup of pre(C)onditions and (Ef)fects "..
				"works as intended,\ntype \"/npc_talk debug "..tostring(n_id).."\" "..
				"in chat in order to enter debug mode. You can leave it with "..
				"\"/npc_talk debug off\".]"
	end


	if(data.what) then
		yl_speak_up.speak_to[pname][ tmp_data_cache ] = data
	end
	local what_type = ""
	if(data and data.what and values_what[ data.what ]) then
		what_type = values_what[ data.what ]
	end
	-- "an internal state (i.e. of a quest)", -- 2
	-- (state is the second offered option in both preconditions and effects list)
	if(data.what and what_type == "state" and id_prefix ~= "a_") then
		return yl_speak_up.get_sub_fs_edit_option_p_and_e_state(
				pname, dialog, formspec, data, id_prefix, save_button, e,
				text_variable, text_select_value, text_select_operator,
				values_operator, check_operator, get_sorted_player_var_list_function )

	-- "the value of a property of the NPC (for generic NPC)"
	elseif(data.what and what_type == "property" and id_prefix ~= "a_") then
		return yl_speak_up.get_sub_fs_edit_option_p_and_e_property(
				pname, dialog, formspec, data, id_prefix, save_button, e,
				text_select_operator, values_operator, check_operator)

	-- "something that has to be calculated or evaluated (=call a function)"
	elseif(data.what and what_type == "evaluate") then
	return yl_speak_up.get_sub_fs_edit_option_p_and_e_evaluate(
			pname, dialog, formspec, data, id_prefix, save_button, e,
				text_select_operator, values_operator, check_operator)

	-- "a block somewhere", -- 3
	-- (block is the third offered option in both preconditions and effects list)
	elseif(data.what and what_type == "block" and id_prefix ~= "a_") then
		return yl_speak_up.get_sub_fs_edit_option_p_and_e_block(
				pname, dialog, formspec, data, id_prefix, save_button, e,
				text_block_position, values_block, check_block)

	-- "a trade", -- 4
	-- (trade - only for preconditions; effects have something else here)
	elseif(data.what and id_prefix == "p_" and what_type == "trade") then
		return yl_speak_up.get_sub_fs_edit_option_precondition_trade(
				pname, dialog, formspec, data, id_prefix, save_button, e,
				values_trade, check_trade)

	-- "the type of the entity of the NPC",
	-- (entity_type - only for preconditions)
	elseif(data.what and id_prefix == "p_" and what_type == "entity_type") then
		return yl_speak_up.get_sub_fs_edit_option_precondition_entity_type(
				pname, dialog, formspec, data, id_prefix, save_button, e,
				values_trade, check_trade)

	-- "the inventory of the player", -- 5
	-- "the inventory of the NPC", -- 6
	-- "the inventory of a block somewhere", -- 7
	-- "put item from the NPC's inventory into a chest etc.", -- 4  (effect)
	-- "take item from a chest etc. and put it into the NPC's inventory", -- 5 (effect)
	-- (inventory - only for preconditions; effects have something else here)
	elseif((data.what and id_prefix == "p_"
	  and (what_type == "player_inv" or what_type == "npc_inv" or what_type == "block_inv"))
	   or  (data.what and id_prefix == "r_"
	  and (what_type == "put_into_block_inv" or what_type == "take_from_block_inv"))) then
		-- the inventory of a block needs more input options (in particular block selection)
		data.what_type = what_type
		return yl_speak_up.get_sub_fs_edit_option_precondition_inv(
				pname, dialog, formspec, data, id_prefix, save_button, e,
				values_inv, check_inv, values_block)

	elseif(data.what and id_prefix == "r_" and what_type == "deal_with_offered_item") then
		return yl_speak_up.get_sub_fs_edit_option_effect_deal_with_offered_item(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "give item (created out of thin air) to player (requires yl_speak_up.npc_privs_priv priv)", -- 9
	-- "take item from player and destroy it (requires yl_speak_up.npc_privs_priv priv)", -- 10
	elseif(data.what and id_prefix == "r_" and (what_type == "give_item" or what_type=="take_item")) then
		return yl_speak_up.get_sub_fs_edit_option_effect_give_item_or_take_item(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "move the player to a given position (requires yl_speak_up.npc_privs_priv priv)", -- 11
	elseif(data.what and id_prefix == "r_" and what_type == "move") then
		return yl_speak_up.get_sub_fs_edit_option_effect_move(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "execute Lua code (requires npc_master priv)", -- precondition: 8; effect: 12
	elseif((data.what and id_prefix == "p_" and what_type == "function")
	    or (data.what and id_prefix == "r_" and what_type == "function")) then
		return yl_speak_up.get_sub_fs_edit_option_p_and_e_function(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "NPC crafts something", -- 6
	-- (craft - only for effects - not for preconditions)
	elseif(data.what and id_prefix == "r_" and what_type == "craft") then
		return yl_speak_up.get_sub_fs_edit_option_effect_craft(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "go to other dialog if the *previous* effect failed", -- 5
	-- (on_failure - only for effects - not for preconditions)
	elseif(data.what and id_prefix == "r_" and what_type == "on_failure") then
		return yl_speak_up.get_sub_fs_edit_option_effect_on_failure(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "send a chat message to all players" -- 8
	elseif(data.what and id_prefix == "r_" and what_type == "chat_all") then
		return yl_speak_up.get_sub_fs_edit_option_effect_chat_all(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "Normal trade - one item(stack) for another item(stack).", -- 3
	elseif(data.what and id_prefix == "a_" and what_type == "trade") then
		return yl_speak_up.get_sub_fs_edit_option_action_trade(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "The NPC gives something to the player (i.e. a quest item).", -- 4
	-- (only for actions)
	elseif(data.what and id_prefix == "a_" and what_type == "npc_gives") then
		return yl_speak_up.get_sub_fs_edit_option_action_npc_gives(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "The player is expected to give something to the NPC (i.e. a quest item).", -- 5
	-- (only for actions)
	-- "an item the player offered/gave to the NPC", (as precondition)
	elseif(data.what and ((id_prefix == "a_" and what_type == "npc_wants")
	                   or (id_prefix == "p_" and what_type == "player_offered_item"))) then
		return yl_speak_up.get_sub_fs_edit_option_action_npc_wants_or_accepts(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "The player has to manually enter a password or passphrase or some other text.", -- 6
	-- (only for actions)
	elseif(data.what and id_prefix == "a_" and what_type == "text_input") then
		return yl_speak_up.get_sub_fs_edit_option_action_text_input(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "Call custom functions that are supposed to be overridden by the server.", -- 7
	-- precondition: 9; action: 7; effect: 13
	elseif(data.what
	  and ((id_prefix == "a_" and what_type == "custom")
	    or (id_prefix == "p_" and what_type == "custom")
	    or (id_prefix == "r_" and what_type == "custom"))) then
		return yl_speak_up.get_sub_fs_edit_option_all_custom(
				pname, dialog, formspec, data, id_prefix, save_button, e)

	-- "The preconditions of another dialog option are fulfilled/not fulfilled.", -- 10
	-- precondition: 9
	elseif(data.what and id_prefix == "p_" and what_type == "other") then
		return yl_speak_up.get_sub_fs_other_option_preconditions(
				pname, dialog, formspec, data, id_prefix, save_button, e)
	end
	-- create a new precondition, action or effect
	return formspec..save_button
end


----------------------------------------------------------------------------
-- begin of formspecs for types of preconditions, actions and effects

-- helper function for "state", "property" and "evaluate";
-- shows dropdown for operator and input field for comparison value var_cmp_value
yl_speak_up.get_sub_fs_operator_based_comparison = function(data, id_prefix, save_button, e,
					values_operator, check_operator,
					what_is_this, text_what_is_this,
					text_select_operator, text_select_value)
	if(e) then
		data.operator = math.max(1,table.indexof(values_operator, e[ id_prefix.."operator" ]))
		data.var_cmp_value = e[ id_prefix.."var_cmp_value" ]
	end
	if(not(data[what_is_this]) or data[what_is_this] == "" or tostring(data[what_is_this]) == -1
	  or tostring(data[what_is_this]) == "0") then
		-- not enough selected yet for saving
		save_button = ""
	elseif(not(data.operator) or data.operator == 1) then
		data.operator = 1
		save_button = ""
	end
	local field_for_value = "field[11.7,4.8;7.5,0.6;var_cmp_value;;"..
		minetest.formspec_escape(data.var_cmp_value or "- enter value -").."]"
	-- do not show value input field for unary operators
	-- (unary operators are diffrent for prerequirements and effects)
	if(not(data.operator)
	  or (id_prefix == "p_" and (data.operator == 1 or (data.operator>=8 and data.operator<11)))
	  -- "unset", "set_to_current_time"
	  or (id_prefix == "r_" and (data.operator == 3 or data.operator == 4))) then
		field_for_value = "label[11.7,5.1;- not used for this operator -]"
	end
	-- the list of available variables needs to be extended with the ones
	-- the player has read access to, and the order has to be constant
	-- (because dropdown just returns an index)
	return "label[0.2,3.3;"..text_what_is_this.."]"..
		"label[0.2,4.3;Name of "..what_is_this..":]"..
		"label[7.0,4.3;"..text_select_operator.."]"..
		"dropdown[7.0,4.8;4.5,0.6;select_operator;"..
			table.concat(check_operator, ",")..";"..
			tostring(data.operator)..";]"..
		"label[11.7,4.3;"..text_select_value.."]"..
		field_for_value..
		save_button
end


-- "an internal state (i.e. of a quest)", -- 2
-- (state is the second offered option in both preconditions and effects list)
yl_speak_up.get_sub_fs_edit_option_p_and_e_state = function(
			pname, dialog, formspec, data, id_prefix, save_button, e,
			text_variable, text_select_value, text_select_operator,
			values_operator, check_operator, get_sorted_player_var_list_function )
	-- the list of available variables needs to be extended with the ones
	-- the player has read access to, and the order has to be constant
	-- (because dropdown just returns an index)
	local var_list = get_sorted_player_var_list_function(pname)
	local var_list_stripped = yl_speak_up.strip_pname_from_varlist(var_list, pname)
	if(e) then
		data.variable_name = yl_speak_up.strip_pname_from_var(e[ id_prefix.."variable" ], pname)
		data.variable = table.indexof(var_list, e[ id_prefix.."variable"])
	end
	if(not(data.variable) or data.variable < 1) then
		data.variable = 0
	end
	return formspec..
		yl_speak_up.get_sub_fs_operator_based_comparison(data, id_prefix, save_button, e,
			values_operator, check_operator, "variable", text_variable,
			text_select_operator, text_select_value)..
		"dropdown[0.2,4.8;6.5,0.6;select_variable;"..
			"- please select -"..var_list_stripped..";"..
			tostring(data.variable + 1)..";]"..
		"button[0.2,6.0;4.0,0.6;manage_variables;Manage variables]"..
		"button[4.7,6.0;6.5,0.6;show_var_usage_edit_element;Show where this variable is used]"..
		"hypertext[1.2,7.0;16.0,2.5;some_text;<normal>"..
			"<b>Note:</b> Each variable is player-specific and will be set and "..
			"checked for the player that currently talks to your NPC.\n"..
			"<b>Note:</b> You can set a variable to the current time in an effect. "..
			"After that, use a precondition to check if that variable was set \"more "..
			"than x seconds ago\" or \"less than x seconds ago\". This can be "..
			"useful for prevending your NPC from handing out the same quest item again "..
			"too quickly (players are inventive and may use your quest item for their "..
			"own needs).\n</normal>]"
end


-- "the value of a property of the NPC (for generic NPC)"
yl_speak_up.get_sub_fs_edit_option_p_and_e_property = function(
			pname, dialog, formspec, data, id_prefix, save_button, e,
			text_select_operator, values_operator, check_operator)
	if(e) then
		data.property = e[ id_prefix.."value"]
	end
	local operator_list = {}
	for i, v in ipairs(check_operator) do
		local v2 = values_operator[i]
		if(    v2 ~= "quest_step_done" and v2 ~= "quest_step_not_done"
		   and v2 ~= "true_for_param"  and v2 ~= "false_for_param") then
			table.insert(operator_list, v)
		end
	end
	local text_compare_with = "Compare property with this value:"
	if(id_prefix == "r_") then
		text_select_operator = "Set property to:"
		text_compare_with = "New value:"
	end
	-- the list of available variables needs to be extended with the ones
	return formspec..
		yl_speak_up.get_sub_fs_operator_based_comparison(data, id_prefix, save_button, e,
			values_operator, operator_list, "property",
			"The NPC shall have the following property:",
			text_select_operator, text_compare_with)..
		"field[1.0,4.8;5.0,0.6;property;;"..
			minetest.formspec_escape(data.property or "- enter name -").."]"..
		"hypertext[1.2,7.0;16.0,2.5;some_text;<normal>"..
			"<b>Note:</b> Properties are useful for NPC that have a generic "..
			"behaviour and may vary their behaviour slightly.\n"..
			"Properties starting with \"server\" can only be set or changed by "..
			"players with the \"npc_talk_admin\" privilege."..
			"</normal>]"
end


-- "something that has to be calculated or evaluated (=call a function)"
yl_speak_up.get_sub_fs_edit_option_p_and_e_evaluate = function(
			pname, dialog, formspec, data, id_prefix, save_button, e,
			text_select_operator, values_operator, check_operator)
	local fun_list = {}
	for k, v in pairs(yl_speak_up["custom_functions_"..id_prefix]) do
		table.insert(fun_list, v["description"] or k)
	end
	table.sort(fun_list)
	local func_selected = 0

	local func_data = nil
	if(e) then
		--data.function_name = e[ id_prefix.."value"]
		data.function_name = e[ id_prefix.."value"]
		for i = 1, 9 do
			local s = "param"..tostring(i)
			if(e[id_prefix..s]) then
				data[s] = e[id_prefix..s]
			end
		end
	end
	local add_description = "Nothing selected."
	if(data.function_name) then
		func_data = yl_speak_up["custom_functions_"..id_prefix][data.function_name]
		-- add the fields for param1..param9:
		if(func_data) then
			local xoff = 0
			for i = 1, 9 do
				if(i > 5) then
					xoff = 10
				end
				local paramn = "param"..tostring(i)
				local s = func_data[paramn.."_text"]
				if(s) then
					formspec = formspec..
						"label["..(0.2 + xoff)..","..(6.05 + ((i-1)%5)*0.8)..";"..
							minetest.formspec_escape(s).."]"..
						"field["..(4.0 + xoff)..","..(5.8 + ((i-1)%5)*0.8)..
							";5.0,0.6;set_"..paramn..";;"..
							minetest.formspec_escape(
								data[paramn] or "").."]"..
						"tooltip[set_"..paramn..";"..
							minetest.formspec_escape(
								func_data[paramn.."_desc"] or "?").."]"
				end
			end
			func_selected = table.indexof(fun_list, func_data["description"])
			add_description = func_data["description"]
			-- necessary so that the save_button can be shown
			data["function"] = func_selected
		end
	end
	local operator_list = {}
	for i, v in ipairs(check_operator) do
		local v2 = values_operator[i]
		if(    v2 ~= "quest_step_done" and v2 ~= "quest_step_not_done"
		   and v2 ~= "true_for_param"  and v2 ~= "false_for_param") then
			table.insert(operator_list, v)
		end
	end
	local text_operator_and_comparison = ""
	local explanation = ""
	local dlength = "6.5"
	if(id_prefix == "p_") then
		text_operator_and_comparison = yl_speak_up.get_sub_fs_operator_based_comparison(
			data, id_prefix, save_button, e,
			values_operator, operator_list, "function",
			"Execute and evaluate the following function:",
			"Operator for checking result:", "Compare the return value with this value:")
		explanation =
			"<b>Note:</b> Functions are called with parameters which are passed on to them. "..
			"The function then calculates a result. This result can be compared to a given "..
			"value. What the function calculates and what it returns depends on its "..
			"implementation."
	else
		dlength = "15" -- we have more room for the dropdown here
		if(not(data["function"]) or data["function"]=="") then
			save_button = ""
		end
		text_operator_and_comparison =
			"label[0.2,3.3;Execute the following function:]"..
			"label[0.2,4.3;Name of function:]"..
			save_button
		explanation =
			"<b>Note:</b> Functions are called with parameters which are passed on to them. "..
			"Functions used as effects/results ought to change something, i.e. set a "..
			"variable to a new value."
		if(id_prefix == "a_") then
			explanation =
				"<b>Note:</b> Functions are called with parameters which are passed on to "..
				"them. Functions used as actions need to return a valid formspec. This "..
				"formspec is then displayed to the player. The clicks the player does in "..
				"that formspec are sent to another custom function linked to it."
		end
	end
	-- the list of available variables needs to be extended with the ones
	return formspec..
		text_operator_and_comparison..
		-- show the description of the function again (the space in the dropdown menu is a bit
		-- limited)
		"label[7.5,3.3;"..minetest.formspec_escape(add_description).."]"..
		"dropdown[0.2,4.8;"..dlength..",0.6;select_function_name;"..
			"- please select -,"..table.concat(fun_list, ",")..";"..
			tostring(func_selected + 1)..";]"..
		"hypertext[1.2,9.6;16.0,2.5;some_text;<normal>"..
			explanation..
			"</normal>]"
end


-- helper function for:
--    yl_speak_up.get_sub_fs_edit_option_p_and_e_block
yl_speak_up.get_block_pos_info = function(pname, data, id_prefix, e, values_block, ignore_protection)
	-- are we more intrested in the inventory of the block or in the block itself?
	local looking_at_inventory = false
	if(data and data.what_type
	  and (data.what_type == "block_inv"
	    or data.what_type == "put_into_block_inv"
	    or data.what_type == "take_from_block_inv")) then
		looking_at_inventory = true
	end
	-- did the player get here through punching a block in the meantime?
	local block_pos = yl_speak_up.speak_to[pname].block_punched
	yl_speak_up.speak_to[pname].block_punched = nil
	if(e and e[id_prefix.."pos"]) then
		-- if we are not looking for the inventory of a block:
		if(looking_at_inventory) then
			data.block = math.max(1,table.indexof(values_block, e[ id_prefix.."value" ]))
		end
		data.node_data = {}
		data.node_data.data = e[ id_prefix.."node" ]
		data.node_data.param2 = e[ id_prefix.."param2" ]
		data.block_pos = {x=e[ id_prefix.."pos" ].x,
				  y=e[ id_prefix.."pos" ].y,
				  z=e[ id_prefix.."pos" ].z}
		-- the block below was punched
		if(id_prefix == "p_" and data.block == 5) then
			data.block_pos.y = data.block_pos.y - 1
		end
	end
	local block_pos_str = "- none set -"
	local node = {name = "- unknown -", param2 = "- unkown -"}
	if(not(block_pos) and data and data.block_pos) then
		block_pos = data.block_pos
	end
	local error_is_protected = ""
	if(block_pos) then
		-- store for later usage
		data.block_pos = block_pos
		local tmp_pos = {x=block_pos.x, y=block_pos.y, z=block_pos.z}
		-- "I can't punch it. The block is as the block *above* the one I punched.",
		-- (only valid for preconditions; not for effects - because the player and
		-- his NPC need to be able to build there)
		if(data.block and id_prefix == "p_" and data.block == 5) then
			tmp_pos.y = block_pos.y + 1
		end
		-- effects (and, likewise, preconditions): the player at least has to be able to
		-- build at that position - check that
		if(not(ignore_protection) and minetest.is_protected(tmp_pos, pname)) then
			error_is_protected = "label[0.2,7.8;Error: "..
				"The position you punched is protected. It cannot be used by "..
				"your NPC for checks or building. Please select a diffrent block!]"
			block_pos = nil
			data.block_pos = nil
		else
			block_pos_str = minetest.pos_to_string(tmp_pos)
			node = minetest.get_node_or_nil(tmp_pos)
			if(not(node)) then
				node = {name = "- unknown -", param2 = "- unkown -"}
			end
			-- "There shall be air instead of this block.",
			-- (only valid for preconditions)
			if(data.block and id_prefix == "p_" and data.block == 3) then
				node = {name = "air", param2 = 0}
			end
			-- cache that (in case a sapling grows or someone else changes it)
			data.node_data = node
		end
	end
	local show_save_button = true
	if(node.name == "- unknown -") then
		show_save_button = false
	end
	-- if we are dealing with the *inventory* of a block, the state of the block is of no intrest here
	if(not(looking_at_inventory) and (not(data.block) or data.block == 1)) then
		data.block = 1
		-- not enough selected yet for saving
		show_save_button = false
	end

	return {block_pos = block_pos, block_pos_str = block_pos_str, node = node,
		error_is_protected = error_is_protected,
		show_save_button = show_save_button}
end



-- "a block somewhere", -- 3
-- (block is the third offered option in both preconditions and effects list)
yl_speak_up.get_sub_fs_edit_option_p_and_e_block = function(
			pname, dialog, formspec, data, id_prefix, save_button, e,
			text_block_position, values_block, check_block)

	local res = yl_speak_up.get_block_pos_info(pname, data, id_prefix, e, values_block, false)
	if(not(res.show_save_button)) then
		save_button = ""
	end
	return formspec..
		"label[0.2,3.3;"..text_block_position.."]"..
		"dropdown[4.0,3.5;16.0,0.6;select_block;"..
			table.concat(check_block, ",")..";"..
			tostring(data.block)..";]"..
		"label[0.2,4.8;Position of the block:]"..
		"label[4.0,4.8;"..minetest.formspec_escape(res.block_pos_str).."]"..
		"label[0.2,5.8;Name of block:]"..
		"label[4.0,5.8;"..minetest.formspec_escape(res.node.name).."]"..
		"label[0.2,6.8;Orientation (param2):]"..
		"label[4.0,6.8;"..minetest.formspec_escape(res.node.param2).."]"..
		"button_exit[10.0,5.5;4.0,0.7;select_block_pos;Set position of block]"..
		"tooltip[select_block_pos;Click on this button to select a block.\n"..
			"This menu will close and you will be asked to punch\n"..
			"the block at the position you want to check or change.\n"..
			"After punching it, you will be returned to this menu.]"..
		res.error_is_protected..
		save_button
end


-- "a trade", -- 4
-- (trade - only for preconditions; effects have something else here)
yl_speak_up.get_sub_fs_edit_option_precondition_trade = function(
			pname, dialog, formspec, data, id_prefix, save_button, e,
			values_trade, check_trade)
	if(e) then
		data.trade = math.max(1,table.indexof(values_trade, e[ "p_value" ]))
	end
	if(not(data.trade) or data.trade == 1) then
		data.trade = 1
		-- not enough selected yet for saving
		save_button = ""
	end
	return formspec..
		"label[0.2,3.3;If the action is a trade, the following shall be true:]"..
		"dropdown[4.0,3.5;16.0,0.6;select_trade;"..
			table.concat(check_trade, ",")..";"..
			tostring(data.trade)..";]"..
		save_button
end


-- "the type of the entity of the NPC",
-- (entity_type - only for preconditions)
yl_speak_up.get_sub_fs_edit_option_precondition_entity_type = function(
			pname, dialog, formspec, data, id_prefix, save_button, e,
			values_trade, check_trade)
	if(e) then
		data.entity_type = e[ "p_value" ]
	end
	if(not(data.entity_type) or data.entity_type == "") then
		-- get the name/type of the current entity
		if(yl_speak_up.speak_to[pname].obj) then
			local obj = yl_speak_up.speak_to[pname].obj
			if(obj) then
				local entity = obj:get_luaentity()
				if(entity) then
					data.entity_type = entity.name
				end
			end
                end
	end
	return formspec..
		"label[0.2,3.3;The entity (this NPC) is of type:]"..
		"field[5.0,3.0;6.0,0.6;entity_type;;"..(data.entity_type or "").."]"..
		"label[0.2,4.3;Note: This is only really useful for generic NPCs.]"..
		save_button
end


-- "the inventory of the player", -- 5
-- "the inventory of the NPC", -- 6
-- "the inventory of a block somewhere", -- 7
-- "put item from the NPC's inventory into a chest etc.", -- 4  (effect)
-- "take item from a chest etc. and put it into the NPC's inventory", -- 5 (effect)
-- (inventory - only for preconditions; effects have something else here)
yl_speak_up.get_sub_fs_edit_option_precondition_inv = function(
			pname, dialog, formspec, data, id_prefix, save_button, e,
			values_inv, check_inv, values_block)
	if(e) then
		data.inv = math.max(1,table.indexof(values_inv, e["p_value"]))
		data.inv_stack_name = e[ id_prefix.."itemstack" ]
	end
	if(id_prefix == "p_" and (not(data.inv) or data.inv == 1)) then
		data.inv = 1
		-- not enough selected yet for saving
		save_button = ""
	end
	local block_selection = ""
	if(data and data.what_type
	  and (data.what_type == "block_inv"
	    or data.what_type == "put_into_block_inv"
	    or data.what_type == "take_from_block_inv")) then
		local inv_list_name = ""
		if(e) then
			-- not really relevant here but needed for getting the position
			e[ id_prefix.."value" ] = "node_is_like"
			inv_list_name = e[ id_prefix.."inv_list_name"]
		end
		-- positions of nodes in protected areas are allowed for inventory access
		local res = yl_speak_up.get_block_pos_info(pname, data, id_prefix, e, values_block, true)
		if(not(res.show_save_button)) then
			save_button = ""
		end
		-- which inventory lists are available?
		local tmp = yl_speak_up.get_node_inv_lists(res.block_pos, inv_list_name)
		block_selection = ""..
			"label[0.2,7.0;Position of the block:]"..
			"label[4.0,7.0;"..minetest.formspec_escape(res.block_pos_str).."]"..
			"label[0.2,7.5;Name of block:]"..
			"label[4.0,7.5;"..minetest.formspec_escape(res.node.name).."]"..
			"label[0.2,8.0;Orientation (param2):]"..
			"label[4.0,8.0;"..minetest.formspec_escape(res.node.param2).."]"..
			"label[0.2,8.5;Inventory list name:]"..
			"dropdown[4.0,8.2;3.8,0.6;inv_list_name;"..
				table.concat(tmp.inv_lists, ",")..";"..
				tostring(tmp.index)..";]"..
			"button_exit[0.2,9.0;4.0,0.7;select_block_pos;Set position of block]"..
			"tooltip[select_block_pos;Click on this button to select a block.\n"..
				"This menu will close and you will be asked to punch\n"..
				"the block at the position you want to check or change.\n"..
				"After punching it, you will be returned to this menu.]"
	end
	local intro = ""
	-- for preconditions: contain/does not contain item, is empty, ..
	if(id_prefix == "p_") then
		intro = "label[0.2,3.0;The following shall be true about the inventory:]"..
		        "dropdown[4.0,3.2;16.0,0.6;select_inv;"..
				table.concat(check_inv, ",")..";"..
				tostring(data.inv)..";]"
	-- for results/effects:
	elseif(data.what_type == "put_into_block_inv") then
		intro = "label[0.2,3.0;The NPC shall put the following item from his inventory "..
			"into the given block's inventory:]"
	elseif(data.what_type == "take_from_block_inv") then
		intro = "label[0.2,3.0;The NPC shall take the following item from the given block's "..
			"inventory and put it into his own inventory:]"
	end
	return formspec..
		intro..
		yl_speak_up.fs_your_inventory_select_item(pname, data)..
		block_selection..
		save_button
end


-- "an item the player offered to the NPC"
yl_speak_up.get_sub_fs_edit_option_effect_deal_with_offered_item = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		data.select_deal_with_offered_item = table.indexof(
				yl_speak_up.dropdown_values_deal_with_offered_item,
				e[ "r_value" ])
	end
	if(not(data) or not(data.select_deal_with_offered_item)
	  or data.select_deal_with_offered_item < 2) then
		save_button = ""
		data.select_deal_with_offered_item = 1
	end
	return formspec..
		"label[0.2,3.3;The NPC shall:]"..
		"dropdown[4.0,3.0;15.0,0.7;select_deal_with_offered_item;"..
			table.concat(yl_speak_up.dropdown_list_deal_with_offered_item, ",")..";"..
			tostring(data.select_deal_with_offered_item)..";]"..
		save_button
end


-- "give item (created out of thin air) to player (requires yl_speak_up.npc_privs_priv priv)", -- 9
-- "take item from player and destroy it (requires yl_speak_up.npc_privs_priv priv)", -- 10
yl_speak_up.get_sub_fs_edit_option_effect_give_item_or_take_item = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		data.inv_stack_name = e[ "r_value" ] or ""
	end
	local text = "The following item shall be created out of thin air and added to the "..
			"player's inventory:"
	local priv_name = "effect_give_item"
	if(data.what == 10) then
		text = "The following item shall be removed from the player's inventory and "..
			"be destroyed:"
		priv_name = "effect_take_item"
	end
	return formspec..
		"label[0.2,3.0;"..text.."]"..
		"label[0.2,3.5;Note: You can *save* this effect only if you have the "..
			"\""..tostring(yl_speak_up.npc_priv_needs_player_priv[priv_name] or "?").."\" priv!]"..
		"label[0.2,8.0;"..
			"And in order to be able to execute it, this NPC\n"..
			"needs the \""..tostring(priv_name).."\" priv.\n\t"..
			"Type \"/npc_talk_privs grant "..tostring(yl_speak_up.speak_to[pname].n_id)..
			" "..tostring(priv_name).."\"\nin order to grant this.]"..
		yl_speak_up.fs_your_inventory_select_item(pname, data)..
		save_button
end


-- "move the player to a given position (requires yl_speak_up.npc_privs_priv priv)", -- 11
yl_speak_up.get_sub_fs_edit_option_effect_move = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		if(e[ "r_value"] and type(e[ "r_value" ]) == "string") then
			local pos = minetest.string_to_pos(e[ "r_value" ])
			if(pos) then
				data.move_to_x = pos.x
				data.move_to_y = pos.y
				data.move_to_z = pos.z
			end
		end
	end
	return formspec..
		"label[0.2,3.0;Move the player to this position:]"..
		"label[0.2,3.5;Note: You can *save* this effect only if you have the "..
			"\""..tostring(yl_speak_up.npc_priv_needs_player_priv["effect_move_player"] or "?")..
			"\" priv!\n"..
			"And in order to be able to execute it, this NPC needs the \""..
			"effect_move_player\" priv.\n\t"..
			"Type \"/npc_talk_privs grant "..tostring(yl_speak_up.speak_to[pname].n_id)..
			" effect_move_player\" in order to grant this.]"..
		"label[0.2,5.3;X:]"..
		"label[3.7,5.3;Y:]"..
		"label[7.2,5.3;Z:]"..
		"field[0.7,5.0;2.0,0.6;move_to_x;;"..(data.move_to_x or "").."]"..
		"field[4.2,5.0;2.0,0.6;move_to_y;;"..(data.move_to_y or "").."]"..
		"field[7.7,5.0;2.0,0.6;move_to_z;;"..(data.move_to_z or "").."]"..
		save_button
end


-- "execute Lua code (requires npc_master priv)", -- precondition: 8; effect: 12
yl_speak_up.get_sub_fs_edit_option_p_and_e_function = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		if(e[ id_prefix.."value"] and e[ id_prefix.."value"] ~= "") then
			data.lua_code = e[ id_prefix.."value" ]
		end
	end
	local priv_name = "precon_exec_lua"
	if(id_prefix == "r_") then
		priv_name = "effect_exec_lua"
	end
	return formspec..
		"label[0.2,3.0;Execute the following Lua code (ought to return true or false):]"..
		"label[0.2,3.5;Note: You can *save* this effect only if you have the "..
			"\"npc_master\" priv!\n"..
			"And in order to be able to execute it, this NPC needs the \""..
			tostring(priv_name).."\" priv.\n\t"..
			"Type \"/npc_talk_privs grant "..tostring(yl_speak_up.speak_to[pname].n_id)..
			" "..tostring(priv_name).."\" in order to grant this.]"..
		"textarea[0.2,5.0;20,4.0;lua_code;;"..
			minetest.formspec_escape(tostring(data.lua_code)).."]"..
		save_button
end


-- "NPC crafts something", -- 6
-- (craft - only for effects - not for preconditions)
yl_speak_up.get_sub_fs_edit_option_effect_craft = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		-- those items can at least be shown as background images
		data.craftresult = e[ "r_value" ]
		data.craft_grid = e[ "r_craft_grid"]
	end
	local bg_img = ""
	if(data and data.craftresult and data.craft_grid) then
		bg_img = "item_image[5.95,8.70;0.7,0.7;"..tostring(data.craftresult).."]"..
			"image[4.6,8.6;1,1;gui_furnace_arrow_bg.png^[transformR270]"
		for i, v in ipairs(data.craft_grid) do
			if(v and v ~= "") then
				bg_img = bg_img.."item_image["..
					tostring(1.15 + ((i-1)%3)*1.25)..","..
					tostring(8.15 + math.floor((i-1)/3)*0.65)..
					";0.7,0.7;"..tostring(v).."]"
			end
		end
	end
	return formspec..
		"label[8,2.6;Your invnetory:]"..
		"list[current_player;main;8,3;8,4;]"..
		"label[1,3.1;Your craft grid:]"..
		"list[current_player;craft;1,3.5;3,3;]"..
		"list[current_player;craftpreview;5.8,4.75;1,1;]"..
		"image[4.6,4.8;1,1;gui_furnace_arrow_bg.png^[transformR270]"..
		"label[1,8.0;Use your craft grid to show your NPC what to craft "..
			"and how. Click on \"Save\" to save. Currently stored:]"..
		bg_img..
		save_button
end


-- "go to other dialog if the *previous* effect failed", -- 5
-- (on_failure - only for effects - not for preconditions)
yl_speak_up.get_sub_fs_edit_option_effect_on_failure = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		data.on_failure = e[ "r_value" ]
		data.alternate_text = e[ "alternate_text" ]
	end
	local dialog = yl_speak_up.speak_to[pname].dialog
	local sorted_dialog_list = yl_speak_up.get_sorted_dialog_name_list(dialog)
	local nr = 1
	if(not(data) or not(data.on_failure)
	  or not(dialog.n_dialogs)
	  or not(dialog.n_dialogs[data.on_failure])) then
		save_button = ""
	else
		local t = dialog.n_dialogs[data.on_failure].d_name or data.on_failure
		nr = math.max(0, table.indexof(sorted_dialog_list, t))
	end
	local on_failure_dialog = ""
	if(dialog and dialog.n_dialogs and dialog.n_dialogs[ data.on_failure ]) then
		on_failure_dialog =
			"label[0.2,5.5;This will switch to dialog \""..
				minetest.formspec_escape(tostring(data.on_failure)).."\""..
			yl_speak_up.show_colored_dialog_text(
				dialog,
				data,
				data.on_failure,
				"1.2,5.8;18.0,2.0;d_text",
				", but with the following *modified* text",
				":]",
				"button_edit_effect_on_failure_text_change")
	end
	return formspec..
		"label[0.2,3.3;If the *previous* effect failed,]"..
		"label[0.2,3.8;switch to the following dialog:]"..
		"dropdown[5.0,3.5;6.5,0.6;select_on_failure;"..
			table.concat(sorted_dialog_list, ",")..";"..
			tostring(nr)..";]"..
		on_failure_dialog..
		save_button
end


-- "send a chat message to all players" -- 8
yl_speak_up.get_sub_fs_edit_option_effect_chat_all = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		data.chat_msg_text = e[ "r_value" ]
	end
	local default_text = "$NPC_NAME$ (owned by $OWNER_NAME$) announces: $PLAYER_NAME$ "..
		"- example; please enter the text -"
	return formspec..
		"label[0.2,3.3;Send the following chat message to *all* players:]"..
		"label[0.2,4.1;Message:]"..
		"field[2.0,3.8;16.0,0.6;chat_msg_text;;"..
			minetest.formspec_escape(
				data.chat_msg_text
				or default_text).."]"..
		"label[0.2,5.3;Note: Your chat message needs to contain the following placeholders,"..
			" which will be replaced automaticly like in dialog texts:"..
			"\n$NPC_NAME$, $PLAYER_NAME$ and $OWNER_NAME$.]"..
		save_button
end


-- "Normal trade - one item(stack) for another item(stack).", -- 3
yl_speak_up.get_sub_fs_edit_option_action_trade = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		data.trade_id = e[ "a_value" ]
		-- use as background images
		if(dialog and dialog.trades and dialog.trades[ data.trade_id ]) then
			data.pay = dialog.trades[ data.trade_id ].pay[1]
			data.buy = dialog.trades[ data.trade_id ].buy[1]
		end
		data.action_failure_dialog = e[ "a_on_failure" ]
	end
	local dialog = yl_speak_up.speak_to[pname].dialog
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id
	if(not(data.trade_id)) then
		data.trade_id = tostring(d_id).." "..tostring(o_id)
	end
	-- show the player which trade is stored
	local bg_img = ""
	if(data and data.buy and data.pay) then
		bg_img = "item_image[1.15,4.35;0.7,0.7;"..tostring(data.pay).."]"..
			 "item_image[6.15,4.35;0.7,0.7;"..tostring(data.buy).."]"
	end
	yl_speak_up.speak_to[pname].trade_id = data.trade_id
	return formspec..
		"label[8,2.6;Your invnetory:]"..
		"list[current_player;main;8,3;8,4;]"..
		"label[0.2,3.1;Configure trade with "..minetest.formspec_escape(dialog.n_npc)..":]"..
		"label[0.5,3.8;The customer pays:]"..
		-- show the second slot of the setup inventory in the detached player's inv
		"list[detached:yl_speak_up_player_"..pname..";setup;2,4.2;1,1;]"..
		"image[3.5,4.2;1,1;gui_furnace_arrow_bg.png^[transformR270]"..
		"label[4.0,3.8;"..minetest.formspec_escape(dialog.n_npc or "?").." sells:]"..
		-- show the second slot of said inventory
		"list[detached:yl_speak_up_player_"..pname..";setup;5,4.2;1,1;1]"..
		bg_img..
		yl_speak_up.set_on_action_failure_dialog(pname, data,
			"The player shall trade at least once.")..
		save_button
end


-- "The NPC gives something to the player (i.e. a quest item).", -- 4
-- (only for actions)
yl_speak_up.get_sub_fs_edit_option_action_npc_gives = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	local bg_img = ""
	if(e) then
		data.item_quest_id = data.item_quest_id or e["item_quest_id"]
		data.item_desc = data.item_desc or e["item_desc"]
	end
	if(data and (data.item_node_name or data.item_string)) then
		bg_img = "item_image[1.15,3.65;0.7,0.7;"..
			 tostring(data.item_node_name or data.item_string).."]"
	end
	return formspec..
		"label[8,2.6;Your inventory:]"..
		"list[current_player;main;8,3;8,4;]"..
		"label[1,3.1;"..minetest.formspec_escape(dialog.n_npc or "?").." gives:]"..
		"list[detached:yl_speak_up_player_"..pname..";npc_gives;2,3.5;1,1;]"..
		"label[3.2,4.0;"..
				minetest.formspec_escape(
					data.item_node_name
					or "- no item set -").."]"..
		"label[0.2,5.6;Set a description to turn the item into a special\n"..
			"quest item. Set a special ID (short text) so that\n"..
			"the player cannot create a fake item. Click on \n"..
			"\"Save\" to apply the changes.\n"..
			"You can use placeholders like $PLAYER_NAME$ etc.]"..
		"label[0.2,8.3;Special ID to set:]"..
		"field[3.2,8.0;14.5,0.6;action_item_quest_id;;"..
				minetest.formspec_escape(
					data.item_quest_id
					or "- none set -").."]"..
		"tooltip[action_item_quest_id;"..
			"Set this to a text that helps *you* to remember what this\n"..
			"special quest item is for (i.e. \"quest_deliver_augusts_"..
			"letter\").\n"..
			"The ID will be extended with the ID of the NPC and the\n"..
			"name of the player who got this item from the NPC.]"..
		"label[0.2,9.0;Description to set:]"..
		"field[3.2,8.7;14.5,0.6;action_item_desc;;"..
				minetest.formspec_escape(
					data.item_desc
					or "- no item set -").."]"..
		"tooltip[action_item_desc;"..
			"Set this to a text that helps the *player* to remember what\n"..
			"this special quest item is for (i.e. \"Letter from August to\n"..
			"Frederike\" for a piece of paper).\n"..
			"This description is shown in the inventory on mouseover.]"..
		bg_img..
		yl_speak_up.set_on_action_failure_dialog(pname, data,
			"The player shall take this offered item.")..
		save_button
end


-- "The player is expected to give something to the NPC (i.e. a quest item).", -- 5
-- (only for actions)
-- "an item the player offered/gave to the NPC", (as precondition)
yl_speak_up.get_sub_fs_edit_option_action_npc_wants_or_accepts = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	local bg_img = ""
	local node_name = ""
	if(e) then
		data.item_quest_id = data.item_quest_id or e["item_quest_id"]
		data.item_desc = data.item_desc or e["item_desc"]
		data.item_group = data.item_group or e["item_group"]
		data.item_stack_size = data.item_stack_size or e["item_stack_size"]
		data.match_stack_size = data.match_stack_size or e["match_stack_size"]
	end
	if(data and (data.item_node_name or data.item_string)) then
		node_name = tostring(data.item_node_name or data.item_string)
		bg_img = "item_image[1.15,3.65;0.7,0.7;"..node_name.."]"
	end
	local info_text = ""
	if(id_prefix == "p_") then
		local group_list = {minetest.formspec_escape("- no, just this one item -")}
		-- get node name without amount
		local parts = node_name:split(" ")
		local nr = 1
		local count = 1
		local amount = tostring(1)
		-- prepare group_list
		if(data and parts and minetest.registered_items[ parts[1] ]) then
			for k,v in pairs(minetest.registered_items[ parts[1] ].groups) do
				table.insert(group_list, k)
				count = count + 1
				if(data.item_group and data.item_group == k) then
					nr = count
				end
			end
			amount = tostring(parts[2])
		end
		local size_list = {"any amount", "exactly "..amount,
			"less than "..amount, "more than "..amount, "another amount than "..amount}
		local match_size = 1
		for i, list_text in ipairs(size_list) do
			if(data.match_stack_size and data.match_stack_size == list_text:split(" ")[ 1 ]) then
				match_size = i
			end
		end
		if(data) then
			data.item_stack_size = amount
		end
		info_text =
			"label[1,2.6;The player offered:]"..
			"label[6.7,3.1;of:]"..
			"dropdown[2,2.8;4.5,0.6;select_match_stack_size;"..
				table.concat(size_list, ",")..";"..
				tostring(match_size or 1)..";]"..
			"label[1,4.8;...and also all other items of the group:]"..
			"dropdown[2,5.1;5.0,0.6;select_accept_group;"..
				table.concat(group_list, ",")..";"..tostring(nr)..";]"
	else
		info_text =
			"label[1,3.1;"..minetest.formspec_escape(dialog.n_npc or "?").." wants:]"..
			yl_speak_up.set_on_action_failure_dialog(pname, data,
						"The player shall give the NPC this item.")
	end
	return formspec..
		"label[8,2.6;Your inventory:]"..
		"list[current_player;main;8,3;8,4;]"..
		"list[detached:yl_speak_up_player_"..pname..";npc_wants;2,3.5;1,1;]"..
		"label[3.2,4.0;"..
			minetest.formspec_escape(
				node_name
				or "- no item set -").."]"..
		"label[0.2,6.1;If you want a special ID and description, create\n"..
			"those via the \"NPC gives something to the player\"\n"..
			"menu option first and insert that item here. Don't\n"..
			"use other placeholders than $PLAYER_NAME$ for this!]"..
		"label[0.2,8.3;Expected special ID:]"..
		"label[4.0,8.3;"..
			minetest.formspec_escape(
				data.item_quest_id
				or "- none set -").."]"..
		"label[0.2,9.0;Expected description:]"..
		"label[4.0,9.0;"..
			minetest.formspec_escape(
				 data.item_desc
				 or "- none set -").."]"..
		bg_img..
		info_text..
		save_button
end


-- "The player has to manually enter a password or passphrase or some other text.", -- 6
-- (only for actions)
yl_speak_up.get_sub_fs_edit_option_action_text_input = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		data.quest_question = e[ "a_question" ]
		data.quest_answer = e[ "a_value" ]
		data.action_failure_dialog = e[ "a_on_failure" ]
	end
	return formspec..
		"label[0.2,3.3;What to ask the player and which answer to expect:]"..
		"label[0.2,4.0;Question to show:]"..
		"field[4.0,3.8;10.0,0.6;quest_question;;"..
			minetest.formspec_escape(
				data.quest_question
				or "Your answer:").."]"..
		"label[0.2,5.0;Expected answer:]"..
		"field[4.0,4.8;10.0,0.6;quest_answer;;"..
			minetest.formspec_escape(
				data.quest_answer
				or "- Insert the correct answer here -").."]"..
		"tooltip[quest_question;"..
			"This is just a short text that will be shown to remind\n"..
			"the player what he is asked for. Most of the question\n"..
			"ought to be part of the normal dialog of the NPC.]"..
		"tooltip[quest_answer;"..
			"The correct answer will not be shown to the player.\n"..
			"What the player enters will be compared to this\n"..
			"correct value.]"..
		"tooltip[select_on_action_failure;"..
			"If the player gives the wrong answer, you can show him\n"..
			"a diffrent target dialog (i.e. with text \"No, that answer\n"..
			"was wrong, but please try again!\"). In such a case the\n"..
			"effects/results of the current dialog option are *not*\n"..
			"executed.]"..
		yl_speak_up.set_on_action_failure_dialog(pname, data,
			"The player shall enter the correct answer.")..
		save_button
end


-- "Call custom functions that are supposed to be overridden by the server.", -- 7
-- precondition: 9; action: 7; effect: 13
yl_speak_up.get_sub_fs_edit_option_all_custom = function(
			pname, dialog, formspec, data, id_prefix, save_button, e)
	if(e) then
		data.custom_param = e[ id_prefix.."value" ]
		if(id_prefix == "a_") then
			data.action_failure_dialog = e[ "a_on_failure" ]
		end
	end
	formspec = formspec..
		"label[0.2,3.3;Note: Calling a custom function will require direct support "..
			"from the server.]"..
		"label[0.2,4.0;Parameter for custom function:]"..
		"field[6.0,3.7;10.0,0.6;custom_param;;"..
			minetest.formspec_escape(
				data.custom_param
				or "- Insert a text that is passed on to your function here -").."]"..
		"tooltip[custom_param;"..
			"The custom parameter may help whoever implements the\n"..
			"custom function to more easily see what it belongs to.\n"..
			"Dialog and option ID are also passed as parameters.]"
	if(id_prefix == "a_") then
		formspec = formspec..
			"tooltip[select_on_action_failure;"..
				"If the player gives the wrong answer, you can show him\n"..
				"a diffrent target dialog (i.e. with text \"No, that answer\n"..
				"was wrong, but please try again!\"). In such a case the\n"..
				"effects/results of the current dialog option are *not*\n"..
				"executed.]"..
			yl_speak_up.set_on_action_failure_dialog(pname, data,
				"The player shall click on the right button.")
	else
		formspec = formspec..
			"label[0.3,5.0;Note: Your custom function has to return either true "..
				"or false.]"
	end
	return formspec..save_button
end


-- "The preconditions of another dialog option are fulfilled/not fulfilled.", -- 10
-- precondition: 10
yl_speak_up.get_sub_fs_other_option_preconditions = function(
				pname, dialog, formspec, data, id_prefix, save_button, e)
	local dialog = yl_speak_up.speak_to[pname].dialog
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id
	-- only o_id with a *lower* o_sort value are suitable (else evaluation would become
	-- difficult and loops might be created)
	local o_id_list = {}
	local options = dialog.n_dialogs[ d_id ].d_options
	if(options) then
		local this_option = options[ o_id ]
		if(not(this_option) or not(this_option.o_sort)) then
			this_option = {o_sort = 0}
		end
		for k, v in pairs(options) do
			if(k and v and v.o_sort and v.o_sort < this_option.o_sort) then
				table.insert(o_id_list, minetest.formspec_escape(k))
			end
		end
	end
	if(e) then
		data.other_o_id = e[ "p_value" ]
		data.fulfilled = e[ "p_fulfilled" ]
	end
	local nr = math.max(0, table.indexof(o_id_list, data.other_o_id))
	nr_fulfilled = 1
	if(data.fulfilled == "true") then
		nr_fulfilled = 2
	elseif(data.fulfilled == "false") then
		nr_fulfilled = 3
	end
	if(nr == 0 or nr_fulfilled == 1) then
		save_button = ""
	end
	return formspec..
		"label[0.2,3.3;Note: You can only select dialog options with a *lower* o_sort value "..
			"for this evaluation.]"..
		"label[0.2,4.0;The preconditions of dialog option:]"..
		"dropdown[6.0,3.7;3.0,0.6;select_other_o_id;-select-,"..
			table.concat(o_id_list, ",")..";"..
			tostring(nr + 1)..";]"..
		"label[9.2,4.0;..shall be:]"..
		"dropdown[11,3.7;2.0,0.6;select_fulfilled;-select-,true,false;"..
			tostring(nr_fulfilled).."]"..
		"tooltip[select_other_o_id;"..
			"Sometimes you may need the same preconditions for more than\n"..
			"one dialog option - or you may need one dialog option to be\n"..
			"available exactly when another one is *not* available.\n"..
			"This is what you can do here.]"..
		"tooltip[select_fulfilled;"..
			"If you select \"true\" here, then this precondition will be\n"..
			"fulfilled when all the preconditions of the dialog option you\n"..
			"selected here are true as well.\n"..
			"If you select \"false\", this precondition will only be\n"..
			"fulfilled if the other dialog option you selected here\n"..
			"is not true.]"..
		save_button
end


-- end of formspecs for types of preconditions, actions and effects
----------------------------------------------------------------------------

-- helper function
yl_speak_up.set_on_action_failure_dialog = function(pname, data, instruction)
	local dialog = yl_speak_up.speak_to[pname].dialog
	local nr = 1

	local sorted_dialog_list = yl_speak_up.get_sorted_dialog_name_list(dialog)
	if(data and data.action_failure_dialog
	   and dialog.n_dialogs
	   and dialog.n_dialogs[data.action_failure_dialog]) then
		local t = dialog.n_dialogs[data.action_failure_dialog].d_name or data.action_failure_dialog
		nr = math.max(0, table.indexof(sorted_dialog_list, t)) + 1
	end
	local start_at = "9.9;"
	if(nr and nr > 1) then
		start_at = "9.7;"
	end
	local on_failure_dialog =
		"label[0.2,"..start_at..tostring(instruction).." If he doesn't, go to dialog:]"..
		"dropdown[11,9.6;8.0,0.6;select_on_action_failure;"..
			"- current one -,"..
			table.concat(sorted_dialog_list, ",")..";"..tostring(nr)..";]"
	if(nr and nr > 1) then
		return on_failure_dialog..
			yl_speak_up.show_colored_dialog_text(
				dialog,
				data,
				sorted_dialog_list[ nr - 1],
				"1.2,10.2;18.0,1.8;d_text",
				"label[0.2,10.1;...and show the following *modified* text:]",
				"",
				"button_edit_action_on_failure_text_change")
	end
	return on_failure_dialog
end


yl_speak_up.edit_mode_set_a_on_failure = function(data, pname, v)
	if(pname and data and data.action_failure_dialog) then
		v[ "a_on_failure" ] = yl_speak_up.d_name_to_d_id(
						yl_speak_up.speak_to[pname].dialog,
						data.action_failure_dialog)
	else
		v[ "a_on_failure" ] = ""
	end
end
