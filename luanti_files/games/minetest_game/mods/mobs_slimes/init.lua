
-- Slimes by TomasJLuis
-- Migration to Mobs Redo API by TenPlus1

-- get path and translator

local path = core.get_modpath("mobs_slimes")
local S = core.get_translator("mobs_slimes")

-- load mod files

dofile(path .. "/greenslimes.lua")
dofile(path .. "/lavaslimes.lua")

-- cannot find mesecons?, craft glue instead
if not core.get_modpath("mesecons_materials") then

	core.register_craftitem(":mesecons_materials:glue", {
		image = "jeija_glue.png",
		description = S("Glue")
	})
end

print("[MOD] Mobs Redo Slimes loaded")
