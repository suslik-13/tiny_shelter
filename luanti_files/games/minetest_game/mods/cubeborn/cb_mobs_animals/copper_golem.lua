-- Copper golem (spec cycle 4, 8b): a pumpkin on a copper block. The chest
-- next to where it was built (within 2 nodes) is its home: it takes up to 16
-- of one item from there and carries them to a chest within 16 nodes (8 up
-- or down) that already holds that item, or else to an empty one, and brings
-- back what does not fit. Chests protected against its builder are left
-- alone. After 10 trips with nowhere to go it rests for 7 s. It oxidizes a
-- stage every 7 hours of activity; fully oxidized it stands still as a
-- statue until an axe scrapes a stage off. An empty hand makes it drop what
-- it carries. Minecraft's copper chests do not exist here.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.COPPER_GOLEM = "cb_mobs_animals:copper_golem"
local CHEST, TAKE, REACH, RANGE, RISE = "default:chest", 16, 1.5, 16, 8
local OX_TIME, STATUE, REST, TRIES = 7 * 3600, 4, 7, 10
local STAGES = { "cb_mobs_animals_copper_golem.png", "cb_mobs_animals_copper_golem_exposed.png",
	"cb_mobs_animals_copper_golem_weathered.png", "cb_mobs_animals_copper_golem_oxidized.png", }

local function retexture(self)
	self.base_texture = { STAGES[self._stage or 1], }
	self.object:set_properties({ textures = self.base_texture, })
end

local function chest_inv(pos)
	return core.get_node(pos).name == CHEST and core.get_meta(pos):get_inventory() or nil
end

local function may_use(self, pos)
	return not core.is_protected(pos, self.owner or "")
end

-- Up to 16 of the first item in the home chest go in its hands.
function A.golem_take(self)
	local home = self._home
	local inv = home and may_use(self, home) and chest_inv(home)
	if self._carry or not inv then
		return false
	end
	for i, stack in ipairs(inv:get_list("main") or {}) do
		if not stack:is_empty() then
			local taken = stack:take_item(TAKE)
			inv:set_stack("main", i, stack)
			self._carry = taken:to_string()
			A.hold(self, self._carry)
			return true
		end
	end
	return false
end

-- The nearest usable chest holding the carried item, else the nearest empty one.
function A.golem_target(self)
	local pos = self.object:get_pos()
	local name = self._carry and ItemStack(self._carry):get_name()
	if not (pos and name) then
		return nil
	end
	local r = vector.new(RANGE, RISE, RANGE)
	local same, empty, ds, de
	for _, p in ipairs(core.find_nodes_in_area(vector.subtract(pos, r), vector.add(pos, r), { CHEST, })) do
		if not (self._home and vector.equals(p, self._home)) and may_use(self, p) then
			local inv = chest_inv(p)
			local d = vector.distance(pos, p)
			if inv:contains_item("main", name) and inv:room_for_item("main", ItemStack(name)) then
				if not ds or d < ds then
					same, ds = p, d
				end
			elseif inv:is_empty("main") and (not de or d < de) then
				empty, de = p, d
			end
		end
	end
	return same or empty
end

-- Puts what it carries in the chest at pos; keeps what does not fit.
function A.golem_put(self, pos)
	local inv = self._carry and may_use(self, pos) and chest_inv(pos)
	if not inv then
		return false
	end
	local left = inv:add_item("main", ItemStack(self._carry))
	self._carry = not left:is_empty() and left:to_string() or nil
	A.hold(self, self._carry)
	self:set_animation("interact", true)
	core.sound_play("cb_mobs_animals_copper_golem_put", { pos = pos, gain = 0.6, }, true)
	return true
end

function A.golem_oxidize(self)
	self._stage = math.min(STATUE, (self._stage or 1) + 1)
	retexture(self)
end

function A.golem_scrape(self, clicker)
	local stack = clicker:get_wielded_item()
	if core.get_item_group(stack:get_name(), "axe") == 0 or (self._stage or 1) <= 1 then
		return false
	end
	self._stage, self._ox_t = self._stage - 1, 0
	retexture(self)
	if not core.is_creative_enabled(clicker:get_player_name()) then
		stack:add_wear(65535 / 250)
		clicker:set_wielded_item(stack)
	end
	core.sound_play("cb_mobs_animals_shear", { pos = self.object:get_pos(), pitch = 0.7, }, true)
	return true
