-- Riding shared by pigs, donkeys, mules and undead horses (spec cycle 4,
-- 8b): mobs:saddle goes on with a right-click, the rider gets on with
-- another and off with a right-click while riding; mobs_redo's mount API
-- (mobs.attach, mobs.drive, mobs.detach) moves the animal. Animals with
-- _need_tame take a saddle and a rider only from their owner.
local A = cb_mobs_animals

-- mobs_redo does not copy unknown fields of a mob definition into the
-- entity, so per-kind settings live here and go on in after_activate.
A.CFG = {}

function A.setup(self)
	for k, v in pairs(A.CFG[self.name] or {}) do
		self[k] = v
	end
end

local function take_one(clicker, stack)
	if not core.is_creative_enabled(clicker:get_player_name()) then
		stack:take_item()
		clicker:set_wielded_item(stack)
	end
end

function A.feed(self, clicker)
	return mobs:feed_tame(self, clicker, self._feed_count or 8, true, self._tame_by_food or false)
end

local function owner_ok(self, clicker)
	if self._need_tame then
		return self.tamed and self.owner == clicker:get_player_name()
	end
	return not self.owner or self.owner == "" or self.owner == clicker:get_player_name()
end

function A.saddle_click(self, clicker)
	local stack = clicker:get_wielded_item()
	if stack:get_name() ~= "mobs:saddle" or self._saddle or self.child or not owner_ok(self, clicker) then
		return false
	end
	self._saddle = true
	if not self._need_tame then
		-- mobs_redo removes far untamed mobs; a saddled one is kept
		self.owner, self.tamed = clicker:get_player_name(), true
	end
	take_one(clicker, stack)
	if self._on_saddle then
		self._on_saddle(self)
	end
	return true
end

function A.mount_click(self, clicker)
	if self.driver then
		if self.driver == clicker then
			mobs.detach(clicker, { x = 1, y = 0, z = 1, })
			return true
		end
		return false
	end
	if not self._saddle or self.child or not owner_ok(self, clicker) then
		return false
	end
	self.driver_attach_at = self._rider_at or { x = 0, y = 6, z = -1, }
	self.driver_eye_offset = self._rider_eye or { x = 0, y = 4, z = 0, }
	-- a rotated model: seat the rider the way it faces and look ahead
	local r = self.rotate or 0
	self.player_rotation = { x = 0, y = math.deg(r), z = 0, }
	mobs.attach(self, clicker)
	if r ~= 0 then
		local name = clicker:get_player_name()
		core.after(0.3, function()
			local p, yaw = core.get_player_by_name(name), self.object:get_yaw()
			if p and yaw and self.driver == p then
				p:set_look_horizontal(yaw + r)
			end
		end)
	end
	return true
end

-- From do_custom: true when the rider controls the animal (skip the AI).
function A.ride_step(self, dtime)
	local rider = self.driver
	if not rider then
		return false
	end
	if not self.v2 then
		self.v2, self.max_speed_forward, self.max_speed_reverse = 0, self._ride_speed or 5, 2
		self.accel, self.terrain_type = 6, 3
	end
	if self._needs_stick and rider:get_wielded_item():get_name() ~= (self._stick or A.STICK) then
		local v = self.object:get_velocity() or vector.zero()
		self.object:set_velocity({ x = 0, y = v.y, z = 0, })
		self.v2 = 0
		self:set_animation("stand")
		return true
	end
	mobs.drive(self, "walk", "stand", false, dtime)
	A.align_drive(self)
	return true
end

-- mobs.drive sets the yaw to the rider's look minus `rotate` but moves along
-- that yaw; models with a `rotate` must move the way they face.
function A.align_drive(self)
	local r = self.rotate or 0
	local v = self.object:get_velocity()
	if r == 0 or not v then
		return
	end
	local speed = math.sqrt(v.x * v.x + v.z * v.z)
	local moved = math.atan2(-v.x, v.z)
	local yaw = self.object:get_yaw() or 0
	if math.abs(math.atan2(math.sin(moved - yaw), math.cos(moved - yaw))) > math.pi / 2 then
		speed = -speed -- going backwards
	end
	local face = yaw + r
	self.object:set_velocity({ x = -math.sin(face) * speed, y = v.y, z = math.cos(face) * speed, })
end

function A.drop_saddle(self)
	local pos = self.object:get_pos()
	if self.driver then
		mobs.detach(self.driver, { x = 1, y = 0, z = 1, })
	end
	if self._saddle and pos then
		core.add_item(pos, "mobs:saddle")
	end
	self._saddle = nil
end
