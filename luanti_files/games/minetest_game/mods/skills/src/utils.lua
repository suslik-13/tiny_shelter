function skills.error(pl_name, msg)
	minetest.chat_send_player(pl_name, minetest.colorize("#f47e1b", "[!] " .. msg))
	minetest.sound_play("skills_error", {to_player = pl_name})
end


function skills.print(pl_name, msg)
	minetest.chat_send_player(pl_name, msg)
end


function skills.override_table(original, new)
	local output = table.copy(original)

   for key, new_value in pairs(new) do
		if new_value == "@@nil" then new_value = nil end

		if type(new_value) == "table" and output[key] then
			output[key] = skills.override_table(output[key], new_value)
		else
			output[key] = new_value
		end
   end

	return output
end



function skills.block_other_skills(pl_name)
   for skill_name, def in pairs(skills.get_unlocked_skills(pl_name)) do
		if def.can_be_blocked_by_other_skills then
      	pl_name:stop_skill(skill_name)
		end
   end
end



function skills.cast_passive_skills(pl_name)
	if not skills.player_skills[pl_name] then return false end

	for name, def in pairs(skills.get_unlocked_skills(pl_name)) do
		if def.passive and def.data._enabled then
			pl_name:start_skill(name)
		end
	end
end