-- Witch (spec cycle 2, 4.5): throws splash potions (entities only):
-- slowness at range 8+, poison at targets with 8+ HP, weakness up close
-- (a quarter of the time), else harming (6). When hurt it drinks healing
-- (+4 HP, every 10 s at most). Lives in witch huts.
local S = cb_mobs_village.S
local V = cb_mobs_village
local NAME = "cb_mobs_village:witch"
local P = "cb_mobs_village:potion_"

function V.witch_potion(hp, dist, has, roll)
	if dist >= 8 and not has.slowness then
		return P .. "slowness"
	elseif hp >= 8 and not has.poison then
		return P .. "poison"
	elseif dist <= 3 and not has.weakness and roll < 0.25 then
		return P .. "weakness"
	end
	return P .. "harming"
end

function V.potion_hit(kind, obj)
	local E = cb_core.effects
	if kind == "harming" then
		if obj:is_player() then
			obj:set_hp(obj:get_hp() - 6, { type = "set_hp", cause = "cb_potion", })
		else
			obj:punch(obj, 1, { full_punch_interval = 1, damage_groups = { fleshy = 6, }, }, nil)
		end
	elseif obj:is_player() then
		if kind == "poison" then
			local s = V.poison_seconds()
			if s > 0 then
				E.apply(obj, "poison", 1, s)
			end
		else
			E.apply(obj, kind, 1, 30)
		end
	end
end

for _, kind in ipairs({ "harming", "poison", "slowness", "weakness", }) do
	mobs:register_arrow(P .. kind, {
		visual = "sprite",
		visual_size = { x = 0.4, y = 0.4, },
		textures = { "cb_mobs_village_potion.png", },
		velocity = 10,
		hit_player = function(_, player)
			V.potion_hit(kind, player)
		end,
		hit_mob = function(_, obj)
			if kind == "harming" then
				V.potion_hit(kind, obj)
			end
		end,
		hit_node = function() end,
	})
end

local function choose(self)
	local t = self.attack
	if not (t and t.get_pos and t:get_pos()) then
		return
	end
	local E = cb_core.effects
	local is_p = t:is_player()
	local has = {
		poison = is_p and E.get(t, "poison") ~= nil,
		slowness = is_p and E.get(t, "slowness") ~= nil,
		weakness = is_p and E.get(t, "weakness") ~= nil,
	}
	local hp = is_p and t:get_hp() or (t:get_luaentity() and t:get_luaentity().health or 20)
	self.arrow = V.witch_potion(hp, vector.distance(self.object:get_pos(), t:get_pos()), has, math.random())
end

mobs:register_mob(NAME, {
	type = "monster",
	passive = false,
	attack_type = "shoot",
	arrow = P .. "harming",
	shoot_interval = 3,
	shoot_offset = 1.5,
	reach = 2,
	damage = 2,
	hp_min = 26,
	hp_max = 26,
	armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 1.95, 0.3, },
	visual = "mesh",
	mesh = "cb_mobs_village_witch.b3d",
	visual_size = { x = 2.75, y = 2.75, },
	textures = { { "cb_mobs_village_witch.png", }, },
	makes_footstep_sound = true,
	walk_velocity = 0.8,
	run_velocity = 1.4,
	view_range = 16,
	stepheight = 1.1,
	water_damage = 0,
	lava_damage = 8,
	drops = V.drops({ { "vessels:glass_bottle", 0, 2, }, { "cb_blocks:glowstone_dust", 0, 2, }, { "farming:sugar", 0, 2, },
		{ "default:stick", 0, 2, }, { "tnt:gunpowder", 0, 2, }, }),
	sounds = { random = "cb_mobs_village_witch_giggle", damage = "cb_mobs_village_witch_hurt",
		death = "cb_mobs_village_witch_death", shoot_attack = "cb_items_throw", distance = 16, },
	animation = { speed_normal = 30, speed_run = 60, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40,
		run_start = 0, run_end = 40, shoot_start = 50, shoot_end = 82, },
	do_custom = function(self, dtime)
		self._wt = (self._wt or 0) + dtime
		if self._wt < 0.5 then
			return true
		end
		self._wt = 0
		choose(self)
		local now = core.get_gametime()
		if self.health < self.object:get_properties().hp_max and (self._drink or 0) <= now then
			self.health = math.min(self.object:get_properties().hp_max, self.health + 4)
			self._drink = now + 10
			core.sound_play("cb_mobs_village_drink", { object = self.object, max_hear_distance = 16, }, true)
		end
		return true
	end,
})

mobs:register_egg(NAME, S("Witch"), "default_obsidian_glass.png", 1)
