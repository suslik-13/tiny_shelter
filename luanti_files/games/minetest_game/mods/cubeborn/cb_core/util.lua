-- Settings and box helpers shared by all Cubeborn mods. Positions may be plain
-- {x, y, z} tables (as restored by core.deserialize).

function cb_core.setting(name, default)
	local value = core.settings:get(name)
	if value == nil or value == "" then
		return default
	end
	return value
end

function cb_core.setting_vector(name, default)
	local value = core.settings:get(name)
	if value and value ~= "" then
		local x, y, z = value:match("^%s*(-?%d+)%s*,%s*(-?%d+)%s*,%s*(-?%d+)%s*$")
		if x then
			return vector.new(tonumber(x), tonumber(y), tonumber(z))
		end
		core.log("warning", "[cubeborn] invalid vector setting " .. name .. " = " .. value)
	end
	return vector.copy(default)
end

function cb_core.inside(p, a, b)
	return p.x >= a.x and p.x <= b.x and p.y >= a.y and p.y <= b.y
		and p.z >= a.z and p.z <= b.z
end

-- Intersection of two boxes, or nil when they do not touch.
function cb_core.intersect(a0, a1, b0, b1)
	local lo = vector.new(math.max(a0.x, b0.x), math.max(a0.y, b0.y), math.max(a0.z, b0.z))
	local hi = vector.new(math.min(a1.x, b1.x), math.min(a1.y, b1.y), math.min(a1.z, b1.z))
	if lo.x > hi.x or lo.y > hi.y or lo.z > hi.z then
		return nil
	end
	return lo, hi
end

-- Mapblock coordinates that cover a node box.
function cb_core.block_range(minp, maxp)
	local function b(v)
		return math.floor(v / 16)
	end
	return vector.new(b(minp.x), b(minp.y), b(minp.z)), vector.new(b(maxp.x), b(maxp.y), b(maxp.z))
end

function cb_core.block_count(b0, b1)
	return (b1.x - b0.x + 1) * (b1.y - b0.y + 1) * (b1.z - b0.z + 1)
end

-- The i-th (0-based) mapblock of a block range; x runs fastest.
function cb_core.block_at(b0, b1, i)
	local sx, sy = b1.x - b0.x + 1, b1.y - b0.y + 1
	return vector.new(b0.x + i % sx, b0.y + math.floor(i / sx) % sy, b0.z + math.floor(i / (sx * sy)))
end

-- Mineclonia models whose head hangs on a "head.control" bone: Mineclonia
-- moves that bone every step (head swivel), mobs_redo never does, and its rest
-- pose folds the head into the back. Pins it where Mineclonia's neutral swivel
-- puts it: (0, y, z) in bone units, no rotation. Wraps def.after_activate.
function cb_core.fixed_head(def, y, z, bone)
	local after = def.after_activate
	local override = {
		position = { vec = vector.new(0, y, z or 0), absolute = true, },
		rotation = { vec = vector.zero(), absolute = true, },
	}
	def.after_activate = function(self, ...)
		self.object:set_bone_override(bone or "head.control", override)
		if after then
			return after(self, ...)
		end
	end
	return def
end
