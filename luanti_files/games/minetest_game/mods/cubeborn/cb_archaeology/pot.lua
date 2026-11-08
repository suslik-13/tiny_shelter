-- Decorated pot (spec cycle 9, 4.3), adapted from Mineclonia
-- mcl_pottery_sherds (GPLv3): crafted from four sherds or clay bricks, each
-- side shows its sherd, holds one kind of item up to a stack, dug -> drops
-- itself whole and spills the contents.
-- Faces are kept as "back,right,front,left" (empty = brick) in item and node
-- meta; the pictures are one unsaved cube entity per pot, made again by an
-- LBM when the block loads (no on_step, no globalstep).
local A = cb_archaeology
local S = A.S

local POT, PIC = "cb_archaeology:decorated_pot", "cb_archaeology:pot_picture"
local FACES, ITEM = "cb_archaeology:faces", "cb_archaeology:item"
local BRICK = "default:clay_brick"
A.POT = POT

local potbox = {
	type = "fixed",
	fixed = {
		{ -4 / 16, 9 / 16, -4 / 16, 4 / 16, 12 / 16, 4 / 16, },
		{ -3 / 16, 8 / 16, -3 / 16, 3 / 16, 9 / 16, 3 / 16, },
		{ -7 / 16, -8 / 16, -7 / 16, 7 / 16, 8 / 16, 7 / 16, },
	},
}

local function parse(s)
	local out, i = {}, 0
	for part in ((s or "") .. ","):gmatch("([^,]*),") do
		i = i + 1
		if i > 4 then
			break
		end
		out[i] = A.SHERD_SET[part] and part or false
	end
	for k = i + 1, 4 do
		out[k] = false
	end
	return out
end

-- { back, right, front, left }: sherd names or false (brick).
function A.pot_faces(stack_or_meta)
	local meta = stack_or_meta.get_meta and stack_or_meta:get_meta() or stack_or_meta
	return parse(meta:get_string(FACES))
end

local function faced(faces)
	for i = 1, 4 do
		if faces[i] then
			return true
		end
	end
	return false
end

local function encode(faces)
	local t = {}
	for i = 1, 4 do
		t[i] = faces[i] or ""
	end
	return table.concat(t, ",")
end

local function pattern(name)
	return name and ("cb_archaeology_pattern_" .. name .. ".png") or "blank.png"
end

local function face_desc(name)
	if not name then
		return S("Brick")
	end
	local def = core.registered_items["cb_archaeology:sherd_" .. name]
	return (def and def.description or name):match("^[^\n]*")
end

-- Writes faces and the matching description/overlay into an item stack.
local function set_item_faces(stack, faces)
	local meta = stack:get_meta()
	if not faced(faces) then
		for _, k in ipairs({ FACES, "description", "inventory_overlay", "wield_overlay", }) do
			meta:set_string(k, "")
		end
		return stack
	end
	meta:set_string(FACES, encode(faces))
	local lines = { S("Decorated Pot"), }
	for i = 1, 4 do
		lines[#lines + 1] = core.colorize("#55ff55", face_desc(faces[i]))
	end
	meta:set_string("description", table.concat(lines, "\n"))
	-- inventorycube(top, left, right): front and right sides as seen in the inventory.
	local img = core.inventorycube("blank.png", pattern(faces[3]), pattern(faces[2]))
	meta:set_string("inventory_overlay", img)
	meta:set_string("wield_overlay", img)
	return stack
end

function A.pot_item(faces)
	return set_item_faces(ItemStack(POT), faces or {})
end

local function picture(pos)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.3)) do
		local e = obj:get_luaentity()
		if e and e.name == PIC then
			return obj
		end
	end
end

function A.pot_picture(pos)
	return picture(pos)
end

-- Cube textures in Luanti order: +Y, -Y, +X, -X, +Z, -Z.
local SIDE = { [0] = 5, [1] = 3, [2] = 6, [3] = 4, } -- fourdir -> texture index

local function pot_textures(faces, param2)
	local tex = { "blank.png", "blank.png", "blank.png", "blank.png", "blank.png", "blank.png", }
	for k = 1, 4 do
		tex[SIDE[(param2 + k - 1) % 4]] = pattern(faces[k])
	end
	return tex
end

local function show(pos)
	local old = picture(pos)
	if old then
		old:remove()
	end
	local node = core.get_node(pos)
	if node.name ~= POT then
		return nil
	end
	local faces = A.pot_faces(core.get_meta(pos))
	if not faced(faces) then
		return nil
	end
	local obj = core.add_entity(pos, PIC)
	if obj then
		obj:set_properties({ textures = pot_textures(faces, node.param2 % 4), })
	end
	return obj
end
A.pot_show = show

core.register_entity(PIC, {
	initial_properties = {
		physical = false, collide_with_objects = false, pointable = false, static_save = false,
		visual = "cube", visual_size = { x = 14.04 / 16, y = 1.002, z = 14.04 / 16, },
		use_texture_alpha = true, backface_culling = true,
		textures = { "blank.png", "blank.png", "blank.png", "blank.png", "blank.png", "blank.png", },
	},
	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1, })
	end,
})

-- Stored contents.
function A.pot_stored(pos)
	return ItemStack(core.get_meta(pos):get_string(ITEM))
