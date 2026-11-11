-- Creeper (spec cycle 4, 8a): walks up and explodes; the blast hurts and
-- pushes creatures within 3 (6 when charged by lightning) and never breaks
-- nodes (owner's rule: only the wither breaks blocks). It goes for players
-- only and runs from ocelots and cats.
local S = cb_mobs_overworld.S
local Z = cb_mobs_overworld
Z.CREEPER = "cb_mobs_overworld:creeper"

-- mobs_redo's explode attack calls mobs:boom, which breaks nodes when
-- mobs_griefing is on; mobs flagged _cb_safe_boom only hurt.
local boom = mobs.boom
function mobs:boom(self, pos, node_r, entity_r, texture)
	if self and self._cb_safe_boom then
		-- mobs_redo's explode attack passes no texture: nil particles show
		-- as unknown_node squares flying around. Z.blasting tells the punched
		-- creatures (wolves) the blow is a creeper's blast.
		Z.blasting = true
		local ok, err = pcall(mobs.safe_boom, mobs, self, pos, entity_r or node_r, texture or "mobs_tnt_smoke.png")
		Z.blasting = nil
		if not ok then
			error(err, 0)
		end
		return
	end
	return boom(mobs, self, pos, node_r, entity_r, texture)
end

local TEX = "cb_mobs_overworld_creeper.png"

-- Creepers fear cats: one within CAT_FEAR nodes stops the fuse and sends the
-- creeper running.
Z.CATS = { ["cb_mobs_animals:ocelot"] = true, ["mobs_animal:kitten"] = true, }
Z.CAT_FEAR = 6

function Z.creeper_fear(self, dtime)
	self._fear_t = (self._fear_t or 0) + dtime
	if self._fear_t < 0.5 then
		return true
	end
	self._fear_t = 0
	local pos = self.object:get_pos()
	if not pos then
		return true
	end
	for _, obj in ipairs(core.get_objects_inside_radius(pos, Z.CAT_FEAR)) do
		local e = obj:get_luaentity()
		if e and Z.CATS[e.name] and (e.health or 1) > 0 then
			if self.v_start then
				self.v_start, self.timer, self.blinktimer, self.blinkstatus = false, 0, 0, false
				self.object:set_texture_mod(self.texture_mods or "")
			end
			self.attack, self.following = nil, nil
			self:yaw_to_pos(obj:get_pos(), 3)
			self.state, self.runaway_timer = "runaway", 3
			self:set_velocity(self.run_velocity)
			self:set_animation("walk")
			return true
		end
	end
	return true
end

function Z.charge_creeper(ent)
	ent._charged = true
	ent.explosion_damage_radius, ent.explosion_radius = 6, 6
	ent.object:set_properties({ textures = { TEX, "cb_mobs_overworld_creeper_charge.png", }, })
end

mobs:register_mob(Z.CREEPER, {
	-- players only: never villagers or tamed wolves (they fight back if hit)
	type = "monster", passive = false, attack_type = "explode", reach = 3, attack_npcs = false,
	attack_animals = false,
	explosion_radius = 3, explosion_damage_radius = 3, explosion_timer = 1.5,
	hp_min = 20, hp_max = 20, armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 1.7, 0.3, },
	visual = "mesh", mesh = "cb_mobs_overworld_creeper.b3d", visual_size = { x = 3, y = 3, },
	textures = { { TEX, "blank.png", }, },
	makes_footstep_sound = false, walk_velocity = 1, run_velocity = 1.8, jump = true, stepheight = 1.1,
	view_range = 16, water_damage = 0, lava_damage = 8,
	drops = core.registered_items["tnt:gunpowder"] and { { name = "tnt:gunpowder", chance = 1, min = 0, max = 2, }, } or {},
	sounds = { damage = "cb_mobs_overworld_creeper_hurt", death = "cb_mobs_overworld_creeper_death",
		fuse = "cb_mobs_overworld_creeper_fuse", explode = "tnt_explode", distance = 16, },
	animation = { speed_normal = 48, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40, run_start = 0,
		run_end = 40, },
	do_custom = function(self, dtime)
		return Z.creeper_fear(self, dtime)
	end,
	-- the lightning mod's own strikes (no position given) punch every object
	-- near them with itself as the puncher and 8 fleshy damage
	do_punch = function(self, hitter, _, caps)
		if rawget(_G, "lightning") and hitter == self.object and not self._charged
				and caps and caps.damage_groups and caps.damage_groups.fleshy == 8 then
			Z.charge_creeper(self)
		end
	end,
	after_activate = function(self)
		self._cb_safe_boom = true
		if self._charged then
			Z.charge_creeper(self)
		end
	end,
})
mobs:register_egg(Z.CREEPER, S("Creeper"), "default_grass.png", 1)

if rawget(_G, "lightning") and lightning.strike then
	local strike = lightning.strike
	lightning.strike = function(pos)
		local r = strike(pos)
		if pos then
			for _, obj in ipairs(core.get_objects_inside_radius(pos, 4)) do
				local e = obj:get_luaentity()
				if e and e.name == Z.CREEPER and not e._charged then
					Z.charge_creeper(e)
				end
			end
		end
		return r
	end
end
