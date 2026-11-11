-- The potion items: drinkable, splash and lingering of every kind. A grey
-- tooltip tells the effects, their time and the level to brew it.
local CP, S = cb_potions, cb_potions.S
local E = cb_core.effects
local ROMAN = { "", " II", " III", " IV", " V", " VI", }

local function clock(secs)
	secs = math.floor(secs + 0.5)
	return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

local function title(kind, variant, form)
	local k = CP.KINDS[kind]
	if not k.label then
		return k.name
	end
	local t = form == "splash" and S("Splash Potion of @1", k.label)
		or form == "lingering" and S("Lingering Potion of @1", k.label) or S("Potion of @1", k.label)
	return variant == "strong" and t .. " " .. (k.roman or "II") or t
end

local function tooltip(item, form)
	local lines = {}
	local list, instant = CP.effects_of(item)
	for _, e in ipairs(list) do
		local def = E.defs[e[1]]
		local secs = form == "lingering" and e[3] / 4 or e[3]
		lines[#lines + 1] = (def and def.description or e[1]) .. ROMAN[e[2]] .. " (" .. clock(secs) .. ")"
	end
	if instant then
		local n = math.abs(instant) / math.abs(CP.KINDS[(CP.parse(item))].instant)
		lines[#lines + 1] = (instant > 0 and S("Instant Health") or S("Instant Damage")) .. ROMAN[n]
	end
	-- experience off (no cb_xp): brewing has no level or cost
	local xp = rawget(_G, "cb_xp")
	local lvl = CP.level(item)
	if xp and lvl > 0 then
		lines[#lines + 1] = S("Requires level @1 to brew", lvl)
	end
	if xp and CP.parse(item) ~= "water" then
		lines[#lines + 1] = S("Brewing costs @1 experience points", CP.xp_cost(item))
	end
	return #lines > 0 and "\n" .. core.colorize("#a8a8a8", table.concat(lines, "\n")) or ""
end

local function image(kind, form)
	local color = CP.KINDS[kind].color
	if form then
		return "(cb_potions_splash_overlay.png^[colorize:" .. color .. ":255)^cb_potions_" .. form .. "_bottle.png"
	end
	return "(cb_potions_overlay.png^[colorize:" .. color .. ":255)^cb_potions_bottle.png"
end

local function drink(itemstack, user)
	if not (user and user:is_player()) then
		return itemstack
	end
	CP.drink(user, itemstack:get_name())
	core.sound_play("cb_potions_drink", { pos = user:get_pos(), max_hear_distance = 8, }, true)
	if core.is_creative_enabled(user:get_player_name()) then
		return itemstack
	end
	return ItemStack("vessels:glass_bottle")
end

local function throw(itemstack, user, pointed)
	if CP.throw and user and user:is_player() then
		return CP.throw(itemstack, user, pointed)
	end
	return itemstack
end

for kind, k in pairs(CP.KINDS) do
	local variants = { false, }
	if k.long then
		variants[#variants + 1] = "long"
	end
	if k.strong then
		variants[#variants + 1] = "strong"
	end
	local forms = { false, }
	if CP.throwable(kind) then
		forms[#forms + 1] = "splash"
		forms[#forms + 1] = "lingering"
	end
	for _, v in ipairs(variants) do
		for _, f in ipairs(forms) do
			local name = CP.name(kind, v or nil, f or nil)
			core.register_craftitem(name, {
				description = title(kind, v or nil, f or nil) .. tooltip(name, f or nil),
				inventory_image = image(kind, f or nil),
				wield_image = image(kind, f or nil),
				stack_max = 1,
				groups = { cb_potion = 1, cb_potion_thrown = f and 1 or nil, not_in_creative_inventory = (v or f) and 1 or nil, },
				on_use = f and throw or drink,
			})
		end
	end
end
