-- the_tiny_spawn: one-shot cyberpunk spawn generator for tiny SHELTER
the_tiny_spawn = {}
local MN = "the_tiny_spawn"
local path = minetest.get_modpath(MN)

dofile(path .. "/nodes.lua")
dofile(path .. "/machines.lua")
the_tiny_spawn.layout = dofile(path .. "/layout.lua")
local G = dofile(path .. "/generator.lua")
the_tiny_spawn.generate = G.generate
the_tiny_spawn.undo = G.undo
the_tiny_spawn.scan = G.scan
the_tiny_spawn.status = G.status

local function default_radius()
	return tonumber(minetest.settings:get(MN .. "_radius")) or 60
end

-- "<x> <y> <z> [radius] [force]" or "here [radius] [force]"
local function parse_args(name, param)
	local words = param:split(" ")
	local pos, rest
	if words[1] == "here" then
		local pl = minetest.get_player_by_name(name)
		if not pl then return nil, "player not found" end
		pos = vector.round(pl:get_pos())
		rest = 2
	else
		local x, y, z = tonumber(words[1]), tonumber(words[2]), tonumber(words[3])
		if not (x and y and z) then return nil end
		pos = {x = x, y = y, z = z}
		rest = 4
	end
	local R, force = default_radius(), false
	for i = rest, #words do
		if words[i] == "force" then force = true
		elseif tonumber(words[i]) then R = math.floor(tonumber(words[i])) end
	end
	if R < 40 or R > 120 then return nil, "radius must be between 40 and 120" end
	return pos, R, force
end

local USAGE = "<x> <y> <z> [radius] [force]  |  here [radius] [force]   " ..
	"(x y z = point where players stand, e.g. static_spawnpoint 0 4 0)"

minetest.register_chatcommand("tiny_spawn_generate", {
	params = USAGE,
	description = "Generate the cyberpunk spawn once (square of ±radius around the point).",
	privs = {server = true},
	func = function(name, param)
		local pos, R, force = parse_args(name, param)
		if not pos then return false, (R or ("Usage: /tiny_spawn_generate " .. USAGE)) end
		minetest.chat_send_player(name, ("[tiny_spawn] Generating at %s, radius %d... the server may freeze for a few seconds.")
			:format(minetest.pos_to_string(pos), R))
		G.generate(pos, R, {force = force, owner = name}, function(ok, msg)
			minetest.chat_send_player(name, "[tiny_spawn] " .. msg)
			if ok then
				minetest.chat_send_player(name, ("[tiny_spawn] Tip: static_spawnpoint = %d,%d,%d puts new players into the beam.")
					:format(pos.x, pos.y, pos.z))
			end
		end)
		return true
	end,
})

minetest.register_chatcommand("tiny_spawn_scan", {
	params = USAGE,
	description = "Show railway nodes found in the spawn area (changes nothing).",
	privs = {server = true},
	func = function(name, param)
		local pos, R = parse_args(name, param)
		if not pos then return false, (R or ("Usage: /tiny_spawn_scan " .. USAGE)) end
		G.scan(pos, R, function(total, names, levels, dirs)
			local out = {("[tiny_spawn] %d railway nodes in the area"):format(total)}
			for n, c in pairs(names) do out[#out + 1] = ("  %s: %d"):format(n, c) end
			local lv = {}
			for h, c in pairs(levels) do lv[#lv + 1] = ("h%+d:%d"):format(h, c) end
			table.sort(lv)
			out[#out + 1] = "  heights relative to the floor (h+1 = standing on the floor): " .. table.concat(lv, " ")
			out[#out + 1] = ("  by direction: N=%d E=%d S=%d W=%d centre=%d"):format(dirs.N, dirs.E, dirs.S, dirs.W, dirs.C)
			minetest.chat_send_player(name, table.concat(out, "\n"))
		end)
		return true, "[tiny_spawn] scanning..."
	end,
})

minetest.register_chatcommand("tiny_spawn_undo", {
	description = "Restore the area as it was before the spawn was generated.",
	privs = {server = true},
	func = function(name)
		G.undo(function(ok, msg) minetest.chat_send_player(name, "[tiny_spawn] " .. msg) end)
		return true, "[tiny_spawn] restoring..."
	end,
})

minetest.register_chatcommand("tiny_spawn_status", {
	description = "Show whether the spawn has been generated.",
	privs = {server = true},
	func = function()
		local st = G.status()
		if not st then return true, "[tiny_spawn] not generated yet" end
		return true, ("[tiny_spawn] generated at %s, radius %d, %s"):format(
			minetest.pos_to_string(st.center), st.R, os.date("%Y-%m-%d %H:%M", st.time))
	end,
})
