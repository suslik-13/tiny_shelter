-- Trade window (spec cycle 3, 2.6): offers on the left, two pay slots and a
-- result slot (a detached inventory per player); taking the result pays
-- once. Closing, walking away (> 6) or the villager's death returns the
-- payment. The villager stands and looks at the player meanwhile.
local S = cb_mobs_village.S
local T, P = cb_mobs_village.trading, cb_mobs_village.professions
local U = { FORM = "cb_mobs_village:trade", REACH = 6, sessions = {}, }
cb_mobs_village.trade_ui = U
local invs = {}

local function pay_stacks(inv)
	return { inv:get_stack("pay", 1), inv:get_stack("pay", 2), }
end

local function give_back(player, inv)
	local pinv = player:get_inventory()
	for i = 1, 2 do
		local left = pinv:add_item("main", inv:get_stack("pay", i))
		if not left:is_empty() then
			core.add_item(player:get_pos(), left)
		end
		inv:set_stack("pay", i, "")
	end
	inv:set_stack("out", 1, "")
end

function U.inv(name)
	if not invs[name] then
		invs[name] = core.create_detached_inventory("cb_trade_" .. name, {
			allow_put = function(_, listname, _, stack)
				return listname == "pay" and stack:get_count() or 0
			end,
			allow_move = function(_, from, _, to, _, count)
				return (from == "pay" and to == "pay") and count or 0
			end,
			allow_take = function(_, listname, _, stack, player)
				if listname == "out" then
					return U.can_take(player, stack) and stack:get_count() or 0
				end
				return stack:get_count()
			end,
			on_put = function(_, _, _, _, player) U.refresh(player) end,
			on_move = function(_, _, _, _, _, _, player) U.refresh(player) end,
			on_take = function(_, listname, _, _, player)
				if listname == "out" then
					U.complete(player)
				else
					U.refresh(player)
				end
			end,
		}, name)
		invs[name]:set_size("pay", 2)
		invs[name]:set_size("out", 1)
	end
	return invs[name]
end

local function offer_of(s)
	return s and s.sel and s.ent._offers and s.ent._offers[s.sel]
end

function U.plan(player)
	local s = U.sessions[player:get_player_name()]
	local offer = offer_of(s)
	return offer and T.match(s.ent, offer, player, pay_stacks(U.inv(player:get_player_name())))
end

-- Only the whole result of the selected offer, fully paid: a partial take
-- (right click, dragging onto a stack, shift-click into a partial slot) or a
-- stale result would pay a full trade for less.
function U.can_take(player, stack)
	local name = player:get_player_name()
	local s = U.sessions[name]
	local offer = offer_of(s)
	if not (offer and U.plan(player)) then
		return false
	end
	local want = T.gives(s.ent, offer, player)
	local cur = U.inv(name):get_stack("out", 1)
	return stack:get_name() == want:get_name() and stack:get_count() == want:get_count()
		and cur:get_name() == want:get_name() and cur:get_count() == want:get_count()
end

function U.refresh(player)
	local name = player:get_player_name()
	local s, inv = U.sessions[name], U.inv(name)
	local offer = offer_of(s)
	if offer and U.plan(player) then
		inv:set_stack("out", 1, T.gives(s.ent, offer, player))
	else
		inv:set_stack("out", 1, "")
	end
end

local function item_button(x, y, stack, field)
	return ("item_image_button[%s,%s;0.8,0.8;%s;%s;%s]"):format(x, y, stack:get_name(), field,
		stack:get_count() > 1 and stack:get_count() or "")
end

