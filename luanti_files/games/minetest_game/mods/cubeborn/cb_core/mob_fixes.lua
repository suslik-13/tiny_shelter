-- Fixes to mobs_redo shared by every mob (BACKLOG 16). A dying mob keeps the
-- cause of death with the puncher object in it; a tame or npc mob saved then
-- (shutdown, unload during the death animation) crashed the serializer. The
-- cause is left out of the saved data and kept for the death drops.
core.register_on_mods_loaded(function()
	local mobs = rawget(_G, "mobs")
	local class = mobs and mobs.mob_class
	if not (class and class.mob_staticdata) then
		return
	end
	local mob_staticdata = class.mob_staticdata
	class.mob_staticdata = function(self, ...)
		local cause = self.cause_of_death
		self.cause_of_death = nil
		local ok, sd = pcall(mob_staticdata, self, ...)
		self.cause_of_death = cause
		if not ok then
			error(sd, 0)
		end
		return sd
	end
end)

-- The owner of a tamed Cubeborn mob names it with a name tag and protects it
-- with a protection rune. Cubeborn mobs have their own right-click handlers
-- that never reached mobs_redo's naming and protection, so the click is caught
-- first for every cb_mobs_* mob. Others keep the mob's own handler.
local OWNER_TOOLS = { ["mobs:nametag"] = true, ["mobs:protector"] = true, ["mobs:protector2"] = true, }

function cb_core.mob_owner_tool(self, clicker)
	local mobs = rawget(_G, "mobs")
	if not (mobs and self.tamed and clicker and clicker:is_player()) then
		return false
	end
	local item = clicker:get_wielded_item():get_name()
	local name = clicker:get_player_name()
	if not OWNER_TOOLS[item] or (self.owner ~= name and not core.check_player_privs(name, "protection_bypass")) then
		return false
	end
	if item == "mobs:nametag" then
		-- mobs_redo's name tag form (the food branch needs food in hand)
		return mobs:feed_tame(self, clicker, 1, false, false)
	end
	return mobs:protect(self, clicker)
end

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_entities) do
		if name:find("^cb_mobs_") and def._cmi_is_mob and def.on_rightclick then
			local on_rightclick = def.on_rightclick
			def.on_rightclick = function(self, clicker, ...)
				if cb_core.mob_owner_tool(self, clicker) then
					return
				end
				return on_rightclick(self, clicker, ...)
			end
		end
	end
end)

-- A mob whose box ended up inside nodes (a structure or a block placed onto
-- it, a wide mob spawned against a wall, a child grown up under a roof) falls
-- through the ground: the engine does not collide with nodes a box already
-- overlaps, and mobs_redo then lets it suffocate. Before mobs_redo's
-- suffocation damage, such a mob is lifted to the first place above where its
-- whole box fits (at most UNSTICK_UP nodes up).
cb_core.UNSTICK_UP = 8

local function solid(p)
	local def = core.registered_nodes[core.get_node(p).name]
	return def ~= nil and def.walkable ~= false
end

local function r(v)
	return math.floor(v + 0.5)
end

-- No walkable node inside the box (collisionbox relative to pos).
function cb_core.box_free(pos, box)
	for x = r(pos.x + box[1] + 0.01), r(pos.x + box[4] - 0.01) do
		for z = r(pos.z + box[3] + 0.01), r(pos.z + box[6] - 0.01) do
			for y = r(pos.y + box[2] + 0.01), r(pos.y + box[5] - 0.01) do
				if solid({ x = x, y = y, z = z, }) then
					return false
				end
			end
		end
	end
	return true
end

-- mobs_redo's own suffocation test: the node at the feet is a full solid node.
local function suffocating(self)
	local def = core.registered_nodes[self.standing_in or ""]
	return def ~= nil and (def.walkable == nil or def.walkable)
		and (def.collision_box == nil or def.collision_box.type == "regular")
		and (def.node_box == nil or def.node_box.type == "regular")
		and (def.groups.disable_suffocation or 0) ~= 1
end

function cb_core.mob_unstick(self)
	local pos = self.object:get_pos()
	if not pos then
		return false
	end
	local box = self.object:get_properties().collisionbox
	local feet = r(pos.y + box[2])
	for dy = 1, cb_core.UNSTICK_UP do
		local p = vector.new(pos.x, feet + dy - 0.5 - box[2] + 0.01, pos.z)
		if cb_core.box_free(p, box) then
			self.object:set_pos(p)
			self.object:set_velocity(vector.zero())
			self.standing_in = core.get_node(vector.new(p.x, p.y + box[2] + 0.25, p.z)).name
			return true
		end
	end
	return false
