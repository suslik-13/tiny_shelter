cb_archaeology = {}
cb_archaeology.S = core.get_translator("cb_archaeology")

local modpath = core.get_modpath("cb_archaeology")
dofile(modpath .. "/sherds.lua")
dofile(modpath .. "/pot.lua")
dofile(modpath .. "/finds.lua")
dofile(modpath .. "/suspicious.lua")
dofile(modpath .. "/brush.lua")
