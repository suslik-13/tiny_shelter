-- Armor trims (spec cycle 9, 4.4): smithing templates put a coloured pattern
-- on 3d_armor armour. A trim is item meta "cb_items:trim" = "<pattern>:<material>";
-- the body overlay is cb_items_trim_<pattern>_<piece>.png coloured like the
-- material. Textures: Mineclonia mcl_armor; raiser, shaper, host: Secret Terra
-- st_items (boots re-laid out for 3d_armor by tools/port_textures.py).
local S = cb_items.S
local T = {}
cb_items.trims = T

local KEY = "cb_items:trim"
local GREY = "#aaaaaa"

-- Pattern, description, block that duplicates the template (candidates).
local PATTERNS = {
	{ "sentry", S("Sentry Armor Trim"), { "default:cobble", }, },
	{ "dune", S("Dune Armor Trim"), { "default:sandstone", }, },
	{ "coast", S("Coast Armor Trim"), { "default:cobble", }, },
	{ "wild", S("Wild Armor Trim"), { "default:mossycobble", }, },
	{ "tide", S("Tide Armor Trim"), { "cb_blocks:prismarine", }, },
	{ "ward", S("Ward Armor Trim"), { "cb_blocks:cobbled_deepslate", }, },
	{ "vex", S("Vex Armor Trim"), { "default:cobble", }, },
	{ "rib", S("Rib Armor Trim"), { "cb_blocks:netherrack", "nether:rack", }, },
	{ "snout", S("Snout Armor Trim"), { "cb_blocks:blackstone", }, },
	{ "eye", S("Eye Armor Trim"), { "cb_blocks:end_stone", }, },
	{ "spire", S("Spire Armor Trim"), { "cb_blocks:purpur_block", }, },
	{ "silence", S("Silence Armor Trim"), { "cb_blocks:cobbled_deepslate", }, },
	{ "wayfinder", S("Wayfinder Armor Trim"), { "bakedclay:natural", }, },
	{ "raiser", S("Raiser Armor Trim"), { "bakedclay:natural", }, },
	{ "shaper", S("Shaper Armor Trim"), { "bakedclay:natural", }, },
	{ "host", S("Host Armor Trim"), { "bakedclay:natural", }, },
	{ "bolt", S("Bolt Armor Trim"), { "default:copperblock", }, },
	{ "flow", S("Flow Armor Trim"), { "cb_mobs_trial:breeze_rod", }, },
}

T.MATERIALS = {
	{ name = "steel", items = { "default:steel_ingot", }, colour = "#938e88", },
	{ name = "copper", items = { "default:copper_ingot", }, colour = "#c36447", },
	{ name = "gold", items = { "default:gold_ingot", }, colour = "#ce9627", },
	{ name = "diamond", items = { "default:diamond", }, colour = "#5faed8", },
	{ name = "emerald", items = { "cb_items:emerald", }, colour = "#1b9958", },
	{ name = "netherite", items = { "cb_blocks:netherite_ingot", }, colour = "#302a26", },
	{ name = "quartz", items = { "cb_blocks:quartz", }, colour = "#c9bcb9", },
	{ name = "mese", items = { "default:mese_crystal", }, colour = "#e3d93c", },
	{ name = "obsidian", items = { "default:obsidian_shard", }, colour = "#3b2754", },
}

