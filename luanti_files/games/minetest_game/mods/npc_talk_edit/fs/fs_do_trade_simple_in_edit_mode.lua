-- spimple trading: one item(stack) for another item(stack)
-- (in edit_mode it's a bit diffrent)


-- if in edit mode: go back to the edit_options dialog
local old_input_do_trade_simple = yl_speak_up.input_do_trade_simple
yl_speak_up.input_do_trade_simple = function(player, formname, fields)
	if(not(player)) then
		return 0
	end
	local pname = player:get_player_name()

	-- which trade are we talking about?
	local trade = yl_speak_up.trade[pname]


	local n_id = yl_speak_up.speak_to[pname].n_id
	-- if in edit mode: go back to the edit options dialog
	if(fields.back_to_edit_options
	  and n_id and yl_speak_up.in_edit_mode(pname)) then
		local dialog = yl_speak_up.speak_to[pname].dialog
		local tr = dialog.trades[ trade.trade_id ]
		if(tr) then
			-- done trading
			yl_speak_up.speak_to[pname].target_d_id = nil
			yl_speak_up.speak_to[pname].trade_id = nil
			-- go to the edit options dialog
			yl_speak_up.show_fs(player, "edit_option_dialog",
				{n_id = n_id, d_id = tr.d_id, o_id = tr.o_id})
			return
		end
	end


	-- can the player edit this trade?
	if(fields.edit_trade_simple
	  and n_id and yl_speak_up.in_edit_mode(pname)) then
		-- force edit mode for this trade
		trade.edit_trade = true
		yl_speak_up.trade[pname] = trade
	end

	return old_input_do_trade_simple(player, formname, fields)
end


yl_speak_up.register_fs("do_trade_simple",
	-- new version implemented here:
	yl_speak_up.input_do_trade_simple,
	-- this is just the old function:
	yl_speak_up.get_fs_do_trade_simple_wrapper,
	-- force formspec version 1:
	1
)
