-- Banker (spec cycle 3, 2.7): at an ATM (atm + currency only). Sells
-- minegeld for emeralds (bank_sell each, at most bank_daily emeralds a day per
-- player, counted in player meta "cb_bank" = "1:<day>:<count>") and emeralds
-- for minegeld (bank_buy "<minegeld>:<emeralds>", paid by the sum of notes,
-- change back in notes).
local S = cb_mobs_village.S
local P, U = cb_mobs_village.professions, cb_mobs_village.trade_ui
if not (core.get_modpath("atm") and core.get_modpath("currency")) then
	return
end
local B = {}
cb_mobs_village.banker = B
B.NOTES = { ["currency:minegeld_100"] = 100, ["currency:minegeld_50"] = 50, ["currency:minegeld_10"] = 10,
	["currency:minegeld_5"] = 5, ["currency:minegeld"] = 1, }
local ORDER = { "currency:minegeld_100", "currency:minegeld_50", "currency:minegeld_10", "currency:minegeld_5",
	"currency:minegeld", }

local function setting(name, default)
	return cb_core.setting(name, default)
end

-- Whole minegeld per emerald, at least 1.
local function sell_value()
	local v = math.floor(tonumber(setting("cubeborn.bank_sell", "10")) or 10)
	return v >= 1 and v or 10
end
B.sell_value = sell_value

-- <minegeld>:<emeralds>; a free price or a sell-then-buy profit falls back
-- to 25:2 (with a warning).
local function buy_rate()
	local m, e = setting("cubeborn.bank_buy", "25:2"):match("^(%d+):(%d+)$")
	m, e = tonumber(m), tonumber(e)
	if not (m and e and m >= 1 and e >= 1 and sell_value() * e <= m) then
		core.log("warning", "[cb_mobs_village] bad cubeborn.bank_buy, using 25:2")
		return 25, 2
	end
	return m, e
end
B.buy_rate = buy_rate

-- Bank days follow game time: sleeping or /time does not reset the limit.
function B.day()
	return math.floor(core.get_gametime() / 1200)
end

local function daily()
	return tonumber(setting("cubeborn.bank_daily", "16")) or 16
end

function B.value(stacks)
	local n = 0
	for _, s in ipairs(stacks) do
		n = n + (B.NOTES[s:get_name()] or 0) * s:get_count()
	end
	return n
end

function B.change(n)
	local out = {}
	for _, name in ipairs(ORDER) do
		local v = B.NOTES[name]
		if core.registered_items[name] and n >= v then
			out[#out + 1] = ItemStack(name .. " " .. math.floor(n / v))
			n = n % v
		end
	end
	return out
end

local function counter(player)
	local raw = player:get_meta():get_string("cb_bank")
	local day, count = raw:match("^1:(%-?%d+):(%d+)$")
	if tonumber(day) ~= B.day() then
		return 0
	end
	return tonumber(count)
end

function B.left(player)
	return math.max(0, daily() - counter(player))
end

function B.view(_, offer, player)
	local E = cb_core.equiv("emerald")
	if offer.bank == "sell" then
		local gives = B.change(sell_value())[1] or ItemStack("")
		return { wants = { ItemStack(E .. " 1"), }, gives = gives, sold = B.left(player) <= 0, }
	end
	local m, e = buy_rate()
	return { wants = B.change(m), gives = ItemStack(E .. " " .. e), sold = false, }
end

function B.gives(ent, offer, player)
	if offer.bank == "sell" then
		local c = B.change(sell_value())
		return c[1] or ItemStack("")
	end
	return B.view(ent, offer, player).gives
end

function B.match(_, offer, player, pay)
	local E = cb_core.equiv("emerald")
	if offer.bank == "sell" then
		if B.left(player) <= 0 then
			return nil
		end
		for slot = 1, 2 do
			if pay[slot]:get_name() == E then
				return { [slot] = 1, }
			end
		end
		return nil
	end
	local m = buy_rate()
	if B.value(pay) < m then
		return nil
	end
	-- only the notes needed, smallest first; the change (less than one of
	-- them) must fit into the inventory
	local slots = {}
	for slot = 1, 2 do
		local v = B.NOTES[pay[slot]:get_name()]
		if v then
			slots[#slots + 1] = { slot = slot, v = v, n = pay[slot]:get_count(), }
		end
	end
	table.sort(slots, function(a, b) return a.v < b.v end)
	local plan, acc = {}, 0
	for _, it in ipairs(slots) do
		if acc < m then
			local n = math.min(it.n, math.ceil((m - acc) / it.v))
			plan[it.slot], acc = n, acc + n * it.v
		end
	end
	if acc < m then
		return nil
	end
	local inv = player:get_inventory()
	for _, st in ipairs(B.change(acc - m)) do
		if inv.room_for_item and not inv:room_for_item("main", st) then
			return nil
		end
	end
	plan.paid = acc
	return plan
end

function B.use(_, offer, player, plan)
	if offer.bank == "sell" then
		player:get_meta():set_string("cb_bank", "1:" .. B.day() .. ":" .. (counter(player) + 1))
		-- a rate that is not one note: the rest of the notes go to the inventory
		local c = B.change(sell_value())
		for i = 2, #c do
			local left = player:get_inventory():add_item("main", c[i])
			if not left:is_empty() then
				core.add_item(player:get_pos(), left)
			end
		end
		return
	end
	local m = buy_rate()
	for _, st in ipairs(B.change((plan.paid or m) - m)) do
		local left = player:get_inventory():add_item("main", st)
		if not left:is_empty() then
			core.add_item(player:get_pos(), left)
		end
	end
end

P.on_init.banker = function(self)
	self._prof, self._level, self._xp, self._traded = "banker", 1, 0, nil
	self._offers = { { id = "sell", bank = "sell", u = 0, d = 0, }, { id = "buy", bank = "buy", u = 0, d = 0, }, }
end

core.register_on_mods_loaded(function()
	P.add_job("atm:atm", "banker")
end)
