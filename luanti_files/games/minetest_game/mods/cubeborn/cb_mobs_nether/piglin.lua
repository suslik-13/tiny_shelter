-- Piglin and zombified piglin (spec cycle 4, 8d).
-- Piglins attack players within 16 nodes who wear no gold armour (any worn
-- 3d_armor piece with "gold" in its name); on a server without gold armour
-- they stay neutral until hit. A gold ingot dropped near a calm piglin is
-- taken, looked at for 6 s and paid for with one item from Bedrock's barter
-- table (what the server has of it). In the Overworld a piglin turns into a
-- zombified piglin after 15 s. Zombified piglins are neutral, but hit one
-- and every zombified piglin within 32 nodes goes for the attacker.
-- Piglin brutes (rare inhabitants of bastions) go for every player in
-- range, gold or not, take no gold and zombify like piglins.
local S = cb_mobs_nether.S
local N = cb_mobs_nether
N.PIGLIN, N.ZOMBIFIED = "cb_mobs_nether:piglin", "cb_mobs_nether:zombified_piglin"
N.BRUTE = "cb_mobs_nether:piglin_brute"
local GOLD, ANGER_RANGE, PACK_RANGE, LOOK_TIME, ZOMBIFY_TIME = "default:gold_ingot", 16, 32, 6, 15
local E = cb_core.equiv

-- Bedrock's barter table: {candidates, weight, min, max}; missing items drop out.
local BARTER = {
	{ { "default:obsidian", }, 40, 1, 1, }, { { "default:gravel", }, 40, 8, 16, }, { { "mobs:leather", }, 40, 4, 10, },
	{ { "nether:soul_sand", "cb_blocks:soul_sand", }, 40, 4, 16, },
	{ { E and E("nether_brick") or "cb_blocks:nether_bricks", }, 40, 4, 16, },
	{ { "farming:string", }, 20, 3, 9, }, { { "cb_blocks:quartz", }, 20, 4, 10, },
	{ { "cb_items:ender_pearl", }, 10, 2, 6, }, { { "3d_armor:boots_steel", }, 8, 1, 1, },
	{ { "cb_blocks:blackstone", }, 40, 8, 16, }, { { "cb_blocks:crying_obsidian", "default:obsidian", }, 40, 1, 1, },
}
N.BARTER = BARTER
local barter_list

local function barter_table()
	if not barter_list then
		barter_list = {}
		for _, b in ipairs(BARTER) do
			for _, name in ipairs(b[1]) do
				if core.registered_items[name] then
					barter_list[#barter_list + 1] = { name, b[2], b[3], b[4], }
					break
				end
			end
		end
	end
	return barter_list
end

-- One barter result (roll 0..1 picks by weight).
function N.barter(roll)
	local list, total = barter_table(), 0
	for _, b in ipairs(list) do
		total = total + b[2]
	end
	local r, acc = (roll or math.random()) * total, 0
	for _, b in ipairs(list) do
		acc = acc + b[2]
		if r <= acc then
			return ItemStack(b[1] .. " " .. math.random(b[3], b[4]))
		end
	end
end

local gold_armor_exists
function N.wears_gold(player)
	local inv = core.get_inventory({ type = "detached", name = player:get_player_name() .. "_armor", })
	for _, st in ipairs(inv and inv:get_list("armor") or {}) do
		if st:get_name():find("gold", 1, true) then
			return true
		end
	end
	return false
end

-- Whether a piglin goes for this player.
function N.piglin_hates(player)
	if gold_armor_exists == nil then
		gold_armor_exists = false
		for name in pairs(core.registered_tools) do
			gold_armor_exists = gold_armor_exists or (name:find("^3d_armor:") and name:find("gold", 1, true)) ~= nil
		end
	end
	return gold_armor_exists and not core.is_creative_enabled(player:get_player_name()) and not N.wears_gold(player)
end

-- Takes one gold ingot lying within 2 nodes; true when it did.
function N.piglin_take_gold(self)
	local pos = self.object:get_pos()
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 2)) do
		local e = obj:get_luaentity()
		local st = e and e.name == "__builtin:item" and ItemStack(e.itemstring)
		if st and st:get_name() == GOLD then
			st:take_item()
			if st:is_empty() then
				obj:remove()
			else
				e:set_item(st)
			end
			self._look = LOOK_TIME
			self:set_velocity(0)
			return true
		end
	end
	return false
end

local function zombify(self)
	local pos = self.object:get_pos()
	self.object:remove()
	local obj = core.add_entity(pos, N.ZOMBIFIED)
	local ent = obj and obj:get_luaentity()
	cb_core.gear.pass_on(self, ent)
	return ent
end
N.zombify = zombify

-- Counts the time in the Overworld; true once it zombified.
local function overworld(self, pos, dtime)
	if cb_spawning.dim_at and cb_spawning.dim_at(pos) == "overworld" then
		self._zt = (self._zt or 0) + dtime
		if self._zt >= ZOMBIFY_TIME then
			zombify(self)
			return true
		end
	end
	return false
end

