-- Sniffer (spec cycle 4, 8b): every 400-500 s an adult sniffs out a patch
-- of dirt, grass or moss within 20 nodes, walks there, digs for 8-10 s and
-- turns up torchflower seeds or a pitcher pod. Planted on soil they grow
-- into a torchflower and a pitcher plant, decorative flowers (orange and
-- cyan dye). Torchflower seeds breed sniffers: the pair lays a sniffer egg
-- that hatches after 20 minutes (10 on moss). Minecraft finds the first
-- eggs in ocean ruins, which the servers do not have: here sniffers also
-- come by themselves, rarely, in warm lands.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.SNIFFER = "cb_mobs_animals:sniffer"
A.TORCHFLOWER_SEEDS, A.PITCHER_POD = "cb_mobs_animals:torchflower_seeds", "cb_mobs_animals:pitcher_pod"
A.TORCHFLOWER, A.PITCHER_PLANT = "cb_mobs_animals:torchflower", "cb_mobs_animals:pitcher_plant"
A.SNIFFER_EGG = "cb_mobs_animals:sniffer_egg_0"
local DIG_RANGE, EGG_TIME = 20, 1200
local DIG_ON = { "group:soil", "default:dirt", "default:dirt_with_grass", "default:dirt_with_rainforest_litter",
	"default:dirt_with_coniferous_litter", "default:dry_dirt", "default:dirt_with_dry_grass", "group:moss", }
local MOSS = { ["default:mossycobble"] = true, }

local function plant_box(h)
	return { type = "fixed", fixed = { -5 / 16, -0.5, -5 / 16, 5 / 16, -0.5 + h / 16, 5 / 16, }, }
end

-- the grown plants
core.register_node(A.TORCHFLOWER, {
	description = S("Torchflower"),
	drawtype = "plantlike", tiles = { "cb_mobs_animals_torchflower.png", },
	inventory_image = "cb_mobs_animals_torchflower.png", wield_image = "cb_mobs_animals_torchflower.png",
	paramtype = "light", sunlight_propagates = true, walkable = false, buildable_to = true,
	selection_box = plant_box(11),
	groups = { snappy = 3, flower = 1, flora = 1, attached_node = 1, color_orange = 1, flammable = 1, },
	sounds = default.node_sound_leaves_defaults(),
})
core.register_node(A.PITCHER_PLANT, {
	description = S("Pitcher Plant"),
	drawtype = "plantlike", tiles = { "cb_mobs_animals_pitcher_plant_top.png", }, visual_scale = 1.4,
	inventory_image = "cb_mobs_animals_pitcher_plant_top.png", wield_image = "cb_mobs_animals_pitcher_plant_top.png",
	paramtype = "light", sunlight_propagates = true, walkable = false, buildable_to = true,
	selection_box = plant_box(14),
	groups = { snappy = 3, flower = 1, flora = 1, attached_node = 1, color_cyan = 1, flammable = 1, },
	sounds = default.node_sound_leaves_defaults(),
})

