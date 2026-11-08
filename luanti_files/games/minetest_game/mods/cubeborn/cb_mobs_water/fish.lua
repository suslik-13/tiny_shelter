-- Cod and salmon (spec cycle 4, 8c): schools that flee from players. A water
-- bucket takes one; they drop raw fish (ethereal's, when there) and now and
-- then a bone. Cod live in seas, salmon in cold waters and rivers.
local S = cb_mobs_water.S
local W = cb_mobs_water
local A = rawget(_G, "cb_mobs_animals")
W.COD, W.SALMON = "cb_mobs_water:cod", "cb_mobs_water:salmon"
W.COD_BUCKET, W.SALMON_BUCKET = "cb_mobs_water:cod_bucket", "cb_mobs_water:salmon_bucket"

local function drops(fish)
	local out = {}
	if core.registered_items[fish] then
		out[#out + 1] = { name = fish, chance = 1, min = 1, max = 1, }
	end
	if core.registered_items["bonemeal:bone"] then
		out[#out + 1] = { name = "bonemeal:bone", chance = 20, min = 1, max = 1, }
	end
	return out
end

local function register(name, desc, mesh, tex, box, rotate, fish, bucket, bucket_img)
	mobs:register_mob(name, {
		type = "animal", passive = true, hp_min = 3, hp_max = 3, armor = 100, rotate = rotate,
		collisionbox = box,
		visual = "mesh", mesh = mesh, visual_size = { x = 3, y = 3, },
		textures = { { tex, }, },
		fly = true, fly_in = W.WATER, walk_velocity = 1, run_velocity = 2.5, jump = false, view_range = 8,
		runaway_from = { "player", },
		water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
		drops = drops(fish),
		sounds = { damage = "cb_mobs_water_fish_flop", death = "cb_mobs_water_fish_flop", distance = 8, },
		animation = { speed_normal = 20, stand_start = 1, stand_end = 20, walk_start = 1, walk_end = 20,
			run_start = 1, run_end = 20, fly_start = 1, fly_end = 20, },
		on_flop = W.choke,
		on_rightclick = function(self, clicker)
			if A and clicker and clicker:is_player() then
				A.bucket_mob(self, clicker, bucket, {})
			end
		end,
	})
	mobs:register_egg(name, desc, tex, 1)
	if A then
		A.register_mob_bucket(bucket, { description = S("Bucket of @1", desc), image = bucket_img, mob = name, })
	end
end
register(W.COD, S("Cod"), "cb_mobs_water_cod.b3d", "cb_mobs_water_cod.png", { -0.3, 0, -0.3, 0.3, 0.79, 0.3, },
	180, "ethereal:fish_cod", W.COD_BUCKET, "cb_mobs_water_cod_bucket.png")
register(W.SALMON, S("Salmon"), "cb_mobs_water_salmon.b3d", "cb_mobs_water_salmon.png",
	{ -0.35, 0, -0.35, 0.35, 0.4, 0.35, }, 0, "ethereal:fish_salmon", W.SALMON_BUCKET, "cb_mobs_water_salmon_bucket.png")
