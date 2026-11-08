-- Structure templates in Mineclonia's mcl_levelgen format (zstd-compressed
-- core.serialize tables; nodes in Minecraft's coordinate system, i.e. z
-- mirrored against Luanti's). On load, Mineclonia node names are mapped to
-- this server's nodes; jigsaw blocks, data blocks and item frames are kept
-- apart. Positions are "level" coordinates until placed: world = anchor +
-- (x, y, -z).
local T = {}
cb_structures.templates = T
local floor = math.floor
local band, rshift = bit.band, bit.rshift

T.NORTH, T.WEST, T.SOUTH, T.EAST, T.UP, T.DOWN = 1, 2, 4, 8, 16, 32
T.DIR = {
	[1] = { 0, 0, -1, }, [4] = { 0, 0, 1, }, [2] = { -1, 0, 0, }, [8] = { 1, 0, 0, }, [16] = { 0, 1, 0, },
	[32] = { 0, -1, 0, },
}
T.OPPOSITE = { [1] = 4, [4] = 1, [2] = 8, [8] = 2, [16] = 32, [32] = 16, }

-- Rotation by k quarter turns, as Mineclonia's template_transform with
-- px = pz = 0 ("90" is k = 1).
function T.transform(x, y, z, k)
	if k == 1 then
		return -z, y, x
	elseif k == 2 then
		return -x, y, -z
	elseif k == 3 then
		return z, y, -x
	end
	return x, y, z
end

function T.turn(face, k)
	if face == T.UP or face == T.DOWN then
		return face
	end
	local d = T.DIR[face]
	local x, _, z = T.transform(d[1], 0, d[3], k)
	for f, v in pairs(T.DIR) do
		if v[1] == x and v[3] == z and v[2] == 0 then
			return f
		end
	end
end

function T.bbox(tpl, x, y, z, k)
	local x1, y1, z1 = T.transform(0, 0, 0, k)
	local x2, y2, z2 = T.transform(tpl.w - 1, tpl.h - 1, tpl.l - 1, k)
	return { x + math.min(x1, x2), y + math.min(y1, y2), z + math.min(z1, z2),
		x + math.max(x1, x2), y + math.max(y1, y2), z + math.max(z1, z2), }
end

-- A world vector turned as the level turns by k (world z is level -z).
function T.world_dir(v, k)
	local x, y, z = T.transform(v.x, v.y, -v.z, k)
	return vector.new(x, y, -z)
end

local AXIS = { [0] = vector.new(0, 1, 0), vector.new(0, 0, 1), vector.new(0, 0, -1), vector.new(1, 0, 0),
	vector.new(-1, 0, 0), vector.new(0, -1, 0), }

function T.rotate_param2(name, p2, k)
	if k % 4 == 0 then
		return p2
	end
	local def = core.registered_nodes[name]
	local pt = def and def.paramtype2
	if pt == "facedir" or pt == "colorfacedir" or pt == "4dir" or pt == "color4dir" then
		local f = p2 % 24
		local front = T.world_dir(core.facedir_to_dir(f), k)
		local up = T.world_dir(AXIS[floor(f / 4)], k)
		for q = 0, 23 do
			if vector.equals(core.facedir_to_dir(q), front) and vector.equals(AXIS[floor(q / 4)], up) then
				return p2 - f + q
			end
		end
	elseif pt == "wallmounted" or pt == "colorwallmounted" then
		local w = p2 % 8
		return p2 - w + core.dir_to_wallmounted(T.world_dir(core.wallmounted_to_dir(w), k))
	end
	return p2
end

