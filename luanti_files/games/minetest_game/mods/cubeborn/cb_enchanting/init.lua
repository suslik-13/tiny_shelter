-- Enchanting (spec 2026-10-25-cycle8-enchanting-design.md).
cb_enchanting = { S = core.get_translator("cb_enchanting"), }
local modpath = core.get_modpath("cb_enchanting")
for _, f in ipairs({ "data", "api", "random", "caps", "drops", "combat", "armor", "armor_move", "mace", "curses", "mending", "fishing", "combine", "grind", "sources", "table", "migrate", }) do
	dofile(modpath .. "/" .. f .. ".lua")
end
