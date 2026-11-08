-- Ender pearl (thrown: moves the thrower where it lands, 5 damage), blaze rod
-- and powder, eye of ender (used on End portal frames; its flight to a
-- stronghold comes with the strongholds).
local S = cb_items.S

local function tex(name)
	return "cb_items_" .. name .. ".png"
end

local PEARL_SPEED, PEARL_LIFE = 22, 10

local function passable(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def ~= nil and def.walkable == false
end

-- Where a pearl that stopped at pos puts its thrower: the bottom of the node
-- it is in or of the one below, with room for the head; nil if neither fits.
function cb_items.pearl_spot(pos)
	local p = cb_blocks.node_at(pos)
	for dy = 0, -1, -1 do
		local feet = vector.offset(p, 0, dy, 0)
		if passable(feet) and passable(vector.offset(feet, 0, 1, 0)) then
			return vector.offset(feet, 0, -0.5, 0)
		end
	end
end

cb_items.pearl_hooks = {} -- fn(pos) after a pearl teleported its thrower

function cb_items.pearl_land(thrower, pos)
	if not thrower or not thrower:get_pos() or thrower:get_hp() <= 0 then
		return nil
	end
	local dest = cb_items.pearl_spot(pos)
	if not dest then
		return nil
	end
	core.sound_play("cb_mobs_dim_enderman_teleport_src", { pos = thrower:get_pos(), max_hear_distance = 16, }, true)
	thrower:set_pos(dest)
	core.sound_play("cb_mobs_dim_enderman_teleport_dst", { pos = dest, max_hear_distance = 16, }, true)
	thrower:set_hp(math.max(0, thrower:get_hp() - 5), { type = "set_hp", cause = "cb_items:ender_pearl", })
	for _, fn in ipairs(cb_items.pearl_hooks) do
		fn(dest)
	end
	return dest
end

core.register_entity("cb_items:ender_pearl_entity", {
	initial_properties = {
		physical = true,
		collide_with_objects = false,
		collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1, },
		pointable = false,
		visual = "sprite",
		visual_size = { x = 0.4, y = 0.4, },
		textures = { tex("ender_pearl"), },
		static_save = false,
	},
	_age = 0,
	on_step = function(self, dtime, moveresult)
		self._age = self._age + dtime
		if self._age > PEARL_LIFE then
			self.object:remove()
			return
		end
		if moveresult and moveresult.collides then
			local pos = self.object:get_pos()
			local thrower = self._thrower and core.get_player_by_name(self._thrower)
			self.object:remove()
			cb_items.pearl_land(thrower, pos)
		end
	end,
})

function cb_items.throw_pearl(user)
	local pos = vector.offset(user:get_pos(), 0, 1.5, 0)
	local obj = core.add_entity(pos, "cb_items:ender_pearl_entity")
	if not obj then
		return nil
	end
	obj:set_velocity(vector.multiply(user:get_look_dir(), PEARL_SPEED))
	obj:set_acceleration(vector.new(0, -9.81, 0))
	obj:get_luaentity()._thrower = user:get_player_name()
	core.sound_play("cb_items_throw", { pos = pos, max_hear_distance = 16, }, true)
	return obj
end

-- A grey second line: where it comes from and what it is for (the way to
-- the End, BACKLOG 3).
local function hint(name, text)
	return name .. "\n" .. core.colorize("#a8a8a8", text)
end

core.register_craftitem("cb_items:ender_pearl", {
	description = hint(S("Ender Pearl"), S("Dropped by endermen. With blaze powder it makes an eye of ender.")),
	inventory_image = tex("ender_pearl"),
	stack_max = 16,
	on_use = function(itemstack, user)
		if user and user:is_player() and cb_items.throw_pearl(user)
				and not core.is_creative_enabled(user:get_player_name()) then
			itemstack:take_item()
		end
		return itemstack
	end,
})

core.register_craftitem("cb_items:blaze_rod", { description = hint(S("Blaze Rod"),
	S("Dropped by blazes in Nether fortresses. Makes blaze powder.")), inventory_image = tex("blaze_rod"), })
core.register_craftitem("cb_items:blaze_powder", { description = hint(S("Blaze Powder"),
	S("With an ender pearl it makes an eye of ender.")), inventory_image = tex("blaze_powder"), })
core.register_craftitem("cb_items:shulker_shell", { description = S("Shulker Shell"), inventory_image = tex("shulker_shell"), })
core.register_craftitem("cb_items:ender_eye", { description = hint(S("Eye of Ender"),
	S("Throw it: it flies towards a stronghold. Twelve in the frames of its portal room open the End.")), inventory_image = tex("ender_eye"), })

core.register_craft({ type = "shapeless", output = "cb_items:blaze_powder 2", recipe = { "cb_items:blaze_rod", }, })
core.register_craft({ type = "shapeless", output = "cb_items:ender_eye", recipe = { "cb_items:ender_pearl", "cb_items:blaze_powder", }, })
core.register_craft({
	output = "cb_blocks:end_rod 4",
	recipe = { { "cb_items:blaze_rod", }, { "cb_blocks:popped_chorus_fruit", }, },
})

-- Rotten flesh (zombies): food that gives hunger 80 % of the time.
core.register_craftitem("cb_items:rotten_flesh", {
	description = S("Rotten Flesh"),
	inventory_image = "cb_items_rotten_flesh.png",
	groups = { food = 1, },
	on_use = function(itemstack, user, pointed)
		local out = core.item_eat(4)(itemstack, user, pointed)
		if user and user:is_player() and math.random() < 0.8 then
			cb_core.effects.apply(user, "hunger", 1, 30)
		end
		return out
	end,
})
-- Phantom membrane (phantoms): with elytra in the crafting grid it mends a
-- quarter of their durability.
core.register_craftitem("cb_items:phantom_membrane", {
	description = S("Phantom Membrane"), inventory_image = "cb_items_phantom_membrane.png",
})

function cb_items.repair_elytra(stack)
	stack = ItemStack(stack)
	stack:set_wear(math.max(0, stack:get_wear() - 16384))
	return stack
end

core.register_craft({
	-- a worn-out output, so autocrafters (no on_craft) cannot mend anything
	type = "shapeless", output = "cb_items:elytra_wings 1 65534",
	recipe = { "cb_items:elytra_wings", "cb_items:phantom_membrane", },
})

local function mended(itemstack, old_grid)
	if itemstack:get_name() ~= "cb_items:elytra_wings" then
		return nil
	end
	local elytra, membrane
	for _, s in ipairs(old_grid) do
		if s:get_name() == "cb_items:elytra_wings" then
			elytra = s
		elseif s:get_name() == "cb_items:phantom_membrane" then
			membrane = true
		end
	end
	if elytra and membrane then
		return cb_items.repair_elytra(elytra)
	end
end

core.register_craft_predict(function(itemstack, _, old_grid)
	return mended(itemstack, old_grid)
end)
core.register_on_craft(function(itemstack, _, old_grid)
	return mended(itemstack, old_grid)
end)
