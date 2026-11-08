-- The grindstone (spec 4.6): enchantments come off, curses stay, and the
-- experience comes back (Minecraft: from half to all of the enchantments'
-- minimum table levels). The station itself is cb_blocks'.
local E = cb_enchanting

-- `stack` without its non-curse enchantments (curses of `other` added), the
-- experience they give back, and whether anything came off. Other meta stays.
function E.strip(stack, other)
	local keep, sum, removed = {}, 0, false
	local function take(t)
		for name, l in pairs(t) do
			local def = E.DEFS[name]
			if def and def.curse then
				keep[name] = math.max(keep[name] or 0, l)
			elseif def then
				removed = true
				sum = sum + ((def.power[l] or def.power[#def.power])[1])
			end
		end
	end
	take(E.get(stack))
	if other then
		take(E.get(other))
	end
	local out = ItemStack(stack)
	if out:get_name() == "cb_enchanting:book" and not next(keep) then
		out = ItemStack("default:book")
	end
	out:get_meta():set_string("cb_enchanting:pwp", "")
	E.set(out, keep)
	local xp = sum > 0 and math.random(math.ceil(sum / 2), sum) or 0
	return out, xp, removed
end

local G = rawget(_G, "cb_blocks") and cb_blocks.grindstone
if G then
	G.strip = E.strip
end
