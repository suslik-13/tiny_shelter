-- Registration helpers. A block whose equivalent the server already has is not
-- registered: cb_core.equiv returns the server's block instead. Blocks the
-- pocket generators place are marked natural for cb_core.check_area.
cb_blocks.registered = {}

function cb_blocks.tex(name)
	return "cb_blocks_" .. name .. ".png"
end

-- opts: equiv = key, natural = bool, stairs = {stair_desc, slab_desc}, wall = desc
function cb_blocks.node(name, def, opts)
	opts = opts or {}
	if opts.equiv and cb_core.has_external(opts.equiv) then
		return false
	end
	local full = "cb_blocks:" .. name
	if def.is_ground_content == nil then
		def.is_ground_content = false
	end
	core.register_node(full, def)
	cb_blocks.registered[full] = true
	if opts.natural then
		cb_core.register_natural(full, "pocket")
	end
	if opts.stairs then
		stairs.register_stair_and_slab("cb_" .. name, full, def.groups, def.tiles,
			opts.stairs[1], opts.stairs[2], def.sounds, true)
	end
	if opts.wall and core.get_modpath("walls") then
		walls.register(full .. "_wall", opts.wall, def.tiles, full, def.sounds)
	end
	return true
end

function cb_blocks.item(name, def)
	core.register_craftitem("cb_blocks:" .. name, def)
	cb_blocks.registered["cb_blocks:" .. name] = true
end
