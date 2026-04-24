-- inventory management, trading and handling of quest items for talking to NPCs

-- cache the inventory of NPCs for easier access
yl_speak_up.npc_inventory = {}

-- used so that unused inventories are not immediately discarded:
yl_speak_up.npc_inventory_last_used = {}

-- where are they stored on the disk?
yl_speak_up.get_inventory_save_path = function(n_id)
    return yl_speak_up.worldpath .. yl_speak_up.inventory_path .. DIR_DELIM .. "inv_" .. n_id .. ".json"
end


-- check if stack contains any metadata; return true if it does
-- (trade_simple does not allow used items or those with metadata)
yl_speak_up.check_stack_has_meta = function(player, stack)
	local meta = stack:get_meta()
	for k, v in pairs(meta:to_table()) do
		-- the name "fields" is allowed - as long as it is empty
		if(k ~= "fields") then
			return true
		end
		for k2, v2 in pairs(v) do
			if(k2) then
				return true
			end
		end
	end
	return false
end



-- save the inventory of the NPC with the id n_id
yl_speak_up.save_npc_inventory = function( n_id )
	-- only save something if we actually can
	if(not(n_id) or not(yl_speak_up.npc_inventory[ n_id ])) then
		return
	end
	-- the inv was just saved - make sure it is kept in memory a bit
	yl_speak_up.npc_inventory_last_used[ n_id ] = os.time()
	-- convert the inventory data to something we can actually store
	local inv = yl_speak_up.npc_inventory[ n_id ]
	local inv_as_table = {}
	for i=1, inv:get_size("npc_main") do
		local stack = inv:get_stack("npc_main", i)
		-- only save those slots that are not empty
		if(not(stack:is_empty())) then
			inv_as_table[ i ] = stack:to_table()
		end
	end
	-- convert the table into json
	local json = minetest.write_json( inv_as_table )
	-- get a file name for storing the data
	local file_name = yl_speak_up.get_inventory_save_path(n_id)
	-- actually store it on disk
	minetest.safe_file_write(file_name, json)
end


-- helper function for yl_speak_up.load_npc_inventory and
-- for yl_speak_up.player_joined_add_trade_inv
yl_speak_up.inventory_allow_item = function(player, stack, input_to)
	if(not(player) or not(stack) or not(input_to)) then
		return 0
	end
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	if(not(n_id) or not(yl_speak_up.may_edit_npc(player, n_id))) then
		return 0
	end
	-- are we editing an action of the type trade?
	if(   yl_speak_up.speak_to[pname][ "tmp_action" ]
	  and yl_speak_up.speak_to[pname][ "tmp_action" ].what == 3) then
		input_to = "yl_speak_up:edit_actions"
	end

	local error_msg = nil
	if(stack:get_wear() > 0) then
		error_msg = "Your NPC accepts only undammaged items.\n"..
			    "Trading dammaged items would be unfair."
	-- items with metadata cannot be traded
	elseif(yl_speak_up.check_stack_has_meta(player, stack)) then
		error_msg = "Your NPC cannot sell items that contain\n"..
			    "additional (meta-) data."
	end
	if(error_msg) then
		yl_speak_up.show_fs(player, "msg", {
			input_to = input_to,
			formspec = "size[6,2]"..
				"label[0.2,-0.2;"..tostring(error_msg).."]"..
				"button[2,1.5;1,0.9;back_from_error_msg;"..
					"OK]"})
		return 0
	end
	return stack:get_count()
end


-- checks dialog and tries to find out if this dialog needs a detached inventory for the NPC;
-- returns true if the NPC needs one; else false
yl_speak_up.dialog_requires_inventory = function(dialog)
	if(not(dialog)) then
		return false
	end
	for t, t_data in pairs(dialog.trades or {}) do
		if(t and t ~= "limits") then
			return true
		end
	end
	for d_id, d_data in pairs(dialog.n_dialogs or {}) do
		for o_id, o_data in pairs(d_data.d_options or {}) do
			-- check preconditions:
			for p_id, p_data in pairs(o_data.o_prerequisites or {}) do
				local t = p_data.p_type or "?"
				if(t == "trade" or t == "npc_inv" or t == "player_offered_item") then
					return true
				end
			end
			-- check actions:
			for a_id, a_data in pairs(o_data.actions or {}) do
				local t = a_data.a_type or "?"
				if(t == "trade" or t == "npc_gives" or t == "npc_wants") then
					return true
				end
			end
			-- check effects:
			for r_id, r_data in pairs(o_data.o_results or {}) do
				local t = r_data.r_type or "?"
				if(t == "block" or t == "craft" or t == "put_into_block_inv"
				  or t == "take_from_block_inv" or t == "deal_with_offered_item") then
					return true
				end
			end
		end
	end
	-- nothing found that actually uses the NPC's inventory - so don't load it
	return false
