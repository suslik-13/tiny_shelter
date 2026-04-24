-- show a list of all trades

-- the player is accessing the trade list
yl_speak_up.input_trade_list = function(player, formname, fields)
        local pname = player:get_player_name()
	local d_id = yl_speak_up.speak_to[pname].d_id
	local n_id = yl_speak_up.speak_to[pname].n_id

        local dialog = yl_speak_up.speak_to[pname].dialog

	if(not(dialog.trades)) then
		dialog.trades = {}
	end

	for k, v in pairs(fields) do
		-- diffrent buttons need diffrent names..
		if(k and string.sub(k, 1, 9) == "show_more") then
			fields.button_up = true
		end
	end
	-- pressing up and down buttons needs to be handled here
	if(fields.button_up) then
		yl_speak_up.speak_to[pname].option_index =
			yl_speak_up.speak_to[pname].option_index + yl_speak_up.max_number_of_buttons
		yl_speak_up.show_fs(player, "trade_list", fields.show_dialog_option_trades)
                return
	elseif(fields.button_down) then
		yl_speak_up.speak_to[pname].option_index =
			yl_speak_up.speak_to[pname].option_index - yl_speak_up.max_number_of_buttons
		if yl_speak_up.speak_to[pname].option_index < 0 then
			yl_speak_up.speak_to[pname].option_index = 1
		end
		yl_speak_up.show_fs(player, "trade_list", fields.show_dialog_option_trades)
		return
	end

	-- the player wants to add a new trade
	if(fields.trade_list_add_trade) then
		-- show the trade config dialog for a new trade
		yl_speak_up.show_fs(player, "add_trade_simple", "new")
		return
	end

	if(fields.trade_limit) then
		-- show a list of how much the NPC can buy and sell
		yl_speak_up.show_fs(player, "trade_limit")
		return
	end

	if(fields.show_log) then
		-- show a log
		yl_speak_up.show_fs(player, "show_log", {log_type = "trade"})
		return
	end

	-- toggle between view of dialog option trades and trade list trades
	if(fields.show_dialog_option_trades
	  or fields.show_trade_list) then
		yl_speak_up.show_fs(player, "trade_list", fields.show_dialog_option_trades)
		return
	end

	-- go back to the main dialog
	if(fields.finished_trading) then
		yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = d_id})
		return
	end

	-- normal mode: the player wants to see a particular trade
	for k,v in pairs(dialog.trades) do
		-- the "_" is necessary for the price button so that offer and price
		-- button can each have their tooltip *and* lead to the same dialog
		if(fields[ k ] or fields[ k.."_" ]) then
			yl_speak_up.show_fs(player, "trade_via_buy_button", k)
			return
		end
	end

	-- show the inventory of the NPC
	if(fields.show_inventory) then
		yl_speak_up.show_fs(player, "inventory")
		return
	end
	-- TODO: and otherwise?
end


-- helper function for fs_trade_list: show a row of offers; returns h
yl_speak_up.show_trade_offer_row = function(h, i, pname_for_old_fs, formspec, row_content)
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"does_not_matter_"..tostring(i),
			"", "", false, "", false,
			pname_for_old_fs, 6, table.concat(row_content, ''))
	-- allow players with older clients to scroll down; this extra line
	-- makes this a lot easier and does not show a broken partial next
	-- trade line
	if(pname_for_old_fs) then
		table.insert(formspec, "style_type[button;bgcolor=#a37e45]")
		local text = "Show more offers."
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"show_more_"..tostring(i),
			text, text,
			true, nil, nil, pname_for_old_fs)
	end
	return h
end


