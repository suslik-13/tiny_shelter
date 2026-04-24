local function restore_celestial_vault() end



function skills.stop(self)
	local data = self.data

	if not self.is_active then return false end
	self.is_active = false

	if not minetest.get_player_by_name(self.pl_name) then return false end

	if self.blocks_other_skills and skills.blocking_skills[self.pl_name] == self.internal_name then
		skills.blocking_skills[self.pl_name] = nil
		skills.cast_passive_skills(self.pl_name)
	end

	skills.play_sound(self, self.sounds.stop, true)

	-- I don't know. MT is weird or maybe my code is just bugged:
	-- without this after, if the skills ends very quickly the
	-- spawner and the sound simply... don't stop.
	minetest.after(0, function()
		-- Stop sound
		if data._bgm then minetest.sound_stop(data._bgm) end

		-- Remove particles
		if data._particles then
			for i, spawner_id in pairs(data._particles) do
				minetest.delete_particlespawner(spawner_id)
			end
		end

		-- Remove hud
		if data._hud then
			for name, id in pairs(data._hud) do
				self.player:hud_remove(id)
			end
		end
	end)

	restore_celestial_vault(self)

	-- Undo physics_override changes
	if self.physics then
		local reverse = {
			["multiply"] = "divide",
			["divide"] = "multiply",
			["add"] = "sub",
			["sub"] = "add",
		}
		local operation = reverse[self.physics.operation] -- multiply/divide/add/sub
		
		for property, value in pairs(self.physics) do
			if property ~= "operation" then
				_G["skills"][operation.."_physics"](self.pl_name, property, value)
			end
		end
	end

	self:on_stop()

	return true
end



function restore_celestial_vault(skill)
	local data = skill.data
	local cel_vault = skill.celestial_vault or {}

	-- Restore sky
	if cel_vault.sky then
		local pl = skill.player
		pl:set_sky(data._sky)
		data._sky = {}
	end

	-- Restore clouds
	if cel_vault.clouds then
		local pl = skill.player
		pl:set_clouds(data._clouds)
		data._clouds = {}
	end

	-- Restore moon
	if cel_vault.moon then
		local pl = skill.player
		pl:set_moon(data._moon)
		data._moon = {}
	end

	-- Restore sun
	if cel_vault.sun then
		local pl = skill.player
		pl:set_sun(data._sun)
		data._sun = {}
	end

	-- Restore stars
	if cel_vault.stars then
		local pl = skill.player
		pl:set_stars(data._stars)
		data._stars = {}
	end
end