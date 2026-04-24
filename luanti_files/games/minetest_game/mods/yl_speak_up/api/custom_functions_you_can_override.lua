
-----------------------------------------------------------------------------
-- This can be customized for each server.
-----------------------------------------------------------------------------
-- But please not in this file. Write your own one and re-define these
-- functions here if needed!
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Placeholders (i.e. $NPC_NAME$) in texts
-----------------------------------------------------------------------------
-- this contains custom functions that you can override on your server
-- please take a look at the example code!

-- replace some variables in the text the NPC speaks and which the player can use to reply
-- pname: the name of the player that is talking to the NPC;
-- Note: If you want to change this function, best call the original as well after
--       applying your custom changes.
yl_speak_up.replace_vars_in_text = function(text, dialog, pname)
	local subs = {
		MY_NAME = dialog.n_npc,
		NPC_NAME = dialog.n_npc,
		OWNER_NAME = dialog.npc_owner,
		PLAYER_NAME = pname,
	}

	-- only try to replace variables if there are variables inside the text
	if(string.find(text, "$VAR ")) then
		local varlist = yl_speak_up.get_quest_variables(dialog.npc_owner, true)
		for i,v in ipairs(varlist) do
			local v_name = string.sub(v, 3)
			-- only allow to replace unproblematic variable names
			if(not(string.find(v_name, "[^%w^%s^_^%-^%.]"))) then
				-- remove leading $ from   $ var_owner_name var_name
				subs["VAR "..v_name] = yl_speak_up.get_quest_variable_value(dialog.npc_owner, v) or "- not set -"
			end
		end
	end

	-- only replace properties if any properties are used inside the text
	if(string.find(text, "$PROP ")) then
		local properties = yl_speak_up.get_npc_properties(pname)
		for k,v in pairs(properties) do
			-- only allow to replace unproblematic property names
			if(not(string.find(k, "[^%w^%s^_^%-^%.]"))) then
				subs["PROP "..k] = v
			end
		end
	end

	local day_time_name = "day"
	local day_time = minetest.get_timeofday()
	if(day_time < 0.5) then
		day_time_name = "morning"
	elseif(day_time < 0.75) then
		day_time_name = "afternoon"
	else
		day_time_name = "evening"
	end
	subs.GOOD_DAY = "Good "..day_time_name
	subs.good_DAY = "good "..day_time_name

	-- Note: the $ char is a special one. It needs to be escaped with %$ in lua.
	-- Note: when substitution argument is a table, we look up
	-- substitutions in it using substring captured by "()" in
	-- pattern. "[%a_]+" means one or more letter or underscore.
	-- If lookup returns nil, then no substitution is made.
	-- Note: Names of variables may contain alphanumeric signs, spaces, "_", "-" and ".".
	--       Variables with other names cannot be replaced.
	text = string.gsub(text or "", "%$([%w%s_%-%.]+)%$", subs)

	return text
end


-----------------------------------------------------------------------------
-- Custom preconditions without parameters - the simple way
-----------------------------------------------------------------------------
-- Unlike the more advanced custom preconditions, actions and effects below,
-- these ones here take *no* custom parameters when beeing used.

-- When you change an existing text in the list below NPC that make use of that
-- precondition will no longer be able to recognize it. You have to reconfigure
-- all those NPC! Adding new texts is no problem.
yl_speak_up.custom_server_functions.precondition_descriptions = {
	"(internal) hour of ingame day",
	"(internal) player's health points",
}

-- please return a useful value depending on the function;
-- parameter:
-- 	player		the player object
-- 	desc		entry from yl_speak_up.custom_server_functions.precondition_descriptions above
-- 	precondition	contains the data of the precondition for additional information;
-- 			precondition.p_var_cmp_value contains a user-specified value against which
-- 			the return value of this function is checked. This depends on
-- 			precondition.p_operator. Depending on the operator, precondition.p_var_cmp_value
-- 			may also be used as a parameter to this function.
-- 			Just make sure to tell your users what return values they shall expect and which
-- 			operators make sense!
-- Note: This function will be called often. Make it efficient!
yl_speak_up.custom_server_functions.precondition_eval = function(player, descr, precondition)

	if(descr == "(internal) hour of ingame day") then
		-- timeofday is between 0..1; translate to 24 hours
		return math.floor((minetest.get_timeofday() * 24)+0.5)

	elseif(descr == "(internal) player's health points") then
		return player:get_hp()

	-- if this custom server function does not exist: return false
	else
		return false
	end
