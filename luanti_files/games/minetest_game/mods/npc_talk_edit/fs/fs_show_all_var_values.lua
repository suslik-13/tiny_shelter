
-- called only by mange_variables formspec
yl_speak_up.fs_show_all_var_values = function(player, pname, var_name)
	-- wrong parameters? no need to show an error message here
	if(not(var_name) or not(pname) or not(player)) then
		return ""
	end
	-- TODO: check if the player really has read access to this variable
	var_name = yl_speak_up.restore_complete_var_name(var_name, pname)

	-- player names with values as key; normally the player name is the key and
	-- the value the value - but that would be a too long list to display, and
	-- so we rearrange the array for display here
	local players_with_value = {}
	-- the diffrent values that exist
	local values = {}
	local var_data = yl_speak_up.player_vars[ var_name ]
	local count_players = 0
	for player_name, v in pairs(var_data) do
		-- metadata is diffrent and not of relevance here
		if(player_name and player_name ~= "$META$" and v) then
			if(not(players_with_value[ v ])) then
				players_with_value[ v ] = {}
				table.insert(values, v)
			end
			table.insert(players_with_value[ v ], player_name)
			count_players = count_players + 1
		end
	end
	-- the values ought to be shown in a sorted way
	table.sort(values)

	-- construct the lines that shall form the table
	local lines = {"#FFFFFF,Value:,#FFFFFF,Players for which this value is stored:"}
	for i, v in ipairs(values) do
		table.insert(lines,
			"#FFFF00,"..minetest.formspec_escape(v)..",#CCCCCC,"..
			-- text, prefix, line_length, max_lines
			yl_speak_up.wrap_long_lines_for_table(
				table.concat(players_with_value[ v ], ", "),
				",,,#CCCCCC,", 80, 8))
	end
	-- true here means: lines are already sorted;
	-- ",": don't insert blank lines between entries
	local formspec = yl_speak_up.print_as_table_prepare_formspec(lines, "table_of_variable_values",
				"back_from_msg", "Back", true, ",",
				"color,span=1;text;color,span=1;text") -- the table columns
	table.insert(formspec,
		"label[18.0,1.8;"..
			minetest.formspec_escape("For variable \""..
				minetest.colorize("#FFFF00", tostring(var_name or "- ? -"))..
				"\", these values are stored:").."]")

	if(values and #values > 0) then
		table.insert(formspec,
			"label[18.0,31.0;The variable holds "..
				minetest.colorize("#FFFF00", tostring(#values)).." diffrent values for "..
				minetest.colorize("#FFFF00", tostring(count_players)).." diffrent players.]")
	else
		table.insert(formspec,
			"label[18.0,31.0;The variable does not currently hold any stored values.]")
	end
	return table.concat(formspec, "\n")
end
