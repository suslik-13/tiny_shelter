-- Shulker boxes (spec 8): 27 slots that travel with the box. Digging (or a
-- blast) turns the box into an item carrying its contents in item meta;
-- placing it back restores them. Boxes never go inside boxes. A plain box is
-- purple; dye gives one of 16 colours and keeps the contents.
local S = cb_blocks.S
local COLORS = { "white", "orange", "magenta", "light_blue", "yellow", "lime", "pink", "gray", "light_gray", "cyan",
	"purple", "blue", "brown", "green", "red", "black", }
cb_blocks.SHULKER_COLORS = COLORS
local NAMES = {
	white = S("White Shulker Box"), orange = S("Orange Shulker Box"), magenta = S("Magenta Shulker Box"),
	light_blue = S("Light Blue Shulker Box"), yellow = S("Yellow Shulker Box"), lime = S("Lime Shulker Box"),
	pink = S("Pink Shulker Box"), gray = S("Gray Shulker Box"), light_gray = S("Light Gray Shulker Box"),
	cyan = S("Cyan Shulker Box"), purple = S("Purple Shulker Box"), blue = S("Blue Shulker Box"),
	brown = S("Brown Shulker Box"), green = S("Green Shulker Box"), red = S("Red Shulker Box"),
	black = S("Black Shulker Box"),
}
-- minetest_game dyes for each colour (light_blue: blue + white).
local DYES = {
	white = { "dye:white", }, orange = { "dye:orange", }, magenta = { "dye:magenta", },
	light_blue = { "dye:blue", "dye:white", }, yellow = { "dye:yellow", }, lime = { "dye:green", },
	pink = { "dye:pink", }, gray = { "dye:dark_grey", }, light_gray = { "dye:grey", }, cyan = { "dye:cyan", },
	purple = { "dye:violet", }, blue = { "dye:blue", }, brown = { "dye:brown", }, green = { "dye:dark_green", },
	red = { "dye:red", }, black = { "dye:black", },
}
local SIZE = 27

local function formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	return "size[9,8.5]" .. "list[nodemeta:" .. spos .. ";main;0,0.3;9,3;]"
		.. "list[current_player;main;0,4.35;9,1;]list[current_player;main;0,5.58;9,3;9]"
		.. "listring[nodemeta:" .. spos .. ";main]listring[current_player;main]"
		.. (default.get_hotbar_bg and default.get_hotbar_bg(0, 4.35) or "")
end

function cb_blocks.shulker_count(stack)
	local list = core.deserialize(stack:get_meta():get_string("cb_box")) or {}
	local n = 0
	for _, s in ipairs(list) do
		n = n + ItemStack(s):get_count()
	end
	return n
end

local function describe(stack)
	local n = cb_blocks.shulker_count(stack)
	local meta = stack:get_meta()
	if n > 0 then
		local base = core.registered_items[stack:get_name()].description
		meta:set_string("description", base .. "\n" .. S("@1 items inside", n))
	else
		meta:set_string("description", "")
	end
end

function cb_blocks.shulker_item(pos)
	local node = core.get_node(pos)
	local stack = ItemStack(node.name)
	local list = {}
	for i, s in ipairs(core.get_meta(pos):get_inventory():get_list("main") or {}) do
		list[i] = s:to_string()
	end
	stack:get_meta():set_string("cb_box", core.serialize(list))
	describe(stack)
	return stack
end

function cb_blocks.shulker_restore(pos, stack)
	local list = core.deserialize(stack:get_meta():get_string("cb_box")) or {}
	local inv = core.get_meta(pos):get_inventory()
	for i = 1, SIZE do
		inv:set_stack("main", i, list[i] or "")
	end
end

local function register(name, desc, texture)
	core.register_node(name, {
		description = desc,
		drawtype = "mesh",
		mesh = "cb_blocks_shulker_box.obj",
		tiles = { texture, },
		paramtype = "light",
		is_ground_content = false,
		stack_max = 1,
		groups = { cracky = 2, shulker_box = 1, },
		sounds = default.node_sound_stone_defaults(),
		drop = "",
		on_construct = function(pos)
			local meta = core.get_meta(pos)
			meta:get_inventory():set_size("main", SIZE)
			meta:set_string("formspec", formspec(pos))
			meta:set_string("infotext", desc)
		end,
		after_place_node = function(pos, _, itemstack)
			cb_blocks.shulker_restore(pos, itemstack)
		end,
		on_dig = function(pos, node, digger)
			local name = digger and digger:get_player_name() or ""
			if core.is_protected(pos, name) then
				core.record_protection_violation(pos, name)
				return false
			end
			local item = cb_blocks.shulker_item(pos)
			core.remove_node(pos)
			local inv = digger and digger:get_inventory()
			if inv and inv:room_for_item("main", item) then
				inv:add_item("main", item)
			else
				core.add_item(pos, item)
			end
			return true
		end,
		on_blast = function(pos)
			local item = cb_blocks.shulker_item(pos)
			core.remove_node(pos)
			return { item:to_string(), }
		end,
		allow_metadata_inventory_put = function(pos, _, _, stack, player)
			if core.get_item_group(stack:get_name(), "shulker_box") > 0 then
				return 0
			end
			if player and core.is_protected(pos, player:get_player_name()) then
				return 0
			end
			return stack:get_count()
		end,
		allow_metadata_inventory_take = function(pos, _, _, stack, player)
			if player and core.is_protected(pos, player:get_player_name()) then
				return 0
			end
			return stack:get_count()
		end,
	})
end

register("cb_blocks:shulker_box", S("Shulker Box"), "cb_blocks_shulker_purple.png")
for _, c in ipairs(COLORS) do
	register("cb_blocks:shulker_box_" .. c, NAMES[c], "cb_blocks_shulker_" .. c .. ".png")
	local recipe = { "group:shulker_box", }
	for _, d in ipairs(DYES[c]) do
		recipe[#recipe + 1] = d
	end
	core.register_craft({ type = "shapeless", output = "cb_blocks:shulker_box_" .. c, recipe = recipe, })
end

core.register_craft({
	output = "cb_blocks:shulker_box",
	recipe = { { "cb_items:shulker_shell", }, { "default:chest", }, { "cb_items:shulker_shell", }, },
})

-- A dyed box keeps what was inside.
function cb_blocks.shulker_on_craft(itemstack, _, old_grid)
	if core.get_item_group(itemstack:get_name(), "shulker_box") == 0 then
		return nil
	end
	for _, s in ipairs(old_grid) do
		if core.get_item_group(s:get_name(), "shulker_box") > 0 then
			itemstack:get_meta():set_string("cb_box", s:get_meta():get_string("cb_box"))
			describe(itemstack)
			return itemstack
		end
	end
	return nil
end
core.register_on_craft(cb_blocks.shulker_on_craft)
