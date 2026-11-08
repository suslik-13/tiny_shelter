-- Stonecutter (spec cycle 3, 4): a stone block in, a button per shape out:
-- its stairs (1), slabs (2), walls (1) and carved or brick variants made
-- from it alone (as many as the recipe gives per block). The index is built
-- once, on first use, from the server's recipes.
local NAME = "cb_blocks:stonecutter"
if not cb_blocks.registered[NAME] then
	return
end
local S, WS = cb_blocks.S, cb_blocks.ws
local SC = {}
cb_blocks.stonecutter = SC
local SIZES = { ["in"] = 1, out = 1, }
local FORM = "cb_blocks:stonecutter_"
local index

local function cracky(name)
	local def = core.registered_nodes[name]
	return def ~= nil and (def.groups or {}).cracky ~= nil
end

local function shape_count(out)
	if out:find("^stairs:stair_inner_") or out:find("^stairs:stair_outer_") then
		return false
	end
	if out:find("^stairs:stair_") or out:find("^walls:") then
		return 1
	end
	if out:find("^stairs:slab_") then
		return 2
	end
end

local function build()
	index = {}
	for out, def in pairs(core.registered_nodes) do
		local g = def.groups or {}
		if g.cracky and not g.not_in_creative_inventory then
			for _, r in ipairs(core.get_all_craft_recipes(out) or {}) do
				if r.method == "normal" and r.items then
					local src, n, same = nil, 0, true
					for _, it in pairs(r.items) do
						if it ~= "" then
							n = n + 1
							src = src or it
							same = same and it == src
						end
					end
					if same and src and src ~= out and cracky(src) then
						local outc = ItemStack(r.output):get_count()
						local count = shape_count(out)
						if count == nil then
							count = outc >= n and math.max(1, math.floor(outc / n)) or nil
						end
						if count then
							index[src] = index[src] or {}
							index[src][out] = count
						end
					end
				end
			end
		end
	end
	for src, set in pairs(index) do
		local list = {}
		for out, count in pairs(set) do
			list[#list + 1] = { out, count, }
		end
		table.sort(list, function(a, b) return a[1] < b[1] end)
		index[src] = list
	end
end

function SC.results(name)
	if not index then
		build()
	end
	return index[name] or {}
end

function SC.cut(pos, i)
	local inv = WS.lists(pos, SIZES)
	local input = inv:get_stack("in", 1)
	local r = not input:is_empty() and SC.results(input:get_name())[i]
	if not r then
		return false
	end
	local result = ItemStack(r[1] .. " " .. r[2])
	if not inv:room_for_item("out", result) then
		return false
	end
	input:take_item(1)
	inv:set_stack("in", 1, input)
	inv:add_item("out", result)
	return true
end

function SC.show(pos, name)
	local inv, loc = WS.lists(pos, SIZES), WS.loc(pos)
	local input = inv:get_stack("in", 1)
	local body = { "label[0,0;" .. core.formspec_escape(S("Stonecutter")) .. "]list[" .. loc .. ";in;0,1.5;1,1;]",
		"list[" .. loc .. ";out;7,1.5;1,1;]listring[" .. loc .. ";out]listring[current_player;main]listring["
		.. loc .. ";in]listring[current_player;main]", }
	if not input:is_empty() then
		for i, r in ipairs(SC.results(input:get_name())) do
			if i > 15 then
				break
			end
			local x, y = 1.5 + ((i - 1) % 5), 0.5 + math.floor((i - 1) / 5)
			body[#body + 1] = "item_image_button[" .. x .. "," .. y .. ";1,1;" .. r[1] .. ";cut_" .. i .. ";" .. r[2] .. "]"
		end
	end
	core.show_formspec(name, FORM .. core.pos_to_string(pos), WS.formspec(table.concat(body)))
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
		local i = tonumber(field:match("^cut_(%d+)$"))
		if i then
			SC.cut(pos, i)
			SC.show(pos, player:get_player_name())
		end
	end
	return true
end)

core.override_item(NAME, {
	on_construct = function(pos)
		WS.lists(pos, SIZES)
	end,
	on_rightclick = function(pos, _, clicker, itemstack)
		if clicker and WS.allowed(pos, clicker) then
			SC.show(pos, clicker:get_player_name())
		end
		return itemstack
	end,
	allow_metadata_inventory_put = function(pos, list, _, stack, player)
		if list ~= "in" or not WS.allowed(pos, player) or #SC.results(stack:get_name()) == 0 then
			return 0
		end
		return stack:get_count()
	end,
	allow_metadata_inventory_move = function()
		return 0
	end,
	allow_metadata_inventory_take = function(pos, _, _, stack, player)
		return WS.allowed(pos, player) and stack:get_count() or 0
	end,
	on_metadata_inventory_put = function(pos, _, _, _, player)
		if player and player.is_player and player:is_player() and player.get_pos then
			SC.show(pos, player:get_player_name())
		end
	end,
	on_metadata_inventory_take = function(pos, _, _, _, player)
		core.sound_play("cb_blocks_stonecutter", { pos = pos, max_hear_distance = 12, }, true)
		if player and player.is_player and player:is_player() and player.get_pos then
			SC.show(pos, player:get_player_name())
		end
	end,
	can_dig = function(pos)
		local inv = WS.lists(pos, SIZES)
		return inv:is_empty("in") and inv:is_empty("out")
	end,
	on_blast = function(pos)
		local inv, drops = WS.lists(pos, SIZES), {}
		for _, list in ipairs({ "in", "out", }) do
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
