-- Emerald (drops, raids, trading later) and the totem of undying (spec
-- cycle 2, 5): held anywhere in the hotbar, a lethal blow leaves 1 HP, the
-- totem is used up and the player heals +1 HP/s for 5 s.
local S = cb_items.S

cb_core.register_equiv("emerald", { "cb_items:emerald", })
core.register_craftitem("cb_items:emerald", { description = S("Emerald"), inventory_image = "cb_items_emerald.png", })
core.register_craftitem("cb_items:totem", {
	description = S("Totem of Undying"),
	inventory_image = "cb_items_totem.png",
	stack_max = 1,
})

local function regen(name, left)
	local player = core.get_player_by_name(name)
	if not player or left <= 0 then
		return
	end
	if player:get_hp() > 0 then
		player:set_hp(player:get_hp() + 1, { type = "set_hp", cause = "cb_totem", })
	end
	core.after(1, regen, name, left - 1)
end

function cb_items.totem_save(player, hp_change)
	if hp_change >= 0 or player:get_hp() + hp_change > 0 then
		return hp_change
	end
	local inv = player:get_inventory()
	local n = player.hud_get_hotbar_itemcount and player:hud_get_hotbar_itemcount() or 8
	for i = 1, math.min(n, inv:get_size("main")) do
		if inv:get_stack("main", i):get_name() == "cb_items:totem" then
			inv:set_stack("main", i, ItemStack(""))
			local pos = player:get_pos()
			core.sound_play("cb_items_totem", { pos = pos, max_hear_distance = 32, }, true)
			core.add_particlespawner({ amount = 40, time = 0.5, minpos = vector.offset(pos, -0.5, 0.5, -0.5),
				maxpos = vector.offset(pos, 0.5, 2, 0.5), minvel = vector.new(-2, 1, -2), maxvel = vector.new(2, 4, 2),
				minexptime = 0.5, maxexptime = 1.5, texture = "cb_items_totem.png", })
			core.after(1, regen, player:get_player_name(), 5)
			return 1 - player:get_hp()
		end
	end
	return hp_change
end

core.register_on_player_hpchange(function(player, hp_change)
	return cb_items.totem_save(player, hp_change)
end, true)
