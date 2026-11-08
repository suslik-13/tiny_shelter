-- The experience bar between the hearts and the hotbar, as in Minecraft:
-- progress through the level and the level number. The hotbar reaches up to
-- -60 px and the builtin hearts start at -64, so there is no room for a bar:
-- the hearts, the breath bubbles and whatever sits above them (stamina's
-- hunger bar, unified_inventory's item name) move up by X.LIFT pixels.
local X = cb_xp
local W = 182 -- bar width in pixels (texture length)
-- drawn bigger than the texture, like Minecraft's GUI scale (BACKLOG 17)
X.HUD_SCALE = 2.5
X.HUD_SCALE_Y = 2 -- 10 px high
X.BAR_TOP = -72 -- the bar spans -72..-62, two pixels above the hotbar
X.LIFT = 14
local SW = W * X.HUD_SCALE
local huds = {}

-- builtin statbars (builtin/game/hud.lua) with the lifted offset
local STATBAR = -(48 + 24 + 16)
core.hud_replace_builtin("health", { type = "statbar", position = { x = 0.5, y = 1, },
	text = "heart.png", text2 = "heart_gone.png", number = core.PLAYER_MAX_HP_DEFAULT,
	item = core.PLAYER_MAX_HP_DEFAULT, direction = 0, size = { x = 24, y = 24, },
	offset = { x = (-10 * 24) - 25, y = STATBAR - X.LIFT, }, })
core.hud_replace_builtin("breath", { type = "statbar", position = { x = 0.5, y = 1, },
	text = "bubble.png", text2 = "bubble_gone.png", number = core.PLAYER_MAX_BREATH_DEFAULT * 2,
	item = core.PLAYER_MAX_BREATH_DEFAULT * 2, direction = 0, size = { x = 24, y = 24, },
	offset = { x = 25, y = STATBAR - X.LIFT, }, })

-- Other mods' elements stacked above the hearts (bottom-centre anchored,
-- between -80 and -140 px) move up with them, once after the join.
local BUILTIN = { ["heart.png"] = true, ["bubble.png"] = true, }
local function lift_others(player)
	local mine = huds[player:get_player_name()] or {}
	local own = { [mine.bg or -1] = true, [mine.fill or -1] = true, [mine.text or -1] = true, }
	for id, def in pairs(player:hud_get_all() or {}) do
		local pos, off = def.position, def.offset
		if not own[id] and not BUILTIN[def.text] and pos and off and pos.x == 0.5 and pos.y == 1
				and off.y <= -80 and off.y >= -140 then
			player:hud_change(id, "offset", { x = off.x, y = off.y - X.LIFT, })
		end
	end
end

function X.hud(player)
	local name = player:get_player_name()
	local level, into, need = X.level_of(X.get(name))
	local h = huds[name]
	if h and h.player ~= player then
		h = nil
	end
	local fill = { x = into / need * X.HUD_SCALE, y = X.HUD_SCALE_Y, }
	local text = tostring(level)
	if not h then
		h = { player = player, }
		h.bg = player:hud_add({ type = "image", position = { x = 0.5, y = 1, },
			offset = { x = -SW / 2, y = X.BAR_TOP, }, alignment = { x = 1, y = 1, },
			scale = { x = X.HUD_SCALE, y = X.HUD_SCALE_Y, },
			text = "cb_xp_bar_bg.png^[transformR90", z_index = 0, })
		h.fill = player:hud_add({ type = "image", position = { x = 0.5, y = 1, },
			offset = { x = -SW / 2, y = X.BAR_TOP, }, alignment = { x = 1, y = 1, }, scale = fill,
			text = "cb_xp_bar.png^[transformR90", z_index = 1, })
		-- the level number sits on the bar between the hearts and the bubbles
		h.text = player:hud_add({ type = "text", position = { x = 0.5, y = 1, },
			offset = { x = 0, y = X.BAR_TOP - 6, }, alignment = { x = 0, y = 0, }, number = 0x80FF20, text = text,
			size = { x = 2, y = 0, }, style = 1, z_index = 2, })
		huds[name] = h
		return
	end
	player:hud_change(h.fill, "scale", fill)
	player:hud_change(h.text, "text", text)
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	huds[name] = nil
	X.hud(player)
	-- after the other mods' join callbacks have added their elements
	core.after(0.5, function()
		local p = core.get_player_by_name(name)
		if p and p == player then
			lift_others(p)
		end
	end)
end)

core.register_on_leaveplayer(function(player)
	huds[player:get_player_name()] = nil
end)

X.register_on_change(function(name)
	local player = core.get_player_by_name(name)
	if player then
		X.hud(player)
	end
end)
