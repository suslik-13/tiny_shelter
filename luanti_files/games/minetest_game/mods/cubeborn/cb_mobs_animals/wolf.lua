-- Wolf (spec cycle 4, 8b): wild wolves are neutral (they fight back as a
-- pack) and hunt skeletons; a bone tames one with a 1 in 3 chance. A tamed
-- wolf becomes a mobs_redo helper ("npc"): it follows its owner, sits and
-- stands up on the owner's right-click (with anything but food, armour or
-- shears; a name tag and a protection rune go to cb_core), fights monsters (not
-- creepers), defends its owner (also from archers and from monsters closing
-- in on the owner) and comes to them from afar; creeper blasts hurt it less. Raw meat heals
-- and breeds it; wolf armour (armadillo scutes) takes the damage for it.
local S = cb_mobs_animals.S
local A = cb_mobs_animals
A.WOLF = "cb_mobs_animals:wolf"
local BONE, SHEARS = "bonemeal:bone", "mobs:shears"
local DEFEND_RANGE, CALL_RANGE = 16, 24
A.WOLF_BLAST_FACTOR = 0.4
local SKELETONS = { "mobs_skeletons:skeleton", "mobs_skeletons:skeleton_archer", "mobs_skeletons:skeleton_archer_dark",
	"cb_mobs_overworld:stray", "cb_mobs_dim:wither_skeleton", }

-- biome name words -> variant; first match wins
local VARIANTS = {
	{ "savanna", "spotted", }, { "snow", "snowy", }, { "ice", "snowy", }, { "tundra", "snowy", },
	{ "taiga", "ashen", }, { "coniferous", "ashen", }, { "rainforest", "rusty", }, { "jungle", "rusty", },
	{ "deciduous", "woods", }, { "grassland", "woods", },
}

function A.wolf_variant(biome)
	for _, v in ipairs(VARIANTS) do
		if biome:find(v[1], 1, true) then
			return v[2]
		end
	end
	return "pale"
end

local function tex(self, kind)
	local v = self._variant ~= "pale" and "_" .. self._variant or ""
	return "cb_mobs_animals_wolf" .. v .. (kind and "_" .. kind or "") .. ".png"
end

local function retexture(self)
	local base
	if self.tamed then
		base = tex(self, "tame") .. "^(cb_mobs_animals_wolf_collar.png^[colorize:#FF0000:192)"
	else
		base = tex(self, self._angry and "angry")
	end
	self.base_texture = { base, self._armor and "cb_mobs_animals_wolf_armor_layer.png" or "blank.png", "blank.png", }
	self.object:set_properties({ textures = self.base_texture, })
end

local function take_one(clicker, stack)
	if not core.is_creative_enabled(clicker:get_player_name()) then
		stack:take_item()
		clicker:set_wielded_item(stack)
	end
end

function A.tame_wolf(self, owner)
	self.tamed, self.owner, self.type = true, owner, "npc"
	self.attack_monsters, self.attack_animals, self.specific_attack = true, false, false
	self.attack_ignore = { "cb_mobs_overworld:creeper", }
	self.owner_loyal, self.order, self.state, self.attack = true, "follow", "stand", nil
	self.static_save = true
	self.hp_max = 20
	self.health = 20
	self.object:set_properties({ hp_max = 20, })
	self.object:set_hp(20)
	self._angry = nil
	retexture(self)
end

-- The owner's click (with an item no other click uses): sit down or stand up.
function A.wolf_order(self, clicker)
	if not (self.tamed and self.owner == clicker:get_player_name()) then
		return false
	end
	if self.order == "stand" then
		self.order = "follow"
		self:set_animation("stand", true)
	else
		self.order, self.state, self.attack, self.following = "stand", "stand", nil, nil
		self:set_velocity(0)
		self:set_animation("sit", true)
	end
	return true
end

-- A mobs_redo arrow stands for whoever shot it (the arrow keeps the
-- shooter's object as text).
local function shooter_of(arrow)
	local e = arrow and arrow:get_luaentity()
	if not (e and e._is_arrow and e.owner_id) then
		return arrow
	end
	local pos = arrow:get_pos()
	for _, obj in ipairs(pos and core.get_objects_inside_radius(pos, 32) or {}) do
		if tostring(obj) == e.owner_id then
			return obj
		end
	end
	return nil
end
A.shooter_of = shooter_of

-- Someone hit the owner: the owner's standing wolves nearby attack them.
function A.defend(owner, hitter)
	hitter = shooter_of(hitter)
	if not hitter or (hitter:is_player() and hitter:get_player_name() == owner) then
		return 0
	end
	local p = core.get_player_by_name(owner)
	local pos = (p and p:get_pos()) or hitter:get_pos()
	if not pos then
		return 0
	end
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, DEFEND_RANGE)) do
		local e = obj:get_luaentity()
		if e and e.name == A.WOLF and e.tamed and e.owner == owner and e.order ~= "stand" and obj ~= hitter
			and e.health > 0 then
			e:do_attack(hitter, true)
			n = n + 1
		end
	end
	return n
