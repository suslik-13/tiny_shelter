local after = minetest.after
local T = minetest.get_translator("skills")



function skills.cast(self, logic, def, args)
	if
		not skills.basic_checks_in_order_to_cast(self)
		or (not self.is_active and (self.loop_params or self.passive))
	then
		return false
	end

	if self.cooldown_timer > 0 and not self.loop_params then
		skills.print_remaining_cooldown_seconds(self)
		return false
	end

	logic(self, args)
	skills.play_sound(self, self.sounds.cast, true)

	if self.loop_params and self.loop_params.cast_rate then
		after(self.loop_params.cast_rate, function() self:cast(args) end)
	end

	if not self.loop_params then
		skills.start_cooldown(self)
	end

	return true
end