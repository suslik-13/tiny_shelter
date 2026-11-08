-- Illagers (spec cycle 2, 5): hostile to players, villagers and golems, not
-- to each other. The pillager's crossbow bolt is an entity only; the captain
-- (Bad Omen in plan 5d) is a pillager with _captain set.
local S = cb_mobs_illager.S
local I = cb_mobs_illager
I.ILLAGERS = {}
local VICTIMS = { "player", "cb_mobs_village:villager", "cb_mobs_village:iron_golem", "cb_mobs_village:zombie_villager", }

function I.drops(list)
	local out = {}
	for _, d in ipairs(list) do
		if core.registered_items[d[1]] then
			out[#out + 1] = { name = d[1], chance = d[4] or 1, min = d[2], max = d[3], }
		end
	end
	return out
end

-- Arrows of illagers look like Mineclonia's arrow and point the way they
-- fly (mobs_redo only turns arrows around the vertical axis).
I.ARROW_LOOK = { visual = "mesh", mesh = "cb_mobs_illager_arrow.b3d", visual_size = { x = -1, y = 1, },
	textures = { "cb_mobs_illager_arrow.png", }, }

function I.point_arrow(name)
	local def = core.registered_entities[name]
	local step = def.on_step
	def.on_step = function(self, dtime, ...)
		local v = self.object:get_velocity()
		if v and (v.x ~= 0 or v.z ~= 0) then
			self.object:set_rotation({ x = 0, y = core.dir_to_yaw(v) - math.pi / 2,
				z = -math.atan2(-v.y, math.abs(v.x) + math.abs(v.z)), })
		end
		return step(self, dtime, ...)
	end
end

-- Pillager 6, captain 9 (set when shot, see arrow_override below).
local function hit(self, obj)
	local e = obj:get_luaentity()
	if e and I.ILLAGERS[e.name] then
		return
	end
	obj:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = self._dmg or 6, }, }, nil)
end

local bolt = { velocity = 18, hit_player = hit, hit_mob = hit, hit_node = function() end, }
for k, v in pairs(I.ARROW_LOOK) do
	bolt[k] = v
end
mobs:register_arrow("cb_mobs_illager:bolt", bolt)
I.point_arrow("cb_mobs_illager:bolt")

local BASE = {
	type = "monster",
	passive = false,
	hp_min = 24,
	hp_max = 24,
	armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 1.95, 0.3, },
	visual = "mesh",
	visual_size = { x = 2.75, y = 2.75, },
	makes_footstep_sound = true,
	walk_velocity = 1,
	run_velocity = 2.2,
	view_range = 16,
	jump = true,
	stepheight = 1.1,
	water_damage = 0,
	lava_damage = 8,
	attack_npcs = true,
	attack_animals = false,
	specific_attack = VICTIMS,
	sounds = { random = "cb_mobs_illager_pillager_grunt", damage = "cb_mobs_illager_pillager_hurt",
		death = "cb_mobs_illager_illager_death", attack = "mobs_punch", shoot_attack = "cb_mobs_illager_crossbow",
		distance = 16, },
	animation = { speed_normal = 25, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40, run_start = 0,
		run_end = 40, punch_start = 0, punch_end = 40, shoot_start = 0, shoot_end = 40, },
}

function I.register(name, def)
	local full = table.copy(BASE)
	for k, v in pairs(def) do
		full[k] = v
	end
	mobs:register_mob(name, full)
	I.ILLAGERS[name] = true
end

function I.make_captain(ent)
	ent._captain = true
	ent.object:set_properties({ nametag = S("Pillager Captain"), nametag_color = "#c0c0c0", })
end

I.register("cb_mobs_illager:pillager", {
	mesh = "cb_mobs_illager_pillager.b3d",
	textures = { { "cb_mobs_illager_pillager.png", }, },
	attack_type = "shoot",
	arrow = "cb_mobs_illager:bolt",
	shoot_interval = 2,
	shoot_offset = 1.5,
	drops = {},
	after_activate = function(self)
		if self._captain then
			I.make_captain(self)
		end
		-- mobs_redo calls the shooter's arrow_override with each new arrow
		self.arrow_override = function(arrow)
			arrow._dmg = self._captain and 9 or 6
		end
	end,
})

I.register("cb_mobs_illager:vindicator", cb_core.fixed_head({
	-- Mineclonia's vindicator/evoker meshes are modelled at full size, unlike the pillager's
	visual_size = { x = 1, y = 1, },
	mesh = "cb_mobs_illager_vindicator.b3d",
	textures = { { "cb_mobs_illager_vindicator.png", }, },
	attack_type = "dogfight",
	reach = 2,
	damage = 8,
	drops = I.drops({ { "cb_items:emerald", 0, 1, }, }),
}, 6.61948))

mobs:register_egg("cb_mobs_illager:pillager", S("Pillager"), "default_stone.png", 1)
mobs:register_egg("cb_mobs_illager:vindicator", S("Vindicator"), "default_stone.png", 1)
