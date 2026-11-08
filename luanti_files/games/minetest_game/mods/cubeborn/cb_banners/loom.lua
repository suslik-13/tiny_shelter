-- Loom (spec cycle 3, 5; after Mineclonia's mcl_loom): banner + dye
-- (+ pattern item) -> a button per pattern -> the banner with one more
-- layer in out, paid when taken (one banner, one dye; the pattern item stays).
local B, S = cb_banners, cb_banners.S
local NAME = "cb_blocks:loom"
B.SKULLS = { "mobs_skeletons:skeleton_skull", "mobs:skull", "cb_blocks:skeleton_skull", }

-- pattern items: paper + a Bedrock ingredient, when the server has it
local SPECIAL = { flower = { "flowers:dandelion_white", }, bricks = { "default:brick", }, curly_border = { "ethereal:vine", },
	skull = B.SKULLS, }
for id, sources in pairs(SPECIAL) do
	for _, src in ipairs(sources) do
		if core.registered_items[src] then
			local item = "cb_banners:pattern_" .. id
			core.register_craftitem(item, {
				description = S("@1 Banner Pattern", B.PATTERNS[id].name),
				inventory_image = "cb_banners_pattern_" .. id .. ".png",
				groups = { cb_banner_pattern = 1, },
				_cb_pattern = id,
			})
			core.register_craft({ type = "shapeless", output = item, recipe = { "default:paper", src, }, })
			break
		end
	end
end

if not core.registered_nodes[NAME] or not cb_blocks.ws then
	return
end
local WS = cb_blocks.ws
local L = { SIZES = { banner = 1, dye = 1, pattern = 1, out = 1, }, }
B.loom = L
local FORM = "cb_banners:loom_"

function L.dye_colour(stack)
	local c = stack:get_name():match("^dye:(.+)$")
	return c and B.COLOURS[c] and c or nil
end

function L.choices(inv)
	local banner, dye = inv:get_stack("banner", 1), inv:get_stack("dye", 1)
	if core.get_item_group(banner:get_name(), "cb_banner_item") == 0 or not L.dye_colour(dye)
			or #B.layers(banner) >= B.MAX_LAYERS then
		return {}
	end
	local pdef = core.registered_items[inv:get_stack("pattern", 1):get_name()]
	if pdef and pdef._cb_pattern then
		return { pdef._cb_pattern, }
	end
	return B.DYE_PATTERNS
end

local function offered(inv, id)
	for _, c in ipairs(L.choices(inv)) do
		if c == id then
			return true
		end
	end
	return false
end

function L.result(inv, id)
	if not offered(inv, id) then
		return nil
	end
	local out = ItemStack(inv:get_stack("banner", 1))
	out:set_count(1)
	local layers = B.layers(out)
	layers[#layers + 1] = { id, L.dye_colour(inv:get_stack("dye", 1)), }
	return B.set_layers(out, layers)
end

function L.refresh(pos)
	local inv = WS.lists(pos, L.SIZES)
	local meta = core.get_meta(pos)
	local id = meta:get_string("cb_pattern")
	local out = id ~= "" and L.result(inv, id) or nil
	if not out then
		meta:set_string("cb_pattern", "")
	end
	inv:set_stack("out", 1, out or "")
end

function L.select(pos, id)
	local inv = WS.lists(pos, L.SIZES)
	if not offered(inv, id) then
		return false
	end
	core.get_meta(pos):set_string("cb_pattern", id)
	L.refresh(pos)
	return true
end

function L.show(pos, name)
	local inv, loc = WS.lists(pos, L.SIZES), WS.loc(pos)
	local banner = inv:get_stack("banner", 1)
	local bdef = core.registered_items[banner:get_name()]
	local colour = L.dye_colour(inv:get_stack("dye", 1))
	local fs = { "size[8,10.3]label[0,0;" .. core.formspec_escape(S("Loom")) .. "]",
		"list[" .. loc .. ";banner;0,0.5;1,1;]list[" .. loc .. ";dye;0,1.6;1,1;]list[" .. loc .. ";pattern;0,2.7;1,1;]",
		"list[" .. loc .. ";out;0,4;1,1;]", }
	for i, id in ipairs(L.choices(inv)) do
		local x, y = 1.2 + ((i - 1) % 8) * 0.85, 0.4 + math.floor((i - 1) / 8) * 0.85
		local img = B.item_texture(bdef and bdef._cb_colour or "white", { { id, colour, }, })
		fs[#fs + 1] = "image_button[" .. x .. "," .. y .. ";0.85,0.85;" .. core.formspec_escape(img) .. ";pat_" .. id .. ";]"
			.. "tooltip[pat_" .. id .. ";" .. core.formspec_escape(B.PATTERNS[id].name) .. "]"
	end
	fs[#fs + 1] = "list[current_player;main;0,5.6;8,1;]list[current_player;main;0,6.85;8,3;8]"
		.. "listring[" .. loc .. ";out]listring[current_player;main]listring[" .. loc .. ";banner]listring[current_player;main]"
		.. "listring[" .. loc .. ";dye]listring[current_player;main]"
	core.show_formspec(name, FORM .. core.pos_to_string(pos), table.concat(fs))
end

local function reshow(pos, player)
	if player and player.is_player and player:is_player() and player.get_pos then
		L.show(pos, player:get_player_name())
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, #FORM) ~= FORM then
		return
	end
	local pos = core.string_to_pos(formname:sub(#FORM + 1))
	if not pos or core.get_node(pos).name ~= NAME or not WS.allowed(pos, player)
			or vector.distance(player:get_pos(), pos) > 10 then
		return true
	end
	for field in pairs(fields) do
		local id = field:match("^pat_([%w_]+)$")
		if id and L.select(pos, id) then
			L.show(pos, player:get_player_name())
		end
	end
	return true
end)

core.override_item(NAME, {
	on_construct = function(pos)
		WS.lists(pos, L.SIZES)
	end,
	on_rightclick = function(pos, _, clicker, itemstack)
		if clicker and WS.allowed(pos, clicker) then
			L.refresh(pos)
			L.show(pos, clicker:get_player_name())
		end
		return itemstack
	end,
	allow_metadata_inventory_put = function(pos, list, _, stack, player)
		if not WS.allowed(pos, player) then
			return 0
		end
		local n = stack:get_name()
		if list == "banner" and core.get_item_group(n, "cb_banner_item") > 0 then
			return 1
		elseif list == "dye" and L.dye_colour(stack) then
			return stack:get_count()
		elseif list == "pattern" and core.get_item_group(n, "cb_banner_pattern") > 0 then
			return 1
		end
		return 0
	end,
	allow_metadata_inventory_move = function()
		return 0
	end,
	allow_metadata_inventory_take = function(pos, _, _, stack, player)
		return WS.allowed(pos, player) and stack:get_count() or 0
	end,
	on_metadata_inventory_put = function(pos, _, _, _, player)
		L.refresh(pos)
		reshow(pos, player)
	end,
	on_metadata_inventory_take = function(pos, list, _, _, player)
		local inv = WS.lists(pos, L.SIZES)
		if list == "out" then
			local banner, dye = inv:get_stack("banner", 1), inv:get_stack("dye", 1)
			banner:take_item(1)
			dye:take_item(1)
			inv:set_stack("banner", 1, banner)
			inv:set_stack("dye", 1, dye)
			core.sound_play("cb_blocks_loom", { pos = pos, max_hear_distance = 12, }, true)
		end
		L.refresh(pos)
		reshow(pos, player)
	end,
	can_dig = function(pos)
		local inv = WS.lists(pos, L.SIZES)
		return inv:is_empty("banner") and inv:is_empty("dye") and inv:is_empty("pattern")
	end,
	on_blast = function(pos)
		local inv, drops = WS.lists(pos, L.SIZES), {}
		for _, list in ipairs({ "banner", "dye", "pattern", }) do
			local st = inv:get_stack(list, 1)
			if not st:is_empty() then
				drops[#drops + 1] = st:to_string()
			end
		end
		drops[#drops + 1] = NAME
		core.remove_node(pos)
		return drops
	end,
})
