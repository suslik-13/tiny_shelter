-- Wandering trader (spec cycle 3, 6.1): Bedrock's wandering trader offers
-- (one tier, own max_uses, no restock) in the villagers' trade window;
-- invisible at night, runs from monsters, leaves after 40-60 minutes with
-- the llamas still bound to it. Behaviour every 0.5 s, active traders only.
local S, TR = cb_mobs_trader.S, cb_mobs_trader
local V = cb_mobs_village
TR.TRADER, TR.LLAMA = "cb_mobs_trader:trader", "cb_mobs_trader:llama"
TR.LIFE_MIN, TR.LIFE_MAX, TR.FLEE_R = 2400, 3600, 8

function TR.setup(ent, rand)
	rand = rand or math.random
	ent._tid = tostring(math.random(1, 2147483646))
	ent._despawn = core.get_gametime() + TR.LIFE_MIN + math.floor(rand() * (TR.LIFE_MAX - TR.LIFE_MIN))
	V.trading.init(ent, "wandering_trader", function(a, b)
		return math.random(a, b)
	end)
	TR.store:set_int("until", ent._despawn)
end

function TR.leave(ent)
	local pos = ent.object:get_pos()
	if pos and ent._tid then
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 48)) do
			local e = obj:get_luaentity()
			if e and e.name == TR.LLAMA and e._tid == ent._tid then
				obj:remove()
			end
		end
	end
	if ent._trading then
		V.trade_ui.close(ent._trading)
	end
	if TR.store:get_int("until") == (ent._despawn or -1) then
		TR.store:set_int("until", 0)
	end
	ent.object:remove()
end

local function monster_near(self)
	local pos = self.object:get_pos()
	for _, obj in ipairs(core.get_objects_inside_radius(pos, TR.FLEE_R)) do
		local e = obj:get_luaentity()
		if e and e._cmi_is_mob and e.type == "monster" then
			return obj:get_pos()
		end
	end
end

function TR.step(self, dtime)
	self._tick = (self._tick or 0) + dtime
	if self._tick < 0.5 then
		return not (self._fleeing or self._trading)
	end
	self._tick = 0
	if cb_core.doors then
		cb_core.doors.bump(self, 0.5)
	end
	if self._despawn and core.get_gametime() >= self._despawn then
		TR.leave(self)
		return false
	end
	local night = V.night()
	if night ~= (self._invis == true) then
		self._invis = night or nil
		self.object:set_properties({ is_visible = not night, })
		core.sound_play("cb_mobs_village_drink", { object = self.object, max_hear_distance = 10, }, true)
	end
	local m = monster_near(self)
	if m then
		local pos = self.object:get_pos()
		V.face(self, vector.add(pos, vector.subtract(pos, m)))
		self:set_velocity(self.run_velocity)
		self:set_animation("walk")
		self._fleeing = true
		return false
	end
	self._fleeing = nil
	if self._trading then
		local s = V.trade_ui.sessions[self._trading]
		local player = s and s.ent == self and core.get_player_by_name(self._trading)
		if player then
			V.face(self, player:get_pos())
		end
		self.object:set_velocity(vector.zero())
		self:set_animation("stand")
		return false
	end
	return true
end

mobs:register_mob(TR.TRADER, {
	type = "npc",
	passive = true,
	hp_min = 20,
	hp_max = 20,
	armor = 100,
	collisionbox = V.BOX,
	visual = "mesh",
	mesh = "cb_mobs_village_villager.b3d",
	textures = { { "cb_mobs_trader_trader.png", "blank.png", "blank.png", }, },
	makes_footstep_sound = true,
	stepheight = 1.1,
	walk_velocity = 1,
	run_velocity = 2.5,
	walk_chance = 40,
	jump = true,
	view_range = 12,
	fear_height = 3,
	floats = 1,
	water_damage = 0,
	lava_damage = 8,
	drops = {},
	sounds = { random = "cb_mobs_village_villager", damage = "cb_mobs_village_villager_hurt",
		death = "cb_mobs_village_villager_death", distance = 10, },
	animation = { speed_normal = 35, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40, run_start = 0,
		run_end = 40, },
	do_custom = function(self, dtime)
		return TR.step(self, dtime)
	end,
	after_activate = function(self)
		self._trading, self._fleeing = nil, nil
		if self._despawn and core.get_gametime() >= self._despawn then
			TR.leave(self)
			return
		end
		if self._invis then
			self.object:set_properties({ is_visible = false, })
		end
		V.trading.sanitize(self)
	end,
	do_punch = function(self, hitter)
		cb_mobs_trader.alert(self, hitter)
		return true
	end,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() and self._offers then
			V.trade_ui.open(self, clicker)
		end
	end,
	on_die = function(self)
		if TR.store:get_int("until") == (self._despawn or -1) then
			TR.store:set_int("until", 0)
		end
	end,
})

mobs:register_egg(TR.TRADER, S("Wandering Trader"), "cb_mobs_trader_trader.png", 1)
