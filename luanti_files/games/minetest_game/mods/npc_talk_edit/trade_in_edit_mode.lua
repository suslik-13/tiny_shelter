-- overrides for api/api_trade_inv.lua:

-- the player *can* place something into the npc_gives inventory list in edit_mode:
local old_trade_inv_allow_put = yl_speak_up.trade_inv_allow_put
yl_speak_up.trade_inv_allow_put = function(inv, listname, index, stack, player)
	if(not(player)) then
		return 0
	end
	-- allow putting something in in edit mode - but not otherwise
	if(listname and listname == "npc_gives") then
		local pname = player:get_player_name()
		local n_id = yl_speak_up.speak_to[pname].n_id
		-- only in edit mode! else the NPC manages this slot
		if(n_id and yl_speak_up.in_edit_mode(pname)) then
			return stack:get_count()
		end
	end
	return old_trade_inv_allow_put(inv, listname, index, stack, player)
end


-- prevent do_trade_simple from executing trade and reporting successful action:
local old_do_trade_simple = yl_speak_up.do_trade_simple
yl_speak_up.do_trade_simple = function(player, count)
	if(not(player)) then
		return
	end

	local pname = player:get_player_name()
	-- which trade are we talking about?
	local trade = yl_speak_up.trade[pname]

	if(trade.n_id and yl_speak_up.edit_mode[pname] == trade.n_id) then
		-- instruct old_do_trade_simple to neither execute the trade nor see this
		-- as an action that was executed
		trade.dry_run_no_exec = true
	end
	return old_do_trade_simple(player, count)
end



-- overrides for api/api_trade.lua:

-- do not allow deleting trades that are actions of an option if not in edit mode:
local old_delete_trade_simple = yl_speak_up.delete_trade_simple
yl_speak_up.delete_trade_simple = function(player, trade_id)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	-- get the necessary dialog data
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(dialog and dialog.trades and trade_id
	  and dialog.trades[ trade_id ] and n_id) then

		if( dialog.trades[ trade_id ].d_id
		  and yl_speak_up.edit_mode[pname] ~= n_id) then
			yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:do_trade_simple",
				formspec = "size[6,2]"..
					"label[0.2,-0.2;"..
						"Trades that are attached to dialog options\n"..
						"can only be deleted in edit mode. Please tell\n"..
						"your NPC that you are its owner and have\n"..
						"new commands!]"..
					"button[2,1.5;1,0.9;back_from_error_msg;Back]"})
			return
		end
	end
	return old_delete_trade_simple(player, trade_id)
end
