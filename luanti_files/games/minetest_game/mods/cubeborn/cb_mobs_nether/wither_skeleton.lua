-- Wither skeleton (spec cycle 4, 8d): lives in Nether fortresses (one of
-- their inhabitants). Its stone sword hurts (8) and withers the target for
-- 10 s (1 damage every 2 s, which can kill). Drops coal and bones, and 1 time
-- in 40 its skull (skull.lua: a block that summons the wither).
local S = cb_mobs_nether.S
local N = cb_mobs_nether
N.WITHER_SKELETON, N.WITHER_SKULL = "cb_mobs_nether:wither_skeleton", "cb_mobs_nether:wither_skeleton_skull"
local WITHER_TIME = 10

-- A blow that lands withers players.
function N.wither_hit(target)
	local E = cb_core.effects
	if E and E.defs.wither and target and target:is_player() then
		E.apply(target, "wither", 1, WITHER_TIME)
		return true
	end
	return false
end

local drops = { { name = "default:coal_lump", chance = 3, min = 1, max = 1, },
	{ name = N.WITHER_SKULL, chance = 40, min = 1, max = 1, }, }
if core.registered_items["bonemeal:bone"] then
	drops[#drops + 1] = { name = "bonemeal:bone", chance = 1, min = 0, max = 2, }
end

mobs:register_mob(N.WITHER_SKELETON, {
	type = "monster", passive = false, attack_type = "dogfight", damage = 8, reach = 2.5,
	hp_min = 20, hp_max = 20, armor = 100,
	collisionbox = { -0.35, 0, -0.35, 0.35, 2.39, 0.35, },
	visual = "mesh", mesh = "cb_mobs_nether_wither_skeleton.b3d", visual_size = { x = 1.2, y = 1.2, },
	textures = { { "default_tool_stonesword.png", "cb_mobs_nether_wither_skeleton.png", }, },
	makes_footstep_sound = true, walk_velocity = 1.2, run_velocity = 3, jump = true, view_range = 16,
	water_damage = 0, lava_damage = 0, fire_damage = 0, light_damage = 0, fall_damage = true,
	drops = drops,
	sounds = { random = "cb_mobs_nether_skeleton_random", damage = "cb_mobs_nether_skeleton_hurt",
		death = "cb_mobs_nether_skeleton_death", distance = 16, },
	animation = { speed_normal = 30, stand_start = 0, stand_end = 40, walk_start = 40, walk_end = 60,
		run_start = 40, run_end = 60, punch_start = 61, punch_end = 81, },
	-- mobs_redo passes a position here: the target is self.attack
	custom_attack = function(self)
		N.wither_hit(self.attack)
		return true
	end,
})
mobs:register_egg(N.WITHER_SKELETON, S("Wither Skeleton"), "cb_mobs_nether_wither_skeleton_skull.png", 1)
