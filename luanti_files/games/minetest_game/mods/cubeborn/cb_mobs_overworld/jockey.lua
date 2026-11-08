-- Spider jockey (spec cycle 4, 8a): a rare night spawn that puts a skeleton
-- archer (mobs_skeletons) on a spider (mobs_monster); only with both mods.
local Z = cb_mobs_overworld
Z.JOCKEY = "cb_mobs_overworld:spider_jockey"
local SPIDER, ARCHER = "mobs_monster:spider", "mobs_skeletons:skeleton_archer"

core.register_entity(Z.JOCKEY, {
	initial_properties = { physical = false, pointable = false, static_save = false, visual = "sprite",
		textures = { "blank.png", }, },
	on_activate = function(self)
		local pos = self.object:get_pos()
		self.object:remove()
		if not (core.registered_entities[SPIDER] and core.registered_entities[ARCHER]) then
			return
		end
		local spider = core.add_entity(pos, SPIDER)
		local rider = spider and core.add_entity(vector.offset(pos, 0, 1, 0), ARCHER)
		if rider then
			-- the spider's origin is the top of its body, the archer's its feet
			rider:set_attach(spider, "", vector.new(0, -1.5, 0), vector.zero())
		end
	end,
})
