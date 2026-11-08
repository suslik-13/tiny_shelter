-- The Nether portal node, frame detection, lighting and putting out.
local S = cb_portals.S
local NODE = cb_portals.NODE
local OBSIDIAN = cb_core.equiv("obsidian")
local MIN_W, MIN_H, MAX = 2, 3, 21

core.register_node(NODE, {
	description = S("Nether Portal"),
	drawtype = "nodebox",
	node_box = { type = "fixed", fixed = { -0.5, -0.5, -0.125, 0.5, 0.5, 0.125, }, },
	tiles = { { name = "cb_portals_nether_portal.png", animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 0.8, }, }, },
	use_texture_alpha = "blend",
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	light_source = 11,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = false,
	is_ground_content = false,
	drop = "",
	post_effect_color = { a = 160, r = 110, g = 20, b = 190, },
	groups = { not_in_creative_inventory = 1, },
	on_blast = function()
	end,
})

local function name(p)
	return core.get_node(p).name
end

local function open(n)
	return n == "air" or n == "fire:basic_flame" or n == "fire:permanent_flame" or n == NODE
end

function cb_portals.along(p, axis, k)
	if axis == "x" then
		return vector.offset(p, k, 0, 0)
	end
	return vector.offset(p, 0, 0, k)
end
local along = cb_portals.along

-- The frame whose opening contains `seed` in the plane of `axis`, or nil.
-- Openings from 2x3 to 21x21; frame corners are not required.
function cb_portals.find_frame(seed, axis)
	if not open(name(seed)) then
		return nil
	end
	local bottom = vector.copy(seed)
	for _ = 1, MAX do
		if not open(name(vector.offset(bottom, 0, -1, 0))) then
			break
		end
		bottom.y = bottom.y - 1
	end
	local left = bottom
	for _ = 1, MAX do
		if not open(name(along(left, axis, -1))) then
			break
		end
		left = along(left, axis, -1)
	end
	local w = 1
	while w <= MAX and open(name(along(left, axis, w))) do
		w = w + 1
	end
	local h = 1
	while h <= MAX and open(name(vector.offset(left, 0, h, 0))) do
		h = h + 1
	end
	if w < MIN_W or w > MAX or h < MIN_H or h > MAX then
		return nil
	end
	for i = 0, w - 1 do
		local col = along(left, axis, i)
		if name(vector.offset(col, 0, -1, 0)) ~= OBSIDIAN or name(vector.offset(col, 0, h, 0)) ~= OBSIDIAN then
			return nil
		end
		for j = 0, h - 1 do
			if not open(name(vector.offset(col, 0, j, 0))) then
				return nil
			end
		end
	end
	for j = 0, h - 1 do
		local row = vector.offset(left, 0, j, 0)
		if name(along(row, axis, -1)) ~= OBSIDIAN or name(along(row, axis, w)) ~= OBSIDIAN then
			return nil
		end
	end
	return { pos = left, axis = axis, w = w, h = h, }
end

function cb_portals.frame_intact(p)
	local f = cb_portals.find_frame(p.pos, p.axis)
	return f ~= nil and f.w == p.w and f.h == p.h and vector.equals(f.pos, p.pos)
end

function cb_portals.activate(frame, dim)
	local param2 = frame.axis == "x" and 0 or 1
	for i = 0, frame.w - 1 do
		for j = 0, frame.h - 1 do
			core.set_node(vector.offset(along(frame.pos, frame.axis, i), 0, j, 0), { name = NODE, param2 = param2, })
		end
	end
	frame.dim = dim or cb_portals.dim_at(frame.pos)
	return cb_portals.add(frame)
end

function cb_portals.deactivate(p)
	cb_portals.remove(p)
	for i = 0, p.w - 1 do
		for j = 0, p.h - 1 do
			local q = vector.offset(along(p.pos, p.axis, i), 0, j, 0)
			if name(q) == NODE then
				core.remove_node(q)
			end
		end
	end
end

local NEAR = {
	vector.new(0, 0, 0), vector.new(0, 1, 0), vector.new(0, -1, 0),
	vector.new(1, 0, 0), vector.new(-1, 0, 0), vector.new(0, 0, 1), vector.new(0, 0, -1),
}

-- Portals light in the overworld and the Nether, never inside other pockets.
local function lightable(pos)
	for dim, pocket in pairs(cb_dimensions.all()) do
		if dim ~= "nether" and cb_core.inside(pos, pocket.minp, pocket.maxp) then
			return false
		end
	end
	return true
end

function cb_portals.try_ignite(pos)
	if not lightable(pos) then
		return nil
	end
	for _, off in ipairs(NEAR) do
		local seed = vector.add(pos, off)
		if not cb_portals.covering(seed) then
			for _, axis in ipairs({ "x", "z", }) do
				local f = cb_portals.find_frame(seed, axis)
				if f and not cb_portals.covering(f.pos) then
					return cb_portals.activate(f)
				end
			end
		end
	end
end

function cb_portals.frame_broken(pos)
	for k = 2, #NEAR do
		local q = vector.add(pos, NEAR[k])
		if name(q) == NODE then
			local p = cb_portals.covering(q)
			if p then
				cb_portals.deactivate(p)
			else
				core.remove_node(q)
			end
		end
	end
end

local odef = core.registered_nodes[OBSIDIAN]
local old_ignite, old_after_destruct = odef.on_ignite, odef.after_destruct
core.override_item(OBSIDIAN, {
	on_ignite = function(pos, igniter)
		if not cb_portals.try_ignite(pos) and old_ignite then
			return old_ignite(pos, igniter)
		end
	end,
	after_destruct = function(pos, oldnode)
		cb_portals.frame_broken(pos)
		if old_after_destruct then
			return old_after_destruct(pos, oldnode)
		end
	end,
})

local flame = core.registered_nodes["fire:basic_flame"]
if flame then
	local old_construct = flame.on_construct
	core.override_item("fire:basic_flame", {
		on_construct = function(pos)
			if old_construct then
				old_construct(pos)
			end
			core.after(0, function()
				if core.get_node(pos).name == "fire:basic_flame" then
					cb_portals.try_ignite(pos)
				end
			end)
		end,
	})
end
