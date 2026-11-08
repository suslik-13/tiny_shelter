-- Mooshroom (spec cycle 4, 8b): a red or (1 in 10) brown cow of the
-- mushroom biome. A bowl gives mushroom soup; shears turn an adult into a
-- plain cow (mobs_animal) and five mushrooms of its colour.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.MOOSHROOM = "cb_mobs_animals:mooshroom"
local RED = { "cb_mobs_animals_mooshroom.png", "cb_mobs_animals_mushroom_red.png", }
local BROWN = { "cb_mobs_animals_mooshroom_brown.png", "cb_mobs_animals_mushroom_brown.png", }
local SOUP, BOWL, SHEARS, COW = "ethereal:mushroom_soup", "farming:bowl", "mobs:shears", "mobs_animal:cow"

local function retexture(self)
	self.base_texture = self._brown and BROWN or RED
	self.object:set_properties({ textures = self.base_texture, })
end

local function give(player, stack)
	local left = player:get_inventory():add_item("main", stack)
	if not left:is_empty() then
		core.add_item(player:get_pos(), left)
	end
end

function A.milk_stew(self, clicker)
	local held = clicker:get_wielded_item()
	if held:get_name() ~= BOWL or self.child or not core.registered_items[SOUP] then
		return false
	end
	if core.is_creative_enabled(clicker:get_player_name()) then
		give(clicker, ItemStack(SOUP))
	elseif held:get_count() == 1 then
		clicker:set_wielded_item(ItemStack(SOUP))
	else
		held:take_item()
		clicker:set_wielded_item(held)
		give(clicker, ItemStack(SOUP))
	end
	core.sound_play("cb_mobs_animals_cow_stew", { object = self.object, max_hear_distance = 8, }, true)
	return true
end

function A.shear_mooshroom(self, clicker)
	local held = clicker:get_wielded_item()
	local pos = self.object:get_pos()
	if held:get_name() ~= SHEARS or self.child or not pos then
		return false
	end
	local shroom = self._brown and "flowers:mushroom_brown" or "flowers:mushroom_red"
	self.object:remove()
	if core.registered_entities[COW] then
		core.add_entity(pos, COW)
	end
	if core.registered_items[shroom] then
		core.add_item(vector.offset(pos, 0, 0.5, 0), shroom .. " 5")
	end
	if not core.is_creative_enabled(clicker:get_player_name()) then
		held:add_wear(650)
		clicker:set_wielded_item(held)
	end
	core.sound_play("cb_mobs_animals_shear", { pos = pos, max_hear_distance = 8, }, true)
	return true
end

mobs:register_mob(A.MOOSHROOM, {
	type = "animal", passive = true, hp_min = 10, hp_max = 10, armor = 100,
	collisionbox = { -0.45, 0, -0.45, 0.45, 1.4, 0.45, },
	visual = "mesh", mesh = "cb_mobs_animals_cow.b3d", visual_size = { x = 1, y = 1, },
	textures = { RED, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 2, jump = true, view_range = 8,
	water_damage = 0, lava_damage = 5, light_damage = 0,
	drops = { { name = "mobs:leather", chance = 1, min = 0, max = 2, },
		{ name = "mobs:meat_raw", chance = 1, min = 1, max = 3, }, },
	sounds = { random = "cb_mobs_animals_cow", damage = "cb_mobs_animals_cow_hurt",
		death = "cb_mobs_animals_cow_hurt", distance = 12, },
	animation = { speed_normal = 40, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40, run_start = 0,
		run_end = 40, },
	follow = { "farming:wheat", },
	on_rightclick = function(self, clicker)
		if not (clicker and clicker:is_player()) then
			return
		end
		if A.feed(self, clicker) or A.milk_stew(self, clicker) then
			return
		end
		A.shear_mooshroom(self, clicker)
	end,
	on_breed = function(self, other)
		return A.on_breed(self, other, function(young)
			young._brown = (math.random(2) == 1 and self or other)._brown
			retexture(young)
		end)
	end,
	after_activate = function(self)
		if self._brown == nil then
			self._brown = math.random(1, 10) == 1
		end
		retexture(self)
	end,
})
mobs:register_egg(A.MOOSHROOM, S("Mooshroom"), "cb_mobs_animals_mushroom_red.png", 1)
