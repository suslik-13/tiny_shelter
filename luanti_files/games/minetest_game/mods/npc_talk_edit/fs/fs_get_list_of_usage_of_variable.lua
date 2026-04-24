
-- this function is called in fs_edit_general.lua when creating preconditions/effects
-- and from fs_manage_variables.lua when the player clicks on a button;
-- input to this formspec is sent to the respective calling functions

-- find out where this variable is used in NPCs
yl_speak_up.fs_get_list_of_usage_of_variable = function(var_name, pname, check_preconditions,
						back_button_name, back_button_text, is_internal_var)
	-- TODO: check if the player really has read access to this variable
	if(not(is_internal_var)) then
		var_name = yl_speak_up.restore_complete_var_name(var_name, pname)
	end
	-- which NPC (might be several) is using this variable?
	-- TODO: ..or if the player at least is owner of these NPC or has extended privs
	local npc_list = yl_speak_up.get_variable_metadata(var_name, "used_by_npc")
	-- list of all relevant preconditions, actions and effects
	local res = {}
	local count_read = 0
	local count_changed = 0
	local var_val_in_text = "$VAR "..string.sub(var_name, 3)
	for i, n_id in ipairs(npc_list) do
		-- the NPC may not even be loaded
		local dialog = yl_speak_up.load_dialog(n_id, false)
		if(dialog and dialog.n_dialogs) then
		for d_id, d in pairs(dialog.n_dialogs) do
			-- show the value of the variable in the dialog text?
			if(string.find(d.d_text or "", var_val_in_text)) then
				-- we are not really dealing with an option - this is a variable displayed in the main text
				local o = {o_id = "", o_text_when_prerequisites_met = "[The value of the variable is displayed in the dialog text.]"}
				-- at least one blank is needed so that the text is displayed at all
				yl_speak_up.print_as_table_dialog(" ", " ", dialog,
					n_id, d_id, "", res, o, sort_value)
			end
			if(d and d.d_options) then
			for o_id, o in pairs(d.d_options) do
				local p_text = ""
				local r_text = ""
				local sort_value = 0
				-- show the value of the variable in the options' text?
				if(string.find(o.o_text_when_prerequisites_met or "", var_val_in_text)) then
					p_text = p_text..yl_speak_up.print_as_table_alternate_text(
							tostring(o.o_id), "", "",
							"[Answer shows value of the variable in the text shown if ALL preconditions are FULFILLED.]")
				end
				if(o and o.o_prerequisites and check_preconditions) then
				for p_id, p in pairs(o.o_prerequisites) do
					if(p and p.p_type and p.p_type == "state"
					  and p.p_variable and p.p_variable == var_name) then
						p_text = p_text..yl_speak_up.print_as_table_precon(p,pname)
						sort_value = (p.p_var_cmp_value or 0)
						count_read = count_read + 1
					end
				end
				end
				-- show the value of the variable in the options' text if preconditions failed?
				if(string.find(o.o_text_when_prerequisites_not_met or "", var_val_in_text)) then
					p_text = p_text..yl_speak_up.print_as_table_alternate_text(
							tostring(o.o_id), "", "",
							"[Answer shows value of the variable in the text shown if a precondition FAILED.]")
				end
				if(o and o.o_results) then
				for r_id, r in pairs(o.o_results) do
					if(r and r.r_type and r.r_type == "state"
					  and r.r_variable and r.r_variable == var_name) then
						r_text = r_text..yl_speak_up.print_as_table_effect(r,pname)
						-- values set in the results are more important than
						-- those set in preconditions
						sort_value = (r.r_var_cmp_value or 0)
						count_changed = count_changed + 1
					end
					if(r and r.alternate_text and string.find(r.alternate_text, var_val_in_text)) then
						r_text = r_text..yl_speak_up.print_as_table_alternate_text(
							tostring(r.r_id), "effect", "failed",
							r.alternate_text)
					end
				end
				end
				-- if preconditions or effects apply: show the action as well
				if(o and o.actions and (p_text ~= "" or r_text ~= "")) then
				for a_id, a in pairs(o.actions) do
					-- no need to introduce an a_text; this will follow
					-- directly after p_text, and p_text is finished
					p_text = p_text..yl_speak_up.print_as_table_action(a, pname)
					if(a and a.alternate_text and string.find(r.alternate_text, var_val_in_text)) then
						p_text = p_text..yl_speak_up.print_as_table_alternate_text(
							tostring(a.a_id), "action", "failed",
							a.alternate_text)
					end
				end
				end
				yl_speak_up.print_as_table_dialog(p_text, r_text, dialog,
					n_id, d_id, o_id, res, o, sort_value)
			end
			end
		end
		end
	end

	local formspec = yl_speak_up.print_as_table_prepare_formspec(res, "table_of_variable_uses",
				back_button_name, back_button_text)
	table.insert(formspec,
		"label[20.0,1.8;"..
			minetest.formspec_escape("Variable \""..
				minetest.colorize("#FFFF00", tostring(var_name or "- ? -"))..
				"\" is used here:").."]")

	if(count_read > 0 or count_changed > 0) then
		table.insert(formspec,
			"label[16.0,31.0;The variable is accessed in "..
				minetest.colorize("#FFFF00", tostring(count_read).." pre(C)onditions")..
				" and changed in "..
				minetest.colorize("#55FF55", tostring(count_changed).." (Ef)fects")..
				".]")
	elseif(not(is_internal_var)) then
		table.insert(formspec,
			"button[0.2,30.6;56.6,1.2;delete_unused_variable;"..
				minetest.formspec_escape("Delete this unused variable \""..
					tostring(var_name or "- ? -")).."\".]")
	else
		table.insert(formspec,
			"label[16.0,31.0;This is an internal variable and cannot be deleted.]")
	end
	return table.concat(formspec, "\n")
end
