-- This file contains what is necessary to add/edit a precondition.
--
-- Which diffrent types of preconditions are available?
-- -> The following fields are part of a precondition:
-- 	p_id		the ID/key of the precondition/prerequirement
-- 	p_type		selected from values_what
-- 	p_value		used to store the subtype of p_type
--
-- a state/variable ("state"):
--	p_variable	name of a variable the player has read access to;
--	                dropdown list with allowed options
--	p_operator	selected from values_operator
--	p_var_cmp_value can be set freely by the player
--
-- the value of a property of the NPC (for generic NPC) ("property"):
-- 	p_value   	name of the property that shall be checked
-- 	p_operator	operator for cheking the property against p_expected_val
-- 	p_var_cmp_value	the expected value of the property
--
-- something that has to be calculated or evaluated (=call a function) ("evaluate"):
-- 	p_value   	the name of the function that is to be called
-- 	p_param1	the first paramter (optional; depends on function)
-- 	..
-- 	p_param9	the 9th parameter (optional; depends on function)
-- 	p_operator	operator for checking the result
-- 	p_var_cmp_value	compare the result of the function with this value
--
-- a block in the world ("block"):
--	p_pos		a position in the world; determined by asking the player
--			to punch the block
--	p_node		(follows from p_pos)
--	p_param2	(follows from p_pos)
--
-- a trade defined as an action ("trade"): no variables needed (buy and pay stack
-- 			follow from the trade set as action)
--
-- an inventory: ("player_inv", "npc_inv" or "block_inv")
-- 	p_itemstack	an itemstack; needs to be a minetest.registered_item[..];
-- 			size/count is also checked
--
-- the inventory of a block on the map: ("block_inv", in addition to the ones above)
--	p_pos		a position in the world; determined by asking the player
--			to punch the block
--	p_inv_list_name name of the inventory list of the block
--
-- the player offered/gave the NPC an item: ("player_offered_item"):
-- 	p_value    	an itemstack; needs to be a minetest.registered_item[..];
-- 	                size/count is checked for some subtypes
--      p_match_stack_size   does the NPC expect exactly one stack size - or is
--                           more or less etc. also ok?
--      p_item_group    are items of this group instead of the exact item name
--                      also acceptable?
--      p_item_desc     the description of the itemstack (set by another quest NPC
--                      so that the player can distinguish it from other itemstacks
--                      with the same item name; see action "npc_gives")
--      p_item_quest_id Special ID to make sure that it is really the *right*
--                      item and not just something the player faked with an
--                      engraving table or something similar
--
-- a function ("function"): requires npc_master to create and edit
--      p_value         the lua code to execute and evaulate
--
-- depends on another option:
--      p_value         name of the other option of this dialog that is considered
--      p_fulfilled     shall option p_value be true or false?
--
-- the type of the entity of the NPC:
-- 	p_value		name of the entity (i.e. npc_talk:talking_npc)


-- some helper lists for creating the formspecs and evaulating
-- the player's answers:

-- general direction of what a prerequirement may be about
local check_what = {
	"- please select -",
	"an internal state (i.e. of a quest)", -- 2
	"the value of a property of the NPC (for generic NPC)",
	"something that has to be calculated or evaluated (=call a function)",
	"a block somewhere", -- 3
	"a trade", -- 4
	"the inventory of the player", -- 5
	"the inventory of the NPC", -- 6
	"the inventory of a block somewhere", -- 7
	"an item the player offered/gave to the NPC", -- 8
	"execute Lua code (requires npc_master priv)", -- 7 -> 9
	"The preconditions of another dialog option are fulfilled/not fulfilled.", -- 9 -> 11
	"nothing - always true (useful for generic dialogs)",
	"nothing - always false (useful for temporally deactivating an option)",
	"the type of the entity of the NPC",
}

-- how to store these as p_type in the precondition:
local values_what = {"", "state", "property", "evaluate", "block", "trade",
	"player_inv", "npc_inv", "block_inv",
	"player_offered_item",
	-- "function" requires npc_master priv:
	"function",
	-- depends on the preconditions of another option
	"other",
	"true", "false",
	"entity_type"}

