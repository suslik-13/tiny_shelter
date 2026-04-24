-- handle input to the formspec
yl_speak_up.input_trade_limit = function(player, formname, fields)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		return
	end
	-- the player has selected an entry - edit it
	if(fields and fields["edit_trade_limit"]) then
		local selection = minetest.explode_table_event( fields[ "edit_trade_limit" ])
		if( selection and selection['row']
		  and (selection['type'] == 'DCL' or selection['type'] == 'CHG')) then
			-- show edit trade limit formspec
			yl_speak_up.show_fs(player, "edit_trade_limit", {selected_row = selection['row']})
			return
		end
	end

	if(fields and (fields.back or fields.quit)) then
		-- back to the normal trade list
		yl_speak_up.show_fs(player, "trade_list")
		return
	end

	-- else show this formspec again
	yl_speak_up.show_fs(player, "trade_limit")
end


-- show the formspec
yl_speak_up.get_fs_trade_limit = function(player, selected)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	-- in items, existing amount and limit are collected for display
	local items = {}

	if(not(dialog) or not(n_id)) then
		return "Error. Missing dialog when accessing trade limits."
	end
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		return "Error. You have no right to edit this NPC."
	end
	-- the player has selected an entry - edit it
	-- make sure all necessary entries in the trades table exist
	yl_speak_up.setup_trade_limits(dialog)

	-- how many items does the NPC have alltogether?
	-- there may be more than one stack of the same type; store amount
	local counted_inv = yl_speak_up.count_npc_inv(n_id)
	for k,v in pairs(counted_inv) do
		yl_speak_up.insert_trade_item_limitation(items, k, 1, v)
	end

	-- items that are part of any of the trades may also be subject to limits; store item names
	for trade_id, trade_data in ipairs(dialog.trades) do
		if(trade_id ~= "limits") then
			-- what the NPC sells may be subject to limits
			local stack = ItemStack(trade_data.buy[1])
			yl_speak_up.insert_trade_item_limitation(items, stack:get_name(), 4, true )
			-- what the customer pays may be subject to limits as well
			stack = ItemStack(trade_data.pay[1])
			yl_speak_up.insert_trade_item_limitation(items, stack:get_name(), 4, true )
		end
	end

	-- everything for which there's already a sell_if_more limit
	for k,v in pairs(dialog.trades.limits.sell_if_more) do
		yl_speak_up.insert_trade_item_limitation( items, k, 2, v )
	end

	-- everything for which there's already a buy_if_less limit
	for k,v in pairs(dialog.trades.limits.buy_if_less ) do
		yl_speak_up.insert_trade_item_limitation( items, k, 3, v )
	end
	
	-- all items for which limitations might possibly be needed have been collected;
	-- now display them
	local formspec = {'size[18,12]',
			'button[0.5,11.1;17,0.8;back;Back]',
			'label[7.0,0.5;List of trade limits]',
			'label[0.5,1.0;If you do not set any limits, your NPC will buy and sell as many '..
				'items as his inventory allows.\n',
				'If you set \'Will sell if more than this\', your NPC '..
					'will only sell if he will have enough left after the trade,\n',
				'and if you set \'Will buy if less than this\', he will '..
					'only buy items as long as he will not end up with more than '..
					'this.]',
			'tablecolumns[',
			      'text,align=left;',
			'color;text,align=right;',
			'color;text,align=center;',
			      'text,align=right;',
			'color;text,align=center;',
			      'text,align=right;',
			'color;text,align=left]',
                        'table[0.1,2.3;17.8,8.5;edit_trade_limit;',
			'Description:,',
			'#FFFFFF,NPC has:,',
			'#FFFFFF,Will sell if more than this:,,',
			'#FFFFFF,Will buy if less than this:,,',
			'#EEEEEE,Item string:,'
			}
	
	-- the table event selection returns a row index - we need to translate that to our table
	local item_list = {}
	for k,v in pairs( items ) do
		table.insert(item_list, k)
	end
	-- avoid total chaos by sorting this list
	table.sort(item_list)
	local row = 2
	for i, k in ipairs( item_list ) do
		local v = items[k]
		local c1 = '#FF0000'
		if( v[1] > 0 ) then
			c1 = '#BBBBBB'
		end
		local t1 = 'sell always'
		local c2 = '#44EE44'
		if( v[2] > 0 ) then
			c2 = '#00FF00'
			t1 = 'sell if more than:'
		end
		local t2 = 'buy always'
		local c3 = '#EEEE44'
		if( v[3] ~= 10000 ) then
			c3 = '#FFFF00'
			t2 = 'buy if less than:'
		end

		local desc = ''
		if( k =="" ) then
			desc = '<free inventory slot>'
			k    = '<nothing>'
		elseif( minetest.registered_items[ k ] 
		    and minetest.registered_items[ k ].description ) then
			desc = minetest.registered_items[ k ].description
		end

		table.insert(formspec,
			desc..','..
			c1..','..         tostring( v[1] )..','..
			c2..','..t1..','..tostring( v[2] )..','..
			c3..','..t2..','..tostring( v[3] )..',#EEEEEE,'..k..',')
	end
	-- we need to store the table somewhere so that we know which limit is edited
	yl_speak_up.speak_to[pname].trade_limit_items = items
	yl_speak_up.speak_to[pname].trade_limit_item_list = item_list

	local selected_row = 1
	if(selected and selected ~= "") then
		selected_row = math.max(1, table.indexof(item_list, selected) + 1)
	end
	table.insert(formspec, ";"..selected_row.."]")
	return table.concat(formspec, '')
end


yl_speak_up.get_fs_trade_limit_wrapper = function(player, param)
	if(not(param)) then
		param = {}
	end
	return yl_speak_up.get_fs_trade_limit(player, param.selected)
end


yl_speak_up.register_fs("trade_limit",
	yl_speak_up.input_trade_limit,
	yl_speak_up.get_fs_trade_limit_wrapper,
	-- no special formspec required:
	nil
)
