-- Fortune and Silk Touch (spec 5): the drops of a dug node. builtin
-- node_dig hands them to handle_node_drops while the node is still there,
-- so the wrap can look at it and at the digger's tool.
local E = cb_enchanting

-- Silk Touch: the node itself, unless that could dupe or give a block
-- players cannot have (meta and inventories, machines, crop stages).
function E.silk_drops(pos, node, drops)
	local def = core.registered_nodes[node.name]
	if not def or def.drop == nil or (def.liquidtype or "none") ~= "none" then
		return drops
	end
	if node.name:find("^technic:") or node.name:find("^techage:") or (def.groups or {}).not_in_creative_inventory then
		return drops
	end
	if #core.find_nodes_with_meta(pos, pos) > 0 then
		return drops
	end
	return { node.name, }
end

local kinds = {}
local function find_kind(name)
	local def = core.registered_nodes[name]
	if not def then
		return nil
	end
	local g = def.groups or {}
	if (g.plant or 0) > 0 and not g.growing then
		return "crop"
	elseif (g.leaves or 0) > 0 then
		return "leaves"
	elseif def.drop ~= nil and ((g.ore or 0) > 0 or name:find("stone_with_", 1, true) or name:find("_ore", 1, true)
			or name:find(":ore", 1, true) or name:find(":mineral_", 1, true)) then
		return "ore"
	end
	return nil
end

-- "ore", "crop", "leaves" or nil: how Fortune treats the node.
function E.fortune_kind(name)
	local k = kinds[name]
	if k == nil then
		k = find_kind(name) or false
		kinds[name] = k
	end
	return k or nil
end

-- Minecraft's sapling chance from leaves rises from 5 % by these.
local LEAF_EXTRA = { 0.0125, 0.0333, 0.05, }

local function roll(rng, a, b)
	return rng and rng:next(a, b) or math.random(a, b)
end

local function rare_drops(name)
	local list = {}
	local drop = core.registered_nodes[name].drop
	for _, e in ipairs(type(drop) == "table" and drop.items or {}) do
		if (e.rarity or 1) > 1 then
			for _, it in ipairs(e.items or {}) do
				list[#list + 1] = it
			end
		end
	end
	return list
end

function E.fortune_drops(node, drops, level, rng)
	local kind = level > 0 and E.fortune_kind(node.name)
	if not kind then
		return drops
	end
	local out = {}
	for i, d in ipairs(drops) do
		out[i] = ItemStack(d)
	end
	if kind == "ore" then
		local mult = math.max(0, roll(rng, 0, level + 1) - 1) + 1
		for _, s in ipairs(out) do
			if core.registered_craftitems[s:get_name()] then
				s:set_count(s:get_count() * mult)
			end
		end
	elseif kind == "crop" then
		local seen = {}
		for _, s in ipairs(table.copy(out)) do
			local n = s:get_name()
			if core.registered_craftitems[n] and not seen[n] then
				seen[n] = true
				local extra = 0
				for _ = 1, level do
					extra = extra + (roll(rng, 1, 7) <= 4 and 1 or 0)
				end
				if extra > 0 then
					out[#out + 1] = ItemStack(n .. " " .. extra)
				end
			end
		end
	else
		local rare = rare_drops(node.name)
		if #rare > 0 and roll(rng, 1, 10000) <= LEAF_EXTRA[math.min(level, 3)] * 10000 then
			out[#out + 1] = ItemStack(rare[roll(rng, 1, #rare)])
		end
	end
	return out
end

core.register_on_mods_loaded(function()
	local orig = core.handle_node_drops
	core.handle_node_drops = function(pos, drops, digger, ...)
		if digger and digger.get_wielded_item and drops then
			local stack = digger:get_wielded_item()
			if E.level(stack, "silk_touch") > 0 then
				drops = E.silk_drops(pos, core.get_node(pos), drops)
			else
				local f = E.level(stack, "fortune")
				if f > 0 then
					drops = E.fortune_drops(core.get_node(pos), drops, f)
				end
			end
		end
		return orig(pos, drops, digger, ...)
	end
	E.drops_wrapped = true
end)
