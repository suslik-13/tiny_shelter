-- Banners (spec cycle 3, 5; after Mineclonia's mcl_banners and mcl_loom,
-- GPLv3; pattern textures CC BY-SA): one item per colour carrying its layers
-- in item meta ("pattern:colour;..."), standing and wall banners whose
-- picture is one entity, the loom, copying, washing in a cauldron, and the
-- pillager captain's ominous banner.
cb_banners = {}
cb_banners.S = core.get_translator("cb_banners")

local modpath = core.get_modpath("cb_banners")
dofile(modpath .. "/api.lua")
dofile(modpath .. "/items.lua")
dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/loom.lua")
dofile(modpath .. "/copy_wash.lua")
dofile(modpath .. "/ominous.lua")
