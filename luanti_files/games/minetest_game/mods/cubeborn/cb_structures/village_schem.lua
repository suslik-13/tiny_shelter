-- Village schematics (role data from tools/port_villages.py): decoding,
-- rotation by quarter turns (as templates.world_dir) and placement through a
-- build ctx. Node order as in .mts: index (z * sy + y) * sx + x + 1.
local VS = {}
cb_structures.village_schem = VS
local VP = cb_structures.village_palettes
local T = cb_structures.templates

local raw = {}

-- Adds the schematics of a data file (village, outpost).
function VS.load(path)
	for k, v in pairs(dofile(path)) do
		raw[k] = v
	end
end

VS.load(core.get_modpath("cb_structures") .. "/village_schems.lua")
VS.load(core.get_modpath("cb_structures") .. "/outpost_schems.lua")
VS.load(core.get_modpath("cb_structures") .. "/mansion_schems.lua")
local decoded = {}
local MARKS = { bell = true, bed_bottom = true, path_endpoint = true, chest = true, mark_vindicator = true,
	mark_evoker = true, }

local function unrle(s)
	local out = {}
	for tok in s:gmatch("[^,]+") do
		local v, n = tok:match("^(%w+)%*(%w+)$")
		v = tonumber(v or tok, 36)
		for _ = 1, n and tonumber(n, 36) or 1 do
			out[#out + 1] = v
		end
	end
	return out
end

function VS.names()
	local list = {}
	for name in pairs(raw) do
		list[#list + 1] = name
	end
	table.sort(list)
	return list
end

function VS.get(name)
	local s = decoded[name]
	if s then
		return s
	end
	local r = assert(raw[name], "unknown village schematic " .. tostring(name))
	local marks = {}
	for kind in pairs(MARKS) do
		marks[kind] = {}
	end
	s = { name = name, x = r.x, y = r.y, z = r.z, beds = r.beds, roles = r.roles, nodes = unrle(r.nodes),
		p2 = unrle(r.p2), marks = marks, }
	local i = 0
	for z = 0, s.z - 1 do
		for y = 0, s.y - 1 do
			for x = 0, s.x - 1 do
				i = i + 1
				local role = s.roles[s.nodes[i] + 1]
				if MARKS[role] then
					table.insert(s.marks[role], { x = x, y = y, z = z, })
				end
			end
		end
	end
	decoded[name] = s
	return s
end

function VS.footprint(s, k)
	if k % 2 == 1 then
		return s.z, s.x
	end
	return s.x, s.z
end

function VS.rotate(s, k, x, z)
	if k == 1 then
		return z, s.x - 1 - x
	elseif k == 2 then
		return s.x - 1 - x, s.z - 1 - z
	elseif k == 3 then
		return s.z - 1 - z, x
	end
	return x, z
end

function VS.world_marks(s, k, minp, kind)
	local out = {}
	for _, m in ipairs(s.marks[kind]) do
		local rx, rz = VS.rotate(s, k, m.x, m.z)
		out[#out + 1] = vector.new(minp.x + rx, minp.y + m.y, minp.z + rz)
	end
	return out
end

-- Writes s turned by k with its (turned) min corner at minp. Chests get the
-- loot table, nodes with on_construct are constructed after the write; the
-- snowy palette puts snow on the topmost walkable node of every column.
function VS.place(ctx, s, minp, k, palette, loot)
	local info = { beds = {}, chests = 0, }
	local top = {}
	local i = 0
	for z = 0, s.z - 1 do
		for y = 0, s.y - 1 do
			for x = 0, s.x - 1 do
				i = i + 1
				local role = s.roles[s.nodes[i] + 1]
				local name, forced = VP.resolve(palette, role)
				if name then
					local rx, rz = VS.rotate(s, k, x, z)
					local pos = vector.new(minp.x + rx, minp.y + y, minp.z + rz)
					local p2 = forced or T.rotate_param2(name, s.p2[i], k)
					if name == "default:chest" then
						ctx.chest(pos, loot, p2)
						info.chests = info.chests + 1
					else
						ctx.set(pos, name, p2)
						local def = core.registered_nodes[name]
						if def and def.on_construct then
							ctx.construct(pos)
						end
					end
					if role == "bed_bottom" then
						info.beds[#info.beds + 1] = pos
					elseif role == "bell" then
						info.bell = pos
					end
					if name ~= "air" then
						local key = rx .. "," .. rz
						local def = core.registered_nodes[name]
						if def and def.walkable ~= false and (not top[key] or top[key].y < pos.y) then
							top[key] = pos
						end
					end
				end
			end
		end
	end
	local snow = VP.roof_snow(palette)
	if snow then
		for _, pos in pairs(top) do
			local above = vector.offset(pos, 0, 1, 0)
			if ctx.get(above) == "air" then
				ctx.set(above, snow)
			end
		end
	end
	return info
end
