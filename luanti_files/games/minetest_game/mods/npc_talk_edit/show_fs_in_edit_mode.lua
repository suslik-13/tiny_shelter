
-- when in edit mode: ask for saving dialogs when needed
local old_show_fs = yl_speak_up.show_fs
yl_speak_up.show_fs = function(player, fs_name, param)
	if(not(player)) then
		return
	end
	local pname = player:get_player_name()
	if(not(yl_speak_up.speak_to[pname])) then
		return
	end

	local last_fs = yl_speak_up.speak_to[pname].last_fs
	-- show the save or discard changes dialog
	if(fs_name and fs_name == "save_or_discard_changes") then
		yl_speak_up.show_fs_ver(pname, "yl_speak_up:save_or_discard_changes",
			yl_speak_up.get_fs_save_or_discard_changes(player, param))
		return

	-- the player either saved or discarded; we may proceed now
	elseif(fs_name and fs_name == "proceed_after_save") then
		fs_name = yl_speak_up.speak_to[pname].next_fs
		param = yl_speak_up.speak_to[pname].next_fs_param
		yl_speak_up.speak_to[pname].next_fs = nil
		yl_speak_up.speak_to[pname].next_fs_param = nil
		yl_speak_up.speak_to[pname].last_fs = fs_name
		yl_speak_up.speak_to[pname].last_fs_param = param
		if(not(fs_name) or fs_name == "quit") then
			yl_speak_up.reset_vars_for_player(pname, false)
			return
		end

	-- the player clicked on "back" in the above dialog
	elseif(fs_name and fs_name == "show_last_fs") then
		-- call the last formspec again - and with the same parameters
		fs_name = yl_speak_up.speak_to[pname].last_fs
		param = yl_speak_up.speak_to[pname].last_fs_param

	-- do we need to check if there is something that needs saving?
	elseif(fs_name
	  -- msg is just a loop for displaying (mostly error) messages
	  and fs_name ~= "msg"
	  and fs_name ~= "player_offers_item"
	  -- is the player editing the NPC? that is: might there be any changes?
	  and (yl_speak_up.edit_mode[pname] == yl_speak_up.speak_to[pname].n_id)) then
		local last_fs = yl_speak_up.speak_to[pname].last_fs
		local d_id = yl_speak_up.speak_to[pname].d_id
		local o_id = yl_speak_up.speak_to[pname].o_id
		-- only these two formspecs need to ask specificly if the data ought to be saved
		if(last_fs == "talk" or last_fs == "edit_option_dialog" or fs_name == "quit") then
			local last_param = yl_speak_up.speak_to[pname].last_fs_param
			local show_save_fs = false
			if(not(param)) then
				param = {}
			end
			-- set the target dialog
			yl_speak_up.speak_to[pname].target_dialog = param.d_id
			-- if we are switching from one dialog to another: is it the same?
			if(last_fs == "talk" and fs_name == last_fs
			  and param and param.d_id and param.d_id ~= d_id) then
				-- diffrent parameters: save (if needed)
				show_save_fs = true
			elseif(fs_name == "talk" and param and param.do_save) then
				-- player clicked on save button
				show_save_fs = true
			-- leaving a dialog: save!
			elseif(last_fs == "talk" and fs_name ~= last_fs) then
				show_save_fs = true
			-- clicking on "save" in an edit option dialog: save!
			elseif(last_fs == "edit_option_dialog" and fs_name == last_fs
			  and param and param.caller and param.caller == "save_option") then
				show_save_fs = true
			-- leaving editing an option: save!
			elseif(last_fs == "edit_option_dialog" and fs_name ~= last_fs) then
				show_save_fs = true
			-- quitting: save!
			elseif(fs_name == "quit") then
				yl_speak_up.speak_to[pname].target_dialog = nil
				show_save_fs = true
			end
			-- show the save or discard dialog
			if(show_save_fs) then
				yl_speak_up.speak_to[pname].next_fs = fs_name
				yl_speak_up.speak_to[pname].next_fs_param = param
				-- check first if it's necessary to ask for save or discard
				yl_speak_up.input_save_or_discard_changes(player, "", {})
				return
			end
		end
		-- store the new formspec
		yl_speak_up.speak_to[pname].last_fs = fs_name
		-- and its parameter
		yl_speak_up.speak_to[pname].last_fs_param = param
	end

	-- Note: fs_name and param *may* have been changed in edit_mode by the code above
	old_show_fs(player, fs_name, param)
end
