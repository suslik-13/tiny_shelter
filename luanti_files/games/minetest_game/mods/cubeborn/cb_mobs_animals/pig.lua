-- Pig (spec cycle 4, 8b): takes a saddle; a rider steers it only while
-- holding a carrot on a stick, whose use gives a short burst of speed.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.PIG, A.STICK = "cb_mobs_animals:pig", "cb_mobs_animals:carrot_on_a_stick"
local TEX, SADDLE = "cb_mobs_animals_pig.png", "cb_mobs_animals_pig_saddle.png"
local BOOST_TIME, BOOST_WEAR = 3, math.floor(65535 / 25)

local function retexture(self)
	self.base_texture = { TEX, self._saddle and SADDLE or "blank.png", }
	self.object:set_properties({ textures = self.base_texture, })
end

core.register_tool(A.STICK, {
	description = S("Carrot on a Stick"),
	inventory_image = "cb_mobs_animals_carrot_on_a_stick.png",
	groups = { not_repaired_by_anvil = 1, },
	on_use = function(stack, user)
		local pig = user and user:get_attach()
		local e = pig and pig:get_luaentity()
		if not (e and e.name == A.PIG and e.driver == user) then
			return
		end
		e._boost = BOOST_TIME
		if not core.is_creative_enabled(user:get_player_name()) then
			stack:add_wear(BOOST_WEAR)
		end
		return stack
	end,
})
if core.registered_items["ethereal:fishing_rod"] and core.registered_items["farming:carrot"] then
	core.register_craft({ type = "shapeless", output = A.STICK,
		recipe = { "ethereal:fishing_rod", "farming:carrot", }, })
end

local food = {}
for _, n in ipairs({ "farming:carrot", "farming:potato", "farming:beetroot", }) do
	if core.registered_items[n] then
		food[#food + 1] = n
	end
end

mobs:register_mob(A.PIG, {
	type = "animal", passive = true, hp_min = 10, hp_max = 10, armor = 100,
	collisionbox = { -0.45, 0, -0.45, 0.45, 0.865, 0.45, },
	visual = "mesh", mesh = "cb_mobs_animals_pig.b3d", visual_size = { x = 1, y = 1, },
	textures = { { TEX, "blank.png", }, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 2, jump = true, view_range = 8,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = true,
	drops = { { name = "mobs:pork_raw", chance = 1, min = 1, max = 3, }, },
	sounds = { random = "cb_mobs_animals_pig", damage = "cb_mobs_animals_pig",
		death = "cb_mobs_animals_pig_death", distance = 12, },
	animation = { speed_normal = 55, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40, run_start = 0,
		run_end = 40, },
	follow = food,
	do_custom = function(self, dtime)
		if self._boost then
			self._boost = self._boost - dtime
			self.max_speed_forward = self._boost > 0 and 6 or 3
			if self._boost <= 0 then
				self._boost = nil
			end
		end
		return not A.ride_step(self, dtime)
	end,
	on_rightclick = function(self, clicker)
		if not (clicker and clicker:is_player()) then
			return
		end
		if A.feed(self, clicker) or A.saddle_click(self, clicker) then
			return
		end
		A.mount_click(self, clicker)
	end,
	on_breed = function(self, other)
		return A.on_breed(self, other)
	end,
	on_die = function(self)
		A.drop_saddle(self)
	end,
	after_activate = function(self)
		A.setup(self)
		retexture(self)
	end,
})
A.CFG[A.PIG] = { _needs_stick = true, _rider_at = { x = 0, y = 5, z = 0, }, _rider_eye = { x = 0, y = 3, z = 0, },
	_on_saddle = retexture, _ride_speed = 3, }
mobs:register_egg(A.PIG, S("Pig"), "cb_mobs_animals_pig.png", 1)
