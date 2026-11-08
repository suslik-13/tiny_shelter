------------------------------------------------------------------------
-- Bundles (plain and 16 dyed colours).
-- Bedrock rules: a bundle holds items up to a total weight of 64, where
-- an item weighs 64 / its stack size (a full stack of 64 fills it, one
-- unstackable item fills it), a nested bundle weighs 4 plus its
-- contents, and shulker boxes cannot be put inside.
--
-- Inventory interaction (Luanti has no cursor callbacks, so moves are
-- intercepted): drop an item onto a bundle to put it in, drop a bundle
-- onto an item to pick that item up.  Using a bundle in the world drops
-- out its contents one stack at a time (as in Bedrock); using it while
-- sneaking opens a window where any stack can be taken out.
------------------------------------------------------------------------

local S = cb_items.S

local MAX_WEIGHT = 64
local BUNDLE_WEIGHT = 4
local META_KEY = "cb_items:bundle_contents"
local VISIBLE_ENTRIES = 12

cb_items.bundles = {}

local function is_bundle (name)
	return core.get_item_group (name, "bundle") > 0
end

local function get_contents (stack)
	local raw = stack:get_meta ():get_string (META_KEY)
	local list = raw ~= "" and core.deserialize (raw) or nil
	local contents = {}
	for _, s in ipairs (list or {}) do
		local item = ItemStack (s)
		if not item:is_empty () then
			table.insert (contents, item)
		end
	end
	return contents
end

local item_weight

local function contents_weight (contents)
	local total = 0
	for _, item in ipairs (contents) do
		total = total + item_weight (item) * item:get_count ()
	end
	return total
end

-- Weight of one item from STACK.
function item_weight (stack)
	if is_bundle (stack:get_name ()) then
		return BUNDLE_WEIGHT + contents_weight (get_contents (stack))
	end
	local max = stack:get_stack_max ()
	if max < 1 then
		max = 1
	end
	return math.ceil (MAX_WEIGHT / max)
end

local function can_store (stack)
	if stack:is_empty () then
		return false
	end
	local name = stack:get_name ()
	if core.get_item_group (name, "shulker_box") > 0 then
		return false
	end
	return core.registered_items[name] ~= nil
end

