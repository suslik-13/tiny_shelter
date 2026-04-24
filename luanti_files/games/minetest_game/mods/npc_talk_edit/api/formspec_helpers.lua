
-- helper function:
-- create a formspec dropdown list with player names (first entry: Add player) and
-- an option to delete players from that list
-- Note: With the what_is_the_list_about-parameter, it is possible to handle i.e. variables as well
yl_speak_up.create_dropdown_playerlist = function(player, pname,
		table_of_names, index_selected,
		start_x, start_y, stretch_x, h, dropdown_name, what_is_the_list_about, delete_button_text,
		field_name_for_adding_player, explain_add_player,
		field_name_for_deleting_player, explain_delete_player)

	local text = "dropdown["..tostring(start_x)..","..tostring(start_y)..";"..
				tostring(3.8 + stretch_x)..","..tostring(h)..";"..
				tostring(dropdown_name)..";Add "..tostring(what_is_the_list_about)..":"
	-- table_of_names is a table with the playernames as keys
	-- we want to work with indices later on; in order to be able to do that reliably, we
	-- need a defined order of names
	local tmp_list = yl_speak_up.sort_keys(table_of_names, true)
	for i, p in ipairs(tmp_list) do
		text = text..","..minetest.formspec_escape(p)
	end
	-- has an entry been selected?
	if(not(index_selected) or index_selected < 0 or index_selected > #tmp_list+1) then
		index_selected = 1
	end
	text = text..";"..tostring(index_selected)..";]"
	if(index_selected == 1) then
		-- first index "Add player" selected? Then offer a field for entering the name
		text = text.."field["..tostring(start_x + 4.0 + stretch_x)..","..tostring(start_y)..
				";"..tostring(3.5 + stretch_x)..","..tostring(h)..";"..
				tostring(field_name_for_adding_player)..";;]"..
				"tooltip["..tostring(field_name_for_adding_player)..";"..
					tostring(explain_add_player).."]"
	else
		text = text.."button["..tostring(start_x + 3.8 + stretch_x)..","..tostring(start_y)..
				";"..tostring(3.4 + stretch_x)..","..tostring(h)..";"..
				tostring(field_name_for_deleting_player)..";"..
				tostring(delete_button_text).."]"..
				"tooltip["..tostring(field_name_for_deleting_player)..";"..
					tostring(explain_delete_player).."]"
	end
	return text
end



-- manages back, exit, prev, next, add_list_entry, del_entry_general
--
-- if a new entry is to be added, the following function that is passed as a parmeter
-- is called:
--	function_add_new_entry(pname, fields.add_entry_general)
-- expected return value: index of fields.add_entry_general in the new list
--
-- if an entry is to be deleted, the following function that is passed as a parameter
-- is called:
--	function_del_old_entry(pname, entry_name)
-- expected return value: text describing weather the removal worked or not
--
-- if any other fields are set that this function does not process, the following
-- function that is passed on as a parameter can be used:
--	function_input_check_fields(player, formname, fields, entry_name, list_of_entries)
-- expected return value: nil if the function found work; else entry_name
--
yl_speak_up.handle_input_fs_manage_general = function(player, formname, fields,
		what_is_the_list_about, min_length, max_length, function_add_new_entry,
		list_of_entries, function_del_old_entry, function_input_check_fields)
	local pname = player:get_player_name()
	local what = minetest.formspec_escape(what_is_the_list_about or "?")
	local fs_name = formname
	if(formname and string.sub(formname, 0, 12) == "yl_speak_up:") then
		formname = string.sub(formname, 13)
	end
	if(fields and fields.back_from_msg) then
		yl_speak_up.show_fs(player, formname, fields.stored_value_for_player)
		return
	end
	-- leave this formspec
	if(fields and (fields.quit or fields.exit or fields.back)) then
		local last_fs = yl_speak_up.speak_to[pname][ "working_at" ]
		local last_params = yl_speak_up.speak_to[pname][ "working_at_params" ]
		yl_speak_up.speak_to[pname].tmp_index_general = nil
		yl_speak_up.show_fs(player, last_fs, last_params)
		return
	-- add a new entry?
	elseif(fields and fields.add_list_entry) then
		local error_msg = ""
		if(not(fields.add_entry_general) or fields.add_entry_general == ""
		  or fields.add_entry_general:trim() == "") then
			error_msg = "Please enter the name of the "..what.." you want to create!"
		-- limit names to something more sensible
		elseif(string.len(fields.add_entry_general) > max_length) then
			error_msg = "The name of your new "..what.." is too long.\n"..
					"Only up to "..tostring(max_length).." characters are allowed."
		elseif(string.len(fields.add_entry_general:trim()) < min_length) then
			error_msg = "The name of your new "..what.." is too short.\n"..
					"It has to be at least "..tostring(min_length).." characters long."
		elseif(table.indexof(list_of_entries, fields.add_entry_general:trim()) > 0) then
			error_msg = "A "..what.." with the name\n     \""..
				minetest.formspec_escape(fields.add_entry_general:trim())..
				"\"\nexists already."
		else
			fields.add_entry_general = fields.add_entry_general:trim()
			-- this depends on what is created
			local res = function_add_new_entry(pname, fields.add_entry_general)
			-- not really an error msg here - but fascilitates output
			error_msg = "A new "..what.." named\n     \""..
				minetest.formspec_escape(fields.add_entry_general)..
				"\"\nhas been created."
			if(not(res) or (type(res) == "number" and res == -1)) then
				error_msg = "Failed to create "..what.." named\n      \""..
					minetest.formspec_escape(fields.add_entry_general).."\"."
			-- pass on any error messages
			elseif(type(res) == "string") then
				error_msg = res
			else
				-- select this new entry (add 1 because the first entry of our
				-- list is adding a new entry)
				yl_speak_up.speak_to[pname].tmp_index_general = res + 1
			end
		end
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formname,
			formspec = "size[10,2]"..
				"label[0.2,0.0;"..error_msg.."]"..
				"button[1.5,1.5;2,0.9;back_from_msg;Back]"})
		return
	-- scroll through the variables with prev/next buttons
	elseif(fields and (fields["prev"] or fields["next"])) then
		local index =  yl_speak_up.speak_to[pname].tmp_index_general
		if(not(index)) then
			yl_speak_up.speak_to[pname].tmp_index_general = 1
		elseif(fields["prev"] and index > 1) then
			yl_speak_up.speak_to[pname].tmp_index_general = index - 1
		elseif(fields["next"] and index <= #list_of_entries) then
			yl_speak_up.speak_to[pname].tmp_index_general = index + 1
		end
		yl_speak_up.show_fs(player, formname, fields.stored_value_for_player)
		return
	end

	-- an entry was selected in the dropdown list
	if(fields and fields.list_of_entries and fields.list_of_entries ~= "") then
		local index = table.indexof(list_of_entries, fields.list_of_entries)
		-- show the "Add <entry>:" entry
		if(fields.list_of_entries == "Add "..what..":") then
			index = 0
			yl_speak_up.speak_to[pname].tmp_index_general = 1
			yl_speak_up.show_fs(player, formname, fields.stored_value_for_player)
			return
		end
		if(index and index > -1) then
			yl_speak_up.speak_to[pname].tmp_index_general = index + 1
		end
	end
	local entry_name = list_of_entries[ yl_speak_up.speak_to[pname].tmp_index_general - 1]

	-- delete entry
	if(fields and ((fields.del_entry_general and fields.del_entry_general ~= ""))
	  and entry_name and entry_name ~= "") then
		local text = function_del_old_entry(pname, entry_name)
		yl_speak_up.show_fs(player, "msg", {
			input_to = "yl_speak_up:"..formname,
                        formspec = "size[10,2]"..
                                "label[0.2,0.0;Trying to delete "..what.." \""..
                                        minetest.formspec_escape(tostring(entry_name))..
                                        "\":\n"..text.."]"..
                                "button[1.5,1.5;2,0.9;back_from_msg;Back]"})
		return

	-- maybe the custom function knows what to do with this
	elseif(fields
	  and not(function_input_check_fields(player, formname, fields, entry_name, list_of_entries))) then
		-- the function_input_check_fields managed to handle this input
		return

	-- an entry was selected in the dropdown list
	elseif(entry_name and entry_name ~= "") then
		-- show the same formspec again, with a diffrent variable selected
		yl_speak_up.show_fs(player, formname)
		return
	end
	-- try to go back to the last formspec shown before this one
	if(not(yl_speak_up.speak_to[pname])) then
		return
	end
	local last_fs = yl_speak_up.speak_to[pname][ "working_at" ]
	local last_params = yl_speak_up.speak_to[pname][ "working_at_params" ]
	yl_speak_up.show_fs(player, last_fs, last_params)
end


-- inserts buttons into formspec which allow to select previous/next entry, to go back,
-- create new entries, delete entries and select entries from a dropdown menu;
-- returns the currently selected entry or nil (=create new entry)
-- Note: Designed for a formspec of size "size[18,12]"
yl_speak_up.build_fs_manage_general = function(player, param,
			formspec, list_of_entries,
			text_add_new, tooltip_add_new,
			what_is_the_list_about,
			tooltip_add_entry_general, tooltip_del_entry_general,
			optional_add_space)
	if(not(optional_add_space)) then
		optional_add_space = 0
	end
	local selected = nil
	local pname = player:get_player_name()
	-- the yl_speak_up.create_dropdown_playerlist function needs a table - not a list
	local table_of_entries = {}
	for i, k in ipairs(list_of_entries) do
		table_of_entries[ k ] = true
	end
	-- "Add variable:" is currently selected
	if(not(yl_speak_up.speak_to[pname].tmp_index_general)
	   or yl_speak_up.speak_to[pname].tmp_index_general == 1
	   or not(list_of_entries[ yl_speak_up.speak_to[pname].tmp_index_general - 1])) then
		yl_speak_up.speak_to[pname].tmp_index_general = 1
		table.insert(formspec,	"button[")
		table.insert(formspec,  tostring(12.2 + 2 * optional_add_space))
		table.insert(formspec,  ",2.15;")
		table.insert(formspec,  tostring(2.5 + 2 * optional_add_space))
		table.insert(formspec,  ",0.6;add_list_entry;")
		table.insert(formspec,	minetest.formspec_escape(text_add_new))
		table.insert(formspec,	"]")
		table.insert(formspec,	"tooltip[add_list_entry;")
		table.insert(formspec,	minetest.formspec_escape(tooltip_add_new))
		table.insert(formspec,	"]")
	else
		-- index 1 is "Add variable:"
		selected = list_of_entries[ yl_speak_up.speak_to[pname].tmp_index_general - 1]
	end
	if(yl_speak_up.speak_to[pname].tmp_index_general > 1) then
		table.insert(formspec,	"button[4.0,0.2;2.0,0.6;prev;< Prev]"..
					"button[4.0,11.0;2.0,0.6;prev;< Prev]")
	end
	if(yl_speak_up.speak_to[pname].tmp_index_general <= #list_of_entries) then
		table.insert(formspec,	"button[12.0,0.2;2.0,0.6;next;Next >]"..
					"button[12.0,11.0;2.0,0.6;next;Next >]")
	end
	table.insert(formspec, 		"button[0.0,0.2;2.0,0.6;back;Back]"..
					"button[8.0,11.0;2.0,0.6;back;Back]")
	local what = minetest.formspec_escape(what_is_the_list_about)
	table.insert(formspec,		"label[7.0,0.4;* Manage your ")
	table.insert(formspec,		what)
	table.insert(formspec,		"s *]")
	table.insert(formspec,		"label[0.2,2.45;Your ")
	table.insert(formspec,		what)
	table.insert(formspec,		":]")
	-- offer a dropdown list and a text input field for new varialbe names for adding
	table.insert(formspec,		yl_speak_up.create_dropdown_playerlist(
						player, pname,
						table_of_entries,
						yl_speak_up.speak_to[pname].tmp_index_general,
						2.6 + (optional_add_space), 2.15, 1.0, 0.6,
						"list_of_entries",
						what,
						"Delete selected "..what,
						"add_entry_general",
						minetest.formspec_escape(tooltip_add_entry_general),
						"del_entry_general",
						minetest.formspec_escape(tooltip_del_entry_general)
					))

	-- either nil or the text of the selected entry
	return selected
end



-- small helper function for the function below
yl_speak_up.get_sub_fs_colorize_table = function(formspec, table_specs, liste, color)
	table.insert(formspec, "tablecolumns[color;text]table[")
	table.insert(formspec, table_specs)
	local tmp = {}
	for k, v in pairs(liste) do
		table.insert(tmp, color or "#FFFFFF")
		table.insert(tmp, minetest.formspec_escape(v))
	end
	table.insert(formspec, table.concat(tmp, ","))
	table.insert(formspec, ";]")
end


yl_speak_up.get_sub_fs_show_list_in_box = function(formspec,
		label, field_name, liste, start_x, start_y, width, height, label_ident,
		box_color, column_color,
		tooltip_text, add_lines)
	local dim_str = tostring(width)..","..tostring(height)
	table.insert(formspec, "container[")
	table.insert(formspec, tostring(start_x)..","..tostring(start_y)..";")
	table.insert(formspec, dim_str)
	table.insert(formspec, "]")
	table.insert(formspec, "box[0,0;")
	table.insert(formspec, dim_str)
	table.insert(formspec, ";")
	table.insert(formspec, box_color or "#666666")
	table.insert(formspec, "]")
	-- add buttons etc. first so that the label remains visible on top
	if(add_lines) then
		table.insert(formspec, add_lines)
	end
	table.insert(formspec, "label[")
	table.insert(formspec, tostring(0.1 + label_ident))
	table.insert(formspec, ",0.5;")
	table.insert(formspec, label)
	table.insert(formspec, "]")
	yl_speak_up.get_sub_fs_colorize_table(formspec,
		"0.1,0.7;"..tostring(width-0.2)..","..tostring(height-0.8)..";"..tostring(field_name)..";",
		liste or {}, column_color)
	if(tooltip_text and tooltip_text ~= "") then
		table.insert(formspec, "tooltip[")
		table.insert(formspec, field_name)
		table.insert(formspec, ";")
		table.insert(formspec, tooltip_text)
		table.insert(formspec, "\n\nClick on an element to select it.")
		table.insert(formspec, "]")
	end
	table.insert(formspec, "container_end[]")
end