end


-----------------------------------------------------------------------------
-- Custom preconditions, actions and effects
-- (they contain functions; they have the type "evaluate")
-----------------------------------------------------------------------------
-- General structure:
-- Each entry in the table
-- 	yl_speak_up.custom_functions_*_ (with * beeing p, a or r)
-- has the following format:
-- key: Short uniq name for the function.
--      description: Long description of what the function does
--      param1_text: Label for the input field for param1 (if empty, no input field is offered)
--      param1_desc: Mouseover text for the input field for param1
--      ...
--      param9_text: Label for the input field for param1
--      param9_desc: Mouseover text for the input field for param1
--      code:        The actual implementation of the function that is to be called.

-----------------------------------------------------------------------------
--  Custom preconditions (of type "evaluate")
-----------------------------------------------------------------------------
-- The function has to have the following structure:
--
--	code = function(player, n_id, p)
--	     -- do something
--	     return result
--	end,
--
-- The return value <result> is compared to the given value with the given
-- comperator operation.
--
-- Please keep in mind that preconditions are called *often*. They need to be
-- fast and efficient.
--
-- Parameters:
-- 	<player>	The acting player object.
-- 	<n_id>		The NPC ID <n_id> of the given NPC.
-- 	<p>		The precondition. Contains the parameters in p.p_param<nr>.
--
-- Table for storing the custom preconditions:
yl_speak_up.custom_functions_p_ = {}

-- example function for preconditions:
yl_speak_up.custom_functions_p_[ "example function" ] = {
	description = "This function is just an example. It tells the player its parameters.",
	param1_text = "1. Parameter:",
	param1_desc = "This is the value passed to the function as first parameter.",
	param2_text = "2. Parameter:",
	param2_desc = "This is the value passed to the function as second parameter.",
	param3_text = "3. Parameter:",
	param3_desc = "This is the value passed to the function as 3. parameter.",
	param4_text = "4. Parameter:",
	param4_desc = "This is the value passed to the function as 4. parameter.",
	param5_text = "5. Parameter:",
	param5_desc = "This is the value passed to the function as 5. parameter.",
	param6_text = "6. Parameter:",
	param6_desc = "This is the value passed to the function as 6. parameter.",
	param7_text = "7. Parameter:",
	param7_desc = "This is the value passed to the function as 7. parameter.",
	param8_text = "8. Parameter:",
	param8_desc = "This is the value passed to the function as 8. parameter.",
	param9_text = "9. Parameter:",
	param9_desc = "This is the value passed to the function as 9. parameter.",
	-- the actual implementation of the function
	code = function(player, n_id, p)
		local pname = player:get_player_name()
		local str = ""
		for i = 1,9 do
			str = str.."\n\tParameter "..tostring(i)..": "..tostring(p["p_param"..tostring(i)])
		end
		minetest.chat_send_player(pname, "Checking precondition "..tostring(p.p_id)..
			" for NPC with ID "..tostring(n_id)..": Executing custom function "..
			tostring(p.p_value).." with the following parameters:"..
			str.."\n(This function just tells you its parameters and returns true.)")
		-- this function is just for demonstration; it always returns true
		return true
	end,
}

-- get the XP the player has collected (provided the xp_redo mod is installed);
-- returns 0 if the mod isn't installed
-- Note: This could also have been handled by the old/above "Custom preconditions
--       without parameters - the simple way" method.
--       Please use this version instead of the old above!
yl_speak_up.custom_functions_p_[ "get_xp_of_player" ] = {
	description = "Get the xp the player has achieved (requires xp_redo).",
	code = function(player, n_id, p)
		local pname = player:get_player_name()
		if(minetest.get_modpath("xp_redo")) then
			return xp_redo.get_xp(pname)
		end
		return 0
	end
}


yl_speak_up.custom_functions_p_[ "check_if_player_has_priv" ] = {
	description = "Check if the player has a given priv.",
	param1_text = "Priv to check for:",
	param1_desc = "Checks if the player has the priv you entered here.",
	code = function(player, n_id, p)
		-- the name of the priv is derived from the parameter
		return minetest.check_player_privs(player,
				minetest.string_to_privs(tostring(p.p_param1 or "")))
	end
}


