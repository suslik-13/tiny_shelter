-- Ordinary llamas (spec cycle 3, 6.3), after Mineclonia's horse and llama:
-- a rider on a wild llama is thrown off until a roll of 1-MAX_TEMPER comes
-- under its temper + 1 (one roll per TAME_EVERY half-second ticks; +5 temper
-- per throw, wheat +3, a hay bale +6). Riding has no steering; sneak gets
-- off. Tamed adults fed a hay bale breed (mobs_redo: 5 min pause, the young
-- grow in GROW s). Strength 1-5 sets the chest size.
local S, TR = cb_mobs_trader.S, cb_mobs_trader
TR.MAX_TEMPER, TR.TAME_EVERY, TR.GROW = 30, 5, 1200
TR.FOOD = {
	["farming:wheat"] = { heal = 2, temper = 3, },
	["farming:straw"] = { heal = 10, temper = 6, breed = true, },
}
TR.ATTACH_AT = { x = 0, y = 12.7, z = -5, }

-- Tests swap these: the bench's fake players cannot be attached.
function TR.attach(ent, player)
	mobs.attach(ent, player)
end

function TR.detach(player)
	mobs.detach(player)
end

function TR.new_strength(rand)
	rand = rand or math.random
	local bonus = rand() < 0.04 and 5 or 3
	return 1 + math.floor(rand() * bonus)
end

function TR.child_strength(s1, s2, rand)
	rand = rand or math.random
	local s = 1 + math.floor(rand() * math.max(s1, s2))
	if s < 5 and rand() < 0.05 then
		s = s + 1
	end
	return s
end

local function take_one(clicker, stack)
	if not core.is_creative_enabled(clicker:get_player_name()) then
		stack:take_item()
		clicker:set_wielded_item(stack)
	end
end

function TR.feed(self, clicker, stack)
	local food = TR.FOOD[stack:get_name()]
	if not food then
		return false
	end
	local used = false
	local maxhp = self.object:get_properties().hp_max
	if self.health < maxhp then
		self.health = math.min(maxhp, self.health + food.heal)
		self.object:set_hp(self.health)
		used = true
	end
	if self.child then
		self.hornytimer = math.floor(self.hornytimer + (TR.GROW - self.hornytimer) * 0.1)
		used = true
	elseif not self.tamed then
		if (self._temper or 0) < TR.MAX_TEMPER then
			self._temper = math.min(TR.MAX_TEMPER, (self._temper or 0) + food.temper)
			used = true
		end
	elseif food.breed and not self.horny and self.hornytimer == 0 then
		self.horny = true
		used = true
	end
	if used then
		take_one(clicker, stack)
	end
	return true
end

function TR.mount(self, player)
	if self.driver or self.child or self._tid then
		return false
	end
	self.driver_attach_at = TR.ATTACH_AT
	TR.attach(self, player)
	return true
end

function TR.dismount(self)
	local d = self.driver
	self.driver = nil
	if d then
		TR.detach(d)
	end
end

-- One taming roll with the rider on: true = tamed, false = thrown off.
function TR.tame_roll(self, rand)
	rand = rand or math.random
	local name = self.driver and self.driver:get_player_name()
	if not name then
		return false
	end
	if rand(1, TR.MAX_TEMPER) <= (self._temper or 0) + 1 then
		self.tamed, self.owner, self._temper = true, name, nil
		core.chat_send_player(name, S("The llama is tamed."))
		return true
	end
	self._temper = math.min(TR.MAX_TEMPER, (self._temper or 0) + 5)
	TR.dismount(self)
	return false
end

-- From the llama's half-second step while someone sits on it.
function TR.rider_step(self)
	local ctrl = self.driver:get_player_control()
	if ctrl and ctrl.sneak then
		TR.dismount(self)
	elseif not self.tamed and math.random(TR.TAME_EVERY) == 1 then
		TR.tame_roll(self)
	end
end

local function half(box)
	return { box[1] * 0.5, box[2] * 0.5, box[3] * 0.5, box[4] * 0.5, box[5] * 0.5, box[6] * 0.5, }
end

-- mobs_redo's breed calls this 5 s after two llamas meet; mobs:add_mob does
-- not make mobs without a spawn rule, so the young one is added here.
function TR.on_breed(self, other)
	local pos = self.object:get_pos()
	local obj = pos and core.add_entity(pos, TR.LLAMA)
	local young = obj and obj:get_luaentity()
	if young then
		local parent = math.random(2) == 1 and self or other
		young._colour = parent._colour
		young._strength = TR.child_strength(self._strength or 1, other._strength or 1)
		young.child, young.hornytimer = true, 0
		obj:set_properties({
			visual_size = { x = young.base_size.x * 0.5, y = young.base_size.y * 0.5, },
			collisionbox = half(young.base_colbox),
			selectionbox = half(young.base_selbox),
		})
		TR.retexture(young)
	end
	return false
end

function TR.on_grown(self)
	TR.retexture(self)
	local pos = self.object:get_pos()
	if pos then
		self.object:set_pos(vector.offset(pos, 0, 0.1, 0))
		self.object:set_velocity(vector.new(0, 2, 0))
	end
end

-- Right-click: food, then (Task 2) gear, then an empty hand mounts.
function TR.click(self, clicker)
	if not (clicker and clicker:is_player()) then
		return
	end
	local stack = clicker:get_wielded_item()
	if TR.feed(self, clicker, stack) then
		return
	end
	if self._tid then
		if not rawget(_G, "leads") and stack:is_empty() and TR.trader_of(self) then
			TR.unbind(self)
		end
		return
	end
	if TR.gear_click and TR.gear_click(self, clicker, stack) then
		return
	end
	if stack:is_empty() then
		TR.mount(self, clicker)
	end
end
