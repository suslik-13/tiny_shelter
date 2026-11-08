-- The brewing table (spec 4.3, 4.4, 4.4a.1): CP.brew(input, ingredient)
-- gives the potion a bottle becomes, or nil. Bedrock's recipes with
-- etherium dust for redstone; the fermented spider eye spoils drinkable
-- potions only, and a harmful potion turns splash only with the explosive
-- charge, so every harmful thrown potion costs a ghast tear.
local CP = cb_potions

local WART, GLOW, DUST = "cb_blocks:nether_wart", "cb_blocks:glowstone_dust", "ethereal:etherium_dust"
local FERMENTED, POWDER, CHARGE, BREATH = "cb_potions:fermented_spider_eye", "tnt:gunpowder", "cb_potions:charge",
	"cb_mobs_dim:dragon_breath"

-- awkward + ingredient -> kind
CP.AWKWARD = {
	["cb_potions:glistering_melon"] = "healing",
	["farming:carrot_gold"] = "night_vision",
	["farming:sugar"] = "swiftness",
	["cb_mobs_nether:magma_cream"] = "fire_resistance",
	["cb_items:blaze_powder"] = "strength",
	["cb_mobs_water:pufferfish_item"] = "water_breathing",
	["cb_mobs_nether:ghast_tear"] = "regeneration",
	["cb_potions:spider_eye"] = "poison",
	["cb_potions:rabbit_foot"] = "leaping",
	["cb_items:phantom_membrane"] = "slow_falling",
	["cb_potions:turtle_shell"] = "turtle_master",
	["default:stone"] = "infestation",
	["ethereal:slime_block"] = "oozing",
	["cb_blocks:cobweb"] = "weaving",
	["cb_mobs_trial:breeze_rod"] = "wind_charged",
}

-- water + any of these (besides the wart, glowstone, the fermented eye) -> mundane
local MUNDANE = { "cb_potions:glistering_melon", "farming:sugar", "cb_potions:spider_eye", "cb_mobs_nether:magma_cream",
	"cb_items:blaze_powder", "cb_mobs_nether:ghast_tear", "cb_potions:rabbit_foot", DUST, }

-- fermented spider eye: kind -> { kind, keeps long, keeps strong }
local SPOIL = {
	healing = { "harming", false, true, },
	poison = { "harming", false, true, },
	swiftness = { "slowness", true, false, },
	leaping = { "slowness", true, false, },
	night_vision = { "invisibility", true, false, },
}

CP.INGREDIENTS = { WART, GLOW, DUST, FERMENTED, POWDER, CHARGE, BREATH, }
for item in pairs(CP.AWKWARD) do
	CP.INGREDIENTS[#CP.INGREDIENTS + 1] = item
end
local is_ingredient = {}
for _, item in ipairs(CP.INGREDIENTS) do
	is_ingredient[item] = true
end

function CP.is_ingredient(item)
	return is_ingredient[item] == true
end

function CP.brew(input, ingredient)
	local kind, variant, form = CP.parse(input)
	if not kind then
		return nil
	end
	local k = CP.KINDS[kind]
	if kind == "water" then
		if ingredient == WART then
			return "cb_potions:awkward"
		elseif ingredient == GLOW then
			return "cb_potions:thick"
		elseif ingredient == FERMENTED then
			return "cb_potions:weakness"
		end
		for _, m in ipairs(MUNDANE) do
			if m == ingredient then
				return "cb_potions:mundane"
			end
		end
		return nil
	elseif kind == "mundane" then
		return ingredient == FERMENTED and "cb_potions:weakness" or nil
	elseif kind == "awkward" then
		local out = CP.AWKWARD[ingredient]
		return out and CP.name(out) or nil
	elseif not CP.throwable(kind) then
		return nil
	end
	if ingredient == DUST then
		return (k.long and not variant) and CP.name(kind, "long", form) or nil
	elseif ingredient == GLOW then
		return (k.strong and not variant) and CP.name(kind, "strong", form) or nil
	elseif ingredient == FERMENTED then
		local s = not form and SPOIL[kind]
		if not s then
			return nil
		end
		local v = (variant == "long" and s[2] and "long") or (variant == "strong" and s[3] and "strong") or nil
		return CP.name(s[1], v)
	elseif ingredient == POWDER then
		return (not form and not k.harmful) and CP.name(kind, variant, "splash") or nil
	elseif ingredient == CHARGE then
		return (not form and k.harmful) and CP.name(kind, variant, "splash") or nil
	elseif ingredient == BREATH then
		return form == "splash" and CP.name(kind, variant, "lingering") or nil
	end
	return nil
end
