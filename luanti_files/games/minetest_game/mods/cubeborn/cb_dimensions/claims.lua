-- Nobody without cb_admin claims land inside a Cubeborn pocket (the End and
-- the own Nether): no protection blocks, no areas. The external nether mod's
-- Nether is not a pocket and keeps its usual rules. Loaded after end_rules,
-- so these wrappers run before the End arena ones.
local S = cb_dimensions.S
local MESSAGE = S("You cannot protect land in the Nether or the End.")

-- True when the box lo..hi touches a pocket and `name` has no cb_admin.
function cb_dimensions.claim_refused(lo, hi, name)
	hi = hi or lo
	if core.check_player_privs(name or "", { cb_admin = true, }) then
		return false
	end
	for _, p in pairs(cb_dimensions.all()) do
		if cb_core.intersect(lo, hi, p.minp, p.maxp) then
			return true
		end
	end
	return false
end

local function place_pos(pointed)
	local def = core.registered_nodes[core.get_node(pointed.under).name]
	if def and def.buildable_to then
		return pointed.under
	end
	return pointed.above
end

for _, name in ipairs({ "protector:protect", "protector:protect2", "protector:protect_hidden", }) do
	local def = core.registered_nodes[name]
	if def then
		local old = def.on_place or core.item_place
		core.override_item(name, {
			on_place = function(itemstack, placer, pointed)
				local pname = placer and placer:get_player_name() or ""
				if pointed and pointed.type == "node" and cb_dimensions.claim_refused(place_pos(pointed), nil, pname) then
					core.chat_send_player(pname, MESSAGE)
					return itemstack
				end
				return old(itemstack, placer, pointed)
			end,
		})
	end
end

-- The protector placer tool sets protectors up to 2r+1 nodes away from one
-- near the player, bypassing on_place: refuse it anywhere near a pocket.
local tool = core.registered_items["protector:tool"]
if tool and tool.on_use then
	local old = tool.on_use
	local reach = 2 * math.min(tonumber(core.settings:get("protector_radius")) or 5, 22) + 3
	core.override_item("protector:tool", {
		on_use = function(itemstack, user, pointed)
			local pos = user and user:get_pos()
			local name = user and user:get_player_name() or ""
			if pos and cb_dimensions.claim_refused(vector.subtract(pos, reach), vector.add(pos, reach), name) then
				core.chat_send_player(name, MESSAGE)
				return itemstack
			end
			return old(itemstack, user, pointed)
		end,
	})
end

if areas and areas.canPlayerAddArea then
	local old = areas.canPlayerAddArea
	function areas.canPlayerAddArea(self, pos1, pos2, name)
		local a, b = vector.sort(pos1, pos2)
		if cb_dimensions.claim_refused(a, b, name) then
			return false, MESSAGE
		end
		return old(self, pos1, pos2, name)
	end
end
