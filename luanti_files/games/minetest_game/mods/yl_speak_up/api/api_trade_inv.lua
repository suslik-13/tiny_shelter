
-- functions for handling the detached trade inventory of players
-- these functions exist as extra functions so that they can be changed with /npc_talk_reload

-- can this trade be made? called in allow_take
yl_speak_up.can_trade_simple = function(player, count)
	if(not(player)) then
		return 0
	end
	local pname = player:get_player_name()
	-- which trade are we talking about?
	local trade = yl_speak_up.trade[pname]
	-- do we have all the necessary data?
	if(not(trade) or trade.trade_type ~= "trade_simple") then
		return 0
	end

	-- the player tries to take *less* items than what his payment is;
	-- avoid this confusion!
	if(ItemStack(trade.npc_gives):get_count() ~= count) then
		return 0
	end
	-- buy, sell and config items need to be placed somewhere
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	-- the players' inventory
	local player_inv = player:get_inventory()
	-- the NPCs' inventory
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(trade.n_id)})

	-- is the payment in the payment slot?
	if( not(trade_inv:contains_item("pay", trade.player_gives))
	-- is the item to be sold in the buy slot?
	 or not(trade_inv:contains_item("buy", trade.npc_gives))
	-- has the NPC room for the payment?
	 or not(npc_inv:room_for_item("npc_main", trade.player_gives))
	-- has the player room for the sold item?
	 or not(player_inv:room_for_item("main", trade.npc_gives))) then
		-- trade not possible
		return 0
	end

	-- used items cannot be sold as there is no fair way to indicate how
	-- much they are used
	if(  trade_inv:get_stack("pay", 1):get_wear() > 0) then
		return 0
	end

	-- all ok; all items that are to be sold can be taken
	return ItemStack(trade.npc_gives):get_count()
end


-- actually execute the trade
yl_speak_up.do_trade_simple = function(player, count)
	-- can the trade be made?
	if(not(yl_speak_up.can_trade_simple(player, count))) then
		return
	end

	local pname = player:get_player_name()
	-- which trade are we talking about?
	local trade = yl_speak_up.trade[pname]

	-- buy, sell and config items need to be placed somewhere
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	-- the NPCs' inventory
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(trade.n_id)})

	-- the NPC sells these items right now, and the player is moving it to his inventory
	npc_inv:remove_item("npc_main", trade.npc_gives)

	-- move price items to the NPC
	local stack = trade_inv:remove_item("pay", trade.player_gives)
	npc_inv:add_item("npc_main", stack)
	-- save the inventory of the npc so that the payment does not get lost
	yl_speak_up.save_npc_inventory( trade.n_id )

	-- store for statistics how many times the player has executed this trade
	-- (this is also necessary to switch to the right target dialog when
	--  dealing with dialog options trades)
	yl_speak_up.trade[pname].trade_done = yl_speak_up.trade[pname].trade_done + 1

	-- log the trade
	yl_speak_up.log_change(pname, trade.n_id,
		"bought "..tostring(trade.npc_gives)..
		" for "..tostring(trade.player_gives))
end


-- moving of items between diffrent lists is not allowed
yl_speak_up.trade_inv_allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
	if(not(player)) then
		return 0
	end
	if(from_list ~= to_list) then
		return 0
	end
	return count
end

