-- Frogs, tadpoles and froglights (spec cycle 4, 8b): a frog is temperate,
-- warm or cold by the heat of its biome. Its tongue catches small slimes
-- within 3 nodes; a small lava slime turns into a froglight of the frog's
-- kind. The servers have no slimeballs, Minecraft's frog food, so frogs do
-- not breed: tadpoles come by themselves in warm, shallow water, grow into
-- the frog of the climate they are in after 20 minutes and go into a water
-- bucket and back.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.FROG, A.TADPOLE = "cb_mobs_animals:frog", "cb_mobs_animals:tadpole"
A.TADPOLE_BUCKET = "cb_mobs_animals:tadpole_bucket"
A.FROGLIGHTS = { temperate = "cb_mobs_animals:ochre_froglight", warm = "cb_mobs_animals:pearlescent_froglight",
	cold = "cb_mobs_animals:verdant_froglight", }
local TEX = { temperate = "cb_mobs_animals_frog.png", warm = "cb_mobs_animals_frog_warm.png",
	cold = "cb_mobs_animals_frog_cold.png", }
-- prey: true for slimes, "lava" for those that turn into froglights
local PREY = { ["mobs_slimes:greensmall"] = true, ["mobs_slimes:lavasmall"] = "lava",
	["cb_mobs_nether:magma_cube_tiny"] = "lava", }
local TONGUE, GROW_TIME = 3, 1200
local WATER = { "default:water_source", "default:water_flowing", "default:river_water_source",
	"default:river_water_flowing", }

for kind, desc in pairs({ ochre = S("Ochre Froglight"), verdant = S("Verdant Froglight"),
	pearlescent = S("Pearlescent Froglight"), }) do
	local top, side = "cb_mobs_animals_" .. kind .. "_froglight_top.png", "cb_mobs_animals_" .. kind .. "_froglight_side.png"
	core.register_node("cb_mobs_animals:" .. kind .. "_froglight", {
		description = desc,
		tiles = { top, top, side, },
		paramtype2 = "facedir",
		on_place = core.rotate_node,
		light_source = core.LIGHT_MAX,
		groups = { cracky = 3, oddly_breakable_by_hand = 3, froglight = 1, },
		sounds = default.node_sound_glass_defaults(),
	})
end

function A.frog_kind(heat)
	return heat >= 70 and "warm" or heat <= 30 and "cold" or "temperate"
end

local function kind_at(pos)
	local data = core.get_biome_data(pos)
	return A.frog_kind(data and data.heat or 50)
end

local function retexture(self)
	self.base_texture = { TEX[self._kind] or TEX.temperate, }
	self.object:set_properties({ textures = self.base_texture, })
end

-- The tongue: the nearest small slime within reach is eaten.
function A.frog_eat(self)
	local pos = self.object:get_pos()
	local best, bd
	for _, obj in ipairs(core.get_objects_inside_radius(pos, TONGUE)) do
		local e = obj:get_luaentity()
		if e and PREY[e.name] and (e.health or 0) > 0 then
			local d = vector.distance(pos, obj:get_pos())
			if not bd or d < bd then
				best, bd = e, d
			end
		end
	end
	if not best then
		return false
	end
	local at = best.object:get_pos()
	local lava = PREY[best.name] == "lava"
	best.object:remove()
	if lava then
		core.add_item(at, A.FROGLIGHTS[self._kind] or A.FROGLIGHTS.temperate)
	end
	self:set_animation("eat", true)
	core.sound_play("cb_mobs_animals_frog_eat", { pos = pos, gain = 0.6, }, true)
	return true
end

mobs:register_mob(A.FROG, {
	type = "animal", passive = true, hp_min = 10, hp_max = 10, armor = 100,
	collisionbox = { -0.25, 0, -0.25, 0.25, 0.55, 0.25, },
	visual = "mesh", mesh = "cb_mobs_animals_frog.b3d", visual_size = { x = 1, y = 1, },
	textures = { { TEX.temperate, }, },
	makes_footstep_sound = false, walk_velocity = 1, run_velocity = 2, jump = true, jump_height = 4,
	view_range = 8, floats = 1, water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false,
	sounds = { random = "cb_mobs_animals_frog_croak", damage = "cb_mobs_animals_frog_hurt",
		death = "cb_mobs_animals_frog_hurt", distance = 12, },
	animation = { speed_normal = 45, stand_start = 0, stand_end = 0, walk_start = 1, walk_end = 21,
		run_start = 1, run_end = 21, run_speed = 70, eat_start = 54, eat_end = 64, eat_loop = false, },
	do_custom = function(self, dtime)
		self._eat_t = (self._eat_t or 0) + dtime
		if self._eat_t >= 2 then
			self._eat_t = 0
			A.frog_eat(self)
		end
	end,
	after_activate = function(self)
		self._kind = self._kind or kind_at(self.object:get_pos())
		retexture(self)
	end,
})
mobs:register_egg(A.FROG, S("Frog"), "cb_mobs_animals_frog.png", 1)

-- A tadpole old enough becomes the frog of the climate it is in.
function A.tadpole_grow(self)
	local pos = self.object:get_pos()
	self.object:remove()
	local obj = core.add_entity(pos, A.FROG)
	return obj and obj:get_luaentity()
end

mobs:register_mob(A.TADPOLE, {
	type = "animal", passive = true, hp_min = 6, hp_max = 6, armor = 100,
	collisionbox = { -0.2, 0, -0.2, 0.2, 0.3, 0.2, },
	visual = "mesh", mesh = "cb_mobs_animals_tadpole.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_animals_tadpole.png", }, },
	fly = true, fly_in = WATER, walk_velocity = 0.8, run_velocity = 1.5, jump = false, view_range = 6,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
	sounds = { damage = "cb_mobs_animals_frog_hurt", death = "cb_mobs_animals_frog_hurt", distance = 8, },
	animation = { speed_normal = 30, stand_start = 0, stand_end = 20, walk_start = 21, walk_end = 31,
		run_start = 21, run_end = 31, fly_start = 21, fly_end = 31, },
	do_custom = function(self, dtime)
		self._grow = (self._grow or 0) + dtime
		if self._grow >= GROW_TIME then
			A.tadpole_grow(self)
			return false
		end
	end,
	-- out of water: it chokes
	on_flop = function(self)
		self.health = self.health - 1
		self:check_for_death({ type = "environment", })
	end,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() then
			A.bucket_mob(self, clicker, A.TADPOLE_BUCKET, { "_grow", })
		end
	end,
})
mobs:register_egg(A.TADPOLE, S("Tadpole"), "cb_mobs_animals_tadpole.png", 1)

A.register_mob_bucket(A.TADPOLE_BUCKET, { description = S("Bucket of Tadpole"),
	overlay = "cb_mobs_animals_tadpole_bucket_overlay.png", mob = A.TADPOLE, })
