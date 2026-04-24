-- This file contains what is necessary to add/edit an action.
--
-- Which diffrent types of actions are available?
-- -> The following fields are part of an action:
-- 	a_id		the ID/key of the action
-- 	a_type		selected from values_what
-- 	a_value		used to store the subtype of a_type
--
-- no action (none):    nothing to do.
--
-- a trade ("trade"):
--      a_buy           what the NPC sells (itemstack)
--      a_pay           what the NPC wants as payment (itemstack)
--
-- giving and taking of items ("npc_gives" and "npc_wants"):
--	a_on_failure	if the action fails, go to this dialog
--	a_value		itemstack of the given/wanted item in string form
--	a_item_desc	the description the NPC shall set for that itemstack
--			(so that the player can distinguish it from other
--			itemstacks with the same items)
--	a_item_quest_id	Special ID to make sure that it is really the *right*
--			item and not just something the player faked with an
--			engraving table or something similar
--
-- the player has to enter text ("text_input"):
--      a_value         the expected answer the player has to enter
--      a_question      the question the NPC shall ask the player (so that the
--                      player can know which answer is expected here)
--
-- Show something custom (has to be provided by the server). (=call a function) ("evaluate"):
--      a_value         the name of the function that is to be called
--      a_param1        the first paramter (optional; depends on function)
--      ..
--      a_param9        the 9th parameter (optional; depends on function)
--
-- a general, more complex formspec-basted puzzle ("puzzle"): not supported
--                      (custom may be more helpful)
--
--
-- Note: Trades are not stored as actions - they are stored in
-- dialog.trades[ trade_id ] with <trade_id> == "<d_id>  <o_id>"
--

-- some helper lists for creating the formspecs and evaulating
-- the player's answers:

-- general direction of what could make up an action
local check_what = {
	"- please select -",
	"No action (default).", -- 2
	"Normal trade - one item(stack) for another item(stack).", -- 3
	"The NPC gives something to the player (i.e. a quest item).", -- 4
	"The player is expected to give something to the NPC (i.e. a quest item).", -- 5
	"The player has to manually enter a password or passphrase or some other text.", -- 6
	"Show something custom (has to be provided by the server).",
	-- "The player has to move virtual items in a virtual inventory to the right position.", -- 8
}

-- how to store these as a_type in the action:
local values_what = {"", "none", "trade", "npc_gives", "npc_wants", "text_input", "evaluate", "puzzle"}


-- returns a human-readable text as description of the action
-- (as shown in the edit options dialog and in the edit effect formspec)
yl_speak_up.show_action = function(a)
	if(not(a.a_type) or a.a_type == "" or a.a_type == "none") then
		return "(nothing): Nothing to do. No action."
	elseif(a.a_type == "trade") then
		return "NPC sells \""..table.concat(a.a_buy, ";").."\" for \""..
			table.concat(a.a_pay, ";").."\"."
	elseif(a.a_type == "npc_gives") then
		return "The NPC gives \""..tostring(a.a_item_desc or "- default description -")..
			"\" (\""..tostring(a.a_value or "- ? -").."\") "..
			"with ID \""..tostring(a.a_item_quest_id or "- no special ID -").."\"."
	elseif(a.a_type == "npc_wants") then
		return "The NPC wants \""..tostring(a.a_item_desc or "- default description -")..
			"\" (\""..tostring(a.a_value or "- ? -").."\") "..
			"with ID \""..tostring(a.a_item_quest_id or "- no special ID -").."\"."
	elseif(a.a_type == "text_input") then
		return "Q: \""..tostring(a.a_question).."\" A:\""..tostring(a.a_value).."\"."
	elseif(a.a_type == "evaluate") then
		local str = ""
		for i = 1, 9 do
			str = str..tostring(a["a_param"..tostring(i)])
			if(i < 9) then
				str = str..","
			end
		end
		return "FUNCTION["..tostring(a.a_value).."]("..str..")"
-- puzzle is unused; better do that via custom
--	elseif(a.a_type == "puzzle") then
--		return "puzzle:"
	end
	-- fallback
	return tostring(a.a_value)
end

-- these are only wrapper functions for those in fs_edit_general.lua

yl_speak_up.input_edit_actions = function(player, formname, fields)
	return yl_speak_up.handle_input_fs_edit_option_related(player, formname, fields,
		"a_", "actions", yl_speak_up.max_actions,
		"(A)ctions", "tmp_action",
		nil, -- unused - no block operations
		values_what, {}, {}, {}, {},
		check_what, {}, {}, {}, {},
		nil, -- no variables
		"edit_actions"
		)
end

yl_speak_up.get_fs_edit_actions = function(player, table_click_result)
	return yl_speak_up.build_fs_edit_option_related(player, table_click_result,
		"a_", "actions", yl_speak_up.max_actions,
		"(A)ctions", "tmp_action",
		"What do you want to happen in this (A)ction?",
		values_what, {}, {}, {}, {},
		check_what, {}, {}, {}, {},
		nil, -- no variables
		yl_speak_up.show_action,
		"table_of_elements",
		nil, nil, nil, -- no variable handling here
		nil -- nothing block-related to do here
		)
end


yl_speak_up.register_fs("edit_actions",
	yl_speak_up.input_edit_actions,
	yl_speak_up.get_fs_edit_actions,
	-- no special formspec required:
	nil
)
