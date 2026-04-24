-- This file contains what is necessary to add/edit an effect.
--
-- Which diffrent types of effects are available?
-- -> The following fields are part of an effect/result:
-- 	r_id		the ID/key of the effect/result
-- 	r_type		selected from values_what; the staffs allow to use other
-- 			types like "function" or "give_item" etc. - but that is not
-- 			supported here (cannot be edited or created; only be shown)
-- 	r_value		used to store the subtype of r_type
--
-- a state/variable ("state"):
--	r_variable	name of a variable the player has *write* access to;
--	                dropdown list with allowed options
--	r_operator	selected from values_operator
--	r_var_cmp_value can be set freely by the player (the variable will be
--	                set to this value)
--
-- the value of a property of the NPC (for generic NPC) ("property"):
--      r_value         name of the property that is to be changed
--      r_operator      how shall the property be changed?
--      r_var_cmp_value the new value (or increment/decrement) for this property
--
-- something that has to be calculated or evaluated (=call a function) ("evaluate"):
--      r_value         the name of the function that is to be called
--      r_param1        the first paramter (optional; depends on function)
--      ..
--      r_param9        the 9th parameter (optional; depends on function)
--
-- a block in the world ("block"):
--	r_pos		a position in the world; determined by asking the player
--			to punch the block
--	r_node		(follows from r_pos)
--	r_param2	(follows from r_pos)
--
-- place an item into the inventory of a block (i.e. a chest; "put_into_block_inv"):
-- 	r_pos		the position of the target block
-- 	r_inv_list_name	the inventory list where the item shall be moved to (often "main")
-- 	r_itemstack	the itemstack that is to be moved
--
-- take item out of the inventory of a block (i.e. a chest; "take_from_block_inv");
-- 	same as "put_into_block_inv"
--
-- accept items the player has given to the NPC ("deal_with_offered_item"):
-- 	r_value		subtype; one of yl_speak_up.dropdown_values_deal_with_offered_item
--
-- a craft receipe ("craft"):
-- 	r_value		the expected craft result
-- 	r_craft_grid	array containing the stacks in the 9 craft grid fields in string form
--
-- on_failure ("on_failure"):
-- 	r_value		alternate target dialog if the previous *effect* failed
--
-- chat_all ("chat_all"):
-- 	r_value		chat message sent to all players
--
--
-- give item to player ("give_item"): requires yl_speak_up.npc_privs_priv priv
-- 	r_value		the itemstack that shall be added to the player's inventory
--
-- take item from player's inventory ("take_item"): requires yl_speak_up.npc_privs_priv priv
-- 	r_value		the itemstack that will be removed from the player's inventory
--
-- move the player to a position ("move"): requires yl_speak_up.npc_privs_priv priv
-- 	r_value		the position where the player shall be moved to
--
-- execute lua code ("function"): requires npc_master priv
-- 	r_value		the lua code that shall be executed
--
-- Unlike in preconditions, trade (the trade action already happened) and
-- inventory actions are not supported as effects.
--

-- some helper lists for creating the formspecs and evaulating
-- the player's answers:

-- general direction of what could make up an effect
local check_what = {
	"- please select -",
	"an internal state (i.e. of a quest)", -- 2
	"the value of a property of the NPC (for generic NPC)", -- property
	"something that has to be calculated or evaluated (=call a function)", -- evaluate
	"a block somewhere", -- 3
	"put item from the NPC's inventory into a chest etc.", -- 4
	"take item from a chest etc. and put it into the NPC's inventory",
								-- 5
	"an item the player offered to the NPC",
	"NPC crafts something", -- 6
	"go to other dialog if the previous effect failed", -- 7
	"send a chat message to all players", -- 8
	"give item (created out of thin air) to player (requires "..
		tostring(yl_speak_up.npc_priv_needs_player_priv["effect_give_item"]).." priv)", -- 9
	"take item from player and destroy it (requires "..
		tostring(yl_speak_up.npc_priv_needs_player_priv["effect_take_item"]).." priv)", -- 10
	"move the player to a given position (requires "..
		tostring(yl_speak_up.npc_priv_needs_player_priv["effect_move_player"]).." priv)", -- 11
	"execute Lua code (requires npc_master priv)", -- 12
}

