-- Eye of ender (spec 5.4): thrown in the overworld it flies FLIGHT nodes
-- towards the portal room of the nearest built stronghold, rising, then drops
-- as an item or breaks. The entity lives TIME seconds and is never saved.
local S = cb_portals.S
local E = { FLIGHT = 12, TIME = 2, RISE = 4, BREAK = 0.2, }
cb_portals.eye = E

local function target_of(rec)
	return rec.target or vector.new(math.floor((rec.minp.x + rec.maxp.x) / 2), rec.minp.y,
		math.floor((rec.minp.z + rec.maxp.z) / 2))
end

-- The target of the nearest ready stronghold (horizontal distance), or nil.
function E.nearest(pos)
	local best, bd
	for _, rec in pairs(cb_structures.registry.all()) do
		if rec.type == "stronghold" and rec.state == "ready" then
			local t = target_of(rec)
			local dx, dz = t.x - pos.x, t.z - pos.z
			local d = dx * dx + dz * dz
			if not bd or d < bd then
				best, bd = t, d
			end
		end
	end
	return best and vector.copy(best)
end

function E.stop_point(from, target)
	local dx, dz = target.x - from.x, target.z - from.z
	local d = math.sqrt(dx * dx + dz * dz)
	local k = d > E.FLIGHT and E.FLIGHT / d or 1
	return vector.new(from.x + dx * k, from.y + E.RISE, from.z + dz * k)
end

-- roll < BREAK: it breaks; else it drops as an item. Returns true on a drop.
function E.land(pos, roll)
	if (roll or math.random()) < E.BREAK then
		core.sound_play("default_break_glass", { pos = pos, max_hear_distance = 16, }, true)
		return false
	end
	core.add_item(pos, "cb_items:ender_eye")
	return true
end

core.register_entity("cb_portals:ender_eye_entity", {
	initial_properties = {
		physical = false,
		pointable = false,
		visual = "sprite",
		visual_size = { x = 0.4, y = 0.4, },
		textures = { "cb_items_ender_eye.png", },
		glow = 8,
		static_save = false,
	},
	_age = 0,
	on_step = function(self, dtime)
		self._age = self._age + dtime
		if self._age >= E.TIME then
			local pos = self.object:get_pos()
			self.object:remove()
			E.land(pos)
		end
	end,
})

-- Returns the flying entity, or nil and a message (the eye stays in hand).
function E.launch(pos)
	if cb_structures.dim_at(pos) ~= "overworld" then
		return nil, S("The eye of ender only works in the overworld.")
	end
	local target = E.nearest(pos)
	if not target then
		return nil, S("The eye of ender finds no stronghold.")
	end
	local obj = core.add_entity(pos, "cb_portals:ender_eye_entity")
	if not obj then
		return nil, S("The eye of ender finds no stronghold.")
	end
	obj:set_velocity(vector.divide(vector.subtract(E.stop_point(pos, target), pos), E.TIME))
	return obj
end

local function throw(itemstack, user)
	if not (user and user:is_player()) then
		return itemstack
	end
	local name = user:get_player_name()
	local obj, msg = E.launch(vector.offset(user:get_pos(), 0, 1.5, 0))
	if not obj then
		core.chat_send_player(name, msg)
		return itemstack
	end
	core.sound_play("cb_items_throw", { pos = obj:get_pos(), max_hear_distance = 16, }, true)
	if not core.is_creative_enabled(name) then
		itemstack:take_item()
	end
	return itemstack
end

core.override_item("cb_items:ender_eye", {
	on_use = throw,
	on_secondary_use = throw,
	on_place = function(itemstack, placer, pointed)
		if pointed and pointed.type == "node" then
			local node = core.get_node(pointed.under)
			local def = core.registered_nodes[node.name]
			local sneak = placer and placer.get_player_control and placer:get_player_control().sneak
			if def and def.on_rightclick and not sneak then
				return def.on_rightclick(pointed.under, node, placer, itemstack, pointed) or itemstack
			end
		end
		return throw(itemstack, placer)
	end,
})