yl_speak_up.custom_functions_p_[ "compare_variable_against_variable" ] = {
	description = "Compare a variable against another variable.",
	param1_text = "Name of the first variable:",
	param1_desc = "Which variables do you want to compare?",
	param2_text = "Name of the second variable:",
	param2_desc = "Which variables do you want to compare?",
	param3_text = "Operator (i.e. >=, <, ==, ~=, ..):",
	param3_text = "Please state which operator shall be used.",
	code = function(player, n_id, p)
		if(not(p) or not(p.p_param1) or p.p_param1 == ""
		  or not(p.p_param2) or p.p_param2 == ""
		  or not(p.p_param3) or p.p_param3 == "") then
			return false
		end
		local pname = player:get_player_name()
		local owner = yl_speak_up.npc_owner[ n_id ]
		local prefix = "$ "..tostring(owner).." "
		-- get the value of the variable
		-- the owner is usually alrady encoded in the variable name - but not here, so
		-- we need to add it manually
		local var_val_1 = yl_speak_up.get_quest_variable_value(pname, prefix..p.p_param1)
		local var_val_2 = yl_speak_up.get_quest_variable_value(pname, prefix..p.p_param2)
		-- the comparison function below takes its parameters mostly in the form
		-- of entries in the table tmp_precon - thus, we construct a table with
		-- fitting entries
		local tmp_precon = {
			p_operator = p.param3,
			p_var_cmp_value = var_val_2
		}
		return yl_speak_up.eval_precondition_with_operator(tmp_precon, var_val_1)
	end
}


yl_speak_up.custom_functions_p_[ "text_contained_these_words" ] = {
	description = "Check if what the player entered in the last text_input action contains\n"..
		"all these words here.",
	param1_text = "List (seperated by space) of words:",
	param1_desc = "The text the player entered during the last text_input action is examined.\n"..
		"If it contains all the words you enter here, then this function here will return true.\n"..
		"Note: All input will be converted to lower case. Word order does not matter.",
	code = function(player, n_id, p)
		local pname = player:get_player_name()
		if(not(yl_speak_up.last_text_input[pname])) then
			return false
		end
		local input_words = string.split(string.lower(yl_speak_up.last_text_input[pname]), " ")
		local word_list = string.split(string.lower(p["p_param1"] or ""), " ")
		for i, word in ipairs(word_list) do
			if(table.indexof(input_words, word) == -1) then
				return -1
			end
		end
		return true
	end,
}


yl_speak_up.custom_functions_p_[ "counted_visits_to_dialog" ] = {
	description = "counted dialog visits: "..
		"How many times has the player visited/seen this dialog during this talk?",
	param1_text = "Name of dialog (i.e. \"d_1\"):",
	param1_desc = "Enter the dialog ID of the dialog for which you want to get the amount of "..
		"visits. If the dialog does not exist, -1 is returned.",
	code = function(player, n_id, p)
		local pname = player:get_player_name()
		if(not(pname)) then
			return -1
		end
		local dialog = yl_speak_up.speak_to[pname].dialog
		local d_id = p["p_param1"]
		if(not(yl_speak_up.check_if_dialog_exists(dialog, d_id))) then
			return -1
		end
		local visits = dialog.n_dialogs[d_id].visits
		if(not(visits)) then
			return 0
		end
		return visits
	end,
}


yl_speak_up.custom_functions_p_[ "counted_visits_to_option" ] = {
	description = "counted dialog option/answers visits: "..
		"How many times has the player visited/seen this dialog *option* during this talk?",
	param1_text = "Name of dialog (i.e. \"d_1\"):",
	param1_desc = "Enter the dialog ID of the dialog the option belongs to.",
	param2_text = "Name of option (i.e. \"o_2\"):",
	param2_desc = "Enter the option ID of the dialog for which you want to get the amount of "..
		"visits. If the option does not exist, -1 is returned.",
	code = function(player, n_id, p)
		local pname = player:get_player_name()
		if(not(pname)) then
			return -1
		end
		local dialog = yl_speak_up.speak_to[pname].dialog
		local d_id = p["p_param1"]
		local o_id = p["p_param2"]
		if(not(yl_speak_up.check_if_dialog_has_option(dialog, d_id, o_id))) then
			return -1
		end
		local visits = dialog.n_dialogs[d_id].d_options[o_id].visits
		if(not(visits)) then
			return 0
		end
		return visits
	end,
}


