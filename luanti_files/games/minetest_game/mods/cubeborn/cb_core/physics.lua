-- Physics factors that several features may hold at once (elytra gliding,
-- levitation, slowness): per field (gravity, speed) they multiply. With
-- player_monoids each is a named change of the field's monoid; without, the
-- product is applied over the base value: the worn 3d_armor's value, else
-- what the player had when the first factor came, and the base comes back
-- when none is left.
local P = {}
cb_core.physics = P
local monoids = rawget(_G, "player_monoids")
P.monoids = { gravity = monoids and monoids.gravity or nil, speed = monoids and monoids.speed or nil,
	jump = monoids and monoids.jump or nil, }
P.monoid = P.monoids.gravity -- kept for callers that only know gravity

local held, bases = {}, {}

local function monoid(field)
	if field == "gravity" then
		return P.monoid
	end
	return P.monoids[field]
end

local function base(name, field)
	-- rawget: armor.def hands out defaults for players it does not know
	local armor = rawget(_G, "armor")
	local def = armor and type(armor.def) == "table" and rawget(armor.def, name)
	local v = type(def) == "table" and rawget(def, field)
	local b = bases[name]
	return type(v) == "number" and v or b and b[field] or 1
end

function P.factors(player, field)
	local h = held[player:get_player_name()]
	return h and h[field or "gravity"] or {}
end

local function apply(player, field)
	local v = base(player:get_player_name(), field)
	for _, f in pairs(P.factors(player, field)) do
		v = v * f
	end
	player:set_physics_override({ [field] = v, })
end

function P.set_factor(player, field, key, factor)
	local name = player:get_player_name()
	held[name] = held[name] or {}
	bases[name] = bases[name] or {}
	if not held[name][field] then
		held[name][field] = {}
		bases[name][field] = player:get_physics_override()[field]
	end
	held[name][field][key] = factor
	local m = monoid(field)
	if m then
		m:add_change(player, factor, "cubeborn:" .. key)
	else
		apply(player, field)
	end
end

function P.clear_factor(player, field, key)
	local name = player:get_player_name()
	local h = held[name] and held[name][field]
	if not h or h[key] == nil then
		return
	end
	h[key] = nil
	local empty = next(h) == nil
	if empty then
		held[name][field] = nil
	end
	local m = monoid(field)
	if m then
		m:del_change(player, "cubeborn:" .. key)
	else
		apply(player, field)
	end
	if empty and bases[name] then
		bases[name][field] = nil
	end
end

function P.set_gravity(player, key, factor)
	P.set_factor(player, "gravity", key, factor)
end

function P.clear_gravity(player, key)
	P.clear_factor(player, "gravity", key)
end

-- 3d_armor sets physics directly when the armor changes; put the held
-- factors back over its new values.
core.register_on_mods_loaded(function()
	local armor = rawget(_G, "armor")
	if not (armor and armor.set_player_armor) then
		return
	end
	local set_player_armor = armor.set_player_armor
	armor.set_player_armor = function(self, player, ...)
		set_player_armor(self, player, ...)
		local h = player and player.get_player_name and held[player:get_player_name()]
		for field in pairs(h or {}) do
			if not monoid(field) then
				apply(player, field)
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	held[name] = nil
	bases[name] = nil
end)
