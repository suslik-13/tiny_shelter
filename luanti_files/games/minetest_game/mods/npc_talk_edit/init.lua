
npc_talk_edit = {}

local modpath = minetest.get_modpath("npc_talk_edit")..DIR_DELIM
npc_talk_edit.modpath = modpath
npc_talk_edit.modname = minetest.get_current_modname()

npc_talk_edit.edit_mode = function()
	dofile(modpath .. "edit_mode.lua")
end


yl_speak_up.register_on_reload(npc_talk_edit.edit_mode, "npc_talk_edit.edit_mode()")
