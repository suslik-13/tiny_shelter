-- Rules of the End pocket: the void at the bottom hurts, and nobody without
-- cb_admin can claim the arena around the main island (protection blocks,
-- areas, homes, travelnets, telemosaic beacons). Building there is allowed.
local the_end = cb_dimensions.the_end
if not the_end then
	return
end
local S = cb_dimensions.S

the_end.ARENA_R = 150
local VOID_DAMAGE = 4
local MESSAGE = S("You cannot do that in the End arena.")

local function geometry()
	local pocket = cb_dimensions.get("end")
	if not pocket then
		return nil
	end
	return pocket, the_end.geometry(pocket)
end

function the_end.in_void(pos)
	local pocket, g = geometry()
	return pocket ~= nil and cb_core.inside(pos, pocket.minp, pocket.maxp) and pos.y < g.ia.y + the_end.VOID
end

function the_end.void_tick(player)
	local pos = player:get_pos()
	if not pos or player:get_hp() <= 0 or not the_end.in_void(pos) then
		return false
	end
	player:set_hp(math.max(0, player:get_hp() - VOID_DAMAGE), { type = "set_hp", cause = "cb_dimensions:void", })
	return true
end

function the_end.in_arena(minp, maxp)
	maxp = maxp or minp
	local pocket, g = geometry()
	if not pocket or not cb_core.intersect(minp, maxp, pocket.minp, pocket.maxp) then
		return false
	end
	local cx, cz = g.centre.x, g.centre.z
	local nx = math.max(minp.x, math.min(cx, maxp.x))
	local nz = math.max(minp.z, math.min(cz, maxp.z))
	return (nx - cx) ^ 2 + (nz - cz) ^ 2 <= the_end.ARENA_R ^ 2
end

function the_end.arena_blocks(pos, name)
	return the_end.in_arena(pos) and not core.check_player_privs(name or "", { cb_admin = true, })
end

-- Where an on_place puts the node: into under when it is buildable_to
-- (grass, snow), else into above.
function the_end.place_pos(pointed)
	local def = core.registered_nodes[core.get_node(pointed.under).name]
	if def and def.buildable_to then
		return pointed.under
	end
	return pointed.above
end

function the_end.sethome_refused(name, pos)
	if pos and the_end.arena_blocks(vector.round(pos), name) then
		return true, MESSAGE
	end
	return false
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 1 then
		return
	end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		the_end.void_tick(player)
	end
end)

local PREFIXES = { "protector:", "travelnet:", "telemosaic:", }
local wrap = {}
for name in pairs(core.registered_nodes) do
	for _, prefix in ipairs(PREFIXES) do
		if name:sub(1, #prefix) == prefix then
			wrap[#wrap + 1] = name
			break
		end
	end
end
for _, name in ipairs(wrap) do
	local old = core.registered_nodes[name].on_place or core.item_place
	core.override_item(name, {
		on_place = function(itemstack, placer, pointed)
			local pname = placer and placer:get_player_name() or ""
			if pointed and pointed.type == "node" and the_end.arena_blocks(the_end.place_pos(pointed), pname) then
				core.chat_send_player(pname, MESSAGE)
				return itemstack
			end
			return old(itemstack, placer, pointed)
		end,
	})
end

-- The protector placer tool sets protectors up to 2r+1 nodes from one within
-- 2 nodes of the player, bypassing on_place: refuse it near the arena.
local tool = core.registered_items["protector:tool"]
if tool and tool.on_use then
	local old = tool.on_use
	local reach = 2 * math.min(tonumber(core.settings:get("protector_radius")) or 5, 22) + 3
	core.override_item("protector:tool", {
		on_use = function(itemstack, user, pointed)
			local pos = user and user:get_pos()
			local name = user and user:get_player_name() or ""
			if pos and the_end.in_arena(vector.subtract(pos, reach), vector.add(pos, reach))
					and not core.check_player_privs(name, { cb_admin = true, }) then
				core.chat_send_player(name, MESSAGE)
				return itemstack
			end
			return old(itemstack, user, pointed)
		end,
	})
end

-- End crystals blow up blocks in the End even where TNT is off.
local blast_allowed = cb_items.crystal_blast_allowed
function cb_items.crystal_blast_allowed(pos)
	local _, pocket = cb_dimensions.is_shell(vector.round(pos))
	return (pocket ~= nil and pocket.dim == "end") or blast_allowed(pos)
end

if areas and areas.canPlayerAddArea then
	local old = areas.canPlayerAddArea
	function areas.canPlayerAddArea(self, pos1, pos2, name)
		local a, b = vector.sort(pos1, pos2)
		if the_end.in_arena(a, b) and not core.check_player_privs(name, { cb_admin = true, }) then
			return false, MESSAGE
		end
		return old(self, pos1, pos2, name)
	end
end

-- The command is refused before sethome runs (one message); the set()
-- wrapper still guards other callers.
local sethome_cmd = core.registered_chatcommands["sethome"]
if sethome_cmd then
	local old = sethome_cmd.func
	core.override_chatcommand("sethome", {
		func = function(name, param)
			local player = core.get_player_by_name(name)
			local refused, msg = the_end.sethome_refused(name, player and player:get_pos())
			if refused then
				return false, msg
			end
			return old(name, param)
		end,
	})
end

if sethome and sethome.set then
	local old = sethome.set
	sethome.set = function(name, pos)
		local refused, msg = the_end.sethome_refused(name, pos)
		if refused then
			core.chat_send_player(name, msg)
			return false
		end
		return old(name, pos)
	end
end
