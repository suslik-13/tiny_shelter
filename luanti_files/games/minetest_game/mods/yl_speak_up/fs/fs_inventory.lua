
-- the player has closed the inventory formspec of the NPC - save it
yl_speak_up.input_inventory = function(player, formname, fields)
        local pname = player:get_player_name()
	local d_id = yl_speak_up.speak_to[pname].d_id
	local n_id = yl_speak_up.speak_to[pname].n_id
	-- after closing the inventory formspec:
	-- ..save the (very probably) modified inventory
	yl_speak_up.save_npc_inventory(n_id)
	-- show inventory again?
	if(fields.back_from_error_msg) then
		yl_speak_up.show_fs(player, "inventory")
		return
	end
	-- show the trade list?
	if(fields.inventory_show_tradelist) then
		yl_speak_up.show_fs(player, "trade_list")
		return
	end
	-- ..and go back to the normal talk formspec
	yl_speak_up.show_fs(player, "talk", {n_id = n_id, d_id = d_id})
end


-- access the inventory of the NPC (only possible for players with the right priv)
yl_speak_up.get_fs_inventory = function(player)
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

	-- only players which can edit this npc can see its inventory
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		return "size[6,2]"..
			"label[0.2,0.5;Sorry. You lack the privileges.]"..
		                "button_exit[2,1.5;1,0.9;exit;Exit]"
	end

	-- make sure the inventory of the NPC is loaded
	yl_speak_up.load_npc_inventory(n_id, true, nil)

	return table.concat({"size[12,11]",
		"label[2,-0.2;Inventory of ",
			minetest.formspec_escape(dialog.n_npc),
			" (ID: ",
			tostring(n_id),
			"):]",
		"list[detached:yl_speak_up_npc_",
			tostring(n_id),
			";npc_main;0,0.3;12,6;]",
		"list[current_player;main;2,7.05;8,1;]",
		"list[current_player;main;2,8.28;8,3;8]",
		"listring[detached:yl_speak_up_npc_",
			tostring(n_id),
			";npc_main]",
		"listring[current_player;main]",
		"button[3.5,6.35;5,0.6;inventory_show_tradelist;Show trade list trades (player view)]",
		"button[10.0,10.4;2,0.9;back_from_inventory;Back]"
		}, "")
end


yl_speak_up.register_fs("inventory",
	yl_speak_up.input_inventory,
	yl_speak_up.get_fs_inventory,
	-- this is a very classical formspec; it works far better with OLD fs;
	-- force formspec version 1:
	1
)
