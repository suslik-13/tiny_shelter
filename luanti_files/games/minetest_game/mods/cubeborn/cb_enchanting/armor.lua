-- Armor enchantments on damage (spec 5): the Protections and Feather
-- Falling (Minecraft's EPF), Unbreaking on armor, Thorns. Armor is 3d_armor's.
local E = cb_enchanting
local FX = cb_core.effects
E.EPF_CAP, E.EPF_STEP = 20, 0.04
E.THORNS_CHANCE = 0.15

-- The worn armor stacks (empty without 3d_armor or for fake players).
function E.worn(player)
	local armor = rawget(_G, "armor")
	if not (armor and armor.get_valid_player) then
		return {}
	end
	local _, inv = armor:get_valid_player(player, "[cb_enchanting]")
	return inv and inv:get_list("armor") or {}
end

-- Blasts in progress: their hp changes are explosions.
E.exploding = 0

local function projectile_name(name)
	for _, w in ipairs({ "arrow", "fireball", "bullet", "charge", "snowball", "spit", }) do
		if name:find(w, 1, true) then
			return true
		end
	end
	return false
end

function E.projectile(obj)
	local ent = obj and obj.get_luaentity and obj:get_luaentity()
	return ent ~= nil and (ent._is_arrow == true or projectile_name(ent.name or ""))
end

-- How Protection sees an hp change: "fall", "fire", "explosion",
-- "projectile", "generic", or nil for damage it does not touch.
function E.damage_kind(reason)
	reason = reason or {}
	if reason.type == "fall" then
		return "fall"
	elseif reason.type == "drown" or reason.hunger then
		return nil
	elseif E.exploding > 0 then
		return "explosion"
	elseif FX.fire_reason(reason) then
		return "fire"
	end
	local cause = reason.type == "set_hp" and reason.cause or ""
	if cause == "cb_dimensions:void" or (cause:match("^cb_") and cause ~= "cb_potion") then
		return nil
	end
	if reason.type == "punch" and E.projectile(reason.object) then
		return "projectile"
	end
	return "generic"
end

local SPECIFIC = { fire = "fire_protection", explosion = "blast_protection", projectile = "projectile_protection", }

function E.epf(stacks, kind)
	if not kind then
		return 0
	end
	local epf = 0
	for _, s in ipairs(stacks) do
		if not s:is_empty() then
			local ench = E.get(s)
			epf = epf + (ench.protection or 0)
			if SPECIFIC[kind] then
				epf = epf + 2 * (ench[SPECIFIC[kind]] or 0)
			elseif kind == "fall" then
				epf = epf + 3 * (ench.feather_falling or 0)
			end
		end
	end
	return math.min(epf, E.EPF_CAP)
end

function E.protect(damage, epf)
	return math.floor(damage * (1 - E.EPF_STEP * math.min(epf, E.EPF_CAP)) + 0.5)
end

-- Unbreaking on armor: whether a hit wears the piece (Minecraft: 60 % + 40 % / (L + 1)).
function E.armor_wears(stack)
	local l = E.level(stack, "unbreaking")
	return l == 0 or math.random() < 0.6 + 0.4 / (l + 1)
end

-- Thorns: each piece may hurt the attacker; returns the damage dealt.
function E.thorns(player, hitter, worn)
	local dealt = 0
	for i, s in ipairs(worn) do
		local l = not s:is_empty() and E.level(s, "thorns") or 0
		if l > 0 and math.random() < E.THORNS_CHANCE * l then
			local dmg = math.random(1, 4)
			dealt = dealt + dmg
			if hitter:is_player() then
				hitter:set_hp(hitter:get_hp() - dmg, { type = "set_hp", cause = "cb_thorns", })
			else
				hitter:punch(hitter, 1, { full_punch_interval = 1, damage_groups = { fleshy = dmg, }, }, nil)
			end
			local armor = rawget(_G, "armor")
			local use = core.get_item_group(s:get_name(), "armor_use")
			if armor and use > 0 and type(player) == "userdata" then
				armor:damage(player, i, s, 2 * use)
			end
		end
	end
	return dealt
end

core.register_on_punchplayer(function(player, hitter)
	if not hitter or hitter == player or E.projectile(hitter) then
		return
	end
	local name, hp = player:get_player_name(), player:get_hp()
	core.after(0, function()
		local p = core.get_player_by_name(name)
		if p and p:get_hp() < hp and hitter:get_pos() then
			E.thorns(p, hitter, E.worn(p))
		end
	end)
end)

core.register_on_mods_loaded(function()
	-- after the other modifiers (3d_armor's, the pack's potion effects)
	core.register_on_player_hpchange(function(player, change, reason)
		if change >= 0 then
			return change
		end
		local epf = E.epf(E.worn(player), E.damage_kind(reason))
		return epf > 0 and -E.protect(-change, epf) or change
	end, true)

	local function counted(t, key)
		local orig = t and t[key]
		if type(orig) ~= "function" then
			return
		end
		t[key] = function(...)
			E.exploding = E.exploding + 1
			local r = { pcall(orig, ...), }
			E.exploding = E.exploding - 1
			if not r[1] then
				error(r[2], 0)
			end
			return unpack(r, 2)
		end
	end
	counted(rawget(_G, "tnt"), "boom")
	counted(rawget(_G, "mobs"), "boom")
	counted(rawget(_G, "mobs"), "safe_boom")
	counted(rawget(_G, "cb_mobs_nether"), "wither_boom")

	-- Unbreaking on armor: a hit wears a piece only sometimes (Minecraft).
	local armor = rawget(_G, "armor")
	if armor and armor.damage then
		local damage = armor.damage
		armor.damage = function(self, player, index, stack, use)
			if not E.armor_wears(stack) then
				use = 0
			end
			return damage(self, player, index, stack, use)
		end
	end
end)
