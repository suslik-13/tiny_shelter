-- Grindstone (spec cycle 3, 4; cycle 8, 4.6): two of the same worn tool
-- become one with both durabilities plus 5 % of the maximum, never above
-- full; one item alone loses its enchantments. G.strip (set by
-- cb_enchanting) takes the enchantments off, curses aside, and the
-- experience they held drops as orbs when the result is taken.
local NAME = "cb_blocks:grindstone"
if not cb_blocks.registered[NAME] then
	return
end
local S = cb_blocks.S
local G = { BONUS = 0.05, }
cb_blocks.grindstone = G
local FULL = 65536

function G.combine(a, b)
	if a:is_empty() or b:is_empty() or a:get_name() ~= b:get_name() or a:get_count() ~= 1 or b:get_count() ~= 1
			or not core.registered_tools[a:get_name()] then
		return nil
	end
	local d = (FULL - a:get_wear()) + (FULL - b:get_wear()) + math.floor(FULL * G.BONUS)
	-- the first tool's meta (toolranks level, enchantments) stays
	local out = ItemStack(a)
	out:set_wear(math.max(0, FULL - d))
	if G.strip then
		out = G.strip(out, b)
	end
	return out
end

-- The result of the lists a and b, and the experience the enchantments held.
function G.result(inv)
	local a, b = inv:get_stack("a", 1), inv:get_stack("b", 1)
	if not a:is_empty() and not b:is_empty() then
		local out = G.combine(a, b)
		return out, out and G.strip and select(2, G.strip(a, b)) or 0
	end
	local one = a:is_empty() and b or a
	if one:is_empty() or not G.strip then
		return nil, 0
	end
	local out, xp, removed = G.strip(one)
	if not removed then
		return nil, 0
	end
	return out, xp
end

cb_blocks.ws.station(NAME, {
	sizes = { a = 1, b = 1, out = 1, },
	sound = "cb_blocks_grindstone",
	body = function(loc)
		return "label[0,0;" .. core.formspec_escape(S("Grindstone")) .. "]list[" .. loc .. ";a;2,0.6;1,1;]list["
			.. loc .. ";b;2,1.9;1,1;]image[3.5,1.25;1,1;gui_furnace_arrow_bg.png^[transformR270]list[" .. loc
			.. ";out;5,1.25;1,1;]listring[" .. loc .. ";out]listring[current_player;main]listring[" .. loc
			.. ";a]listring[current_player;main]"
	end,
	accept = function(_, stack)
		return (core.registered_tools[stack:get_name()] or stack:get_name() == "cb_enchanting:book") and 1 or 0
	end,
	compute = function(inv)
		return (G.result(inv))
	end,
	spend = function(inv, pos)
		local _, xp = G.result(inv)
		local X = rawget(_G, "cb_xp")
		if xp > 0 and X and pos then
			X.drop(pos, xp)
		end
		inv:set_stack("a", 1, "")
		inv:set_stack("b", 1, "")
	end,
})