local function update_appearance (bundle, contents)
	local meta = bundle:get_meta ()
	local def = bundle:get_definition ()
	local weight = contents_weight (contents)
	local lines = { def.description, }
	for i = #contents, math.max (1, #contents - VISIBLE_ENTRIES + 1), -1 do
		local item = contents[i]
		local idef = item:get_definition ()
		local desc = item:get_short_description ()
			or (idef and idef.description) or item:get_name ()
		table.insert (lines, core.colorize ("#a8a8a8",
			desc:match ("[^\n]*") .. " ×" .. item:get_count ()))
	end
	if #contents > VISIBLE_ENTRIES then
		table.insert (lines, core.colorize ("#a8a8a8",
			S ("and @1 more…", #contents - VISIBLE_ENTRIES)))
	end
	table.insert (lines, core.colorize ("#d0d0d0", S ("@1/@2", weight, MAX_WEIGHT)))
	if #contents == 0 then
		meta:set_string ("description", "")
		meta:set_string ("inventory_image", "")
		meta:set_string ("wield_image", "")
	else
		meta:set_string ("description", table.concat (lines, "\n"))
		meta:set_string ("inventory_image", def._cb_filled_image)
		meta:set_string ("wield_image", def._cb_filled_image)
	end
	-- Keep the comparator / tooltip-friendly fullness in meta too.
	meta:set_int ("cb_items:bundle_weight", weight)
end

local function set_contents (bundle, contents)
	local list = {}
	for _, item in ipairs (contents) do
		table.insert (list, item:to_string ())
	end
	bundle:get_meta ():set_string (META_KEY,
		#list > 0 and core.serialize (list) or "")
	update_appearance (bundle, contents)
end

-- Put as much of STACK as fits into BUNDLE.  Both are modified in
-- place; returns the number of items stored.
function cb_items.bundle_insert (bundle, stack)
	if not can_store (stack) then
		return 0
	end
	local contents = get_contents (bundle)
	local free = MAX_WEIGHT - contents_weight (contents)
	local weight = item_weight (stack)
	local count = math.min (stack:get_count (), math.floor (free / weight))
	if count <= 0 then
		return 0
	end
	local moving = stack:take_item (count)
	-- Merge with the most recent matching entry, otherwise append.
	for i = #contents, 1, -1 do
		local entry = contents[i]
		if entry:item_fits (moving) then
			local rest = entry:add_item (moving)
			table.remove (contents, i)
			table.insert (contents, entry)
			if not rest:is_empty () then
				table.insert (contents, rest)
			end
			moving = nil
			break
		end
	end
	if moving then
		table.insert (contents, moving)
	end
	set_contents (bundle, contents)
	return count
end

-- Remove and return the stack at INDEX (default: the latest one).
function cb_items.bundle_take (bundle, index)
	local contents = get_contents (bundle)
	index = index or #contents
	local item = contents[index]
	if not item then
		return ItemStack ("")
	end
	table.remove (contents, index)
	set_contents (bundle, contents)
	return item
end

function cb_items.bundle_contents (bundle)
	return get_contents (bundle)
end

------------------------------------------------------------------------
-- Sounds.
------------------------------------------------------------------------

local function play (name, pos)
	core.sound_play (name, { pos = pos, gain = 0.6, max_hear_distance = 10, }, true)
end

------------------------------------------------------------------------
-- Inventory moves: item onto bundle, bundle onto item.
------------------------------------------------------------------------

local SUPPORTED_LISTS = { main = true, craft = true, offhand = true, }

core.register_allow_player_inventory_action (function (player, action, inv, info)
	if action ~= "move" then
		return
	end
	if not SUPPORTED_LISTS[info.from_list] or not SUPPORTED_LISTS[info.to_list] then
		return
	end
	local from = inv:get_stack (info.from_list, info.from_index)
	local to = inv:get_stack (info.to_list, info.to_index)
	if to:is_empty () or from:is_empty () then
		return
	end
	local pos = player:get_pos ()
	if is_bundle (to:get_name ()) and to:get_count () == 1 then
		-- Item (or another bundle) dropped onto a bundle.
		local moving = from:peek_item (info.count)
		local stored = cb_items.bundle_insert (to, moving)
		if stored == 0 then
			return 0
		end
		from:take_item (stored)
		core.after (0, function ()
			if not player:is_valid () then
				return
			end
			local inv = player:get_inventory ()
			inv:set_stack (info.to_list, info.to_index, to)
			inv:set_stack (info.from_list, info.from_index, from)
			play ("cb_items_bundle_insert", pos)
		end)
		return 0
	elseif is_bundle (from:get_name ()) and from:get_count () == 1
		and not is_bundle (to:get_name ()) then
		-- Bundle dropped onto an item: pick that item up.
		local stored = cb_items.bundle_insert (from, to)
		if stored == 0 then
			return 0
		end
		core.after (0, function ()
			if not player:is_valid () then
				return
			end
			local inv = player:get_inventory ()
			inv:set_stack (info.from_list, info.from_index, from)
			inv:set_stack (info.to_list, info.to_index, to)
			play ("cb_items_bundle_insert", pos)
		end)
		return 0
	end
end)

------------------------------------------------------------------------
-- Bundle window (sneak + use): take any stack out.
------------------------------------------------------------------------

local FORMNAME = "cb_items:bundle"
local open_bundles = {}

local function show_window (player)
	local name = player:get_player_name ()
	local bundle = player:get_wielded_item ()
	if not is_bundle (bundle:get_name ()) then
		open_bundles[name] = nil
		return
	end
	open_bundles[name] = player:get_wield_index ()
	local contents = get_contents (bundle)
	local cols = 8
	local rows = math.max (1, math.ceil (#contents / cols))
	local fs = {
		"formspec_version[4]",
		"size[", 0.5 + cols * 1.25, ",", 2.2 + rows * 1.25, "]",
		"label[0.4,0.5;", core.formspec_escape (bundle:get_short_description ()
			or bundle:get_definition ().description), " (",
			contents_weight (contents), "/", MAX_WEIGHT, ")]",
	}
	if #contents == 0 then
		table.insert (fs, "label[0.4,1.3;" .. core.formspec_escape (S ("Empty")) .. "]")
	end
	-- Newest first, as in the tooltip.
	local slot = 0
	for i = #contents, 1, -1 do
		local item = contents[i]
		local x = 0.4 + (slot % cols) * 1.25
		local y = 1.0 + math.floor (slot / cols) * 1.25
		table.insert (fs, string.format ("item_image_button[%f,%f;1.1,1.1;%s;take_%d;%s]",
			x, y, core.formspec_escape (item:get_name ()), i,
			item:get_count () > 1 and tostring (item:get_count ()) or ""))
		table.insert (fs, string.format ("tooltip[take_%d;%s]", i,
			core.formspec_escape (item:get_description ())))
		slot = slot + 1
	end
	table.insert (fs, string.format ("button_exit[0.4,%f;3,0.8;close;%s]",
		1.2 + rows * 1.25, core.formspec_escape (S ("Close"))))
	core.show_formspec (name, FORMNAME, table.concat (fs))
end

core.register_on_player_receive_fields (function (player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local name = player:get_player_name ()
	local index = open_bundles[name]
	if not index or fields.quit then
		open_bundles[name] = nil
		return true
	end
	local inv = player:get_inventory ()
	local bundle = inv:get_stack ("main", index)
	if not is_bundle (bundle:get_name ()) or player:get_wield_index () ~= index then
		open_bundles[name] = nil
		core.close_formspec (name, FORMNAME)
		return true
	end
	for field in pairs (fields) do
		local i = tonumber (field:match ("^take_(%d+)$"))
		if i then
			local item = cb_items.bundle_take (bundle, i)
			inv:set_stack ("main", index, bundle)
			if not item:is_empty () then
				local leftover = inv:add_item ("main", item)
				if not leftover:is_empty () then
					core.add_item (player:get_pos (), leftover)
				end
				play ("cb_items_bundle_remove", player:get_pos ())
			end
			show_window (player)
			break
		end
	end
	return true
end)

core.register_on_leaveplayer (function (player)
	open_bundles[player:get_player_name ()] = nil
end)

------------------------------------------------------------------------
-- Using a bundle: drop out the latest stack, or open the window.
------------------------------------------------------------------------

local function drop_one (itemstack, user)
	local item = cb_items.bundle_take (itemstack)
	if item:is_empty () then
		return itemstack
	end
	local pos = vector.offset (user:get_pos (), 0, user:get_properties ().eye_height or 1.5, 0)
	local dir = user:get_look_dir ()
	local obj = core.add_item (vector.add (pos, vector.multiply (dir, 0.4)), item)
	if obj then
		obj:set_velocity (vector.multiply (dir, 3))
	end
	play ("cb_items_bundle_drop", pos)
	return itemstack
end

local function on_use_bundle (itemstack, user, pointed_thing)
	if not user or not user:is_player () then
		return itemstack
	end
	-- a node with its own right-click (chest, door) comes first
	if pointed_thing and pointed_thing.type == "node" and not user:get_player_control ().sneak then
		local node = core.get_node (pointed_thing.under)
		local ndef = core.registered_nodes[node.name]
		if ndef and ndef.on_rightclick then
			return ndef.on_rightclick (pointed_thing.under, node, user, itemstack, pointed_thing) or itemstack
		end
	end
	if user:get_player_control ().sneak then
		core.after (0, function ()
			if user:is_valid () then
				show_window (user)
			end
		end)
		return itemstack
	end
	return drop_one (itemstack, user)
end

------------------------------------------------------------------------
-- Registration.
------------------------------------------------------------------------

local function register_bundle (name, desc, image, filled, extra_groups)
	local groups = { bundle = 1, craftitem = 1, }
	for k, v in pairs (extra_groups or {}) do
		groups[k] = v
	end
	core.register_craftitem (name, {
		description = desc,
		_doc_items_longdesc = S ("A bundle can hold a mixed stack of items: up to 64 light items, or fewer heavy ones."),
		_doc_items_usagehelp = S ("Drop an item onto the bundle in your inventory to put it in, or drop the bundle onto an item to pick it up. Use the bundle to drop out the last stack; sneak and use it to choose what to take out."),
		inventory_image = image,
		wield_image = image,
		_cb_filled_image = filled,
		stack_max = 1,
		groups = groups,
		on_place = on_use_bundle,
		on_secondary_use = on_use_bundle,
	})
	cb_items.bundles[name] = true
end

register_bundle ("cb_items:bundle", S ("Bundle"),
	"cb_items_bundle.png", "cb_items_bundle_filled.png")

local COLOR_NAMES = {
	white = S ("White Bundle"), grey = S ("Gray Bundle"), dark_grey = S ("Dark Gray Bundle"),
	black = S ("Black Bundle"), violet = S ("Purple Bundle"), blue = S ("Blue Bundle"),
	cyan = S ("Cyan Bundle"), dark_green = S ("Green Bundle"), green = S ("Lime Bundle"),
	yellow = S ("Yellow Bundle"), brown = S ("Brown Bundle"), orange = S ("Orange Bundle"),
	red = S ("Red Bundle"), magenta = S ("Magenta Bundle"), pink = S ("Pink Bundle"),
}
local RGB = {
	white = "#f0f0f0", grey = "#9d9d97", dark_grey = "#474f52", black = "#1d1d21", violet = "#8932b8",
	blue = "#3c44aa", cyan = "#169c9c", dark_green = "#5e7c16", green = "#80c71f", yellow = "#fed83d",
	brown = "#835432", orange = "#f9801d", red = "#b02e26", magenta = "#c74ebd", pink = "#f38baa",
}

for color, rgb in pairs (RGB) do
	local img = "(cb_items_bundle_mask.png^[multiply:" .. rgb .. ")^cb_items_bundle_overlay.png"
	local img_filled = "(cb_items_bundle_filled_mask.png^[multiply:" .. rgb .. ")^cb_items_bundle_filled_overlay.png"
	register_bundle ("cb_items:bundle_" .. color,
		COLOR_NAMES[color] or color, img, img_filled,
		{ ["bundle_" .. color] = 1, })
end

core.register_craft ({
	output = "cb_items:bundle",
	recipe = {
		{ "farming:string", },
		{ "mobs:leather", },
	},
})

-- Dyeing keeps the contents.
for color in pairs (RGB) do
	core.register_craft ({
		type = "shapeless",
		output = "cb_items:bundle_" .. color,
		recipe = { "group:bundle", "dye:" .. color, },
	})
end

local function keep_contents (itemstack, _, old_grid)
	if not is_bundle (itemstack:get_name ()) then
		return
	end
	for _, stack in ipairs (old_grid) do
		if is_bundle (stack:get_name ()) then
			if stack:get_name () == itemstack:get_name () then
				-- Same colour: refuse the pointless recolour.
				return ItemStack ("")
			end
			local contents = get_contents (stack)
			itemstack:get_meta ():from_table (stack:get_meta ():to_table ())
			set_contents (itemstack, contents)
			return itemstack
		end
	end
end

core.register_craft_predict (keep_contents)
core.register_on_craft (keep_contents)