local PURPUR = "cb_blocks:purpur_block"
-- Mineclonia name -> this server's node, or { node, param2 } to force param2.
T.MAP = {
	["air"] = "air",
	["mcl_end:purpur_block"] = PURPUR,
	["mcl_end:purpur_pillar"] = "cb_blocks:purpur_pillar",
	["mcl_end:end_bricks"] = "cb_blocks:end_stone_bricks",
	["mcl_end:end_rod"] = "cb_blocks:end_rod",
	["mcl_stairs:stair_purpur_block"] = "stairs:stair_cb_purpur_block",
	["mcl_stairs:slab_purpur_block"] = "stairs:slab_cb_purpur_block",
	["mcl_stairs:slab_purpur_block_top"] = { "stairs:slab_cb_purpur_block", 20, },
	["mcl_stairs:slab_purpur_block_double"] = PURPUR,
	["mcl_core:glass_purple"] = "cb_blocks:glass_purple",
	["mcl_core:ladder"] = "default:ladder_wood",
	["mcl_chests:chest_small"] = "default:chest",
	["mcl_chests:ender_chest_small"] = "default:obsidian",
	["mcl_heads:dragon_wall"] = "cb_blocks:dragon_head_wall",
	["mcl_banners:hanging_banner"] = "air",
	["mcl_brewing:stand_001"] = "air",
	["mcl_brewing:stand_100"] = "air",
}
local WALL = "cb_blocks:end_stone_bricks_wall"
local JIGSAW, DATA, VOID, FRAME = "mcl_levelgen:jigsaw_block", "mcl_levelgen:structure_block_data",
	"mcl_levelgen:structure_void", "mcl_itemframes:frame"
local ROT = { [0] = 0, 1, 2, 3, }

local PREFIX = {}