-- options for "a trade"
local check_trade = {
	"- please select -",
	"The NPC has the item(s) he wants to sell in his inventory.", -- 2
	"The player has the item(s) needed to pay the price.", -- 3
	"The NPC ran out of stock.", -- 4
	"The player cannot afford the price.", -- 5
}

-- how to store these as p_value:
local values_trade = {"", "npc_can_sell", "player_can_buy", "npc_is_out_of_stock", "player_has_not_enough"}

-- options for "the inventory of " (either player or NPC; perhaps blocks later on)
local check_inv = {
	"- please select -",
	"The inventory contains the following item:",
	"The inventory *does not* contain the following item:",
	"There is room for the following item in the inventory:",
	"The inventory is empty.",
}

-- how to store these as p_value (the actual itemstack gets stored as p_itemstack):
local values_inv = {"", "inv_contains", "inv_does_not_contain", "has_room_for", "inv_is_empty"}

local check_block = {
	"- please select -",
	"The block is as it is now.",
	"There shall be air instead of this block.",
	"The block is diffrent from how it is now.",
	"I can't punch it. The block is as the block *above* the one I punched.",
}

-- how to store these as p_value (the actual node data gets stored as p_node, p_param2 and p_pos):
-- Note: "node_is_like" occours twice because it is used to cover blocks that
--       cannot be punched as well as normal blocks.
local values_block = {"", "node_is_like", "node_is_air", "node_is_diffrent_from", "node_is_like"}

-- comparison operators for variables
local check_operator = {
	"- please select -", -- 1
	"== (is equal)", -- 2
	"~= (is not equal)", -- 3
	">= (is greater or equal)", -- 4
	">  (is greater)", -- 5
	"<= (is smaller or equal)", -- 6
	"<  (is smaller)", -- 7
	"not (logically invert)", -- 8
	"is_set (has a value)", -- 9
	"is_unset (has no value)", -- 10
	"more than x seconds ago", -- 11
	"less than x seconds ago", -- 12
	"has completed quest step", -- 13
	"quest step *not* completed", -- 14
}

-- how to store these as p_value (the actual variable is stored in p_variable, and the value in p_cmp_value):
local values_operator = {"", "==", "~=", ">=", ">", "<=", "<", "not", "is_set", "is_unset",
	"more_than_x_seconds_ago","less_than_x_seconds_ago",
	"quest_step_done", "quest_step_not_done"}



-- get the list of variables the player has read access to
yl_speak_up.get_sorted_player_var_list_read_access = function(pname)
	local var_list = {}
	-- copy the values that are server-specific
	for i, v in ipairs(yl_speak_up.custom_server_functions.precondition_descriptions) do
		table.insert(var_list, v)
	end
	-- get the list of variables the player can read
	local tmp = yl_speak_up.get_quest_variables_with_read_access(pname)
	-- sort that list (the dropdown formspec element returns just an index)
	table.sort(tmp)
	for i, v in ipairs(tmp) do
		table.insert(var_list, v)
	end
	return var_list
end


