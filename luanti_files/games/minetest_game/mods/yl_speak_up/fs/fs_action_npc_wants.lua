yl_speak_up.input_fs_action_npc_wants = function(player, formname, fields)
	-- back from error_msg? then show the formspec again
	if(fields.back_from_error_msg) then
		yl_speak_up.show_fs(player, "action_npc_wants", nil)
		return
	end
	local pname = player:get_player_name()
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return
	end
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	local a_id = yl_speak_up.speak_to[pname].a_id
	-- is the npc_wants inv empty and the player pressed the back to talk button? then the action failed.
	if(trade_inv:is_empty("npc_wants") and fields.back_to_talk) then
		-- the action was aborted
		yl_speak_up.execute_next_action(player, a_id, nil, formname)
		return
	end
	-- the player tried to give something; check if it is the right thing
	if(not(trade_inv:is_empty("npc_wants"))) then
		local stack = trade_inv:get_stack("npc_wants", 1)
		-- check if it really is the item the NPC wanted; let the NPC take it
		local is_correct_item = yl_speak_up.action_quest_item_take_back(player)
		-- the action may have been a success or failure
		yl_speak_up.execute_next_action(player, a_id, is_correct_item, formname)
		return
	end
	-- else show a message to the player
	yl_speak_up.show_fs(player, "msg", {
		input_to = "yl_speak_up:action_npc_wants",
		formspec = "size[7,1.5]"..
			"label[0.2,-0.2;"..
				"Please insert the item for the npc and click on \"Done\"!\n"..
				"If you don't have what he wants, click on \"Back to talk\".]"..
				"button[2,1.0;1.5,0.9;back_from_error_msg;Back]"})
end

yl_speak_up.get_fs_action_npc_wants = function(player, param)
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	return table.concat({"size[8.5,8]",
		"list[current_player;main;0.2,3.85;8,1;]",
		"list[current_player;main;0.2,5.08;8,3;8]",
		"button[0.2,0.0;2.0,0.9;back_to_talk;Back to talk]",
		"button[4.75,1.6;1.5,0.9;finished_action;Done]",

		"tooltip[back_to_talk;Click here if you don't know what item the\n",
			"NPC wants or don't have the desired item.]",
		"tooltip[finished_action;Click here once you have placed the item in\n",
			"the waiting slot.]",
		"label[1.5,0.7;",
			minetest.formspec_escape(dialog.n_npc or "- ? -"),
			" expects something from you:]",
		"list[detached:yl_speak_up_player_",
			pname,
			";npc_wants;3.25,1.5;1,1;]",
		"label[1.5,2.7;Insert the right item and click on \"Done\" to proceed.]"
		}, "")
end


yl_speak_up.register_fs("action_npc_wants",
	yl_speak_up.input_fs_action_npc_wants,
	yl_speak_up.get_fs_action_npc_wants,
	-- force formspec version 1 for this:
	1
)
