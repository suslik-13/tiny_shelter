-- when closing the yl_speak_up.get_fs_add_trade_simple formspec:
--   give the items back to the player (he took them from his inventory and
--   had no real chance to put them elsewhere - so there really ought to be
--   room enough)
yl_speak_up.add_trade_simple_return_items = function(player, trade_inv, pay, buy)
	local player_inv = player:get_inventory()
	if( pay and player_inv:room_for_item("main", pay)) then
		player_inv:add_item("main", pay)
		trade_inv:set_stack("setup", 1, "")
	end
	if( buy and player_inv:room_for_item("main", buy)) then
		player_inv:add_item("main", buy)
		trade_inv:set_stack("setup", 2, "")
	end
end



-- simple trade: add a new trade or edit existing one (by storing a new one);
-- set trade_id to "new" if it shall be a new trade added to the trade list;
-- set trade_id to "<d_id> <o_id>" if it shall be a result/effect of a dialog option;
yl_speak_up.get_fs_add_trade_simple = function(player, trade_id)
	if(not(player)) then
		return yl_speak_up.trade_fail_fs
	end
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	local dialog = yl_speak_up.speak_to[pname].dialog

	-- is this player allowed to edit the NPC and his trades? If not abort.
	if(not(yl_speak_up.may_edit_npc(player, n_id)) or not(dialog) or not(dialog.n_npc)) then
		return "size[9,2]"..
			"label[2.0,1.8;Ups! Something went wrong.]"..
			"button[6.2,1.6;2.0,0.9;abort_trade_simple;Back]"
	end

	-- store the trade_id (so that it doesn't have to be transfered in a hidden field)
	yl_speak_up.speak_to[pname].trade_id = trade_id

	local delete_button =
		"button[0.2,2.6;1.0,0.9;delete_trade_simple;Delete]"..
		"tooltip[delete_trade_simple;Delete this trade.]"
	-- no point in deleting a new trade - it doesn't exist yet
	if(trade_id and trade_id == "new") then
		delete_button = ""
	end
	return table.concat({"size[8.5,9]",
		"label[4.35,0.8;",
			minetest.formspec_escape(dialog.n_npc),
			" sells:]",
		"list[current_player;main;0.2,4.85;8,1;]",
		"list[current_player;main;0.2,6.08;8,3;8]",
		-- show the second slot of the setup inventory in the detached player's inv
		"list[detached:yl_speak_up_player_",
			pname,
			";setup;2,1.5;1,1;]",
		-- show the second slot of said inventory
		"list[detached:yl_speak_up_player_",
			pname,
			";setup;5,1.5;1,1;1]",
		"label[0.5,0.0;Configure trade with ",
			minetest.formspec_escape(dialog.n_npc),
			":]",
		"label[1.5,0.8;The customer pays:]",
		"label[1.5,3.8;Put items in the two slots and click on \"Store trade\".]",
		"label[1.5,4.2;You will get your items back when storing the trade.]",
		-- annoyingly, the height value no longer works :-(
		"label[0.2,2.5;Item\nname:]",
		"field[1.5,3.2;3,0.2;item_name_price;;]",
		"label[4.35,2.5;If you don't have the item you\n",
				"want to buy, then enter its item\n",
				"name (i.e. default:diamond) here.]",
		"button[0.2,1.6;1.0,0.9;abort_trade_simple;Abort]",
		delete_button,
		"button[6.2,1.6;2.0,0.9;store_trade_simple;Store trade]",
		"tooltip[store_trade_simple;Click here to store this as a new trade. Your\n",
		                           "items will be returned to you and the trade will\n",
					   "will be shown the way the customer can see it.]",
		"tooltip[abort_trade_simple;Abort setting up this new trade.]"
		}, "")
end

-- the player wants to add a simple trade; handle formspec input
-- possible inputs:
--    fields.back_from_error_msg       show this formspec here again
--    fields.store_trade_simple        store this trade as a result and
--                                     go on to showing the do_trade_simple formspec
--    fields.delete_trade_simple       delete this trade
--                                     go back to edit options dialog
--    abort_trade_simple, ESC          go back to edit options dialog
-- The rest is inventory item movement.
yl_speak_up.input_add_trade_simple = function(player, formname, fields, input_to)
	if(not(player)) then
		return 0
	end
	local pname = player:get_player_name()

	if(not(input_to)) then
		input_to = "add_trade_simple"
	end

	-- we return from showing an error message (the player may not have noticed
	-- a chat message while viewing a formspec; thus, we showed a formspec message)
	if(fields.back_from_error_msg) then
		yl_speak_up.show_fs(player, input_to)
		return
	end

	-- which trade are we talking about?
	local trade_id = yl_speak_up.speak_to[pname].trade_id

	-- this also contains the inventory list "setup" where the player placed the items
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})

	-- fields.abort_trade_simple can be ignored as it is similar to ESC

	local pay = trade_inv:get_stack("setup", 1)
	local buy = trade_inv:get_stack("setup", 2)

	-- clicking on abort here when adding a new trade via the trade list
	-- goes back to the trade list (does not require special privs)
	if(fields.abort_trade_simple and trade_id == "new") then
		-- we are no longer doing a particular trade
		yl_speak_up.speak_to[pname].trade_id = nil
		-- return the items (setting up the trade was aborted)
		yl_speak_up.add_trade_simple_return_items(player, trade_inv, pay, buy)
		-- ..else go back to the edit options formspec
		yl_speak_up.show_fs(player, "trade_list")
		return
	end
	-- adding a new trade via the trade list?
	if(not(trade_id) and fields.store_trade_simple) then
		trade_id = "new"
	end

	local n_id = yl_speak_up.speak_to[pname].n_id
	local d_id = yl_speak_up.speak_to[pname].d_id
	local o_id = yl_speak_up.speak_to[pname].o_id

	-- the trade can only be changed in edit mode
	if((input_to == "add_trade_simple")
	-- exception: when adding a new trade via the trade list
	-- (that is allowed without having to be in edit mode)
	  and not(trade_id == "new" and yl_speak_up.may_edit_npc(player, n_id))) then
		-- return the items (setting up the trade was aborted)
		yl_speak_up.add_trade_simple_return_items(player, trade_inv, pay, buy)
		return
	end

	-- store the new trade
	if(fields.store_trade_simple) then
		local error_msg = ""
		local simulated_pay = false
		if(pay:is_empty() and fields.item_name_price and fields.item_name_price ~= "") then
			pay = ItemStack(fields.item_name_price)
			simulated_pay = true
		end
		-- check for error conditions
		if(pay:is_empty()) then
			error_msg = "What shall the customer pay?\nWe don't give away stuff for free here!"
		elseif(buy:is_empty()) then
			error_msg = "What shall your NPC sell?\nCustomers won't pay for nothing!"
		elseif(pay:get_wear() > 0 or buy:get_wear() > 0) then
			error_msg = "Selling used items is not possible."
		elseif(not(minetest.registered_items[ pay:get_name() ])
		    or not(minetest.registered_items[ buy:get_name() ])) then
			error_msg = "Unkown items cannot be traded."
		elseif(pay:get_name() == buy:get_name()) then
			error_msg = "Selling *and* buying the same item\nat the same time makes no sense."
		else
			-- get the necessary dialog data
			local dialog = yl_speak_up.speak_to[pname].dialog
			-- player_gives (pay stack):
			local ps = pay:get_name().." "..tostring(pay:get_count())
			-- npc_gives (buy stack):
			local bs = buy:get_name().." "..tostring(buy:get_count())
			local r_id = "?"

			if(not(dialog.trades)) then
				dialog.trades = {}
			end
			-- is this a trade attached to the trade list?
			-- or do we have to create a new trade ID?
			if(trade_id == "new") then
				-- if the player adds the same trade again, the ID is reused; other
				-- than that, the ID is uniq
				-- (the ID is formed so that we can later easily sort the offers by
				--  the name of the buy stack - which is more helpful for the player
				--  than sorting by the pay stack)
				trade_id = "sell "..bs.." for "..ps
				-- log the change
				yl_speak_up.log_change(pname, n_id,
					"Trade: Added offer "..tostring(trade_id)..".")
				-- add this new trade
				dialog.trades[ trade_id ] = {pay={ps},buy={bs}}
				-- actually save the dialog to disk
				yl_speak_up.save_dialog(n_id, dialog)
				-- store the newly created trade_id
				yl_speak_up.speak_to[pname].trade_id = trade_id
				-- all ok so far
				error_msg = nil
			-- storing trades that are associated with particular dialogs and options
			-- requires d_id and o_id to be set
			elseif(trade_id ~= "new" and (not(d_id) or not(o_id))) then
				error_msg = "Internal error. o_id was not set."
			else
				-- would be too complicated to handle exceptions; this is for edit_mode:
				if(yl_speak_up.npc_was_changed
				  and yl_speak_up.npc_was_changed[n_id]) then
					-- record this as a change, but do not save do disk yet
					table.insert(yl_speak_up.npc_was_changed[ n_id ],
						"Dialog "..d_id..": Trade "..tostring(trade_id)..
							" added to option "..tostring(o_id)..".")
				end
				-- add this new trade - complete with information to which dialog and
				-- to which option the trade belongs
				dialog.trades[ trade_id ] = {pay={ps},buy={bs}, d_id = d_id, o_id = o_id}
				-- all ok so far
				error_msg = nil
			end
			-- do not return yet - the items still need to be given back!
		end
		-- make sure we don't create items here out of thin air
		if(simulated_pay) then
			pay = ItemStack("")
		end
		-- show error message (that leads back to this formspec)
		if(error_msg) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:"..input_to,
				formspec =
					"size[6,2]"..
					"label[0.2,0.5;"..error_msg.."]"..
					"button[2,1.5;1,0.9;back_from_error_msg;Back]"})
			return
		end

	-- we need a way of deleting trades as well;
	-- this affects only trades that are associated with dialogs and options;
	-- trades from the trade list are deleted more directly
	elseif(fields.delete_trade_simple) then
		-- delete this result (if it exists)
		-- get the necessary dialog data
		local dialog = yl_speak_up.speak_to[pname].dialog
		-- would be too complicated to handle exceptions; this is for edit_mode:
		if(yl_speak_up.npc_was_changed
		  and yl_speak_up.npc_was_changed[n_id]) then
			-- record this as a change
			table.insert(yl_speak_up.npc_was_changed[ n_id ],
				"Dialog "..d_id..": Trade "..tostring(trade_id)..
					" deleted from option "..tostring(o_id)..".")
		end
		if(not(dialog.trades)) then
			dialog.trades = {}
		end
		-- delete the trade type result
		if(trade_id) then
			dialog.trades[ trade_id ] = nil
		end
		-- do not return yet - the items still need to be given back!
	end

	-- return the items after successful setup
	yl_speak_up.add_trade_simple_return_items(player, trade_inv, pay, buy)

	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(dialog.trades)) then
		dialog.trades = {}
	end
	if(dialog.trades[ trade_id ] and dialog.trades[ trade_id ].d_id
	  and input_to == "add_trade_simple") then
		yl_speak_up.speak_to[pname].trade_id = trade_id
		-- tell the player that the new trade has been added
		yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:do_trade_simple",
				formspec =
					"size[6,2]"..
					"label[0.2,0.5;The new trade has been configured successfully.]"..
					"button[1.5,1.5;2,0.9;trade_simple_stored;Show trade]"})
	-- return back to trade list
	elseif(not(o_id)) then
		-- we are no longer trading
		yl_speak_up.speak_to[pname].trade_id = nil
		-- ..else go back to the edit options formspec
		yl_speak_up.show_fs(player, "trade_list")
	else
		-- we are no longer trading
		yl_speak_up.speak_to[pname].trade_id = nil
		-- the trade has been stored or deleted successfully
		return true
--		-- ..else go back to the edit options formspec (obsolete)
--		yl_speak_up.show_fs(player, "edit_option_dialog",
--			{n_id = n_id, d_id = d_id, o_id = o_id})
	end
end


yl_speak_up.get_fs_add_trade_simple_wrapper = function(player, param)
	local pname = player:get_player_name()
	-- the optional parameter param is the trade_id
	if(not(param) and yl_speak_up.speak_to[pname]) then
		param = yl_speak_up.speak_to[pname].trade_id
	end
	return yl_speak_up.get_fs_add_trade_simple(player, param)
end


yl_speak_up.register_fs("add_trade_simple",
	yl_speak_up.input_add_trade_simple,
	yl_speak_up.get_fs_add_trade_simple_wrapper,
	-- force formspec version 1:
	1
)
