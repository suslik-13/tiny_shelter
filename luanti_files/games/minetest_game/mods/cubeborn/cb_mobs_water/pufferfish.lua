-- Pufferfish (spec cycle 4, 8c): a player or a land mob closer than 2.5
-- makes it puff up (half, then fully a second later); fully puffed it
-- stings whatever touches it (2 damage and poison) and goes down again 3 s
-- after the threat is gone. Eating one poisons and starves for a while.
local S = cb_mobs_water.S
local W = cb_mobs_water
local A = rawget(_G, "cb_mobs_animals")
W.PUFFERFISH, W.PUFFERFISH_ITEM = "cb_mobs_water:pufferfish", "cb_mobs_water:pufferfish_item"
W.PUFFERFISH_BUCKET = "cb_mobs_water:pufferfish_bucket"
local SIZES = {
	[0] = { mesh = "cb_mobs_water_pufferfish_small.b3d", box = { -0.175, 0, -0.175, 0.175, 0.35, 0.175, }, },
	{ mesh = "cb_mobs_water_pufferfish_medium.b3d", box = { -0.245, 0, -0.245, 0.245, 0.49, 0.245, }, },
	{ mesh = "cb_mobs_water_pufferfish_big.b3d", box = { -0.45, 0, -0.45, 0.45, 0.7, 0.45, }, },
}
local SCARE, STING, CALM = 2.5, 1.2, 3

local function poison(obj, seconds)
	local E = cb_core.effects
	if E and obj:is_player() then
		E.apply(obj, "poison", 1, seconds)
	end
end

core.register_craftitem(W.PUFFERFISH_ITEM, {
	description = S("Pufferfish"), inventory_image = "cb_mobs_water_pufferfish_item.png",
	groups = { food_fish_raw = 1, },
	on_use = function(stack, user)
		if not (user and user:is_player()) then
			return stack
		end
		local E = cb_core.effects
		user:set_hp(math.min(user:get_properties().hp_max or 20, user:get_hp() + 1))
		if E then
			E.apply(user, "poison", 1, 12)
			if E.defs.hunger then
				E.apply(user, "hunger", 3, 15)
			end
		end
		if not core.is_creative_enabled(user:get_player_name()) then
			stack:take_item()
		end
		return stack
	end,
})

function W.puff(self, state)
	state = math.max(0, math.min(2, state))
	if state == (self._puff or 0) and self.base_mesh then
		return
	end
	self._puff = state
	local s = SIZES[state]
	self.object:set_properties({ mesh = s.mesh, collisionbox = s.box, selectionbox = s.box, })
	self.collisionbox, self.base_colbox, self.base_mesh = s.box, s.box, s.mesh
end

local function threat(self, obj)
	if obj == self.object then
		return false
	end
	if obj:is_player() then
		return not core.is_creative_enabled(obj:get_player_name())
	end
	local e = obj:get_luaentity()
	return e and e._cmi_is_mob and not (e.fly and table.indexof(e.fly_in or {}, "default:water_source") > 0) or false
end

-- Looks around: puffs up or down, stings what touches it; the threat or nil.
function W.puff_tick(self, dtime)
	local pos = self.object:get_pos()
	local near, touching
	for _, obj in ipairs(core.get_objects_inside_radius(pos, SCARE)) do
		if threat(self, obj) then
			near = near or obj
			if vector.distance(pos, obj:get_pos()) <= STING then
				touching = obj
			end
		end
	end
	if near then
		self._calm = CALM
		W.puff(self, (self._puff or 0) + 1)
	else
		self._calm = (self._calm or 0) - dtime
		if self._calm <= 0 then
			W.puff(self, (self._puff or 0) - 1)
		end
	end
	if touching and self._puff == 2 then
		touching:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = 2, }, },
			vector.direction(pos, touching:get_pos()))
		poison(touching, 6)
	end
	return near
end

local function drops()
	local out = { { name = W.PUFFERFISH_ITEM, chance = 1, min = 1, max = 1, }, }
	if core.registered_items["bonemeal:bone"] then
		out[#out + 1] = { name = "bonemeal:bone", chance = 20, min = 1, max = 1, }
	end
	return out
end

mobs:register_mob(W.PUFFERFISH, {
	type = "animal", passive = true, hp_min = 3, hp_max = 3, armor = 100,
	collisionbox = SIZES[0].box,
	visual = "mesh", mesh = SIZES[0].mesh, visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_water_pufferfish.png", }, },
	fly = true, fly_in = W.WATER, walk_velocity = 0.6, run_velocity = 1, jump = false, view_range = 6,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
	drops = drops(),
	sounds = { damage = "cb_mobs_water_fish_flop", death = "cb_mobs_water_fish_flop", distance = 8, },
	animation = { speed_normal = 30, stand_start = 10, stand_end = 530, walk_start = 10, walk_end = 530,
		fly_start = 10, fly_end = 530, },
	do_custom = function(self, dtime)
		self._look_t = (self._look_t or 0) + dtime
		if self._look_t >= 1 then
			W.puff_tick(self, self._look_t)
			self._look_t = 0
		end
	end,
	on_flop = W.choke,
	on_rightclick = function(self, clicker)
		if A and clicker and clicker:is_player() then
			A.bucket_mob(self, clicker, W.PUFFERFISH_BUCKET, {})
		end
	end,
	after_activate = function(self)
		local p = self._puff or 0
		self._puff = nil
		W.puff(self, p)
	end,
})
mobs:register_egg(W.PUFFERFISH, S("Pufferfish"), "cb_mobs_water_pufferfish_item.png", 1)
if A then
	A.register_mob_bucket(W.PUFFERFISH_BUCKET, { description = S("Bucket of @1", S("Pufferfish")),
		image = "cb_mobs_water_pufferfish_bucket.png", mob = W.PUFFERFISH, })
end
