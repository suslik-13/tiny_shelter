-- Strider (spec cycle 4, 8d): walks over lava, which does not hurt it; on
-- land it shivers (cold look, slower). A saddle (mobs:saddle) lets a rider
-- steer it with a warped fungus on a stick (a fishing rod and a warped
-- fungus), whose use gives a burst of speed. Warped fungi breed striders.
local S = cb_mobs_nether.S
local N = cb_mobs_nether
local A = rawget(_G, "cb_mobs_animals")
N.STRIDER, N.FUNGUS_STICK = "cb_mobs_nether:strider", "cb_mobs_nether:warped_fungus_on_a_stick"
local WARM, COLD = "cb_mobs_nether_strider.png", "cb_mobs_nether_strider_cold.png"
local SADDLE = "cb_mobs_animals_pig_saddle.png"

local function in_lava(pos)
	return core.get_item_group(core.get_node(vector.round(pos)).name, "lava") > 0
end

local function retexture(self)
	self.base_texture = { self._cold and COLD or WARM, self._saddle and SADDLE or "blank.png", }
	self.object:set_properties({ textures = self.base_texture, })
end

-- From do_custom: floats on lava, shivers off it. True when on lava.
function N.strider_float(self)
	local pos = self.object:get_pos()
	local lava = in_lava(vector.offset(pos, 0, 0.2, 0))
	if lava then
		local v = self.object:get_velocity() or vector.zero()
		self.object:set_velocity({ x = v.x, y = math.max(v.y, 2), z = v.z, })
	end
	local cold = not lava and not in_lava(vector.offset(pos, 0, -0.5, 0))
	if cold ~= (self._cold or false) then
		self._cold = cold
		self.walk_velocity = cold and 0.5 or 1
		retexture(self)
	end
	return not cold
end

core.register_tool(N.FUNGUS_STICK, {
	description = S("Warped Fungus on a Stick"),
	inventory_image = "cb_mobs_nether_warped_fungus_on_a_stick.png",
	on_use = function(stack, user)
		local mount = user and user:get_attach()
		local e = mount and mount:get_luaentity()
		if not (e and e.name == N.STRIDER and e.driver == user) then
			return
		end
		e._boost = 3
		if not core.is_creative_enabled(user:get_player_name()) then
			stack:add_wear(65535 / 100)
		end
		return stack
	end,
})
if core.registered_items["ethereal:fishing_rod"] then
	core.register_craft({ type = "shapeless", output = N.FUNGUS_STICK,
		recipe = { "ethereal:fishing_rod", "cb_blocks:warped_fungus", }, })
end

mobs:register_mob(N.STRIDER, {
	type = "animal", passive = true, hp_min = 20, hp_max = 20, armor = 100,
	collisionbox = { -0.45, 0, -0.45, 0.45, 1.69, 0.45, },
	visual = "mesh", mesh = "cb_mobs_nether_strider.b3d", visual_size = { x = 3, y = 3, },
	textures = { { WARM, "blank.png", }, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 1.5, jump = true, view_range = 8,
	water_damage = 4, lava_damage = 0, fire_damage = 0, light_damage = 0, fall_damage = true,
	sounds = { random = "cb_mobs_nether_strider", damage = "cb_mobs_nether_strider", death = "cb_mobs_nether_strider",
		distance = 12, },
	animation = { speed_normal = 30, stand_start = 5, stand_end = 5, walk_start = 1, walk_end = 20,
		run_start = 1, run_end = 20, },
	follow = { "cb_blocks:warped_fungus", },
	do_custom = function(self, dtime)
		N.strider_float(self)
		if self._boost then
			self._boost = self._boost - dtime
			self.max_speed_forward = self._boost > 0 and 6 or 3
			if self._boost <= 0 then
				self._boost = nil
			end
		end
		return not (A and A.ride_step(self, dtime))
	end,
	on_rightclick = function(self, clicker)
		if not (A and clicker and clicker:is_player()) then
			return
		end
		if A.feed(self, clicker) or A.saddle_click(self, clicker) then
			return
		end
		A.mount_click(self, clicker)
	end,
	on_breed = function(self, other)
		return A and A.on_breed(self, other) or false
	end,
	on_die = function(self)
		if A then
			A.drop_saddle(self)
		end
	end,
	after_activate = function(self)
		if A then
			A.setup(self)
		end
		retexture(self)
	end,
})
if A then
	A.CFG[N.STRIDER] = { _needs_stick = true, _stick = N.FUNGUS_STICK, _rider_at = { x = 0, y = 5.1, z = -1.75, },
		_rider_eye = { x = 0, y = 8, z = 0, }, _on_saddle = retexture, _ride_speed = 3, _feed_count = 1, }
end
mobs:register_egg(N.STRIDER, S("Strider"), WARM, 1)
