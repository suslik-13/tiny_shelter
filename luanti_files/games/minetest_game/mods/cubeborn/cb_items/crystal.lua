-- End crystal: an entity standing on obsidian or the End's bedrock. Any hit
-- makes it explode. The dragon (plan 4) heals from crystals and sets
-- cb_items.on_crystal_destroyed to hear about lost ones.
local S = cb_items.S

cb_items.on_crystal_destroyed = nil

-- fn(base_pos) called after a player sets a crystal (the dragon's respawn).
cb_items.on_crystal_placed = nil

-- Whether a crystal exploding at pos may break blocks: only where TNT is on
-- (both servers have it off); cb_dimensions also allows it in the End.
function cb_items.crystal_blast_allowed(_)
	return core.settings:get_bool("enable_tnt", core.is_singleplayer())
end

function cb_items.crystal_explode(self)
	local pos = self.object:get_pos()
	self.object:remove()
	if not pos then
		return
	end
	if tnt and tnt.boom and cb_items.crystal_blast_allowed(pos) then
		tnt.boom(vector.round(pos), { radius = 2, damage_radius = 6, })
	end
	if cb_items.on_crystal_destroyed then
		cb_items.on_crystal_destroyed(pos)
	end
end

core.register_entity("cb_items:end_crystal", {
	initial_properties = {
		physical = true,
		collide_with_objects = false,
		visual = "mesh",
		mesh = "cb_items_end_crystal.b3d",
		textures = { "cb_items_end_crystal.png", },
		visual_size = { x = 6, y = 6, },
		collisionbox = { -1, 0.5, -1, 1, 2.5, 1, },
		static_save = true,
	},
	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1, })
		self.object:set_animation({ x = 0, y = 120, }, 25)
	end,
	on_punch = function(self)
		cb_items.crystal_explode(self)
		return true
	end,
})

local BASES = { ["default:obsidian"] = true, ["cb_blocks:end_bedrock"] = true, }

function cb_items.spawn_crystal(pos)
	return core.add_entity(vector.offset(pos, 0, 0.5, 0), "cb_items:end_crystal")
end

core.register_craftitem("cb_items:end_crystal", {
	description = S("End Crystal"),
	inventory_image = "cb_items_end_crystal_item.png",
	on_place = function(itemstack, placer, pointed)
		if pointed.type ~= "node" or not BASES[core.get_node(pointed.under).name]
				or core.get_node(pointed.above).name ~= "air" then
			return itemstack
		end
		local name = placer and placer:get_player_name() or ""
		if core.is_protected(pointed.above, name) then
			core.record_protection_violation(pointed.above, name)
			return itemstack
		end
		if cb_items.spawn_crystal(pointed.under) then
			if not core.is_creative_enabled(name) then
				itemstack:take_item()
			end
			if cb_items.on_crystal_placed then
				cb_items.on_crystal_placed(vector.copy(pointed.under))
			end
		end
		return itemstack
	end,
})

local g = "default:glass"
core.register_craft({
	output = "cb_items:end_crystal",
	recipe = { { g, g, g, }, { g, "cb_items:ender_eye", g, }, { g, "cb_items:blaze_powder", g, }, },
})
