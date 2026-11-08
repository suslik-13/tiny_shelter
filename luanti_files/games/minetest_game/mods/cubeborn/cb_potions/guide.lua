-- Brewing in unified_inventory's craft guide: one "Brewing" recipe per
-- (bottle, ingredient) pair of the brewing table.
local CP, S = cb_potions, cb_potions.S
local ui = rawget(_G, "unified_inventory")
if not (ui and ui.register_craft_type and ui.register_craft) then
	return
end

ui.register_craft_type("cb_brewing", {
	description = core.formspec_escape(S("Brewing")),
	icon = "cb_blocks_brewing_stand.png",
	width = 2,
	height = 1,
})

local inputs = {}
for kind, k in pairs(CP.KINDS) do
	for _, v in ipairs({ false, k.long and "long" or false, k.strong and "strong" or false, }) do
		for _, f in ipairs({ false, "splash", "lingering", }) do
			local name = CP.name(kind, v or nil, f or nil)
			if (v or not f or CP.throwable(kind)) and CP.parse(name) and not inputs[name] then
				inputs[name] = true
			end
		end
	end
end
for input in pairs(inputs) do
	for _, ing in ipairs(CP.INGREDIENTS) do
		local out = CP.brew(input, ing)
		if out then
			ui.register_craft({ type = "cb_brewing", output = out, items = { input, ing, }, width = 2, })
		end
	end
end
