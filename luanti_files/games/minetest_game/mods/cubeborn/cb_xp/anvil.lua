-- Anvil repairs cost experience (spec section 8): each hammer blow that
-- repairs something costs cubeborn.xp_repair_cost points; without them the
-- blow does nothing. Dropping below a gear threshold takes armour off
-- (gates.lua, on change).
local X = cb_xp
local S = X.S
X.REPAIR_COST = tonumber(core.settings:get("cubeborn.xp_repair_cost")) or 1

core.register_on_mods_loaded(function()
	local def = core.registered_nodes["anvil:anvil"]
	if not def then
		return
	end
	local punch = def.on_punch
	core.override_item("anvil:anvil", {
		on_punch = function(pos, node, puncher, ...)
			if not (puncher and puncher.is_player and puncher:is_player()) then
				return punch(pos, node, puncher, ...)
			end
			local name = puncher:get_player_name()
			local inv = core.get_meta(pos):get_inventory()
			local before = inv:get_stack("input", 1)
			local repairing = puncher:get_wielded_item():get_name() == "anvil:hammer" and before:get_wear() > 0
			if repairing and X.get(name) < X.REPAIR_COST then
				X.notify(name, S("Repairing needs experience"))
				return
			end
			local r = punch(pos, node, puncher, ...)
			local after = inv:get_stack("input", 1)
			if repairing and after:get_name() == before:get_name() and after:get_wear() < before:get_wear() then
				X.spend(name, X.REPAIR_COST)
			end
			return r
		end,
	})
end)
