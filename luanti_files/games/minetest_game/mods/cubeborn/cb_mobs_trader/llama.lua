-- Llamas (spec cycle 3, 6.2). A trader llama (_tid, _despawn) keeps within
-- FOLLOW of its trader, on a lead when the leads mod is there, and spits at
-- whoever hits it or its trader (a mobs_redo arrow: an entity, never an
-- item, 1 damage). Taking the lead off (or, without leads, right-clicking it
-- empty-handed near its trader) makes it an ordinary llama that stays.
local S, TR = cb_mobs_trader.S, cb_mobs_trader
local V = cb_mobs_village
-- mobs_redo drops untamed animals on unload while lifetimer < 20000: trader
-- llamas leave by _despawn, unbound ones stay.
TR.FOLLOW, TR.SPIT_DAMAGE, TR.LOOK_EVERY, TR.KEEP = 6, 1, 5, 20001
TR.COLOURS = { "brown", "creamy", "gray", "white", }
-- MTG wool colours -> Mineclonia's llama decor files
TR.DECOR = { white = "white", grey = "light_gray", dark_grey = "gray", black = "black", violet = "purple",
	blue = "blue", cyan = "cyan", dark_green = "green", green = "lime", yellow = "yellow", brown = "brown",
	orange = "orange", red = "red", magenta = "magenta", pink = "pink", }
local traders = setmetatable({}, { __mode = "kv", }) -- llama -> trader luaentity

function TR.retexture(self)
	if not self._colour then
		self._colour = TR.COLOURS[math.random(#TR.COLOURS)]
	end
	local coat = "cb_mobs_trader_llama_" .. self._colour .. ".png"
	local decor = (self._carpet and TR.DECOR[self._carpet] and "cb_mobs_trader_llama_decor_" .. TR.DECOR[self._carpet] .. ".png")
		or (self._tid and "cb_mobs_trader_llama_decor_trader.png") or "blank.png"
	self.base_texture = { self._chest and coat or "blank.png", decor, coat, }
	self.object:set_properties({ textures = self.base_texture, })
end

function TR.trader_of(self)
	if not self._tid then
		return nil
	end
	local t = traders[self]
	if t and t.object and t.object:get_pos() and t._tid == self._tid then
		return t
	end
	traders[self] = nil
	local now = core.get_gametime()
	if (self._look_t or 0) > now then
		return nil
	end
	self._look_t = now + TR.LOOK_EVERY
	for _, obj in ipairs(core.get_objects_inside_radius(self.object:get_pos(), 48)) do
		local e = obj:get_luaentity()
		if e and e.name == TR.TRADER and e._tid == self._tid then
			traders[self] = e
			return e
		end
	end
end

function TR.bind(self, trader)
	self._tid, self._despawn = trader._tid, trader._despawn
	traders[self] = trader
	TR.retexture(self)
	if rawget(_G, "leads") and leads.add_lead then
		leads.add_lead(trader.object, self.object, "leads:lead")
	end
end

function TR.unbind(self)
	self._tid, self._despawn = nil, nil
	traders[self] = nil
end

function TR.alert(target, attacker)
	if not attacker then
		return
	end
	local tid = target._tid
	local pos = target.object:get_pos()
	if not tid or not pos then
		return
	end
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 16)) do
		local e = obj:get_luaentity()
		if e and e.name == TR.LLAMA and e._tid == tid and e.do_attack then
			e:do_attack(attacker)
		end
	end
end

local function hit(self, obj)
	local e = obj.get_luaentity and obj:get_luaentity()
	if e and (e.name == TR.LLAMA or e.name == TR.TRADER) then
		return
	end
	obj:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = TR.SPIT_DAMAGE, }, }, nil)
end

mobs:register_arrow("cb_mobs_trader:spit", {
	visual = "sprite",
	visual_size = { x = 0.3, y = 0.3, },
	textures = { "cb_mobs_trader_spit.png", },
	velocity = 12,
	hit_player = hit,
	hit_mob = hit,
	hit_node = function() end,
})

