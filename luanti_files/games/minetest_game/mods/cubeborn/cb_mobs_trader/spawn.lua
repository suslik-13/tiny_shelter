-- When the trader comes (spec cycle 3, 6.1): a check every EVERY s with a
-- chance from BASE, +STEP after each miss up to MAX, back to BASE after a
-- hit (mod_storage "chance"); one trader per server ("until" = its leave
-- time). It comes to a random online player under the open sky: at the bell
-- when the player is in a village, else 24-48 nodes away on open ground.
local S, TR = cb_mobs_trader.S, cb_mobs_trader
TR.EVERY, TR.BASE, TR.STEP, TR.MAX = 1200, 0.025, 0.025, 0.075
TR.R_MIN, TR.R_MAX, TR.SKY = 24, 48, 48

function TR.chance()
	local c = TR.store:get_float("chance")
	return c > 0 and c or TR.BASE
end

function TR.busy()
	return TR.store:get_int("until") > core.get_gametime()
end

function TR.roll(rand)
	if TR.busy() then
		return false
	end
	local c = TR.chance()
	if (rand or math.random)() < c then
		TR.store:set_float("chance", TR.BASE)
		return true
	end
	TR.store:set_float("chance", math.min(TR.MAX, c + TR.STEP))
	return false
end

function TR.open_sky(pos)
	for y = 0, TR.SKY do
		local n = core.get_node_or_nil(vector.offset(pos, 0, y, 0))
		if not n or n.name == "ignore" then
			return true
		end
		if n.name ~= "air" then
			return false
		end
	end
	return true
end

function TR.spot(center, rmin, rmax, rand)
	rand = rand or math.random
	for _ = 1, 10 do
		local a, d = rand() * math.pi * 2, rmin + rand() * (rmax - rmin)
		local x, z = math.floor(center.x + math.cos(a) * d + 0.5), math.floor(center.z + math.sin(a) * d + 0.5)
		for y = math.floor(center.y + 0.5) + 16, math.floor(center.y + 0.5) - 16, -1 do
			local p = vector.new(x, y, z)
			local name = core.get_node(p).name
			if name == "ignore" then
				break
			end
			local def = core.registered_nodes[name]
			if def and def.walkable then
				local up = vector.offset(p, 0, 1, 0)
				if (def.liquidtype or "none") == "none" and core.get_node(up).name == "air"
						and core.get_node(vector.offset(p, 0, 2, 0)).name == "air" and TR.open_sky(up) then
					return up
				end
				break
			end
		end
	end
end

function TR.spawn(at, rand)
	local obj = core.add_entity(vector.offset(at, 0, 0.5, 0), TR.TRADER)
	local t = obj and obj:get_luaentity()
	if not t then
		return nil
	end
	TR.setup(t, rand)
	for i = 1, 2 do
		local lo = core.add_entity(vector.offset(at, i == 1 and 1 or -1, 0.5, 0), TR.LLAMA)
		local l = lo and lo:get_luaentity()
		if l then
			TR.bind(l, t)
		end
	end
	return t
end

-- The ready village at pos (cb_structures' one lookup), or nil.
function TR.village_at(pos)
	if not rawget(_G, "cb_structures") then
		return nil
	end
	local _, rec = cb_structures.village.find(pos)
	return rec
end

function TR.spawn_near(pos, rand)
	local at
	local village = TR.village_at(pos)
	if village then
		local bell = cb_structures.village.bell(village)
		at = bell and TR.spot(bell, 2, 6, rand)
	end
	at = at or TR.spot(pos, TR.R_MIN, TR.R_MAX, rand)
	return at and TR.spawn(at, rand) or nil
end

function TR.tick()
	core.after(TR.EVERY, TR.tick)
	local under_sky = {}
	for _, p in ipairs(core.get_connected_players()) do
		if TR.open_sky(vector.offset(vector.round(p:get_pos()), 0, 1, 0)) then
			under_sky[#under_sky + 1] = p
		end
	end
	if #under_sky == 0 or not TR.roll() then
		return
	end
	TR.spawn_near(under_sky[math.random(#under_sky)]:get_pos())
end
core.after(TR.EVERY, TR.tick)

core.register_chatcommand("cb_trader", {
	description = S("Call the wandering trader to you"),
	privs = { cb_admin = true, },
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, S("Only for players in the game.")
		end
		if TR.busy() then
			return false, S("A wandering trader is already about.")
		end
		local t = TR.spawn_near(player:get_pos())
		return t ~= nil, t and S("The wandering trader is coming.") or S("No open ground nearby.")
	end,
})
