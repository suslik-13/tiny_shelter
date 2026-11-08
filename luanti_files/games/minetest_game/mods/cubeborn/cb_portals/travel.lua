-- Travel through Nether portals between the overworld and the Nether pocket:
-- x/z scale = world width / pocket width, linking through the registry, a new
-- portal where none is near, and the stand-in-portal / cooldown timer.
local S = cb_portals.S
local NODE = cb_portals.NODE
local OBSIDIAN = cb_core.equiv("obsidian")
local along = cb_portals.along
local AIR = core.CONTENT_AIR

cb_portals.STAND, cb_portals.COOLDOWN = 4, 3
local TICK = 0.5
local LINK_NETHER, LINK_OVERWORLD, SEARCH, MAX_CHECKS = 16, 128, 16, 6
local ENTRY = "cb_portals:entry"

function cb_portals.scale(pocket)
	local e0, e1 = core.get_mapgen_edges()
	local ia, ib = cb_dimensions.inner(pocket)
	return (e1.x - e0.x + 1) / (ib.x - ia.x + 1)
end

local function centre(pocket)
	local ia, ib = cb_dimensions.inner(pocket)
	return math.floor((ia.x + ib.x) / 2), math.floor((ia.z + ib.z) / 2)
end

local function clamp(v, a, b)
	return math.max(a, math.min(b, v))
end

function cb_portals.to_nether(pos, pocket)
	local ia, ib = cb_dimensions.inner(pocket)
	local s = cb_portals.scale(pocket)
	local cx, cz = centre(pocket)
	return vector.new(clamp(cx + math.floor(pos.x / s), ia.x + 8, ib.x - 8), ia.y,
		clamp(cz + math.floor(pos.z / s), ia.z + 8, ib.z - 8))
end

function cb_portals.to_overworld(pos, pocket)
	local e0, e1 = core.get_mapgen_edges()
	local s = cb_portals.scale(pocket)
	local cx, cz = centre(pocket)
	return vector.new(clamp(math.floor((pos.x - cx) * s), e0.x + 16, e1.x - 16), 0,
		clamp(math.floor((pos.z - cz) * s), e0.z + 16, e1.z - 16))
end

function cb_portals.build(pos, axis, dim)
	local side = axis == "x" and "z" or "x"
	core.load_area(vector.offset(pos, -2, -2, -2), vector.offset(pos, 3, 5, 3))
	for i = -1, 2 do
		for j = -1, 3 do
			for k = -1, 1 do
				local p = along(along(vector.offset(pos, 0, j, 0), axis, i), side, k)
				if j == -1 or (k == 0 and (i == -1 or i == 2 or j == 3)) then
					core.set_node(p, { name = OBSIDIAN, })
				elseif k ~= 0 then
					core.set_node(p, { name = "air", })
				end
			end
		end
	end
	return cb_portals.activate({ pos = vector.copy(pos), axis = axis, w = 2, h = 3, }, dim)
end

local solid_cache = {}
local function is_solid(id)
	local v = solid_cache[id]
	if v == nil then
		local def = core.registered_nodes[core.get_name_from_content_id(id)]
		v = def ~= nil and def.walkable ~= false and (def.liquidtype or "none") == "none"
		solid_cache[id] = v
	end
	return v
end

-- Whether the 4x4 footprint x-1..x+2, z-1..z+2 has 4 rows of air from y up
-- and solid ground in row y - 1.
local function free(data, va, x, y, z)
	for dx = -1, 2 do
		for dz = -1, 2 do
			if not is_solid(data[va:index(x + dx, y - 1, z + dz)]) then
				return false
			end
			for dy = 0, 3 do
				if data[va:index(x + dx, y + dy, z + dz)] ~= AIR then
					return false
				end
			end
		end
	end
	return true
end

-- The box a portal at `spot` occupies, floor and clearance included.
local function portal_box(spot)
	return vector.offset(spot, -1, -1, -1), vector.offset(spot, 2, 3, 2)
end

local function placeable(spot)
	local a, b = portal_box(spot)
	return cb_core.check_area_now(a, b).ok
end

