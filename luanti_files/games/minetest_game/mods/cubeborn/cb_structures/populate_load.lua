-- Load governor of /cb_populate: players must barely notice it. While a run is
-- on, every second it picks a mode and sets the background job budget:
--   gentle (players online): small job budget, a spot a second, a pause after
--                            every built structure;
--   full   (nobody online):  normal speed;
--   lag    (smoothed server step above 0.15 s): everything waits until the
--                            step has stayed below for 3 s.
local PL = {}
cb_structures.populate_load = PL

local BUDGET_US = (tonumber(cb_core.setting("cubeborn.populate_budget_ms", "4")) or 4) * 1000
local SPOT_S = tonumber(cb_core.setting("cubeborn.populate_spot_s", "1")) or 1
local PAUSE_S = tonumber(cb_core.setting("cubeborn.populate_pause_s", "20")) or 20
local LAG_S, CALM_S = 0.15, 3

local running = false
local avg, calm, lagging = 0, 0, false
local mode = "full"

local function players()
	if PL._players then
		return PL._players()
	end
	return #core.get_connected_players()
end

function PL._feed_dtime(dtime)
	avg = avg * 0.9 + dtime * 0.1
	if avg > LAG_S then
		lagging, calm = true, 0
	elseif lagging then
		calm = calm + dtime
		if calm >= CALM_S then
			lagging = false
		end
	end
end

local function apply()
	if lagging then
		mode = "lag"
		cb_core.jobs.set_budget(0)
	elseif players() > 0 then
		mode = "gentle"
		cb_core.jobs.set_budget(BUDGET_US)
	else
		mode = "full"
		cb_core.jobs.set_budget(nil)
	end
end

local timer = 0
core.register_globalstep(function(dtime)
	if not running then
		return
	end
	if not PL._lag_hold then
		PL._feed_dtime(dtime)
	end
	timer = timer + dtime
	if timer >= 1 then
		timer = 0
		apply()
	end
end)

function PL.start()
	running, timer = true, 0
	avg, calm, lagging = 0, 0, false
	apply()
end

function PL.stop()
	running = false
	mode = "full"
	cb_core.jobs.set_budget(nil)
end

function PL.mode()
	if running and lagging then
		return "lag"
	end
	return mode
end

function PL.ready()
	return not (running and lagging)
end

-- Seconds before the next spot is examined; nil while the server lags.
function PL.spot_delay()
	if not PL.ready() then
		return nil
	end
	return PL.mode() == "gentle" and SPOT_S or 0.2
end

function PL.pause_after_build()
	return PL.mode() == "gentle" and PAUSE_S or 0
end