end


-- create and load the detached inventory in yl_speak_up.after_activate;
-- direct access to this inventory is only possible for players with the right privs
-- (this is an inventory for the *NPC*, which is stored to disk sometimes)
-- if force_load is true, the inventory will be loaded even if the NPC doesn't usually
-- 	need one (i.e. in edit_mode, or with "show me your inventory").
yl_speak_up.load_npc_inventory = function(n_id, force_load, dialog)
	if(not(n_id)) then
		return
	end

	-- clean up no longer needed detached inventories
	local recently_used = os.time() - 600 -- used in the last 10 minutes
	for id, data in pairs(yl_speak_up.npc_inventory) do
		-- not the one for this particular NPC,
		if(id and id ~= n_id and data
		-- and has not been used recently:
		  and yl_speak_up.npc_inventory_last_used[id]
		  and yl_speak_up.npc_inventory_last_used[id] < recently_used
		-- and not if anyone is talking to it
		  and not(yl_speak_up.npc_is_in_conversation(id))) then
			-- actually remove that detached inventory:
			minetest.remove_detached_inventory("yl_speak_up_npc_"..tostring(id))
			-- delete it here as well:
			yl_speak_up.npc_inventory[id] = nil
		end
	end

	yl_speak_up.npc_inventory_last_used[ n_id ] = os.time()
	-- the inventory is already loaded
	if(yl_speak_up.npc_inventory[ n_id ]) then
		return
	end

	-- check if the NPC actually needs an inventory - else don't load it
	if(not(force_load) and dialog
	  and not(yl_speak_up.dialog_requires_inventory(dialog))) then
		return
	end

	-- create the detached inventory (it is empty for now)
	local npc_inv = minetest.create_detached_inventory("yl_speak_up_npc_"..tostring(n_id), {
		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			if(not(yl_speak_up.may_edit_npc(player, n_id))) then
				return 0
			end
			return count
		end,
	        -- Called when a player wants to move items inside the inventory.
	        -- Return value: number of items allowed to move.

	        allow_put = function(inv, listname, index, stack, player)
			-- check if player can edit NPC, item is undammaged and contains no metadata
			return yl_speak_up.inventory_allow_item(player, stack, "yl_speak_up:inventory")
		end,
	        -- Called when a player wants to put something into the inventory.
	        -- Return value: number of items allowed to put.
	        -- Return value -1: Allow and don't modify item count in inventory.

	        allow_take = function(inv, listname, index, stack, player)
			if(not(yl_speak_up.may_edit_npc(player, n_id))) then
				return 0
			end
			return stack:get_count()
		end,
	        -- Called when a player wants to take something out of the inventory.
	        -- Return value: number of items allowed to take.
	        -- Return value -1: Allow and don't modify item count in inventory.

		-- log inventory changes (same way as modifications to chest inventories)
	        on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			yl_speak_up.log_change(player:get_player_name(), n_id,
				"moves stuff inside inventory of NPC")

		end,
	        on_put = function(inv, listname, index, stack, player)
			yl_speak_up.log_change(player:get_player_name(), n_id,
				"adds "..tostring(stack:to_string()).." to inventory of NPC")

		end,
	        on_take = function(inv, listname, index, stack, player)
			yl_speak_up.log_change(player:get_player_name(), n_id,
				"takes "..tostring(stack:to_string()).." from inventory of NPC")
		end,
	})
	-- the NPC needs enough room for trade items, payment and questitems
	npc_inv:set_size("npc_main", 6*12)

	-- cache a pointer to this inventory for easier access
	yl_speak_up.npc_inventory[ n_id ] = npc_inv

	-- find out where the inventory of the NPC is stored
	local file_name = yl_speak_up.get_inventory_save_path(n_id)

	-- load the data from the file
	local file, err = io.open(file_name, "r")
	if err then
		return
	end
	io.input(file)
	local text = io.read()
	local inv_as_table = minetest.parse_json(text)
	io.close(file)

	if(type(inv_as_table) ~= "table") then
		return
	end

	-- restore the inventory
	for i=1, npc_inv:get_size("npc_main") do
		npc_inv:set_stack("npc_main", i, ItemStack( inv_as_table[ i ]))
	end
end
