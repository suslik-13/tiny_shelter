-- Young of two animals in love. mobs_redo's own breeding makes the young
-- through mobs:add_mob, which refuses mobs without a mobs_redo spawn rule;
-- ours spawn through cb_spawning, so on_breed makes it here. `hook(young)`
-- passes on what the young takes from its parents.
local A = cb_mobs_animals

function A.half(box)
	return { box[1] * 0.5, box[2] * 0.5, box[3] * 0.5, box[4] * 0.5, box[5] * 0.5, box[6] * 0.5, }
end

-- A young `name` at pos (half size, growing up as mobs_redo children do).
function A.spawn_young(pos, name)
	local obj = core.add_entity(pos, name)
	local young = obj and obj:get_luaentity()
	if young then
		young.child, young.hornytimer = true, 0
		obj:set_properties({
			visual_size = { x = young.base_size.x * 0.5, y = young.base_size.y * 0.5, },
			collisionbox = A.half(young.base_colbox), selectionbox = A.half(young.base_selbox),
		})
	end
	return young
end

function A.on_breed(self, _, hook)
	local pos = self.object:get_pos()
	local young = pos and A.spawn_young(pos, self.name)
	if young and hook then
		hook(young)
	end
	return false
end
