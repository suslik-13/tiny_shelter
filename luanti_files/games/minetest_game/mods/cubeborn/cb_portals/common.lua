-- Helpers shared by the Nether and End portals.

-- Moves a player through a portal or gateway, with the teleport sound at
-- both ends.
function cb_portals.teleport(player, dest)
	local from = player:get_pos()
	if from then
		core.sound_play("cb_portals_teleport", { pos = from, max_hear_distance = 16, }, true)
	end
	player:set_pos(dest)
	core.sound_play("cb_portals_teleport", { pos = dest, max_hear_distance = 16, }, true)
end
-- A bed inside a pocket is not a respawn point (as in MC, beds do not work in
-- the Nether or the End): otherwise the exit portal and death would lead back.
local function in_pocket(pos)
	local _, pocket = cb_dimensions.is_shell(vector.round(pos))
	return pocket ~= nil
end

function cb_portals.respawn_pos(name)
	local bed = beds and beds.spawn and beds.spawn[name]
	if bed and not in_pocket(bed) then
		return vector.copy(bed)
	end
	return core.setting_get_pos("static_spawnpoint") or vector.new(0, core.get_spawn_level(0, 0) or 8, 0)
end

if beds and beds.set_spawns then
	local S = cb_portals.S
	local old = beds.set_spawns
	function beds.set_spawns()
		local before = {}
		for name in pairs(beds.player) do
			before[name] = beds.spawn[name] or false
		end
		old()
		local changed = false
		for name, prev in pairs(before) do
			local now = beds.spawn[name]
			if now and now ~= prev and in_pocket(now) then
				beds.spawn[name] = prev or nil
				changed = true
				core.chat_send_player(name, S("Beds do not set a respawn point here."))
			end
		end
		if changed then
			beds.save_spawns()
		end
	end
end
