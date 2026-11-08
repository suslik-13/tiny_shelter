-- Professions (spec cycle 3, 2.2): a jobless adult takes a free job site
-- within RADIUS of its bed (checked every 10-20 s while active); without it
-- it is jobless again unless it has traded; nitwits never work.
local S = cb_mobs_village.S
local V, T = cb_mobs_village, cb_mobs_village.trading
-- A job site remembers its holder in node meta (cb_holder, cb_holder_t),
-- refreshed every HOLD/4 s: an unloaded holder keeps it for HOLD s, a dead one
-- not at all. A failed search waits BACKOFF_MIN..BACKOFF_MAX s.
local P = { RADIUS = 32, NITWIT = 0.05, MIN_T = 10, MAX_T = 20, HOLD = 1200, BACKOFF_MIN = 60, BACKOFF_MAX = 120, }
cb_mobs_village.professions = P
P.JOBS = { farmer = "village_composter", fisherman = "village_barrel", shepherd = "village_loom",
	fletcher = "village_fletching_table", librarian = "village_lectern", cartographer = "village_cartography_table",
	cleric = "village_brewing_stand", armorer = "village_blast_furnace", toolsmith = "village_smithing_table",
	weaponsmith = "village_grindstone", butcher = "village_smoker", leatherworker = "village_cauldron",
	mason = "village_stonecutter", }
P.NAMES = { farmer = S("Farmer"), fisherman = S("Fisherman"), shepherd = S("Shepherd"), fletcher = S("Fletcher"),
	librarian = S("Librarian"), cartographer = S("Cartographer"), cleric = S("Cleric"), armorer = S("Armorer"),
	toolsmith = S("Toolsmith"), weaponsmith = S("Weaponsmith"), butcher = S("Butcher"),
	leatherworker = S("Leatherworker"), mason = S("Mason"), banker = S("Banker"), wandering_trader = S("Wandering Trader"), nitwit = S("Nitwit"), }
P.LEVEL_NAMES = { S("Novice"), S("Apprentice"), S("Journeyman"), S("Expert"), S("Master"), }
P.on_init = {}
local by_node, names = {}, {}

function P.add_job(name, prof)
	if prof ~= "banker" and not T.available(prof) then
		return
	end
	if core.registered_nodes[name] and not by_node[name] then
		by_node[name] = prof
		names[#names + 1] = name
	end
end

core.register_on_mods_loaded(function()
	for prof, key in pairs(P.JOBS) do
		local ok, name = pcall(cb_core.equiv, key)
		if ok then
			P.add_job(name, prof)
		end
	end
	-- xdecor's cauldron changes its node while it works
	for _, n in ipairs({ "xdecor:cauldron_idle", "xdecor:cauldron_boiling", "xdecor:cauldron_soup", }) do
		P.add_job(n, "leatherworker")
	end
	-- variants of a job site (composter levels, an open barrel, a lit smoker) name their base node
	for name, def in pairs(core.registered_nodes) do
		local prof = def._cb_jobsite_of and by_node[def._cb_jobsite_of]
		if prof then
			P.add_job(name, prof)
		end
	end
end)

function P.of_node(name)
	return by_node[name]
end

local function vid(self)
	if not self._vid then
		self._vid = tostring(math.random(1, 2147483646))
	end
	return self._vid
end

local function held_by_other(pos, self)
	local meta = core.get_meta(pos)
	local holder = meta:get_string("cb_holder")
	return holder ~= "" and holder ~= vid(self) and core.get_gametime() - meta:get_int("cb_holder_t") < P.HOLD
end

local function hold(pos, self, force)
	local meta = core.get_meta(pos)
	if force or core.get_gametime() - meta:get_int("cb_holder_t") >= P.HOLD / 4 then
		meta:set_string("cb_holder", vid(self))
		meta:set_int("cb_holder_t", core.get_gametime())
	end
end

function P.release(self)
	local pos = self._job
	if pos and core.get_meta(pos):get_string("cb_holder") == vid(self) then
		core.get_meta(pos):set_string("cb_holder", "")
	end
end

function P.claimed(pos, self)
	if held_by_other(pos, self) then
		return true
	end
	for _, obj in ipairs(core.get_objects_inside_radius(pos, P.RADIUS)) do
		local e = obj:get_luaentity()
		if e and e ~= self and e.name == "cb_mobs_village:villager" and e._job and vector.equals(e._job, pos) then
			return true
		end
	end
	return false
end

function P.find(self, only)
	local center = self._bed or vector.round(self.object:get_pos())
	local r = P.RADIUS
	local best, bd, bp
	for _, pos in ipairs(core.find_nodes_in_area(vector.offset(center, -r, -8, -r), vector.offset(center, r, 8, r), names)) do
		local prof = by_node[core.get_node(pos).name]
		local d = vector.distance(pos, center)
		if (not only or prof == only) and (not bd or d < bd) and not P.claimed(pos, self) then
			best, bd, bp = pos, d, prof
		end
	end
	return best, bp
end

local function start(self, prof)
	if P.on_init[prof] then
		P.on_init[prof](self)
	else
		T.init(self, prof)
	end
end

-- The job site is gone (or too far now): one that never traded loses its
-- profession too.
function P.lose_job(self)
	self._job = nil
	if not self._traded then
		self._prof, self._level, self._xp, self._offers = nil, nil, nil, nil
		V.retexture(self, "villager")
	end
end

function P.update(self)
	if self._nitwit or self._child then
		return
	end
	if self._job then
		if core.get_node(self._job).name == "ignore" then
			return
		end
		if by_node[core.get_node(self._job).name] == self._prof and not held_by_other(self._job, self) then
			hold(self._job, self)
			return
		end
		P.lose_job(self)
	end
	local pos, prof = P.find(self, self._traded and self._prof or nil)
	if pos then
		self._job = pos
		hold(pos, self, true)
		if self._prof ~= prof then
			start(self, prof)
		end
		V.retexture(self, "villager")
	else
		self._job_t = math.random(P.BACKOFF_MIN, P.BACKOFF_MAX)
	end
end

-- "Farmer — Apprentice", "Nitwit", "Villager"
function P.title(self)
	if self._nitwit then
		return P.NAMES.nitwit
	end
	if not self._prof then
		return S("Villager")
	end
	if self._prof == "banker" then
		return P.NAMES.banker
	end
	if self._prof == "wandering_trader" then
		return P.NAMES.wandering_trader
	end
	return S("@1 — @2", P.NAMES[self._prof], P.LEVEL_NAMES[self._level or 1])
end

-- every MIN_T..MAX_T s from the villager's step
function P.tick(self, dt)
	self._job_t = (self._job_t or 0) - dt
	if self._job_t <= 0 then
		self._job_t = math.random(P.MIN_T, P.MAX_T)
		P.update(self) -- may set a longer back-off
	end
end
