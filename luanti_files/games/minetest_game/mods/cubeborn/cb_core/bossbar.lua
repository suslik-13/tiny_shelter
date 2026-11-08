-- Boss health bar at the top of the screen (spec cycle 4, 8d): a name and a
-- bar. A boss refreshes it for players near it; a bar not refreshed for
-- KEEP seconds goes away (the boss died, unloaded or the player left).
local B = { KEEP = 1.5, W = 182, SCALE = 2, bars = {}, }
cb_core.bossbar = B

local function add(player, text, frac, color)
	local w, y = B.W * B.SCALE, 0.08
	local function img(tex, scale, z)
		return player:hud_add({ type = "image", hud_elem_type = "image", position = { x = 0.5, y = y, },
			offset = { x = -w / 2, y = 0, }, alignment = { x = 1, y = 0, }, scale = scale, text = tex, z_index = z, })
	end
	return {
		bg = img("cb_core_bossbar_bg.png", { x = B.SCALE, y = B.SCALE, }, 10),
		fill = img("cb_core_bossbar_fill.png^[multiply:" .. color, { x = B.SCALE * frac, y = B.SCALE, }, 11),
		text = player:hud_add({ type = "text", hud_elem_type = "text", position = { x = 0.5, y = y, },
			offset = { x = 0, y = -14, }, alignment = { x = 0, y = 0, }, number = 0xFFFFFF, text = text, z_index = 12, }),
		player = player,
	}
end

-- Shows or refreshes the bar `key` (one per player: the latest boss wins).
function B.show(player, key, text, frac, color)
	local name = player:get_player_name()
	frac = math.max(0, math.min(1, frac))
	color = color or "#b040ff"
	local h = B.bars[name]
	if h and (h.player ~= player or h.color ~= color) then
		B.hide(player)
		h = nil
	end
	if not h then
		h = add(player, text, frac, color)
		h.color = color
		B.bars[name] = h
	else
		player:hud_change(h.fill, "scale", { x = B.SCALE * frac, y = B.SCALE, })
		player:hud_change(h.text, "text", text)
	end
	h.key, h.t, h.frac = key, core.get_us_time() / 1e6, frac
end

function B.hide(player)
	local name = player:get_player_name()
	local h = B.bars[name]
	if h then
		if h.player == player then
			player:hud_remove(h.bg)
			player:hud_remove(h.fill)
			player:hud_remove(h.text)
		end
		B.bars[name] = nil
	end
end

function B.get(name)
	return B.bars[name]
end

local acc = 0
core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < 0.5 then
		return
	end
	acc = 0
	local now = core.get_us_time() / 1e6
	for name, h in pairs(B.bars) do
		if now - h.t > B.KEEP then
			local p = core.get_player_by_name(name)
			if p then
				B.hide(p)
			else
				B.bars[name] = nil
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	B.bars[player:get_player_name()] = nil
end)
