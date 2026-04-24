
-- if player has npc_talk_owner priv AND is owner of this particular npc:
--   chat option: "I am your owner. I have new orders for you.
--   -> enters edit mode
-- when edit_mode has been enabled, the following chat options are added to the options:
--   chat option: "Add new answer/option to this dialog."
--   -> adds a new aswer/option
--   chat option: "That was all. I'm finished with giving you new orders. Remember them!"
--   -> ends edit mode
-- (happens in fs/fs_talkdialog_in_edit_mode.lua)


-- store if the player is editing a particular NPC; format: yl_speak_up.edit_mode[pname] = npc_id
yl_speak_up.edit_mode = {}

-- changes applied in edit_mode are applied immediately - but not immediately stored to disk
-- (this gives the players a chance to back off in case of unwanted changes)
yl_speak_up.npc_was_changed = {}


-- is the player in edit mode?
yl_speak_up.in_edit_mode = function(pname)
	return pname
		and yl_speak_up.edit_mode[pname]
		and (yl_speak_up.edit_mode[pname] == yl_speak_up.speak_to[pname].n_id)
end


-- reset edit_mode when stopping to talk to an NPC
local old_reset_vars_for_player = yl_speak_up.reset_vars_for_player
yl_speak_up.reset_vars_for_player = function(pname, reset_fs_version)
	yl_speak_up.edit_mode[pname] = nil
	old_reset_vars_for_player(pname, reset_fs_version)
end


-- make sure generic dialogs are never included in edit_mode (because in edit mode we want to
--    edit this particular NPC without generic parts)
local old_load_dialog = yl_speak_up.load_dialog
yl_speak_up.load_dialog = function(n_id, player) -- returns the saved dialog
	if(player and yl_speak_up.in_edit_mode(player:get_player_name())) then
		return old_load_dialog(n_id, false)
	end
	return old_load_dialog(n_id, player)
end


-- in edit mode the dialog may be saved. visits to a particular dialog are of no intrest here
local old_count_visits_to_dialog = yl_speak_up.count_visits_to_dialog
yl_speak_up.count_visits_to_dialog = function(pname)
	if(yl_speak_up.in_edit_mode(pname)) then
		return
	end
	return old_count_visits_to_dialog(pname)
end


local modpath = npc_talk_edit.modpath

-- this is a way to provide additional help if a mod adds further commands (like the editor)
yl_speak_up.add_to_command_help_text = yl_speak_up.add_to_command_help_text..
		"\nAdditional commands provided by "..tostring(npc_talk_edit.modname)..":\n"..
		"       force_edit  forces edit mode for any NPC you talk to\n"

	-- overrides of functions fo fs/fs_talkdialog.lua when in edit_mode (or for entering/leaving it)
	dofile(modpath .. "fs/fs_talkdialog_edit_mode.lua")

	-- edit preconditions (can be reached through edit options dialog)
	dofile(modpath .. "fs/fs_edit_preconditions.lua")
	-- edit actions (can be reached through edit options dialog)
	dofile(modpath .. "fs/fs_edit_actions.lua")
	-- edit effects (can be reached through edit options dialog)
	dofile(modpath .. "fs/fs_edit_effects.lua")
	-- edit options dialog (detailed configuration of options in edit mode)
	dofile(modpath .. "fs/fs_edit_options_dialog.lua")

	-- the player wants to change something regarding the dialog
	dofile(modpath .. "edit_mode_apply_changes.lua")



	-- handle page changes and asking for saving when in edit mode:
	dofile(modpath .. "show_fs_in_edit_mode.lua")
	-- ask if the player wants to save, discard or go back in edit mode
	dofile(modpath .. "fs/fs_save_or_discard_or_back.lua")
	-- the player wants to change something regarding the dialog
	dofile(modpath .. "edit_mode_apply_changes.lua")

	-- assign a quest step to a dialog option/answer
	dofile(modpath .. "fs/fs_assign_quest_step.lua")

	-- in edit_mode we need a more complex reaction to inventory changes
	dofile(modpath .. "exec_actions_action_inv_changed.lua")
	-- in edit_mode: effects are not executed
	dofile(modpath .. "exec_all_relevant_effects.lua")
	-- some helper functions for formatting text for a formspec talbe
	dofile(modpath .. "print_as_table.lua")
	-- create i.e. a dropdown list of player names
	dofile(modpath .. "api/formspec_helpers.lua")
	-- handle alternate text for dialogs
	dofile(modpath .. "api/api_alternate_text.lua")
	-- helpful for debugging the content of the created dialog structure
	dofile(modpath .. "fs/fs_show_what_points_to_this_dialog.lua")
	-- common functions for editing preconditions and effects
	dofile(modpath .. "api/fs_edit_general.lua")
	-- edit preconditions (can be reached through edit options dialog)
	dofile(modpath .. "fs/fs_edit_preconditions.lua")
	-- edit actions (can be reached through edit options dialog)
	dofile(modpath .. "fs/fs_edit_actions.lua")
	-- edit effects (can be reached through edit options dialog)
	dofile(modpath .. "fs/fs_edit_effects.lua")
	-- edit options dialog (detailed configuration of options in edit mode)
	dofile(modpath .. "fs/fs_edit_options_dialog.lua")
	dofile(modpath .. "fs/fs_initial_config_in_edit_mode.lua")
	dofile(modpath .. "trade_in_edit_mode.lua")
	dofile(modpath .. "fs/fs_add_trade_simple_in_edit_mode.lua")
	-- handle back button diffrently when editing a trade as an action:
	dofile(modpath .. "fs/fs_do_trade_simple_in_edit_mode.lua")
	-- as the name says: list which npc acesses a variable how and in which context
	dofile(modpath .. "fs/fs_get_list_of_usage_of_variable.lua")
	-- show which values are stored for which player in a quest variable
	dofile(modpath .. "fs/fs_show_all_var_values.lua")
	-- manage quest variables: add, delete, manage access rights etc.
	dofile(modpath .. "fs/fs_manage_variables.lua")
	-- GUI for adding/editing quests
	dofile(modpath .. "fs/fs_manage_quests.lua")
	-- GUI for adding/editing quest steps for the quests
	dofile(modpath .. "api/api_quest_steps.lua")
	dofile(modpath .. "fs/fs_manage_quest_steps.lua")
	-- used by the above
	dofile(modpath .. "fs/fs_add_quest_steps.lua")
	-- setting skin, wielded item etc.
	dofile(modpath .. "fs/fs_fashion.lua")
	dofile(modpath .. "fs/fs_fashion_extended.lua")
	-- properties for NPC without specific dialogs that want to make use of
	dofile(modpath .. "fs/fs_properties.lua")
	-- /npc_talk force_edit (when talking to an NPC in the normal way fails):
	dofile(modpath .. "command_force_edit_mode.lua")
	-- add the force_edit option to the chat commands
	dofile(modpath .. "chat_commands_in_edit_mode.lua")
	-- creating and maintaining quests
	dofile(modpath .. "fs/fs_quest_gui.lua")
	-- take notes regarding what the NPC is for
	dofile(modpath .. "fs/fs_notes.lua")
