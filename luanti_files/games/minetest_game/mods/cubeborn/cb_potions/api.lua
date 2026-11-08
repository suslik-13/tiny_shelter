-- Potion names, levels and what drinking or a splash does. An item name is
-- cb_potions:<kind>[_long|_strong][_splash|_lingering].
local CP = cb_potions
local E = cb_core.effects
local PREFIX = "cb_potions:"

function CP.name(kind, variant, form)
	return PREFIX .. kind .. (variant and "_" .. variant or "") .. (form and "_" .. form or "")
end

-- kind, variant, form of a potion item; nil for anything else.
function CP.parse(item)
	if type(item) ~= "string" or item:sub(1, #PREFIX) ~= PREFIX then
		return nil
	end
	local rest, form = item:sub(#PREFIX + 1), nil
	for _, f in ipairs({ "splash", "lingering", }) do
		if rest:sub(-#f - 1) == "_" .. f then
			rest, form = rest:sub(1, -#f - 2), f
		end
	end
	local variant
	for _, v in ipairs({ "long", "strong", }) do
		if rest:sub(-#v - 1) == "_" .. v then
			rest, variant = rest:sub(1, -#v - 2), v
		end
	end
	local k = CP.KINDS[rest]
	if not k or (variant and not k[variant]) or (form and not (k.effects or k.instant)) then
		return nil
	end
	return rest, variant, form
end

function CP.throwable(kind)
	local k = CP.KINDS[kind]
	return k ~= nil and (k.effects ~= nil or k.instant ~= nil)
end

-- Experience points a brew of the item costs: each kind its own price; a
-- long potion half as much again, II twice, splash +5 (harmful +50: they
-- are meant to be dear), lingering 15 more; at most 80.
CP.XP_BASE = {
	water = 1, awkward = 1, mundane = 1, thick = 1,
	water_breathing = 2, night_vision = 2, swiftness = 3, leaping = 3, healing = 4, weakness = 4,
	fire_resistance = 5, slow_falling = 5, slowness = 5, invisibility = 6, poison = 6,
	strength = 8, regeneration = 8, harming = 8,
	wind_charged = 10, weaving = 10, oozing = 10, infestation = 10, turtle_master = 12,
}
CP.XP_LONG, CP.XP_STRONG, CP.XP_SPLASH, CP.XP_SPLASH_HARMFUL, CP.XP_LINGERING, CP.XP_MAX = 0.5, 2, 5, 50, 15, 80

function CP.xp_cost(item)
	local kind, variant, form = CP.parse(item)
	if not kind then
		return 0
	end
	local base = CP.XP_BASE[kind] or 1
	local n = base
	if variant == "long" then
		n = n + math.ceil(base * CP.XP_LONG)
	elseif variant == "strong" then
		n = n * CP.XP_STRONG
	end
	if form then
		n = n + (CP.KINDS[kind].harmful and CP.XP_SPLASH_HARMFUL or CP.XP_SPLASH)
	end
	if form == "lingering" then
		n = n + CP.XP_LINGERING
	end
	return math.min(n, CP.XP_MAX)
end

-- The experience level needed to brew the item (0 for anything else).
function CP.level(item)
	local kind, variant, form = CP.parse(item)
	if not kind then
		return 0
	end
	local k = CP.KINDS[kind]
	if form and k.harmful then
		return 30
	end
	local lvl = k.base
	if variant == "long" then
		lvl = math.max(lvl, lvl == 0 and 5 or 15)
	elseif variant == "strong" then
		lvl = math.max(lvl, CP.MIGHTY[kind] and 25 or 15)
	end
	if form == "splash" then
		lvl = math.max(lvl, 15)
	elseif form == "lingering" then
		lvl = math.max(lvl, 20)
	end
	return lvl
end

local function slot(variant)
	return variant == "long" and 2 or variant == "strong" and 3 or 1
end

-- The effects of an item: { { effect, level, seconds }, ... }, and the
-- instant HP change (or nil).
function CP.effects_of(item)
	local kind, variant = CP.parse(item)
	local k = kind and CP.KINDS[kind]
	if not k then
		return {}, nil
	end
	local list = {}
	for _, e in ipairs(k.effects or {}) do
		local level = variant == "strong" and (e[3] or e[2]) or e[2]
		list[#list + 1] = { e[1], level, k.dur[slot(variant)], }
	end
	local instant = k.instant and k.instant * (variant == "strong" and 2 or 1) or nil
	return list, instant
end

-- A thrown potion's share: durations and the instant change times factor
-- (0..1); lasting_only leaves out the instant change. Lasting effects reach
-- players only (spec 4.4a.2).
function CP.apply(obj, item, factor, lasting_only)
	local list, instant = CP.effects_of(item)
	if instant and not lasting_only then
		local n = math.floor(instant * factor + (instant > 0 and 0.5 or -0.5))
		if n ~= 0 then
			E.instant(obj, n)
		end
	end
	if obj:is_player() then
		for _, e in ipairs(list) do
			local secs = e[3] * factor
			if secs >= 1 then
				E.apply(obj, e[1], e[2], secs)
			end
		end
	end
end

function CP.drink(player, item)
	CP.apply(player, item, 1)
end
