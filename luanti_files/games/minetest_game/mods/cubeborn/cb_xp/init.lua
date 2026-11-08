-- Experience (spec 2026-10-20-xp-design): one counter per player in this
-- mod's storage (so commands and the leaderboard work for offline players),
-- Minecraft levels, /xp and the admin command /cb_xp.
cb_xp = {}
local X = cb_xp
local S = core.get_translator("cb_xp")
X.S = S
local storage = core.get_mod_storage()
X.storage = storage

-- Gear thresholds (levels), shown by /xp as the next goal.
X.THRESHOLDS = { 5, 10, 15, 20, 25, 30, }

-- Points a level-up from `level` costs (Minecraft).
local function cost(level)
	if level <= 15 then
		return 2 * level + 7
	elseif level <= 30 then
		return 5 * level - 38
	end
	return 9 * level - 158
end

function X.points_for(level)
	local sum = 0
	for l = 0, level - 1 do
		sum = sum + cost(l)
	end
	return sum
end

-- Level of `points`, points into that level and the cost of the next one.
function X.level_of(points)
	local level = 0
	while points >= cost(level) do
		points = points - cost(level)
		level = level + 1
	end
	return level, points, cost(level)
end

function X.get(name)
	return storage:get_int(name)
end

local listeners = {}

function X.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

function X.set(name, n)
	local old = X.get(name)
	n = math.max(0, math.floor(n))
	storage:set_int(name, n)
	if n ~= old then
		for _, fn in ipairs(listeners) do
			fn(name, old, n)
		end
	end
	return n
end

function X.add(name, delta)
	return X.set(name, X.get(name) + delta)
end

function X.spend(name, n)
	if X.get(name) < n then
		return false
	end
	X.set(name, X.get(name) - n)
	return true
end

function X.is_admin(name)
	return core.check_player_privs(name, { cb_admin = true, }) or core.check_player_privs(name, { server = true, })
end

-- Chat message, at most once per 3 s for the same player and text.
local last = {}

function X.notify(name, msg)
	local key, now = name .. "\0" .. msg, core.get_us_time() / 1e6
	if last[key] and now - last[key] < 3 then
		return
	end
	last[key] = now
	core.chat_send_player(name, msg)
end

core.register_on_leaveplayer(function(player)
	local prefix = player:get_player_name() .. "\0"
	for key in pairs(last) do
		if key:sub(1, #prefix) == prefix then
			last[key] = nil
		end
	end
end)

function X.describe(name)
	local points = X.get(name)
	local level = X.level_of(points)
	local msg = S("@1: level @2 (@3 points)", name, level, points)
	for _, t in ipairs(X.THRESHOLDS) do
		if t > level then
			return msg .. ", " .. S("next gear at level @1", t)
		end
	end
	return msg
end

core.register_chatcommand("xp", {
	params = S("[<player>]"),
	description = S("Show experience"),
	func = function(name, param)
		local who = param:match("^%s*(%S+)") or name
		if not core.player_exists(who) then
			return false, S("Unknown player: @1", who)
		end
		return true, X.describe(who)
	end,
})

core.register_chatcommand("cb_xp", {
	params = S("<player> <+N|-N>"),
	description = S("Give or take experience"),
	privs = { cb_admin = true, },
	func = function(name, param)
		local who, n = param:match("^%s*(%S+)%s+([+-]?%d+)%s*$")
		if not who then
			return false, S("Usage: /cb_xp <player> <+N|-N>")
		end
		if not core.player_exists(who) then
			return false, S("Unknown player: @1", who)
		end
		local new = X.add(who, tonumber(n))
		core.log("action", ("[cb_xp] %s changed the experience of %s by %s to %d"):format(name, who, n, new))
		return true, X.describe(who)
	end,
})

local modpath = core.get_modpath("cb_xp")
dofile(modpath .. "/hud.lua")
dofile(modpath .. "/orb.lua")
dofile(modpath .. "/sources.lua")
dofile(modpath .. "/tiers.lua")
dofile(modpath .. "/gates.lua")
dofile(modpath .. "/anvil.lua")
dofile(modpath .. "/board.lua")
