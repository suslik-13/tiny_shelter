-- Pottery sherds (spec cycle 9, 4.3): found by brushing, crafted into
-- decorated pots. Textures from Mineclonia mcl_pottery_sherds.
local S = cb_archaeology.S

local NAMES = {
	{ "angler", S("Angler Pottery Sherd"), }, { "archer", S("Archer Pottery Sherd"), },
	{ "arms_up", S("Arms Up Pottery Sherd"), }, { "blade", S("Blade Pottery Sherd"), },
	{ "brewer", S("Brewer Pottery Sherd"), }, { "burn", S("Burn Pottery Sherd"), },
	{ "danger", S("Danger Pottery Sherd"), }, { "explorer", S("Explorer Pottery Sherd"), },
	{ "flow", S("Flow Pottery Sherd"), }, { "friend", S("Friend Pottery Sherd"), },
	{ "guster", S("Guster Pottery Sherd"), }, { "heart", S("Heart Pottery Sherd"), },
	{ "heartbreak", S("Heartbreak Pottery Sherd"), }, { "howl", S("Howl Pottery Sherd"), },
	{ "miner", S("Miner Pottery Sherd"), }, { "mourner", S("Mourner Pottery Sherd"), },
	{ "plenty", S("Plenty Pottery Sherd"), }, { "prize", S("Prize Pottery Sherd"), },
	{ "scrape", S("Scrape Pottery Sherd"), }, { "sheaf", S("Sheaf Pottery Sherd"), },
	{ "shelter", S("Shelter Pottery Sherd"), }, { "skull", S("Skull Pottery Sherd"), },
	{ "snort", S("Snort Pottery Sherd"), },
}

cb_archaeology.SHERDS = {}
cb_archaeology.SHERD_SET = {}
for _, d in ipairs(NAMES) do
	local name = d[1]
	table.insert(cb_archaeology.SHERDS, name)
	cb_archaeology.SHERD_SET[name] = true
	core.register_craftitem("cb_archaeology:sherd_" .. name, {
		description = d[2] .. "\n" .. core.colorize("#aaaaaa", S("Used for crafting decorated pots")),
		inventory_image = "cb_archaeology_sherd_" .. name .. ".png",
		groups = { pottery_sherd = 1, cb_pot_recipe = 1, },
		_cb_sherd = name,
	})
end