end

local function short_desc(stack)
	local d = stack:get_short_description()
	return d ~= "" and d or stack:get_name()
end

local function set_stored(pos, stack)
	local meta = core.get_meta(pos)
	meta:set_string(ITEM, stack:is_empty() and "" or stack:to_string())
	meta:set_string("infotext", stack:is_empty() and S("Decorated Pot")
		or S("Decorated Pot") .. "\n" .. S("@1 × @2", stack:get_count(), short_desc(stack)))
end

local function drop_all(pos, oldmeta, digger)
	local fields = oldmeta and oldmeta.fields or {}
	local faces = parse(fields[FACES])
	core.handle_node_drops(pos, { A.pot_item(faces), }, digger)
	local stored = ItemStack(fields[ITEM] or "")
	if not stored:is_empty() then
		core.add_item(pos, stored)
	end
end

core.register_node(POT, {
	description = S("Decorated Pot"),
	drawtype = "nodebox",
	node_box = potbox,
	selection_box = potbox,
	collision_box = potbox,
	tiles = {
		{ name = "cb_archaeology_pot_top.png", align_style = "world", },
		{ name = "cb_archaeology_pot_bottom.png", align_style = "world", },
		{ name = "cb_archaeology_pot_side.png", align_style = "world", },
	},
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "4dir",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = { cracky = 3, oddly_breakable_by_hand = 3, },
	sounds = default.node_sound_stone_defaults(),
	drop = "",
	on_construct = function(pos)
		set_stored(pos, ItemStack(""))
	end,
	after_place_node = function(pos, _, itemstack)
		local faces = A.pot_faces(itemstack)
		if faced(faces) then
			core.get_meta(pos):set_string(FACES, encode(faces))
		end
		show(pos)
	end,
	on_destruct = function(pos)
		local old = picture(pos)
		if old then
			old:remove()
		end
	end,
	after_dig_node = function(pos, _, oldmeta, digger)
		drop_all(pos, oldmeta, digger)
	end,
	on_blast = function(pos)
		local oldmeta = core.get_meta(pos):to_table()
		core.remove_node(pos)
		drop_all(pos, oldmeta, nil)
	end,
	on_rightclick = function(pos, _, clicker, itemstack)
		if itemstack:is_empty() then
			return itemstack
		end
		local name = clicker and clicker:get_player_name() or ""
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return itemstack
		end
		local stored = A.pot_stored(pos)
		local one = ItemStack(itemstack)
		one:set_count(1)
		if stored:is_empty() then
			stored = one
		else
			-- Same item: equal as single items (name, wear and meta).
			local probe = ItemStack(stored)
			probe:set_count(1)
			if probe:to_string() ~= one:to_string() or stored:get_count() >= stored:get_stack_max() then
				return itemstack
			end
			stored:set_count(stored:get_count() + 1)
		end
		set_stored(pos, stored)
		if not core.is_creative_enabled(name) then
			itemstack:take_item(1)
		end
		core.sound_play("default_place_node_hard", { pos = pos, gain = 0.5, }, true)
		return itemstack
	end,
	on_rotate = function(pos, node, _, mode, new_param2)
		if mode ~= 1 then
			return false
		end
		node.param2 = new_param2 % 4
		core.swap_node(pos, node)
		show(pos)
		return true
	end,
})

-- Pistons (mesecons) move the node with its meta: the picture follows.
if rawget(_G, "mesecon") and mesecon.register_on_mvps_move then
	mesecon.register_on_mvps_move(function(moved)
		for _, m in ipairs(moved) do
			if m.node and m.node.name == POT then
				local old = m.oldpos and picture(m.oldpos)
				if old then
					old:remove()
				end
				show(m.pos)
			end
		end
	end)
end

core.register_lbm({
	label = "Cubeborn decorated pot pictures",
	name = "cb_archaeology:pot_pictures",
	nodenames = { POT, },
	run_at_every_load = true,
	action = function(pos)
		show(pos)
	end,
})

-- Crafting: a diamond of sherds or clay bricks; craft top -> back,
-- right -> right, bottom -> front, left -> left.
do
	local def = core.registered_items[BRICK]
	if def then
		local g = table.copy(def.groups or {})
		g.cb_pot_recipe = 1
		core.override_item(BRICK, { groups = g, })
	end
end

core.register_craft({
	output = POT,
	recipe = {
		{ "", "group:cb_pot_recipe", "", },
		{ "group:cb_pot_recipe", "", "group:cb_pot_recipe", },
		{ "", "group:cb_pot_recipe", "", },
	},
})

local function sherd_of(stack)
	local def = core.registered_items[ItemStack(stack):get_name()]
	return def and def._cb_sherd or false
end

local function on_craft(itemstack, _, old_craft_grid)
	if itemstack:get_name() ~= POT or #old_craft_grid < 9 then
		return nil
	end
	local faces = {
		sherd_of(old_craft_grid[2]), sherd_of(old_craft_grid[6]),
		sherd_of(old_craft_grid[8]), sherd_of(old_craft_grid[4]),
	}
	return set_item_faces(itemstack, faces)
end
core.register_craft_predict(on_craft)
core.register_on_craft(on_craft)
