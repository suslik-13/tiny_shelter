-- Gear of hostile mobs: a weapon in the hand (piglins: a bronze or steel
-- sword, brutes: an axe) and, now and then, 3d_armor pieces (zombies, husks,
-- piglins, zombified piglins). Some swords and pieces are enchanted, never
-- with the strongest enchantments. Armour lowers the damage the mob takes,
-- Protection more so; Sharpness adds to its hit. What a mob wears drops when
-- a player kills it (armour always, the weapon with G.WEAPON_DROP), each
-- piece worn by a random amount. The gear is rolled once and kept with the
-- mob; the weapon in the hand is a small attached entity shown again on
-- every activation.
local G = {
	ARMOR_CHANCE = 0.15, -- a mob wears armour at all
	PIECE_CHANCE = 0.5, -- then each slot (at least one piece)
	ENCHANT_CHANCE = 0.3, -- each armour piece and weapon
	POWER = { 5, 15, }, -- enchanting table power (30 is the best)
	PER_FLESHY = 0.8, -- mob armour (100 = no protection) lost per point of the pieces' fleshy
	PER_PROTECTION = 3, -- and per level of Protection
	MIN_ARMOR = 45,
	WEAPON_DROP = 0.15,
	WEAR = { 0.15, 0.85, }, -- fraction of the durability used up on a dropped item
}
cb_core.gear = G
G.ENTITY = "cb_core:wielded"
G.SLOTS = { "helmet", "chestplate", "leggings", "boots", }

core.register_entity(G.ENTITY, {
	initial_properties = { visual = "wielditem", visual_size = { x = 0.21, y = 0.21, }, physical = false,
		pointable = false, static_save = false, wield_item = "air", },
	on_step = function(self, dtime)
		self._t = (self._t or 0) + dtime
		if self._t >= 1 then
			self._t = 0
			if not self.object:get_attach() then
				self.object:remove()
			end
		end
	end,
})

local function rand(a, b)
	return a + (b - a) * math.random()
end

local function pick(weights)
	local total = 0
	for _, w in pairs(weights) do
		total = total + w
	end
	local r = math.random() * total
	for k, w in pairs(weights) do
		r = r - w
		if r <= 0 then
			return k
		end
	end
	return next(weights)
end

local function enchanted(name)
	local stack = ItemStack(name)
	local E = rawget(_G, "cb_enchanting")
	if E and E.enchant_randomly and math.random() < G.ENCHANT_CHANCE then
		stack = E.enchant_randomly(stack, math.random(G.POWER[1], G.POWER[2]), false)
	end
	return stack:to_string()
end

