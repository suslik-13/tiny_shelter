-- The unbreakable barrier around pockets: not diggable, blast-proof, a piston
-- stopper, and protected for everyone without cb_admin (which also stops
-- machines that respect protection, e.g. techage quarries).
local S = cb_dimensions.S

core.register_node("cb_dimensions:barrier", {
	description = S("Pocket Barrier"),
	tiles = { "cb_dimensions_barrier.png", },
	groups = { unbreakable = 1, immortal = 1, not_in_creative_inventory = 1, },
	diggable = false,
	drop = "",
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),
	on_blast = function()
	end,
	can_dig = function()
		return false
	end,
})

cb_core.register_natural("cb_dimensions:barrier")

if core.get_modpath("mesecons_mvps") then
	mesecon.register_mvps_stopper("cb_dimensions:barrier")
end

local is_protected = core.is_protected
function core.is_protected(pos, name)
	if cb_dimensions.is_shell(vector.round(pos))
			and not core.check_player_privs(name or "", { cb_admin = true, }) then
		return true
	end
	return is_protected(pos, name)
end

-- Teleports through walls (chorus fruit) never cross a pocket shell.
table.insert(cb_blocks.teleport_rules, function(_, from, to)
	local _, a = cb_dimensions.is_shell(vector.round(from))
	local _, b = cb_dimensions.is_shell(vector.round(to))
	return a == b
end)
