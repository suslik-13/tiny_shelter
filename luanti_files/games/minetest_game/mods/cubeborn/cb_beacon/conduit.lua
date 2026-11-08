-- Conduit (spec cycle 10): in water inside a frame of prismarine blocks. The
-- frame cells are the rims of the three 5x5 squares through the conduit (42
-- cells); 16 blocks wake it up, every 7 blocks reach 16 nodes further (max
-- 96). Players in water within reach get Conduit Power; a full frame also
-- hurts one hostile mob in water within 8 every 2 s. Node timer, 2 s.
local S = cb_beacon.S
local B = cb_beacon
local E = cb_core.effects
B.CONDUIT, B.HEART = "cb_beacon:conduit", "cb_items:heart_of_the_sea"
B.CONDUIT_PERIOD, B.CONDUIT_DURATION, B.CONDUIT_DAMAGE = 2, 11, 4

B.FRAME = {}
for _, n in ipairs({ "cb_blocks:prismarine", "cb_blocks:prismarine_bricks", "cb_blocks:dark_prismarine",
		"cb_blocks:sea_lantern", }) do
	if core.registered_nodes[n] then
		B.FRAME[n] = true
	end
end

-- The 42 frame offsets.
B.FRAME_CELLS = {}
for x = -2, 2 do
	for y = -2, 2 do
		for z = -2, 2 do
			local zeros = (x == 0 and 1 or 0) + (y == 0 and 1 or 0) + (z == 0 and 1 or 0)
			local rim = math.max(math.abs(x), math.abs(y), math.abs(z)) == 2
			if rim and zeros >= 1 then
				-- on a centre plane and on its 5x5 rim
				local ok = false
				if x == 0 then ok = ok or math.max(math.abs(y), math.abs(z)) == 2 end
				if y == 0 then ok = ok or math.max(math.abs(x), math.abs(z)) == 2 end
				if z == 0 then ok = ok or math.max(math.abs(x), math.abs(y)) == 2 end
				if ok then
					B.FRAME_CELLS[#B.FRAME_CELLS + 1] = vector.new(x, y, z)
				end
			end
		end
	end
end

local function water(name)
	return core.get_item_group(name, "water") > 0
end

function B.conduit_frame(pos)
	local n = 0
	for _, o in ipairs(B.FRAME_CELLS) do
		local node = core.get_node_or_nil(vector.add(pos, o))
		if node and B.FRAME[node.name] then
			n = n + 1
		end
	end
	return n
end

-- Awake: 16+ frame blocks and water all around (the 3x3x3 but the conduit).
function B.conduit_active(pos)
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				if x ~= 0 or y ~= 0 or z ~= 0 then
					local node = core.get_node_or_nil(vector.offset(pos, x, y, z))
					if not node or not water(node.name) then
						return false
					end
				end
			end
		end
	end
	return B.conduit_frame(pos) >= 16
end

local function in_water(obj)
	local p = obj:get_pos()
	local node = p and core.get_node_or_nil(vector.round(vector.offset(p, 0, 0.5, 0)))
	return node ~= nil and water(node.name)
end

-- Players near pos (tests replace it).
function B.conduit_players(pos, range)
	local list = {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, range)) do
		if obj:is_player() then
			list[#list + 1] = obj
		end
	end
	return list
end

function B.conduit_tick(pos)
	if not B.conduit_active(pos) then
		return true
	end
	local frame = B.conduit_frame(pos)
	local range = 16 * math.floor(frame / 7)
	for _, player in ipairs(B.conduit_players(pos, range)) do
		if in_water(player) then
			E.apply(player, "conduit_power", 1, B.CONDUIT_DURATION)
		end
	end
	if frame >= 42 then
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 8)) do
			local e = obj:get_luaentity()
			if e and e.type == "monster" and (e.health or 0) > 0 and in_water(obj) then
				obj:punch(obj, 1.0, { full_punch_interval = 1.0, damage_groups = { fleshy = B.CONDUIT_DAMAGE, }, })
				break
			end
		end
	end
	return true
end

core.register_node(B.CONDUIT, {
	description = S("Conduit") .. "\n" .. S("In water, inside a frame of prismarine: breath, light and speed under water"),
	drawtype = "nodebox", paramtype = "light", sunlight_propagates = true,
	node_box = { type = "fixed", fixed = { -3 / 16, -3 / 16, -3 / 16, 3 / 16, 3 / 16, 3 / 16, }, },
	tiles = { "cb_beacon_conduit_node.png", }, inventory_image = "cb_beacon_conduit.png", wield_image = "cb_beacon_conduit.png",
	light_source = 15, is_ground_content = false, groups = { cracky = 3, oddly_breakable_by_hand = 2, },
	sounds = default.node_sound_glass_defaults(),
	on_construct = function(pos)
		core.get_node_timer(pos):start(B.CONDUIT_PERIOD)
	end,
	on_timer = function(pos)
		return B.conduit_tick(pos)
	end,
})

core.register_lbm({
	label = "Cubeborn conduit timers",
	name = "cb_beacon:conduit_restart",
	nodenames = { B.CONDUIT, },
	run_at_every_load = true,
	action = function(pos)
		local t = core.get_node_timer(pos)
		if not t:is_started() then
			t:start(B.CONDUIT_PERIOD)
		end
	end,
})

core.register_craftitem(":" .. B.HEART, {
	description = S("Heart of the Sea"),
	inventory_image = "cb_beacon_heart_of_the_sea.png",
})

local shell = "cb_mobs_water:nautilus_shell"
core.register_craft({
	output = B.CONDUIT,
	recipe = { { shell, shell, shell, }, { shell, B.HEART, shell, }, { shell, shell, shell, }, },
})

-- Minecraft keeps the heart in buried treasure, which this pack has not: the
-- shipwreck treasure chest always holds one, big ocean ruin chests sometimes.
local loot = rawget(_G, "cb_structures") and cb_structures.loot
if loot and loot.add_pool then
	loot.add_pool("shipwreck_treasure", { rolls = { 1, 1, }, entries = { { items = { B.HEART, }, w = 1, }, }, })
	loot.add_pool("underwater_ruin_big", { rolls = { 1, 1, }, entries = { { w = 19, }, { items = { B.HEART, }, w = 1, }, }, })
end
