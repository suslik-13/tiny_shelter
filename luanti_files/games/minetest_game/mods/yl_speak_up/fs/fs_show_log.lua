-- show logfile of the NPC to the player

yl_speak_up.input_show_log = function(player, formname, fields)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		return
	end
	if(fields.show_trade_log) then
		yl_speak_up.show_fs(player, "show_log", {log_type = "trade"})
	elseif(fields.show_full_log) then
		yl_speak_up.show_fs(player, "show_log", {log_type = "full"})
	elseif(fields.back_to_trade) then
		yl_speak_up.show_fs(player, "trade_list")
	elseif(fields.back_to_talk) then
		yl_speak_up.show_fs(player, "talk")
	end
	return
end


-- helper function for get_fs_show_log
--   text: list of string
yl_speak_up.show_log_add_line = function(text, last_day, last_who, last_line, same_lines, entry_type, log_type)
	local line = {}
	-- split the line up so that it can actually be read
	local multiline = minetest.wrap_text(last_line, 75, true)
	for i, p in ipairs(multiline) do
		if(i == 1) then
			table.insert(line, '#AAAAAA')
			table.insert(line, minetest.formspec_escape(last_day))
			table.insert(line, '#FFFF00')
			table.insert(line, minetest.formspec_escape(last_who))
			table.insert(line, '#AAAAAA')
			if(same_lines > 1) then
				table.insert(line, tostring(same_lines).."x")
			else
				table.insert(line, "")
			end
		else
			-- do not repeat all the other entries - we just continue text
			table.insert(line, '#AAAAAA,,#FFFF00,,#AAAAAA,')
		end
		if(entry_type and entry_type == "bought") then
			--table.insert(line, '#FF0000') -- red
			--table.insert(line, '#00FF00') -- green
			--table.insert(line, '#0000FF') -- blue
			--table.insert(line, '#FFFF00') -- yellow
			--table.insert(line, '#00FFFF') -- cyan
			--table.insert(line, '#FF00FF') -- magenta
			table.insert(line, '#00FF00') -- green
		elseif(entry_type and entry_type == "takes") then
			table.insert(line, '#FF6600') -- orange
		elseif(entry_type and entry_type == "adds") then
			table.insert(line, '#FFCC00') -- orange
		elseif(entry_type and (entry_type == "buy_if_less" or entry_type == "sell_if_more")) then
			table.insert(line, '#00FFFF') -- cyan
		elseif(entry_type and entry_type == "Trade:") then
			table.insert(line, '#00BBFF') -- darker cyan
		elseif(log_type and log_type == 'trade') then
			-- don't show this line if only trade lines are beeing asked for
			return
		elseif(entry_type and entry_type == "error:") then
			table.insert(line, '#FF4444') -- bright red
		else
			table.insert(line, '#FFFFFF')
		end
		table.insert(line, minetest.formspec_escape(p))
	end
	table.insert(text, table.concat(line, ','))
end


-- allow to toggle between trade entries and full log
yl_speak_up.get_fs_show_log = function(player, log_type)
	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		return "size[5,1]label[0,0;Error: You do not own this NPC.]"
	end

	local log_type_desc = "Full"
	local log_type_switch = "show_trade_log;Show trade log"
	local back_link = "back_to_talk;Back to talk"
	if(log_type == "trade") then
		log_type_desc = "Trade"
		log_type_switch = "show_full_log;Show full log"
		back_link = "back_to_trade;Back to trade"
	end
	local file, err = io.open(yl_speak_up.worldpath..yl_speak_up.log_path..DIR_DELIM..
					"log_"..tostring(n_id)..".txt", "r")
	local formspec = {'size[18,12]'..
			'button[0.5,11.1;17,0.8;',
				back_link,
				']'..
			'label[4.5,0.5;'..log_type_desc..' Log of ',
				minetest.formspec_escape(tostring(dialog.n_npc)..
							" [ID: "..tostring(n_id).."]"),
				']',
			'button[0.5,0.1;3,0.8;',
				log_type_switch,
				']',
			'tablecolumns[' ..
				'color;text,align=left;'..	-- the date
				'color;text,align=center;'..	-- name of the player
				'color;text,align=right;'..	-- how many times the entry was repeated
				'color;text,align=left]'..	-- actual log file entry
			'table[0.1,1.0;17.8,9.8;show_log_of_npc;'..
				'#FFFFFF,Date,#FFFFFF,Player,#FFFFFF,,#FFFFFF,',
			}
	-- without the time information, some entries (in particular when someone buys from a shpo)
	-- may be the same. Those entries are combined into one when viewing the log.
	local text = {}
	local last_line = ""
	local last_day = ""
	local last_who = ""
	local same_lines = 0
	local count = 0
	if(err) then
		-- we don't want to get too much into detail here for players
		return "size[5,1]label[0,0;Error reading NPC logfile.]"
	else
		local last_entry_type = ""
		for line in file:lines() do
			local parts = string.split(line, " ")
			-- suppress the time information as that would be too detailled;
			-- it is still logged so that admins can check
			local this_line = table.concat(parts, " ", 4)
			if(this_line == last_line and parts[1] == last_day
			  and #parts > 3 and parts[3] == last_who) then
				-- just count the line
				same_lines = same_lines + 1
			else
				yl_speak_up.show_log_add_line(text, last_day, last_who, last_line, same_lines,
					last_entry_type, log_type)
				-- store information about the next line
				same_lines = 0
				last_line = this_line
				last_day = parts[1]
				last_who = parts[3]
				last_entry_type = parts[4]
			end
			count = count + 1
		end
		-- cover the last line
		yl_speak_up.show_log_add_line(text, last_day, last_who, last_line, same_lines, last_entry_type, log_type)
		file:close()

		-- reverse the order so that new entries are on top (newer entries are more intresting)
		local reverse_text = {}
		for part = #text, 1, -1 do
			table.insert(reverse_text, text[part])
		end
		table.insert(formspec, minetest.formspec_escape('Log entry, newest first, '..
					tostring(#text)..' entries:')..",")
		table.insert(formspec, table.concat(reverse_text, ','))
	end

	-- selected row
	table.insert(formspec, ";1]")
	return table.concat(formspec, '')
end

yl_speak_up.get_fs_show_log_wrapper = function(player, param)
	if(not(param)) then
		param = {}
	end
	return yl_speak_up.get_fs_show_log(player, param.log_type)
end


yl_speak_up.register_fs("show_log",
	yl_speak_up.input_show_log,
	yl_speak_up.get_fs_show_log_wrapper,
	-- no special formspec required:
	nil
)