-- the crops: torchflower 2 stages, pitcher 4, then the plant
local CROPS = {}
local function register_crops(kind, stages, seed, grown)
	local names = {}
	for i = 0, stages - 1 do
		names[#names + 1] = "cb_mobs_animals:" .. kind .. "_crop_" .. i
	end
	for i, name in ipairs(names) do
		core.register_node(name, {
			description = S("Ancient Crop"),
			drawtype = "plantlike", tiles = { "cb_mobs_animals_" .. kind .. "_crop_" .. (i - 1) .. ".png", },
			paramtype = "light", sunlight_propagates = true, walkable = false, buildable_to = true,
			selection_box = plant_box(3 + i * 3), drop = seed,
			groups = { snappy = 3, attached_node = 1, not_in_creative_inventory = 1, cb_ancient_crop = 1, },
			sounds = default.node_sound_leaves_defaults(),
		})
		CROPS[name] = names[i + 1] or grown
	end
	return names[1]
end
local TORCH_CROP = register_crops("torchflower", 2, A.TORCHFLOWER_SEEDS, A.TORCHFLOWER)
local PITCHER_CROP = register_crops("pitcher", 4, A.PITCHER_POD, A.PITCHER_PLANT)

-- One growth step of an ancient crop (from the ABM).
function A.crop_grow(pos)
	local next = CROPS[core.get_node(pos).name]
	if next then
		core.swap_node(pos, { name = next, })
	end
	return next
end

core.register_abm({
	label = "cb_mobs_animals ancient crops", nodenames = { "group:cb_ancient_crop", },
	interval = 60, chance = 8, catch_up = false,
	action = function(pos)
		if (core.get_node_light(pos) or 0) >= 9 then
			A.crop_grow(pos)
		end
	end,
})

local function seed_item(name, desc, image, crop)
	core.register_craftitem(name, {
		description = desc, inventory_image = image,
		on_place = function(stack, placer, pointed)
			if not pointed or pointed.type ~= "node" then
				return stack
			end
			local soil, at = pointed.under, pointed.above
			if core.get_item_group(core.get_node(soil).name, "soil") == 0 or core.get_node(at).name ~= "air"
				or core.is_protected(at, placer and placer:get_player_name() or "") then
				return stack
			end
			core.set_node(at, { name = crop, })
			if not (placer and core.is_creative_enabled(placer:get_player_name())) then
				stack:take_item()
			end
			return stack
		end,
	})
end
seed_item(A.TORCHFLOWER_SEEDS, S("Torchflower Seeds"), "cb_mobs_animals_torchflower_seeds.png", TORCH_CROP)
seed_item(A.PITCHER_POD, S("Pitcher Pod"), "cb_mobs_animals_pitcher_pod.png", PITCHER_CROP)

-- A spot to dig: diggable ground with air above, within reach.
function A.sniffer_spot(self)
	local pos = vector.round(self.object:get_pos())
	local r = vector.new(DIG_RANGE, 3, DIG_RANGE)
	local spots = core.find_nodes_in_area_under_air(vector.subtract(pos, r), vector.add(pos, r), DIG_ON)
	if #spots == 0 then
		return nil
	end
	return spots[math.random(#spots)]
end

function A.sniffer_dig_done(self, spot)
	local find = math.random(2) == 1 and A.TORCHFLOWER_SEEDS or A.PITCHER_POD
	core.add_item(vector.offset(spot, 0, 1, 0), find)
	self._dig, self._dig_cd = nil, 400 + math.random() * 100
	self:set_animation("stand", true)
	return find
end

function A.sniffer_tick(self, dtime)
	if self.child then
		return true
	end
	local d = self._dig
	if not d then
		self._dig_cd = (self._dig_cd or 400 + math.random() * 100) - dtime
		if self._dig_cd > 0 or self.state == "attack" or self.following then
			return true
		end
		local spot = A.sniffer_spot(self)
		if not spot then
			self._dig_cd = 60
			return true
		end
		self._dig = { pos = spot, phase = "walk", t = 0, }
		return true
	end
	d.t = d.t + dtime
	local pos = self.object:get_pos()
	if d.phase == "walk" then
		local flat = vector.new(d.pos.x - pos.x, 0, d.pos.z - pos.z)
		if vector.length(flat) <= 1.5 then
			d.phase, d.t = "sniff", 0
			self:set_velocity(0)
			self:set_animation("sniff", true)
		elseif d.t > 30 then
			self._dig, self._dig_cd = nil, 60
			return true
		else
			self:yaw_to_pos(d.pos)
			self:set_velocity(self.walk_velocity)
			self:set_animation("walk")
		end
		return false
	end
	local v = self.object:get_velocity() or vector.zero()
	self.object:set_velocity({ x = 0, y = v.y, z = 0, })
	if d.phase == "sniff" and d.t >= 1.5 then
		d.phase, d.t, d.len = "dig", 0, 8 + math.random() * 2
		self:set_animation("dig", true)
	elseif d.phase == "dig" and d.t >= d.len then
		A.sniffer_dig_done(self, d.pos)
	end
	return false
end

local function egg_time(pos)
	local below = core.get_node(vector.offset(pos, 0, -1, 0)).name
	local t = EGG_TIME / 3
	if MOSS[below] or core.get_item_group(below, "moss") > 0 then
		t = t / 2
	end
	return t * (0.9 + math.random() * 0.2)
end

-- The last crack: the egg gives way to a young sniffer.
function A.egg_hatch(pos)
	core.remove_node(pos)
	core.sound_play("default_break_glass", { pos = pos, gain = 0.5, pitch = 0.8, }, true)
	return A.spawn_young(pos, A.SNIFFER)
end

for stage = 0, 2 do
	core.register_node("cb_mobs_animals:sniffer_egg_" .. stage, {
		description = S("Sniffer Egg"),
		drawtype = "nodebox", paramtype = "light",
		tiles = { "cb_mobs_animals_sniffer_egg_" .. stage .. ".png", },
		inventory_image = "cb_mobs_animals_sniffer_egg_item.png", wield_image = "cb_mobs_animals_sniffer_egg_item.png",
		node_box = { type = "fixed", fixed = { -7 / 16, -0.5, -5 / 16, 7 / 16, 0.5, 5 / 16, }, },
		groups = { cracky = 3, oddly_breakable_by_hand = 2, not_in_creative_inventory = stage == 0 and 0 or 1, },
		drop = A.SNIFFER_EGG,
		sounds = default.node_sound_stone_defaults(),
		on_construct = function(pos)
			core.get_node_timer(pos):start(egg_time(pos))
		end,
		on_timer = function(pos)
			if stage < 2 then
				core.swap_node(pos, { name = "cb_mobs_animals:sniffer_egg_" .. (stage + 1), })
				core.sound_play("default_dig_cracky", { pos = pos, gain = 0.5, pitch = 1.5, }, true)
				core.get_node_timer(pos):start(egg_time(pos))
			else
				A.egg_hatch(pos)
			end
			return false
		end,
	})
end

-- A pair in love lays an egg next to the mother.
function A.lay_egg(self)
	local pos = vector.round(self.object:get_pos())
	for _, p in ipairs({ pos, vector.offset(pos, 1, 0, 0), vector.offset(pos, -1, 0, 0), vector.offset(pos, 0, 0, 1),
		vector.offset(pos, 0, 0, -1), }) do
		local below = core.registered_nodes[core.get_node(vector.offset(p, 0, -1, 0)).name]
		if core.get_node(p).name == "air" and below and below.walkable then
			core.set_node(p, { name = A.SNIFFER_EGG, })
			return p
		end
	end
end

mobs:register_mob(A.SNIFFER, {
	type = "animal", passive = true, hp_min = 14, hp_max = 14, armor = 100,
	collisionbox = { -0.95, 0, -0.95, 0.95, 1.75, 0.95, },
	visual = "mesh", mesh = "cb_mobs_animals_sniffer.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_animals_sniffer.png", }, },
	makes_footstep_sound = true, walk_velocity = 0.8, run_velocity = 1.6, jump = true, view_range = 8,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = true,
	sounds = { random = "cb_mobs_animals_bear_random", damage = "cb_mobs_animals_bear_hurt",
		death = "cb_mobs_animals_bear_death", distance = 16, },
	animation = { speed_normal = 25, stand_start = 0, stand_end = 0, walk_start = 1, walk_end = 41,
		run_start = 1, run_end = 41, run_speed = 45, sniff_start = 42, sniff_end = 72, sniff_speed = 30,
		sniff_loop = false, dig_start = 73, dig_end = 113, dig_speed = 30, },
	follow = { A.TORCHFLOWER_SEEDS, },
	do_custom = function(self, dtime)
		return A.sniffer_tick(self, dtime)
	end,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() then
			mobs:feed_tame(self, clicker, 1, true, false)
		end
	end,
	on_breed = function(self)
		A.lay_egg(self)
		return false
	end,
})
mobs:register_egg(A.SNIFFER, S("Sniffer"), "cb_mobs_animals_sniffer_egg_item.png", 1)