-- show a list of all trades the NPC has to offer
-- if show_dialog_option_trades is set: show only those trades that are attached to options of dialogs;
--   otherwise show only those trades attached to the trade list
yl_speak_up.get_fs_trade_list = function(player, show_dialog_option_trades)
	if(not(player)) then
		return ""
	end
	local pname = player:get_player_name()

	-- which NPC is the player talking to?
	local n_id = yl_speak_up.speak_to[pname].n_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	-- do we have all the necessary data?
	if(not(n_id) or not(dialog.n_npc)) then
		return "size[6,2]"..
			"label[0.2,0.5;Ups! This NPC lacks ID or name.]"..
		                "button_exit[2,1.5;1,0.9;exit;Exit]"
	end
	-- the trade list is a bit special - we need to evaluate the preconditions of the
	-- options of the d_talk dialog and execute corresponding effects; this can be used
	-- to refill stock from chests or craft new items to increase stock
	local do_o_id = yl_speak_up.eval_trade_list_preconditions(player)
	if(do_o_id) then
		local effects = dialog.n_dialogs["d_trade"].d_options[do_o_id].o_results
		local d_option = dialog.n_dialogs["d_trade"].d_options[do_o_id]
		-- the return value is of no intrest here - we won't be showing another dialog,
		-- and alternate_text isn't relevant either; we just do the effects and then show
		-- the trade list
		local res = yl_speak_up.execute_all_relevant_effects(player, effects, do_o_id, true, d_option)
	end

	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		-- do not show trades attached to dialog options for players who cannot edit the NPC
		show_dialog_option_trades = false
	end

	local alternate_text = " I can offer you these trades.\n\n"..
				"Select one trade and then choose \"buy\" to actually buy something."..
				"\n\nThere may be more trades then those shown in the first row."..
				"\nPlease look at all my offers [that is, scroll down a bit]!"..
				"\n\n[$NPC_NAME$ looks expectantly at you.]"

	local pname_for_old_fs = yl_speak_up.get_pname_for_old_fs(pname)
	local formspec = {}
        local h = -0.8

	-- arrange the offers in yl_speak_up.trade_max_cols columns horizontally
	-- and yl_speak_up.trade_max_rows row vertically
	local row = 0
	local col = 0
	local anz_trades = 0

	-- make sure all fields (especially the buy and trade limits) are initialized properly
	yl_speak_up.setup_trade_limits(dialog)

	-- the order in which the trades appear shall not change each time;
	-- but lua cannot sort the keys of a table by itself...
	-- this function can be found in fs_trade_via_button.lua
	local sorted_trades = yl_speak_up.get_sorted_trade_id_list(dialog, show_dialog_option_trades)
	yl_speak_up.speak_to[pname].trade_id_list = sorted_trades

	-- how much stock does the NPC have?
	local counted_npc_inv = yl_speak_up.count_npc_inv(n_id)

	local row_content = {}
	for i, k in ipairs(sorted_trades) do
		local v = dialog.trades[ k ]
		  -- needs both to be negated because show_dialog_option_trades will most of the time be nil
		  -- and the actual value of v.d_id isn't of intrest here either
		if(   (not(show_dialog_option_trades) == not(v.d_id))
		  and v.pay and v.pay[1] and v.pay[1] ~= "" and v.buy and v.buy[1] and v.buy[1] ~= "") then
			local pay_stack = ItemStack(v.pay[1])
			local buy_stack = ItemStack(v.buy[1])
			local pay_stack_name = pay_stack:get_name()
			local buy_stack_name = buy_stack:get_name()
			-- do not show trades with nonexistant items
			if(  not(minetest.registered_items[ pay_stack_name ])
			  or not(minetest.registered_items[ buy_stack_name ])) then
				break
			end

			anz_trades = anz_trades + 1
			local kstr = tostring(minetest.formspec_escape(k))
			-- how many times can the NPC do this particular trade?
			local amount_available = yl_speak_up.get_trade_amount_available(
				(counted_npc_inv[ buy_stack_name ] or 0),
				(counted_npc_inv[ pay_stack_name ] or 0),
				buy_stack, pay_stack,
				dialog.trades.limits.sell_if_more[ buy_stack_name ],
				dialog.trades.limits.buy_if_less[  pay_stack_name ])

			local sold_out = false
			local color = "#a37e45" --"#777777"
			if(amount_available < 1) then
				sold_out = true
				color = "#663333"
