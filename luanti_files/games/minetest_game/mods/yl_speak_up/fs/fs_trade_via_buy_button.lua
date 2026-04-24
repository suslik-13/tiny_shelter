
-- buy-button-based trading from trade list: one item(stack) for another item(stack)

-- helper function
yl_speak_up.get_trade_item_desc = function(item)
	local stack = ItemStack(item)
	local def = minetest.registered_items[stack:get_name()]
	if(def and def.description) then
		return minetest.formspec_escape(tostring(stack:get_count()).."x "..def.description)
	end
	return minetest.formspec_escape(tostring(stack:get_count()).."x "..stack:get_name())
end


yl_speak_up.input_trade_via_buy_button = function(player, formname, fields)
	local pname = player:get_player_name()

	if(fields.buy_directly) then
		local trade_id = yl_speak_up.speak_to[pname].trade_id
		local res = yl_speak_up.check_trade_via_buy_button(player, trade_id, true)

		if(res.msg ~= "OK") then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:trade_via_buy_button",
				formspec = "size[6,2.5]"..
					"label[0.2,-0.2;"..res.msg.."\nTrade aborted.]"..
					"button[2,1.5;1,0.9;back_from_error_msg;Back]"})
			return
		end
		yl_speak_up.show_fs(player, "trade_via_buy_button", trade_id)
		return
	end

	-- scroll through the trades with prev/next buttons
	if(fields.prev_trade or fields.next_trade) then
		local pname = player:get_player_name()
		local n_id = yl_speak_up.speak_to[pname].n_id
		local dialog = yl_speak_up.speak_to[pname].dialog
		local keys = yl_speak_up.speak_to[pname].trade_id_list or {}
		local trade_id = yl_speak_up.speak_to[pname].trade_id
		local idx = math.max(1, table.indexof(keys, trade_id))
		if(fields.prev_trade) then
			idx = idx - 1
		elseif(fields.next_trade) then
			idx = idx + 1
		end
		if(idx > #keys) then
			idx = 1
		elseif(idx < 1) then
			idx = #keys
		end
		yl_speak_up.speak_to[pname].trade_id = keys[idx]
		-- this is another trade; count from 0 again
		yl_speak_up.speak_to[pname].trade_done = nil
	end

	if(fields.delete_trade_via_buy_button) then
		local trade_id = yl_speak_up.speak_to[pname].trade_id
		yl_speak_up.delete_trade_simple(player, trade_id)
		return
	end

	-- the owner wants to go back to the trade list from a dialog trade (action) view
	if(fields.back_to_trade_list_dialog_trade) then
		yl_speak_up.show_fs(player, "trade_list", true)
		return
	-- a dialog trade (action) was displayed; go back to the corresponding dialog
	elseif(fields.back_to_dialog) then
		local pname = player:get_player_name()
		local n_id = yl_speak_up.speak_to[pname].n_id
		local dialog = yl_speak_up.speak_to[pname].dialog
		local trade_id = yl_speak_up.speak_to[pname].trade_id
		local new_d_id = dialog.trades[ trade_id ].d_id
		yl_speak_up.speak_to[pname].d_id = new_d_id
		yl_speak_up.speak_to[pname].trade_list = {}
		yl_speak_up.show_fs(player, "talk") -- TODO parameters
		return
	-- show the trade list
	elseif(fields.back_to_trade_list or fields.quit
	  or not(yl_speak_up.speak_to[pname].trade_id)) then
		yl_speak_up.show_fs(player, "trade_list")
		return
	end

	-- show the trade formspec again
	yl_speak_up.show_fs(player, "trade_via_buy_button", yl_speak_up.speak_to[pname].trade_id)
end


-- helper function
-- if do_trade is false: check only if the trade would be possible and return
-- 	error message if not; return "OK" when trade is possible
-- if do_trade is true: if possible, execute the trade; return the same as above
-- also returns how many times the trade could be done (stock= ..)
yl_speak_up.check_trade_via_buy_button = function(player, trade_id, do_trade)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	-- make sure all necessary table entries exist
	yl_speak_up.setup_trade_limits(dialog)
	local this_trade = dialog.trades[trade_id]
	-- the players' inventory
	local player_inv = player:get_inventory()
	-- the NPCs' inventory
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(n_id)})
	if(not(this_trade)) then
		return {msg = "Trade not found.", stock=0}
	elseif(not(player_inv)) then
		return {msg = "Couldn't find player's inventory.", stock=0}
	elseif(not(npc_inv)) then
		return {msg = "Couldn't find the NPC's inventory.", stock=0}
	end
	-- store which trade we're doing
	yl_speak_up.speak_to[pname].trade_id = trade_id

	-- what the player pays to the npc:
	local pay_stack = ItemStack(dialog.trades[ trade_id ].pay[1])
	-- what the npc sells and the player buys:
	local buy_stack = ItemStack(dialog.trades[ trade_id ].buy[1])
	local npc_name = minetest.formspec_escape(dialog.n_npc)

	-- can the NPC provide his part?
	if(not(npc_inv:contains_item("npc_main", buy_stack))) then
		return {msg = "Out of stock", stock = 0}
		-- return {msg = "Sorry. "..npc_name.." ran out of stock.\nPlease come back later.", stock=0}
	-- has the NPC room for the payment?
	elseif(not(npc_inv:room_for_item("npc_main", pay_stack))) then
		return {npc_name.." has no room left!", stock = 0}
