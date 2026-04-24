-- override fs/fs_add_trade_simple.lua:
-- (this is kept here as it is trade related and does not change the formspec as such)

local old_input_add_trade_simple = yl_speak_up.input_add_trade_simple
yl_speak_up.input_add_trade_simple = function(player, formname, fields, input_to)
	if(not(player)) then
		return 0
	end
	local pname = player:get_player_name()

	input_to = "add_trade_simple"
	-- are we editing an action of the type trade?
	if(   yl_speak_up.speak_to[pname][ "tmp_action" ]
	  and yl_speak_up.speak_to[pname][ "tmp_action" ].what == 3
	  and yl_speak_up.in_edit_mode(pname)
	  and yl_speak_up.edit_mode[pname] == n_id) then
		input_to = "edit_actions"
	end

	return old_input_add_trade_simple(player, formname, fields, input_to)
end


yl_speak_up.register_fs("add_trade_simple",
	-- the input function is a new one now
	yl_speak_up.input_add_trade_simple,
	-- the get_fs function stays the same
	yl_speak_up.get_fs_add_trade_simple_wrapper,
	-- force formspec version 1 (not changed):
	1
)
