-- Fireworks (spec cycle 10): firework stars (shape, colours, fade, trail,
-- twinkle) and rockets (flight 1-3, up to 3 stars here... any number that
-- fits the grid). Placed on a block a rocket flies up and bursts into its
-- stars; used while gliding it boosts the elytra. No crossbow use: players
-- have no ranged weapons. The fire charge (large-ball shape) also lights fire.
local S = cb_items.S
local F = {}
cb_items.fireworks = F
F.STAR, F.ROCKET, F.CHARGE, F.ENTITY = "cb_items:firework_star", "cb_items:firework_rocket", "cb_items:fire_charge",
	"cb_items:firework_entity"
local GUNPOWDER, PAPER = "tnt:gunpowder", "default:paper"
local DIAMOND, GLOW = "default:diamond", "cb_blocks:glowstone_dust"

-- MTG dye colours (Minecraft's firework colours where they match).
F.COLORS = {
	white = "#f0f0f0", grey = "#ababab", dark_grey = "#434343", black = "#1e1b1b", violet = "#7b2fbe",
	blue = "#253192", cyan = "#287697", dark_green = "#3b511a", green = "#41cd34", yellow = "#decf2a",
	brown = "#51301a", orange = "#eb8844", red = "#b3312c", magenta = "#c354cd", pink = "#d88198",
}
local COLOR_NAMES = {}

local SHAPES = { small = S("Small Ball"), large = S("Large Ball"), star = S("Star-shaped"), creeper = S("Creeper-shaped"),
	burst = S("Burst"), }

-- Shape ingredients: Minecraft's fire charge, gold nugget, head, feather.
F.SHAPE_ITEMS = { [F.CHARGE] = "large", ["cb_items:gold_nugget"] = "star", ["mobs:chicken_feather"] = "burst", }
for _, h in ipairs({ "mobs:skull", "mobs_skeletons:skeleton_skull", "cb_blocks:skeleton_skull", "cb_blocks:dragon_head", }) do
	F.SHAPE_ITEMS[h] = "creeper"
end

local function dye_color(name)
	local d = name:match("^dye:(.+)$")
	return d and F.COLORS[d], d
end

-- Data of a star stack, or nil.
function F.star_data(stack)
	stack = ItemStack(stack)
	if stack:get_name() ~= F.STAR then
		return nil
	end
	local d = core.deserialize(stack:get_meta():get_string("cb_fw"))
	return d
end

function F.rocket_data(stack)
	stack = ItemStack(stack)
	local meta = stack:get_meta()
	return { flight = math.max(1, meta:get_int("cb_fw_flight")),
		stars = core.deserialize(meta:get_string("cb_fw_stars")) or {}, }
end

local function color_list(colors)
	local out = {}
	for _, c in ipairs(colors) do
		out[#out + 1] = COLOR_NAMES[c] or c
	end
	return table.concat(out, ", ")
end

local function star_lines(d)
	local lines = { SHAPES[d.shape] or d.shape, color_list(d.colors), }
	if d.fade and #d.fade > 0 then
		lines[#lines + 1] = S("Fade to @1", color_list(d.fade))
	end
	if d.trail then
		lines[#lines + 1] = S("Trail")
	end
	if d.twinkle then
		lines[#lines + 1] = S("Twinkle")
	end
	return lines
end

local function set_star(stack, d)
	local meta = stack:get_meta()
	meta:set_string("cb_fw", core.serialize(d))
	meta:set_string("description", S("Firework Star") .. "\n" .. core.colorize("#aaaaaa", table.concat(star_lines(d), "\n")))
	meta:set_string("color", d.colors[1])
	return stack
end

local function set_rocket(stack, flight, stars)
	local meta = stack:get_meta()
	meta:set_int("cb_fw_flight", flight)
	meta:set_string("cb_fw_stars", #stars > 0 and core.serialize(stars) or "")
	local lines = { S("Firework Rocket"), core.colorize("#aaaaaa", S("Flight Duration: @1", flight)), }
	for _, d in ipairs(stars) do
		for _, l in ipairs(star_lines(d)) do
			lines[#lines + 1] = core.colorize("#aaaaaa", "  " .. l)
		end
	end
	meta:set_string("description", table.concat(lines, "\n"))
	return stack
end
F.set_star, F.set_rocket = set_star, set_rocket

-- Items --------------------------------------------------------------------

core.register_craftitem(F.STAR, {
	description = S("Firework Star"),
	inventory_image = "cb_items_firework_star.png^(cb_items_firework_star_overlay.png^[multiply:#ffffff)",
})

local function launch_or_boost(itemstack, user, pointed)
	if not (user and user:is_player()) then
		return itemstack
	end
	local name = user:get_player_name()
	local E = cb_items.elytra
	local d = F.rocket_data(itemstack)
	if E and E.gliding(name) then
		E.boost(user, F.lifetime(d.flight), d.stars)
		F.sound("launch", user:get_pos())
	elseif pointed and pointed.type == "node" then
		local above = pointed.above
		if core.is_protected(above, name) then
			return itemstack
		end
		F.launch(vector.offset(above, 0, -0.3, 0), d, name)
	else
		return itemstack
	end
	if not core.is_creative_enabled(name) then
		itemstack:take_item(1)
	end
	return itemstack
end

core.register_craftitem(F.ROCKET, {
	description = S("Firework Rocket"),
	inventory_image = "cb_items_firework_rocket.png",
	on_place = launch_or_boost,
	on_secondary_use = launch_or_boost,
})

core.register_craftitem(F.CHARGE, {
	description = S("Fire Charge") .. "\n" .. S("Sets fire where it is used; makes large-ball firework stars"),
	inventory_image = "cb_items_fire_charge.png",
	on_place = function(itemstack, user, pointed)
		if not (pointed and pointed.type == "node" and core.registered_nodes["fire:basic_flame"]) then
			return itemstack
		end
		local name = user and user:get_player_name() or ""
		-- a node that can be lit (campfire, TNT) is lit like with flint and steel
		local under = core.registered_nodes[core.get_node(pointed.under).name]
		if under and under.on_ignite and not core.is_protected(pointed.under, name) then
			under.on_ignite(pointed.under, user)
			F.sound("charge", pointed.under)
			if not core.is_creative_enabled(name) then
				itemstack:take_item(1)
			end
			return itemstack
		end
		local pos = pointed.above
		local def = core.registered_nodes[core.get_node(pos).name]
		if core.is_protected(pos, name) or not (def and def.buildable_to) then
			return itemstack
		end
		core.set_node(pos, { name = "fire:basic_flame", })
		F.sound("charge", pos)
		if not core.is_creative_enabled(name) then
			itemstack:take_item(1)
		end
		return itemstack
	end,
})
core.register_craft({ type = "shapeless", output = F.CHARGE .. " 3",
	recipe = { "cb_items:blaze_powder", "group:coal", GUNPOWDER, }, })

-- Recipes: generated for every count that fits a 3x3 grid; on_craft works the
-- meta out of the actual grid.
for name, shape in pairs(F.SHAPE_ITEMS) do
	local def = core.registered_items[name]
	if def then
		local g = table.copy(def.groups or {})
		g.cb_fw_shape = 1
		core.override_item(name, { groups = g, })
	end
end
if core.registered_items["default:coal_lump"] then
	local g = table.copy(core.registered_items["default:coal_lump"].groups or {})
	g.coal = 1
	core.override_item("default:coal_lump", { groups = g, })
end

local function rep(t, item, n)
	for _ = 1, n do
		t[#t + 1] = item
	end
	return t
end

for k = 1, 8 do
	for _, shape in ipairs({ false, true, }) do
		for _, trail in ipairs({ false, true, }) do
			for _, twinkle in ipairs({ false, true, }) do
				local r = rep({ GUNPOWDER, }, "group:dye", k)
				if shape then r[#r + 1] = "group:cb_fw_shape" end
				if trail then r[#r + 1] = DIAMOND end
				if twinkle then r[#r + 1] = GLOW end
				if #r <= 9 then
					core.register_craft({ type = "shapeless", output = F.STAR, recipe = r, })
				end
			end
		end
	end
	core.register_craft({ type = "shapeless", output = F.STAR, recipe = rep({ F.STAR, }, "group:dye", k), })
end
for g = 1, 3 do
	for s = 0, 8 - g do
		core.register_craft({ type = "shapeless", output = F.ROCKET .. " 3", recipe = rep(rep({ PAPER, }, GUNPOWDER, g), F.STAR, s), })
	end
end

local function from_grid(stack, grid)
	local name = stack:get_name()
	if name ~= F.STAR and name ~= F.ROCKET then
		return nil
	end
	local colors, shape, trail, twinkle, gunpowder, star_in, stars = {}, "small", false, false, 0, nil, {}
	for _, st in ipairs(grid) do
		local n = st:get_name()
		local c = dye_color(n)
		if c then
			colors[#colors + 1] = c
		elseif F.SHAPE_ITEMS[n] then
			shape = F.SHAPE_ITEMS[n]
		elseif n == DIAMOND then
			trail = true
		elseif n == GLOW then
			twinkle = true
		elseif n == GUNPOWDER then
			gunpowder = gunpowder + 1
		elseif n == F.STAR then
			local d = F.star_data(st)
			if d then
				star_in = d
				stars[#stars + 1] = d
			end
		end
	end
	if name == F.ROCKET then
		return set_rocket(stack, gunpowder, stars)
	end
	if gunpowder == 0 then
		-- fading an existing star
		if not star_in then
			return ItemStack("")
		end
		local d = table.copy(star_in)
		d.fade = colors
		return set_star(stack, d)
	end
	if #colors == 0 then
		return ItemStack("")
	end
	return set_star(stack, { shape = shape, colors = colors, fade = {}, trail = trail or nil, twinkle = twinkle or nil, })
end

local function on_craft(itemstack, _, old_grid)
	return from_grid(itemstack, old_grid)
end
core.register_craft_predict(on_craft)
core.register_on_craft(on_craft)

for d, hex in pairs(F.COLORS) do
	local def = core.registered_items["dye:" .. d]
	COLOR_NAMES[hex] = def and def.description or d
end

-- Flight and burst ----------------------------------------------------------

-- Minecraft's rocket life in seconds: 10 (flight + 1) + rand(0..5) + rand(0..6) ticks.
function F.lifetime(flight, rand)
	rand = rand or math.random
	return (10 * (flight + 1) + rand(0, 5) + rand(0, 6)) / 20
end

local SOUNDS = { launch = "cb_items_firework_launch", blast = "cb_items_firework_blast",
	large_blast = "cb_items_firework_large_blast", twinkle = "cb_items_firework_twinkle",
	charge = "cb_items_firework_charge", }

function F.sound(kind, pos)
	core.sound_play(SOUNDS[kind], { pos = pos, gain = 1.0, max_hear_distance = 64, }, true)
end

local SPARK = "cb_items_firework_spark.png"

local function particle(pos, vel, color, life, size)
	core.add_particle({
		pos = pos, velocity = vel, acceleration = { x = 0, y = -1.5, z = 0, }, expirationtime = life,
		size = size or 1.6, texture = SPARK .. "^[multiply:" .. color, glow = 14, collisiondetection = false,
	})
end

-- Directions of a shape (unit-ish vectors); speed is applied later.
local function shape_dirs(shape)
	local dirs = {}
	if shape == "star" then
		for i = 0, 9 do
			local a1, a2 = i * math.pi / 5, (i + 1) * math.pi / 5
			local r1, r2 = (i % 2 == 0) and 1 or 0.45, (i % 2 == 0) and 0.45 or 1
			for t = 0, 1, 0.25 do
				local a, r = a1 + (a2 - a1) * t, r1 + (r2 - r1) * t
				dirs[#dirs + 1] = vector.new(math.sin(a) * r, math.cos(a) * r, 0)
			end
		end
	elseif shape == "creeper" then
		local face = { "#..#", "#..#", ".##.", "####", "#..#", }
		for y, row in ipairs(face) do
			for x = 1, 4 do
				if row:sub(x, x) == "#" then
					dirs[#dirs + 1] = vector.new((x - 2.5) * 0.3, (3 - y) * 0.3, 0)
				end
			end
		end
	elseif shape == "burst" then
		for _ = 1, 50 do
			local a = math.random() * 2 * math.pi
			local r = math.random() * 0.4
			dirs[#dirs + 1] = vector.new(math.cos(a) * r, 0.6 + math.random() * 0.6, math.sin(a) * r)
		end
	else
		local n = shape == "large" and 90 or 45
		for _ = 1, n do
			local v = vector.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
			dirs[#dirs + 1] = vector.normalize(v)
		end
	end
	return dirs
end

-- The burst of a rocket's stars at pos; players within 5 take Minecraft's
-- damage. Returns the number of particles (tests).
function F.explode(pos, stars, players)
	if #stars == 0 then
		return 0
	end
	local count = 0
	for _, d in ipairs(stars) do
		local speed = d.shape == "large" and 9 or 5
		for i, dir in ipairs(shape_dirs(d.shape)) do
			local color = d.colors[(i - 1) % #d.colors + 1]
			local vel = vector.multiply(dir, speed)
			particle(pos, vel, color, 1.2, d.shape == "large" and 2 or 1.6)
			count = count + 1
			if d.trail then
				particle(pos, vector.multiply(vel, 0.6), color, 1.6, 1)
			end
			if d.fade and #d.fade > 0 then
				local fc = d.fade[(i - 1) % #d.fade + 1]
				core.after(0.9, particle, vector.add(pos, vector.multiply(vel, 0.9)), vector.multiply(vel, 0.3), fc, 0.8)
			end
		end
		F.sound(d.shape == "large" and "large_blast" or "blast", pos)
		if d.twinkle then
			core.after(0.6, function()
				F.sound("twinkle", pos)
				for _ = 1, 20 do
					local v = vector.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
					particle(vector.add(pos, vector.multiply(v, 4)), vector.zero(), "#ffffff", 0.3, 1.2)
				end
			end)
		end
	end
	local damage = 5 + 2 * #stars
	for _, obj in ipairs(players or core.get_objects_inside_radius(pos, 5)) do
		if obj:is_player() then
			local dist = vector.distance(pos, obj:get_pos())
			if dist <= 5 then
				local hurt = math.floor(damage * math.sqrt((5 - dist) / 5) + 0.5)
				if hurt > 0 then
					obj:set_hp(math.max(0, obj:get_hp() - hurt), { type = "set_hp", cause = "cb_items:firework", })
				end
			end
		end
	end
	return count
end

core.register_entity(F.ENTITY, {
	initial_properties = {
		physical = true, collide_with_objects = false, pointable = false, static_save = false,
		collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1, },
		visual = "sprite", textures = { "cb_items_firework_rocket.png", }, visual_size = { x = 0.5, y = 0.5, },
	},
	on_step = function(self, dtime, moveresult)
		self._t = (self._t or 0) + dtime
		local pos = self.object:get_pos()
		local blocked = moveresult and moveresult.collides
		local node = pos and core.get_node_or_nil(pos)
		if self._t >= (self._life or 1) or blocked or not node then
			F.explode(pos, self._stars or {})
			self.object:remove()
			return
		end
		-- the rocket speeds up as it climbs (Minecraft: x1.15 + 0.04 a tick)
		local v = self.object:get_velocity()
		self.object:set_velocity(vector.new(v.x, math.min(30, v.y * (1 + 0.15 * dtime * 20 / 20) + 0.8 * dtime * 20), v.z))
		core.add_particle({ pos = pos, velocity = { x = 0, y = -2, z = 0, }, expirationtime = 0.4, size = 1,
			texture = SPARK .. "^[multiply:#ffe6a0", glow = 10, })
	end,
})

-- Launches a rocket from pos; returns the entity object.
function F.launch(pos, d, owner)
	local obj = core.add_entity(pos, F.ENTITY)
	if not obj then
		return nil
	end
	local e = obj:get_luaentity()
	e._life, e._stars, e._owner = F.lifetime(d.flight), d.stars or {}, owner
	obj:set_velocity(vector.new((math.random() - 0.5) * 0.4, 8, (math.random() - 0.5) * 0.4))
	F.sound("launch", pos)
	return obj
end
