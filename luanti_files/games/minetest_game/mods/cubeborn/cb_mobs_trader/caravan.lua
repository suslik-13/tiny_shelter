-- Caravans (spec cycle 3, 6.3): a llama a player leads on a lead (leads
-- mod) heads one; free tamed adult llamas within JOIN hook onto its end, up
-- to CARAVAN_MAX llamas, and keep GAP behind the one in front. Links live
-- only in memory (weak tables). A link breaks when the head is no longer
-- led, the one in front is farther than BREAK or gone, or the llama gets a
-- rider. Each active tamed llama looks for a caravan once a second.
local TR = cb_mobs_trader
local V = cb_mobs_village
TR.JOIN, TR.CARAVAN_MAX, TR.GAP, TR.BREAK = 8, 10, 2.5, 16
local front = setmetatable({}, { __mode = "kv", })
local back = setmetatable({}, { __mode = "kv", })
local look_t = setmetatable({}, { __mode = "k", })

local function alive(e)
	return e and e.object and e.object:get_pos() ~= nil
end

function TR.led_by_player(self)
	if not rawget(_G, "leads") or not leads.leads_by_connector or not leads.leads_by_connector[self.object] then
		return false
	end
	for lead in leads.find_connected_leads(self.object, false, true) do
		local le = lead:get_luaentity()
		if le and le.leader and le.leader.is_player and le.leader:is_player() then
			return true
		end
	end
	return false
end

function TR.front_of(self)
	local f = front[self]
	return alive(f) and f or nil
end

function TR.head_of(self)
	local e, n = self, 0
	while TR.front_of(e) and n <= TR.CARAVAN_MAX do
		e, n = front[e], n + 1
	end
	return e
end

function TR.caravan_len(head)
	local e, n = head, 1
	while alive(back[e]) and front[back[e]] == e and n <= TR.CARAVAN_MAX do
		e, n = back[e], n + 1
	end
	return n
end

function TR.leave_caravan(self)
	local f = front[self]
	if f and back[f] == self then
		back[f] = nil
	end
	front[self] = nil
end

local function try_join(self)
	local now = core.get_us_time()
	if (look_t[self] or 0) > now then
		return
	end
	look_t[self] = now + 1000000
	for _, obj in ipairs(core.get_objects_inside_radius(self.object:get_pos(), TR.JOIN)) do
		local e = obj:get_luaentity()
		-- only onto a caravan whose head is led: a breaking one would
		-- otherwise catch its own falling-off llamas again
		if e and e ~= self and e.name == TR.LLAMA and not alive(back[e]) then
			local head = TR.head_of(e)
			if head ~= self and TR.led_by_player(head) and TR.caravan_len(head) < TR.CARAVAN_MAX then
				front[self], back[e] = e, self
				return
			end
		end
	end
end

-- From the llama's half-second step; true while it walks after the one in front.
function TR.caravan_step(self)
	if front[self] and not TR.front_of(self) then
		TR.leave_caravan(self)
	end
	local f = TR.front_of(self)
	if not f then
		if self.tamed and not self.child and not self.driver and not self._tid
				and not alive(back[self]) and not TR.led_by_player(self) then
			try_join(self)
		end
		return false
	end
	local pos, fp = self.object:get_pos(), f.object:get_pos()
	if self.driver or vector.distance(pos, fp) > TR.BREAK or not TR.led_by_player(TR.head_of(self)) then
		TR.leave_caravan(self)
		return false
	end
	if vector.distance(pos, fp) > TR.GAP + 0.5 then
		V.face(self, fp)
		self:set_velocity(self.walk_velocity * 2)
		self:set_animation("walk")
		return true
	end
	self.object:set_velocity(vector.new(0, self.object:get_velocity().y, 0))
	self:set_animation("stand")
	return true
end
