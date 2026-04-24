
yl_speak_up.stop_talking = function(pname)
	if(not(pname)) then
		return
	end
	yl_speak_up.reset_vars_for_player(pname, nil)
	minetest.close_formspec(pname, "yl_speak_up:talk")
end




-- count visits to this dialog - but *not* for generic dialogs as those are just linked and not
-- copied for each player; also not in edit_mode as it makes no sense there
yl_speak_up.count_visits_to_dialog = function(pname)
	if(not(pname)) then
		return
	end
	local d_id   = yl_speak_up.speak_to[pname].d_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(d_id) or not(dialog) or not(dialog.n_dialogs) or not(dialog.n_dialogs[d_id])) then
		return
	end
	if(not(dialog.n_dialogs[d_id].is_generic)) then
		if(not(dialog.n_dialogs[d_id].visits)) then
			dialog.n_dialogs[d_id].visits = 0
		end
		dialog.n_dialogs[d_id].visits = dialog.n_dialogs[d_id].visits + 1
	end
end

-- count visits to options - but *not* for generic dialogs as those are just linked and not
-- copied for each player;
-- called after all effects have been executed successfully
-- not called in edit_mode because effects are not executed there
yl_speak_up.count_visits_to_option = function(pname, o_id)
	if(not(pname)) then
		return
	end
	local d_id   = yl_speak_up.speak_to[pname].d_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(d_id) or not(dialog) or not(dialog.n_dialogs) or not(dialog.n_dialogs[d_id])
	  or not(o_id)
	  or not(dialog.n_dialogs[d_id].d_options)
	  or not(dialog.n_dialogs[d_id].d_options[o_id])) then
		return
	end
	local o_data = dialog.n_dialogs[d_id].d_options[o_id]
	if(not(o_data.is_generic)) then
		if(not(o_data.visits)) then
			o_data.visits = 0
		end
		o_data.visits = o_data.visits + 1
	end
end
