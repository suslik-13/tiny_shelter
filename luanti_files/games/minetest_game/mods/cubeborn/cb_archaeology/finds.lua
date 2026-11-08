-- What brushing a suspicious block turns up (Bedrock weights, as Mineclonia
-- mcl_sus_nodes). An entry lists candidates; the first registered one is
-- used, an entry without one is left out.
local A = cb_archaeology

local function sherd(name, w)
	return { items = { "cb_archaeology:sherd_" .. name, }, w = w, }
end

local function item(name, w)
	return { items = type(name) == "table" and name or { name, }, w = w, }
end

local EMERALD = { "cb_items:emerald", }
local COMMON = {
	item("default:coal_lump", 2), item(EMERALD, 2), item("farming:wheat", 2), item("farming:hoe_wood", 2),
	item("cb_items:gold_nugget", 2),
}

local function with_common(list)
	local out = table.copy(COMMON)
	for _, e in ipairs(list) do
		out[#out + 1] = e
	end
	return out
end

A.FINDS = {
	desert_well = {
		sherd("arms_up", 2), sherd("brewer", 2), item("default:clay_brick", 1), item(EMERALD, 1),
		item("default:stick", 1),
	},
	desert_pyramid = {
		sherd("archer", 1), item(EMERALD, 1), item("tnt:gunpowder", 1), sherd("miner", 1), sherd("prize", 1),
		sherd("skull", 1), item("tnt:tnt", 1), item("default:diamond", 1),
	},
	ocean_ruins_cold = with_common({
		sherd("blade", 1), sherd("explorer", 1), sherd("mourner", 1), sherd("plenty", 1),
		item("default:axe_steel", 1),
	}),
	-- Bedrock trail_ruins_common: coloured panes and hanging signs as the
	-- servers' plain glass pane and wall sign (their weights summed).
	trail_ruins_common = {
		item(EMERALD, 2), item("farming:wheat", 2), item("farming:hoe_wood", 2), item("default:clay_lump", 2),
		item("default:clay_brick", 2), item("dye:yellow", 2), item("dye:blue", 2), item("dye:cyan", 2),
		item("dye:white", 2), item("dye:orange", 2), item("cb_blocks:candle_1", 2), item("xpanes:pane_flat", 6),
		item("default:sign_wall_wood", 2), item("cb_items:gold_nugget", 1), item("default:coal_lump", 1),
		item("farming:seed_wheat", 1), item("farming:beetroot", 1), item("default:dry_shrub", 1),
		item("farming:string", 1), item("leads:lead", 1),
	},
	trail_ruins_rare = {
		sherd("burn", 1), sherd("danger", 1), sherd("friend", 1), sherd("heart", 1), sherd("heartbreak", 1),
		sherd("howl", 1), sherd("sheaf", 1), item("cb_items:trim_wayfinder", 1), item("cb_items:trim_raiser", 1),
		item("cb_items:trim_shaper", 1), item("cb_items:trim_host", 1),
	},
	ocean_ruins_warm = with_common({
		sherd("angler", 1), sherd("shelter", 1), sherd("snort", 1), item("cb_mobs_animals:sniffer_egg_0", 1),
		item("default:axe_steel", 1),
	}),
}

local function first(items)
	for _, n in ipairs(items) do
		if core.registered_items[n] then
			return n
		end
	end
end

-- One weighted pick from table `name`, the same for the same seed; nil for an
-- unknown or empty table.
function A.find(name, seed)
	local entries = A.FINDS[name]
	if not entries then
		return nil
	end
	local pool, total = {}, 0
	for _, e in ipairs(entries) do
		local n = first(e.items)
		if n then
			pool[#pool + 1] = { n, e.w, }
			total = total + e.w
		end
	end
	if total == 0 then
		return nil
	end
	local r = PcgRandom(seed):next(1, total)
	for _, e in ipairs(pool) do
		r = r - e[2]
		if r <= 0 then
			return ItemStack(e[1])
		end
	end
end
