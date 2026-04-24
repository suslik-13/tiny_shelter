
local old_action_inv_changed = yl_speak_up.action_inv_changed
-- monitor changes to the npc_gives and npc_wants slots (in particular when editing actions)
-- how: can be "put" or "take"
yl_speak_up.action_inv_changed = function(inv, listname, index, stack, player, how)
	if(not(player)) then
		return
	end
	local pname = player:get_player_name()
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return
	end
	local n_id = yl_speak_up.speak_to[pname].n_id
	-- if not in edit mode: the player may just be normally interacting with the NPC;
	-- nothing to do for us here (wait for the player to click on "save")
	if(not(n_id) or yl_speak_up.edit_mode[pname] ~= n_id) then
		return old_action_inv_changed(inv, listname, index, stack, player, how)
	end
	-- is the player in the process of editing an action of the npc_gives/npc_wants type?
	local target_fs = "edit_actions"
	local data = yl_speak_up.speak_to[pname][ "tmp_action" ]
	if(not(data) or (data.what ~= 4 and data.what ~= 5)) then
		-- we are editing an action
		if(data) then
			return
		end
		-- it might be a precondition
		data = yl_speak_up.speak_to[pname][ "tmp_prereq" ]
		if(not(data) or (data.what ~= 8)) then
			return
		end
		target_fs = "edit_preconditions"
	end
	-- "The NPC gives something to the player (i.e. a quest item).", -- 4
	-- "The player is expected to give something to the NPC (i.e. a quest item).", -- 5
	if(how == "put") then
		data.item_node_name = stack:get_name().." "..stack:get_count()
		local meta = stack:get_meta()
		if(meta and meta:get_string("description")) then
			-- try to reconstruct $PLAYER_NAME$ (may not always work)
			local item_was_for = meta:get_string("yl_speak_up:quest_item_for")
			local new_desc = meta:get_string("description")
			if(item_was_for and item_was_for ~= "") then
				new_desc = string.gsub(new_desc, item_was_for, "$PLAYER_NAME$")
			end
			data.item_desc = new_desc
		end
		if(meta and meta:get_string("yl_speak_up:quest_id")) then
			data.item_quest_id = meta:get_string("yl_speak_up:quest_id")
		end
	elseif(how == "take" and data.what == 4) then
		data.item_desc = "- no item set -"
		data.item_node_name = ""
	elseif(how == "take" and data.what == 5) then
		data.item_desc = "- no item set -"
		data.item_node_name = ""
	end
	-- show the updated formspec to the player
	yl_speak_up.show_fs(player, target_fs, nil)
	-- no need to check anything more here; the real checks need to be done
	-- when the player presses the save/store/execute button
end
