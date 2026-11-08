-- Dried ghast, ghastling and happy ghast (plan 8f-3), Bedrock behaviour
-- after secret_terra's st_mobs ones (their model, textures and sounds).
-- A dried ghast (8 ghast tears around soul sand; piglins barter it) next to
-- water rehydrates one stage every 4-6 minutes and after the fourth hatches
-- a ghastling; away from water it dries back. A ghastling follows players
-- and grows up in 20 minutes (snow fed to it: 2 minutes each; players have
-- no snowballs here). A happy ghast (20 HP) drifts near its home; a harness
-- (leather, glass and wool) lets up to four players ride, the first one
-- steering (forward along the look, jump to rise, sneak to get off); it
-- stops while a player stands on its back, heals 1 HP every 30 s, takes no
-- fall damage, and shears take the harness off.
local S = cb_mobs_trial.S
local T = cb_mobs_trial
T.GHASTLING, T.HAPPY_GHAST, T.DRIED_GHAST = "cb_mobs_trial:ghastling", "cb_mobs_trial:happy_ghast", "cb_mobs_trial:dried_ghast"
local G = { GROW = 1200, SNOW_GROWTH = 120, SNOW = "default:snow", RIDE = 3.6, RISE = 3, BACK = 0.5, SCALE = 4, TOP = 4,
	HEAL = 30, HYDRATE = 250, JITTER = 136, FOLLOW = 16, FOLLOW_STOP = 5, }
T.ghast = G
local PA = rawget(_G, "player_api")

-- { harness colour, description, wool }
local COLOURS = {
	{ "white", S("White Harness"), "white", }, { "light_gray", S("Light Gray Harness"), "grey", },
	{ "gray", S("Gray Harness"), "dark_grey", }, { "black", S("Black Harness"), "black", },
	{ "brown", S("Brown Harness"), "brown", }, { "red", S("Red Harness"), "red", },
	{ "orange", S("Orange Harness"), "orange", }, { "yellow", S("Yellow Harness"), "yellow", },
	{ "lime", S("Lime Harness"), "green", }, { "green", S("Green Harness"), "dark_green", },
	{ "cyan", S("Cyan Harness"), "cyan", }, { "blue", S("Blue Harness"), "blue", },
	{ "purple", S("Purple Harness"), "violet", }, { "magenta", S("Magenta Harness"), "magenta", },
	{ "pink", S("Pink Harness"), "pink", },
}
G.HARNESS = {}
for _, c in ipairs(COLOURS) do
	local name = "cb_mobs_trial:harness_" .. c[1]
	G.HARNESS[name] = c[1]
	core.register_craftitem(name, { description = c[2], inventory_image = "cb_mobs_trial_harness_" .. c[1] .. ".png",
		stack_max = 1, groups = { cb_harness = 1, }, })
	core.register_craft({ output = name, recipe = { { "mobs:leather", "mobs:leather", "mobs:leather", },
		{ "default:glass", "wool:" .. c[3], "default:glass", }, }, })
end

local function sound(name, pos, gain)
	core.sound_play(name, { pos = pos, gain = gain or 1, max_hear_distance = 24, }, true)
end

local function take_one(player, stack)
	if not core.is_creative_enabled(player:get_player_name()) then
		stack:take_item()
		player:set_wielded_item(stack)
	end
end

local function face(self, dir)
	if dir.x ~= 0 or dir.z ~= 0 then
		self.object:set_yaw(core.dir_to_yaw(vector.new(dir.x, 0, dir.z)))
	end
end

-- Riders by entity (objects cannot be saved).
local riders = setmetatable({}, { __mode = "k", })
local function rider_list(self)
	local list = riders[self]
	if not list then
		list = {}
		riders[self] = list
	end
	for i = #list, 1, -1 do
		local seat = list[i]:get_pos() and list[i]:get_attach()
		if not (seat and seat:get_attach() == self.object) then
			table.remove(list, i)
		end
	end
	return list
end
G.riders = rider_list

