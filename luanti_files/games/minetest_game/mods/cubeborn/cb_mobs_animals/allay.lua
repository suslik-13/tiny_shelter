-- Allay (spec cycle 4, 8b): found at pillager outposts. Give it an item and
-- it bonds with you: it gathers dropped items of the same kind within 32
-- nodes (up to 64) and brings them to you, dropping them at your feet; if
-- a note block (mesecons) played within 16 nodes of it in the last 30 s,
-- it brings them there instead. It follows its owner, cannot be hurt by
-- them, and gives the item back to an empty hand; then only the owner can
-- give it a new one. Jukeboxes and amethyst do
-- not exist here, so it neither dances nor duplicates.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.ALLAY = "cb_mobs_animals:allay"
local GATHER, NOTE_RANGE, NOTE_TIME, BAG, DROP_REACH, PAUSE = 32, 16, 30, 64, 2, 3
local heard = {}

function A.noteblock_heard(pos)
	heard[core.hash_node_position(vector.round(pos))] = { pos = vector.round(pos), t = core.get_gametime(), }
end

core.register_on_mods_loaded(function()
	local M = rawget(_G, "mesecon")
	if M and M.noteblock_play then
		local play = M.noteblock_play
		M.noteblock_play = function(pos, ...)
			A.noteblock_heard(pos)
			return play(pos, ...)
		end
	end
end)

function A.allay_give(self, clicker)
	local stack = clicker:get_wielded_item()
	if self._want then
		if not stack:is_empty() or clicker:get_player_name() ~= self.owner then
			return false
		end
		clicker:set_wielded_item(ItemStack(self._want))
		self._want = nil
		A.hold(self, nil)
		return true
	end
	-- a bonded allay takes a new item from its owner only
	if stack:is_empty() or (self.tamed and (self.owner or "") ~= "" and clicker:get_player_name() ~= self.owner) then
		return false
	end
	self._want = stack:get_name()
	self.owner, self.tamed, self.static_save = clicker:get_player_name(), true, true
	if not core.is_creative_enabled(self.owner) then
		stack:take_item()
		clicker:set_wielded_item(stack)
	end
	A.hold(self, self._want)
	core.sound_play("cb_mobs_animals_allay_item_given", { pos = self.object:get_pos(), }, true)
	return true
end

-- Picks up dropped items like the one it holds; returns how many.
function A.allay_collect(self)
	local pos = self.object:get_pos()
	if not (self._want and pos) then
		return 0
	end
	local bag = ItemStack(self._bag or "")
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, GATHER)) do
		local e = obj:get_luaentity()
		if bag:get_count() >= BAG then
			break
		end
		local st = e and e.name == "__builtin:item" and ItemStack(e.itemstring)
		if st and st:get_name() == self._want then
			local left = bag:add_item(st)
			n = n + st:get_count() - left:get_count()
			if left:is_empty() then
				obj:remove()
			else
				e:set_item(left)
			end
		end
	end
	self._bag = not bag:is_empty() and bag:to_string() or nil
	return n
end

-- Where to bring the items: a note block heard lately, else the owner.
function A.allay_target(self)
	local pos = self.object:get_pos()
	local now = core.get_gametime()
	for h, n in pairs(heard) do
		if now - n.t > NOTE_TIME then
			heard[h] = nil
		elseif vector.distance(pos, n.pos) <= NOTE_RANGE then
			return vector.offset(n.pos, 0, 1, 0), "noteblock"
		end
	end
	local p = core.get_player_by_name(self.owner or "")
	return p and p:get_pos(), p and "owner"
end

-- Close enough to the target: the bag drops there.
function A.allay_deliver(self, at)
	if not self._bag then
		return false
	end
	core.add_item(at or self.object:get_pos(), self._bag)
	self._bag, self._pause = nil, PAUSE
	core.sound_play("cb_mobs_animals_allay_item_thrown", { pos = self.object:get_pos(), }, true)
	return true
end

local function fly_to(self, pos, speed)
	local at = self.object:get_pos()
	local d = vector.subtract(pos, at)
	local len = vector.length(d)
	if len < 0.1 then
		self.object:set_velocity(vector.zero())
		return len
	end
	self:yaw_to_pos(pos)
	self.object:set_velocity(vector.multiply(d, speed / len))
	self:set_animation("fly")
	return len
end

function A.allay_tick(self, dtime)
	if self._pause then
		self._pause = self._pause > dtime and self._pause - dtime or nil
	end
	self._t = (self._t or 0) + dtime
	if self._t < 0.5 then
		return not self._busy
	end
	self._t = 0
	if not self._want then
		self._busy = nil
		return true
	end
	if not self._pause and (self._bag == nil or ItemStack(self._bag):get_count() < BAG) then
		A.allay_collect(self)
	end
	local target, kind = A.allay_target(self)
	if not target then
		self._busy = nil
		return true
	end
	local up = vector.offset(target, 0, kind == "owner" and 1.5 or 0.5, 0)
	local dist = vector.distance(self.object:get_pos(), up)
	if self._bag and not self._pause then
		self._busy = true
		if fly_to(self, up, 4) <= DROP_REACH then
			A.allay_deliver(self, target)
		end
		return false
	end
	-- follows its owner: comes from 16 away, stops at 4
	if kind == "owner" and (dist > 16 or (self._busy and dist > 4)) then
		self._busy = true
		fly_to(self, up, 3)
		return false
	end
	self._busy = nil
	return true
end

mobs:register_mob(A.ALLAY, {
	type = "animal", passive = true, hp_min = 20, hp_max = 20, armor = 100, glow = 6,
	collisionbox = { -0.175, 0, -0.175, 0.175, 0.6, 0.175, },
	visual = "mesh", mesh = "cb_mobs_animals_allay.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_animals_allay.png", }, },
	fly = true, fly_in = { "air", }, walk_velocity = 2, run_velocity = 4, jump = false, view_range = 8,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
	sounds = { random = "cb_mobs_animals_allay_idle", damage = "cb_mobs_animals_allay_hurt",
		death = "cb_mobs_animals_allay_death", distance = 12, },
	animation = { speed_normal = 30, stand_start = 0, stand_end = 20, stand_speed = 25, walk_start = 21, walk_end = 33,
		run_start = 21, run_end = 33, fly_start = 21, fly_end = 33, },
	do_custom = function(self, dtime)
		return A.allay_tick(self, dtime)
	end,
	-- its owner cannot hurt it
	do_punch = function(self, hitter)
		if hitter and hitter:is_player() and hitter:get_player_name() == self.owner then
			return false
		end
	end,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() then
			A.allay_give(self, clicker)
		end
	end,
	on_die = function(self)
		local pos = self.object:get_pos()
		for _, it in ipairs({ self._want, self._bag, }) do
			core.add_item(pos, it)
		end
	end,
	after_activate = function(self)
		self._held, self._held_bone, self._held_at = self._want, "wield_item", { x = 0, y = 0, z = -1, }
		A.show_held(self)
	end,
})
mobs:register_egg(A.ALLAY, S("Allay"), "cb_mobs_animals_allay.png", 1)
