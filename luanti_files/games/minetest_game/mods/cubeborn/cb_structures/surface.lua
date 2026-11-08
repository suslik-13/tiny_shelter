-- Ground for surface structures. Natural nodes (cb_core.natural_cids) fall in
-- three kinds: liquid; ground (walkable, not buildable_to, not trees or
-- leaves); clear (everything else natural: trunks, leaves, plants, snow
-- layers). A reader caches one VoxelManip over the whole planning area.
local SU = {}
cb_structures.surface = SU
local kinds

local function build()
	kinds = {}
	local natural = cb_core.natural_cids("world")
	for name, def in pairs(core.registered_nodes) do
		local cid = core.get_content_id(name)
		if cid == core.CONTENT_AIR then
			kinds[cid] = "air"
		elseif natural[cid] and cid ~= core.CONTENT_IGNORE then
			local g = def.groups or {}
			if def.liquidtype and def.liquidtype ~= "none" then
				kinds[cid] = "liquid"
			elseif def.walkable ~= false and not def.buildable_to and not (g.tree or g.leaves or g.leafdecay) then
				kinds[cid] = "ground"
			else
				kinds[cid] = "clear"
			end
		end
	end
end

function SU.kind_cid(cid)
	if not kinds then
		build()
	end
	return kinds[cid]
end

function SU.kind(name)
	return SU.kind_cid(core.get_content_id(name))
end

local Reader = {}
Reader.__index = Reader

function SU.reader(minp, maxp)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(minp, maxp)
	return setmetatable({ va = VoxelArea(e1, e2), data = vm:get_data(), minp = minp, maxp = maxp, cache = {}, },
		Reader)
end

function Reader:surface(x, z)
	local key = x .. "," .. z
	local v = self.cache[key]
	if v ~= nil then
		return v or nil
	end
	v = false
	for y = self.maxp.y, self.minp.y, -1 do
		local k = SU.kind_cid(self.data[self.va:index(x, y, z)])
		if k == "ground" then
			v = y < self.maxp.y and y or false
			break
		elseif k ~= "air" and k ~= "clear" then
			break
		end
	end
	self.cache[key] = v
	return v or nil
end

SU.SITE_RADIUS = 24

local function axis(a, b)
	local list = {}
	for v = a, b, 3 do
		list[#list + 1] = v
	end
	if list[#list] ~= b then
		list[#list + 1] = b
	end
	return list
end

-- The highest surface when every column has ground and the drop is at most
-- opts.max_drop.
local function flat_floor(reader, x1, z1, w, d, opts)
	local lo, hi = math.huge, -math.huge
	for _, x in ipairs(axis(x1, x1 + w - 1)) do
		for _, z in ipairs(axis(z1, z1 + d - 1)) do
			local y = reader:surface(x, z)
			if not y then
				return
			end
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
	end
	if hi - lo <= (opts.max_drop or 8) then
		return hi
	end
end

-- Whether column (x, z) of the reader ends in liquid (a pond, a river).
function Reader:wet(x, z)
	for y = self.maxp.y, self.minp.y, -1 do
		local k = SU.kind_cid(self.data[self.va:index(x, y, z)])
		if k ~= "air" and k ~= "clear" then
			return k == "liquid"
		end
	end
	return false
end

-- Levelled ground (opts.level = {wet, cut, fill}) for big buildings: at most
-- the share `wet` of the columns under water; the floor at the median
-- surface, raised so that at most `cut` nodes of ground above it get cut
-- away; the lowest tenth of the columns at most `fill` below it (foundation).
local function level_floor(reader, x1, z1, w, d, opts)
	local L = opts.level
	local hs, wet, n = {}, 0, 0
	for _, x in ipairs(axis(x1, x1 + w - 1)) do
		for _, z in ipairs(axis(z1, z1 + d - 1)) do
			n = n + 1
			local y = reader:surface(x, z)
			if y then
				hs[#hs + 1] = y
			elseif reader:wet(x, z) then
				wet = wet + 1
			else
				return -- a build, or ground up to the reader's top
			end
		end
	end
	if wet > n * L.wet or #hs == 0 then
		return
	end
	table.sort(hs)
	local floor = math.max(hs[math.ceil(#hs / 2)], hs[#hs] - L.cut)
	if floor - hs[math.max(1, math.floor(#hs / 10))] <= L.fill then
		return floor
	end
end

-- Floor y for a w x d box (x and z) near origin, h high, opts.below nodes of
-- foundation room: the highest surface on a grid over the box, a drop of at
-- most opts.max_drop (or levelled ground with opts.level), the box free.
-- Tries spots within opts.radius or SITE_RADIUS (step 4, nearest first).
-- Returns y, minp corner (x, z) or nil, err (where a build is in the way,
-- when one is).
function SU.site(origin, w, d, h, opts)
	local R = opts.radius or SU.SITE_RADIUS
	-- every spot's box lies within R + half the box (+1) of origin
	local hw, hd = R + math.ceil(w / 2) + 1, R + math.ceil(d / 2) + 1
	local reader = SU.reader(vector.offset(origin, -hw, -24, -hd), vector.offset(origin, hw, 40, hd))
	local spots = {}
	for dx = -R, R, 4 do
		for dz = -R, R, 4 do
			spots[#spots + 1] = { dx, dz, }
		end
	end
	table.sort(spots, function(a, b)
		return a[1] * a[1] + a[2] * a[2] < b[1] * b[1] + b[2] * b[2]
	end)
	local floor_of = opts.level and level_floor or flat_floor
	local blocked = {}
	for _, s in ipairs(spots) do
		local x1, z1 = origin.x + s[1] - math.floor(w / 2), origin.z + s[2] - math.floor(d / 2)
		local y = floor_of(reader, x1, z1, w, d, opts)
		if y then
			local a, b = vector.new(x1, y - (opts.below or 8), z1), vector.new(x1 + w - 1, y + h, z1 + d - 1)
			local known
			-- a box around a node already found in the way needs no new scan
			for _, f in ipairs(blocked) do
				known = known or cb_core.inside(f.pos, a, b)
			end
			if not known then
				local res = cb_core.check_area_now(a, b)
				if res.ok then
					return y, x1, z1
				end
				blocked[#blocked + 1] = res
			end
		end
	end
	local f = blocked[1]
	if f then
		local where = core.pos_to_string(f.pos)
		return nil, f.reason == "protected" and cb_structures.S("Place is protected at @1.", where)
			or cb_structures.S("Place is occupied at @1.", where)
	end
	return nil, cb_structures.S("No flat free ground here.")
end
