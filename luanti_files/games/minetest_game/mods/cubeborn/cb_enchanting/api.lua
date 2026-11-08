-- Enchantments in item meta (spec 4.1): the item keeps its name, so toolranks
-- and everything else that knows the item keep working.
local E = cb_enchanting
local S = E.S
local KEY = "cb_ench"
local GLINT = "cb_enchanting_glint.png"
-- Our description lines start with one of these, so they can be stripped
-- from a description toolranks or another mod wrote.
local COLOUR, CURSE = "#b9a0ff", "#fc5454"
local MARKS = { "\n" .. core.get_color_escape_sequence(COLOUR), "\n" .. core.get_color_escape_sequence(CURSE), }

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", }
function E.roman(n)
	return ROMAN[n] or tostring(n)
end

local class_cache = {}

local function find_class(name)
	local def = core.registered_items[name]
	if not def or name == "" then
		return nil
	end
	if name == "cb_enchanting:book" then
		return "book"
	end
	for _, prefix in ipairs(E.NOT_ENCHANTABLE_PREFIX) do
		if name:sub(1, #prefix) == prefix then
			return nil
		end
	end
	-- old xdecor enchanted tools: migrate.lua turns them into plain ones
	if name:find(":enchanted_", 1, true) then
		return nil
	end
	if def.wear_represents == "technic_RE_charge" then
		return nil
	end
	if E.EXACT_CLASS[name] then
		return E.EXACT_CLASS[name]
	end
	local groups = def.groups or {}
	for _, g in ipairs(E.ARMOR_GROUPS) do
		if (groups[g] or 0) > 0 then
			return g
		end
	end
	if (groups.armor_shield or 0) > 0 then
		return "shield"
	end
	if not core.registered_tools[name] then
		return nil
	end
	for _, nc in ipairs(E.NAME_CLASS) do
		if name:find(nc[1], 1, true) then
			return nc[2]
		end
	end
	local caps = def.tool_capabilities
	local gc = caps and caps.groupcaps or {}
	if gc.cracky then
		return "pick"
	elseif gc.choppy then
		return "axe"
	elseif gc.crumbly then
		return "shovel"
	elseif gc.snappy and caps.damage_groups and (caps.damage_groups.fleshy or 0) >= 4 then
		return "sword"
	end
	return nil
end

-- The enchanting class of an item ("pick", "sword", "armor_head", "book", …) or nil.
function E.class(name)
	local c = class_cache[name]
	if c == nil then
		c = find_class(name) or false
		class_cache[name] = c
	end
	return c or nil
end

function E.enchantability(name)
	if name == "cb_enchanting:book" or name == "default:book" then
		return 1
	end
	local material = name:match("_([%a]+)$")
	return E.ENCHANTABILITY[material] or E.ENCHANTABILITY_DEFAULT
end

-- Whether the item supports the enchantment at all; second value: offered by the table.
function E.supports(name, ench)
	local def, class = E.DEFS[ench], E.class(name)
	if not def or not class then
		return false
	end
	if class == "book" then
		return true, not def.treasure
	end
	if def.primary[class] then
		return true, true
	end
	return def.secondary[class] == true, false
end

-- Pure check against an enchantment table `have` (for random rolls).
function E.can_add_to(name, have, ench, level)
	local def = E.DEFS[ench]
	if not def or not E.supports(name, ench) then
		return false, "unsupported"
	end
	if level < 1 or level > def.max then
		return false, "level"
	end
	if have[ench] then
		return false, "present"
	end
	if E.class(name) ~= "book" then
		for other in pairs(have) do
			if def.incompatible[other] or (E.DEFS[other] and E.DEFS[other].incompatible[ench]) then
				return false, "incompatible"
			end
		end
	end
	return true
end

function E.get(stack)
	local s = stack:get_meta():get_string(KEY)
	return s ~= "" and core.deserialize(s) or {}
end

function E.level(stack, ench)
	return E.get(stack)[ench] or 0
end

function E.can_add(stack, ench, level)
	return E.can_add_to(stack:get_name(), E.get(stack), ench, level)
end

function E.label(ench, level)
	local def = E.DEFS[ench]
	local text = E.LABELS[ench] or ench
	if def and def.max > 1 then
		text = text .. " " .. E.roman(level)
	end
	return text
end

-- The description without our lines: what toolranks (or the item) shows.
local function base_description(stack)
	local d = stack:get_meta():get_string("description")
	if d == "" then
		return nil
	end
	local cut
	for _, m in ipairs(MARKS) do
		local i = d:find(m, 1, true)
		if i and (not cut or i < cut) then
			cut = i
		end
	end
	return cut and d:sub(1, cut - 1) or d
end

local function sorted_names(t)
	local names = {}
	for n in pairs(t) do
		names[#names + 1] = n
	end
	table.sort(names, function(a, b)
		local ca, cb = E.DEFS[a] and E.DEFS[a].curse, E.DEFS[b] and E.DEFS[b].curse
		if ca ~= cb then
			return not ca
		end
		return a < b
	end)
	return names
end

-- Caps, description and glint from the stored enchantments.
function E.refresh(stack)
	local meta = stack:get_meta()
	local ench = E.get(stack)
	if E.apply_caps then
		E.apply_caps(stack, ench)
	end
	local base = base_description(stack)
	local lines = {}
	for _, n in ipairs(sorted_names(ench)) do
		local curse = E.DEFS[n] and E.DEFS[n].curse
		lines[#lines + 1] = "\n" .. core.colorize(curse and CURSE or COLOUR, E.label(n, ench[n]))
	end
	if #lines > 0 then
		meta:set_string("description", (base or stack:get_definition().description or "") .. table.concat(lines))
		meta:set_string("inventory_overlay", GLINT)
		meta:set_string("wield_overlay", GLINT)
	else
		meta:set_string("description", base or "")
		meta:set_string("inventory_overlay", "")
		meta:set_string("wield_overlay", "")
	end
	-- mobs_redo reads Looting from this meta field
	meta:set_string("looting_level", (ench.looting or 0) > 0 and tostring(ench.looting) or "")
	return stack
end

function E.set(stack, t)
	stack:get_meta():set_string(KEY, next(t) and core.serialize(t) or "")
	return E.refresh(stack)
end

function E.enchant(stack, ench, level)
	local t = E.get(stack)
	t[ench] = level
	return E.set(stack, t)
end

core.register_craftitem("cb_enchanting:book", {
	description = S("Enchanted Book"),
	inventory_image = "default_book.png^[colorize:#8a3fd1:90",
	stack_max = 1,
	groups = { book = 1, not_in_creative_inventory = 1, },
})
