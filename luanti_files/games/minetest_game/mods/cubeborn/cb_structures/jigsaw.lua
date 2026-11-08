-- A compact jigsaw assembler for Mineclonia templates: a child is the first
-- element of the target pool (by weight, shuffled), rotation and jigsaw
-- (by selection priority) whose name is the source's target, that faces it
-- and whose box fits its free space. As in Minecraft, a child whose target
-- spot is inside the parent's box takes space of the parent (its holder is
-- the parent), any other child takes space where the parent stands (the
-- parent's holder; nil: the bounds, minus the start piece). A box fits when
-- it lies within its holder's box (or the bounds) and clear of the pieces
-- with the same holder. FIFO order, at most max_depth deep. A piece from a
-- must_complete pool that did not get all its children is dropped with its
-- descendants.
local T = cb_structures.templates
local J = { pools = {}, }
cb_structures.jigsaw = J

function J.register_pool(id, elements, must_complete)
	J.pools[id] = { elements = elements, must_complete = must_complete, }
end

local function shuffle(t, rng)
	for i = #t, 2, -1 do
		local j = rng:next(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function weighted(pool, rng)
	local list = {}
	for _, e in ipairs(pool.elements) do
		for _ = 1, e.weight do
			list[#list + 1] = e
		end
	end
	return shuffle(list, rng)
end

local function jigsaws(tpl, rng, skip)
	local list = {}
	for _, j in ipairs(tpl.jigsaws) do
		if j ~= skip then
			list[#list + 1] = j
		end
	end
	shuffle(list, rng)
	table.sort(list, function(a, b)
		return a.sel > b.sel
	end)
	return list
end

local function hit(a, b)
	return a[1] <= b[4] and b[1] <= a[4] and a[2] <= b[5] and b[2] <= a[5] and a[3] <= b[6] and b[3] <= a[6]
end

local function within(a, b)
	return a[1] >= b[1] and a[2] >= b[2] and a[3] >= b[3] and a[4] <= b[4] and a[5] <= b[5] and a[6] <= b[6]
end

local function compatible(t, k, facing, parent_rot)
	local f = T.turn(t.facing, k)
	local rollable = f ~= T.UP and f ~= T.DOWN or t.joint == 2
	return f == T.OPPOSITE[facing] and (rollable or (k + t.rot) % 4 == parent_rot)
end

local function fits(bb, pieces, holder, bounds)
	if not within(bb, holder and holder.bbox or bounds) then
		return false
	end
	for _, p in ipairs(pieces) do
		if p.holder == holder and p ~= holder and hit(bb, p.bbox) then
			return false
		end
	end
	return true
end

local function try(parent, j, pieces, rng, bounds)
	local sx, sy, sz = T.transform(j.dx, j.dy, j.dz, parent.k)
	sx, sy, sz = sx + parent.x, sy + parent.y, sz + parent.z
	local facing = T.turn(j.facing, parent.k)
	local d = T.DIR[facing]
	local tx, ty, tz = sx + d[1], sy + d[2], sz + d[3]
	local pb = parent.bbox
	local inner = tx >= pb[1] and tx <= pb[4] and ty >= pb[2] and ty <= pb[5] and tz >= pb[3] and tz <= pb[6]
	local parent_rot = (j.rot + parent.k) % 4
	local holder = inner and parent or parent.holder
	for _, elem in ipairs(weighted(J.pools[j.pool], rng)) do
		for _, k in ipairs(shuffle({ 0, 1, 2, 3, }, rng)) do
			for _, t in ipairs(jigsaws(elem.tpl, rng)) do
				if t.name == j.target and compatible(t, k, facing, parent_rot) then
					local ox, oy, oz = T.transform(t.dx, t.dy, t.dz, k)
					local cx, cy, cz = tx - ox, ty - oy, tz - oz
					local bb = T.bbox(elem.tpl, cx, cy, cz, k)
					if fits(bb, pieces, holder, bounds) then
						return { tpl = elem.tpl, x = cx, y = cy, z = cz, k = k, depth = parent.depth + 1, parent = parent,
							holder = holder, bbox = bb, entry = t, pool = j.pool,
							link = { at = { tx, ty, tz, }, from = { sx, sy, sz, }, }, }
					end
				end
			end
		end
	end
	return nil
end

function J.assemble(start_pool, rng, x, y, z, opts)
	local start = weighted(J.pools[start_pool], rng)[1]
	local k = rng:next(0, 3)
	local root = { tpl = start.tpl, x = x, y = y, z = z, k = k, depth = 0, bbox = T.bbox(start.tpl, x, y, z, k),
		pool = start_pool, }
	local pieces, queue = { root, }, { root, }
	while #queue > 0 and #pieces < opts.max_pieces do
		local parent = table.remove(queue, 1)
		parent.need, parent.got = 0, 0
		for _, j in ipairs(jigsaws(parent.tpl, rng, parent.entry)) do
			if J.pools[j.pool] and parent.depth < opts.max_depth and #pieces < opts.max_pieces then
				parent.need = parent.need + 1
				local child = try(parent, j, pieces, rng, opts.bounds)
				if child then
					parent.got = parent.got + 1
					pieces[#pieces + 1] = child
					queue[#queue + 1] = child
				end
			end
		end
	end
	-- must_complete: drop unfinished pieces with their descendants.
	local changed = true
	while changed do
		changed = false
		local alive = {}
		for _, p in ipairs(pieces) do
			alive[p] = true
		end
		local kept = {}
		for _, p in ipairs(pieces) do
			local keep = not p.parent or alive[p.parent]
			if keep and p.need and J.pools[p.pool] and J.pools[p.pool].must_complete then
				local got = 0
				for _, c in ipairs(pieces) do
					got = got + ((c.parent == p and alive[c]) and 1 or 0)
				end
				keep = got >= p.need
			end
			if keep then
				kept[#kept + 1] = p
			else
				changed = true
				alive[p] = nil
			end
		end
		pieces = kept
	end
	return pieces
end