function N.piglin_tick(self, dtime)
	local pos = self.object:get_pos()
	if overworld(self, pos, dtime) then
		return false
	end
	if self._look then
		self._look = self._look - dtime
		if self._look <= 0 then
			self._look = nil
			local item = N.barter()
			if item then
				core.add_item(vector.offset(pos, 0, 1, 0), item)
			end
		end
		return false
	end
	self._scan = (self._scan or 0) + dtime
	if self._scan < 1 then
		return true
	end
	self._scan = 0
	if self.state ~= "attack" then
		if N.piglin_take_gold(self) then
			return false
		end
		for _, p in ipairs(core.get_connected_players()) do
			if vector.distance(pos, p:get_pos()) <= ANGER_RANGE and N.piglin_hates(p) then
				self:do_attack(p)
				break
			end
		end
	end
	return true
end

function N.brute_tick(self, dtime)
	local pos = self.object:get_pos()
	if overworld(self, pos, dtime) then
		return false
	end
	self._scan = (self._scan or 0) + dtime
	if self._scan < 1 or self.state == "attack" then
		return true
	end
	self._scan = 0
	for _, p in ipairs(core.get_connected_players()) do
		if vector.distance(pos, p:get_pos()) <= ANGER_RANGE and not core.is_creative_enabled(p:get_player_name())
				and p:get_hp() > 0 then
			self:do_attack(p)
			break
		end
	end
	return true
end

-- A zombified piglin hit: the others near join in.
function N.pack_anger(self, hitter)
	local n = 0
	if not hitter or hitter == self.object then
		return n
	end
	for _, obj in ipairs(core.get_objects_inside_radius(self.object:get_pos(), PACK_RANGE)) do
		local e = obj:get_luaentity()
		if e and e.name == N.ZOMBIFIED and obj ~= hitter then
			e:do_attack(hitter)
			n = n + 1
		end
	end
	return n
end

local ANIM = { speed_normal = 30, stand_start = 0, stand_end = 79, walk_start = 168, walk_end = 187, walk_speed = 12,
	run_start = 168, run_end = 187, run_speed = 12, punch_start = 189, punch_end = 198, punch_speed = 45, }

-- Mineclonia's piglin: the Wield_Item bone holds a tool at this offset; the
-- legs armour goes to texture 2, body and boots to 3 (the helmet would need
-- a head model of its own, so it is worn but not shown).
local HAND = { bone = "Wield_Item", pos = vector.new(0, 4.7, 3.1), rot = vector.new(-90, 225, 90), }
local SWORDS = { "default:sword_bronze", "default:sword_steel", }
local ARMOR = { gold = 3, steel = 1, bronze = 1, }
N.GEAR = {
	piglin = { weapons = SWORDS, armor = ARMOR, wield = HAND, armor_slots = { 2, 3, }, helmet = false, },
	brute = { weapons = { "default:axe_bronze", "default:axe_steel", }, wield = HAND, },
}

local function register(name, desc, tex, hp, extra)
	local def = {
		type = "animal", passive = false, attack_players = false, attack_type = "dogfight", damage = 5, reach = 2,
		hp_min = hp, hp_max = hp, armor = 100,
		collisionbox = { -0.3, 0, -0.3, 0.3, 1.95, 0.3, },
		visual = "mesh", mesh = "cb_mobs_nether_piglin.b3d", visual_size = { x = 1, y = 1, },
		textures = { { tex, "blank.png", "blank.png", }, },
		makes_footstep_sound = true, walk_velocity = 1, run_velocity = 2.5, jump = true, view_range = 16,
		water_damage = 0, lava_damage = 4, light_damage = 0, fall_damage = true,
		sounds = { random = "cb_mobs_nether_zombiepig_random", war_cry = "cb_mobs_nether_zombiepig_war_cry",
			damage = "cb_mobs_nether_zombiepig_hurt", death = "cb_mobs_nether_zombiepig_death", distance = 16, },
		animation = ANIM,
	}
	for k, v in pairs(extra) do
		def[k] = v
	end
	-- weapon in the hand, sometimes armour (cb_core/mob_gear.lua)
	if def.gear then
		cb_core.gear.register(name, def.gear)
		def.gear = nil
		local own = def.after_activate
		def.after_activate = function(self, ...)
			cb_core.gear.apply(self)
			if own then
				return own(self, ...)
			end
		end
	end
	mobs:register_mob(name, def)
	mobs:register_egg(name, desc, tex, 1)
end

register(N.PIGLIN, S("Piglin"), "cb_mobs_nether_piglin.png", 16, {
	gear = N.GEAR.piglin,
	do_custom = function(self, dtime)
		return N.piglin_tick(self, dtime)
	end,
})
register(N.BRUTE, S("Piglin Brute"), "cb_mobs_nether_piglin_brute.png", 50, {
	damage = 7,
	gear = N.GEAR.brute,
	do_custom = function(self, dtime)
		return N.brute_tick(self, dtime)
	end,
})
local zdrops = { { name = "default:gold_lump", chance = 10, min = 1, max = 1, }, }
if core.registered_items["cb_items:rotten_flesh"] then
	zdrops[#zdrops + 1] = { name = "cb_items:rotten_flesh", chance = 1, min = 0, max = 1, }
end
register(N.ZOMBIFIED, S("Zombified Piglin"), "cb_mobs_nether_zombified_piglin.png", 20, {
	fire_damage = 0, lava_damage = 0,
	drops = zdrops,
	gear = N.GEAR.piglin,
	do_punch = function(self, hitter)
		N.pack_anger(self, hitter)
	end,
})
