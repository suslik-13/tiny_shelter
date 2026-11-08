-- The mace's enchantments (spec 5, MC 1.21): Density adds damage for the
-- height fallen, Breach goes through armor, Wind Burst throws the wielder
-- up after a falling hit. cb_mobs_trial calls MACE.on_hit for each blow.
local E = cb_enchanting
E.DENSITY_STEP, E.BREACH_STEP = 0.5, 0.15

-- Damage of a blow after falling h nodes, with the stack's Density and Breach.
function E.mace_damage(stack, target, h, dmg, min_fall)
	local ench = E.get(stack)
	if (ench.density or 0) > 0 and h > (min_fall or 0) then
		dmg = dmg + E.DENSITY_STEP * ench.density * h
	end
	local a = (ench.breach or 0) > 0 and target.get_armor_groups and (target:get_armor_groups().fleshy or 100) or 100
	if a > 0 and a < 100 then
		dmg = dmg * math.min(100, a + (100 - a) * E.BREACH_STEP * ench.breach) / a
	end
	return dmg
end

-- Wind Burst: up 7 nodes, 4 more a level.
function E.wind_burst(user, level)
	local h = 7 + 4 * (level - 1)
	user:add_velocity(vector.new(0, math.sqrt(2 * 9.81 * h), 0))
end

local T = rawget(_G, "cb_mobs_trial")
local MACE = T and T.mace
if MACE then
	MACE.on_hit = function(user, obj, h, dmg)
		if not user.get_wielded_item then
			return dmg
		end
		local stack = user:get_wielded_item()
		dmg = E.mace_damage(stack, obj, h, dmg, MACE.MIN_FALL)
		local wind = E.level(stack, "wind_burst")
		if wind > 0 and h > MACE.MIN_FALL then
			E.wind_burst(user, wind)
		end
		return dmg
	end
end