--		return "Sorry. "..npc_name.." ran out of inventory space.\n"..
--			"There is no room to store your payment!"
	end

	local counted_npc_inv = yl_speak_up.count_npc_inv(n_id)
	local stock_pay = counted_npc_inv[ pay_stack:get_name() ] or 0
	local stock_buy = counted_npc_inv[ buy_stack:get_name() ] or 0
	-- are there any limits which we have to take into account?
	local min_storage = dialog.trades.limits.sell_if_more[ buy_stack:get_name() ]
	local max_storage = dialog.trades.limits.buy_if_less[  pay_stack:get_name() ]
	if((min_storage and min_storage > 0)
	  or (max_storage and max_storage < 10000)) then
		-- trade limit: is enough left after the player buys the item?
		if(    min_storage and min_storage > stock_buy - buy_stack:get_count()) then
--			return "Stock too low. Only "..tostring(stock_buy)..
--				" left, want to keep "..tostring(min_storage).."."
			return {msg = "Sorry. "..npc_name.." currently does not want to\nsell that much."..
				" Current stock: "..tostring(stock_buy)..
				" (min: "..tostring(min_storage).."). Perhaps later?",
				stock = 0}
		-- trade limit: make sure the bought amount does not exceed the desired maximum
		elseif(max_storage and max_storage < stock_pay + pay_stack:get_count()) then
			return {msg = "Sorry. "..npc_name.." currently does not want to\n"..
				"buy that much."..
				" Current stock: "..tostring(stock_pay)..
				" (max: "..tostring(max_storage).."). Perhaps later?",
				stock = 0}
		end
		-- the NPC shall not sell more than this
		if(min_storage and min_storage > 0) then
			stock_buy = math.max(0, stock_buy - min_storage)
		end
	end
	-- how often can this trade be done?
	local stock = yl_speak_up.get_trade_amount_available(
				stock_buy, stock_pay,
				buy_stack, pay_stack,
				min_storage, max_storage)
	-- can the player pay?
	if(not(player_inv:contains_item("main", pay_stack))) then
		-- both slots will remain empty
		return {msg = "You can't pay the price.", stock = stock}
	elseif(not(player_inv:room_for_item("main", buy_stack))) then
		-- the player has no room for the sold item; give a warning
		return {msg = "You don't have enough free inventory\nspace to store your purchase.",
			stock = stock}
	end

	-- was it a dry run to check if the trade is possible?
	if(not(do_trade)) then
		return {msg = "OK", stock = stock}
	end

	-- actually do the trade
	local payment = player_inv:remove_item("main",  pay_stack)
	local sold    = npc_inv:remove_item("npc_main", buy_stack)
	-- used items cannot be sold as there is no fair way to indicate how
	-- much they are used
	if(payment:get_wear() > 0 or sold:get_wear() > 0) then
		-- revert the trade
		player_inv:add_item("main", payment)
		npc_inv:add_item("npc_main", sold)
		return {msg  = "Sorry. "..npc_name.." accepts only undammaged items.", stock = stock}
	end
	player_inv:add_item("main", sold)
	npc_inv:add_item("npc_main", payment)
	-- save the inventory of the npc so that the payment does not get lost
	yl_speak_up.save_npc_inventory( n_id )
	-- store for statistics how many times the player has executed this trade
	-- (this is also necessary to switch to the right target dialog when
	--  dealing with dialog options trades)
	if(not(yl_speak_up.speak_to[pname].trade_done)) then
		yl_speak_up.speak_to[pname].trade_done = 0
	end
	yl_speak_up.speak_to[pname].trade_done = yl_speak_up.speak_to[pname].trade_done + 1
	-- log the trade
	yl_speak_up.log_change(pname, n_id,
		"bought "..tostring(buy_stack:to_string())..
		" for "..tostring(pay_stack:to_string()))
	return {msg = "OK", stock = stock}
