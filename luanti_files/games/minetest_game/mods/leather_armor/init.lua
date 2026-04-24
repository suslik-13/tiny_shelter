--[[
		Minetest-mod "Leather Armor", Adds an armor made of leather
		Copyright (C) 2021 J. A. Anders

		This program is free software; you can redistribute it and/or modify
		it under the terms of the GNU General Public License as published by
		the Free Software Foundation; version 3 of the License.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.

		You should have received a copy of the GNU General Public License
		along with this program; if not, write to the Free Software
		Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
		MA 02110-1301, USA.
]]

leather_armor = {}

-- Get Translator
local S = minetest.get_translator("leather_armor")
leather_armor.get_translator = S
local S = leather_armor.get_translator


armor:register_armor("leather_armor:boots", {
  description = S("Leather Boots"),
  inventory_image = "leather_armor_boots_inv.png",
  groups = {armor_feet=1, armor_heal=1, armor_use=2700},
  armor_groups = {fleshy=10},
  damage_groups = {cracky=3, snappy=3, choppy=3, crumbly=2, level=2},
  texture = "leather_armor_boots.png",
  preview = "leather_armor_boots_preview.png",
})

armor:register_armor("leather_armor:cap", {
  description = S("Leather Cap"),
  inventory_image = "leather_armor_cap_inv.png",
  groups = {armor_head=1, armor_heal=1, armor_use=2700},
  armor_groups = {fleshy=10},
  damage_groups = {cracky=3, snappy=3, choppy=3, crumbly=2, level=2},
  texture = "leather_armor_cap.png",
  preview = "leather_armor_cap_preview.png",
})

armor:register_armor("leather_armor:jacket", {
  description = S("Leather Jacket"),
  inventory_image = "leather_armor_jacket_inv.png",
  groups = {armor_torso=1, armor_heal=1, armor_use=2700},
  armor_groups = {fleshy=10},
  damage_groups = {cracky=3, snappy=3, choppy=3, crumbly=2, level=2},
  texture = "leather_armor_jacket.png",
  preview = "leather_armor_jacket_preview.png",
})

armor:register_armor("leather_armor:leggings", {
  description = S("Leather Leggings"),
  inventory_image = "leather_armor_leggings_inv.png",
  groups = {armor_legs=1, armor_heal=1, armor_use=2700},
  armor_groups = {fleshy=10},
  damage_groups = {cracky=3, snappy=3, choppy=3, crumbly=2, level=2},
  texture = "leather_armor_leggings.png",
  preview = "leather_armor_leggings_preview.png",
})


minetest.register_craft({
	type = "shaped",
	output = "leather_armor:boots",
	recipe = {
		{"mobs:leather","","mobs:leather"},
		{"mobs:leather","","mobs:leather"},
	},
})

minetest.register_craft({
	type = "shaped",
	output = "leather_armor:cap",
	recipe = {
		{"mobs:leather","mobs:leather","mobs:leather"},
		{"mobs:leather","","mobs:leather"},
	},
})

minetest.register_craft({
	type = "shaped",
	output = "leather_armor:jacket",
	recipe = {
		{"mobs:leather","","mobs:leather"},
		{"mobs:leather","mobs:leather","mobs:leather"},
		{"mobs:leather","mobs:leather","mobs:leather"},
	},
})

minetest.register_craft({
	type = "shaped",
	output = "leather_armor:leggings",
	recipe = {
		{"mobs:leather","mobs:leather","mobs:leather"},
		{"mobs:leather","","mobs:leather"},
		{"mobs:leather","","mobs:leather"},
	},
})
