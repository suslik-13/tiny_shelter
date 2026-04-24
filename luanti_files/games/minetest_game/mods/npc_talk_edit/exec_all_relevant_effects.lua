
local old_execute_all_relevant_effects = yl_speak_up.execute_all_relevant_effects
yl_speak_up.execute_all_relevant_effects = function(player, effects, o_id, action_was_successful, d_option,
						dry_run_no_exec) -- dry_run_no_exec for edit_mode
	-- if in edit mode: do a dry run - do *not* execute the effects
	local edit_mode = (player and yl_speak_up.in_edit_mode(player:get_player_name()))
	-- we pass this as an additional parameter so that it doesn't have to be re-evaluated for each effect
	return old_execute_all_relevant_effects(player, effects, o_id, action_was_successful, d_option, edit_mode)
end
