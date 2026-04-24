-- the player wants to give an item (not a specific one; just any item) to the NPC
yl_speak_up.get_fs_player_offers_item = function(player, param)
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	return table.concat({yl_speak_up.show_fs_simple_deco(8.5, 8),
		"list[current_player;main;0.2,3.85;8,1;]",
		"list[current_player;main;0.2,5.08;8,3;8]",
		"button[0.2,0.0;2.0,0.9;back_to_talk;Back to talk]",
		"button[4.75,1.6;1.5,0.9;finished_action;Give]",

		"tooltip[back_to_talk;Click here if you're finished with giving\n"..
			"items to the NPC.]",
		"tooltip[finished_action;Click here once you have placed the item in\n"..
			"the waiting slot.]",
		"label[1.5,0.7;What do you want to give to ",
			minetest.formspec_escape(dialog.n_npc or "- ? -"), "?]",
		-- the npc_wants inventory slot can be used here as well
		"list[detached:yl_speak_up_player_", pname, ";npc_wants;3.25,1.5;1,1;]",
		"label[1.5,2.7;Insert the item here and click on \"Give\" to proceed.]"
		}, "")
end


yl_speak_up.input_player_offers_item = function(player, formname, fields)
	-- back from error_msg? then show the formspec again
	if(fields.back_from_error_msg) then
		yl_speak_up.show_fs(player, "player_offers_item", nil)
		return
	end
	local pname = player:get_player_name()
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	if(fields.quit) then
		-- return the items
		local player_inv = player:get_inventory()
		local stack = trade_inv:get_stack("npc_wants", 1)
		if( trade_inv and player_inv:room_for_item("main", stack)) then
			player_inv:add_item("main", stack)
			trade_inv:set_stack("npc_wants", 1, "")
		end
		-- sometimes players are desperate and just want to leave - allow them to do so
		yl_speak_up.stop_talking(pname)
		return
	end
	local error_msg = "Please insert the item for the npc and click on \"Give\"!\n"..
			  "If you don't want to give anything, click on \"Back to talk\".]"
	-- is the npc_wants inv empty and the player pressed the back to talk button?
	if(trade_inv:is_empty("npc_wants") and fields.back_to_talk) then
		local n_id = yl_speak_up.speak_to[pname].n_id
		local show_dialog = yl_speak_up.speak_to[pname].d_id
		-- show the start dialog again
		yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = show_dialog})
		return
	elseif(fields.back_to_talk) then
		error_msg = "Please take your item back first!"
		-- reset the dialog (the accepting of items happens in the very first dialog)
		yl_speak_up.speak_to[pname].d_id = nil
	-- so far so good: -- the player tried to give something;
	-- go to the dialog where all given items are checked
	elseif(not(trade_inv:is_empty("npc_wants"))) then
		local n_id = yl_speak_up.speak_to[pname].n_id
		yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = "d_got_item"})
		return
	end
	-- show a message to the player
	yl_speak_up.show_fs(player, "msg", {
		input_to = "yl_speak_up:player_offers_item",
		formspec = table.concat({yl_speak_up.show_fs_simple_deco(8, 2.5),
			"label[0.5,0.5;",
			error_msg, "]"..
			"button[3.5,1.5;1.5,1.0;back_from_error_msg;Back]"}, ""),
			""})
end


yl_speak_up.register_fs("player_offers_item",
	yl_speak_up.input_player_offers_item,
	yl_speak_up.get_fs_player_offers_item,
	-- force formspec version 1:
	1
)
