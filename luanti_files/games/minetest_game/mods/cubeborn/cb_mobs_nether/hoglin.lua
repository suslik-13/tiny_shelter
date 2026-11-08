-- Hoglin and zoglin (spec cycle 4, 8d): hoglins roam crimson Nether woods
-- and attack players; they keep away from warped fungi and breed on crimson
-- fungi. In the Overworld a hoglin turns into a zoglin after 15 s, which
-- attacks every creature and never breeds. Both drop raw pork and leather.
local S = cb_mobs_nether.S
local N = cb_mobs_nether
local A = rawget(_G, "cb_mobs_animals")
N.HOGLIN, N.ZOGLIN = "cb_mobs_nether:hoglin", "cb_mobs_nether:zoglin"
local ZOGLIN_TIME = 15

function N.zoglinify(self)
	local pos = self.object:get_pos()
	self.object:remove()
	local obj = core.add_entity(pos, N.ZOGLIN)
	return obj and obj:get_luaentity()
end

local drops = { { name = "mobs:pork_raw", chance = 1, min = 2, max = 4, }, { name = "mobs:leather", chance = 2, min = 0, max = 1, }, }
local ANIM = { speed_normal = 30, stand_start = 24, stand_end = 24, walk_start = 11, walk_end = 21,
	run_start = 1, run_end = 10, punch_start = 22, punch_end = 32, punch_speed = 20, }

local function register(name, desc, tex, extra)
	local def = {
		type = "monster", passive = false, attack_type = "dogfight", damage = 6, reach = 2,
		hp_min = 40, hp_max = 40, armor = 100,
		collisionbox = { -0.6, 0, -0.6, 0.6, 1.4, 0.6, },
		visual = "mesh", mesh = "cb_mobs_nether_hoglin.b3d", visual_size = { x = 3, y = 3, },
		textures = { { tex, }, },
		makes_footstep_sound = true, walk_velocity = 1, run_velocity = 2.5, jump = true, view_range = 16,
		water_damage = 0, lava_damage = 4, light_damage = 0, fall_damage = true,
		drops = drops,
		sounds = { random = "cb_mobs_nether_hoglin", damage = "cb_mobs_nether_hoglin_hurt",
			death = "cb_mobs_nether_hoglin_hurt", distance = 16, },
		animation = ANIM,
	}
	for k, v in pairs(extra) do
		def[k] = v
	end
	mobs:register_mob(name, def)
	mobs:register_egg(name, desc, tex, 1)
end

register(N.HOGLIN, S("Hoglin"), "cb_mobs_nether_hoglin.png", {
	runaway_from = { "cb_blocks:warped_fungus", },
	follow = { "cb_blocks:crimson_fungus", },
	do_custom = function(self, dtime)
		local pos = self.object:get_pos()
		if cb_spawning.dim_at and cb_spawning.dim_at(pos) == "overworld" then
			self._zt = (self._zt or 0) + dtime
			if self._zt >= ZOGLIN_TIME then
				N.zoglinify(self)
				return false
			end
		end
	end,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() then
			mobs:feed_tame(self, clicker, 1, true, false)
		end
	end,
	on_breed = function(self, other)
		return A and A.on_breed(self, other) or false
	end,
})
register(N.ZOGLIN, S("Zoglin"), "cb_mobs_nether_zoglin.png", {
	attack_animals = true, attack_npcs = true, attack_monsters = true,
	attack_ignore = { N.ZOGLIN, "cb_mobs_dim:ender_dragon", },
	on_breed = function() return false end,
})
