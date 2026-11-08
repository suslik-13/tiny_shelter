-- Zombies and husks (spec cycle 4, 8a): Mineclonia's model on mobs_redo.
-- Zombies burn in daylight, husks do not and give hunger; 5 % spawn as
-- babies that never grow up and walk faster. Villagers they kill turn into
-- zombie villagers (cb_mobs_village matches names with "zombie").
local S = cb_mobs_overworld.S
local Z = cb_mobs_overworld
Z.ZOMBIE, Z.HUSK = "cb_mobs_overworld:zombie", "cb_mobs_overworld:husk"
Z.BABY_CHANCE = 0.05

function Z.make_baby(ent)
	ent.child = true
	ent.hornytimer = 0
	ent.walk_velocity, ent.run_velocity = ent.walk_velocity * 1.5, ent.run_velocity * 1.5
	local p = ent.object:get_properties()
	ent.object:set_properties({ visual_size = { x = p.visual_size.x * 0.5, y = p.visual_size.y * 0.5, },
		collisionbox = { -0.15, 0, -0.15, 0.15, 0.97, 0.15, }, })
end

-- A hit landed on obj (player or mob): husks give hunger.
function Z.on_hit(self, obj)
	if self.name == Z.HUSK and obj.is_player and obj:is_player() then
		cb_core.effects.apply(obj, "hunger", 1, 7 * ({ easy = 1, normal = 1, hard = 2, })[cb_core.difficulty()])
	end
end

Z.custom = {} -- name -> list of do_custom steps (Task 3 adds the breaker)

function Z.register_zombie(name, def, head_y)
	local base = {
		type = "monster", passive = false, attack_type = "dogfight", reach = 2, damage = 3,
		hp_min = 20, hp_max = 20, armor = 100,
		collisionbox = { -0.3, 0, -0.3, 0.3, 1.95, 0.3, },
		visual = "mesh", mesh = "cb_mobs_overworld_zombie.b3d", visual_size = { x = 1, y = 1.1, },
		makes_footstep_sound = true, stepheight = 1.1, walk_velocity = 1, run_velocity = 1.8, jump = true,
		view_range = 16, water_damage = 0, lava_damage = 8, attack_npcs = true, attack_animals = false,
		specific_attack = { "player", "cb_mobs_village:villager", "cb_mobs_trader:trader", "cb_mobs_village:iron_golem", },
		drops = { { name = "cb_items:rotten_flesh", chance = 1, min = 0, max = 2, }, },
		sounds = { random = "cb_mobs_overworld_zombie_growl", war_cry = "cb_mobs_overworld_zombie_growl",
			damage = "cb_mobs_overworld_zombie_hurt", death = "cb_mobs_overworld_zombie_death", attack = "mobs_punch",
			distance = 16, },
		animation = { speed_normal = 25, stand_start = 40, stand_end = 49, walk_start = 0, walk_end = 39,
			run_start = 0, run_end = 39, punch_start = 50, punch_end = 59, },
		-- mobs_redo calls self:custom_attack(self, target_pos); the target is
		-- self.attack; true lets the ordinary punch go on
		custom_attack = function(self)
			if self.attack then
				Z.on_hit(self, self.attack)
			end
			return true
		end,
		do_custom = function(self, dtime)
			if self.child then
				self.hornytimer = 0
			end
			for _, step in ipairs(Z.custom[self.name] or {}) do
				if step(self, dtime) == false then
					return false
				end
			end
			return true
		end,
	}
	local own_after = def.after_activate
	for k, v in pairs(def) do
		base[k] = v
	end
	-- babies first, then the mob's own after_activate
	base.after_activate = function(self, ...)
		-- decided once; a reloaded baby keeps child and its speeds from its
		-- staticdata, and mobs_redo halves its size itself
		if self._baby == nil then
			self._baby = math.random() < Z.BABY_CHANCE
			if self._baby then
				Z.make_baby(self)
			end
		end
		if own_after then
			return own_after(self, ...)
		end
	end
	Z.custom[name] = Z.custom[name] or {}
	-- head_y: the head.control bone height (Mineclonia bone_eye_height), or
	-- false for models whose head bone needs no pinning
	if head_y ~= false then
		base = cb_core.fixed_head(base, head_y or 6.3)
	end
	mobs:register_mob(name, base)
end

Z.register_zombie(Z.ZOMBIE, {
	textures = { { "blank.png", "cb_mobs_overworld_zombie.png", }, },
	light_damage = 2,
})
Z.register_zombie(Z.HUSK, {
	textures = { { "blank.png", "cb_mobs_overworld_husk.png", }, },
	light_damage = 0,
})

mobs:register_egg(Z.ZOMBIE, S("Zombie"), "default_dirt.png", 1)
mobs:register_egg(Z.HUSK, S("Husk"), "default_sand.png", 1)
