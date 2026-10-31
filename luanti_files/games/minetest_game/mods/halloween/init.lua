-- Halloween: a purely cosmetic, temporary mod.
--
-- It only changes how already existing nodes, items and mobs LOOK.
-- Nothing is registered and nothing is written into the map, node meta,
-- inventories or mob staticdata, so after the event the mod folder can simply
-- be deleted and everything returns to the normal look.
--
--   apples           -> apples wrapped in cobweb
--   torches          -> glowing skulls
--   locked chests    -> small coffins
--   chests           -> jack-o'-lanterns
--   all armor        -> bones painted on top
--   sheep            -> skeletons with a pumpkin head
--   unified_inventory -> cobwebs, cracks and spiders on the background,
--                        pumpkins, skulls, bones and coffins along the bottom

local function override(name, def)
	if minetest.registered_items[name] then
		minetest.override_item(name, def)
	end
end

-- Calls fn on every texture string of a tiles list, returns a new list.
-- Animated tiles are left untouched (an overlay would break the frames).
local function map_tiles(tiles, fn)
	if not tiles then
		return nil
	end
	local out = {}
	for i, tile in ipairs(tiles) do
		if type(tile) == "string" then
			out[i] = fn(tile)
		elseif type(tile) == "table" and not tile.animation then
			local t = table.copy(tile)
			if t.name then
				t.name = fn(t.name)
			elseif t.image then
				t.image = fn(t.image)
			end
			out[i] = t
		else
			out[i] = tile
		end
	end
	return out
end

local function overlay_fn(overlay)
	return function(tex)
		return "(" .. tex .. ")^" .. overlay
	end
end

-- Replaces whole texture file names inside a texture string.
local function rename_fn(map)
	return function(tex)
		for from, to in pairs(map) do
			tex = tex:gsub(from:gsub("%p", "%%%0"), (to:gsub("%%", "%%%%")))
		end
		return tex
	end
end

local function has_items(...)
	for _, name in ipairs({...}) do
		if minetest.registered_items[name] then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- apples

local function apples()
	local def = minetest.registered_nodes["default:apple"]
	if not def then
		return
	end
	local web = overlay_fn("halloween_cobweb_apple.png")
	local inv = def.inventory_image ~= "" and def.inventory_image or "default_apple.png"
	override("default:apple", {
		tiles = map_tiles(def.tiles, web),
		inventory_image = web(inv),
		wield_image = web(def.wield_image ~= "" and def.wield_image or inv),
	})
end

---------------------------------------------------------------- torches

local function skull_tile(name)
	return {name = name, backface_culling = false}
end

local skull_front = {
	name = "halloween_skull_front.png",
	backface_culling = false,
	animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 2.4},
}

local function torches()
	-- the skull is a 6x6x6 px cube; the meshes keep the torch placement
	-- logic (floor / wall / ceiling) of default untouched
	override("default:torch", {
		mesh = "halloween_skull_floor.obj",
		tiles = {skull_front, skull_tile("halloween_skull_top.png"),
			skull_tile("halloween_skull_bottom.png")},
		inventory_image = "halloween_skull_inv.png",
		wield_image = "halloween_skull_inv.png",
		selection_box = {
			type = "wallmounted",
			wall_bottom = {-3/16, -1/2, -3/16, 3/16, -2/16, 3/16},
		},
	})
	override("default:torch_wall", {
		mesh = "halloween_skull_wall.obj",
		tiles = {skull_front, skull_tile("halloween_skull_side.png"),
			skull_tile("halloween_skull_top.png"), skull_tile("halloween_skull_bottom.png"),
			skull_tile("halloween_skull_back.png")},
		selection_box = {
			type = "wallmounted",
			wall_side = {-1/2, -2/16, -3/16, -2/16, 4/16, 3/16},
		},
	})
	override("default:torch_ceiling", {
		mesh = "halloween_skull_ceiling.obj",
		tiles = {skull_front, skull_tile("halloween_skull_top.png"),
			skull_tile("halloween_skull_bottom.png")},
		selection_box = {
			type = "wallmounted",
			wall_top = {-3/16, 2/16, -3/16, 3/16, 1/2, 3/16},
		},
	})
end

---------------------------------------------------------------- chests

