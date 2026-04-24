-----------------------------------------------------------------------------
-- limits for trading: maximum and minimum stock to keep
-----------------------------------------------------------------------------
-- sometimes players may not want the NPC to sell *all* of their stock,
-- or not let the NPC buy endless amounts of something when only a limited
-- amount is needed
-----------------------------------------------------------------------------

-- helper function: make sure all necessary entries in the trades table exist
yl_speak_up.setup_trade_limits = function(dialog)
	if(not(dialog)) then
		dialog = {}
	end
	if(not(dialog.trades)) then
		dialog.trades = {}
	end
	if(not(dialog.trades.limits)) then
		dialog.trades.limits = {}
	end
	if(not(dialog.trades.limits.sell_if_more)) then
		dialog.trades.limits.sell_if_more = {}
	end
	if(not(dialog.trades.limits.buy_if_less)) then
		dialog.trades.limits.buy_if_less = {}
	end
	return dialog
end


-- helper function: count how many items the NPC has in his inventory
--   empty stacks are counted under the key "";
--   for other items, the amount of items of each type is counted
yl_speak_up.count_npc_inv = function(n_id)
	if(not(n_id)) then
		return {}
	end
	-- the NPC's inventory
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(n_id)})

	if(not(npc_inv)) then
		return {}
	end
	local anz = npc_inv:get_size('npc_main')
	local stored = {}
	for i=1, anz do
		local stack = npc_inv:get_stack('npc_main', i )
		local name = stack:get_name()
		local count = stack:get_count()
		-- count empty stacks 
		if(name=="") then
			count = 1
		end
		-- count how much of each item is there
		if(not(stored[ name ])) then
			stored[ name ] = count
		else
			stored[ name ] = stored[ name ] + count
		end
	end
	return stored
end


-- helper function: update the items table so that it reflects a limitation
-- items is a table (list) with these entries:
--   [1] 0 in stock;
--   [2] sell if more than 0;
--   [3] buy if less than 10000;
--   [4] item is part of a trade offer
yl_speak_up.insert_trade_item_limitation = function( items, k, i, v )
	if( i<1 or i>4) then
		return;
	end
	if( not( items[ k ] )) then
		-- 0 in stock; sell if more than 0; buy if less than 10000; item is part of a trade offer
		items[ k ] = { 0, 0, 10000, false, #items }
	end
	items[ k ][ i ] = v
end


-- helper function; returns how often a trade can be done
-- 	stock_buy	how much of the buy stack does the NPC have in storage?
-- 	stock_pay	how much of the price stack does the NPC have in storage?
-- 	buy_stack	stack containing the item the NPC sells
-- 	pay_stack	stack containing the price for said item
-- 	min_storage	how many items of the buy stack items shall the NPC keep?
-- 	max_storage	how many items of the pay stack items can the NPC accept?
-- used in fs_trade_via_buy_button.lua and fs_trade_list.lua
yl_speak_up.get_trade_amount_available = function(stock_buy, stock_pay, buy_stack, pay_stack, min_storage, max_storage)
	local stock = 0
	-- the NPC shall not sell more than this
	if(min_storage and min_storage > 0) then
		stock_buy = math.max(0, stock_buy - min_storage)
	end
	stock = math.floor(stock_buy / buy_stack:get_count())
	-- the NPC shall not buy more than this
	if(max_storage and max_storage < 10000) then
		stock_pay = math.min(max_storage - stock_pay, 10000)
		stock = math.min(stock, math.floor(stock_pay / pay_stack:get_count()))
	end
	return stock
end



-- helper function; also used by fs_trade_list.lua
yl_speak_up.get_sorted_trade_id_list = function(dialog, show_dialog_option_trades)
	-- make sure all fields exist
	yl_speak_up.setup_trade_limits(dialog)
	local keys = {}
	if(show_dialog_option_trades) then
		for k, v in pairs(dialog.trades) do
			if(k ~= "limits" and k ~= "" and v.d_id) then
				table.insert(keys, k)
			end
		end
	else
		for k, v in pairs(dialog.trades) do
			if(k ~= "limits" and k ~= "") then
				-- structure of the indices: sell name amount for name amount
				local parts = string.split(k, " ")
				if(parts and #parts == 6 and parts[4] == "for"
				  and v.pay and v.pay[1] ~= "" and v.pay[1] == parts[5].." "..parts[6]
				  and v.buy and v.buy[1] ~= "" and v.buy[1] == parts[2].." "..parts[3]
				  and minetest.registered_items[parts[5]]
				  and minetest.registered_items[parts[2]]
				  and tonumber(parts[6]) > 0
				  and tonumber(parts[3]) > 0) then
					table.insert(keys, k)
				end
			end
		end
	end
	table.sort(keys)
	return keys
end


-- taken from trade_simple.lua:

-- helper function for
-- 	yl_speak_up.input_do_trade_simple (here) and
-- 	yl_speak_up.input_trade_via_buy_button (in fs_trade_via_buy_button.lua)
--
-- delete a trade; this can be done here only if..
--  * it is a trade from the trade list (not an effect of a dialog option)
--  * it is a trade associated with a dialog option and the player is in
--    edit mode
--  * the player has the necessary privs
-- This option is available without having to enter edit mode first.
yl_speak_up.delete_trade_simple = function(player, trade_id)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		-- not a really helpful message - but then, this should never happen (player probably cheated)
		return yl_speak_up.trade_fail_msg
	end
	-- get the necessary dialog data
	local dialog = yl_speak_up.speak_to[pname].dialog
	-- store d_id and o_id in order to be able to return to the right
	-- edit options dialog
	local back_to_d_id = nil
	local back_to_o_id = nil
	if(dialog and dialog.trades and trade_id
	  and dialog.trades[ trade_id ] and n_id) then

		-- Note: That the trade cannot be deleted outside edit mode if it is the action
		--       belonging to an option is checked in editor/trade_*.lua
		if( dialog.trades[ trade_id ].d_id ) then
			back_to_d_id = dialog.trades[ trade_id ].d_id
			back_to_o_id = dialog.trades[ trade_id ].o_id
		end
		-- log the change
		yl_speak_up.log_change(pname, n_id,
			"Trade: Deleted offer "..tostring(trade_id)..".")
		-- delete this particular trade
		dialog.trades[ trade_id ] = nil
		-- actually save the dialog to disk
		yl_speak_up.save_dialog(n_id, dialog)
		-- we are done with this trade
		yl_speak_up.trade[pname] = nil
		yl_speak_up.speak_to[pname].trade_id = nil
		yl_speak_up.speak_to[pname].trade_done = nil
	end
	-- always return to edit options dialog if deleting a trade that belonged to one
	if(back_to_d_id and back_to_o_id) then
		yl_speak_up.show_fs(player, "edit_option_dialog",
			{n_id = n_id, d_id = back_to_d_id, o_id = back_to_o_id})
		return
	end
	-- go back showing the trade list (since we deleted this trade)
	yl_speak_up.show_fs(player, "trade_list")
	return
end
