-- Weapon enchantments on hits (spec 5): Smite, Bane of Arthropods,
-- Knockback, Looting. Mob hits go through mobs_redo's on_punch, wrapped like
-- cb_core does for Weakness; Looting is mobs_redo's own looting_level meta.
local E = cb_enchanting
local FX = cb_core.effects
E.KIND_BONUS = 2.5
E.KNOCKBACK_STEP = 3

local ARTHROPODS = { "spider", "silverfish", "endermite", ":bee", }
function E.arthropod(ent)
	if not ent then
		return false
	end
	if ent._cb_arthropod ~= nil then
		return ent._cb_arthropod
	end
	for _, w in ipairs(ARTHROPODS) do
		if ent.name:find(w, 1, true) then
			return true
		end
	end
	return false
end

-- The caps of a hit by `stack` on the mob `ent`; `caps` itself when no enchantment changes them.
function E.hit_caps(ent, stack, caps)
	local ench = E.get(stack)
	local bonus = 0
	if (ench.smite or 0) > 0 and FX.undead(ent) then
		bonus = E.KIND_BONUS * ench.smite
	elseif (ench.bane_of_arthropods or 0) > 0 and E.arthropod(ent) then
		bonus = E.KIND_BONUS * ench.bane_of_arthropods
	end
	local kb = ench.knockback or 0
	if bonus == 0 and kb == 0 or not (caps and caps.damage_groups) then
		return caps
	end
	local c = table.copy(caps)
	c.damage_groups.fleshy = (c.damage_groups.fleshy or 0) + bonus
	if kb > 0 then
		c.damage_groups.knockback = (caps.damage_groups.fleshy or 1) + E.KNOCKBACK_STEP * kb
	end
	return c
end

-- Bane's slowness: a quarter of the speed for `seconds`.
function E.slow(ent, seconds)
	local till = core.get_us_time() + seconds * 1e6
	if ent._cb_slow then
		ent._cb_slow.till = math.max(ent._cb_slow.till, till)
	else
		ent._cb_slow = { walk = ent.walk_velocity, run = ent.run_velocity, till = till, }
		ent.walk_velocity = (ent.walk_velocity or 1) * 0.25
		ent.run_velocity = (ent.run_velocity or 1) * 0.25
	end
	local function restore()
		local s = ent._cb_slow
		if not (s and ent.object:get_pos()) then
			return
		end
		local left = (s.till - core.get_us_time()) / 1e6
		if left > 0.05 then
			return core.after(left, restore)
		end
		ent.walk_velocity, ent.run_velocity, ent._cb_slow = s.walk, s.run, nil
	end
	core.after(seconds, restore)
end

-- A mob saved while slowed would keep the slow speed for good.
do
	local mobs = rawget(_G, "mobs")
	local class = mobs and mobs.mob_class
	local save = class and class.mob_staticdata
	if save then
		class.mob_staticdata = function(self, ...)
			local s = self._cb_slow
			if s then
				self.walk_velocity, self.run_velocity, self._cb_slow = s.walk, s.run, nil
			end
			return save(self, ...)
		end
	end
end

local function is_player(o)
	return o and o.is_player and o:is_player()
end

-- At load time, not on mods loaded: cb_xp's gates copy each mob's on_punch
-- then, and the copy must already be this one.
do
	local mobs = rawget(_G, "mobs")
	local class = mobs and mobs.mob_class
	local on_punch = class and class.on_punch
	class = on_punch and class or {}
	class.on_punch = function(self, hitter, tflp, caps, dir, damage)
		if not is_player(hitter) then
			return on_punch(self, hitter, tflp, caps, dir, damage)
		end
		local stack = hitter:get_wielded_item()
		local ench = E.get(stack)
		if not next(ench) then
			return on_punch(self, hitter, tflp, caps, dir, damage)
		end
		-- swords enchanted before Looting worked have no looting_level yet
		local loot = ench.looting or 0
		if stack:get_meta():get_string("looting_level") ~= (loot > 0 and tostring(loot) or "") then
			E.refresh(stack)
			hitter:set_wielded_item(stack)
		end
		local before = self.health
		local r = on_punch(self, hitter, tflp, E.hit_caps(self, stack, caps), dir, damage)
		-- only blows that hurt (not protected mobs, not immune ones)
		if self.health > 0 and self.health < before then
			local bane = ench.bane_of_arthropods or 0
			if bane > 0 and E.arthropod(self) then
				E.slow(self, 1 + math.random() * 0.5 * bane)
			end
			if (ench.fire_aspect or 0) > 0 then
				E.ignite(self.object, E.BURN_PER_LEVEL * ench.fire_aspect, hitter:get_player_name())
			end
		end
		return r
	end
	E.combat_wrapped = on_punch ~= nil