-- these all require calling special functions, depending on context
yl_speak_up.trade_inv_allow_put = function(inv, listname, index, stack, player)
	if(not(player)) then
		return 0
	end
	-- the "buy" slot is managed by the NPC; the player only takes from it
	if(listname == "buy") then
		return 0
	end
	-- do not allow used items or items with metadata in the setup slots
	-- (they can't really be traded later on anyway)
	if(listname == "setup") then
		-- check if player can edit NPC, item is undammaged and contains no metadata
		return yl_speak_up.inventory_allow_item(player, stack,
			"yl_speak_up:add_trade_simple")
	end
	-- allow putting something in in edit mode - but not otherwise
	if(listname == "npc_gives") then
		return 0
	end
	return stack:get_count()
end

yl_speak_up.trade_inv_allow_take = function(inv, listname, index, stack, player)
	if(not(player)) then
		return 0
	end
	-- can the trade be made?
	if(listname == "buy") then
		return yl_speak_up.can_trade_simple(player, stack:get_count())
	end
	return stack:get_count()
end

yl_speak_up.trade_inv_on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
end

yl_speak_up.trade_inv_on_put = function(inv, listname, index, stack, player)
	if(listname == "pay") then
		local pname = player:get_player_name()
		-- show formspec with updated information (perhaps sale is now possible)
		yl_speak_up.show_fs(player, "trade_simple")
	elseif(listname == "npc_gives"
	    or listname == "npc_wants") then
		-- monitor changes in order to adjust the formspec
		yl_speak_up.action_inv_changed(inv, listname, index, stack, player, "put")
	end
end

yl_speak_up.trade_inv_on_take = function(inv, listname, index, stack, player)
	-- the player may have put something wrong in the payment slot
	-- -> show updated formspec
	if(listname == "pay") then
		local pname = player:get_player_name()
		-- show formspec with updated information (perhaps sale is now possible)
		yl_speak_up.show_fs(player, "trade_simple")
	elseif(listname == "buy") then
		-- do the exchange
		yl_speak_up.do_trade_simple(player, stack:get_count())
		local pname = player:get_player_name()
		-- which trade are we talking about?
		local trade = yl_speak_up.trade[pname]
		-- when the player traded once inside an action: that action was a success;
		-- 	execute next action
		-- but only if not in edit mode
		if(trade and trade.trade_done > 0
		  and not(trade.trade_is_trade_list)
		  and not(trade.dry_run_no_exec)) then
			local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
			-- return surplus items from the pay slot
			local pay = trade_inv:get_stack("pay", 1)
			local player_inv = player:get_inventory()
			if( pay and player_inv:room_for_item("main", pay)) then
				player_inv:add_item("main", pay)
				trade_inv:set_stack("pay", 1, "")
			end
			-- done trading
			yl_speak_up.speak_to[pname].target_d_id = nil
			yl_speak_up.speak_to[pname].trade_id = nil
			-- execute the next action
			yl_speak_up.execute_next_action(player, trade.a_id, true, "yl_speak_up:trade_simple")
			return
		end
		-- information may require an update (NPC might now be out of stock), or
		-- the player can do the trade a second time
		yl_speak_up.show_fs(player, "trade_simple")
	elseif(listname == "npc_gives"
	    or listname == "npc_wants") then
		-- monitor changes in order to adjust the formspec
		yl_speak_up.action_inv_changed(inv, listname, index, stack, player, "take")
	end
end

-- create a detached inventory for the *player* for trading with the npcs
-- (called in minetest.register_on_joinplayer)
yl_speak_up.player_joined_add_trade_inv = function(player, last_login)
	local pname = player:get_player_name()

	-- create the detached inventory;
	-- the functions for monitoring changes will be important later on
	-- only the the player owning this detached inventory may access it
	local trade_inv = minetest.create_detached_inventory("yl_speak_up_player_"..tostring(pname), {
		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			return yl_speak_up.trade_inv_allow_move(inv, from_list, from_index, to_list,
								to_index, count, player)
		end,

	        allow_put = function(inv, listname, index, stack, player)
			return yl_speak_up.trade_inv_allow_put(inv, listname, index, stack, player)
		end,
	        allow_take = function(inv, listname, index, stack, player)
			return yl_speak_up.trade_inv_allow_take(inv, listname, index, stack, player)
		end,
	        on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			return yl_speak_up.trade_inv_on_move(inv, from_list, from_index, to_list,
								to_index, count, player)
		end,
	        on_put = function(inv, listname, index, stack, player)
			return yl_speak_up.trade_inv_on_put(inv, listname, index, stack, player)
		end,
	        on_take = function(inv, listname, index, stack, player)
			return yl_speak_up.trade_inv_on_take(inv, listname, index, stack, player)
		end,
	-- create the detached inventory only for that player (don't spam other clients with it):
	}, tostring(pname))
	-- prepare the actual inventories
	trade_inv:set_size("pay", 1)
	trade_inv:set_size("buy", 1)
	-- for setting up new simple trades
	trade_inv:set_size("setup", 2*1)
	-- for setting up actions
	trade_inv:set_size("npc_gives", 1)
	trade_inv:set_size("npc_wants", 1)
	-- for setting wielded items (left and right)
	trade_inv:set_size("wield", 2)
end


yl_speak_up.player_left_remove_trade_inv = function(player)
	if(not(player)) then
		return
	end
	local pname = player:get_player_name()
	minetest.remove_detached_inventory("yl_speak_up_player_"..tostring(pname))
end
