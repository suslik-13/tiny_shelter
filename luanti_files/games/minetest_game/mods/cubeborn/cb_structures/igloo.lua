-- Igloo (spec cycle 2, 4.6): Mineclonia's three templates. Half of them
-- have a basement down a ladder shaft (4-11 segments) with a chest and two
-- cells: a villager and a zombie villager, spawned once at build time.
local S = cb_structures.S
local T = cb_structures.templates
local A = cb_structures.piecegen
local IG = {}
cb_structures.igloo = IG

T.MAP["mcl_core:snowblock"] = "default:snowblock"
T.MAP["mcl_core:packed_ice"] = "default:ice"
T.MAP["mcl_beds:bed_red_bottom"] = "beds:bed_bottom"
T.MAP["mcl_beds:bed_red_top"] = "beds:bed_top"
T.MAP["mcl_crafting_table:crafting_table"] = A.first("xdecor:workbench", "default:wood")
T.MAP["mcl_doors:trapdoor_oak"] = A.first("doors:trapdoor", "air")
T.MAP["mcl_furnaces:furnace"] = "default:furnace"
T.MAP["mcl_redstone_torch:redstone_torch_on_wall"] = "default:torch_wall"
T.MAP["mcl_core:stonebrick"] = "default:stonebrick"
T.MAP["mcl_core:stone"] = "default:stone"
T.MAP["mcl_core:stone_smooth"] = "default:stone_block"
T.MAP["mcl_core:stonebrickcarved"] = "default:stone_block"
T.MAP["mcl_core:stonebrickcracked"] = A.first("cb_blocks:cracked_stone_bricks", "default:stonebrick")
T.MAP["mcl_core:stonebrickmossy"] = cb_core.equiv("mossy_stone_bricks")
T.MAP["mcl_monster_eggs:monster_egg_stonebrick"] = "default:stonebrick"
T.MAP["mcl_monster_eggs:monster_egg_stonebrickcracked"] = A.first("cb_blocks:cracked_stone_bricks", "default:stonebrick")
T.MAP["mcl_stairs:slab_stonebrickcracked"] = "stairs:slab_stonebrick"
T.MAP["mcl_stairs:slab_stonebrickmossy"] = "stairs:slab_stonebrick"
T.MAP["mcl_stairs:slab_stonebrick_top"] = { "stairs:slab_stonebrick", 20, }
T.MAP["mcl_stairs:stair_stonebrick"] = "stairs:stair_stonebrick"
T.MAP["mcl_core:cobweb"] = cb_core.equiv("cobweb")
T.MAP["mcl_panes:bar_flat"] = A.first("xpanes:bar_flat", "default:fence_wood")
T.MAP["mcl_signs:wall_sign_oak"] = A.first("default:sign_wall_wood", "air")
T.MAP["mcl_torches:torch_wall"] = "default:torch_wall"
T.MAP["mcl_cauldrons:cauldron_3"] = cb_core.equiv("village_cauldron")
T.map_prefix("mcl_wool:", "air")
T.map_prefix("mcl_flowerpots:", "air")
T.map_prefix("mcl_brewing:", "air")

local DIR = core.get_modpath("cb_structures") .. "/templates/"
IG.TOP, IG.MIDDLE, IG.BOTTOM = T.load(DIR .. "igloo_top.dat"), T.load(DIR .. "igloo_middle.dat"),
	T.load(DIR .. "igloo_bottom.dat")
-- Shaft columns (Mineclonia): the templates turn around them.
local SHAFT = { top = { 3, 6, }, middle = { 1, 1, }, bottom = { 3, 7, }, }
local ENTITIES = {
	["mobs_mc:villager"] = "cb_mobs_village:villager",
	["mobs_mc:villager_zombie"] = "cb_mobs_village:zombie_villager",
	["mobs_mc:zombie_villager"] = "cb_mobs_village:zombie_villager",
}

function IG.plan(origin, seed)
	local rng = PcgRandom(seed)
	local k = rng:next(0, 3)
	local basement = rng:next(0, 1) == 0
	local segments = rng:next(4, 11)
	local y, x1, z1 = cb_structures.surface.site(origin, IG.TOP.w, IG.TOP.l, IG.TOP.h, { max_drop = 4, below = 2, })
	if not y then
		return nil, x1
	end
	return { x = x1, y = y, z = z1, k = k, basement = basement, segments = segments, }
end

-- tpl turned by k around its shaft column, the shaft over level (sx, sz).
local function at(tpl, shaft, sx, y, sz, k)
	local rx, _, rz = T.transform(shaft[1], 0, shaft[2], k)
	return sx - rx, y, sz - rz
end

function IG.layout(origin, seed, plan)
	-- level coordinates: anchor = plan corner; the top's shaft at level (3, 6)
	local anchor = vector.new(plan.x, plan.y, plan.z + IG.TOP.l - 1)
	local sx, sz = SHAFT.top[1], SHAFT.top[2]
	local parts = { { IG.TOP, SHAFT.top, 0, }, }
	if plan.basement then
		local h = IG.MIDDLE.h
		local lab_y = -plan.segments * h - IG.BOTTOM.h
		parts[#parts + 1] = { IG.BOTTOM, SHAFT.bottom, lab_y, }
		for i = 0, plan.segments - 1 do
			parts[#parts + 1] = { IG.MIDDLE, SHAFT.middle, lab_y + IG.BOTTOM.h + i * h, }
		end
	end
	local pieces, lo, hi = {}, nil, nil
	for _, p in ipairs(parts) do
		local tpl, shaft, y = p[1], p[2], p[3]
		local x, ly, z = at(tpl, shaft, sx, y, sz, plan.k)
		local bb = T.bbox(tpl, x, ly, z, plan.k)
		local a = vector.new(anchor.x + bb[1], anchor.y + bb[2], anchor.z - bb[6])
		local b = vector.new(anchor.x + bb[4], anchor.y + bb[5], anchor.z - bb[3])
		pieces[#pieces + 1] = { minp = a, maxp = b, build = function(ctx)
			local actions = T.place(ctx, tpl, anchor, x, ly, z, plan.k, { loot = "igloo_chest", all_chests = true, })
			ctx.after(function()
				for _, act in ipairs(actions) do
					local name = act.kind == "entity" and ENTITIES[act.what]
					if name and core.registered_entities[name] then
						core.add_entity(act.pos, name)
					end
				end
			end)
		end, }
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or vector.copy(a)
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or vector.copy(b)
	end
	return { minp = lo, maxp = hi, pieces = pieces, }
end

cb_structures.register("igloo", {
	description = S("Igloo"),
	dims = { "overworld", },
	biome_words = { "snowy", "tundra", "icesheet", "glacier", "frost", "taiga", },
	prepare = { radius = 48, below = 24, above = 40, },
	plan = IG.plan,
	layout = IG.layout,
})
