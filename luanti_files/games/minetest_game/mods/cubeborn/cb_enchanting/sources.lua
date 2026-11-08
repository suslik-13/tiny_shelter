-- Where else enchantments come from (spec 4.7): chest loot, dungeon chests
-- and (trading.lua's hook) villagers. A uniform roll is Minecraft's
-- enchant_randomly: any enchantment the item takes, treasure and curses
-- included, at a random level.
local E = cb_enchanting
local BOOK = "cb_enchanting:book"

local NAMES = {}
for name in pairs(E.DEFS) do
	NAMES[#NAMES + 1] = name
end
table.sort(NAMES)

-- One random enchantment the stack can take (none of `exclude`), or nil.
function E.uniform_pick(stack, exclude, rand)
	local pool = {}
	for _, n in ipairs(NAMES) do
		if not (exclude and table.indexof(exclude, n) > 0) and E.can_add(stack, n, 1) then
			pool[#pool + 1] = n
		end
	end
	if #pool == 0 then
		return nil
	end
	local n = pool[E.rnd(rand, 1, #pool)]
	return n, E.rnd(rand, 1, E.DEFS[n].max)
end

function E.enchant_uniform(stack, exclude, rand)
	local n, l = E.uniform_pick(stack, exclude, rand)
	if n then
		E.enchant(stack, n, l)
	end
	return stack
end

-- Chest loot entries with `ench` (cb_structures.loot).
function E.loot_stack(stack, entry)
	if stack:get_name() == "default:book" then
		return stack -- no cb_enchanting:book on this server
	end
	if entry.ench == "uniform" then
		return E.enchant_uniform(stack)
	elseif type(entry.ench) == "table" then
		local a, b, treasure = entry.ench[1], entry.ench[2], entry.ench[3]
		return E.enchant_randomly(stack, math.random(a, b), treasure == true)
	end
	return stack
end

local loot = rawget(_G, "cb_structures") and cb_structures.loot
if loot then
	loot.on_stack = E.loot_stack
end

-- Dungeon chests (minetest_game's dungeon_loot) take plain stacks: their book
-- is enchanted when it reaches a player (migrate.lua's E.convert).
local dl = rawget(_G, "dungeon_loot")
if dl and dl.register then
	dl.register({ name = BOOK, chance = 0.1, })
end

function E.blank_book(stack)
	if stack:get_name() ~= BOOK or next(E.get(stack)) then
		return nil
	end
	local out = ItemStack(stack)
	return E.enchant_uniform(out)
end

-- Villager goods (cb_mobs_village trading.lua): g.ench = N is a table roll at
-- power N; g.book = { base, base_random, per_level_random, per_level } is a
-- librarian book (Bedrock's enchant_book_for_trading): a uniform enchantment,
-- the price from its level, doubled for treasure, at most 64.
E.LIBRARIAN_EXCLUDE = { "wind_burst", "density", "breach", }
E.BOOK_PRICE_MAX = 64

function E.trade_stack(stack, g)
	if g.book then
		local n, l = E.uniform_pick(stack, E.LIBRARIAN_EXCLUDE)
		if not n then
			return stack
		end
		E.enchant(stack, n, l)
		local b = g.book
		local price = b[1] + math.random(0, b[2] + l * b[3]) + l * b[4]
		if E.DEFS[n].treasure then
			price = price * 2
		end
		return stack, math.min(price, E.BOOK_PRICE_MAX)
	end
	if g.ench then
		E.enchant_randomly(stack, g.ench, false)
	end
	return stack
end

local trading = rawget(_G, "cb_mobs_village") and cb_mobs_village.trading
if trading then
	trading.enchant = E.trade_stack
end