-- returns a human-readable text as description of the precondition
-- (as shown in the edit options dialog and in the edit precondition formspec)
yl_speak_up.show_precondition = function(p, pname)
	if(not(p.p_type) or p.p_type == "") then
		return "(nothing): Always true."
	elseif(p.p_type == "item") then
		return "item: The player has \""..tostring(p.p_value).."\" in his inventory."
	elseif(p.p_type == "quest") then
		return "quest: Always false."
	elseif(p.p_type == "auto") then
		return "auto: Always true."
	elseif(p.p_type == "true") then
		return "true: Always true."
	elseif(p.p_type == "false") then
		return "false: Always false."
	elseif(p.p_type == "function") then
		return "function: evaluate "..tostring(p.p_value)
	elseif(p.p_type == "state") then
		local var_name = "VALUE_OF[ - ? - ]"
		if(p.p_variable) then
			var_name = "VALUE_OF[ "..tostring(
					yl_speak_up.strip_pname_from_var(p.p_variable, pname)).." ]"
		end
		if(not(p.p_operator)) then
			return "Error: Operator not defined."
		elseif(p.p_operator == "not") then
			return "not( "..var_name.." )"
		elseif(p.p_operator == "is_set") then
			return var_name.." ~= nil (is_set)"
		elseif(p.p_operator == "is_unset") then
			return var_name.." == nil (is_unset)"
		elseif(p.p_operator == "more_than_x_seconds_ago") then
			return var_name.." was set to current time "..
				"*more* than "..tostring(p.p_var_cmp_value).." seconds ago"
		elseif(p.p_operator == "less_than_x_seconds_ago") then
			return var_name.." was set to current time "..
				"*less* than "..tostring(p.p_var_cmp_value).." seconds ago"
		elseif(p.p_operator == "quest_step_done") then
			return var_name.." shows: player completed quest step \""..
				tostring(p.p_var_cmp_value).."\" successfully"
		elseif(p.p_operator == "quest_step_not_done") then
			return var_name.." shows: player has not yet completed quest step \""..
				tostring(p.p_var_cmp_value).."\""
		end
		if(p.p_var_cmp_value == "") then
			return var_name.." "..tostring(p.p_operator).." \"\""
		end
		return var_name.." "..tostring(p.p_operator).." "..
			tostring(p.p_var_cmp_value)
	elseif(p.p_type == "property") then
		local i = math.max(1,table.indexof(values_operator, p.p_operator))
		return tostring(p.p_value)..
			" "..tostring(check_operator[i])..
			" "..tostring(p.p_var_cmp_value)
	elseif(p.p_type == "evaluate") then
		local str = ""
		for i = 1, 9 do
			str = str..tostring(p["p_param"..tostring(i)])
			if(i < 9) then
				str = str..","
			end
		end
		local i_op = math.max(1,table.indexof(values_operator, p.p_operator))
		return "FUNCTION["..tostring(p.p_value).."]"..
			"("..str..") "..tostring(check_operator[i_op])..
			" "..tostring(p.p_var_cmp_value)
	elseif(p.p_type == "block") then
		if(not(p.p_pos) or type(p.p_pos) ~= "table"
		  or not(p.p_pos.x) or not(p.p_pos.y) or not(p.p_pos.z)) then
			return "ERROR: p.p_pos is "..minetest.serialize(p.p_pos)
		elseif(p.p_value == "node_is_like") then
			return "The block at "..minetest.pos_to_string(p.p_pos).." is \""..
				tostring(p.p_node).."\" with param2: "..tostring(p.p_param2).."."
		elseif(p.p_value == "node_is_air") then
			return "There is no block at "..minetest.pos_to_string(p.p_pos).."."
		elseif(p.p_value == "node_is_diffrent_from") then
			return "There is another block than \""..tostring(p.p_node).."\" at "..
				minetest.pos_to_string(p.p_pos)..", or it is at least "..
				"rotated diffrently (param2 is not "..tostring(p.p_param2)..")."
		end
	elseif(p.p_type == "trade") then
		local nr = table.indexof(values_trade, p.p_value)
		if(nr and check_trade[ nr ]) then
			return check_trade[ nr ]
		end
	elseif(p.p_type == "player_inv" or p.p_type == "npc_inv" or p.p_type == "block_inv") then
		local who = "The player"
		local what = "\""..tostring(p.p_itemstack).."\" in his inventory."
		if(p.p_type == "npc_inv") then
			who = "The NPC"
		elseif(p.p_type == "block_inv") then
			if(not(p.p_pos) or type(p.p_pos) ~= "table"
			  or not(p.p_pos.x) or not(p.p_pos.y) or not(p.p_pos.z)) then
				return "ERROR: p.p_pos is "..minetest.serialize(p.p_pos)
			end
			who = "The block at "..minetest.pos_to_string(p.p_pos)
			what = "\""..tostring(p.p_itemstack).."\" in inventory list \""..
				tostring(p.p_inv_list_name).."\"."
		end
		if(p.p_value == "inv_contains") then
			return who.." has "..what
		elseif(p.p_value == "inv_does_not_contain") then
			return who.." does not have "..what
		elseif(p.p_value == "has_room_for") then
			return who.." has room for "..what
		elseif(p.p_value == "inv_is_empty") then
			if(p.p_type == "block_inv") then
				return who.." has an empty inventory list \""..
					tostring(p.p_inv_list_name).."\"."
			end
			return who.." has an empty inventory."
		end
	elseif(p.p_type == "player_offered_item") then
		local item = tostring(p.p_value:split(" ")[1])
		local amount = tostring(p.p_value:split(" ")[2])
		local match = "any amount"
		if(p.p_match_stack_size == "any") then
			match = "any amount"
		elseif(p.p_match_stack_size == "exactly") then
			match = "exactly "..tostring(amount)
		elseif(p.p_match_stack_size == "less"
		    or p.p_match_stack_size == "more") then
			match = p.p_match_stack_size.." than "..tostring(amount)
		elseif(p.p_match_stack_size == "another") then
			match = "another amount than " ..tostring(amount)
		end
		if(p.p_item_group and p.p_item_group ~= "") then
			return "The player offered "..tostring(match).." item(s) of the group \""..
				tostring(item).."\"."
		elseif((p.p_item_quest_id and p.p_item_quest_id ~= "")
		    or (p.p_item_desc and p.p_item_desc ~= "")) then
			return "The player offered "..tostring(match).." of \""..
				tostring(p.p_item_desc or "- default description -")..
	                        "\" (\""..tostring(item or "- ? -").."\") "..
	                        "with ID \""..tostring(p.p_item_quest_id or "- no special ID -").."\"."
		else
			return "The player offered "..tostring(match).." of \""..tostring(item).."\"."
		end
	elseif(p.p_type == "other") then
		local fulfilled = "fulfilled"
		if(not(p.p_fulfilled) or p.p_fulfilled ~= "true") then
			fulfilled = "*not* fulfilled"
		end
		return "The preconditions for dialog option \""..tostring(p.p_value).."\" are "..
			fulfilled.."."
	elseif(p.p_type == "entity_tpye") then
		return "the type of the entity of the NPC is: \""..tostring(p.p_value).."\"."
	end
	-- fallback
	return tostring(p.p_value)
