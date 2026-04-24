
-- allow show_fs to be extended more easily;
--   key: formname without yl_speak_up: prefix
yl_speak_up.registered_forms_get_fs = {}
yl_speak_up.registered_forms_input_handler = {}
-- force_fs_ver can be nil if no special formspec version is required
yl_speak_up.registered_forms_force_fs_ver = {}

yl_speak_up.register_fs = function(formname, fun_input_handler, fun_get_fs, force_fs_ver)
	yl_speak_up.registered_forms_input_handler[formname] = fun_input_handler
	yl_speak_up.registered_forms_get_fs[formname] = fun_get_fs
	yl_speak_up.registered_forms_force_fs_ver[formname] = force_fs_ver
end


-- route player input to the right functions;
-- return true when the right function has been found
-- called in minetest.register_on_player_receive_fields
yl_speak_up.input_handler = function(player, formname, fields)
	if(not(formname)) then
		return false
	end
	-- cut off the leading "yl_speak_up:" prefix
	local fs_name = string.sub(formname, 13)
	if(fs_name and fs_name ~= "") then
		local fun = yl_speak_up.registered_forms_input_handler[fs_name]
		if(fun) then
			fun(player, formname, fields)
			return true
		end
	end
end


-- show formspec with highest possible version information for the player
-- force_version: optional parameter
yl_speak_up.show_fs_ver = function(pname, formname, formspec, force_version)
	-- catch errors
	if(not(formspec)) then
		force_version = "1"
		formspec = "size[4,2]label[0,0;Error: No text found for form\n\""..
				minetest.formspec_escape(formname).."\"]"..
				"button_exit[1.5,1.5;1,0.5;exit;Exit]"
	end
	-- if the formspec already calls for a specific formspec version: use that one
	if(string.sub(formspec, 1, 17) == "formspec_version[") then
		minetest.show_formspec(pname, formname, formspec)
		return
	end
	local fs_ver = (yl_speak_up.fs_version[pname] or "2")
	if(force_version) then
		fs_ver = force_version
	end
	minetest.show_formspec(pname, formname,
		"formspec_version["..tostring(fs_ver).."]"..
		formspec)
end


-- call show_formspec with the right input_* function for the right formspec
-- (handles all show_formspec-calls)
yl_speak_up.show_fs = function(player, fs_name, param)
	if(not(player)) then
		return
	end
	local pname = player:get_player_name()
	if(not(yl_speak_up.speak_to[pname])) then
		return
	end

	-- abort talk if we hit d_end
	if(fs_name == "talk" and param and param.d_id and param.d_id == "d_end") then
		yl_speak_up.stop_talking(pname)
		return
	end

	local fun = yl_speak_up.registered_forms_get_fs[fs_name]
	if(fun) then
		yl_speak_up.show_fs_ver(pname, "yl_speak_up:"..fs_name,
			fun(player, param),
			yl_speak_up.registered_forms_force_fs_ver[fs_name])
		return true

	-- this is here mostly to fascilitate debugging - so that really all calls to
	-- minetest.show_formspec are routed through here
	elseif(fs_name == "msg") then
		if(not(param)) then
			param = {}
		end
		yl_speak_up.show_fs_ver(pname, param.input_to, param.formspec, 1)


	elseif(fs_name == "quit") then
		return

	-- fallback in case of wrong call
	else
		minetest.chat_send_player(pname, "Error: Trying to show wrong "..
			"formspec: \""..tostring(fs_name).."\". Please notify "..
			"an admin.")
	end
end
