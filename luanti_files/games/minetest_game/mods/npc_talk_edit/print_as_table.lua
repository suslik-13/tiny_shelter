-- helper function
yl_speak_up.wrap_long_lines_for_table = function(text, prefix, line_length, max_lines)
	-- show newlines as <\n> in order to save space
	local text = (text or "?")
	text = string.gsub(text, "\n", minetest.formspec_escape("<br>"))
	-- break the text up into lines of length x
	local parts = minetest.wrap_text(text, line_length, true)
	if(not(parts) or #parts < 2) then
		return minetest.formspec_escape(text)
	end
	local show_parts = {}
	-- only show the first two lines (we don't have infinite room)
	for i, p in ipairs(parts) do
		if(i <= max_lines) then
			table.insert(show_parts, minetest.formspec_escape(p))
		end
	end
	if(#parts > max_lines) then
		return table.concat(show_parts, prefix)..minetest.formspec_escape(" [...]")
	end
	return table.concat(show_parts, prefix)
end


-- helper functions for yl_speak_up.fs_get_list_of_usage_of_variable
-- and yl_speak_up.show_what_points_to_this_dialog
yl_speak_up.print_as_table_precon = function(p, pname)
	return ",#FFFF00,"..
		minetest.formspec_escape(tostring(p.p_id))..
		",#FFFF00,pre(C)ondition,#FFFF00,"..
		minetest.formspec_escape(p.p_type)..",#FFFF00,"..
		minetest.formspec_escape(yl_speak_up.show_precondition(p, pname))
end


yl_speak_up.print_as_table_effect = function(r, pname)
	return ",#55FF55,"..
		minetest.formspec_escape(tostring(r.r_id))..
		",#55FF55,(Ef)fect,#55FF55,"..
		minetest.formspec_escape(r.r_type)..",#55FF55,"..
		minetest.formspec_escape(yl_speak_up.show_effect(r, pname))
end


yl_speak_up.print_as_table_alternate_text = function(where_used, col1, col2, alternate_text)
	if(not(alternate_text) or alternate_text == "") then
		return ""
	end
	return  ",#777777,"..minetest.formspec_escape(where_used or "")..
		",#777777,"..minetest.formspec_escape(col1 or "")..
		",#777777,"..minetest.formspec_escape(col2 or "")..
		",#777777,"..minetest.formspec_escape(alternate_text)
end


yl_speak_up.print_as_table_action = function(a, pname)
	return ",#FF9900,"..
		minetest.formspec_escape(tostring(a.a_id))..
		",#FF9900,(A)ction,#FF9900,"..
		minetest.formspec_escape(a.a_type)..",#FF9900,"..
		-- these lines can get pretty long when a description for a quest item is set
		yl_speak_up.wrap_long_lines_for_table(
			yl_speak_up.show_action(a, pname),
			",#FFFFFF,,#FFFFFF,,#FFFFFF,,#FF9900,",
			80, 4)
end


yl_speak_up.print_as_table_dialog = function(p_text, r_text, dialog, n_id, d_id, o_id, res, o, sort_value,
		alternate_dialog, alternate_text)
	if(p_text == "" and r_text == "" ) then
		return
	end
	local d_text = yl_speak_up.wrap_long_lines_for_table(
		dialog.n_dialogs[ d_id ].d_text or "?",
		",#FFFFFF,,#FFFFFF,,#FFFFFF,,#BBBBFF,",
		80, 3)
	if(not(alternate_dialog) or not(alternate_text)) then
		alternate_text = ""
	else
		alternate_text = ",#BBBBFF,"..minetest.formspec_escape(tostring(alternate_dialog))..
				-- show alternate text in a diffrent color
				",#BBBBFF,Dialog,#BBBBFF,says next:,#FFBBBB,"..
				 yl_speak_up.wrap_long_lines_for_table(
					alternate_text,
					",#FFFFFF,,#FFFFFF,,#FFFFFF,,#FFBBBB,",
					80, 3)
	end
	res[ tostring(n_id).." "..tostring(d_id).." "..tostring(o_id) ] = {
		text =  "#6666FF,"..
			tostring(n_id)..",#6666FF,NPC,#6666FF,named:,#6666FF,"..
			minetest.formspec_escape(dialog.n_npc or "?")..","..
			"#BBBBFF,"..
			tostring(d_id)..",#BBBBFF,Dialog,#BBBBFF,says:,#BBBBFF,"..
			d_text..","..
			"#FFFFFF,"..
			tostring(o_id)..",#FFFFFF,Option,#FFFFFF,A:,#FFFFFF,"..
			minetest.formspec_escape(tostring(o.o_text_when_prerequisites_met or "?"))..
			p_text..r_text..
			alternate_text,
		sort_value = sort_value}
end


yl_speak_up.print_as_table_prepare_formspec = function(res, table_name, back_button_name, back_button_text,
		is_already_sorted, concat_with, table_columns)
	local sorted_res = {}
	-- this is the default for "show where a variable is used"
	if(not(is_already_sorted)) then
		local sorted_list = yl_speak_up.get_sorted_options(res, "sort_value")
		for i, k in pairs(sorted_list) do
			table.insert(sorted_res, res[ k ].text)
		end
		table_columns = "color,span=1;text;color,span=1;text;color,span=1;text;color,span=1;text"
	else
		sorted_res = res
	end
	if(not(concat_with)) then
		-- insert blank lines between lines belonging together
		concat_with = ",#FFFFFF,,#FFFFFF,,#FFFFFF,,#FFFFFF,,"
	end
	local formspec = {
		"size[57,33]",
		-- back to the list with that one precondition or effect
		"button[0.2,0.2;56.6,1.2;"..back_button_name..";"..
			minetest.formspec_escape(back_button_text).."]",
		"button[0.2,31.6;56.6,1.2;"..back_button_name..";"..
			minetest.formspec_escape(back_button_text).."]",
		"tablecolumns["..tostring(table_columns).."]",
	}
	table.insert(formspec,
		"table[1.2,2.4;55.0,28.0;"..tostring(table_name)..";"..
		table.concat(sorted_res, concat_with).."]")
	return formspec
end
