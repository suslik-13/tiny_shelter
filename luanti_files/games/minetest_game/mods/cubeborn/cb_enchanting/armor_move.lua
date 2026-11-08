-- Respiration, Depth Strider and Frost Walker (spec 5): one 0.5 s loop over
-- the online players whose worn armor has them (E.movers, refreshed when
-- 3d_armor updates a player's armor).
local E = cb_enchanting
local P = cb_core.physics
local S = E.S
E.FROSTED_ICE = "cb_enchanting:frosted_ice"
local WATER = "default:water_source"
E.movers = {}

-- The levels of the moving enchantments in `stacks`, or nil if none.
function E.mover_info(stacks)
	local info
	for _, s in ipairs(stacks) do
		if not s:is_empty() then
			local ench = E.get(s)
			for _, n in ipairs({ "respiration", "depth_strider", "frost_walker", }) do
				if (ench[n] or 0) > 0 then
					info = info or {}
					info[n] = math.max(info[n] or 0, ench[n])
				end
			end
		end
	end
	return info
end

local ice_sounds = default.node_sound_ice_defaults and default.node_sound_ice_defaults() or default.node_sound_glass_defaults()
local function melt(pos)
	core.set_node(pos, { name = WATER, })
end
core.register_node(E.FROSTED_ICE, {
	description = S("Frosted Ice"),
	tiles = { "default_ice.png^[opacity:210", },
	use_texture_alpha = "blend",
	paramtype = "light",
	groups = { cracky = 3, slippery = 3, not_in_creative_inventory = 1, },
	drop = "",
	is_ground_content = false,
	sounds = ice_sounds,
	on_construct = function(pos)
		core.get_node_timer(pos):start(math.random(6, 12))
	end,
	on_timer = melt,
	after_dig_node = melt,
	on_blast = melt,
})

-- Frost Walker: water sources around `pos` (the level under the feet), with
-- air above and not protected from `name`, turn into frosted ice.
function E.freeze(pos, level, name)
	local r = 2 + level
	local c = vector.round(pos)
	local n = 0
	for _, p in ipairs(core.find_nodes_in_area(vector.offset(c, -r, 0, -r), vector.offset(c, r, 0, r), { WATER, })) do
		local dx, dz = p.x - c.x, p.z - c.z
		if dx * dx + dz * dz <= r * r and core.get_node(vector.offset(p, 0, 1, 0)).name == "air"
				and not core.is_protected(p, name) then
			core.set_node(p, { name = E.FROSTED_ICE, })
			n = n + 1
		end
	end
	return n
end

-- Respiration: a lost breath point comes back with chance L / (L + 1).
function E.keep_breath(player, info, level)
	local b = player:get_breath()
	if info.breath and b < info.breath and math.random() < level / (level + 1) then
		b = info.breath
		player:set_breath(b)
	end
	info.breath = b
end

local function water_at(pos)
	local def = core.registered_nodes[core.get_node(vector.round(pos)).name]
	return def and (def.groups or {}).water and true or false
end

function E.move_step(player, info)
	local pos = player:get_pos()
	if not pos then
		return
	end
	if info.respiration then
		E.keep_breath(player, info, info.respiration)
	end
	local wet = water_at(pos)
	if info.depth_strider then
		local on = wet and 1 + info.depth_strider / 3 or nil
		if on ~= info.strider_on then
			if on then
				P.set_factor(player, "speed", "cb_depth_strider", on)
			else
				P.clear_factor(player, "speed", "cb_depth_strider")
			end
			info.strider_on = on
		end
	end
	if info.frost_walker and not wet then
		local under = vector.round(vector.offset(pos, 0, -0.5, 0))
		local def = core.registered_nodes[core.get_node(under).name]
		if def and (def.walkable or def.name == WATER) then
			E.freeze(under, info.frost_walker, player:get_player_name())
		end
	end
end

local function update(player)
	local name = player:get_player_name()
	local old = E.movers[name]
	local info = E.mover_info(E.worn(player))
	if old and old.strider_on and not (info and info.depth_strider) then
		P.clear_factor(player, "speed", "cb_depth_strider")
	end
	if info and old then
		info.strider_on = info.depth_strider and old.strider_on or nil
		info.breath = old.breath
	end
	E.movers[name] = info
end

local armor = rawget(_G, "armor")
if armor and armor.register_on_update then
	armor:register_on_update(update)
end

core.register_on_leaveplayer(function(player)
	E.movers[player:get_player_name()] = nil
end)

local acc = 0
core.register_globalstep(function(dtime)
	if not next(E.movers) then
		return
	end
	acc = acc + dtime
	if acc < 0.5 then
		return
	end
	acc = 0
	for name, info in pairs(E.movers) do
		local player = core.get_player_by_name(name)
		if player then
			E.move_step(player, info)
		end
	end
end)
