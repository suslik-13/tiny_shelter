local petard_burn_time = 10

local colors = {"red","lime","yellow","cyan","blue","violet","magenta","white"}

local bengals_burning = {}

local S = minetest.get_translator("petards")

local rnd = math.random

local function frnd(min, max)
	return (max-min)*rnd() + min
end

minetest.register_craftitem("petards:confetti_petard",{
	description = S("Confetti petard"),
	inventory_image = "petards_confetti_petard.png",
	on_use = function(itemstack, user, pointed_thing)
		local pos = user:get_pos()
		local name = user:get_player_name()
		local creative = minetest.is_creative_enabled(name)
		if not creative then
			local inv = user:get_inventory()
			itemstack:take_item()
			local used = "petards:confetti_petard_used"
			if inv:room_for_item("main",used) then
				inv:add_item("main",used)
			else
				minetest.add_item(pos,used)
			end
		end
		local dir = user:get_look_dir()
		local eye_height = user:get_properties().eye_height
		local vel = user:get_velocity()
		pos.y = pos.y + eye_height
		minetest.sound_play("tnt_explode",{pos = pos, gain=0.5, pitch = 3})
		for i=1, 200 do
			minetest.add_particle({
				pos = pos,
				velocity = {x = vel.x + (dir.x * rnd(2,5) + frnd(-1,1)), y = vel.y + (dir.y * rnd(2,5) + frnd(-1,1)), z = vel.z + (dir.z * rnd(2,5) + frnd(-1,1))},
				acceleration = {x=0, y=-3, z=0},
				expirationtime = 30,
				size = 1,
				collisiondetection = true,
				collision_removal = true,
				vertical = false,
				texture = table.concat({"petards_particle.png^[colorize:",colors[rnd(1,#colors)],":255"}),
				glow = 14
			})
		end
		return itemstack
	end
})

minetest.register_craftitem("petards:confetti_petard_used",{
	description = S("Used confetti petard"),
	inventory_image = "petards_confetti_petard_used.png",
	groups = {not_in_creative_inventory = 1},
})

minetest.register_craftitem("petards:petard",{
	description = S("Petard"),
	inventory_image = "petards_petard.png",
	on_use = function(itemstack, user, pointed_thing)
		local pos = user:get_pos()
		local name = user:get_player_name()
		local creative = minetest.is_creative_enabled(name)
		if not creative then
			itemstack:take_item()
		end
		local dir = user:get_look_dir()
		local eye_height = user:get_properties().eye_height
		local vel = user:get_velocity()
		pos.y = pos.y + eye_height
		local obj = minetest.add_entity(pos, "petards:petard")
		if obj then
			obj:set_velocity({x = vel.x + dir.x * 10, y = vel.y + dir.y * 10, z = vel.z + dir.z * 10})
			obj:set_rotation({x = 0, y = user:get_look_horizontal()+math.pi/2, z = frnd(0,math.pi*2)})
		end
		return itemstack
	end
})

minetest.register_tool("petards:bengal",{
	description = S("Bengal Fire"),
	inventory_image = "petards_bengal.png",
	wield_scale = {x = 1, y = 1, z = 0.8},
	on_use = function(itemstack, user, pointed_thing)
		bengals_burning[user] = true
		return itemstack
	end,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		local wear = itemstack:get_wear()
		local obj = minetest.add_entity(pos, "petards:bengal", wear)
		if obj then
			itemstack:take_item()
		end
		return itemstack
	end,
})

minetest.register_globalstep(function(dtime)
	for player,_ in pairs(bengals_burning) do
		local pos = player and player:get_pos()
		if pos then
			local witem = player:get_wielded_item()
			if witem and witem:get_name() == "petards:bengal" then
				witem:add_wear(20)
				player:set_wielded_item(witem)
				local dir = player:get_look_dir()
				local yaw = player:get_look_horizontal()+math.pi/4
				local eye_height = player:get_properties().eye_height
				pos.y = pos.y + eye_height*0.9 + dir.y/2
				pos.x = pos.x + math.cos(yaw)/2
				pos.z = pos.z + math.sin(yaw)/2
				minetest.add_particle({
					pos = pos,
					velocity = {x = frnd(-1,1), y = frnd(-1,1), z = frnd(-1,1)},
					expirationtime = frnd(0.2,0.6),
					size = 0.5,
					collisiondetection = true,
					collision_removal = true,
					vertical = false,
					texture = "petards_particle.png^[colorize:"..(rnd(0,1) == 1 and "yellow" or "orange")..":255",
					glow = 14
				})
			else
				bengals_burning[player] = nil
			end
		end
	end
end)

minetest.register_entity("petards:petard",{
	physical = true,
	collide_with_objects = false,
	pointable = false,
	visual = "item",
	textures = {"petards:petard"},
	visual_size = {x = 0.3, y = 0.3, z = 0.5},
	collisionbox = {-0.1, -0.1, -0.1, 0.1, 0.1, 0.1},
	timer = 0,
	sound = 0,
	on_activate = function(self, staticdata)
		self.object:set_acceleration({x = 0, y = -9.81, z = 0})
		self.object:set_armor_groups({immortal=1})
		self.sound = minetest.sound_play("tnt_gunpowder_burning", {object = self.object, loop = true, pitch = 2, gain = 0.5})
	end,
	on_step = function(self, dtime, moveresult)
		self.timer = self.timer + dtime
		local vel = self.object:get_velocity()
		local pos = self.object:get_pos()
		minetest.add_particle({
			pos = pos,
			velocity = {x = vel.x + frnd(-1,1), y = vel.y + frnd(-1,1), z = vel.z + frnd(-1,1)},
			acceleration = {x=0, y=2, z=0},
			expirationtime = frnd(0.5,1.5),
			size = 1,
			collisiondetection = true,
			collision_removal = true,
			vertical = false,
			texture = "petards_particle.png^[colorize:black:"..tostring(rnd(80,160)),
			glow = 14
		})
		if moveresult.touching_ground then
			self.object:set_velocity({x = 0, y = 0, z = 0})
		else
			local rot = self.object:get_rotation()
			rot.z = rot.z + 0.1
			self.object:set_rotation(rot)
		end
		if self.timer > petard_burn_time then
			minetest.add_particle({
				pos = pos,
				expirationtime = 0.2,
				size = 2,
				collisiondetection = true,
				collision_removal = true,
				vertical = false,
				texture = "petards_particle.png^[colorize:orange:255",
				glow = 14
			})
			minetest.sound_play("tnt_explode",{object = self.object, gain = 0.5, pitch = 2})
			local objs = minetest.get_objects_inside_radius(pos, 2)
			for _,obj in ipairs(objs) do
				local opos = obj:get_pos()
				obj:punch(self.object, 1.0, {full_punch_interval = 1.0, damage_groups = {fleshy=2}}, vector.direction(pos,opos))
			end
			for i=1, 50 do
				minetest.add_particle({
					pos = pos,
					velocity = {x = vel.x + frnd(-2,2), y = vel.y + frnd(-2,2), z = vel.z + frnd(-2,2)},
					acceleration = {x=0, y=2, z=0},
					expirationtime = frnd(1,2),
					size = 1,
					collisiondetection = true,
					collision_removal = true,
					vertical = false,
					texture = "petards_particle.png^[colorize:black:"..tostring(rnd(80,160)),
					glow = 14
				})
			end
			self.object:remove()
			minetest.sound_stop(self.sound)
		end
	end,
})

local function grab_bengal(self, player)
	if not player or not player:is_player() then
		return
	end
	local inv = player:get_inventory()
	local stack = ItemStack("petards:bengal")
	if inv:room_for_item("main",stack) then
		stack:set_wear(self.wear)
		inv:add_item("main",stack)
	end
	self.object:remove()
end

minetest.register_entity("petards:bengal",{
	physical = true,
	collide_with_objects = false,
	pointable = true,
	visual = "item",
	textures = {"petards:bengal"},
	visual_size = {x = 0.3, y = 0.3, z = 0.3},
	collisionbox = {-0.1, -0.35, -0.1, 0.1, 0.4, 0.1},
	wear = 0,
	on_activate = function(self, staticdata)
		self.object:set_acceleration({x = 0, y = -9.81, z = 0})
		self.object:set_rotation({x = 0, y = 0, z = math.pi/4})
		self.object:set_armor_groups({immortal=1})
		local wear = tonumber(staticdata)
		if wear then
			self.wear = tonumber(wear)
		end
	end,
	on_step = function(self, dtime, moveresult)
		self.wear = self.wear + 20
		local pos = self.object:get_pos()
		pos.y = pos.y + 0.4 - self.wear/107000
		minetest.add_particle({
			pos = pos,
			velocity = {x = frnd(-1,1), y = frnd(-1,1), z = frnd(-1,1)},
			expirationtime = frnd(0.2,0.6),
			size = 0.5,
			collisiondetection = true,
			collision_removal = true,
			vertical = false,
			texture = "petards_particle.png^[colorize:"..(rnd(0,1) == 1 and "yellow" or "orange")..":255",
			glow = 14
		})
		if self.wear > 65535 then
			self.object:remove()
		end
	end,
	on_rightclick = grab_bengal,
	on_punch = grab_bengal,
})

dofile(minetest.get_modpath("petards").."/crafts.lua")
