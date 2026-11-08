-- The dragon fight (spec 7, 5.2, 5.3). The dragon is alive while the End is
-- ready and it has not been killed (or has been called back). It is made
-- when a player is in the arena and is saved with the world; each one gets a
-- new generation id, and its HP is kept in mod_storage too. A dragon lost
-- for good (cleared objects) is replaced after MISSING_TIME with players in
-- the arena; an old copy that loads later removes itself. Its death opens
-- the exit portal, puts an egg on it (every kill, if the spot is free) and adds a gateway; four
-- crystals on the portal rim call it back.
local the_end = cb_dimensions.the_end
local D = cb_mobs_dim.dragon
local storage = core.get_mod_storage()
local F = { TICK = 2, MISSING_TIME = 60, RANGE = 128, SPAWN_UP = 30, RESPAWN_DELAY = 5, }
cb_portals.end_fight = F

-- pending: the next dragon may appear at once (first one, after a respawn).
function F.state()
	return core.deserialize(storage:get_string("dragon"))
		or { alive = true, hp = D.HP, kills = 0, id = 0, pending = true, }
end

local function save(st)
	storage:set_string("dragon", core.serialize(st))
end

local function arena()
	local pocket = cb_dimensions.get("end")
	if not pocket or pocket.state ~= "ready" then
		return nil
	end
	return pocket, the_end.geometry(pocket)
end

function F.players_in_arena(g)
	local list = {}
	for _, player in ipairs(core.get_connected_players()) do
		local p = player:get_pos()
		if p and player:get_hp() > 0 and vector.distance(p, g.centre) <= F.RANGE then
			list[#list + 1] = player
		end
	end
	return list
end

local missing, cache = 0, {}

function F.dragon()
	local st = F.state()
	return st.alive and D.find(st.id) or nil
end

local function scan_crystals(pocket)
	local list = {}
	for _, spot in ipairs(the_end.crystal_spots(pocket)) do
		local obj = the_end.crystal_on(spot)
		if obj then
			list[#list + 1] = obj:get_pos()
		end
	end
	return list
end

function F.tick(players, dt)
	local pocket, g = arena()
	if not pocket then
		return
	end
	local st = F.state()
	if not st.alive then
		return
	end
	cache = scan_crystals(pocket)
	if #players == 0 or F.dragon() or F.respawning then
		missing = 0
		return
	end
	missing = missing + dt
	if st.pending or missing >= F.MISSING_TIME then
		missing = 0
		st.id, st.pending = st.id + 1, false
		save(st)
		D.spawn(vector.offset(g.centre, 0, F.SPAWN_UP, 0), g.centre, vector.offset(g.centre, 0, 4, 0), st.hp, st.id)
	end
end

function F.on_death()
	local st = F.state()
	st.alive, st.hp, st.kills = false, D.HP, st.kills + 1
	save(st)
	local pocket, g = arena()
	if not pocket then
		return
	end
	cb_portals.end_open_exit()
	if rawget(_G, "cb_xp") then
		cb_xp.drop(vector.offset(g.centre, 0, 4, 0), st.kills == 1 and 12000 or 500)
	end
	local egg = vector.offset(g.centre, 0, 7, 0)
	core.load_area(egg)
	if core.get_node(egg).name == "air" then
		core.set_node(egg, { name = "cb_blocks:dragon_egg", })
	end
	cb_portals.end_gateway_spawn()
end

-- The four rim nodes of the exit portal, 3 nodes from its axis.
function F.rim_spots(g)
	local c = g.centre
	return { vector.offset(c, 3, 3, 0), vector.offset(c, -3, 3, 0), vector.offset(c, 0, 3, 3), vector.offset(c, 0, 3, -3), }
end

function F.check_ritual()
	local pocket, g = arena()
	if not pocket or F.state().alive or F.respawning then
		return false
	end
	local found = {}
	for _, spot in ipairs(F.rim_spots(g)) do
		local obj = the_end.crystal_on(spot)
		if not obj then
			return false
		end
		found[#found + 1] = obj
	end
	F.respawning = true
	for _, obj in ipairs(found) do
		obj:remove()
	end
	cb_portals.end_close_exit()
	the_end.rebuild_pillars(pocket)
	the_end.place_crystals(pocket)
	core.after(F.RESPAWN_DELAY, function()
		F.respawning = nil
		local st = F.state()
		st.alive, st.hp, st.pending = true, D.HP, true
		save(st)
	end)
	return true
end

D.hooks.players = function()
	local _, g = arena()
	return g and F.players_in_arena(g) or {}
end
D.hooks.crystals = function()
	return cache
end
D.hooks.on_hp = function(hp)
	local st = F.state()
	st.hp = hp
	save(st)
end
D.hooks.valid = function(id)
	local st = F.state()
	return st.alive and id == st.id
end
D.hooks.on_death = function()
	F.on_death()
end

local placed = cb_items.on_crystal_placed
cb_items.on_crystal_placed = function(pos)
	F.check_ritual()
	if placed then
		placed(pos)
	end
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < F.TICK then
		return
	end
	local dt = timer
	timer = 0
	local pocket, g = arena()
	if pocket then
		F.tick(F.players_in_arena(g), dt)
	end
end)