-----------------------------------------------------------------------------
--  Custom actions (of type "evaluate")
-----------------------------------------------------------------------------
-- The function has to have the following structure:
--
--	code = function(player, n_id, r)
--	     -- create the formspec
--	     return formspec
--	end,
--
-- The return value <formspec> has to be a valid formspec text and is shown
-- directly to the player.
--
-- Parameters:
-- 	<player>	The acting player object.
-- 	<n_id>		The NPC ID <n_id> of the given NPC.
-- 	<r>		The effect/result. Contains the parameters in r.r_param<nr>.
--
-- Table for storing the custom actions:
yl_speak_up.custom_functions_a_ = {}

-- example function for actions:
yl_speak_up.custom_functions_a_[ "example function" ] = {
	description = "This function is just an example. It tells the player its parameters.",
	param1_text = "1. Parameter:",
	param1_desc = "This is the value passed to the function as first parameter.",
	param2_text = "2. Parameter:",
	param2_desc = "This is the value passed to the function as second parameter.",
	param3_text = "3. Parameter:",
	param3_desc = "This is the value passed to the function as 3. parameter.",
	param4_text = "4. Parameter:",
	param4_desc = "This is the value passed to the function as 4. parameter.",
	param5_text = "5. Parameter:",
	param5_desc = "This is the value passed to the function as 5. parameter.",
	param6_text = "6. Parameter:",
	param6_desc = "This is the value passed to the function as 6. parameter.",
	param7_text = "7. Parameter:",
	param7_desc = "This is the value passed to the function as 7. parameter.",
	param8_text = "8. Parameter:",
	param8_desc = "This is the value passed to the function as 8. parameter.",
	param9_text = "9. Parameter:",
	param9_desc = "This is the value passed to the function as 9. parameter.",
	-- the actual implementation of the function
	-- note that what it shall return is a formspec
	code = function(player, n_id, a)
		local pname = player:get_player_name()
		local dialog = yl_speak_up.speak_to[pname].dialog
		local str = ""
		for i = 1,9 do
			str = str.."label[1.0,"..tostring(3.0 + i*0.5)..";"..tostring(i)..". Parameter: "..
				minetest.formspec_escape(tostring(a["a_param"..tostring(i)])).."]"
		end
		return "size[12.5,9.0]"..
			"button[0.2,0.0;2.0,0.9;back_to_talk;Back to talk]"..
			"button[5.75,0.0;6.0,0.9;finished_action;Successfully complete the action]"..
			"button[5.75,0.8;6.0,0.9;failed_action;Fail to complete the action]"..
			"tooltip[back_to_talk;Click here if you want to abort/cancel.]"..
			"tooltip[failed_action;Click here if you want the action to FAIL.]"..
			"tooltip[finished_action;Click here if you want the action to be a SUCCESS.]"..
			"label[0.5,2.0;"..minetest.formspec_escape(
				"["..(dialog.n_npc or "- ? -").." stares expectantly at you.]").."]"..
			"label[0.5,3.0;This function was called with the following custom parameters:]"..
			str..
			"label[0.5,8.0;It is up to the custom function to make whatever sense it wants "..
				"\nout of these parameters.]"
	end,
	-- this function will be called by the one that handles all custom input to actions
	-- of the type "evaluate"; it can change the value of entries of the table "fields"
	-- if necessary
	code_input_handler = function(player, n_id, a, formname, fields)
		local pname = player:get_player_name()
		-- let's just tell the player the value of "fields" (after all this is an
		-- example function)
		minetest.chat_send_player(pname, "The custom action input handler \""..
			minetest.formspec_escape(tostring(a.a_value)).."\" was called with "..
			"the following input:\n"..minetest.serialize(fields))
		-- the function has to return fields
		return fields
	end,
}

-- example function for actions:
yl_speak_up.custom_functions_a_[ "quest maintenance" ] = {
	description = "Create and maintain quests.",
	-- the actual implementation of the function
	-- note that what it shall return is a formspec
	code = function(player, n_id, a)
		return yl_speak_up.get_fs_quest_gui(player, n_id, a)
	end,
	-- this function will be called by the one that handles all custom input to actions
	-- of the type "evaluate"; it can change the value of entries of the table "fields"
	-- if necessary
	code_input_handler = function(player, n_id, a, formname, fields)
		-- the function has to return fields
		return yl_speak_up.input_quest_gui(player, formname, fields)
	end,
}