end


-- trade for a player (the owner of the NPC): one item(stack) for another
--   trade by clicking on the "buy" button instead of moving inventory items around
--   checks if payment and buying is possible
yl_speak_up.get_fs_trade_via_buy_button = function(player, trade_id)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	-- make sure all necessary table entries exist
	yl_speak_up.setup_trade_limits(dialog)
	local this_trade = dialog.trades[trade_id]
	-- the players' inventory
	local player_inv = player:get_inventory()
	-- the NPCs' inventory
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(n_id)})
	if(not(this_trade) or not(player_inv) or not(npc_inv)) then
		return yl_speak_up.trade_fail_fs
	end
	-- what the player pays to the npc:
	local pay = dialog.trades[ trade_id ].pay[1]
	-- what the npc sells and the player buys:
	local buy = dialog.trades[ trade_id ].buy[1]
	local pay_name = yl_speak_up.get_trade_item_desc(pay)
	local buy_name = yl_speak_up.get_trade_item_desc(buy)
	local npc_name = minetest.formspec_escape(dialog.n_npc)
	-- get the number of the trade
	local keys = yl_speak_up.speak_to[pname].trade_id_list or {}
	local idx = math.max(1, table.indexof(keys, trade_id))

	-- the common formspec, shared by actual trade and configuration
	-- no listring here as that would make things more complicated
	local formspec = { -- "size[8.5,8]"..
		yl_speak_up.show_fs_simple_deco(10, 8.8),
		"container[0.75,0]",
		"label[4.35,1.4;", npc_name, " sells:]",
		"list[current_player;main;0.2,4.55;8,1;]",
		"list[current_player;main;0.2,5.78;8,3;8]",
--		"label[7.0,0.2;Offer ", tostring(idx), "/", tostring(#keys), "]",
--		"label[2.5,0.7;Trading with ", npc_name, "]",
		"label[1.5,0.7;Offer no. ",
			tostring(idx), "/", tostring(#keys),
			" from ", npc_name, "]",
		"label[1.5,1.4;You pay:]",
		-- show images of price and what is sold so that the player knows what
		-- it costs and what he will get even if the trade is not possible at
		-- that moment
--		"item_image[2.1,2.0;1,1;",
		"item_image_button[2.1,1.9;1.2,1.2;",
			tostring(pay),
			";pay_item_img;",
			"]",
--		"item_image[5.1,2.0;1,1;",
--			tostring(buy),
		"item_image_button[5.1,1.9;1.2,1.2;",
			tostring(buy),
			";buy_item_img;",
			"]",
		"label[1.5,3.0;",
			pay_name,
			"]",
		"label[4.35,3.0;",
			buy_name,
			"]",
		"image[3.5,2.0;1,1;gui_furnace_arrow_bg.png^[transformR270]",
	}

	if(not(dialog.trades[ trade_id ].d_id)) then
		-- go back to the trade list
		table.insert(formspec, "button[0.2,0.0;8.0,1.0;back_to_trade_list;Back to trade list]")
		table.insert(formspec, "tooltip[back_to_trade_list;"..
						"Click here once you've traded enough with this "..
						"NPC and want to get back to the trade list.]")
	elseif(true) then
		-- go back to the trade list
		table.insert(formspec, "button[0.2,0.0;3.8,1.0;back_to_trade_list_dialog_trade;Back to trade list]")
		table.insert(formspec, "tooltip[back_to_trade_list_dialog_trade;"..
						"Click here once you've traded enough with this "..
						"NPC and want to get back to the trade list.]")
		-- go back to dialog
		table.insert(formspec, "button[4.2,0.0;3.8,1.0;back_to_dialog;Back to dialog ")
		table.insert(formspec, minetest.formspec_escape(dialog.trades[ trade_id ].d_id)..
					" (option "..
					minetest.formspec_escape(dialog.trades[ trade_id ].o_id)..
					")")
		table.insert(formspec, "]")
		table.insert(formspec, "tooltip[back_to_dialog;"..
						"Click here once you've traded enough with this "..
						"NPC and want to get back to talking with the NPC.]")
	else
		-- go back to dialog
		table.insert(formspec, "button[0.2,0.0;8.0,1.0;back_to_dialog;Back to dialog ")
		table.insert(formspec, minetest.formspec_escape(dialog.trades[ trade_id ].d_id))
		table.insert(formspec, "]")
		table.insert(formspec, "tooltip[back_to_dialog;"..
						"Click here once you've traded enough with this "..
						"NPC and want to get back to talking with the NPC.]")
	end

	-- show edit button for the owner if the player can edit the NPC
	if(yl_speak_up.may_edit_npc(player, n_id)) then
		-- for trades in trade list: allow delete (new trades can easily be added)
		-- allow delete for trades in trade list even if not in edit mode
		-- (entering edit mode for that would be too much work)
		table.insert(formspec,
			"button[0.2,2.0;1.2,0.9;delete_trade_via_buy_button;Delete]"..
			"tooltip[delete_trade_via_buy_button;"..
				"Delete this trade. You can do so only if\n"..
				"you can edit the NPC as such (i.e. own it).]")
	end

	-- dry-run: test if the trade can be done
	local res = yl_speak_up.check_trade_via_buy_button(player, trade_id, false)
	if(res.msg == "OK") then
		local buy_str = "Buy"
		local trade_done = yl_speak_up.speak_to[pname].trade_done
		if(trade_done and trade_done > 0) then
			buy_str = "Buy again. Bought: "..tostring(trade_done).."x"
		end
		table.insert(formspec, "button[0.2,3.5;8.0,1.0;buy_directly;")
--			"button[6.5,2.0;1.7,0.9;buy_directly;Buy]"..
		table.insert(formspec, buy_str)
		table.insert(formspec, "]")
		table.insert(formspec, "tooltip[buy_directly;Click here in order to buy.]")
	else
		-- set a red background color in order to alert thep layer to the error
		table.insert(formspec, "style_type[button;bgcolor=#FF4444]"..
					"button[0.2,3.5;8.0,1.0;back_from_error_msg;")
--		table.insert(formspec, "label[0.5,3.5;")
		table.insert(formspec, res.msg)
		table.insert(formspec, ']')
		-- set the background color for the next buttons back to our normal one
		table.insert(formspec, 'style_type[button;bgcolor=#a37e45]')
--		table.insert(formspec, "label[6.5,2.0;Trade not\npossible.]")
	end
	-- how often can this trade be repeated?
	if(res.stock and res.stock > 0) then
		table.insert(formspec, "label[6.5,2.0;Trade ")
		table.insert(formspec, tostring(res.stock))
		table.insert(formspec, " x\navailable]")
	end

	table.insert(formspec, "container_end[]"..
		"real_coordinates[true]"..
		"button[0.5,1.9;0.8,2.0;prev_trade;<]"..
		"button[11.7,1.9;0.8,2.0;next_trade;>]"..
		"tooltip[prev_trade;Show previous trade offer]"..
		"tooltip[next_trade;Show next trade offer]")
	return table.concat(formspec, '')
end


yl_speak_up.get_fs_trade_via_buy_button_wrapper = function(player, param)
	local pname = player:get_player_name()
	-- the optional parameter param is the trade_id
	if(not(param) and yl_speak_up.speak_to[pname]) then
		param = yl_speak_up.speak_to[pname].trade_id
	end
	return yl_speak_up.get_fs_trade_via_buy_button(player, param)
end


yl_speak_up.register_fs("trade_via_buy_button",
	yl_speak_up.input_trade_via_buy_button,
	yl_speak_up.get_fs_trade_via_buy_button_wrapper,
	-- force formspec version 1:
	1
)