end


-- these are only wrapper functions for those in fs_edit_general.lua

yl_speak_up.input_edit_preconditions = function(player, formname, fields)
	return yl_speak_up.handle_input_fs_edit_option_related(player, formname, fields,
		"p_", "o_prerequisites", yl_speak_up.max_prerequirements,
		"pre(C)ondition", "tmp_prereq",
		"Please punch the block you want to check in your precondition!",
		values_what, values_operator, values_block, values_trade, values_inv,
		check_what, check_operator, check_block, check_trade, check_inv,
		-- player variables with read access
		yl_speak_up.get_sorted_player_var_list_read_access,
		"edit_preconditions"
		)
end


yl_speak_up.get_fs_edit_preconditions = function(player, table_click_result)
	return yl_speak_up.build_fs_edit_option_related(player, table_click_result,
		"p_", "o_prerequisites", yl_speak_up.max_prerequirements,
		"pre(C)ondition", "tmp_prereq",
		"What do you want to check in this precondition?",
		values_what, values_operator, values_block, values_trade, values_inv,
		check_what, check_operator, check_block, check_trade, check_inv,
		-- player variables with read access
		yl_speak_up.get_sorted_player_var_list_read_access,
		-- show one precondition element
		yl_speak_up.show_precondition,
		"table_of_preconditions",
		"The following expression shall be true:", "Operator:",
		"Value to compare with (in some cases parameter):",
		"The following shall be true about the block:"
		)
end


yl_speak_up.register_fs("edit_preconditions",
	yl_speak_up.input_edit_preconditions,
	yl_speak_up.get_fs_edit_preconditions,
	-- no special formspec required:
	nil
)
