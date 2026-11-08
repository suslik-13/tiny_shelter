-- Iron golem (spec cycle 2, 3.5): guards villages. Attacks monsters within 16
-- and the player who hit a villager; its blow does 7-21 and throws the target
-- up. Players build one from 4 iron blocks in a T and a pumpkin on top.
local S = cb_mobs_village.S
local V = cb_mobs_village
local NAME = "cb_mobs_village:iron_golem"
local IRON = "default:steelblock"
-- farming:pumpkin is an alias: the placed block is farming:pumpkin_8
V.PUMPKINS = { "farming:pumpkin_8", "farming:jackolantern", "farming:jackolantern_on", }

-- A village golem keeps near the bell (BACKLOG 19): the village respawn
-- counts golems around it, and one that wandered off was replaced again and
-- again. _home = the bell, false = free (built by a player); golems from
-- before this rule find their village on the first check.
V.GOLEM_LEASH, V.GOLEM_HOME_EVERY = 16, 2

-- Turns the golem towards its bell when it is too far; true if it did.
function V.golem_go_home(self)
	local pos = self.object:get_pos()
	if not pos then
		return false
	end
	if self._home == nil then
		local v = V.village_at and V.village_at(pos)
		self._home = v and v.bell or false
	end
	if not self._home or self.attack or self.state == "attack"
		or vector.distance(pos, self._home) <= V.GOLEM_LEASH then
		return false
	end
	V.face(self, self._home)
	self:set_velocity(self.walk_velocity)
	self.state = "walk"
	self:set_animation("walk")
	return true
end

mobs:register_mob(NAME, cb_core.fixed_head({
	type = "npc",
	passive = false,
	attack_type = "dogfight",
	attack_monsters = true,
	attack_players = false,
	attack_npcs = false,
	attack_animals = false,
	reach = 3,
	damage = 14,
	hp_min = 100,
	hp_max = 100,
	armor = 60,
	knock_back = false,
	collisionbox = { -0.7, -0.01, -0.7, 0.7, 2.69, 0.7, },
	visual = "mesh",
	mesh = "cb_mobs_village_iron_golem.b3d",
	visual_size = { x = 3, y = 3, },
	textures = { { "cb_mobs_village_iron_golem.png", "blank.png", }, },
	makes_footstep_sound = true,
	stepheight = 1.1,
	walk_velocity = 0.6,
	run_velocity = 1.2,
	view_range = 16,
	fall_damage = false,
	water_damage = 0,
	lava_damage = 4,
	sounds = { damage = "cb_mobs_village_iron_golem_hurt", attack = "cb_mobs_village_iron_golem_attack",
		death = "cb_mobs_village_iron_golem_death", distance = 16, },
	animation = { speed_normal = 25, stand_start = 0, stand_end = 0, walk_start = 40, walk_end = 80, run_start = 40,
		run_end = 80, punch_start = 80, punch_end = 90, punch_speed = 15, },
	drops = {
		{ name = "default:steel_ingot", chance = 1, min = 3, max = 5, },
		{ name = "flowers:rose", chance = 1, min = 0, max = 2, },
	},
	do_custom = function(self, dtime)
		self._home_t = (self._home_t or 0) + dtime
		if self._home_t >= V.GOLEM_HOME_EVERY then
			self._home_t = 0
			V.golem_go_home(self)
		end
		return true
	end,
	-- mobs_redo calls self:custom_attack(self, p); true = do the usual punch.
	custom_attack = function(self)
		self.damage = math.random(7, 21)
		if self.attack and self.attack.add_velocity then
			self.attack:add_velocity(vector.new(0, 6, 0))
		end
		return true
	end,
}, 3.38))

mobs:register_egg(NAME, S("Iron Golem"), "default_steel_block.png", 1)

function V.alert_golems(villager, hitter)
	if not (hitter and hitter.is_player and hitter:is_player()) then
		return
	end
	for _, obj in ipairs(core.get_objects_inside_radius(villager.object:get_pos(), 16)) do
		local e = obj:get_luaentity()
		if e and e.name == NAME then
			e:do_attack(hitter)
		end
	end
end
table.insert(V.punch_hooks, V.alert_golems)

function V.golem_shape(head)
	local body, legs = vector.offset(head, 0, -1, 0), vector.offset(head, 0, -2, 0)
	if core.get_node(body).name ~= IRON or core.get_node(legs).name ~= IRON then
		return nil
	end
	for _, d in ipairs({ { 1, 0, }, { 0, 1, }, }) do
		local a, b = vector.offset(body, d[1], 0, d[2]), vector.offset(body, -d[1], 0, -d[2])
		if core.get_node(a).name == IRON and core.get_node(b).name == IRON then
			return { head, body, legs, a, b, }
		end
	end
end

core.register_on_placenode(function(pos, newnode, placer)
	if table.indexof(V.PUMPKINS, newnode.name) < 0 then
		return
	end
	local nodes = V.golem_shape(pos)
	if not nodes then
		return
	end
	local name = placer and placer.is_player and placer:is_player() and placer:get_player_name() or ""
	for _, p in ipairs(nodes) do
		if core.is_protected(p, name) then
			return
		end
	end
	for _, p in ipairs(nodes) do
		core.remove_node(p)
	end
	local obj = core.add_entity(vector.offset(nodes[3], 0, 0.5, 0), NAME)
	local e = obj and obj:get_luaentity()
	if e then
		e._home = false
	end
end)