end

-- Players: the engine pushes them, Knockback pushes harder. `ench` are the
-- hitter's enchantments at the time of the hit.
function E.player_hit(player, hitter_name, ench, tflp, caps, dir)
	local kb = ench.knockback or 0
	if kb > 0 and dir and tflp >= ((caps or {}).full_punch_interval or 1) then
		local h = vector.normalize(vector.new(dir.x, 0, dir.z))
		player:add_velocity(vector.new(h.x * E.KNOCKBACK_STEP * kb, 2, h.z * E.KNOCKBACK_STEP * kb))
	end
	local f = ench.fire_aspect or 0
	if f > 0 and player:get_hp() > 0 then
		E.ignite(player, E.BURN_PER_LEVEL * f, hitter_name)
	end
end

-- Punch callbacks run even for hits another callback cancels (PvP off,
-- protected areas): the effects wait to see the hit take health.
core.register_on_punchplayer(function(player, hitter, tflp, caps, dir)
	if not is_player(hitter) then
		return
	end
	local ench = E.get(hitter:get_wielded_item())
	if not (ench.knockback or ench.fire_aspect) then
		return
	end
	local name, hitter_name, hp = player:get_player_name(), hitter:get_player_name(), player:get_hp()
	core.after(0, function()
		local p = core.get_player_by_name(name)
		if p and p:get_hp() < hp then
			E.player_hit(p, hitter_name, ench, tflp, caps, dir)
		end
	end)
end)

-- Fire Aspect: the target burns 4 s a level, 1 damage a second. Only the
-- burning are stepped, once a second.
E.BURN_PER_LEVEL = 4
E.burning = {}

local function in_water(obj)
	local pos = obj:get_pos()
	local def = pos and core.registered_nodes[core.get_node(vector.round(pos)).name]
	return def and (def.groups or {}).water
end

-- Light `obj` (a mob or a player) for `seconds`; false for the fire-proof.
function E.ignite(obj, seconds, by)
	if is_player(obj) then
		if FX.get(obj, "fire_resistance") then
			return false
		end
	else
		local ent = obj:get_luaentity()
		if not (ent and ent.health and (ent.fire_damage or 1) ~= 0) then
			return false
		end
	end
	local b = E.burning[obj]
	if b then
		b.left, b.by = math.max(b.left, seconds), by
		return true
	end
	b = { left = seconds, acc = 0, by = by, }
	if type(obj) == "userdata" then
		b.fx = core.add_particlespawner({ amount = 6 * seconds, time = seconds, attached = obj,
			minpos = vector.new(-0.3, 0.2, -0.3), maxpos = vector.new(0.3, 1.6, 0.3),
			minvel = vector.new(0, 0.5, 0), maxvel = vector.new(0, 1.2, 0), minexptime = 0.3, maxexptime = 0.7,
			minsize = 1.5, maxsize = 3, texture = "fire_basic_flame.png", glow = 14, })
	end
	E.burning[obj] = b
	return true
end

local function put_out(obj, b)
	if b.fx then
		core.delete_particlespawner(b.fx)
	end
	E.burning[obj] = nil
end

-- One damage per whole second burnt; drops the dead, the gone and the wet.
local function burn_once(obj, b)
	if not obj:get_pos() or in_water(obj) then
		return false
	end
	if is_player(obj) then
		local hp = obj:get_hp()
		if hp <= 0 or FX.get(obj, "fire_resistance") then
			return false
		end
		obj:set_hp(hp - FX.reduce(obj, 1, "fire"), { type = "set_hp", cause = "cb_fire_aspect", })
		return obj:get_hp() > 0
	end
	local ent = obj:get_luaentity()
	if not (ent and ent.health and ent.health > 0) then
		return false
	end
	ent.health = ent.health - 1
	local by = core.get_player_by_name(b.by or "")
	if ent.check_for_death then
		ent:check_for_death(by and { type = "punch", puncher = by, hot = true, } or { type = "fire", hot = true, })
	end
	return ent.health > 0
end

function E.burn_step(dt)
	for obj, b in pairs(E.burning) do
		b.acc = b.acc + dt
		while b.acc >= 1 and E.burning[obj] do
			b.acc, b.left = b.acc - 1, b.left - 1
			if not burn_once(obj, b) or b.left <= 0 then
				put_out(obj, b)
			end
		end
	end
end

core.register_globalstep(function(dtime)
	if next(E.burning) then
		E.burn_step(dtime)
	end
end)
