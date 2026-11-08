-- Guardian and elder guardian (spec cycle 4, 8c): monsters of the ocean
-- monument. They aim a beam at their target for 2 s (a line of particles)
-- and then hurt it (6, elder 8); hitting one up close pricks back (2). The
-- elder guardian gives players within 50 nodes Mining Fatigue III for five
-- minutes, once a minute. Out of water they flop and choke.
local S = cb_mobs_water.S
local W = cb_mobs_water
W.GUARDIAN, W.ELDER = "cb_mobs_water:guardian", "cb_mobs_water:elder_guardian"
local AIM, BEAM_RANGE, THORNS, FATIGUE_RANGE = 2, 15, 2, 50

local function beam_particles(from, to, glow)
	local d = vector.subtract(to, from)
	local n = math.max(1, math.floor(vector.length(d) * 2))
	for i = 1, n do
		core.add_particle({ pos = vector.add(from, vector.multiply(d, i / n)), expirationtime = 0.3, size = 1.5,
			texture = "[fill:2x2:#a0f0e0", glow = glow, })
	end
end

-- From do_custom: aims at the target and, after AIM seconds, hits it.
-- Returns true when the beam struck.
function W.guardian_beam(self, dtime)
	local target = self.attack
	local pos, tpos = self.object:get_pos(), target and target:get_pos()
	if not (pos and tpos) or vector.distance(pos, tpos) > BEAM_RANGE then
		self._aim = nil
		return false
	end
	self._aim = (self._aim or 0) + dtime
	local eye = vector.offset(pos, 0, 0.4, 0)
	beam_particles(eye, vector.offset(tpos, 0, 1, 0), math.floor(self._aim / AIM * 14))
	if self._aim < AIM then
		return false
	end
	self._aim = 0
	target:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = self._beam or 6, }, },
		vector.direction(pos, tpos))
	return true
end

-- Thorns: who hits it from close by is pricked back.
function W.guardian_thorns(self, hitter)
	local pos, hp = self.object:get_pos(), hitter and hitter:get_pos()
	if not (pos and hp) or vector.distance(pos, hp) > 3 or hitter == self.object then
		return false
	end
	hitter:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = THORNS, }, },
		vector.direction(pos, hp))
	return true
end

-- The elder's curse: Mining Fatigue III for the players near (or `players`).
function W.elder_curse(self, players)
	local E = cb_core.effects
	local pos, n = self.object:get_pos(), 0
	for _, p in ipairs(players or core.get_connected_players()) do
		local at = p:get_pos()
		if at and vector.distance(pos, at) <= FATIGUE_RANGE and not core.is_creative_enabled(p:get_player_name()) then
			E.apply(p, "mining_fatigue", 3, 300)
			n = n + 1
		end
	end
	return n
end

local function drops(elder)
	local out = { { name = "cb_blocks:prismarine_shard", chance = 1, min = 0, max = 2, },
		{ name = "cb_blocks:prismarine_crystals", chance = 3, min = 1, max = 1, }, }
	if core.registered_items["ethereal:fish_cod"] then
		out[#out + 1] = { name = "ethereal:fish_cod", chance = 2, min = 1, max = 1, }
	end
	if elder then
		out[#out + 1] = { name = "cb_blocks:wet_sponge", chance = 1, min = 1, max = 1, }
		if core.registered_items["cb_items:trim_tide"] then
			out[#out + 1] = { name = "cb_items:trim_tide", chance = 5, min = 1, max = 1, }
		end
	end
	return out
end

local function register(name, desc, tex, hp, size, beam, elder)
	local box = { -0.425 * size / 3, 0, -0.425 * size / 3, 0.425 * size / 3, 0.85 * size / 3, 0.425 * size / 3, }
	mobs:register_mob(name, {
		type = "monster", passive = false, attack_type = "dogfight", attack_animals = true,
		specific_attack = { "player", "cb_mobs_water:squid", "cb_mobs_water:glow_squid", "cb_mobs_animals:axolotl", },
		damage = 0, reach = 0.1, hp_min = hp, hp_max = hp, armor = 100,
		collisionbox = box,
		visual = "mesh", mesh = "cb_mobs_water_guardian.b3d", visual_size = { x = size, y = size, },
		textures = { { tex, }, },
		fly = true, fly_in = W.WATER, walk_velocity = 1, run_velocity = elder and 1 or 2, jump = false, view_range = 16,
		water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
		drops = drops(elder),
		sounds = { random = "cb_mobs_water_guardian_random", war_cry = "cb_mobs_water_guardian_random",
			damage = "cb_mobs_water_guardian_hurt", death = "cb_mobs_water_guardian_death", distance = 16, },
		animation = { speed_normal = 20, stand_start = 0, stand_end = 20, walk_start = 0, walk_end = 20,
			run_start = 0, run_end = 20, fly_start = 0, fly_end = 20, },
		do_custom = function(self, dtime)
			if self.state == "attack" then
				W.guardian_beam(self, dtime)
			else
				self._aim = nil
			end
			if elder then
				self._curse_t = (self._curse_t or 60) + dtime
				if self._curse_t >= 60 then
					self._curse_t = 0
					W.elder_curse(self)
				end
			end
		end,
		do_punch = function(self, hitter)
			W.guardian_thorns(self, hitter)
		end,
		on_flop = W.choke,
		after_activate = function(self)
			self._beam = beam
		end,
	})
	mobs:register_egg(name, desc, tex, 1)
end
register(W.GUARDIAN, S("Guardian"), "cb_mobs_water_guardian.png", 30, 3, 6, false)
register(W.ELDER, S("Elder Guardian"), "cb_mobs_water_guardian_elder.png", 80, 7, 8, true)
