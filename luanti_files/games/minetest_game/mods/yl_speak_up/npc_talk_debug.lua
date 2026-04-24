
-- full version found in fs_edit_preconditions.lua:
yl_speak_up.show_precondition = function(p, pname)
	return "P: "..minetest.serialize(p or {}).."."
end

-- full version found in fs_edit_actions.lua:
yl_speak_up.show_action = function(a)
	return "A: "..minetest.serialize(a or {}).."."
end

-- full version found in fs_edit_effects.lua:
yl_speak_up.show_effect = function(r, pname)
	return "E: "..minetest.serialize(r or {}).."."
end


-- store which player is monitoring the NPC (for preconditions and
-- effects)
yl_speak_up.debug_mode_set_by_player = {}

-- for sending debug information about preconditions and effects to
-- the player who is monitoring the NPC
-- (sometimes it is not easy/obvious to see why something failed)
yl_speak_up.debug_msg = function(player, n_id, o_id, text)
	local dname = yl_speak_up.debug_mode_set_by_player[ n_id ]
	-- nobody cares
	if(not(dname)) then
		return
	end
	local pname = player:get_player_name()
	local d_id = yl_speak_up.speak_to[pname].d_id
	minetest.chat_send_player(dname, "[NPC "..tostring(n_id)..": "..
		tostring(pname).."] <"..tostring(d_id).." "..tostring(o_id)..
		"> "..tostring(text))
end


-- a chat command for entering and leaving debug mode; needs to be a chat command
-- because the player may have wandered off from his NPC and get too many messages
-- without a quick way to get rid of them otherwise
-- registered in register_once.lua
--minetest.register_chatcommand( 'npc_talk_debug', {
--	description = "Sets you as debugger for the yl_speak_up-NPC with the ID <n_id>.\n"..
--		"  <list> lists the NPC you are currently debugging.\n"..
--		"  <off> turns debug mode off again.",
--	privs = {npc_talk_owner = true},
yl_speak_up.command_npc_talk_debug = function(pname, param)
	if(param and param == "off") then
		local count = 0
		for k, v in pairs(yl_speak_up.debug_mode_set_by_player) do
			if(v and v == pname) then
				yl_speak_up.debug_mode_set_by_player[ k ] = nil
				count = count + 1
				minetest.chat_send_player(pname, "You are no longer "..
					"debugging the NPC with the ID "..tostring(k)..".")
			end
		end
		minetest.chat_send_player(pname, "Removed you as debugger of "..
			tostring(count).." NPCs.")
		return
	elseif(not(param) or param == "" or param == "list") then
		local count = 0
		local text = "You are currently debugging the NPCs with the following IDs:\n"
		for k, v in pairs(yl_speak_up.debug_mode_set_by_player) do
			if(v and v == pname) then
				count = count + 1
				text = text.."  "..tostring(k)
			end
		end
		if(count == 0) then
			text = text.." - none -"
		else
			text = text.."\nTo turn debugging off, call this command with the "..
				"parameter <off>."
		end
		minetest.chat_send_player(pname, text)
		return
	elseif(not(yl_speak_up.may_edit_npc(minetest.get_player_by_name(pname), param))) then
		minetest.chat_send_player(pname, "You do not have the necessary privs to "..
			"edit that NPC.")
		return
	else
		yl_speak_up.debug_mode_set_by_player[ param ] = pname
		minetest.chat_send_player(pname, "You are now receiving debug information "..
			"for NPC "..tostring(param)..".\nTo turn that off, type "..
			"\"/npc_talk debug off\".")
	end
end
