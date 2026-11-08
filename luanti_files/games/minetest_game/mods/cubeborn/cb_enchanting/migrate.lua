-- Old xdecor enchanted tools (spec 4.4): default:enchanted_<tool>_<material>_<kind>
-- become default:<tool>_<material> with the matching enchantment. xdecor
-- still registers them, so ones not yet converted are not unknown items.
local E = cb_enchanting
E.MIGRATE = { fast = { "efficiency", 2, }, durable = { "unbreaking", 2, }, sharp = { "sharpness", 2, }, }
E.MIGRATE_EVERY = 10

function E.convert(stack)
	local book = E.blank_book and E.blank_book(stack)
	if book then
		return book
	end
	local base, kind = stack:get_name():match("^default:enchanted_(.+)_(%a+)$")
	local m = kind and E.MIGRATE[kind]
	if not m or not core.registered_items["default:" .. base] then
		return nil
	end
	local out = ItemStack("default:" .. base)
	out:set_wear(stack:get_wear())
	local meta = out:get_meta()
	meta:from_table(stack:get_meta():to_table())
	-- the toolranks line named the old item
	local tr, dug = rawget(_G, "toolranks"), tonumber(meta:get_string("dug"))
	local orig = out:get_definition().original_description
	meta:set_string("description", tr and dug and orig and tr.create_description(orig, dug) or "")
	local ench = E.get(stack)
	ench[m[1]] = math.max(ench[m[1]] or 0, m[2])
	return E.set(out, ench)
end

function E.convert_player(player)
	local inv = player:get_inventory()
	for _, list in ipairs({ "main", "craft", }) do
		for i, stack in ipairs(inv:get_list(list) or {}) do
			local out = not stack:is_empty() and E.convert(stack)
			if out then
				inv:set_stack(list, i, out)
			end
		end
	end
end

core.register_on_joinplayer(E.convert_player)

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < E.MIGRATE_EVERY then
		return
	end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		E.convert_player(player)
	end
end)
