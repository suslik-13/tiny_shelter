-- Squid and glow squid (spec cycle 4, 8c): they drift in water; hit, they
-- squirt a cloud of ink and dart away. Ink sacs make black dye; glow ink
-- sacs (Minecraft's glowing signs and frames do not exist here) cyan dye.
-- Squid live in open water under the sky, glow squid in dark water below 0.
local S = cb_mobs_water.S
local W = cb_mobs_water
W.SQUID, W.GLOW_SQUID = "cb_mobs_water:squid", "cb_mobs_water:glow_squid"
W.INK, W.GLOW_INK = "cb_mobs_water:ink_sac", "cb_mobs_water:glow_ink_sac"

core.register_craftitem(W.INK, { description = S("Ink Sac"), inventory_image = "cb_mobs_water_ink_sac.png", })
core.register_craftitem(W.GLOW_INK, { description = S("Glow Ink Sac"),
	inventory_image = "cb_mobs_water_glow_ink_sac.png", })
if core.get_modpath("dye") then
	core.register_craft({ type = "shapeless", output = "dye:black", recipe = { W.INK, }, })
	core.register_craft({ type = "shapeless", output = "dye:cyan", recipe = { W.GLOW_INK, }, })
end

-- The ink cloud and the dash away from what hit it.
function W.squirt(self, from)
	local pos = self.object:get_pos()
	core.add_particlespawner({
		amount = 30, time = 0.3, minpos = vector.offset(pos, -0.3, 0.2, -0.3), maxpos = vector.offset(pos, 0.3, 0.8, 0.3),
		minvel = { x = -1, y = -0.5, z = -1, }, maxvel = { x = 1, y = 0.5, z = 1, }, minexptime = 1, maxexptime = 2,
		minsize = 2, maxsize = 4, texture = self._ink_tex, glow = self._ink_glow or 0,
	})
	local away = from and vector.direction(from, pos) or vector.new(0, 0, 1)
	self.object:set_velocity(vector.multiply(away, 4))
	self.state, self.runaway_timer = "runaway", 3
	return away
end

local function register(name, desc, tex, drop, glow, ink_tex)
	mobs:register_mob(name, {
		type = "animal", passive = true, hp_min = 10, hp_max = 10, armor = 100, glow = glow,
		collisionbox = { -0.4, 0, -0.4, 0.4, 0.9, 0.4, },
		visual = "mesh", mesh = "cb_mobs_water_squid.b3d", visual_size = { x = 3, y = 3, },
		textures = { { tex, }, },
		fly = true, fly_in = W.WATER, walk_velocity = 0.8, run_velocity = 3, jump = false, view_range = 8,
		water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
		drops = { { name = drop, chance = 1, min = 1, max = 3, }, },
		sounds = { damage = "cb_mobs_water_squid_hurt", death = "cb_mobs_water_squid_death", distance = 12, },
		animation = {},
		do_punch = function(self, hitter)
			W.squirt(self, hitter and hitter:get_pos())
		end,
		on_flop = W.choke,
		after_activate = function(self)
			self._ink_tex, self._ink_glow = ink_tex, glow
		end,
	})
	mobs:register_egg(name, desc, tex, 1)
end
register(W.SQUID, S("Squid"), "cb_mobs_water_squid.png", W.INK, 0, "cb_mobs_water_ink.png")
register(W.GLOW_SQUID, S("Glow Squid"), "cb_mobs_water_glow_squid.png", W.GLOW_INK, 10, "cb_mobs_water_glow_ink.png")
