-- Bogged (plan 8f-1), after secret_terra's st_mobs bogged (its textures; the
-- skeleton model of cb_mobs_overworld): the swamp skeleton with 16 HP. Its
-- arrows (mob projectiles only) hurt 2 and poison for 4 s; it burns in
-- daylight; shears take its mushrooms once (two, red or brown). Drops bones.
-- Spawns in swamps and from trial spawners.
local S = cb_mobs_trial.S
local T = cb_mobs_trial
T.BOGGED, T.POISON_ARROW = "cb_mobs_trial:bogged", "cb_mobs_trial:poison_arrow"
local SHEARS = "mobs:shears"
local OVERLAY, SHEARED = "cb_mobs_trial_bogged_overlay.png", "cb_mobs_trial_bogged_overlay_sheared.png"

-- An arrow (from) hits obj: 2 damage, players are poisoned for 4 s.
function T.bogged_hit(obj, from)
	obj:punch(from or obj, 1, { full_punch_interval = 1, damage_groups = { fleshy = 2, }, }, nil)
	if obj:is_player() then
		cb_core.effects.apply(obj, "poison", 1, 4)
	end
end

mobs:register_arrow(T.POISON_ARROW, {
	visual = "sprite", visual_size = { x = 0.5, y = 0.5, }, textures = { "cb_mobs_overworld_arrow.png^[colorize:#4e9331:90", },
	velocity = 18,
	hit_player = function(self, player)
		T.bogged_hit(player, self.object)
	end,
	hit_mob = function(self, obj)
		T.bogged_hit(obj, self.object)
	end,
	hit_node = function() end,
})

local function textures(sheared)
	return { "blank.png", sheared and SHEARED or OVERLAY, "cb_mobs_trial_bogged.png", }
end

-- A player's click with shears: two mushrooms, once.
function T.shear_bogged(self, clicker)
	local held = clicker and clicker:get_wielded_item()
	local pos = self.object:get_pos()
	if not (held and held:get_name() == SHEARS and pos) or self._sheared then
		return false
	end
	self._sheared = true
	self.object:set_properties({ textures = textures(true), })
	self.base_texture = textures(true)
	for _ = 1, 2 do
		core.add_item(vector.offset(pos, 0, 1.4, 0), math.random(2) == 1 and "flowers:mushroom_brown" or "flowers:mushroom_red")
	end
	core.sound_play("cb_mobs_animals_shear", { pos = pos, }, true)
	if not core.is_creative_enabled(clicker:get_player_name()) then
		held:add_wear(650)
		clicker:set_wielded_item(held)
	end
	return true
end

mobs:register_mob(T.BOGGED, {
	type = "monster", passive = false, attack_type = "shoot", arrow = T.POISON_ARROW,
	shoot_interval = 3.5, shoot_offset = 1.5, hp_min = 16, hp_max = 16, armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 1.99, 0.3, },
	visual = "mesh", mesh = "cb_mobs_overworld_skeleton.b3d", visual_size = { x = 1, y = 1, },
	textures = { textures(false), },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 1.6, jump = true, view_range = 16,
	light_damage = 2, water_damage = 0, lava_damage = 8,
	drops = core.registered_items["bonemeal:bone"] and { { name = "bonemeal:bone", chance = 1, min = 0, max = 2, }, } or {},
	sounds = { random = "cb_mobs_overworld_skeleton_random", damage = "cb_mobs_overworld_skeleton_hurt",
		death = "cb_mobs_overworld_skeleton_death", distance = 16, },
	animation = { speed_normal = 15, stand_start = 0, stand_end = 40, walk_start = 40, walk_end = 60, run_start = 40,
		run_end = 60, shoot_start = 40, shoot_end = 60, },
	on_rightclick = function(self, clicker)
		T.shear_bogged(self, clicker)
	end,
	after_activate = function(self)
		if self._sheared then
			self.object:set_properties({ textures = textures(true), })
		end
	end,
})
mobs:register_egg(T.BOGGED, S("Bogged"), "cb_mobs_trial_bogged.png", 1)

if rawget(_G, "cb_spawning") then
	cb_spawning.register(T.BOGGED, { dims = { "overworld", }, category = "monster", dark = true,
		on = { "group:soil", "group:stone", "group:sand", "default:gravel", },
		biomes = { "swamp", "marsh", "mangrove", "bayou", }, weight = 40, group = { 1, 2, }, })
end
