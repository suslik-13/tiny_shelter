cb_portals = {}
cb_portals.S = core.get_translator("cb_portals")

local modpath = core.get_modpath("cb_portals")
dofile(modpath .. "/common.lua")

-- With the nether mod (profile "external") its own Nether portals are used.
if cb_core.profile.nether == "own" and cb_dimensions.get_dim("nether") then
	cb_portals.NODE = "cb_portals:nether_portal"
	dofile(modpath .. "/registry.lua")
	dofile(modpath .. "/frame.lua")
	dofile(modpath .. "/travel.lua")
end

if cb_dimensions.the_end then
	dofile(modpath .. "/end_portal.lua")
	dofile(modpath .. "/end_gateway.lua")
	if core.get_modpath("cb_mobs_dim") then
		dofile(modpath .. "/end_fight.lua")
	end
end

if core.get_modpath("cb_structures") then
	dofile(modpath .. "/eye.lua")
end
