-- Endermen carry blocks: they take only listed natural blocks (grass, dirt,
-- sand, gravel, clay, flowers, mushrooms) from unprotected places and put
-- them down later, again only where it is not protected. A decision is made
-- every CARRY_INTERVAL seconds per enderman and costs one node read (plus a
-- raycast when the node is takable). A carried block is never lost: it
-- drops on death, stays carried when the enderman is unloaded and goes back
-- where it was taken when the enderman is removed.
local CARRY_INTERVAL = 2
local PLACE_CHANCE = 30
local floor = math.floor

local EXPLICIT = { "default:dirt", "default:dry_dirt", "ethereal:dry_dirt", "default:sand", "default:desert_sand",
	"default:silver_sand", "default:gravel", "default:clay", }

local takable = {}

-- Only nodes the map generator places count (no potted flowers or other
-- player-made decorations that share the groups).
core.register_on_mods_loaded(function()
	local natural = cb_core.natural_cids("world")
	local function add(name)
		if natural[core.get_content_id(name)] then
			takable[name] = true
		end
	end
	for _, name in ipairs(EXPLICIT) do
		if core.registered_nodes[name] then
			add(name)
		end
	end
	for name, def in pairs(core.registered_nodes) do
		local g = def.groups or {}
		local drawtype = def.drawtype or "normal"
		if ((g.spreading_dirt_type or 0) > 0 and drawtype == "normal")
				or (((g.flower or 0) > 0 or (g.mushroom or 0) > 0) and drawtype == "plantlike") then
			add(name)
		end
	end
end)

function cb_mobs_dim.takable(name)
	return takable[name] == true
end

local function node_pos(v)
	return vector.new(floor(v.x + 0.5), floor(v.y + 0.5), floor(v.z + 0.5))
end

-- The first walkable node on the line from the enderman's chest to pos is pos.
local function reachable(ent, pos)
	local chest = ent.object:get_pos()
	chest.y = chest.y + 1.5
	for hit in core.raycast(chest, pos, false, false) do
		if hit.type == "node" then
			if vector.equals(hit.under, pos) then
				return true
			end
			local def = core.registered_nodes[core.get_node(hit.under).name]
			if not def or def.walkable ~= false then
				return false
			end
		end
	end
	return false
end

function cb_mobs_dim.try_take(ent, pos)
	if ent._carried or not ent.object:get_pos() then
		return false
	end
	local node = core.get_node_or_nil(pos)
	if not node or not takable[node.name] or core.is_protected(pos, "") or not reachable(ent, pos) then
		return false
	end
	core.remove_node(pos)
	ent._carried, ent._taken_from = node.name, vector.copy(pos)
	cb_mobs_dim.set_carried_visual(ent)
	local def = core.registered_nodes[node.name]
	if def.sounds and def.sounds.dug then
		core.sound_play(def.sounds.dug, { pos = pos, max_hear_distance = 16, }, true)
	end
	return true
end

local function full_block(pos)
	local n = core.get_node_or_nil(pos)
	local def = n and core.registered_nodes[n.name]
	return def ~= nil and def.walkable ~= false and (def.drawtype or "normal") == "normal"
end

function cb_mobs_dim.try_place(ent, pos)
	local name = ent._carried
	if not name then
		return false
	end
	local n = core.get_node_or_nil(pos)
	if not n or n.name ~= "air" or not full_block(vector.offset(pos, 0, -1, 0)) or core.is_protected(pos, "") then
		return false
	end
	core.set_node(pos, { name = name, })
	ent._carried, ent._taken_from = nil, nil
	cb_mobs_dim.set_carried_visual(ent)
	local def = core.registered_nodes[name]
	if def and def.sounds and def.sounds.place then
		core.sound_play(def.sounds.place, { pos = pos, max_hear_distance = 16, }, true)
	end
	return true
end

-- Per-entity timers kept out of staticdata.
local timers = setmetatable({}, { __mode = "k", })

function cb_mobs_dim.carry_step(ent, dtime)
	local t = (timers[ent] or 0) + dtime
	if t < CARRY_INTERVAL then
		timers[ent] = t
		return
	end
	timers[ent] = 0
	local pos = ent.object:get_pos()
	if not pos or ent.state == "attack" or ent.health <= 0 then
		return
	end
	local rand = cb_mobs_dim.rand
	local p = node_pos(pos)
	if ent._carried then
		if rand(1, PLACE_CHANCE) == 1 then
			local dx, dz = rand(-1, 1), rand(-1, 1)
			if dx ~= 0 or dz ~= 0 then
				cb_mobs_dim.try_place(ent, vector.offset(p, dx, rand(0, 2), dz))
			end
		end
	else
		cb_mobs_dim.try_take(ent, vector.offset(p, rand(-2, 2), rand(0, 3), rand(-2, 2)))
	end
end

local function put_back(p, name)
	local n = p and core.get_node_or_nil(p)
	if n and n.name == "air" and not core.is_protected(p, "") then
		core.set_node(p, { name = name, })
		return true
	end
	return false
end

-- Removed (not killed): the block goes back where it was taken, else under
-- the enderman's feet, else it drops as an item. On unload it stays in the
-- enderman's hands: the staticdata saved just before already holds it.
function cb_mobs_dim.carrier_gone(ent, removal)
	local name, from = ent._carried, ent._taken_from
	if not name or not removal then
		return
	end
	ent._carried, ent._taken_from = nil, nil
	local pos = ent.object:get_pos()
	if put_back(from, name) or (pos and put_back(node_pos(pos), name)) then
		return
	end
	if pos then
		core.add_item(pos, name)
	end
end

function cb_mobs_dim.carrier_died(ent, pos)
	if ent._carried then
		core.add_item(pos, ent._carried)
		ent._carried, ent._taken_from = nil, nil
	end
end
