
-- this file lods addons - actions, preconditions, effects and other things
-- - which may not be of intrest to all games
-- - and which usually require other mods to be installed in order to work

local path_addons = yl_speak_up.modpath..DIR_DELIM.."addons"..DIR_DELIM


-- the action "send_mail" requires the "mail" mod and allows to send
-- ingame mails via actions
if(minetest.global_exists("mail")
  and type(mail) == "table"
  and type(mail.send) == "function") then

	dofile(path_addons .. "action_send_mail.lua")
	dofile(path_addons .. "effect_send_mail.lua")
end

-- makes mostly sense if the waypoint_compass mod is installed
dofile(path_addons.."effect_send_coordinates.lua")
