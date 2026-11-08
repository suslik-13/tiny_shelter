-- Nodes the map generator places on its own. Area checks treat every other
-- node as a sign of a player build. is_ground_content is useless here: it
-- defaults to true for every node.
local extra = { world = {}, pocket = {}, }
cb_core.NATURAL_MODS = "caverealms,riesenpilz,moretrees,spawners_env,tac_nayn"
-- placed by the nether mod's own generator (mantle, geodes, the dark cave
-- air): no biome or decoration names them
local MAPGEN_NODES = {
	"nether:airlike_darkness", "nether:native_mapgen", "nether:basalt", "nether:geode", "nether:geodelite",
	"nether:lava_crust", "nether:rack", "nether:rack_deep", "nether:glowstone", "nether:glowstone_deep",
	"nether:sand", "nether:fumarole", "nether:fumarole_slab", "nether:fumarole_corner",
}

local BIOME_FIELDS = {
	"node_top", "node_filler", "node_stone", "node_water_top", "node_water",
	"node_river_water", "node_riverbed", "node_cave_liquid", "node_dungeon",
	"node_dungeon_alt", "node_dungeon_stair", "node_dust",
}

-- scope "pocket": natural only inside dimension pockets (blocks their
-- generators place); nil or "world": natural everywhere.
function cb_core.register_natural(name, scope)
	extra[scope == "pocket" and "pocket" or "world"][name] = true
	cb_core._natural = nil
end

-- Which natural set applies to a box. cb_dimensions replaces this so that
-- boxes touching a pocket use the "pocket" set.
function cb_core.natural_scope()
	return "world"
end

local function add(set, name)
	if type(name) == "table" then
		for _, n in ipairs(name) do
			add(set, n)
		end
		return
	end
	if type(name) ~= "string" then
		return
	end
	name = core.registered_aliases[name] or name
	if core.registered_nodes[name] then
		set[core.get_content_id(name)] = true
	end
end

local function build_world()
	local set = { [core.CONTENT_AIR] = true, [core.CONTENT_IGNORE] = true, }
	for _, biome in pairs(core.registered_biomes) do
		for _, field in ipairs(BIOME_FIELDS) do
			add(set, biome[field])
		end
	end
	for _, ore in pairs(core.registered_ores) do
		add(set, ore.ore)
		add(set, ore.wherein)
	end
	-- trees of schematic decorations (ethereal, x_farming, aspens): only the
	-- default ones have mapgen_* aliases
	local read = {}
	for _, deco in pairs(core.registered_decorations) do
		if deco.deco_type == "simple" then
			add(set, deco.decoration)
		elseif deco.deco_type == "schematic" and deco.schematic and not read[deco.schematic] then
			read[deco.schematic] = true
			-- read_schematic gives nil for Lua table schematics (ethereal, nether)
			local ok, schem = true, deco.schematic
			if type(schem) ~= "table" then
				ok, schem = pcall(core.read_schematic, schem, {})
			end
			for _, n in ipairs(ok and type(schem) == "table" and schem.data or {}) do
				local def = core.registered_nodes[n.name]
				-- a chest or furnace in a decoration is still a sign of a player
				if def and not def.on_rightclick and not def.on_metadata_inventory_put then
					add(set, n.name)
				end
			end
		end
		add(set, deco.place_on)
	end
	for alias in pairs(core.registered_aliases) do
		if alias:sub(1, 7) == "mapgen_" then
			add(set, alias)
		end
	end
	for name, def in pairs(core.registered_nodes) do
		if def.liquidtype and def.liquidtype ~= "none" then
			add(set, name)
		end
	end
	add(set, MAPGEN_NODES)
	for name in pairs(extra.world) do
		add(set, name)
	end
	for name in cb_core.setting("cubeborn.natural_extra", ""):gmatch("[^,%s]+") do
		add(set, name)
	end
	-- mods that generate their own terrain in on_generated (caverealms fills
	-- the deep underground of survival SHELTER, riesenpilz grows giant
	-- mushrooms): all their nodes count as natural
	local mods = {}
	for mod in cb_core.setting("cubeborn.natural_mods", cb_core.NATURAL_MODS):gmatch("[^,%s]+") do
		mods[mod] = true
	end
	for name in pairs(core.registered_nodes) do
		if mods[name:match("^([^:]+):") or ""] then
			add(set, name)
		end
	end
	return set
end

-- Set of natural content ids for `scope` ("world" by default, or "pocket").
function cb_core.natural_cids(scope)
	if not cb_core._natural then
		local world = build_world()
		local pocket = table.copy(world)
		for name in pairs(extra.pocket) do
			add(pocket, name)
		end
		cb_core._natural = { world = world, pocket = pocket, }
	end
	return cb_core._natural[scope == "pocket" and "pocket" or "world"]
end
