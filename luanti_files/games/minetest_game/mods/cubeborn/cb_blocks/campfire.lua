-- Campfire and soul campfire (spec cycle 10; model and textures from
-- Mineclonia's mcl_campfires). A lit campfire cooks up to four raw foods
-- (30 s each, no fuel), hurts who stands in it, smokes; a shovel or a water
-- bucket puts it out, flint and steel or a fire charge lights it again.
-- One node timer (1 s) per lit campfire with food or smoke; the food
-- pictures are unsaved entities remade by an LBM.
local S = cb_blocks.S
local C = {}
cb_blocks.campfire = C
C.COOK_TIME, C.SLOTS, C.PICTURE = 30, 4, "cb_blocks:campfire_item"

local KINDS = {
	campfire = { desc = S("Campfire"), light = 15, damage = 1, fire = "cb_blocks_campfire_fire.png",
		logs = "cb_blocks_campfire_log_lit.png", inv = "cb_blocks_campfire_inv.png",
		drops = function()
			if core.registered_items["ethereal:charcoal_lump"] then
				return { "ethereal:charcoal_lump 2", }
			end
			return { "default:coal_lump", }
		end, },
	soul_campfire = { desc = S("Soul Campfire"), light = 10, damage = 2, fire = "cb_blocks_campfire_soul_campfire_fire.png",
		logs = "cb_blocks_campfire_soul_campfire_log_lit.png", inv = "cb_blocks_campfire_soul_campfire_inv.png",
		drops = function()
			return { core.registered_items["cb_blocks:soul_soil"] and "cb_blocks:soul_soil" or "cb_blocks:soul_sand", }
		end, },
}

-- What cooking `stack` gives on a campfire (raw food only), or nil.
function C.cooked(stack)
	stack = ItemStack(stack)
	local def = stack:get_definition()
	if not def or stack:is_empty() then
		return nil
	end
	local food = def.on_use ~= nil or (def.groups and ((def.groups.food or 0) > 0 or (def.groups.eatable or 0) > 0
		or (def.groups.food_meat_raw or 0) > 0 or (def.groups.food_fish_raw or 0) > 0))
	if not food then
		return nil
	end
	local out = core.get_craft_result({ method = "cooking", width = 1, items = { ItemStack(stack:get_name()), }, })
	if out.item:is_empty() then
		return nil
	end
	return out.item
end

local function slot_pos(pos, i, param2)
	local off = ({ { -0.22, -0.22, }, { 0.22, -0.22, }, { 0.22, 0.22, }, { -0.22, 0.22, }, })[i]
	return vector.offset(pos, off[1], -0.02, off[2])
end

local function pictures(pos)
	local list = {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.6)) do
		local e = obj:get_luaentity()
		if e and e.name == C.PICTURE then
			list[#list + 1] = obj
		end
	end
	return list
end

local function show(pos)
	for _, o in ipairs(pictures(pos)) do
		o:remove()
	end
	local inv = core.get_meta(pos):get_inventory()
	for i = 1, C.SLOTS do
		local st = inv:get_stack("food", i)
		if not st:is_empty() then
			local obj = core.add_entity(slot_pos(pos, i), C.PICTURE)
			if obj then
				obj:set_properties({ wield_item = st:get_name(), })
				obj:set_rotation(vector.new(math.pi / 2, 0, i * math.pi / 2))
			end
		end
	end
end
C.show = show

core.register_entity(C.PICTURE, {
	initial_properties = {
		physical = false, collide_with_objects = false, pointable = false, static_save = false,
		visual = "wielditem", visual_size = { x = 0.18, y = 0.18, }, wield_item = "air",
	},
})

local function lit(name)
	return name:find("_lit$") ~= nil
end

-- Puts a raw food on the fire; returns true when it took one.
function C.add_food(pos, stack)
	if not C.cooked(stack) then
		return false
	end
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	for i = 1, C.SLOTS do
		if inv:get_stack("food", i):is_empty() then
			inv:set_stack("food", i, ItemStack(stack:get_name()))
			meta:set_int("t" .. i, 0)
			show(pos)
			core.get_node_timer(pos):start(1)
			return true
		end
	end
	return false
end

-- Advances the cooking by `dt` seconds: cooked items pop out above.
function C.tick(pos, dt)
	local node = core.get_node(pos)
	if not lit(node.name) then
		return false
	end
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local busy, changed = false, false
	for i = 1, C.SLOTS do
		local st = inv:get_stack("food", i)
		if not st:is_empty() then
			local t = meta:get_float("t" .. i) + dt
			if t >= C.COOK_TIME then
				local out = C.cooked(st)
				inv:set_stack("food", i, ItemStack(""))
				meta:set_float("t" .. i, 0)
				if out then
					core.add_item(vector.offset(pos, 0, 0.6, 0), out)
				end
				changed = true
			else
				meta:set_float("t" .. i, t)
				busy = true
			end
		end
	end
	if changed then
		show(pos)
	end
	-- smoke (higher over a hay bale, as in Minecraft)
	local below = core.get_node(vector.offset(pos, 0, -1, 0)).name
	local high = below:find("hay") ~= nil or below:find("straw") ~= nil
	core.add_particlespawner({
		amount = 2, time = 1, minpos = vector.offset(pos, -0.25, 0.1, -0.25), maxpos = vector.offset(pos, 0.25, 0.3, 0.25),
		minvel = { x = -0.1, y = high and 1.6 or 0.8, z = -0.1, }, maxvel = { x = 0.1, y = high and 2.4 or 1.2, z = 0.1, },
		minexptime = 3, maxexptime = high and 7 or 4, minsize = 3, maxsize = 5,
		texture = "cb_blocks_campfire_particle_" .. math.random(1, 4) .. ".png", collisiondetection = false,
	})
	return true
end

local function drop_food(pos)
	local inv = core.get_meta(pos):get_inventory()
	for i = 1, C.SLOTS do
		local st = inv:get_stack("food", i)
		if not st:is_empty() then
			core.add_item(vector.offset(pos, 0, 0.5, 0), st)
		end
	end
end

function C.extinguish(pos)
	local node = core.get_node(pos)
	if lit(node.name) then
		core.swap_node(pos, { name = node.name:gsub("_lit$", ""), param2 = node.param2, })
		core.sound_play("fire_extinguish_flame", { pos = pos, gain = 0.25, max_hear_distance = 16, }, true)
		core.get_node_timer(pos):stop()
	end
end

function C.ignite(pos)
	local node = core.get_node(pos)
	if not lit(node.name) and KINDS[node.name:match("^cb_blocks:(.+)$") or ""] then
		core.swap_node(pos, { name = node.name .. "_lit", param2 = node.param2, })
		core.get_node_timer(pos):start(1)
		return true
	end
	return false
end

local function shovel(stack)
	local name = stack:get_name()
	return name:find("shovel") ~= nil or core.get_item_group(name, "shovel") > 0
end

local function common(kind, k, is_lit)
	local name = "cb_blocks:" .. kind .. (is_lit and "_lit" or "")
	local def = {
		description = k.desc .. "\n" .. S("Cooks up to four raw foods without fuel"),
		drawtype = "mesh", mesh = "cb_blocks_campfire.obj",
		inventory_image = k.inv, wield_image = k.inv,
		paramtype = "light", paramtype2 = "4dir", sunlight_propagates = true, use_texture_alpha = "clip",
		is_ground_content = false,
		groups = { choppy = 2, oddly_breakable_by_hand = 1, flammable = 0, not_in_creative_inventory = is_lit and nil or 1,
			cb_campfire = 1, },
		selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.05, 0.5, }, },
		collision_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.05, 0.5, }, },
		sounds = default.node_sound_wood_defaults(),
		drop = "",
		on_construct = function(pos)
			core.get_meta(pos):get_inventory():set_size("food", C.SLOTS)
			if is_lit then
				core.get_node_timer(pos):start(1)
			end
		end,
		on_destruct = function(pos)
			for _, o in ipairs(pictures(pos)) do
				o:remove()
			end
		end,
		after_dig_node = function(pos, _, oldmeta, digger)
			local inv = oldmeta and oldmeta.inventory and oldmeta.inventory.food or {}
			for _, st in pairs(inv) do
				st = ItemStack(st)
				if not st:is_empty() then
					core.add_item(vector.offset(pos, 0, 0.5, 0), st)
				end
			end
			local tool = digger and digger:get_wielded_item()
			local ench = rawget(_G, "cb_enchanting")
			if tool and ench and ench.level and ench.level(tool, "silk_touch") > 0 then
				core.add_item(pos, "cb_blocks:" .. kind .. "_lit")
				return
			end
			for _, d in ipairs(k.drops()) do
				core.add_item(pos, d)
			end
		end,
		on_rightclick = function(pos, node, clicker, itemstack, pointed)
			if not (clicker and clicker:is_player()) or core.is_protected(pos, clicker:get_player_name()) then
				return itemstack
			end
			local iname = itemstack:get_name()
			if is_lit and shovel(itemstack) then
				C.extinguish(pos)
			elseif is_lit and iname == "bucket:bucket_water" then
				C.extinguish(pos)
				if not core.is_creative_enabled(clicker:get_player_name()) then
					return ItemStack("bucket:bucket_empty")
				end
			elseif is_lit and C.add_food(pos, itemstack) then
				if not core.is_creative_enabled(clicker:get_player_name()) then
					itemstack:take_item(1)
				end
			elseif not itemstack:is_empty() and itemstack:get_definition().type == "node" and pointed then
				return core.item_place_node(itemstack, clicker, pointed)
			end
			return itemstack
		end,
		on_timer = function(pos, elapsed)
			return C.tick(pos, elapsed)
		end,
	}
	if is_lit then
		def.tiles = { { name = k.fire, animation = { type = "vertical_frames", aspect_w = 32, aspect_h = 16, length = 2.0, }, }, }
		def.overlay_tiles = { { name = k.logs, animation = { type = "vertical_frames", aspect_w = 32, aspect_h = 16, length = 2.0, }, }, }
		def.light_source = k.light
		def.damage_per_second = k.damage
	else
		def.tiles = { "cb_blocks_campfire_log.png", }
		def.on_ignite = function(pos)
			C.ignite(pos)
		end
		def.description = k.desc .. " (" .. S("out") .. ")"
	end
	core.register_node(name, def)
