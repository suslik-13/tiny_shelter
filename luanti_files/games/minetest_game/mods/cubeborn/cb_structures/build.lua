-- Placing a structure: validate the box, check that the place is free, then a
-- background job emerges the box (plus a small margin against overgeneration),
-- builds one piece per step with a VoxelManip and samples one part per step.
local S = cb_structures.S

cb_structures.SAMPLES = 64
cb_structures.SINK_MAX = 24
local MAX_ANCHORS, MARGIN = 16, 16
local buf, buf2 = {}, {}
local layouts = {}
local emerging = {}
local pending = {}

local function layout_of(st)
	local l = layouts[st.id]
	if not l then
		l = cb_structures.get_type(st.name).layout(vector.copy(st.origin), st.seed, st.plan)
		layouts[st.id] = l
	end
	return l
end

local function build_piece(piece)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(piece.minp, piece.maxp)
	local va = VoxelArea(e1, e2)
	local data = vm:get_data(buf)
	local p2 = vm:get_param2_data(buf2)
	local cids, chests = {}, {}
	local function cid(name)
		local c = cids[name]
		if not c then
			c = core.get_content_id(name)
			cids[name] = c
		end
		return c
	end
	local ctx = {}
	function ctx.set(pos, name, param2)
		if cb_core.inside(pos, piece.minp, piece.maxp) then
			local i = va:indexp(pos)
			data[i], p2[i] = cid(name), param2 or 0
		end
	end
	function ctx.fill(a, b, name, param2)
		local lo, hi = cb_core.intersect(a, b, piece.minp, piece.maxp)
		if lo then
			local c = cid(name)
			for i in va:iterp(lo, hi) do
				data[i], p2[i] = c, param2 or 0
			end
		end
	end
	function ctx.chest(pos, loot_name, param2)
		if cb_core.inside(pos, piece.minp, piece.maxp) then
			ctx.set(pos, "default:chest", param2)
			chests[#chests + 1] = { pos = vector.copy(pos), loot = loot_name, }
		end
	end
	function ctx.get(pos)
		if not cb_core.inside(pos, piece.minp, piece.maxp) then
			return "ignore"
		end
		return core.get_name_from_content_id(data[va:indexp(pos)])
	end
	local construct = {}
	local after = {}
	-- fn() runs once the piece is on the map (entities, armour stands).
	function ctx.after(fn)
		after[#after + 1] = fn
	end
	function ctx.construct(pos)
		if cb_core.inside(pos, piece.minp, piece.maxp) then
			construct[#construct + 1] = vector.copy(pos)
		end
	end
	-- Metadata (a dungeon chest generated during the emerge, a chest of an
	-- earlier piece) is not cleared by a VoxelManip write: drop it wherever
	-- this piece replaces the node.
	local metas = core.find_nodes_with_meta(piece.minp, piece.maxp)
	local before = {}
	for k, p in ipairs(metas) do
		before[k] = data[va:indexp(p)]
	end
	piece.build(ctx)
	for k, p in ipairs(metas) do
		if data[va:indexp(p)] ~= before[k] then
			core.get_meta(p):from_table(nil)
		end
	end
	vm:set_data(data)
	vm:set_param2_data(p2)
	vm:write_to_map(true)
	local chest = core.registered_nodes["default:chest"]
	-- Chests without loot (woodland mansions have hundreds) stay without
	-- metadata until someone opens or digs one (loot.open builds it then).
	for _, c in ipairs(chests) do
		if c.loot then
			if chest.on_construct then
				chest.on_construct(c.pos)
			end
			core.get_meta(c.pos):set_string("cb_loot", c.loot)
		end
	end
	for _, pos in ipairs(construct) do
		local def = core.registered_nodes[core.get_node(pos).name]
		if def and def.on_construct then
			def.on_construct(pos)
		end
	end
	for _, fn in ipairs(after) do
		fn()
	end
end
cb_structures.build_piece = build_piece

local function palette_index(st, name)
	for i, n in ipairs(st.palette) do
		if n == name then
			return i
		end
	end
	st.palette[#st.palette + 1] = name
	return #st.palette
end

-- 64 random non-air nodes of the part, plus up to 16 anchor nodes.
local function sample_part(st, piece, j, anchors)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(piece.minp, piece.maxp)
	local va = VoxelArea(e1, e2)
	local data = vm:get_data(buf)
	local filled, a = {}, {}
	local exclude = cb_structures.get_type(st.name).sample_exclude or {}
	for i in va:iterp(piece.minp, piece.maxp) do
		local c = data[i]
		if c ~= core.CONTENT_AIR and c ~= core.CONTENT_IGNORE then
			local name = core.get_name_from_content_id(c)
			if anchors[name] and #a < MAX_ANCHORS then
				a[#a + 1] = { o = cb_structures.offset(piece.minp, piece.maxp, va:position(i)), p = palette_index(st, name), }
			end
			if not exclude[name] then
				filled[#filled + 1] = i
			end
		end
	end
	local rng = PcgRandom(st.seed + j)
	local s = {}
	for k = 1, math.min(cb_structures.SAMPLES, #filled) do
		local pick = rng:next(k, #filled)
		filled[k], filled[pick] = filled[pick], filled[k]
		local i = filled[k]
		s[k] = { o = cb_structures.offset(piece.minp, piece.maxp, va:position(i)),
			p = palette_index(st, core.get_name_from_content_id(data[i])), }
	end
	return { minp = piece.minp, maxp = piece.maxp, s = cb_structures.pack(s), a = #a > 0 and cb_structures.pack(a) or nil, }
end

local function parts_of(l)
	local parts = {}
	for _, piece in ipairs(l.pieces) do
		if piece.part then
			parts[#parts + 1] = piece
		end
	end
	return parts
end

cb_core.jobs.register_type("cb_structures:build", {
	label = S("Building structure"),
	progress = function(st)
		if st.phase == "build" then
			return 0.1 + 0.8 * st.i / math.max(st.n or 1, 1)
		elseif st.phase == "sample" then
			return 0.9 + 0.05 * st.i / math.max(st.np or 1, 1)
		elseif st.phase == "lamps" then
			return 0.95
		end
		return 0
	end,
	step = function(st)
		local rec = cb_structures.registry.get(st.id)
		if not rec then
			return "done"
		end
		local l = layout_of(st)
		if st.phase == "emerge" then
			if emerging[st.id] == "done" then
				emerging[st.id] = nil
				st.phase, st.i, st.n = "build", 0, #l.pieces
				return "more"
			end
			if not emerging[st.id] then
				emerging[st.id] = "pending"
				local e0, e1 = core.get_mapgen_edges()
				local lo, hi = cb_core.intersect(vector.subtract(l.minp, MARGIN), vector.add(l.maxp, MARGIN), e0, e1)
				core.emerge_area(lo, hi, function(_, _, remaining)
					if remaining == 0 then
						emerging[st.id] = "done"
					end
				end)
			end
			return "wait"
		elseif st.phase == "build" then
			st.i = st.i + 1
			-- pieces without build() are parts only: sampled, never written
			local piece = l.pieces[st.i]
			if piece and piece.build then
				build_piece(piece)
			end
			if st.i >= #l.pieces then
				st.phase, st.i, st.np = "sample", 0, #parts_of(l)
			end
			return "more"
		elseif st.phase == "lamps" then
			st.i = st.i + 1
			local part = st.parts[st.i]
			if part then
				cb_structures.lamps.light_box(st.name, part.minp, part.maxp)
				return "more"
			end
			rec.lit = true
			rec.palette = st.palette
			rec.state = "ready"
			cb_structures.registry.set_parts(st.id, st.parts)
			return "done"
		end
		local parts = parts_of(l)
		st.i = st.i + 1
		local piece = parts[st.i]
		if piece then
			local kinh = cb_structures.respawn.kind(cb_structures.get_type(st.name).inhabitants, piece)
			local anchors = {}
			for _, n in ipairs(kinh and kinh.anchors or {}) do
				anchors[n] = true
			end
			st.parts[st.i] = sample_part(st, piece, st.i, anchors)
			st.parts[st.i].k = piece.kind
		end
		if st.i < #parts then
			return "more"
		end
		if cb_structures.lamps.TYPES[st.name] then
			st.phase, st.i = "lamps", 0
			return "more"
		end
		rec.palette = st.palette
		rec.state = "ready"
		cb_structures.registry.set_parts(st.id, st.parts)
		return "done"
	end,
	on_done = function(st, job)
		layouts[st.id] = nil
		if job.owner then
			core.chat_send_player(job.owner, S("Structure #@1 (@2) is built.", st.id, st.name))
		end
	end,
})

local function emerge(minp, maxp, cb)
	local e0, e1 = core.get_mapgen_edges()
	local lo, hi = cb_core.intersect(minp, maxp, e0, e1)
	if not lo then
		return cb()
	end
	core.emerge_area(lo, hi, function(_, _, remaining)
		if remaining == 0 then
			cb()
		end
	end)
end

local function queue(name, origin, owner, seed, l, plan, callback)
	local id = cb_structures.registry.add({ type = name, minp = l.minp, maxp = l.maxp, seed = seed,
		owner = owner, state = "building", target = l.target, })
	cb_core.jobs.start("cb_structures:build", { id = id, name = name, origin = vector.copy(origin), seed = seed,
		plan = plan, phase = "emerge", i = 0, parts = {}, palette = {}, }, { owner = owner, })
	callback({ ok = true, id = id, })
end

-- Places structure `name` with its layout origin at `origin`. callback(res)
-- gets {ok = true, id = id} once the build is queued, or {ok = false, msg}.
-- opts.variant picks a variant of types that have them. Types with a plan()
-- first emerge their `prepare` area, then plan (reading the map); the plan
-- is kept in the build job so that the layout never reads the map again.
function cb_structures.place(name, origin, owner, callback, seed, opts)
	opts = opts or {}
	local def = cb_structures.get_type(name)
	if not def then
		return callback({ ok = false, msg = S("Unknown structure '@1'.", name), })
	end
	seed = seed or math.random(1, 2147483646)
	local variant
	if def.variants then
		variant = opts.variant or def.pick_variant(origin)
		if table.indexof(def.variants, variant) < 0 then
			return callback({ ok = false, msg = S("Unknown variant '@1' of '@2'.", tostring(variant), name), })
		end
	end
	local function go(plan)
		local l = def.layout(vector.copy(origin), seed, plan)
		-- an underground type that pokes a little above its ceiling goes down
		-- by as much (a mineshaft corridor climbing from an origin at the
		-- ceiling); one on the surface is still refused
		for _ = 1, 3 do
			if plan or not def.y_max or l.maxp.y <= def.y_max or l.maxp.y - def.y_max > cb_structures.SINK_MAX then
				break
			end
			origin = vector.offset(origin, 0, def.y_max - l.maxp.y, 0)
			l = def.layout(vector.copy(origin), seed, plan)
		end
		local ok, err = cb_structures.validate(name, l.minp, l.maxp)
		if ok then
			for box in pairs(pending) do
				if cb_core.intersect(l.minp, l.maxp, box.minp, box.maxp) then
					ok, err = false, S("Another structure is being placed there.")
				end
			end
		end
		if not ok then
			return callback({ ok = false, msg = err, })
		end
		if def.self_checked then
			return queue(name, origin, owner, seed, l, plan, callback)
		end
		local box = { minp = l.minp, maxp = l.maxp, }
		pending[box] = true
		cb_core.check_area(l.minp, l.maxp, function(res)
			pending[box] = nil
			if not res.ok then
				local msg = res.reason == "protected" and S("Place is protected at @1.", core.pos_to_string(res.pos))
					or S("Place is occupied at @1.", core.pos_to_string(res.pos))
				return callback({ ok = false, msg = msg, })
			end
			local valid, why = cb_structures.validate(name, l.minp, l.maxp)
			if not valid then
				return callback({ ok = false, msg = why, })
			end
			queue(name, origin, owner, seed, l, plan, callback)
		end)
	end
	if not def.plan then
		return go(nil)
	end
	local pr = def.prepare
	emerge(vector.offset(origin, -pr.radius, -pr.below, -pr.radius), vector.offset(origin, pr.radius, pr.above, pr.radius),
		function()
			local plan, err = def.plan(vector.copy(origin), seed, variant)
			if not plan then
				return callback({ ok = false, msg = err, })
			end
			go(plan)
		end)
end