function G.texture(self)
	local tex = "cb_mobs_trial_happy_ghast.png"
	if (self._harness or "") ~= "" then
		local ridden = riders[self] and #riders[self] > 0
		tex = tex .. "^cb_mobs_trial_happy_ghast_harness_" .. self._harness .. ".png^cb_mobs_trial_happy_ghast_goggles_"
			.. (ridden and "down" or "up") .. ".png"
	end
	self.object:set_properties({ textures = { tex, }, })
	self.base_texture = { tex, }
end

-- Seats (model units, the model faces +z); the first one steers.
local SEATS = { vector.new(0, 38, 17), vector.new(-17, 38, 0), vector.new(0, 38, -17), vector.new(17, 38, 0), }

-- A rider sits on an invisible seat attached to the ghast: the client keeps an
-- attached player's camera at the origin of its parent, and the ghast's own origin
-- is under the body, which put the third person views inside the model (an eye
-- offset cannot lift them: the engine caps it at 1.5 nodes there). Children inherit
-- the scale of a parent's mesh: the seat's offset is divided by the ghast's scale and
-- its own invisible mesh undoes that scale, else riders are four times too big and
-- float high above. A seat without a rider or a ghast removes itself.
local SEAT = "cb_mobs_trial:happy_ghast_seat"
core.register_entity(SEAT, {
	initial_properties = { physical = false, pointable = false, visual = "mesh", mesh = "cb_mobs_trial_happy_ghast.b3d",
		textures = { "blank.png", }, visual_size = { x = 1 / G.SCALE, y = 1 / G.SCALE, }, static_save = false, },
	on_step = function(self)
		if not self.object:get_attach() or #self.object:get_children() == 0 then
			self.object:remove()
		end
	end,
})

local function seated(player, on)
	if PA then
		PA.player_attached[player:get_player_name()] = on or nil
		PA.set_animation(player, on and "sit" or "stand", 30)
	end
end