local pumpkin = rename_fn({
	["default_chest_top.png"] = "halloween_pumpkin_top.png",
	["default_chest_side.png"] = "halloween_pumpkin_side.png",
	["default_chest_front.png"] = "halloween_pumpkin_front.png",
	["default_chest_inside.png"] = "halloween_pumpkin_inside.png",
	["connected_chests_front.png"] = "halloween_pumpkin_front.png",
})

local coffin = rename_fn({
	["default_chest_top.png"] = "halloween_coffin_top.png",
	["default_chest_side.png"] = "halloween_coffin_side.png",
	["default_chest_lock.png"] = "halloween_coffin_front.png",
	["default_chest_inside.png"] = "halloween_coffin_inside.png",
	["connected_chests_front.png"] = "halloween_coffin_side.png",
})

-- small coffin seen from above: narrow head, wide shoulders, narrower feet
local coffin_box = {
	{-4/16, -8/16,  4/16, 4/16, -1/16,  7/16},
	{-6/16, -8/16, -1/16, 6/16, -1/16,  4/16},
	{-5/16, -8/16, -7/16, 5/16, -1/16, -1/16},
}
local coffin_open_box = {
	{-4/16, -8/16,  4/16, 4/16, -3/16,  7/16},
	{-6/16, -8/16, -1/16, 6/16, -3/16,  4/16},
	{-5/16, -8/16, -7/16, 5/16, -3/16, -1/16},
}
local coffin_sel = {-6/16, -8/16, -7/16, 6/16, -1/16, 7/16}
local coffin_open_sel = {-6/16, -8/16, -7/16, 6/16, -3/16, 7/16}

local function chests()
	for name, def in pairs(minetest.registered_nodes) do
		if name:find("^default:chest_locked") then
			override(name, {tiles = map_tiles(def.tiles, coffin)})
		elseif name:find("^default:chest") then
			override(name, {tiles = map_tiles(def.tiles, pumpkin)})
		end
	end

	-- the single locked chest also gets the coffin shape
	override("default:chest_locked", {
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = coffin_box},
		selection_box = {type = "fixed", fixed = coffin_sel},
		collision_box = {type = "fixed", fixed = coffin_sel},
	})
	override("default:chest_locked_open", {
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = coffin_open_box},
		selection_box = {type = "fixed", fixed = coffin_open_sel},
		collision_box = {type = "fixed", fixed = coffin_open_sel},
		tiles = {
			"halloween_coffin_inside.png", "halloween_coffin_top.png",
			"halloween_coffin_side.png", "halloween_coffin_side.png",
			"halloween_coffin_side.png", "halloween_coffin_front.png",
		},
	})
end

---------------------------------------------------------------- armor

local armor_slots = {
	armor_head = "head",
	armor_torso = "torso",
	armor_legs = "legs",
	armor_feet = "feet",
	armor_shield = "shield",
}

local function armor()
	for name, def in pairs(minetest.registered_tools) do
		local g = def.groups or {}
		for group, slot in pairs(armor_slots) do
			if (g[group] or 0) > 0 then
				-- same fallbacks as 3d_armor uses (api.lua: armor:set_player_armor)
				local tex = (def.texture or name:gsub(":", "_")):gsub("%.png$", "")
				local prev = (def.preview or tex .. "_preview"):gsub("%.png$", "")
				local inv = def.inventory_image
				override(name, {
					texture = tex .. ".png^halloween_bones_" .. slot .. ".png",
					preview = prev .. ".png^halloween_bones_" .. slot .. "_preview.png",
					inventory_image = inv and inv ~= "" and
						"(" .. inv .. ")^halloween_bones_badge.png" or nil,
				})
				break
			end
		end
	end
end

---------------------------------------------------------------- sheep

-- survival_shelter runs an older mobs_animal with a different sheep model
-- (and a separate model for shaved sheep), it needs its own textures
local function old_sheep_model()
	local mp = minetest.get_modpath("mobs_animal")
	if not mp then
		return false
	end
	local ok, f = pcall(io.open, mp .. "/models/mobs_sheep_shaved.b3d", "rb")
	if ok and f then
		f:close()
		return true
	end
	return false
end

