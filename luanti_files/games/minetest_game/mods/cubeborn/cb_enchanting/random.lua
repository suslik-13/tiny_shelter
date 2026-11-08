-- Random enchantments (spec 4.3), ported from Mineclonia mcl_enchanting/engine.lua.
local E = cb_enchanting

local function rnd(rand, a, b)
	if a then
		return rand and rand:next(a, b) or math.random(a, b)
	end
	return rand and (rand:next() + 2147483648) / 4294967295 or math.random()
end
E.rnd = rnd

local NAMES = {}
for name in pairs(E.DEFS) do
	NAMES[#NAMES + 1] = name
end
table.sort(NAMES)

local function power_level(def, level)
	for i = def.max, 1, -1 do
		local r = def.power[i]
		if r and level >= r[1] and level <= r[2] then
			return i
		end
	end
	return nil
end

-- Like Minecraft, only enchantments with a level for this power are in the pool.
local function pick_one(itemname, have, treasure, rand, level)
	local pool = {}
	for _, n in ipairs(NAMES) do
		local def = E.DEFS[n]
		local ok = E.can_add_to(itemname, have, n, 1)
		local _, primary = E.supports(itemname, n)
		if ok and (primary or (treasure and def.treasure)) and power_level(def, level) then
			for _ = 1, def.weight do
				pool[#pool + 1] = n
			end
		end
	end
	return #pool > 0 and pool[rnd(rand, 1, #pool)] or nil
end

-- Enchantments a roll of `power` (1..30 on the table) gives the item, or nil.
function E.random(stack, power, treasure, rand)
	local itemname = stack:get_name()
	if not E.class(itemname) then
		return nil
	end
	local ea = E.enchantability(itemname)
	local level = power + 1 + rnd(rand, 0, math.floor(ea / 4)) + rnd(rand, 0, math.floor(ea / 4))
	level = level + level * (rnd(rand) + rnd(rand) - 1) * 0.15
	level = math.max(math.floor(level + 0.5), 1) * 2
	local have = {}
	repeat
		level = math.floor(level / 2)
		if level == 0 then
			break
		end
		local n = pick_one(itemname, have, treasure, rand, level)
		if not n then
			break
		end
		have[n] = power_level(E.DEFS[n], level)
	until rnd(rand) >= (level + 1) / 50
	return next(have) and have or nil
end

-- Rolls until something comes out (at most 20 tries) and enchants the stack.
function E.enchant_randomly(stack, power, treasure, rand)
	for _ = 1, 20 do
		local t = E.random(stack, power, treasure, rand)
		if t then
			return E.set(stack, t)
		end
	end
	return stack
end
