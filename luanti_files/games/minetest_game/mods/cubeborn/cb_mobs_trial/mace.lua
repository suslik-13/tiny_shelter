-- Mace and heavy core (plan 8f-1): a heavy core (vault loot) on a breeze
-- rod makes the mace, a slow melee weapon (6, once per 1.6 s). Hitting while
-- falling adds Bedrock's bonus for the height fallen (estimated from the
-- falling speed): +4 a node for the first 3, +2 for the next 5, +1 beyond;
-- such a hit stops the fall and no fall damage follows. Textures from
-- Mineclonia's mcl_tools.
local S = cb_mobs_trial.S
local T = cb_mobs_trial
T.MACE = "cb_mobs_trial:mace"
local MACE = { BASE = 6, COOLDOWN = 1.6, MIN_FALL = 1.5, SAFE = 1, USES = 500, }
T.mace = MACE
local last_hit, safe_until = {}, {}

local CORE_BOX = { type = "fixed", fixed = { -0.25, -0.5, -0.25, 0.25, 0, 0.25, }, }
core.register_node(T.HEAVY_CORE, {
	description = S("Heavy Core"),
	drawtype = "nodebox",
	node_box = CORE_BOX,
	selection_box = CORE_BOX,
	tiles = { "cb_mobs_trial_heavy_core_top.png", "cb_mobs_trial_heavy_core_bottom.png", "cb_mobs_trial_heavy_core_side.png", },
	paramtype = "light",
	groups = { cracky = 2, },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),
})

-- Damage of a mace hit after falling h nodes.
function MACE.damage(h)
	if h <= MACE.MIN_FALL then
		return MACE.BASE
	end
	return math.floor(MACE.BASE + 4 * math.min(h, 3) + 2 * math.min(math.max(h - 3, 0), 5) + math.max(h - 8, 0))
end

-- Height fallen from the falling speed (v^2 = 2gh).
function MACE.fallen(vy)
	if vy >= 0 then
		return 0
	end
	return vy * vy / (2 * 9.81)
end

-- user hits obj with the mace: the damage dealt, or nil while it recovers.
function MACE.hit(user, obj, now)
	local name = user:get_player_name()
	now = now or core.get_us_time() / 1e6
	if last_hit[name] and now - last_hit[name] < MACE.COOLDOWN then
		return nil
	end
	last_hit[name] = now
	local v = user:get_velocity()
	local h = MACE.fallen(v.y)
	local dmg = MACE.damage(h)
	if h > MACE.MIN_FALL then
		user:add_velocity(vector.new(0, -v.y, 0))
		safe_until[name] = now + MACE.SAFE
		core.sound_play("cb_mobs_trial_breeze_burst", { pos = obj:get_pos(), gain = 0.6, max_hear_distance = 16, }, true)
	end
	-- enchantments (cb_enchanting) change the blow
	if MACE.on_hit then
		dmg = MACE.on_hit(user, obj, h, dmg) or dmg
	end
	obj:punch(user, MACE.COOLDOWN, { full_punch_interval = MACE.COOLDOWN, damage_groups = { fleshy = dmg, }, },
		vector.direction(user:get_pos(), obj:get_pos()))
	return dmg
end

core.register_tool(T.MACE, {
	description = S("Mace"),
	inventory_image = "cb_mobs_trial_mace.png",
	tool_capabilities = { full_punch_interval = MACE.COOLDOWN, max_drop_level = 1,
		damage_groups = { fleshy = MACE.BASE, }, },
	groups = { weapon = 1, },
	on_use = function(itemstack, user, pointed)
		if pointed.type ~= "object" or not (user and user:is_player()) or pointed.ref == user then
			return nil
		end
		if MACE.hit(user, pointed.ref) and not core.is_creative_enabled(user:get_player_name()) then
			itemstack:add_wear(math.ceil(65535 / MACE.USES))
		end
		return itemstack
	end,
})

core.register_craft({ output = T.MACE, recipe = { { T.HEAVY_CORE, }, { T.BREEZE_ROD, }, }, })

core.register_on_player_hpchange(function(player, change, reason)
	local name = player:get_player_name()
	if change < 0 and reason.type == "fall" and safe_until[name] and core.get_us_time() / 1e6 < safe_until[name] then
		return 0
	end
	return change
end, true)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	last_hit[name], safe_until[name] = nil, nil
end)