end

core.register_on_punchplayer(function(player, hitter)
	A.defend(player:get_player_name(), hitter)
end)

local function drop_armor(self)
	if not self._armor then
		return
	end
	local armor = ItemStack(A.WOLF_ARMOR)
	armor:set_wear(math.min(65534, math.floor(self._armor / A.ARMOR_LIFE * 65535)))
	core.add_item(self.object:get_pos(), armor)
	self._armor = nil
end

-- The owner's click with wolf armour (put on) or shears (take off).
function A.wolf_armor_click(self, clicker)
	if not (self.tamed and self.owner == clicker:get_player_name()) or self.child then
		return false
	end
	local stack = clicker:get_wielded_item()
	if stack:get_name() == A.WOLF_ARMOR and not self._armor then
		self._armor = math.floor(stack:get_wear() / 65535 * A.ARMOR_LIFE)
		take_one(clicker, stack)
		retexture(self)
		return true
	elseif stack:get_name() == SHEARS and self._armor then
		drop_armor(self)
		core.sound_play("cb_mobs_animals_shear", { pos = self.object:get_pos(), }, true)
		retexture(self)
		return true
	end
	return false
end

local function bone_click(self, clicker)
	local stack = clicker:get_wielded_item()
	if self.tamed or self.child or self._angry or stack:get_name() ~= BONE then
		return false
	end
	take_one(clicker, stack)
	local pos = self.object:get_pos()
	core.sound_play("cb_mobs_animals_wolf_take_bone", { pos = pos, }, true)
	if math.random(3) == 1 then
		A.tame_wolf(self, clicker:get_player_name())
		mobs:effect(vector.offset(pos, 0, 0.7, 0), 6, "mobs_heart_particle.png", 1, 2, 1, 0)
	else
		mobs:effect(vector.offset(pos, 0, 0.7, 0), 6, "mobs_tnt_smoke.png", 1, 2, 1, 0)
	end
	return true
end

-- A tamed wolf following a far owner comes to them, onto free ground.
local function call_to_owner(self)
	local p = core.get_player_by_name(self.owner or "")
	local pos, at = self.object:get_pos(), p and p:get_pos()
	if not (at and vector.distance(pos, at) > CALL_RANGE) or p:get_attach() then
		return
	end
	for _, d in ipairs({ { 1, 0, }, { -1, 0, }, { 0, 1, }, { 0, -1, }, { 1, 1, }, { -1, -1, }, }) do
		local spot = vector.round(vector.offset(at, d[1], 0, d[2]))
		local here, below = core.get_node(spot), core.get_node(vector.offset(spot, 0, -1, 0))
		local hd, bd = core.registered_nodes[here.name], core.registered_nodes[below.name]
		if hd and not hd.walkable and (hd.liquidtype or "none") == "none" and bd and bd.walkable then
			self.object:set_pos(vector.offset(spot, 0, -0.5 + 0.01, 0))
			self.following = p
			return
		end
	end
end

-- A following wolf goes for the monsters (but creepers) that are after its
-- owner, before they land a blow.
local function guard_owner(self)
	local p = core.get_player_by_name(self.owner or "")
	local at = p and p:get_pos()
	if not at then
		return false
	end
	for _, obj in ipairs(core.get_objects_inside_radius(at, DEFEND_RANGE)) do
		local e = obj:get_luaentity()
		if e and e._cmi_is_mob and e.type == "monster" and e.health > 0 and e.name ~= "cb_mobs_overworld:creeper"
				and e.attack and e.attack:is_player() and e.attack:get_player_name() == self.owner then
			self:do_attack(obj)
			return true
		end
	end
	return false
end
A.wolf_guard_owner = guard_owner

-- From do_custom: sitting, the angry look and coming to the owner.
function A.wolf_tick(self, dtime)
	local angry = not self.tamed and self.state == "attack" or nil
	if angry ~= self._angry then
		self._angry = angry
		retexture(self)
	end
	if self.tamed and self.order == "stand" and self.state ~= "attack" then
		local v = self.object:get_velocity() or vector.zero()
		self.object:set_velocity({ x = 0, y = v.y, z = 0, })
		self:set_animation("sit")
		return false
	end
	self._call_t = (self._call_t or 0) + dtime
	if self.tamed and self.order == "follow" and self._call_t >= 2 then
		self._call_t = 0
		if self.state ~= "attack" and not guard_owner(self) then
			call_to_owner(self)
		end
	end
	return true