-- how to store these as r_type in the precondition:
local values_what = {"", "state",
	"property", "evaluate", "block",
	-- interact with the inventory of blocks on the map
	"put_into_block_inv", "take_from_block_inv",
	-- the player gave an item to the NPC; now deal with it somehow
	"deal_with_offered_item",
	-- crafting, handling failure, send chat message to all
	"craft", "on_failure", "chat_all",
	-- the following require the yl_speak_up.npc_privs_priv priv:
	"give_item", "take_item", "move",
	-- the following require the npc_master priv:
	"function",
	}

-- unlike in the preconditions, the "I cannot punch it" option is
-- not offered here - because the player (and later the NPC) needs
-- to be able to build at this position
local check_block = {
	"- please select -", -- 1
	"If there is air: Place a block so that it looks like now.", -- 2
	"If there is a block: Dig it.", -- 3
	"Punch the block.", -- 4
	"Right-click the block.", -- 5
}

-- how to store these as p_value (the actual node data gets stored as p_node, p_param2 and p_pos):
local values_block = {"", "place", "dig", "punch", "right-click"}

-- comparison operators for variables
local check_operator = {
	"- please select -", -- 1
	"new value:", -- 2
	"discard/unset/forget", -- 3
	"current time", -- 4
	"quest step completed:", -- 5
	minetest.formspec_escape("max(current, new_value)"), -- 6
	minetest.formspec_escape("min(current, new_value)"), -- 7
	"increment by:", -- 8
	"decrement by:", -- 9
}

-- how to store these as r_value (the actual variable is stored in r_variable, and the value in r_new_value):
local values_operator = {"", "set_to", "unset", "set_to_current_time",
	"quest_step", "maximum", "minimum", "increment", "decrement"}


-- get the list of variables the player has *write* access to
yl_speak_up.get_sorted_player_var_list_write_access = function(pname)
	local var_list = {}
	-- some values - like hour of day or HP of the player - can be read in
	-- a precondition but not be modified
	-- get the list of variables the player can *write*
	local tmp = yl_speak_up.get_quest_variables_with_write_access(pname)
	-- sort that list (the dropdown formspec element returns just an index)
	table.sort(tmp)
	for i, v in ipairs(tmp) do
		table.insert(var_list, v)
	end
	return var_list
end


-- helper function for yl_speak_up.show_effect
-- used by "state" and "property"
yl_speak_up.show_effect_with_operator = function(r, var_name)
	if(not(r.r_operator)) then
		return "Error: Operator not defined."
	elseif(r.r_operator == "set_to") then
		return "set "..var_name.." to value \""..
			tostring(r.r_var_cmp_value).."\""
	elseif(r.r_operator == "unset") then
		return "discard "..var_name.." (unset)"
	elseif(r.r_operator == "set_to_current_time") then
		return "set "..var_name.." to the current time"
	elseif(r.r_operator == "quest_step") then
		return "store that the player has completed quest step \""..
			tostring(r.r_var_cmp_value).."\""
	elseif(r.r_operator == "maximum") then
		return "set "..var_name.." to value \""..
			tostring(r.r_var_cmp_value).."\" if its current value is larger than that"
	elseif(r.r_operator == "minimum") then
		return "set "..var_name.." to value \""..
			tostring(r.r_var_cmp_value).."\" if its current value is lower than that"
	elseif(r.r_operator == "increment") then
		return "increment the value of "..var_name.." by \""..
			tostring(r.r_var_cmp_value).."\""
	elseif(r.r_operator == "decrement") then
		return "decrement the value of "..var_name.." by \""..
			tostring(r.r_var_cmp_value).."\""
	else
		return "ERROR: Wrong operator \""..tostring(r.r_operator).."\" for "..var_name
	end
