-- spimple trading: one item(stack) for another item(stack)

-- fallback message if something went wrong
yl_speak_up.trade_fail_fs = "size[6,2]"..
                "label[0.2,0.5;Ups! The trade is not possible.\nPlease notify an admin.]"..
		"button_exit[2,1.5;1,0.9;exit;Exit]"



-- possible inputs:
--    fields.edit_trade_simple         go on to showing the add_trade_simple formspec
--    fields.abort_trade_simple, ESC,  depends on context
--    fields.delete_trade_simple       delete this trade
--    fields.finished_trading
--           if in edit_mode:          go back to edit options dialog (handled by editor/)
--           if traded at least once:  go on to the target dialog
--           if not traded:            go back to the original dialog
yl_speak_up.input_do_trade_simple = function(player, formname, fields)
	if(not(player)) then
		return 0
	end
	local pname = player:get_player_name()

	-- which trade are we talking about?
	local trade = yl_speak_up.trade[pname]

	-- show the trade list
	if(fields.back_to_trade_list) then
		yl_speak_up.show_fs(player, "trade_list")
		return
	end

	-- get from a dialog option trade back to the list of all these trades
	if(fields.show_trade_list_dialog_options) then
		yl_speak_up.show_fs(player, "trade_list", true)
		return
	end

	-- a new trade has been stored - show it
	if(fields.trade_simple_stored) then
		yl_speak_up.show_fs(player, "trade_simple", yl_speak_up.speak_to[pname].trade_id)
		return
	end

	if(fields.buy_directly) then
		local error_msg = yl_speak_up.do_trade_direct(player)

		if(error_msg ~= "") then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:do_trade_simple",
				formspec = "size[6,2]"..
					"label[0.2,-0.2;"..error_msg.."]"..
					"button[2,1.5;1,0.9;back_from_error_msg;Back]"})
			return
		end
		yl_speak_up.show_fs(player, "trade_simple", yl_speak_up.speak_to[pname].trade_id)
		return
	end

	if(fields.delete_trade_simple) then
		yl_speak_up.delete_trade_simple(player, trade.trade_id)
		return
	end


	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	local player_inv = player:get_inventory()
	-- give the items from the pay slot back
	local pay = trade_inv:get_stack("pay", 1)
	if( player_inv:room_for_item("main", pay)) then
		player_inv:add_item("main", pay)
		trade_inv:set_stack("pay", 1, "")
	end
	-- clear the buy slot as well
	trade_inv:set_stack("buy", 1, "")

	-- show the edit trade formspec
	if(fields.edit_trade_simple) then
		yl_speak_up.show_fs(player, "add_trade_simple", trade.trade_id)
		return
	end

	-- go back to the main dialog
	if(fields.abort_trade_simple or fields.quit or fields.finished_trading) then
		-- was the action a success?
		local success = not(not(trade and trade.trade_done and trade.trade_done > 0))
		local a_id = trade.a_id
		local o_id = trade.o_id
		local n_id = yl_speak_up.speak_to[pname].n_id
		yl_speak_up.debug_msg(player, n_id, o_id, "Ending trade.")
		-- done trading
		yl_speak_up.speak_to[pname].target_d_id = nil
		yl_speak_up.speak_to[pname].trade_id = nil
		-- execute the next action
		yl_speak_up.execute_next_action(player, a_id, success, formname)
		return
	end

	-- show this formspec again
	yl_speak_up.show_fs(player, "trade_simple")
end






-- try to do the trade directly - without moving items in the buy/sell inventory slot
-- returns error_msg or "" when successful
yl_speak_up.do_trade_direct = function(player)
	if(not(player)) then
		return "Player, where are you?"
	end
	local pname = player:get_player_name()
	-- which trade are we talking about?
	local trade = yl_speak_up.trade[pname]
	-- do we have all the necessary data?
	if(not(trade) or trade.trade_type ~= "trade_simple") then
		return "No trade found!"
	end
	-- the players' inventory
	local player_inv = player:get_inventory()
	-- the NPCs' inventory
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(trade.n_id)})
	-- has the NPC the item he wants to sell?
	if(    not(npc_inv:contains_item("npc_main", trade.npc_gives))) then
		return "Sorry. This item is sold out!"
	-- has the NPC room for the payment?
	elseif(not(npc_inv:room_for_item("npc_main", trade.player_gives))) then
		return "Sorry. No room to store your payment!\n"..
			"Please try again later."
	-- can the player pay the price?
	elseif(not(player_inv:contains_item("main", trade.player_gives))) then
		return "You can't pay the price!"
	-- has the player room for the sold item?
	elseif(not(player_inv:room_for_item("main", trade.npc_gives))) then
		return "You don't have enough free inventory space.\n"..
			"Trade aborted."
	end
	local payment = player_inv:remove_item("main", trade.player_gives)
	local sold    = npc_inv:remove_item("npc_main", trade.npc_gives)
	-- used items cannot be sold as there is no fair way to indicate how
	-- much they are used
	if(payment:get_wear() > 0 or sold:get_wear() > 0) then
		-- revert the trade
		player_inv:add_item("main", payment)
		npc_inv:add_item("npc_main", sold)
		return "At least one of the items that shall be traded\n"..
			"is dammaged. Trade aborted."
	end
	player_inv:add_item("main", sold)
	npc_inv:add_item("npc_main", payment)
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
	return ""
