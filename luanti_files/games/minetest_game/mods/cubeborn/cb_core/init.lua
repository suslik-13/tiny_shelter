cb_core = {}
cb_core.S = core.get_translator("cb_core")

local modpath = core.get_modpath("cb_core")
dofile(modpath .. "/util.lua")
dofile(modpath .. "/profile.lua")
dofile(modpath .. "/equiv.lua")
dofile(modpath .. "/natural.lua")
dofile(modpath .. "/jobs.lua")
dofile(modpath .. "/area_check.lua")
dofile(modpath .. "/physics.lua")
dofile(modpath .. "/biome_palette.lua")
dofile(modpath .. "/mob_fixes.lua")
dofile(modpath .. "/mob_gear.lua")
dofile(modpath .. "/effects.lua")
dofile(modpath .. "/effects_potions.lua")
dofile(modpath .. "/effects_haste.lua")
dofile(modpath .. "/bossbar.lua")
dofile(modpath .. "/doors.lua")

core.register_privilege("cb_admin", {
	description = cb_core.S("Can manage Cubeborn dimensions and structures"),
	give_to_singleplayer = false,
})