end

for kind, k in pairs(KINDS) do
	common(kind, k, false)
	common(kind, k, true)
end

core.register_lbm({
	label = "Cubeborn campfire food and timers",
	name = "cb_blocks:campfire_restart",
	nodenames = { "cb_blocks:campfire_lit", "cb_blocks:soul_campfire_lit", },
	run_at_every_load = true,
	action = function(pos)
		show(pos)
		local t = core.get_node_timer(pos)
		if not t:is_started() then
			t:start(1)
		end
	end,
})

local stick = "default:stick"
core.register_craft({
	output = "cb_blocks:campfire_lit",
	recipe = { { "", stick, "", }, { stick, "group:coal", stick, }, { "group:tree", "group:tree", "group:tree", }, },
})
core.register_craft({
	output = "cb_blocks:soul_campfire_lit",
	recipe = { { "", stick, "", }, { stick, "group:soul_block", stick, }, { "group:tree", "group:tree", "group:tree", }, },
})
for _, n in ipairs({ "default:coal_lump", "ethereal:charcoal_lump", }) do
	local d = core.registered_items[n]
	if d then
		local g = table.copy(d.groups or {})
		g.coal = 1
		core.override_item(n, { groups = g, })
	end
end
for _, n in ipairs({ "cb_blocks:soul_sand", "cb_blocks:soul_soil", "nether:soul_sand", }) do
	local d = core.registered_items[n]
	if d then
		local g = table.copy(d.groups or {})
		g.soul_block = 1
		core.override_item(n, { groups = g, })
	end
end