end


-- simple trade: one item(stack) for another
-- handles configuration of new trades and showing the formspec for trades;
-- checks if payment and buying is possible
yl_speak_up.get_fs_do_trade_simple = function(player, trade_id)
	if(not(player)) then
		return yl_speak_up.trade_fail_fs
	end
	local pname = player:get_player_name()
	-- which trade are we talking about?
	local trade = yl_speak_up.trade[pname]

	if(trade and trade.trade_id and trade_id and trade.trade_id == trade_id) then
		-- nothing to do; trade is already loaded and stored
	elseif(trade_id) then
		local d_id = yl_speak_up.speak_to[pname].d_id
		local n_id = yl_speak_up.speak_to[pname].n_id
		local dialog = yl_speak_up.speak_to[pname].dialog

		yl_speak_up.setup_trade_limits(dialog)
		trade = {
			-- we start with the simple trade
			trade_type = "trade_simple",
			-- can be determined from other variables, but it is easier to store it here
			n_id = n_id,
			npc_name = dialog.n_npc,
			-- for statistics and in order to determine which dialog to show next
			trade_done = 0,
			-- we need to know which option this is
			target_dialog = d_id,
			trade_is_trade_list = true,
			trade_id = trade_id
		}
		if(dialog.trades[ trade_id ]) then
			trade.player_gives = dialog.trades[ trade_id ].pay[1]
			trade.npc_gives    = dialog.trades[ trade_id ].buy[1]
			trade.trade_is_trade_list = not(dialog.trades[ trade_id ].d_id)
			yl_speak_up.speak_to[pname].trade_id = trade_id
			-- copy the limits
			local stack = ItemStack(trade.npc_gives)
			trade.npc_gives_name = stack:get_name()
			trade.npc_gives_amount = stack:get_count()
			trade.min_storage = dialog.trades.limits.sell_if_more[ trade.npc_gives_name ]
			stack = ItemStack(trade.player_gives)
			trade.player_gives_name = stack:get_name()
			trade.player_gives_amount = stack:get_count()
			trade.max_storage = dialog.trades.limits.buy_if_less[  trade.player_gives_name ]
		else
			trade.edit_trade = true
		end
		yl_speak_up.trade[pname] = trade
		-- store which action we are working at
		trade.a_id = yl_speak_up.speak_to[pname].a_id
	else
		trade_id = yl_speak_up.speak_to[pname].trade_id
		trade.trade_id = trade_id
	end

	-- do we have all the necessary data?
	if(not(trade) or trade.trade_type ~= "trade_simple") then
		return yl_speak_up.trade_fail_fs
	end
	-- the common formspec, shared by actual trade and configuration
	-- no listring here as that would make things more complicated
	local formspec = table.concat({ -- "size[8.5,8]"..
		yl_speak_up.show_fs_simple_deco(8.5, 8),
		"label[4.35,0.7;", minetest.formspec_escape(trade.npc_name), " sells:]",
		"list[current_player;main;0.2,3.85;8,1;]",
		"list[current_player;main;0.2,5.08;8,3;8]"
		}, "")

	-- configuration of a new trade happens here
	if(not(trade.player_gives) or not(trade.npc_gives) or trade.edit_trade) then
		return yl_speak_up.get_fs_add_trade_simple(player, trade_id)
	end

	-- view for the customer when actually trading

	-- buy, sell and config items need to be placed somewhere
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	-- the players' inventory
	local player_inv = player:get_inventory()
	-- the NPCs' inventory
	local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(trade.n_id)})

	-- show edit button for the owner if the owner can edit the npc
	if(yl_speak_up.may_edit_npc(player, trade.n_id)) then
		-- for trades in trade list: allow delete (new trades can easily be added)
		-- allow delete for trades in trade list even if not in edit mode
		-- (entering edit mode for that would be too much work)
		formspec = formspec..
			"button[0.2,2.0;1.2,0.9;delete_trade_simple;Delete]"..
			"tooltip[delete_trade_simple;"..
				"Delete this trade. You can do so only if\n"..
				"you can edit the NPC as such (i.e. own it).]"
		if(not(trade.trade_is_trade_list)) then
			-- normal back button will lead to the talk dialog or edit option dialog;
			-- add this second back button to go back to the list of all dialog option trades
			formspec = formspec..
				"button[0.2,1.0;2.0,0.9;show_trade_list_dialog_options;Back to list]"..
				"tooltip[show_trade_list_dialog_options;"..
					"Click here to get back to the list of all trades\n"..
					"associated with dialog options (like this one).]"
			local dialog = yl_speak_up.speak_to[pname].dialog
			local tr = dialog.trades[ trade_id ]
			if( tr and tr.d_id and tr.o_id) then
				formspec = formspec..
					"label[0.2,-0.3;This trade belongs to dialog "..
						minetest.formspec_escape(tostring(tr.d_id)).." option "..
						minetest.formspec_escape(tostring(tr.o_id))..".]"
			end
		end
	end
	-- the functionality of the back button depends on context
	if(not(trade.trade_is_trade_list)) then
		-- go back to the right dialog (or forward to the next one)
		formspec = formspec..
