-- Scaffolding (spec cycle 10; textures from Mineclonia's mcl_bamboo). Climb
-- it like a ladder (jump up, sneak down). param2 is the distance from a
-- supported scaffolding: on a solid block 0, on scaffolding below the same,
-- sideways one more; beyond 6 it cannot be placed, and scaffolding that
-- loses its support breaks and drops. Using scaffolding on the top of a column builds
-- at the column's top.
local S = cb_blocks.S
local SC = { NODE = "cb_blocks:scaffolding", MAX = 6, }
cb_blocks.scaffolding = SC

local function is_sc(pos)
	return core.get_node(pos).name == SC.NODE
end

local SIDES = { vector.new(1, 0, 0), vector.new(-1, 0, 0), vector.new(0, 0, 1), vector.new(0, 0, -1), }

-- The distance a scaffolding at pos would have (nil = no support at all).
function SC.distance(pos)
	local below = vector.offset(pos, 0, -1, 0)
	local bn = core.get_node(below)
	if bn.name == SC.NODE then
		return bn.param2
	end
	local bdef = core.registered_nodes[bn.name]
	if bdef and bdef.walkable then
		return 0
	end
	local best
	for _, d in ipairs(SIDES) do
		local n = core.get_node(vector.add(pos, d))
		if n.name == SC.NODE then
			best = math.min(best or 99, n.param2 + 1)
		end
	end
	return best
end

-- Re-checks the scaffolding connected to pos after a change: distances are
-- worked out again from the supported ones (a solid block under them; going
-- up keeps the distance, sideways adds one); what is cut off or too far
-- breaks and drops. Capped at 2048 nodes.
local updating = false

function SC.update(pos)
	if updating then
		return
	end
	updating = true
	local all, order, i = {}, {}, 1
	local ALL6 = { vector.new(0, 1, 0), vector.new(0, -1, 0), SIDES[1], SIDES[2], SIDES[3], SIDES[4], }
	local start = {}
	for _, d in ipairs(ALL6) do
		start[#start + 1] = vector.add(pos, d)
	end
	if is_sc(pos) then
		start[#start + 1] = pos
	end
	for _, q in ipairs(start) do
		local h = core.hash_node_position(q)
		if is_sc(q) and not all[h] then
			all[h] = q
			order[#order + 1] = q
		end
	end
	while order[i] and #order < 2048 do
		for _, d in ipairs(ALL6) do
			local q = vector.add(order[i], d)
			local h = core.hash_node_position(q)
			if not all[h] and is_sc(q) then
				all[h] = q
				order[#order + 1] = q
			end
		end
		i = i + 1
	end
	-- 0-1 breadth-first search from the supported ones
	local dist, front, back = {}, {}, {}
	for h, q in pairs(all) do
		local below = core.get_node(vector.offset(q, 0, -1, 0)).name
		local bdef = core.registered_nodes[below]
		if below ~= SC.NODE and bdef and bdef.walkable then
			dist[h] = 0
			front[#front + 1] = q
		end
	end
	while #front > 0 or #back > 0 do
		local q
		if #front > 0 then
			q = table.remove(front)
		else
			q = table.remove(back, 1)
		end
		local d = dist[core.hash_node_position(q)]
		local up = vector.offset(q, 0, 1, 0)
		local hu = core.hash_node_position(up)
		if all[hu] and (dist[hu] == nil or dist[hu] > d) then
			dist[hu] = d
			front[#front + 1] = up
		end
		for _, s in ipairs(SIDES) do
			local n = vector.add(q, s)
			local hn = core.hash_node_position(n)
			if all[hn] and d + 1 <= SC.MAX and (dist[hn] == nil or dist[hn] > d + 1) then
				dist[hn] = d + 1
				back[#back + 1] = n
			end
		end
	end
	for h, q in pairs(all) do
		local d = dist[h]
		if not d then
			core.set_node(q, { name = "air", })
			core.add_item(q, SC.NODE)
		elseif core.get_node(q).param2 ~= d then
			core.swap_node(q, { name = SC.NODE, param2 = d, })
		end
	end
	updating = false
end

-- Where a scaffolding used on `pointed` goes: the top of the column when the
-- top face of scaffolding is pointed, else the usual place.
function SC.place_pos(pointed)
	if is_sc(pointed.under) and pointed.above.y > pointed.under.y then
		local p = vector.copy(pointed.under)
		while is_sc(vector.offset(p, 0, 1, 0)) do
			p = vector.offset(p, 0, 1, 0)
		end
		return vector.offset(p, 0, 1, 0)
	end
	return pointed.above
end

function SC.place(itemstack, placer, pointed)
	if not (pointed and pointed.type == "node") then
		return itemstack
	end
	local name = placer and placer:get_player_name() or ""
	local udef = core.registered_nodes[core.get_node(pointed.under).name]
	if udef and udef.on_rightclick and not is_sc(pointed.under) and placer and not placer:get_player_control().sneak then
		return udef.on_rightclick(pointed.under, core.get_node(pointed.under), placer, itemstack, pointed) or itemstack
	end
	local pos = SC.place_pos(pointed)
	local here = core.registered_nodes[core.get_node(pos).name]
	if not (here and here.buildable_to) or core.is_protected(pos, name) then
		return itemstack
	end
	local dist = SC.distance(pos)
	if not dist or dist > SC.MAX then
		return itemstack
	end
	core.set_node(pos, { name = SC.NODE, param2 = dist, })
	core.sound_play("default_place_node", { pos = pos, gain = 0.5, }, true)
	if not core.is_creative_enabled(name) then
		itemstack:take_item(1)
	end
	return itemstack
end

core.register_node(SC.NODE, {
	description = S("Scaffolding") .. "\n" .. S("Climb it; up to 6 sideways from a supported one"),
	drawtype = "nodebox", paramtype = "light", sunlight_propagates = true, paramtype2 = "none",
	tiles = { "cb_blocks_scaffolding_top.png", "cb_blocks_scaffolding_top.png", "cb_blocks_scaffolding_side.png", },
	use_texture_alpha = "clip",
	node_box = { type = "fixed", fixed = {
		{ -0.5, 0.375, -0.5, 0.5, 0.5, 0.5, },
		{ -0.5, -0.5, -0.5, -0.375, 0.375, -0.375, }, { 0.375, -0.5, -0.5, 0.5, 0.375, -0.375, },
		{ -0.5, -0.5, 0.375, -0.375, 0.375, 0.5, }, { 0.375, -0.5, 0.375, 0.5, 0.375, 0.5, },
	}, },
	selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5, }, },
	walkable = false, climbable = true, is_ground_content = false,
	groups = { choppy = 3, oddly_breakable_by_hand = 3, flammable = 2, dig_immediate = 3, },
	sounds = default.node_sound_wood_defaults(),
	on_place = SC.place,
	after_destruct = function(pos)
		SC.update(pos)
	end,
})

local bamboo = core.registered_items["ethereal:bamboo"] and "ethereal:bamboo" or "default:papyrus"
core.register_craft({
	output = SC.NODE .. " 6",
	recipe = { { bamboo, "farming:string", bamboo, }, { bamboo, "", bamboo, }, { bamboo, "", bamboo, }, },
})