T.PATTERNS = {}
local DESC, BY_MATERIAL, BY_ITEM = {}, {}, {}
for _, p in ipairs(PATTERNS) do
	T.PATTERNS[#T.PATTERNS + 1] = p[1]
	DESC[p[1]] = p[2]
end
for _, m in ipairs(T.MATERIALS) do
	BY_MATERIAL[m.name] = m
	for _, it in ipairs(m.items) do
		BY_ITEM[it] = m
	end
end

for _, p in ipairs(PATTERNS) do
	local name = "cb_items:trim_" .. p[1]
	core.register_craftitem(name, {
		description = p[2] .. "\n" .. core.colorize(GREY, S("Smithing Template")) .. "\n"
			.. core.colorize(GREY, S("Applies to: armor; with an ingot or a crystal")),
		inventory_image = "cb_items_trim_" .. p[1] .. ".png",
		groups = { smithing_template = 1, },
		_cb_trim = p[1],
	})
end

-- Duplication: 7 diamonds, the template and its block -> 2 templates.
core.register_on_mods_loaded(function()
	for _, p in ipairs(PATTERNS) do
		local block
		for _, c in ipairs(p[3]) do
			block = block or (core.registered_items[c] and c)
		end
		if block then
			local t, d = "cb_items:trim_" .. p[1], "default:diamond"
			core.register_craft({
				output = t .. " 2",
				recipe = { { d, t, d, }, { d, block, d, }, { d, d, d, }, },
			})
		end
	end
end)

local PIECES = { armor_head = "helmet", armor_torso = "chestplate", armor_legs = "leggings", armor_feet = "boots", }
local NOT_TRIMMABLE = { ["cb_items:elytra_wings"] = true, }

function T.piece_of(stack)
	local name = ItemStack(stack):get_name()
	if NOT_TRIMMABLE[name] or core.get_item_group(name, "armor_shield") > 0 then
		return nil
	end
	for group, piece in pairs(PIECES) do
		if core.get_item_group(name, group) > 0 then
			return piece
		end
	end
	return nil
end

function T.material_of(stack)
	local m = BY_ITEM[ItemStack(stack):get_name()]
	return m and m.name or nil
end

function T.pattern_of(stack)
	local def = core.registered_items[ItemStack(stack):get_name()]
	return def and def._cb_trim or nil
end

function T.get(stack)
	local s = ItemStack(stack):get_meta():get_string(KEY)
	local p, m = s:match("^([%w_]+):([%w_]+)$")
	if p and DESC[p] and BY_MATERIAL[m] then
		return p, m
	end
	return nil
end

local function material_desc(m)
	for _, it in ipairs(BY_MATERIAL[m].items) do
		local def = core.registered_items[it]
		if def and def.description then
			return def.description:match("^[^\n]*")
		end
	end
	return m
end

local function lines_of(p, m)
	return "\n" .. core.colorize(GREY, DESC[p]) .. "\n"
		.. core.colorize(BY_MATERIAL[m].colour, S("Material: @1", material_desc(m)))
end

-- Body overlay for 3d_armor ("" when not trimmed).
function T.overlay(stack)
	local p, m = T.get(stack)
	local piece = p and T.piece_of(stack)
	if not piece then
		return ""
	end
	return "^(cb_items_trim_" .. p .. "_" .. piece .. ".png^[colorize:" .. BY_MATERIAL[m].colour .. ":150)"
end

-- A copy of `armor` with the trim, or nil (not trimmable, unknown pattern or
-- material, or the same trim already). Wear and other meta are kept.
function T.apply(armor, pattern, material)
	armor = ItemStack(armor)
	local piece = T.piece_of(armor)
	if not piece or armor:get_count() ~= 1 or not DESC[pattern] or not BY_MATERIAL[material] then
		return nil
	end
	local op, om = T.get(armor)
	if op == pattern and om == material then
		return nil
	end
	local meta = armor:get_meta()
	local def = armor:get_definition()
	local desc = meta:get_string("description")
	if desc == "" then
		desc = def.description or armor:get_name()
	end
	if op then
		local old = lines_of(op, om)
		local i = desc:find(old, 1, true)
		if i then
			desc = desc:sub(1, i - 1) .. desc:sub(i + #old)
		end
	end
	-- Trim lines right after the name: cb_enchanting keeps everything before
	-- its own lines, so enchanting later does not drop them.
	local nl = desc:find("\n", 1, true)
	local new = lines_of(pattern, material)
	desc = nl and (desc:sub(1, nl - 1) .. new .. desc:sub(nl)) or (desc .. new)
	meta:set_string("description", desc)
	meta:set_string(KEY, pattern .. ":" .. material)
	meta:set_string("inventory_image", (def.inventory_image or "") .. "^(cb_items_trim_" .. piece
		.. "_mark.png^[colorize:" .. BY_MATERIAL[material].colour .. ":150)")
	return armor
end

-- After the item name changed (netherite upgrade): the icon mark on the new image.
function T.rebase(stack)
	local p, m = T.get(stack)
	local piece = p and T.piece_of(stack)
	if piece then
		stack:get_meta():set_string("inventory_image", (stack:get_definition().inventory_image or "")
			.. "^(cb_items_trim_" .. piece .. "_mark.png^[colorize:" .. BY_MATERIAL[m].colour .. ":150)")
	end
	return stack
end

-- Body texture with the trims of `stacks` on top of `base`.
function T.with_trims(base, stacks)
	local out = base
	for _, st in ipairs(stacks) do
		out = out .. T.overlay(st)
	end
	return out
end

local transparent = core.settings:get_bool("armor_transparent", false)

-- Player: 3d_armor builds textures[name].armor in set_player_armor and then
-- calls update_player_visuals; the trims go on top in that call only, so
-- later visual updates (skin changes) reuse the stored texture unchanged.
local A = rawget(_G, "armor")
if A and A.set_player_armor and A.update_player_visuals and not transparent then
	local set = A.set_player_armor
	function A.set_player_armor(self, player)
		local update = rawget(self, "update_player_visuals")
		self.update_player_visuals = function(s, p)
			local name, inv = s:get_valid_player(p, "[cb_items trims]")
			local tex = name and s.textures[name]
			if tex and inv and tex.armor then
				tex.armor = T.with_trims(tex.armor, inv:get_list("armor") or {})
			end
			return update(s, p)
		end
		local ok, err = pcall(set, self, player)
		self.update_player_visuals = update
		if not ok then
			error(err, 0)
		end
	end
	T.player_wrapped = true
end

-- Armour stand: after 3d_armor_stand sets the entity texture, add the trims
-- of the stand's armour (old stand: list "main"; new: "armor_<element>").
local STAND_ENTITY = "3d_armor_stand:armor_entity"
local STANDS = { "3d_armor_stand:armor_stand", "3d_armor_stand:locked_armor_stand", }

function T.stand_refresh(pos)
	pos = vector.round(pos)
	local inv = core.get_meta(pos):get_inventory()
	-- Only what the stand draws: old stand slot i = element i of "main".
	local stacks = {}
	for i, el in ipairs({ "head", "torso", "legs", "feet", }) do
		for _, st in ipairs({ inv:get_stack("main", i), inv:get_stack("armor_" .. el, 1), }) do
			if st:get_count() == 1 and core.get_item_group(st:get_name(), "armor_" .. el) > 0 then
				stacks[#stacks + 1] = st
			end
		end
	end
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.5)) do
		local e = obj:get_luaentity()
		if e and e.name == STAND_ENTITY then
			local cur = (obj:get_properties().textures or {})[1] or ""
			local base = (e._cb_trimmed == cur and e._cb_base) or cur
			local new = T.with_trims(base, stacks)
			e._cb_base, e._cb_trimmed = base, new
			if new ~= cur then
				obj:set_properties({ textures = { new, }, })
			end
		end
	end
end

local function after(fn)
	return function(pos, ...)
		local r = fn and fn(pos, ...)
		T.stand_refresh(pos)
		return r
	end
end

core.register_on_mods_loaded(function()
	local ent = core.registered_entities[STAND_ENTITY]
	if not ent then
		return
	end
	local activate = ent.on_activate
	ent.on_activate = function(self, ...)
		if activate then
			activate(self, ...)
		end
		local pos = self.object:get_pos()
		if pos then
			T.stand_refresh(pos)
		end
	end
	for _, name in ipairs(STANDS) do
		local def = core.registered_nodes[name]
		if def then
			core.override_item(name, {
				on_metadata_inventory_put = after(def.on_metadata_inventory_put),
				on_metadata_inventory_take = after(def.on_metadata_inventory_take),
			})
		end
	end
	local stand_set = {}
	for _, n in ipairs(STANDS) do
		stand_set[n] = true
	end
	for _, abm in ipairs(core.registered_abms) do
		local nodes = type(abm.nodenames) == "table" and abm.nodenames or { abm.nodenames, }
		local hit = false
		for _, n in ipairs(nodes) do
			hit = hit or stand_set[n] == true
		end
		if hit then
			abm.action = after(abm.action)
		end
	end
	T.stand_wrapped = true
end)
