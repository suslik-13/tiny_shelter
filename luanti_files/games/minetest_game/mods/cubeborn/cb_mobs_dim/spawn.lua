-- Natural enderman spawning with mobs:spawn (mobs_redo ABMs): rare on the
-- overworld surface at night, rarer in the Nether, often in the End. Pockets
-- are made at run time, so the ABM height ranges are wide and one wrapper of
-- mobs:spawn_abm_check decides from the position which dimension it is and
-- whether the node fits it (a few comparisons, no map scans).
local NAME = "cb_mobs_dim:enderman"
local MAX_Y = cb_dimensions and cb_dimensions.MAX_Y
	or tonumber(cb_core.setting("cubeborn.pocket_max_y", "-1500")) or -1500
local SURFACE_LIGHT = 10 -- natural light at noon above the ground: open sky

local external_nether = cb_core.profile.nether == "external" and rawget(_G, "nether")
if external_nether and not (external_nether.DEPTH_FLOOR and external_nether.DEPTH_CEILING) then
	external_nether = nil
end

local OVERWORLD_NODES = { "group:soil", "group:sand", "default:gravel", "default:snowblock", }
local NETHER_NODES = {}
if cb_core.profile.nether ~= "off" then
	local seen = {}
	for _, name in ipairs({ cb_core.equiv("netherrack"), "nether:rack_deep", "nether:sand", "cb_blocks:soul_sand",
		"cb_blocks:crimson_nylium", "cb_blocks:warped_nylium", }) do
		if core.registered_nodes[name] and not seen[name] then
			seen[name] = true
			NETHER_NODES[#NETHER_NODES + 1] = name
		end
	end
end
local END_NODES = { "cb_blocks:end_stone", }

local function set_of(list)
	local set = {}
	for _, n in ipairs(list) do
		set[n] = true
	end
	return set
end
local nether_set, end_set = set_of(NETHER_NODES), set_of(END_NODES)

local function overworld_node(name)
	return core.get_item_group(name, "soil") > 0 or core.get_item_group(name, "sand") > 0
		or name == "default:gravel" or name == "default:snowblock"
end

-- "overworld", "nether", "end" or nil: see cb_spawning.dim_at.
function cb_mobs_dim.spawn_dim(pos)
	return cb_spawning.dim_at(pos)
end

-- pos is the ground node, the enderman would stand above it.
function cb_mobs_dim.enderman_spawn_ok(pos, node)
	local above = vector.offset(pos, 0, 1, 0)
	local dim = cb_mobs_dim.spawn_dim(above)
	if dim == "overworld" then
		return overworld_node(node.name) and (core.get_natural_light(above, 0.5) or 0) >= SURFACE_LIGHT
	elseif dim == "nether" then
		return nether_set[node.name] == true
	elseif dim == "end" then
		return end_set[node.name] == true
	end
	return false
end

local abm_check = mobs.spawn_abm_check
function mobs:spawn_abm_check(pos, node, name)
	if name == NAME and not cb_mobs_dim.enderman_spawn_ok(pos, node) then
		return true
	end
	return abm_check(self, pos, node, name)
end

mobs:spawn({
	name = NAME,
	nodes = OVERWORLD_NODES,
	neighbors = { "air", },
	max_light = 7,
	interval = 30,
	chance = 30000,
	active_object_count = 1,
	min_height = MAX_Y + 1,
	day_toggle = false,
})

if #NETHER_NODES > 0 then
	mobs:spawn({
		name = NAME,
		nodes = NETHER_NODES,
		neighbors = { "air", },
		-- no light limit: the lamps of Nether structures must not keep it away
		interval = 30,
		chance = 50000,
		active_object_count = 1,
		min_height = external_nether and external_nether.DEPTH_FLOOR or -31000,
		max_height = external_nether and external_nether.DEPTH_CEILING or MAX_Y,
	})
end

if cb_dimensions and cb_core.profile.end_dim and core.registered_nodes[END_NODES[1]] then
	mobs:spawn({
		name = NAME,
		nodes = END_NODES,
		neighbors = { "air", },
		interval = 30,
		chance = 4000,
		active_object_count = 3,
		min_height = -31000,
		max_height = MAX_Y,
	})
end