-- Textures are only changed on the live object. The mob's own fields
-- (base_texture etc.) are not touched, so nothing Halloween-related ends up
-- in the saved staticdata.
local function sheep()
	local old_model = old_sheep_model()
	local timers = setmetatable({}, {__mode = "k"})

	local function wanted(props)
		if not old_model then
			return "halloween_sheep.png"
		elseif props.mesh == "mobs_sheep_shaved.b3d" then
			return "halloween_sheep_old_shaved.png"
		end
		return "halloween_sheep_old.png"
	end

	local function apply(self)
		local props = self.object:get_properties()
		if not props then
			return
		end
		local tex = wanted(props)
		if not props.textures or props.textures[1] ~= tex then
			self.object:set_properties({textures = {tex}})
		end
	end

	for name, def in pairs(minetest.registered_entities) do
		if name:find("^mobs_animal:sheep_") then
			local on_activate = def.on_activate
			local on_step = def.on_step
			def.on_activate = function(self, staticdata, dtime)
				if on_activate then
					on_activate(self, staticdata, dtime)
				end
				if self.object:get_pos() then
					apply(self)
				end
			end
			-- mobs_animal resets the texture on shearing, dyeing, regrowing
			-- wool etc., so it is checked again from time to time
			def.on_step = function(self, dtime, moveresult)
				if on_step then
					on_step(self, dtime, moveresult)
				end
				local t = (timers[self] or 0) + dtime
				if t >= 0.5 then
					t = 0
					if self.object:get_pos() then
						apply(self)
					end
				end
				timers[self] = t
			end
		end
	end
end

---------------------------------------------------------------- unified_inventory

local F = minetest.formspec_escape

-- Builds the decoration for one unified_inventory layout (full or lite).
-- Everything except the two dropping spiders is a background[] element, so it
-- is drawn under the slots, buttons and text of the inventory. The form gets
-- a strip of graveyard ground at the bottom (ground_h high).
local ground_h = 0.75

local ground_items = {
	{"halloween_ui_pumpkin.png", 18, 16},
	{"halloween_ui_bones.png", 22, 16},
	{"halloween_ui_skull.png", 14, 13},
	{"halloween_ui_coffin.png", 28, 13},
	{"halloween_ui_skull.png", 14, 13},
	{"halloween_ui_pumpkin.png", 18, 16},
	{"halloween_ui_bones.png", 22, 16},
	{"halloween_ui_coffin.png", 28, 13},
	{"halloween_ui_pumpkin.png", 18, 16},
	{"halloween_ui_skull.png", 14, 13},
}
local ground_gaps = {0.35, 0.9, 0.2, 0.6, 1.1, 0.4, 0.15, 0.8, 0.5}