end

mobs:register_mob(A.WOLF, {
	type = "animal", passive = false, attack_players = false, group_attack = true, attack_type = "dogfight",
	attack_monsters = true, specific_attack = SKELETONS, damage = 4, reach = 2,
	hp_min = 8, hp_max = 8, armor = 100,
	collisionbox = { -0.3, 0, -0.3, 0.3, 0.85, 0.3, },
	visual = "mesh", mesh = "cb_mobs_animals_wolf.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_animals_wolf.png", "blank.png", "blank.png", }, },
	makes_footstep_sound = true, walk_velocity = 1.5, run_velocity = 3, jump = true, view_range = 12,
	water_damage = 0, lava_damage = 5, light_damage = 0, fall_damage = true, floats = 1,
	sounds = { random = "cb_mobs_animals_wolf_bark", war_cry = "cb_mobs_animals_wolf_growl",
		attack = "cb_mobs_animals_wolf_bark", damage = "cb_mobs_animals_wolf_hurt",
		death = "cb_mobs_animals_wolf_death", distance = 16, },
	animation = { speed_normal = 30, stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 40,
		run_start = 0, run_end = 40, run_speed = 50, punch_start = 0, punch_end = 40, sit_start = 41, sit_end = 41, },
	follow = { "mobs:meat_raw", "mobs:pork_raw", "mobs:chicken_raw", },
	do_custom = function(self, dtime)
		return A.wolf_tick(self, dtime)
	end,
	-- the armour takes the hit; mobs_redo would apply the damage after this
	do_punch = function(self, hitter, _, _, _, damage)
		if not self._armor or damage <= 0 then
			return
		end
		-- returning false skips mobs_redo's fighting back, so do it here
		if hitter and hitter ~= self.object and not (hitter:is_player() and hitter:get_player_name() == self.owner) then
			self:do_attack(hitter)
		end
		self._armor = self._armor + damage
		if self._armor >= A.ARMOR_LIFE then
			self._armor = nil
			core.sound_play("default_tool_breaks", { pos = self.object:get_pos(), gain = 0.6, }, true)
			retexture(self)
		end
		self:mob_sound(self.sounds.damage)
		return false
	end,
	on_rightclick = function(self, clicker)
		if not (clicker and clicker:is_player()) then
			return
		end
		if bone_click(self, clicker) or A.wolf_armor_click(self, clicker) then
			return
		end
		if self.tamed and self.owner == clicker:get_player_name()
			and mobs:feed_tame(self, clicker, 1, true, false) then
			return
		end
		A.wolf_order(self, clicker)
	end,
	on_breed = function(self, other)
		return A.on_breed(self, other, function(young)
			young._variant = (math.random(2) == 1 and self or other)._variant
			if self.tamed and self.owner and self.owner ~= "" then
				A.tame_wolf(young, self.owner)
			else
				retexture(young)
			end
		end)
	end,
	on_die = function(self)
		drop_armor(self)
	end,
	after_activate = function(self)
		if not self._variant then
			local pos = self.object:get_pos()
			self._variant = A.wolf_variant(pos and cb_spawning.biome_at(pos) or "")
		end
		if self.tamed then
			A.tame_wolf_keep(self)
		end
		retexture(self)
		if self.tamed and self.order == "stand" then
			self:set_animation("sit", true)
		end
	end,
})

-- After a reload, to be safe: the tamed settings (nil would fall back to the
-- wild definition, hence false for the attack list).
function A.tame_wolf_keep(self)
	self.type, self.attack_monsters, self.specific_attack = "npc", true, false
	self.attack_ignore, self.owner_loyal = { "cb_mobs_overworld:creeper", }, true
	self.object:set_properties({ hp_max = 20, })
end

-- A creeper's blast hurts a wolf less: a healthy tamed wolf lives through
-- even a charged one (cb_core scales the blow before mobs_redo counts it;
-- mobs_redo keeps no unknown fields, hence set on the entity).
core.registered_entities[A.WOLF]._cb_damage_factor = function(self, hitter)
	local Z = rawget(_G, "cb_mobs_overworld")
	if hitter == self.object and Z and Z.blasting then
		return A.WOLF_BLAST_FACTOR
	end
end

mobs:register_egg(A.WOLF, S("Wolf"), "cb_mobs_animals_wolf.png", 1)
