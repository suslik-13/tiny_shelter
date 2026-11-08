cb_raids = {}
cb_raids.S = core.get_translator("cb_raids")

local modpath = core.get_modpath("cb_raids")
dofile(modpath .. "/omen.lua")
dofile(modpath .. "/hud.lua")
dofile(modpath .. "/raid.lua")