-----------------------------------------------------------------------------
--  Custom effects (of type "evaluate")
-----------------------------------------------------------------------------
-- The function has to have the following structure:
--
--	code = function(player, n_id, r)
--	     -- do something
--	     return result
--	end,
--
-- The return value <result> has to be either <true> (if the function was
-- successful) or <false> if it encountered an error.
--
-- Functions used in/as effects usually change something, i.e. a variable.
--
-- Parameters:
-- 	<player>	The acting player object.
-- 	<n_id>		The NPC ID <n_id> of the given NPC.
-- 	<r>		The effect/result. Contains the parameters in r.r_param<nr>.
--
-- Table for storing the custom results/effects:
yl_speak_up.custom_functions_r_ = {}

-- example function for results/effects:
yl_speak_up.custom_functions_r_[ "example function" ] = {
	-- Describe here in short form what your function does:
	description = "This function is just an example. It tells the player its parameters.",
	param1_text = "1. Parameter:",
	param1_desc = "This is the value passed to the function as first parameter.",
	param2_text = "2. Parameter:",
	param2_desc = "This is the value passed to the function as second parameter.",
	param3_text = "3. Parameter:",
	param3_desc = "This is the value passed to the function as 3. parameter.",
	param4_text = "4. Parameter:",
	param4_desc = "This is the value passed to the function as 4. parameter.",
	param5_text = "5. Parameter:",
	param5_desc = "This is the value passed to the function as 5. parameter.",
	param6_text = "6. Parameter:",
	param6_desc = "This is the value passed to the function as 6. parameter.",
	param7_text = "7. Parameter:",
	param7_desc = "This is the value passed to the function as 7. parameter.",
	param8_text = "8. Parameter:",
	param8_desc = "This is the value passed to the function as 8. parameter.",
	param9_text = "9. Parameter:",
	param9_desc = "This is the value passed to the function as 9. parameter.",
	-- the actual implementation of the function
	code = function(player, n_id, r)
		local pname = player:get_player_name()
		local str = ""
		for i = 1,9 do
			str = str.."\n\tParameter "..tostring(i)..": "..tostring(r["r_param"..tostring(i)])
		end
		minetest.chat_send_player(pname, "Checking effect "..tostring(r.r_id)..
			" for NPC with ID "..tostring(n_id)..": Executing custom function "..
			tostring(r.r_value).." with the following parameters:"..
			str.."\n(This function just tells you its parameters and returns true.)")
		-- the function was successful (effects only return true or false)
		return true
	end,
}


yl_speak_up.custom_functions_r_[ "set_variable_to_random_number" ] = {
	description = "Set a variable to a random number.",
	param1_text = "Name of the variable:",
	param1_desc = "Which variable do you want to set to a random number?",
	param2_text = "Minimum value:",
	param2_desc = "Which is the MINIMUM value the varible might be set to?",
	param3_text = "Maximum value:",
	param3_desc = "Which is the MAXIMUM value the varible might be set to?",
	code = function(player, n_id, r)
		if(not(r) or not(r.r_param1) or r.r_param1 == ""
		  or not(r.r_param2) or r.r_param2 == ""
		  or not(r.r_param3) or r.r_param3 == "") then
			return false
		end
		-- set the value of the variable
		local n1 = tonumber(r.r_param2)
		local n2 = tonumber(r.r_param3)
		if(n2 < n1) then
			local tmp = n1
			n1 = n2
			n2 = tmp
		end
		local new_value = math.random(n1, n2)
		-- the owner is already encoded in the variable name
		local pname = player:get_player_name()
		local owner = yl_speak_up.npc_owner[ n_id ]
		local prefix = "$ "..tostring(owner).." "
		local ret = yl_speak_up.set_quest_variable_value(pname, prefix..r.r_param1, new_value)
		local o_id = yl_speak_up.speak_to[pname].o_id or "?"
		yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
			"state: Success: "..tostring(ret).." for setting "..tostring(r.r_param1).." to "..
			tostring(new_value)..".")
		return ret
	end
}