end

local function walk_to(self, pos)
	local at = self.object:get_pos()
	if vector.distance(vector.new(at.x, pos.y, at.z), pos) <= REACH then
		self:set_velocity(0)
		return true
	end
	self:yaw_to_pos(pos)
	self:set_velocity(self.walk_velocity)
	self:set_animation(self._carry and "carry" or "walk")
	return false
end

function A.golem_tick(self, dtime)
	self._ox_t = (self._ox_t or 0) + dtime
	if self._ox_t >= OX_TIME then
		self._ox_t = 0
		A.golem_oxidize(self)
	end
	if (self._stage or 1) >= STATUE then
		local v = self.object:get_velocity() or vector.zero()
		self.object:set_velocity({ x = 0, y = v.y, z = 0, })
		self:set_animation("stand")
		return false
	end
	if self._rest then
		self._rest = self._rest - dtime
		if self._rest <= 0 then
			self._rest = nil
		end
		return true
	end
	if self._goto then
		self._goto_t = (self._goto_t or 0) + dtime
		if walk_to(self, self._goto) then
			A.golem_put(self, self._goto)
			self._goto, self._goto_t = nil, nil
		elseif self._goto_t > 30 then
			self._goto, self._goto_t = nil, nil
		end
		return false
	end
	self._work_t = (self._work_t or 0) + dtime
	if self._work_t < 3 then
		return true
	end
	self._work_t = 0
	if not self._carry then
		A.golem_take(self)
		return true
	end
	local target = A.golem_target(self) or (self._fails or 0) >= TRIES and self._home
	if target then
		self._goto, self._fails = target, target == self._home and 0 or self._fails
		return false
	end
	self._fails = (self._fails or 0) + 1
	if self._fails >= TRIES then
		self._rest = REST
	end
	return true
end

mobs:register_mob(A.COPPER_GOLEM, {
	type = "npc", passive = true, attack_players = false, attack_npcs = false, hp_min = 12, hp_max = 12, armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 0.98, 0.3, },
	visual = "mesh", mesh = "cb_mobs_animals_copper_golem.b3d", visual_size = { x = 1, y = 1, },
	textures = { { STAGES[1], }, },
	makes_footstep_sound = true, walk_velocity = 1, run_velocity = 1.5, jump = true, view_range = 8,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = false,
	drops = { { name = "default:copper_ingot", chance = 1, min = 1, max = 3, }, },
	sounds = { damage = "cb_mobs_animals_copper_golem_hurt", death = "cb_mobs_animals_copper_golem_death",
		distance = 16, },
	animation = { speed_normal = 30, stand_start = 0, stand_end = 20, stand_speed = 15, walk_start = 21, walk_end = 41,
		run_start = 21, run_end = 41, carry_start = 42, carry_end = 62, interact_start = 63, interact_end = 93,
		interact_speed = 10, interact_loop = false, },
	do_custom = function(self, dtime)
		return A.golem_tick(self, dtime)
	end,
	on_rightclick = function(self, clicker)
		if not (clicker and clicker:is_player()) or A.golem_scrape(self, clicker) then
			return
		end
		if self._carry and clicker:get_wielded_item():is_empty() then
			core.add_item(self.object:get_pos(), self._carry)
			self._carry, self._goto = nil, nil
			A.hold(self, nil)
		end
	end,
	on_die = function(self)
		if self._carry then
			A.drop_held(self)
		end
	end,
	after_activate = function(self)
		self._held, self._held_bone, self._held_at = self._carry, "wield_item", { x = 0, y = 0, z = 0, }
		retexture(self)
		A.show_held(self)
	end,
})
mobs:register_egg(A.COPPER_GOLEM, S("Copper Golem"), "default_copper_block.png", 1)

A.register_golem(A.COPPER_GOLEM, { "default:copperblock", }, function(e, who, base)
	e.owner, e.tamed, e.static_save, e._stage = who, true, true, 1
	e._home = core.find_node_near(base, 2, { CHEST, }, true)
	e._held_bone, e._held_at = "wield_item", { x = 0, y = 0, z = 0, }
end)
