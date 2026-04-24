-- create the table for the functions:
yl_speak_up.parse_ink = {}
-- add a local abbreviation:
local parse_ink = yl_speak_up.parse_ink

-- remove leading and tailing blanks, spaces, tabs, newlines and equal signs from names
-- of knots and stitches;
-- helper function for the parser
parse_ink.strip_name = function(s)
	local CHAR_EQUAL   = string.byte("=", 1)
	local CHAR_BLANK   = string.byte(" ", 1)
	local CHAR_TAB     = string.byte("\t", 1)
	local CHAR_NEWLINE = string.byte('\n', 1)
	local i = 1
	local k = string.len(s)
	local b = string.byte(s, i)
	while(i < k and (b==CHAR_EQUAL or b==CHAR_BLANK or b==CHAR_TAB or b==CHAR_NEWLINE)) do
		i = i + 1
		b = string.byte(s, i)
	end
	b = string.byte(s, k)
	while(k > i and (b==CHAR_EQUAL or b==CHAR_BLANK or b==CHAR_TAB or b==CHAR_NEWLINE)) do
		k = k - 1
		b = string.byte(s, k)
	end
	return string.sub(s, i, k)
end


-- the actual parser for ink (more or less)
parse_ink.parse = function(text, print_debug)
	-- just an abbreviation
	local strip_name = parse_ink.strip_name
	-- this is what this function shall find:
	local knots = {}

	-- first: scan for things that have to start at the *beginning* of a line;
	-- this limitation may or may not be part of ink (hard to tell), but it does
	-- make parsing a lot easier while not imposing an undue limitation on writers

	-- optional whitespaces/tabs are allowed;
	local CHAR_NEWLINE = string.byte('\n', 1)
	-- whitespace characters
	local CHAR_BLANK   = string.byte(" ", 1)
	local CHAR_TAB     = string.byte("\t", 1)
	-- allow to escape things at the start of a line
	local CHAR_ESCAPE  = string.byte("\\", 1)

	-- covers "* " choices and "*/" end of multiline comment
	local CHAR_STAR    = string.byte("*", 1)
	local CHAR_SLASH   = string.byte("/", 1)
	local CHAR_PLUS    = string.byte("+", 1)
	local CHAR_MINUS   = string.byte("-", 1)
	-- for diverts
	local CHAR_GREATER = string.byte(">", 1)
	-- for text that is gluecd together
	local CHAR_SMALLER = string.byte("<", 1)
	-- == for knots;  = for stitches
	local CHAR_EQUAL   = string.byte("=", 1)
	-- for code:
	local CHAR_TILDE   = string.byte("~", 1)
	-- for INCLUDE
	local CHAR_I       = string.byte("I", 1)
	-- for VAR
	local CHAR_V       = string.byte("V", 1)
	-- for CONST
	local CHAR_C       = string.byte("C", 1)

	-- detect labels at the start of choices and gathers
	local CHAR_LABEL_START = string.byte("(", 1)
	local CHAR_LABEL_END   = string.byte(")", 1)

	-- this is used for a lot of things:
	-- * printing values for variables
	-- * checking conditions
	-- * if/else and switch statements - which may even cover multiple lines
	-- * alternatives, cycles, shuffles etc.
	local CHAR_COND_START  = string.byte("{", 1)
	local CHAR_COND_END    = string.byte("}", 1)

	local i = 1
	local i_max = string.len(text)
	local at_line_start = false
	-- TODO: turn that into constants?
	local what = ""
	local last_what = ""
	local multiline_comment = false
	local inline_comment = false
	-- knots and stitches have names
	local search_for_name = nil
	local name_found = nil
	local search_for_nesting = nil
	-- choices and gathers can be nested
	local nested = 0
	local last_nested = 0
	local search_for_label = nil
	-- choices and gathers can have labels
	local label_start = -1
	local label_found = nil
	-- choices can have conditions
	local search_for_condition = nil
	local cond_start = -1
	local conditions = {}
	-- the actual text/content of a choice or gather
	local content = ""
	-- we start with text (usually a divert to the main knot)
	local content_start = 1
	-- the main program text...not a knot at the start
	local content_type = "MAIN_PROGRAM"
	local last_content_type = content_type
	-- we need to know if we're inside a mutiline condition or alternative
	local counted_curly_brackets = 0
	
	local started_at = 1 -- used for printing out the line for debugging
	while(i < i_max) do
		local b = string.byte(text, i)
		if(    b == CHAR_NEWLINE) then
			-- this is text (from node, stitch, gather, choice) that spans more than
			-- one line
			if(not(multiline_comment)
			  and not(inline_comment)) then
				content = content..string.sub(text, content_start, i)
			end
			if(search_for_name) then
				name_found = content
				content = ""
				search_for_name = false
			end
			-- the content of this line may become relevant
			content_start = i + 1

			at_line_start = true


			if(print_debug) then
				print("|LINE| "..string.sub(text, started_at, i - 1))
			end
			if(what == "START_OF_MULTILINE_COMMENT") then
				what = "INSIDE_MULTILINE_COMMENT"
			else
				what = ""
			end

			started_at = i + 1
			-- inline comments end here
			inline_comment = false
			search_for_nesting = nil
			search_for_label = nil
			search_for_condition = nil
			search_for_name = nil
		elseif(multiline_comment) then
			-- nothing can start inside a multilne comment apart from it ending
			-- (we only allow multiline comments to start and end in their own lines,
			--  not inside other texts or structures)
			if(b == CHAR_STAR and string.byte(text, i + 1) == CHAR_SLASH) then
				what = "END_OF_MULTILINE_COMMENT"
				multiline_comment = false
				-- just to be sure that the rest of the line is really skipped
				inline_comment = true
				at_line_start = false
			end
		-- TODO: handle inline comments
		elseif(not(at_line_start)) then
			-- choices and gathers can be nested
			if(search_for_nesting) then
				-- a divert -> is following a gather -
				if((b == CHAR_MINUS and string.byte(text, i + 1) == CHAR_GREATER)
				   -- if escaped: no point searching for label or conditions
				   or b == CHAR_ESCAPE) then
					search_for_nesting = nil
					search_for_label = nil
					search_for_condition = nil
				elseif(b == search_for_nesting) then
					nested = nested + 1
				elseif(b ~= CHAR_BLANK and b ~= CHAR_TAB) then
					search_for_nesting = nil
					-- choices (* and +) and gathers (-) may be followed by a (label):
					if(b == CHAR_LABEL_START) then
						label_start = i + 1
						search_for_label = CHAR_LABEL_END
					-- if no label: did we find the start of a condition already?
					elseif(b == CHAR_COND_START)
					   and (what == "NORMAL_CHOICE" or what == "STICKY_CHOICE") then
						cond_start = i + 1
						search_for_condition = CHAR_COND_END
					else
						content_start = i
						content = ""
					end
				end
			elseif(search_for_label and search_for_label == CHAR_LABEL_END) then
				if(b == CHAR_LABEL_END) then
					label = string.sub(text, label_start, i-1)
					search_for_label = nil
					if(what == "NORMAL_CHOICE" or what == "STICKY_CHOICE") then
						search_for_condition = CHAR_COND_START
					end
					content_start = i + 1
					content = ""
				end

			-- choices can have multiple conditions (at least they are not multiline)
			elseif(search_for_condition and search_for_condition == CHAR_COND_START) then
				if(b == CHAR_COND_START) then
					cond_start = i + 1
					search_for_condition = CHAR_COND_END
				elseif(b ~= CHAR_BLANK and b ~= CHAR_TAB) then
					-- no condition found
					cond_start = -1
					search_for_condition = nil
					-- next we get the actual text of the choice or gather
					content_start = i
					content = ""
				end
			elseif(search_for_condition and search_for_condition == CHAR_COND_END) then
				if(b == CHAR_COND_END) then
					table.insert(conditions, string.sub(text, cond_start, i-1))
					cond_start = -1
					-- there may be more conditions comming
					search_for_condition = CHAR_COND_START
				end
			end

			-- not at line start: multiline alternatives or conditions
			if(b == CHAR_COND_START and string.byte(text, i - 1) ~= CHAR_ESCAPE) then
				-- one more open
				counted_curly_brackets = counted_curly_brackets + 1
			elseif(b == CHAR_COND_END and string.byte(text, i - 1) ~= CHAR_ESCAPE) then
				counted_curly_brackets = counted_curly_brackets - 1
			end

			-- nothing to do; we read until the end of the line
			-- TODO: there are some inline things we need to check for as well
			-- TODO: inline commends need to be processed here
		elseif(b == CHAR_BLANK or b == CHAR_TAB) then
			-- nothing to do; real start of the line not yet found
			at_line_start = true
			-- blanks at the beginning are usually just identation for better
			-- readability of weaved content - best ignore these
			if(not(multiline_comment)
			  and not(inline_comment)
			  and content_start > -1
			  and content_start < i + 1) then
				content_start = i + 1
			end

		elseif(at_line_start) then
			last_what = what
			last_nested = nested
			nested = 1

			-- "\" (escape the next character)
			if(    b == CHAR_ESCAPE) then
				-- the line can no longer start with a special char; it is text
				what = "TEXT"
			--  at line start: multiline alternatives or conditions
			elseif(b == CHAR_COND_START and string.byte(text, i - 1) ~= CHAR_ESCAPE) then
				-- one more open
				counted_curly_brackets = counted_curly_brackets + 1
				what = "TEXT"
			elseif(b == CHAR_COND_END and string.byte(text, i - 1) ~= CHAR_ESCAPE) then
				counted_curly_brackets = counted_curly_brackets - 1
				what = "TEXT"
			-- "//" (start of inline comment) or "/* " (start of multiline comment)
			elseif(b == CHAR_SLASH) then
				local b2 = string.byte(text, i + 1)
				if(    b2 == CHAR_SLASH) then
					what = "COMMENT" -- inline comment
					-- remember that we are inside a comment
					inline_comment = true
					-- the text of the comment is not part of the content
					content_start = -1
				elseif(b2 == CHAR_STAR) then
					what = "START_OF_MULTILINE_COMMENT"
					-- remember that we are inside a multiline comment
					multiline_comment = true
					-- the text of the multiline comment is not part of the content
					content_start = -1
				else
					what = "ERROR:_UNKNOWN_SYMBOL_FOLLOWING_\"/\""
				end
			-- "*" (choice) - no matter what follows - it's a choice
			elseif(b == CHAR_STAR) then
				if(counted_curly_brackets > 0) then
					-- we are inside a condition or alternate
					-- normally choices would be allowed here in ink - but that'd be
					-- too complicated
					what = "TEXT"
				else
					what = "NORMAL_CHOICE"
					nested = 1
					search_for_nesting = b
				end
			-- "+" (sticky choice) - no mater what follows - it's a sticky choice
			elseif(b == CHAR_PLUS) then
				if(counted_curly_brackets > 0) then
					-- we are inside a condition or alternate
					-- normally choices would be allowed here in ink - but that'd be
					-- too complicated
					what = "TEXT"
				else
					what = "STICKY_CHOICE"
					nested = 1
					search_for_nesting = b
				end
			-- "-" (gather) or "->" divert
			elseif(b == CHAR_MINUS) then
				local b2 = string.byte(text, i + 1)
				if(b2 == CHAR_GREATER) then
					what = "TEXT" --DIVERT"
				elseif(counted_curly_brackets > 0) then
					-- we are inside a condition or alternate
					what = "TEXT"
				else
					-- TODO: we might be inside a multiline if/else/switch branch
					what = "GATHER"
					nested = 1
					search_for_nesting = b
				end
			-- "==" (knot) or "= " (stitch)
			elseif(b == CHAR_EQUAL) then
				local b2 = string.byte(text, i + 1)
				if(    b2 == CHAR_EQUAL) then
					what = "KNOT"
					search_for_name = true
				else
					what = "STITCH"
					search_for_name = true
				end
			-- "<>" (glue) apart from that it's a normal text line
			elseif(b == CHAR_SMALLER) then
				local b2 = string.byte(text, i + 1)
				if(    b2 == CHAR_GREATER) then
					what = "TEXT_GLUE"
				end
			-- "~ " (code/calculation)
			elseif(b == CHAR_TILDE) then
				local b2 = string.byte(text, i + 1)
				what = "CODE"
			-- "INCLUDE " (code/calculation)
			elseif(b == CHAR_I) then
				local s = string.sub(text, i, i + 7)
				if(    s == "INCLUDE ") then
					what = "INCLUDE"
				else
					-- else it is just text starting with a capital I
					what = "TEXT"
				end
			-- "VAR " (variable definition)
			elseif(b == CHAR_V) then
				local s = string.sub(text, i, i + 3)
				if(    s == "VAR ") then
					what = "VAR"
				else
					-- else it is just text starting with a capital V
					what = "TEXT"
				end
			-- "CONST " (variable definition)
			elseif(b == CHAR_C) then
				local s = string.sub(text, i, i + 5)
				if(    s == "CONST ") then
					what = "CONST"
				else
					-- else it is just text starting with a capital V
					what = "TEXT"
				end
			else
				what = "TEXT"
			end
			-- we have processed the start of the line and found a type
			at_line_start = false

			-- observation: choices end at the end of a line
			if(what == "TEXT"
			  and (content_type == "NORMAL_CHOICE" or content_type == "STICKY_CHOICE")) then
				what = "WEAVE"
			end
			-- the collected content of the last knot, stitch, gather or choice ends
			-- TODO: handle the situation of the last line
			if(  what == "NORMAL_CHOICE"
			  or what == "STICKY_CHOICE"
			  or what == "MAIN_PROGRAM"
			  or what == "GATHER"
			  or what == "KNOT"
			  or what == "STITCH"
			  or what == "WEAVE") then
			  	-- there may have been content in the last line
			  	if(content_start > -1) then
					content = content..string.sub(text, content_start, i - 1)
				end
				-- remove tailing newlines and blanks
				if(content) then
					content = strip_name(content)
				end
				local divert_to = ""
				if(content_type == "NORMAL_CHOICE" or content_type == "STICKY_CHOICE") then
					local start_1, start = string.find(content, "->")
					if(start) then
						start = start + 1
						while(start < string.len(content)
						   and string.byte(content, start) == CHAR_BLANK) do
							start = start + 1
						end
						local ende = start + 1
						while(ende < string.len(content)
						   and string.byte(content, ende) ~= CHAR_BLANK
						   and string.byte(content, ende) ~= CHAR_NEWLINE) do
							ende = ende + 1
						end
						divert_to = strip_name(string.sub(content, start, ende))
						content = strip_name(string.sub(content, 1, start_1 - 1))
					end
				end

				local knot = {}
				knot.content_type = content_type
				knot.name = strip_name(name_found or "")
				knot.label = label
				knot.nested = last_nested
				knot.conditions = conditions
				knot.text = content
				knot.divert_to = divert_to
				table.insert(knots, knot)

				if(not(print_debug)) then
					name_found = nil
				else
					local s = "   FOUND:  "..content_type
					if(name_found) then
						-- name of a knot or stitch
						-- TODO: strip leading and tailing blanks, tabs and = from found_name
						s = s.." Name: "..tostring(knot.name)
						name_found = nil
					end
					if(last_nested and last_nested > 0) then
						s = s.."\n   NESTED: "..tostring(last_nested)
					end
					if(label) then
						s = s.."\n   LABEL:  ["..tostring(label).."]"
					end
					if(conditions and #conditions > 0) then
						s = s.."\n   COND:   ["..table.concat(conditions, "] [").."]"
					end
					if(divert_to and divert_to ~= "") then
						s = s.."\n   TARGET: ["..tostring(divert_to).."]"
					end
					if(content and content ~= "") then
						s = s.."\n   STR:    ["..tostring(content).."]:STR\n"
					end
					print(s)
				end

				last_content_type = content_type
				content_type = what
				-- the old content ends
				content_start = i
				content = ""

				label = nil
				conditions = {}
				counted_curly_brackets = 0
			end
		end
		-- continue with the next charcter
		i = i + 1
	end
	return knots
end



-- TODO: intended for future parsing of ink inline functionality
parse_ink.inspect_inline = function(text)

	local CHAR_INLINE_START  = string.byte("{", 1)
	local CHAR_INLINE_END    = string.byte("}", 1)
	local CHAR_ESCAPE        = string.byte("\\", 1)
	local CHAR_SEPERATOR     = string.byte("|", 1)
	local CHAR_ML_SEPERATOR  = string.byte("-", 1)
	local CHAR_DOPPELPUNKT   = string.byte(":", 1)
	local CHAR_NEWLINE       = string.byte('\n', 1)
	local CHAR_BLANK         = string.byte(" ", 1)
	local CHAR_TAB     = string.byte("\t", 1)
	local CHAR_CYCLE         = string.byte("&", 1)
	local CHAR_ONCE_ONLY     = string.byte("!", 1)
	local CHAR_SHUFFLE       = string.byte("~", 1)

	local inline_starts = {}
	local sep_starts = {}
	local is_multiline = {}
	local level = 0
	local i = 1
	local i_max = string.len(text)
	while(i < i_max) do
		local b = string.byte(text, i)
		if(at_line_start and level > 0 and is_multiline[level]
		  and (b ~= CHAR_ML_SEPERATOR and b ~= CHAR_BLANK and b ~= CHAR_TAB)) then
			at_line_start = false
		end
		if(string.byte(text, i-1) == CHAR_ESCAPE) then
			-- do nothing; escape sign
		elseif( b == CHAR_INLINE_START) then
			table.insert(inline_starts, i)
			table.insert(sep_starts, {i})
			table.insert(is_multiline, false)
			level = level + 1
		elseif(level == 0) then
			-- not inside an inline expression; do nothing
		elseif(b == CHAR_NEWLINE) then
			at_line_start = true
			is_multiline[level] = true
		elseif(b == CHAR_ML_SEPERATOR and     is_multiline[level] and at_line_start) then
--			if(#sep_starts[level] == 1 and string.byte(text, sep_starts[level][1] == TODO)
			table.insert(sep_starts[level], i)
		elseif(b == CHAR_SEPERATOR    and not(is_multiline[level])) then
			table.insert(sep_starts[level], i)
		elseif(b == CHAR_DOPPELPUNKT  and #sep_starts[level] == 1) then
			print("Condition: "..string.sub(text, sep_starts[level][1] + 1, i))
			-- up until now we had the condition
			sep_starts[level][1] = i
		elseif(b == CHAR_INLINE_END) then
			local prefix = ""
			for j = 1, level do
				prefix = "  "..prefix
			end
			local t = prefix..string.sub(text, inline_starts[level], i)
			if(is_multiline[level]) then
				print("MULTIL: "..tostring(t))
			else
				print("INLINE: "..tostring(t))
			end

			table.insert(sep_starts[level], i)
			local max = #sep_starts[level]
			for c, pos in ipairs(sep_starts[level]) do
				if(c < max) then
					local t2 = prefix.." "..tostring(c)..") ".. string.sub(text,
									pos + 1, sep_starts[level][c+1] - 1)
					print(t2)
				end
			end
			table.remove(sep_starts,   level)
			table.remove(is_multiline, level)

			local b2 = string.byte(text, inline_starts[level] + 1)
--			if(b2 == CHAR_CYCLE) then

--			-- get the inline part
--			j = inline_starts[level] + 1
--			-- remove leading blanks
--			while(j < i and string.byte(text, j) == CHAR_BLANK) do
--				j = j + 1
--			end
--			-- remove tailing blanks
--			k = i
--			while(k > j and string.byte(text, j) == CHAR_BLANK) do
--				k = k - 1
--			end
--
			table.remove(inline_starts, level)
			level = level - 1
		end
		i = i + 1
	end
end


-- analyze the intermediate knot data strutcture parse_ink.parse created:

-- log to a table (debug_level > 0) and additionally to stdout (debug_level > 1)
parse_ink.print_debug = function(log_level, log, text)
	if(not(log_level) or log_level < 1) then
		return
	end
	if(log_level > 1) then
		print(text)
	end
	if(not(log) or log_level <= 1) then
		return
	end
	table.insert(log, text)
end


-- actions and effects are knots in ink but only part of the dialog in NPC dialogs;
-- find out which of their option knots serves which purpose
parse_ink.analyze_actions_or_effects = function(knot_list, what_to_analyze, cap_name, log_level, log)
	parse_ink.print_debug(log_level, log, "\nAnalyzing "..what_to_analyze.."s:")
	local success_str = "["..cap_name.." was successful]"
	local failure_str = "["..cap_name.." failed]"

	for knot_name, knot in pairs(knot_list) do
		parse_ink.print_debug(log_level, log, "  Found "..tostring(what_to_analyze)..": "..tostring(knot_name))
		-- examine options (we are mostly intrested in their links)
		for o_name, o_knot in pairs(knot.options) do
			if(o_knot.text and o_knot.text == success_str) then
				knot_list[knot_name].on_success = o_knot.divert_to
			elseif(o_knot.text and o_knot.text == failure_str) then
				knot_list[knot_name].on_failure = o_knot.divert_to
			elseif(o_knot.text and o_knot.text == "[Back]") then
				knot_list[knot_name].back = o_knot.divert_to
			else
				-- log that error regardless of log_level
				parse_ink.print_debug(2, log,
					"ERROR: Unsupported text \""..tostring(o_knot.text)..
					"\" for option \""..tostring(o_name)..
					"\" of "..what_to_analyze.." in knot name \""..
					tostring(knot_name).."\".")
			end
--			print("o_knot "..tostring(o_name).." target: "..tostring(o_knot.divert_to or "- none -"))
		end
	end
end


-- this serarches for the *real* target dialog;
-- it populates option_knot[option_name].actions and option_knot.effects with the
-- actions and effects it encountered
-- (there had to be extra knots inserted for actions and effects - which are no dialogs in NPC
-- dialog sense but are required as ink knots so that divert_to can be used in a sensible way;
-- after all actions and effects can fail)
parse_ink.find_real_target_dialog = function(option_knot, target, prefix, start_dialog, dialogs, actions, effects, log_level, log)
--	print("  option_knot: "..tostring(option_knot).." Next link: "..tostring(target))
	-- go back to the start
	if(not(target) or target == "" or target == start_dialog) then
		return start_dialog
	-- we found the end of the conversation - or another dialog
	elseif(target == "END" or dialogs[target]) then
		return target
	-- we found a special dialog
	elseif(yl_speak_up.is_special_dialog(parse_ink.strip_prefix(target, prefix))) then
		return parse_ink.strip_prefix(target, prefix)
	-- we found an action
	elseif(actions[target]) then
		-- avoid loops by restricting the number of actions visited
		if(#option_knot.actions > 0) then
			parse_ink.print_debug(2, log,
				"WARNING: Aborting finding real target dialog. "..
				"Only one action allowed per option. Using start dialog instead.")
			return start_dialog
		end
		-- remember that we visited this action
		table.insert(option_knot.actions, target)
		-- recursively find the option that corresponds to the success option
		return parse_ink.find_real_target_dialog(option_knot, actions[target].on_success, prefix, start_dialog, dialogs, actions, effects, log_level, log)
	-- we found an effect
	elseif(effects[target]) then
		-- avoid loops by restricting the number of effects visited
		if(#option_knot.effects > 20) then
			parse_ink.print_debug(2, log,
				"WARNING: Aborting finding real target dialog. "..
				"Too many effects chained. Using start dialog instead.")
			return start_dialog
		end
		-- remember that we visited this efffect
		table.insert(option_knot.effects, target)
		-- recursively find the option that corresponds to the success option
		return parse_ink.find_real_target_dialog(option_knot, effects[target].on_success, prefix, start_dialog, dialogs, actions, effects, log_level, log)
	-- the name was not found
	else
		parse_ink.print_debug(2, log,
			"WARNING: Aborting finding real target dialog. "..
			"Could not find target dialog \""..tostring(target).."\". Using start dialog.")
		return start_dialog
	end
end


parse_ink.print_knots = function(knots)
	-- debug output
	for i, knot in ipairs(knots) do
		-- TODO: knot.conditions
		print("Knot: "..tostring(knot.content_type).." ["..tostring(knot.nested).."] "..
			tostring(knot.name).." ("..tostring(knot.label)..")"..
			"\n  Text: "..tostring(knot.text))
	end
end


-- analyzes all knots and populates the lists knot_data, dialogs, actions and effects
-- with the names of the knots
parse_ink.analyze_knots_by_type = function(knots, log_level, log)
	-- start interpreting the meaning of the knots
	local knot_data = {}
	local dialogs = {}
	local actions = {}
	local effects = {}
	local start_knot = nil
	local last_knot_name = nil
	local dialog_list = {}
	parse_ink.print_debug(log_level, log, "\nIdentifying dialogs, actions, effects and options:")
	for i, knot in ipairs(knots) do
		if(knot.content_type == "KNOT") then
			if(knot_data[knot_name]) then
				parse_ink.print_debug(2, log,
					"WARNING: Knot "..tostring(knot_name).." already defined.\n"..
					"Using this new data and discarding old.")
			end
			knot_data[knot.name] = knot
			knot_data[knot.name].options = {}
			knot_data[knot.name].option_list = {}
			last_knot_name = knot.name
			-- actions and effects are just simulated as knots - they do not represent
			-- any actual dialogs in the NPC sense
			if(string.sub(knot.text, 1, 9) == ":action: ") then
				actions[knot.name] = knot
				parse_ink.print_debug(log_level, log, "ACTION: "..tostring(knot.name).."\n")
			elseif(string.sub(knot.text, 1, 9) == ":effect: ") then
				effects[knot.name] = knot
				parse_ink.print_debug(log_level, log, "EFFECT: "..tostring(knot.name).."\n")
			else
				dialogs[knot.name] = knot
				-- remember the sort order of the options
				parse_ink.print_debug(log_level, log, "=== "..tostring(knot.name).." ===\n")
				-- keep the order of appearance of the dialog names
				table.insert(dialog_list, knot.name)
			end
		elseif(last_knot_name
		   and (knot.content_type == "NORMAL_CHOICE" or knot.content_type == "STICKY_CHOICE")) then
			-- we need a label for the option so that it can be referenced correctly
			-- between ink and NPC dialogs; if none is provided (new dialog), then we'll
			-- create a temporary name (there may also be grey_out_ options);
			-- [Farewell!] is also still included
			if(not(knot.label) or knot.label == "") then
				knot.label = "new_"..tostring(i)
			end
			knot_data[last_knot_name].options[knot.label] = knot
			table.insert(knot_data[last_knot_name].option_list, knot.label)
			parse_ink.print_debug(log_level, log, "- "..tostring(knot.label or "ERROR")..": "..knot.text)
		elseif(knot.content_type == "WEAVE"
		   -- this is not really a WEAVE - it's the effects list and divert of an option
		   and i > 1
		   and  (knots[i-1].content_type == "NORMAL_CHOICE"
		      or knots[i-1].content_type == "STICKY_CHOICE")
		   and  (knots[i-1].divert_to
		      or knots[i-1].divert_to == "")) then
			local p = string.find(knot.text or "", "-> ")
			if(p) then
				knots[i-1].divert_to   = string.sub(knot.text or "", p + 3)
				if(p > 4) then
					knots[i-1].effect_list = string.sub(knot.text, 1, p - 2)
				else
					knots[i-1].effect_list = ""
					parse_ink.print_debug(2, log,
						"ERROR: WEAVE with no text apart from divert: ["..
						tostring(knot.text).."]")
				end
			elseif(knot.text) then
				knots[i-1].text2     = knot.text
			end
		elseif(knot.content_type == "MAIN_PROGRAM") then
			start_knot = knot
		else
			-- TODO	"GATHER"
			-- TODO	"STITCH"
			-- TODO	"WEAVE" (real ones)
			parse_ink.print_debug(2, log,
				"ERROR: Cannot handle knots of type \""..tostring(knot.content_type).."\" yet.")
		end
	end

	return {knot_data = knot_data, dialogs = dialogs, actions = actions, effects = effects, start_knot = start_knot, dialog_list = dialog_list}
end



parse_ink.find_dialog_name_prefix = function(start_knot, log_level, log)
	-- the ink program has to start with "-> PREFIXd_end" (with PREFIX usually beeing something
	-- like n_<NPC_ID>, so i.e. "-> n_105_d_end" might be a valid first line
	-- Export to ink supports prefixes.
	-- Prefixes are particulary useful if you want to combine the texts of multiple NPC in one
	-- ink program for testing.
	local prefix = ""
	if(not(start_knot) or not(start_knot.text)) then
		parse_ink.print_debug(2, log,
			"ERROR: MAIN_PROGRAM/divert_to start knot not found. Please start your ink file "..
			"with a divert to the main dialog!")
	else
		prefix = start_knot.text
	end
	if(string.sub(prefix, string.len(prefix) - 4) ~= "d_end"
	  or string.sub(prefix, 1, 3) ~= "-> ") then
		parse_ink.print_debug(2, log,
			"ERROR: Your MAIN_PROGRAM/divert_to ought to contain a prefix (usually n_<NPC_ID>_) "..
			", followed by d_end. Example: \"-> n_105_d_end\". You used: \""..
			tostring(prefix).."\".")
	else
		prefix = string.sub(prefix, 4, string.len(prefix) - 5)
	end
	parse_ink.print_debug(log_level, log, "\nUsing prefix: "..tostring(prefix))
	return prefix
end


parse_ink.find_start_dialog_name = function(prefix, dialogs, log_level, log)
	-- find out the real start dialog
	local start_dialog = prefix.."d_end"
	if(dialogs[start_dialog]) then
		for o_name, o_knot in pairs(dialogs[start_dialog].options) do
			-- the last option that diverts to anything else than END is what we're looking for
			if(o_knot.divert_to and o_knot.divert_to ~= "END") then
				start_dialog = o_knot.divert_to
			end
		end
	end
	parse_ink.print_debug(log_level, log, "\nUsing start dialog: "..tostring(start_dialog))
	return start_dialog
end


-- options link to *actions* and *effects* - because that is necessary to simulate
-- NPC behaviour in inc. But for importing that data, we need the real target link
-- that happens when all actions and effects were successful.
parse_ink.adjust_links = function(dialogs, actions, effects, start_dialog, prefix, log_level, log)
	-- determine on_success, on_failure and back links for actions and effects
	parse_ink.analyze_actions_or_effects(actions, "action", "Action", log_level, log)
	parse_ink.analyze_actions_or_effects(effects, "effect", "Effect", log_level, log)

	parse_ink.print_debug(log_level, log,
		"\nAssigning actions and effects to their options and adjusting those options' target dialog:")
	-- now check if all options are linked properly; for this we check dialogs only
	-- (actions and effects are referenced through their options)
	for d_name, dialog_knot in pairs(dialogs) do
		-- only the options have links
		for o_name, o_knot in pairs(dialog_knot.options) do
			-- actions that belong to this dialog
			o_knot.actions = {}
			-- effects that belong to this dialog
			o_knot.effects = {}
			local old_target = o_knot.divert_to
			-- this function also fills the .actions and .effects table with any actions
			-- and effects it finds on its way while following the successful option of
			-- each action and effect encountered
			local target = parse_ink.find_real_target_dialog(o_knot, o_knot.divert_to, prefix, start_dialog, dialogs, actions, effects, log_level, log)
			if(target ~= o_knot.divert_to) then
				parse_ink.print_debug(log_level, log,
					"INFO: Changing target dialog for option \""..tostring(o_name)..
					"\" of dialog "..tostring(d_name)..
					"\n     from     "..tostring(o_knot.divert_to)..
					"\n     to:      "..tostring(target)..
					"\n     Actions: "..
						table.concat(o_knot.actions, ", ")..
					"\n     Effects: "..
						table.concat(o_knot.effects, ", "))
				o_knot.divert_to = target
			end
		end
	end
end


parse_ink.strip_prefix = function(text, prefix)
	local i = string.len(prefix)
	if(string.sub(text or "", 1, i) == prefix) then
		return string.sub(text, i+1)
	end
	return text
end


-- strip "[" and "]" enclosing text
parse_ink.strip_brackets = function(text)
	if(not(text)) then
		return
	end
	local p1 = 1
	if(string.sub(text, 1, 1) == "[") then
		p1 = 2
	end
	local p2 = string.len(text)
	-- remove tailing "]" (needed for ink)
	if(string.sub(text, string.len(text)) == "]") then
		p2 = p2 - 1
	end
	return string.sub(text, p1, p2)
end



-- actually doing the import
parse_ink.import_dialogs = function(dialog, dialogs, actions, effects, start_dialog, prefix, orig_dialog_list, log_level, log)
	parse_ink.print_debug(log_level, log, "\n\nStarting dialog import:")

	local dialog_list = {}
	-- remove the extra wrapper dialog (added for ink) from the list
	for i, d_name in ipairs(orig_dialog_list) do
		if(d_name ~= prefix.."d_end") then
			table.insert(dialog_list, d_name)
		end
	end
	-- we need to add the dialogs as such first so that target_dialog will work
	local d_sort = 1
	for i, d_name in ipairs(dialog_list) do
		local dialog_knot = dialogs[d_name]
		local dialog_name = parse_ink.strip_prefix(d_name, prefix)

		local d_id = yl_speak_up.update_dialog(log, dialog, dialog_name, dialog_knot.text)
		dialog_knot.d_id = d_id

		-- adjust d_sort so that it is the same order as in the import
		if(d_id and dialog.n_dialogs[d_id] and d_name ~= start_dialog) then
			dialog.n_dialogs[d_id].d_sort = d_sort
			d_sort = d_sort + 1
		end
	end

	-- now we can add the options
	for i, d_name in ipairs(dialog_list) do
		local dialog_knot = dialogs[d_name]
		local dialog_name = parse_ink.strip_prefix(d_name, prefix)
		local d_id = dialog_knot.d_id

		-- identify and remove options that are grey_out_ texts
		-- and store them in table greyed_out
		local greyed_out = {}
		local tmp_option_list = {}
		for i, o_name in ipairs(dialog_knot.option_list) do
			if(string.sub(o_name, 1, 9) == "grey_out_") then
				local o_id = string.sub(o_name, 10)
				greyed_out[o_id] = parse_ink.strip_brackets(dialog_knot.options[o_name].text)
			else
				table.insert(tmp_option_list, o_name)
			end
		end

		-- o_random belongs to the dialog; if one option is randomly, then the entire dialog is
		local is_random = false
		for i, o_name in ipairs(tmp_option_list) do
			if(string.sub(o_name, 1, 9) == "randomly_") then
				is_random = true
			end
		end
		-- we now have all information to decude about the dialogs' o_random
		if(is_random and not(dialog.n_dialogs[d_id].o_random)) then
			parse_ink.print_debug(log_level, log, "Changed DIALOG \""..tostring(d_id).."\" to RANDOMLY SELECTED.")
			dialog.n_dialogs[d_id].o_random = 1
		elseif(not(is_random)
		  and dialog.n_dialogs[d_id]
		  and dialog.n_dialogs[d_id].o_random) then
			parse_ink.print_debug(log_level, log, "Changed DIALOG \""..tostring(d_id).."\" back to normal (was: RANDOMLY SELECTED).")
			dialog.n_dialogs[d_id].o_random = nil
		end


		for i, o_name in ipairs(tmp_option_list) do
			local o_knot = dialog_knot.options[o_name]
			local option_text   = o_knot.text
			local visit_only_once = (o_knot.content_type == "NORMAL_CHOICE")
			local alternate_text = nil
			local target_dialog = o_knot.divert_to
			target_dialog = parse_ink.strip_prefix(target_dialog, prefix)

			-- remove leading "[" (needed for ink but not for dialogs)
			option_text = parse_ink.strip_brackets(option_text)

--			if(o_knot.effect_list and o_knot.effect_list ~= "") then
--				print("EFFECT LIST: "..tostring(d_id).." "..tostring(o_name).." "..tostring(o_knot.effect_list))
--			end
			-- extract the alternate text
			local p = string.find(o_knot.effect_list or "", "\n#")
			if(p and p > 1 and string.sub(o_knot.effect_list, 1, 1) ~= "#") then
				alternate_text = string.sub(o_knot.effect_list or "", 1, p)
			else
				-- TODO: the rest of this is the effect list as comment
				p = 1
			end
			-- ignore the automaticly added Farewell!-option
			if(option_text ~= "Farewell!" or target_dialog == prefix.."d_end") then
				local o_id = yl_speak_up.update_dialog_option(log, dialog, d_id, o_name,
						option_text, greyed_out[o_name], target_dialog,
                                                alternate_text, visit_only_once,
						-- make sure o_sort gets set approprately:
						i)
			end
			-- TODO: deal with preconditions
			-- TODO: deal with actions
			-- TODO: deal with effects
			-- TODO: effects are not parsed yet
		end
		-- the dialog may already contain further options that are no longer needed;
		-- those need o_sort set and a false precondition; update_dialog did prepare the
		-- options already for this, and this function here does the necessary cleanup:
		yl_speak_up.update_dialog_options_completed(log, dialog, dialog_knot.d_id)
	end

	-- make sure the right start dialog is set
	yl_speak_up.update_start_dialog(log, dialog, parse_ink.strip_prefix(start_dialog, prefix), d_sort)

	return dialog
end






-- helper function - yl_speak_up includes this, but we here not
-- TODO: use the same for export
yl_speak_up.show_effect = function(r)
	local text = r.r_type or "ERROR: no r.r_type! "
	for k, v in pairs(r or {}) do
		if(k == "r_craft_grid") then
			text = text.." "..tostring(k)..": "..table.concat(v or {}, ",")
		elseif(k ~= "r_id" and k ~= "r_type") then
			text = text.." "..tostring(k)..": "..tostring(v)
		end
	end
	return text
end


-- parameters:
--     dialog     a yl_speak_up NPC dialog data structure containing the dialogs of the NPC
--     text       the ink program that is to be parsed
--     log_level  how detailled a report shall be created in the table log
--     log        table - log entries will be appended to it
parse_ink.import_from_ink = function(dialog, text, log_level, log)
	-- parse the ink program;
	-- the "false" stands for "do not print out the parsed lines to stdout"
	local knots = parse_ink.parse(text, false)

	-- prepare the knots so that they can be turned into dialogs
	local res = parse_ink.analyze_knots_by_type(knots, log_level, log)
	-- the prefix helps to combine multiple NPC dialogs into one ink program; it is usally n_<ID>_
	local prefix = parse_ink.find_dialog_name_prefix(res.start_knot, log_level, log)
	-- which dialog is the start dialog?
	local start_dialog = parse_ink.find_start_dialog_name(prefix, res.dialogs, log_level, log)
	-- if there is an action or effect of the type "If the previous effect failed, ..", then the
	-- export_to_ink will create extra knots for these actions and effects - and adjust the links;
	-- this code here just turns it back to the target dialog that is shown when the action and all
	-- effects were successful
	parse_ink.adjust_links(res.dialogs, res.actions, res.effects, start_dialog, prefix, log_level, log)

	-- now we're ready to actually import this into the dialog datastructure; uses functions_dialog.lua
	parse_ink.import_dialogs(dialog, res.dialogs, res.actions, res.effects, start_dialog, prefix, res.dialog_list, log_level, log)

	return dialog
end