--			"button[6.2,1.6;2.0,0.9;finished_trading;Back to talk]"..
			"button[0.2,0.0;2.0,0.9;finished_trading;Back to talk]"..
			"tooltip[finished_trading;Click here once you've traded enough with this "..
				"NPC and want to get back to talking.]"
	else
		-- go back to the trade list
		formspec = formspec..  "button[0.2,0.0;2.0,0.9;back_to_trade_list;Back to list]"..
			"tooltip[back_to_trade_list;Click here once you've traded enough with this "..
				"NPC and want to get back to the trade list.]"
	end


	local trade_possible_msg = "Status of trade: Unknown."
	local can_trade = false
	-- find out how much the npc has stoerd
	local stock_pay = 0
	local stock_buy = 0
	-- only count the inv if there actually are any mins or max
	if(trade.min_storage or trade.max_storage) then
		local n_id = yl_speak_up.speak_to[pname].n_id
		local counted_npc_inv = {}
		counted_npc_inv = yl_speak_up.count_npc_inv(n_id)
		stock_pay = counted_npc_inv[trade.player_gives_name] or 0
		stock_buy = counted_npc_inv[trade.npc_gives_name] or 0
	end
	-- can the NPC provide his part?
	if(not(npc_inv:contains_item("npc_main", trade.npc_gives))) then
		trade_possible_msg = "Sorry. "..minetest.formspec_escape(trade.npc_name)..
			" ran out of stock.\nPlease come back later."
	-- has the NPC room for the payment?
	elseif(not(npc_inv:room_for_item("npc_main", trade.player_gives))) then
		trade_possible_msg = "Sorry. "..minetest.formspec_escape(trade.npc_name)..
			" ran out of inventory space.\nThere is no room to store your payment!"
	-- trade limit: is enough left after the player buys the item?
	elseif(trade.min_storage and trade.min_storage > stock_buy - trade.npc_gives_amount) then
		trade_possible_msg = "Sorry. "..minetest.formspec_escape(trade.npc_name)..
			" currently does not want to\nsell that much."..
			" Current stock: "..tostring(stock_buy)..
			" (min: "..tostring(trade.min_storage)..
			"). Perhaps later?"
	-- trade limit: make sure the bought amount does not exceed the desired maximum
	elseif(trade.max_storage and trade.max_storage < stock_pay + trade.player_gives_amount) then
		trade_possible_msg = "Sorry. "..minetest.formspec_escape(trade.npc_name)..
			" currently does not want to\nbuy that much."..
			" Current stock: "..tostring(stock_pay)..
			" (max: "..tostring(trade.max_storage)..
			"). Perhaps later?"
	-- trade as an action
	elseif(not(trade.trade_is_trade_list)) then
		if(trade_inv:contains_item("pay", trade.player_gives)) then
		-- all good so far; move the price stack to the pay slot
			-- move price item to the price slot
			local stack = player_inv:remove_item("main", trade.player_gives)
			trade_inv:add_item("pay", stack)
			trade_possible_msg = "Please take your purchase!"
			can_trade = true
		elseif(trade_inv:is_empty("pay")) then
			trade_possible_msg = "Please insert the right payment in the pay slot\n"..
				"and then take your purchase."
			can_trade = false
		else
			trade_possible_msg = "This is not what "..minetest.formspec_escape(trade.npc_name)..
				" wants.\nPlease insert the right payment!"
			can_trade = false
		end
	-- can the player pay?
	elseif(not(player_inv:contains_item("main", trade.player_gives))) then
		-- both slots will remain empty
		trade_possible_msg = "You cannot pay the price."
	-- is the slot for the payment empty?
	elseif not(trade_inv:is_empty("pay")) then
		-- both slots will remain empty
		-- (the slot may already contain the right things; we'll find that out later on)
		trade_possible_msg = "This is not what "..minetest.formspec_escape(trade.npc_name)..
			" wants.\nPlease insert the right payment!"
	else
		trade_possible_msg = "Please insert the right payment in the pay slot\n"..
			"or click on \"buy\"."..
			"]button[6.5,2.0;1.2,0.9;buy_directly;Buy]"..
			"tooltip[buy_directly;"..
				"Click here in order to buy directly without having to insert\n"..
				"your payment manually into the pay slot."
		can_trade = true
	end

	-- make sure the sale slot is empty (we will fill it if the trade is possible)
	trade_inv:set_stack("buy", 1, "")
	-- after all this: does the payment slot contain the right things?
	if(can_trade and trade_inv:contains_item("pay", trade.player_gives)) then
		trade_possible_msg = "Take the offered item(s) in order to buy them."

		-- only new/undammaged tools, weapons and armor are accepted
		if(trade_inv:get_stack("pay", 1):get_wear() > 0) then
			trade_possible_msg = "Sorry. "..minetest.formspec_escape(trade.npc_name)..
				" accepts only undammaged items."
		else
			-- put a *copy* of the item(stack) that is to be sold in the sale slot
			trade_inv:add_item("buy", trade.npc_gives)
		end
	end

	if(can_trade and not(player_inv:room_for_item("main", trade.npc_gives))) then
		-- the player has no room for the sold item; give a warning
		trade_possible_msg = "Careful! You do not seem to have enough\n"..
				"free inventory space to store your purchase."
	end

	local trades_done = "Not yet traded."
	if(yl_speak_up.trade[pname].trade_done > 0) then
		trades_done = "Traded: "..tostring(yl_speak_up.trade[pname].trade_done).." time(s)"
	end

	return table.concat({formspec,
		"label[2.5,0.0;Trading with ",
			minetest.formspec_escape(trade.npc_name),
			"]",
		"label[1.5,0.7;You pay:]",
		-- show images of price and what is sold so that the player knows what
		-- it costs and what he will get even if the trade is not possible at
		-- that moment
		"item_image[2.1,1.2;0.8,0.8;",
			tostring(trade.player_gives),
			"]",
		"item_image[5.1,1.2;0.8,0.8;",
			tostring(trade.npc_gives),
			"]",
		"image[3.5,2.0;1,1;gui_furnace_arrow_bg.png^[transformR270]",
		-- show the pay slot from the detached player's trade inventory
		"list[detached:yl_speak_up_player_",
			pname,
			";pay;2,2.0;1,1;]",
		-- show the buy slot from the same inventory
		"list[detached:yl_speak_up_player_",
			pname,
			";buy;5,2.0;1,1;]",
		"label[1.5,3.0;",
			trade_possible_msg,
			"]",
		"label[6.0,1.5;",
			trades_done,
			"]"
		}, "")
end


yl_speak_up.get_fs_do_trade_simple_wrapper = function(player, param)
	local pname = player:get_player_name()
	-- the optional parameter param is the trade_id
	if(not(param) and yl_speak_up.speak_to[pname]) then
		param = yl_speak_up.speak_to[pname].trade_id
	end
	return yl_speak_up.get_fs_do_trade_simple(player, param)
end


yl_speak_up.register_fs("do_trade_simple",
	yl_speak_up.input_do_trade_simple,
	yl_speak_up.get_fs_do_trade_simple_wrapper,
	-- force formspec version 1:
	1
)
