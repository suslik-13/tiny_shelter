-- Donkey and mule (spec cycle 4, 8b): tamed with wheat, apples or carrots,
-- then the owner can saddle and ride them and give them a chest (15 slots,
-- sneak + right-click opens it; cb_mobs_trader's llama chest). A donkey and
-- a horse (mob_horse) in love make a mule; mules do not breed.
-- A.horse_def builds the shared Mineclonia horse model for undead horses too.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.DONKEY, A.MULE = "cb_mobs_animals:donkey", "cb_mobs_animals:mule"
local TR = rawget(_G, "cb_mobs_trader")
local HORSE, HORNY_TIME = "mob_horse:horse", 30
local BOX = { -0.69825, 0, -0.69825, 0.69825, 1.6, 0.69825, }

-- textures: chest, body, saddle (Mineclonia draws them all in the body
-- image and shows a slot by giving it that image)
local function retexture(self)
	local tex = self._tex
	self.base_texture = { self._chest and tex or "blank.png", tex, self._saddle and tex or "blank.png", }
	self.object:set_properties({ textures = self.base_texture, })
end

function A.chest_click(self, clicker)
	if not TR or not self._strength or not self.tamed or self.child then
		return false
	end
	local stack = clicker:get_wielded_item()
	if stack:get_name() == TR.CHEST and not self._chest and self.owner == clicker:get_player_name() then
		self._chest, self._inv = true, {}
		if not core.is_creative_enabled(clicker:get_player_name()) then
			stack:take_item()
			clicker:set_wielded_item(stack)
		end
		retexture(self)
		return true
	end
	local ctrl = clicker:get_player_control()
	if self._chest and ctrl and ctrl.sneak then
		if clicker:get_player_name() == self.owner then
			TR.open_chest(self, clicker)
		end
		return true
	end
	return false
end

-- A donkey in love next to a horse in love: both calm down and a young mule
-- comes 5 s later.
function A.mule_match(self)
	local pos = self.object:get_pos()
	if not (pos and self.horny and (self.hornytimer or 0) <= HORNY_TIME) or self.child then
		return false
	end
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 3)) do
		local e = obj:get_luaentity()
		if e and e.name == HORSE and not e.child and e.horny and (e.hornytimer or 0) <= HORNY_TIME then
			-- as mobs_redo after mating: the cooldown runs, then they may breed again
			self.hornytimer, e.hornytimer = HORNY_TIME + 1, HORNY_TIME + 1
			core.after(5, function()
				local at = self.object:get_pos()
				local child = at and core.add_entity(at, A.MULE)
				local young = child and child:get_luaentity()
				if young then
					young.child, young.hornytimer = true, 0
					child:set_properties({
						visual_size = { x = young.base_size.x * 0.5, y = young.base_size.y * 0.5, },
						collisionbox = A.half(young.base_colbox), selectionbox = A.half(young.base_selbox),
					})
				end
			end)
			return true
		end
	end
	return false
end

function A.horse_def(tex, scale, extra)
	local box = {}
	for i, v in ipairs(BOX) do
		box[i] = v * scale
	end
	local def = {
		type = "animal", passive = true, hp_min = 15, hp_max = 30, armor = 100,
		collisionbox = box, visual = "mesh", mesh = "cb_mobs_animals_horse.b3d",
		visual_size = { x = 3 * scale, y = 3 * scale, }, textures = { { "blank.png", tex, "blank.png", }, },
		makes_footstep_sound = true, walk_velocity = 1, run_velocity = 3, jump = true, stepheight = 1.1,
		view_range = 8, water_damage = 0, lava_damage = 5, light_damage = 0,
		animation = { speed_normal = 25, speed_run = 50, stand_start = 0, stand_end = 0, walk_start = 0,
			walk_end = 40, run_start = 0, run_end = 40, },
		drops = { { name = "mobs:leather", chance = 1, min = 0, max = 2, }, },
		do_custom = function(self, dtime)
			if TR and self._lid then
				TR.gear_step(self)
			end
			if self._mule_t then
				self._mule_t = self._mule_t - dtime
				if self._mule_t <= 0 then
					self._mule_t = 1
					A.mule_match(self)
				end
			end
			return not A.ride_step(self, dtime)
		end,
		on_rightclick = function(self, clicker)
			if not (clicker and clicker:is_player()) then
				return
			end
			if (self._feed_count and A.feed(self, clicker)) or A.chest_click(self, clicker)
					or A.saddle_click(self, clicker) then
				return
			end
			A.mount_click(self, clicker)
		end,
		on_die = function(self)
			A.drop_saddle(self)
			if TR then
				TR.drop_gear(self)
			end
		end,
		after_activate = function(self)
			A.setup(self)
			self._tex = tex
			retexture(self)
		end,
	}
	for k, v in pairs(extra or {}) do
		def[k] = v
	end
	return def
end

local FOOD = {}
for _, n in ipairs({ "farming:wheat", "default:apple", "farming:carrot", }) do
	if core.registered_items[n] then
		FOOD[#FOOD + 1] = n
	end
end
local SOUNDS = { random = "cb_mobs_animals_donkey_random", damage = "cb_mobs_animals_donkey_hurt",
	death = "cb_mobs_animals_donkey_death", distance = 16, }

local function config(title, mule)
	return { _need_tame = true, _tame_by_food = true, _feed_count = 6, _ride_speed = 5, _strength = 5,
		_chest_title = title, _on_saddle = retexture, _rider_at = { x = 0, y = 4, z = -1, },
		_rider_eye = { x = 0, y = 6, z = 0, }, _mule_t = not mule and 1 or nil, }
end

mobs:register_mob(A.DONKEY, A.horse_def("cb_mobs_animals_donkey.png", 0.86, { follow = FOOD, sounds = SOUNDS, }))
mobs:register_mob(A.MULE, A.horse_def("cb_mobs_animals_mule.png", 0.94, { follow = FOOD, sounds = SOUNDS,
	on_breed = function() return false end, }))
A.CFG[A.DONKEY] = config(S("Donkey"), false)
A.CFG[A.MULE] = config(S("Mule"), true)
mobs:register_egg(A.DONKEY, S("Donkey"), "cb_mobs_animals_donkey.png", 1)
mobs:register_egg(A.MULE, S("Mule"), "cb_mobs_animals_mule.png", 1)