yl_speak_up.custom_functions_r_[ "set_variable_to_random_value_from_list" ] = {
	description = "Set a variable to a random value from a list.",
	param1_text = "Name of the variable:",
	param1_desc = "Which variable do you want to set to a random value from your list?",
	param2_text = "Possible values:",
	param2_desc = "Enter all the possible values/texts for your variable here.\n"..
			"Seperate the entires by \"|\", i.e.: \"entry1|entry2|entry3\".",
	code = function(player, n_id, r)
		if(not(r) or not(r.r_param1) or r.r_param1 == ""
		  or not(r.r_param2) or r.r_param2 == "") then
			return false
		end
		local liste = string.split(r.r_param2, "|")
		if(not(liste) or #liste < 1) then
			return false
		end
		local new_value = liste[math.random(1, #liste)]
		-- the owner is already encoded in the variable name
		local pname = player:get_player_name()
		local owner = yl_speak_up.npc_owner[ n_id ]
		local prefix = "$ "..tostring(owner).." "
		local ret = yl_speak_up.set_quest_variable_value(pname, prefix..r.r_param1, new_value)
		local o_id = yl_speak_up.speak_to[pname].o_id or "?"
		yl_speak_up.debug_msg(player, n_id, o_id, tostring(r.r_id).." "..
			"state: Success: "..tostring(ret).." for setting "..tostring(r.r_param1).." to "..
			tostring(new_value)..".")
		return ret
	end
}


yl_speak_up.custom_functions_r_[ "play_sound" ] = {
	description = "Plays a sound.",
	param1_text = "Name of the sound(file):",
	param1_desc = "How is the sound(file) called?\n"..
			"It has to be provided by another mod.\n"..
			"Example: default_dirt_footstep",
	param2_text = "Gain:",
	param2_desc = "Number between 1 and 10. Default: 10.",
	param3_text = "Pitch:",
	param3_desc = "Applies a pitch-shift to the sound.\n"..
			"Each factor of 20 results in a pitch-shift of +12 semitones.\n"..
			"Default is 10.",
	param4_text = "Max hear distance:",
	param4_desc = "Default: 32 m. Can be set to a value between 3 and 64.",
	code = function(player, n_id, r)
		if(not(r) or not(r.r_param1) or r.r_param1 == "") then
			return false
		end
		if(not(player)) then
			return false
		end
		local pname = player:get_player_name()

		sound_param = {}
		if(r.r_param2 and r.r_param2 ~= "") then
			sound_param.gain = math.floor(tonumber(r.r_param2) or 0)
			if(sound_param.gain < 1 or sound_param.gain > 10) then
				sound_param.gain = 10
			end
			sound_param.gain = sound_param.gain / 10
		end
		if(r.r_param3 and r.r_param3 ~= "") then
			sound_param.pitch = math.floor(tonumber(r.r_pitch) or 0)
			if(sound_param.pitch < 1) then
				sound_param.pitch = 10
			end
			sound_param.pitch = sound_param.pitch / 10
		end
		if(r.r_param4 and r.r_param4 ~= "") then
			sound_param.max_hear_distance = math.min(tonumber(r.r_pitch) or 1, 32)
			if(sound_param.max_hear_distance < 3) then
				sound_param.max_hear_distance = 3
			end
			if(sound_param.max_hear_distance > 64) then
				sound_param.max_hear_distance = 64
			end
		end
		sound_param.loop = false
		-- located at the NPC
		sound_param.object = yl_speak_up.speak_to[pname].obj
		if(not(sound_param.object)) then
			return false
		end
		-- actually play the sound
		core.sound_play(r.r_param1, sound_param, true)
		return true
	end
}

-----------------------------------------------------------------------------
-- Custom handling of special properties
-----------------------------------------------------------------------------
-- self.order is used by most mobs_redo NPC and stores weather they ought to
-- stand around, follow the player or wander around randomly
yl_speak_up.custom_property_self_order = function(pname, property_name, property_value, property_data)
	if(property_name ~= "self.order") then
		return "This function handles only the self.order property."
	end
	if(property_value == "stand") then
		property_data.entity.state = "stand"
		property_data.entity.attack = nil
		property_data.entity:set_animation("stand")
		property_data.entity:set_velocity(0)
	elseif(property_value ~= "wander"
	   and property_value ~= "follow") then
		return "self.order can only be set to stand, wander or follow."
	end
	property_data.entity.order = property_value
	return "OK"
end

-- make sure the mod knows how to handle change attempts to the property self.order
yl_speak_up.custom_property_handler["self.order"] = yl_speak_up.custom_property_self_order

