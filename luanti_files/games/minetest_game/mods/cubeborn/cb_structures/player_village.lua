-- Players' villages (spec cycle 5, 4.3): a bell a player puts outside every
-- village makes one, an ordinary "village" record with the player flag, so
-- raids, the wandering trader and golems treat it as any village. Its box is
-- R around the bell (H up and down); its beds need a wooden door near
-- (VL.beds). No villagers come back on their own: only those brought there
-- and their children live in it. Breaking the bell ends the village.
local S = cb_structures.S
local VL = cb_structures.village
local reg = cb_structures.registry
local PV = { R = 32, H = 16, APART = 64, BELL = "cb_blocks:bell", }
cb_structures.player_village = PV

-- The player's village whose bell is at pos.
local function at_bell(pos)
	local found
	reg.parts_near(pos, 0, function(id, _, rec)
		if rec.type == "village" and rec.player and vector.equals(rec.bell, pos) then
			found = id
			return false
		end
	end)
	return found
end

-- Another player's village bell within APART of pos.
local function bell_near(pos)
	local near = false
	reg.parts_near(pos, PV.APART, function(_, _, rec)
		if rec.type == "village" and rec.player and vector.distance(rec.bell, pos) <= PV.APART then
			near = true
			return false
		end
	end)
	return near
end

function PV.create(bell, owner)
	bell = vector.round(bell)
	if VL.find(bell) or bell_near(bell) then
		return nil
	end
	local r, h = PV.R, PV.H
	local cmin, cmax = vector.offset(bell, -8, -2, -8), vector.offset(bell, 8, 4, 8)
	local rec = { type = "village", player = true, state = "ready", owner = owner, bell = bell,
		minp = vector.offset(bell, -r, -h, -r), maxp = vector.offset(bell, r, h, r), palette = { PV.BELL, }, }
	local id = reg.add(rec)
	reg.set_parts(id, { { k = "center", minp = cmin, maxp = cmax, s = cb_structures.pack({}),
		a = cb_structures.pack({ { o = cb_structures.offset(cmin, cmax, bell), p = 1, }, }), }, })
	core.log("action", "[cb_structures] " .. tostring(owner) .. " founded village #" .. id .. " at "
		.. core.pos_to_string(bell))
	return id
end

-- The bell is gone: so is the village (a raid on it ends as "gone").
function PV.remove_at(bell)
	local id = at_bell(vector.round(bell))
	if id then
		reg.remove(id)
		core.log("action", "[cb_structures] village #" .. id .. " lost its bell")
	end
	return id
end

if cb_blocks.bell_place_hooks then
	table.insert(cb_blocks.bell_place_hooks, function(pos, placer)
		if placer and placer:is_player() then
			local name = placer:get_player_name()
			if PV.create(pos, name) then
				core.chat_send_player(name, S("This bell founds a village: beds with a wooden door within 8 nodes are its houses, villagers you bring here live and breed in it."))
			end
		end
	end)
	table.insert(cb_blocks.bell_remove_hooks, PV.remove_at)
end
