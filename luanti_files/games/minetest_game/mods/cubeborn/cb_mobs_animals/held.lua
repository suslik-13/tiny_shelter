-- An item a mob carries in its mouth (spec cycle 4, 8b: the fox). The mob
-- keeps the itemstring in _held (saved with it); a small wielditem entity on
-- its head bone shows it. That entity is not saved and removes itself once
-- it has no carrier; the carrier shows it again when it activates.
local A = cb_mobs_animals
A.HELD = "cb_mobs_animals:held"

core.register_entity(A.HELD, {
	initial_properties = { visual = "wielditem", visual_size = { x = 0.21, y = 0.21, }, physical = false,
		pointable = false, static_save = false, wield_item = "air", },
	on_step = function(self, dtime)
		self._t = (self._t or 0) + dtime
		if self._t >= 1 then
			self._t = 0
			if not self.object:get_attach() then
				self.object:remove()
			end
		end
	end,
})

function A.show_held(self)
	if self._held_obj then
		self._held_obj:remove()
		self._held_obj = nil
	end
	local pos = self.object:get_pos()
	if not (self._held and pos) then
		return
	end
	local obj = core.add_entity(pos, A.HELD)
	if obj then
		-- default: between the fox's jaws, under the front half of its snout
		obj:set_attach(self.object, self._held_bone or "head", self._held_at or { x = 0, y = -1.6, z = 4.4, },
			{ x = 90, y = 0, z = 0, })
		obj:set_properties({ wield_item = ItemStack(self._held):get_name(), })
		self._held_obj = obj
	end
end

function A.hold(self, itemstring)
	self._held = itemstring
	A.show_held(self)
end

function A.drop_held(self)
	local pos = self.object:get_pos()
	if self._held and pos then
		core.add_item(pos, self._held)
	end
	A.hold(self, nil)
end
