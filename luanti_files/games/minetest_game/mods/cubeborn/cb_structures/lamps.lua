-- Lamps of Nether and End structures. Minecraft lights these dimensions by an
-- ambient level that Luanti lacks, so their inside would stay black. Dark air
-- under a structure's own ceiling gets a hanging lamp, dark air on its floor
-- along a wall a standing one; a lamp lights its surroundings, so the next dark
-- spot comes by itself. No spawn rule of these mobs looks at the light (see the
-- scenario structure_lamps), and a lamp takes one air node.
-- /cb_lamps adds them to structures built before this existed.
local S = cb_structures.S
local LAMPS = { DARK = 4, MAX_PER_PART = 32, }
cb_structures.lamps = LAMPS

local LANTERN = { hang = "cb_blocks:lantern_hanging", hang_p2 = 0, stand = "cb_blocks:lantern", stand_p2 = 1, }
local ROD = { hang = "cb_blocks:end_rod", hang_p2 = 20, stand = "cb_blocks:end_rod", stand_p2 = 0, }
LAMPS.TYPES = { nether_fortress = LANTERN, bastion = LANTERN, end_city = ROD, }

-- Whether a node of the map was built, not generated: bricks of the nether mod
-- count as natural because its own generator places them too.
function LAMPS.built(cid, natural)
	local name = core.get_name_from_content_id(cid)
	local def = core.registered_nodes[name]
	return (not natural[cid] or name:find("brick", 1, true) ~= nil)
		and def ~= nil and def.walkable ~= false and (def.liquidtype or "none") == "none"
end

-- Adds lamps to one part of a structure of this type; returns how many.
function LAMPS.light_box(kind, minp, maxp)
	local lamp = LAMPS.TYPES[kind]
	if not (lamp and core.registered_nodes[lamp.hang] and core.registered_nodes[lamp.stand]) then
		return 0
	end
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map(vector.offset(minp, -1, -1, -1), vector.offset(maxp, 1, 1, 1))
	local va, data = VoxelArea(e1, e2), vm:get_data()
	local natural = cb_core.natural_cids(cb_core.natural_scope(minp, maxp))
	local AIR, IGNORE = core.CONTENT_AIR, core.CONTENT_IGNORE
	local built = {}
	-- a solid node that the structure placed, not the terrain around it
	local function ours(cid)
		if cid == AIR or cid == IGNORE then
			return false
		end
		if built[cid] == nil then
			built[cid] = LAMPS.built(cid, natural)
		end
		return built[cid]
	end
	local added = 0
	local function place(pos, name, param2)
		if added < LAMPS.MAX_PER_PART and (core.get_node_light(pos, 0) or 15) < LAMPS.DARK then
			core.set_node(pos, { name = name, param2 = param2, })
			added = added + 1
		end
	end
	-- hanging first: they stay out of the way (two air nodes below them)
	for y = maxp.y, minp.y + 2, -1 do
		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				local i = va:index(x, y, z)
				if data[i] == AIR and ours(data[va:index(x, y + 1, z)]) and data[va:index(x, y - 1, z)] == AIR
						and data[va:index(x, y - 2, z)] == AIR then
					place(vector.new(x, y, z), lamp.hang, lamp.hang_p2)
				end
			end
		end
	end
	-- no ceiling (bridges, roofs): along a wall or a railing
	for y = minp.y, maxp.y - 1 do
		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				local i = va:index(x, y, z)
				if data[i] == AIR and ours(data[va:index(x, y - 1, z)]) and data[va:index(x, y + 1, z)] == AIR
						and (ours(data[va:index(x + 1, y, z)]) or ours(data[va:index(x - 1, y, z)])
						or ours(data[va:index(x, y, z + 1)]) or ours(data[va:index(x, y, z - 1)])) then
					place(vector.new(x, y, z), lamp.stand, lamp.stand_p2)
				end
			end
		end
	end
	return added
end

-- /cb_lamps: one part per step, under the load governor of /cb_populate
local JOB = "cb_structures:lamps"
local governed = false

local function govern(on)
	if on ~= governed then
		governed = on
		local PL = cb_structures.populate_load
		if on then
			PL.start()
		else
			PL.stop()
		end
	end
end

cb_core.jobs.register_type(JOB, {
	label = S("Adding lamps"),
	progress = function(st)
		return (st.i - 1) / math.max(#st.ids, 1)
	end,
	step = function(st)
		govern(true)
		local id = st.ids[st.i]
		if not id then
			return "done"
		end
		local rec = cb_structures.registry.get(id)
		local parts = rec and rec.state == "ready" and rec.parts or {}
		st.part = st.part + 1
		local part = parts[st.part]
		if part then
			core.load_area(part.minp, part.maxp)
			st.added = st.added + LAMPS.light_box(rec.type, part.minp, part.maxp)
			return "more"
		end
		if rec and rec.state == "ready" then
			rec.lit = true
			cb_structures.registry.save(id)
		end
		st.i, st.part = st.i + 1, 0
		return "more"
	end,
	on_done = function(st, job)
		govern(false)
		core.log("action", "[cubeborn] lamps: " .. st.added .. " added in " .. #st.ids .. " structures")
		if job.owner then
			core.chat_send_player(job.owner, S("Lamps: @1 added in @2 structures.", st.added, #st.ids))
		end
	end,
})

local function running()
	for _, job in ipairs(cb_core.jobs.list()) do
		if job.type == JOB then
			return job
		end
	end
end

-- Structures of these types still without lamps.
function LAMPS.unlit()
	local ids = {}
	for id, rec in pairs(cb_structures.registry.all()) do
		if LAMPS.TYPES[rec.type] and rec.state == "ready" and not rec.lit then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	return ids
end

core.register_chatcommand("cb_lamps", {
	params = "[status|stop]",
	description = S("Add lamps to the Nether and End structures built without them"),
	privs = { cb_admin = true, },
	func = function(name, param)
		param = param:match("^%s*(%S*)%s*$")
		local job = running()
		if param == "status" then
			if not job then
				return true, S("No lamps are being added; @1 structures have none.", #LAMPS.unlit())
			end
			return true, S("Adding lamps: structure @1 of @2, @3 lamps so far.", math.min(job.state.i, #job.state.ids),
				#job.state.ids, job.state.added)
		elseif param == "stop" then
			if not job then
				return true, S("No lamps are being added.")
			end
			cb_core.jobs.cancel(job.id)
			govern(false)
			return true, S("Stopped; /cb_lamps goes on with the rest.")
		elseif param ~= "" then
			return false, S("Usage: /cb_lamps [status|stop]")
		end
		if job then
			return false, S("Lamps are already being added (/cb_lamps status).")
		end
		if cb_structures.populate_state or cb_structures.scatter_state or cb_structures.nether_fill_state then
			return false, S("Another fill is going on; wait for it or stop it first.")
		end
		local ids = LAMPS.unlit()
		if #ids == 0 then
			return true, S("Every structure has its lamps.")
		end
		cb_core.jobs.start(JOB, { ids = ids, i = 1, part = 0, added = 0, }, { owner = name, })
		return true, S("Adding lamps to @1 structures.", #ids)
	end,
})
