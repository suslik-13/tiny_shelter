-- Villager trades (spec cycle 3, 2): offers from Bedrock's tables
-- (trades.lua), chosen per level; price = base + demand, minus the hero's
-- discount; restocks at most twice a day. State on the entity (saved by
-- mobs_redo): _prof, _level, _xp, _offers = {{id, u, d, c, s, p}}, _traded,
-- _rday, _rn. Enchanted goods (g.ench, g.book) are rolled once per offer by
-- T.enchant (set by cb_enchanting): s = the item string, p = a book's price.
local T = {}
cb_mobs_village.trading = T
T.DATA = dofile(core.get_modpath("cb_mobs_village") .. "/trades.lua")
local resolved = {}

function T.item(spec)
	local key = spec[1]
	local r = resolved[key]
	if r == nil then
		r = false
		for _, name in ipairs(key) do
			if core.registered_items[name] then
				r = name
				break
			end
		end
		resolved[key] = r
	end
	return r or nil
end

function T.trade(prof, id)
	local l, g, i = id:match("^(%d+)%.(%d+)%.(%d+)$")
	local tiers = T.DATA[prof]
	local tier = tiers and tiers[tonumber(l)]
	local group = tier and tier.groups[tonumber(g)]
	return group and group.t[tonumber(i)]
end

local function usable(tr)
	for _, w in ipairs(tr.w) do
		if not T.item(w) then
			return false
		end
	end
	return T.item(tr.g) ~= nil
end

local function any_of(spec, rand)
	local list = {}
	for _, name in ipairs(spec[1]) do
		if core.registered_items[name] then
			list[#list + 1] = name
		end
	end
	return list[rand(1, #list)]
end

-- fn(stack, g) -> stack, price (nil: the trade's own); nil without cb_enchanting.
T.enchant = nil

function T.roll(offer, tr)
	if offer.s or not T.enchant or not (tr.g.ench or tr.g.book) then
		return
	end
	local st, price = T.enchant(ItemStack(offer.c or T.item(tr.g)), tr.g)
	offer.s, offer.p = st:to_string(), price
end

function T.choose(self, level, rand)
	rand = rand or math.random
	local tier = T.DATA[self._prof][level]
	if not tier then
		return
	end
	self._offers = self._offers or {}
	for gi, g in ipairs(tier.groups) do
		local pool = {}
		for ti, tr in ipairs(g.t) do
			if usable(tr) then
				pool[#pool + 1] = ti
			end
		end
		for _ = 1, math.min(g.n, #pool) do
			local ti = table.remove(pool, rand(1, #pool))
			local tr = g.t[ti]
			local offer = { id = level .. "." .. gi .. "." .. ti, u = 0, d = 0, c = tr.g.any and any_of(tr.g, rand) or nil, }
			T.roll(offer, tr)
			self._offers[#self._offers + 1] = offer
		end
	end
end

-- Whether prof has at least one novice offer on this server (a profession
-- without one is never given: its job site stays decoration).
local available = {}
function T.available(prof)
	if available[prof] == nil then
		available[prof] = false
		local tier = T.DATA[prof] and T.DATA[prof][1]
		for _, g in ipairs(tier and tier.groups or {}) do
			for _, tr in ipairs(g.t) do
				available[prof] = available[prof] or usable(tr)
			end
		end
	end
	return available[prof]
end

-- Offers whose trade or item no longer exists (regenerated tables, a mod
-- removed) are dropped when a villager comes back.
function T.sanitize(self)
	if not self._offers then
		return
	end
	local keep = {}
	for _, o in ipairs(self._offers) do
		local tr = not o.bank and self._prof and T.trade(self._prof, o.id)
		if o.bank or (tr and usable(tr) and (not o.c or core.registered_items[o.c])
				and (not o.s or core.registered_items[ItemStack(o.s):get_name()])) then
			keep[#keep + 1] = o
		end
	end
	self._offers = keep
end

function T.init(self, prof, rand)
	self._prof, self._level, self._xp, self._offers, self._traded = prof, 1, 0, {}, nil
	T.choose(self, 1, rand)
end

function T.price(self, offer, player)
	local tr = T.trade(self._prof, offer.id)
	local base = offer.p or tr.w[1][2]
	local p = base + math.max(0, math.floor(base * (tr.m or 0) * (offer.d or 0)))
	local hero = player and cb_core.effects.get(player, "hero")
	if hero then
		p = p - math.floor(base * (0.3 + 0.0625 * (hero - 1)))
	end
	local max = ItemStack(T.item(tr.w[1])):get_stack_max()
	return math.max(1, math.min(max, p))
end

function T.view(self, offer, player)
	local tr = T.trade(self._prof, offer.id)
	local wants = { ItemStack(T.item(tr.w[1]) .. " " .. T.price(self, offer, player)), }
	if tr.w[2] then
		wants[2] = ItemStack(T.item(tr.w[2]) .. " " .. tr.w[2][2])
	end
	-- offers made before enchanting existed roll on their first view
	T.roll(offer, tr)
	local gives = ItemStack(offer.s or (offer.c or T.item(tr.g)))
	gives:set_count(tr.g[2])
	return { wants = wants, gives = gives, sold = offer.u >= tr.u, }
end

function T.level_up(self, rand)
	local tiers = T.DATA[self._prof]
	while self._level < #tiers and self._xp >= tiers[self._level + 1].exp do
		self._level = self._level + 1
		T.choose(self, self._level, rand)
	end
end

function T.use(self, offer, rand)
	local tr = T.trade(self._prof, offer.id)
	offer.u = offer.u + 1
	self._xp = self._xp + (tr.x or 0)
	self._traded = true
	T.level_up(self, rand)
end

function T.restock(self, day)
	if self._prof == "banker" then
		return false
	end
	if self._rday ~= day then
		self._rday, self._rn = day, 0
	end
	if self._rn >= 2 then
		return false
	end
	local used = false
	for _, o in ipairs(self._offers or {}) do
		used = used or o.u > 0
	end
	if not used then
		return false
	end
	for _, o in ipairs(self._offers) do
		local tr = T.trade(self._prof, o.id)
		if tr then
			o.d = math.max(0, o.d + o.u - (tr.u - o.u))
			o.u = 0
		end
	end
	self._rn = self._rn + 1
	return true
end

-- xp of the current level and of the next one (nil at master)
function T.level_xp(self)
	local tiers = T.DATA[self._prof]
	local nxt = tiers[self._level + 1]
	return tiers[self._level].exp, nxt and nxt.exp
end
-- Payment check: the wanted stacks in the two pay slots, in either order.
-- Returns a plan {[slot] = count to take} or nil. Bank offers (offer.bank)
-- are handled by banker.lua.
function T.match(self, offer, player, pay)
	if offer.bank then
		return cb_mobs_village.banker.match(self, offer, player, pay)
	end
	local v = T.view(self, offer, player)
	if v.sold then
		return nil
	end
	local function fits(a, b)
		local plan = {}
		for k, w in ipairs(v.wants) do
			local slot = k == 1 and a or b
			local s = pay[slot]
			if s:get_name() ~= w:get_name() or s:get_count() < w:get_count() then
				return nil
			end
			plan[slot] = w:get_count()
		end
		return plan
	end
	return fits(1, 2) or fits(2, 1)
end

-- Gives of an offer (bank offers may give different stacks).
function T.gives(self, offer, player)
	if offer.bank then
		return cb_mobs_village.banker.gives(self, offer, player)
	end
	return T.view(self, offer, player).gives
end
