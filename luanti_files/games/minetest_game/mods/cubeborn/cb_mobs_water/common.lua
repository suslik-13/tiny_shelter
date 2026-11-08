-- What the water mobs share: the water they swim in, choking on land.
local W = cb_mobs_water
W.WATER = { "default:water_source", "default:water_flowing", "default:river_water_source",
	"default:river_water_flowing", }

-- on_flop: out of water a fish or squid chokes, 1 damage a second.
function W.choke(self)
	self.health = self.health - 1
	self:check_for_death({ type = "environment", })
end

function W.in_water(pos)
	return core.get_item_group(core.get_node(pos).name, "water") > 0
end
