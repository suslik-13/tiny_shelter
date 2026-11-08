-- Zombies break plain wooden doors (12 s of blows) and glass (3 s) that
-- stand between them and their target, never where protection (areas,
-- protector, pocket shells) forbids it (spec cycle 4, 8a). Progress lives on
-- the mob and resets when the blocker or the target changes. Runs from the
-- zombie's do_custom every 0.5 s while it attacks.
local Z = cb_mobs_overworld
local B = { DOOR_TIME = 12, GLASS_TIME = 3, REACH = 1.5, TICK = 0.5, on_door_broken = {}, }
Z.breaker = B

local function door_bottom(pos)
	local node = core.get_node(pos)
	if node.name == "doors:hidden" then
		return vector.offset(pos, 0, -1, 0), core.get_node(vector.offset(pos, 0, -1, 0))
	end
	return pos, node
end

-- "door", "glass" or nil. The node is looked at first: protection lookups
-- (protector scans 11^3 nodes) only run for doors and glass.
function B.kind(pos)
	pos = vector.round(pos)
	local bp, node = door_bottom(pos)
	local def = core.registered_nodes[node.name]
	if not def then
		return nil
	end
	local kind
	if core.get_item_group(node.name, "door") > 0 then
		local meta = core.get_meta(bp)
		if not def.protected and core.get_item_group(node.name, "choppy") > 0 and meta:get_string("owner") == ""
				and meta:get_string("doors_owner") == "" then
			kind = "door"
		end
	elseif node.name ~= "default:obsidian_glass" and (node.name == "default:glass"
			or core.get_item_group(node.name, "glass") > 0) and not node.name:find("^cb_") then
		kind = "glass"
	end
	if kind and (core.is_protected(bp, "") or (kind == "door" and core.is_protected(vector.offset(bp, 0, 1, 0), ""))) then
		return nil
	end
	return kind
end

function B.blocker(from, to)
	local dir = vector.subtract(to, from)
	dir.y = 0
	if vector.length(dir) < 0.1 then
		return nil
	end
	dir = vector.normalize(dir)
	for _, dy in ipairs({ 0, 1, }) do
		for _, d in ipairs({ 0.6, 1.0, B.REACH, }) do
			local p = vector.round(vector.add(vector.offset(from, 0, dy, 0), vector.multiply(dir, d)))
			local kind = B.kind(p)
			if kind then
				local bottom = door_bottom(p)
				return bottom, kind
			end
		end
	end
end

local function hit_sound(pos)
	core.sound_play("cb_mobs_overworld_door_hit", { pos = pos, max_hear_distance = 16, }, true)
end

local function break_node(pos, kind)
	if kind == "door" then
		local node = core.get_node(pos)
		local top = vector.offset(pos, 0, 1, 0)
		local info = { n = node.name, r = node.param2, h = core.get_node(top).param2,
			s = core.get_meta(pos):get_int("state"), }
		local def = core.registered_nodes[node.name]
		local drop = def and type(def.drop) == "string" and def.drop or node.name:gsub("_[a-d]$", "")
		core.remove_node(pos)
		if core.get_node(top).name == "doors:hidden" then
			core.remove_node(top)
		end
		core.add_item(vector.offset(pos, 0, 0.5, 0), drop)
		for _, fn in ipairs(B.on_door_broken) do
			fn(pos, info)
		end
	else
		core.remove_node(pos)
		core.sound_play("default_break_glass", { pos = pos, max_hear_distance = 16, }, true)
	end
end

function B.step(self, target_pos, dt)
	local pos = self.object:get_pos()
	if not (pos and target_pos) then
		self._brk = nil
		return false
	end
	local bp, kind = B.blocker(pos, target_pos)
	if not bp then
		self._brk = nil
		return false
	end
	local st = self._brk
	if not st or not vector.equals(st.pos, bp) then
		st = { pos = bp, t = 0, s = 0, }
		self._brk = st
	end
	st.t, st.s = st.t + dt, st.s + dt
	if st.s >= 1 then
		st.s = 0
		hit_sound(bp)
	end
	if st.t >= (kind == "door" and B.DOOR_TIME or B.GLASS_TIME) - 1e-6 then
		self._brk = nil
		break_node(bp, kind)
		return true
	end
	return false
end

-- in the zombies' do_custom: every TICK while attacking
local function zombie_step(self, dtime)
	self._brk_t = (self._brk_t or 0) + dtime
	if self._brk_t < B.TICK then
		return true
	end
	local dt = self._brk_t
	self._brk_t = 0
	local t = self.state == "attack" and self.attack
	B.step(self, t and t.get_pos and t:get_pos(), dt)
	return true
end

for _, name in ipairs({ Z.ZOMBIE, Z.HUSK, }) do
	table.insert(Z.custom[name], zombie_step)
end

if rawget(_G, "cb_structures") and cb_structures.village and cb_structures.village.note_broken_door then
	table.insert(B.on_door_broken, cb_structures.village.note_broken_door)
end
