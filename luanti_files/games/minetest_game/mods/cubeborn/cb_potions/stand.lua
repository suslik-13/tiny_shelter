-- The brewing stand brews (spec 4.1, 4.2): three bottles, one ingredient,
-- blaze powder for fuel (one powder = FUEL brews), TIME s a brew. Only a
-- player puts the ingredient, and the brew starts only if that player's
-- level reaches the level of every potion it makes; the check repeats at
-- each brew. A brew costs the brewer experience points once, the price of
-- its dearest potion (CP.xp_cost): checked at the start, paid when
-- the brew is done (a restarted brew is not paid twice; without the points
-- by then nothing is brewed and the ingredient stays). No pipes or hoppers: a machine
-- could not be asked for a level.
-- Village stands placed by schematics get their inventory on first use.
local CP, S = cb_potions, cb_potions.S
local NAME = "cb_blocks:brewing_stand"
CP.STAND = { TIME = 20, FUEL = 20, }
local POWDER = "cb_items:blaze_powder"

-- The points the brewer pays (nil: nothing to pay, no cb_xp or an admin).
local function cost_for(name, out)
	local X = rawget(_G, "cb_xp")
	if not X or X.is_admin(name) then
		return nil
	end
	local n = 0
	for _, o in pairs(out) do
		n = math.max(n, CP.xp_cost(o))
	end
	return n
end

local function level_of(name)
	local X = rawget(_G, "cb_xp")
	if not X then
		return math.huge
	end
	if X.is_admin(name) then
		return math.huge
	end
	return X.level_of(X.get(name))
end

local function formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local loc = "nodemeta:" .. spos
	local meta = core.get_meta(pos)
	local fuel = meta:get_int("fuel")
	local t = meta:get_float("t")
	local progress = math.floor(100 * math.min(1, t / CP.STAND.TIME))
	return "formspec_version[4]size[10.5,10]" ..
		"label[0.4,0.5;" .. core.formspec_escape(S("Brewing Stand")) .. "]" ..
		"list[" .. loc .. ";fuel;0.6,1;1,1;]" ..
		"label[0.4,2.6;" .. core.formspec_escape(S("Fuel: @1", fuel)) .. "]" ..
		"list[" .. loc .. ";ingredient;4.6,0.8;1,1;]" ..
		"image[4.85,2;0.6,1.2;cb_potions_progress.png^[lowpart:" .. progress .. ":cb_potions_progress_full.png]" ..
		"list[" .. loc .. ";bottles;3.4,3.4;3,1;]" ..
		"list[current_player;main;0.4,4.9;8,4;]" ..
		"listring[" .. loc .. ";bottles]listring[current_player;main]"
end

local function refresh(pos)
	local meta = core.get_meta(pos)
	meta:set_string("formspec", formspec(pos))
	meta:set_string("infotext", S("Brewing Stand") .. "\n" .. S("Fuel: @1", meta:get_int("fuel")))
end

local function ensure(pos)
	local inv = core.get_meta(pos):get_inventory()
	if inv:get_size("bottles") ~= 3 then
		inv:set_size("bottles", 3)
		inv:set_size("ingredient", 1)
		inv:set_size("fuel", 1)
		refresh(pos)
	end
	return inv
end

-- What each bottle becomes with the ingredient now in the stand.
local function outputs(inv)
	local ing = inv:get_stack("ingredient", 1):get_name()
	local out, any = {}, false
	for i, s in ipairs(inv:get_list("bottles")) do
		local o = not s:is_empty() and CP.brew(s:get_name(), ing) or nil
		out[i] = o
		any = any or o ~= nil
	end
	return any and out or nil
end

-- Starts a brew if one can start; false and "recipe", "fuel", "brewer" or
-- "level" if not.
function CP.try_start(pos)
	local inv = ensure(pos)
	local meta = core.get_meta(pos)
	local out = outputs(inv)
	if not out then
		return false, "recipe"
	end
	local brewer = meta:get_string("brewer")
	if brewer == "" then
		return false, "brewer"
	end
	local need = 0
	for _, o in pairs(out) do
		need = math.max(need, CP.level(o))
	end
	if level_of(brewer) < need then
		local X = rawget(_G, "cb_xp")
		if X then
			X.notify(brewer, S("Not enough experience to brew this: level @1 needed", need))
		end
		return false, "level"
	end
	local cost = cost_for(brewer, out)
	local X = rawget(_G, "cb_xp")
	if cost and X.get(brewer) < cost then
		X.notify(brewer, S("Not enough experience to brew this: @1 points needed", cost))
		return false, "xp"
	end
	if meta:get_int("fuel") <= 0 then
		local f = inv:get_stack("fuel", 1)
		if f:get_name() ~= POWDER then
			return false, "fuel"
		end
		f:take_item()
		inv:set_stack("fuel", 1, f)
		meta:set_int("fuel", CP.STAND.FUEL)
	end
	meta:set_int("cost", cost or 0)
	meta:set_float("t", 0)
	core.get_node_timer(pos):start(1)
	refresh(pos)
	return true
