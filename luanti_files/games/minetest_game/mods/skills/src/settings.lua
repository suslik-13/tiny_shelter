skills.settings = {}

local function is_file_in_dir(dir, file)
	for i, file_ in ipairs(minetest.get_dir_list(dir, false)) do
		if file_ == file then return true end
	end
end

-- import default settings
dofile(minetest.get_modpath("skills") .. "/SETTINGS.lua")

-- import custom_settings
local skills_dir = minetest.get_worldpath() .. "/skills"

if is_file_in_dir(skills_dir, "SETTINGS.lua") then
	dofile(skills_dir .. "/SETTINGS.lua")
end
