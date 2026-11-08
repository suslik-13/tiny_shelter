-- Ocelot (spec cycle 4, 8b): a shy jungle cat that runs from players and
-- hunts chickens. Raw fish wins its trust with a 1 in 3 chance: then it no
-- longer runs and is kept (tamed, no owner); more fish breeds it.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.OCELOT = "cb_mobs_animals:ocelot"
-- any raw fish (ethereal has many kinds, all in this group)
local FISH = { "group:food_fish_raw", }

local function trusting(self)
	-- false, not nil: nil would fall back to the shy definition
	self.runaway, self.runaway_from = false, false
	self.tamed, self.static_save = true, true
end

-- Fish from a player's hand; `roll` (0..1) is the trust chance roll.
function A.ocelot_feed(self, clicker, roll)
	local stack = clicker:get_wielded_item()
	if core.get_item_group(stack:get_name(), "food_fish_raw") == 0 then
		return false
	end
	if self._trust then
		return mobs:feed_tame(self, clicker, 1, true, false)
	end
	if not core.is_creative_enabled(clicker:get_player_name()) then
		stack:take_item()
		clicker:set_wielded_item(stack)
	end
	local pos = self.object:get_pos()
	if (roll or math.random()) < 1 / 3 then
		self._trust = true
		trusting(self)
		mobs:effect(vector.offset(pos, 0, 0.7, 0), 6, "mobs_heart_particle.png", 1, 2, 1, 0)
	else
		mobs:effect(vector.offset(pos, 0, 0.7, 0), 6, "mobs_tnt_smoke.png", 1, 2, 1, 0)
	end
	return true
end

mobs:register_mob(A.OCELOT, {
	type = "animal", passive = false, attack_players = false, attack_animals = true,
	specific_attack = { "mobs_animal:chicken", }, runaway = true, runaway_from = { "player", },
	attack_type = "dogfight", damage = 3, reach = 1.5, hp_min = 10, hp_max = 10, armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 0.7, 0.3, },
	visual = "mesh", mesh = "cb_mobs_animals_cat.b3d", visual_size = { x = 1.75, y = 1.75, },
	textures = { { "cb_mobs_animals_ocelot.png", }, },
	makes_footstep_sound = true, walk_velocity = 1.5, run_velocity = 3.5, jump = true, view_range = 10,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, floats = 1,
	sounds = { random = "cb_mobs_animals_cat_idle", war_cry = "cb_mobs_animals_cat_hiss",
		damage = "cb_mobs_animals_ocelot_hurt", death = "cb_mobs_animals_ocelot_hurt", distance = 12, },
	animation = { speed_normal = 110, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40,
		run_start = 0, run_end = 40, punch_start = 0, punch_end = 40, sit_start = 50, sit_end = 50, },
	follow = FISH,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() then
			A.ocelot_feed(self, clicker)
		end
	end,
	on_breed = function(self, other)
		return A.on_breed(self, other, function(young)
			young._trust = true
			trusting(young)
		end)
	end,
	after_activate = function(self)
		if self._trust then
			trusting(self)
		end
	end,
})
mobs:register_egg(A.OCELOT, S("Ocelot"), "cb_mobs_animals_ocelot.png", 1)
