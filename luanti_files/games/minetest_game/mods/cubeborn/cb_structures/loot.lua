-- Chest loot. Tables come from tools/gen_loot.py (loot_tables.lua) or
-- loot.register(). An entry lists candidate items; the first registered one is
-- used, and an entry with none drops out (its weight goes to the rest). A
-- structure's chest keeps only the table name in its meta and is filled when
-- it is first opened or someone tries to dig it.
local loot = {}
cb_structures.loot = loot

local tables = dofile(core.get_modpath("cb_structures") .. "/loot_tables.lua")
-- Rooms of woodland mansions with fixed contents (Mineclonia's
-- build_specific_loot_processor).
for name, item in pairs({ mansion_allium = { { "flowers:viola", }, 8, }, mansion_sapling = { { "default:junglesapling", }, 26, },
	mansion_pearl = { { "cb_items:ender_pearl", }, 2, }, mansion_axe = { { "default:axe_steel", }, 1, }, }) do
	tables[name] = { { rolls = { 1, 1, }, entries = { { items = item[1], w = 1, n = { item[2], item[2], }, }, }, }, }
end
local resolved = {}

-- connected_chests and the open chest copy the meta, so they need loot too.
loot.CONTAINERS = { "default:chest", "default:chest_open", "default:chest_connected_left",
	"default:chest_connected_left_open", }

-- fn(stack, entry, rand) -> stack for entries with `ench` ("uniform" or
-- { min, max, treasure }); set by cb_enchanting.
loot.on_stack = nil

function loot.register(name, pools)
	tables[name] = pools
	resolved[name] = nil
end

-- One more pool for a table (other mods' items in generated tables).
function loot.add_pool(name, pool)
	if tables[name] then
		table.insert(tables[name], pool)
		resolved[name] = nil
	end
end

local function resolve(name)
	if resolved[name] then
		return resolved[name]
	end
	local def = tables[name]
	if not def then
		return nil
	end
	local pools = {}
	for _, pool in ipairs(def) do
		local entries, total = {}, 0
		for _, e in ipairs(pool.entries) do
			local item
			for _, c in ipairs(e.items or {}) do
				if core.registered_items[c] then
					item = c
					break
				end
			end
			if item or not e.items then
				entries[#entries + 1] = { name = item, w = e.w, n = e.n, ench = e.ench, }
				total = total + e.w
			end
		end
		pools[#pools + 1] = { rolls = pool.rolls, entries = entries, total = total, }
	end
	resolved[name] = pools
	return pools
end

-- A list of ItemStacks, or nil for an unknown table. rand(a, b) defaults to
-- math.random.
function loot.roll(name, rand)
	rand = rand or math.random
	local pools = resolve(name)
	if not pools then
		return nil
	end
	local out = {}
	for _, pool in ipairs(pools) do
		if pool.total > 0 then
			for _ = 1, rand(pool.rolls[1], pool.rolls[2]) do
				local r = rand(1, pool.total)
				for _, e in ipairs(pool.entries) do
					r = r - e.w
					if r <= 0 then
						if e.name then
							local st = ItemStack(e.name)
							st:set_count(math.min(e.n and rand(e.n[1], e.n[2]) or 1, st:get_stack_max()))
							if e.ench and loot.on_stack then
								st = loot.on_stack(st, e, rand) or st
							end
							out[#out + 1] = st
						end
						break
					end
				end
			end
		end
	end
	return out
end

-- Fills a structure chest once, into random free slots. True if it was filled.
function loot.open(pos)
	local meta = core.get_meta(pos)
	-- an empty structure chest gets its inventory only now (see build.lua)
	if meta:get_inventory():get_size("main") == 0 then
		local def = core.registered_nodes[core.get_node(pos).name]
		if def and def.on_construct then
			def.on_construct(pos)
		end
	end
	local name = meta:get_string("cb_loot")
	if name == "" then
		return false
	end
	meta:set_string("cb_loot", "")
	local inv = meta:get_inventory()
	local free = {}
	for i = 1, inv:get_size("main") do
		if inv:get_stack("main", i):is_empty() then
			free[#free + 1] = i
		end
	end
	for _, st in ipairs(loot.roll(name) or {}) do
		if #free == 0 then
			break
		end
		local k = math.random(#free)
		inv:set_stack("main", free[k], st)
		table.remove(free, k)
	end
	return true
end

-- Wrapped after all mods are loaded, so that mods overriding the chest later
-- in the load order still get the loot.
core.register_on_mods_loaded(function()
	for _, name in ipairs(loot.CONTAINERS) do
		local def = core.registered_nodes[name]
		if def then
			local click, can_dig, blast = def.on_rightclick, def.can_dig, def.on_blast
			core.override_item(name, {
				on_blast = blast and function(pos, ...)
					loot.open(pos)
					return blast(pos, ...)
				end or nil,
				on_rightclick = function(pos, ...)
					loot.open(pos)
					if click then
						return click(pos, ...)
					end
				end,
				can_dig = function(pos, ...)
					loot.open(pos)
					if can_dig then
						return can_dig(pos, ...)
					end
					return true
				end,
				_cb_loot = true,
			})
		end
	end
end)
