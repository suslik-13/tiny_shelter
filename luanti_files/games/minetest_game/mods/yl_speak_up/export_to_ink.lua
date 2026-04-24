-- helper functions for export_to_ink_language:

-- this table will hold the functions for exporting to ink so that we don't fill that namespace too much
yl_speak_up.export_to_ink = {}

-- an abbreviation
local ink_export = yl_speak_up.export_to_ink

-- use d_name field (name of dialog) instead of n_<id>_d_<id>
local use_d_name = true


-- in order to be able to deal with multiple NPC in ink, we use the NPC id n_id
-- plus the dialog id d_id as a name prefix; o_id, a_id and r_id are appended
-- as needed
yl_speak_up.export_to_ink.print_knot_name = function(lines, knot_name, use_prefix, dialog_names)
	if(knot_name and dialog_names[knot_name]) then
		knot_name = dialog_names[knot_name]
	end
	knot_name = use_prefix..tostring(knot_name or "ERROR")
	table.insert(lines, "\n\n=== ")
	table.insert(lines, knot_name)
	table.insert(lines, " ===")
	return knot_name
end


-- execution of effects ends if an on_failure effect is reached; for ink to be able to
-- display effects (as tags) correctly, we need to add them at the right place - some
-- tags come after the option/choice, some after the last action (if there is an action),
-- some between on_failure actions (if they exist) 
yl_speak_up.export_to_ink.add_effect_tags = function(text, sorted_e_list, effects, start_at_effect)
	if(not(text)) then
		text = ""
	end
	if(not(start_at_effect) or start_at_effect > #sorted_e_list) then
		return text
	end
	for i = start_at_effect, #sorted_e_list do
		local r_id = sorted_e_list[i]
		if(effects and effects[r_id]) then
			local r = effects[r_id]
			if(r and r.r_type and r.r_type == "on_failure") then
				-- end as soon as we reach the next on_failure dialog
				return text
			end
			if(r and r.r_type and r.r_type ~= "dialog") then
				if(text ~= "") then
					text = text.."\n  "
				end
				-- the dialog effect is something diffrent
				text = text.."# effect "..tostring(r_id).." "..tostring(yl_speak_up.show_effect(r))
			end
		end
	end
	return text
end


-- choices are a bit complicated as they may contain alternate_text that is to be
-- displayed instead (in yl_speak_up) and before (in ink) shwoing the target dialog text;
-- also, the divert_to target dialog may need to be rewritten
yl_speak_up.export_to_ink.print_choice = function(lines, choice_text, use_prefix, start_dialog,
							alternate_text, divert_to, only_once, label,
							precondition_list, effect_list,
							dialog_names)
	-- usually, options/answers/choices can be selected multiple times;
	-- we support the default ink way of "*" as well (but only until the player stops talking,
	-- not persistently stored)
	if(not(only_once)) then
		table.insert(lines, "\n+ ")
	else
		table.insert(lines, "\n* ")
	end
	-- helps to regcognize what has been changed how when importing again
	if(label and label ~= "") then
		table.insert(lines, "(")
		table.insert(lines, tostring(label))
		table.insert(lines, ") ")
	end
	-- are there any preconditions which can be handled by ink? most can not as they can
	-- only be determined ingame (i.e. state of a block); even the value of variables may
	-- have been changed externally
	if(precondition_list and #precondition_list > 0) then
		for _, p_text in ipairs(precondition_list) do
			if(p_text ~= "") then
				table.insert(lines, "{ ")
				table.insert(lines, p_text)
				table.insert(lines, " } ")
			end
		end
	end
	-- don't repeat the text of the choice in the output when running ink
	table.insert(lines, "[")
	table.insert(lines, choice_text)
	table.insert(lines, "]")
	-- dialogs, actions and effects can have an alternate_text with which they override the
	-- text of the target_dialog/divert_to;
	-- this isn't perfect as alternate_text supports $TEXT$ for inserting the text of the
	-- target dialog anywhere in the alternate_text - while ink will print out this alternate_text
	-- first and then that of the target dialog/divert_to
	if(alternate_text and alternate_text ~= "") then
		-- a new line and some indentation makes this more readable
		table.insert(lines, "\n  ")
		table.insert(lines, alternate_text)
		-- write the divert into a new line as well
		table.insert(lines, "\n ")
	end
	-- setting a variable to a value is something we can model in ink as well
	if(effect_list and #effect_list > 0) then
		for _, e_text in ipairs(effect_list) do
			table.insert(lines, "\n  ~ ")
			table.insert(lines, e_text)
		end
		-- the divert needs to be put into a new line
		table.insert(lines, "\n")
	end
	-- actually go to the dialog this option leads to
	table.insert(lines, " -> "..use_prefix)
	if(not(start_dialog) or start_dialog == "") then
		start_dialog = "d_1"
	end
	if(not(divert_to) or divert_to == "") then
		-- go back to the start dialog (the start dialog may have been changed)
		divert_to = tostring(start_dialog)
	elseif(divert_to == "d_end" or divert_to == use_prefix.."d_end") then
		-- go back to choosing between talking to NPC and end
		divert_to = "d_end"
	else
		divert_to = tostring(divert_to)
	end
	if(dialog_names and dialog_names[divert_to]) then
		divert_to = dialog_names[divert_to]
	end
	table.insert(lines, divert_to)
end


-- this prints the dialog as a knot - but without choices (those are added to the lines table later)
-- d: dialog
yl_speak_up.export_to_ink.print_dialog_knot = function(lines, use_prefix, d_id, d, dialog_names)
	local knot_name = ink_export.print_knot_name(lines, d_id, use_prefix, dialog_names)

	-- many characters at the start of a line have a special meaning;
	-- hopefully they will not be obstrusive later on;
	-- TODO: in order to be on the safe side: add a ":" in front of each line?
	local t = d.d_text or ""
	if(t == "") then
		-- entirely empty text for knots does not work
		t = "No text."
	end
--	t = string.gsub(t, "\n([:>=])", "\n %1")
	table.insert(lines, "\n")
	table.insert(lines, t)
	return knot_name
end

-- actions can fail *and* be aborted by the player; in order to model that in ink, we add
-- a knot for each action
-- Parameter:
--  a        action
yl_speak_up.export_to_ink.print_action_knot = function(lines, use_prefix, d_id, o_id, start_dialog,
						a, alternate_text_on_success, next_target, dialog_names,
						e_list_on_success)
	local action_prefix = use_prefix.."action_"..tostring(a.a_id).."_"..tostring(o_id).."_"
	local knot_name = ink_export.print_knot_name(lines, d_id, action_prefix, dialog_names)

	table.insert(lines, "\n:action: ")
	table.insert(lines, a.a_id)
	table.insert(lines, " ")
	table.insert(lines, yl_speak_up.show_action(a))
	table.insert(lines, "A: "..minetest.serialize(a or {})..".")

	ink_export.print_choice(lines, "Action was successful", use_prefix, start_dialog,
					alternate_text_on_success, next_target, false, nil,
					nil, e_list_on_success, dialog_names)

	ink_export.print_choice(lines, "Action failed", use_prefix, start_dialog,
					a.alternate_text, a.a_on_failure, false, nil,
					nil, nil, dialog_names)

	ink_export.print_choice(lines, "Back", use_prefix, start_dialog,
					nil, tostring(d_id), false, nil,
					nil, nil, dialog_names)
	return string.sub(knot_name, string.len(use_prefix)+1)
end


-- there is a special on_failure effect that can lead to a diffrent target dialog and print
-- out a diffrent alternate_text if the *previous* effect failed; in order to model that in
-- ink, we add a knot for such on_failure effects
-- Parameter:
--  r        effect/result
--  r_prev   previous effect
yl_speak_up.export_to_ink.print_effect_knot = function(lines, use_prefix, d_id, o_id, start_dialog,
						r, r_prev, alternate_text_on_success, next_target,
						dialog_names)
	local effect_prefix = use_prefix.."effect_"..tostring(r.r_id).."_"..tostring(o_id).."_"
	local knot_name = ink_export.print_knot_name(lines, d_id, effect_prefix, dialog_names)

	table.insert(lines, "\n:effect: ")
	table.insert(lines, r.r_id)
	table.insert(lines, " ")
	-- show text of the *previous effect* - because that is the one which may have failed:
	table.insert(lines, yl_speak_up.show_effect(r))

	table.insert(lines, "\nThe previous effect was: ")
	table.insert(lines, r_prev.r_id)
	table.insert(lines, " ")
	-- show text of the *previous effect* - because that is the one which may have failed:
	table.insert(lines, yl_speak_up.show_effect(r_prev))

	ink_export.print_choice(lines, "Effect was successful", use_prefix, start_dialog,
					alternate_text_on_success, next_target, false, nil,
					nil, nil, dialog_names)

	ink_export.print_choice(lines, "Effect failed", use_prefix, start_dialog,
					r.alternate_text, r.r_value, false, nil,
					nil, nil, dialog_names)
	return string.sub(knot_name, string.len(use_prefix)+1)
end


-- which variables are used by this NPC?
yl_speak_up.export_to_ink.print_variables_used = function(lines, dialog)
	if(not(dialog) or not(dialog.n_dialogs)) then
		return
	end
	local vars_used = {}
	for d_id, d_data in pairs(dialog.n_dialogs or {}) do
		for o_id, o_data in pairs(d_data.d_options or {}) do
			-- variables may be used in preconditions
			for p_id, p in pairs(o_data.o_prerequisites or {}) do
				-- we are checking the state of a variable
				if(p and p.p_type and p.p_type == "state") then
					-- store as key in order to avoid duplicates
					vars_used[ p.p_variable ] = true
				-- properties are comparable to variables
				elseif(p and p.p_type and p.p_type == "property") then
					vars_used[ "property "..p.p_value ] = true
				end
			end
			for r_id, r in pairs(o_data.o_results or {}) do
				if(r and r.r_type and r.r_type == "state") then
					vars_used[ r.r_variable ] = true
				elseif(r and r.r_type and r.r_type == "property") then
					vars_used[ "property "..r.r_value ] = true
				end
			end
		end
	end
	table.insert(lines, "\n")
	-- we stored as key/value in order to avoid duplicates
	for var_name, _ in pairs(vars_used) do
		-- replace blanks with an underscore in an attempt to turn it into a legal var name
		-- (this is not really sufficient as var names in yl_speak_up are just strings, 
		--  while the ink language expects sane var names like other lanugages)
		-- TODO: this is not necessarily a legitimate var name!
		local parts = string.split(var_name, " ")
		table.remove(parts, 1)
		local v_name = table.concat(parts, "_")
		-- stor it for later use
		vars_used[var_name] = v_name
		-- add the variable as a variable to INK
		table.insert(lines, "\nVAR ")
		table.insert(lines, v_name)
		table.insert(lines, " = false") -- start with undefined/nil (we don't know the stored value)
	end
	table.insert(lines, "\n")
	return vars_used
end


-- which preconditions and effects can be modelled in ink?
--
-- in singleplayer adventures, properties can be relevant as well;
-- in multiplayer, other players may affect the state of the property
--
-- *some* functions may be relevant here:
-- (but not for variables)
-- * compare a variable with a variable
-- * counted dialog option visits
-- * counted option visits
--
-- types "true" and "false" can be relevant later on

-- small helper function
local var_with_operator = function(liste, var_name, op, var_cmp_value, vars_used)
	-- visits are not stored as variables in ink
	if(not(vars_used[var_name])) then
		vars_used[var_name] = var_name
	end
	if(op == "~=") then
		op = "!="
	end
	if(op=="==" or op=="!=" or op==">=" or op==">" or op=="<=" or op==">") then
		table.insert(liste, tostring(vars_used[var_name]).." ".. op.." "..tostring(var_cmp_value))
	elseif(op=="not") then
		table.insert(liste, "not "..tostring(vars_used[var_name]))
	elseif(op=="is_set") then
		table.insert(liste, tostring(vars_used[var_name]))
	elseif(op=="is_unset") then
		table.insert(liste, tostring(vars_used[var_name]).." == false")
	end
	-- the following values for op cannot really be checked here and are not printed:
	--	 "more_than_x_seconds_ago","less_than_x_seconds_ago",
	--	 "quest_step_done", "quest_step_not_done"
end

yl_speak_up.export_to_ink.translate_precondition_list = function(dialog, preconditions, vars_used, use_prefix,
									dialog_names)
	-- collect preconditions that may work in ink
	local liste = {}
	-- variables may be used in preconditions
	for p_id, p in pairs(preconditions or {}) do
		if(p and p.p_type and p.p_type == "state") then
			-- state changes of variables may mostly work in ink as well
			var_with_operator(liste, p.p_variable, p.p_operator, p.p_var_cmp_value, vars_used)
		elseif(p and p.p_type and p.p_type == "property") then
			-- same with properties
			var_with_operator(liste, p.p_value,    p.p_operator, p.p_var_cmp_value, vars_used)
		elseif(p and p.p_type and p.p_type == "evaluate" and p.p_value == "counted_visits_to_option") then
			-- simulate the visit counter that ink has in yl_speak_up
			local tmp_var_name = use_prefix..p.p_param1
			if(dialog_names[tmp_var_name]) then
				tmp_var_name = use_prefix..dialog_names[tmp_var_name].."."..tostring(p.p_param2)
			else
				tmp_var_name = tmp_var_name..              "_"..tostring(p.p_param2)
			end
			var_with_operator(liste, tmp_var_name, p.p_operator, p.p_var_cmp_value, vars_used)
		elseif(p and p.p_type and p.p_type == "true") then
			table.insert(liste, p.p_type)
		elseif(p and p.p_type and p.p_type == "false") then
			table.insert(liste, p.p_type)
		end
	end
	return liste
end


-- small helper function
local set_var_to_value = function(liste, var_name_full, op, val, vars_used)
	if(not(vars_used[var_name_full])) then
		vars_used[var_name_full] = var_name_full
	end
	local var_name = vars_used[var_name_full]
	if(op == "set_to") then
		table.insert(liste, tostring(var_name).." = "..tostring(val))
	elseif(op == "unset") then
		-- TODO: there does not seem to be a none/nil type in the Ink language
		table.insert(liste, tostring(var_name).." = false ")
	elseif(op == "maximum") then
		table.insert(liste, tostring(var_name).." = max("..tostring(var_name)..", "..tostring(val))
	elseif(op == "minimum") then
		table.insert(liste, tostring(var_name).." = min("..tostring(var_name)..", "..tostring(val))
	elseif(op == "increment") then
		table.insert(liste, tostring(var_name).." = "..tostring(var_name).." + "..tostring(val))
	elseif(op == "decrement") then
		table.insert(liste, tostring(var_name).." = "..tostring(var_name).." - "..tostring(val))
	-- not supported: "set_to_current_time", "quest_step"
	end
end

yl_speak_up.export_to_ink.translate_effect_list = function(dialog, effects, vars_used)
	-- collect effects that may work in ink
	local liste = {}
	-- variables may be set in effects
	for r_id, r in pairs(effects or {}) do
		if(r and r.r_type and r.r_type == "state") then
			-- state changes of variables may mostly work in ink as well
			set_var_to_value(liste, r.r_variable, r.r_operator, r.r_var_cmp_value, vars_used)
		elseif(p and p.p_type and p.p_type == "property") then
			-- same with properties
			set_var_to_value(liste, r.r_value,    r.r_operator, r.r_var_cmp_value, vars_used)
		end
	end
	return liste
end


-- Note: use_prefix ought to be   tostring(n_id).."_"  or ""
yl_speak_up.export_to_ink_language = function(dialog, use_prefix)
	local start_dialog = yl_speak_up.get_start_dialog_id(dialog)
	if(not(start_dialog)) then
		start_dialog = "d_1"
        end
	if(use_d_name
	  and dialog.n_dialogs
	  and dialog.n_dialogs[start_dialog]
	  and dialog.n_dialogs[start_dialog].d_name) then
		start_dialog = dialog.n_dialogs[start_dialog].d_name
	else
		start_dialog = tostring(start_dialog)
	end

	-- prefix all dialog names with this;
	-- advantage: several NPC dialog exports can be combined into one inc game
	--            where the player can talk to diffrent NPC (which can have the
	--            same dialog names without conflict thanks to the prefix)
--	use_prefix = tostring(n_id).."_"
	if(not(use_prefix)) then
		use_prefix = ""
	end

	-- go to the main loop whenever the player ends the conversation with the NPC;
	-- this allows to create an additional dialog in INK where the player can then
	-- decide to talk to multiple NPC - or to continue his conversation with the
	-- same NPC
	local main_loop = use_prefix.."d_end"
	local tmp = {"-> ", main_loop,
		"\n=== ", main_loop, " ===",
		"\nWhat do you wish to do?",
		"\n+ Talk to ", tostring(dialog.n_npc or prefix or "-unknown-"), " -> ", use_prefix..tostring(start_dialog),
		"\n+ End -> END"}

	local vars_used = ink_export.print_variables_used(tmp, dialog)

	local sorted_d_list = yl_speak_up.get_dialog_list_for_export(dialog)
	-- d_got_item may contain alternate texts - so it is of intrest here
	-- (also links to other dialogs)
	if(dialog.n_dialogs["d_got_item"]) then
		table.insert(sorted_d_list, "d_got_item")
	end
	-- maybe not that useful to set up this one in inK; add it for completeness
	if(dialog.n_dialogs["d_trade"]) then
		table.insert(sorted_d_list, "d_trade")
	end

	-- make use of dialog names if wanted
	local dialog_names = {}
	for i, d_id in ipairs(sorted_d_list) do
		if(use_d_name) then
			local n = tostring(d_id)
			local d = dialog.n_dialogs[d_id]
			dialog_names[n] = (d.d_name or n)
		end
	end

	for i, d_id in ipairs(sorted_d_list) do
		-- store the knots for actions and effects here:
		local tmp2 = {}
		local d = dialog.n_dialogs[d_id]
		-- print the dialog knot, but without choices (those we add in the following loop)
		local this_knot_name = ink_export.print_dialog_knot(tmp, use_prefix, d_id, d, dialog_names)

		-- iterate over all options
		local sorted_o_list = yl_speak_up.get_sorted_options(dialog.n_dialogs[d_id].d_options or {}, "o_sort")
		for j, o_id in ipairs(sorted_o_list) do
			local o_data = d.d_options[o_id]

			local sorted_a_list = yl_speak_up.sort_keys(o_data.actions   or {})
			local sorted_e_list = yl_speak_up.sort_keys(o_data.o_results or {})

			-- we will get alternate_text from the dialog result later on
			local alternate_text_on_success = ""
			local target_dialog = nil
			-- what is the normal target dialog/divert (in ink language) of this dialog?
			for k, r_id in ipairs(sorted_e_list) do
				local r = o_data.o_results[r_id]
				if(r and r.r_type and r.r_type == "dialog") then
					target_dialog = tostring(r.r_value)
					alternate_text_on_success = r.alternate_text or ""
				end
			end

			-- iterate backwards through the effects and serach for on_failure;
			-- the first effect cannot be an on_failure effect because on_failure effects
			-- decide on failure/success of the *previous* effect
			for k = #sorted_e_list, 2, -1 do
				local r_id = sorted_e_list[k]
				local r = o_data.o_results[r_id]
				if(r and r.r_type and r.r_type == "on_failure") then
					local r_prev = o_data.o_results[sorted_e_list[k-1]]
					-- *after* this effect we still need to execute all the other
					-- remaining effects (read: add them as tag)
					alternate_text_on_success = ink_export.add_effect_tags(
									alternate_text_on_success,
									sorted_e_list, o_data.o_results, k)
					-- whatever dialog comes previously - the dialog, an action, or
					-- another on_failure dialog - needs to lead to this dialog
					target_dialog = ink_export.print_effect_knot(tmp2,
								use_prefix, d_id, o_id, start_dialog,
								r, r_prev,
								alternate_text_on_success, target_dialog,
								dialog_names)
					-- we have dealt with the alternate text (it will only be shown
					-- in the last on_failure dialog before we go to the target)
					alternate_text_on_success = ""
				end
			end

			-- add the remaining effects
			alternate_text_on_success = ink_export.add_effect_tags(
									alternate_text_on_success,
									sorted_e_list, o_data.o_results, 1)

			-- if it is an action knot then the effects have to go to the action knot
			local e_list = ink_export.translate_effect_list(dialog, o_data.o_results,
							vars_used)
			-- iterate backwards through the actions (though usually only one is supported)
			for k = #sorted_a_list, 1, -1 do
				local a_id = sorted_a_list[k]
				local a = o_data.actions[a_id]

				target_dialog = ink_export.print_action_knot(tmp2,
						use_prefix, d_id, o_id, start_dialog,
						a,
						alternate_text_on_success, target_dialog, dialog_names,
						e_list)
				-- has been dealt with
				alternate_text_on_success = ""
			end

			-- which preconditions can be translated to ink?
			local p_list = ink_export.translate_precondition_list(dialog, o_data.o_prerequisites,
							vars_used, use_prefix, dialog_names)

			-- what remains is to print the option/choice itself
			local o_text = o_data.o_text_when_prerequisites_met
			local o_prefix = ""
			if(d.o_random) then
				o_text = "[One of these options is randomly selected]"
				o_prefix = "randomly_"
			elseif(o_data.o_autoanswer) then
				o_text = "[Automaticly selected if preconditions are met]"
				o_prefix = "automaticly_"
			end
			-- if the target is an action knot: do not print the effect list as that belongs
			-- to the action knot!
			if(#sorted_a_list > 0) then
				e_list = {}
			end
			ink_export.print_choice(tmp,
					o_text, use_prefix, start_dialog,
					alternate_text_on_success, target_dialog,
					o_data.o_visit_only_once, -- print + (often) or * (only once)
					o_prefix..o_id, p_list, e_list, dialog_names)
			-- deal with o_grey_when_prerequisites_not_met (grey out this answer)
			if(   o_data.o_text_when_prerequisites_not_met
			  and o_data.o_text_when_prerequisites_not_met ~= ""
			  and o_data.o_grey_when_prerequisites_not_met
			  and o_data.o_grey_when_prerequisites_not_met == "true") then
				o_text = o_data.o_text_when_prerequisites_not_met
				-- this option cannot be selected - so choose d_end as target dialog
				ink_export.print_choice(tmp,
					o_text, use_prefix, start_dialog,
					alternate_text_on_success, "d_end",
					o_data.o_visit_only_once, -- print + (often) or * (only once)
					"grey_out_"..o_id, p_list, e_list, dialog_names)
			end
			-- Note: Showing an alternate text if the preconditions are not met is not
			--       covered here. It makes little sense for the NPC as the option appears
			--       but cannot be clicked. It exists for backward compatibility of old NPC
			--       on the Your Land server.
		end -- dealt with the option
		-- add way to end talking to the NPC
		ink_export.print_choice(tmp, "Farewell!", use_prefix, start_dialog,
						nil, "d_end", false, nil, dialog_names)

		-- add the knots for actions and effects for this dialog and all its options:
		for _, line in ipairs(tmp2) do
			table.insert(tmp, line)
		end
	end
	return table.concat(tmp, "")
end
