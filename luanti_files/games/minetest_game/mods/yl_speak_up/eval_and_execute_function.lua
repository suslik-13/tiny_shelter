
-- evaluate those preconditions of type "function" (set by the staff)
-- and execute those effects/results of type "function" (set by the staff)
-- WARNING: This is extremly powerful!
--          The code is taken out of the function
--              calculate_displayable_options(..)
--          (written by AliasAlreadyTaken).
-- It requires the npc_master priv to add or edit this prereq.
-- The function is called by
--   * yl_speak_up.eval_precondition and
--   * yl_speak_up.eval_effect.
-- The npc also needs a priv to execute this.
yl_speak_up.eval_and_execute_function = function(player, x_v, id_prefix)
	local pname = player:get_player_name()

        --minetest.chat_send_all("this is in a single prereq or effect: "..dump(x_v))
        local x_id = x_v[ id_prefix.. "id" ]
        if x_v[ id_prefix.."type" ] ~= "function" then
		return true
	end

        local code = x_v[ id_prefix.."value" ]
        if code:byte(1) == 27 then
		yl_speak_up.log_with_position(pname, n_id,
			"error: could not compile the content of "..tostring(x_id).." :"..dump(code)..
			" because of illegal bytecode for player "..tostring(pname))
        end

	local param = "playername"
	if( id_prefix == "r_") then
		param = "player"
	end
        local f, msg = loadstring("return function("..param..") " .. code .. " end")

        if not f then
		yl_speak_up.log_with_position(pname, n_id,
			"error: could not compile the content of "..tostring(x_id).." :"..dump(code)..
			" for player "..tostring(pname))
        else
            local func = f()

            local ok, ret = pcall(func,pname)

            if not ok then
		yl_speak_up.log_with_position(pname, n_id,
			"error: could not execute the content of "..tostring(x_id).." :"..dump(code)..
			" for player "..tostring(pname))
            end

            if type(ret) == "boolean" then
                return ret
            end
        end
	-- fallback
	return false
end


