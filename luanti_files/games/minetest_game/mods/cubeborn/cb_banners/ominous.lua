-- The ominous banner (Bedrock's fixed pattern): pillager captains carry it on
-- their back (an attached entity, not saved, gone with the captain) and drop
-- it when they die. Bad Omen still comes from cb_raids.
local B = cb_banners
B.OMINOUS = { { "rhombus", "cyan", }, { "stripe_bottom", "grey", }, { "stripe_center", "dark_grey", },
	{ "stripe_middle", "black", }, { "half_horizontal", "grey", }, { "circle", "grey", }, { "border", "black", }, }
local CARRIED = "cb_banners:carried"
local carried = setmetatable({}, { __mode = "k", })

function B.ominous_item()
	local st = ItemStack(B.item("white"))
	st:get_meta():set_string("cb_ominous", "1")
	return B.set_layers(st, B.OMINOUS)
end

core.register_entity(CARRIED, {
	initial_properties = {
		physical = false, collide_with_objects = false, pointable = false, static_save = false,
		visual = "mesh", mesh = "cb_banners_banner.b3d", visual_size = { x = 1, y = 1, },
		textures = { B.texture("white", B.OMINOUS), },
	},
	on_step = function(self)
		if not self.object:get_attach() then
			self.object:remove()
		end
	end,
})

function B.carried(ent)
	local obj = carried[ent]
	return obj and obj:get_pos() and obj or nil
end

function B.carry(ent)
	if not ent or not ent.object or not ent.object:get_pos() or B.carried(ent) then
		return
	end
	local obj = core.add_entity(ent.object:get_pos(), CARRIED)
	if obj then
		obj:set_attach(ent.object, "", vector.new(0, 6, -3), vector.new(0, 180, 0))
		carried[ent] = obj
	end
end

local I = rawget(_G, "cb_mobs_illager")
if I and I.make_captain and core.registered_items[B.item("white")] then
	local make = I.make_captain
	I.make_captain = function(ent)
		make(ent)
		B.carry(ent)
	end
	core.register_on_mods_loaded(function()
		local def = core.registered_entities["cb_mobs_illager:pillager"]
		if not def then
			return
		end
		local on_die = def.on_die
		def.on_die = function(self, pos)
			if self._captain then
				core.add_item(pos or self.object:get_pos(), B.ominous_item())
			end
			if on_die then
				return on_die(self, pos)
			end
		end
	end)
end