end

-- Swimming Cubeborn mobs never head out of the water: mobs_redo moves them
-- along their yaw without looking ahead, and fleeing or wandering fish, squid
-- and dolphins threw themselves onto flat beaches and choked (or climbed the
-- sloping bottom onto the sand). Each step the water ahead (at or just under
-- its feet) is checked; without it the mob stops and turns back.
local function wet(p)
	return core.get_item_group(core.get_node(p).name, "water") > 0
end

-- At the feet or under them: a mob at the surface floats with its feet just
-- above the water.
local function water_at(x, feet, z)
	return wet({ x = x, y = feet + 0.2, z = z, }) or wet({ x = x, y = feet - 0.3, z = z, })
		or wet({ x = x, y = feet - 0.8, z = z, })
end

function cb_core.shore_guard(self)
	local v = self.object:get_velocity()
	local pos = self.object:get_pos()
	if not (v and pos) then
		return false
	end
	local h = math.sqrt(v.x * v.x + v.z * v.z)
	if h < 0.05 then
		return false
	end
	local box = self.object:get_properties().collisionbox
	local feet = pos.y + box[2]
	-- a mob already ashore is left to mobs_redo (it flops back if it can)
	if not water_at(pos.x, feet, pos.z) then
		return false
	end
	local reach = math.max(box[4], -box[1], box[6], -box[3]) + 0.7
	if water_at(pos.x + v.x / h * reach, feet, pos.z + v.z / h * reach) then
		return false
	end
	self.object:set_velocity({ x = 0, y = v.y, z = 0, })
	if self.state ~= "attack" then
		self:set_yaw((self.object:get_yaw() or 0) + math.pi + (math.random() - 0.5), 4)
		if self.state == "runaway" or self.state == "walk" then
			self.state = "stand"
		end
	end
	return true
end

local function swims_in_water(def)
	return def.fly and type(def.fly_in) == "table"
		and (table.indexof(def.fly_in, "default:water_source") > 0
			or table.indexof(def.fly_in, "default:river_water_source") > 0)
end

-- Damage a tamed mob takes from a mob or a blast (not from players: that is
-- mobs_redo's own protection) is multiplied by these: a protection rune
-- (level 1, level 2) shields it from monsters and explosions too. A mob
-- definition may add its own factor with _cb_damage_factor(self, hitter).
cb_core.RUNE_FACTOR = { [true] = 0.5, [2] = 0, }

local function scaled_caps(caps, f)
	local out = table.copy(caps)
	out.damage_groups = {}
	for g, d in pairs(caps.damage_groups or {}) do
		out.damage_groups[g] = math.floor(d * f + 0.5)
	end
	return out
end

function cb_core.mob_damage_factor(self, hitter)
	local f = 1
	if self._cb_damage_factor then
		f = f * (self:_cb_damage_factor(hitter) or 1)
	end
	if self.tamed and self.protected and hitter and not hitter:is_player() then
		f = f * (cb_core.RUNE_FACTOR[self.protected] or 1)
	end
	return f
end

core.register_on_mods_loaded(function()
	local mobs = rawget(_G, "mobs")
	local class = mobs and mobs.mob_class
	if not class then
		return
	end
	local do_env_damage = class.do_env_damage
	if do_env_damage then
		class.do_env_damage = function(self, ...)
			if self.suffocation and self.suffocation ~= 0 and suffocating(self) then
				cb_core.mob_unstick(self)
			end
			return do_env_damage(self, ...)
		end
	end
	for name, def in pairs(core.registered_entities) do
		if name:find("^cb_mobs_") and def._cmi_is_mob then
			if swims_in_water(def) then
				-- every step: mobs_redo sets the speed once a second (2 to 4
				-- nodes of travel), and swimming along a sloping bottom the
				-- mob climbed the beach node by node
				local do_custom = def.do_custom
				def.do_custom = function(self, ...)
					cb_core.shore_guard(self)
					if do_custom then
						return do_custom(self, ...)
					end
				end
			end
			local on_punch = def.on_punch
			def.on_punch = function(self, hitter, tflp, caps, dir, damage, ...)
				if caps and hitter then
					local f = cb_core.mob_damage_factor(self, hitter)
					if f ~= 1 then
						caps = scaled_caps(caps, f)
					end
				end
				return on_punch(self, hitter, tflp, caps, dir, damage, ...)
			end
		end
	end
end)
