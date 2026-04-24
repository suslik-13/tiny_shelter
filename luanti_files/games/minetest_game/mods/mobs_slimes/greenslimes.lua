
-- Green Slimes by TomasJLuis & TenPlus1

local S = core.get_translator("mobs_slimes")
local MP = core.get_modpath(core.get_current_modname()) .. "/"

-- sounds

local green_sounds = {
	damage = "slimes_damage",
	death = "slimes_death",
	jump = "slimes_jump",
	attack = "slimes_attack",
}

-- green slime textures

local green_textures = {
	"green_slime_sides.png", "green_slime_sides.png", "green_slime_sides.png",
	"green_slime_sides.png", "green_slime_front.png", "green_slime_sides.png"
}

-- small green slime

mobs:register_mob("mobs_slimes:greensmall", {
	type = "monster",
	hp_min = 1, hp_max = 2,
	collisionbox = {-0.25, -0.25, -0.25, 0.25, 0.25, 0.25},
	stepheight = 0.5,
	visual = "cube",
	visual_size = {x = 0.5, y = 0.5},
	textures = {green_textures},
	blood_texture = "green_slime_blood.png",
	makes_footstep_sound = false,
	sounds = green_sounds,
	attack_type = "dogfight",
	attack_animals = true,
	damage = 1, reach = 2,
	passive = false,
	walk_velocity = 1,
	run_velocity = 1,
	walk_chance = 0,
	jump_chance = 30,
	jump_height = 3,
	armor = 100,
	view_range = 15,
	drops = {
		{name = "mesecons_materials:glue", chance = 4, min = 1, max = 2},
	},
	water_damage = 0,
	lava_damage = 10,
	light_damage = 0
})

-- medium green slime

mobs:register_mob("mobs_slimes:greenmedium", {
	type = "monster",
	hp_min = 3, hp_max = 4,
	collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	stepheight = 0.5,
	visual = "cube",
	visual_size = {x = 1, y = 1},
	textures = {green_textures},
	blood_texture = "green_slime_blood.png",
	makes_footstep_sound = false,
	sounds = green_sounds,
	attack_type = "dogfight",
	attack_animals = true,
	damage = 2, reach = 2,
	passive = false,
	walk_velocity = 1,
	run_velocity = 2,
	walk_chance = 0,
	jump_chance = 30,
	jump_height = 5,
	armor = 100,
	view_range = 15,
	water_damage = 0,
	lava_damage = 10,
	light_damage = 0,

	on_die = function(self, pos)

		local num = math.random(2, 4)

		for i = 1, num do

			local obj = core.add_entity({
				x = pos.x + math.random(-2, 2),
				y = pos.y + 1,
				z = pos.z + (math.random(-2, 2))
			}, "mobs_slimes:greensmall")

			local ent = obj and obj:get_luaentity()

			if ent then
				ent.state = "attack"
				ent.attack = self.attack
			end
		end
	end
})

-- big green slime

mobs:register_mob("mobs_slimes:greenbig", {
	type = "monster",
	hp_min = 7, hp_max = 8,
	collisionbox = {-1, -1, -1, 1, 1, 1},
	stepheight = 0.5,
	visual = "cube",
	visual_size = {x = 2, y = 2},
	textures = {green_textures},
	blood_texture = "green_slime_blood.png",
	makes_footstep_sound = false,
	sounds = green_sounds,
	attack_type = "dogfight",
	attack_animals = true,
	damage = 4, reach = 3,
	passive = false,
	walk_velocity = 1,
	run_velocity = 2,
	walk_chance = 0,
	jump_chance = 30,
	jump_height = 8,
	armor = 100,
	view_range = 15,
	water_damage = 0,
	lava_damage = 10,
	light_damage = 0,

	on_die = function(self, pos)

		local num = math.random(2, 4)

		for i = 1, num do

			local obj = core.add_entity({
				x = pos.x + math.random(-2, 2),
				y = pos.y + 1,
				z = pos.z + (math.random(-2, 2))
			}, "mobs_slimes:greenmedium")

			local ent = obj and obj:get_luaentity()

			if ent then
				ent.state = "attack"
				ent.attack = self.attack
			end
		end
	end
})

-- spawn eggs

mobs:register_egg("mobs_slimes:greensmall", S("Small Green Slime"), "green_slime_egg.png", 1)
mobs:register_egg("mobs_slimes:greenmedium", S("Medium Green Slime"), "green_slime_egg.png", 1)
mobs:register_egg("mobs_slimes:greenbig", S("Big Green Slime"), "green_slime_egg.png", 1)

-- check for custom spawn.lua

local input = io.open(MP .. "spawn.lua", "r")

if input then
	input:close()
	input = nil
	dofile(MP .. "spawn.lua")
else
	-- choose spawn medium depending on [game]
	local nod_dirt = "default:dirt_with_rainforest_litter"
	local nod_grass = "default:junglegrass"
	local nod_mossy = "default:mossycobble"

	if core.get_modpath("mcl_core") then
		nod_dirt = "mcl_core:dirt_with_grass"
		nod_grass = "mcl_flowers:tallgrass"
		nod_mossy = "mcl_core:mossycobble"
	end

	-- spawn in world
	mobs:spawn({
		name = "mobs_slimes:greensmall",
		nodes = {nod_dirt},
		neighbors = {"air", nod_grass},
		min_light = 4,
		chance = 5000,
		min_height = 0,
		active_object_count = 8
	})

	mobs:spawn({
		name = "mobs_slimes:greenmedium",
		nodes = {nod_dirt},
		neighbors = {"air", nod_grass},
		min_light = 4,
		chance = 10000,
		min_height = 0,
		active_object_count = 8
	})

	mobs:spawn({
		name = "mobs_slimes:greenbig",
		nodes = {nod_dirt},
		neighbors = {"air", nod_grass},
		min_light = 4,
		chance = 15000,
		min_height = 0,
		active_object_count = 8
	})

	mobs:spawn({
		name = "mobs_slimes:greensmall",
		nodes = {nod_mossy},
		min_light = 4,
		chance = 10000,
		min_height = 0,
		active_object_count = 8
	})

	mobs:spawn({
		name = "mobs_slimes:greenmedium",
		nodes = {nod_mossy},
		min_light = 4,
		chance = 10000,
		min_height = 0,
		active_object_count = 8
	})
end

-- compatibility

mobs:alias_mob("slimes:greensmall", "mobs_slimes:greensmall")
mobs:alias_mob("slimes:greenmedium", "mobs_slimes:greenmedium")
mobs:alias_mob("slimes:greenbig", "mobs_slimes:greenbig")

