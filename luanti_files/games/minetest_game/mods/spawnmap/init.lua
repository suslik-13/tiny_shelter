-- spawnmap: a daily top-down snapshot of the area around spawn,
-- displayed on 9 blocks that together form a 3x3 map.
--
-- Layout (north = +Z, east = +X):
--     nw  n  ne
--     w   c  e
--     sw  s  se

local S = minetest.get_translator and minetest.get_translator("spawnmap") or function(s) return s end

local modname = minetest.get_current_modname()
local storage = minetest.get_mod_storage()
local settings = minetest.settings

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

local function int_setting(name, default)
	return tonumber(settings:get(name)) or default
end

local RADIUS    = int_setting("spawnmap_radius", 2000)
local INTERVAL  = int_setting("spawnmap_interval", 86400)
local TILE      = int_setting("spawnmap_tile_size", 128)
local YMIN      = int_setting("spawnmap_ymin", -64)
local YMAX      = int_setting("spawnmap_ymax", 256)
local BUDGET    = int_setting("spawnmap_budget_ms", 15) / 1000
local ARCHIVE   = settings:get_bool("spawnmap_archive", true)
local ARCHIVE_MAX = int_setting("spawnmap_archive_max", 0)
-- 14 = as bright as a mese lamp (minetest.LIGHT_MAX), 0 = no light
local LIGHT = math.max(0, math.min(minetest.LIGHT_MAX, int_setting("spawnmap_light", minetest.LIGHT_MAX)))
local IGNORE_PATTERNS = {}
for raw in (settings:get("spawnmap_ignore_nodes") or "cloud"):gmatch("[^,]+") do
	local p = raw:match("^%s*(.-)%s*$")
	if p ~= "" then IGNORE_PATTERNS[#IGNORE_PATTERNS + 1] = p end
end

-- Never look into the v7 floatlands (flying islands).
do
	local mg = minetest.get_mapgen_setting("mg_name")
	local flags = minetest.get_mapgen_setting("mgv7_spflags") or ""
	if mg == "v7" and flags:find("floatlands") and not flags:find("nofloatlands") then
		local fl = tonumber(minetest.get_mapgen_setting("mgv7_floatland_ymin")) or 1280
		if YMAX >= fl then
			YMAX = fl - 1
		end
	end
end

local function get_center()
	local sp = minetest.string_to_pos(settings:get("static_spawnpoint") or "")
	if sp then
		return math.floor(sp.x + 0.5), math.floor(sp.z + 0.5)
	end
	return 0, 0
end

-------------------------------------------------------------------------------
-- Tiny drawing helpers (colors are 0xAARRGGBB numbers)
-------------------------------------------------------------------------------

local function rgb(r, g, b)
	r = math.max(0, math.min(255, math.floor(r + 0.5)))
	g = math.max(0, math.min(255, math.floor(g + 0.5)))
	b = math.max(0, math.min(255, math.floor(b + 0.5)))
	return 0xFF000000 + r * 0x10000 + g * 0x100 + b
end

local FRAME      = rgb(112, 78, 44)
local FRAME_DARK = rgb(62, 40, 20)
local TEXT       = rgb(246, 234, 200)
local UNKNOWN_A  = rgb(72, 66, 58)
local UNKNOWN_B  = rgb(64, 58, 50)
local MARKER     = rgb(220, 30, 30)
local PARCHMENT  = rgb(226, 206, 160)

local function new_canvas(w, h, fill)
	local c = {w = w, h = h}
	for i = 1, w * h do c[i] = fill end
	return c
end

local function plot(c, x, y, col)
	if x >= 0 and y >= 0 and x < c.w and y < c.h then
		c[y * c.w + x + 1] = col
	end
end

local function rect(c, x0, y0, w, h, col)
	for y = y0, y0 + h - 1 do
		for x = x0, x0 + w - 1 do plot(c, x, y, col) end
	end
end

local function to_png(c)
	local data = {}
	for i = 1, c.w * c.h do data[i] = c[i] end
	return minetest.encode_png(c.w, c.h, data, 9)
end

local function to_texmod(c)
	return "[png:" .. minetest.encode_base64(to_png(c))
end

-- 5x7 pixel font, only the letters needed for compass labels.
local FONT = {
	N = {"#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"},
	O = {".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."},
	R = {"####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"},
	T = {"#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."},
	H = {"#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"},
	S = {".####", "#....", "#....", ".###.", "....#", "....#", "####."},
	U = {"#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."},
	E = {"#####", "#....", "#....", "####.", "#....", "#....", "#####"},
	A = {".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"},
	W = {"#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"},
}

local function draw_glyph(c, ch, x0, y0, scale, col)
	local g = FONT[ch]
	if not g then return end
	for gy = 1, 7 do
		local row = g[gy]
		for gx = 1, 5 do
			if row:sub(gx, gx) == "#" then
				rect(c, x0 + (gx - 1) * scale, y0 + (gy - 1) * scale, scale, scale, col)
			end
		end
	end
end

local function text_width(text, scale)
	return (#text * 6 - 1) * scale
end

-- Horizontal text centered on (cx, top y0).
local function draw_text_h(c, text, cx, y0, scale, col)
	local x = cx - math.floor(text_width(text, scale) / 2)
	for i = 1, #text do
		draw_glyph(c, text:sub(i, i), x, y0, scale, col)
		x = x + 6 * scale
	end
end

-- Letters stacked top to bottom, centered on (left x0, cy).
local function draw_text_v(c, text, x0, cy, scale, col)
	local h = (#text * 9 - 2) * scale
	local y = cy - math.floor(h / 2)
	for i = 1, #text do
		draw_glyph(c, text:sub(i, i), x0, y, scale, col)
		y = y + 9 * scale
	end
end

-------------------------------------------------------------------------------
-- The 9 tiles
-------------------------------------------------------------------------------

local TILES = {
	{id = "nw", row = 0, col = 0, desc = "North-West"},
	{id = "n",  row = 0, col = 1, desc = "North"},
	{id = "ne", row = 0, col = 2, desc = "North-East"},
	{id = "w",  row = 1, col = 0, desc = "West"},
	{id = "c",  row = 1, col = 1, desc = "Center (spawn)"},
	{id = "e",  row = 1, col = 2, desc = "East"},
	{id = "sw", row = 2, col = 0, desc = "South-West"},
	{id = "s",  row = 2, col = 1, desc = "South"},
	{id = "se", row = 2, col = 2, desc = "South-East"},
}

-- Side texture: wooden frame, optionally with a compass word.
local function make_side(word)
	local c = new_canvas(64, 64, FRAME)
	rect(c, 0, 0, 64, 3, FRAME_DARK)
	rect(c, 0, 61, 64, 3, FRAME_DARK)
	rect(c, 0, 0, 3, 64, FRAME_DARK)
	rect(c, 61, 0, 3, 64, FRAME_DARK)
	if word then
		draw_text_h(c, word, 32, 25, 2, TEXT)
	end
	return to_texmod(c)
end

-- Placeholder top (before the first snapshot and in the inventory):
-- parchment with a 3x3 grid and this tile's cell highlighted.
local function make_placeholder(row, col)
	-- no dark pixels on the image edge (they would show as seams)
	local c = new_canvas(16, 16, PARCHMENT)
	local grid = rgb(150, 120, 80)
	for i = 1, 2 do
		rect(c, i * 5, 1, 1, 14, grid)
		rect(c, 1, i * 5, 14, 1, grid)
	end
	rect(c, col * 5 + 1, row * 5 + 1, 4, 4, rgb(190, 60, 50))
	return to_texmod(c)
end

local SIDE_PLAIN = make_side(nil)
local SIDE_WORD = {
	north = make_side("NORTH"),
	south = make_side("SOUTH"),
	east  = make_side("EAST"),
	west  = make_side("WEST"),
}

for _, t in ipairs(TILES) do
	t.placeholder = make_placeholder(t.row, t.col)
	-- Node tile order: +Y, -Y, +X (east), -X (west), +Z (north), -Z (south)
	t.sides = {
		t.col == 2 and SIDE_WORD.east  or SIDE_PLAIN,
		t.col == 0 and SIDE_WORD.west  or SIDE_PLAIN,
		t.row == 0 and SIDE_WORD.north or SIDE_PLAIN,
		t.row == 2 and SIDE_WORD.south or SIDE_PLAIN,
	}
end

-- Current snapshot texture names (nil until the first snapshot exists).
local current_tops = nil

local function top_texture(idx)
	return current_tops and current_tops[idx] or TILES[idx].placeholder
end

-------------------------------------------------------------------------------
-- Display entity (node textures can't change at runtime, entities can)
-------------------------------------------------------------------------------

-- Same textures as the node, except the top shows the current snapshot.
local function entity_textures(idx)
	local t = TILES[idx]
	return {top_texture(idx), SIDE_PLAIN, t.sides[1], t.sides[2], t.sides[3], t.sides[4]}
end

minetest.register_entity(modname .. ":display", {
	initial_properties = {
		visual = "cube",
		-- a bit bigger than the node so it is drawn on top of it
		visual_size = {x = 1.004, y = 1.004, z = 1.004},
		physical = false,
		pointable = false,
		collide_with_objects = false,
		collisionbox = {0, 0, 0, 0, 0, 0},
		selectionbox = {0, 0, 0, 0, 0, 0},
		static_save = false,
		glow = LIGHT,
		textures = {"blank.png", "blank.png", "blank.png", "blank.png", "blank.png", "blank.png"},
	},
	on_activate = function(self, staticdata)
		local idx = tonumber(staticdata)
		if not idx or not TILES[idx] then
			self.object:remove()
			return
		end
		self.tile = idx
		self.object:set_armor_groups({immortal = 1})
		self.object:set_properties({textures = entity_textures(idx)})
	end,
	refresh = function(self)
		self.object:set_properties({textures = entity_textures(self.tile)})
	end,
})

local function find_displays(pos)
	local list = {}
	for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 0.45)) do
		local le = obj:get_luaentity()
		if le and le.name == modname .. ":display" then
			list[#list + 1] = obj
		end
	end
	return list
end

local function ensure_display(pos, idx)
	local list = find_displays(pos)
	for i = 2, #list do list[i]:remove() end
	if not list[1] then
		minetest.add_entity(pos, modname .. ":display", tostring(idx))
	end
end

local function refresh_all_displays()
	for _, le in pairs(minetest.luaentities) do
		if le.name == modname .. ":display" and le.tile then
			le:refresh()
		end
	end
end

-------------------------------------------------------------------------------
-- Nodes
-------------------------------------------------------------------------------

local node_names = {}

for idx, t in ipairs(TILES) do
	local name = modname .. ":map_" .. t.id
	node_names[#node_names + 1] = name
	minetest.register_node(name, {
		description = S("Spawn Map Block") .. " (" .. S(t.desc) .. ")",
		tiles = {t.placeholder, SIDE_PLAIN, t.sides[1], t.sides[2], t.sides[3], t.sides[4]},
		paramtype = "light",
		sunlight_propagates = true,
		light_source = LIGHT,
		is_ground_content = false,
		groups = {oddly_breakable_by_hand = 2, dig_immediate = 2, spawnmap = 1},
		sounds = minetest.global_exists("default") and default.node_sound_wood_defaults() or nil,
		on_construct = function(pos)
			ensure_display(pos, idx)
		end,
		on_destruct = function(pos)
			for _, obj in ipairs(find_displays(pos)) do obj:remove() end
		end,
		_spawnmap_tile = idx,
	})
end

minetest.register_lbm({
	label = "Restore spawn map displays",
	name = modname .. ":restore_display",
	nodenames = node_names,
	run_at_every_load = true,
	action = function(pos, node)
		local def = minetest.registered_nodes[node.name]
		if def and def._spawnmap_tile then
			ensure_display(pos, def._spawnmap_tile)
		end
	end,
})

-------------------------------------------------------------------------------
-- Node colors
-------------------------------------------------------------------------------

-- Checked in order against the node name, first match wins.
local NAME_COLORS = {
	{"lava",               230,  90,  20},
	{"river_water",         60, 125, 215},
	{"water",               40,  90, 190},
	{"ice",                170, 210, 240},
	{"snow",               245, 245, 250},
	{"dry_grass",          178, 165,  85},
	{"coniferous_litter",   85, 105,  55},
	{"rainforest_litter",   60, 115,  40},
	{"grass",               86, 155,  60},
	{"moss",                70, 120,  50},
	{"needles",             35,  85,  45},
	{"leaves",              40, 105,  40},
	{"cactus",              70, 140,  60},
	{"tree",               105,  75,  45},
	{"wood",               160, 120,  75},
	{"desert_sandstone",   195, 140,  95},
	{"silver_sandstone",   200, 200, 185},
	{"sandstone",          210, 190, 140},
	{"desert_sand",        215, 165, 105},
	{"silver_sand",        215, 215, 200},
	{"sand",               225, 205, 145},
	{"permafrost",         110, 100,  85},
	{"dirt",               130,  95,  60},
	{"soil",               110,  80,  50},
	{"gravel",             125, 120, 115},
	{"clay",               165, 160, 175},
	{"desert_stone",       180, 110,  80},
	{"obsidian",            35,  30,  45},
	{"cobble",             115, 115, 115},
	{"brick",              160,  80,  60},
	{"glass",              190, 220, 230},
	{"stone",              128, 128, 128},
}

local GROUP_COLORS = {
	{"lava",   230,  90,  20},
	{"water",   40,  90, 190},
	{"leaves",  40, 105,  40},
	{"tree",   105,  75,  45},
	{"wood",   160, 120,  75},
	{"sand",   225, 205, 145},
	{"soil",   130,  95,  60},
	{"stone",  128, 128, 128},
	{"cracky", 140, 140, 140},
	{"choppy", 150, 115,  75},
	{"crumbly",140, 110,  80},
}

local SKIP_DRAWTYPES = {
	airlike = true, plantlike = true, torchlike = true, signlike = true,
	firelike = true, raillike = true,
}

-- name -> false (treat as air) or {r, g, b, liquid}
local node_info = {}

local function get_info(name)
	local info = node_info[name]
	if info ~= nil then return info end
	info = false
	local def = minetest.registered_nodes[name]
	local skip = name == "air" or name == "ignore" or not def or SKIP_DRAWTYPES[def.drawtype or "normal"]
	if not skip then
		for _, p in ipairs(IGNORE_PATTERNS) do
			if name:find(p) then skip = true break end
		end
	end
	if not skip then
		local lname = name:lower()
		local col
		for _, r in ipairs(NAME_COLORS) do
			if lname:find(r[1], 1, true) then col = r break end
		end
		if not col then
			local groups = def.groups or {}
			for _, r in ipairs(GROUP_COLORS) do
				if (groups[r[1]] or 0) > 0 then col = r break end
			end
		end
		col = col or {"", 150, 145, 135}
		local liquid = (def.liquidtype or "none") ~= "none"
		info = {col[2], col[3], col[4], liquid and not lname:find("lava", 1, true)}
	end
	node_info[name] = info
	return info
end

-------------------------------------------------------------------------------
-- Scanner
-------------------------------------------------------------------------------

local STEP_Y = 4   -- coarse step when searching the surface downward
local job = nil

-- Returns height, r, g, b of the topmost visible node, or nil.
-- `vm` must already contain the column (x, z).
local function scan_column(vm, x, z)
	local p = {x = x, y = YMAX, z = z}

	-- coarse search from the top
	local y = YMAX
	local hit = nil
	while y >= YMIN do
		p.y = y
		if get_info(vm:get_node_at(p).name) then hit = y break end
		y = y - STEP_Y
	end
	if not hit then return nil end

	-- refine: the real top is within [hit, hit + STEP_Y - 1]
	local top = hit
	for yy = math.min(hit + STEP_Y - 1, YMAX), hit + 1, -1 do
		p.y = yy
		if get_info(vm:get_node_at(p).name) then top = yy break end
	end
	p.y = top
	local info = get_info(vm:get_node_at(p).name)
	local r, g, b = info[1], info[2], info[3]

	if info[4] then
		-- water: darker the deeper it is
		local depth = 0
		local yy = top - 1
		while yy >= YMIN and depth < 24 do
			p.y = yy
			local i2 = get_info(vm:get_node_at(p).name)
			if not (i2 and i2[4]) then break end
			depth = depth + 1
			yy = yy - 1
		end
		local f = 1.15 - math.min(depth, 24) / 24 * 0.55
		r, g, b = r * f, g * f, b * f
	end
	return top, r, g, b
end

local function log(msg)
	minetest.log("action", "[spawnmap] " .. msg)
end

local function start_job(reason)
	if job then return false end
	local cx, cz = get_center()
	local size = TILE * 3
	local fs = math.max(1, math.floor(TILE / 64))
	local margin = 10 * fs
	local n = size - 2 * margin
	local step = 2 * RADIUS / n

	-- Group the sample columns by mapblock (16x16 nodes), so each mapblock
	-- column is read from the map only once, however many pixels it holds.
	local function groups(origin, sign)
		local list, last = {}, nil
		for i = 0, n - 1 do
			local coord = math.floor(origin + sign * (i + 0.5) * step)
			local b = math.floor(coord / 16)
			if b ~= last then
				list[#list + 1] = {b = b, idx = {}, coord = {}}
				last = b
			end
			local g = list[#list]
			g.idx[#g.idx + 1] = i
			g.coord[#g.coord + 1] = coord
		end
		return list
	end

	job = {
		cx = cx, cz = cz, size = size, fs = fs, margin = margin, n = n,
		step = step, k = 0, total = n * n,
		gx = groups(cx - RADIUS, 1), gz = groups(cz + RADIUS, -1), gxi = 1, gzi = 1,
		h = {}, r = {}, g = {}, b = {},
		started = os.time(), clock = os.clock(), last_pct = -1,
	}
	log(("snapshot started (%s): center %d,%d radius %d, Y %d..%d, %dx%d samples")
		:format(reason or "timer", cx, cz, RADIUS, YMIN, YMAX, n, n))
	return true
end

-------------------------------------------------------------------------------
-- Rendering the finished snapshot
-------------------------------------------------------------------------------

-- The only thing written to the world folder: the snapshot archive.
local function archive_dir()
	return minetest.get_worldpath() .. DIR_DELIM .. "spawnmap_archive"
end

local function tile_filename(snap_id, idx)
	return ("spawnmap_snap_%d_%s.png"):format(snap_id, TILES[idx].id)
end

local function compose(j)
	local size, n, m, fs = j.size, j.n, j.margin, j.fs
	local c = new_canvas(size, size, FRAME)

	-- map area
	for iy = 0, n - 1 do
		for ix = 0, n - 1 do
			local k = iy * n + ix + 1
			local h = j.h[k]
			local col
			if h then
				local shade = 1
				if ix > 0 and iy > 0 then
					local hn = j.h[k - n - 1]
					if hn then
						shade = 1 + math.max(-0.3, math.min(0.3, (h - hn) * 0.06))
					end
				end
				col = rgb(j.r[k] * shade, j.g[k] * shade, j.b[k] * shade)
			else
				col = ((ix + iy) % 2 == 0) and UNKNOWN_A or UNKNOWN_B
			end
			c[(iy + m) * size + ix + m + 1] = col
		end
	end

	-- frame line around the map area. No dark pixels on the outer image
	-- edge: mipmapping wraps textures, so they would bleed onto the
	-- opposite edge of the tile and show up as seams.
	rect(c, m - 1, m - 1, n + 2, 1, FRAME_DARK)
	rect(c, m - 1, m + n, n + 2, 1, FRAME_DARK)
	rect(c, m - 1, m - 1, 1, n + 2, FRAME_DARK)
	rect(c, m + n, m - 1, 1, n + 2, FRAME_DARK)

	-- compass words on the frame
	local ty = math.floor((m - 7 * fs) / 2)
	local tx = math.floor((m - 5 * fs) / 2)
	local mid = math.floor(size / 2)
	draw_text_h(c, "NORTH", mid, ty, fs, TEXT)
	draw_text_h(c, "SOUTH", mid, size - m + ty, fs, TEXT)
	draw_text_v(c, "WEST", tx, mid, fs, TEXT)
	draw_text_v(c, "EAST", size - m + tx, mid, fs, TEXT)

	-- spawn marker
	local sm = m + math.floor(n / 2)
	for d = -2 * fs, 2 * fs do
		plot(c, sm + d, sm, MARKER)
		plot(c, sm, sm + d, MARKER)
	end
	return c
end

local function slice(c, row, col)
	local t = new_canvas(TILE, TILE, 0)
	for y = 0, TILE - 1 do
		local src = (row * TILE + y) * c.w + col * TILE
		local dst = y * TILE
		for x = 1, TILE do
			t[dst + x] = c[src + x]
		end
	end
	return t
end

-- The current tiles live in mod storage (not as files): they are sent to
-- clients straight from memory, then the displays switch to them.
local function publish(snap_id, on_done)
	local names = {}
	for idx = 1, #TILES do
		local fname = tile_filename(snap_id, idx)
		local data = minetest.decode_base64(storage:get_string("tile_" .. idx))
		if not data or data == "" then
			return false
		end
		local ok = minetest.dynamic_add_media({
			filename = fname,
			filedata = data,
			ephemeral = false,
		}, function() end)
		if not ok then
			minetest.log("error", "[spawnmap] could not add media " .. fname)
			return false
		end
		names[idx] = fname
	end
	-- give connected clients a moment to download the new textures
	minetest.after(2, function()
		current_tops = names
		refresh_all_displays()
		if on_done then on_done() end
	end)
	return true
end

-- Keep every snapshot as one full 3x3 image in <world>/spawnmap_archive/.
-- Names start with the date, so alphabetical order = chronological order.
local function archive_snapshot(c, snap_id, started)
	local adir = archive_dir()
	minetest.mkdir(adir)
	local fname = ("spawnmap_%s_%04d.png"):format(os.date("%Y-%m-%d_%H-%M", started), snap_id)
	if not minetest.safe_file_write(adir .. DIR_DELIM .. fname, to_png(c)) then
		minetest.log("error", "[spawnmap] could not write archive " .. fname)
		return
	end
	if ARCHIVE_MAX > 0 then
		local files = {}
		for _, f in ipairs(minetest.get_dir_list(adir, false) or {}) do
			if f:match("^spawnmap_.*%.png$") then files[#files + 1] = f end
		end
		table.sort(files)
		for i = 1, #files - ARCHIVE_MAX do
			os.remove(adir .. DIR_DELIM .. files[i])
		end
	end
end

local function finish_job()
	local j = job
	local c = compose(j)
	local snap_id = storage:get_int("snap_id") + 1
	for idx, t in ipairs(TILES) do
		local png = to_png(slice(c, t.row, t.col))
		storage:set_string("tile_" .. idx, minetest.encode_base64(png))
	end
	if ARCHIVE then
		archive_snapshot(c, snap_id, j.started)
	end
	storage:set_int("snap_id", snap_id)
	storage:set_int("last_time", j.started)
	job = nil
	local known = 0
	for k = 1, j.total do if j.h[k] then known = known + 1 end end
	log(("snapshot #%d done in %ds (%d%% of the area explored)")
		:format(snap_id, os.time() - j.started, math.floor(known * 100 / j.total)))
	publish(snap_id, function()
		minetest.chat_send_all(minetest.colorize("#e0c080", "[spawnmap] ") ..
			S("The spawn map has been updated."))
	end)
end

local function process_job()
	local j = job
	local t0 = os.clock()
	local n = j.n
	while j.gzi <= #j.gz and os.clock() - t0 < BUDGET do
		local gx, gz = j.gx[j.gxi], j.gz[j.gzi]
		-- one mapblock column, all samples inside it
		local vm = minetest.get_voxel_manip(
			{x = gx.b * 16, y = YMIN, z = gz.b * 16},
			{x = gx.b * 16 + 15, y = YMAX, z = gz.b * 16 + 15})
		for a = 1, #gz.idx do
			local iy, z = gz.idx[a], gz.coord[a]
			for c = 1, #gx.idx do
				local ix, x = gx.idx[c], gx.coord[c]
				local k = iy * n + ix + 1
				local h, r, g, b = scan_column(vm, x, z)
				if h then
					j.h[k], j.r[k], j.g[k], j.b[k] = h, r, g, b
				end
				j.k = j.k + 1
			end
		end
		j.gxi = j.gxi + 1
		if j.gxi > #j.gx then
			j.gxi = 1
			j.gzi = j.gzi + 1
		end
	end
	local pct = math.floor(j.k * 100 / j.total)
	if pct >= j.last_pct + 10 then
		j.last_pct = pct
		log(("snapshot progress %d%%"):format(pct))
	end
	if j.k >= j.total then
		finish_job()
	end
end

-------------------------------------------------------------------------------
-- Scheduling
-------------------------------------------------------------------------------

local check_timer = 0

minetest.register_globalstep(function(dtime)
	if job then
		process_job()
		return
	end
	check_timer = check_timer + dtime
	if check_timer < 30 then return end
	check_timer = 0
	if os.time() - storage:get_int("last_time") >= INTERVAL then
		start_job("daily")
	end
end)

-- On startup: re-announce the latest snapshot from mod storage.
minetest.after(0, function()
	local snap_id = storage:get_int("snap_id")
	if snap_id > 0 and not publish(snap_id) then
		-- tiles missing: take a new snapshot soon
		storage:set_int("last_time", 0)
	end
end)

-------------------------------------------------------------------------------
-- Chat commands
-------------------------------------------------------------------------------

minetest.register_chatcommand("spawnmap_update", {
	description = S("Take a new spawn map snapshot now"),
	privs = {server = true},
	func = function()
		if start_job("manual") then
			return true, S("Spawn map snapshot started.")
		end
		return false, S("A snapshot is already in progress.")
	end,
})

minetest.register_chatcommand("spawnmap_status", {
	description = S("Show spawn map snapshot status"),
	func = function()
		if job then
			return true, ("Snapshot in progress: %d%%"):format(math.floor(job.k * 100 / job.total))
		end
		local last = storage:get_int("last_time")
		if last == 0 then
			return true, "No snapshot yet."
		end
		local left = math.max(0, INTERVAL - (os.time() - last))
		return true, ("Snapshot #%d taken %s. Next in %d min."):format(
			storage:get_int("snap_id"), os.date("%Y-%m-%d %H:%M", last), math.ceil(left / 60))
	end,
})

minetest.register_chatcommand("spawnmap_kit", {
	description = S("Give yourself the 9 spawn map blocks"),
	privs = {give = true},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false end
		local inv = player:get_inventory()
		for _, nn in ipairs(node_names) do
			local left = inv:add_item("main", nn)
			if not left:is_empty() then
				minetest.add_item(player:get_pos(), left)
			end
		end
		return true, S("Place them as a 3x3 square, North-West block at the north-west corner.")
	end,
})
