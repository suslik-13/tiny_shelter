-- Snow golem (spec cycle 4, 8b; BACKLOG): a pumpkin on two snow blocks. It
-- throws snowballs at monsters within 10 nodes: they only push back, but
-- burn fiery mobs for 3. Snowballs are its own; players have none. Where the
-- biome is cool it leaves a trail of snow (not in protected areas); in hot
-- biomes and in water it melts away (1 damage a second). Shears take its
-- pumpkin off. Drops snow.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.SNOW_GOLEM, A.SNOWBALL = "cb_mobs_animals:snow_golem", "cb_mobs_animals:snowball"
local FIERY = { ["cb_mobs_dim:blaze"] = true, ["cb_mobs_dim:magma_cube"] = true, ["mobs_monster:fire_spirit"] = true,
	["mobs_monster:lava_flan"] = true, }
local BODY = "cb_mobs_animals_snow_golem.png"
local HEAD = { BODY, "farming_pumpkin_side.png", "farming_pumpkin_top.png", "farming_pumpkin_side.png^farming_pumpkin_face_off.png",
	"farming_pumpkin_side.png", "farming_pumpkin_side.png", "farming_pumpkin_top.png", }
local BARE = { BODY, "blank.png", "blank.png", "blank.png", "blank.png", "blank.png", "blank.png", }
local COOL, HOT = 50, 70

-- A snowball hit: fiery mobs burn, everyone else is only pushed.
function A.snowball_hit(ball_pos, obj)
	local e = obj:get_luaentity()
	local dir = vector.direction(ball_pos, obj:get_pos())
	if e and FIERY[e.name] then
		obj:punch(obj, 1, { full_punch_interval = 1, damage_groups = { fleshy = 3, }, }, dir)
		return 3
	end
	obj:add_velocity({ x = dir.x * 3, y = 1, z = dir.z * 3, })
	return 0
end

mobs:register_arrow(A.SNOWBALL, {
	visual = "sprite", visual_size = { x = 0.4, y = 0.4, }, textures = { "cb_mobs_animals_snowball.png", },
	collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1, }, velocity = 16,
	hit_player = function(self, player)
		A.snowball_hit(self.object:get_pos(), player)
	end,
	hit_mob = function(self, mob)
		A.snowball_hit(self.object:get_pos(), mob)
	end,
	hit_node = function() end,
})

local function heat_at(pos)
	local data = core.get_biome_data(pos)
	return data and data.heat or 50
end

-- Snow under its feet where the biome is cool enough and nobody owns the spot.
function A.snow_trail(self, heat)
	local pos = vector.round(self.object:get_pos())
	if (heat or heat_at(pos)) > COOL or core.get_node(pos).name ~= "air" or core.is_protected(pos, "") then
		return false
	end
	local below = core.registered_nodes[core.get_node(vector.offset(pos, 0, -1, 0)).name]
	if not (below and below.walkable and (below.drawtype or "normal") == "normal") then
		return false
	end
	core.set_node(pos, { name = "default:snow", })
	return true
end

-- In a hot biome or in water it melts: true when it took damage.
function A.snow_melt(self, heat)
	local wet = core.get_item_group(self.standing_in or "", "water") > 0
	if (heat or heat_at(self.object:get_pos())) < HOT and not wet then
		return false
	end
	self.health = self.health - 1
	self:check_for_death({ type = "environment", })
	return true
end

mobs:register_mob(A.SNOW_GOLEM, {
	type = "npc", passive = false, attack_monsters = true, attack_players = false, attack_npcs = false,
	attack_animals = false, attack_type = "shoot", arrow = A.SNOWBALL, shoot_interval = 1, shoot_offset = 1.2,
	hp_min = 4, hp_max = 4, armor = 100,
	collisionbox = { -0.35, 0, -0.35, 0.35, 1.89, 0.35, },
	visual = "mesh", mesh = "cb_mobs_animals_snow_golem.b3d", visual_size = { x = 3, y = 3, },
	textures = { HEAD, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 1.5, jump = true, view_range = 10,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false,
	drops = { { name = "default:snow", chance = 1, min = 0, max = 15, }, },
	sounds = { damage = "cb_mobs_animals_snow_golem_hurt", death = "cb_mobs_animals_snow_golem_death", distance = 16, },
	animation = { speed_normal = 25, stand_start = 20, stand_end = 40, walk_start = 0, walk_end = 20,
		run_start = 0, run_end = 20, shoot_start = 20, shoot_end = 40, },
	do_custom = function(self, dtime)
		self._snow_t = (self._snow_t or 0) + dtime
		if self._snow_t >= 0.5 then
			self._melt_t = (self._melt_t or 0) + self._snow_t
			self._snow_t = 0
			local heat = heat_at(self.object:get_pos())
			A.snow_trail(self, heat)
			if self._melt_t >= 1 then
				self._melt_t = 0
				A.snow_melt(self, heat)
			end
		end
	end,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() and not self._sheared
			and clicker:get_wielded_item():get_name() == "mobs:shears" then
			self._sheared = true
			self.base_texture = BARE
			self.object:set_properties({ textures = BARE, })
			core.sound_play("cb_mobs_animals_shear", { pos = self.object:get_pos(), }, true)
		end
	end,
	after_activate = function(self)
		self.base_texture = self._sheared and BARE or HEAD
		self.object:set_properties({ textures = self.base_texture, })
	end,
})
mobs:register_egg(A.SNOW_GOLEM, S("Snow Golem"), "default_snow.png", 1)

A.register_golem(A.SNOW_GOLEM, { "default:snowblock", "default:snowblock", }, function(e)
	-- built golems are kept like tamed ones
	e.tamed, e.static_save = true, true
end)