local function ui_decor(ui, style)
	local W, H = style.formw, style.formh
	local s = style.is_lite_mode and 0.8 or 1
	local img = ui.imgscale or 1.25
	local out = {}

	local function bg(x, y, w, h, tex)
		out[#out + 1] = ("background[%.3f,%.3f;%.3f,%.3f;%s;false]"):format(x, y, w, h, F(tex))
	end

	-- free areas of the main page: left of the craft grid and between the
	-- craft result slot and the item browser
	local bottom = style.std_inv_y - 0.15
	local left_w = style.craft_x - 0.1
	local gap_x = style.craft_x + img * 5 + 0.05
	local gap_w = math.max(0.6, style.page_x - 0.2 - gap_x)

	-- cracks
	bg(0.05, bottom * 0.3, 1.4 * s, 2.3 * s, "halloween_ui_crack1.png")
	bg(style.craft_x + 0.6, 0.03, 1.3 * s, 1.1 * s, "halloween_ui_crack2.png")
	bg(gap_x, bottom * 0.5, gap_w, 1.9 * s, "halloween_ui_crack3.png")
	bg(W - 1.05 * s, H - 1.6 * s, 1.0 * s, 1.5 * s, "halloween_ui_crack4.png")

	-- graveyard ground with pumpkins, skulls, bones and coffins
	bg(0, H - 0.1, W, ground_h + 0.1, "halloween_ui_ground.png")
	local px = 0.045 * s -- one sprite pixel
	local x, i = 0.3, 1
	while true do
		local it = ground_items[(i - 1) % #ground_items + 1]
		local w, h = it[2] * px, it[3] * px
		if x + w > W - 0.3 then
			break
		end
		bg(x, H + ground_h - 0.08 - h, w, h, it[1])
		x = x + w + ground_gaps[(i - 1) % #ground_gaps + 1] * s
		i = i + 1
	end

	-- cobwebs: big ones in the corners, smaller ones in the free areas
	local cw = 2.4 * s
	local fh = H + ground_h
	bg(0, 0, cw, cw, "halloween_ui_web_black.png")
	bg(W - cw, 0, cw, cw, "halloween_ui_web_white.png^[transformFX")
	bg(0, fh - cw, cw, cw, "halloween_ui_web_white.png^[transformFY")
	bg(W - cw, fh - cw, cw, cw, "halloween_ui_web_black.png^[transformR180")
	local top_x = style.craft_x + 3.4 * s
	bg(top_x, 0, 1.6 * s, 0.8 * s, "halloween_ui_web_top.png")
	local round = math.min(1.2 * s, left_w * 0.5)
	bg(0.1, bottom - round - 0.1, round, round, "halloween_ui_web_round.png")

	-- spiders sitting on the webs (sprite is 17x14 px)
	local sw, sh = 17 * px * 1.3, 14 * px * 1.3
	bg(0.55 * s, fh - 1.3 * s, sw, sh, "halloween_ui_spider.png^[transformR180")
	bg(W - 1.2 * s, fh - 1.6 * s, sw, sh, "halloween_ui_spider.png^[transformFX")
	bg(top_x + 0.8 * s - sw / 2, 0.18 * s, sw, sh, "halloween_ui_spider.png")
	bg(0.1 + round / 2 - sw / 2, bottom - round / 2 - 0.1 - sh / 2, sw, sh,
		"halloween_ui_spider.png")

	-- spiders going down and up on their threads (25 frames of 18x160 px, the
	-- short one 18x100 px: it stops above the trash slot)
	local drop_h = bottom - 0.15
	local drop_w = drop_h * 18 / 160
	out[#out + 1] = ("animated_image[%.3f,%.3f;%.3f,%.3f;halloween_spider_1;%s;25;140;1]"):format(
		left_w * 0.62 - drop_w / 2, 0.15, drop_w, drop_h, "halloween_ui_spider_drop.png")
	out[#out + 1] = ("animated_image[%.3f,%.3f;%.3f,%.3f;halloween_spider_2;%s;25;170;13]"):format(
		gap_x + gap_w / 2 - drop_w / 2, 0.05, drop_w, drop_w * 100 / 18,
		"halloween_ui_spider_drop_short.png")

	return table.concat(out)
end

-- Wraps unified_inventory.get_formspec: the decoration is inserted right
-- after the standard background and the form is made ground_h taller.
-- Only the formspec string sent to the client changes.
local function unified_inventory_decor()
	local ui = rawget(_G, "unified_inventory")
	if type(ui) ~= "table" or type(ui.get_formspec) ~= "function"
			or type(ui.get_per_player_formspec) ~= "function"
			or type(ui.standard_background) ~= "string" then
		return
	end
	local get_formspec = ui.get_formspec
	local cache = {}

	ui.get_formspec = function(player, page, ...)
		local fs = get_formspec(player, page, ...)
		if type(fs) ~= "string" or fs == "" or not player then
			return fs
		end
		local style = ui.get_per_player_formspec(player:get_player_name())
		if not style or not style.formw or not style.formh then
			return fs
		end
		local size = "size[" .. style.formw .. "," .. style.formh .. "]"
		local s1, e1 = fs:find(size, 1, true)
		local s2, e2 = fs:find(ui.standard_background, 1, true)
		if not s1 or not s2 or s2 < e1 then
			return fs
		end
		local key = style.is_lite_mode and "lite" or "full"
		cache[key] = cache[key] or ui_decor(ui, style)
		return fs:sub(1, s1 - 1)
			.. "size[" .. style.formw .. "," .. (style.formh + ground_h) .. "]"
			.. fs:sub(e1 + 1, e2) .. cache[key] .. fs:sub(e2 + 1)
	end
end

----------------------------------------------------------------

minetest.register_on_mods_loaded(function()
	if has_items("default:apple") then apples() end
	if has_items("default:torch") then torches() end
	if has_items("default:chest") then chests() end
	armor()
	sheep()
	unified_inventory_decor()
end)
