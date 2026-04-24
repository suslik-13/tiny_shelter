-- helpful for debugging the content/texts of the created dialog structure

yl_speak_up.input_show_what_points_to_this_dialog = function(player, formname, fields)
	local pname = player:get_player_name()
	if(fields.back_from_show_what_points_here
	  or not(fields.turn_dialog_into_alternate_text)) then
		-- back to the dialog
		yl_speak_up.show_fs(player, "talk",
			{n_id = yl_speak_up.speak_to[pname].n_id,
			 d_id = yl_speak_up.speak_to[pname].d_id})
		return
	end
	-- fields.turn_dialog_into_alternate_text is set
	local n_id = yl_speak_up.speak_to[pname].n_id
	local this_dialog = yl_speak_up.speak_to[pname].d_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(dialog)
	  or not(dialog.n_dialogs)
	  or not(this_dialog)
	  or not(dialog.n_dialogs[ this_dialog ])) then
		return
	end
	-- only show this information when editing this npc
	if(yl_speak_up.edit_mode[pname] ~= yl_speak_up.speak_to[pname].n_id) then
		return
	end
	-- find out what needs to be turned into an alternate dialog
	local found = {}
	-- how many options does the current dialog have?
	local count_options = 0
	-- iterate over all dialogs
	for d_id, d in pairs(dialog.n_dialogs) do
		-- the dialog itself may have options that point back to the dialog itself
		if(d.d_options) then
			-- iterate over all options
			for o_id, o in pairs(d.d_options) do
				-- this is only possible if there are no options for this dialog
				if(d_id == this_dialog) then
					count_options = count_options + 1
				end
				-- preconditions are not relevant;
				-- effects are (dialog and on_failure)
				if(o.o_results) then
					for r_id, r in pairs(o.o_results) do
						if(r and r.r_type and r.r_type == "dialog"
						  and r.r_value == this_dialog) then
							table.insert(found, {d_id=d_id, o_id=o_id, id=r_id,
								element=r, text="option was selected"})
						elseif(r and r.r_type and r.r_type == "on_failure"
						  and r.r_value == this_dialog) then
							table.insert(found, {d_id=d_id, o_id=o_id, id=r_id,
								element=r, text="the previous effect failed"})
						end
					end
				end
				-- actions may be relevant
				if(o.actions) then
					for a_id, a in pairs(o.actions) do
						if(a and a.a_on_failure
						  and a.a_on_failure == this_dialog) then
							table.insert(found, {d_id=d_id, o_id=o_id, id=a_id,
								element=a, text="action failed"})
						end
					end
				end
			end
		end
	end

	local error_msg = ""
	if(count_options > 0) then
		error_msg = "This dialog still has dialog options.\nConversion not possible."
	elseif(#found < 1) then
		error_msg = "Found no option, action or effect\nthat points to this dialog."
	elseif(#found > 1) then
		error_msg = "Found more than one option, action\nor effect that points to this dialog."
	end
	if(error_msg ~= "") then
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:show_what_points_to_this_dialog",
			formspec = "size[8,2]"..
				"label[0.2,0.5;Error: "..error_msg.."]"..
				"button[1.5,1.5;2,0.9;back_from_error_msg;Back]"})
		return
	end

	-- all fine so far; this is the text we want to set as alternate text
	local d_text = dialog.n_dialogs[ this_dialog ].d_text
	local f = found[1]
	-- are we dealing with a result/effect or an action?
	t = "o_results"
	if(f.element.a_id) then
		t = "actions"
	end
	-- there may already be an alternate text stored there
	local alternate_text = dialog.n_dialogs[ f.d_id ].d_options[ f.o_id ][ t ][ f.id ].alternate_text
	if(not(alternate_text)) then
		-- no old text found
		alternate_text = d_text
	else
		-- the old text may reference this d_text
		alternate_text = string.gsub(alternate_text, "%$TEXT%$", d_text)
	end
	-- log the change
	table.insert(yl_speak_up.npc_was_changed[ n_id ],
		"Dialog "..tostring(this_dialog)..": Deleted this dialog and turned it into an "..
		"alternate text for dialog \""..tostring(f.d_id).."\" option \""..tostring(f.o_id)..
		"\" element \""..tostring(f.id).."\".")

	-- actually set the new alternate_text
	dialog.n_dialogs[ f.d_id ].d_options[ f.o_id ][ t ][ f.id ].alternate_text = alternate_text
	-- delete this dialog
	dialog.n_dialogs[ this_dialog ] = nil
	-- we need to show a new/diffrent dialog to the player now - because the old one was deleted
	yl_speak_up.speak_to[pname].d_id = f.d_id
	yl_speak_up.speak_to[pname].o_id = f.o_id
	if(t == "o_results") then
		-- we can't really know where this ought to point to - the old dialog is gone, so
		-- let's point to the current dialog to avoid errors
		dialog.n_dialogs[ f.d_id ].d_options[ f.o_id ][ t ][ f.id ].r_value = f.d_id
		-- dialog - normal switching to the next dialog or on_failure - the previous effect failed:
		yl_speak_up.show_fs(player, "edit_effects", f.id)
	else
		-- the player may have to change this manually; we really can't know what would fit
		-- (but the old dialog is gone)
		dialog.n_dialogs[ f.d_id ].d_options[ f.o_id ][ t ][ f.id ].a_on_failure = f.d_id
		-- an action failed:
		yl_speak_up.show_fs(player, "edit_actions", f.id)
	end
