
-- show the diffrent action-related formspecs and handle input to them
-- (Note: trade is handled in trade_simple.lua)

yl_speak_up.input_fs_action_npc_gives = function(player, formname, fields)
	-- back from error_msg? then show the formspec again
	if(fields.back_from_error_msg) then
		-- do not create a new item
		yl_speak_up.show_fs(player, "action_npc_gives", nil)
		return
	end
	local pname = player:get_player_name()
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	if(not(yl_speak_up.speak_to[pname])) then
		return
	end
	local a_id = yl_speak_up.speak_to[pname].a_id
	if(fields.npc_does_not_have_item) then
		-- the NPC can't supply the item - abort the action
		yl_speak_up.execute_next_action(player, a_id, nil, formname)
		return
	end
	-- is the npc_gives inv empty? then all went as expected.
	-- (it does not really matter which button the player pressed in this case)
	if(trade_inv:is_empty("npc_gives")) then
		-- the NPC has given the item to the player; save the NPCs inventory
		local n_id = yl_speak_up.speak_to[pname].n_id
		yl_speak_up.save_npc_inventory(n_id)
		-- the action was a success; the NPC managed to give the item to the player
		yl_speak_up.execute_next_action(player, a_id, true, formname)
		return
	end
	-- the npc_gives slot does not accept input - so we don't have to check for any misplaced items
	-- but if the player aborts, give the item back to the NPC
	if(fields.back_to_talk) then
		-- actually take the item back into the NPC's inventory
		local n_id = yl_speak_up.speak_to[pname].n_id
		local npc_inv = minetest.get_inventory({type="detached", name="yl_speak_up_npc_"..tostring(n_id)})
		yl_speak_up.action_take_back_failed_npc_gives(trade_inv, npc_inv)
		-- strip the quest item info from the stack (so that it may stack again)
		-- and give that (hopefully) stackable stack back to the NPC
		yl_speak_up.action_quest_item_take_back(player)
		-- the action failed
		yl_speak_up.execute_next_action(player, a_id, nil, formname)
		return
	end
	-- else show a message to the player that he ought to take the item
	yl_speak_up.show_fs(player, "msg", {
		input_to = "yl_speak_up:action_npc_gives",
		formspec = "size[7,1.5]"..
			"label[0.2,-0.2;"..
				"Please take the offered item and click on \"Done\"!\n"..
				"If you can't take it, click on \"Back to talk\".]"..
				"button[2,1.0;1.5,0.9;back_from_error_msg;Back]"})
end


yl_speak_up.get_fs_action_npc_gives = function(player, param)
	-- called for the first time; create the item the NPC wants to give
	if(param) then
		if(not(yl_speak_up.action_quest_item_prepare(player))) then
			local pname = player:get_player_name()
			local dialog = yl_speak_up.speak_to[pname].dialog
			-- it's not the fault of the player that the NPC doesn't have the item;
			-- so tell him that (the action will still fail)
			return table.concat({"size[7,2.0]"..
				"label[0.2,-0.2;",
					minetest.formspec_escape(dialog.n_npc or "- ? -"),
					" is very sorry:\n"..
					"The item intended for you is currently unavailable.\n"..
					"Please come back later!]"..
					"button[2,1.5;1.5,0.9;npc_does_not_have_item;Back]"}, "")
		end
	end
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	return table.concat({"size[8.5,8]",
		"list[current_player;main;0.2,3.85;8,1;]",
		"list[current_player;main;0.2,5.08;8,3;8]",
		"button[0.2,0.0;2.0,0.9;back_to_talk;Back to talk]",
		"button[4.75,1.6;1.5,0.9;finished_action;Done]",

		"tooltip[back_to_talk;Click here if you don't want to (or can't)\n",
			"take the offered item.]",
		"tooltip[finished_action;Click here once you have taken the item and\n",
			"stored it in your inventory.]",
		"label[1.5,0.7;",
			minetest.formspec_escape(dialog.n_npc or "- ? -"),
			" offers to you:]",
		-- unlike the npc_gives slot - which is used for setting up the NPC - the
		-- npc_gives slot does not allow putting something in
		"list[detached:yl_speak_up_player_"..pname..";npc_gives;3.25,1.5;1,1;]" ,
		"label[1.5,2.7;Take the offered item and click on \"Done\" to proceed.]"
		}, "")
end


yl_speak_up.register_fs("action_npc_gives",
	yl_speak_up.input_fs_action_npc_gives,
	yl_speak_up.get_fs_action_npc_gives,
	-- force formspec version 1 for this:
	1
)
