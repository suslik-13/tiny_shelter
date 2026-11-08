-- Potions and brewing (spec 2026-10-24-cycle6-potions-design.md).
cb_potions = { S = core.get_translator("cb_potions"), }
local modpath = core.get_modpath("cb_potions")
dofile(modpath .. "/data.lua")
dofile(modpath .. "/api.lua")
dofile(modpath .. "/items.lua")
dofile(modpath .. "/ingredients.lua")
dofile(modpath .. "/brewing.lua")
dofile(modpath .. "/stand.lua")
dofile(modpath .. "/guide.lua")
dofile(modpath .. "/throw.lua")
