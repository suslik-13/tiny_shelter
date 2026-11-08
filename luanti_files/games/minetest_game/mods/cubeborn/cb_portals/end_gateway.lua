-- End gateways: one more after every dragon death (up to 20) on a ring of
-- radius 96 around the main island. A gateway leads to the outer islands in its
-- direction and gets a return gateway there; the return one leads back onto
-- the main island.
local S = cb_portals.S
local the_end = cb_dimensions.the_end
local GATE = "cb_portals:end_gateway"
local MAX_GATES, RING, LIFT, SEARCH, BACK_D = 20, 96, 20, 32, 60
local TICK, COOLDOWN = 0.5, 3
local storage = core.get_mod_storage()

local gates = {}
for _, e in ipairs(core.deserialize(storage:get_string("end_gateways")) or {}) do
	e.a = vector.copy(e.a)
	e.b = e.b and vector.copy(e.b)
	e.land = e.land and vector.copy(e.land)
	gates[#gates + 1] = e
end

local function save()
	storage:set_string("end_gateways", core.serialize(gates))
end

core.register_node(GATE, {
	description = S("End Gateway"),
	drawtype = "glasslike",
	tiles = { "cb_portals_end_portal.png", },
	paramtype = "light",
	sunlight_propagates = true,
	light_source = core.LIGHT_MAX,
	walkable = false,
	pointable = false,
	diggable = false,
	is_ground_content = false,
	drop = "",
	groups = { not_in_creative_inventory = 1, },
	on_blast = function()
	end,
})

-- Gateways and their fallback platforms keep protected nodes.
local function put(pos, name)
	if not core.is_protected(pos, "") then
		core.set_node(pos, { name = name, })
	end
end

local function build(pos)
	core.load_area(vector.offset(pos, -1, -2, -1), vector.offset(pos, 1, 2, 1))
	put(vector.offset(pos, 0, -1, 0), "cb_blocks:end_bedrock")
	put(vector.offset(pos, 0, 1, 0), "cb_blocks:end_bedrock")
	put(pos, GATE)
end

function cb_portals.end_gateways()
	return gates
end

function cb_portals.end_gateway_spawn()
	local pocket = cb_dimensions.get("end")
	if not pocket or pocket.state ~= "ready" or #gates >= MAX_GATES then
		return nil
	end
	local g = the_end.geometry(pocket)
	local a = #gates * 2 * math.pi / MAX_GATES
	local pos = vector.new(g.centre.x + math.floor(RING * math.cos(a) + 0.5), g.centre.y + LIFT,
		g.centre.z + math.floor(RING * math.sin(a) + 0.5))
	build(pos)
	gates[#gates + 1] = { a = pos, }
	save()
	return pos
end

local STONE = "cb_blocks:end_stone"

function cb_portals.end_island_near(target, g)
	local lo = vector.new(target.x - SEARCH, g.centre.y - 48, target.z - SEARCH)
	local hi = vector.new(target.x + SEARCH, g.centre.y + 32, target.z + SEARCH)
	lo, hi = cb_core.intersect(lo, hi, vector.offset(g.ia, 3, 0, 3), vector.offset(g.ib, -3, -6, -3))
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(lo, hi)
	local va, data = VoxelArea(e1, e2), vm:get_data()
	local stone, air = core.get_content_id(STONE), core.CONTENT_AIR
	local cols = {}
	for x = lo.x, hi.x, 2 do
		for z = lo.z, hi.z, 2 do
			cols[#cols + 1] = { x = x, z = z, d = (x - target.x) ^ 2 + (z - target.z) ^ 2, }
		end
	end
	table.sort(cols, function(a, b)
		return a.d < b.d
	end)
	for _, c in ipairs(cols) do
		for y = hi.y - 2, lo.y, -1 do
			if data[va:index(c.x, y, c.z)] == stone and data[va:index(c.x, y + 1, c.z)] == air
					and data[va:index(c.x, y + 2, c.z)] == air then
				return vector.new(c.x, y + 1, c.z)
			end
		end
	end
	local p = vector.new(math.max(lo.x + 2, math.min(hi.x - 2, target.x)), g.centre.y,
		math.max(lo.z + 2, math.min(hi.z - 2, target.z)))
	core.load_area(vector.offset(p, -2, 0, -2), vector.offset(p, 2, 4, 2))
	for dx = -2, 2 do
		for dz = -2, 2 do
			put(vector.offset(p, dx, 0, dz), STONE)
			for dy = 1, 4 do
				put(vector.offset(p, dx, dy, dz), "air")
			end
		end
	end
	return vector.offset(p, 0, 1, 0)
end

local function direction(g, pos)
	local d = vector.new(pos.x - g.centre.x, 0, pos.z - g.centre.z)
	if vector.length(d) < 1 then
		return vector.new(1, 0, 0)
	end
	return vector.normalize(d)
end

local players = {}

function cb_portals.end_gateway_tick(player, dtime)
	local name = player:get_player_name()
	local st = players[name]
	if not st then
		st = { cooldown = 0, }
		players[name] = st
	end
	st.cooldown = st.cooldown - dtime
	if st.cooldown > 0 then
		return false
	end
	local pos = player:get_pos()
	if not pos or player:get_hp() <= 0 then
		return false
	end
	local feet = cb_blocks.node_at(pos)
	local at
	for _, q in ipairs({ feet, vector.offset(feet, 0, 1, 0), }) do
		if core.get_node(q).name == GATE then
			at = q
			break
		end
	end
	local pocket = cb_dimensions.get("end")
	if not at or not pocket then
		return false
	end
	local g = the_end.geometry(pocket)
	for _, e in ipairs(gates) do
		if vector.equals(e.a, at) then
			if not e.b then
				local half = math.min(g.ib.x - g.centre.x, g.ib.z - g.centre.z) - the_end.EDGE
				local dist = math.min(g.outer_r + 50, half)
				local target = vector.round(vector.add(g.centre, vector.multiply(direction(g, at), dist)))
				e.land = cb_portals.end_island_near(target, g)
				e.b = vector.offset(e.land, 0, 3, 0)
				build(e.b)
				save()
			end
			cb_portals.teleport(player, vector.offset(e.land, 0, -0.5, 0))
			st.cooldown = COOLDOWN
			return true
		elseif e.b and vector.equals(e.b, at) then
			local p = vector.round(vector.add(g.centre, vector.multiply(direction(g, e.a), BACK_D)))
			local _, top = the_end.island_range(g, p.x, p.z)
			cb_portals.teleport(player, vector.new(p.x, (top or g.centre.y + 2) + 0.5, p.z))
			st.cooldown = COOLDOWN
			return true
		end
	end
	return false
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
		cb_portals.end_gateway_tick(player, dt)
	end
end)

core.register_on_leaveplayer(function(player)
	players[player:get_player_name()] = nil
end)
