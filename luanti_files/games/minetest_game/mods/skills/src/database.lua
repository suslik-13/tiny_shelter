local function remove_userdata() end

local storage = minetest.get_mod_storage()

--[[
    {
        "player": {
            {"mod:skill1" = {...}},
            {"mod:skill2" = {...}}
        }
    }
--]]
skills.player_skills = minetest.deserialize(storage:get_string("player_skills")) or {}



minetest.register_on_mods_loaded(function()
	skills.update_db()
end)




function skills.update_db()
	local pl_skills_without_userdata = table.copy(skills.player_skills)
	remove_userdata(pl_skills_without_userdata)

   storage:set_string("player_skills", minetest.serialize(pl_skills_without_userdata))

	minetest.after(10, skills.update_db)
end



function skills.remove_unregistered_skills_from_db()
	for pl_name, pl_skills in pairs(skills.player_skills) do
		for skill_name, def in pairs(pl_skills) do
			if not skills.get_skill_def(skill_name) then pl_skills[skill_name] = nil end
		end
	end
end



function remove_userdata(t)
	for key, value in pairs(t) do
		if type(value) == "table" then remove_userdata(value) end
		if minetest.is_player(value) or type(value) == "userdata" or type(value) == "function" then t[key] = nil end
	end
end