-- Columns around a target, nearest first, every `step` nodes up to `radius`.
local function columns(target, radius, step)
	local list = {}
	for dx = -radius, radius, step do
		for dz = -radius, radius, step do
			list[#list + 1] = { x = target.x + dx, z = target.z + dz, d = dx * dx + dz * dz, }
		end
	end
	table.sort(list, function(a, b)
		return a.d < b.d
	end)
	return list
end

-- A place for a portal in the Nether near `target`, column by column from the
-- target outwards: the lowest open spot above the lava sea, else a spot just
-- above the lava sea to carve out. The portal box must hold only natural,
-- unprotected nodes. nil if no column within SEARCH nodes has one.
function cb_portals.nether_spot(target, pocket)
	local ia, ib = cb_dimensions.inner(pocket)
	local lava = ia.y + cb_dimensions.nether.LAVA_LEVEL
	local list = {}
	for _, c in ipairs(columns(target, SEARCH, 2)) do
		if c.x - 1 >= ia.x and c.x + 2 <= ib.x and c.z - 1 >= ia.z and c.z + 2 <= ib.z then
			list[#list + 1] = c
		end
	end
	local lo = vector.new(target.x - SEARCH - 1, lava, target.z - SEARCH - 1)
	local hi = vector.new(target.x + SEARCH + 2, ib.y - 4, target.z + SEARCH + 2)
	lo, hi = cb_core.intersect(lo, hi, ia, ib)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(lo, hi)
	local va, data = VoxelArea(e1, e2), vm:get_data()
	for _, c in ipairs(list) do
		for y = lava + 1, ib.y - 8 do
			if free(data, va, c.x, y, c.z) and placeable(vector.new(c.x, y, c.z)) then
				return vector.new(c.x, y, c.z)
			end
		end
		local spot = vector.new(c.x, lava + 2, c.z)
		if placeable(spot) then
			return spot
		end
	end
end

function cb_portals.overworld_spot(target, cb)
	local y0 = core.get_spawn_level(target.x, target.z) or 8
	local lo = vector.new(target.x - SEARCH - 1, y0 - 24, target.z - SEARCH - 1)
	local hi = vector.new(target.x + SEARCH + 2, y0 + 40, target.z + SEARCH + 2)
	core.emerge_area(lo, hi, function(_, _, remaining)
		if remaining > 0 then
			return
		end
		local vm = core.get_voxel_manip()
		local e1, e2 = vm:read_from_map(lo, hi)
		local va, data = VoxelArea(e1, e2), vm:get_data()
		local checks = 0
		for _, c in ipairs(columns(target, SEARCH, 4)) do
			for y = hi.y - 4, lo.y + 1, -1 do
				if free(data, va, c.x, y, c.z) then
					checks = checks + 1
					local spot = vector.new(c.x, y, c.z)
					if placeable(spot) then
						return cb(spot)
					end
					break
				end
			end
			if checks >= MAX_CHECKS then
				break
			end
		end
		cb(nil)
	end)
end

function cb_portals.travel(player, from, done)
	local name = player:get_player_name()
	local pocket = cb_dimensions.get("nether")
	if not pocket or pocket.state ~= "ready" then
		core.chat_send_player(name, S("The Nether is not open yet."))
		return done(nil)
	end
	local src = cb_portals.covering(from) or cb_portals.covering(vector.offset(from, 0, 1, 0))
	if src and not cb_portals.frame_intact(src) then
		cb_portals.deactivate(src)
		return done(nil)
	end
	local axis = src and src.axis or "x"
	-- Still online, alive and in the portal: a search may finish much later.
	local function present()
		local pos = player:get_pos()
		return pos ~= nil and player:get_hp() > 0 and vector.distance(pos, from) <= 3
	end
	local function go(dest)
		if not present() then
			return done(nil)
		end
		cb_portals.teleport(player, vector.offset(dest, 0, -0.5, 0))
		done(dest)
	end
	if cb_portals.dim_at(from) ~= "nether" then
		local target = cb_portals.to_nether(from, pocket)
		local p = cb_portals.nearest("nether", target, LINK_NETHER)
		if not p then
			local spot = cb_portals.nether_spot(target, pocket)
			if not spot then
				core.chat_send_player(name, S("There is no room for a portal on the other side."))
				return done(nil)
			end
			p = cb_portals.build(spot, axis, "nether")
		end
		player:get_meta():set_string(ENTRY, core.pos_to_string(src and src.pos or from))
		return go(p.pos)
	end
	local target = cb_portals.to_overworld(from, pocket)
	local p = cb_portals.nearest("overworld", target, LINK_OVERWORLD)
	if p then
		return go(p.pos)
	end
	cb_portals.overworld_spot(target, function(spot)
		if not present() then
			return done(nil)
		end
		if spot then
			return go(cb_portals.build(spot, axis, "overworld").pos)
		end
		local entry = core.string_to_pos(player:get_meta():get_string(ENTRY))
		if entry and cb_portals.covering(entry) then
			return go(entry)
		end
		go(cb_portals.respawn_pos(name))
	end)
end

local players = {}

function cb_portals.player_state(name)
	return players[name]
end

function cb_portals.tick_player(player, dtime)
	local name = player:get_player_name()
	local st = players[name]
	if not st then
		st = { t = 0, cooldown = 0, busy = false, }
		players[name] = st
	end
	if st.busy then
		return
	end
	if st.cooldown > 0 then
		st.cooldown = st.cooldown - dtime
		return
	end
	local pos = player:get_pos()
	if not pos then
		return
	end
	local feet = vector.round(pos)
	if core.get_node(feet).name ~= NODE and core.get_node(vector.offset(feet, 0, 1, 0)).name ~= NODE then
		st.t = 0
		return
	end
	st.t = st.t + dtime
	if st.t < cb_portals.STAND then
		return
	end
	st.t, st.busy = 0, true
	cb_portals.travel(player, feet, function()
		st.busy = false
		st.cooldown = cb_portals.COOLDOWN
	end)
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < TICK then
		return
	end
	local dt = timer
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		cb_portals.tick_player(player, dt)
	end
end)

core.register_on_leaveplayer(function(player)
	players[player:get_player_name()] = nil
end)
