-- Mobs in buckets (spec cycle 4, 8b: tadpoles, axolotls): a water bucket
-- used on the mob takes it, with the fields listed in `keep`, into a bucket
-- item; placing that bucket pours the water as a water bucket would and lets
-- the mob out there, leaving an empty bucket.
local A = cb_mobs_animals
local WATER, EMPTY = "bucket:bucket_water", "bucket:bucket_empty"

function A.register_mob_bucket(item, def)
	core.register_craftitem(item, {
		description = def.description,
		inventory_image = def.image or "bucket_water.png^" .. def.overlay,
		stack_max = 1,
		groups = { not_in_creative_inventory = 1, },
		on_place = function(stack, placer, pointed)
			return A.release_bucket(stack, placer, pointed, def.mob, def.after) or stack
		end,
	})
end

-- The water bucket in the clicker's hand takes the mob.
function A.bucket_mob(self, clicker, item, keep)
	local stack = clicker:get_wielded_item()
	if stack:get_name() ~= WATER then
		return false
	end
	local bucket = ItemStack(item)
	local fields = {}
	for _, k in ipairs(keep) do
		fields[k] = self[k]
	end
	bucket:get_meta():set_string("mob", core.serialize(fields))
	clicker:set_wielded_item(bucket)
	self.object:remove()
	return true
end

-- Pours the water and lets the mob out, then after(entity) if given;
-- returns the empty bucket (nil when nothing could be poured).
function A.release_bucket(stack, placer, pointed, mob, after)
	local water = core.registered_items[WATER]
	if not (water and water.on_place and pointed and pointed.type == "node") then
		return nil
	end
	-- (in creative the water bucket comes back unchanged: look for the water)
	water.on_place(ItemStack(WATER), placer, pointed)
	local at
	for _, p in ipairs({ pointed.above, pointed.under, }) do
		if core.get_item_group(core.get_node(p).name, "water") > 0 then
			at = p
			break
		end
	end
	if not at then
		return nil
	end
	local obj = core.add_entity(at, mob)
	local e = obj and obj:get_luaentity()
	if e then
		for k, v in pairs(core.deserialize(stack:get_meta():get_string("mob")) or {}) do
			e[k] = v
		end
		if after then
			after(e)
		end
	end
	return ItemStack(EMPTY)
end
