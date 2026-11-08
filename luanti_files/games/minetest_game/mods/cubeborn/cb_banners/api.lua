-- Colours, patterns, the layer string and textures.
local S = cb_banners.S
local B = cb_banners
B.MAX_LAYERS = 6
-- the servers' wool and dye names; rgb from Mineclonia's mcl_dyes
B.COLOURS = {
	white = { S("White"), "#d0d6d7", }, grey = { S("Light Grey"), "#818177", },
	dark_grey = { S("Grey"), "#383c40", }, black = { S("Black"), "#080a10", },
	violet = { S("Purple"), "#6821a0", }, blue = { S("Blue"), "#2e3094", },
	light_blue = { S("Light Blue"), "#258ec9", }, cyan = { S("Cyan"), "#167b8c", },
	dark_green = { S("Green"), "#4b5e25", }, green = { S("Lime"), "#60ac19", },
	yellow = { S("Yellow"), "#f1b216", }, brown = { S("Brown"), "#633d20", },
	orange = { S("Orange"), "#e26501", }, red = { S("Red"), "#912222", },
	magenta = { S("Magenta"), "#ab31a2", }, pink = { S("Pink"), "#d56791", },
}
-- id (texture name) -> short code for the layer string (Minecraft's), name
local function p(code, name, special)
	return { code = code, name = name, special = special or false, }
end
B.PATTERNS = {
	border = p("bo", S("Bordure")), circle = p("mc", S("Roundel")), cross = p("cr", S("Saltire")),
	diagonal_up_left = p("lud", S("Per Bend Inverted")), diagonal_up_right = p("rud", S("Per Bend Sinister Inverted")),
	diagonal_right = p("rd", S("Per Bend")), diagonal_left = p("ld", S("Per Bend Sinister")),
	gradient = p("gra", S("Gradient")), gradient_up = p("gru", S("Base Gradient")),
	half_horizontal_bottom = p("hhb", S("Per Fess Inverted")), half_horizontal = p("hh", S("Per Fess")),
	half_vertical = p("vh", S("Per Pale")), half_vertical_right = p("vhr", S("Per Pale Inverted")),
	rhombus = p("mr", S("Lozenge")), small_stripes = p("ss", S("Paly")),
	square_bottom_left = p("bl", S("Base Dexter Canton")), square_bottom_right = p("br", S("Base Sinister Canton")),
	square_top_left = p("tl", S("Chief Dexter Canton")), square_top_right = p("tr", S("Chief Sinister Canton")),
	straight_cross = p("sc", S("Cross")), stripe_bottom = p("bs", S("Base")), stripe_center = p("cs", S("Pale")),
	stripe_downleft = p("dls", S("Bend Sinister")), stripe_downright = p("drs", S("Bend")),
	stripe_left = p("ls", S("Pale Dexter")), stripe_middle = p("ms", S("Fess")), stripe_right = p("rs", S("Pale Sinister")),
	stripe_top = p("ts", S("Chief")), triangle_bottom = p("bt", S("Chevron")), triangle_top = p("tt", S("Chevron Inverted")),
	triangles_bottom = p("bts", S("Base Indented")), triangles_top = p("tts", S("Chief Indented")),
	flower = p("flo", S("Flower Charge"), true), bricks = p("bri", S("Field Masoned"), true),
	curly_border = p("cbo", S("Bordure Indented"), true), skull = p("sku", S("Skull Charge"), true),
}
B.DYE_PATTERNS, B.BY_CODE = {}, {}
for id, def in pairs(B.PATTERNS) do
	B.BY_CODE[def.code] = id
	if not def.special then
		B.DYE_PATTERNS[#B.DYE_PATTERNS + 1] = id
	end
end
table.sort(B.DYE_PATTERNS)

function B.item(colour)
	return "cb_banners:banner_" .. colour
end

function B.decode(s)
	local out = {}
	for code, colour in (s or ""):gmatch("([%w_]+):([%w_]+)") do
		local id = B.BY_CODE[code]
		if id and B.COLOURS[colour] then
			out[#out + 1] = { id, colour, }
		end
	end
	return out
end

function B.encode(layers)
	local t = {}
	for i, l in ipairs(layers) do
		t[i] = B.PATTERNS[l[1]].code .. ":" .. l[2]
	end
	return table.concat(t, ";")
end

function B.layers(stack)
	return B.decode(stack:get_meta():get_string("cb_layers"))
end

-- [combine escaping: a backslash escapes the next character, so backslashes
-- themselves are escaped too (the icon nests one [combine in another)
local function esc(t)
	return (t:gsub("[%^:\\]", "\\%0"))
end

local function coats(layers)
	local t = ""
	for _, l in ipairs(layers or {}) do
		local tex = "cb_banners_" .. l[1] .. ".png"
		t = t .. "^(" .. tex .. "^[colorize:" .. B.COLOURS[l[2]][2] .. ":255^[mask:" .. tex .. ")"
	end
	return t
end

function B.texture(colour, layers)
	local rgb = B.COLOURS[colour] and B.COLOURS[colour][2] or "#ffffff"
	return "(cb_banners_banner_base.png^[mask:cb_banners_base_inverted.png)^((cb_banners_banner_base.png^[colorize:"
		.. rgb .. ":255)^[mask:cb_banners_base.png)" .. coats(layers)
end

function B.item_texture(colour, layers)
	local rgb = B.COLOURS[colour] and B.COLOURS[colour][2] or "#ffffff"
	local base = "cb_banners_item_base_48.png^(cb_banners_item_overlay_48.png^[colorize:" .. rgb .. ":255)"
	local c = coats(layers)
	if c == "" then
		return base
	end
	-- the pattern's front (20x40 at 1,1 of the 64x64 skin) over the item at 14,4
	return "[combine:48x48:0,0=" .. esc(base) .. ":14,4=" .. esc("[combine:20x40:-1,-1=" .. esc(c:sub(2) .. "^[resize:64x64"))
end

function B.refresh(stack)
	local def = stack:get_definition()
	local meta = stack:get_meta()
	local layers = B.layers(stack)
	if #layers == 0 then
		meta:set_string("description", "")
		meta:set_string("inventory_image", "")
		meta:set_string("wield_image", "")
		return stack
	end
	local lines = { meta:get_string("cb_ominous") ~= "" and S("Ominous Banner") or def.description, }
	for i = 1, math.min(#layers, B.MAX_LAYERS) do
		lines[#lines + 1] = core.colorize("#a0a0a0", S("@1 @2", B.COLOURS[layers[i][2]][1], B.PATTERNS[layers[i][1]].name))
	end
	if #layers > B.MAX_LAYERS then
		lines[#lines + 1] = core.colorize("#a0a0a0", S("And @1 more", #layers - B.MAX_LAYERS))
	end
	meta:set_string("description", table.concat(lines, "\n"))
	local img = B.item_texture(def._cb_colour, layers)
	meta:set_string("inventory_image", img)
	meta:set_string("wield_image", img)
	return stack
end

function B.set_layers(stack, layers)
	stack:get_meta():set_string("cb_layers", B.encode(layers))
	return B.refresh(stack)
end
