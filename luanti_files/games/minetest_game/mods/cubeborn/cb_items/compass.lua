-- Compass: points to where its holder last died, to the spawn point before the
-- first death; spins in another dimension. Its 32 needle images are set per
-- stack (meta inventory_image) for compasses on the hotbar.
local S = cb_items.S

local NAME, FRAMES, TICK = "cb_items:compass", 32, 0.2
local KEY = "cb_items:death_pos"

local function img(frame)
	return string.format("cb_items_compass_%02d.png", frame)
end

local function dim_at(pos)
	local st = rawget(_G, "cb_structures")
	return st and st.dim_at and st.dim_at(pos) or "overworld"
end

function cb_items.compass_died(player)
	player:get_meta():set_string(KEY, core.pos_to_string(vector.round(player:get_pos())))
end

core.register_on_dieplayer(function(player)
	cb_items.compass_died(player)
end)

-- Where the needle points for player, or nil when it spins.
function cb_items.compass_target(player)
	local pos = player:get_pos()
	local death = core.string_to_pos(player:get_meta():get_string(KEY))
	local target = death or core.setting_get_pos("static_spawnpoint") or vector.zero()
	if dim_at(target) ~= dim_at(pos) then
		return nil
	end
	return target
end

-- The needle frame for a holder at pos looking at yaw (Mineclonia's formula).
function cb_items.compass_frame(pos, target, yaw)
	local north = math.deg(math.atan2(target.x - pos.x, target.z - pos.z))
	return math.floor(((north + math.deg(yaw) + 180) % 360) / (360 / FRAMES) + 0.5) % FRAMES
end

local spin = math.random(0, FRAMES - 1)

-- Lodestone binding (spec cycle 10): a compass used on a lodestone points
-- there (same dimension), back to the last death once the lodestone is gone.
local LODE, BOUND = "cb_items:lodestone", "cb_items:lodestone_pos"
cb_items.LODESTONE = LODE

function cb_items.compass_bind(stack, pos)
	local meta = stack:get_meta()
	meta:set_string(BOUND, core.pos_to_string(pos))
	meta:set_string("description", S("Lodestone Compass") .. "\n" .. S("Points to the lodestone at @1", core.pos_to_string(pos)))
	return stack
end

local function unbind(stack)
	local meta = stack:get_meta()
	meta:set_string(BOUND, "")
	meta:set_string("description", "")
	return stack
end

-- The target of this compass stack for player (nil = spin); changed = the
-- stack was unbound (its lodestone is gone).
function cb_items.compass_stack_target(stack, player)
	local lpos = core.string_to_pos(stack:get_meta():get_string(BOUND))
	if lpos then
		local node = core.get_node_or_nil(lpos)
		if node and node.name ~= LODE then
			unbind(stack)
			return cb_items.compass_target(player), true
		end
		if dim_at(lpos) ~= dim_at(player:get_pos()) then
			return nil
		end
		return lpos
	end
	return cb_items.compass_target(player)
end

function cb_items.compass_update(player)
	local inv = player:get_inventory()
	for i = 1, player:hud_get_hotbar_itemcount() do
		local stack = inv:get_stack("main", i)
		if stack:get_name() == NAME then
			local target, changed = cb_items.compass_stack_target(stack, player)
			local frame = target and cb_items.compass_frame(player:get_pos(), target, player:get_look_horizontal())
				or spin
			local meta = stack:get_meta()
			if changed then
				inv:set_stack("main", i, stack)
			end
			if meta:get_string("inventory_image") ~= img(frame) then
				meta:set_string("inventory_image", img(frame))
				meta:set_string("wield_image", img(frame))
				inv:set_stack("main", i, stack)
			end
		end
	end
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < TICK then
		return
	end
	timer = 0
	spin = (spin + 1) % FRAMES
	for _, player in ipairs(core.get_connected_players()) do
		cb_items.compass_update(player)
	end
end)

core.register_craftitem(NAME, {
	description = S("Compass") .. "\n" .. S("Points to where you last died"),
	inventory_image = img(1),
	wield_image = img(1),
	groups = { tool = 1, },
})

core.register_craft({
	output = NAME,
	recipe = {
		{ "", "default:steel_ingot", "", },
		{ "default:steel_ingot", "default:mese_crystal", "default:steel_ingot", },
		{ "", "default:steel_ingot", "", },
	},
})

core.register_node(LODE, {
	description = S("Lodestone") .. "\n" .. S("Use a compass on it: the compass will point here"),
	tiles = { "cb_items_lodestone_top.png", "cb_items_lodestone_bottom.png", "cb_items_lodestone_side1.png", },
	is_ground_content = false, groups = { cracky = 1, level = 2, },
	sounds = default.node_sound_stone_defaults(),
	on_rightclick = function(pos, _, clicker, itemstack)
		if itemstack:get_name() ~= NAME or not (clicker and clicker:is_player()) then
			return itemstack
		end
		local name = clicker:get_player_name()
		if itemstack:get_count() > 1 then
			-- one compass of the stack is bound, the rest stays
			local one = cb_items.compass_bind(ItemStack(NAME), pos)
			itemstack:take_item(1)
			local inv = clicker:get_inventory()
			if inv:room_for_item("main", one) then
				inv:add_item("main", one)
			else
				core.add_item(clicker:get_pos(), one)
			end
		else
			cb_items.compass_bind(itemstack, pos)
		end
		core.chat_send_player(name, S("The compass now points to this lodestone."))
		return itemstack
	end,
})

local nether_ingot = "cb_blocks:netherite_ingot"
core.register_craft({
	output = LODE,
	recipe = {
		{ "default:stonebrick", "default:stonebrick", "default:stonebrick", },
		{ "default:stonebrick", nether_ingot, "default:stonebrick", },
		{ "default:stonebrick", "default:stonebrick", "default:stonebrick", },
	},
})
