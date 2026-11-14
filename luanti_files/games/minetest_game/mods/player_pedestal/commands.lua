local S = player_pedestal.S
local R = player_pedestal.ranking

minetest.register_chatcommand("pedestal_refresh", {
	description = S("Rescan rankings and re-create all loaded statues"),
	privs = { pedestal_admin = true },
	func = function()
		for _, stat in ipairs(R.order) do
			R.rescan(stat)
		end
		local n = player_pedestal.respawn_all()
		return true, S("Refreshed @1 loaded pedestals.", n)
	end,
})

-- Pose calibration: rotate one bone of the nearest statue (degrees, relative).
minetest.register_chatcommand("pedestal_bone", {
	params = "<Head|Body|Arm_Left|Arm_Right|Leg_Left|Leg_Right> <x> <y> <z>",
	description = S("Test a bone rotation on the nearest statue (pose calibration)"),
	privs = { pedestal_admin = true },
	func = function(name, param)
		local bone, x, y, z = param:match("^(%S+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)$")
		if not bone then
			return false, "/pedestal_bone <bone> <x> <y> <z>"
		end
		local player = minetest.get_player_by_name(name)
		if not player then
			return false
		end
		local best, bestd
		for _, obj in ipairs(minetest.get_objects_inside_radius(player:get_pos(), 6)) do
			local le = obj:get_luaentity()
			if le and le.name == "player_pedestal:statue" then
				local d = vector.distance(obj:get_pos(), player:get_pos())
				if not bestd or d < bestd then
					best, bestd = obj, d
				end
			end
		end
		if not best then
			return false, S("No statue within 6 blocks.")
		end
		player_pedestal.apply_bone(best, bone, { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
		return true, S("Applied. Save the values into poses.lua to keep them.")
	end,
})
