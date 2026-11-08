-- With the nether mod, quartz and ancient debris become ordinary ores of its
-- netherrack. The nether mod runs generate_ores in its on_generated, so only
-- mapchunks generated from now on get them; nothing is done at runtime.
if cb_core.profile.nether ~= "external" or not core.get_modpath("nether")
		or not (nether and nether.DEPTH_FLOOR and nether.DEPTH_CEILING) then
	return
end

core.register_ore({
	ore_type = "scatter",
	ore = "cb_blocks:quartz_ore",
	wherein = "nether:rack",
	clust_scarcity = 9 * 9 * 9,
	clust_num_ores = 5,
	clust_size = 3,
	y_min = nether.DEPTH_FLOOR,
	y_max = nether.DEPTH_CEILING,
})

core.register_ore({
	ore_type = "scatter",
	ore = "cb_blocks:ancient_debris",
	wherein = "nether:rack",
	clust_scarcity = 24 * 24 * 24,
	clust_num_ores = 2,
	clust_size = 2,
	y_min = nether.DEPTH_FLOOR,
	y_max = nether.DEPTH_CEILING,
})