--			else -- if admin shop
--				-- indicate that the shop will never run out of stock with a special color
--				color = "#999999"
			end
			table.insert(row_content,
				"container["..((col*4.5)-0.6)..",0]"..
				"style_type[button;bgcolor=#FF4444]"..
				"box[0,0;4.2,5.6;"..color.."]"..
				"item_image_button[1.0,0.2;3,3;"..
					tostring(v.buy[1])..";"..kstr..";]"..
				"item_image_button[2.0,3.4;2,2;"..
					-- the "_" at the end is necessary; we need a diffrent name
					-- here than kstr as that was used for another button (leading
					-- to the same result) just above
					tostring(v.pay[1])..";"..kstr.."_;]")
			if(sold_out) then
				table.insert(row_content, "button[0,1.0;4.3,1.0;"..kstr.."__;Sold out]"..
							"\ncontainer_end[]")
			else
				-- how often can this trade be done?
				table.insert(row_content, "label[0,0.8;Stock: "..tostring(amount_available).."x]")
				-- show the price label only when the offer is in stock
				table.insert(row_content, "label[0,1.9;->]"..
							"label[0,4.4;Price:]"..
							"\ncontainer_end[]")
			end
			col = col + 1
			if(col >= yl_speak_up.trade_max_cols) then
				col = 0
				h = yl_speak_up.show_trade_offer_row(h, i, pname_for_old_fs, formspec, row_content)
				row_content = {}
			end
		end
	end
	h = yl_speak_up.show_trade_offer_row(h, 999, pname_for_old_fs, formspec, row_content)

	-- set button background color back to golden/brownish
	table.insert(formspec, "style_type[button;bgcolor=#a37e45]")
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"show_inventory",
		"Access and manage the inventory of the NPC. This is used for adding trade "..
			"items, getting collected payments and managing quest items.",
			"Show your inventory (only accessible to owner)!",
			true, nil, nil, pname_for_old_fs)

	-- allow players with the right priv to switch view between dialog option trades
	-- and those normal ones in the trade list
	if(yl_speak_up.may_edit_npc(player, n_id)) then
		if(not(show_dialog_option_trades)) then
			local text = "This is the trade list view (player view). "..
				"Show trades attached to dialog options."
			h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
				"show_dialog_option_trades",
				text, text,
				true, nil, nil, pname_for_old_fs)
		else
			local text = "These are trades attached to dialog options. "..
				"Show trade list trades (player view)."
			h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
				"show_trade_list",
				text, text,
				true, nil, nil, pname_for_old_fs)
		end
		-- button "add trade" for those who can edit the NPC (entering edit mode is not required)
		local text = "Add a new trade."
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"trade_list_add_trade",
			text, text,
			true, nil, nil, pname_for_old_fs)
		-- show a list of how much the NPC will buy and sell
		text = minetest.formspec_escape(
			"[Limits] Do not buy or sell more than what I will tell you.")
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"trade_limit",
			text, text,
			true, nil, nil, pname_for_old_fs)
		-- button "show log" for those who can edit the NPC (entering edit mode is not required)
		text = minetest.formspec_escape(
			"[Log] Show me who bought what.")
		h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"show_log",
			text, text,
			true, nil, nil, pname_for_old_fs)
	end

	local text = "That was all. Let's continue talking."
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"finished_trading",
		text, text,
		true, nil, nil, pname_for_old_fs) -- button_exit

	-- if there are no trades, at least print a hint that there could be some here
	-- (a mostly empty formspec looks too boring and could irritate players)
	if(anz_trades == 0) then
		table.insert(formspec,
			"label[1,1;Sorry. There are currently no offers available.]")
	end

	-- edit mode makes no sense here in the trade list
	return yl_speak_up.show_fs_decorated(pname, nil, h, alternate_text, "",
                                        table.concat(formspec, "\n"), nil, h)
end


yl_speak_up.register_fs("trade_list",
	yl_speak_up.input_trade_list,
	yl_speak_up.get_fs_trade_list,
	-- no special formspec required:
	nil
)
