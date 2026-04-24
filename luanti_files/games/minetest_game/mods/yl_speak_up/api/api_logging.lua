-- handle logging

-- log changes done by players or admins to NPCs
yl_speak_up.log_change = function(pname, n_id, text, log_level)
	-- make sure all variables are defined
	if(not(pname)) then
		pname = "- unkown player -"
	end
	if(not(n_id)) then
		n_id = "- unknown NPC -"
	end
	if(not(text)) then
		text = "- no text given -"
	end
	if(not(log_level)) then
		log_level = "info"
	end
	-- we don't want newlines in the texts
	text = string.gsub(text, "\n", "\\n")

	-- log in debug.txt
	local log_text = "<"..tostring(n_id).."> ["..tostring(pname).."]: "..text
	minetest.log(log_level, "[MOD] yl_speak_up "..log_text)

	-- log in a file for each npc so that it can be shown when needed
	-- date needs to be inserted manually (minetest.log does it automaticly);
	-- each file logs just one npc, so n_id is not important
	log_text = tostring(os.date("%Y-%m-%d %H:%M:%S ")..tostring(pname).." "..text.."\n")
	n_id = tostring(n_id)
	if(n_id and n_id ~= "" and n_id ~= "n_" and n_id ~= "- unkown NPC -") then
		-- actually append to the logfile
		local file, err = io.open(yl_speak_up.worldpath..yl_speak_up.log_path..DIR_DELIM..
					"log_"..tostring(n_id)..".txt", "a")
		if err then
			minetest.log("error", "[MOD] yl_speak_up Error saving NPC logfile: "..minetest.serialize(err))
			return
		end
		file:write(log_text)
		file:close()
	end

	-- log into a general all-npc-file as well
	local file, err = io.open(yl_speak_up.worldpath..yl_speak_up.log_path..DIR_DELIM..
					"log_ALL.txt", "a")
	if err then
		minetest.log("error","[MOD] yl_speak_up Error saving NPC logfile: "..minetest.serialize(err))
		return
	end
	file:write(tostring(n_id).." "..log_text)
	file:close()
end


-- this is used by yl_speak_up.eval_and_execute_function(..) in fs_edit_general.lua
yl_speak_up.log_with_position = function(pname, n_id, text, log_level)
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		yl_speak_up.log_change(pname, n_id,
			"error: -npc not found- "..tostring(text))
		return
	end
	local obj = yl_speak_up.speak_to[pname].obj
	local n_id = yl_speak_up.speak_to[pname].n_id
	local pos_str = "-unknown-"
	if obj:get_luaentity() and tonumber(npc) then
		pos_str = minetest.pos_to_string(obj:get_pos(),0)
	end
	yl_speak_up.log_change(pname, n_id,
		"NPC at position "..pos_str.." "..tostring(text), log_level)
end
