-- Smithing table (spec cycle 3, 4): a diamond tool or armor piece and a
-- netherite ingot give the netherite item with the same wear (Luanti wear is
-- already a share of the item's life); the upgrade needs no template. With an
-- armor trim template (plan 14c) armour + a trim material gets the trim.
local NAME = "cb_blocks:smithing_table"
local S = cb_items.S
local SM = { INGOT = "cb_blocks:netherite_ingot", }
cb_items.smithing = SM

function SM.result(tool, ingot)
	local target = cb_items.netherite.UPGRADE[tool:get_name()]
	if not target or tool:get_count() ~= 1 or ingot:get_name() ~= SM.INGOT then
		return nil
	end
	-- Keep enchantments, trims, names: copy the meta, rename the first line.
	local out = ItemStack(target)
	out:get_meta():from_table(tool:get_meta():to_table())
	out:set_wear(tool:get_wear())
	local meta = out:get_meta()
	local desc = meta:get_string("description")
	if desc ~= "" then
		local new = (out:get_definition().description or target):match("^[^\n]*")
		local nl = desc:find("\n", 1, true)
		meta:set_string("description", new .. (nl and desc:sub(nl) or ""))
	end
	if cb_items.trims then
		cb_items.trims.rebase(out)
	end
	return out
end

-- The table's result: a trim when a template sits in its slot (template +
-- armour + trim material), else the netherite upgrade (no template needed).
function SM.compute(tool, template, ingot)
	local T = cb_items.trims
	if not template:is_empty() then
		local pattern, material = T.pattern_of(template), T.material_of(ingot)
		if not pattern or not material or tool:get_count() ~= 1 then
			return nil
		end
		return T.apply(tool, pattern, material)
	end
	return SM.result(tool, ingot)
end

local function tool_ok(stack)
	return cb_items.netherite.UPGRADE[stack:get_name()] or cb_items.trims.piece_of(stack)
end

if core.registered_nodes[NAME] and cb_blocks.ws then
	cb_blocks.ws.station(NAME, {
		sizes = { tool = 1, template = 1, ingot = 1, out = 1, },
		sound = "cb_blocks_smithing",
		body = function(loc)
			return "label[0,0;" .. core.formspec_escape(S("Smithing Table")) .. "]"
				.. "list[" .. loc .. ";template;0.5,1.25;1,1;]list[" .. loc .. ";tool;1.6,1.25;1,1;]"
				.. "list[" .. loc .. ";ingot;2.7,1.25;1,1;]"
				.. "image[3.9,1.25;1,1;gui_furnace_arrow_bg.png^[transformR270]list[" .. loc .. ";out;5.1,1.25;1,1;]"
				.. "listring[" .. loc .. ";out]listring[current_player;main]listring[" .. loc
				.. ";tool]listring[current_player;main]"
		end,
		accept = function(list, stack)
			if list == "tool" then
				return tool_ok(stack) and 1 or 0
			elseif list == "template" then
				return core.get_item_group(stack:get_name(), "smithing_template") > 0 and stack:get_count() or 0
			end
			return (stack:get_name() == SM.INGOT or cb_items.trims.material_of(stack)) and stack:get_count() or 0
		end,
		compute = function(inv)
			return SM.compute(inv:get_stack("tool", 1), inv:get_stack("template", 1), inv:get_stack("ingot", 1))
		end,
		spend = function(inv)
			inv:set_stack("tool", 1, "")
			for _, list in ipairs({ "ingot", "template", }) do
				local st = inv:get_stack(list, 1)
				st:take_item(1)
				inv:set_stack(list, 1, st)
			end
		end,
	})
end
