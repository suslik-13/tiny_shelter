-- Workstation windows: lists made on first use (schematic nodes get no
-- constructor), area protection, and a "station": input lists whose
-- result shows in out as a preview and is paid for when taken.
local WS = {}
cb_blocks.ws = WS

function WS.allowed(pos, player)
	local name = player and player.get_player_name and player:get_player_name() or ""
	if name ~= "" and core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return false
	end
	return true
end

function WS.loc(pos)
	return "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z
end

function WS.lists(pos, sizes)
	local inv = core.get_meta(pos):get_inventory()
	for list, n in pairs(sizes) do
		if inv:get_size(list) ~= n then
			inv:set_size(list, n)
		end
	end
	return inv
end

function WS.formspec(body)
	return "size[8,8.5]" .. body .. "list[current_player;main;0,4.25;8,1;]list[current_player;main;0,5.5;8,3;8]"
		.. (default.get_hotbar_bg and default.get_hotbar_bg(0, 4.25) or "")
end

function WS.station(name, opts)
	local sizes = opts.sizes
	local function refresh(pos)
		local inv = WS.lists(pos, sizes)
		inv:set_stack("out", 1, opts.compute(inv) or "")
	end
	core.override_item(name, {
		on_construct = function(pos)
			WS.lists(pos, sizes)
		end,
		on_rightclick = function(pos, _, clicker, itemstack)
			if clicker and WS.allowed(pos, clicker) then
				WS.lists(pos, sizes)
				core.show_formspec(clicker:get_player_name(), name:gsub(":", "_") .. "_" .. core.pos_to_string(pos),
					WS.formspec(opts.body(WS.loc(pos))))
			end
			return itemstack
		end,
		allow_metadata_inventory_put = function(pos, list, _, stack, player)
			if list == "out" or not WS.allowed(pos, player) then
				return 0
			end
			return opts.accept(list, stack)
		end,
		allow_metadata_inventory_move = function()
			return 0
		end,
		allow_metadata_inventory_take = function(pos, _, _, stack, player)
			return WS.allowed(pos, player) and stack:get_count() or 0
		end,
		on_metadata_inventory_put = function(pos)
			refresh(pos)
		end,
		on_metadata_inventory_take = function(pos, list)
			if list == "out" then
				opts.spend(WS.lists(pos, sizes), pos)
				if opts.sound then
					core.sound_play(opts.sound, { pos = pos, max_hear_distance = 12, }, true)
				end
			end
			refresh(pos)
		end,
		can_dig = function(pos)
			local inv = WS.lists(pos, sizes)
			for list in pairs(sizes) do
				if list ~= "out" and not inv:is_empty(list) then
					return false
				end
			end
			return true
		end,
		on_blast = function(pos)
			local inv, drops = WS.lists(pos, sizes), {}
			for list in pairs(sizes) do
				if list ~= "out" then
					for _, st in ipairs(inv:get_list(list)) do
						if not st:is_empty() then
							drops[#drops + 1] = st:to_string()
						end
					end
				end
			end
			drops[#drops + 1] = name
			core.remove_node(pos)
			return drops
		end,
	})
	return refresh
end
