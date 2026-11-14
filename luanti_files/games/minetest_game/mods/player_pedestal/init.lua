-- player_pedestal: statues of real players on pedestals + top-3 ranking podiums.
--
-- Load model (the mod is designed to cost ~nothing at runtime):
--   * no globalstep, statues have no on_step;
--   * player appearance is captured only on events (join/leave, skin or armor
--     change), debounced, and written to storage only when it really changed;
--   * rankings are kept incrementally from the statistics mods' own update
--     calls; a full storage scan runs once at startup (and on /pedestal_refresh);
--   * statues are non-persistent entities re-created by an LBM when their
--     mapblock loads, so nothing piles up in the map database.

player_pedestal = {}
local modpath = minetest.get_modpath("player_pedestal")
player_pedestal.S = minetest.get_translator("player_pedestal")

local S = player_pedestal.S

minetest.register_privilege("pedestal_admin", {
	description = S("Can place, configure and remove player pedestals"),
	give_to_singleplayer = true,
	give_to_admin = true,
})

function player_pedestal.is_admin(who)
	local name = type(who) == "string" and who or (who and who.get_player_name and who:get_player_name())
	if not name or name == "" then
		return false
	end
	return minetest.check_player_privs(name, { pedestal_admin = true })
		or minetest.check_player_privs(name, { server = true })
end

dofile(modpath .. "/poses.lua")
dofile(modpath .. "/appearance.lua")
dofile(modpath .. "/ranking.lua")
dofile(modpath .. "/statue.lua")
dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/commands.lua")
