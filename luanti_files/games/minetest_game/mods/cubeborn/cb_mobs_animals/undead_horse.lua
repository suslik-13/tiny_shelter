-- Skeleton and zombie horses (spec cycle 4, 8b): a rare night spawn; they
-- do not burn, eat or breed. No taming: whoever saddles one owns it and
-- rides it like a donkey (no chest).
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.SKELETON_HORSE, A.ZOMBIE_HORSE = "cb_mobs_animals:skeleton_horse", "cb_mobs_animals:zombie_horse"

local function undead(tex, drop, sounds)
	return A.horse_def(tex, 1, {
		hp_min = 15, hp_max = 15, follow = {},
		drops = core.registered_items[drop] and { { name = drop, chance = 1, min = 0, max = 2, }, } or {},
		sounds = sounds,
		on_breed = function() return false end,
	})
end

mobs:register_mob(A.SKELETON_HORSE, undead("cb_mobs_animals_horse_skeleton.png", "bonemeal:bone",
	{ random = "cb_mobs_overworld_skeleton_random", damage = "cb_mobs_overworld_skeleton_hurt",
		death = "cb_mobs_overworld_skeleton_death", distance = 16, }))
mobs:register_mob(A.ZOMBIE_HORSE, undead("cb_mobs_animals_horse_zombie.png", "cb_items:rotten_flesh",
	{ random = "cb_mobs_overworld_zombie_growl", damage = "cb_mobs_overworld_zombie_hurt",
		death = "cb_mobs_overworld_zombie_death", distance = 16, }))
local cfg = { _ride_speed = 6, _rider_at = { x = 0, y = 4, z = -1, }, _rider_eye = { x = 0, y = 6, z = 0, }, }
A.CFG[A.SKELETON_HORSE], A.CFG[A.ZOMBIE_HORSE] = cfg, cfg
mobs:register_egg(A.SKELETON_HORSE, S("Skeleton Horse"), "cb_mobs_animals_horse_skeleton.png", 1)
mobs:register_egg(A.ZOMBIE_HORSE, S("Zombie Horse"), "cb_mobs_animals_horse_zombie.png", 1)