function U.formspec(ent, player)
	local name = player:get_player_name()
	local fs = { "formspec_version[4]size[11.6,10.4]", "label[0.4,0.5;" .. core.formspec_escape(P.title(ent)) .. "]", }
	if ent._prof ~= "banker" and ent._prof ~= "wandering_trader" then
		local cur, nxt = T.level_xp(ent)
		local w = nxt and 4 * math.min(1, (ent._xp - cur) / math.max(1, nxt - cur)) or 4
		fs[#fs + 1] = "box[0.4,0.8;4,0.2;#303030]box[0.4,0.8;" .. w .. ",0.2;#5ec85e]"
	end
	fs[#fs + 1] = "scroll_container[0.3,1.2;5.4,4.6;offers;vertical]"
	for i, offer in ipairs(ent._offers or {}) do
		local v = offer.bank and cb_mobs_village.banker.view(ent, offer, player) or T.view(ent, offer, player)
		local y = (i - 1) * 0.95
		fs[#fs + 1] = item_button(0.1, y, v.wants[1], "o" .. i)
		if v.wants[2] then
			fs[#fs + 1] = item_button(1.0, y, v.wants[2], "o" .. i)
		end
		fs[#fs + 1] = "label[2.0," .. (y + 0.4) .. ";→]"
		fs[#fs + 1] = item_button(2.5, y, v.gives, "o" .. i)
		if v.sold then
			fs[#fs + 1] = "label[3.5," .. (y + 0.4) .. ";" .. core.formspec_escape(S("Sold out")) .. "]"
		end
	end
	fs[#fs + 1] = "scroll_container_end[]scrollbar[5.8,1.2;0.3,4.6;vertical;offers;0]"
	local loc = "detached:cb_trade_" .. name
	fs[#fs + 1] = "list[" .. loc .. ";pay;6.5,2.4;2,1;]label[9.1,2.8;→]list[" .. loc .. ";out;9.6,2.4;1,1;]"
	fs[#fs + 1] = "list[current_player;main;0.9,6.0;8,4;]listring[" .. loc .. ";pay]listring[current_player;main]"
	return table.concat(fs)
end

function U.show(ent, player)
	core.show_formspec(player:get_player_name(), U.FORM, U.formspec(ent, player))
end

-- false when another player is already trading with this villager
function U.open(ent, player)
	local name = player:get_player_name()
	local other = ent._trading and U.sessions[ent._trading]
	if other and other.ent == ent and ent._trading ~= name then
		return false
	end
	if U.sessions[name] then
		U.close(name)
	end
	U.sessions[name] = { ent = ent, player = player, }
	ent._trading = name
	U.inv(name)
	U.show(ent, player)
	return true
end

-- Selecting an offer: the old payment back, the new one from the inventory.
function U.select(player, i)
	local name = player:get_player_name()
	local s, inv = U.sessions[name], U.inv(name)
	local offer = s and s.ent._offers and s.ent._offers[i]
	if not offer then
		return
	end
	give_back(player, inv)
	s.sel = i
	local v = offer.bank and cb_mobs_village.banker.view(s.ent, offer, player) or T.view(s.ent, offer, player)
	local pinv = player:get_inventory()
	for k, w in ipairs(v.wants) do
		if pinv:contains_item("main", w) then
			inv:set_stack("pay", k, pinv:remove_item("main", w))
		end
	end
	U.refresh(player)
	U.show(s.ent, player)
end

-- The result was taken: pay by the plan, count the trade.
function U.complete(player)
	local name = player:get_player_name()
	local s, inv = U.sessions[name], U.inv(name)
	local offer = offer_of(s)
	local plan = offer and T.match(s.ent, offer, player, pay_stacks(inv))
	if plan then
		for slot = 1, 2 do
			if plan[slot] then
				local st = inv:get_stack("pay", slot)
				st:take_item(plan[slot])
				inv:set_stack("pay", slot, st)
			end
		end
		if offer.bank then
			cb_mobs_village.banker.use(s.ent, offer, player, plan)
		else
			T.use(s.ent, offer)
		end
		if rawget(_G, "cb_xp") then
			cb_xp.drop(player:get_pos(), cb_xp.trade_xp(offer))
		end
	end
	U.refresh(player)
	U.show(s.ent, player)
end

function U.close(name)
	local s = U.sessions[name]
	U.sessions[name] = nil
	local player = core.get_player_by_name(name) or (s and s.player)
	if invs[name] and player then
		give_back(player, invs[name])
	end
	if s and s.ent and s.ent._trading == name then
		s.ent._trading = nil
	end
	core.close_formspec(name, U.FORM)
end

-- From the villager's step and the globalstep: dead villager or > REACH.
function U.watch(player, _)
	local name = player:get_player_name()
	local s = U.sessions[name]
	if not s then
		return
	end
	s.player = player
	local pos = s.ent.object and s.ent.object:get_pos()
	if not pos or vector.distance(pos, player:get_pos()) > U.REACH then
		U.close(name)
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= U.FORM then
		return
	end
	for k in pairs(fields) do
		local i = tonumber(k:match("^o(%d+)$") or "")
		if i then
			U.select(player, i)
			return true
		end
	end
	if fields.quit then
		U.close(player:get_player_name())
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if U.sessions[name] then
		U.sessions[name].player = player
		U.close(name)
	end
end)

-- The detached inventory is not saved: hand the payments back first.
function U.shutdown()
	for name in pairs(U.sessions) do
		U.close(name)
	end
end
core.register_on_shutdown(U.shutdown)

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.5 or next(U.sessions) == nil then
		return
	end
	timer = 0
	for name in pairs(U.sessions) do
		local player = core.get_player_by_name(name)
		if player then
			U.watch(player, 0)
		else
			U.sessions[name] = nil
		end
	end
end)
