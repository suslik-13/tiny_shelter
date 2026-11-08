-- Wandering trader and llamas (spec cycle 3, 6). Models and textures from
-- Mineclonia's mobs_mc (GPLv3 / CC BY-SA) on mobs_redo.
cb_mobs_trader = {}
cb_mobs_trader.S = core.get_translator("cb_mobs_trader")
cb_mobs_trader.store = core.get_mod_storage()

local modpath = core.get_modpath("cb_mobs_trader")
dofile(modpath .. "/trader.lua")
dofile(modpath .. "/llama.lua")
dofile(modpath .. "/tame.lua")
dofile(modpath .. "/gear.lua")
dofile(modpath .. "/caravan.lua")
dofile(modpath .. "/spawn.lua")
