-- add or edit a trade limit

yl_speak_up.input_edit_trade_limit = function(player, formname, fields)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		return
	end

	-- store the new limits?
	if(fields and fields["store_limit"]) then
		if(not(fields["item_name"])
		  or fields["item_name"] == ""
		  or not(minetest.registered_items[fields["item_name"]])) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:edit_trade_limit",
				formspec = "size[6,2]"..
					"label[0.2,0.0;Unknown item. Please enter item name\n"..
						"for which to store the limit!]"..
					"button[1.5,1.5;2,0.9;back_from_msg;Back]"})
			return
		end
		local dialog = yl_speak_up.speak_to[pname].dialog

		-- make sure all necessary entries in the trades table exist
		yl_speak_up.setup_trade_limits(dialog)

		local anz = tonumber(fields['SellIfMoreThan'] or "0")
		if( anz and anz > 0 and anz < 10000 ) then
			dialog.trades.limits.sell_if_more[ fields["item_name"] ] = anz
			yl_speak_up.log_change(pname, n_id, "sell_if_more set to "..tostring(anz)..
				" for "..tostring(fields["item_name"]))
		end

		anz = tonumber(fields['BuyIfLessThan'] or "0")
		if( anz and anz > 0 and anz < 10000 ) then
			dialog.trades.limits.buy_if_less[ fields["item_name"] ] = anz
			yl_speak_up.log_change(pname, n_id, "buy_if_less set to "..tostring(anz)..
				" for "..tostring(fields["item_name"]))
		end
		-- save these values
		yl_speak_up.save_dialog(n_id, dialog)
		yl_speak_up.show_fs(player, "trade_limit", {selected = fields.item_name})
		return
	end

	if(fields and fields["delete_limit"]) then
		local dialog = yl_speak_up.speak_to[pname].dialog

		-- make sure all necessary entries in the trades table exist
		yl_speak_up.setup_trade_limits(dialog)

		dialog.trades.limits.sell_if_more[ fields["item_name"] ] = nil
		dialog.trades.limits.buy_if_less[  fields["item_name"] ] = nil

		yl_speak_up.log_change(pname, n_id, "trade limits deleted"..
				" for "..tostring(fields["item_name"]))
		yl_speak_up.save_dialog(n_id, dialog)
		yl_speak_up.show_fs(player, "trade_limit")
		return
	end

	-- back to the normal trade list
	yl_speak_up.show_fs(player, "trade_limit", {selected = fields.item_name})
end


-- edit a trade limit or add a new one
yl_speak_up.get_fs_edit_trade_limit = function(player, selected_row)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		return "You have no right to edit this NPC."
	end
	local items = yl_speak_up.speak_to[pname].trade_limit_items
	local item_list = yl_speak_up.speak_to[pname].trade_limit_item_list
	if(not(selected_row) or selected_row < 1
	  or not(items) or not(item_list)
	  or selected_row > #item_list + 1) then
		return "size[6,2]"..
			"label[0.2,0.0;Unknown item. Please select an item\n"..
					"from the list!]"..
				"button[1.5,1.5;2,0.9;back_from_msg;Back]"
	end
	local selected = item_list[ selected_row - 1]
	local item_data = items[ selected ]
	-- items is a table (list) with these entries:
	--   [1] 0 in stock;
	--   [2] sell if more than 0;
	--   [3] buy if less than 10000;
	--   [4] item is part of a trade offer
	local def = minetest.registered_items[ selected ]
	if(not(def)) then
		def = {description = '- unknown item -'}
	end

	local formspec = {'size[8,7]',
		'item_image[-0.25,2.5;2.0,2.0;', selected, ']',
		'label[1.0,0.0;Set limits for buy and sell]',
		'label[1.5,1.0;Description:]',
			'label[4.0,1.0;', minetest.formspec_escape(def.description or '?'), ']',
		'label[1.5,2.0;Item name:]',
			--'label[3.5,1.0;', tostring( selected ), ']',
			'field[4.0,2.0;4,1;item_name;;', minetest.formspec_escape( selected ), ']',
		'label[1.5,3.0;In stock:]',
			'label[4.0,3.0;', tostring( item_data[1] ), ']',
		'label[1.5,4.0;Sell if more than]',
			'field[4.0,4.0;1.2,1.0;SellIfMoreThan;;', tostring( item_data[2] ), ']',
				'label[5.0,4.0;will remain in stock.]',
		'label[1.5,5.0;Buy if less than]',
			'field[4.0,5.0;1.2,1.0;BuyIfLessThan;;', tostring( item_data[3] ), ']',
				'label[5.0,5.0;will end up in stock.]',
		'button[1.0,6.0;2,1.0;store_limit;Save]',
		'button[3.5,6.0;2,1.0;back_to_limit_list;Back]',
		'button[6.0,6.0;2,1.0;delete_limit;Delete]'
		}
	return table.concat(formspec, '')
end


yl_speak_up.get_fs_edit_trade_limit = function(player, param)
	if(not(param)) then
		param = {}
	end
	return yl_speak_up.get_fs_edit_trade_limit(player, param.selected_row)
end


yl_speak_up.register_fs("edit_trade_limit",
	yl_speak_up.input_edit_trade_limit,
	yl_speak_up.get_fs_edit_trade_limit_wrapper,
	-- force formspec version 1:
	1
)