end


-- returns a human-readable text as description of the effects
-- (as shown in the edit options dialog and in the edit effect formspec)
yl_speak_up.show_effect = function(r, pname)
	if(not(r.r_type) or r.r_type == "") then
		return "(nothing): Nothing to do. No effect."
	elseif(r.r_type == "give_item") then
		return "give_item: Add \""..tostring(r.r_value).."\" to the player's inventory."
	elseif(r.r_type == "take_item") then
		return "take_item: Take \""..tostring(r.r_value).."\" from the player's inventory."
	elseif(r.r_type == "move") then
		return "move: Move the player to "..tostring(r.r_value).."."
	elseif(r.r_type == "function") then
		return "function: execute \""..tostring(r.r_value).."\"."
	elseif(r.r_type == "trade") then
		return "trade: obsolete (now defined as an action)"
	elseif(r.r_type == "dialog") then
		return "Switch to dialog \""..tostring(r.r_value).."\"."
	elseif(r.r_type == "state") then
		local var_name = "VARIABLE[ - ? - ]"
                if(r.r_variable) then
                        var_name = "VARIABLE[ "..tostring(
                                        yl_speak_up.strip_pname_from_var(r.r_variable, pname)).." ]"
                end
		return yl_speak_up.show_effect_with_operator(r, var_name)
	-- the value of a property of the NPC (for generic NPC) ("property"):
	elseif(r.r_type == "property") then
		local var_name = "PROPERTY[ "..tostring(r.r_value or "- ? -").." ]"
		return yl_speak_up.show_effect_with_operator(r, var_name)
	-- something that has to be calculated or evaluated (=call a function) ("evaluate"):
	elseif(r.r_type == "evaluate") then
		local str = ""
		for i = 1, 9 do
			str = str..tostring(r["r_param"..tostring(i)])
			if(i < 9) then
				str = str..","
			end
		end
		return "FUNCTION["..tostring(r.r_value).."]("..str..")"
	elseif(r.r_type == "block") then
		if(not(r.r_pos) or type(r.r_pos) ~= "table"
		  or not(r.r_pos.x) or not(r.r_pos.y) or not(r.r_pos.z)) then
			return "ERROR: r.r_pos is "..minetest.serialize(r.r_pos)
		-- we don't check here yet which node is actually there - that will be done upon execution
		elseif(yl_speak_up.check_blacklisted(r.r_value, r.r_node, r.r_node)) then
			return "ERROR: Blocks of type \""..tostring(r.r_node).."\" do not allow "..
				"interaction of type \""..tostring(r.r_value).."\" for NPC."
		elseif(r.r_value == "place") then
			return "Place \""..tostring(r.r_node).."\" with param2: "..tostring(r.r_param2)..
				" at "..minetest.pos_to_string(r.r_pos).."."
		elseif(r.r_value == "dig") then
			return "Dig the block at "..minetest.pos_to_string(r.r_pos).."."
		elseif(r.r_value == "punch") then
			return "Punch the block at "..minetest.pos_to_string(r.r_pos).."."
		elseif(r.r_value == "right-click") then
			return "Right-click the block at "..minetest.pos_to_string(r.r_pos).."."
		else
			return "ERROR: Don't know what to do with the block at "..
				minetest.pos_to_string(r.r_pos)..": \""..tostring(r.r_value).."\"?"
		end
	elseif(r.r_type == "craft") then
		-- this is only shown in the edit options menu and when editing an effect;
		-- we can afford a bit of calculation here (it's not a precondtion...)
		if(not(r.r_value) or not(r.r_craft_grid)) then
			return "ERROR: Crafting not configured correctly."
		end
		local craft_str = "Craft \""..tostring(r.r_value).."\" from "..
			table.concat(r.r_craft_grid, ", ").."."
		-- check here if the craft receipe is broken
		local input = {}
		input.items = {}
		for i, v in ipairs(r.r_craft_grid) do
			input.items[ i ] = ItemStack(v or "")
		end
		input.method = "normal" -- normal crafting; no cooking or fuel or the like
		input.width = 3
		local output, decremented_input = minetest.get_craft_result(input)
		if(output.item:is_empty()) then
			return "Error: Recipe changed! No output for "..craft_str
		end
		-- the craft receipe may have changed in the meantime and yield a diffrent result
		local expected_stack = ItemStack(r.r_value)
		if(output.item:get_name() ~= expected_stack:get_name()
		  or output.item:get_count() ~= expected_stack:get_count()) then
			return "Error: Amount of output changed! "..craft_str
		end
		return craft_str
	elseif(r.r_type == "on_failure") then
		return "If the *previous* effect failed, go to dialog \""..tostring(r.r_value).. "\"."
	elseif(r.r_type == "chat_all") then
		return "Send chat message: \""..tostring(r.r_value).."\""
	elseif(r.r_type == "put_into_block_inv") then
		if(not(r.r_pos) or type(r.r_pos) ~= "table"
		  or not(r.r_pos.x) or not(r.r_pos.y) or not(r.r_pos.z)) then
			return "ERROR: r.r_pos is "..minetest.serialize(r.r_pos)
		end
		return "Put item \""..tostring(r.r_itemstack).."\" from NPC inv into block at "..
			minetest.pos_to_string(r.r_pos)..
			" in inventory list \""..tostring(r.r_inv_list_name).."\"."
	elseif(r.r_type == "take_from_block_inv") then
		if(not(r.r_pos) or type(r.r_pos) ~= "table"
		  or not(r.r_pos.x) or not(r.r_pos.y) or not(r.r_pos.z)) then
			return "ERROR: r.r_pos is "..minetest.serialize(r.r_pos)
		end
		return "Take item \""..tostring(r.r_itemstack).."\" from block at "..
			minetest.pos_to_string(r.r_pos)..
			" out of inventory list \""..tostring(r.r_inv_list_name)..
			"\" and put it into the NPC's inventory."
	elseif(r.r_type == "deal_with_offered_item") then
		local nr = 1
		if(r.r_value) then
			nr = math.max(1, table.indexof(yl_speak_up.dropdown_values_deal_with_offered_item,
						 r.r_value))
			return yl_speak_up.dropdown_list_deal_with_offered_item[ nr ]
		end
		return "ERROR: Missing subtype r.r_value: \""..tostring(r.r_value).."\""
	end
	-- fallback
	return tostring(r.r_value)
end

-- these are only wrapper functions for those in fs_edit_general.lua

yl_speak_up.input_edit_effects = function(player, formname, fields)
	return yl_speak_up.handle_input_fs_edit_option_related(player, formname, fields,
		"r_", "o_results", yl_speak_up.max_result_effects,
		"(Ef)fect", "tmp_result",
		"Please punch the block you want to manipulate in your effect!",
		values_what, values_operator, values_block, {}, {},
		check_what, check_operator, check_block, {}, {},
		-- player variables with write access
		yl_speak_up.get_sorted_player_var_list_write_access,
		"edit_effects"
		)
end

yl_speak_up.get_fs_edit_effects = function(player, table_click_result)
	return yl_speak_up.build_fs_edit_option_related(player, table_click_result,
		"r_", "o_results", yl_speak_up.max_result_effects,
		"(Ef)fect", "tmp_result",
		"What do you want to change with this effect?",
		values_what, values_operator, values_block, {}, {},
		check_what, check_operator, check_block, {}, {},
		-- player variables with write access
		yl_speak_up.get_sorted_player_var_list_write_access,
		yl_speak_up.show_effect,
		"table_of_elements",
		"Change the value of the following variable:", "Set variable to:", "New value:",
		"The NPC shall do something to the block at the following position:"
		)
end


yl_speak_up.register_fs("edit_effects",
	yl_speak_up.input_edit_effects,
	yl_speak_up.get_fs_edit_effects,
	-- no special formspec required:
	nil
)
