-- Illusioner (spec cycle 4, 8a): a rare mansion inhabitant; shoots arrows
-- (mob projectiles only), and every ~30 s blinds its target, hides and
-- sends four harmless decoys that vanish when hit or after 30 s.
local S = cb_mobs_illager.S
local I = cb_mobs_illager
I.ILLUSIONER, I.ILLUSION_EVERY, I.ILLUSION_TIME = "cb_mobs_illager:illusioner", 30, 30
local MESH, TEX = "cb_mobs_illager_illusioner.b3d", "cb_mobs_illager_illusioner.png"

mobs:register_arrow("cb_mobs_illager:illusion_arrow", {
	visual = I.ARROW_LOOK.visual, mesh = I.ARROW_LOOK.mesh, visual_size = I.ARROW_LOOK.visual_size,
	textures = I.ARROW_LOOK.textures, velocity = 18,
	hit_player = function(self, player)
		player:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = 4, }, }, nil)
	end,
	hit_mob = function(self, obj)
		obj:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = 4, }, }, nil)
	end,
	hit_node = function() end,
})

I.point_arrow("cb_mobs_illager:illusion_arrow")

core.register_entity("cb_mobs_illager:illusion", {
	initial_properties = { visual = "mesh", mesh = MESH, textures = { TEX, TEX, }, visual_size = { x = 1, y = 1, },
		physical = false, collisionbox = { -0.4, 0, -0.4, 0.4, 1.95, 0.4, }, static_save = false, },
	on_activate = function(self)
		self._life = I.ILLUSION_TIME
		self.object:set_animation({ x = 0, y = 40, }, 25, 0, true)
	end,
	on_step = function(self, dtime)
		self._life = self._life - dtime
		if self._life <= 0 then
			self.object:remove()
		end
	end,
	on_punch = function(self)
		self.object:remove()
		return true
	end,
})

function I.cast_illusion(ent, target)
	local pos = ent.object:get_pos()
	if not pos then
		return 0
	end
	if target and target.is_player and target:is_player() then
		cb_core.effects.apply(target, "blindness", 1, 10)
	end
	core.sound_play("cb_mobs_illager_illusion_cast", { pos = pos, max_hear_distance = 24, }, true)
	local n = 0
	for i = 1, 4 do
		local a = i * math.pi / 2
		if core.add_entity(vector.offset(pos, math.cos(a) * 2, 0, math.sin(a) * 2), "cb_mobs_illager:illusion") then
			n = n + 1
		end
	end
	ent.object:set_properties({ is_visible = false, })
	ent._hidden = I.ILLUSION_TIME
	return n
end

I.register(I.ILLUSIONER, cb_core.fixed_head({
	visual_size = { x = 1, y = 1, },
	hp_min = 32, hp_max = 32, collisionbox = { -0.4, 0, -0.4, 0.4, 1.95, 0.4, },
	mesh = MESH, textures = { { TEX, TEX, }, },
	attack_type = "shoot", arrow = "cb_mobs_illager:illusion_arrow", shoot_interval = 1.5, shoot_offset = 1.5,
	drops = {},
	do_custom = function(self, dtime)
		if self._hidden then
			self._hidden = self._hidden - dtime
			if self._hidden <= 0 then
				self._hidden = nil
				self.object:set_properties({ is_visible = true, })
			end
		end
		self._cast = (self._cast or I.ILLUSION_EVERY) - dtime
		if self._cast <= 0 and self.attack and self.state == "attack" then
			self._cast = I.ILLUSION_EVERY
			I.cast_illusion(self, self.attack)
		end
		return true
	end,
}, 6.61948))
mobs:register_egg(I.ILLUSIONER, S("Illusioner"), "default_obsidian_glass.png", 1)