end

local function finish(pos)
	local inv = ensure(pos)
	local meta = core.get_meta(pos)
	local out = outputs(inv)
	if not out then
		return
	end
	local cost, brewer, X = meta:get_int("cost"), meta:get_string("brewer"), rawget(_G, "cb_xp")
	if cost > 0 and X then
		if X.get(brewer) < cost then
			X.notify(brewer, S("Not enough experience to brew this: @1 points needed", cost))
			return
		end
		X.set(brewer, X.get(brewer) - cost)
	end
	local list = inv:get_list("bottles")
	for i, o in pairs(out) do
		list[i] = ItemStack(o)
	end
	inv:set_list("bottles", list)
	local ing = inv:get_stack("ingredient", 1)
	ing:take_item()
	inv:set_stack("ingredient", 1, ing)
	if ing:is_empty() then
		meta:set_string("brewer", "")
	end
	meta:set_int("fuel", math.max(0, meta:get_int("fuel") - 1))
	core.sound_play("cb_potions_brew", { pos = pos, max_hear_distance = 12, }, true)
end

local function on_timer(pos, elapsed)
	local meta = core.get_meta(pos)
	local inv = ensure(pos)
	if not outputs(inv) then
		meta:set_float("t", 0)
		refresh(pos)
		return false
	end
	local t = meta:get_float("t") + elapsed
	if t < CP.STAND.TIME then
		meta:set_float("t", t)
		refresh(pos)
		return true
	end
	meta:set_float("t", 0)
	finish(pos)
	CP.try_start(pos)
	refresh(pos)
	return false
end

local function allow_put(pos, list, _, stack, player)
	local name = player and player:get_player_name() or ""
	if core.is_protected(pos, name) then
		return 0
	end
	local item = stack:get_name()
	if list == "bottles" then
		return CP.parse(item) and 1 or 0
	elseif list == "fuel" then
		return item == POWDER and stack:get_count() or 0
	elseif list == "ingredient" then
		return CP.is_ingredient(item) and stack:get_count() or 0
	end
	return 0
end

local function allow_take(pos, _, _, stack, player)
	return core.is_protected(pos, player and player:get_player_name() or "") and 0 or stack:get_count()
end

local function allow_move(pos, from, fi, to, ti, count, player)
	local inv = core.get_meta(pos):get_inventory()
	local stack = inv:get_stack(from, fi)
	stack:set_count(count)
	return allow_put(pos, to, ti, stack, player)
end

local function changed(pos, list, player)
	if list == "ingredient" and player and player:is_player() then
		core.get_meta(pos):set_string("brewer", player:get_player_name())
	end
	-- any change restarts the brew: time and level count from now
	core.get_node_timer(pos):stop()
	core.get_meta(pos):set_float("t", 0)
	if not CP.try_start(pos) then
		refresh(pos)
	end
end

core.override_item(NAME, {
	on_construct = function(pos)
		ensure(pos)
	end,
	on_rightclick = function(pos, _, clicker)
		ensure(pos)
		if clicker and clicker.is_player and clicker:is_player() and clicker.get_inventory then
			core.show_formspec(clicker:get_player_name(), "cb_potions:stand", formspec(pos))
		end
	end,
	on_destruct = function(pos)
		local inv = core.get_meta(pos):get_inventory()
		for _, list in ipairs({ "bottles", "ingredient", "fuel", }) do
			for _, s in ipairs(inv:get_list(list) or {}) do
				if not s:is_empty() then
					core.add_item(vector.offset(pos, math.random() - 0.5, 0.3, math.random() - 0.5), s)
				end
			end
		end
	end,
	on_timer = on_timer,
	allow_metadata_inventory_put = allow_put,
	allow_metadata_inventory_take = allow_take,
	allow_metadata_inventory_move = allow_move,
	on_metadata_inventory_put = function(pos, list, _, _, player)
		changed(pos, list, player)
	end,
	on_metadata_inventory_take = function(pos, list, _, _, player)
		changed(pos, list, player)
	end,
	on_metadata_inventory_move = function(pos, _, _, to, _, _, player)
		changed(pos, to, player)
	end,
})
