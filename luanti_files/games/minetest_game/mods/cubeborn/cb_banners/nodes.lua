-- Standing (16 directions) and wall banners. The node is a thin pole or plate
-- holding the banner item in meta (cb_item, cb_rot); the picture is one
-- entity per node, not saved (an LBM puts it back when the block loads).
local B = cb_banners
local STAND, WALL, PIC = "cb_banners:standing", "cb_banners:wall", "cb_banners:picture"
local OFFSET = { [STAND] = vector.new(0, -0.499, 0), [WALL] = vector.new(0, -0.64, 0), }
local MESH = { [STAND] = "cb_banners_banner.b3d", [WALL] = "cb_banners_banner_hanging.b3d", }

local function yaw_of(rot)
	return rot * math.pi / 8 + math.pi
end

-- The node keeps the item without what B.refresh rebuilds (description and
-- icons): a few dozen bytes.
function B.stored(pos)
	local st = ItemStack(core.get_meta(pos):get_string("cb_item"))
	return st:is_empty() and st or B.refresh(st)
end

local function compact(stack)
	local one = ItemStack(stack)
	one:set_count(1)
	local m = one:get_meta()
	m:set_string("description", "")
	m:set_string("inventory_image", "")
	m:set_string("wield_image", "")
	return one:to_string()
end

function B.picture(pos)
	local node = core.get_node(pos)
	local off = OFFSET[node.name] or OFFSET[STAND]
	for _, obj in ipairs(core.get_objects_inside_radius(vector.add(pos, off), 0.5)) do
		local e = obj:get_luaentity()
		if e and e.name == PIC then
			return obj
		end
	end
end

function B.show(pos, force)
	local node = core.get_node(pos)
	if not OFFSET[node.name] then
		return nil
	end
	local old = B.picture(pos)
	if old and not force then
		return old
	end
	if old then
		old:remove()
	end
	local item = B.stored(pos)
	local def = core.registered_items[item:get_name()]
	if not def or not def._cb_colour then
		return nil
	end
	local obj = core.add_entity(vector.add(pos, OFFSET[node.name]), PIC)
	if obj then
		obj:set_properties({ mesh = MESH[node.name], textures = { B.texture(def._cb_colour, B.layers(item)), }, })
		obj:set_yaw(yaw_of(core.get_meta(pos):get_int("cb_rot")))
	end
	return obj
end

core.register_entity(PIC, {
	initial_properties = {
		physical = false, collide_with_objects = false, pointable = false, static_save = false,
		visual = "mesh", mesh = MESH[STAND], visual_size = { x = 2.499, y = 2.499, },
		textures = { "cb_banners_banner_base.png", },
	},
	on_activate = function(self)
		self.object:set_animation({ x = 0, y = 80, }, 25)
		self.object:set_armor_groups({ immortal = 1, })
	end,
})

-- Drops go through preserve_metadata (digging and a lost support both call
-- it) and on_blast, never through on_destruct: pistons and movers remove and
-- set the node with its meta, which must not copy the banner.
local function preserve_metadata(_, _, oldmeta, drops)
	local st = ItemStack(oldmeta.cb_item or "")
	if not st:is_empty() then
		drops[#drops + 1] = B.refresh(st)
	end
end

local function on_destruct(pos)
	local pic = B.picture(pos)
	if pic then
		pic:remove()
	end
end

local function on_blast(pos)
	local item = B.stored(pos)
	core.remove_node(pos)
	return item:is_empty() and {} or { item:to_string(), }
end

local function node(name, def)
	def.walkable, def.is_ground_content, def.paramtype, def.sunlight_propagates = false, false, "light", true
	def.drawtype, def.tiles, def.drop = "nodebox", { "cb_banners_fallback_wood.png", }, ""
	def.groups = { choppy = 2, oddly_breakable_by_hand = 3, attached_node = 1, not_in_creative_inventory = 1, cb_banner = 1, }
	def.sounds = default.node_sound_wood_defaults()
	def.preserve_metadata, def.on_destruct, def.on_blast, def.on_rotate = preserve_metadata, on_destruct, on_blast, false
	def.on_punch = function(pos)
		B.show(pos)
	end
	core.register_node(name, def)
end

node(STAND, {
	description = "Banner",
	node_box = { type = "fixed", fixed = { -1 / 32, -0.49, -1 / 32, 1 / 32, 1.49, 1 / 32, }, },
	selection_box = { type = "fixed", fixed = { -0.3, -0.5, -0.3, 0.3, 0.5, 0.3, }, },
})
node(WALL, {
	description = "Wall Banner",
	paramtype2 = "wallmounted",
	node_box = { type = "wallmounted", wall_side = { -0.49, 0.41, -0.49, -0.41, 0.49, 0.49, },
		wall_top = { -0.49, 0.41, -0.49, -0.41, 0.49, 0.49, }, wall_bottom = { -0.49, -0.49, -0.49, -0.41, -0.41, 0.49, }, },
	selection_box = { type = "wallmounted", wall_side = { -0.5, -0.5, -0.5, -4 / 16, 0.5, 0.5, }, },
})

function B.place(itemstack, placer, pointed)
	if not pointed or pointed.type ~= "node" then
		return itemstack
	end
	local under, above = pointed.under, pointed.above
	local unode = core.get_node(under)
	local udef = core.registered_nodes[unode.name]
	local ctrl = placer and placer.get_player_control and placer:get_player_control() or {}
	if udef and udef.on_rightclick and not ctrl.sneak then
		return udef.on_rightclick(under, unode, placer, itemstack, pointed) or itemstack
	end
	if under.y > above.y then
		return itemstack -- not on a ceiling
	end
	local name = placer and placer:get_player_name() or ""
	local target = udef and udef.buildable_to and under or above
	if core.is_protected(target, name) then
		core.record_protection_violation(target, name)
		return itemstack
	end
	local wall = under.y == above.y
	local _, at = core.item_place_node(ItemStack(wall and WALL or STAND), placer, pointed)
	if not at then
		return itemstack
	end
	local one = ItemStack(itemstack)
	one:set_count(1)
	local meta = core.get_meta(at)
	meta:set_string("cb_item", compact(one))
	local rot
	if wall then
		local d = vector.direction(under, above)
		rot = d.x > 0 and 4 or d.z > 0 and 8 or d.x < 0 and 12 or 0
	else
		local yaw = placer and placer.get_look_horizontal and placer:get_look_horizontal() or 0
		rot = math.floor(yaw / (math.pi * 2) * 16 + 0.5) % 16
	end
	meta:set_int("cb_rot", rot)
	B.show(at, true)
	if not core.is_creative_enabled(name) then
		itemstack:take_item()
	end
	return itemstack
end

for colour in pairs(B.COLOURS) do
	if core.registered_items[B.item(colour)] then
		core.override_item(B.item(colour), { on_place = B.place, })
	end
end

-- pistons (mesecons) move the node with its meta: the picture follows
if rawget(_G, "mesecon") and mesecon.register_on_mvps_move then
	mesecon.register_on_mvps_move(function(moved)
		for _, m in ipairs(moved) do
			if m.node and OFFSET[m.node.name] then
				B.show(m.pos, true)
			end
		end
	end)
end

core.register_lbm({
	label = "Cubeborn banner pictures",
	name = "cb_banners:pictures",
	nodenames = { STAND, WALL, },
	run_at_every_load = true,
	action = function(pos)
		B.show(pos)
	end,
})
