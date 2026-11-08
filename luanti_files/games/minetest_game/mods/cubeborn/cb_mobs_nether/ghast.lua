-- Ghast (spec cycle 4, 8d): drifts high in the Nether and shoots fireballs at
-- players within 64 nodes. A fireball hurts and sets things alight, but it
-- breaks no blocks: fire goes only into unprotected air (users' choice). A
-- punch sends the fireball back; a returned fireball kills a ghast at once.
local S = cb_mobs_nether.S
local N = cb_mobs_nether
N.GHAST, N.GHAST_FIREBALL, N.GHAST_TEAR = "cb_mobs_nether:ghast", "cb_mobs_nether:ghast_fireball",
	"cb_mobs_nether:ghast_tear"
local DAMAGE = 6
local FIRE = core.registered_nodes["fire:basic_flame"] and "fire:basic_flame"

core.register_craftitem(N.GHAST_TEAR, { description = S("Ghast Tear"), inventory_image = "cb_mobs_nether_ghast_tear.png", })

local function ignite(pos)
	local p = vector.round(pos)
	if FIRE and core.get_node(p).name == "air" and not core.is_protected(p, "") then
		core.set_node(p, { name = FIRE, })
		return true
	end
	return false
end
N.ignite = ignite

-- A fireball hitting obj: a returned one kills a ghast, else it hurts (but not
-- a ghast, see friendly_fire below).
function N.fireball_hit(ball, obj)
	local e = obj:get_luaentity()
	if ball._returned and e and e.name == N.GHAST then
		e.health = 0
		e:check_for_death({ type = "punch", puncher = ball._returned_by or ball.object, })
		return "killed"
	end
	-- the position first: the punch removes a mob it kills
	local pos = obj:get_pos()
	obj:punch(ball.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = DAMAGE, }, }, nil)
	if pos then
		ignite(pos)
	end
	return "hurt"
end

-- A punch sends it back the way it came, now on the puncher's side.
function N.fireball_return(ball, hitter)
	local v = ball.object:get_velocity() or vector.zero()
	ball.object:set_velocity(vector.multiply(v, -1))
	ball._returned, ball._returned_by = true, hitter
	ball.owner_id = hitter and tostring(hitter) or ball.owner_id
	return true
end

mobs:register_arrow(N.GHAST_FIREBALL, {
	visual = "sprite", visual_size = { x = 1, y = 1, }, textures = { "cb_mobs_nether_ghast_fireball.png", },
	collisionbox = { -0.3, -0.3, -0.3, 0.3, 0.3, 0.3, }, velocity = 10, glow = 14,
	hit_player = function(self, player)
		N.fireball_hit(self, player)
	end,
	hit_mob = function(self, mob)
		N.fireball_hit(self, mob)
	end,
	hit_node = function(_, pos)
		ignite(vector.offset(pos, 0, 1, 0))
	end,
	on_punch = function(self, hitter)
		N.fireball_return(self, hitter)
	end,
})

mobs:register_mob(N.GHAST, {
	type = "monster", passive = false, attack_type = "shoot", arrow = N.GHAST_FIREBALL, shoot_interval = 3,
	shoot_offset = 1, hp_min = 10, hp_max = 10, armor = 100,
	-- mobs_redo's default lets ghasts kill each other with their shots; a
	-- returned fireball kills through fireball_hit, not through the damage
	friendly_fire = false,
	collisionbox = { -2, 0, -2, 2, 4, 2, },
	visual = "mesh", mesh = "cb_mobs_nether_ghast.b3d", visual_size = { x = 12, y = 12, },
	textures = { { "cb_mobs_nether_ghast.png", }, },
	fly = true, fly_in = { "air", }, walk_velocity = 1, run_velocity = 1.5, jump = false, view_range = 64,
	water_damage = 0, lava_damage = 0, fire_damage = 0, light_damage = 0, fall_damage = false,
	makes_footstep_sound = false, glow = 4,
	drops = { { name = N.GHAST_TEAR, chance = 1, min = 0, max = 1, },
		{ name = "tnt:gunpowder", chance = 1, min = 0, max = 2, }, },
	sounds = { random = "cb_mobs_nether_ghast_moan", shoot_attack = "cb_mobs_nether_ghast_shot",
		damage = "cb_mobs_nether_ghast_hurt", death = "cb_mobs_nether_ghast_dying", distance = 64, },
	animation = { speed_normal = 25, stand_start = 0, stand_end = 40, walk_start = 0, walk_end = 40,
		fly_start = 0, fly_end = 40, shoot_start = 0, shoot_end = 40, },
})
mobs:register_egg(N.GHAST, S("Ghast"), "cb_mobs_nether_ghast_tear.png", 1)
