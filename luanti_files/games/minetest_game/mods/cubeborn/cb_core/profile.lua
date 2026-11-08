-- Which parts of Cubeborn this server runs. Detected from the installed mods,
-- every value can be overridden in minetest.conf.
local nether = cb_core.setting("cubeborn.nether", core.get_modpath("nether") and "external" or "own")
if nether ~= "own" and nether ~= "external" and nether ~= "off" then
	core.log("warning", "[cubeborn] invalid cubeborn.nether = " .. nether .. ", using own")
	nether = "own"
end

cb_core.profile = {
	nether = nether,
	end_dim = core.settings:get_bool("cubeborn.end", true),
}

core.log("action", "[cubeborn] profile: nether=" .. nether .. " end=" .. tostring(cb_core.profile.end_dim))
