

---
---Mask
---

if minetest.get_modpath("3d_armor") then
  
  armor:register_armor("mask:mask", {
		description = ("Mask"),
		inventory_image = "mask_inv_mask.png",
		groups = {armor_head=1, armor_heal=8, armor_use=0, armor_fire=5, armor_water=1, armor_feather=1},
		armor_groups = {fleshy=15, radiation=100},
		damage_groups = {cracky=2, snappy=1, level=3},
	})
end


---
---Craft
---

---minetest.register_craft({
---	output = "mask:mask",
---	recipe = {
---		{"", "", ""},
---		{"farming:string", "default:paper", "farming:string"},
---		{"", "", ""},
---	}
---})