function TR.llama_step(self, dtime)
	self._tick = (self._tick or 0) + dtime
	if self._tick < 0.5 then
		return not self._following
	end
	self._tick = 0
	self.lifetimer = TR.KEEP
	if self._despawn and core.get_gametime() >= self._despawn and not TR.trader_of(self) then
		self.object:remove()
		return false
	end
	if self.driver then
		TR.rider_step(self)
	end
	TR.gear_step(self)
	if self.state == "attack" then
		self._following = nil
		return true
	end
	local t = TR.trader_of(self)
	local pos = self.object:get_pos()
	local tp = t and t.object:get_pos()
	if tp and vector.distance(pos, tp) > TR.FOLLOW then
		V.face(self, tp)
		self:set_velocity(self.walk_velocity * 1.5)
		self:set_animation("walk")
		self._following = true
		return false
	end
	if TR.caravan_step(self) then
		self._following = true
		return false
	end
	self._following = nil
	return true
end

mobs:register_mob(TR.LLAMA, cb_core.fixed_head({
	type = "animal",
	passive = false,
	attack_type = "shoot",
	arrow = "cb_mobs_trader:spit",
	shoot_interval = 2,
	shoot_offset = 1.6,
	attack_animals = false,
	attack_npcs = false,
	hp_min = 15,
	hp_max = 30,
	armor = 100,
	collisionbox = { -0.45, 0, -0.45, 0.45, 1.87, 0.45, },
	visual = "mesh",
	mesh = "cb_mobs_trader_llama.b3d",
	textures = { { "blank.png", "blank.png", "cb_mobs_trader_llama_brown.png", }, },
	makes_footstep_sound = true,
	stepheight = 1.1,
	walk_velocity = 1,
	run_velocity = 2,
	walk_chance = 30,
	jump = true,
	view_range = 16,
	fear_height = 3,
	floats = 1,
	water_damage = 0,
	lava_damage = 8,
	drops = core.registered_items["mobs:leather"] and { { name = "mobs:leather", chance = 1, min = 0, max = 2, }, } or {},
	follow = { "farming:straw", "farming:wheat", },
	sounds = { random = "cb_mobs_trader_llama", shoot_attack = "cb_mobs_trader_llama_spit", damage = "cb_mobs_trader_llama_hurt",
		death = "cb_mobs_trader_llama_death", distance = 16, },
	animation = { stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40, walk_speed = 25, run_start = 0,
		run_end = 40, run_speed = 30, },
	do_custom = function(self, dtime)
		return TR.llama_step(self, dtime)
	end,
	after_activate = function(self)
		self._following, self.lifetimer = nil, TR.KEEP
		if self._despawn and core.get_gametime() >= self._despawn then
			self.object:remove()
			return
		end
		self._strength = self._strength or TR.new_strength()
		TR.retexture(self)
	end,
	on_breed = function(self, other)
		return TR.on_breed(self, other)
	end,
	on_grown = function(self)
		TR.on_grown(self)
	end,
	on_die = function(self)
		if self.driver then
			TR.dismount(self)
		end
		TR.drop_gear(self)
	end,
	do_punch = function(self, hitter)
		TR.alert(self, hitter)
		return true
	end,
	on_rightclick = function(self, clicker)
		TR.click(self, clicker)
	end,
	_leads_lead_remove = function(self, lead, is_leader)
		if is_leader or not self._tid then
			return
		end
		local leader = lead and lead.leader
		local le = leader and leader.get_luaentity and leader:get_luaentity()
		if not (le and le.name == TR.TRADER and le._tid == self._tid) then
			return
		end
		local pos = self.object:get_pos()
		for _, obj in ipairs(pos and core.get_objects_inside_radius(pos, 8) or {}) do
			if obj:is_player() then
				TR.unbind(self)
				return
			end
		end
	end,
}, 11))

mobs:register_egg(TR.LLAMA, S("Llama"), "cb_mobs_trader_llama_creamy.png", 1)
