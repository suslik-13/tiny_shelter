-- Potion effects (spec cycle 6, 4.5): what Bedrock potions do to players.
-- Speed, jump boost and slow falling are physics factors; strength, resistance
-- and fire resistance change damage in one hpchange modifier (and strength
-- also in mobs_redo's punch); night vision lights the client, invisibility
-- hides the model and the name tag. The 1.21 effects act when the player is
-- hurt (infested) or dies (oozing, weaving, wind charged); death clears all.
local S = cb_core.S
local E = cb_core.effects
local P = cb_core.physics
E.STRENGTH, E.RESISTANCE = 3, 0.2

local function factor(name, field, per)
	E.register(name, {
		description = name,
		icon = "cb_core_effect_" .. name .. ".png",
		on_start = function(player, e)
			P.set_factor(player, field, name, 1 + per * (e.level or 1))
		end,
		on_end = function(player)
			P.clear_factor(player, field, name)
		end,
	})
end
factor("speed", "speed", 0.2)
factor("jump_boost", "jump", 0.1)
E.defs.speed.description = S("Speed")
E.defs.jump_boost.description = S("Jump Boost")

E.register("slow_falling", {
	description = S("Slow Falling"),
	icon = "cb_core_effect_slow_falling.png",
	on_start = function(player)
		P.set_gravity(player, "slow_falling", 0.15)
	end,
	on_end = function(player)
		P.clear_gravity(player, "slow_falling")
	end,
})

E.register("strength", { description = S("Strength"), icon = "cb_core_effect_strength.png", })
E.register("resistance", { description = S("Resistance"), icon = "cb_core_effect_resistance.png", })
E.register("fire_resistance", { description = S("Fire Resistance"), icon = "cb_core_effect_fire_resistance.png", })

E.register("water_breathing", {
	description = S("Water Breathing"),
	icon = "cb_core_effect_water_breathing.png",
	on_tick = function(player)
		local max = player:get_properties().breath_max or 10
		if player:get_breath() < max then
			player:set_breath(max)
		end
	end,
})

E.register("night_vision", {
	description = S("Night Vision"),
	icon = "cb_core_effect_night_vision.png",
	on_start = function(player)
		player:override_day_night_ratio(1)
	end,
	on_end = function(player)
		player:override_day_night_ratio(nil)
	end,
})

-- Invisibility: the look before it is kept in player meta, so the end of the
-- effect brings it back after a restart too. Worn armour shows (as in MC):
-- 3d_armor draws it on the same model, so it hides with it here.
local invisible = {}
local LOOK = "cb_invis_look"

local function hide(name, on)
	invisible[name] = on or nil
	local inv = rawget(_G, "invisibility")
	if inv and inv.hidden then
		inv.hidden[name] = on or nil
	end
end

function cb_core.invisible(name)
	return invisible[name] == true
end

-- Hides the model, keeping what it looked like (a skin mod may set the
-- look again after a join or a skin change: the tick hides it once more and
-- keeps that newer look for the end).
local function conceal(player, fresh)
	local meta = player:get_meta()
	if fresh or meta:get_string(LOOK) == "" then
		local props = player:get_properties()
		local look = core.deserialize(meta:get_string(LOOK)) or {}
		look.visual_size = props.visual_size
		local tag = props.nametag_color
		if tag and (tag.a or 255) > 0 then
			look.nametag_color = tag
		end
		meta:set_string(LOOK, core.serialize(look))
	end
	hide(player:get_player_name(), true)
	player:set_properties({ visual_size = { x = 0, y = 0, z = 0, }, nametag_color = { a = 0, r = 255, g = 255, b = 255, },
		show_on_minimap = false, })
end

E.register("invisibility", {
	description = S("Invisibility"),
	icon = "cb_core_effect_invisibility.png",
	on_start = function(player)
		conceal(player, false)
	end,
	on_tick = function(player)
		local size = player:get_properties().visual_size
		if size and size.x ~= 0 then
			conceal(player, true)
		end
	end,
	on_end = function(player)
		local meta = player:get_meta()
		local look = core.deserialize(meta:get_string(LOOK)) or {}
		meta:set_string(LOOK, "")
		hide(player:get_player_name(), false)
		player:set_properties({ visual_size = look.visual_size or { x = 1, y = 1, z = 1, },
			nametag_color = look.nametag_color or { a = 255, r = 255, g = 255, b = 255, }, show_on_minimap = true, })
	end,
})

core.register_on_leaveplayer(function(player)
	hide(player:get_player_name(), false)
end)

E.register("wind_charged", { description = S("Wind Charged"), icon = "cb_core_effect_wind_charged.png", })
E.register("weaving", { description = S("Weaving"), icon = "cb_core_effect_weaving.png", })
E.register("oozing", { description = S("Oozing"), icon = "cb_core_effect_oozing.png", })
E.register("infested", { description = S("Infested"), icon = "cb_core_effect_infested.png", })

function E.strength_bonus(player)
	local level = E.get(player, "strength")
	return level and E.STRENGTH * level or 0
end

-- Damage after the effects that change it; kind is "fall", "fire" or nil.
-- Jump boost takes one fall damage per level; resistance 20 % per level.
function E.reduce(player, damage, kind)
	if kind == "fall" then
		if E.get(player, "slow_falling") then
			return 0
		end
		damage = math.max(0, damage - (E.get(player, "jump_boost") or 0))
	elseif kind == "fire" and E.get(player, "fire_resistance") then
		return 0
	end
	local r = E.get(player, "resistance")
	if r then
		damage = math.floor(damage * math.max(0, 1 - E.RESISTANCE * r) + 0.5)
	end
	return damage
end

-- Undead mobs: instant health hurts them and instant damage heals them.
local UNDEAD = { "zombie", "skeleton", "wither", "drowned", "husk", "stray", "phantom", "zoglin", "bogged", }
function E.undead(ent)
	if not ent then
		return false
	end
	if ent._cb_undead ~= nil then
		return ent._cb_undead
	end
	for _, w in ipairs(UNDEAD) do
		if ent.name:find(w, 1, true) then
			return true
		end
	end
	return false
end

-- Instant health (+) or damage (-) to a player or a mob.
function E.instant(obj, delta)
	if obj:is_player() then
		local hp = obj:get_hp()
		local max = obj:get_properties().hp_max or 20
		if hp > 0 then
			obj:set_hp(math.max(0, math.min(max, hp + delta)), { type = "set_hp", cause = "cb_potion", })
		end
		return
	end
	local ent = obj:get_luaentity()
	if not (ent and ent.health) then
		return
	end
	if E.undead(ent) then
		delta = -delta
	end
	if delta > 0 then
		ent.health = math.min(ent.hp_max or ent.health + delta, ent.health + delta)
	else
		obj:punch(obj, 1, { full_punch_interval = 1, damage_groups = { fleshy = -delta, }, }, nil)
	end
end

-- Whether an hp change reason is fire or lava (also used by Fire Protection).
function E.fire_reason(reason)
	if reason.type == "node_damage" and reason.node then
		local def = core.registered_nodes[reason.node]
		local g = def and def.groups or {}
		return (g.lava or 0) > 0 or (g.igniter or 0) > 0 or reason.node:find("fire", 1, true) ~= nil
	end
	local cause = reason.type == "set_hp" and reason.cause or ""
	return cause:find("fire", 1, true) ~= nil or cause:find("lava", 1, true) ~= nil
		or cause:find("burn", 1, true) ~= nil
end

local function infest(player)
	if E.get(player, "infested") and math.random() < 0.1 and core.registered_entities["cb_mobs_overworld:silverfish"] then
		core.add_entity(vector.offset(player:get_pos(), 0, 0.5, 0), "cb_mobs_overworld:silverfish")
	end
end

core.register_on_player_hpchange(function(player, change, reason)
	if change >= 0 then
		return change
	end
	reason = reason or {}
	local damage = -change
	local hitter = reason.type == "punch" and reason.object
	if hitter and hitter:is_player() then
		damage = damage + E.strength_bonus(hitter)
	end
	local kind = reason.type == "fall" and "fall" or E.fire_reason(reason) and "fire" or nil
	-- the pack's own ticking effects are not resisted (as poison in MC)
	local own = reason.type == "set_hp" and (reason.cause or ""):match("^cb_") and reason.cause ~= "cb_potion"
	if own then
		return change
	end
	damage = E.reduce(player, damage, kind)
	if damage > 0 then
		infest(player)
	end
	return -damage
end, true)

-- Strength: blows at mobs hit harder (mobs_redo reads damage groups).
core.register_on_mods_loaded(function()
	local mobs = rawget(_G, "mobs")
	local class = mobs and mobs.mob_class
	if not (class and class.on_punch) then
		return
	end
	local on_punch = class.on_punch
	class.on_punch = function(self, hitter, tflp, caps, dir, damage)
		local bonus = hitter and hitter.is_player and hitter:is_player() and E.strength_bonus(hitter) or 0
		if bonus > 0 and caps and caps.damage_groups then
			caps = table.copy(caps)
			caps.damage_groups.fleshy = (caps.damage_groups.fleshy or 0) + bonus
		end
		return on_punch(self, hitter, tflp, caps, dir, damage)
	end
end)

-- Invisible players are no target, unless they hit the mob in the last
-- HIT_MEMORY s; the warden hears them anyway (as in MC). Covers the pack's
-- mobs that pick their own targets (do_attack) as well as mobs_redo's.
E.HIT_MEMORY = 10

-- A hit mob sees invisible players for HIT_MEMORY s: mobs_redo drops an
-- invisible target every step unless the mob ignores invisibility.
function E.remember_hit(self, name)
	local now = core.get_gametime()
	self._cb_hit_by = self._cb_hit_by or {}
	self._cb_hit_by[name] = now
	if not invisible[name] then
		return
	end
	self.ignore_invisibility = true
	core.after(E.HIT_MEMORY + 0.5, function()
		local last = self._cb_hit_by and self._cb_hit_by[name]
		if self.object:get_pos() and last and core.get_gametime() - last >= E.HIT_MEMORY then
			self.ignore_invisibility = nil
		end
	end)
end
core.register_on_mods_loaded(function()
	local mobs = rawget(_G, "mobs")
	local class = mobs and mobs.mob_class
	if not (class and class.do_attack and class.on_punch) then
		return
	end
	local do_attack, on_punch = class.do_attack, class.on_punch
	class.do_attack = function(self, target, ...)
		local name = target and target.is_player and target:is_player() and target:get_player_name()
		if name and invisible[name] and self.name ~= "cb_mobs_deep:warden" then
			local hit = self._cb_hit_by and self._cb_hit_by[name]
			if not (hit and core.get_gametime() - hit <= E.HIT_MEMORY) then
				return
			end
		end
		return do_attack(self, target, ...)
	end
	class.on_punch = function(self, hitter, ...)
		if hitter and hitter.is_player and hitter:is_player() then
			E.remember_hit(self, hitter:get_player_name())
		end
		return on_punch(self, hitter, ...)
	end
end)

-- Milk (mobs_animal's bucket and glass) clears every effect. When the
-- food mod hands the stack back (stamina with a full bar) the milk is drunk
-- anyway, as in MC: the empty vessel is given instead.
local MILK = { ["mobs:bucket_milk"] = "bucket:bucket_empty", ["mobs:glass_milk"] = "vessels:drinking_glass", }

function E.after_milk(name, count, result, user, empty)
	E.clear_all(user)
	result = result or ItemStack(name .. " " .. count)
	local untouched = result:get_name() == name and result:get_count() == count
	if untouched and not core.is_creative_enabled(user:get_player_name()) then
		result:take_item()
		if result:is_empty() then
			return ItemStack(empty)
		end
		local inv = user.get_inventory and user:get_inventory()
		local vessel = ItemStack(empty)
		if inv and inv:room_for_item("main", vessel) then
			inv:add_item("main", vessel)
		elseif user.get_pos then
			core.add_item(user:get_pos(), vessel)
		end
	end
	return result
end

core.register_on_mods_loaded(function()
	for name, empty in pairs(MILK) do
		local def = core.registered_items[name]
		if def and def.on_use then
			local on_use = def.on_use
			core.override_item(name, {
				on_use = function(itemstack, user, ...)
					if not (user and user.is_player and user:is_player()) then
						return on_use(itemstack, user, ...)
					end
					local count = itemstack:get_count()
					return E.after_milk(name, count, on_use(ItemStack(itemstack), user, ...), user, empty)
				end,
			})
		end
	end
end)

-- On death: oozing leaves two small slimes, weaving cobwebs, wind charged
-- a gust; then every effect ends (as in MC).
local function free_air(pos, name)
	return core.get_node(pos).name == "air" and not core.is_protected(pos, name)
end

core.register_on_dieplayer(function(player)
	local pos, name = player:get_pos(), player:get_player_name()
	if pos and E.get(player, "oozing") and core.registered_entities["mobs_slimes:greensmall"] then
		for _ = 1, 2 do
			core.add_entity(vector.offset(pos, math.random() - 0.5, 0.5, math.random() - 0.5), "mobs_slimes:greensmall")
		end
	end
	if pos and E.get(player, "weaving") and core.registered_nodes["cb_blocks:cobweb"] then
		local n = 0
		for _, d in ipairs({ vector.new(0, 0, 0), vector.new(1, 0, 0), vector.new(-1, 0, 0), vector.new(0, 0, 1), vector.new(0, 0, -1), }) do
			local p = vector.round(vector.add(pos, d))
			if n < 3 and free_air(p, name) then
				core.set_node(p, { name = "cb_blocks:cobweb", })
				n = n + 1
			end
		end
	end
	if pos and E.get(player, "wind_charged") then
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 3)) do
			if obj ~= player then
				local d = vector.subtract(obj:get_pos(), pos)
				local v = vector.add(vector.multiply(vector.normalize(vector.new(d.x, 0, d.z)), 8), vector.new(0, 6, 0))
				obj:add_velocity(v)
			end
		end
	end
	E.clear_all(player)
end)
