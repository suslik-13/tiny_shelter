-- Doors for mobs (spec cycle 5, 4.1): villagers, raiders and the wandering
-- trader open plain wooden doors in their way and close those they opened.
-- Wooden = a door of the doors mod (any mod's doors.register) with the choppy
-- group and not protected; steel, glass and obsidian doors, gates and
-- trapdoors are never touched. Protection does not matter: mobs open doors
-- the way they always could in MC, and nothing is ever broken here.
local D = {}
cb_core.doors = D

local HIDDEN = "doors:hidden"
local AXES = { vector.new(1, 0, 0), vector.new(0, 0, 1), }

-- The lower node of the door at pos (either half), or nil.
function D.bottom(pos)
	pos = vector.round(pos)
	local name = core.get_node(pos).name
	if name == HIDDEN then
		pos = vector.offset(pos, 0, -1, 0)
		name = core.get_node(pos).name
	end
	if rawget(_G, "doors") and doors.registered_doors[name] then
		return pos
	end
end

function D.wooden(pos)
	local bp = D.bottom(pos)
	if not bp then
		return false
	end
	local name = core.get_node(bp).name
	local def = core.registered_nodes[name]
	return def ~= nil and not def.protected and core.get_item_group(name, "door") > 0
		and core.get_item_group(name, "choppy") > 0
end

function D.is_open(pos)
	local bp = D.bottom(pos)
	return bp ~= nil and doors.get(bp):state()
end

-- Opens (closes) a wooden door; true when it changed.
function D.open(pos)
	local bp = D.bottom(pos)
	return bp ~= nil and D.wooden(bp) and doors.get(bp):open(nil) or false
end

function D.close(pos)
	local bp = D.bottom(pos)
	return bp ~= nil and D.wooden(bp) and doors.get(bp):close(nil) or false
end

local function free(p)
	for dy = 0, 1 do
		local def = core.registered_nodes[core.get_node(vector.offset(p, 0, dy, 0)).name]
		if not def or def.walkable then
			return false
		end
	end
	return true
end

-- The two floor cells across the door: along the axis with more free
-- neighbours (a door stands in a wall), ties broken by the door's facing.
function D.sides(pos)
	local bp = D.bottom(pos)
	if not bp then
		return nil
	end
	local best, score = nil, -1
	for _, ax in ipairs(AXES) do
		local s = (free(vector.add(bp, ax)) and 1 or 0) + (free(vector.subtract(bp, ax)) and 1 or 0)
		if s > score then
			best, score = ax, s
		elseif s == score then
			local f = core.facedir_to_dir(core.get_node(bp).param2 % 4)
			if math.abs(f.x) == ax.x and math.abs(f.z) == ax.z then
				best = ax
			end
		end
	end
	return vector.subtract(bp, best), vector.add(bp, best)
end

-- Lower nodes of wooden doors within r of pos.
function D.near(pos, r)
	pos = vector.round(pos)
	local out = {}
	for _, p in ipairs(core.find_nodes_in_area(vector.offset(pos, -r, -r, -r), vector.offset(pos, r, r, r),
			{ "group:door", })) do
		if core.get_node(p).name ~= HIDDEN and D.wooden(p) then
			out[#out + 1] = p
		end
	end
	return out
end

-- Something other than skip stands in the doorway.
function D.occupied(pos, skip)
	local bp = D.bottom(pos) or vector.round(pos)
	for _, obj in ipairs(core.get_objects_inside_radius(vector.offset(bp, 0, -0.5, 0), 0.9)) do
		local e = obj:get_luaentity()
		if obj ~= skip and (obj:is_player() or (e and e.name ~= "__builtin:item")) then
			return true
		end
	end
	return false
end

-- For mobs without a path of their own: a closed wooden door just ahead of
-- a walking mob opens; once the mob is 2 away it closes again if this mob
-- opened it and the doorway is clear. true when it opened a door.
function D.bump(self, dt)
	local pos = self.object:get_pos()
	if not pos then
		return false
	end
	local held = self._cb_door
	if held then
		if math.hypot(pos.x - held.p.x, pos.z - held.p.z) >= 2 then
			if held.opened and D.is_open(held.p) and not D.occupied(held.p, self.object) then
				D.close(held.p)
			end
			self._cb_door = nil
		end
		return false
	end
	local v = self.object:get_velocity()
	local speed = math.hypot(v.x, v.z)
	if speed < 0.2 then
		return false
	end
	-- ahead, and ahead to either side: a mob sliding along a wall finds the
	-- door beside its way too
	local dir = vector.new(v.x / speed, 0, v.z / speed)
	local side = vector.new(-dir.z, 0, dir.x)
	local feet = vector.offset(pos, 0, 0.5, 0)
	for _, d in ipairs({ 0.6, 1.0, 1.2, }) do
		for _, sd in ipairs({ 0, 0.8, -0.8, }) do
			local bp = D.bottom(vector.add(feet, vector.add(vector.multiply(dir, d), vector.multiply(side, sd))))
			if bp and D.wooden(bp) and not D.is_open(bp) and D.open(bp) then
				self._cb_door = { p = bp, opened = true, }
				return true
			end
		end
	end
	return false
end
