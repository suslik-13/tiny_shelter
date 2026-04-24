-- Implementation of chat commands that were registered in register_once

-- this is a way to provide additional help if a mod adds further commands (like the editor)
yl_speak_up.add_to_command_help_text = ""

-- general function for handling talking to the NPC
yl_speak_up.command_npc_talk = function(pname, param)
	if(not(pname)) then
		return
	end
	local parts = string.split(param or "", " ", false, 1)
	local cmd  = parts[1] or ""
	local rest = parts[2] or ""
	-- setting talk style is available for all
	if(    cmd and cmd == "style") then
		-- implemented in fs_decorated.lua:
		return yl_speak_up.command_npc_talk_style(pname, rest)
	-- show formspec with list of NPC controlled by the player
	elseif(cmd and cmd == "list") then
		return yl_speak_up.command_npc_talk_list(pname, rest)
	-- show the version of the mod
	elseif(cmd and cmd == "version") then
		minetest.chat_send_player(pname, "Version of yl_speak_up: "..tostring(yl_speak_up.version))
		return
	-- debug mode only makes sense if the player can edit that NPC; the command checks for this
	elseif(cmd and cmd == "debug") then
		-- implemented in npc_talk_debug.lua:
		return yl_speak_up.command_npc_talk_debug(pname, rest)

	-- managing generic NPC requires npc_talk_admin priv
	elseif(cmd and cmd == "generic") then
		if(not(minetest.check_player_privs(pname, {npc_talk_admin = true}))) then
			minetest.chat_send_player(pname, "This command is used for managing "..
				"generic NPC. You lack the \"npc_talk_admin\" priv required to "..
				"run this command.")
			return
		end
		-- implemented in add_generic_dialogs.lua:
		return yl_speak_up.command_npc_talk_generic(pname, rest)
	-- restore an NPC that got lost
	elseif(cmd and cmd == "force_restore_npc") then
		if(not(minetest.check_player_privs(pname, {npc_talk_admin = true}))) then
			minetest.chat_send_player(pname, "This command is used for restoring "..
				"NPC that somehow got lost (egg destroyed, killed, ..). You "..
				"lack the \"npc_talk_admin\" priv required to run this command.")
			return
		end
		-- implemented in fs_npc_list.lua:
		return yl_speak_up.command_npc_force_restore_npc(pname, rest)
	elseif(cmd and cmd == "privs") then
		-- the command now checks for player privs
		-- implemented in npc_privs.lua:
		return yl_speak_up.command_npc_talk_privs(pname, rest)
	end
	minetest.chat_send_player(pname,
		"The /npc_talk command is used for managing the yl_speak_up mod and "..
			"any NPC that use it.\n"..
		"Usage: \"/npc_talk <command>\" with <command> beeing:\n"..
		"       help        this help here\n"..
		"       style       display talk menu in a way better suited for very old versions of MT\n"..
		"       version     show human-readable version information\n"..
		"       list        shows a list of NPC that you can edit\n"..
		"       debug       debug a particular NPC\n"..
		"       privs       list, grant or revoke privs for your NPC\n"..
		"       generic           [requires npc_talk_admin priv] list, add or remove NPC as generic NPC\n"..
		"       force_restore_npc [requires npc_talk_admin priv] restore NPC that got lost\n"..
		-- reload is fully handled in register_once
		"Note: /npc_talk_reload [requires privs priv] reloads the code of the mod without server "..
			"restart."..
		yl_speak_up.add_to_command_help_text)
end
