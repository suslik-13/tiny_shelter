
--
-- Paraglider mod for repixture
-- By m492
-- Modified for Techage by joe7575
-- Made standalone (no Techage dependency) for SHELTER
--
local S = minetest.get_translator("paraglider")

-- Track which players are currently attached to a paraglider (or another
-- entity such as a boat/bed from the "default" mod, when it is present).
-- This used to be default.player_attached, shared with minetest_game's
-- "default" mod. We fall back to our own local table so the mod works
-- with no dependency on "default" (or techage) at all.
local player_attached = {}
if minetest.get_modpath("default") and default and default.player_attached then
	player_attached = default.player_attached
end

local function set_player_yaw(self, player, yaw)
	local offs = (yaw - self.yaw) % (2 * math.pi)
	if offs > math.pi then 
		offs = offs - (2 * math.pi)
	elseif offs < -math.pi then
		offs = offs + (2 * math.pi)
	end
	self.yaw = self.yaw + offs
	player:set_look_horizontal(self.yaw)
end	
	
minetest.register_tool(
	"paraglider:paraglider", {
		description = S("Paraglider"),
		inventory_image = "paraglider_inventory.png",
		wield_image = "paraglider_inventory.png",
		stack_max = 1,
		on_activate = function(self)
			self.object:set_armor_groups({immortal=1})
		end,
		on_use = function(itemstack, player, pointed_thing)
			local name = player:get_player_name()
			local pos = player:get_pos()
			local node_under = minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z})

			if player_attached[name] then
				return
			end

			-- Player physics access control, using the player's own meta
			-- (no external mod tables required).
			local pmeta = player:get_meta()
			if pmeta:get_int("player_physics_locked") ~= 0 then
				return
			end
			pmeta:set_int("player_physics_locked", 1)
				
			if node_under.name == "air" then
				-- Spawn paraglider
				pos.y = pos.y + 3

				local obj = minetest.add_entity(pos, "paraglider:entity")

				obj:set_velocity(
					{
						x = 0,
						y = math.min(0, player:get_player_velocity().y),
						z = 0
					})

				player:set_attach(obj, "", {x = 0, y = -8, z = 0}, {x = 0, y = 0, z = 0})
				obj:set_yaw(player:get_look_horizontal())

				local entity = obj:get_luaentity()
				entity.attached = name
				entity.yaw = player:get_look_horizontal()

				player_attached[player:get_player_name()] = true

				itemstack:add_wear(65536/30)
				return itemstack
			else
				minetest.chat_send_player(name,
					minetest.colorize("#FFFF00", S("First jump from a hill and then use the paraglider")))
				pmeta:set_int("player_physics_locked", 0)
			end
		end,
	
	})

minetest.register_entity(
	"paraglider:entity",
	{
		visual = "mesh",
		mesh = "paraglider.b3d",
		textures = {"paraglider_mesh.png"},
		physical = false,
		pointable = false,
		automatic_face_movement_dir = -90,
		attached = nil,

		on_step = function(self, dtime)
			local pos = self.object:get_pos()
			local yaw = self.object:get_yaw()
			local node_under = minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z})

			if self.attached ~= nil then
				local player = minetest.get_player_by_name(self.attached)
				local controls = player:get_player_control()
				local hspeed = 5.0
				local vspeed = -1
				self.idle = (self.idle or 1) - 1

				if controls.up then
					vspeed = -3
					hspeed = 8
					player:set_look_vertical(math.tan(-vspeed / hspeed))
					set_player_yaw(self, player, yaw)
					self.idle = 1
				elseif controls.down then
					vspeed = -0.25
					hspeed = 2
					player:set_look_vertical(math.tan(-vspeed / hspeed))
					set_player_yaw(self, player, yaw)
					self.idle = 1
				end

				if controls.right then
					yaw = yaw - math.pi / 60
					vspeed = -2
					hspeed = 4
					player:set_look_vertical(math.tan(-vspeed / hspeed))
					set_player_yaw(self, player, yaw)
					self.idle = 1
				elseif controls.left then
					yaw = yaw + math.pi / 60
					vspeed = -2
					hspeed = 4
					player:set_look_vertical(math.tan(-vspeed / hspeed))
					set_player_yaw(self, player, yaw)
					self.idle = 1
				end

				if self.idle == 0 then
					player:set_look_vertical(math.tan(-vspeed / hspeed))
					set_player_yaw(self, player, yaw)
				end
				
				self.object:set_yaw(yaw)
				local vel = vector.multiply(minetest.yaw_to_dir(yaw), hspeed)
				vel.y = vspeed
				self.object:set_velocity(vel)

				if node_under.name ~= "air" then
					player_attached[self.attached] = false
					local player = minetest.get_player_by_name(self.attached)
					player:get_meta():set_int("player_physics_locked", 0)
				end
			else
				self.object:remove()
				return
			end

			if node_under.name ~= "air" then
				if self.attached ~= nil then
					player_attached[self.attached] = false
					self.object:set_detach()
					local player = minetest.get_player_by_name(self.attached)
					player:get_meta():set_int("player_physics_locked", 0)
				end
				self.object:remove()
			end
		end
	})

local function restore_player(player)
	local name = player:get_player_name()
	if name and player_attached[name] then
		player_attached[name] = false
		player:get_meta():set_int("player_physics_locked", 0)
	end
end

minetest.register_on_joinplayer(function(player)
	restore_player(player)
end)

minetest.register_on_respawnplayer(function(player)
	player:get_meta():set_int("player_physics_locked", 0)
end)

minetest.register_on_leaveplayer(function(player)
	restore_player(player)
end)

minetest.register_on_dieplayer(function(player)
	player:get_meta():set_int("player_physics_locked", 0)
end)

minetest.register_craft({
	output = "paraglider:paraglider",
	recipe = {
		{"mesecons_materials:fiber", "wool:green", "mesecons_materials:fiber"},
		{"farming:string", "farming:string", "farming:string"},
		{"", "unified_inventory:bag_large", ""}
	},
})

