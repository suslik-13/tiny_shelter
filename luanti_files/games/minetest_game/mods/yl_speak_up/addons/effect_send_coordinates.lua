-- hand out a preconfigured waypoint compass to the player
yl_speak_up.custom_functions_r_[ "send_coordinates" ] = {
	description = "Send a chat message to the player with coordinates.",
	param1_text = "X coordinate:",
	param1_desc = "The target x coordinate.",
	param2_text = "Y coordinate:",
	param2_desc = "The target y coordinate.",
	param3_text = "Z coordinate:",
	param3_desc = "The target z coordinate.",
	param4_text = "Name of target location:",
	param4_desc = "This is how the target location is called, i.e. \"Hidden treasure chest\".",
	-- the color cannot be set this way
--	param5_text = "Color code in Hex:",
--	param5_desc = "Give the color for the compass here. Example: \"FFD700\".\n"..
--			"Needs to be 6 characters long, with each character ranging\n"..
--			"from 0-9 or beeing A, B, C, D, E or F.\n"..
--			"Or just write something like yellow, orange etc.",
	code = function(player, n_id, r)
		local pname = player:get_player_name()
		local coords = core.string_to_pos((r.r_param1 or "0")..","..
						  (r.r_param2 or "0")..","..
						  (r.r_param3 or "0"))
		local town = (r.r_param4 or "- some place somewhere -")
		if(not(coords)) then
			minetest.chat_send_player(pname, "Sorry. There was an internal error with the "..
					"coordinates. Please inform whoever is responsible for this NPC.")

			return false
		end
		if(not(pname) or not(yl_speak_up.speak_to[pname])) then
			return false
		end
		local dialog = yl_speak_up.speak_to[pname].dialog
		minetest.chat_send_player(pname, 
			(dialog.n_npc or "- ? -")..": \""..
			tostring(town).."\" can be found at "..core.pos_to_string(coords, 0)..".")
		if(minetest.get_modpath("waypoint_compass")) then
			minetest.chat_send_player(pname, "If you have a waypoint compass, right-click "..
				"while wielding it. Select \"copy:\" to copy the location above into "..
				"your compass.")
		end
		-- the function was successful (effects only return true or false)
		return true
	end,
}