-- Every name starting with prefix maps to node (redstone and the like).
function T.map_prefix(prefix, node)
	PREFIX[#PREFIX + 1] = { prefix, node, }
end

local function map(name, p2)
	local m = T.MAP[name]
	if not m then
		for _, r in ipairs(PREFIX) do
			if name:sub(1, #r[1]) == r[1] then
				m = r[2]
				break
			end
		end
	end
	if not m and name:match("^mcl_walls:endbricks_%d+$") then
		m = WALL
	end
	if type(m) == "table" then
		return m[1], m[2]
	end
	return m, p2
end

-- Mineclonia's facedir_to_jigsaw_dir.
local function jigsaw_dir(p2)
	local facing, r = rshift(p2, 2), band(p2, 3)
	if facing == 0 then
		return T.UP, ROT[r]
	elseif facing == 5 then
		return T.DOWN, band(4 - r, 3)
	end
	return ({ [1] = T.NORTH, [2] = T.SOUTH, [3] = T.EAST, [4] = T.WEST, })[facing], 0
end

local function extract(tpl, i)
	local idx = i - 1
	return floor(idx / (tpl.h * tpl.l)) % tpl.w, floor(idx / tpl.l) % tpl.h, idx % tpl.l
end

function T.load(path)
	local f = assert(io.open(path, "rb"))
	local raw = f:read("*a")
	f:close()
	local data = core.deserialize(core.decompress(raw, "zstd"))
	local tpl = { w = data.width, h = data.height, l = data.length, nodes = {}, jigsaws = {}, data = {}, frames = {},
		unmapped = {}, }
	for i, packed in ipairs(data.nodes) do
		local id, p2, meta_id = band(rshift(packed, 8), 0xffff), band(packed, 0xff), rshift(packed, 24)
		local name = data.names[id]
		local meta = meta_id ~= 0 and data.metadata[meta_id] or nil
		local dx, dy, dz = extract(tpl, i)
		-- "ignore": unloaded space when Mineclonia saved the template; like void.
		if name == VOID or name == "ignore" then
			tpl.nodes[i] = false
		elseif name == JIGSAW then
			local j = core.deserialize(meta.fields["mcl_levelgen:structure_jigsaw_save_data"])
			local facing, rot = jigsaw_dir(p2)
			local into = map(j.turns_into, 0)
			if not into and j.turns_into ~= "ignore" then
				tpl.unmapped[j.turns_into] = true
			end
			tpl.jigsaws[#tpl.jigsaws + 1] = { dx = dx, dy = dy, dz = dz, facing = facing, rot = rot, name = j.name,
				pool = j.target_pool, target = j.target_name, joint = j.joint_type, sel = j.selection_priority or 0, }
			-- turns into "ignore": the connector keeps what is there.
			tpl.nodes[i] = j.turns_into ~= "ignore" and { into or "air", 0, } or false
		elseif name == DATA then
			local d = core.deserialize(meta.fields["mcl_levelgen:structure_data_save_data"])
			if d.value == "mcl_levelgen:create_entity" then
				tpl.data[#tpl.data + 1] = { dx = dx, dy = dy, dz = dz, kind = "entity", what = d.param1, }
			elseif d.value == "mcl_levelgen:set_loot_table" then
				tpl.data[#tpl.data + 1] = { dx = dx, dy = dy, dz = dz, kind = "loot", what = d.param1, }
			elseif d.value == "mcl_levelgen:piglin" or d.value == "mcl_levelgen:piglin_melee" then
				-- bastions: a roll on Mineclonia's piglin tables
				tpl.data[#tpl.data + 1] = { dx = dx, dy = dy, dz = dz, kind = "entity", what = d.value, }
			end
			tpl.nodes[i] = { "air", 0, }
		elseif name == FRAME then
			tpl.frames[#tpl.frames + 1] = { dx = dx, dy = dy, dz = dz, param2 = p2, }
			tpl.nodes[i] = { "air", 0, }
		else
			local node, q = map(name, p2)
			if not node then
				tpl.unmapped[name] = true
				node = "air"
			end
			tpl.nodes[i] = { node, q, }
		end
	end
	return tpl
end

-- Writes tpl rotated by k at level (x, y, z); world = anchor + (lx, ly, -lz).
-- Returns the data blocks and frames as world-space actions.
-- Nodes that need their on_construct after the write (furnaces, traps);
-- chests are set up through ctx.chest.
local construct_cache = {}
local function constructs(name)
	local c = construct_cache[name]
	if c == nil then
		local def = core.registered_nodes[name]
		c = def ~= nil and def.on_construct ~= nil
		construct_cache[name] = c
	end
	return c
end

-- opts.loot: the table for chests of loot data blocks (default
-- end_city_treasure), or function(Mineclonia's table) -> table or nil; opts.all_chests: chests without data get it too;
-- opts.process(name, pos): the node to write instead (weathering);
-- opts.skip_air: template air is not written (buried structures keep the ground).
function T.place(ctx, tpl, anchor, x, y, z, k, opts)
	local function world(dx, dy, dz)
		local lx, ly, lz = T.transform(dx, dy, dz, k)
		return vector.new(anchor.x + x + lx, anchor.y + y + ly, anchor.z - (z + lz))
	end
	local chests, done = {}, {}
	local process = opts and opts.process
	local skip_air = opts and opts.skip_air
	local i = 0
	for dx = 0, tpl.w - 1 do
		for dy = 0, tpl.h - 1 do
			for dz = 0, tpl.l - 1 do
				i = i + 1
				local n = tpl.nodes[i]
				if n and not (skip_air and n[1] == "air") then
					local pos = world(dx, dy, dz)
					local name = process and process(n[1], pos) or n[1]
					local p2 = T.rotate_param2(name, n[2], k)
					ctx.set(pos, name, p2)
					if name == "default:chest" then
						chests[core.hash_node_position(pos)] = p2
					elseif constructs(name) then
						ctx.construct(pos)
					end
				end
			end
		end
	end
	local actions = {}
	for _, d in ipairs(tpl.data) do
		local pos = world(d.dx, d.dy, d.dz)
		if d.kind == "loot" then
			pos = vector.offset(pos, 0, -1, 0)
			local h = core.hash_node_position(pos)
			local p2 = chests[h]
			local loot = opts and opts.loot or "end_city_treasure"
			if type(loot) == "function" then
				loot = loot(d.what)
			end
			if p2 and loot then
				ctx.chest(pos, loot, p2)
				done[h] = true
			end
		else
			actions[#actions + 1] = { kind = "entity", pos = pos, what = d.what, }
		end
	end
	if opts and opts.all_chests then
		for h, p2 in pairs(chests) do
			if not done[h] then
				ctx.chest(core.get_position_from_hash(h), opts.loot, p2)
			end
		end
	end
	for _, fr in ipairs(tpl.frames) do
		actions[#actions + 1] = { kind = "frame", pos = world(fr.dx, fr.dy, fr.dz),
			param2 = T.rotate_param2("default:ladder_wood", fr.param2, k), }
	end
	return actions
end
