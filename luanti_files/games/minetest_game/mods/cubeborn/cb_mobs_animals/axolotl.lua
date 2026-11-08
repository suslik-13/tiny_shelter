-- Axolotl (spec cycle 4, 8b): lives in dark underground water, in six
-- colours plus a rare purple one (1 in 1200). It fights drowned in the
-- water; when what it fights dies, players within 20 nodes get a few
-- seconds of regeneration. Badly hurt (under half health) it plays dead for
-- 10 s, which makes mobs attacking it lose interest, and heals meanwhile.
-- Out of water it dries out after 5 minutes. A water bucket takes it; caught
-- tropical fish (mobs_fish) breed it.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.AXOLOTL, A.AXOLOTL_BUCKET = "cb_mobs_animals:axolotl", "cb_mobs_animals:axolotl_bucket"
local COLOURS = { "pink", "brown", "yellow", "green", "white", "black", }
local RARE, DEAD_TIME, DRY_TIME, REWARD_RANGE = "purple", 10, 300, 20
local WATER = { "default:water_source", "default:water_flowing", "default:river_water_source",
	"default:river_water_flowing", }
local FOOD = { "mobs_fish:tropical", "mobs_fish:clownfish", }

function A.axolotl_colour(roll)
	if roll < 1 / 1200 then
		return RARE
	end
	return COLOURS[math.min(#COLOURS, 1 + math.floor((roll - 1 / 1200) / (1 - 1 / 1200) * #COLOURS))]
end

local function retexture(self)
	self.base_texture = { "cb_mobs_animals_axolotl_" .. (self._colour or "pink") .. ".png", }
	self.object:set_properties({ textures = self.base_texture, })
end

function A.play_dead(self)
	self._dead_t = DEAD_TIME
	self.attack, self.state = nil, "stand"
	self:set_velocity(0)
	for _, obj in ipairs(core.get_objects_inside_radius(self.object:get_pos(), 16)) do
		local e = obj:get_luaentity()
		if e and e._cmi_is_mob and e.attack == self.object then
			e.attack, e.state = nil, "stand"
		end
	end
end

-- What it fought died: regeneration for the players nearby (or `players`).
function A.axolotl_reward(self, players)
	local E = cb_core.effects
	if not (E and E.defs.regeneration) then
		return 0
	end
	local pos, n = self.object:get_pos(), 0
	for _, p in ipairs(players or core.get_connected_players()) do
		if players or vector.distance(p:get_pos(), pos) <= REWARD_RANGE then
			local _, left = E.get(p, "regeneration")
			E.apply(p, "regeneration", 1, math.min(120, (left or 0) + 5))
			n = n + 1
		end
	end
	return n
end

function A.axolotl_tick(self, dtime)
	if self._dead_t then
		self._dead_t = self._dead_t - dtime
		self._heal_t = (self._heal_t or 0) + dtime
		if self._heal_t >= 1 then
			self._heal_t = 0
			self.health = math.min(self.hp_max or 14, self.health + 1)
		end
		if self._dead_t <= 0 then
			self._dead_t = nil
		end
		local v = self.object:get_velocity() or vector.zero()
		self.object:set_velocity({ x = 0, y = v.y, z = 0, })
		return false
	end
	if self.state ~= "flop" then
		self._dry = nil
	end
	local foe = self._foe
	if foe and not (foe:get_pos() and (foe:get_luaentity() or {}).health ~= nil
		and foe:get_luaentity().health > 0) then
		self._foe = nil
		A.axolotl_reward(self)
	end
	if self.state == "attack" and self.attack and not self.attack:is_player() then
		self._foe = self.attack
	end
	return true
end

mobs:register_mob(A.AXOLOTL, {
	type = "animal", passive = false, attack_players = false, attack_monsters = true,
	specific_attack = { "cb_mobs_overworld:drowned", }, attack_type = "dogfight", damage = 2, reach = 1.5,
	hp_min = 14, hp_max = 14, armor = 100, rotate = 180,
	collisionbox = { -0.375, 0, -0.375, 0.375, 0.42, 0.375, },
	visual = "mesh", mesh = "cb_mobs_animals_axolotl.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_animals_axolotl_pink.png", }, },
	fly = true, fly_in = WATER, walk_velocity = 1, run_velocity = 2, jump = false, view_range = 8,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
	sounds = { random = "cb_mobs_animals_axolotl", damage = "cb_mobs_animals_axolotl_hurt",
		death = "cb_mobs_animals_axolotl_hurt", distance = 12, },
	animation = { speed_normal = 15, stand_start = 61, stand_end = 81, walk_start = 61, walk_end = 81,
		run_start = 61, run_end = 81, run_speed = 20, fly_start = 61, fly_end = 81, },
	follow = FOOD,
	do_custom = function(self, dtime)
		return A.axolotl_tick(self, dtime)
	end,
	do_punch = function(self, _, _, _, _, damage)
		if not self._dead_t and damage < self.health and self.health - damage < (self.hp_max or 14) / 2
			and core.get_item_group(self.standing_in or "", "water") > 0 then
			-- the blow lands, then it plays dead
			core.after(0, function()
				if self.object:get_pos() then
					A.play_dead(self)
				end
			end)
		end
	end,
	-- out of water it dries out
	on_flop = function(self)
		self._dry = (self._dry or 0) + 1
		if self._dry > DRY_TIME then
			self.health = self.health - 1
			self:check_for_death({ type = "environment", })
		end
	end,
	on_rightclick = function(self, clicker)
		if not (clicker and clicker:is_player()) then
			return
		end
		if not A.bucket_mob(self, clicker, A.AXOLOTL_BUCKET, { "_colour", }) then
			mobs:feed_tame(self, clicker, 1, true, false)
		end
	end,
	on_breed = function(self, other)
		return A.on_breed(self, other, function(young)
			young._colour = math.random(1200) == 1 and RARE or (math.random(2) == 1 and self or other)._colour
			retexture(young)
		end)
	end,
	after_activate = function(self)
		self._colour = self._colour or A.axolotl_colour(math.random())
		retexture(self)
	end,
})
mobs:register_egg(A.AXOLOTL, S("Axolotl"), "cb_mobs_animals_axolotl_pink.png", 1)

A.register_mob_bucket(A.AXOLOTL_BUCKET, { description = S("Bucket of Axolotl"),
	image = "cb_mobs_animals_axolotl_bucket.png", mob = A.AXOLOTL, after = retexture, })
