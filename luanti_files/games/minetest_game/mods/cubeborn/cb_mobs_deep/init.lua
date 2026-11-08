cb_mobs_deep = {}
cb_mobs_deep.S = core.get_translator("cb_mobs_deep")
local modpath = core.get_modpath("cb_mobs_deep")
dofile(modpath .. "/sculk.lua")
if rawget(_G, "mobs") then
	dofile(modpath .. "/warden.lua")
end
