-- Raid line at the top of the screen of players within 64 of the bell
-- (spec cycle 2, 6): refreshed every second, the outcome stays KEEP seconds.
local S = cb_raids.S
local H = { huds = {}, KEEP = 5, }
cb_raids.hud = H

function H.text(raid)
	return S("Raid — wave @1/@2, @3 left", raid.wave, raid.waves, raid.alive or 0)
end

local function set(p, text, now)
	local name = p:get_player_name()
	local h = H.huds[name]
	if h then
		p:hud_change(h.id, "text", text)
	else
		h = { id = p:hud_add({ type = "text", hud_elem_type = "text", position = { x = 0.5, y = 0.06, },
			alignment = { x = 0, y = 0, }, offset = { x = 0, y = 0, }, number = 0xFF5555, text = text, }), }
		H.huds[name] = h
	end
	h.t = now
end

function H.show(raid, near, now)
	local text = H.text(raid)
	for _, p in ipairs(near) do
		set(p, text, now)
	end
end

function H.finish(raid, near, outcome, now)
	local text = outcome == "victory" and S("Raid — Victory") or outcome == "defeat" and S("Raid — Defeat") or nil
	if text then
		for _, p in ipairs(near) do
			set(p, text, now)
			core.sound_play(outcome == "victory" and "cb_raids_victory" or "cb_raids_defeat",
				{ to_player = p:get_player_name(), }, true)
		end
	end
end

function H.sweep(players, now)
	for _, p in ipairs(players) do
		local name = p:get_player_name()
		local h = H.huds[name]
		if h and now - h.t >= H.KEEP then
			p:hud_remove(h.id)
			H.huds[name] = nil
		end
	end
end

core.register_on_leaveplayer(function(player)
	H.huds[player:get_player_name()] = nil
end)