end


-- show which dialogs point/lead to this_dialog
yl_speak_up.get_fs_show_what_points_to_this_dialog = function(player, this_dialog)
	local pname = player:get_player_name()
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(dialog)
	  or not(dialog.n_dialogs)
	  or not(this_dialog)
	  or not(dialog.n_dialogs[ this_dialog ])) then
		return ""
	end

	-- only show this information when editing this npc
	if(yl_speak_up.edit_mode[pname] ~= yl_speak_up.speak_to[pname].n_id) then
		return ""
	end
	local found = {}
	-- colored lines for the table showing the results
	local res = {}
	-- iterate over all dialogs
	for d_id, d in pairs(dialog.n_dialogs) do
		-- the dialog itself may have options that point back to the dialog itself
		if(d.d_options) then
			-- iterate over all options
			for o_id, o in pairs(d.d_options) do
				local r_text = ""
				local p_text = ""
				local alternate_dialog = nil
				local alternate_text = nil
				-- preconditions are not relevant;
				-- effects are (dialog and on_failure)
				if(o.o_results) then
					for r_id, r in pairs(o.o_results) do
						if(r and r.r_type and r.r_type == "dialog"
						  and r.r_value == this_dialog) then
							r_text = r_text..yl_speak_up.print_as_table_effect(
										r, pname)
							table.insert(found, {d_id, o_id, r_id,
								"option was selected"})
							alternate_dialog = r.r_value
							if(r.alternate_text) then
								alternate_text =
									"Show alternate text: "..
									tostring(r.alternate_text)
							end
						elseif(r and r.r_type and r.r_type == "on_failure"
						  and r.r_value == this_dialog) then
							r_text = r_text..yl_speak_up.print_as_table_effect(
										r, pname)
							table.insert(found, {d_id, o_id, r_id,
								"the previous effect failed"})
							alternate_dialog = r.r_value
							alternate_text = "The previous effect failed. "
							if(r.alternate_text) then
								alternate_text = alternate_text..
									"Show alternate text: "..
									tostring(r.alternate_text)
							else
								alternate_text = alternate_text..
									"Show this dialog here."
							end
						end
					end
				end
				-- actions may be relevant
				if(o.actions) then
					for a_id, a in pairs(o.actions) do
						if(a and a.a_on_failure
						  and a.a_on_failure == this_dialog) then
							p_text = p_text..yl_speak_up.print_as_table_action(
										a, pname)
							table.insert(found, {d_id, o_id, a_id,
								"action failed"})
							alternate_dialog = a.a_on_failure
							alternate_text = "The action failed. "
							if(a.alternate_text) then
								alternate_text = alternate_text..
									"Show this alternate text: "..
									tostring(a.alternate_text)
							else
								alternate_text = alternate_text..
									"Show this dialog here."
							end
						end
					end
				end
				yl_speak_up.print_as_table_dialog(p_text, r_text, dialog,
					dialog.n_id, d_id, o_id,
					-- sort value: formed by dialog and option id (not perfect but
					-- good enough)
					res, o, tostring(d_id).." "..tostring(o_id),
					alternate_dialog, alternate_text)
			end
		end
	end

	local d_id = this_dialog
	local formspec = yl_speak_up.print_as_table_prepare_formspec(res, "table_of_dialog_uses",
		"back_from_show_what_points_here", "Back to dialog \""..tostring(d_id).."\"")
	table.insert(formspec,
		"label[20.0,1.8;Dialog \""..minetest.formspec_escape(this_dialog)..
				"\" is referenced here:]")
	if(#found ~= 1) then
		table.insert(formspec,
			"label[16.0,31.0;"..
				minetest.formspec_escape("This dialog \""..tostring(d_id)..
					"\" can be reached from "..
					minetest.colorize("#FFFF00", tostring(#found))..
					" options/actions/results.").."]")
	else
		table.insert(formspec,
                        "button[0.2,30.6;56.6,1.2;turn_dialog_into_alternate_text;"..
                                minetest.formspec_escape("Turn this dialog \""..
                                        tostring(d_id)).."\" into an alternate text.]")
	end
	return table.concat(formspec, "\n")
end


yl_speak_up.register_fs("show_what_points_to_this_dialog",
	yl_speak_up.input_show_what_points_to_this_dialog,
	yl_speak_up.get_fs_show_what_points_to_this_dialog,
	-- no special formspec required:
	nil
)
