-- Blaze: a flying Nether mob that shoots fireballs. It comes only from blaze
-- spawners (no natural spawning); fire and lava do not hurt it, water and
-- snowballs do.
local S = cb_mobs_dim.S

local FIRE = core.registered_nodes["fire:basic_flame"] and "fire:basic_flame"
local FIREBALL_DAMAGE = 5
local SNOWBALL_DAMAGE = 3

-- Sets fire in the node a fireball stopped in, if it is unprotected air.
function cb_mobs_dim.fireball_ignite(pos)
	local p = vector.new(math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))
	if not FIRE or core.get_node(p).name ~= "air" or core.is_protected(p, "") then
		return false
	end
	core.set_node(p, { name = FIRE, })
	return true
end

local function burn(self, obj)
	obj:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = FIREBALL_DAMAGE, }, }, nil)
end

mobs:register_arrow("cb_mobs_dim:blaze_fireball", {
	visual = "sprite",
	visual_size = { x = 0.5, y = 0.5, },
	textures = { "cb_mobs_dim_fireball.png", },
	collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1, },
	velocity = 12,
	glow = 14,
	hit_player = burn,
	hit_mob = burn,
	hit_node = function(_, pos)
		cb_mobs_dim.fireball_ignite(pos)
	end,
})

local ANIM = { speed_normal = 25, }
for _, a in ipairs({ "stand", "walk", "run", "shoot", }) do
	ANIM[a .. "_start"], ANIM[a .. "_end"] = 0, 100
end

mobs:register_mob("cb_mobs_dim:blaze", cb_core.fixed_head({
	type = "monster",
	hp_min = 20,
	hp_max = 20,
	armor = 100,
	collisionbox = { -0.3, -0.01, -0.3, 0.3, 1.79, 0.3, },
	visual = "mesh",
	mesh = "cb_mobs_dim_blaze.b3d",
	visual_size = { x = 3, y = 3, },
	textures = { { "cb_mobs_dim_blaze.png", }, },
	glow = 14,
	makes_footstep_sound = false,
	fly = true,
	fly_in = { "air", },
	walk_velocity = 1.5,
	run_velocity = 2.5,
	view_range = 32,
	damage = 6,
	attack_type = "shoot",
	arrow = "cb_mobs_dim:blaze_fireball",
	shoot_interval = 1,
	water_damage = 2,
	lava_damage = 0,
	fire_damage = 0,
	fall_damage = false,
	friendly_fire = false,
	blood_amount = 0,
	sounds = {
		random = "cb_mobs_dim_blaze_breath",
		damage = "cb_mobs_dim_blaze_hurt",
		death = "cb_mobs_dim_blaze_died",
		shoot_attack = "mobs_fireball",
		distance = 16,
	},
	animation = ANIM,
	drops = {
		{ name = "cb_items:blaze_rod", chance = 1, min = 0, max = 1, },
	},
	-- Snowballs are zero-damage projectiles: their hit costs the blaze 3 HP.
	do_punch = function(self, hitter)
		local e = hitter and not hitter:is_player() and hitter:get_luaentity()
		if e and not e._cmi_is_mob and type(e.name) == "string" and e.name:find("snow", 1, true) then
			self.health = self.health - SNOWBALL_DAMAGE
			self:check_for_death({ type = "punch", puncher = hitter, })
			return false
		end
	end,
}, 4))

mobs:register_egg("cb_mobs_dim:blaze", S("Blaze"), "default_lava.png", 1)
