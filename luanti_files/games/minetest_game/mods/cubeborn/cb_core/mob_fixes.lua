-- Fixes to mobs_redo shared by every mob (BACKLOG 16). A dying mob keeps the
-- cause of death with the puncher object in it; a tame or npc mob saved then
-- (shutdown, unload during the death animation) crashed the serializer. The
-- cause is left out of the saved data and kept for the death drops.
core.register_on_mods_loaded(function()
	local mobs = rawget(_G, "mobs")
	local class = mobs and mobs.mob_class
	if not (class and class.mob_staticdata) then
		return
	end
	local mob_staticdata = class.mob_staticdata
	class.mob_staticdata = function(self, ...)
		local cause = self.cause_of_death
		self.cause_of_death = nil
		local ok, sd = pcall(mob_staticdata, self, ...)
		self.cause_of_death = cause
		if not ok then
			error(sd, 0)
		end
		return sd
	end
end)

-- The owner of a tamed Cubeborn mob names it with a name tag and protects it
-- with a protection rune. Cubeborn mobs have their own right-click handlers
-- that never reached mobs_redo's naming and protection, so the click is caught
-- first for every cb_mobs_* mob. Others keep the mob's own handler.
local OWNER_TOOLS = { ["mobs:nametag"] = true, ["mobs:protector"] = true, ["mobs:protector2"] = true, }

function cb_core.mob_owner_tool(self, clicker)
	local mobs = rawget(_G, "mobs")
	if not (mobs and self.tamed and clicker and clicker:is_player()) then
		return false
	end
	local item = clicker:get_wielded_item():get_name()
	local name = clicker:get_player_name()
	if not OWNER_TOOLS[item] or (self.owner ~= name and not core.check_player_privs(name, "protection_bypass")) then
		return false
	end
	if item == "mobs:nametag" then
		-- mobs_redo's name tag form (the food branch needs food in hand)
		return mobs:feed_tame(self, clicker, 1, false, false)
	end
	return mobs:protect(self, clicker)
end

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_entities) do
		if name:find("^cb_mobs_") and def._cmi_is_mob and def.on_rightclick then
			local on_rightclick = def.on_rightclick
			def.on_rightclick = function(self, clicker, ...)
				if cb_core.mob_owner_tool(self, clicker) then
					return
				end
				return on_rightclick(self, clicker, ...)
			end
		end
	end
end)
