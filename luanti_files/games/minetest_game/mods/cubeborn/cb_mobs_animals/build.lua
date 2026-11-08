-- Golems players build (spec cycle 4, 8b): a pumpkin placed on top of the
-- right blocks (two snow blocks: snow golem; a copper block: copper golem)
-- turns them into the golem, unless the builder may not build there. The
-- iron golem has its own T shape in cb_mobs_village.
local A = cb_mobs_animals
local V = rawget(_G, "cb_mobs_village")
-- farming:pumpkin is an alias: the placed block is farming:pumpkin_8
A.PUMPKINS = V and V.PUMPKINS or { "farming:pumpkin_8", "farming:jackolantern", "farming:jackolantern_on", }
local SHAPES = {}

-- below: the blocks under the pumpkin, top first; built(ent, builder, base)
function A.register_golem(name, below, built)
	SHAPES[#SHAPES + 1] = { name = name, below = below, built = built, }
end

function A.build_golem(pos, placer)
	if table.indexof(A.PUMPKINS, core.get_node(pos).name) < 0 then
		return nil
	end
	local who = placer and placer.is_player and placer:is_player() and placer:get_player_name() or ""
	for _, shape in ipairs(SHAPES) do
		local nodes, ok = { pos, }, true
		for i, want in ipairs(shape.below) do
			local p = vector.offset(pos, 0, -i, 0)
			if core.get_node(p).name ~= want then
				ok = false
				break
			end
			nodes[#nodes + 1] = p
		end
		if ok then
			for _, p in ipairs(nodes) do
				if core.is_protected(p, who) then
					return nil
				end
			end
			for _, p in ipairs(nodes) do
				core.remove_node(p)
			end
			local base = nodes[#nodes]
			local obj = core.add_entity(vector.offset(base, 0, -0.5, 0), shape.name)
			local e = obj and obj:get_luaentity()
			if e and shape.built then
				shape.built(e, who, base)
			end
			return e
		end
	end
	return nil
end

core.register_on_placenode(function(pos, newnode, placer)
	if table.indexof(A.PUMPKINS, newnode.name) >= 0 then
		A.build_golem(pos, placer)
	end
end)