-- The gear for opts: { weapons = { names }, armor = { material = weight } }.
function G.roll(opts)
	local gear = { armor = {}, }
	if opts.weapons then
		local list = {}
		for _, n in ipairs(opts.weapons) do
			if core.registered_items[n] then
				list[#list + 1] = n
			end
		end
		if #list > 0 then
			gear.weapon = enchanted(list[math.random(#list)])
		end
	end
	if opts.armor and math.random() < G.ARMOR_CHANCE then
		local material = pick(opts.armor)
		local slots = {}
		for _, slot in ipairs(G.SLOTS) do
			if core.registered_items["3d_armor:" .. slot .. "_" .. material] and math.random() < G.PIECE_CHANCE then
				slots[#slots + 1] = slot
			end
		end
		if #slots == 0 and core.registered_items["3d_armor:chestplate_" .. material] then
			slots[1] = "chestplate"
		end
		for _, slot in ipairs(slots) do
			gear.armor[#gear.armor + 1] = enchanted("3d_armor:" .. slot .. "_" .. material)
		end
	end
	return gear
end

-- The armour texture (3d_armor's own, on the Minecraft skin layout the mob
-- models use); helmets left out when the model shows no head armour.
function G.armor_texture(gear, helmet)
	local parts = {}
	for _, s in ipairs(gear.armor or {}) do
		local name = ItemStack(s):get_name()
		local def = core.registered_items[name]
		if def and (helmet or not name:find(":helmet_", 1, true)) then
			parts[#parts + 1] = ((def.texture or name:gsub(":", "_")):gsub("%.png$", "")) .. ".png"
		end
	end
	return #parts > 0 and ("blank.png^" .. table.concat(parts, "^")) or "blank.png"
end

local function set_bone(obj, bone, pos, rot)
	if obj.set_bone_override then
		obj:set_bone_override(bone, { position = { vec = pos, absolute = true, },
			rotation = { vec = vector.apply(rot, math.rad), absolute = true, }, })
	else
		obj:set_bone_position(bone, pos, rot)
	end
end

local function show_weapon(self, opts)
	if self._cb_wield_obj then
		self._cb_wield_obj:remove()
		self._cb_wield_obj = nil
	end
	local pos = self.object:get_pos()
	local w = opts.wield
	if not (self._cb_gear.weapon and w and pos) then
		return
	end
	local obj = core.add_entity(pos, G.ENTITY)
	if obj then
		obj:set_attach(self.object, w.bone)
		set_bone(self.object, w.bone, w.pos, w.rot)
		obj:set_properties({ wield_item = ItemStack(self._cb_gear.weapon):get_name(), })
		self._cb_wield_obj = obj
	end
end

-- Damage taken and dealt from the gear; the mob's own values are kept apart
-- so that this can run on every activation.
function G.stats(self)
	local gear = self._cb_gear
	self._cb_base = self._cb_base or { armor = self.armor, damage = self.damage, }
	local E = rawget(_G, "cb_enchanting")
	local fleshy, protection = 0, 0
	for _, s in ipairs(gear.armor) do
		local stack = ItemStack(s)
		local def = core.registered_items[stack:get_name()]
		fleshy = fleshy + (def and def.armor_groups and def.armor_groups.fleshy or 0)
		protection = protection + (E and E.level(stack, "protection") or 0)
	end
	local base = self._cb_base
	local function lowered(v)
		return math.max(G.MIN_ARMOR, math.floor(v - fleshy * G.PER_FLESHY - protection * G.PER_PROTECTION + 0.5))
	end
	-- a number (fleshy) or a table of groups (mods such as mobs_balrog add some)
	if type(base.armor) == "number" then
		self.armor = lowered(base.armor)
		self.object:set_armor_groups({ fleshy = self.armor, immortal = 1, })
	elseif type(base.armor) == "table" then
		self.armor = table.copy(base.armor)
		self.armor.fleshy = lowered(base.armor.fleshy or 100)
		self.object:set_armor_groups(self.armor)
	end
	local sharp = gear.weapon and E and E.level(ItemStack(gear.weapon), "sharpness") or 0
	if base.damage then
		self.damage = base.damage + (sharp > 0 and math.ceil(0.5 * sharp + 0.5) or 0)
	end
end

G.OPTS = {}

-- From the mob's after_activate. opts: weapons, armor (material weights),
-- wield = { bone, pos, rot } (the hand), armor_slots (texture slots the
-- armour goes to), helmet (whether the model shows the helmet).
function G.apply(self, opts)
	opts = opts or G.OPTS[self.name]
	if not opts then
		return
	end
	if self._cb_gear == nil then
		self._cb_gear = G.roll(opts)
	end
	self._cb_gear.armor = self._cb_gear.armor or {}
	if #self._cb_gear.armor > 0 and opts.armor_slots then
		local textures = table.copy(self.object:get_properties().textures)
		local tex = G.armor_texture(self._cb_gear, opts.helmet)
		for _, i in ipairs(opts.armor_slots) do
			textures[i] = tex
		end
		self.object:set_properties({ textures = textures, })
		self.textures = textures
	end
	show_weapon(self, opts)
	G.stats(self)
end

-- The gear, worn by a random amount, as it drops (weapon not always).
function G.loot(gear)
	local out = {}
	local function worn(s)
		local stack = ItemStack(s)
		if core.registered_tools[stack:get_name()] then
			stack:set_wear(math.floor(65535 * rand(G.WEAR[1], G.WEAR[2])))
		end
		return stack
	end
	for _, s in ipairs(gear.armor or {}) do
		out[#out + 1] = worn(s)
	end
	if gear.weapon and math.random() < G.WEAPON_DROP then
		out[#out + 1] = worn(gear.weapon)
	end
	return out
end

-- The gear goes on to a mob that turns into another (piglin -> zombified).
function G.pass_on(from, to)
	if from._cb_gear and to then
		to._cb_gear = from._cb_gear
		G.apply(to)
	end
end

-- opts of a mob, for G.apply(self) and G.pass_on.
function G.register(name, opts)
	G.OPTS[name] = opts
end

core.register_on_mods_loaded(function()
	local mobs = rawget(_G, "mobs")
	if not (mobs and mobs.mob_class and mobs.mob_class.item_drop) then
		return
	end
	local item_drop = mobs.mob_class.item_drop
	mobs.mob_class.item_drop = function(self, ...)
		local c, gear = self.cause_of_death, self._cb_gear
		local killer = c and c.puncher
		if gear and killer and killer.is_player and killer:is_player() then
			self._cb_gear = nil
			local pos = self.object:get_pos()
			for _, stack in ipairs(G.loot(gear)) do
				local obj = pos and core.add_item(pos, stack)
				if obj then
					obj:set_velocity({ x = rand(-1, 1), y = 4, z = rand(-1, 1), })
				end
			end
		end
		return item_drop(self, ...)
	end
end)
