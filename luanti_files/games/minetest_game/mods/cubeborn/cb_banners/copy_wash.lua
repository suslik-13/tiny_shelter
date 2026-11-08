-- Copying (two banners of a colour in the crafting grid, one patterned: two
-- copies) and washing (a patterned banner on xdecor's water cauldron loses
-- its top layer; three washes empty it). Only banners change xdecor's
-- cauldron; everything else goes to its own handler.
local B = cb_banners
B.WASHES = 3

for colour in pairs(B.COLOURS) do
	local name = B.item(colour)
	if core.registered_items[name] then
		core.register_craft({ type = "shapeless", output = name .. " 2", recipe = { name, name, }, })
	end
end

function B.copy_result(itemstack, grid)
	local name = itemstack:get_name()
	if core.get_item_group(name, "cb_banner_item") == 0 then
		return nil
	end
	local n, patterned = 0, nil
	for _, st in ipairs(grid) do
		if not st:is_empty() then
			if st:get_name() ~= name then
				return nil
			end
			n = n + 1
			if #B.layers(st) > 0 then
				if patterned then
					return ItemStack("")
				end
				patterned = st
			end
		end
	end
	if n ~= 2 or not patterned then
		return nil
	end
	local out = ItemStack(patterned)
	out:set_count(2)
	return out
end

core.register_craft_predict(function(itemstack, _, grid)
	return B.copy_result(itemstack, grid)
end)
core.register_on_craft(function(itemstack, _, grid)
	return B.copy_result(itemstack, grid)
end)

function B.wash(pos, stack, player)
	local layers = B.layers(stack)
	if #layers == 0 then
		return false
	end
	local name = player and player:get_player_name() or ""
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return false
	end
	table.remove(layers)
	B.set_layers(stack, layers)
	local meta = core.get_meta(pos)
	local n = meta:get_int("cb_washes") + 1
	if n >= B.WASHES then
		local node = core.get_node(pos)
		core.set_node(pos, { name = "xdecor:cauldron_empty", param2 = node.param2, })
	else
		meta:set_int("cb_washes", n)
	end
	return true
end

for _, cname in ipairs({ "xdecor:cauldron_idle", "xdecor:cauldron_boiling", }) do
	local def = core.registered_nodes[cname]
	if def then
		local old = def.on_rightclick
		core.override_item(cname, {
			on_rightclick = function(pos, node, clicker, itemstack, pointed)
				if core.get_item_group(itemstack:get_name(), "cb_banner_item") > 0 then
					if #B.layers(itemstack) > 0 then
						local one = itemstack:take_item(1)
						if B.wash(pos, one, clicker) then
							if itemstack:is_empty() then
								return one
							end
							local inv = clicker and clicker.get_inventory and clicker:get_inventory()
							local left = inv and inv:add_item("main", one) or one
							if not left:is_empty() then
								core.add_item(vector.offset(pos, 0, 1, 0), left)
							end
							return itemstack
						end
						itemstack:add_item(one)
					end
					return itemstack
				end
				if old then
					return old(pos, node, clicker, itemstack, pointed)
				end
				return itemstack
			end,
		})
	end
end