function G.mount(self, player)
	local list = rider_list(self)
	if #list >= #SEATS or player:get_attach() or (self._harness or "") == "" then
		return false
	end
	list[#list + 1] = player
	local seat = core.add_entity(self.object:get_pos(), SEAT)
	if not seat then
		list[#list] = nil
		return false
	end
	seat:set_attach(self.object, "", vector.divide(SEATS[#list], G.SCALE), vector.zero())
	player:set_attach(seat, "", vector.zero(), vector.zero())
	seated(player, true)
	G.texture(self)
	sound("cb_mobs_trial_happy_ghast_goggles_down", self.object:get_pos())
	return true
end

function G.dismount(self, player)
	if not player:get_pos() then
		return
	end
	player:set_detach()
	seated(player, false)
	local pos = self and self.object:get_pos()
	if pos then
		player:set_pos(vector.offset(pos, 0, G.TOP + 0.05, 0))
	end
end

function G.dismount_all(self)
	for _, p in ipairs(rider_list(self)) do
		G.dismount(self, p)
	end
	riders[self] = nil
end

-- Players standing on its back (not riding).
local function on_top(self, pos)
	local n = 0
	for _, p in ipairs(core.get_connected_players()) do
		local at = p:get_pos()
		if not p:get_attach() and math.abs(at.x - pos.x) <= 2.5 and math.abs(at.z - pos.z) <= 2.5
				and at.y >= pos.y + G.TOP - 0.3 and at.y <= pos.y + G.TOP + 1.5 then
			n = n + 1
		end
	end
	return n
end

-- Velocity from the pilot's controls.
function G.pilot_velocity(look, ctrl)
	local v = vector.zero()
	if ctrl.up then
		v = vector.multiply(look, G.RIDE)
	elseif ctrl.down then
		v = vector.multiply(look, -G.RIDE * G.BACK)
	end
	local right = vector.normalize(vector.new(look.z, 0, -look.x))
	if ctrl.right then
		v = vector.add(v, vector.multiply(right, G.RIDE))
	elseif ctrl.left then
		v = vector.add(v, vector.multiply(right, -G.RIDE))
	end
	if ctrl.jump then
		v.y = v.y + G.RISE
	end
	if vector.length(v) > G.RIDE then
		v = vector.multiply(vector.normalize(v), G.RIDE)
	end
	return v
end

function G.step(self, dtime)
	local pos = self.object:get_pos()
	self._home = self._home or vector.copy(pos)
	self._heal = (self._heal or 0) + dtime
	if self._heal >= G.HEAL then
		self._heal = 0
		self.health = math.min(self.hp_max or 20, self.health + 1)
	end
	local list = rider_list(self)
	for i = #list, 1, -1 do
		if list[i]:get_player_control().sneak then
			local p = table.remove(list, i)
			G.dismount(self, p)
			for j = i, #list do
				list[j]:get_attach():set_attach(self.object, "", vector.divide(SEATS[j], G.SCALE), vector.zero())
			end
			if #list == 0 then
				self._home = vector.copy(pos)
				G.texture(self)
				sound("cb_mobs_trial_happy_ghast_goggles_up", pos)
			end
		end
	end
	local pilot = list[1]
	if pilot then
		self.object:set_velocity(G.pilot_velocity(pilot:get_look_dir(), pilot:get_player_control()))
		self.object:set_yaw(pilot:get_look_horizontal())
		self:set_animation("walk")
		return false
	end
	if on_top(self, pos) > 0 then
		self.object:set_velocity(vector.zero())
		self:set_animation("stand")
		return false
	end
	-- drift back when far from home (64 nodes, 32 with a harness)
	local radius = (self._harness or "") ~= "" and 32 or 64
	if vector.distance(pos, self._home) > radius then
		local dir = vector.direction(pos, self._home)
		self.object:set_velocity(vector.multiply(dir, 1))
		face(self, dir)
		return false
	end
	return true
end

-- A click: harness on, shears take it off, or a seat.
function G.click(self, clicker)
	local item = clicker:get_wielded_item()
	local name = item:get_name()
	local pos = self.object:get_pos()
	if (self._harness or "") == "" and G.HARNESS[name] then
		self._harness = G.HARNESS[name]
		take_one(clicker, item)
		self._home = vector.copy(pos)
		sound("cb_mobs_trial_harness_equip", pos)
		G.texture(self)
		return "harness"
	end
	if name == "mobs:shears" and (self._harness or "") ~= "" and #rider_list(self) == 0 then
		core.add_item(vector.offset(pos, 0, 5, 0), "cb_mobs_trial:harness_" .. self._harness)
		self._harness = ""
		sound("cb_mobs_trial_harness_equip", pos, 0.7)
		G.texture(self)
		return "shears"
	end
	if (self._harness or "") ~= "" and G.mount(self, clicker) then
		return "mount"
	end
	return nil
end

mobs:register_mob(T.HAPPY_GHAST, {
	type = "animal", passive = true, hp_min = 20, hp_max = 20, armor = 100,
	collisionbox = { -2, 0, -2, 2, G.TOP, 2, },
	visual = "mesh", mesh = "cb_mobs_trial_happy_ghast.b3d", visual_size = { x = G.SCALE, y = G.SCALE, },
	textures = { { "cb_mobs_trial_happy_ghast.png", }, },
	fly = true, fly_in = { "air", }, walk_velocity = 1, run_velocity = 1.6, jump = false, view_range = 16,
	water_damage = 1, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
	drops = {},
	sounds = { random = "cb_mobs_trial_happy_ghast_idle", damage = "cb_mobs_trial_happy_ghast_hurt",
		death = "cb_mobs_trial_happy_ghast_death", distance = 32, },
	animation = { speed_normal = 20, stand_start = 0, stand_end = 40, walk_start = 41, walk_end = 61, fly_start = 41,
		fly_end = 61, },
	do_custom = G.step,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() then
			G.click(self, clicker)
		end
	end,
	on_die = function(self, pos)
		G.dismount_all(self)
		if (self._harness or "") ~= "" then
			core.add_item(vector.offset(pos, 0, 1, 0), "cb_mobs_trial:harness_" .. self._harness)
			self._harness = ""
		end
	end,
	after_activate = function(self)
		-- kept like a tamed animal
		self.tamed = true
		G.texture(self)
	end,
})
mobs:register_egg(T.HAPPY_GHAST, S("Happy Ghast"), "cb_mobs_trial_happy_ghast.png", 1)

core.register_on_leaveplayer(function(player)
	for self, list in pairs(riders) do
		for i = #list, 1, -1 do
			if list[i] == player then
				table.remove(list, i)
				G.dismount(nil, player)
			end
		end
	end
end)

-- Ghastling: grows up into a happy ghast.
function G.grow(self)
	local pos = self.object:get_pos()
	local yaw = self.object:get_yaw()
	self.object:remove()
	local obj = core.add_entity(pos, T.HAPPY_GHAST)
	if obj then
		obj:set_yaw(yaw)
	end
	return obj
end

function G.ghastling_step(self, dtime)
	self._age = (self._age or 0) + dtime
	if self._age >= G.GROW then
		G.grow(self)
		return false
	end
	local pos = self.object:get_pos()
	local best, bd
	for _, p in ipairs(core.get_connected_players()) do
		local d = vector.distance(p:get_pos(), pos)
		if d <= G.FOLLOW and (not bd or d < bd) then
			best, bd = p, d
		end
	end
	if best and bd > G.FOLLOW_STOP then
		local dir = vector.direction(pos, vector.offset(best:get_pos(), 0, 1, 0))
		self.object:set_velocity(vector.multiply(dir, 2.4))
		face(self, dir)
		return false
	end
	return true
end

-- Snow fed to a ghastling: 2 minutes nearer to growing up.
function G.feed_ghastling(self, clicker)
	local item = clicker:get_wielded_item()
	if item:get_name() ~= G.SNOW then
		return false
	end
	take_one(clicker, item)
	self._age = (self._age or 0) + G.SNOW_GROWTH
	if self._age >= G.GROW then
		G.grow(self)
	end
	return true
end

mobs:register_mob(T.GHASTLING, {
	type = "animal", passive = true, hp_min = 20, hp_max = 20, armor = 100,
	collisionbox = { -0.475, 0, -0.475, 0.475, 0.95, 0.475, },
	visual = "mesh", mesh = "cb_mobs_trial_happy_ghast.b3d", visual_size = { x = 0.95, y = 0.95, },
	textures = { { "cb_mobs_trial_happy_ghast.png", }, },
	fly = true, fly_in = { "air", }, walk_velocity = 1.5, run_velocity = 2.4, jump = false, view_range = 16,
	water_damage = 1, lava_damage = 5, light_damage = 0, fall_damage = false, makes_footstep_sound = false,
	drops = {},
	sounds = { random = "cb_mobs_trial_ghastling_idle", damage = "cb_mobs_trial_happy_ghast_hurt",
		death = "cb_mobs_trial_happy_ghast_death", distance = 16, },
	animation = { speed_normal = 20, stand_start = 0, stand_end = 40, walk_start = 41, walk_end = 61, fly_start = 41,
		fly_end = 61, },
	do_custom = G.ghastling_step,
	on_rightclick = function(self, clicker)
		if clicker and clicker:is_player() then
			G.feed_ghastling(self, clicker)
		end
	end,
	after_activate = function(self)
		self.tamed = true
	end,
})
mobs:register_egg(T.GHASTLING, S("Ghastling"), "cb_mobs_trial_happy_ghast.png", 1)

-- Dried ghast block: four stages.
local function dried(stage)
	return stage == 0 and T.DRIED_GHAST or T.DRIED_GHAST .. "_" .. stage
end

function G.wet(pos)
	for _, d in ipairs({ { 0, 1, 0, }, { 1, 0, 0, }, { -1, 0, 0, }, { 0, 0, 1, }, { 0, 0, -1, }, }) do
		if core.get_item_group(core.get_node(vector.offset(pos, d[1], d[2], d[3])).name, "water") > 0 then
			return true
		end
	end
	return false
end

local function start(pos)
	core.get_node_timer(pos):start(G.HYDRATE + math.random() * G.JITTER)
end

-- One rehydration step of the dried ghast at pos: "hatched", "wetter",
-- "drier" or "same".
function G.hydrate(pos)
	local node = core.get_node(pos)
	local stage = core.get_item_group(node.name, "dried_ghast") - 1
	if stage < 0 then
		return "same"
	end
	if G.wet(pos) then
		if stage >= 3 then
			core.remove_node(pos)
			core.add_entity(vector.offset(pos, 0, -0.45, 0), T.GHASTLING)
			sound("cb_mobs_trial_dried_ghast_hatch", pos)
			return "hatched"
		end
		core.swap_node(pos, { name = dried(stage + 1), param2 = node.param2, })
		sound("cb_mobs_trial_dried_ghast_rehydrate", pos, 0.8)
		return "wetter"
	elseif stage > 0 then
		core.swap_node(pos, { name = dried(stage - 1), param2 = node.param2, })
		return "drier"
	end
	return "same"
end

local BOX = { type = "fixed", fixed = {
	{ -5 / 16, -5 / 16, -5 / 16, 5 / 16, 5 / 16, 5 / 16, },
	{ -4 / 16, -8 / 16, -4 / 16, -2 / 16, -5 / 16, -2 / 16, }, { 2 / 16, -8 / 16, -4 / 16, 4 / 16, -5 / 16, -2 / 16, },
	{ -1 / 16, -7 / 16, -1 / 16, 1 / 16, -5 / 16, 1 / 16, }, { -4 / 16, -8 / 16, 2 / 16, -2 / 16, -5 / 16, 4 / 16, },
	{ 2 / 16, -8 / 16, 2 / 16, 4 / 16, -5 / 16, 4 / 16, },
}, }
for stage = 0, 3 do
	local t = "cb_mobs_trial_dried_ghast_" .. stage
	core.register_node(dried(stage), {
		description = S("Dried Ghast"),
		drawtype = "nodebox",
		node_box = BOX,
		selection_box = { type = "fixed", fixed = { -5 / 16, -8 / 16, -5 / 16, 5 / 16, 5 / 16, 5 / 16, }, },
		paramtype = "light",
		paramtype2 = "4dir",
		sunlight_propagates = true,
		tiles = { t .. "_top.png", t .. "_bottom.png", t .. "_side.png", t .. "_side.png", t .. "_side.png", t .. "_front.png", },
		groups = { dig_immediate = 3, dried_ghast = stage + 1, not_in_creative_inventory = stage > 0 and 1 or nil, },
		drop = T.DRIED_GHAST,
		is_ground_content = false,
		sounds = default.node_sound_sand_defaults(),
		on_construct = start,
		on_timer = function(pos)
			if G.hydrate(pos) ~= "hatched" then
				start(pos)
			end
			return false
		end,
	})
end

core.register_lbm({
	label = "Dried ghast timers",
	name = "cb_mobs_trial:dried_ghast_timer",
	nodenames = { "group:dried_ghast", },
	run_at_every_load = true,
	action = function(pos)
		if not core.get_node_timer(pos):is_started() then
			start(pos)
		end
	end,
})

local TEAR = "cb_mobs_nether:ghast_tear"
local SOUL = core.registered_nodes["nether:soul_sand"] and "nether:soul_sand" or "cb_blocks:soul_sand"
core.register_craft({ output = T.DRIED_GHAST, recipe = { { TEAR, TEAR, TEAR, }, { TEAR, SOUL, TEAR, }, { TEAR, TEAR, TEAR, }, }, })

-- Piglins barter it (Bedrock: 10 in 469).
local N = rawget(_G, "cb_mobs_nether")
if N and N.BARTER then
	table.insert(N.BARTER, { { T.DRIED_GHAST, }, 10, 1, 1, })
end
