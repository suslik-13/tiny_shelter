-----------------------------------------------------------------------------
-- This file is for calling all the necessary minetest.register_* functions.
-----------------------------------------------------------------------------
-- These functions shall be called only *once* after the server is started
-- and the mod is loaded.
-- Other files may be reloaded on the fly - but better not this one.
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- the privs: players need some privs
-----------------------------------------------------------------------------
--	npc_talk_owner is required to set up an NPC;
--	npc_talk_master allows to edit NPC of other players;
--	npc_master allows to set dangerous commands like execute lua code

local npc_master_priv_definition = {
    description="Can use the staffs to command NPCs",
    give_to_singleplayer = false,
    give_to_admin = true,
}
minetest.register_privilege("npc_master", npc_master_priv_definition)


local npc_talk_owner_priv_definition = {
    description="Can edit the dialogs of his/her own NPCs",
    give_to_singleplayer = false,
    give_to_admin = true,
}
minetest.register_privilege("npc_talk_owner", npc_talk_owner_priv_definition)


local npc_talk_master_priv_definition = {
    description="Can edit the dialogs of NPCs independent of owner",
    give_to_singleplayer = false,
    give_to_admin = true,
}
minetest.register_privilege("npc_talk_master", npc_talk_master_priv_definition)


local npc_talk_admin_priv_definition = {
    description="Can do maintenance of NPCs (adding generic, adding server_ properties, managing NPC privs)",
    give_to_singleplayer = false,
    give_to_admin = true,
}
minetest.register_privilege("npc_talk_admin", npc_talk_admin_priv_definition)

-----------------------------------------------------------------------------
-- players joining or leaving
-----------------------------------------------------------------------------
-- some variables - especially which NPC the player is talking to - need
-- to be reset when a player joins or leaves;
-- handled in functions.lua
minetest.register_on_leaveplayer(
    function(player)
	yl_speak_up.reset_vars_for_player(player:get_player_name(), true)
	yl_speak_up.player_left_remove_trade_inv(player)
    end
)

minetest.register_on_joinplayer(
    function(player)
	yl_speak_up.reset_vars_for_player(player:get_player_name(), true)
    end
)


-----------------------------------------------------------------------------
-- chat commands
-----------------------------------------------------------------------------
-- create a detached inventory for the *player* for trading with the npcs;
-- handled in trade_simple.lua
minetest.register_on_joinplayer(function(player, last_login)
	return yl_speak_up.player_joined_add_trade_inv(player, last_login)
end)


-- react to player input in formspecs;
-- handled in show_fs.lua
minetest.register_on_player_receive_fields( function(player, formname, fields)
	return yl_speak_up.input_handler(player, formname, fields)
end)



-- chat commands

-- set which NPC provides generic dialogs (=dialogs that are added to all non-generic NPC)
-- handled in add_generic_dialogs.lua
minetest.register_chatcommand( 'npc_talk_generic', {
        description = "Lists, add or removes the dialogs of NPC <n_id> as generic dialogs.\n"..
		"Call:  [list|add|remove|reload] [<n_id>]",
        privs = {npc_talk_admin = true},
        func = function(pname, param)
		return yl_speak_up.command_npc_talk_generic(pname, param)
	end
})


-- contains the command to hand out privs to NPC;
-- a chat command to grant or deny or disallow npc these privs;
-- it is not checked if the NPC exists
-- handled in npc_privs.lua
minetest.register_chatcommand( 'npc_talk_privs', {
        description = "Grants or revokes the privilege <priv> to the "..
		"yl_speak_up-NPC with the ID <n_id>.\n"..
		"Call:  [grant|revoke] <n_id> <priv>\n"..
		"If called with parameter [list], all granted privs for all NPC are shown.",
        privs = {privs = true},
        func = function(pname, param)
		return yl_speak_up.command_npc_talk_privs(pname, param)
	end,
})


