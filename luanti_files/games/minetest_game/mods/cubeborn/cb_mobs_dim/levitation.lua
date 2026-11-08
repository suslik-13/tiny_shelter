-- Levitation (shulker bullets): no gravity and a steady rise of
-- LEVITATION_RISE nodes/s for its time; a new hit never shortens it.
local L_RISE = 0.9
cb_mobs_dim.LEVITATION_RISE = L_RISE
local left = {}

function cb_mobs_dim.levitate(player, seconds)
	local name = player:get_player_name()
	left[name] = math.max(left[name] or 0, seconds)
	cb_core.physics.set_gravity(player, "levitation", 0)
end

-- Returns whether the player still levitates.
function cb_mobs_dim.levitation_tick(player, dt)
	local name = player:get_player_name()
	if not left[name] then
		return false
	end
	left[name] = left[name] - dt
	if left[name] <= 0 then
		left[name] = nil
		cb_core.physics.clear_gravity(player, "levitation")
		return false
	end
	local v = player:get_velocity()
	if v then
		player:add_velocity(vector.new(0, L_RISE - v.y, 0))
	end
	return true
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.5 or next(left) == nil then
		return
	end
	local dt = timer
	timer = 0
	for name in pairs(left) do
		local player = core.get_player_by_name(name)
		if player then
			cb_mobs_dim.levitation_tick(player, dt)
		else
			left[name] = nil
		end
	end
end)

core.register_on_dieplayer(function(player)
	if left[player:get_player_name()] then
		left[player:get_player_name()] = nil
		cb_core.physics.clear_gravity(player, "levitation")
	end
end)
