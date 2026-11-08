-- Infested blocks (spec cycle 4, 8a): look like their stone, break fast, drop
-- nothing and release a silverfish (cb_mobs_overworld) when dug or blown up.
local S = cb_blocks.S
cb_blocks.INFESTED = {}
cb_blocks.infested_hooks = {} -- fn(pos) when one breaks

local function release(pos)
	for _, fn in ipairs(cb_blocks.infested_hooks) do
		fn(pos)
	end
end

local function infest(suffix, base)
	local def = core.registered_nodes[base]
	if not def then
		return
	end
	local name = "cb_blocks:infested_" .. suffix
	cb_blocks.INFESTED[name] = base
	core.register_node(name, {
		description = S("Infested @1", def.description or base),
		tiles = def.tiles, groups = { cracky = 3, not_in_creative_inventory = 1, infested = 1, },
		drop = "", is_ground_content = true, sounds = def.sounds,
		after_dig_node = function(pos)
			release(pos)
		end,
		on_blast = function(pos)
			core.remove_node(pos)
			release(pos)
		end,
	})
end

infest("stone", "default:stone")
infest("cobble", "default:cobble")
infest("stonebrick", "default:stonebrick")
infest("mossy_stonebrick", cb_core.equiv("mossy_stone_bricks"))
infest("cracked_stonebrick", cb_core.equiv("cracked_stone_bricks"))

-- mountains: a little infested stone in high stone (new chunks only)
core.register_ore({
	ore_type = "scatter", ore = "cb_blocks:infested_stone", wherein = "default:stone",
	clust_scarcity = 24 * 24 * 24, clust_num_ores = 3, clust_size = 2, y_min = 30, y_max = 31000,
})
