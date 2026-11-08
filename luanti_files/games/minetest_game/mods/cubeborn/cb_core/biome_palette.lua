-- Which village palette fits a place: the biome name (minetest_game and
-- ethereal) decides by keywords, first match wins. Noise only, so it works
-- for places that are not generated yet.
cb_core.PALETTES = { "plains", "desert", "savanna", "taiga", "snowy", }

local RULES = {
	{ "snowy", { "snowy", "tundra", "icesheet", "glacier", "frost", }, },
	{ "taiga", { "taiga", "coniferous", }, },
	{ "savanna", { "savanna", "mesa", "prairie", }, },
	{ "desert", { "desert", "fiery", }, },
}

function cb_core.palette_of_biome(name)
	for _, rule in ipairs(RULES) do
		for _, word in ipairs(rule[2]) do
			if name:find(word, 1, true) then
				return rule[1]
			end
		end
	end
	return "plains"
end

function cb_core.biome_palette(pos)
	local data = core.get_biome_data(pos)
	local name = data and core.get_biome_name(data.biome)
	return cb_core.palette_of_biome(name or "")
end
