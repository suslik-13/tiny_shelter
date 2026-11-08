-- Temple traps (spec cycle 2, 4.3-4.4), none of them obtainable: the hidden
-- pressure plate lights the TNT under it; the dispenser shoots an arrow (an
-- entity, never an item) at players in front of it; levers open the hidden
-- door when all of them near it are on. Plates and dispensers watch with a
-- node timer (only in active blocks): 0.5 s and 1 s.
local S = cb_structures.S
local TR = { DISPENSER_RANGE = 5, DISPENSER_COOLDOWN = 3, ARROW_DAMAGE = 3, PUZZLE_RADIUS = 8, }
cb_structures.traps = TR

local LOCKED = { diggable = false, drop = "", on_blast = function() end, is_ground_content = false, }

local function locked(def)
	for k, v in pairs(LOCKED) do
		def[k] = v
	end
	def.groups = def.groups or {}
	def.groups.not_in_creative_inventory = 1
	return def
end

function TR.ignite(pos)
	local n = 0
	if not core.registered_nodes["tnt:tnt_burning"] then
		return 0
	end
	for _, p in ipairs(core.find_nodes_in_area(vector.offset(pos, -2, -4, -2), vector.offset(pos, 2, 0, 2), { "tnt:tnt", })) do
		core.set_node(p, { name = "tnt:tnt_burning", })
		n = n + 1
	end
	return n
end

function TR.plate_tick(pos)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.9)) do
		if obj:is_player() then
			TR.ignite(pos)
			return true
		end
	end
	return false
end

core.register_node("cb_structures:trap_plate", locked({
	description = S("Pressure Plate"),
	drawtype = "nodebox",
	tiles = { "default_sandstone.png", },
	paramtype = "light",
	walkable = false,
	node_box = { type = "fixed", fixed = { -7 / 16, -8 / 16, -7 / 16, 7 / 16, -7.5 / 16, 7 / 16, }, },
	on_construct = function(pos)
		core.get_node_timer(pos):start(0.5)
	end,
	on_timer = function(pos)
		TR.plate_tick(pos)
		return true
	end,
}))

if core.global_exists("mobs") then
	local function hit(self, obj)
		obj:punch(self.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = TR.ARROW_DAMAGE, }, }, nil)
	end
	mobs:register_arrow("cb_structures:trap_arrow", {
		visual = "sprite",
		visual_size = { x = 0.5, y = 0.5, },
		textures = { "default_stick.png", },
		velocity = 16,
		hit_player = hit,
		hit_mob = hit,
		hit_node = function() end,
	})
end

-- Shoots where the front (-Z face) looks.
function TR.dispenser_dir(pos)
	return vector.multiply(core.facedir_to_dir(core.get_node(pos).param2 % 32), -1)
end

function TR.dispenser_fire(pos)
	if not core.registered_entities["cb_structures:trap_arrow"] then
		return nil
	end
	local dir = TR.dispenser_dir(pos)
	local obj = core.add_entity(vector.add(pos, vector.multiply(dir, 0.8)), "cb_structures:trap_arrow")
	local ent = obj and obj:get_luaentity()
	if ent then
		ent.switch, ent.owner_id = 1, "cb_structures:trap"
		obj:set_velocity(vector.multiply(dir, 16))
	end
	return obj
end

local function dispenser_tick(pos)
	local meta = core.get_meta(pos)
	if meta:get_float("next") > core.get_gametime() then
		return
	end
	local dir = TR.dispenser_dir(pos)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, TR.DISPENSER_RANGE)) do
		if obj:is_player() then
			local to = vector.direction(pos, obj:get_pos())
			if vector.dot(to, dir) > 0.8 then
				TR.dispenser_fire(pos)
				meta:set_float("next", core.get_gametime() + TR.DISPENSER_COOLDOWN)
				return
			end
		end
	end
end

core.register_node("cb_structures:trap_dispenser", locked({
	description = S("Dispenser"),
	tiles = { "default_cobble.png", "default_cobble.png", "default_cobble.png", "default_cobble.png",
		"default_cobble.png", "default_cobble.png^default_furnace_front.png", },
	paramtype2 = "facedir",
	on_construct = function(pos)
		core.get_node_timer(pos):start(1)
	end,
	on_timer = function(pos)
		dispenser_tick(pos)
		return true
	end,
}))

core.register_node("cb_structures:temple_door", locked({
	description = S("Mossy Cobblestone"),
	tiles = { "default_mossycobble.png", },
}))

local LEVER_BOX = { type = "fixed", fixed = { -3 / 16, -8 / 16, -3 / 16, 3 / 16, -2 / 16, 3 / 16, }, }

function TR.toggle_lever(pos)
	local node = core.get_node(pos)
	local on = node.name == "cb_structures:temple_lever"
	core.swap_node(pos, { name = on and "cb_structures:temple_lever_on" or "cb_structures:temple_lever",
		param2 = node.param2, })
	local r = TR.PUZZLE_RADIUS
	local a, b = vector.offset(pos, -r, -r, -r), vector.offset(pos, r, r, r)
	if #core.find_nodes_in_area(a, b, { "cb_structures:temple_lever", }) == 0 then
		for _, p in ipairs(core.find_nodes_in_area(a, b, { "cb_structures:temple_door", })) do
			core.remove_node(p)
		end
	end
end

for _, on in ipairs({ false, true, }) do
	core.register_node(on and "cb_structures:temple_lever_on" or "cb_structures:temple_lever", locked({
		description = S("Lever"),
		drawtype = "nodebox",
		tiles = { on and "default_stone.png^[colorize:#40ff40:60" or "default_stone.png", },
		paramtype = "light",
		paramtype2 = "facedir",
		node_box = LEVER_BOX,
		selection_box = LEVER_BOX,
		walkable = false,
		on_rightclick = function(pos, _, _, itemstack)
			TR.toggle_lever(pos)
			return itemstack
		end,
	}))
end

cb_structures.piecegen.CONSTRUCT["cb_structures:trap_plate"] = true
cb_structures.piecegen.CONSTRUCT["cb_structures:trap_dispenser"] = true