-- a chat command for entering and leaving debug mode; needs to be a chat command
-- because the player may have wandered off from his NPC and get too many messages
-- without a quick way to get rid of them otherwise
-- handled in npc_talk_debug.lua
minetest.register_chatcommand( 'npc_talk_debug', {
	description = "Sets you as debugger for the yl_speak_up-NPC with the ID <n_id>.\n"..
		"  <list> lists the NPC you are currently debugging.\n"..
		"  <off> turns debug mode off again.",
	privs = {npc_talk_owner = true},
	func = function(pname, param)
		return yl_speak_up.command_npc_talk_debug(pname, param)
	end,
});


-- change the formspec style used in fs_decorated.lua
-- because the player may have wandered off from his NPC and get too many messages
-- without a quick way to get rid of them otherwise
-- handled in fs_decorated.lua
minetest.register_chatcommand( 'npc_talk_style', {
	description = "This command sets your formspec version "..
				"for the yl_speak_up NPC to value <version>.\n"..
				"  Version 1: For very old clients. Not recommended.\n"..
				"  Version 2: Adds extra scroll buttons. Perhaps you like this more.\n"..
				"  Version 3: Default version.",
	privs = {},
	func = function(pname, param)
		return yl_speak_up.command_npc_talk_style(pname, param)
	end,
})


-- most of the files of this mod can be reloaded without the server having to
-- be restarted;
-- handled in init.lua
minetest.register_chatcommand( 'npc_talk_reload', {
        description = "Reloads most of the files of this mod so that you can update their code "..
		"without having to restart the server. Requires the privs priv.",
        privs = {privs = true},
        func = function(pname, param)
		minetest.chat_send_player(pname, "Reloading most files from mod yl_speak_up...")
		yl_speak_up.reload(yl_speak_up.modpath, "reloaded by "..tostring(pname))
		minetest.chat_send_player(pname, "Reloaded successfully.")
	end
})

-- most of the files of this mod can be reloaded without the server having to
-- be restarted;

-- a general command that may branch off and/or offer help
minetest.register_chatcommand( 'npc_talk', {
	description = "Manage NPC based on yl_speak_up.\n"..
		"Usage: \"/npc_talk <command>\"  i.e. \"/npc_talk help\".",
	privs = {},
	func = function(pname, param)
		return yl_speak_up.command_npc_talk(pname, param)
	end,
})

-----------------------------------------------------------------------------
-- some node positions can be set by punching a node
-----------------------------------------------------------------------------
-- some formspecs need a position; let the player punch the node
minetest.register_on_punchnode(function(pos, node, puncher)
        local pname = puncher:get_player_name()
        if(pname and pname ~= ""
	  and yl_speak_up.speak_to[pname]
	  and yl_speak_up.speak_to[pname].expect_block_punch) then
		local fs_name = yl_speak_up.speak_to[pname].expect_block_punch
		-- the block was punched successfully
		yl_speak_up.speak_to[pname].expect_block_punch = nil
		-- store *which* block has been punched
		yl_speak_up.speak_to[pname].block_punched = pos
		-- show the formspec again
		yl_speak_up.show_fs(puncher, fs_name)
	end
end)

-----------------------------------------------------------------------------
-- other register_on_* functions that might be helpful for the quest api
-- later on but which are not used yet
-----------------------------------------------------------------------------
-- TODO minetest.register_on_chat_message(function(name, message))
-- TODO minetest.register_on_chat_message(function(name, message))
-- TODO minetest.register_on_chatcommand(function(name, command, params))
-- TODO minetest.register_on_player_receive_fields(function(player, formname, fields))
-- TODO minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv))
-- TODO minetest.register_on_player_inventory_action(function(player, action, inventory, inventory_info))
-- TODO minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, user, pointed_thing))
--
-- TODO minetest.hash_node_position(pos) (has an inverse function as well)
-- TODO minetest.global_exists(name)
