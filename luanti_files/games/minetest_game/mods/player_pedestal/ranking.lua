-- Rankings for the podiums, kept incrementally.
--
-- A full scan of a statistics storage runs once at startup (and on demand).
-- After that the statistics mods' own update functions are wrapped: every
-- change of a player's value costs a comparison against a top-10 buffer
-- (a few table lookups). Only a decrease that pushes a buffered player out of
-- the buffer marks the stat for a rescan, which happens lazily and only while
-- a podium of that stat is loaded.
--
-- A podium type exists only if its statistic exists on the server:
--   xp     -> cb_xp (Cubeborn experience)
--   kills  -> atl_server_statistics "Kills Count"
--   placed -> atl_server_statistics "Nodes Placed"
-- Other mods can add sources with player_pedestal.ranking.register_source().

local S = player_pedestal.S
local R = {}
player_pedestal.ranking = R

local BUF = 10
R.sources = {}      -- stat -> def {label, unit, scan = fn() -> {name = value}}
R.order = {}        -- registration order of stats
R.tops = {}         -- stat -> array {name, value}, sorted desc, <= BUF
R.version = {}      -- stat -> counter, bumped when the visible top-3 changes
local dirty = {}    -- stat -> true when a rescan is needed
local scanned = {}  -- stat -> true after the first scan

local excluded = {}
for n in (minetest.settings:get("player_pedestal.rank_exclude") or ""):gmatch("[^,%s]+") do
	excluded[n] = true
end

local function valid_name(n)
	return type(n) == "string" and n:match("^[%w_%-]+$") ~= nil and not excluded[n]
end

local function sort(top)
	table.sort(top, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.name < b.name
	end)
end

local function top3_signature(top)
	local t = {}
	for i = 1, 3 do
		if top[i] then
			t[#t + 1] = top[i].name .. "=" .. top[i].value
		end
	end
	return table.concat(t, ";")
end

local sig = {}
local function touch(stat)
	local s = top3_signature(R.tops[stat])
	if s ~= sig[stat] then
		sig[stat] = s
		R.version[stat] = (R.version[stat] or 0) + 1
	end
end

function R.register_source(stat, def)
	if R.sources[stat] then
		return
	end
	R.sources[stat] = def
	R.order[#R.order + 1] = stat
	R.tops[stat] = {}
	R.version[stat] = 0
	dirty[stat] = true
end

function R.has(stat)
	return R.sources[stat] ~= nil
end

function R.rescan(stat)
	local def = R.sources[stat]
	if not def then
		return
	end
	local values = def.scan() or {}
	local top = {}
	for name, value in pairs(values) do
		value = tonumber(value) or 0
		if value > 0 and valid_name(name) then
			top[#top + 1] = { name = name, value = value }
		end
	end
	sort(top)
	for i = #top, BUF + 1, -1 do
		top[i] = nil
	end
	R.tops[stat] = top
	dirty[stat] = nil
	scanned[stat] = true
	touch(stat)
end

-- Called on every change of a player's value.
function R.update(stat, name, value)
	local top = R.tops[stat]
	if not top or not scanned[stat] or not valid_name(name) then
		return
	end
	value = tonumber(value) or 0
	local idx
	for i = 1, #top do
		if top[i].name == name then
			idx = i
			break
		end
	end
	if idx then
		if value <= 0 then
			table.remove(top, idx)
			if #top >= BUF - 1 then
				dirty[stat] = true
			end
		else
			local old = top[idx].value
			top[idx].value = value
			sort(top)
			-- A full buffer may hide players outside it; if this player
			-- dropped to the last slot, one of them could be ahead now.
			if value < old and #top >= BUF and top[#top].name == name then
				dirty[stat] = true
			end
		end
	else
		if value <= 0 then
			return
		end
		if #top < BUF or value > top[#top].value then
			top[#top + 1] = { name = name, value = value }
			sort(top)
			top[BUF + 1] = nil
		else
			return
		end
	end
	touch(stat)
end

-- Top-3 for display; runs a pending rescan first.
function R.get_top3(stat)
	if dirty[stat] then
		R.rescan(stat)
	end
	local top, out = R.tops[stat] or {}, {}
	for i = 1, 3 do
		out[i] = top[i]
	end
	return out
end

-- Experience: Cubeborn cb_xp (one int per player name in its storage).

if minetest.global_exists("cb_xp") and cb_xp.storage and cb_xp.register_on_change then
	R.register_source("xp", {
		label = S("Experience"),
		unit = S("XP"),
		scan = function()
			local out = {}
			for key, v in pairs(cb_xp.storage:to_table().fields) do
				if key:match("^[%w_%-]+$") then
					out[key] = tonumber(v)
				end
			end
			return out
		end,
	})
	cb_xp.register_on_change(function(name, _, new)
		R.update("xp", name, new)
	end)
end

-- Kills and placed nodes: atl_server_statistics (keys "<name>_<Stat>").

local atl = rawget(_G, "atl_server_statistics")
if atl and atl.mod_storage and atl.increment_value then
	local map = {}    -- atl stat key -> our stat
	local function enabled(setting)
		return not minetest.settings:get_bool("atl_server_statistics." .. setting, false)
	end
	if enabled("disable_kill_count_and_death_count") then
		map["Kills Count"] = "kills"
		R.register_source("kills", { label = S("Kills"), unit = S("kills") })
	end
	if enabled("register_on_placenode") then
		map["Nodes Placed"] = "placed"
		R.register_source("placed", { label = S("Placed blocks"), unit = S("blocks") })
	end

	-- One storage pass serves every atl-based stat.
	local function scan_atl()
		local res = {}
		for _, stat in pairs(map) do
			res[stat] = {}
		end
		for key, v in pairs(atl.mod_storage:to_table().fields) do
			for akey, stat in pairs(map) do
				local n = #akey + 1
				if key:sub(-n) == "_" .. akey then
					res[stat][key:sub(1, -n - 1)] = tonumber(v)
					break
				end
			end
		end
		return res
	end
	local cache
	for _, stat in pairs(map) do
		R.sources[stat].scan = function()
			-- both atl stats are usually rescanned together at startup
			cache = cache or scan_atl()
			local r = cache[stat]
			minetest.after(0, function() cache = nil end)
			return r
		end
	end

	if next(map) then
		local orig_inc = atl.increment_value
		atl.increment_value = function(player_name, key, amount)
			local new = orig_inc(player_name, key, amount)
			local stat = map[key]
			if stat and new then
				R.update(stat, player_name, new)
			end
			return new
		end
		local orig_reset = atl.reset_player_stats
		if orig_reset then
			atl.reset_player_stats = function(player_name, ...)
				local r = orig_reset(player_name, ...)
				for _, stat in pairs(map) do
					R.update(stat, player_name, 0)
				end
				return r
			end
		end
	end
end

-- Initial scans, once the server is running.
minetest.after(1, function()
	for _, stat in ipairs(R.order) do
		R.rescan(stat)
	end
	minetest.log("action", "[player_pedestal] rankings ready: " .. table.concat(R.order, ", "))
end)
